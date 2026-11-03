# OPUS attack extension

All attack additions live in this directory. The original OPUS source files,
documentation, input data, and entry points are unmodified. Add this directory
to MATLAB's path to use the `opusattack` package; do not add the `+opusattack`
directory itself. The package does not override the names of upstream functions.

## Current functionality

- Scenario-specific opt-in, disabled by default.
- One CSV per owner specifying initial active and derelict satellite counts by shell.
- Validation against the original MOCAT initial S, Su and D populations.
- Scenario naming that includes owner allocations when enabled.
- Owner-specific S, Su and D propagation through the shared MOCAT environment,
  with shared debris N and constant owner-specific launch rates.
- Annual owner-specific target, replacement, fixed-rate or no-launch decisions.
- Integrated expected flow accounting, attributed interval event records and exports.

Destruction/disabling events, time-varying launch-schedule files and independent
owner economic equilibrium decisions are not implemented yet. Behavior profiles
are deferred. `runScenario` now runs the annual owner controllers and exports
results. `propagateScenario` remains available for physical-only comparisons.
The original OPUS workflow remains the entry point for ordinary simulations.

## Validate the example

From the OPUS repository root in MATLAB:

```matlab
addpath('extensions/attack');
scenario = opusattack.prepareScenario('extensions/attack/examples/attack-example.csv');
owners = scenario.attack.owners;
% owners.ids identifies columns; owners.S, owners.Su and owners.D are shell-by-owner.
```

This reads input and returns configuration without writing results. To simulate
five years with annual owner-specific launch decisions and export the results:

```matlab
result = opusattack.runScenario('extensions/attack/examples/attack-example.csv', 5);
disp(result.output_directory);
```

Do not pass extension parameter files to the original `iam_solver`,
`scenarioNamer`, or `conductor.sh`: those entry points do not understand attacks.
`opusattack.prepareScenario('benchmark')` returns disabled configuration without
requiring owner files. Setup temporarily uses the OPUS working directory for
upstream relative input paths, then restores the caller's directory and path.

## Scenario and owner files

Start with the [filled CSV templates and field guide](templates/README.md).
They include a named owner, a matching generic owner, accepted value types,
units, a shell reference, and instructions for editing and saving the CSVs.

The extension parameter CSV uses the existing three-column numeric layout:

```csv
parameter_type,parameter_name,parameter_value
attack,enabled,1
```

Use `0`, or omit the row, to disable attack configuration. Numeric `MOCAT` and
`econ` overrides are supported by the extension adapter with the original OPUS
assignment semantics. Derived physical parameters are not rebuilt automatically.
GMPHD is not supported by the attack extension.

For `my-scenario.csv`, create a sibling directory `my-scenario-owners/`.
Put one CSV per owner in it. The filename without `.csv` is the unique owner ID,
using letters, digits, underscores or hyphens. IDs are case-insensitive.
Every file must contain exactly the columns `shell,S,Su,D` and one row for each
shell, including zeros. For example, the first rows might be:

```csv
shell,S,Su,D
1,0,0,0
2,4,1,1
```

Continue through shell 40 for the default model. S means active slotted satellites;
Su means active fringe satellites; D means non-operational satellites still in
the modeled orbital region. Row order does not matter. Counts must be
finite and nonnegative; fractional expected counts are allowed. Across owners,
S, Su and D totals must separately match the original populations in every shell.
The loader rejects missing allocations and double counting. N remains shared
debris and is not allocated here. Files currently specify initial ownership,
not launch rules. Older three-column owner files must add D explicitly; the
loader does not infer derelict ownership or silently assume zero counts.

The example assigns 1,000 of the existing 2,529 slotted satellites in shell 10
(515–550 km) to `attacked`. `generic` owns the remaining 1,529, all other slotted
satellites, all fringe satellites, and all existing derelicts. The attacked owner
initially has zero D in every shell. This is an illustrative scenario assumption,
not historical ownership data. When changing the attacked counts, adjust the
generic counts so that the totals still match. Add further owners by creating
files and reallocating counts from the generic owner.

Disabled satellites will use their owner's D population rather than a separate
U population. The planned attack transfer adds D in the same shell, without the
retirement-related relocation to the disposal shell. Owner-specific propagation
is implemented; the attack transfers themselves are not implemented yet.

## Owner-aware physical propagation

From the repository root, run the template for one year with zero launches:

```matlab
addpath('extensions/attack');
OUT = opusattack.propagateScenario( ...
    'extensions/attack/templates/owner-scenario.csv', linspace(0,1,5));
```

To prescribe constant launch rates in satellites/year for each owner and shell:

```matlab
p = 'extensions/attack/templates/owner-scenario.csv';
scenario = opusattack.prepareScenario(p);
owners = scenario.attack.owners;
launches.S = zeros(size(owners.S));
launches.Su = zeros(size(owners.Su));
% Select an owner by ID, not by assuming a particular column order.
i = find(strcmp(owners.ids,'example-owner'));
launches.S(10,i) = 100;
OUT = opusattack.propagateScenario(p, linspace(0,1,5), launches);
```

These are fixed rates for the integration interval, not automatically selected
launch policies or individual rocket launches. Omitting `launches` means zero
launches. No economic solver or attack event is run by this function. No files
are written automatically by `propagateScenario`; the returned data can be saved
to a MAT file. `runScenario`, in contrast, exports by default.

| Output | Meaning / dimensions |
| --- | --- |
| `OUT.T` | Reporting times in years |
| `OUT.owners.ids` | Owner IDs in column order |
| `OUT.owners.S`, `.Su`, `.D` | Counts: time x shell x owner |
| `OUT.S`, `.Su`, `.D`, `.N` | Aggregate counts: time x shell |
| `OUT.total` | Total objects per time and shell |
| `OUT.final.owners`, `OUT.final.N` | Final state for continuing propagation |
| `OUT.launches`, `OUT.parameters` | Launch rates and physical parameters used |
| `OUT.flow_definition`, `OUT.cumulative_flows` | Definition of each attributed flow and its integrated count at every reporting time |
| `OUT.balance_residual` | Numerical difference between the state and its initial state plus recorded net flows |
| `OUT.scenario`, `OUT.cost_parameters` | Setup metadata from the scenario wrapper |

For three or more requested times, the histories use those times. With only
start and end times, MATLAB also returns its intermediate integration points.
Singleton owner dimensions follow normal MATLAB array conventions.

The lower-level `opusattack.propagateOwners(tspan,owners,N,launches,VAR)` accepts
an arbitrary current state, including the previous output's final state. It
requires `VAR.k_star` from the disposal calculation; `propagateScenario` supplies
that automatically. A continued run must pass the current shared N as well as
the owner counts, rather than reload the initial state.

All owners currently share each species' upstream physical properties. Their
summed populations define the shell collision environment. Equal-exposure active
satellites incur losses proportional to owner counts. New damage-generated D
belongs to the affected active satellite's owner; retirement-generated D retains
its owner when placed into the original disposal shell. Existing D decays from
its current shell and never receives that retirement relocation. Drag transfers
D between shells without changing owner, and removes it below the lower boundary.
Default slotted-slotted collision suppression is preserved.

The numerical implementation mirrors the original MOCAT equations, including
their breakup counting conventions, rather than correcting physical assumptions.
The extension defines the active cross terms to be zero when both active counts
are zero and uses the ODE solver's nonnegative constraints. It rejects negative
initial populations and reports incomplete/nonfinite integration as an error.
It has been tested against the original symbolic MOCAT propagator with identical
aggregate initial states and fixed launch rates. This does not yet establish
equivalence of the annual economic controllers, which are not used here.

## Annual launch controller and complete runs

Place an optional `<scenario>-launches.csv` beside the scenario CSV. Columns:

```csv
owner_id,shell,population,mode,target_size,max_launch_rate
example-owner,10,S,target,3000,1500
generic-owner,29,S,target,300,150
```

Each row identifies an existing owner, shell, and active population (`S` or `Su`).
Duplicate rows for that combination are rejected. All numeric cells must be finite
and nonnegative. Target size is a count; maximum launch rate is satellites/year.

| Mode | Rate at the start of each decision interval |
| --- | --- |
| `target` | min(maximum rate, max(target - current owner count, 0) / interval years) |
| `replacement` | min(maximum rate, current owner count / lifetime) |
| `fixed` | maximum rate, regardless of current count |
| `none` | zero |

Use target_size=0 except in target mode, and max_launch_rate=0 for none mode.
Unlisted combinations use uncapped replacement (current owner count / lifetime).
No launch file means replacement everywhere. Every decision, including zero rates,
is saved with the current owner count and policy. A target rule follows the
original buildup formula at annual intervals; it does not guarantee the target
will be reached after simultaneous retirement and collisions. S and Su policies
are owner-specific but are not yet independently optimized economic decisions.

`runScenario(parameter_file, years, outputDirectory)` updates launch rates at
year boundaries, propagates once per interval, and uses that final state for the
next decision. A fractional final year is supported. Omitting years selects one
year. Omitting outputDirectory creates a unique directory in `extensions/attack/results/`.
An explicitly empty third argument (`''`) runs in memory only. Existing output
directories are rejected rather than overwritten. Generated default results are
ignored by Git through the extension's own `.gitignore`.

## Accounting, events, and exports

The ODE integrates cumulative flow counters alongside the populations. Each flow
has an affected owner/population, counterpart when known, source and destination
shells, and source/destination quantities. Retirement splits into D transfer and
removal according to P. Collision damage transfers active satellites to their
owner's D; destruction produces shared N. D/N drag transfers and lower-boundary
exits are recorded. The counters generate the same population derivatives, which
allows a numerical population balance check for every run.

Collision records are **ordered expected flow contributions**, not individual
collision incidents or numbers of rocket launches. Same-owner and cross-owner
terms preserve the original equations' counting conventions. Do not sum them as
unique physical encounters. A source loss and its generated debris are different
quantities, recorded as `source_count` and `destination_count`. Shared N has no
invented owner. An owner may appear as both affected and counterpart in an event.

The major-event table includes launches and collision-related summaries with
start/end times. It excludes routine retirement and drag, which remain in the
complete flow ledger. `event_time` is NaN for these interval records; future
instantaneous attacks can use equal start/end times and a finite event_time.
The separate participant table links all known involved owners and their roles
to the event ID. No destruction/disabling event scheduler is implemented yet.

Each export contains:

| File | Contents |
| --- | --- |
| `result.mat` | Full histories, per-interval flow definitions and counters (including zeros), final state, configuration and input snapshots |
| `owner-populations.csv` | Time, shell, owner, S, Su and D |
| `shell-populations.csv` | Aggregate S, Su, D, N and total counts |
| `launch-decisions.csv` | Owner-specific policy and rate at each interval start |
| `flows.csv` | Nonzero integrated channel totals per decision interval |
| `events.csv`, `event-participants.csv` | Major interval records and participating owners |
| `diagnostics.csv` | Maximum population balance residual per interval |
| `metadata.json`, `source-manifest.csv` | Run settings and SHA-256 hashes of source/input dependencies |
| `inputs/` | Copies of the scenario, owner and optional launch-policy CSVs as read |
| `COMPLETE.txt` | Written last to mark a completed export |

CSV quantities may contain fractional expected objects. Zero channels and finer
reporting-time cumulative counts remain available in `result.mat`. The state
dimensions are linear in owner count; detailed owner-pair flow accounting grows
approximately quadratically. Non-opt-in scenarios continue using the untouched
upstream entry points. Regression tests compare against original MOCAT under
equivalent launch inputs, not against the old controller's stale initial counts.

## Tests and upstream synchronization

From the repository root:

```matlab
results = runtests('extensions/attack/tests');
assertSuccess(results);
```

Keep future extension source, tests, example inputs, documentation, and generated
outputs within `extensions/attack/`. The original repository can be updated without
merging attack edits into its files. This does not guarantee API compatibility:
after an upstream update, run the tests and review changes to initializers,
parameter structures, state ordering, and population data. The package currently
expects the original four-population state `[S; D; N; Su]` and 40-shell naming
configuration. Its numeric parameter adapter and scenario naming mirror upstream
behavior and should be checked when those upstream interfaces change.

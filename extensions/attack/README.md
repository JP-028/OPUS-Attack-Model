# OPUS attack extension

For practical instructions, read the [simulation guide](templates/SIMULATION_GUIDE.md).
The [examples index](examples/README.md) lists the runnable scenario folders.

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
- Multiple scheduled fragmentation events, each destroying exactly one active
  satellite of a selected owner and adding standard debris to N in the same shell.
- Scheduled disabling events transferring a chosen number of active satellites
  to the same owner's D population in the same shell, using the same event CSV.

Bulk destruction within one event, time-varying launch schedules and independent
owner economic equilibrium decisions are not implemented yet. Behavior profiles
are deferred. `runScenario` now runs the annual owner controllers and exports
results. `propagateScenario` remains available for physical-only comparisons.
The original OPUS workflow remains the entry point for ordinary simulations.

## Validate the example

From the OPUS repository root in MATLAB:

```matlab
addpath('extensions/attack');
scenario = opusattack.prepareScenario('extensions/attack/examples/baseline/attack-example.csv');
owners = scenario.attack.owners;
% owners.ids identifies columns; owners.S, owners.Su and owners.D are shell-by-owner.
```

This reads input and returns configuration without writing results. To simulate
five years with annual owner-specific launch decisions and export the results:

```matlab
result = opusattack.runScenario('extensions/attack/examples/baseline/attack-example.csv', 5);
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

Disabled satellites use their owner's D population rather than a separate
U population. The attack transfer adds D in the same shell, without the
retirement-related relocation to the disposal shell. Their owner remains known
while the derelicts follow passive drag and collision dynamics.

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
launches. No economic solver or attack event is run by this function. It rejects
scenarios containing events rather than silently ignoring them. No files
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
year boundaries, propagates between boundaries/events, and uses the final state for the
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
complete flow ledger. `event_time` is NaN for these interval records. Attack
records have equal start/end times and a finite event_time.
The separate participant table links all known involved owners and their roles
to the event ID. Fragmentation and disabling share the schedule described below.

Each export contains:

| File | Contents |
| --- | --- |
| `result.mat` | Full histories, per-interval flow definitions and counters (including zeros), final state, configuration and input snapshots |
| `owner-populations.csv` | Time, shell, owner, S, Su and D |
| `shell-populations.csv` | Aggregate S, Su, D, N and total counts |
| `launch-decisions.csv` | Owner-specific policy and rate at each interval start |
| `flows.csv` | Nonzero integrated channel totals per decision interval |
| `events.csv`, `event-participants.csv` | Major interval records, instantaneous attacks and participating owners |
| `fragmentations.csv` | Exact attack quantities, before/after counts and representative mass balance |
| `disablings.csv` | Disabled counts, retained physical properties, before/after active/D/N counts and transfer balances |
| `population-balance.csv` | Final per-shell/per-owner balance including continuous flows and attacks |
| `diagnostics.csv` | Maximum continuous population balance residual per integration segment |
| `metadata.json`, `source-manifest.csv` | Run settings and SHA-256 hashes of source/input dependencies |
| `inputs/` | Copies of the scenario, owner, optional launch-policy and optional event CSVs as read |
| `COMPLETE.txt` | Written last to mark a completed export |

CSV quantities may contain fractional expected objects. Zero channels and finer
reporting-time cumulative counts remain available in `result.mat`. The state
dimensions are linear in owner count; detailed owner-pair flow accounting grows
approximately quadratically. Non-opt-in scenarios continue using the untouched
upstream entry points. Regression tests compare against original MOCAT under
equivalent launch inputs, not against the old controller's stale initial counts.

## Scheduled fragmentation

The complete example is `examples/fragmentation/fragmentation.csv`. It uses the same owners
and launch policies as `examples/baseline/attack-example.csv` (which remains an attack-free
control), and adds `fragmentation-events.csv`:

```csv
event_id,time_year,event_type,owner_id,shell,population,count
fragment-001,0.5,fragmentation,attacked,10,S,1
```

This destroys one of the attacked owner's S satellites in shell 10 at year 0.5.
No F or U population is introduced. The active owner count decreases by exactly
one; N in that shell increases by `VAR.mass(1)/VAR.mass(3)` for S or
`VAR.mass(4)/VAR.mass(3)` for Su. With the defaults, the increase is
`223 / 0.640 = 348.4375` standard debris objects. D and all other owner counts
are unchanged at the instant of the attack. Fractions are retained, conserving
the representative mass of the immediate conversion. The subsequent original
MOCAT breakup equations are not a globally mass-conserving material model.

The new debris is immediately distributed within the attacked shell and follows
the standard N dynamics. Later debris counts need not differ from a control by
exactly 348.4375: drag, collisions and subsequent annual launch responses change
both trajectories. This is a functional implementation of the specified
shell-average assumption, not validation of a real breakup-cloud distribution.

Run and export from the repository root in PowerShell:

```powershell
matlab -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/examples/fragmentation/fragmentation.csv',1); disp(r.fragmentations); disp(r.output_directory);"
```

Or run in MATLAB without exporting:

```matlab
addpath('extensions/attack');
r = opusattack.runScenario('extensions/attack/examples/fragmentation/fragmentation.csv',1,'');
r.fragmentations
r.max_global_balance_residual
```

For another scenario, copy an event template to `<scenario>-events.csv` beside
its parameter CSV and set existing owner IDs. Missing or header-only event
files mean no attack. The loader rejects duplicate event IDs (ignoring case),
fragmentation counts other than 1, nonpositive or fractional disabling counts,
unsupported event types, invalid targets and times outside the run horizon.
The actual remaining target count is checked at execution time; if fewer than
the requested count remain, the run stops rather than reducing the attack silently.

### Multiple attacks: choose when, who and where

The complete `examples/multiple-attacks/multiple-attacks.csv` scenario uses this schedule in
`examples/multiple-attacks/multiple-attacks-events.csv`:

```csv
event_id,time_year,event_type,owner_id,shell,population,count
attack-001,0.25,fragmentation,attacked,10,S,1
attack-002,0.75,fragmentation,attacked,10,S,1
attack-003,0.75,fragmentation,generic,11,Su,1
attack-004,1,fragmentation,generic,29,S,1
```

Edit `time_year` for elapsed simulation years (decimal times are allowed),
`owner_id` for the owner filename without `.csv`, and `shell` for the altitude
shell index. `templates/shell-reference.csv` lists the default altitude bounds.
There are no horizontal divisions or localized debris clusters within a shell.
`population` selects active slotted S or active fringe Su satellites. Each row
destroys one satellite; use a distinct `event_id` for each row. The runner sorts
events chronologically and executes equal-time rows in their original CSV order.
Repeated attacks may target the same owner and shell, or different ones.

```powershell
matlab -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/examples/multiple-attacks/multiple-attacks.csv',1); disp(r.fragmentations); disp(r.output_directory);"
```

The final numeric argument is the simulation horizon in years; it must include
all scheduled events. For your own scenario, start from
`templates/attack-schedule-events.csv` and rename it to match the parameter file.
The four example attacks immediately generate a combined 1393.75 standard N
objects from 892 kg using default masses. These are sums of the instantaneous
additions, not the final debris difference from a control run.

Timing is explicit: propagate up to the event, apply the state jump, and continue.
At year zero and annual boundaries, all attacks occur before the launch decision.
A midyear attack does not reset rates already decided for that year. An attack
exactly at the simulation end is included in the final state without a new launch
decision. Each event is executed exactly once.

History/export schema version 3 retains version 2's `sample_index`, `phase`, and `event_id` in
the owner and shell population CSVs. Each event has two rows per shell/owner at
its time: `pre_event` and `post_event`. Two simultaneous events therefore have
four rows at that time, preserving both transitions. Do not deduplicate on time alone.
Normal samples are `regular`. Full owner/debris states before and after the
attack are also retained in `result.attack_snapshots` in the MAT file.

The event log uses an `attack:` prefix for configured event IDs, distinguishing
them from automatically generated interval-record IDs. Its kind is
`instantaneous_attack`; the attacked owner is the known participant. No attacker
identity is invented. The flow ledger records one source object and the generated
N objects. `result.population_balance` and `max_global_balance_residual` include
that jump, while per-segment residuals audit continuous propagation separately.
`fragmentations.csv` reports masses and exact local changes. The event input is
included in scenario identity and copied to `inputs/events.csv` on export.

## Disabling satellites with the same schedule

Use `event_type=disabling` in the same `<scenario>-events.csv` file. Set `count`
to the positive whole number of satellites to disable. For example:

```csv
event_id,time_year,event_type,owner_id,shell,population,count
fragment-001,0.25,fragmentation,attacked,10,S,1
disable-001,0.5,disabling,attacked,10,S,100
disable-002,0.5,disabling,generic,11,Su,20
fragment-002,0.75,fragmentation,attacked,10,S,1
disable-003,1,disabling,generic,29,S,1
```

This is the complete `examples/mixed-attacks/mixed-attacks.csv` scenario. Run it from the
repository root in PowerShell:

```powershell
matlab -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/examples/mixed-attacks/mixed-attacks.csv',1); disp(r.disablings); disp(r.output_directory);"
```

Each disabling event subtracts `count` from the selected owner's S or Su and adds
the same count to that owner's D in the selected shell. No N is added, and total
object count and representative satellite mass are conserved at that instant.
The disabled satellites do not undergo the normal active-retirement relocation
or successful-disposal fraction. They have no launches, stationkeeping, active
avoidance or further lifetime removal of their own. Existing D drag transports
them downward; crossing the lowest shell boundary removes them from the model.
Collisions may also remove D and generate N according to the original equations.
Gravity alone is not the decay mechanism: the model uses atmospheric drag.

The disabled objects interact with all owners through the existing active-D and
D-D collision terms. S-S collision suppression does not suppress S-D interactions.
Active operators retain the original MOCAT avoidance assumptions; this extension
does not add individual maneuvers or attack-specific behavior profiles. Annual
launch decisions use the remaining active owner counts, with the same timing
rules as fragmentation. A target policy may therefore launch replacements.

The default S, Su and D classes have matching physical properties (223 kg mass,
1.741 square metres area and 1.490 metres diameter). Because a shared D class
cannot preserve differing properties, configured disabling events are rejected
if the targeted active class differs from D in mass, area, diameter or ballistic
coefficient. Supporting heterogeneous disabled classes would require additional
physics classes. Other scenarios are unaffected by this validation.

Export schema version 3 adds `result.disablings` and `disablings.csv`. Both attack
types also appear in `events.csv`, `flows.csv`, the participant table, full
before/after snapshots and global population balances. Disabled objects merge
into their owner's existing D count; the event ledger records their origin, but
later D losses are not separately attributed to an attack cohort. Percentages
are not interpreted by the scheduler: supply a number of satellites, not `20%`.

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

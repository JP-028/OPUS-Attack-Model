# OPUS attack extension

All attack additions live in this directory. The original OPUS source files,
documentation, input data, and entry points are unmodified. Add this directory
to MATLAB's path to use the `opusattack` package; do not add the `+opusattack`
directory itself. The package does not override the names of upstream functions.

## Current functionality

- Scenario-specific opt-in, disabled by default.
- One CSV per owner specifying initial active satellite counts by shell.
- Validation against the original MOCAT initial S and Su populations.
- Scenario naming that includes owner allocations when enabled.

Owner propagation, attack events, event logging, and independent owner economic
decisions are not implemented yet. Behavior profiles are deferred. The separate
attack runner stops explicitly after validation until propagation is implemented.
The original OPUS workflow remains the entry point for ordinary simulations.

## Validate the example

From the OPUS repository root in MATLAB:

```matlab
addpath('extensions/attack');
scenario = opusattack.prepareScenario('extensions/attack/examples/attack-example.csv');
owners = scenario.attack.owners;
% owners.ids identifies columns; owners.S and owners.Su are shell-by-owner.
```

This reads input and returns configuration without writing results. The eventual
attack simulation entry point is:

```matlab
opusattack.runScenario('extensions/attack/examples/attack-example.csv');
% Currently reports OPUS:AttackModelNotImplemented after validation.
```

Do not pass extension parameter files to the original `iam_solver`,
`scenarioNamer`, or `conductor.sh`: those entry points do not understand attacks.
`opusattack.prepareScenario('benchmark')` returns disabled configuration without
requiring owner files. Setup temporarily uses the OPUS working directory for
upstream relative input paths, then restores the caller's directory and path.

## Scenario and owner files

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
Every file must contain exactly the columns `shell,S,Su` and one row for each
shell, including zeros. For example, the first rows might be:

```csv
shell,S,Su
1,0,0
2,4,1
```

Continue through shell 40 for the default model. S means active slotted satellites;
Su means active fringe satellites. Row order does not matter. Counts must be
finite and nonnegative; fractional expected counts are allowed. Across owners,
S and Su totals must separately match the original populations in every shell.
The loader rejects missing allocations and double counting. D and N are not
allocated here. Files currently specify initial ownership, not launch rules.

The example assigns 1,000 of the existing 2,529 slotted satellites in shell 10
(515–550 km) to `attacked`. `generic` owns the remaining 1,529, all other slotted
satellites, and all fringe satellites. This is an illustrative scenario assumption,
not historical ownership data. When changing the attacked counts, adjust the
generic counts so that the totals still match. Add further owners by creating
files and reallocating counts from the generic owner.

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

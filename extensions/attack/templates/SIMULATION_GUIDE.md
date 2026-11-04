# Editing and running an OPUS attack simulation

This guide describes the currently implemented extension. All input changes and
new scenarios belong under `extensions/attack/`. You do not need to edit the
original OPUS conductor, MATLAB functions, initial-population files, or parsets.

You edit and save CSV files, then run one MATLAB command from PowerShell. MATLAB
must be installed and available through the `matlab` command. The extension has
been tested with MATLAB R2026b. There is no interactive scenario-selection
launcher yet; the path in the command selects the scenario.

Jump to:

1. [Run the six-event example](#1-run-the-existing-six-event-example)
2. [Create a scenario](#2-create-your-own-scenario)
3. [Change or add owners](#3-change-the-generic-and-secondary-owner)
4. [Choose shells](#4-choose-shells)
5. [Set launch policies](#5-set-owner-launch-behavior)
6. [Schedule attacks](#6-schedule-fragmentation-and-disabling)
7. [Change parameters](#7-change-model-parameters)
8. [Save and validate CSVs](#8-save-and-validate-your-files)
9. [Run from PowerShell or MATLAB](#9-run-from-powershell-or-matlab)
10. [Read results](#10-read-the-results)
11. [Troubleshoot](#11-common-problems)

## 1. Run the existing six-event example

Open PowerShell in the repository root: the directory containing
`extensions`, `MOCAT4S`, and the original OPUS files. In VS Code, open a terminal
and check its working directory with `Get-Location`.

```powershell
matlab -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/examples/six-events/six-events.csv',1); disp(r.output_directory);"
```

This executes one simulation year, with three fragmentation and three disabling
events. It prints the new result directory. The example destroys three satellites
and disables 121. Its fragmentation events add a total of 1045.3125 standard
debris objects at their event times, using the default masses. That number is
not the final debris difference from a no-attack run: collisions and drag keep
acting between events.

The [examples index](../examples/README.md) lists the other runnable scenarios.
Their inputs are grouped by scenario. Old commands with flat paths such as
`examples/six-events.csv` must now use `examples/six-events/six-events.csv`.

## 2. Create your own scenario

Use a fresh directory for each experiment. The following PowerShell commands
copy the templates into a scenario named `my-study`. Choose another directory
name if it already exists; these instructions are for a new study.

```powershell
New-Item -ItemType Directory -Path 'extensions/attack/scenarios/my-study'
Copy-Item -LiteralPath 'extensions/attack/templates/owner-scenario.csv' -Destination 'extensions/attack/scenarios/my-study/my-study.csv'
Copy-Item -LiteralPath 'extensions/attack/templates/owner-scenario-launches.csv' -Destination 'extensions/attack/scenarios/my-study/my-study-launches.csv'
Copy-Item -LiteralPath 'extensions/attack/templates/owner-scenario-owners' -Destination 'extensions/attack/scenarios/my-study/my-study-owners' -Recurse
Copy-Item -LiteralPath 'extensions/attack/templates/attack-schedule-events.csv' -Destination 'extensions/attack/scenarios/my-study/my-study-events.csv'
```

The resulting structure must be:

```text
my-study/
  my-study.csv
  my-study-launches.csv
  my-study-events.csv
  my-study-owners/
    example-owner.csv
    generic-owner.csv
```

The parameter filename determines the companion filenames. If the parameter
file is `my-study.csv`, the runner looks beside it for `my-study-owners/`,
`my-study-launches.csv`, and `my-study-events.csv`. The containing folder can
have any name. Rename all companion files/directories together if you change
the parameter filename.

Alternatively, copy an entire example folder into `extensions/attack/scenarios/`
and keep its internal filenames. Example owners are named `attacked` and
`generic`; template owners are named `example-owner` and `generic-owner`.
Do not mix these IDs when copying event or launch rows between the two.

| Input | What you edit |
| --- | --- |
| `my-study.csv` | Opt-in switch and shared model parameters |
| `my-study-owners/*.csv` | Initial owner counts per shell |
| `my-study-launches.csv` | Launch policies for owner/shell/population combinations |
| `my-study-events.csv` | Attack time, type, owner, shell, active population and count |

Keep references, backups, and unused owner CSVs outside `my-study-owners/`.
Every CSV in that directory is loaded as an owner.

## 3. Change the generic and secondary owner

### What an owner means

An owner is a set of population counts per shell, not a list of individual
satellites. The filename without `.csv` supplies the owner ID. `generic-owner`
and `example-owner` are ordinary IDs; neither has special automatic behavior.
The generic owner represents the remainder of the original population because
the supplied CSV assigns that remainder to it.

Every owner file needs the exact header `shell,S,Su,D` and one row for each of
the 40 default shells, including zeros:

```csv
shell,S,Su,D
1,0,0,0
2,0,0,0
```

This excerpt is not a complete file: retain rows 3 through 40 as well.

| Column | Meaning | Accepted values |
| --- | --- | --- |
| `shell` | Altitude-band index | Every integer 1 through 40 exactly once |
| `S` | Active slotted satellites owned in this shell | Finite number >= 0 |
| `Su` | Active fringe satellites owned in this shell | Finite number >= 0 |
| `D` | Non-operational satellites owned in this shell, still inside the modeled region | Finite number >= 0 |

Whole numbers are natural for initial allocations. Fractional expected counts
are also accepted because the model propagates populations continuously.
Use `0` for an empty population, not a blank. Do not add N, owner-name,
percentage, behavior, or explanatory columns. N debris is shared across owners.

### Reallocate satellites between the two owners

For every shell and for S, Su and D separately, the sum across owners must match
the original initial population. Editing ownership does not create new satellites.
The supplied template has these shell-10 counts:

| Owner | S | Su | D |
| --- | ---: | ---: | ---: |
| example-owner | 1000 | 0 | 0 |
| generic-owner | 1529 | 334 | 2 |
| Required total | 2529 | 334 | 2 |

To give the secondary owner 1200 S instead of 1000, edit shell 10 in both files:

```csv
10,1200,0,0
```

in `example-owner.csv`, and:

```csv
10,1329,334,2
```

in `generic-owner.csv`. All other rows stay as intended. Similarly, assigning
one existing derelict to the secondary owner means increasing its D to 1 and
reducing generic D to 1 in that shell. This changes initial ownership; it does
not simulate a disabling attack.

For any number of owners, calculate each generic entry as:

`generic = original shell/population total - sum of all other owners`

The remainder cannot be negative. The program checks these sums but does not
calculate or rewrite the generic file for you. Moving 100 satellites out of
one shell and into another would change the initial shell totals and is rejected
by this ownership-only input mechanism. Model additional deployments with launch
rules rather than increasing initial totals in owner files.

### Rename or add owners

To rename `example-owner` to `owner-b`:

1. Rename its file to `owner-b.csv`.
2. Replace `example-owner` with `owner-b` in the launch CSV.
3. Replace it in the event CSV as well.
4. Validate the scenario before running.

IDs may contain letters, digits, hyphens and underscores and must begin with a
letter or digit. IDs must be unique ignoring case. Renaming the generic owner
works identically. Removing a named owner requires reallocating its counts and
removing or updating its event and launch references.

To add a third owner, create another complete 40-row file, give it the desired
counts, and subtract the same amounts from the existing owners in the same
shells/populations. Start its unused entries at zero; copying an existing file
without changing those entries would double-count satellites. Add launch rules
where needed. All owners interact through the same shell populations even
though their counts and flows are recorded separately.

## 4. Choose shells

Use the shell index, not the altitude in kilometres, in every CSV. The default
grid has 40 shells, each 35 km thick, spanning 200 to 1600 km. Shell 10 covers
515-550 km. [shell-reference.csv](shell-reference.csv) gives every boundary.

The model has altitude shells only, with no longitude, latitude or localized
debris clouds inside a shell. New fragmentation debris is distributed across
the selected shell according to the same approximation as existing N.

## 5. Set owner launch behavior

The exact launch CSV header is:

```csv
owner_id,shell,population,mode,target_size,max_launch_rate
example-owner,10,S,target,3000,1500
generic-owner,29,S,target,300,150
```

Use existing owner IDs, shell integers, and `S` or `Su`. D and N cannot receive
launches. Provide no more than one row per owner/shell/population combination.
Targets are satellite counts; rate limits are satellites per year. Both numeric
fields must be finite and nonnegative, including when a field is unused.

| Mode | Launch rate at a decision | Required field usage |
| --- | --- | --- |
| `target` | Smaller of the rate cap and positive target shortfall divided by the decision interval in years | Set target and cap |
| `replacement` | Smaller of the rate cap and current active count / `Dt` | Set target to 0 |
| `fixed` | Exactly the configured rate cap | Set target to 0 |
| `none` | Zero | Set both numbers to 0 |

Decisions normally occur at years 0, 1, 2, etc., and use each owner's current
active count. A final partial year uses its shorter decision interval for target
rates. Launches are continuous rates during an interval, not instantaneous
batches. A target policy does not guarantee that the target is reached because
losses occur during propagation.

**Unlisted combinations use uncapped replacement (`current count / Dt`).** A
missing launches file therefore does not turn launches off. To stop launches
for an owner everywhere, supply `none,0,0` rules for both S and Su in every shell.

A target policy may increase launches after attacks by trying to fill the larger
shortfall. A replacement policy uses the remaining active count, so its rate may
decrease after attacks. These are mathematical rules, not implemented cautious
or fearless behavior profiles. Profiles and independent economic optimization
are still future work.

## 6. Schedule fragmentation and disabling

Both attack types use the same CSV and these exact columns:

```csv
event_id,time_year,event_type,owner_id,shell,population,count
fragment-001,0.25,fragmentation,example-owner,10,S,1
disable-001,0.5,disabling,example-owner,10,S,100
disable-002,0.5,disabling,generic-owner,11,Su,20
```

| Field | What to enter |
| --- | --- |
| `event_id` | A unique ID for this row, ignoring case; letters/digits/hyphens/underscores, first character alphanumeric |
| `time_year` | Finite elapsed simulation years >= 0 and <= the run duration; `0.5` is half a year, not a calendar date |
| `event_type` | Exactly `fragmentation` or `disabling` |
| `owner_id` | Existing owner filename without `.csv` |
| `shell` | Integer 1-40 on the default grid |
| `population` | `S` or `Su`; attacks on D or N are not supported |
| `count` | Exactly 1 for fragmentation; a positive whole number for disabling |

Add rows for additional events. Events are sorted by time. Equal-time events
execute in their CSV row order, and each sees the state left by the previous
one. This matters if two attacks compete for the same remaining satellites.
All events share one unique-ID namespace, regardless of type.

At execution time there must be enough active satellites of the selected owner
and population in that shell. Counts may have changed through launches,
retirements, collisions, and earlier attacks. The run stops on an insufficient
count; it does not silently disable fewer satellites or borrow another owner's.

At time zero and annual decision boundaries, all attacks execute before the next
launch decision. Midyear attacks retain the previously selected launch rates
until the next annual decision. An attack exactly at the run end changes the
final state, but no time remains to observe its subsequent evolution. Extend
the run duration if you want to observe that aftermath.

### Fragmentation

One selected active satellite is removed. Standard N debris increases in the
same shell by `active satellite mass / standard N object mass`. Defaults are
`223 / 0.640 = 348.4375` objects. Fractional debris counts are kept to preserve
representative mass. There is no separate F population. Existing N is retained.
Later collisions and drag change N, so do not expect the final difference from
a control to equal the sum of the immediate attack additions.

### Disabling

The selected active count moves into the same owner's D in the same shell.
There is no immediate N addition, disposal maneuver, or move to the lowest
shell. The satellites stop being active/slotted objects. They follow the
existing derelict collision and atmospheric-drag equations, preserve ownership,
and leave the simulation when they cross below its lowest shell. They have no
stationkeeping, active avoidance or further active-lifetime retirement.

Default S, Su and D physical properties match. Disabling rejects configurations
where the targeted active class and D differ in mass, area, diameter or ballistic
coefficient, because a shared D class cannot retain different properties. D
includes both existing derelicts and newly disabled objects. Their attack origin
is logged, but subsequent D losses are not split into separate attack cohorts.

Percentages are not accepted in the schedule. For example, disabling 20% of an
initially 1000-satellite shell population at time zero means `count=200`. At a
later time, a fixed count is not necessarily 20% of the then-current population.

For an attack-free control, use a separate copy of your scenario with no matching
events file, or with an events file containing only the header. Keep owner
allocation, launch rules, parameters and duration identical. Leave
`attack,enabled,1` to use the owner-aware extension for both runs.

## 7. Change model parameters

The parameter CSV contains numeric overrides:

```csv
parameter_type,parameter_name,parameter_value
attack,enabled,1
MOCAT,Dt,5
MOCAT,P,0
econ,satLifetime,5
econ,disposalTime,5
```

Category and field names are case-sensitive. Use one numeric value per row,
without units or percent signs. Remove an optional row to use the original
default; do not leave its value blank. Avoid duplicate rows for one parameter.
Unknown physical/economic field names can be ignored by the current adapter,
so check the loaded values rather than relying on a misspelled row to error.

| Setting | Meaning and editing guidance |
| --- | --- |
| `attack,enabled` | Use 1 for this runner, including owner-aware controls. Setting 0 disables extension setup; `runScenario` then rejects the run rather than launching original OPUS automatically. |
| `MOCAT,Dt` | Positive mean operating lifetime in years. Active retirement and replacement rates use this; retirement is continuous, not removal of every satellite exactly at this age. |
| `econ,satLifetime` | Economic lifetime; keep equal to `Dt`. |
| `MOCAT,P` | Keep 0 initially. In the population equations P is the fraction removed on retirement; 1-P becomes D with retirement relocation. Upstream comments label it inconsistently. It does not apply to disabling transfers. |
| `econ,disposalTime` | Years used to calculate the disposal shell for normal retirement. Start with 5. A value too short to define a valid shell is rejected during run setup. It does not force attack-disabled satellites to that shell. |
| `econ,discountRate` | Decimal annual fraction, e.g. 0.05 for 5%. |
| `econ,intercept` | Revenue intercept; template 750000. |
| `econ,coef` | Revenue slope magnitude; template 100. |
| `econ,tax` | Upstream risk-cost adjustment; template 0. |
| `econ,delta_v_cost` | Upstream delta-v cost coefficient; template 1000. |
| `econ,lift_price` | Lift cost per kg; template 5000. |

The economic entries are accepted as shared upstream settings and saved in the
scenario. `runScenario` builds upstream cost parameters and uses their disposal
shell, but owner launches follow the launch CSV. Changing a revenue coefficient,
tax or discount rate does not trigger profit optimization or automatically
change these launch rules. Some economic settings only affect stored parameters
or cost calculations in this runner. They are not per-owner economic choices.

To test a longer lifetime, for example, change both `MOCAT,Dt` and
`econ,satLifetime` from 5 to 7. This changes retirement and replacement behavior.
Changing the run duration is different: pass the desired years to `runScenario`
as shown below; duration is not a parameter-file row.

[field-reference.csv](field-reference.csv) provides units and suggested values
for every supplied input field. Suggested economic ranges are guidance; not all
are enforced by the adapter. Do not use this scalar CSV interface to change
shell geometry, initial population vectors, mass/area vectors, or derived
collision/drag matrices. Derived physical fields are not rebuilt automatically.
The adapter does not implement `constellation` rows or behavior keywords.

## 8. Save and validate your files

When editing in Excel, save each sheet as comma-delimited UTF-8 CSV. Use decimal
points (`0.5`), not decimal commas, and no thousands separators, formulas left
as text, unit suffixes or blank numeric fields. Some German Excel configurations
write semicolon-separated CSV despite the file extension: check the saved text
in VS Code against the examples. Keep exact column names and save all files
before running. Documentation and reference CSVs are not simulation inputs.

Validate the new study without running the simulation:

```powershell
matlab -batch "addpath('extensions/attack'); s=opusattack.prepareScenario('extensions/attack/scenarios/my-study/my-study.csv'); disp(s.attack.owners.ids); disp(s.attack.events); disp(s.attack.launch_rules); disp(s.VAR.Dt); disp(s.econ_params.satLifetime);"
```

This checks owners, initial totals, launch rules, event fields and disabling
property compatibility. It does not predict whether enough satellites will
remain at a future event, and it has no run horizon to check. Those checks occur
during `runScenario`. It also does not fully validate every arbitrary economic
override or guarantee a valid disposal shell.

## 9. Run from PowerShell or MATLAB

From the repository root, run five years and export:

```powershell
matlab -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/scenarios/my-study/my-study.csv',5); disp(r.output_directory); disp(r.fragmentations); disp(r.disablings);"
```

The horizon must be positive and include every scheduled event. Decimals such
as `1.5` are allowed. Larger horizons require more calculation and produce more
history data. More owners also increase detailed owner-pair accounting costs.

If `matlab` is not recognized, use your installation's executable. For the tested
installation, PowerShell's call operator handles the space in `Program Files`:

```powershell
& 'C:\Program Files\MATLAB\R2026b\bin\matlab.exe' -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/scenarios/my-study/my-study.csv',5); disp(r.output_directory);"
```

Adjust the installation path to your machine. In the MATLAB Command Window,
the equivalent is:

```matlab
addpath('extensions/attack');
r = opusattack.runScenario('extensions/attack/scenarios/my-study/my-study.csv',5);
disp(r.output_directory);
```

For a run kept only in MATLAB memory, pass an empty third argument:

```matlab
r = opusattack.runScenario('extensions/attack/scenarios/my-study/my-study.csv',5,'');
```

A nonempty third argument selects an explicit output directory. It must not
already exist: exports never overwrite a previous run. By default, the runner
creates a unique directory under `extensions/attack/results/`. Keep outputs
outside input/owner directories. Each run starts from the saved initial CSVs;
it does not resume the previous MAT file or rewrite input populations.

## 10. Read the results

Open the directory printed by the run you just executed. An older CSV already
open in VS Code does not switch to the new run automatically. `COMPLETE.txt`
marks a completed export. If a run errors, do not treat an incomplete output
directory as a completed result.

| File | What to inspect |
| --- | --- |
| `fragmentations.csv` | One row per fragmentation, immediate active/N changes and converted mass |
| `disablings.csv` | One row per disabling, requested/actual count, retained properties and active/D/N changes |
| `owner-populations.csv` | Every owner's S, Su and D history in every shell |
| `shell-populations.csv` | Combined S, Su, D, N and total population history per shell |
| `launch-decisions.csv` | Each owner's selected rates and current counts at decisions |
| `events.csv` | Scheduled attacks and major interval summaries such as launches and collision losses |
| `event-participants.csv` | Known owners and roles linked to event IDs |
| `flows.csv` | Integrated flow accounting, including retirement, drag and boundary exits |
| `population-balance.csv` | Initial/final counts and incoming/outgoing balances, including attack jumps |
| `diagnostics.csv` | Continuous population accounting residuals by integration segment |
| `metadata.json`, `source-manifest.csv` | Run settings and source/input dependency hashes |
| `inputs/` | Snapshots of the inputs actually used |
| `result.mat` | Full result structure, histories, counters, snapshots and parameters |

The filename is **`result.mat`**, singular. Open it in MATLAB with a path to
the desired run, for example while `r` is still available:

```matlab
saved = load(fullfile(r.output_directory,'result.mat'),'result');
result = saved.result;
result.fragmentations
result.disablings
result.final
result.max_global_balance_residual
result.attack_snapshots{1}
```

In a later MATLAB session, set a variable to the actual output directory and
use `load(fullfile(runFolder,'result.mat'),'result')`. A MAT file is binary;
opening it as text in VS Code will not show the result structure.

An instantaneous event has both `pre_event` and `post_event` history samples at
the same time. Two simultaneous events produce four samples. Use `sample_index`,
`phase`, and `event_id`; do not remove duplicates based only on time. Counts can
be fractional because this is a continuous population model.

Scheduled attacks have exact event times. Launch and collision records summarize
expected flows over intervals, not individually observed incidents; their
`event_time` can be NaN. Shared debris has no invented owner. Small numerical
population-balance residuals measure accounting consistency, not validation of
real-world breakup physics. Fragmentation transfer mass is conserved at the
jump; original downstream collision equations are not a global material balance.

## 11. Common problems

| Symptom | What to check |
| --- | --- |
| Scenario file not found | Run from the repository root; use the new example subfolder; check the filename. |
| Owner directory missing | Match `<scenario>-owners` to the parameter filename exactly. |
| Owner totals do not match | Recalculate generic counts for each shell and each of S, Su and D; look for spare CSV copies. |
| Unknown owner | Match the filename-derived ID in both events and launch rules. |
| Attack outside horizon | Increase the duration argument or move the event earlier. |
| Insufficient attack targets | Check the selected owner's remaining S or Su in that shell; account for earlier events and ordinary losses. |
| Invalid attack size | Fragmentation uses 1; disabling uses a positive integer; percentages and fractional counts are not accepted. |
| Incompatible disabling physics | The targeted active and D physical classes must match; use defaults until heterogeneous classes are implemented. |
| Invalid disposal shell | Return disposalTime to the supplied default and review any physical changes. |
| No launches after editing rules | Check `none`, caps, and target shortfall; unlisted combinations instead use replacement. |
| Economic edits do not change launch rates | Rates come from owner launch rules; independent economic optimization is not implemented. |
| No attack appears | Check that the events file has the matching scenario stem, contains rows, was saved, and that you opened the newest output folder. |
| Output directory already exists | Choose a new folder or omit the third argument for a unique automatic output. |

To run the extension regression suite after code or upstream changes:

```powershell
matlab -batch "r=runtests('extensions/attack/tests'); assertSuccess(r);"
```

Editing CSV values normally requires validating and running the chosen scenario,
not changing tests. Preserve saved input snapshots with each result when comparing
experiments. Original OPUS remains available through its original entry points.

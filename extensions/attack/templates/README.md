# CSV templates and accepted values

Start with the [complete editing and running guide](SIMULATION_GUIDE.md) for a
step-by-step workflow covering owners, attacks, parameters, PowerShell commands,
results and troubleshooting. This README is the shorter field reference.
The same guide is available as a [Word document](SIMULATION_GUIDE.docx).
Edit the Markdown source when updating the guide, then refresh the Word copy.

These templates are for the extension only. They do not change the original
OPUS files. All input cells are filled with concrete example values; no guessing
or replacement of placeholder words is needed to validate the supplied example.
Owner-aware propagation, annual launch policies, accounting and result export are
available (see the parent README), along with scheduled fragmentation and disabling
events in a common CSV. Time-varying launch schedules and the PowerShell
launcher are still future steps.

## Which file to edit

| File | Purpose |
| --- | --- |
| `owner-scenario.csv` | Opt-in and selected physical/economic parameters, filled with current defaults |
| `owner-scenario-launches.csv` | Owner-specific launch policies, with targets and rate limits |
| `<scenario>-economics.csv` | Optional owner ID and deployment-cost multiplier; create beside the scenario CSV |
| `single-satellite-events.csv` | Optional one-satellite fragmentation template; copy/rename to activate |
| `attack-schedule-events.csv` | Optional mixed fragmentation/disabling schedule specifying times, owners and shells; copy/rename to activate |
| `owner-scenario-owners/example-owner.csv` | Named constellation owner's initial counts in all 40 shells |
| `owner-scenario-owners/generic-owner.csv` | Explicit remainder of the initial satellite population |
| `field-reference.csv` | Spreadsheet-readable descriptions, types, units, and example values; not a simulation input |
| `shell-reference.csv` | Default shell numbers and their altitude boundaries; not a simulation input |

Keep reference files outside the owner directory. Currently the loader reads
**every CSV in the matching owner directory** as an owner. Do not put spare
templates or reference sheets there. Explicit owner selection by the future
launcher is not implemented yet.

## Owner columns

| Column | Enter | Example | Do not enter |
| --- | --- | --- | --- |
| `shell` | An integer from 1 to 40, once each | `10` | `550`, `10.5`, `shell 10` |
| `S` | A finite, nonnegative count of active slotted satellites | `1000` or `0` | A blank, `-1`, `1000 satellites` |
| `Su` | A finite, nonnegative count of active fringe satellites | `334` or `0` | A percentage or text |
| `D` | A finite, nonnegative count of derelict satellites still in the modeled region | `2` or `0` | Satellites already removed from the model |

These are counts, not launch rates, masses, or percentages. Whole numbers are
usually the clearest initial inputs. Fractional expected counts such as `12.5`
are accepted because the simulation is continuous. `NaN`, `Inf`, negative values,
missing values, duplicate shells, and missing shells are rejected. Column names
are case-sensitive. Do not add an owner-name or explanation column.

The filename supplies the owner ID: for example, `owner-a.csv` defines `owner-a`.
Use letters, digits, hyphens, or underscores; start with a letter or digit.
Owner IDs must be unique, ignoring case. The word `generic` has no special
automatic behavior: its file contains explicit counts like any other owner.

The default shells are 35 km thick from 200 to 1600 km. Shell 10 spans
515-550 km; consult `shell-reference.csv` for the others. These boundaries apply
to the current default grid, not to a future changed grid.

## A complete matching owner allocation

The allocation instructions below are the default mode. To add new constellations
of arbitrary sizes instead, use `attack,additional_constellations,1` alongside
`attack,enabled,1`. Owner CSVs then contain additional satellites; the original
population is created automatically as `generic`, and shared N is retained once.
Do not include a generic CSV in additional mode. Copy the complete
[additional-constellations example](../examples/additional-constellations/) as
the template for this mode; it contains Starlink and Kuiper owners but accepts
any number. Use its paired runner to generate a matching no-attack control.
See the guide's new section on additional constellations for details.

The supplied example uses the existing populations and adds no satellites:

| Shell 10 | S | Su | D |
| --- | ---: | ---: | ---: |
| `example-owner` | 1000 | 0 | 0 |
| `generic-owner` | 1529 | 334 | 2 |
| Required total from original inputs | 2529 | 334 | 2 |

The generic owner also holds all active satellites and derelicts in every other
shell. This is an illustrative ownership allocation, not historical ownership data.

For example, to give `example-owner` 1200 S in shell 10, reduce generic S there
from 1529 to 1329. To give it one existing derelict there, set its D to 1 and
generic D to 1. No attack occurs from editing these initial allocations.

For every shell and each of S, Su, and D separately:

`generic count = original initial count - sum of other owners' counts`

The remainder must be nonnegative. The loader validates the totals but does not
calculate or rewrite the generic file. N debris remains shared and has no owner
column. A new owner needs its own full 40-row file and a matching reduction in
the other owners' allocations.

## Scenario parameters

`owner-scenario.csv` has exactly the layout
`parameter_type,parameter_name,parameter_value`. Values are numbers only. The
opt-in row is `attack,enabled,1`; set its value to `0` to disable attack setup.
Optional parameter rows can be removed to keep the original defaults. Do not
leave their values blank: the numeric adapter does not interpret blanks as defaults.

`field-reference.csv` lists each supplied parameter's meaning, unit, and example.
Its ranges for economic parameters are input guidance, not additional implemented
validation. Owner counts and the attack switch are explicitly validated; the
current economic/physical parameter adapter does not enforce all those ranges.

Keep `MOCAT,Dt` and `econ,satLifetime` equal (both are 5 years in the template).
Use decimal fractions for rates: `0.05` means 5%, not `5` or `5%`.

Leave `MOCAT,P` at 0 initially. In the current population equations the fraction
`1-P` of retirements enters D, while P leaves the tracked populations. Its upstream
comment describes non-compliance, which does not consistently describe those
equations. Do not interpret P as a reliable compliance slider without further review.
The default disposal time is 5 years; arbitrary positive values are not guaranteed
to produce a valid `k_star` in the original cost function.

The template intentionally omits shell geometry, vector-valued physical properties,
and `constellation` rows. Owner launch policies use the separate launches CSV;
the parameter adapter does not process `constellation` rows. Changing physical inputs that
require rebuilding derived matrices is also not supported by this template.
The included economic values are shared upstream defaults. The optional
`economic` launch mode uses them for owner-specific decisions. A separate
`<scenario>-economics.csv` may specify `owner_id,cost_multiplier`; omitted
owners retain multiplier 1. Cost multipliers are scenario assumptions.

## Launch policy values

`owner-scenario-launches.csv` contains one rule per owner/shell/population.
Use an existing filename-derived owner ID, a shell integer 1-40, and population
`S` or `Su` (never D or N). `target_size` and `max_launch_rate` must be finite,
nonnegative numbers; target size is satellites, rate is satellites/year.

| mode | Meaning | target_size | max_launch_rate example |
| --- | --- | --- | --- |
| `target` | Build toward a target from this owner's current active count | `3000` | `1500` |
| `replacement` | Current count divided by lifetime, capped by the rate | `0` | `500` |
| `fixed` | Prescribed rate regardless of current count | `0` | `100` |
| `none` | No launches | `0` | `0` |
| `economic` | Bounded owner response to projected return in the shared market | `0` | `500` (scenario assumption) |

Unlisted owner/shell/population combinations use uncapped replacement. This
also applies if no launches file exists. The example assigns a target of 3000
slotted satellites to example-owner in shell 10, and 300 to generic-owner in
shell 29. These are independent rules even when owners share a shell. Rules
are recalculated annually from current counts; no behavior profiles are used.

## Attack event values: fragmentation and disabling

For attacks, copy `attack-schedule-events.csv` (or `single-satellite-events.csv`
for a one-row example) to `<scenario>-events.csv`
beside the scenario parameter file (for example `owner-scenario-events.csv`).
It is deliberately not loaded automatically under its template filename.

| Event column | Allowed value | Example |
| --- | --- | --- |
| `event_id` | Unique ID ignoring case; letters/digits/hyphens/underscores; first character alphanumeric | `fragment-001` |
| `time_year` | Finite nonnegative simulation time, at or before the run's end | `0.5` |
| `event_type` | `fragmentation` or `disabling` | `disabling` |
| `owner_id` | An existing owner ID | `example-owner` |
| `shell` | Integer 1-40 on the default grid | `10` |
| `population` | `S` or `Su` | `S` |
| `count` | Exactly `1` for fragmentation; a positive integer for disabling | `100` for disabling |

Add one row per attack. Rows are sorted by time; rows with the same time execute
in CSV order. Times are elapsed simulation years, not calendar years. Shells
are altitude bands; see `shell-reference.csv` for their default boundaries.
Fragmentation destroys one satellite and generates standard N debris. Disabling
moves the requested number from the owner's S or Su to the same owner's D in
the same shell, without adding N or applying retirement disposal. The derelicts
then follow passive drag and collision dynamics. There must still be enough
satellites of the targeted owner/population in that shell when the event executes.
All attacks at an annual decision time happen before that decision. Midyear
attacks keep the already selected launch rates until the next annual decision.
Use `runScenario` for configured events; `propagateScenario` rejects them.
For disabling, active and D mass, area, diameter and ballistic coefficient must
match (as they do in the defaults). Supply counts, not percentages. Both types
can be mixed and share one unique event ID namespace. The complete runnable
example is `../examples/mixed-attacks/mixed-attacks.csv`.

## Saving CSV files from Excel

- Keep the exact header row and save as a comma-delimited UTF-8 CSV.
- Use a decimal point, such as `12.5`, without thousands separators or unit text.
- Some regional Excel settings produce semicolon-delimited CSVs and decimal
  commas. This template format uses commas between columns and decimal points.
- Put numbers, not descriptive labels, into input cells. Keep explanations in
  the separate reference files. Save before validating or running.

## Make your own scenario without editing base files

1. Copy `owner-scenario.csv`, `owner-scenario-launches.csv`, and its `owner-scenario-owners` directory into
   `extensions/attack/scenarios/` (create that directory if needed).
2. Rename them together: `my-scenario.csv`, `my-scenario-launches.csv`, and `my-scenario-owners/`.
3. Rename and edit owner files inside that directory. Keep the totals consistent.
4. Validate the saved files from the repository root in MATLAB:

```matlab
addpath('extensions/attack');
scenario = opusattack.prepareScenario('extensions/attack/scenarios/my-scenario.csv');
```

To validate the supplied template directly, use
`extensions/attack/templates/owner-scenario.csv` instead. Successful validation
returns `scenario.attack.owners.S`, `.Su`, and `.D` with the owner IDs in `.ids`.
The future PowerShell launcher will select scenarios outside the original OPUS
configuration. It has not been added in this template/documentation step.

To run five years and export, use `opusattack.runScenario` with the scenario path
and `5` as arguments (see the parent README). No base files need editing.

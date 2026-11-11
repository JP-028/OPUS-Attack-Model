# Runnable example scenarios

Each folder is a complete scenario: parameter CSV, owner directory, launch rules,
and an event CSV where applicable. Copy the entire folder to customize a scenario.
Keep its file stems matched. Examples contain inputs; generated runs go to
`../results/`.

| Folder | Parameter file inside the folder | Fragmentation events | Disabling events | Purpose |
| --- | --- | ---: | ---: | --- |
| [baseline](baseline/) | `attack-example.csv` | 0 | 0 | Owner-aware control without attacks |
| [fragmentation](fragmentation/) | `fragmentation.csv` | 1 | 0 | One satellite destroyed at year 0.5 |
| [multiple-attacks](multiple-attacks/) | `multiple-attacks.csv` | 4 | 0 | Repeated and simultaneous fragmentation events |
| [mixed-attacks](mixed-attacks/) | `mixed-attacks.csv` | 2 | 3 | Fragmentation and disabling in one schedule |
| [six-events](six-events/) | `six-events.csv` | 3 | 3 | The requested three-fragmentation/three-disabling test |
| [additional-constellations](additional-constellations/) | `additional-constellations.csv` | 2 | 2 | Starlink and Kuiper design profiles plus automatic generic background; matched owner controls |

The first five examples use `attacked` and `generic` as owner IDs and the same initial
allocation and launch rules. Each fragmentation destroys one satellite. Both
mixed examples disable 121 satellites in total (100, 20 and 1).
All schedules fit within a one-year run; an event at year 1 is included in the
final state. Use a longer horizon to observe its later effects.

From the repository root in PowerShell:

```powershell
matlab -batch "addpath('extensions/attack'); r=opusattack.runScenario('extensions/attack/examples/six-events/six-events.csv',1); disp(r.output_directory);"
```

For another example, substitute its folder and parameter filename. The final
number is the simulation duration in years. Each run writes a new result folder.
For the Starlink/Kuiper example, use `opusattack.runPairedScenarios` to write
both the attacked run and its matching no-attack control together. See that
folder's README for the command and comparison files.

Read the [editing and running guide](../templates/SIMULATION_GUIDE.md) for owner
changes, scheduling, parameter choices, validation, results and troubleshooting.

The examples previously lived directly in this directory. Their CSV contents
are preserved, but commands using the old flat paths must include the new folder.
Existing result directories and their saved input snapshots remain unchanged.

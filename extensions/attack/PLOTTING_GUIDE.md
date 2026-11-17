# Plotting paired attack results

The plotting functions read completed **paired** experiments. They use the
attacked run and its otherwise identical no-attack control. They do not rerun
the model or edit the source result files. Each difference means *attacked
minus control*.

## Generate a figure set

From the repository root in PowerShell, using a paired result folder that
contains `attacked/`, `control/`, `owner-impact.csv` and `COMPLETE.txt`:

```powershell
matlab -batch "addpath('extensions/attack'); p=opusattack.plotPairedResults('extensions/attack/results/YOUR_PAIRED_FOLDER'); disp(p.output_directory);"
```

The default destination is a new `figures/` directory inside that paired
folder. If it exists, the function stops rather than overwriting it. Pass a
second argument to choose another **new** directory:

```matlab
p = opusattack.plotPairedResults(pairFolder, fullfile(pairFolder,'figures-revised'));
```

For a new experiment, run the pair first, then use its returned path:

```matlab
addpath('extensions/attack');
pair = opusattack.runPairedScenarios(parameterFile, 2);
figures = opusattack.plotPairedResults(pair.output_directory);
```

A pair with several targeted owners gets one active-fleet, economic-trajectory
and economic-components figure per targeted owner, plus one shared debris
figure. A pair without an applied attack has no attack figures to plot.

## Figures

| Filename prefix | What it shows |
| --- | --- |
| `01-active-fleet-<owner>` | Active S+Su count for the owner in both runs; lower panel shows the difference. |
| `02-debris-by-altitude` | Difference in shared N over time and altitude. Its view focuses on changed and targeted shells with two shells of context. The model still treats each shell as uniformly distributed. |
| `03-economic-trajectory-<owner>` | Cumulative difference in the discounted cash-flow proxy, separately for the targeted owner and all other owners combined. |
| `04-economic-components-<owner>` | Change in modeled revenue, the contribution from changed launch spending, and their net cash-flow difference. |

The event lines have no in-plot labels so they cannot cover the data. Dotted
means fragmentation, dashed means disabling, and dash-dot means both at the
same time. Their times, types and owner IDs are in `FIGURE_CAPTIONS.md`.
The heatmap colours are interpolated for display between output samples;
the underlying model uses discrete altitude shells. The figures contain no
individual debris positions or collision maneuvers.

The economic proxy is modeled revenue less launch spending. It omits other
company costs, so it should not be described as profit or total economic
damage. A lower launch bill can make the net proxy less negative even when
revenue falls. See `owner-economics.csv` and `owner-impact.csv` for the
numbers behind the economic figures.

## Compare owners across experiments

Give `plotOwnerComparison` one or more completed paired folders in the order
you want them displayed:

```matlab
pairs = [
    "extensions/attack/results/STARLINK_PAIRED_FOLDER"
    "extensions/attack/results/KUIPER_PAIRED_FOLDER"
];
comparison = opusattack.plotOwnerComparison(pairs);
disp(comparison.output_directory);
```

This generates `05-owner-comparison-01.pdf` and `.png` (additional numbered
pages when needed), `owner-comparison-data.csv`, a caption file and a
completion marker. Each panel shows one paired experiment. Orange means an
owner targeted in that experiment, blue means another named owner, and grey
means the generic owner. All panels share one horizontal scale. Panels contain
at most ten owner rows; extra owners receive another panel. Full owner IDs and
values remain in the CSV even if a displayed label is shortened.

## File formats and layout

Every figure is a vector PDF for a paper and a 250 dpi PNG for quick review.
`figure-manifest.csv` lists the per-pair figures. Open either format from the
result folder or VS Code Explorer. Inspect the final page at the size you will
use in the thesis, especially after adding many owners or long owner names.

The colours are inspired by public UniBw M orange, blue and grey materials.
They are **not official corporate design colour values**. Exact values can be
substituted in `+opusattack/private/plotAppearance.m` if the university
supplies its corporate design guide.

Generated figures live under the ignored `extensions/attack/results/` tree
and stay local. The plotting source and this guide belong in Git.

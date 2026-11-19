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

A pair with several targeted owners gets owner-specific active-fleet,
economic-trajectory, economic-components, economic-development, shell-impact
and replacement-reference figures, plus one shared debris figure.
A pair without an applied attack has no attack figures to plot.

## Figures

| Filename prefix | What it shows |
| --- | --- |
| `01-active-fleet-<owner>` | Active S+Su count for the owner in both runs; lower panel shows the difference. |
| `02-debris-by-altitude` | Difference in shared N over time and altitude. Its view focuses on changed and targeted shells with two shells of context. The model still treats each shell as uniformly distributed. |
| `03-economic-trajectory-<owner>` | Cumulative difference in the discounted cash-flow proxy, separately for the targeted owner and all other owners combined. |
| `04-economic-components-<owner>` | Change in modeled revenue, the contribution from changed launch spending, and their net cash-flow difference. |
| `06-economic-development-<owner>` | Annualized modeled revenue and cash-flow proxy for attacked and control runs, plus their differences. Each step covers one model interval. |
| `08-economic-by-shell-<owner>` | Discounted revenue, spending and net cash-flow differences in material and attacked shells. The companion CSV retains all shells. |
| `09-replacement-reference-<owner>` | Nominal replacement-value reference beside the owner's discounted cash-flow difference. They are separate measures. |

The event lines have no in-plot labels so they cannot cover the data. Dotted
means fragmentation, dashed means disabling, and dash-dot means both at the
same time. Their times, types and owner IDs are in `FIGURE_CAPTIONS.md`.
The heatmap colours are interpolated for display between output samples;
the underlying model uses discrete altitude shells. The figures contain no
individual debris positions or collision maneuvers.

Economic development is shown as an average annualized rate for each recorded
interval, since event checkpoints can create unequal interval lengths. It is
not a measured company growth rate. The economic proxy is modeled revenue
less launch spending. It omits other company costs, so it should not be
described as profit or total economic damage. A lower launch bill can make
the net proxy less negative even when revenue falls. See
`owner-economics.csv` and `owner-impact.csv` for the underlying values.

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

This generates `05-owner-comparison-01.pdf` and `.png` for absolute effects,
and `07-owner-comparison-normalized-01.pdf` and `.png` for the size-adjusted
effect. Extra numbered pages appear when needed. The output also includes
`owner-comparison-data.csv`, a caption file and a completion marker.

Each panel shows one paired experiment. Orange means a targeted owner, blue
another named owner, and grey the generic owner. Each comparison uses one
horizontal scale across its panels. At most ten owners appear per panel.

The size-adjusted unit is USD million of discounted cash-flow difference per
1,000 initially active satellites. An owner with zero initial active
satellites appears as n/a. Compare runs with the same horizon and attack
schedule when interpreting this value. Full owner IDs and numbers remain
in the CSV if a displayed label is shortened.

## Compare fragmentation with disabling

Use two completed paired experiments that differ only in whether **one**
satellite is fragmented or disabled. Their event rows must have the same
`time_year`, `owner_id`, `shell`, `population` and `count=1`. Keep the
scenario parameters, initial owner counts, launch rules and run horizon the
same. The function verifies that the no-attack control trajectories and
economic records match, and rejects a mismatched pair.

```matlab
comparison = opusattack.plotAttackTypeComparison(fragmentationPairFolder, ...
    disablingPairFolder);
disp(comparison.output_directory);
```

The output contains `10-fragmentation-vs-disabling-01.pdf` and `.png`,
`attack-type-comparison.csv`, a caption and a completion marker. The
figure shows each owner's discounted cash-flow proxy difference against
its own no-attack control. Orange circles represent fragmentation and blue
squares disabling. Additional pages appear after ten owners. This comparison
does not include replacement-value references as realized spending.

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

# Two deployed-operator design profiles

This example adds Starlink Gen 1 and Kuiper Gen 1 / Amazon Leo to the original
OPUS background, assigned to `generic`. It uses their published **fully
deployed design** counts, although the real operators have deployed different
numbers of satellites. These are controlled size-and-altitude scenarios, not
company-specific financial or spacecraft models.

| Owner | Initial active S | OPUS shells |
| --- | ---: | --- |
| Starlink Gen 1 | 4,408 | 1,584 in shell 10 (540 km); 2,824 in shell 11 (550-570 km) |
| Kuiper Gen 1 / Amazon Leo | 3,232 | 2,076 in shell 12 (590-610 km); 1,156 in shell 13 (630 km) |

See [SOURCES.md](SOURCES.md) for primary sources and exact mapping choices.
Both owner files contain only S. The original S, Su and D belong to `generic`,
and original N remains a shared shell count. A file may assign an owner to
multiple shells; no number of owners is hardcoded.

The header-only launch CSV applies the **same current-count/lifetime replacement
rule** to every owner, including `generic`. There is no owner cost-multiplier
file. Economic revenue, spending and loss estimates are still exported for
every owner; those estimates do not alter launches in this example. OPUS's
shared 223 kg satellite and other physical properties apply to all owners.

The event CSV schedules the **same two attacks for each owner**: one satellite
fragmented at year 0.25 and one disabled at year 0.5, in Starlink's shell 10
or Kuiper's shell 12. To compare each owner separately against its exact
no-attack control, from the repository root:

```powershell
matlab -batch "addpath('extensions/attack'); f='extensions/attack/examples/additional-constellations/additional-constellations.csv'; a=opusattack.runPairedScenarios(f,2,[],'starlink-gen1'); b=opusattack.runPairedScenarios(f,2,[],'kuiper-gen1'); disp(a.output_directory); disp(b.output_directory);"
```

Each paired folder contains `attacked/`, `control/`, `owner-impact.csv`,
`owner-shell-impact.csv` and `debris-impact.csv`. The control uses the same
initial state, owner policies and event-time integration checkpoints, but
applies no attack transfers. Differences are attacked minus control. The
optional fourth argument chooses one attacked owner's event rows. Omitting
it runs the combined four-event schedule against one control. To isolate only
fragmentation or only disabling, copy this folder and keep only the selected
event type in the copied `-events.csv`, then run the copy as a pair.
The two-year horizon includes the next annual decision after the attacks;
a one-year run ends before any post-attack launch-rate update.

The example is a reference design comparison. It does not claim that either
operator has fully deployed its cited design, or that the economic output is
actual company profit. The generic background may overlap the named fleets.

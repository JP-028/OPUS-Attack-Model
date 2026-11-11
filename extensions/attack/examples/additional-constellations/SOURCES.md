# Primary sources and mapping decisions

These profiles use **fully deployed designs**, not the number currently in
orbit. Only published design counts and altitudes determine the named owners'
initial populations. Both owners use the same original OPUS representative
satellite properties, economic parameters and current-count/lifetime launch rule.

1. **Starlink Gen 1:** U.S. Federal Communications Commission, *FCC 21-48*
   (2021), paragraph 4, printed pp. 3-4: 1,584 at 550 km, another 1,584 at
   540 km, 720 at 570 km, 348 at 560 km and 172 more at 560 km. The sum is
   4,408. Shell 10 receives 1,584 at 540 km. Shell 11 receives the remaining
   2,824. The 550 km band lies on the shell boundary; this profile assigns it
   to shell 11 by the lower-bound-inclusive convention.
   [FCC order](https://docs.fcc.gov/public/attachments/fcc-21-48a1.pdf).

2. **Kuiper Gen 1 / Amazon Leo:** U.S. Federal Communications Commission,
   *DA 24-224* (2024), paragraph 4, FCC Rcd p. 2181: 782 satellites at 590 km
   and 2 more at 590 km, 1,292 at 610 km, and 1,156 at 630 km. The modified
   authorized total is 3,232. OPUS shell 12 receives 784 + 1,292 = 2,076;
   shell 13 receives 1,156.
   [FCC modification grant](https://docs.fcc.gov/public/attachments/DA-24-224A1_Rcd.pdf).
   Amazon now calls the system Amazon Leo; its
   [2026 deployment update](https://www.aboutamazon.com/news/innovation-at-amazon/project-kuiper-satellite-rocket-launch-progress-updates)
   describes real deployment, but the 3,232 count above is the **full design**,
   not the number already deployed.

Shell boundaries are in [shell-reference.csv](../../templates/shell-reference.csv)
and use the original OPUS 35 km altitude bins. S denotes active operational
satellites; each named owner starts with Su=0 and D=0. The published sources
do not set a company-specific OPUS mass, cross-section, revenue, cost or launch
policy. Inclinations and orbital planes cannot be represented by the shell model.

The original TLE background, assigned to `generic`, may already contain some
satellites from these operators. This additive example compares size and
altitude under a common background; it is not a deduplicated historical census.

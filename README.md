# Playing Tougher for Their Size

This repository contains CSAx_P, an extension of the original CSAx study toward the MIT Sloan Sports Analytics Conference Research Paper Competition. We study playing tough or soft for one's size through shared direct physicality measures and position-specific indirect behaviors. The analysis predicts listed height-and-weight size, calibrates that prediction against the player's frame, and standardizes calibrated size above expected (CSAx) within each season and reference population. NHL events and All Three Zones (A3Z) microstats use matched games and five-on-five exposure. The main models cover forwards, including centers, and defensemen. The [research summary](reports/paper_mitssacrpc/research_summary.md), [abstract draft](reports/paper_mitssacrpc/abstract.md), and [provisional paper roadmap](reports/paper_mitssacrpc/research_roadmap.md) present the findings and research direction.

## Reproduce

The workflow is tested with R 4.6.1. R package versions are pinned in `renv.lock`, and `.Rprofile` activates the project library.

For a fast report rebuild from the supplied analysis object:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/04_write_summary.R
```

For a model rebuild from the supplied input snapshot, run the ordered pipeline from the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
Rscript scripts/04_write_summary.R
```

The workflow fits one physicality specification for forwards and defensemen, using five outer folds, five inner folds, and the fixed 20-penalty grid. Fitting uses up to 12 local workers. Additive direct, indirect, and frame contributions come from those same fits. Continuation intervals use player-clustered uncertainty conditional on the estimated scores and sample. Historical A3Z comparisons and the full-season benchmark, including its stored bootstrap results, remain in the analysis object. The default workflow runs no alternative specifications or bootstrap campaign.

For fresh A3Z inputs, download the workbook from the public [transition statistics view](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1) using **Download → Tableau Workbook**, and save it as `data/cache/a3z_transition.twbx`. Converting the extract requires Python, tested with 3.12, and the pinned Tableau Hyper reader:

```sh
python3 -m venv tmp/a3z_reader
tmp/a3z_reader/bin/python -m pip install tableauhyperapi==0.0.26479
tmp/a3z_reader/bin/python scripts/read_a3z.py data/cache/a3z_transition.twbx data/cache/a3z_raw.csv
Rscript scripts/01_prepare_data.R --refresh-events
```

Then run the model, analysis, and reporting commands above. The preparation command retrieves NHL schedules, rosters, events, and shifts for matching, while preserving the supplied full-season eligibility and outcome snapshots. Raw files and download timestamps provide source hashes and provenance. Upstream records can change; reproducing the reported results uses the bundled input snapshot and requires no Python reader.

Historical full-season routines require the explicit `--benchmark` flag. The previously used `--a3z` flag remains compatible with the default positional workflow.

The scouting expansion contains 43 blinded passages: 20 forwards and 23 defensemen. One human rater completes the two fields in the local `validation_private/scouting_expansion_packet.csv`, following the [codebook](validation/external_validation_codebook.md). Identity keys and scores stay separate from the packet. After completed ratings are saved, lock them and update the analysis without refitting CSAx:

```sh
Rscript scripts/01_prepare_data.R --lock-scouting
Rscript scripts/03_analyze.R
Rscript scripts/04_write_summary.R
```

The lock command requires complete 0/1 codes and unchanged passages. It preserves the 40 original ratings and writes public codes without scouting prose. Expanded ratings are required to complete the abstract; reporting identifies the draft as awaiting ratings until they are locked.

## Files

- `reports/paper_mitssacrpc/`: research summary, abstract draft, provisional roadmap, A3Z data dictionary, figures, player rankings, team coverage, and application estimates
- `data/analysis_data.rds`: compact analysis object with frozen inputs and current results under `a3z`, historical A3Z results under `a3zBenchmark`, completed center comparisons under `a3zCenterBenchmark`, and the full-season benchmark with its 499 bootstrap summaries
- `validation/`: public scouting codebook, source catalog, immutable forward codes, and expanded-cohort provenance
- `scripts/01_prepare_data.R` through `scripts/04_write_summary.R`: ordered data, metric, analysis, and reporting workflow
- `scripts/read_a3z.py`: reader for a freshly downloaded public A3Z workbook
- `R/`: shared research functions, fixed analysis settings, event aggregation, positional models, and application helpers

## Public data

A3Z microstats come from Corey Sznajder's freely downloadable transition workbook, available through the [official A3Z links page](https://www.allthreezones.com/links.html). Definitions follow the [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html) and [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve). The analysis retains source labels, NHL game and player mappings, exclusions, event counts, opportunity denominators, tracked exposure, retrieval dates, and source hashes.

The [A3Z data dictionary](reports/paper_mitssacrpc/a3z_data_dictionary.md) inventories all 95 fields in the downloaded workbook, with meanings, units, seasonal coverage, current model use, and unresolved definitions. It also outlines opportunities for further feature development.

NHL game, roster, event, shift, and career records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. Benchmark contract records originate from [Spotrac NHL Contracts](https://www.spotrac.com/nhl/contracts/), expected goals use the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG), and the external validation uses official NHL Central Scouting reports identified in `validation/external_validation_source_catalog.csv`. Raw download caches and private scouting prose are excluded from the repository; all 40 frozen scouting ratings remain separate from derived CSAx summaries. The current validation uses physical-engagement and interior-play codes. The repository remains private pending a public-release decision; source attribution and redistribution terms require review before release.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

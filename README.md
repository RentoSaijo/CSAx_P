# Playing Tougher for One’s Size

This repository contains CSAx_P, an extension of the original CSAx study toward the MIT Sloan Sports Analytics Conference Research Paper Competition. We study playing tougher or softer for one’s size through shared direct physicality measures and position-specific indirect behaviors. The analysis predicts listed height-and-weight size, calibrates that prediction against the player's frame, and standardizes calibrated size above expected (CSAx) within each season and reference population. NHL events and All Three Zones (A3Z) microstats use matched games and five-on-five exposure. The main models cover forwards, including centers, and defensemen. The [research summary](reports/paper_mitssacrpc/research_summary.md), [abstract PDF](reports/abstract_mitssacrpc/abstract_mitssacrpc.pdf), and [paper roadmap](reports/paper_mitssacrpc/paper_roadmap.md) follow construction, independent scouting, special-teams deployment, postseason engagement, and roster continuation.

## Reproduce

The workflow is tested with R 4.6.1. R package versions are pinned in `renv.lock`, and `.Rprofile` activates the project library. Abstract rendering uses Quarto, tested with 1.9.38, and a LaTeX installation with PDFLaTeX and Latin Modern fonts. The reporting command finds Quarto on `PATH` or in the standard macOS RStudio installation.

For a fast report rebuild from the supplied analysis object:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/04_write_summary.R
```

The [Quarto abstract](reports/abstract_mitssacrpc/abstract_mitssacrpc.qmd) supplies the narrative, authors, and presentation. The reporting command renders its PDF and derives Markdown and plain-text companions with textual equivalents of the figure and table. Values come from the stored analysis; rendering fits no models. To render only the PDF with Quarto on `PATH`:

```sh
quarto render reports/abstract_mitssacrpc/abstract_mitssacrpc.qmd --to pdf
```

For a model rebuild from the supplied input snapshot, run the ordered pipeline from the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
Rscript scripts/04_write_summary.R
```

The workflow fits one physicality specification for forwards and defensemen, using five outer folds, five inner folds, and the fixed 20-penalty grid. Fitting uses up to 12 local workers. Additive direct, indirect, and frame contributions come from those same fits. Scouting, deployment, postseason, and continuation intervals use robust uncertainty conditional on the estimated scores and sample, clustering repeated observations by player. The matched role-timing comparison uses identical observations for current- and previous-season role. Postseason contact models use the pinned `poissonreg` extension, player-season effects, and ice-time offsets. Historical A3Z comparisons, team applications, and the full-season benchmark, including its stored bootstrap results, remain in the analysis object. The default workflow runs no alternative specifications, team-association estimation, or bootstrap campaign.

For fresh A3Z inputs, download the workbook from the public [transition statistics view](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1) using **Download → Tableau Workbook**, and save it as `data/cache/a3z_transition.twbx`. Converting the extract requires Python, tested with 3.12, and the pinned Tableau Hyper reader:

```sh
python3 -m venv tmp/a3z_reader
tmp/a3z_reader/bin/python -m pip install tableauhyperapi==0.0.26479
tmp/a3z_reader/bin/python scripts/read_a3z.py data/cache/a3z_transition.twbx data/cache/a3z_raw.csv
Rscript scripts/01_prepare_data.R --refresh-events
```

Then run the model, analysis, and reporting commands above. The preparation command retrieves NHL schedules, rosters, events, and shifts for matching, while preserving the supplied full-season eligibility and continuation snapshots. It also prepares official PP/PK ice time and complete regular-season and playoff records for the outcome applications. Existing bundled application inputs support rebuilding without new downloads. Raw files and download timestamps provide source hashes and provenance. Upstream records can change; reproducing the reported results uses the bundled input snapshot and requires no Python reader.

Postseason outcomes use regular-season games excluded from CSAx construction and each team’s first four playoff games. Traded players use baseline games with their playoff team. A single full-postseason check repeats hits delivered. Tracking coverage and paired exposure remain explicit in the research summary and exported player-period observations.

Historical full-season routines require the explicit `--benchmark` flag. The previously used `--a3z` flag remains compatible with the default positional workflow.

The completed scouting expansion contains 43 blinded passages: 20 forwards and 23 defensemen. One human rater codes `activePhysicalEngagement` following the [codebook](validation/external_validation_codebook.md). The original 40 annotations remain frozen; 39 original players and all 43 expansion players have eligible scores, yielding 59 forwards and 23 defensemen. Scouting analysis uses active engagement only. To recompute associations and reporting from the supplied scores:

```sh
Rscript scripts/03_analyze.R
Rscript scripts/04_write_summary.R
```

The Numbers source and its completed CSV are preserved privately, including passage text, row order, and annotation notes. Source, packet, and code hashes document the lock before linkage to identities and scores. The public expansion file supplies completed codes and source references without scouting prose; private files are not required to reproduce the estimates. The one-time `--lock-scouting` preparation option rejects incomplete codes, altered passages, and already locked ratings.

## Files

- `reports/abstract_mitssacrpc/`: authoritative Quarto abstract, PDF with one scouting figure and one application table, and matching Markdown and plain-text versions
- `reports/paper_mitssacrpc/`: research summary, paper roadmap, A3Z data dictionary, three figures, player rankings, player-period engagement, and application estimates
- `data/analysis_data.rds`: compact analysis object with frozen score and application inputs and current results under `a3z`, historical A3Z results under `a3zBenchmark`, completed center comparisons under `a3zCenterBenchmark`, team results and provenance under `a3zTeamBenchmark`, and the full-season benchmark with its 499 bootstrap summaries
- `validation/`: public scouting codebook, source catalog, immutable forward codes, completed expansion codes, and lock provenance
- `scripts/01_prepare_data.R` through `scripts/04_write_summary.R`: ordered data, metric, analysis, and reporting workflow
- `scripts/read_a3z.py`: reader for a freshly downloaded public A3Z workbook
- `R/`: shared research functions, fixed analysis settings, event aggregation, positional models, and application helpers

## Public data

A3Z microstats come from Corey Sznajder's freely downloadable transition workbook, available through the [official A3Z links page](https://www.allthreezones.com/links.html). Definitions follow the [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html) and [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve). The analysis retains source labels, NHL game and player mappings, exclusions, event counts, opportunity denominators, tracked exposure, retrieval dates, and source hashes.

The [A3Z data dictionary](reports/paper_mitssacrpc/a3z_data_dictionary.md) inventories all 95 fields in the downloaded workbook, with meanings, units, seasonal coverage, current model use, and unresolved definitions. It also outlines opportunities for further feature development.

NHL game, roster, event, shift, and career records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. Historical contract records originate from [Spotrac NHL Contracts](https://www.spotrac.com/nhl/contracts/), historical expected-goals applications use the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG), and the external validation uses official NHL Central Scouting reports identified in `validation/external_validation_source_catalog.csv`. Raw download caches and private scouting prose are excluded from the repository; frozen scouting ratings remain separate from derived CSAx summaries. The repository remains private pending a public-release decision; source attribution and redistribution terms require review before release.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

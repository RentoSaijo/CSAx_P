# Playing Big for Their Size

This repository contains CSAx_P, an extension of the original CSAx study toward the MIT Sloan Sports Analytics Conference Research Paper Competition. The analysis predicts listed height-and-weight size from shared direct physicality measures and position-specific indirect behaviors, calibrates the prediction for the player's listed frame, and studies calibrated size above expected (CSAx) among NHL forwards and defensemen. The pilot integrates All Three Zones (A3Z) puck-play measures and compares them with play-by-play models using the same players, tracked games, and five-on-five exposure. It examines next-season continuation, frozen scouting ratings, and center standing under wing and defenseman models that exclude centers from training. The research findings and roadmap are available at [`reports/paper_mitssacrpc/research_summary.md`](reports/paper_mitssacrpc/research_summary.md).

## Reproduce

The workflow is tested with R 4.6.1. R package versions are pinned in `renv.lock`, and `.Rprofile` activates the project library.

For a fast report rebuild from the supplied analysis object:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/04_write_summary.R
```

For a full pilot rebuild from the supplied input snapshot, run the ordered pipeline from the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/01_prepare_data.R --a3z
Rscript scripts/02_build_csax.R --a3z
Rscript scripts/03_analyze.R --a3z
Rscript scripts/04_write_summary.R
```

The pilot rebuild reruns seasonal ridge models with five outer folds, five inner folds, and the fixed 20-penalty grid, followed by matched play-by-play and component comparisons. Model fitting uses up to 12 local workers. Supporting outcome intervals are conditional on the estimated scores and use player-clustered uncertainty. The full-season benchmark and its 499 stored full-pipeline bootstrap summaries remain in the analysis object; the pilot does not launch another bootstrap campaign.

For fresh A3Z inputs, download the workbook from the public [transition statistics view](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1) using **Download → Tableau Workbook**, and save it as `data/cache/a3z_transition.twbx`. Converting the extract requires Python, tested with 3.12, and the pinned Tableau Hyper reader:

```sh
python3 -m venv tmp/a3z_reader
tmp/a3z_reader/bin/python -m pip install tableauhyperapi==0.0.26479
tmp/a3z_reader/bin/python scripts/read_a3z.py data/cache/a3z_transition.twbx data/cache/a3z_raw.csv
Rscript scripts/01_prepare_data.R --a3z --refresh-events
```

Then run the pilot model, analysis, and reporting commands above. The preparation command retrieves NHL schedules, rosters, events, and shifts for matching, while preserving the supplied full-season eligibility and outcome snapshots. Raw files and download timestamps provide source hashes and provenance. Upstream records can change; reproducing the reported results uses the bundled input snapshot and requires no Python reader.

Running the numbered commands without `--a3z` rebuilds the full-season benchmark, including its original 499-replicate campaign. That workflow is substantially slower; completed bootstrap batches are cached under `data/cache/` and resume when its analysis command is rerun.

## Files

- `reports/paper_mitssacrpc/`: research summary, three figures, matched player rankings, center comparisons, team coverage, and labeled application estimates
- `data/analysis_data.rds`: compact analysis object with frozen A3Z inputs and pilot results under `a3z`, plus the full-season benchmark and its 499 bootstrap summaries
- `validation/`: public scouting codebook, source catalog, and frozen forward scouting codes
- `scripts/01_prepare_data.R` through `scripts/04_write_summary.R`: ordered data, metric, analysis, and reporting workflow
- `scripts/read_a3z.py`: reader for a freshly downloaded public A3Z workbook
- `R/`: shared research functions, fixed analysis settings, event aggregation, positional models, and application helpers

## Public data

A3Z microstats come from Corey Sznajder's freely downloadable transition workbook, available through the [official A3Z links page](https://www.allthreezones.com/links.html). Definitions follow the [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html) and [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve). The analysis retains source labels, NHL game and player mappings, exclusions, event counts, opportunity denominators, tracked exposure, retrieval dates, and source hashes.

NHL game, roster, event, shift, and career records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. Benchmark contract records originate from [Spotrac NHL Contracts](https://www.spotrac.com/nhl/contracts/), expected goals use the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG), and the external validation uses official NHL Central Scouting reports identified in `validation/external_validation_source_catalog.csv`. Raw download caches and private scouting prose are excluded from the repository; all 40 frozen scouting ratings remain separate from derived CSAx summaries.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

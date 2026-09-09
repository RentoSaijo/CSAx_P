# Playing Big for Their Size

This repository contains CSAx_P, an extension of the original CSAx study toward the MIT Sloan Sports Analytics Conference Research Paper Competition. The analysis predicts listed height-and-weight size from shared direct physicality measures and position-specific indirect behaviors, calibrates the prediction for the player's listed frame, and studies whether calibrated size above expected (CSAx) accompanies next-season roster continuation among forwards and defensemen in comparable roles among other applications. Centers are also compared through wing and defenseman reference models that exclude centers from training. The research findings and roadmap are available at [`reports/paper_mitssacrpc/research_summary.md`](reports/paper_mitssacrpc/research_summary.md).

## Reproduce

The workflow is tested with R 4.6.1. R package versions are pinned in `renv.lock`, and `.Rprofile` activates the project library.

For a fast report rebuild from the supplied analysis object:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/04_write_summary.R
```

For a full rebuild from the supplied input snapshot, run the ordered pipeline from the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
Rscript scripts/04_write_summary.R
```

The full rebuild reruns the nested positional models, focused sensitivities, and 499 shared full-pipeline player bootstrap replicates using 12 local workers. This is substantially slower than regenerating the report from the supplied object; completed bootstrap batches are cached under `data/cache/` and resume when the analysis command is rerun.

To retrieve fresh public play-by-play, roster, and shift records for the frozen cohort, run `Rscript scripts/01_prepare_data.R --refresh-events` before the model and analysis commands. This requires internet access and retains the supplied outcome, contract, expected-goal, and scouting snapshots. Upstream records can change; reproducing the reported results uses the bundled input snapshot.

## Files

- `reports/paper_mitssacrpc/`: research summary, three figures, player rankings, center comparisons, team summaries, and application estimates
- `data/analysis_data.rds`: compact analysis object, frozen scientific inputs, and all 499 bootstrap summaries
- `validation/`: public scouting codebook, source catalog, and frozen forward scouting codes
- `scripts/01_prepare_data.R` through `scripts/04_write_summary.R`: ordered data, metric, analysis, and reporting workflow
- `R/`: shared research functions, fixed analysis settings, event aggregation, positional models, and application helpers

## Public data

NHL game, roster, event, shift, and career records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. Contract records originate from [Spotrac NHL Contracts](https://www.spotrac.com/nhl/contracts/), expected goals use the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG), and the external validation uses official NHL Central Scouting reports identified in `validation/external_validation_source_catalog.csv`. Raw download caches and private scouting prose are excluded from the repository; frozen scouting codes remain separate from derived CSAx summaries.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

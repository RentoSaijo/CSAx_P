# CSAx_P: playing big for one's size

Playing big for one's size means showing a pattern of direct physical engagement and position-specific indirect behaviors associated with contested space that is more characteristic of a larger player than expected for one's listed height and weight.

CSAx_P extends the forward study accepted for presentation at the Carnegie Mellon Sports Analytics Conference. We fit separate expected-size models for forwards and defensemen, and compare centers through wing and defenseman reference models that exclude centers from training. Defenseman spatial takeaway measures are exploratory proxies whose construct validity remains unresolved.

Read the methods, findings, and research roadmap in [research_summary.md](reports/paper_mit_ssac/research_summary.md).

## Reproduce

Run from the repository root with R 4.6.1. Package versions and the nhlscraper revision are pinned in `renv.lock`; `.Rprofile` activates `renv`.

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
Rscript scripts/04_write_summary.R
```

The first command in the numbered workflow restores the frozen scientific inputs bundled in `data/analysis_data.rds`. The second fits the positional models and six focused sensitivities. The third runs the applications and one shared set of 499 full-pipeline player bootstrap samples. Completed batches resume from `data/cache/`. The fourth writes the Markdown report and gridless figures from the completed analysis object, and also runs independently for a fast report rebuild.

The bootstrap uses 12 local workers with single-threaded numerical libraries. Each draw samples whole player histories, groups duplicate copies within folds, and refits size references, preprocessing, ridge tuning, calibration, scores, continuation models, and center comparisons. Supporting application intervals cluster by player and condition on estimated scores.

To retrieve fresh play-by-play, roster, and shift records for the frozen cohort, use `Rscript scripts/01_prepare_data.R --refresh-events` before the model and analysis commands. This preserves the supplied outcome, contract, expected-goal, and scouting snapshots. Upstream records can change; source hashes and collection times distinguish input versions. Reproducing the reported results uses the bundled snapshot.

## Files

- `data/analysis_data.rds`: scientific inputs, predictions, compact model summaries, application estimates, and bootstrap summaries.
- `reports/paper_mit_ssac/`: research summary, player rankings, paired center comparisons, team summaries, application estimates, and figures.
- `scripts/01_prepare_data.R` through `scripts/04_write_summary.R`: ordered preparation, modeling, analysis, and reporting.
- `R/`: shared settings, event aggregation, positional estimation, and application helpers.
- `validation/`: frozen forward scouting codes, codebook, and source catalog; derived score associations reside in the analysis object.
- `data/cache/`: ignored local inputs and resumable calculations, including the preserved baseline `cmsac_baseline.rds`.

## Sources and submission

NHL events, rosters, shifts, career records, and contract records are accessed through the pinned [nhlscraper](https://github.com/RentoSaijo/nhlscraper) revision. Contract records originate from Spotrac, and supplied expected-goal aggregates use the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG). The scouting source catalog identifies the official NHL Central Scouting reports. Private scouting prose and raw download caches are excluded from Git.

The repository is private. Sloan's current research competition guidance lists October 1, 2026 for abstracts and December 4, 2026 for invited papers, and requires actual results and an open-source repository link. Public release requires a subsequent visibility decision. See [Sloan's competition guidance](https://www.sloansportsconference.com/research-paper-competition).

Original project code uses the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

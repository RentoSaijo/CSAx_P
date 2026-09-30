# Playing Tougher for One’s Size

This repository accompanies our study of physical presence relative to body size among NHL forwards and defensemen. Calibrated size above expected (CSAx) compares the size implied by recorded behavior with a player's listed frame. The [Sloan abstract](reports/abstract_mitssacrpc/abstract_mitssacrpc.pdf) examines agreement with independent scouting descriptions, special-teams deployment, postseason engagement, and next-season continuation.

## Reproduce

R package versions are pinned in `renv.lock`. With R, Quarto, and a LaTeX installation available, render the abstract from the supplied analysis object at the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
quarto render reports/abstract_mitssacrpc/abstract_mitssacrpc.qmd --to pdf
```

To rebuild the analysis from the bundled inputs, run:

```sh
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
```

This refits the positional models and applications; rendering the abstract does not.

## Files

- `reports/abstract_mitssacrpc/`: Quarto abstract and PDF
- `data/analysis_data.rds`: analysis inputs, fitted scores, and results
- `R/` and `scripts/01_prepare_data.R` through `scripts/03_analyze.R`: research functions and ordered analysis workflow
- `validation/`: scouting codebook, source catalog, and prose-free ratings

## Public data

The microstats come from Corey Sznajder's [All Three Zones transition workbook](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1); we follow its [glossary](https://www.allthreezones.com/player-cardsfaq.html). NHL records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. The scouting descriptions come from official NHL draft-year reports listed in the [source catalog](validation/external_validation_source_catalog.csv). Historical application inputs also cite [Spotrac](https://www.spotrac.com/nhl/contracts/) and the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG). Raw scouting passages are not redistributed.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

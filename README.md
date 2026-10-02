# Playing Tougher for One’s Size

Calibrated size above expected (CSAx) measures how tough NHL forwards and defensemen play for their listed size. It compares each player's frame with the size implied by direct contact and position-specific signs of physicality in battles for the puck and space. The [Sloan abstract](reports/abstract_mitssacrpc/abstract_mitssacrpc.pdf) compares CSAx with earlier scouting descriptions and examines special-teams deployment, postseason hitting, and next-season continuation.

## Reproduce

R package versions are pinned in `renv.lock`. With R, Quarto, and a LaTeX installation available, render the abstract from the supplied analysis object at the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript -e "base::source('R/abstract.R'); render_abstract()"
```

To rebuild the analysis from the bundled inputs, run:

```sh
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
```

This refits the positional models and applications.

## Data

The microstats come from Corey Sznajder's [All Three Zones transition workbook](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1); we follow its [glossary](https://www.allthreezones.com/player-cardsfaq.html). NHL records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. The scouting descriptions come from official NHL draft-year reports listed in the [source catalog](validation/external_validation_source_catalog.csv). Historical application inputs also cite [Spotrac](https://www.spotrac.com/nhl/contracts/) and the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG). Raw scouting passages are not redistributed.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms.

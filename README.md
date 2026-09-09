# Playing Big for Their Size

This repository accompanies the CMSAC Reproducible Research Competition paper *Playing Big for Their Size: Expected Size and Roster Security among NHL Forwards*. The analysis predicts listed height-and-weight size from ten contact and interior-shot features, calibrates the prediction for the player's listed frame, and studies whether calibrated size above expected (CSAx) accompanies next-season roster continuation among forwards in comparable roles among other applications. The final anonymous paper is available at [`reports/paper_cmsacrrc/paper_cmsacrrc.pdf`](reports/paper_cmsacrrc/paper_cmsacrrc.pdf).

## Reproduce

The workflow is tested with R 4.6.1, Quarto 1.10.18, TeX Live 2026, and Ghostscript 10.07.0. R package versions are pinned in `renv.lock`. Install Git and make the following tools available on your command path:

- Quarto and LaTeX: `quarto`, `lualatex`, `latexmk` (tested with 4.88), and `bibtex`
- Poppler PDF utilities: `pdfinfo`, `pdffonts`, `pdftotext`, and `pdftoppm`
- Ghostscript: `gs`, needed to embed fonts when rebuilding figures

For a fast render and complete manuscript verification from the supplied analysis object:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/04_render_paper.R
```

For a full rebuild from the public sources, run the ordered pipeline from the repository root:

```sh
Rscript -e "renv::restore(prompt = FALSE)"
Rscript scripts/01_prepare_data.R
Rscript scripts/02_build_csax.R
Rscript scripts/03_analyze.R
Rscript scripts/04_render_paper.R
```

The full rebuild requires internet access and reruns the nested models and 999 full-pipeline player bootstrap replicates. This is substantially slower than rendering the supplied object; completed bootstrap batches are cached under `data/cache/` and resume when the analysis command is rerun.

## Files

- `reports/paper_cmsacrrc/`: anonymous manuscript source, stable PDF, three vector figures, bibliography, and player/team rankings
- `data/analysis_data.rds`: compact strict analysis object and all 999 bootstrap summaries
- `validation/`: public scouting codebook, source catalog, and prose-free validation data
- `scripts/01_prepare_data.R` through `scripts/04_render_paper.R`: ordered data, metric, analysis, and rendering workflow
- `R/functions.R`: shared research functions and fixed analysis settings

## Public data

NHL game, roster, event, and shift records are retrieved through the pinned [`nhlscraper`](https://github.com/RentoSaijo/nhlscraper) revision. Contract records originate from [Spotrac NHL Contracts](https://www.spotrac.com/nhl/contracts/), expected goals use the pinned [NHLxG model store](https://huggingface.co/datasets/RentoSaijo/NHLxG), and the external validation uses official NHL Central Scouting reports identified in `validation/external_validation_source_catalog.csv`. All analysis inputs are publicly accessible without a paywall; raw downloads and scouting prose are not redistributed.

## License

Original project code is available under the [MIT license](LICENSE). Third-party data and materials retain their respective terms; the bundled Quarto template includes its upstream license and notices.

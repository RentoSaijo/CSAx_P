# Abstract Values --------------------------------------------------------

# Format estimates and intervals with consistent precision.
abstract_interval <- function(estimate, low, high) {
  base::paste0(base::formatC(estimate, digits = 2L, format = 'f'), ' (', base::formatC(low, digits = 2L, format = 'f'), ', ', base::formatC(high, digits = 2L, format = 'f'), ')')
}

# Prepare presentation values without fitting models.
prepare_abstract <- function(p) {
  if (!p$scouting$expansionComplete) base::stop('Completed, locked scouting ratings are required.', call. = FALSE)
  scout <- p$scouting$estimates |>
    dplyr::mutate(panel = base::paste0(model, ' (n = ', n, ')\nDifference: ', abstract_interval(estimate, confLow, confHigh), '\nSpearman correlation: ', base::formatC(spearman, digits = 2L, format = 'f')))
  panels <- scout$panel[base::match(base::c('Forwards', 'Defensemen'), scout$model)]
  observations <- p$scouting$scores |>
    dplyr::left_join(scout |> dplyr::select(model, panel), by = 'model') |>
    dplyr::mutate(panel = base::factor(panel, levels = panels), description = base::factor(activePhysicalEngagement, levels = base::c(0, 1), labels = base::c('No mention', 'Active engagement')))
  means <- observations |> dplyr::group_by(panel, description) |> dplyr::summarise(meanScore = base::mean(meanCSAx), n = dplyr::n(), .groups = 'drop')
  scouting_text <- purrr::map_chr(base::c('Forwards', 'Defensemen'), function(population) {
    row <- scout[scout$model == population, ]
    values <- p$scouting$scores |> dplyr::filter(model == population) |> dplyr::group_by(activePhysicalEngagement) |> dplyr::summarise(meanScore = base::mean(meanCSAx), .groups = 'drop')
    glue::glue('{population} (n = {row$n}): {row$absentReports} without a mention average {base::formatC(values$meanScore[1L], digits = 2L, format = "f")}; {row$positiveReports} with a mention average {base::formatC(values$meanScore[2L], digits = 2L, format = "f")}. Mean difference: {abstract_interval(row$estimate, row$confLow, row$confHigh)}; Spearman correlation: {base::formatC(row$spearman, digits = 2L, format = "f")}.')
  })
  deployment <- p$applications$deployment$estimates |>
    dplyr::transmute(model, Outcome = dplyr::recode(outcome, powerPlayShare = 'Power-play share (pp)', penaltyKillShare = 'Penalty-kill share (pp)'), estimate = 2 * effect, low = 2 * effectLow, high = 2 * effectHigh)
  postseason <- p$applications$engagement$estimates |>
    dplyr::filter(outcome == 'hits', window == 'First four') |>
    dplyr::transmute(model, Outcome = 'Playoff hit-rate change (ratio)', estimate = effect^2, low = effectLow^2, high = effectHigh^2)
  continuation <- p$continuationContrasts |>
    dplyr::transmute(model, Outcome = 'Next-season continuation (pp)', estimate = 100 * estimate, low = 100 * confLow, high = 100 * confHigh)
  playing_time <- p$applications$playingTime$estimates |>
    dplyr::transmute(model, Outcome = 'Ice time (min/game)', estimate = 2 * effect, low = 2 * effectLow, high = 2 * effectHigh)
  applications <- dplyr::bind_rows(deployment, postseason, continuation, playing_time) |>
    dplyr::mutate(value = abstract_interval(estimate, low, high), Outcome = base::factor(Outcome, levels = base::c('Power-play share (pp)', 'Penalty-kill share (pp)', 'Playoff hit-rate change (ratio)', 'Next-season continuation (pp)', 'Ice time (min/game)'))) |>
    dplyr::select(Outcome, model, value) |>
    tidyr::pivot_wider(names_from = model, values_from = value) |>
    dplyr::arrange(Outcome) |>
    dplyr::select(Outcome, Forwards, Defensemen)
  base::list(forwardSeasons = base::sum(p$predictions$model == 'Forwards'), defenseSeasons = base::sum(p$predictions$model == 'Defensemen'), scouting = observations, scoutingMeans = means, scoutingText = base::paste(scouting_text, collapse = '\n\n'), applications = applications)
}

# Abstract Figure --------------------------------------------------------

# Display individual scouting scores and group means within each position.
plot_abstract_scouting <- function(values) {
  ggplot2::ggplot(values$scouting, ggplot2::aes(description, meanCSAx)) +
    ggplot2::geom_hline(yintercept = 0, color = '#CCCCCC', linewidth = 0.3) +
    ggplot2::geom_point(ggplot2::aes(color = description), position = ggplot2::position_jitter(width = 0.13, height = 0, seed = 20260926L), size = 1.6, alpha = 0.8) +
    ggplot2::geom_point(data = values$scoutingMeans, ggplot2::aes(y = meanScore), shape = 23, size = 3, fill = 'white', color = '#151515', stroke = 0.6) +
    ggplot2::geom_text(data = values$scoutingMeans, ggplot2::aes(y = -2.3, label = base::paste0('n = ', n)), family = 'Latin Modern Roman', size = 2.8) +
    ggplot2::facet_wrap(~panel, nrow = 1L) +
    ggplot2::scale_color_manual(values = base::c('No mention' = '#727272', 'Active engagement' = '#17324D'), guide = 'none') +
    ggplot2::scale_y_continuous(breaks = -2:3, limits = base::c(-2.45, 3.5), expand = ggplot2::expansion(mult = 0)) +
    ggplot2::labs(x = NULL, y = 'Player-average CSAx') +
    ggplot2::theme_minimal(base_family = 'Latin Modern Roman', base_size = 10) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), axis.text = ggplot2::element_text(color = '#151515'), strip.text = ggplot2::element_text(size = 9, margin = ggplot2::margin(b = 6)), panel.spacing = grid::unit(1, 'lines'), plot.margin = ggplot2::margin(2, 8, 2, 2))
}

# Abstract Rendering -----------------------------------------------------

# Render authoritative Quarto source and check submission length.
render_abstract <- function() {
  candidates <- base::c(base::Sys.which('quarto'), '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto')
  candidates <- candidates[base::nzchar(candidates) & base::file.exists(candidates)]
  if (!base::length(candidates)) base::stop('Quarto is required; add its executable to PATH.', call. = FALSE)
  quarto <- candidates[1L]
  abstract_directory <- 'reports/abstract_mitssacrpc'
  source <- base::file.path(abstract_directory, 'abstract_mitssacrpc.qmd')
  markdown <- base::file.path(abstract_directory, 'abstract_mitssacrpc.md')
  plain <- base::tempfile(fileext = '.txt')
  base::on.exit(base::unlink(base::c(markdown, plain)), add = TRUE)
  for (format in base::c('gfm', 'pdf')) {
    status <- base::system2(quarto, base::c('render', base::shQuote(source), '--to', format, '--quiet'))
    if (status != 0L) base::stop('Quarto abstract rendering failed for ', format, '.', call. = FALSE)
  }
  contents <- stringr::str_replace_all(readr::read_file(markdown), '\f', '')
  display_start <- '<!-- abstract-display-start -->'
  display_end <- '<!-- abstract-display-end -->'
  if (stringr::str_count(contents, stringr::fixed(display_start)) != 2L || stringr::str_count(contents, stringr::fixed(display_end)) != 2L) base::stop('Abstract must mark exactly one figure and one table.', call. = FALSE)
  narrative <- stringr::str_replace_all(contents, '(?s)<!-- abstract-display-start -->.*?<!-- abstract-display-end -->', '')
  plain_source <- stringr::str_replace_all(narrative, '<sup>([^<]+)</sup>', ' [\\1]')
  status <- base::system2(quarto, base::c('pandoc', '--from=gfm', '--to=plain', '--wrap=none', '--output', base::shQuote(plain)), input = plain_source)
  if (status != 0L) base::stop('Plain-text abstract conversion failed.', call. = FALSE)
  word_count <- stringr::str_count(stringr::str_squish(readr::read_file(plain)), '\\S+')
  if (word_count >= 480L) base::stop('Abstract exceeds the project target of fewer than 480 words.', call. = FALSE)
  base::message('Rendered Quarto abstract (', word_count, ' counted words; figure and table excluded).')
  word_count
}

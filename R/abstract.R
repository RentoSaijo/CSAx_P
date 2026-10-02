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
    dplyr::mutate(panel = base::factor(panel, levels = panels), description = base::factor(activePhysicalEngagement, levels = base::c(0, 1), labels = base::c('No mention', 'Physical-trait mention')))
  means <- observations |> dplyr::group_by(panel, description) |> dplyr::summarise(meanScore = base::mean(meanCSAx), n = dplyr::n(), .groups = 'drop')
  deployment <- p$applications$deployment$estimates |>
    dplyr::transmute(model, Outcome = dplyr::recode(outcome, powerPlayShare = 'Power-play share (percentage points)', penaltyKillShare = 'Penalty-kill share (percentage points)'), estimate = 2 * effect, low = 2 * effectLow, high = 2 * effectHigh)
  postseason <- p$applications$engagement$estimates |>
    dplyr::filter(outcome == 'hits', window == 'First four') |>
    dplyr::transmute(model, Outcome = 'Postseason hit-rate (ratio)', estimate = effect^2, low = effectLow^2, high = effectHigh^2)
  continuation <- p$continuationContrasts |>
    dplyr::transmute(model, Outcome = 'Next-season continuation (percentage points)', estimate = 100 * estimate, low = 100 * confLow, high = 100 * confHigh)
  playing_time <- p$applications$playingTime$estimates |>
    dplyr::transmute(model, Outcome = 'Ice time (min/game)', estimate = 2 * effect, low = 2 * effectLow, high = 2 * effectHigh)
  applications <- dplyr::bind_rows(deployment, postseason, continuation, playing_time) |>
    dplyr::mutate(value = abstract_interval(estimate, low, high), Outcome = base::factor(Outcome, levels = base::c('Power-play share (percentage points)', 'Penalty-kill share (percentage points)', 'Postseason hit-rate (ratio)', 'Next-season continuation (percentage points)', 'Ice time (min/game)'))) |>
    dplyr::select(Outcome, model, value) |>
    tidyr::pivot_wider(names_from = model, values_from = value) |>
    dplyr::arrange(Outcome) |>
    dplyr::select(Outcome, Forwards, Defensemen)
  base::list(scouting = observations, scoutingMeans = means, applications = applications)
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
    ggplot2::scale_x_discrete(labels = base::c('No mention', 'Physical-trait mention')) +
    ggplot2::scale_color_manual(values = base::c('No mention' = '#727272', 'Physical-trait mention' = '#17324D'), guide = 'none') +
    ggplot2::scale_y_continuous(breaks = -2:3, limits = base::c(-2.45, 3.5), expand = ggplot2::expansion(mult = 0)) +
    ggplot2::labs(x = NULL, y = 'Player-average CSAx') +
    ggplot2::theme_minimal(base_family = 'Latin Modern Roman', base_size = 10) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), axis.text = ggplot2::element_text(color = '#151515'), strip.text = ggplot2::element_text(size = 9, margin = ggplot2::margin(b = 6)), panel.spacing = grid::unit(1, 'lines'), plot.margin = ggplot2::margin(2, 8, 2, 2))
}

# Abstract Rendering -----------------------------------------------------

# Render authoritative Quarto source as PDF.
render_abstract <- function() {
  candidates <- base::c(base::Sys.which('quarto'), '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto')
  candidates <- candidates[base::nzchar(candidates) & base::file.exists(candidates)]
  if (!base::length(candidates)) base::stop('Quarto is required; add its executable to PATH.', call. = FALSE)
  quarto <- candidates[1L]
  source <- base::file.path('reports/abstract_mitssacrpc', 'abstract_mitssacrpc.qmd')
  status <- base::system2(quarto, base::c('render', base::shQuote(source), '--to', 'pdf', '--quiet'))
  if (status != 0L) base::stop('Quarto abstract PDF rendering failed.', call. = FALSE)
  base::message('Rendered Quarto abstract PDF.')
  base::invisible(NULL)
}

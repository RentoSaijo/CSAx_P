# A3Z Research Report -----------------------------------------------------

# Write matched-model results and retain labeled benchmark products.
write_a3z_report <- function(analysis, report_directory, figure_directory) {
  p <- analysis$a3z
  features <- p$inputs$features
  main_specs <- base::c('A3Z integrated', 'Matched play-by-play')
  labels <- base::c(feature_labels, dumpInRecoveriesPer60 = 'Dump-in recoveries', forecheckPressuresPer60 = 'Forecheck pressures', forecheckCycleAssistsPer60 = 'Forecheck/cycle shot assists', retrievalExitsPer60 = 'Retrievals leading to exits', botchedRetrievalsPer60 = 'Botched retrievals', possessionExitShare = 'Possession share of successful exits', entryDenialShare = 'Entry denial share')
  count_columns <- base::c('hits', 'hitsReceived', 'blockedShots', 'fights', 'contactPenaltiesTaken', 'contactPenaltiesDrawn', 'unblockedAttempts', 'reboundAttempts', 'locatedAttempts', 'netFrontAttempts', 'typedShotsOnNet', 'backhandShots', 'deflectionShots', 'takeaways', 'locatedTakeaways', 'defensiveTakeaways', 'defensivePerimeterTakeaways')
  feature_values <- features |> dplyr::select(playerId, seasonId, height, weight, dplyr::all_of(base::setdiff(base::names(a3z_source_columns), 'sourceMinutes')), dplyr::all_of(count_columns), dplyr::all_of(base::names(labels)))

  # Export matched rankings with event denominators and model identities.
  baseline_rankings <- readr::read_csv(base::file.path(report_directory, 'player_rankings.csv'), show_col_types = FALSE) |>
    dplyr::mutate(specification = 'Full-season play-by-play benchmark', eventScope = 'All situations', .before = 1L)
  rankings <- p$predictions |>
    dplyr::filter(specification %in% main_specs, !isCenterComparison, model != 'Wings', timeOnIce >= 500 * 60) |>
    dplyr::left_join(feature_values, by = base::c('playerId', 'seasonId')) |>
    dplyr::left_join(p$performance |> dplyr::select(specification, model, seasonId, scoreCaution), by = base::c('specification', 'model', 'seasonId')) |>
    dplyr::group_by(specification, model, seasonId) |>
    dplyr::arrange(dplyr::desc(CSAx), playerId, .by_group = TRUE) |>
    dplyr::mutate(rank = dplyr::row_number(), season = season_label(seasonId), minutes = timeOnIce / 60) |>
    dplyr::ungroup() |>
    dplyr::rename(player = playerFullName, heightInches = height, weightPounds = weight) |>
    dplyr::select(-rowId, -timeOnIce, -directRaw, -indirectRaw, -intercept) |>
    dplyr::relocate(specification, model, referencePopulation, eventScope, season, seasonId, rank, playerId, player)
  readr::write_csv(dplyr::bind_rows(rankings, baseline_rankings) |> dplyr::mutate(dplyr::across(dplyr::where(base::is.double), ~ base::round(.x, 2L))), base::file.path(report_directory, 'player_rankings.csv'))

  # Export center comparisons with both reference populations and opportunity flags.
  baseline_centers <- readr::read_csv(base::file.path(report_directory, 'center_comparisons.csv'), show_col_types = FALSE) |>
    dplyr::mutate(specification = 'Full-season play-by-play benchmark', eventScope = 'All situations', .before = 1L)
  center_export <- p$centers |> dplyr::filter(specification %in% main_specs) |>
    dplyr::mutate(eventScope = a3z_scope, wingReference = 'Wings; centers excluded', defensemanReference = 'Defensemen; centers excluded', rankingEligible = timeOnIce >= 500 * 60) |>
    dplyr::left_join(feature_values, by = base::c('playerId', 'seasonId')) |>
    dplyr::select(-rowId)
  readr::write_csv(dplyr::bind_rows(center_export, baseline_centers) |> dplyr::mutate(dplyr::across(dplyr::where(base::is.double), ~ base::round(.x, 2L))), base::file.path(report_directory, 'center_comparisons.csv'))
  baseline_agreement <- readr::read_csv(base::file.path(report_directory, 'center_agreement.csv'), show_col_types = FALSE) |>
    dplyr::mutate(specification = 'Full-season play-by-play benchmark', eventScope = 'All situations', .before = 1L)
  agreement_export <- p$centerAgreement |>
    tidyr::pivot_longer(dplyr::all_of(base::c('spearman', 'meanPercentileDifference', 'medianPercentileDifference', 'meanAbsolutePercentileDifference')), names_to = 'statistic', values_to = 'estimate') |>
    dplyr::mutate(eventScope = a3z_scope, model = 'Wings versus Defensemen', referencePopulation = 'Wings and Defensemen separately')
  readr::write_csv(dplyr::bind_rows(agreement_export, baseline_agreement), base::file.path(report_directory, 'center_agreement.csv'))

  # Keep team coverage distinct from full-season team applications.
  baseline_teams <- readr::read_csv(base::file.path(report_directory, 'team_summaries.csv'), show_col_types = FALSE) |>
    dplyr::mutate(specification = 'Full-season play-by-play benchmark', referencePopulation = model, eventScope = 'All situations', summaryType = 'Team applications', .before = 1L)
  tracked_teams <- p$inputs$sourceRows |>
    dplyr::filter(rowStatus == 'Retained') |>
    dplyr::left_join(analysis$inputs$teamPlayerPositions |> dplyr::select(playerId, positionCode), by = 'playerId') |>
    dplyr::mutate(model = dplyr::if_else(dplyr::coalesce(positionCode, rosterPosition) == 'D', 'Defensemen', 'Forwards')) |>
    dplyr::group_by(seasonId, teamId, model) |>
    dplyr::summarise(trackedGames = dplyr::n_distinct(gameId), trackedPlayers = dplyr::n_distinct(playerId), trackedPlayerMinutes = base::sum(nhlSeconds) / 60, .groups = 'drop') |>
    dplyr::left_join(analysis$inputs$teams |> dplyr::select(teamId, teamTriCode), by = 'teamId') |>
    dplyr::mutate(specification = 'A3Z integrated', referencePopulation = model, eventScope = a3z_scope, summaryType = 'Tracking coverage')
  readr::write_csv(dplyr::bind_rows(tracked_teams, baseline_teams), base::file.path(report_directory, 'team_summaries.csv'))
  baseline_applications <- readr::read_csv(base::file.path(report_directory, 'application_estimates.csv'), show_col_types = FALSE) |>
    dplyr::mutate(specification = dplyr::if_else(label == 'Sensitivity', base::paste0('Full-season benchmark: ', outcome), 'Full-season play-by-play benchmark'), eventScope = dplyr::case_when(outcome == 'Away games' ~ 'Away games', outcome == 'Five on five' ~ 'Five on five', TRUE ~ 'All situations'), .before = 1L)
  readr::write_csv(dplyr::bind_rows(p$continuation, baseline_applications), base::file.path(report_directory, 'application_estimates.csv'))

  # Summarize matched predictive performance and annual coverage.
  pooled <- p$performance |>
    dplyr::group_by(specification, model) |>
    dplyr::summarise(playerSeasons = base::sum(n), pooledRmse = base::sqrt(base::sum(n * rmse^2) / base::sum(n)), pooledR2 = 1 - base::sum(n * rmse^2) / base::sum(n * baselineRmse^2), .groups = 'drop')
  performance_table <- pooled |> dplyr::filter(specification %in% main_specs) |>
    dplyr::transmute(Specification = specification, Reference = model, `Player-seasons` = base::as.character(playerSeasons), RMSE = pooledRmse, `Predictive R² (%)` = 100 * pooledR2)
  coverage_table <- p$inputs$coverage |> dplyr::group_by(seasonId, positionGroup) |>
    dplyr::summarise(originalN = dplyr::n(), retainedN = base::sum(eligible), medianGames = stats::median(trackedGames[eligible]), medianMinutes = stats::median(trackedMinutes[eligible]), .groups = 'drop') |>
    dplyr::transmute(Season = season_label(seasonId), Position = positionGroup, `Full-season eligible` = base::as.character(originalN), `Pilot eligible` = base::as.character(retainedN), `Retained (%)` = 100 * retainedN / originalN, `Median tracked games` = base::as.character(medianGames), `Median tracked minutes` = medianMinutes)
  characteristics <- p$inputs$coverage |>
    dplyr::group_by(positionGroup, eligible) |>
    dplyr::summarise(playerSeasons = dplyr::n(), meanHeight = base::mean(height), meanWeight = base::mean(weight), medianMinutes = stats::median(timeOnIce / 60), .groups = 'drop') |>
    dplyr::transmute(Position = positionGroup, Sample = dplyr::if_else(eligible, 'Included', 'Outside tracked-minute sample'), `Player-seasons` = base::as.character(playerSeasons), `Mean height (in)` = meanHeight, `Mean weight (lb)` = meanWeight, `Median full-season minutes` = medianMinutes)
  annual <- p$performance |> dplyr::filter(specification %in% main_specs) |>
    dplyr::select(specification, seasonId, model, predictiveRSquared, residualSizeCorrelation) |>
    tidyr::pivot_wider(names_from = specification, values_from = base::c('predictiveRSquared', 'residualSizeCorrelation')) |>
    dplyr::transmute(Season = season_label(seasonId), Reference = model, `A3Z R² (%)` = 100 * .data[['predictiveRSquared_A3Z integrated']], `Matched PBP R² (%)` = 100 * .data[['predictiveRSquared_Matched play-by-play']], `A3Z CSAx–size correlation` = .data[['residualSizeCorrelation_A3Z integrated']], `PBP CSAx–size correlation` = .data[['residualSizeCorrelation_Matched play-by-play']])
  component_table <- pooled |> dplyr::filter(!specification %in% main_specs) |>
    dplyr::left_join(p$performance |> dplyr::group_by(specification, model) |> dplyr::summarise(seasonsAboveBaseline = base::paste0(base::sum(predictiveRSquared > 0), ' of ', dplyr::n()), .groups = 'drop'), by = base::c('specification', 'model')) |>
    dplyr::transmute(Specification = specification, Reference = model, `Predictive R² (%)` = 100 * pooledR2, `Seasons above mean baseline` = seasonsAboveBaseline)
  stability_table <- p$stability |> dplyr::filter(specification %in% main_specs) |> dplyr::group_by(specification, model) |>
    dplyr::summarise(pearsonRange = base::paste(fixed(base::range(correlation)), collapse = ' to '), spearmanRange = base::paste(fixed(base::range(spearman)), collapse = ' to '), .groups = 'drop') |>
    dplyr::rename(Specification = specification, Reference = model, `Annual Pearson range` = pearsonRange, `Annual Spearman range` = spearmanRange)

  # Describe coefficient patterns without treating weights as performance rewards.
  coefficients <- p$coefficients |> dplyr::filter(specification == 'A3Z integrated') |>
    dplyr::group_by(model, feature, component) |>
    dplyr::summarise(medianCoefficient = stats::median(coefficient), positiveFolds = base::sum(coefficient > 0), negativeFolds = base::sum(coefficient < 0), .groups = 'drop')
  coefficient_table <- coefficients |>
    dplyr::arrange(base::match(feature, base::names(labels))) |>
    dplyr::mutate(Measure = base::unname(labels[feature])) |>
    dplyr::select(Component = component, Measure, model, medianCoefficient) |>
    tidyr::pivot_wider(names_from = model, values_from = medianCoefficient)
  sparse_table <- features |> dplyr::mutate(Position = dplyr::case_when(positionCode == 'D' ~ 'Defensemen', positionCode == 'C' ~ 'Centers', TRUE ~ 'Wings')) |>
    dplyr::group_by(Position) |>
    dplyr::summarise(`Median successful exits` = stats::median(successfulExits), `Median targeted entries` = stats::median(entryTargets), `Median retrievals leading to exits` = stats::median(retrievalExits), `Median dump-in recoveries` = stats::median(dumpInRecoveries), .groups = 'drop')
  diagnostics <- p$predictions |> dplyr::filter(specification == 'A3Z integrated') |>
    dplyr::mutate(scoredGroup = dplyr::if_else(isCenterComparison, 'Centers', model), completeInputs = imputedFeatures == 0L, withinRanges = !outsideTrainingRange & completeInputs, shareCounts = !base::nzchar(sparseDenominators)) |>
    dplyr::group_by(scoredGroup, model) |>
    dplyr::summarise(scored = dplyr::n(), complete = base::sum(completeInputs), withinRanges = base::sum(withinRanges), shareCounts = base::sum(shareCounts), bothChecks = base::sum(!outsideTrainingRange & completeInputs & !base::nzchar(sparseDenominators)), .groups = 'drop') |>
    dplyr::arrange(base::match(scoredGroup, base::c('Forwards', 'Defensemen', 'Wings', 'Centers')), base::match(model, base::c('Forwards', 'Wings', 'Defensemen'))) |>
    dplyr::transmute(`Scored group` = scoredGroup, Reference = model, Scored = base::as.character(scored), `Complete inputs` = base::as.character(complete), `Within ranges and complete` = base::as.character(withinRanges), `Every share ≥20` = base::as.character(shareCounts), `Both checks` = base::as.character(bothChecks))
  center_diagnostics <- p$centers |> dplyr::filter(specification == 'A3Z integrated') |>
    dplyr::group_by(seasonId) |>
    dplyr::summarise(withinRanges = base::sum(withinTrainingRanges), shareCounts = base::sum(!base::nzchar(sparseDenominators_Wings) & !base::nzchar(sparseDenominators_Defensemen)), bothChecks = base::sum(supported), .groups = 'drop')
  center_table <- p$centerAgreement |> dplyr::filter(specification == 'A3Z integrated', sample == 'All centers') |>
    dplyr::left_join(center_diagnostics, by = 'seasonId') |>
    dplyr::transmute(Season = season_label(seasonId), `Centers scored` = base::as.character(n), Spearman = spearman, `Mean wing-minus-defenseman percentile` = meanPercentileDifference, `Within both ranges and complete` = base::as.character(withinRanges), `Every share ≥20 in both models` = base::as.character(shareCounts), `Both checks` = base::as.character(bothChecks))
  center_direct <- p$centerAgreement |> dplyr::filter(specification == 'Direct only', sample == 'All centers') |>
    dplyr::transmute(Season = season_label(seasonId), Spearman = spearman, `Mean wing-minus-defenseman percentile` = meanPercentileDifference)
  examples <- p$rankChanges |> dplyr::filter(model != 'Wings', seasonId == 20242025L, timeOnIce >= 500 * 60) |>
    dplyr::group_by(model) |> dplyr::slice_max(base::abs(percentileChange), n = 4L, with_ties = FALSE) |> dplyr::ungroup() |>
    dplyr::transmute(Position = model, Player = playerFullName, `Tracked games` = base::as.character(trackedGames), `Play-by-play percentile` = .data[['referencePercentile_Matched play-by-play']], `A3Z percentile` = .data[['referencePercentile_A3Z integrated']], `Difference (points)` = percentileChange)
  continuation_table <- p$continuation |> dplyr::transmute(Specification = specification, Position = model, `Player-seasons` = base::as.character(sampleSize), `Continuation odds ratio (95% CI)` = interval(effect, effectLow, effectHigh))
  scouting_table <- purrr::imap_dfr(p$scouting, function(result, label) result$estimates |>
    dplyr::transmute(Specification = .env$label, Indicator = dplyr::recode(indicator, overallPhysicality = 'Overall physicality', playsBiggerExplicit = 'Explicitly plays bigger', activePhysicalEngagement = 'Active physical engagement', interiorPlay = 'Interior play'), Players = base::as.character(n), Spearman = spearman))
  contribution_players <- p$rankChanges |> dplyr::filter(model != 'Wings', seasonId == base::max(xs_behavior_seasons), timeOnIce >= 500 * 60, percentileChange != 0) |>
    dplyr::group_by(model, direction = base::sign(percentileChange)) |> dplyr::slice_max(base::abs(percentileChange), n = 1L, with_ties = FALSE) |> dplyr::ungroup() |>
    dplyr::select(playerId, seasonId, model)
  contribution_table <- p$predictions |> dplyr::filter(specification %in% main_specs, !isCenterComparison) |>
    dplyr::semi_join(contribution_players, by = base::c('playerId', 'seasonId', 'model')) |>
    dplyr::arrange(model, playerFullName, specification) |>
    dplyr::transmute(Player = playerFullName, Specification = specification, Direct = directContribution, Indirect = indirectContribution, `Frame adjustment` = frameAdjustment, CSAx)
  center_examples <- p$centers |> dplyr::filter(specification == 'A3Z integrated', seasonId == base::max(xs_behavior_seasons), playerFullName %in% base::c('Sidney Crosby', 'Aleksander Barkov', 'Jack Hughes')) |>
    dplyr::left_join(features |> dplyr::select(playerId, seasonId, entryTargets), by = base::c('playerId', 'seasonId')) |>
    dplyr::transmute(Player = playerFullName, `Wing percentile` = referencePercentile_Wings, `Defenseman percentile` = referencePercentile_Defensemen, `Targeted entries` = base::as.character(entryTargets), `Within both ranges and complete` = dplyr::if_else(withinTrainingRanges, 'Yes', 'No'), `Every share ≥20 in both models` = dplyr::if_else(!base::nzchar(sparseDenominators_Wings) & !base::nzchar(sparseDenominators_Defensemen), 'Yes', 'No'))

  # Draw coefficient, center, and continuation figures without grids.
  coefficient_plot <- coefficients |> dplyr::filter(model != 'Wings') |>
    dplyr::mutate(measure = base::factor(labels[feature], levels = base::rev(base::unique(base::unname(labels))))) |>
    ggplot2::ggplot(ggplot2::aes(medianCoefficient, measure, color = component)) +
    ggplot2::geom_vline(xintercept = 0, color = '#BBBBBB', linewidth = 0.4) + ggplot2::geom_point(size = 2.6) +
    ggplot2::facet_wrap(~model, scales = 'free_y', ncol = 1L) +
    ggplot2::scale_color_manual(values = base::c(Direct = '#17324D', Indirect = '#BD7C27')) +
    ggplot2::scale_x_continuous(breaks = base::seq(-0.10, 0.20, by = 0.05), labels = scales::label_number(accuracy = 0.01)) +
    ggplot2::labs(title = 'A3Z adds puck-play detail to learned size weights', subtitle = 'Median standardized coefficient across 20 season-by-fold fits per position', x = 'Coefficient in listed-size units', y = NULL, color = NULL) + research_theme()
  ggplot2::ggsave(base::file.path(figure_directory, 'feature_weights.png'), coefficient_plot, width = 9, height = 9, dpi = 180, bg = 'white')
  center_plot <- p$centers |> dplyr::filter(specification == 'A3Z integrated') |>
    dplyr::mutate(season = season_label(seasonId), rangeCheck = dplyr::if_else(withinTrainingRanges, 'Within both ranges; complete inputs', 'Outside range or incomplete inputs'), countCheck = dplyr::if_else(!base::nzchar(sparseDenominators_Wings) & !base::nzchar(sparseDenominators_Defensemen), 'Every share ≥20', 'At least one share below 20 or undefined')) |>
    ggplot2::ggplot(ggplot2::aes(referencePercentile_Wings, referencePercentile_Defensemen, color = rangeCheck, shape = countCheck)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = '#BBBBBB', linewidth = 0.4) +
    ggplot2::geom_point(alpha = 0.65, size = 1.4) + ggplot2::facet_wrap(~season, ncol = 2L) +
    ggplot2::scale_color_manual(values = base::c('Within both ranges; complete inputs' = '#17324D', 'Outside range or incomplete inputs' = '#BD7C27')) +
    ggplot2::scale_shape_manual(values = base::c('Every share ≥20' = 16, 'At least one share below 20 or undefined' = 2)) +
    ggplot2::coord_equal(xlim = base::c(0, 100), ylim = base::c(0, 100)) +
    ggplot2::labs(title = 'Center standing under two positional references', subtitle = 'All eligible center-seasons; separate range and opportunity diagnostics', x = 'Percentile relative to wings', y = 'Percentile relative to defensemen', color = NULL, shape = NULL) +
    ggplot2::guides(color = ggplot2::guide_legend(order = 1L), shape = ggplot2::guide_legend(order = 2L)) + research_theme() + ggplot2::theme(legend.box = 'vertical', legend.text = ggplot2::element_text(size = 9))
  ggplot2::ggsave(base::file.path(figure_directory, 'center_standing.png'), center_plot, width = 9, height = 7, dpi = 180, bg = 'white')
  continuation_plot <- ggplot2::ggplot(p$continuation, ggplot2::aes(effect, specification, color = specification)) +
    ggplot2::geom_vline(xintercept = 1, color = '#BBBBBB', linetype = 'dashed', linewidth = 0.4) +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = effectLow, xmax = effectHigh), orientation = 'y', width = 0.12) +
    ggplot2::geom_point(size = 2.8) + ggplot2::facet_wrap(~model, ncol = 1L) +
    ggplot2::scale_color_manual(values = base::c('A3Z integrated' = '#17324D', 'Matched play-by-play' = '#BD7C27')) +
    ggplot2::scale_x_continuous(labels = scales::label_number(accuracy = 0.01)) +
    ggplot2::labs(title = 'Continuation associations in matched samples', subtitle = '95% player-clustered intervals conditional on estimated scores and tracked sample', x = 'Odds ratio per CSAx standard deviation', y = NULL) + research_theme() + ggplot2::theme(legend.position = 'none')
  ggplot2::ggsave(base::file.path(figure_directory, 'continuation.png'), continuation_plot, width = 8, height = 5, dpi = 180, bg = 'white')

  # Present findings, measurement limits, and subsequent research questions.
  exclusions <- p$inputs$sourceRows |> dplyr::count(rowStatus) |> dplyr::transmute(Disposition = rowStatus, `Player-game rows` = base::as.character(n))
  source_games <- p$inputs$sourceRows |> dplyr::filter(rowStatus == 'Retained') |> dplyr::group_by(seasonId) |>
    dplyr::summarise(games = dplyr::n_distinct(gameId), teams = dplyr::n_distinct(teamId), medianDifference = stats::median(base::abs(deltaSeconds)), .groups = 'drop') |>
    dplyr::left_join(tracked_teams |> dplyr::group_by(seasonId) |> dplyr::summarise(teamGameRange = base::paste(base::range(trackedGames), collapse = ' to '), .groups = 'drop'), by = 'seasonId') |>
    dplyr::transmute(Season = season_label(seasonId), `Retained NHL games` = base::as.character(games), Teams = base::as.character(teams), `Tracked games per team` = teamGameRange, `Median absolute time difference (seconds)` = medianDifference)
  forward_main <- pooled |> dplyr::filter(specification == 'A3Z integrated', model == 'Forwards')
  forward_comparator <- pooled |> dplyr::filter(specification == 'Matched play-by-play', model == 'Forwards')
  defense_main <- pooled |> dplyr::filter(specification == 'A3Z integrated', model == 'Defensemen')
  defense_comparator <- pooled |> dplyr::filter(specification == 'Matched play-by-play', model == 'Defensemen')
  latest_defense <- p$performance |> dplyr::filter(specification == 'A3Z integrated', model == 'Defensemen', seasonId == base::max(xs_behavior_seasons))
  center_count <- p$centers |> dplyr::filter(specification == 'A3Z integrated') |> base::nrow()
  center_ranges <- p$centers |> dplyr::filter(specification == 'A3Z integrated') |>
    dplyr::summarise(entryShareOutside = base::sum(stringr::str_detect(outsideFeatures_Defensemen, 'entryDenialShare')), botchedRateOutside = base::sum(stringr::str_detect(outsideFeatures_Defensemen, 'botchedRetrievalsPer60')))
  scouting_main <- p$scouting[['A3Z integrated']]$estimates |> dplyr::filter(indicator == 'overallPhysicality')
  scouting_comparator <- p$scouting[['Matched play-by-play']]$estimates |> dplyr::filter(indicator == 'overallPhysicality')
  collected_on <- base::format(base::as.Date(p$inputs$provenance$collectedAt), '%B %d, %Y')
  report <- glue::glue('# Playing bigger through contact and puck play

Players make their presence felt through contact, puck recovery, and plays that create or protect space. We examine these forms of involvement among forwards and defensemen, bringing A3Z puck-play observations into CSAx alongside direct physical engagement.

> **<<a3z_definition>>**

We distinguish involvement in physical contests from effective puck play under pressure. Higher CSAx describes behavior associated with larger players after accounting for the listed frame. Its weights are learned from size prediction, so they do not necessarily reward successful execution.

## What the models show

The A3Z-integrated models use **<<scales::comma(forward_main$playerSeasons, accuracy = 1)>> forward-seasons and <<scales::comma(defense_main$playerSeasons, accuracy = 1)>> defenseman-seasons**. Compared with play-by-play models fitted on identical players and games, pooled predictive R² rises from **<<fixed(100 * defense_comparator$pooledR2)>>% to <<fixed(100 * defense_main$pooledR2)>>% for defensemen** and changes from **<<fixed(100 * forward_comparator$pooledR2)>>% to <<fixed(100 * forward_main$pooledR2)>>% for forwards**. The forward difference offers no predictive gain. Defensive performance varies substantially by season: the <<season_label(latest_defense$seasonId)>> model reduces squared prediction error relative to the training-mean baseline by only **<<fixed(100 * latest_defense$predictiveRSquared)>>%**, with a remaining CSAx–size correlation of **<<fixed(latest_defense$residualSizeCorrelation)>>**.

The learned weights expose an important conceptual limitation. Defensemen receive a positive median weight for botched retrievals and a negative weight for the possession share of successful exits. These are conditional associations with listed size. They cannot support interpreting higher CSAx as uniformly better puck play under pressure. A3Z expands what we observe, while the size-prediction target continues to determine what the score rewards.

Centers belong to the main forward model. In a separate exploratory comparison, **all <<center_count>> eligible center-seasons receive both wing-reference and defenseman-reference scores**. Of these, **<<base::sum(center_diagnostics$withinRanges)>>** have complete inputs within both training ranges, **<<base::sum(center_diagnostics$shareCounts)>>** have at least 20 opportunities for every modeled share under both references, and **<<base::sum(center_diagnostics$bothChecks)>>** meets both checks. These diagnostic subsets describe extrapolation and sparse opportunities within the scored sample. The comparison remains descriptive because most centers differ substantially from the defensive reference population.

## Data, coverage, and opportunity

We use the freely downloadable [A3Z transition workbook](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1), linked from the [official A3Z website](https://www.allthreezones.com/links.html). The extract collected on <<collected_on>> includes game-level microstats for all four behavior seasons. We retain regular-season observations from 2021–22 through 2024–25 and preserve the existing next-season outcome definitions through 2025–26.

<<markdown_table(source_games)>>

Eligibility requires 300 full-season NHL minutes and 150 matched five-on-five minutes. Published rankings additionally require 500 full-season minutes. NHL shift-derived time supplies the common denominator for NHL and A3Z count rates. Event numerators cover the same retained player-games; untracked observations are never filled with zero.

<<markdown_table(coverage_table)>>

The tracked sample retains **<<fixed(100 * base::mean(p$inputs$coverage$eligible))>>%** of the full-season eligible panel. Tracking covers every team but follows an uneven selection of games. Included skaters also have substantially greater full-season playing time. The pilot therefore represents a more established group, and its associations need not extend to players with limited NHL exposure.

<<markdown_table(characteristics)>>

We match source labels to NHL schedules and game rosters. Exact names take precedence over sweater numbers; roster names, surnames, and numbers resolve aliases and distinguish players with shared names, including both Sebastian Ahos and both Elias Petterssons. A nearby date is accepted only when a unique candidate within three days has at least 90% roster agreement. Ambiguous games remain excluded. Two December 14, 2024 labels contain opposite teams from the same Chicago–New Jersey game; their distinct player rows share one NHL game identifier. We collapse identical player-game duplicates and exclude conflicting copies. Original labels, match decisions, and row dispositions are retained in the analysis object.

We calculate time from the union of overlapping NHL shift intervals, preventing duplicate records from multiplying exposure. A player-game is excluded when its A3Z and NHL totals differ by more than 120 seconds; a game is excluded when the median absolute difference exceeds 60 seconds. These are source-consistency filters set before model fitting. They do not establish that every manually tracked event is complete or correctly classified.

<<markdown_table(exclusions)>>

## Direct engagement and positional indirect measures

Both positions use hits delivered, hits received, opponent shots blocked, fights, contact penalties taken, and contact penalties drawn per 60 matched five-on-five minutes. Contact penalties follow the existing whitelist: boarding, charging, checking from behind, clipping, elbowing, illegal head checks, kneeing, roughing, slew-footing, cross-checking, high-sticking, holding, holding the stick, hooking, and tripping, including recorded helmet-removal and double-minor variants. We count infractions; fighting has its own variable. Generic interference, slashing, attempted-contact categories, and administrative penalties remain excluded. Event-team attribution agrees with game rosters for the checked contact measures.

Forwards retain net-front unblocked-attempt share, tip/deflection share, median unblocked-shot distance, and backhand share. Net-front attempts lie between normalized x = 82 and 89 feet with |y| ≤ 8 feet; the denominator is all located unblocked attempts. Tips, deflections, and backhands use typed shots on net. The added A3Z measures are:

| Population | Measure | Calculation |
| --- | --- | --- |
| Forwards and wing reference | Dump-in recoveries | Recorded recoveries per 60 |
| Forwards and wing reference | Forecheck pressures | Recorded pressures per 60 |
| Forwards and wing reference | Forecheck/cycle shot assists | Recorded forecheck assists plus cycle assists, per 60 |
| Defensemen | Retrievals leading to exits | Recorded count per 60 |
| Defensemen | Botched retrievals | Recorded count per 60 |
| Defensemen | Possession exit share | Exits with possession / recorded successful exits |
| Defensemen | Entry denial share | Denials / targeted entries |

A3Z credits dump-in recoveries when a subsequent play follows recovery, and its exit tracking focuses on resistance from a forecheck. The possession-exit share describes how successful exits occur; failed exits are outside its denominator. Botched retrievals remain a rate because the failure categories do not provide an interchangeable set of attempt denominators. Forecheck/cycle assists can reflect skill and offensive role without establishing physical contact. [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html), [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve).

For defensemen, these four features replace the takeaway-location proxies. The matched play-by-play comparator retains those proxies and uses the same five-on-five observations. All undefined shares remain missing until training-sample imputation. Counts and denominators remain available alongside scores.

<<markdown_table(sparse_table)>>

## Estimation and held-out performance

We fit separate seasonal ridge models for all forwards, wings, and defensemen. Each system uses five outer folds and five inner tuning folds over the same 20 penalties from 0.0001 to 100. Training samples supply median imputation, zero-variance removal, Yeo–Johnson transformations, and normalization. Within each outer training sample, inner held-out predictions supply the linear frame calibration. Each reference player receives one excluded-sample prediction.

Listed size is the standardized combination of listed height and weight within the native season and reference population. CSAx is the calibrated prediction residual standardized against native held-out residuals. The A3Z and matched play-by-play models share players, games, folds, preprocessing procedures, and listed-size references; their fitted preprocessing parameters and residual scales belong to their respective specifications. Predictive R² compares held-out squared error with prediction by the outer-training mean. The pooled values below combine squared errors across seasons.

<<markdown_table(performance_table)>>

<<markdown_table(annual)>>

Direct and indirect reconstructions relearn weights and calibration using their respective feature blocks. The forward A3Z-only reconstruction uses the three microstats without shooting features. These comparisons assess information in each block; they do not establish that the blocks measure the same construct.

<<markdown_table(component_table)>>

Annual stability is lower for the A3Z-integrated scores than for the matched play-by-play scores across the forward and defenseman comparisons. The available game samples and changing fitted relationships both contribute potential uncertainty.

<<markdown_table(stability_table)>>

## What influences CSAx

Hits delivered retain the largest median standardized weight in both main positional models. Dump-in recoveries receive a positive forward weight, whereas forecheck pressure and forecheck/cycle shot assists have small negative medians. Among defensemen, retrievals leading to exits and entry denials contribute alongside botched retrievals and possession-exit share.

<<markdown_table(coefficient_table)>>

![Learned positional feature weights](figures/feature_weights.png)

Each coefficient summarizes transformed, standardized predictors and conditional size prediction. Botched retrievals receive positive weights despite recording unsuccessful execution, while possession-preserving exits receive negative weights in most fits. These directions can reflect differences in physical style and role. They leave higher CSAx without a uniform interpretation as more effective puck play.

For individual scores, we retain the exact decomposition into direct contribution, indirect contribution, and frame-calibration adjustment. The three terms sum to CSAx. The coefficient table reports medians across fits, so it is not a single scoring formula.

The following 2024–25 examples are selected by the largest absolute percentile changes among ranking-eligible skaters. Percentile changes describe relative standing within each positional sample. They are especially uncertain for defensemen because that season has weak size prediction and a remaining size gradient.

<<markdown_table(examples)>>

For the largest upward and downward moves in each position, the following decomposition shows how the fitted feature weights and frame adjustment combine. Contributions are in units of the corresponding reference score and sum to CSAx before rounding. Comparing the direct terms also reveals that adding indirect measures can change the weights and scaling of the shared contact variables.

<<markdown_table(contribution_table)>>

## Centers across positional references

The main forward model includes centers and wings, while the main defensive model contains defensemen. We use centers for an additional cross-position comparison: the forward feature specification trains on wings and the defensive specification trains on defensemen, excluding centers from both reference populations. All <<center_count>> eligible center-seasons receive one prediction from each matched assessment-fold fit. Reference populations supply size and residual scales; centers are never standardized separately.

We apply range, missingness, and opportunity diagnostics to every positional model. A range check compares listed height, weight, and modeled features with the observed minima and maxima in the assigned outer training sample. Complete inputs require no imputation. The opportunity check requires at least 20 recorded opportunities for every modeled share. This threshold identifies sparse denominators; reaching it does not establish reliable estimation. Marginal range overlap also cannot establish support for every combination of features.

<<markdown_table(diagnostics)>>

The rows represent overlapping applications: forwards include centers and wings, and the same centers appear under both external references. Every row counts scored player-seasons. Range and opportunity columns describe separate checks, while the final column counts their intersection. The checks retain all eligible scores and do not change the training populations.

For paired center comparisons, the following diagnostics require the relevant check to hold under both reference models. Correlations and mean percentile differences use every scored center in each season.

<<markdown_table(center_table)>>

![Center standing under wing and defenseman references](figures/center_standing.png)

Center profiles often lie beyond the defensive training ranges: <<center_ranges$entryShareOutside>> have an entry denial share outside the corresponding defenseman range, and <<center_ranges$botchedRateOutside>> have an out-of-range botched-retrieval rate. Most also have few targeted entries. Centers have a median of <<fixed(sparse_table$`Median targeted entries`[sparse_table$Position == "Centers"], 0L)>> targeted entries, compared with <<fixed(sparse_table$`Median targeted entries`[sparse_table$Position == "Defensemen"], 0L)>> for defensemen. These differences in opportunity and role limit interpretation of the comparison as positional consistency in playing bigger. Percentiles describe relative standing under separate models and do not measure differences in physicality on a common scale.

Shared-direct reconstructions show how much difference exists before position-specific indirect features enter:

<<markdown_table(center_direct)>>

The following center examples illustrate the overlap problem in 2024–25. Their percentiles remain descriptive outputs of the reference models, with the defensive opportunity counts shown alongside them.

<<markdown_table(center_examples)>>

## Scouting and next-season continuation

We retain all 40 frozen forward scouting ratings, with eligible pilot scores available for <<scouting_main$n>> rated players. Associations use their available seasonal means and the same observed players under both specifications. Overall-physicality Spearman correlation is **<<fixed(scouting_main$spearman)>>** for the A3Z-integrated score and **<<fixed(scouting_comparator$spearman)>>** for the matched play-by-play score. Interior-play associations remain weak. These ratings evaluate forward physical style and do not supply independent validation of defensive pressure-handling skill.

<<markdown_table(scouting_table)>>

Continuation means at least 300 NHL minutes in the following season. We retain listed size, age and age squared, games dressed, ice time per game, five-on-five scoring rate, relative shot attempts, and season controls. The comparison uses identical player-seasons under both specifications.

<<markdown_table(continuation_table)>>

![Conditional continuation associations](figures/continuation.png)

The A3Z defensive point estimate is larger, and the forward interval includes an odds ratio of one. These comparisons are descriptive; we do not estimate an interval for the difference between specifications. The reported intervals are player-clustered HC1 intervals conditional on the estimated scores and tracked sample. They omit uncertainty from reconstructing CSAx and should not be read as full-pipeline inference or evidence of a causal effect. A continuation association cannot resolve whether the score measures successful physical play.

## Other candidate measures and research direction

The NHL event record offers useful extensions within its limits. Block locations can distinguish interior shot-block involvement within the direct component. Interior attempts and rebounds provide further evidence of offensive involvement, although shot location and shot type also reflect deployment. Backhand share alone cannot distinguish a contested play from an open-ice opportunity.

Short sequences after hits or takeaways provide much weaker foundations for individual pressure-handling measures. Personal follow-up events are sparse, and the next recorded team event does not establish continuous possession or identify which player protects the puck. Off-puck net-front defense, contested-recovery success, and sustained puck protection remain unobserved in ordinary play-by-play. We therefore prioritize the available A3Z observations for subsequent work.

The pilot supports keeping A3Z in the research program, especially for defensive retrieval and exit context. It also gives a concrete reason to separate the broad hockey idea from the present scalar score. Our next decision concerns the target: retain CSAx as size-associated physical style, or develop a separately validated measure of successful play under pressure. The current results do not support presenting the expanded CSAx as both at once.

For an engagement-focused CSAx, we need to establish repeatable signal in the indirect component and understand team-role effects before expanding downstream applications. For a success-focused measure, we need defensible outcome and opportunity definitions, with direction determined by successful execution and an explicit approach to accounting for size. The exploratory center comparison requires better overlap with the reference population or a narrower question about shared behaviors. A future study may concentrate on the main forward and defenseman models, keeping centers within forwards and omitting the cross-position comparison. The present analysis retains both applications.

A defensible next step is to present CSAx as size-associated physical style alongside the observed retrieval and exit measures. A separate execution measure becomes worthwhile if successful play under pressure is central to the research question. We can then evaluate its validity directly, without relying on size prediction to establish whether a play is successful.

We defer additional feature searches, another full-pipeline bootstrap campaign, and A3Z-based contract, playoff, career-stage, and team-outcome analyses until the construct and specification are settled. The full-season play-by-play analysis remains a labeled benchmark in the analysis object and accompanying exports; its stored bootstrap intervals belong to that specification.

## Reproduction and source attribution

The numbered R workflow restores frozen inputs, rebuilds the matched models, estimates the pilot associations, and regenerates this report. The compact analysis object includes source rows, game mappings, exclusions, denominators, source hashes, fitted summaries, and the full-season benchmark. Frozen scouting ratings remain separate from derived scores. A3Z observations are credited to Corey Sznajder / All Three Zones; NHL inputs use the pinned nhlscraper revision. Third-party materials retain their source terms.

The accompanying files contain [player rankings](player_rankings.csv), [center comparisons](center_comparisons.csv), [center agreement](center_agreement.csv), [team coverage and benchmark summaries](team_summaries.csv), and [application estimates](application_estimates.csv). Every specification and reference population is identified. Benchmark-only applications remain distinguishable from pilot results.

The Sloan abstract deadline is October 1, 2026; invited papers are due December 4. Current guidance requires actual results and an open-source repository link. The research repository remains private pending a separate public-release decision. [Sloan research competition](https://www.sloansportsconference.com/research-paper-competition).
', .open = '<<', .close = '>>')
  readr::write_file(report, base::file.path(report_directory, 'research_summary.md'))
  base::message('Wrote A3Z findings, matched comparisons, and labeled benchmark outputs.')
}

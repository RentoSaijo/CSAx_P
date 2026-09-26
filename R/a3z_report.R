# Positional Physicality Report -------------------------------------------

# Define feature meanings, exposure, and construct qualifications.
physicality_feature_dictionary <- function() {
  tibble::tribble(
    ~feature, ~component, ~population, ~label, ~measurement, ~rationale,
    'hitsPer60', 'Direct', 'Both', 'Hits delivered', 'NHL hits credited to hitter, per 60', 'Initiating recorded contact; opportunities depend on possession and deployment.',
    'hitsReceivedPer60', 'Direct', 'Both', 'Hits received', 'NHL hits credited to recipient, per 60', 'Exposure to contact; receiving a hit does not establish active engagement.',
    'blockedShotsPer60', 'Direct', 'Both', 'Opponent shots blocked', 'NHL opponent attempts credited to blocker, per 60', 'Intervention in a shot path; recorded blocks do not uniformly imply body contact.',
    'fightsPer60', 'Direct', 'Both', 'Fights', 'Recorded fighting infractions, per 60', 'Confrontation with an opponent; counts are sparse.',
    'contactPenaltiesTakenPer60', 'Direct', 'Both', 'Contact penalties taken', 'Whitelisted infractions credited to offender, per 60', 'Contact-related behavior; disciplinary acts are distinct from effective play.',
    'contactPenaltiesDrawnPer60', 'Direct', 'Both', 'Contact penalties drawn', 'Whitelisted infractions credited to recipient, per 60', 'Opponents’ contact-related infractions; puck possession and skill affect exposure.',
    'netFrontAttemptShare', 'Indirect', 'Forwards', 'Net-front attempt share', 'Unblocked attempts in 82 ≤ x ≤ 89 and absolute y ≤ 8 feet / located unblocked attempts', 'Shooting involvement near interior space; location alone does not confirm pressure.',
    'deflectionShare', 'Indirect', 'Forwards', 'Tip/deflection share', 'Tips and deflections / typed shots on goal, including goals', 'Redirection opportunities often involve traffic; tactical role affects opportunities.',
    'medianShotDistance', 'Indirect', 'Forwards', 'Median shot distance', 'Median distance from net for located unblocked attempts, in feet', 'Proximity of shooting involvement to net; this is a broad positional proxy.',
    'backhandShare', 'Indirect', 'Forwards', 'Backhand share', 'Backhands / typed shots on goal, including goals', 'Possible constrained shooting situations; open-ice backhands also contribute.',
    'dumpInRecoveriesPer60', 'Indirect', 'Forwards', 'Dump-in recoveries', 'A3Z Recoveries, per 60', 'Recovering possession and making a subsequent play during forechecking sequences.',
    'forecheckPressuresPer60', 'Indirect', 'Forwards', 'Forecheck pressures', 'A3Z Forecheck Pressures, per 60', 'Forcing an exiting opponent to act; a hit is not required.',
    'defensiveRetrievalsPer60', 'Indirect', 'Defensemen', 'Clean defensive-zone retrievals', 'A3Z DZ Retrievals, per 60', 'Recovering possession and making a subsequent play; workload and team systems affect frequency.',
    'botchedRetrievalsPer60', 'Indirect', 'Defensemen', 'Botched retrievals', 'A3Z Botched Retrievals, per 60', 'Retrieval-related breakdowns reflect execution and workload; attribution can involve a receiver.',
    'entryDenialShare', 'Indirect', 'Defensemen', 'Entry denial share', 'A3Z Denials / Targets', 'Preventing zone entry; gap control, skating, and tactics also contribute.'
  )
}

# Write primary results, measurement diagnostics, and submission documents.
write_a3z_report <- function(analysis, report_directory, figure_directory) {
  p <- analysis$a3z
  if (!base::identical(p$settings$version, a3z_version)) base::stop('Current positional physicality results are required.', call. = FALSE)
  applications <- p$applications
  if (base::is.null(applications)) base::stop('Completed deployment and postseason applications are required.', call. = FALSE)
  features <- p$inputs$features
  dictionary <- physicality_feature_dictionary()
  labels <- stats::setNames(dictionary$label, dictionary$feature)
  count_columns <- base::c('hits', 'hitsReceived', 'blockedShots', 'fights', 'contactPenaltiesTaken', 'contactPenaltiesDrawn', 'unblockedAttempts', 'locatedAttempts', 'netFrontAttempts', 'typedShotsOnNet', 'backhandShots', 'deflectionShots')
  feature_values <- features |> dplyr::select(playerId, seasonId, height, weight, dplyr::all_of(base::setdiff(base::names(a3z_source_columns), 'sourceMinutes')), dplyr::all_of(count_columns), dplyr::all_of(dictionary$feature))
  write_table <- function(data, file, digits = 6L) readr::write_csv(data |> dplyr::mutate(dplyr::across(dplyr::where(base::is.double), ~ base::round(.x, digits))), base::file.path(report_directory, file))

  # Export native rankings with source counts and interpretation flags.
  rankings <- p$predictions |>
    dplyr::filter(timeOnIce >= 500 * 60) |>
    dplyr::left_join(feature_values, by = base::c('playerId', 'seasonId')) |>
    dplyr::left_join(p$performance |> dplyr::select(model, seasonId, scoreCaution), by = base::c('model', 'seasonId')) |>
    dplyr::group_by(model, seasonId) |>
    dplyr::arrange(dplyr::desc(CSAx), playerId, .by_group = TRUE) |>
    dplyr::mutate(rank = dplyr::row_number(), season = season_label(seasonId), minutes = timeOnIce / 60) |>
    dplyr::ungroup() |>
    dplyr::rename(player = playerFullName, heightInches = height, weightPounds = weight) |>
    dplyr::select(-rowId, -timeOnIce, -directRaw, -indirectRaw, -intercept, -isCenterComparison) |>
    dplyr::relocate(specification, model, referencePopulation, eventScope, season, seasonId, rank, playerId, player)
  write_table(rankings, 'player_rankings.csv', digits = 2L)
  # Describe tracking coverage while counting centers once with forwards.
  tracked_teams <- p$inputs$sourceRows |>
    dplyr::filter(rowStatus == 'Retained') |>
    dplyr::left_join(features |> dplyr::select(playerId, seasonId, positionCode), by = base::c('playerId', 'seasonId')) |>
    dplyr::mutate(model = dplyr::if_else(dplyr::coalesce(positionCode, rosterPosition) == 'D', 'Defensemen', 'Forwards')) |>
    dplyr::group_by(seasonId, teamId, model) |>
    dplyr::summarise(trackedGames = dplyr::n_distinct(gameId), trackedPlayers = dplyr::n_distinct(playerId), eligiblePlayers = dplyr::n_distinct(playerId[!base::is.na(positionCode)]), trackedPlayerMinutes = base::sum(nhlSeconds) / 60, .groups = 'drop') |>
    dplyr::left_join(analysis$inputs$teams |> dplyr::select(teamId, teamTriCode), by = 'teamId') |>
    dplyr::mutate(specification = a3z_specification, referencePopulation = model, eventScope = a3z_scope, summaryType = 'Tracking coverage')
  write_table(applications$engagement$panel |> dplyr::mutate(specification = a3z_specification, eventScope = a3z_scope, outcomeScope = 'NHL five on five; disjoint regular-season baseline and playoffs', referencePopulation = model, roleTiming = 'Current regular season'), 'postseason_engagement.csv')
  application_export <- dplyr::bind_rows(
    p$continuation |> dplyr::mutate(statistic = 'Odds ratio per CSAx SD'),
    p$continuationProbabilities |> dplyr::mutate(outcome = 'Next-season continuation', statistic = 'Adjusted continuation probability (%)', scale = 'percentage points', effect = 100 * probability, effectLow = 100 * confLow, effectHigh = 100 * confHigh),
    p$continuationContrasts |> dplyr::mutate(outcome = 'Next-season continuation', statistic = 'Probability difference: CSAx +1 minus -1', scale = 'percentage points', effect = 100 * estimate, effectLow = 100 * confLow, effectHigh = 100 * confHigh),
    p$scouting$estimates |> dplyr::mutate(specification = a3z_specification, eventScope = a3z_scope, outcomeScope = 'Independent scouting passages predating included NHL seasons', outcome = 'Scouting physicality description', statistic = 'Mean CSAx difference: mention minus no mention', scale = 'CSAx units', effect = estimate, effectLow = confLow, effectHigh = confHigh),
    applications$roleTiming$estimates |> dplyr::mutate(statistic = 'Odds ratio per CSAx SD'),
    applications$roleTiming$probabilities |> dplyr::mutate(outcome = 'Next-season continuation', statistic = 'Adjusted continuation probability (%)', scale = 'percentage points', effect = 100 * probability, effectLow = 100 * confLow, effectHigh = 100 * confHigh),
    applications$roleTiming$contrasts |> dplyr::mutate(outcome = 'Next-season continuation', statistic = 'Probability difference: CSAx +1 minus -1', scale = 'percentage points', effect = 100 * estimate, effectLow = 100 * confLow, effectHigh = 100 * confHigh),
    applications$deployment$estimates,
    applications$engagement$estimates,
    applications$engagement$rateChanges,
    applications$engagement$descriptive |> dplyr::mutate(statistic = 'Observed event rate per 60', scale = 'events per 60', effect = ratePer60, intervalMethod = 'Descriptive; no interval')
  )
  write_table(application_export, 'application_estimates.csv')

  # Summarize population coverage and held-out prediction performance.
  pooled <- p$performance |>
    dplyr::group_by(model) |>
    dplyr::summarise(playerSeasons = base::sum(n), pooledRmse = base::sqrt(base::sum(n * rmse^2) / base::sum(n)), pooledR2 = 1 - base::sum(n * rmse^2) / base::sum(n * baselineRmse^2), .groups = 'drop')
  performance_table <- pooled |> dplyr::transmute(Reference = model, 'Player-seasons' = base::as.character(playerSeasons), RMSE = pooledRmse, 'Predictive R² (%)' = 100 * pooledR2)
  coverage_table <- p$inputs$coverage |> dplyr::group_by(seasonId, positionGroup) |>
    dplyr::summarise(originalN = dplyr::n(), retainedN = base::sum(eligible), medianGames = stats::median(trackedGames[eligible]), medianMinutes = stats::median(trackedMinutes[eligible]), .groups = 'drop') |>
    dplyr::transmute(Season = season_label(seasonId), Position = positionGroup, 'Full-season eligible' = base::as.character(originalN), Included = base::as.character(retainedN), 'Included (%)' = 100 * retainedN / originalN, 'Median tracked games' = base::as.character(medianGames), 'Median tracked minutes' = medianMinutes)
  characteristics <- p$inputs$coverage |> dplyr::group_by(positionGroup, eligible) |>
    dplyr::summarise(n = dplyr::n(), height = base::mean(height), weight = base::mean(weight), minutes = stats::median(timeOnIce / 60), .groups = 'drop') |>
    dplyr::transmute(Position = positionGroup, Sample = dplyr::if_else(eligible, 'Included', 'Below tracking eligibility'), 'Player-seasons' = base::as.character(n), 'Mean height (in)' = height, 'Mean weight (lb)' = weight, 'Median full-season minutes' = minutes)
  source_games <- p$inputs$sourceRows |> dplyr::filter(rowStatus == 'Retained') |> dplyr::group_by(seasonId) |>
    dplyr::summarise(games = dplyr::n_distinct(gameId), teams = dplyr::n_distinct(teamId), medianDifference = stats::median(base::abs(deltaSeconds)), .groups = 'drop') |>
    dplyr::left_join(tracked_teams |> dplyr::group_by(seasonId) |> dplyr::summarise(teamGameRange = base::paste(base::range(trackedGames), collapse = ' to '), .groups = 'drop'), by = 'seasonId') |>
    dplyr::transmute(Season = season_label(seasonId), 'Matched games' = base::as.character(games), Teams = base::as.character(teams), 'Tracked games per team' = teamGameRange, 'Median exposure difference (seconds)' = medianDifference)
  annual <- p$performance |> dplyr::transmute(Season = season_label(seasonId), Reference = model, 'Predictive R² (%)' = 100 * predictiveRSquared, 'CSAx–size correlation' = residualSizeCorrelation)
  stability_table <- p$stability |> dplyr::group_by(model) |>
    dplyr::summarise(pairs = base::paste(base::range(n), collapse = ' to '), spearmanRange = base::paste(fixed(base::range(spearman)), collapse = ' to '), .groups = 'drop') |>
    dplyr::rename(Reference = model, 'Players per annual comparison' = pairs, 'Annual Spearman range' = spearmanRange)

  # Summarize learned weights and exact additive score contributions.
  coefficients <- p$coefficients |> dplyr::group_by(model, feature, component) |>
    dplyr::summarise(medianCoefficient = stats::median(coefficient), positiveFolds = base::sum(coefficient > 0), negativeFolds = base::sum(coefficient < 0), .groups = 'drop')
  coefficient_table <- coefficients |> dplyr::arrange(base::match(feature, dictionary$feature)) |>
    dplyr::mutate(Measure = base::unname(labels[feature])) |>
    dplyr::select(Component = component, Measure, model, medianCoefficient) |>
    tidyr::pivot_wider(names_from = model, values_from = medianCoefficient)
  examples <- rankings |> dplyr::filter(seasonId == base::max(xs_behavior_seasons)) |>
    dplyr::group_by(model) |> dplyr::filter(rank <= 2L | rank > dplyr::n() - 2L) |> dplyr::ungroup() |>
    dplyr::transmute(Position = model, Player = player, 'Tracked games' = base::as.character(trackedGames), CSAx, Percentile = referencePercentile, Direct = directContribution, Indirect = indirectContribution, 'Frame adjustment' = frameAdjustment, 'Season caution' = scoreCaution)
  sparse_table <- features |> dplyr::mutate(Position = dplyr::if_else(positionCode == 'D', 'Defensemen', 'Forwards')) |>
    dplyr::group_by(Position) |>
    dplyr::summarise('Median fights' = stats::median(fights), 'Median targeted entries' = stats::median(entryTargets), 'Median clean retrievals' = stats::median(defensiveRetrievals), 'Median botched retrievals' = stats::median(botchedRetrievals), 'Median dump-in recoveries' = stats::median(dumpInRecoveries), .groups = 'drop')

  # Keep inclusion, range overlap, and denominator warnings separate.
  diagnostics <- p$predictions |>
    dplyr::mutate(scoredGroup = model, completeInputs = imputedFeatures == 0L, withinRanges = !outsideTrainingRange & completeInputs, shareCounts = !base::nzchar(sparseDenominators)) |>
    dplyr::group_by(scoredGroup, model) |>
    dplyr::summarise(scored = dplyr::n(), complete = base::sum(completeInputs), ranges = base::sum(withinRanges), shares = base::sum(shareCounts), both = base::sum(withinRanges & shareCounts), .groups = 'drop') |>
    dplyr::arrange(base::match(scoredGroup, base::c('Forwards', 'Defensemen')), model) |>
    dplyr::transmute('Scored group' = scoredGroup, Reference = model, Scored = base::as.character(scored), 'Complete inputs' = base::as.character(complete), 'Within ranges and complete' = base::as.character(ranges), 'Every share ≥20' = base::as.character(shares), 'Both checks' = base::as.character(both))
  # Summarize historical center overlap using unchanged reference diagnostics.
  centers <- analysis$a3zCenterBenchmark$centers
  center_diagnostics <- base::list(n = base::nrow(centers), medianTargets = stats::median(features$entryTargets[features$positionCode == 'C']), defenseTargets = stats::median(features$entryTargets[features$positionCode == 'D']), outsideDenial = base::sum(stringr::str_detect(centers$outsideFeatures_Defensemen, 'entryDenialShare')), completeWithinRanges = base::sum(centers$withinTrainingRanges & centers$imputedFeatures_Wings == 0L & centers$imputedFeatures_Defensemen == 0L))
  # Present external descriptions and adjusted continuation probabilities.
  scouting_table <- p$scouting$estimates |>
    dplyr::transmute(Position = model, Players = base::as.character(n), Mentions = base::as.character(positiveReports), 'No mention' = base::as.character(absentReports), Spearman = spearman, 'Mean CSAx difference (95% CI)' = interval(estimate, confLow, confHigh), 'Contrast status' = contrastStatus)
  scout_forward <- p$scouting$estimates |> dplyr::filter(model == 'Forwards')
  scout_defense <- p$scouting$estimates |> dplyr::filter(model == 'Defensemen')
  continuation_table <- p$continuation |> dplyr::transmute(Position = model, 'Player-seasons' = base::as.character(sampleSize), 'Odds ratio per CSAx SD (95% CI)' = interval(effect, effectLow, effectHigh, 3L), 'p-value' = p_value(pValue))
  probability_table <- p$continuationProbabilities |>
    dplyr::transmute(Position = model, CSAx, 'Adjusted continuation probability (%)' = 100 * probability, '95% CI (%)' = base::paste(fixed(100 * confLow), fixed(100 * confHigh), sep = ' to '))
  scouting_text <- if (p$scouting$expansionComplete) {
    glue::glue('The scouting collection comprises 40 frozen forward ratings and {p$scouting$completedNewPlayers} additional ratings covering {p$scouting$plannedNewForwards} forwards and {p$scouting$plannedNewDefensemen} defensemen. All use the same active-engagement coding rules and are locked before linkage to CSAx. We evaluate {dplyr::n_distinct(p$scouting$scores$playerId)} eligible players: {scout_forward$n} forwards and {scout_defense$n} defensemen. The original collection contributes 39 players; Matthew Poitras has 148.88 matched minutes in his best-covered season and falls below tracking eligibility.')
  } else {
    glue::glue('The current associations use {dplyr::n_distinct(p$scouting$scores$playerId)} eligible players from the 40 frozen forward ratings. We reuse their active-engagement codes. Matthew Poitras falls below tracking eligibility, with 148.88 matched minutes in his best-covered season. An additional {p$scouting$plannedNewPlayers} verified passages cover {p$scouting$plannedNewForwards} forwards and {p$scouting$plannedNewDefensemen} defensemen. These passages await human coding and locking. Expanded validation and completion of the submission abstract depend on those ratings; the table below describes only available codes.')
  }

  # Present role timing, deployment, and paired postseason applications.
  role_table <- applications$roleTiming$estimates |>
    dplyr::transmute(Position = model, 'Role timing' = roleTiming, 'Player-seasons' = base::as.character(sampleSize), 'Odds ratio (95% CI)' = interval(effect, effectLow, effectHigh), 'p-value' = p_value(pValue))
  role_probabilities <- applications$roleTiming$probabilities |>
    dplyr::transmute(Position = model, 'Role timing' = roleTiming, CSAx, 'Adjusted continuation probability (%)' = 100 * probability, '95% CI (%)' = base::paste(fixed(100 * confLow), fixed(100 * confHigh), sep = ' to '))
  deployment_table <- applications$deployment$estimates |>
    dplyr::transmute(Position = model, Unit = dplyr::recode(outcome, powerPlayShare = 'Power play', penaltyKillShare = 'Penalty kill'), 'Player-seasons' = base::as.character(sampleSize), 'Mean TOI share (%)' = meanShare, Spearman = spearman, 'Adjusted percentage points per CSAx SD (95% CI)' = interval(effect, effectLow, effectHigh))
  engagement_labels <- base::c(hits = 'Hits delivered', hitsReceived = 'Hits received', blockedShots = 'Opponent shots blocked', fights = 'Fights', contactPenaltiesTaken = 'Contact penalties taken', contactPenaltiesDrawn = 'Contact penalties drawn')
  selection_table <- applications$engagement$selection |>
    dplyr::transmute(Window = window, Position = model, 'Scored player-seasons' = base::as.character(scoredPlayerSeasons), 'Positive playoff exposure' = base::as.character(playoffParticipants), 'Paired positive exposure' = base::as.character(pairedPlayerSeasons))
  engagement_table <- applications$engagement$estimates |>
    dplyr::transmute(Window = window, Position = model, Measure = base::unname(engagement_labels[outcome]), 'Informative pairs' = base::as.character(sampleSize), 'Zero-total pairs' = base::as.character(zeroTotalStrata), 'Rate-ratio multiplier per CSAx SD (95% CI)' = interval(effect, effectLow, effectHigh))
  rate_table <- applications$engagement$rateChanges |> dplyr::filter(outcome == 'hits') |>
    dplyr::transmute(Window = window, Position = model, CSAx, 'Adjusted postseason/baseline rate ratio (95% CI)' = interval(effect, effectLow, effectHigh), 'Rate change (%)' = rateChangePercent)
  descriptive_contacts <- applications$engagement$descriptive |> dplyr::filter(window == 'First four') |>
    dplyr::transmute(Position = model, Period = period, Measure = base::unname(engagement_labels[outcome]), Events = base::as.character(count), 'Five-on-five minutes' = exposureSeconds / 60, 'Events per 60' = ratePer60)
  window_coverage <- p$applicationInputs$teamGames |> dplyr::group_by(seasonId) |>
    dplyr::summarise(construction = dplyr::n_distinct(gameId[scoreConstructionGame]), baselineGames = dplyr::n_distinct(gameId[baseline]), firstFourGames = dplyr::n_distinct(gameId[firstFour]), fullPlayoffGames = dplyr::n_distinct(gameId[gameTypeId == 3L]), .groups = 'drop') |>
    dplyr::transmute(Season = season_label(seasonId), 'Excluded construction games' = base::as.character(construction), 'Available baseline games' = base::as.character(baselineGames), 'First-four playoff games' = base::as.character(firstFourGames), 'Full playoff games' = base::as.character(fullPlayoffGames))
  primary_forward_hits <- applications$engagement$estimates |> dplyr::filter(model == 'Forwards', outcome == 'hits', window == 'First four')
  primary_defense_hits <- applications$engagement$estimates |> dplyr::filter(model == 'Defensemen', outcome == 'hits', window == 'First four')

  # Draw gridless figures for weights and continuation.
  coefficient_plot <- coefficients |>
    dplyr::mutate(featureLabel = base::factor(labels[feature], levels = base::rev(base::unname(labels)))) |>
    ggplot2::ggplot(ggplot2::aes(medianCoefficient, featureLabel, color = component)) +
    ggplot2::geom_vline(xintercept = 0, color = '#BBBBBB', linewidth = 0.4) +
    ggplot2::geom_point(size = 2.7) + ggplot2::scale_x_continuous(labels = scales::label_number(accuracy = 0.01)) + ggplot2::facet_wrap(~model, scales = 'free_y', ncol = 1L) +
    ggplot2::scale_color_manual(values = base::c(Direct = '#17324D', Indirect = '#BD7C27')) +
    ggplot2::labs(title = 'Physicality features and listed-size prediction', subtitle = 'Median standardized coefficient across 20 outer fits per reference', x = 'Coefficient in listed-size units', y = NULL, color = NULL) + research_theme()
  ggplot2::ggsave(base::file.path(figure_directory, 'feature_weights.png'), coefficient_plot, width = 9, height = 8, dpi = 180, bg = 'white')
  continuation_plot <- ggplot2::ggplot(p$continuationProbabilities, ggplot2::aes(CSAx, 100 * probability)) +
    ggplot2::geom_line(color = '#17324D', linewidth = 0.7) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = 100 * confLow, ymax = 100 * confHigh), width = 0.10, color = '#17324D') +
    ggplot2::geom_point(color = '#BD7C27', size = 2.7) + ggplot2::facet_wrap(~model) +
    ggplot2::scale_x_continuous(breaks = base::c(-1, 0, 1)) +
    ggplot2::labs(title = 'Physicality profile and next-season continuation', subtitle = '95% player-clustered intervals conditional on estimated scores and sample', x = 'CSAx within positional reference', y = 'Adjusted probability of at least 300 NHL minutes (%)') + research_theme()
  ggplot2::ggsave(base::file.path(figure_directory, 'continuation.png'), continuation_plot, width = 9, height = 5, dpi = 180, bg = 'white')

  # Draw primary postseason rate changes.
  engagement_plot <- applications$engagement$rateChanges |> dplyr::filter(outcome == 'hits') |>
    ggplot2::ggplot(ggplot2::aes(CSAx, effect, color = window, group = window)) +
    ggplot2::geom_hline(yintercept = 1, color = '#BBBBBB', linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = effectLow, ymax = effectHigh), width = 0.08) +
    ggplot2::geom_point(ggplot2::aes(shape = window), size = 2.5) + ggplot2::facet_wrap(~model) +
    ggplot2::scale_color_manual(values = base::c('First four' = '#17324D', 'Full postseason' = '#BD7C27')) +
    ggplot2::scale_x_continuous(breaks = base::c(-1, 0, 1)) +
    ggplot2::labs(title = 'Changes in hits delivered during postseason play', subtitle = 'Adjusted rate ratios; conditional player-clustered 95% intervals', x = 'CSAx within positional reference', y = 'Postseason / baseline hits per 60', color = NULL, shape = NULL) + research_theme()
  ggplot2::ggsave(base::file.path(figure_directory, 'postseason_engagement.png'), engagement_plot, width = 9, height = 5, dpi = 180, bg = 'white')
  # Report observed results without treating size prediction as construct validation.
  forward <- pooled |> dplyr::filter(model == 'Forwards')
  defense <- pooled |> dplyr::filter(model == 'Defensemen')
  latest_defense <- p$performance |> dplyr::filter(model == 'Defensemen', seasonId == base::max(xs_behavior_seasons))
  feature_table <- dictionary |> dplyr::transmute(Component = component, Population = population, Measure = label, 'Source and denominator' = measurement, 'Rationale and qualification' = rationale)
  exclusions <- p$inputs$sourceRows |> dplyr::count(rowStatus) |> dplyr::transmute(Disposition = rowStatus, 'Player-game rows' = base::as.character(n))
  report <- glue::glue('# Playing tougher for one’s size

Physical play takes several forms, from delivering contact to competing for possession in crowded areas. We study those behaviors relative to a player’s listed frame, using separate forward and defenseman references.

> **<<p$settings$definition>>**

Higher CSAx describes playing tougher for one’s size; playing softer for one’s size describes the corresponding lower end of this measured continuum. The score does not establish courage, overall ability, or successful play under pressure. Its weights identify behaviors associated with listed size, so an error count can receive a positive coefficient and a useful skill can receive a negative one.

## Study population and observations

We combine NHL events and shift-derived five-on-five exposure with Corey Sznajder’s All Three Zones (A3Z) player-game records. Behavior seasons span 2021–22 through 2024–25, with next-season continuation observed through 2025–26. Eligibility requires 300 full-season NHL minutes and 150 matched tracked minutes. Published rankings require 500 full-season minutes.

The analysis contains **<<forward$playerSeasons>> forward-seasons** and **<<defense$playerSeasons>> defenseman-seasons**. Centers remain in the main forward model.

<<markdown_table(coverage_table)>>

<<markdown_table(source_games)>>

Tracked games cover all 32 teams in each season, with uneven selection and exposure. Listed frame and playing time also differ between included and excluded observations:

<<markdown_table(characteristics)>>

Game identities use NHL schedules and rosters. Player matching uses names, teams, and sweater numbers, including distinct players with shared names. Identical duplicate player-game records collapse; conflicting duplicates and unresolved or incompatible records remain excluded. Counts, original labels, exposure differences, and exclusions remain in the analysis object.

<<markdown_table(exclusions)>>

The [A3Z data dictionary](a3z_data_dictionary.md) inventories all 95 source fields, their coverage, definitions, and unresolved labels. These records are player-game aggregates without linked possession sequences or event timestamps.

## Direct and indirect physicality

The six direct measures are shared across positions. Forwards use six indirect measures; defensemen use three. Count rates use matched NHL five-on-five minutes, and undefined shares remain missing before training-sample imputation.

<<markdown_table(feature_table)>>

Shot coordinates are normalized to attacking direction. The net-front region extends seven feet in front of the goal line and eight feet to either side of the center line. Located unblocked attempts include goals, saved shots, and misses; shot-type shares use only typed goals and shots on goal.

The contact-penalty whitelist covers boarding, charging, checking from behind, clipping, elbowing, illegal checks to the head, kneeing, roughing, slew-footing, cross-checking, high-sticking, holding, holding the stick, hooking, and tripping, including the corresponding helmet-removal and double-minor variants. We count recorded infractions and keep fighting separate. Generic interference, slashing, attempted contact, and administrative infractions fall outside this definition. [NHL rules](https://media.nhl.com/site/asset/public/ext/2023-24/2023-24Rulebook.pdf).

A3Z retrieval and forechecking measures provide information about recovering possession and responding to pressure. Their counts also reflect deployment, team systems, and opportunities. Clean and botched retrievals do not supply an established common attempt denominator, and a botched event can be attributed to a receiver. Entry denial can result from skating, anticipation, and stick positioning. We therefore treat defensive indirect physicality as a construct requiring external evidence. [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html), [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve).

## Estimation and predictive performance

We fit one selected specification for each reference population and season. Listed size combines standardized height and weight within the native reference. Five outer folds yield one excluded-sample prediction per player-season; five inner folds select ridge penalties from the fixed 20-value grid. Preprocessing, imputation, predictor transformations, and linear frame calibration use training observations. Calibration uses inner held-out predictions within the outer training sample.

Native excluded-sample residuals provide seasonal score means, standard deviations, and percentile references. Feature weights and additive contributions come from the same fitted models; component-only and alternative-specification fits are outside the active workflow.

<<markdown_table(performance_table)>>

Predictive R² compares held-out squared error with an outer-training mean-size prediction. A value below zero means the model performs worse than that baseline. Across seasons, forward and defenseman models explain **<<fixed(100 * forward$pooledR2)>>%** and **<<fixed(100 * defense$pooledR2)>>%** of held-out variation by this measure. These are checks on the expected-size model, not independent proof of toughness.

<<markdown_table(annual)>>

The 2024–25 defenseman model has predictive R² of **<<fixed(100 * latest_defense$predictiveRSquared)>>%**, with CSAx–size correlation **<<fixed(latest_defense$residualSizeCorrelation)>>**. Its weak size prediction and remaining size gradient limit confidence in that season’s defensive ordering.

<<markdown_table(stability_table)>>

Annual correlations describe rank persistence among players eligible in consecutive seasons. Persistence can reflect stable role and opportunity as well as behavior; it does not estimate the precision of every individual score.

## Learned weights and player profiles

<<markdown_table(coefficient_table)>>

Coefficients are median fitted weights across the 20 outer fits for each reference. Predictors are transformed and scaled to unit training-sample standard deviation. The weights describe conditional size prediction; a positive botched-retrieval coefficient does not imply that unsuccessful execution is desirable.

![Physicality features and listed-size prediction](figures/feature_weights.png)

Each score equals its direct contribution, indirect contribution, and frame adjustment. The adjustment includes the intercept, expected prediction for listed size, and reference centering. These terms remain visible in the 2024–25 examples below, which show the two highest and two lowest eligible scores in each main positional ranking.

<<markdown_table(examples)>>

The defensive examples carry the seasonal prediction caution. Percentiles describe standing within a positional reference; they do not provide a common forward–defenseman physicality scale.

## Positional measurement diagnostics

<<markdown_table(diagnostics)>>

The forward population includes centers and wings. Range and denominator columns describe warnings within the included sample. Twenty share opportunities is a caution threshold and does not establish reliability.

<<markdown_table(sparse_table)>>

The historical cross-position exercise scores all <<center_diagnostics$n>> eligible center-seasons against wing and defenseman references. Centers have a median of **<<center_diagnostics$medianTargets>> targeted entries**, compared with **<<center_diagnostics$defenseTargets>> for defensemen**. Among those center-seasons, **<<center_diagnostics$outsideDenial>> of <<center_diagnostics$n>>** have entry-denial shares outside their defensive training range, and only **<<center_diagnostics$completeWithinRanges>>** have complete inputs within both references’ ranges. These opportunity differences make the comparison difficult to interpret as physical style. We therefore use the main forward and defenseman models for the paper. Every eligible center remains in the forward model; the diagnostic counts do not represent exclusions from that model.

## Independent scouting descriptions

<<scouting_text>>

<<markdown_table(scouting_table)>>

Descriptions of active physical engagement align with higher player-average CSAx in both positions. Spearman correlations are **<<fixed(scout_forward$spearman)>>** for forwards and **<<fixed(scout_defense$spearman)>>** for defensemen. Players with a positive code average **<<interval(scout_forward$estimate, scout_forward$confLow, scout_forward$confHigh)>>** higher CSAx among forwards and **<<interval(scout_defense$estimate, scout_defense$confLow, scout_defense$confHigh)>>** among defensemen, with 95% conditional intervals. This agreement supplies independent evidence about the physicality interpretation, while the smaller defensive cohort leaves greater uncertainty about its magnitude.

A single human rater codes active physical engagement while blinded to identities, scores, and rankings. The source collection comprises official NHL scouting publications from 2018–2024. Profiles are matched to individual NHL identities and draft years before inclusion, regardless of score or physicality wording. The 2024 source date uses its PDF creation timestamp; the exact publication day is unavailable.

Player-average scores use eligible seasons following the source report. A zero code records absence of the specified description; it does not establish soft play. Mean differences compare players with and without the description. Their HC1 intervals condition on the estimated scores and observed scouting cohort. Draft-era prose, prospect selection, and a single rater constrain interpretation, particularly as players mature.

## Special-teams deployment

We express official power-play and penalty-kill ice time as percentages of total regular-season ice time. Recorded zeros remain observations. The source covers all <<base::nrow(applications$deployment$panel)>> scored player-seasons, with <<base::sum(applications$deployment$estimates$missingRecords)>> missing unit-specific records. Higher CSAx accompanies lower power-play shares and higher penalty-kill shares in both positions. Linear models adjust for current-season listed size, age and age squared, games dressed, ice time per game, five-on-five scoring rate, relative shot attempts, and season. Intervals use player-clustered HC1 uncertainty conditional on the scores.

<<markdown_table(deployment_table)>>

The associations describe how teams deploy players with different physical profiles. Special-teams assignments also reflect skill, tactical needs, and teammates; a power-play or penalty-kill association cannot independently validate toughness.

## Postseason physical engagement

We compare five-on-five observations from regular-season games excluded from score construction with each qualifying team’s first four playoff games. A player enters the paired analysis only with positive exposure in both periods. For traded players, the baseline includes games with their playoff team. The window is common to teams; a player need not dress in all four games.

<<markdown_table(window_coverage)>>

The baseline excludes every game with retained A3Z tracking, including records outside individual scoring eligibility. This conservative separation prevents the same game from contributing to score construction and the regular-season outcome baseline. Selection into the playoffs and the paired sample remains visible:

<<markdown_table(selection_table)>>

We fit separate positional Poisson models for hits delivered, hits received, and opponent shots blocked. Player-season effects absorb each player’s baseline level, ice-time offsets account for exposure, and postseason interactions with CSAx and the existing regular-season controls describe differential changes. Player-clustered HC1 intervals condition on scores and observed pairs. Pairs with zero events across both periods contribute to descriptive totals but contain no information about within-player rate change for that event.

<<markdown_table(engagement_table)>>

The forward hits-delivered multiplier is **<<interval(primary_forward_hits$effect, primary_forward_hits$effectLow, primary_forward_hits$effectHigh)>>** per CSAx standard deviation. Higher-scoring forwards show a smaller proportional postseason increase, and the full-postseason check has the same direction. The defenseman estimate is **<<interval(primary_defense_hits$effect, primary_defense_hits$effectLow, primary_defense_hits$effectHigh)>>**; its interval includes no differential change.

A rate-ratio multiplier below one indicates a smaller proportional postseason increase as CSAx rises, after adjustment. It does not by itself establish a physical ceiling or imply lower postseason contact levels. Adjusted ratios below average log-rate changes over the covariate distribution of informative pairs, with CSAx set to −1, 0, or +1:

<<markdown_table(rate_table)>>

![Postseason changes in hits delivered](figures/postseason_engagement.png)

Fights and contact penalties receive descriptive summaries because their counts are sparse. These observed rates also show the contact levels underlying the fitted changes:

<<markdown_table(descriptive_contacts)>>

The full-postseason check repeats only the primary hits-delivered model. Its longer windows depend on team advancement. All estimates concern participating players; they do not describe what nonqualifiers would do in the playoffs.

## Next-season continuation

Continuation means at least 300 NHL minutes in the following season. CSAx and controls come from season t, and continuation concerns t+1. The primary models condition on current-season role: games dressed and ice time per game in t. Separate positional models also retain listed size, age and age squared, five-on-five scoring rate, relative shot attempts, and season controls.

<<markdown_table(continuation_table)>>

Both odds ratios exceed one, with intervals that exclude one, although the forward lower bound is close to that value. These estimates support a positive conditional association with continuation. Their magnitude and uncertainty are more informative than the nominal significance threshold alone. [ASA guidance](https://www.amstat.org/asa/files/pdfs/p-valuestatement.pdf).

We also average predicted probabilities over each observed positional sample while setting CSAx to −1, 0, or +1. Other controls retain their observed values.

<<markdown_table(probability_table)>>

![Adjusted next-season continuation probabilities](figures/continuation.png)

These associations describe roster relevance. They are not causal effects or independent confirmation of the physicality construct. Player-clustered HC1 intervals condition on the estimated scores and tracked sample; uncertainty from reconstructing CSAx is outside these intervals.

### Current and previous roles

The role-timing comparison restricts both models to identical observations with NHL participation and observed role in t−1. We replace only games dressed and ice time per game with their preceding-season values, retaining CSAx and all other controls from t. The full-sample current-role analysis remains primary.

<<markdown_table(role_table)>>

<<markdown_table(role_probabilities)>>

These comparisons address conditioning choices. They do not isolate causal pathways, and differences in nominal significance do not determine which model we prefer.

## Paper structure and reproduction

The [paper roadmap](paper_roadmap.md) follows construction → scouting → deployment → postseason engagement → continuation. This progression first establishes what CSAx measures and how it agrees with independent descriptions, then examines assigned roles, behavioral changes, and practical roster relevance. The [Sloan abstract](abstract.md), also available as [plain text](abstract.txt), follows the same sequence. Individual shooting-percentage variability, contracts, and numerous career interactions remain outside the paper core.

The compact analysis object retains frozen source inputs, model identities, feature counts, folds, calibration summaries, historical benchmarks, and current results. The numbered workflow fits only the selected positional specification by default. Previous alternative models and bootstrap summaries remain labeled historical results.

Current outputs include [player rankings](player_rankings.csv), [player-period engagement](postseason_engagement.csv), and [application estimates](application_estimates.csv). The [README](../../README.md) supplies reproduction instructions and describes the locked scouting data. NHL inputs use the pinned nhlscraper revision; A3Z observations remain attributed to Corey Sznajder / All Three Zones. Source materials retain their third-party terms.

Sloan requires an abstract under 500 words, including title and body, with Introduction, Methods, Results, and Conclusion sections reporting actual findings. We count the headings toward that limit. Abstracts are due October 1, 2026, at 11:59 p.m. Eastern; invited manuscripts are due December 4 at the same time. The authenticated form’s upload requirements remain unverified. Current guidance requires an open-source repository link. The repository remains private pending a public-release decision, and full-manuscript formatting awaits invitation guidance. [Competition rules](https://www.sloansportsconference.com/research-paper-competition).
', .open = '<<', .close = '>>')
  readr::write_file(base::paste0(report, '\n'), base::file.path(report_directory, 'research_summary.md'))
  write_physicality_submission(p, pooled, report_directory)
}

# Prepare matching submission formats and focused manuscript roadmap.
write_physicality_submission <- function(p, pooled, report_directory) {
  if (!p$scouting$expansionComplete) base::stop('Completed, locked scouting ratings are required for submission documents.', call. = FALSE)
  forward <- pooled |> dplyr::filter(model == 'Forwards')
  defense <- pooled |> dplyr::filter(model == 'Defensemen')
  forward_outcome <- p$continuation |> dplyr::filter(model == 'Forwards')
  defense_outcome <- p$continuation |> dplyr::filter(model == 'Defensemen')
  scout <- p$scouting$estimates |> dplyr::filter(indicator == 'activePhysicalEngagement')
  scout_forward <- scout |> dplyr::filter(model == 'Forwards')
  scout_defense <- scout |> dplyr::filter(model == 'Defensemen')
  deployment <- p$applications$deployment$estimates
  forward_pp <- deployment |> dplyr::filter(model == 'Forwards', outcome == 'powerPlayShare')
  defense_pp <- deployment |> dplyr::filter(model == 'Defensemen', outcome == 'powerPlayShare')
  forward_pk <- deployment |> dplyr::filter(model == 'Forwards', outcome == 'penaltyKillShare')
  defense_pk <- deployment |> dplyr::filter(model == 'Defensemen', outcome == 'penaltyKillShare')
  hits <- p$applications$engagement$estimates |> dplyr::filter(outcome == 'hits', window == 'First four')
  forward_hits <- hits |> dplyr::filter(model == 'Forwards')
  defense_hits <- hits |> dplyr::filter(model == 'Defensemen')
  scouting_sentence <- if (base::all(scout$contrastStatus == 'Available')) {
    glue::glue('Among {scout_forward$n} forwards and {scout_defense$n} defensemen, active-engagement descriptions have Spearman correlations with CSAx of {fixed(scout_forward$spearman)} and {fixed(scout_defense$spearman)}; mean CSAx differences between players with and without such descriptions are {interval(scout_forward$estimate, scout_forward$confLow, scout_forward$confHigh)} and {interval(scout_defense$estimate, scout_defense$confLow, scout_defense$confHigh)}, respectively.')
  } else {
    base::paste(purrr::pmap_chr(scout |> dplyr::select(model, n, spearman, contrastStatus), function(model, n, spearman, contrastStatus) {
      if (contrastStatus == 'Available') glue::glue('Scouting descriptions correlate with CSAx at {fixed(spearman)} among {n} {base::tolower(model)}.') else glue::glue('The scouting contrast is unavailable among {n} {base::tolower(model)} because observations or code variation are insufficient.')
    }), collapse = ' ')
  }
  abstract <- glue::glue('# Playing Tougher for One’s Size: Positional Physicality in the NHL

## Introduction

Players of similar size can make their presence felt in different ways. We quantify playing tougher for one’s size through direct contact and indirect signs of physicality in battles for the puck and space, then examine independent scouting evidence, assigned roles, postseason behavior, and roster relevance.

## Methods

We combine NHL events and All Three Zones microstats across 2021–22 through 2024–25, retaining <<forward$playerSeasons>> forward-seasons and <<defense$playerSeasons>> defenseman-seasons with at least 300 NHL minutes and 150 tracked five-on-five minutes. Seasonal ridge models predict listed height-and-weight size from shared direct and position-specific indirect measures. Nested five-fold estimation and training-based frame calibration yield standardized residuals: calibrated size above expected (CSAx). Centers remain forwards. We compare player-average CSAx with blinded human codes from earlier scouting passages, then estimate adjusted special-teams deployment, postseason contact changes, and next-season continuation of at least 300 NHL minutes. Postseason Poisson models pair regular-season games excluded from CSAx construction with each team’s first four playoff games. Reported 95% robust intervals condition on estimated scores; repeated player observations are clustered.

## Results

Held-out size prediction improves on the training-mean baseline by <<fixed(100 * forward$pooledR2)>>% for forwards and <<fixed(100 * defense$pooledR2)>>% for defensemen in squared-error terms. <<scouting_sentence>>

Per CSAx standard deviation, adjusted power-play shares are lower by <<interval(-forward_pp$effect, -forward_pp$effectHigh, -forward_pp$effectLow)>> percentage points for forwards and <<interval(-defense_pp$effect, -defense_pp$effectHigh, -defense_pp$effectLow)>> for defensemen; penalty-kill shares are higher by <<interval(forward_pk$effect, forward_pk$effectLow, forward_pk$effectHigh)>> and <<interval(defense_pk$effect, defense_pk$effectLow, defense_pk$effectHigh)>> points, respectively.

Higher-scoring forwards show smaller proportional postseason increases in hits delivered: the postseason-to-baseline rate-ratio multiplier per CSAx standard deviation is <<interval(forward_hits$effect, forward_hits$effectLow, forward_hits$effectHigh)>>, versus <<interval(defense_hits$effect, defense_hits$effectLow, defense_hits$effectHigh)>> for defensemen. The full-postseason check agrees in direction. Continuation odds ratios per CSAx standard deviation are <<interval(forward_outcome$effect, forward_outcome$effectLow, forward_outcome$effectHigh, 3L)>> and <<interval(defense_outcome$effect, defense_outcome$effectLow, defense_outcome$effectHigh, 3L)>>, respectively.

## Conclusion

CSAx aligns with independent physical-engagement descriptions and adds context to player assessment through role, behavioral, and roster associations. Uneven tracking, selective prospect coverage, and one rater limit generalization. Weak 2024–25 defensive size prediction and uncertain defensive postseason differences constrain positional claims. The score describes physical presence relative to frame without establishing courage, overall ability, or causal effects.
', .open = '<<', .close = '>>')
  plain_text <- stringr::str_replace_all(abstract, stringr::regex('^#{1,6} +', multiline = TRUE), '')
  word_count <- stringr::str_count(stringr::str_squish(plain_text), '\\S+')
  if (word_count >= 500L) base::stop('Sloan abstract exceeds permitted word count.', call. = FALSE)
  readr::write_file(base::paste0(abstract, '\n'), base::file.path(report_directory, 'abstract.md'))
  readr::write_file(base::paste0(plain_text, '\n'), base::file.path(report_directory, 'abstract.txt'))
  roadmap <- glue::glue('# Playing tougher for one’s size: paper roadmap

Physical presence is visible in contact, puck battles, and the roles teams assign, yet listed height and weight describe only a player’s frame. We organize the paper around a single question: how well does CSAx capture physical presence relative to that frame? The progression is **construction → scouting → deployment → postseason engagement → continuation**. The [research summary](research_summary.md) supplies the completed results and measurement qualifications.

## Paper structure

1. **Construction: define the measured profile.** Introduce direct contact and indirect signs of physicality, justify the selected predictors, and explain listed-size prediction, frame calibration, and separate forward and defenseman references. Show held-out performance, annual stability, and the additive direct, indirect, and frame contributions. Retain the weak 2024–25 defensive prediction as a limitation of the interpretation. A score relative to frame does not establish courage or overall ability.
2. **Scouting: assess independent descriptions.** Lead the empirical evidence with the <<scout_forward$n>> forwards and <<scout_defense$n>> defensemen whose eligible NHL observations follow their scouting passages. Active-engagement correlations of <<fixed(scout_forward$spearman)>> and <<fixed(scout_defense$spearman)>>, together with the mean differences and conditional intervals, address the intended physicality interpretation directly. Explain that a zero means no mention, and discuss draft-era descriptions, selective prospect coverage, and one rater.
3. **Deployment: place the score in assigned roles.** Present power-play and penalty-kill shares, descriptive correlations, and adjusted percentage-point associations. Lower PP shares and higher PK shares in both positions characterize deployment patterns. Skill, tactical needs, and teammates also shape those assignments, so their signs alone do not establish construct validity.
4. **Postseason engagement: examine changes in behavior.** Use disjoint regular-season observations and each team’s first four playoff games to ask whether physical profiles accompany different proportional contact changes. Lead with delivered hits, explain the rate-ratio multiplier and adjusted changes at CSAx −1, 0, and +1, and support the result with received hits and shot blocks. The full-postseason check repeats delivered hits. A smaller forward increase does not establish a physical ceiling; the defensive interval includes no differential change. Distinguish playoff participation from changes among observed participants.
5. **Continuation: conclude with practical roster relevance.** Present the full-sample current-role odds ratios alongside adjusted probabilities of at least 300 NHL minutes next season. The matched current/prior-role comparison addresses conditioning choices while holding the observations fixed. These associations extend the scouting and behavioral evidence to roster relevance without establishing causal effects.

This order develops the measurement argument before its applications: scouting addresses the construct, deployment describes roles, postseason comparisons examine behavior, and continuation connects the profile to NHL participation.

## Presentation and interpretation

The main text pairs concise positional estimates with uncertainty. The feature-weight figure explains score construction; postseason and continuation figures translate the regression results into rate changes and probabilities. Coverage, source definitions, complete coefficient tables, sparse-event diagnostics, and the role-timing comparison support the main narrative. Full-manuscript length and appendix placement depend on invitation guidance.

Separate positional scales are essential. In the historical cross-position exercise, centers have a median of 10 targeted entries compared with 137 for defensemen. Of 724 center-seasons, 638 have denial shares outside the defensive training range, and only 7 have complete inputs within both references’ ranges. These opportunity differences confound a physical-style interpretation, so cross-position center scoring stays outside the paper. All eligible centers remain in the main forward model.

We preserve all 40 original annotations and supplement them with 43 completed ratings. Thirty-nine original players and all 43 expansion players meet scoring eligibility. Passages and codes are locked before linkage to identities and CSAx. Each scouting contrast uses player-average scores, and every application interval conditions on the estimated metric. These intervals omit uncertainty from reconstructing CSAx. Feature choice follows the physicality rationale and measurement evidence, without optimizing downstream significance.

## Remaining paper decisions

The results review determines which player examples best explain the direct, indirect, and frame contributions, how much weight the smaller defensive scouting cohort supports, and which diagnostic details fit in supplementary material. The current predictors and four player-level analyses define the paper core. Individual shooting-percentage variability, contracts, and additional career interactions remain outside that scope. Further construct validation requires independent observations with broader player coverage and more direct information about physical pressure.

## Abstract and submission

The completed [Markdown abstract](abstract.md) and matching [plain-text abstract](abstract.txt) contain **<<word_count>> words**, including the title and section headings. Introduction, Methods, Results, and Conclusion follow Sloan’s published structure; Markdown is the working-file format. The text-only version contains the same content without Markdown syntax. The authenticated submission form’s upload requirements remain unverified.

Abstracts are due **October 1, 2026, at 11:59 p.m. Eastern**. Invited papers are due **December 4, 2026, at 11:59 p.m. Eastern**. Hockey belongs in the Other Sports track. Full-manuscript formatting awaits invitation guidance. [Sloan competition rules](https://www.sloansportsconference.com/research-paper-competition).

Sloan requires an open-source repository link. This repository remains private until an explicit release decision. Release review covers reproducible inputs, source attribution, third-party terms, and exclusion of private scouting prose and identity keys. The paper explains the positional and A3Z contributions in relation to the preceding forward study.
', .open = '<<', .close = '>>')
  readr::write_file(base::paste0(roadmap, '\n'), base::file.path(report_directory, 'paper_roadmap.md'))
  base::message('Wrote positional physicality report and matching ', word_count, '-word abstracts.')
}

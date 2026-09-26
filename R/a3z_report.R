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

# Write primary results, transparent diagnostics, and provisional submission documents.
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
  team_scores <- applications$teams$scores |>
    dplyr::select(seasonId, teamId, teamTriCode, franchiseId, model, teamCSAx, teamScore, playerSeconds, scoredSeconds, scoredCoverage, scoredPlayers, players, teamReferenceMean, teamReferenceSd) |>
    tidyr::pivot_wider(names_from = model, values_from = base::c('teamCSAx', 'teamScore', 'playerSeconds', 'scoredSeconds', 'scoredCoverage', 'scoredPlayers', 'players', 'teamReferenceMean', 'teamReferenceSd'))
  team_export <- team_scores |>
    dplyr::left_join(applications$teams$changes |> dplyr::select(-teamTriCode, -franchiseId, -seasonFactor, -dplyr::starts_with('teamScore_'), -dplyr::starts_with('scoredCoverage_')), by = base::c('seasonId', 'teamId')) |>
    dplyr::mutate(window = dplyr::coalesce(window, 'No postseason'), specification = a3z_specification, eventScope = a3z_scope, outcomeScope = 'NHL five on five; disjoint regular-season baseline and playoffs', referencePopulation = 'All 32 teams within season; positional scores separate', roleTiming = 'Regular-season five-on-five team weights')
  write_table(team_export, 'team_summaries.csv')
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
    applications$engagement$descriptive |> dplyr::mutate(statistic = 'Observed event rate per 60', scale = 'events per 60', effect = ratePer60, intervalMethod = 'Descriptive; no interval'),
    applications$teams$estimates
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
  # Present external descriptions and adjusted continuation probabilities.
  scouting_table <- p$scouting$estimates |>
    dplyr::transmute(Position = model, Indicator = dplyr::recode(indicator, activePhysicalEngagement = 'Active physical engagement'), Players = base::as.character(n), Mentions = base::as.character(positiveReports), Spearman = spearman, 'Mean CSAx difference (95% CI)' = interval(estimate, confLow, confHigh), 'Contrast status' = contrastStatus)
  continuation_table <- p$continuation |> dplyr::transmute(Position = model, 'Player-seasons' = base::as.character(sampleSize), 'Odds ratio per CSAx SD (95% CI)' = interval(effect, effectLow, effectHigh, 3L), 'p-value' = p_value(pValue))
  probability_table <- p$continuationProbabilities |>
    dplyr::transmute(Position = model, CSAx, 'Adjusted continuation probability (%)' = 100 * probability, '95% CI (%)' = base::paste(fixed(100 * confLow), fixed(100 * confHigh), sep = ' to '))
  scouting_text <- if (p$scouting$expansionComplete) {
    glue::glue('The expanded blinded ratings are complete and locked before linkage to CSAx. We evaluate {dplyr::n_distinct(p$scouting$scores$playerId)} eligible players separately by position, retaining the same active-engagement coding rules across the original and expanded cohorts.')
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
  team_coverage <- applications$teams$changes |> dplyr::filter(window == 'First four') |> dplyr::group_by(seasonId) |>
    dplyr::summarise(qualifiers = dplyr::n(), included = base::sum(included), forwardCoverage = stats::median(scoredCoverage_Forwards), defenseCoverage = stats::median(scoredCoverage_Defensemen), .groups = 'drop') |>
    dplyr::transmute(Season = season_label(seasonId), 'Playoff teams' = base::as.character(qualifiers), 'Joint-model teams' = base::as.character(included), 'Median scored forward TOI (%)' = 100 * forwardCoverage, 'Median scored defenseman TOI (%)' = 100 * defenseCoverage)
  team_exclusions <- applications$teams$changes |> dplyr::filter(window == 'First four', !included) |>
    dplyr::transmute(Season = season_label(seasonId), Team = teamTriCode, 'Scored forward TOI (%)' = 100 * scoredCoverage_Forwards, 'Scored defenseman TOI (%)' = 100 * scoredCoverage_Defensemen, Reason = exclusion)
  team_labels <- base::c(deltaXGF60 = 'Expected goals for per 60', deltaAttempts60 = 'Unblocked attempts per 60', deltaQuality100 = 'Expected goals per 100 unblocked attempts')
  team_estimates <- applications$teams$estimates |>
    dplyr::transmute(Window = window, Outcome = base::unname(team_labels[outcome]), 'Positional team score' = model, 'Team-seasons' = base::as.character(sampleSize), Franchises = base::as.character(franchises), 'Signed change per team-score SD (95% CI)' = interval(effect, effectLow, effectHigh, 3L))
  team_descriptive <- applications$teams$changes |> dplyr::filter(window == 'First four') |> dplyr::group_by(seasonId) |>
    dplyr::summarise('Mean change in xGF per 60' = base::mean(deltaXGF60), 'Mean change in attempts per 60' = base::mean(deltaAttempts60), 'Mean change in xG per 100 attempts' = base::mean(deltaQuality100), 'Mean absolute quality change' = base::mean(absoluteQualityChange), .groups = 'drop') |> dplyr::mutate(Season = season_label(seasonId), .before = 1L) |> dplyr::select(-seasonId)

  primary_forward_hits <- applications$engagement$estimates |> dplyr::filter(model == 'Forwards', outcome == 'hits', window == 'First four')
  primary_defense_hits <- applications$engagement$estimates |> dplyr::filter(model == 'Defensemen', outcome == 'hits', window == 'First four')
  primary_team <- applications$teams$estimates |> dplyr::filter(outcome == 'deltaXGF60', window == 'First four')

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

  # Draw primary postseason rate changes and team chance-creation contrasts.
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
  chance_plot <- applications$teams$estimates |> dplyr::filter(outcome == 'deltaXGF60') |>
    ggplot2::ggplot(ggplot2::aes(effect, model, color = window)) +
    ggplot2::geom_vline(xintercept = 0, color = '#BBBBBB', linewidth = 0.4) +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = effectLow, xmax = effectHigh), orientation = 'y', width = 0.15, position = ggplot2::position_dodge(width = 0.4)) +
    ggplot2::geom_point(size = 2.7, position = ggplot2::position_dodge(width = 0.4)) +
    ggplot2::scale_color_manual(values = base::c('First four' = '#17324D', 'Full postseason' = '#BD7C27')) +
    ggplot2::labs(title = 'Positional physicality and postseason chance creation', subtitle = 'Both team scores enter jointly; franchise-clustered 95% intervals', x = 'Change in xGF per 60 per positional team-score SD', y = NULL, color = NULL) + research_theme()
  ggplot2::ggsave(base::file.path(figure_directory, 'team_chance_creation.png'), chance_plot, width = 9, height = 4.5, dpi = 180, bg = 'white')

  # Report observed results without treating size prediction as construct validation.
  forward <- pooled |> dplyr::filter(model == 'Forwards')
  defense <- pooled |> dplyr::filter(model == 'Defensemen')
  latest_defense <- p$performance |> dplyr::filter(model == 'Defensemen', seasonId == base::max(xs_behavior_seasons))
  feature_table <- dictionary |> dplyr::transmute(Component = component, Population = population, Measure = label, 'Source and denominator' = measurement, 'Rationale and qualification' = rationale)
  exclusions <- p$inputs$sourceRows |> dplyr::count(rowStatus) |> dplyr::transmute(Disposition = rowStatus, 'Player-game rows' = base::as.character(n))
  report <- glue::glue('# Playing tougher for your size

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

## Independent scouting descriptions

<<scouting_text>>

<<markdown_table(scouting_table)>>

A single human rater codes active physical engagement while blinded to identities, scores, and rankings. The source collection comprises official NHL scouting publications from 2018–2024. Profiles are matched to individual NHL identities and draft years before inclusion, regardless of score or physicality wording. The 2024 source date uses its PDF creation timestamp; the exact publication day is unavailable.

Player-average scores use eligible seasons following the source report. A zero code records absence of the specified description; it does not establish soft play. Mean differences compare players with and without the description. Their HC1 intervals condition on the estimated scores and observed scouting cohort. Draft-era prose, prospect selection, and a single rater constrain interpretation, particularly as players mature.

## Next-season continuation

Continuation means at least 300 NHL minutes in the following season. CSAx and controls come from season t, and continuation concerns t+1. The primary models condition on current-season role: games dressed and ice time per game in t. Separate positional models also retain listed size, age and age squared, five-on-five scoring rate, relative shot attempts, and season controls.

<<markdown_table(continuation_table)>>

Both primary associations meet the nominal 5% significance threshold. We retain three decimals here because the forward lower bound rounds to 1.00 at two decimals. Statistical significance does not establish measurement validity or identify an optimal feature subset. The specification remains fixed; any future simplification requires hockey rationale and measurement evidence. [ASA guidance](https://www.amstat.org/asa/files/pdfs/p-valuestatement.pdf).

We also average predicted probabilities over each observed positional sample while setting CSAx to −1, 0, or +1. Other controls retain their observed values.

<<markdown_table(probability_table)>>

![Adjusted next-season continuation probabilities](figures/continuation.png)

These associations describe roster relevance. They are not causal effects or independent confirmation of the physicality construct. Player-clustered HC1 intervals condition on the estimated scores and tracked sample; uncertainty from reconstructing CSAx is outside these intervals.

### Current and previous roles

The role-timing comparison restricts both models to identical observations with NHL participation and observed role in t−1. We replace only games dressed and ice time per game with their preceding-season values, retaining CSAx and all other controls from t. The full-sample current-role analysis remains primary.

<<markdown_table(role_table)>>

<<markdown_table(role_probabilities)>>

These comparisons address conditioning choices. They do not isolate causal pathways, and differences in nominal significance do not determine which model we prefer.

## Special-teams deployment

We express official power-play and penalty-kill ice time as percentages of total regular-season ice time. Recorded zeros remain observations. The source covers all <<base::nrow(applications$deployment$panel)>> scored player-seasons, with <<base::sum(applications$deployment$estimates$missingRecords)>> missing unit-specific records. Higher CSAx accompanies lower power-play shares and higher penalty-kill shares in both positions. Linear models use the same current-season size, age, usage, scoring, relative-shot-attempt, and season controls as continuation. Intervals use player-clustered HC1 uncertainty conditional on the scores.

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

## Team chance creation

We examine signed postseason-minus-baseline changes in expected goals for per 60. Unblocked attempts per 60 measure chance volume, while expected goals per 100 unblocked attempts describe average chance quality. For each team, xGF per 60 equals attempts per 60 multiplied by xG per attempt. The outcomes use the same disjoint baseline and first-four-game window as physical engagement.

Separate forward and defenseman team scores weight player CSAx by full regular-season five-on-five ice time. Centers contribute once to forwards. Each positional team score is standardized across all 32 teams within season before playoff teams are selected. Joint models require at least 80% scored ice-time coverage in both positions and complete underlying player exposure.

<<markdown_table(team_coverage)>>

<<if (base::nrow(team_exclusions)) markdown_table(team_exclusions) else "Every playoff team meets the joint-model coverage requirement.">>

Expected goals use the pinned NHLxG model files, whose SHA-256 hashes match the inherited model index. We score complete game records before selecting five-on-five events or outcome windows. The chance measures cover skater unblocked attempts: <<base::sum(p$applicationInputs$teamGames$excludedGoalieAttempts)>> goalie-attributed attempts across the full four-season source are outside the model’s supported population and excluded from both expected goals and attempt denominators. All retained attempts have an expected-goal prediction. [NHLxG model source](https://huggingface.co/datasets/RentoSaijo/NHLxG).

The change models include both positional scores, season effects, and changes in opponent defensive strength. Opponent strength is regular-season xGA per 60, excluding head-to-head games against the focal team, then averaged over each period using five-on-five exposure. We weight rate changes by the harmonic combination of baseline and playoff ice time; the quality model uses attempt-count weights. Franchise-clustered HC1 intervals use a t reference with the number of franchises minus one degrees of freedom.

<<markdown_table(team_estimates)>>

The primary models contain **<<primary_team$sampleSize[1L]>> team-seasons** from **<<primary_team$franchises[1L]>> franchises**. Both positional intervals for xGF-per-60 change include zero. The full-postseason estimates remain uncertain, so the team results do not establish a clear chance-creation advantage for a tougher measured profile.

![Positional team scores and postseason chance creation](figures/team_chance_creation.png)

The full-postseason check repeats only the primary xGF-per-60 analysis. Both windows are observational comparisons affected by matchups, playoff selection, team systems, and remaining unmeasured differences.

The following descriptive means include all 16 playoff teams in each season.

<<markdown_table(team_descriptive)>>

The last column preserves a descriptive connection to the original study of 16 playoff teams in 2024–25. An absolute change combines increases and declines; one such change does not estimate variability or establish consistency. The signed models retain that distinction across the four seasons.

## Research direction and reproduction

The [provisional research roadmap](research_roadmap.md) organizes the paper around frame-relative physicality, independent scouting, continuation and deployment, and postseason engagement and team chance creation. Expanded scouting results are required before completing the [Sloan abstract](abstract.md). The results review determines which application findings advance the final narrative. Individual shooting-percentage variability, contracts, and numerous career interactions remain outside this analysis.

The compact analysis object retains frozen source inputs, model identities, feature counts, folds, calibration summaries, historical benchmarks, and current results. The numbered workflow fits only the selected positional specification by default. Previous alternative models and bootstrap summaries remain labeled historical results.

Current outputs include [player rankings](player_rankings.csv), [team scores and postseason summaries](team_summaries.csv), [player-period engagement](postseason_engagement.csv), and [application estimates](application_estimates.csv). The [README](../../README.md) supplies reproduction and scouting-lock instructions. NHL inputs use the pinned nhlscraper revision; A3Z observations remain attributed to Corey Sznajder / All Three Zones. Source materials retain their third-party terms.

Sloan requires an abstract under 500 words, including title and body, with Introduction, Methods, Results, and Conclusion sections reporting actual findings. Abstracts are due October 1, 2026, at 11:59 p.m. Eastern; invited manuscripts are due December 4. Current guidance requires an open-source repository link. The repository remains private pending a public-release decision, and full-manuscript formatting requires confirmation from invitation guidance. [Competition rules](https://www.sloansportsconference.com/research-paper-competition).
', .open = '<<', .close = '>>')
  readr::write_file(base::paste0(report, '\n'), base::file.path(report_directory, 'research_summary.md'))
  write_physicality_submission(p, pooled, report_directory)
}

# Prepare factual abstract draft and outcome-dependent manuscript roadmap.
write_physicality_submission <- function(p, pooled, report_directory) {
  forward <- pooled |> dplyr::filter(model == 'Forwards')
  defense <- pooled |> dplyr::filter(model == 'Defensemen')
  forward_outcome <- p$continuation |> dplyr::filter(model == 'Forwards')
  defense_outcome <- p$continuation |> dplyr::filter(model == 'Defensemen')
  scout <- p$scouting$estimates |> dplyr::filter(indicator == 'activePhysicalEngagement')
  scout_forward <- scout |> dplyr::filter(model == 'Forwards')
  scout_defense <- scout |> dplyr::filter(model == 'Defensemen')
  scouting_sentence <- if (p$scouting$expansionComplete) {
    if (base::all(base::is.finite(scout$spearman))) {
      glue::glue('Scouting physical-engagement descriptions have Spearman correlations of {fixed(scout_forward$spearman)} among {scout_forward$n} forwards and {fixed(scout_defense$spearman)} among {scout_defense$n} defensemen.')
    } else {
      descriptions <- purrr::map_chr(base::seq_len(base::nrow(scout)), function(index) {
        row <- scout[index, ]
        statistic <- if (base::is.finite(row$spearman)) base::paste0('Spearman correlation ', fixed(row$spearman)) else 'correlation unavailable because observations or variation are insufficient'
        glue::glue('{row$n} {base::tolower(row$model)} ({statistic})')
      })
      glue::glue('Scouting physical-engagement comparisons include {base::paste(descriptions, collapse = " and ")}.')
    }
  } else {
    'Expanded scouting associations await completion and locking of the blinded human ratings.'
  }
  status <- if (p$scouting$expansionComplete) '' else '**Draft awaiting expanded scouting ratings; not ready for submission.**\n\n'
  abstract <- glue::glue('# Playing Tougher for Your Size: Positional Physicality and NHL Continuation

<<status>>## Introduction

Listed size provides an incomplete picture of physical play. We study whether NHL skaters show more or less physical presence than their frame suggests through direct contact and indirect involvement in battles for possession and space.

## Methods

We combine NHL play-by-play with All Three Zones microstats for 2021–22 through 2024–25, retaining <<forward$playerSeasons>> forward-seasons and <<defense$playerSeasons>> defenseman-seasons with at least 300 full-season minutes and 150 tracked five-on-five minutes. Seasonal ridge models predict listed height-and-weight size using shared direct and position-specific indirect measures. Nested five-fold estimation supplies excluded-sample predictions and training-based frame calibration; standardized residuals define CSAx. We assess independent scouting descriptions of active physical engagement and adjusted next-season continuation of at least 300 NHL minutes.

## Results

Held-out predictive R² is <<fixed(100 * forward$pooledR2)>>% for forwards and <<fixed(100 * defense$pooledR2)>>% for defensemen relative to training-mean size predictions. Defensive prediction weakens in 2024–25. <<scouting_sentence>> Continuation odds ratios per CSAx standard deviation are <<interval(forward_outcome$effect, forward_outcome$effectLow, forward_outcome$effectHigh)>> for forwards and <<interval(defense_outcome$effect, defense_outcome$effectLow, defense_outcome$effectHigh)>> for defensemen, with 95% player-clustered intervals conditional on estimated scores.

## Conclusion

CSAx describes physical behavior relative to frame within positional references and shows associations with roster continuation. Learned size-prediction weights, uneven tracking, and seasonal instability constrain interpretation. Continued external evaluation is necessary to establish how closely this statistical profile represents playing tougher or softer for one’s size.
', .open = '<<', .close = '>>')
  word_count <- stringr::str_count(stringr::str_squish(abstract), '\\S+')
  if (word_count >= 500L) base::stop('Sloan abstract exceeds permitted word count.', call. = FALSE)
  readr::write_file(base::paste0(abstract, '\n'), base::file.path(report_directory, 'abstract.md'))
  roadmap <- glue::glue('# Positional physicality: provisional research roadmap

We study physical presence relative to listed frame using separate models for forwards, including centers, and defensemen. The [research summary](research_summary.md) presents the completed measurement, deployment, continuation, and postseason analyses. Their place in the final paper depends on the results review and independent scouting evidence.

## Paper structure

1. **Frame-relative physicality and positional construction.** Define direct and indirect physicality, explain expected-size prediction and frame calibration, and present held-out performance, annual stability, and player contributions. Positional responsibilities set the reference population.
2. **Independent scouting evidence.** Evaluate active physical engagement separately for forwards and defensemen. Preserve the 40 frozen annotations; 39 currently have eligible scores. The <<p$scouting$plannedNewPlayers>> new passages supplement this collection without recoding previous reports.
3. **Continuation and deployment.** Keep full-sample current-role continuation primary. Present the matched current/prior-role comparison and PP/PK shares as contextual applications, with adjusted probabilities and percentage-point associations.
4. **Postseason engagement and team chance creation.** Lead with hits delivered and expected goals for per 60. Use received hits, shot blocks, attempt volume, and average chance quality to explain the primary findings. First-four-game windows are primary; full-postseason results are the single window check.

The cross-position center exercise remains historical material. Defensive targeted-entry opportunities differ sharply: medians are 10 for centers and 137 for defensemen. Of 724 center-seasons, 638 have denial shares outside the defensive training range, and only seven have complete inputs within both references’ ranges. These comparisons mix positional responsibilities with physical style. Centers contribute to the main forward population.

## Decisions for results review

| Evidence | Interpretation to assess | Paper decision |
| --- | --- | --- |
| Scouting descriptions | Do descriptions of active physical engagement align with player-average CSAx in both positions? | Central external evidence. Status: **<<p$scouting$status>>**. Complete and lock ratings before completing the abstract. |
| Model performance | How much confidence do seasonal prediction, residual size gradients, sparse events, and annual stability support? | Retain the 2024–25 defensive limitation when framing claims. Do not select features for stronger outcome associations. |
| Continuation and deployment | How does the measured profile relate to roster persistence and assigned roles? | Present practical relevance without treating role signs or nominal significance as construct validation. |
| Postseason engagement | Do players with different scores show different proportional contact changes on disjoint baseline games? | Evaluate effect sizes, uncertainty, selection, and agreement across windows. A smaller increase does not establish a physical ceiling. |
| Team chance creation | Are positional team scores associated with signed changes in chance volume and quality? | Assess coverage, opponent adjustment, and franchise-clustered uncertainty before choosing emphasis. Absolute change remains descriptive. |

Individual shooting-percentage variability, contracts, and numerous career interactions remain outside this pass. Further model simplification requires a hockey mechanism and measurement evidence; it does not follow from choosing a larger odds ratio or smaller p-value.

## Scouting and submission

The blinded packet contains <<p$scouting$plannedNewForwards>> forwards and <<p$scouting$plannedNewDefensemen>> defensemen. One human rater codes active physical engagement without identities or CSAx. A zero records absence of a description, and cannot establish soft play. Draft-era sources, selective prospect coverage, and one rater remain limitations.

The [abstract](abstract.md) remains below 500 words, including its title, and awaits completed expanded ratings. The abstract deadline is October 1, 2026, at 11:59 p.m. Eastern; invited papers are due December 4 at the same time. We use the Other Sports track. Full-manuscript formatting remains subject to invitation guidance. [Sloan competition rules](https://www.sloansportsconference.com/research-paper-competition).

The repository remains private until an explicit release decision. Release review covers reproducible inputs, source attribution, third-party terms, and exclusion of private scouting prose and identity keys. The final narrative explains the positional and A3Z contributions in relation to the preceding forward study.
', .open = '<<', .close = '>>')
  readr::write_file(base::paste0(roadmap, '\n'), base::file.path(report_directory, 'research_roadmap.md'))
  base::message('Wrote positional physicality report and ', word_count, '-word abstract ', if (p$scouting$expansionComplete) 'draft.' else 'draft awaiting expanded ratings.')
}

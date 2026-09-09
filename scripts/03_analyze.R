# Setup --------------------------------------------------------------------

# Load helper functions and strict CSAx data.
base::source('R/functions.R')
paper_directory  <- 'reports/paper_cmsacrrc'
figure_directory <- base::file.path(paper_directory, 'figures')
base::dir.create(figure_directory, recursive = TRUE, showWarnings = FALSE)
analysis_data   <- base::readRDS('data/analysis_data.rds')
forward_seasons <- analysis_data$forward_seasons

# Roster Outcomes ----------------------------------------------------------

# Assemble public roster and time-on-ice records for current, prior, and following seasons.
regular_outcomes <- purrr::map_dfr(xs_roster_seasons, function(season_id) {
  outcomes <- base::readRDS(base::file.path('data/cache', base::paste0('outcomes_', season_id, '.rds')))
  outcomes$regularRoster |>
    dplyr::full_join(outcomes$regularTime, by = 'playerId') |>
    dplyr::mutate(seasonId = season_id)
})
assert_unique(regular_outcomes, base::c('playerId', 'seasonId'), 'Regular roster outcomes')

# Count completed NHL seasons before each observation.
player_histories <- base::readRDS('data/cache/player_seasons.rds') |>
  dplyr::filter(playerId %in% forward_seasons$playerId)
career_counts <- forward_seasons |>
  dplyr::select(playerId, seasonId) |>
  dplyr::left_join(player_histories |> dplyr::rename(historySeasonId = seasonId), by = 'playerId', relationship = 'many-to-many') |>
  dplyr::filter(historySeasonId < seasonId) |>
  dplyr::group_by(playerId, seasonId) |>
  dplyr::summarise(priorNhlSeasons = dplyr::n_distinct(historySeasonId), .groups = 'drop')

# Join following-season continuation and preceding-season role.
roster_outcomes <- forward_seasons |>
  dplyr::mutate(nextSeasonId = next_season_id(seasonId), priorRoleSeasonId = previous_season_id(seasonId)) |>
  dplyr::left_join(career_counts, by = base::c('playerId', 'seasonId')) |>
  dplyr::left_join(
    regular_outcomes |>
      dplyr::transmute(playerId, nextSeasonId = seasonId, nextGamesDressed = gamesDressed, nextGamesPlayed = regularGamesPlayed, nextTimeOnIce = regularTimeOnIce, nextToiPerGame = regularToiPerGame),
    by = base::c('playerId', 'nextSeasonId')
  ) |>
  dplyr::left_join(
    regular_outcomes |>
      dplyr::transmute(playerId, priorRoleSeasonId = seasonId, priorGamesDressed = dplyr::coalesce(gamesDressed, regularGamesPlayed), priorTimeOnIce = regularTimeOnIce, priorToiPerGame = regularToiPerGame),
    by = base::c('playerId', 'priorRoleSeasonId')
  ) |>
  dplyr::mutate(
    returnedFlag = base::as.integer(!base::is.na(nextGamesDressed)),
    continued300Flag = base::as.integer(dplyr::coalesce(nextTimeOnIce, 0) >= xs_minutes * 60),
    returned = base::factor(returnedFlag, levels = base::c(0, 1)),
    continued300 = base::factor(continued300Flag, levels = base::c(0, 1)),
    nextGamesDressed = dplyr::coalesce(nextGamesDressed, 0),
    priorAppearance = base::as.integer(!base::is.na(priorGamesDressed)),
    priorGamesDressed = dplyr::coalesce(priorGamesDressed, 0),
    priorTimeOnIce = dplyr::coalesce(priorTimeOnIce, 0),
    priorToiPerGame = dplyr::coalesce(priorToiPerGame, 0),
    priorNhlSeasons = dplyr::coalesce(priorNhlSeasons, 0L),
    careerStage = base::factor(dplyr::case_when(priorNhlSeasons <= 2L ~ '0-2 prior seasons', priorNhlSeasons <= 6L ~ '3-6 prior seasons', TRUE ~ '7+ prior seasons'), levels = base::c('0-2 prior seasons', '3-6 prior seasons', '7+ prior seasons')),
    seasonFactor = base::factor(seasonId),
    teamSeasonCluster = base::interaction(seasonId, finalTeamId, drop = TRUE),
    ageC = age - base::mean(age),
    ageSquared = ageC^2,
    gamesC = standardize_complete(gamesDressed),
    toiC = standardize_complete(timeOnIcePerGame),
    priorGamesC = standardize_complete(priorGamesDressed),
    priorToiC = standardize_complete(priorToiPerGame),
    pointsC = standardize_complete(pointsPer605v5),
    satC = standardize_complete(satRelative5v5)
  )

# Validate continuation and prior-role coverage.
assert_unique(roster_outcomes, base::c('playerId', 'seasonId'), 'Roster analysis outcomes')
if (base::nrow(roster_outcomes) != 1763L || dplyr::n_distinct(roster_outcomes$playerId) != 613L || base::sum(roster_outcomes$continued300Flag) != 1486L) base::stop('Roster cohort or continuation count changed.', call. = FALSE)
if (!base::identical(base::sort(base::unique(roster_outcomes$priorRoleSeasonId)), xs_prior_role_seasons)) base::stop('Prior-role seasons are incomplete.', call. = FALSE)
if (base::anyNA(roster_outcomes$priorGamesDressed) || base::anyNA(roster_outcomes$priorToiPerGame)) base::stop('Prior-role values are incomplete.', call. = FALSE)
prior_role_coverage <- roster_outcomes |>
  dplyr::group_by(seasonId, priorRoleSeasonId) |>
  dplyr::summarise(forwardSeasons = dplyr::n(), priorAppearances = base::sum(priorAppearance), noPriorAppearance = base::sum(priorAppearance == 0L), .groups = 'drop')

# Conditioning Sequence ---------------------------------------------------

# Add controls in six prespecified steps.
conditioning_predictors <- base::list(
  '1. CSAx' = 'CSAx',
  '2. Listed size' = base::c('CSAx', 'listedSize'),
  '3. Age' = base::c('CSAx', 'listedSize', 'ageC', 'ageSquared'),
  '4. Games dressed' = base::c('CSAx', 'listedSize', 'ageC', 'ageSquared', 'gamesC'),
  '5. Ice time' = base::c('CSAx', 'listedSize', 'ageC', 'ageSquared', 'gamesC', 'toiC'),
  '6. Production and season' = base::c('CSAx', 'listedSize', 'ageC', 'ageSquared', 'gamesC', 'toiC', 'pointsC', 'satC', 'seasonFactor')
)
conditioning_models <- purrr::map(conditioning_predictors, function(predictors) {
  fit_analysis_workflow(roster_outcomes, 'continued300', predictors, model_type = 'logistic')
})
conditioning_results <- purrr::imap_dfr(conditioning_models, function(model, step) {
  summarize_analysis_result(model, roster_outcomes, step, 'Continuation conditioning sequence', scale = 'odds ratio') |>
    dplyr::mutate(step = base::match(step, base::names(conditioning_predictors)), controls = base::paste(conditioning_predictors[[step]], collapse = ', '), .before = 1L)
})
primary_predictors <- conditioning_predictors[[6L]]
continuation_model <- conditioning_models[[6L]]
conditional_continuation_result <- summarize_analysis_result(continuation_model, roster_outcomes, 'Primary', 'Next-season 300-minute continuation', scale = 'odds ratio')

# Primary and Secondary Models --------------------------------------------

# Estimate player and team-season clustered uncertainty.
team_season_cluster_result <- summarize_analysis_result(
  continuation_model,
  roster_outcomes,
  'Robustness',
  'Player and team-season clustering',
  scale = 'odds ratio',
  cluster_data = roster_outcomes |> dplyr::select(playerId, teamSeasonCluster)
) |>
  dplyr::mutate(teamSeasons = dplyr::n_distinct(roster_outcomes$teamSeasonCluster))

# Estimate secondary roster outcomes.
appearance_model  <- fit_analysis_workflow(roster_outcomes, 'returned', primary_predictors, model_type = 'logistic')
appearance_result <- summarize_analysis_result(appearance_model, roster_outcomes, 'Secondary', 'Any next-season NHL appearance', scale = 'odds ratio')
games_model       <- fit_analysis_workflow(roster_outcomes, 'nextGamesDressed', primary_predictors)
games_result      <- summarize_analysis_result(games_model, roster_outcomes, 'Secondary', 'Next-season games dressed')
returning_outcomes <- roster_outcomes |>
  dplyr::filter(returnedFlag == 1L, !base::is.na(nextToiPerGame)) |>
  dplyr::mutate(nextToiMinutes = nextToiPerGame / 60)
toi_model  <- fit_analysis_workflow(returning_outcomes, 'nextToiMinutes', primary_predictors)
toi_result <- summarize_analysis_result(toi_model, returning_outcomes, 'Secondary', 'Next-season TOI/game')

# Replace current role with preceding-season games and ice time.
prior_role_predictors <- base::c('CSAx', 'listedSize', 'ageC', 'ageSquared', 'priorGamesC', 'priorToiC', 'pointsC', 'satC', 'seasonFactor')
prior_role_model  <- fit_analysis_workflow(roster_outcomes, 'continued300', prior_role_predictors, model_type = 'logistic')
prior_role_result <- summarize_analysis_result(prior_role_model, roster_outcomes, 'Sensitivity', 'Prior-season role conditioning', scale = 'odds ratio')

# Role Timing and Roster Margin --------------------------------------------

# Compare current and preceding role among forwards with a prior NHL appearance.
role_timing_outcomes <- roster_outcomes |>
  dplyr::filter(priorAppearance == 1L) |>
  dplyr::mutate(seasonFactor = forcats::fct_drop(seasonFactor))
role_timing_predictors <- base::list(
  'Current games and ice time' = primary_predictors,
  'Prior games and ice time' = prior_role_predictors
)
role_timing_results <- purrr::imap_dfr(role_timing_predictors, function(predictors, specification) {
  model <- fit_analysis_workflow(role_timing_outcomes, 'continued300', predictors, model_type = 'logistic')
  summarize_analysis_result(model, role_timing_outcomes, 'Sensitivity', specification, scale = 'odds ratio') |>
    dplyr::mutate(specification = specification, .before = 1L)
})
if (base::nrow(role_timing_outcomes) != 1664L || dplyr::n_distinct(role_timing_outcomes$playerId) != 574L || base::nrow(role_timing_results) != 2L) base::stop('Same-sample role-timing cohort or results changed.', call. = FALSE)

# Summarize continuation information across the current ice-time distribution.
role_margin_outcomes <- roster_outcomes |>
  dplyr::mutate(toiQuartile = dplyr::ntile(timeOnIcePerGame, 4L), CSAxToi = CSAx * toiC)
role_quartile_summary <- role_margin_outcomes |>
  dplyr::group_by(toiQuartile) |>
  dplyr::summarise(forwardSeasons = dplyr::n(), continuations = base::sum(continued300Flag), noncontinuations = base::sum(continued300Flag == 0L), continuationRate = base::mean(continued300Flag), .groups = 'drop')
role_margin_summary <- tibble::tibble(
  noncontinuations = base::sum(role_quartile_summary$noncontinuations),
  lowerHalfNoncontinuations = base::sum(role_quartile_summary$noncontinuations[role_quartile_summary$toiQuartile <= 2L]),
  lowerHalfNoncontinuationShare = lowerHalfNoncontinuations / noncontinuations,
  thirdQuartileContinuationRate = role_quartile_summary$continuationRate[role_quartile_summary$toiQuartile == 3L],
  fourthQuartileContinuationRate = role_quartile_summary$continuationRate[role_quartile_summary$toiQuartile == 4L],
  thirdQuartileNoncontinuations = role_quartile_summary$noncontinuations[role_quartile_summary$toiQuartile == 3L],
  fourthQuartileNoncontinuations = role_quartile_summary$noncontinuations[role_quartile_summary$toiQuartile == 4L]
)

# Estimate whether the CSAx association varies with current ice time.
role_time_interaction_model <- fit_analysis_workflow(role_margin_outcomes, 'continued300', base::c(primary_predictors, 'CSAxToi'), model_type = 'logistic')
role_time_interaction_result <- clustered_term(role_time_interaction_model, role_margin_outcomes, term = 'CSAxToi') |>
  dplyr::transmute(parameter = 'CSAx-by-current-ice-time interaction', sampleSize = base::nrow(role_margin_outcomes), players = dplyr::n_distinct(role_margin_outcomes$playerId), estimate, stdError, statistic, pValue, confLow, confHigh, effect = base::exp(estimate), effectLow = base::exp(confLow), effectHigh = base::exp(confHigh), scale = 'odds ratio')

# Estimate listed-size association and CSAx-by-size modification.
size_interaction_outcomes <- roster_outcomes |>
  dplyr::mutate(CSAxListedSize = CSAx * listedSize)
size_interaction_model <- fit_analysis_workflow(size_interaction_outcomes, 'continued300', base::c(primary_predictors, 'CSAxListedSize'), model_type = 'logistic')
size_interaction_results <- dplyr::bind_rows(
  clustered_term(size_interaction_model, size_interaction_outcomes, term = 'CSAx'),
  clustered_term(size_interaction_model, size_interaction_outcomes, term = 'listedSize'),
  clustered_term(size_interaction_model, size_interaction_outcomes, term = 'CSAxListedSize')
) |>
  dplyr::mutate(parameter = base::c('CSAx at mean listed size', 'Listed size at mean CSAx', 'CSAx-by-listed-size interaction'), effect = base::exp(estimate), effectLow = base::exp(confLow), effectHigh = base::exp(confHigh), .before = 1L)

# Describe observed outcomes by within-season CSAx quartile.
quartile_profiles <- roster_outcomes |>
  dplyr::group_by(seasonId) |>
  dplyr::mutate(csaxQuartile = dplyr::ntile(CSAx, 4L)) |>
  dplyr::ungroup() |>
  dplyr::group_by(csaxQuartile) |>
  dplyr::summarise(forwardSeasons = dplyr::n(), pointsPer605v5 = base::mean(pointsPer605v5, na.rm = TRUE), satRelative5v5 = base::mean(satRelative5v5, na.rm = TRUE), toiPerGameMinutes = base::mean(timeOnIcePerGame, na.rm = TRUE) / 60, continuationRate = base::mean(continued300Flag), .groups = 'drop')
# Career-Stage Models ------------------------------------------------------

# Fit and summarize the pooled career-stage interaction.
career_interaction_outcomes <- roster_outcomes |>
  dplyr::mutate(careerStageMid = base::as.integer(careerStage == '3-6 prior seasons'), careerStageVeteran = base::as.integer(careerStage == '7+ prior seasons'), CSAxCareerStageMid = CSAx * careerStageMid, CSAxCareerStageVeteran = CSAx * careerStageVeteran)
career_interaction_predictors <- base::c(primary_predictors, 'careerStageMid', 'careerStageVeteran', 'CSAxCareerStageMid', 'CSAxCareerStageVeteran')
career_interaction_model <- fit_analysis_workflow(career_interaction_outcomes, 'continued300', career_interaction_predictors, model_type = 'logistic')
career_stage_slopes <- dplyr::bind_rows(
  clustered_linear_combination(career_interaction_model, career_interaction_outcomes, base::c(CSAx = 1), '0-2 prior seasons'),
  clustered_linear_combination(career_interaction_model, career_interaction_outcomes, base::c(CSAx = 1, CSAxCareerStageMid = 1), '3-6 prior seasons'),
  clustered_linear_combination(career_interaction_model, career_interaction_outcomes, base::c(CSAx = 1, CSAxCareerStageVeteran = 1), '7+ prior seasons')
) |>
  dplyr::transmute(careerStage = label, estimate, stdError, statistic, pValue, confLow, confHigh, effect = base::exp(estimate), effectLow = base::exp(confLow), effectHigh = base::exp(confHigh))
career_stage_wald <- clustered_joint_wald(career_interaction_model, career_interaction_outcomes, base::c('CSAxCareerStageMid', 'CSAxCareerStageVeteran')) |>
  dplyr::mutate(sampleSize = base::nrow(career_interaction_outcomes), players = dplyr::n_distinct(career_interaction_outcomes$playerId))

# Primary Bootstrap --------------------------------------------------------

# Calculate canonical probabilities, then propagate full-pipeline player sampling.
probability_grid <- base::seq(-2, 2, by = 0.1)
conditional_probability_estimates <- estimate_average_probabilities(continuation_model, roster_outcomes, probability_grid)
primary_bootstrap <- run_primary_bootstrap(roster_outcomes, primary_predictors, probability_grid)
bootstrap_summary <- summarize_primary_bootstrap(primary_bootstrap, conditional_continuation_result, conditional_probability_estimates$curve, conditional_probability_estimates$contrast)
continuation_result        <- bootstrap_summary$result
continuation_probabilities <- bootstrap_summary$probabilities
continuation_contrast      <- bootstrap_summary$contrast
if (base::nrow(primary_bootstrap$results) != xs_bootstrap_reps) base::stop('Primary full-pipeline bootstrap is incomplete.', call. = FALSE)

# Focused Robustness Checks ------------------------------------------------

# Fit leave-one-season-out and 500-minute models.
leave_one_season_results <- purrr::map_dfr(xs_behavior_seasons, function(excluded_season) {
  data <- roster_outcomes |>
    dplyr::filter(seasonId != excluded_season) |>
    dplyr::mutate(seasonFactor = forcats::fct_drop(seasonFactor))
  model <- fit_analysis_workflow(data, 'continued300', primary_predictors, model_type = 'logistic')
  summarize_analysis_result(model, data, 'Robustness', base::paste0('Excluding ', format_season(excluded_season)), scale = 'odds ratio')
})
minutes_outcomes <- roster_outcomes |>
  dplyr::filter(timeOnIce >= 500 * 60) |>
  dplyr::mutate(seasonFactor = forcats::fct_drop(seasonFactor))
minutes_model  <- fit_analysis_workflow(minutes_outcomes, 'continued300', primary_predictors, model_type = 'logistic')
minutes_result <- summarize_analysis_result(minutes_model, minutes_outcomes, 'Robustness', '500-minute behavior restriction', scale = 'odds ratio')

# Fit away-game and natural-spline reconstructions.
away_outcomes <- roster_outcomes |>
  dplyr::select(-CSAx) |>
  dplyr::inner_join(analysis_data$away_game_sensitivity$predictions |> dplyr::select(playerId, seasonId, CSAx), by = base::c('playerId', 'seasonId'))
away_model  <- fit_analysis_workflow(away_outcomes, 'continued300', primary_predictors, model_type = 'logistic')
away_result <- summarize_analysis_result(away_model, away_outcomes, 'Robustness', 'Away-game CSAx', scale = 'odds ratio')
flexible_outcomes <- roster_outcomes |>
  dplyr::select(-CSAx) |>
  dplyr::inner_join(analysis_data$flexible_calibration_sensitivity$predictions |> dplyr::select(playerId, seasonId, CSAx = flexibleCSAx), by = base::c('playerId', 'seasonId'))
flexible_model  <- fit_analysis_workflow(flexible_outcomes, 'continued300', primary_predictors, model_type = 'logistic')
flexible_result <- summarize_analysis_result(flexible_model, flexible_outcomes, 'Robustness', 'Natural-spline mean calibration', scale = 'odds ratio')

# Fit contact-only and interior-shot-only continuation models.
construct_sensitivity <- base::split(analysis_data$construct_predictions, analysis_data$construct_predictions$specification) |>
  purrr::imap_dfr(function(predictions, specification) {
    data <- roster_outcomes |>
      dplyr::select(-CSAx) |>
      dplyr::inner_join(predictions |> dplyr::select(playerId, seasonId, CSAx), by = base::c('playerId', 'seasonId'))
    model <- fit_analysis_workflow(data, 'continued300', primary_predictors, model_type = 'logistic')
    summarize_analysis_result(model, data, 'Construct sensitivity', specification, scale = 'odds ratio') |>
      dplyr::mutate(specification = specification, .before = 1L)
  }) |>
  dplyr::left_join(analysis_data$construct_validation, by = 'specification')
if (base::nrow(construct_sensitivity) != 2L) base::stop('Focused construct sensitivity is incomplete.', call. = FALSE)

# External Validation ------------------------------------------------------

# Prefer locked private ratings and otherwise reconstruct from public codes.
private_validation_paths <- base::c('validation_private/external_validation_ratings.csv', 'validation_private/external_validation_hashes.csv', 'validation_private/external_validation_key.csv')
if (base::all(base::file.exists(private_validation_paths))) {
  scouting_validation <- read_scouting_validation()
  scouting_validation$source <- 'private'
} else {
  scouting_validation <- read_public_scouting_validation(forward_seasons, provenance = analysis_data$provenance$externalValidation)
  base::message('Private scouting ratings are unavailable; reconstructed validation from validation/external_validation_data.csv.')
}
player_mean_csax <- forward_seasons |>
  dplyr::filter(playerId %in% scouting_validation$data$playerId) |>
  dplyr::group_by(playerId) |>
  dplyr::summarise(meanCSAx = base::mean(CSAx), observedSeasons = dplyr::n_distinct(seasonId), .groups = 'drop')
external_validation <- scouting_validation$data |>
  dplyr::inner_join(player_mean_csax, by = 'playerId')
if (base::nrow(external_validation) != 40L || dplyr::n_distinct(external_validation$playerId) != 40L || base::any(external_validation$observedSeasons != external_validation$eligibleSeasons)) base::stop('External-validation cohort or CSAx histories changed.', call. = FALSE)

# Write only codes, provenance, identifiers, hashes, and rounded means publicly.
validation_data <- external_validation |>
  dplyr::transmute(studyId, playerId, player = playerFullName, eligibleSeasons, firstSeason = format_season(firstSeasonId), draftYear, draftTeam, draftRound, draftOverall, sourceId, reportYear, publicationDate, sourcePage, sourceLocator, publicUrl, reportTextSha256, overallPhysicality, playsBiggerExplicit, activePhysicalEngagement, interiorPlay, meanCSAx = base::round(meanCSAx, 2L)) |>
  dplyr::arrange(studyId)
readr::write_csv(validation_data, 'validation/external_validation_data.csv')
public_validation <- read_public_scouting_validation(forward_seasons, provenance = base::list(ratingsSha256 = scouting_validation$lock$sha256[[1L]], lockedAt = scouting_validation$lock$lockedAt[[1L]]))
validation_code_columns <- base::c('studyId', 'playerId', 'overallPhysicality', 'playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay')
if (!base::isTRUE(base::all.equal(external_validation |> dplyr::select(dplyr::all_of(validation_code_columns)) |> dplyr::arrange(studyId), public_validation$data |> dplyr::select(dplyr::all_of(validation_code_columns)) |> dplyr::arrange(studyId), check.attributes = FALSE))) base::stop('Public and private external-validation codes differ.', call. = FALSE)

# Estimate the ordinal trend and all three planned cue contrasts.
validation_trend_model <- fit_analysis_workflow(external_validation, 'meanCSAx', 'overallPhysicality')
validation_trend <- clustered_term(validation_trend_model, external_validation, term = 'overallPhysicality') |>
  dplyr::mutate(label = 'External validation', outcome = 'Ordinal scouting physicality', sampleSize = base::nrow(external_validation), players = dplyr::n_distinct(external_validation$playerId), scale = 'CSAx per rating category', effect = estimate, effectLow = confLow, effectHigh = confHigh, .before = 1L)
validation_indicator_labels <- base::c(playsBiggerExplicit = 'Explicit plays-bigger language', activePhysicalEngagement = 'Active physical engagement', interiorPlay = 'Interior or wall play')
validation_indicators <- purrr::imap_dfr(validation_indicator_labels, function(label, indicator) {
  model <- fit_analysis_workflow(external_validation, 'meanCSAx', indicator)
  clustered_term(model, external_validation, term = indicator) |>
    dplyr::mutate(indicator = indicator, label = label, sampleSize = base::nrow(external_validation), positiveReports = base::sum(external_validation[[indicator]] == 1L), effect = estimate, effectLow = confLow, effectHigh = confHigh, .before = 1L)
}) |>
  dplyr::mutate(holmPValue = stats::p.adjust(pValue, method = 'holm'))
validation_summary <- tibble::tibble(matchedReports = base::nrow(external_validation), sources = dplyr::n_distinct(external_validation$sourceId), raterCount = 1L, ordinalSpearman = stats::cor(external_validation$meanCSAx, external_validation$overallPhysicality, method = 'spearman'), lockedAt = scouting_validation$lock$lockedAt[[1L]])
assert_finite(validation_trend, base::c('effect', 'effectLow', 'effectHigh', 'pValue'), 'External-validation trend')
assert_finite(validation_indicators, base::c('effect', 'effectLow', 'effectHigh', 'pValue', 'holmPValue'), 'External-validation indicators')
if (base::nrow(validation_indicators) != 3L || validation_indicators$positiveReports[validation_indicators$indicator == 'playsBiggerExplicit'] != 2L) base::stop('External-validation cue coverage changed.', call. = FALSE)

# Player Stories -----------------------------------------------------------

# Create the recent qualified ranking before summarizing named examples.
latest_season <- base::max(forward_seasons$seasonId)
ranking_cohort <- forward_seasons |>
  dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60) |>
  dplyr::arrange(dplyr::desc(CSAx), playerId) |>
  dplyr::mutate(Rank = dplyr::row_number())
if (base::nrow(ranking_cohort) != 388L) base::stop('Recent ranking cohort does not contain 388 qualified forwards.', call. = FALSE)

# Summarize three full stories and one brief large-frame illustration.
case_study_names <- base::c('Zach Benson', 'Jake Neighbours', 'William Eklund', 'Brady Tkachuk')
case_study_seasons <- forward_seasons |>
  dplyr::group_by(seasonId) |>
  dplyr::mutate(
    hitsDeliveredPercentile = 100 * dplyr::percent_rank(hitsPer60),
    hitsReceivedPercentile = 100 * dplyr::percent_rank(hitsReceivedPer60),
    blocksPercentile = 100 * dplyr::percent_rank(blockedShotsPer60),
    fightsPercentile = 100 * dplyr::percent_rank(fightsPer60),
    netFrontPercentile = 100 * dplyr::percent_rank(netFrontAttemptShare),
    deflectionPercentile = 100 * dplyr::percent_rank(deflectionShare),
    closeShotPercentile = 100 * dplyr::percent_rank(-medianShotDistance)
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(playerFullName %in% case_study_names) |>
  dplyr::arrange(playerFullName, seasonId)
scouting_case_profiles <- case_study_seasons |>
  dplyr::group_by(playerId, playerFullName) |>
  dplyr::summarise(
    eligibleSeasons = dplyr::n(),
    firstSeasonId = base::min(seasonId),
    lastSeasonId = base::max(seasonId),
    firstCSAx = dplyr::first(CSAx),
    lastCSAx = dplyr::last(CSAx),
    meanS = base::mean(listedSize),
    meanXS = base::mean(xS),
    meanCSAx = base::mean(CSAx),
    hitsDeliveredPercentile = base::mean(hitsDeliveredPercentile),
    hitsReceivedPercentile = base::mean(hitsReceivedPercentile),
    blocksPercentile = base::mean(blocksPercentile),
    fightsPercentile = base::mean(fightsPercentile),
    netFrontPercentile = base::mean(netFrontPercentile),
    deflectionPercentile = base::mean(deflectionPercentile),
    closeShotPercentile = base::mean(closeShotPercentile),
    csaxTrajectory = base::paste0(format_season(seasonId), ': ', base::formatC(CSAx, format = 'f', digits = 2L), collapse = '; '),
    .groups = 'drop'
  ) |>
  dplyr::left_join(ranking_cohort |> dplyr::select(playerId, latestRank = Rank, latestCSAx = CSAx), by = 'playerId') |>
  dplyr::mutate(displayOrder = base::match(playerFullName, case_study_names), storyRole = dplyr::if_else(playerFullName == 'Brady Tkachuk', 'brief illustration', 'full story')) |>
  dplyr::arrange(displayOrder)
if (base::nrow(scouting_case_profiles) != 4L || base::anyNA(scouting_case_profiles)) base::stop('Named player-story summaries are incomplete.', call. = FALSE)

# Playoff Outcomes ---------------------------------------------------------

# Assemble team qualification and player availability.
playoff_teams <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('outcomes_', season_id, '.rds')))$playoffTeam |>
    dplyr::mutate(seasonId = season_id)
})
playoff_players <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  outcomes <- base::readRDS(base::file.path('data/cache', base::paste0('outcomes_', season_id, '.rds')))
  outcomes$playoffPlayer |>
    dplyr::left_join(outcomes$playoffTime, by = 'playerId') |>
    dplyr::mutate(seasonId = season_id)
})
playoff_outcomes <- roster_outcomes |>
  dplyr::inner_join(playoff_teams, by = base::c('seasonId', 'finalTeamId' = 'teamId')) |>
  dplyr::left_join(playoff_players, by = base::c('playerId', 'seasonId', 'finalTeamId' = 'teamId')) |>
  dplyr::mutate(playoffGamesDressed = dplyr::coalesce(playoffGamesDressed, 0), playoffTimeOnIce = dplyr::coalesce(playoffTimeOnIce, 0), playoffDressedShare = playoffGamesDressed / teamPlayoffGames, playoffToiPerTeamGame = playoffTimeOnIce / 60 / teamPlayoffGames)
playoff_dress_model  <- fit_analysis_workflow(playoff_outcomes, 'playoffDressedShare', primary_predictors)
playoff_dress_result <- summarize_analysis_result(playoff_dress_model, playoff_outcomes, 'Exploratory', 'Playoff games-dressed share')
playoff_toi_model    <- fit_analysis_workflow(playoff_outcomes, 'playoffToiPerTeamGame', primary_predictors)
playoff_toi_result   <- summarize_analysis_result(playoff_toi_model, playoff_outcomes, 'Exploratory', 'Playoff TOI/team game')

# Contract Outcomes --------------------------------------------------------

# Identify audited external veteran contracts with prior-season CSAx.
players <- base::readRDS('data/cache/players.rds') |>
  dplyr::select(playerId, birthDate)
contracts <- base::readRDS('data/cache/contracts.rds') |>
  dplyr::left_join(players, by = 'playerId') |>
  dplyr::arrange(playerId, startSeasonId) |>
  dplyr::group_by(playerId) |>
  dplyr::mutate(previousAav = dplyr::lag(aav), previousTerm = dplyr::lag(term)) |>
  dplyr::ungroup() |>
  dplyr::filter(positionCode %in% base::c('C', 'L', 'R'), ageAtSigning >= 27, startSeasonId %in% xs_contract_seasons)
contract_keys <- contracts |>
  dplyr::count(playerId, startSeasonId, name = 'contractKeyCount')
contracts <- contracts |>
  dplyr::left_join(contract_keys, by = base::c('playerId', 'startSeasonId')) |>
  dplyr::filter(contractKeyCount == 1L, !base::is.na(previousAav), previousAav > 0, !base::is.na(previousTerm)) |>
  dplyr::mutate(priorSeasonId = previous_season_id(startSeasonId))
transaction_audit <- audit_contract_transactions(contracts, build_transaction_clauses(base::readRDS('data/cache/transactions.rds')))
contracts <- contracts |>
  dplyr::mutate(contractRow = dplyr::row_number()) |>
  dplyr::left_join(transaction_audit, by = 'contractRow')
cap_table <- tibble::tibble(startSeasonId = xs_contract_seasons, capMillions = base::c(82.5, 83.5, 88, 95.5))
season_calendar <- base::readRDS('data/cache/seasons.rds') |>
  dplyr::transmute(priorSeasonId = seasonId, priorRegularEndDate = base::as.Date(regularSeasonEndDate))
contracts <- contracts |>
  dplyr::left_join(cap_table, by = 'startSeasonId') |>
  dplyr::left_join(season_calendar, by = 'priorSeasonId') |>
  dplyr::mutate(timingLeak = !base::is.na(matchDate) & matchDate <= priorRegularEndDate)
external_contracts <- contracts |>
  dplyr::inner_join(regular_outcomes |> dplyr::select(playerId, priorSeasonId = seasonId, finalPriorTeamId = finalTeamId), by = base::c('playerId', 'priorSeasonId')) |>
  dplyr::filter(signedWithTeamId != finalPriorTeamId, !timingLeak) |>
  dplyr::inner_join(forward_seasons, by = base::c('playerId', 'priorSeasonId' = 'seasonId')) |>
  dplyr::mutate(logCapAav = base::log(aav / (capMillions * 1e6)), signingAgeC = ageAtSigning - base::mean(ageAtSigning), signingAgeSquared = signingAgeC^2, contractGamesC = standardize_complete(gamesPlayed), contractToiC = standardize_complete(timeOnIcePerGame), contractPointsC = standardize_complete(pointsPer605v5), contractSatC = standardize_complete(satRelative5v5), previousLogAavC = standardize_complete(base::log(previousAav)), previousTermC = standardize_complete(previousTerm), contractSeasonFactor = base::factor(startSeasonId))
assert_unique(external_contracts, base::c('playerId', 'startSeasonId'), 'External contracts')
if (base::nrow(external_contracts) != 183L) base::stop('External-contract cohort changed from 183 signings.', call. = FALSE)
contract_predictors <- base::c('CSAx', 'listedSize', 'signingAgeC', 'signingAgeSquared', 'contractGamesC', 'contractToiC', 'contractPointsC', 'contractSatC', 'previousLogAavC', 'previousTermC', 'contractSeasonFactor')
contract_aav_model  <- fit_analysis_workflow(external_contracts, 'logCapAav', contract_predictors)
contract_aav_result <- summarize_analysis_result(contract_aav_model, external_contracts, 'Supporting', 'External-contract AAV', scale = 'percent')
contract_term_model <- fit_analysis_workflow(external_contracts, 'term', contract_predictors)
contract_term_result <- summarize_analysis_result(contract_term_model, external_contracts, 'Supporting', 'External-contract term')

# Team Patterns ------------------------------------------------------------

# Aggregate player-game exposure and public expected-goal outcomes by team-season.
team_roster_exposure <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('outcomes_', season_id, '.rds')))$regularPlayerTeam |>
    dplyr::mutate(seasonId = season_id)
})
team_expected_goals <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('expected_goals_', season_id, '.rds')))$team |>
    dplyr::mutate(seasonId = season_id)
})
team_style_seasons <- team_roster_exposure |>
  dplyr::left_join(forward_seasons |> dplyr::select(playerId, seasonId, CSAx, listedSize, age), by = base::c('playerId', 'seasonId')) |>
  dplyr::group_by(seasonId, teamId) |>
  dplyr::summarise(eligibleForwardPlayerGames = base::sum(teamGamesDressed[!base::is.na(CSAx)]), allForwardPlayerGames = base::sum(teamGamesDressed), coverage = eligibleForwardPlayerGames / allForwardPlayerGames, teamCSAx = stats::weighted.mean(CSAx, teamGamesDressed, na.rm = TRUE), teamListedSize = stats::weighted.mean(listedSize, teamGamesDressed, na.rm = TRUE), teamAge = stats::weighted.mean(age, teamGamesDressed, na.rm = TRUE), .groups = 'drop') |>
  dplyr::inner_join(team_expected_goals, by = base::c('teamId', 'seasonId')) |>
  dplyr::left_join(base::readRDS('data/cache/teams.rds') |> dplyr::select(teamId, teamFullName, teamTriCode), by = 'teamId') |>
  dplyr::group_by(seasonId) |>
  dplyr::mutate(teamCSAxZ = standardize_vector(teamCSAx), teamGAxZ = standardize_vector(GAx)) |>
  dplyr::ungroup()
assert_unique(team_style_seasons, base::c('teamId', 'seasonId'), 'Team style seasons')
if (base::nrow(team_style_seasons) != 128L || base::min(team_style_seasons$coverage) < 0.85) base::stop('Team-style panel or coverage changed.', call. = FALSE)
team_descriptive_summary <- tibble::tibble(teamSeasons = base::nrow(team_style_seasons), teams = dplyr::n_distinct(team_style_seasons$teamId), correlation = stats::cor(team_style_seasons$teamCSAxZ, team_style_seasons$teamGAxZ), medianCoverage = stats::median(team_style_seasons$coverage), minimumCoverage = base::min(team_style_seasons$coverage))

# Compare 2024-25 regular-season and playoff five-on-five shot quality.
latest_expected_goals <- base::readRDS(base::file.path('data/cache', base::paste0('expected_goals_', latest_season, '.rds')))
regular_five_on_five <- latest_expected_goals$teamFiveOnFive |>
  dplyr::filter(gameTypeId == 2L) |>
  dplyr::transmute(teamId, regularAttempts = attempts, regularXGoals = xGoals, regularXGoalsPerAttempt = xGoalsPerAttempt)
playoff_five_on_five <- latest_expected_goals$teamFiveOnFive |>
  dplyr::filter(gameTypeId == 3L) |>
  dplyr::transmute(teamId, playoffAttempts = attempts, playoffXGoals = xGoals, playoffXGoalsPerAttempt = xGoalsPerAttempt)
team_playoff_shot_quality <- team_style_seasons |>
  dplyr::filter(seasonId == latest_season) |>
  dplyr::inner_join(regular_five_on_five, by = 'teamId') |>
  dplyr::inner_join(playoff_five_on_five, by = 'teamId') |>
  dplyr::mutate(absoluteXGoalsPerAttemptChange = base::abs(playoffXGoalsPerAttempt - regularXGoalsPerAttempt)) |>
  dplyr::select(seasonId, teamId, teamFullName, teamTriCode, teamCSAx, teamCSAxZ, regularAttempts, regularXGoals, regularXGoalsPerAttempt, playoffAttempts, playoffXGoals, playoffXGoalsPerAttempt, absoluteXGoalsPerAttemptChange)
team_playoff_shot_summary <- tibble::tibble(seasonId = latest_season, teams = base::nrow(team_playoff_shot_quality), correlation = stats::cor(team_playoff_shot_quality$teamCSAx, team_playoff_shot_quality$absoluteXGoalsPerAttemptChange), minimumPlayoffAttempts = base::min(team_playoff_shot_quality$playoffAttempts), maximumPlayoffAttempts = base::max(team_playoff_shot_quality$playoffAttempts))
if (base::nrow(team_playoff_shot_quality) != 16L) base::stop('Playoff shot-quality panel changed.', call. = FALSE)

# Rankings and Public CSV Files -------------------------------------------

# Write the 388-player qualified ranking.
ranking_supplement <- ranking_cohort |>
  dplyr::transmute(season = format_season(seasonId), CSAxRank = Rank, playerId, player = playerFullName, heightInches = height, weightPounds = weight, S = base::round(listedSize, 2L), xS = base::round(xS, 2L), CSAx = base::round(CSAx, 2L), minutes = base::round(timeOnIce / 60))
ranking_path <- base::file.path(paper_directory, 'csax_rankings_2024-25.csv')
readr::write_csv(ranking_supplement, ranking_path)
written_rankings <- readr::read_csv(ranking_path, show_col_types = FALSE)
if (base::nrow(written_rankings) != 388L || !base::identical(base::as.integer(written_rankings$CSAxRank), base::seq_len(388L))) base::stop('Player ranking file failed validation.', call. = FALSE)
recent_rankings <- dplyr::bind_rows(written_rankings |> dplyr::slice_head(n = 10L), written_rankings |> dplyr::slice_tail(n = 10L)) |>
  dplyr::transmute(Rank = CSAxRank, Player = player, Height = base::paste0(heightInches %/% 12, base::intToUtf8(39L), heightInches %% 12, base::intToUtf8(34L)), Weight = weightPounds, S, xS, CSAx, Minutes = minutes)

# Write the 32-team recent-season ranking.
team_ranking_supplement <- team_style_seasons |>
  dplyr::filter(seasonId == latest_season) |>
  dplyr::arrange(dplyr::desc(teamCSAx), teamId) |>
  dplyr::mutate(teamCSAxRank = dplyr::row_number()) |>
  dplyr::transmute(season = format_season(seasonId), teamCSAxRank, teamId, team = teamFullName, teamCode = teamTriCode, teamCSAx = base::round(teamCSAx, 2L), goals, xGoals = base::round(xGoals, 2L), GAx = base::round(GAx, 2L), eligibleForwardPlayerGames, forwardPlayerGameCoveragePct = base::round(100 * coverage, 2L)) |>
  dplyr::left_join(regular_five_on_five |> dplyr::transmute(teamId, regularSeasonFiveOnFiveXGoalsPerAttempt = format_fixed(regularXGoalsPerAttempt, 4L)), by = 'teamId') |>
  dplyr::left_join(team_playoff_shot_quality |> dplyr::transmute(teamId, playoffFiveOnFiveXGoalsPerAttempt = format_fixed(playoffXGoalsPerAttempt, 4L), absoluteFiveOnFiveXGoalsPerAttemptChange = format_fixed(absoluteXGoalsPerAttemptChange, 4L)), by = 'teamId')
team_ranking_path <- base::file.path(paper_directory, 'team_csax_rankings_2024-25.csv')
readr::write_csv(team_ranking_supplement, team_ranking_path)
if (base::nrow(readr::read_csv(team_ranking_path, show_col_types = FALSE)) != 32L) base::stop('Team ranking file failed validation.', call. = FALSE)

# Figure Generation --------------------------------------------------------

# Define publication colors.
navy <- '#17324D'
gold <- '#C8892B'
gray <- '#77818C'

# Plot the shrinkage artifact and calibrated residual.
raw_plot <- ggplot2::ggplot(forward_seasons, ggplot2::aes(listedSize, SAx)) +
  ggplot2::geom_point(alpha = 0.12, size = 0.55, color = gray) +
  ggplot2::geom_smooth(method = 'lm', se = FALSE, linewidth = 0.8, color = gold) +
  ggplot2::labs(title = 'Naive size above expected', subtitle = base::paste0('Correlation with listed size: ', format_fixed(stats::cor(forward_seasons$SAx, forward_seasons$listedSize), 2L)), x = 'Listed size, S (SD)', y = 'xS - S (SD)') +
  theme_xs()
calibrated_plot <- ggplot2::ggplot(forward_seasons, ggplot2::aes(listedSize, CSAx)) +
  ggplot2::geom_point(alpha = 0.12, size = 0.55, color = gray) +
  ggplot2::geom_smooth(method = 'lm', se = FALSE, linewidth = 0.8, color = navy) +
  ggplot2::labs(title = 'Calibrated size above expected', subtitle = base::paste0('Correlation with listed size: ', format_fixed(stats::cor(forward_seasons$CSAx, forward_seasons$listedSize), 2L)), x = 'Listed size, S (SD)', y = 'CSAx (residual SD)') +
  theme_xs()
shrinkage_figure <- patchwork::wrap_plots(raw_plot, calibrated_plot) +
  patchwork::plot_annotation(title = 'Calibration removes mechanical small-player advantage', theme = ggplot2::theme(plot.title = ggplot2::element_text(face = 'bold', size = 12)))
save_pdf_figure(shrinkage_figure, base::file.path(figure_directory, 'shrinkage.pdf'), width = 7.1, height = 3.35)

# Plot bootstrap continuation probabilities.
probability_labels <- continuation_probabilities |>
  dplyr::filter(CSAx %in% base::c(-1, 0, 1)) |>
  dplyr::mutate(label = scales::percent(probability, accuracy = 0.01))
probability_limits <- base::c(base::max(0, base::min(continuation_probabilities$confLow, continuation_probabilities$probability) - 0.015), base::min(1, base::max(continuation_probabilities$confHigh, continuation_probabilities$probability) + 0.015))
roster_figure <- ggplot2::ggplot(continuation_probabilities, ggplot2::aes(CSAx, probability)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = confLow, ymax = confHigh), fill = navy, alpha = 0.14) +
  ggplot2::geom_line(linewidth = 1, color = navy) +
  ggplot2::geom_point(data = probability_labels, size = 2.4, color = gold) +
  ggplot2::geom_text(data = probability_labels, ggplot2::aes(label = label), vjust = -0.8, size = 3, fontface = 'bold') +
  ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 1), breaks = scales::breaks_pretty(n = 5L), limits = probability_limits) +
  ggplot2::labs(title = 'CSAx tracks NHL continuation in comparable roles', subtitle = 'Average predictions with full-pipeline player-bootstrap 95% intervals', x = 'Calibrated size above expected, CSAx (residual SD)', y = 'Probability of at least 300 next-season minutes') +
  theme_xs()
save_pdf_figure(roster_figure, base::file.path(figure_directory, 'roster_continuation.pdf'), width = 6.5, height = 3.8)

# Plot the ten strict feature coefficients.
feature_labels <- base::c(hitsPer60 = 'Hits delivered/60', hitsReceivedPer60 = 'Hits received/60', blockedShotsPer60 = 'Blocks/60', penaltiesTakenPer60 = 'Penalties taken/60', penaltiesDrawnPer60 = 'Penalties drawn/60', fightsPer60 = 'Fights/60', netFrontAttemptShare = 'Net-front attempt share', deflectionShare = 'Tip/deflection share', medianShotDistance = 'Median shot distance', backhandShare = 'Backhand share')
coefficient_summary <- analysis_data$xs_coefficients |>
  dplyr::group_by(feature) |>
  dplyr::summarise(median = stats::median(coefficient), lower = stats::quantile(coefficient, 0.25), upper = stats::quantile(coefficient, 0.75), .groups = 'drop') |>
  dplyr::mutate(label = dplyr::recode(feature, !!!feature_labels), label = forcats::fct_reorder(label, median))
coefficient_figure <- ggplot2::ggplot(coefficient_summary, ggplot2::aes(median, label)) +
  ggplot2::geom_vline(xintercept = 0, color = '#D1D5DB') +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper), width = 0, orientation = 'y', color = gray) +
  ggplot2::geom_point(size = 2, color = navy) +
  ggplot2::labs(title = 'What recorded behavior predicts size?', subtitle = 'Median and interquartile range of season ridge coefficients', x = 'Standardized ridge coefficient', y = NULL) +
  theme_xs()
save_pdf_figure(coefficient_figure, base::file.path(figure_directory, 'feature_coefficients.pdf'), width = 6.5, height = 3.8)

# Result Assembly ----------------------------------------------------------

# Assemble reported estimates.
application_results <- dplyr::bind_rows(continuation_result, appearance_result, games_result, toi_result, prior_role_result, team_season_cluster_result, leave_one_season_results, minutes_result, away_result, flexible_result, playoff_dress_result, playoff_toi_result, contract_aav_result, contract_term_result)

# Save the complete strict analysis object without private prose or notes.
analysis_data$roster_outcomes <- roster_outcomes
analysis_data$prior_role_coverage <- prior_role_coverage
analysis_data$conditioning_results <- conditioning_results
analysis_data$role_timing_results <- role_timing_results
analysis_data$role_margin_summary <- role_margin_summary
analysis_data$role_time_interaction_result <- role_time_interaction_result
analysis_data$application_results <- application_results
analysis_data$size_interaction_results <- size_interaction_results
analysis_data$quartile_profiles <- quartile_profiles
analysis_data$career_stage_slopes <- career_stage_slopes
analysis_data$career_stage_wald <- career_stage_wald
analysis_data$construct_sensitivity <- construct_sensitivity
analysis_data$flexible_calibration_sensitivity$continuation <- flexible_result
analysis_data$away_game_sensitivity$continuation <- away_result
analysis_data$external_validation <- validation_data
analysis_data$external_validation_trend <- validation_trend
analysis_data$external_validation_indicators <- validation_indicators
analysis_data$external_validation_summary <- validation_summary
analysis_data$scouting_case_profiles <- scouting_case_profiles
analysis_data$team_style_seasons <- team_style_seasons
analysis_data$team_descriptive_summary <- team_descriptive_summary
analysis_data$team_playoff_shot_summary <- team_playoff_shot_summary
analysis_data$continuation_probabilities <- continuation_probabilities
analysis_data$continuation_contrast <- continuation_contrast
analysis_data$primary_bootstrap <- base::list(configuration = primary_bootstrap$configuration, replicates = primary_bootstrap$results, probabilityReplicates = primary_bootstrap$probabilities, conditionalResult = conditional_continuation_result, conditionalProbabilities = conditional_probability_estimates$curve, conditionalContrast = conditional_probability_estimates$contrast)
analysis_data$recent_rankings <- recent_rankings
analysis_data$coefficient_summary <- coefficient_summary
analysis_data$provenance$confidenceLevel <- confidence_level
analysis_data$provenance$primaryBootstrap <- primary_bootstrap$configuration
analysis_data$provenance$externalValidation <- base::list(matchedReports = validation_summary$matchedReports[[1L]], raterCount = 1L, ratingsSha256 = scouting_validation$lock$sha256[[1L]], lockedAt = base::as.character(scouting_validation$lock$lockedAt[[1L]]))
analysis_data$provenance$transactionMatchRate <- base::mean(!base::is.na(contracts$matchDate))
analysis_data$provenance$analyzedAt <- base::format(base::Sys.time(), tz = 'America/New_York', usetz = TRUE)
analysis_data$xs_tuning <- NULL
analysis_data$construct_predictions <- NULL
analysis_data$construct_performance <- NULL
analysis_data$flexible_calibration_sensitivity$predictions <- NULL
analysis_data$away_game_sensitivity$predictions <- NULL
analysis_data$away_game_sensitivity$performance <- NULL
base::saveRDS(analysis_data, 'data/analysis_data.rds', compress = 'xz')

# Report analysis completion.
base::message('Analyzed ', base::nrow(roster_outcomes), ' roster outcomes, ', base::nrow(external_validation), ' blinded scouting reports, ', base::nrow(external_contracts), ' external contracts, and ', base::nrow(team_style_seasons), ' team-seasons.')

# Setup --------------------------------------------------------------------

# Load helper functions.
base::source('R/functions.R')

# Load strict season features and current rosters.
prepared_features <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('features_', season_id, '.rds')))
})
current_rosters <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('outcomes_', season_id, '.rds')))$regularRoster |>
    dplyr::mutate(seasonId = season_id)
})

# Eligibility --------------------------------------------------------------

# Select eligible forwards and calculate listed size within season.
eligible_forwards <- prepared_features |>
  dplyr::filter(positionCode %in% base::c('C', 'L', 'R'), timeOnIce >= xs_minutes * 60, !base::is.na(height), !base::is.na(weight), !base::is.na(birthDate)) |>
  dplyr::left_join(current_rosters, by = base::c('playerId', 'seasonId')) |>
  dplyr::mutate(age = calculate_season_age(birthDate, seasonId)) |>
  dplyr::group_by(seasonId) |>
  dplyr::mutate(zHeight = standardize_vector(height), zWeight = standardize_vector(weight), listedSize = standardize_vector((zHeight + zWeight) / base::sqrt(2))) |>
  dplyr::ungroup() |>
  dplyr::arrange(seasonId, playerId)

# Validate the scientific panel and feature provenance.
assert_unique(eligible_forwards, base::c('playerId', 'seasonId'), 'Eligible forwards')
assert_columns(eligible_forwards, xs_features, 'Strict eligible-forward features')
discarded_features <- base::c('giveawaysPer60', 'takeawaysPer60', 'faceoffsPer60', 'individualSatForPer60', 'individualShotsForPer60', 'slapShare')
if (base::any(discarded_features %in% base::names(eligible_forwards))) base::stop('A discarded feature remains in the strict scientific panel.', call. = FALSE)
if (base::any(eligible_forwards$height < 60 | eligible_forwards$height > 84 | eligible_forwards$weight < 140 | eligible_forwards$weight > 300)) base::stop('Implausible biometric value found among eligible forwards.', call. = FALSE)
if (base::any(base::vapply(base::split(eligible_forwards, eligible_forwards$seasonId), base::nrow, base::integer(1L)) < 100L)) base::stop('Season contains too few eligible forwards for 10-fold modeling.', call. = FALSE)

# Expected Size Models -----------------------------------------------------

# Fit five repeated nested held-out models in each season.
season_data <- base::split(eligible_forwards, eligible_forwards$seasonId)
season_fits <- purrr::imap(season_data, function(data, season_name) {
  base::message('Fitting strict expected size for ', season_name, '.')
  fit_expected_size(data, seed = xs_seed + base::as.integer(season_name))
})

# Assemble the strict panel and diagnostics.
forward_seasons <- purrr::map2_dfr(season_data, season_fits, function(data, fit) {
  dplyr::bind_cols(data, fit$predictions |> dplyr::select(xS, SAx, expectedXSGivenS, CSAx))
})
flexible_predictions <- purrr::map2_dfr(season_data, season_fits, function(data, fit) {
  dplyr::bind_cols(data |> dplyr::select(playerId, seasonId, listedSize, timeOnIce), fit$predictions |> dplyr::select(flexibleExpectedXSGivenS, flexibleCSAx))
})
xs_performance <- purrr::imap_dfr(season_fits, function(fit, season_name) {
  fit$performance |> dplyr::mutate(seasonId = base::as.integer(season_name), .before = 1L)
})
xs_coefficients <- purrr::imap_dfr(season_fits, function(fit, season_name) {
  fit$coefficients |> dplyr::mutate(seasonId = base::as.integer(season_name), .before = 1L)
})
xs_tuning <- purrr::imap_dfr(season_fits, function(fit, season_name) {
  fit$tuning |> dplyr::mutate(seasonId = base::as.integer(season_name), .before = 1L)
})

# Calibration Diagnostics -------------------------------------------------

# Describe raw shrinkage and calibrated size agreement.
calibration_diagnostics <- forward_seasons |>
  dplyr::group_by(seasonId) |>
  dplyr::group_modify(function(data, key) {
    slope <- stats::coef(stats::lm(xS ~ listedSize, data = data))[['listedSize']]
    tibble::tibble(
      n = base::nrow(data),
      xSListedSlope = base::unname(slope),
      xSListedCorrelation = stats::cor(data$xS, data$listedSize),
      naiveSAxListedCorrelation = stats::cor(data$SAx, data$listedSize),
      csaxListedCorrelation = stats::cor(data$CSAx, data$listedSize),
      meanCSAx = base::mean(data$CSAx),
      sdCSAx = stats::sd(data$CSAx)
    )
  }) |>
  dplyr::ungroup()

# Summarize direct single-feature associations with listed size and CSAx.
feature_correlations <- purrr::map_dfr(xs_features, function(feature) {
  tibble::tibble(feature = feature, listedSizeCorrelation = stats::cor(forward_seasons[[feature]], forward_seasons$listedSize), csaxCorrelation = stats::cor(forward_seasons[[feature]], forward_seasons$CSAx))
}) |>
  dplyr::mutate(absoluteCsaxCorrelation = base::abs(csaxCorrelation)) |>
  dplyr::arrange(dplyr::desc(absoluteCsaxCorrelation), feature)

# Calculate adjacent-season stability.
csax_stability <- forward_seasons |>
  dplyr::select(playerId, seasonId, currentCSAx = CSAx) |>
  dplyr::mutate(nextSeasonId = next_season_id(seasonId)) |>
  dplyr::inner_join(forward_seasons |> dplyr::select(playerId, nextSeasonId = seasonId, nextCSAx = CSAx), by = base::c('playerId', 'nextSeasonId')) |>
  dplyr::group_by(seasonId, nextSeasonId) |>
  dplyr::summarise(n = dplyr::n(), correlation = stats::cor(currentCSAx, nextCSAx), .groups = 'drop')

# Summarize natural-spline calibration sensitivity.
flexible_calibration_validation <- flexible_predictions |>
  dplyr::left_join(forward_seasons |> dplyr::select(playerId, seasonId, CSAx), by = base::c('playerId', 'seasonId')) |>
  dplyr::group_by(seasonId) |>
  dplyr::summarise(n = dplyr::n(), csaxCorrelation = stats::cor(flexibleCSAx, CSAx), rankCorrelation = stats::cor(flexibleCSAx, CSAx, method = 'spearman'), listedCorrelation = stats::cor(flexibleCSAx, listedSize), .groups = 'drop')
latest_season <- base::max(forward_seasons$seasonId)
flexible_calibration_ranking <- forward_seasons |>
  dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60) |>
  dplyr::arrange(dplyr::desc(CSAx), playerId) |>
  dplyr::transmute(playerId, primaryRank = dplyr::row_number()) |>
  dplyr::inner_join(
    flexible_predictions |>
      dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60) |>
      dplyr::arrange(dplyr::desc(flexibleCSAx), playerId) |>
      dplyr::transmute(playerId, flexibleRank = dplyr::row_number()),
    by = 'playerId'
  ) |>
  dplyr::summarise(seasonId = latest_season, n = dplyr::n(), rankCorrelation = stats::cor(primaryRank, flexibleRank, method = 'spearman'), topTenOverlap = base::sum(primaryRank <= 10L & flexibleRank <= 10L), bottomTenOverlap = base::sum(primaryRank > n - 10L & flexibleRank > n - 10L))

# Away-Game Sensitivity ----------------------------------------------------

# Reconstruct the metric from away-game recording only.
away_features <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('away_features_', season_id, '.rds')))
})
away_forwards <- eligible_forwards |>
  dplyr::select(playerId, seasonId, listedSize, timeOnIce) |>
  dplyr::inner_join(away_features, by = base::c('playerId', 'seasonId')) |>
  dplyr::arrange(seasonId, playerId)
assert_unique(away_forwards, base::c('playerId', 'seasonId'), 'Away-game eligible forwards')
if (base::nrow(away_forwards) != base::nrow(eligible_forwards)) base::stop('Away-game aggregates do not cover the complete scientific panel.', call. = FALSE)
away_season_data <- base::split(away_forwards, away_forwards$seasonId)
away_season_fits <- purrr::imap(away_season_data, function(data, season_name) {
  base::message('Fitting strict away-game expected size for ', season_name, '.')
  fit_expected_size(data, seed = xs_seed + base::as.integer(season_name), fit_flexible_calibration = FALSE)
})
away_predictions <- purrr::map2_dfr(away_season_data, away_season_fits, function(data, fit) {
  dplyr::bind_cols(data |> dplyr::select(playerId, seasonId, awayTimeOnIce, awayGames), fit$predictions |> dplyr::select(xS, expectedXSGivenS, CSAx))
})
away_performance <- purrr::imap_dfr(away_season_fits, function(fit, season_name) {
  fit$performance |> dplyr::mutate(seasonId = base::as.integer(season_name), .before = 1L)
})
away_agreement <- away_predictions |>
  dplyr::left_join(forward_seasons |> dplyr::select(playerId, seasonId, listedSize, primaryXS = xS, primaryCSAx = CSAx), by = base::c('playerId', 'seasonId')) |>
  dplyr::group_by(seasonId) |>
  dplyr::summarise(n = dplyr::n(), xSCorrelation = stats::cor(xS, primaryXS), csaxCorrelation = stats::cor(CSAx, primaryCSAx), csaxRankCorrelation = stats::cor(CSAx, primaryCSAx, method = 'spearman'), listedCorrelation = stats::cor(CSAx, listedSize), .groups = 'drop')
away_ranks <- away_predictions |>
  dplyr::filter(seasonId == latest_season) |>
  dplyr::inner_join(forward_seasons |> dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60) |> dplyr::select(playerId), by = 'playerId') |>
  dplyr::arrange(dplyr::desc(CSAx), playerId) |>
  dplyr::transmute(playerId, awayRank = dplyr::row_number())
away_ranking_agreement <- forward_seasons |>
  dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60) |>
  dplyr::arrange(dplyr::desc(CSAx), playerId) |>
  dplyr::transmute(playerId, primaryRank = dplyr::row_number()) |>
  dplyr::inner_join(away_ranks, by = 'playerId') |>
  dplyr::summarise(seasonId = latest_season, n = dplyr::n(), rankCorrelation = stats::cor(primaryRank, awayRank, method = 'spearman'), topTenOverlap = base::sum(primaryRank <= 10L & awayRank <= 10L), bottomTenOverlap = base::sum(primaryRank > n - 10L & awayRank > n - 10L))

# Construct Checks ---------------------------------------------------------

# Rebuild contact and interior-shot components separately.
construct_definitions <- base::list('Contact actions' = xs_contact_features, 'Interior-shot actions' = xs_interior_features)
construct_fits <- purrr::imap(construct_definitions, function(features, specification) {
  base::message('Fitting construct check: ', specification, '.')
  purrr::imap(season_data, function(data, season_name) {
    fit_expected_size(data, seed = xs_seed + base::as.integer(season_name), features = features, fit_flexible_calibration = FALSE)
  })
})
construct_predictions <- purrr::imap_dfr(construct_fits, function(specification_fits, specification) {
  purrr::map2_dfr(season_data, specification_fits, function(data, fit) {
    dplyr::bind_cols(data |> dplyr::select(playerId, seasonId), fit$predictions |> dplyr::select(xS, CSAx))
  }) |>
    dplyr::mutate(specification = specification, .before = 1L)
})
construct_performance <- purrr::imap_dfr(construct_fits, function(specification_fits, specification) {
  purrr::imap_dfr(specification_fits, function(fit, season_name) {
    fit$performance |> dplyr::mutate(specification = specification, seasonId = base::as.integer(season_name), nestedRepeats = xs_repeats, .before = 1L)
  })
})
construct_validation <- construct_predictions |>
  dplyr::left_join(forward_seasons |> dplyr::select(playerId, seasonId, primaryCSAx = CSAx), by = base::c('playerId', 'seasonId')) |>
  dplyr::group_by(specification) |>
  dplyr::summarise(n = dplyr::n(), csaxCorrelation = stats::cor(CSAx, primaryCSAx), .groups = 'drop') |>
  dplyr::left_join(construct_performance |> dplyr::group_by(specification) |> dplyr::summarise(nestedRepeats = dplyr::first(nestedRepeats), meanXSRSquared = base::mean(rSquared), .groups = 'drop'), by = 'specification')

# Verification -------------------------------------------------------------

# Confirm strict construction invariants.
if (base::nrow(forward_seasons) != 1763L || dplyr::n_distinct(forward_seasons$playerId) != 613L) base::stop('Scientific panel differs from 1,763 forward-seasons and 613 players.', call. = FALSE)
if (base::nrow(forward_seasons |> dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60)) != 388L) base::stop('Recent ranking cohort differs from 388 qualified forwards.', call. = FALSE)
if (base::nrow(xs_tuning) != base::length(xs_behavior_seasons) * xs_repeats * xs_outer_folds) base::stop('Nested tuning coverage is incomplete.', call. = FALSE)
if (base::nrow(construct_validation) != 2L || base::any(construct_validation$nestedRepeats != xs_repeats)) base::stop('Focused construct checks are incomplete.', call. = FALSE)
if (base::any(base::abs(calibration_diagnostics$meanCSAx) > 0.01 | base::abs(calibration_diagnostics$sdCSAx - 1) > 0.01 | base::abs(calibration_diagnostics$csaxListedCorrelation) > 0.05)) base::stop('CSAx calibration validation failed.', call. = FALSE)
assert_finite(forward_seasons, base::c('listedSize', 'xS', 'SAx', 'expectedXSGivenS', 'CSAx'), 'Strict CSAx panel')
assert_finite(calibration_diagnostics, base::c('xSListedSlope', 'xSListedCorrelation', 'naiveSAxListedCorrelation', 'csaxListedCorrelation'), 'Calibration diagnostics')
assert_finite(feature_correlations, base::c('listedSizeCorrelation', 'csaxCorrelation', 'absoluteCsaxCorrelation'), 'Single-feature correlations')
assert_finite(away_predictions, base::c('awayTimeOnIce', 'awayGames', 'xS', 'expectedXSGivenS', 'CSAx'), 'Away-game predictions')
assert_finite(away_agreement, base::c('xSCorrelation', 'csaxCorrelation', 'csaxRankCorrelation', 'listedCorrelation'), 'Away-game agreement')

# Analysis Artifact --------------------------------------------------------

# Record strict metric provenance.
provenance <- base::readRDS('data/cache/provenance.rds')
provenance$metricDefinitions <- base::c(
  listedSize = 'Equal-weight within-season index of standardized listed height and weight',
  xS = 'Average of five outer-fold held-out behavior-predicted listed sizes',
  SAx = 'Naive xS minus listed size before calibration',
  CSAx = 'Within-season standardized residual from the nested held-out linear xS-on-listed-size calibration'
)
provenance$strictFeatures <- xs_features
provenance$featureEventScope <- 'Regular-season events excluding shootouts'
provenance$nestedCrossFitting <- base::list(repeats = xs_repeats, outerFolds = xs_outer_folds, innerFolds = xs_inner_folds, penaltyGrid = 10^base::seq(-4, 2, length.out = 20L))
provenance$constructFeatures <- construct_definitions
provenance$flexibleCalibration <- base::list(degreesFreedom = 3L, calibrationData = 'Inner out-of-fold xS predictions inside each outer training sample', repeats = xs_repeats)
provenance$awayGameSensitivity <- base::list(features = xs_features, eventScope = 'Regular-season away events', opportunity = 'Away-game shift time on ice', eligibility = 'Full-season regular-season minutes', repeats = xs_repeats)

# Save the lean strict object.
analysis_data <- base::list(
  forward_seasons = forward_seasons,
  xs_performance = xs_performance,
  xs_tuning = xs_tuning,
  xs_coefficients = xs_coefficients,
  calibration_diagnostics = calibration_diagnostics,
  feature_correlations = feature_correlations,
  csax_stability = csax_stability,
  flexible_calibration_sensitivity = base::list(predictions = flexible_predictions, validation = flexible_calibration_validation, rankingAgreement = flexible_calibration_ranking),
  construct_predictions = construct_predictions,
  construct_performance = construct_performance,
  construct_validation = construct_validation,
  away_game_sensitivity = base::list(predictions = away_predictions, performance = away_performance, agreement = away_agreement, rankingAgreement = away_ranking_agreement),
  provenance = provenance
)
base::saveRDS(analysis_data, 'data/analysis_data.rds', compress = 'xz')

# Report construction completion.
base::message('Built strict xS and CSAx for ', base::nrow(forward_seasons), ' forward-seasons across ', dplyr::n_distinct(forward_seasons$playerId), ' players.')

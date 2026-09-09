# Analysis objects ----

# Load the strict publication analysis.
analysis_path <- if (base::file.exists('../../data/analysis_data.rds')) '../../data/analysis_data.rds' else '../data/analysis_data.rds'
analysis        <- base::readRDS(analysis_path)
forward_seasons <- analysis$forward_seasons
roster_outcomes <- analysis$roster_outcomes
results         <- analysis$application_results

# Formatting helpers ----

# Format fixed decimals without negative zero.
format_number <- function(x, digits = 2L) {
  rounded <- base::round(x, digits)
  rounded[!base::is.na(rounded) & rounded == 0] <- 0
  base::formatC(rounded, format = 'f', digits = digits)
}

# Format percentages.
format_percent <- function(x, digits = 2L) {
  base::paste0(format_number(100 * x, digits), '\\%')
}

# Format estimates and confidence intervals.
format_interval <- function(estimate, lower, upper, digits = 2L) {
  base::paste0(format_number(estimate, digits), ' (', format_number(lower, digits), ', ', format_number(upper, digits), ')')
}

# Format p-values.
format_p_value <- function(x) {
  if (x < 0.001) '<0.001' else format_number(x, 3L)
}

# Locate a named application result.
find_result <- function(outcome) {
  result <- results[base::match(outcome, results$outcome), ]
  if (base::nrow(result) != 1L || base::anyNA(result$outcome)) base::stop(base::paste0('Manuscript result is unavailable: ', outcome, '.'), call. = FALSE)
  result
}

# Locate a modeled continuation probability.
find_probability <- function(csax_value) {
  probabilities <- analysis$continuation_probabilities
  probabilities[base::which.min(base::abs(probabilities$CSAx - csax_value)), ]
}

# Result summaries ----

# Extract roster and organizational estimates.
continuation_result <- find_result('Next-season 300-minute continuation')
appearance_result   <- find_result('Any next-season NHL appearance')
games_result        <- find_result('Next-season games dressed')
toi_result          <- find_result('Next-season TOI/game')
prior_role_result   <- find_result('Prior-season role conditioning')
two_way_result      <- find_result('Player and team-season clustering')
minutes_result      <- find_result('500-minute behavior restriction')
away_result         <- find_result('Away-game CSAx')
flexible_result     <- find_result('Natural-spline mean calibration')
contract_term_result <- find_result('External-contract term')
playoff_dress_result <- find_result('Playoff games-dressed share')
playoff_toi_result  <- find_result('Playoff TOI/team game')
leave_one_results <- results |>
  dplyr::filter(base::grepl('^Excluding 202[1-4]-', outcome))

# Extract conditioning, construct, interaction, and career-stage estimates.
conditioning_results <- analysis$conditioning_results
role_timing_results  <- analysis$role_timing_results
same_sample_current_result <- role_timing_results |>
  dplyr::filter(specification == 'Current games and ice time') |>
  dplyr::slice_head(n = 1L)
same_sample_prior_result <- role_timing_results |>
  dplyr::filter(specification == 'Prior games and ice time') |>
  dplyr::slice_head(n = 1L)
role_margin_summary <- analysis$role_margin_summary
role_time_interaction_result <- analysis$role_time_interaction_result
contact_result <- analysis$construct_sensitivity |>
  dplyr::filter(specification == 'Contact actions') |>
  dplyr::slice_head(n = 1L)
interior_result <- analysis$construct_sensitivity |>
  dplyr::filter(specification == 'Interior-shot actions') |>
  dplyr::slice_head(n = 1L)
size_main_result <- analysis$size_interaction_results |>
  dplyr::filter(parameter == 'Listed size at mean CSAx') |>
  dplyr::slice_head(n = 1L)
size_interaction_result <- analysis$size_interaction_results |>
  dplyr::filter(parameter == 'CSAx-by-listed-size interaction') |>
  dplyr::slice_head(n = 1L)
stage_early_result <- analysis$career_stage_slopes |>
  dplyr::filter(careerStage == '0-2 prior seasons') |>
  dplyr::slice_head(n = 1L)
stage_mid_result <- analysis$career_stage_slopes |>
  dplyr::filter(careerStage == '3-6 prior seasons') |>
  dplyr::slice_head(n = 1L)
stage_veteran_result <- analysis$career_stage_slopes |>
  dplyr::filter(careerStage == '7+ prior seasons') |>
  dplyr::slice_head(n = 1L)
career_stage_wald <- analysis$career_stage_wald

# Extract all planned scouting-validation estimates.
validation_trend <- analysis$external_validation_trend
validation_explicit <- analysis$external_validation_indicators |>
  dplyr::filter(indicator == 'playsBiggerExplicit') |>
  dplyr::slice_head(n = 1L)
validation_engagement <- analysis$external_validation_indicators |>
  dplyr::filter(indicator == 'activePhysicalEngagement') |>
  dplyr::slice_head(n = 1L)
validation_interior <- analysis$external_validation_indicators |>
  dplyr::filter(indicator == 'interiorPlay') |>
  dplyr::slice_head(n = 1L)
validation_summary <- analysis$external_validation_summary

# Cohort and metric summaries ----

# Calculate sample summaries.
roster_sample       <- base::nrow(roster_outcomes)
player_sample       <- dplyr::n_distinct(roster_outcomes$playerId)
continuation_rate   <- base::mean(roster_outcomes$continued300Flag)
no_prior_appearance <- base::sum(roster_outcomes$priorAppearance == 0L)
annual_minimum      <- base::min(analysis$xs_performance$n)
annual_maximum      <- base::max(analysis$xs_performance$n)
ranking_cohort_size <- base::sum(forward_seasons$seasonId == base::max(forward_seasons$seasonId) & forward_seasons$timeOnIce >= 500 * 60)
bootstrap_replicates <- base::nrow(analysis$primary_bootstrap$replicates)
scouting_candidate_count <- forward_seasons |>
  dplyr::count(playerId) |>
  dplyr::filter(n >= 2L) |>
  base::nrow()
scouting_source_count <- dplyr::n_distinct(analysis$external_validation$sourceId)

# Calculate construction and calibration summaries.
sax_correlation         <- stats::cor(forward_seasons$SAx, forward_seasons$listedSize)
calibration_slope_range <- base::range(analysis$calibration_diagnostics$xSListedSlope)
size_correlation_range  <- base::range(analysis$calibration_diagnostics$csaxListedCorrelation)
csax_xs_correlation_range <- forward_seasons |>
  dplyr::group_by(seasonId) |>
  dplyr::summarise(correlation = stats::cor(CSAx, xS), .groups = 'drop') |>
  dplyr::pull(correlation) |>
  base::range()
xs_fit_range            <- base::range(analysis$xs_performance$rSquared)
stability_range         <- base::range(analysis$csax_stability$correlation)
hits_correlation <- analysis$feature_correlations |>
  dplyr::filter(feature == 'hitsPer60') |>
  dplyr::pull(csaxCorrelation)

# Extract descriptive quartile profiles.
quartile_profiles <- analysis$quartile_profiles
low_quartile      <- quartile_profiles |> dplyr::filter(csaxQuartile == 1L)
high_quartile     <- quartile_profiles |> dplyr::filter(csaxQuartile == 4L)

# Calculate probability and team summaries.
probability_low       <- find_probability(-1)
probability_high      <- find_probability(1)
probability_contrast  <- analysis$continuation_contrast
team_gax_correlation  <- analysis$team_descriptive_summary$correlation[[1L]]
team_seasons          <- analysis$team_descriptive_summary$teamSeasons[[1L]]
team_shot_correlation <- analysis$team_playoff_shot_summary$correlation[[1L]]
team_shot_sample      <- analysis$team_playoff_shot_summary$teams[[1L]]

# Player examples ----

# Extract recent ranking examples.
find_recent_player <- function(player_name) {
  analysis$recent_rankings |>
    dplyr::filter(Player == player_name) |>
    dplyr::slice_head(n = 1L)
}
olivier    <- find_recent_player('Mathieu Olivier')
lomberg    <- find_recent_player('Ryan Lomberg')
jeannot    <- find_recent_player('Tanner Jeannot')
laine      <- find_recent_player('Patrik Laine')
burakovsky <- find_recent_player('Andre Burakovsky')
protas     <- find_recent_player('Aliaksei Protas')

# Extract named longitudinal profiles.
find_case_study <- function(player_name) {
  analysis$scouting_case_profiles |>
    dplyr::filter(playerFullName == player_name) |>
    dplyr::slice_head(n = 1L)
}
benson     <- find_case_study('Zach Benson')
neighbours <- find_case_study('Jake Neighbours')
eklund     <- find_case_study('William Eklund')
tkachuk    <- find_case_study('Brady Tkachuk')

# Fail early if any manuscript object is unavailable.
required_rows <- base::c(base::nrow(same_sample_current_result), base::nrow(same_sample_prior_result), base::nrow(role_margin_summary), base::nrow(role_time_interaction_result), base::nrow(contact_result), base::nrow(interior_result), base::nrow(size_main_result), base::nrow(size_interaction_result), base::nrow(validation_explicit), base::nrow(validation_engagement), base::nrow(validation_interior), base::nrow(olivier), base::nrow(lomberg), base::nrow(jeannot), base::nrow(laine), base::nrow(burakovsky), base::nrow(protas), base::nrow(benson), base::nrow(neighbours), base::nrow(eklund), base::nrow(tkachuk))
if (base::any(required_rows != 1L) || base::nrow(conditioning_results) != 6L || base::nrow(role_timing_results) != 2L || base::nrow(quartile_profiles) != 4L || no_prior_appearance != 99L || scouting_candidate_count != 477L || scouting_source_count != 6L) base::stop('A required manuscript summary is unavailable.', call. = FALSE)

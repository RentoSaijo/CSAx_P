# Setup -------------------------------------------------------------------

# Load fitted models and application helpers.
base::source('R/functions.R')
base::source('R/models.R')
base::source('R/applications.R')
base::Sys.setenv(OMP_NUM_THREADS = '1', OPENBLAS_NUM_THREADS = '1', VECLIB_MAXIMUM_THREADS = '1')

# Estimate pilot relationships while preserving full-season benchmark.
if ('--a3z' %in% base::commandArgs(trailingOnly = TRUE)) {
  base::source('R/a3z.R')
  analysis <- base::readRDS('data/analysis_data.rds')
  inputs <- base::readRDS('data/cache/a3z_inputs.rds')
  fits <- base::readRDS('data/cache/a3z_models.rds')
  pilot <- analyze_a3z_models(fits, inputs, analysis$inputs)
  pilot$inputs <- inputs
  pilot$coefficients <- purrr::imap_dfr(fits, function(fit, label) fit$coefficients |> dplyr::mutate(specification = label))
  pilot$tuning <- purrr::imap_dfr(fits, function(fit, label) fit$tuning |> dplyr::mutate(specification = label))
  pilot$sizeReference <- fits[['A3Z integrated']]$sizeReference
  pilot$benchmark <- base::list(specification = 'Full-season play-by-play benchmark', eventScope = 'All situations with labeled sensitivities', components = base::c('inputs', 'primary', 'centers', 'sensitivities', 'applications', 'bootstrap', 'inference'), builtAt = analysis$builtAt)
  pilot$settings <- base::list(version = a3z_version, definition = a3z_definition, features = purrr::map(fits, 'features'), eligibilityMinutes = xs_minutes, trackedMinutes = a3z_minutes, rankingMinutes = 500, sparseDenominatorThreshold = 20L, outerFolds = xs_outer_folds, innerFolds = xs_inner_folds, penaltyGrid = xs_penalty_grid, seed = xs_seed)
  pilot$builtAt <- base::format(base::Sys.time(), tz = 'UTC', usetz = TRUE)
  analysis$a3z <- pilot
  analysis$definition <- a3z_definition
  base::saveRDS(analysis, 'data/analysis_data.rds', compress = 'xz')
  base::message('Saved A3Z pilot and preserved full-season benchmark.')
  base::quit(save = 'no', status = 0L)
}

# Read full-season benchmark models and inputs.
models <- base::readRDS('data/cache/positional_models.rds')
inputs <- base::readRDS('data/cache/positional_inputs.rds')

# Positional Applications -------------------------------------------------

# Estimate roster, contract, playoff, scouting, and team relationships.
applications <- analyze_positional_applications(models, inputs)
inputs$teamPlayerPositions <- applications$teams$exposurePositions
assert_unique(applications$panel, base::c('model', 'playerId', 'seasonId'), 'Positional application panel')
assert_unique(applications$playoffs, base::c('model', 'playerId', 'seasonId'), 'Playoff application panel')
if (base::any(applications$playoffs$playoffDressedShare < 0 | applications$playoffs$playoffDressedShare > 1)) base::stop('Playoff dressing denominator is invalid.', call. = FALSE)

# Shared Bootstrap --------------------------------------------------------

# Propagate player sampling through complete positional pipeline.
bootstrap <- run_positional_bootstrap(inputs$features, prepare_outcomes(inputs))
inference <- summarize_positional_bootstrap(bootstrap, applications$primaryPoints, models$centers)

# Analysis Object ---------------------------------------------------------

# Preserve scientific inputs and compact results in single analysis object.
analysis <- base::list(definition = 'Playing big for one\'s size means showing a pattern of direct physical engagement and position-specific indirect behaviors associated with contested space that is more characteristic of a larger player than expected for one\'s listed height and weight.', settings = base::list(behaviorSeasons = xs_behavior_seasons, nextOutcomeSeasons = next_season_id(xs_behavior_seasons), eligibilityMinutes = xs_minutes, rankingMinutes = 500, directFeatures = xs_direct_features, forwardFeatures = xs_forward_features, defenseFeatures = xs_defense_features, contactPenalties = xs_contact_penalties, penaltyGrid = xs_penalty_grid, outerFolds = xs_outer_folds, innerFolds = xs_inner_folds, seed = xs_seed, bootstrapSeed = xs_bootstrap_seed, bootstrapReplicates = xs_bootstrap_reps, modelVersion = xs_model_version), inputs = inputs, primary = models$primary, centers = models$centers, sensitivities = models$sensitivities, applications = applications, bootstrap = bootstrap, inference = inference, builtAt = base::format(base::Sys.time(), tz = 'UTC', usetz = TRUE))
base::saveRDS(analysis, 'data/analysis_data.rds', compress = 'xz')
base::message('Saved positional analysis with ', bootstrap$replicates, ' shared bootstrap samples.')

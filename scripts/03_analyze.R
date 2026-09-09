# Setup -------------------------------------------------------------------

# Load fitted models and application helpers.
base::source('R/functions.R')
base::source('R/models.R')
base::source('R/applications.R')
base::Sys.setenv(OMP_NUM_THREADS = '1', OPENBLAS_NUM_THREADS = '1', VECLIB_MAXIMUM_THREADS = '1')
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

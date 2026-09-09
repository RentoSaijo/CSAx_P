# Setup --------------------------------------------------------------------

# Load helper functions.
base::source('R/functions.R')

# Create cache directory.
base::dir.create('data/cache', recursive = TRUE, showWarnings = FALSE)

# Validate package revision.
package_description <- utils::packageDescription('nhlscraper')
package_sha         <- package_description[['RemoteSha']]
if (base::is.null(package_sha) || package_sha != xs_package_sha) base::stop('Installed nhlscraper revision does not match pinned research revision.', call. = FALSE)

# Registry Data ------------------------------------------------------------

# Load player registry.
players <- base::suppressMessages(nhlscraper::players())
assert_columns(players, base::c('playerId', 'playerFullName', 'height', 'weight', 'birthDate'), 'Player registry')
assert_unique(players, 'playerId', 'Player registry')
base::saveRDS(players, 'data/cache/players.rds', compress = 'xz')

# Load season calendar.
season_calendar <- base::suppressMessages(nhlscraper::seasons())
assert_columns(season_calendar, base::c('seasonId', 'regularSeasonEndDate'), 'Season calendar')
base::saveRDS(season_calendar, 'data/cache/seasons.rds', compress = 'xz')

# Load team registry.
teams <- base::suppressMessages(nhlscraper::teams())
assert_columns(teams, base::c('teamId', 'teamFullName', 'teamTriCode'), 'Team registry')
assert_unique(teams, 'teamId', 'Team registry')
base::saveRDS(teams, 'data/cache/teams.rds', compress = 'xz')

# Season Data --------------------------------------------------------------

# Determine cache preference and provenance path.
refresh_cache       <- base::identical(base::Sys.getenv('XS_REFRESH'), '1')
provenance_path     <- 'data/cache/provenance.rds'
previous_provenance <- if (base::file.exists(provenance_path)) base::readRDS(provenance_path) else NULL
feature_columns <- base::c('playerId', 'seasonId', 'playerFullName', 'positionCode', 'height', 'weight', 'birthDate', 'gamesPlayed', 'timeOnIce', 'timeOnIcePerGame', 'pointsPer605v5', 'satRelative5v5', xs_features)
away_feature_columns <- base::c('playerId', 'seasonId', 'awayTimeOnIce', 'awayGames', xs_features)

# Prepare behavior-season aggregates.
behavior_inventory <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  feature_path      <- base::file.path('data/cache', base::paste0('features_', season_id, '.rds'))
  away_feature_path <- base::file.path('data/cache', base::paste0('away_features_', season_id, '.rds'))
  expected_goal_path <- base::file.path('data/cache', base::paste0('expected_goals_', season_id, '.rds'))
  cached_expected_goals <- if (!refresh_cache && base::file.exists(expected_goal_path)) base::readRDS(expected_goal_path) else NULL
  prepare_features  <- refresh_cache || !base::file.exists(feature_path)
  prepare_away      <- refresh_cache || !base::file.exists(away_feature_path)
  prepare_expected_goals <- refresh_cache || !base::identical(cached_expected_goals$scoringScope, xs_xg_scoring_scope) || !'teamFiveOnFive' %in% base::names(cached_expected_goals)
  raw_play_by_play  <- if (prepare_features || prepare_away || prepare_expected_goals) base::suppressMessages(nhlscraper::gc_play_by_plays(season = season_id)) else NULL
  if (prepare_features) {
    base::message('Preparing behavior season ', season_id, '.')
    play_by_play <- aggregate_play_by_play(season_id, raw_play_by_play)
    features     <- build_regular_features(season_id, players, play_by_play$data)
    base::attr(features, 'playByPlayRows') <- play_by_play$sourceRows
    base::saveRDS(features, feature_path, compress = 'xz')
    source_rows  <- play_by_play$sourceRows
    feature_rows <- base::nrow(features)
    base::rm(play_by_play, features)
    base::gc(verbose = FALSE)
  } else {
    base::message('Using behavior cache ', season_id, '.')
    features    <- base::readRDS(feature_path)
    source_rows <- base::attr(features, 'playByPlayRows')
    if (base::is.null(source_rows) && !base::is.null(previous_provenance)) source_rows <- previous_provenance$behaviorInventory$playByPlayRows[base::match(season_id, previous_provenance$behaviorInventory$seasonId)]
    if (base::length(source_rows) != 1L || base::is.na(source_rows)) base::stop('Cached behavior provenance is unavailable; rerun with XS_REFRESH=1.', call. = FALSE)
    if (base::is.null(base::attr(features, 'playByPlayRows'))) {
      base::attr(features, 'playByPlayRows') <- source_rows
    }
    assert_columns(features, feature_columns, base::paste0('Cached behavior features ', season_id))
    if (!base::identical(base::names(features), feature_columns)) features <- features |>
      dplyr::select(dplyr::all_of(feature_columns))
    base::attr(features, 'playByPlayRows') <- source_rows
    base::saveRDS(features, feature_path, compress = 'xz')
    feature_rows <- base::nrow(features)
    base::rm(features)
  }
  if (prepare_away) {
    base::message('Preparing away-game behavior season ', season_id, '.')
    away_features <- aggregate_away_game_behavior(season_id, raw_play_by_play)
    base::attr(away_features$data, 'playByPlayRows') <- away_features$playByPlayRows
    base::attr(away_features$data, 'shiftRows')      <- away_features$shiftRows
    base::attr(away_features$data, 'regularGames')   <- away_features$regularGames
    base::saveRDS(away_features$data, away_feature_path, compress = 'xz')
    away_source_rows <- away_features$playByPlayRows
    shift_rows       <- away_features$shiftRows
    regular_games    <- away_features$regularGames
    away_feature_rows <- base::nrow(away_features$data)
    base::rm(away_features)
    base::gc(verbose = FALSE)
  } else {
    base::message('Using away-game behavior cache ', season_id, '.')
    away_features    <- base::readRDS(away_feature_path)
    away_source_rows <- base::attr(away_features, 'playByPlayRows')
    shift_rows       <- base::attr(away_features, 'shiftRows')
    regular_games    <- base::attr(away_features, 'regularGames')
    if (!base::is.null(previous_provenance)) {
      provenance_row <- base::match(season_id, previous_provenance$behaviorInventory$seasonId)
      if (base::is.null(away_source_rows)) away_source_rows <- previous_provenance$behaviorInventory$playByPlayRows[provenance_row]
      if (base::is.null(shift_rows)) shift_rows <- previous_provenance$behaviorInventory$shiftRows[provenance_row]
      if (base::is.null(regular_games)) regular_games <- previous_provenance$behaviorInventory$regularGames[provenance_row]
    }
    if (base::length(away_source_rows) != 1L || base::is.na(away_source_rows) || base::length(shift_rows) != 1L || base::is.na(shift_rows) || base::length(regular_games) != 1L || base::is.na(regular_games)) base::stop('Cached away-game provenance is unavailable; rerun with XS_REFRESH=1.', call. = FALSE)
    assert_columns(away_features, away_feature_columns, base::paste0('Cached away-game features ', season_id))
    if (!base::identical(base::names(away_features), away_feature_columns)) away_features <- away_features |>
      dplyr::select(dplyr::all_of(away_feature_columns))
    base::attr(away_features, 'playByPlayRows') <- away_source_rows
    base::attr(away_features, 'shiftRows')      <- shift_rows
    base::attr(away_features, 'regularGames')   <- regular_games
    base::saveRDS(away_features, away_feature_path, compress = 'xz')
    away_feature_rows <- base::nrow(away_features)
    base::rm(away_features)
  }
  if (source_rows != away_source_rows) base::stop('Full-season and away-game play-by-play row counts disagree.', call. = FALSE)
  if (prepare_expected_goals) {
    base::message('Preparing expected goals season ', season_id, '.')
    expected_goals <- aggregate_expected_goals(season_id, raw_play_by_play)
    base::saveRDS(expected_goals, expected_goal_path, compress = 'xz')
  } else {
    base::message('Using expected-goals cache ', season_id, '.')
    expected_goals <- cached_expected_goals
  }
  if (expected_goals$playByPlayRows != source_rows) base::stop('Expected-goal and behavior play-by-play row counts disagree.', call. = FALSE)
  expected_goal_regular_rows <- expected_goals$regularPlayRows
  expected_goal_shot_rows    <- expected_goals$scoredShotRows
  expected_goal_rows         <- expected_goals$goalRows
  expected_goal_player_rows  <- base::nrow(expected_goals$player)
  expected_goal_team_rows    <- base::nrow(expected_goals$team)
  base::rm(expected_goals)
  base::rm(raw_play_by_play)
  base::gc(verbose = FALSE)
  tibble::tibble(seasonId = season_id, playByPlayRows = source_rows, shiftRows = shift_rows, regularGames = regular_games, featureRows = feature_rows, awayFeatureRows = away_feature_rows, expectedGoalRegularRows = expected_goal_regular_rows, expectedGoalShotRows = expected_goal_shot_rows, expectedGoalRows = expected_goal_rows, expectedGoalPlayerRows = expected_goal_player_rows, expectedGoalTeamRows = expected_goal_team_rows)
})

# Prepare roster-season outcomes.
outcome_inventory <- purrr::map_dfr(xs_roster_seasons, function(season_id) {
  outcome_path <- base::file.path('data/cache', base::paste0('outcomes_', season_id, '.rds'))
  cached_outcomes <- if (!refresh_cache && base::file.exists(outcome_path)) base::readRDS(outcome_path) else NULL
  needs_player_team <- season_id %in% xs_behavior_seasons && (base::is.null(cached_outcomes) || !'regularPlayerTeam' %in% base::names(cached_outcomes))
  if (refresh_cache || base::is.null(cached_outcomes) || needs_player_team) {
    base::message('Preparing roster season ', season_id, '.')
    outcomes <- build_roster_outcomes(season_id)
    base::saveRDS(outcomes, outcome_path, compress = 'xz')
  } else {
    base::message('Using roster cache ', season_id, '.')
    outcomes <- cached_outcomes
  }
  outcomes$regularTime <- outcomes$regularTime |>
    dplyr::select(playerId, regularGamesPlayed, regularTimeOnIce, regularToiPerGame)
  outcomes$playoffTime <- outcomes$playoffTime |>
    dplyr::select(playerId, playoffGamesPlayed, playoffTimeOnIce, playoffToiPerGame)
  base::saveRDS(outcomes, outcome_path, compress = 'xz')
  regular_player_teams <- if ('regularPlayerTeam' %in% base::names(outcomes)) base::nrow(outcomes$regularPlayerTeam) else NA_integer_
  inventory_row <- tibble::tibble(seasonId = season_id, rosterRows = outcomes$sourceRows, regularPlayers = base::nrow(outcomes$regularRoster), regularPlayerTeams = regular_player_teams, playoffPlayerTeams = base::nrow(outcomes$playoffPlayer))
  base::rm(outcomes)
  base::gc(verbose = FALSE)
  inventory_row
})

# Validate cached source provenance.
if (base::anyNA(behavior_inventory) || base::anyNA(outcome_inventory$rosterRows)) base::stop('Source row counts are incomplete.', call. = FALSE)
if (base::anyNA(outcome_inventory$regularPlayerTeams[outcome_inventory$seasonId %in% xs_behavior_seasons])) base::stop('Behavior-season player-team roster counts are incomplete.', call. = FALSE)

# Career History -----------------------------------------------------------

# Identify eligible player-season keys.
eligible_history_keys <- purrr::map_dfr(xs_behavior_seasons, function(season_id) {
  base::readRDS(base::file.path('data/cache', base::paste0('features_', season_id, '.rds'))) |>
    dplyr::filter(positionCode %in% base::c('C', 'L', 'R'), timeOnIce >= xs_minutes * 60, !base::is.na(height), !base::is.na(weight), !base::is.na(birthDate)) |>
    dplyr::select(playerId, seasonId)
}) |>
  dplyr::distinct()
eligible_player_ids <- base::sort(base::unique(eligible_history_keys$playerId))

# Load compact player histories.
history_path <- 'data/cache/player_seasons.rds'
player_histories <- if (!refresh_cache && base::file.exists(history_path)) base::readRDS(history_path) else tibble::tibble(playerId = base::integer(), seasonId = base::integer())
remaining_player_ids <- base::setdiff(eligible_player_ids, base::unique(player_histories$playerId))
if (base::length(remaining_player_ids) > 0L) {
  base::message('Collecting ', base::length(remaining_player_ids), ' remaining player histories.')
  for (index in base::seq_along(remaining_player_ids)) {
    player_histories <- dplyr::bind_rows(player_histories, load_player_history(remaining_player_ids[index])) |>
      dplyr::distinct(playerId, seasonId)
    if (index %% 100L == 0L || index == base::length(remaining_player_ids)) {
      base::saveRDS(player_histories, history_path, compress = 'xz')
      base::message('Collected ', dplyr::n_distinct(player_histories$playerId), ' player histories.')
    }
  }
} else {
  base::message('Using complete player-history cache.')
}

# Validate career-history coverage.
assert_unique(player_histories, base::c('playerId', 'seasonId'), 'Player histories')
missing_histories <- eligible_history_keys |>
  dplyr::anti_join(player_histories, by = base::c('playerId', 'seasonId'))
if (base::nrow(missing_histories) > 0L || !base::all(eligible_player_ids %in% player_histories$playerId)) base::stop('Player histories do not cover every eligible forward-season.', call. = FALSE)

# Contract Data ------------------------------------------------------------

# Load contract registry.
contract_path <- 'data/cache/contracts.rds'
contracts <- if (!refresh_cache && base::file.exists(contract_path)) base::readRDS(contract_path) else base::suppressMessages(nhlscraper::contracts())
assert_columns(contracts, base::c('playerId', 'playerFullName', 'positionCode', 'ageAtSigning', 'signedWithTeamId', 'signedWithTeamTriCode', 'startSeasonId', 'endSeasonId', 'term', 'aav'), 'Contract registry')
usable_contracts <- contracts |>
  dplyr::filter(!base::is.na(playerId), !base::is.na(signedWithTeamId), !base::is.na(startSeasonId), !base::is.na(endSeasonId), base::is.finite(term), term > 0, base::is.finite(aav), aav > 0)
if (base::nrow(usable_contracts) == 0L) base::stop('Contract registry contains no usable signings.', call. = FALSE)
base::saveRDS(contracts, contract_path, compress = 'xz')

# Load transaction audit data.
transaction_seasons <- xs_outcome_seasons
transaction_path <- 'data/cache/transactions.rds'
transactions <- if (!refresh_cache && base::file.exists(transaction_path)) {
  base::readRDS(transaction_path)
} else {
  purrr::map_dfr(transaction_seasons, function(season_id) {
    base::suppressMessages(nhlscraper::espn_transactions(season = season_id)) |>
      dplyr::mutate(sourceSeasonId = season_id)
  }) |>
    dplyr::filter(!base::is.na(description)) |>
    dplyr::distinct(date, description, teamTriCode, .keep_all = TRUE)
}
base::saveRDS(transactions, transaction_path, compress = 'xz')

# Provenance ---------------------------------------------------------------

# Save data provenance.
xg_bundle      <- utils::getFromNamespace('.xg_load_bundle', 'nhlscraper')()
xg_model_index <- xg_bundle$model_index |>
  dplyr::filter(targetSeason %in% xs_behavior_seasons) |>
  dplyr::arrange(targetSeason, partition)
if (base::nrow(xg_model_index) != base::length(xs_behavior_seasons) * 6L || base::anyNA(xg_model_index$boosterSha256)) base::stop('Expected-goal model provenance is incomplete.', call. = FALSE)
provenance <- base::list(
  collectedAt = base::format(base::Sys.time(), tz = 'America/New_York', usetz = TRUE),
  rVersion = base::as.character(base::getRversion()),
  nhlscraperVersion = base::as.character(utils::packageVersion('nhlscraper')),
  nhlscraperSha = package_sha,
  behaviorSeasons = xs_behavior_seasons,
  outcomeSeasons = xs_outcome_seasons,
  priorRoleSeasons = xs_prior_role_seasons,
  rosterSeasons = xs_roster_seasons,
  eligibilityMinutes = xs_minutes,
  seed = xs_seed,
  behaviorInventory = behavior_inventory,
  outcomeInventory = outcome_inventory,
  playerRows = base::nrow(players),
  expectedGoalSource = base::list(
    name = 'NHLxG',
    url = xs_xg_model_store,
    scoringScope = xs_xg_scoring_scope,
    bundleBuiltAt = xg_bundle$built_at,
    modelIndex = xg_model_index
  ),
  teamRows = base::nrow(teams),
  contractRows = base::nrow(contracts),
  contractSource = base::list(
    name = 'Spotrac NHL Contracts',
    url = 'https://www.spotrac.com/nhl/contracts/',
    retrievedAt = base::as.Date('2026-08-02'),
    accessMethod = 'nhlscraper::contracts()',
    sourceRows = base::nrow(contracts),
    fields = base::c('player identity', 'position', 'signing age', 'signing team', 'start season', 'end season', 'term', 'AAV')
  ),
  transactionRows = base::nrow(transactions),
  playerHistoryRows = base::nrow(player_histories),
  playerHistoryPlayers = dplyr::n_distinct(player_histories$playerId)
)
base::saveRDS(provenance, provenance_path, compress = 'xz')

# Confirm preparation output.
base::message('Prepared ', base::nrow(behavior_inventory), ' behavior seasons and ', base::nrow(outcome_inventory), ' roster seasons.')

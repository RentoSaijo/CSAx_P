# Constants ----------------------------------------------------------------

# Define research constants.
xs_seed             <- 20260801L
xs_bootstrap_seed   <- 20260804L
xs_bootstrap_reps   <- 999L
xs_minutes          <- 300
xs_repeats          <- 5L
xs_outer_folds      <- 10L
xs_inner_folds      <- 5L
confidence_level    <- 0.95
xs_package_sha      <- '58821f001469d5024766511e511051377c0f859f'
xs_behavior_seasons <- base::c(20212022L, 20222023L, 20232024L, 20242025L)
xs_outcome_seasons  <- base::c(xs_behavior_seasons, 20252026L)
xs_prior_role_seasons <- base::c(20202021L, 20212022L, 20222023L, 20232024L)
xs_roster_seasons   <- base::sort(base::unique(base::c(xs_prior_role_seasons, xs_outcome_seasons)))
xs_contract_seasons <- base::c(20222023L, 20232024L, 20242025L, 20252026L)
xs_xg_model_store   <- 'https://huggingface.co/datasets/RentoSaijo/NHLxG'
xs_xg_scoring_scope <- 'Regular-season and playoff events excluding shootouts'
xs_contact_features <- base::c('hitsPer60', 'hitsReceivedPer60', 'blockedShotsPer60', 'penaltiesTakenPer60', 'penaltiesDrawnPer60', 'fightsPer60')
xs_interior_features <- base::c('netFrontAttemptShare', 'deflectionShare', 'medianShotDistance', 'backhandShare')
xs_features          <- base::c(xs_contact_features, xs_interior_features)

# Validation Helpers -------------------------------------------------------

# Validate required columns.
assert_columns <- function(data, columns, label) {
  missing_columns <- base::setdiff(columns, base::names(data))
  if (base::length(missing_columns) > 0L) base::stop(base::paste0(label, ' is missing: ', base::paste(missing_columns, collapse = ', ')), call. = FALSE)
  base::invisible(data)
}

# Validate unique keys.
assert_unique <- function(data, columns, label) {
  duplicate_count <- data |>
    dplyr::count(dplyr::across(dplyr::all_of(columns)), name = 'keyCount') |>
    dplyr::filter(keyCount > 1L) |>
    base::nrow()
  if (duplicate_count > 0L) base::stop(base::paste0(label, ' contains ', duplicate_count, ' duplicated key(s).'), call. = FALSE)
  base::invisible(data)
}

# Validate finite values.
assert_finite <- function(data, columns, label) {
  invalid_count <- base::sum(!base::vapply(data[columns], function(x) base::all(base::is.finite(x)), base::logical(1L)))
  if (invalid_count > 0L) base::stop(base::paste0(label, ' contains non-finite modeled columns.'), call. = FALSE)
  base::invisible(data)
}

# Numeric Helpers ----------------------------------------------------------

# Standardize numeric vector.
standardize_vector <- function(x) {
  base::as.numeric(base::scale(x))
}

# Standardize complete numeric vector.
standardize_complete <- function(x) {
  x[!base::is.finite(x)] <- NA_real_
  x[base::is.na(x)]      <- stats::median(x, na.rm = TRUE)
  standardize_vector(x)
}

# Calculate safe rate.
rate_per_60 <- function(events, seconds) {
  dplyr::if_else(seconds > 0, events / seconds * 3600, NA_real_)
}

# Calculate age on October first.
calculate_season_age <- function(birth_date, season_id) {
  reference_date <- base::as.Date(base::paste0(season_id %/% 10000L, '-10-01'))
  birth_date     <- base::as.Date(birth_date)
  base::as.integer(base::format(reference_date, '%Y')) - base::as.integer(base::format(birth_date, '%Y')) - (base::format(reference_date, '%m%d') < base::format(birth_date, '%m%d'))
}

# Calculate following season identifier.
next_season_id <- function(season_id) {
  start_year <- season_id %/% 10000L + 1L
  base::as.integer(base::paste0(start_year, start_year + 1L))
}

# Calculate preceding season identifier.
previous_season_id <- function(season_id) {
  start_year <- season_id %/% 10000L - 1L
  base::as.integer(base::paste0(start_year, start_year + 1L))
}

# Data Collection Helpers --------------------------------------------------

# Load skater report.
load_skater_report <- function(season_id, category, game_type = 2L) {
  report <- base::suppressMessages(nhlscraper::skater_season_report(season = season_id, game_type = game_type, category = category))
  if (!base::is.data.frame(report) || base::nrow(report) == 0L) base::stop(base::paste0('Empty ', category, ' report for ', season_id, '.'), call. = FALSE)
  report
}

# Load player career history.
load_player_history <- function(player_id, attempts = 3L) {
  history <- NULL
  for (attempt in base::seq_len(attempts)) {
    candidate <- base::try(base::suppressMessages(nhlscraper::player_seasons(player = player_id)), silent = TRUE)
    if (base::is.data.frame(candidate) && base::all(base::c('seasonId', 'gameTypeIds') %in% base::names(candidate))) {
      history <- candidate |>
        dplyr::mutate(hasRegularSeason = purrr::map_lgl(gameTypeIds, function(game_types) 2L %in% game_types)) |>
        dplyr::filter(hasRegularSeason) |>
        dplyr::select(seasonId)
      break
    }
  }
  if (base::is.null(history) || base::nrow(history) == 0L) {
    for (attempt in base::seq_len(attempts)) {
      summary <- base::try(base::suppressMessages(nhlscraper::player_summary(player = player_id)), silent = TRUE)
      if (base::is.list(summary) && base::is.data.frame(summary$seasonTotals) && base::all(base::c('season', 'gameTypeId', 'gamesPlayed', 'leagueAbbrev') %in% base::names(summary$seasonTotals))) {
        history <- summary$seasonTotals |>
          dplyr::filter(leagueAbbrev == 'NHL', gameTypeId == 2L, gamesPlayed > 0) |>
          dplyr::transmute(seasonId = base::as.integer(season)) |>
          dplyr::distinct()
        break
      }
    }
  }
  if (base::is.null(history) || base::nrow(history) == 0L) base::stop(base::paste0('Player history failed for ', player_id, '.'), call. = FALSE)
  history |>
    dplyr::mutate(playerId = player_id) |>
    dplyr::select(playerId, seasonId)
}

# Aggregate regular-season play-by-play features.
aggregate_play_by_play <- function(season_id, play_by_play = NULL) {
  if (base::is.null(play_by_play)) play_by_play <- base::suppressMessages(nhlscraper::gc_play_by_plays(season = season_id))
  assert_columns(
    play_by_play,
    base::c('gameTypeId', 'periodType', 'eventTypeDescKey', 'penaltyTypeDescKey', 'hitteePlayerId', 'committedByPlayerId', 'shootingPlayerId', 'xCoordNorm', 'yCoordNorm'),
    base::paste0('Play-by-play ', season_id)
  )
  play_by_play_rows <- base::nrow(play_by_play)
  regular_plays <- play_by_play |>
    dplyr::filter(gameTypeId == 2L, periodType != 'SO')
  hits_received <- regular_plays |>
    dplyr::filter(eventTypeDescKey == 'hit', !base::is.na(hitteePlayerId)) |>
    dplyr::count(playerId = hitteePlayerId, name = 'hitsReceived')
  fights <- regular_plays |>
    dplyr::filter(eventTypeDescKey == 'penalty', penaltyTypeDescKey == 'fighting', !base::is.na(committedByPlayerId)) |>
    dplyr::count(playerId = committedByPlayerId, name = 'fights')
  unblocked_shots <- regular_plays |>
    dplyr::filter(eventTypeDescKey %in% base::c('goal', 'shot-on-goal', 'missed-shot'), !base::is.na(shootingPlayerId), !base::is.na(xCoordNorm), !base::is.na(yCoordNorm)) |>
    dplyr::mutate(shotDistance = base::sqrt((89 - xCoordNorm)^2 + yCoordNorm^2), netFront = xCoordNorm >= 82 & xCoordNorm <= 89 & base::abs(yCoordNorm) <= 8) |>
    dplyr::group_by(playerId = shootingPlayerId) |>
    dplyr::summarise(medianShotDistance = stats::median(shotDistance), netFrontAttemptShare = base::mean(netFront), .groups = 'drop')
  base::rm(play_by_play, regular_plays)
  base::gc(verbose = FALSE)
  aggregates <- hits_received |>
    dplyr::full_join(fights, by = 'playerId') |>
    dplyr::full_join(unblocked_shots, by = 'playerId')
  base::list(data = aggregates, sourceRows = play_by_play_rows)
}

# Expected Goal Helpers ---------------------------------------------------

# Aggregate expected goals.
aggregate_expected_goals <- function(season_id, play_by_play = NULL) {
  if (base::is.null(play_by_play)) play_by_play <- base::suppressMessages(nhlscraper::gc_play_by_plays(season = season_id))
  assert_columns(play_by_play, base::c('gameTypeId', 'periodType', 'situationCode', 'eventTypeDescKey', 'eventOwnerTeamId', 'shootingPlayerId'), base::paste0('Expected-goal play-by-play ', season_id))
  included_plays <- play_by_play |>
    dplyr::filter(gameTypeId %in% base::c(2L, 3L), periodType != 'SO')
  scored_plays <- base::suppressMessages(nhlscraper::calculate_expected_goals(included_plays))
  assert_columns(scored_plays, 'xG', base::paste0('Expected-goal scores ', season_id))
  scored_shots <- scored_plays |>
    dplyr::filter(eventTypeDescKey %in% base::c('goal', 'shot-on-goal', 'missed-shot'), !base::is.na(eventOwnerTeamId), base::is.finite(xG))
  if (base::any(scored_shots$periodType == 'SO')) base::stop(base::paste0('Shootout events entered expected-goal aggregates for ', season_id, '.'), call. = FALSE)
  regular_shots <- scored_shots |>
    dplyr::filter(gameTypeId == 2L)
  team_expected_goals <- regular_shots |>
    dplyr::group_by(teamId = eventOwnerTeamId) |>
    dplyr::summarise(goals = base::sum(eventTypeDescKey == 'goal'), xGoals = base::sum(xG), GAx = goals - xGoals, .groups = 'drop')
  player_expected_goals <- regular_shots |>
    dplyr::filter(!base::is.na(shootingPlayerId)) |>
    dplyr::group_by(playerId = shootingPlayerId) |>
    dplyr::summarise(goals = base::sum(eventTypeDescKey == 'goal'), xGoals = base::sum(xG), GAx = goals - xGoals, .groups = 'drop')
  team_five_on_five <- scored_shots |>
    dplyr::filter(base::as.character(situationCode) == '1551') |>
    dplyr::group_by(gameTypeId, teamId = eventOwnerTeamId) |>
    dplyr::summarise(attempts = dplyr::n(), xGoals = base::sum(xG), xGoalsPerAttempt = xGoals / attempts, .groups = 'drop')
  assert_unique(team_expected_goals, 'teamId', base::paste0('Team expected goals ', season_id))
  assert_unique(player_expected_goals, 'playerId', base::paste0('Player expected goals ', season_id))
  assert_unique(team_five_on_five, base::c('gameTypeId', 'teamId'), base::paste0('Team five-on-five expected goals ', season_id))
  assert_finite(team_expected_goals, base::c('goals', 'xGoals', 'GAx'), base::paste0('Team expected goals ', season_id))
  assert_finite(player_expected_goals, base::c('goals', 'xGoals', 'GAx'), base::paste0('Player expected goals ', season_id))
  assert_finite(team_five_on_five, base::c('attempts', 'xGoals', 'xGoalsPerAttempt'), base::paste0('Team five-on-five expected goals ', season_id))
  base::list(player = player_expected_goals, team = team_expected_goals, teamFiveOnFive = team_five_on_five, scoringScope = xs_xg_scoring_scope, playByPlayRows = base::nrow(play_by_play), regularPlayRows = base::sum(play_by_play$gameTypeId == 2L & play_by_play$periodType != 'SO', na.rm = TRUE), scoredShotRows = base::nrow(regular_shots), goalRows = base::sum(regular_shots$eventTypeDescKey == 'goal'))
}

# Count player events.
count_player_events <- function(data, player_column, count_name) {
  data |>
    dplyr::filter(!base::is.na(.data[[player_column]])) |>
    dplyr::count(playerId = .data[[player_column]], name = count_name)
}

# Aggregate regular-season away-game behavior.
aggregate_away_game_behavior <- function(season_id, play_by_play = NULL) {
  if (base::is.null(play_by_play)) play_by_play <- base::suppressMessages(nhlscraper::gc_play_by_plays(season = season_id))
  assert_columns(
    play_by_play,
    base::c('gameId', 'gameTypeId', 'periodType', 'eventOwnerTeamId', 'isHome', 'eventTypeDescKey', 'penaltyTypeDescKey', 'hittingPlayerId', 'hitteePlayerId', 'committedByPlayerId', 'drawnByPlayerId', 'blockingPlayerId', 'shootingPlayerId', 'shotType', 'xCoordNorm', 'yCoordNorm'),
    base::paste0('Away-game play-by-play ', season_id)
  )
  regular_plays <- play_by_play |>
    dplyr::filter(gameTypeId == 2L, periodType != 'SO')
  away_teams <- regular_plays |>
    dplyr::filter(isHome == FALSE, !base::is.na(eventOwnerTeamId)) |>
    dplyr::distinct(gameId, awayTeamId = eventOwnerTeamId)
  away_team_counts <- away_teams |>
    dplyr::count(gameId, name = 'awayTeamCount')
  if (base::any(away_team_counts$awayTeamCount != 1L)) base::stop(base::paste0('Away-team identification failed for ', season_id, '.'), call. = FALSE)
  if (base::nrow(away_teams) != dplyr::n_distinct(regular_plays$gameId)) base::stop(base::paste0('An away team was not identified for every regular-season game in ', season_id, '.'), call. = FALSE)
  shifts <- base::suppressMessages(nhlscraper::shift_charts(season = season_id))
  assert_columns(shifts, base::c('gameId', 'teamId', 'playerId', 'duration'), base::paste0('Shift charts ', season_id))
  away_time <- shifts |>
    dplyr::inner_join(away_teams, by = 'gameId') |>
    dplyr::filter(teamId == awayTeamId, !base::is.na(playerId), base::is.finite(duration), duration > 0) |>
    dplyr::group_by(playerId) |>
    dplyr::summarise(awayTimeOnIce = base::sum(duration), awayGames = dplyr::n_distinct(gameId), .groups = 'drop')
  away_owned <- regular_plays |>
    dplyr::filter(isHome == FALSE)
  home_owned <- regular_plays |>
    dplyr::filter(isHome == TRUE)
  hits <- away_owned |>
    dplyr::filter(eventTypeDescKey == 'hit') |>
    count_player_events('hittingPlayerId', 'hits')
  hits_received <- home_owned |>
    dplyr::filter(eventTypeDescKey == 'hit') |>
    count_player_events('hitteePlayerId', 'hitsReceived')
  blocked_shots <- home_owned |>
    dplyr::filter(eventTypeDescKey == 'blocked-shot') |>
    count_player_events('blockingPlayerId', 'blockedShots')
  penalties_taken <- away_owned |>
    dplyr::filter(eventTypeDescKey == 'penalty') |>
    count_player_events('committedByPlayerId', 'penaltiesTaken')
  penalties_drawn <- home_owned |>
    dplyr::filter(eventTypeDescKey == 'penalty') |>
    count_player_events('drawnByPlayerId', 'penaltiesDrawn')
  fights <- away_owned |>
    dplyr::filter(eventTypeDescKey == 'penalty', penaltyTypeDescKey == 'fighting') |>
    count_player_events('committedByPlayerId', 'fights')
  unblocked_shots <- away_owned |>
    dplyr::filter(eventTypeDescKey %in% base::c('goal', 'shot-on-goal', 'missed-shot'), !base::is.na(shootingPlayerId), !base::is.na(xCoordNorm), !base::is.na(yCoordNorm)) |>
    dplyr::mutate(shotDistance = base::sqrt((89 - xCoordNorm)^2 + yCoordNorm^2), netFront = xCoordNorm >= 82 & xCoordNorm <= 89 & base::abs(yCoordNorm) <= 8) |>
    dplyr::group_by(playerId = shootingPlayerId) |>
    dplyr::summarise(medianShotDistance = stats::median(shotDistance), netFrontAttemptShare = base::mean(netFront), .groups = 'drop')
  shot_types <- away_owned |>
    dplyr::filter(eventTypeDescKey %in% base::c('goal', 'shot-on-goal'), !base::is.na(shootingPlayerId)) |>
    dplyr::group_by(playerId = shootingPlayerId) |>
    dplyr::summarise(
      shotTypeTotal = dplyr::n(),
      backhandShare = base::mean(shotType == 'backhand', na.rm = TRUE),
      deflectionShare = base::mean(shotType %in% base::c('deflected', 'tip-in'), na.rm = TRUE),
      .groups = 'drop'
    )
  count_columns <- base::c('hits', 'hitsReceived', 'blockedShots', 'penaltiesTaken', 'penaltiesDrawn', 'fights')
  aggregates <- base::list(hits, hits_received, blocked_shots, penalties_taken, penalties_drawn, fights, unblocked_shots, shot_types) |>
    purrr::reduce(dplyr::full_join, by = 'playerId')
  away_features <- away_time |>
    dplyr::left_join(aggregates, by = 'playerId') |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(count_columns), ~ dplyr::coalesce(.x, 0L)),
      hitsPer60 = rate_per_60(hits, awayTimeOnIce),
      hitsReceivedPer60 = rate_per_60(hitsReceived, awayTimeOnIce),
      blockedShotsPer60 = rate_per_60(blockedShots, awayTimeOnIce),
      penaltiesTakenPer60 = rate_per_60(penaltiesTaken, awayTimeOnIce),
      penaltiesDrawnPer60 = rate_per_60(penaltiesDrawn, awayTimeOnIce),
      fightsPer60 = rate_per_60(fights, awayTimeOnIce),
      backhandShare = dplyr::coalesce(backhandShare, 0),
      deflectionShare = dplyr::coalesce(deflectionShare, 0),
      seasonId = season_id
    ) |>
    dplyr::select(playerId, seasonId, awayTimeOnIce, awayGames, dplyr::all_of(xs_features))
  assert_unique(away_features, base::c('playerId', 'seasonId'), base::paste0('Away-game features ', season_id))
  if (base::any(!base::is.finite(away_features$awayTimeOnIce) | away_features$awayTimeOnIce <= 0)) base::stop(base::paste0('Away-game time on ice is invalid for ', season_id, '.'), call. = FALSE)
  base::list(data = away_features, playByPlayRows = base::nrow(play_by_play), shiftRows = base::nrow(shifts), regularGames = dplyr::n_distinct(regular_plays$gameId))
}

# Build regular-season feature table.
build_regular_features <- function(season_id, players, play_by_play) {
  time_on_ice <- load_skater_report(season_id, 'timeonice') |>
    dplyr::select(playerId, positionCode, gamesPlayed, timeOnIce, timeOnIcePerGame)
  realtime <- load_skater_report(season_id, 'realtime') |>
    dplyr::select(playerId, hitsPer60, blockedShotsPer60)
  penalties <- load_skater_report(season_id, 'penalties') |>
    dplyr::select(playerId, penaltiesTakenPer60, penaltiesDrawnPer60)
  scoring <- load_skater_report(season_id, 'scoringRates') |>
    dplyr::select(playerId, pointsPer605v5, satRelative5v5)
  shot_types <- load_skater_report(season_id, 'shottype') |>
    dplyr::select(playerId, dplyr::starts_with('shotsOnNet'))
  assert_columns(players, base::c('playerId', 'playerFullName', 'height', 'weight', 'birthDate'), 'Player registry')
  features <- time_on_ice |>
    dplyr::left_join(realtime, by = 'playerId') |>
    dplyr::left_join(penalties, by = 'playerId') |>
    dplyr::left_join(scoring, by = 'playerId') |>
    dplyr::left_join(shot_types, by = 'playerId') |>
    dplyr::left_join(players |> dplyr::select(playerId, playerFullName, height, weight, birthDate), by = 'playerId') |>
    dplyr::left_join(play_by_play, by = 'playerId')
  shot_columns <- base::grep('^shotsOnNet', base::names(features), value = TRUE)
  features <- features |>
    dplyr::mutate(
      shotTypeTotal = base::rowSums(dplyr::pick(dplyr::all_of(shot_columns)), na.rm = TRUE),
      backhandShare = dplyr::if_else(shotTypeTotal > 0, shotsOnNetBackhand / shotTypeTotal, 0),
      deflectionShare = dplyr::if_else(shotTypeTotal > 0, (shotsOnNetDeflected + shotsOnNetTipIn) / shotTypeTotal, 0),
      hitsReceived = dplyr::coalesce(hitsReceived, 0L),
      fights = dplyr::coalesce(fights, 0L),
      hitsReceivedPer60 = rate_per_60(hitsReceived, timeOnIce),
      fightsPer60 = rate_per_60(fights, timeOnIce),
      seasonId = season_id
    ) |>
    dplyr::select(playerId, seasonId, playerFullName, positionCode, height, weight, birthDate, gamesPlayed, timeOnIce, timeOnIcePerGame, pointsPer605v5, satRelative5v5, dplyr::all_of(xs_features))
  assert_unique(features, base::c('playerId', 'seasonId'), base::paste0('Regular features ', season_id))
  features
}

# Build roster and deployment outcomes.
build_roster_outcomes <- function(season_id) {
  rosters <- base::suppressMessages(nhlscraper::game_rosters(season = season_id))
  assert_columns(rosters, base::c('gameId', 'teamId', 'playerId', 'positionCode'), base::paste0('Game rosters ', season_id))
  rosters <- rosters |>
    dplyr::mutate(gameTypeId = (gameId %/% 10000L) %% 100L)
  regular_roster <- rosters |>
    dplyr::filter(gameTypeId == 2L) |>
    dplyr::group_by(playerId) |>
    dplyr::summarise(gamesDressed = dplyr::n_distinct(gameId), finalTeamId = teamId[base::which.max(gameId)], .groups = 'drop')
  regular_player_team <- rosters |>
    dplyr::filter(gameTypeId == 2L, positionCode %in% base::c('C', 'L', 'R')) |>
    dplyr::group_by(playerId, teamId) |>
    dplyr::summarise(teamGamesDressed = dplyr::n_distinct(gameId), .groups = 'drop')
  playoff_player <- rosters |>
    dplyr::filter(gameTypeId == 3L) |>
    dplyr::group_by(playerId, teamId) |>
    dplyr::summarise(playoffGamesDressed = dplyr::n_distinct(gameId), .groups = 'drop')
  playoff_team <- rosters |>
    dplyr::filter(gameTypeId == 3L) |>
    dplyr::group_by(teamId) |>
    dplyr::summarise(teamPlayoffGames = dplyr::n_distinct(gameId), .groups = 'drop')
  regular_time <- load_skater_report(season_id, 'timeonice', game_type = 2L) |>
    dplyr::select(playerId, regularGamesPlayed = gamesPlayed, regularTimeOnIce = timeOnIce, regularToiPerGame = timeOnIcePerGame)
  playoff_time_raw <- base::suppressMessages(nhlscraper::skater_season_report(season = season_id, game_type = 3L, category = 'timeonice'))
  playoff_time <- if (base::is.data.frame(playoff_time_raw) && base::nrow(playoff_time_raw) > 0L) {
    playoff_time_raw |>
      dplyr::select(playerId, playoffGamesPlayed = gamesPlayed, playoffTimeOnIce = timeOnIce, playoffToiPerGame = timeOnIcePerGame)
  } else {
    tibble::tibble(playerId = base::integer(), playoffGamesPlayed = base::integer(), playoffTimeOnIce = base::numeric(), playoffToiPerGame = base::numeric())
  }
  base::list(regularRoster = regular_roster, regularPlayerTeam = regular_player_team, playoffPlayer = playoff_player, playoffTeam = playoff_team, regularTime = regular_time, playoffTime = playoff_time, sourceRows = base::nrow(rosters))
}

# Contract Helpers ---------------------------------------------------------

# Normalize transaction text.
normalize_transaction_text <- function(x) {
  x |>
    stringi::stri_trans_general('Latin-ASCII') |>
    stringr::str_to_lower() |>
    stringr::str_replace_all('[^a-z0-9]+', ' ') |>
    stringr::str_squish()
}

# Build transaction clauses.
build_transaction_clauses <- function(transactions) {
  clauses <- purrr::map_dfr(base::seq_len(base::nrow(transactions)), function(index) {
    pieces <- stringr::str_split(transactions$description[index], '(?<=\\.)\\s+')[[1L]]
    tibble::tibble(date = transactions$date[index], teamTriCode = transactions$teamTriCode[index], description = transactions$description[index], clause = pieces)
  }) |>
    dplyr::mutate(
      date = base::as.Date(base::substr(date, 1L, 10L)),
      team = dplyr::recode(teamTriCode, NJ = 'NJD', TB = 'TBL', SJ = 'SJS', LA = 'LAK', WAS = 'WSH', MON = 'MTL', PHX = 'ARI', .default = teamTriCode),
      clauseNorm = normalize_transaction_text(clause),
      signingClause = stringr::str_detect(clauseNorm, '(^| )(signed|re signed|signs|re signs|agreed|agrees)( |$)|contract extension'),
      tryoutClause = stringr::str_detect(clauseNorm, 'professional tryout|pto contract|tryout contract')
    ) |>
    dplyr::filter(signingClause, !tryoutClause)
  clauses
}

# Calculate age on date.
calculate_date_age <- function(birth_date, reference_date) {
  birth_date     <- base::as.Date(birth_date)
  reference_date <- base::as.Date(reference_date)
  base::as.integer(base::format(reference_date, '%Y')) - base::as.integer(base::format(birth_date, '%Y')) - (base::format(reference_date, '%m%d') < base::format(birth_date, '%m%d'))
}

# Match contract announcements.
audit_contract_transactions <- function(contracts, clauses) {
  number_words <- base::c(one = 1L, two = 2L, three = 3L, four = 4L, five = 5L, six = 6L, seven = 7L, eight = 8L)
  purrr::map_dfr(base::seq_len(base::nrow(contracts)), function(index) {
    player_name  <- normalize_transaction_text(contracts$playerFullName[index])
    start_year   <- contracts$startSeasonId[index] %/% 10000L
    name_pattern <- base::paste0('(^| )', stringr::str_replace_all(player_name, ' ', ' +'), '( |$)')
    candidates <- clauses |>
      dplyr::filter(team == contracts$signedWithTeamTriCode[index], date >= base::as.Date(base::paste0(start_year - 2L, '-01-01')), date <= base::as.Date(base::paste0(start_year, '-12-31')), stringr::str_detect(clauseNorm, name_pattern))
    if (base::nrow(candidates) == 0L) base::return(tibble::tibble(contractRow = index, transactionCandidates = 0L, matchDate = base::as.Date(NA), matchedTerm = FALSE, matchedAge = FALSE, matchClause = NA_character_))
    term_word     <- base::names(number_words)[number_words == contracts$term[index]]
    term_pattern  <- base::paste0('(^| )(', contracts$term[index], '|', term_word, ') year( |$)')
    term_match    <- stringr::str_detect(candidates$clauseNorm, term_pattern)
    candidate_age <- calculate_date_age(contracts$birthDate[index], candidates$date)
    age_match     <- candidate_age == contracts$ageAtSigning[index]
    score         <- term_match * 2 + dplyr::coalesce(age_match, FALSE) * 4
    best          <- base::which(score == base::max(score, na.rm = TRUE))
    best          <- best[base::which.max(candidates$date[best])]
    tibble::tibble(contractRow = index, transactionCandidates = base::nrow(candidates), matchDate = candidates$date[best], matchedTerm = term_match[best], matchedAge = age_match[best], matchClause = candidates$clause[best])
  })
}

# Modeling Helpers ---------------------------------------------------------

# Build expected-size workflow.
build_xs_workflow <- function(data, features = xs_features) {
  recipe <- recipes::recipe(listedSize ~ ., data = data |> dplyr::select(listedSize, dplyr::all_of(features))) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_YeoJohnson(recipes::all_numeric_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors())
  model <- parsnip::linear_reg(penalty = tune::tune(), mixture = 0) |>
    parsnip::set_engine('glmnet')
  workflows::workflow() |>
    workflows::add_recipe(recipe) |>
    workflows::add_model(model)
}

# Create ordinary or grouped cross-validation folds.
create_xs_folds <- function(data, folds, fold_group = NULL) {
  if (base::is.null(fold_group)) base::return(rsample::vfold_cv(data, v = folds))
  if (!base::is.character(fold_group) || base::length(fold_group) != 1L || !fold_group %in% base::names(data)) base::stop('Expected-size fold group is unavailable.', call. = FALSE)
  rlang::inject(rsample::group_vfold_cv(data, group = !!rlang::sym(fold_group), v = folds))
}

# Fit one outer expected-size fold.
fit_outer_xs_fold <- function(split, repeat_id, outer_fold, seed, features = xs_features, fit_flexible_calibration = TRUE, fold_group = NULL) {
  training   <- rsample::analysis(split)
  assessment <- rsample::assessment(split)
  if (base::length(base::intersect(training$.xsRow, assessment$.xsRow)) > 0L) base::stop('Outer assessment rows entered expected-size training.', call. = FALSE)
  if (!base::is.null(fold_group) && base::length(base::intersect(training[[fold_group]], assessment[[fold_group]])) > 0L) base::stop('Outer assessment players entered expected-size training.', call. = FALSE)
  base::set.seed(seed)
  inner_folds <- create_xs_folds(training, xs_inner_folds, fold_group = fold_group)
  if (!base::is.null(fold_group)) {
    inner_overlap <- purrr::map_lgl(inner_folds$splits, function(inner_split) base::length(base::intersect(rsample::analysis(inner_split)[[fold_group]], rsample::assessment(inner_split)[[fold_group]])) > 0L)
    if (base::any(inner_overlap)) base::stop('Inner assessment players entered expected-size tuning.', call. = FALSE)
  }
  workflow     <- build_xs_workflow(training, features = features)
  penalty_grid <- tibble::tibble(penalty = 10^base::seq(-4, 2, length.out = 20L))
  tuned <- tune::tune_grid(
    workflow,
    resamples = inner_folds,
    grid = penalty_grid,
    metrics = yardstick::metric_set(yardstick::rmse),
    control = tune::control_grid(save_pred = TRUE, verbose = FALSE)
  )
  best_penalty <- tune::select_best(tuned, metric = 'rmse')
  inner_predictions <- tune::collect_predictions(tuned, parameters = best_penalty) |>
    dplyr::arrange(.row)
  if (!base::identical(inner_predictions$.row, base::seq_len(base::nrow(training)))) base::stop('Inner predictions do not map one-to-one to outer training rows.', call. = FALSE)
  calibration_data <- tibble::tibble(
    xS = inner_predictions$.pred,
    listedSize = training$listedSize[inner_predictions$.row]
  )
  calibration    <- stats::lm(xS ~ listedSize, data = calibration_data)
  final_workflow <- tune::finalize_workflow(workflow, best_penalty)
  final_fit      <- parsnip::fit(final_workflow, data = training |> dplyr::select(listedSize, dplyr::all_of(features)))
  outer_xs       <- stats::predict(final_fit, new_data = assessment)$.pred
  expected_xs    <- stats::predict(calibration, newdata = assessment |> dplyr::select(listedSize))
  flexible_expected_xs <- if (fit_flexible_calibration) {
    flexible_calibration <- stats::lm(xS ~ splines::ns(listedSize, df = 3L), data = calibration_data)
    stats::predict(flexible_calibration, newdata = assessment |> dplyr::select(listedSize))
  } else {
    expected_xs
  }
  engine             <- workflows::extract_fit_engine(final_fit)
  coefficient_matrix <- base::as.matrix(stats::coef(engine, s = best_penalty$penalty))
  coefficients <- tibble::tibble(
    repeatId = repeat_id,
    outerFold = outer_fold,
    feature = base::rownames(coefficient_matrix),
    coefficient = base::as.numeric(coefficient_matrix[, 1L])
  ) |>
    dplyr::filter(feature != '(Intercept)')
  tuning_metrics <- tune::collect_metrics(tuned) |>
    dplyr::filter(.metric == 'rmse', penalty == best_penalty$penalty) |>
    dplyr::transmute(repeatId = repeat_id, outerFold = outer_fold, penalty, innerRmse = mean, innerRmseStdError = std_err)
  predictions <- tibble::tibble(
    .xsRow = assessment$.xsRow,
    repeatId = repeat_id,
    outerFold = outer_fold,
    xS = outer_xs,
    expectedXSGivenS = base::as.numeric(expected_xs),
    calibrationResidual = outer_xs - base::as.numeric(expected_xs),
    flexibleExpectedXSGivenS = base::as.numeric(flexible_expected_xs),
    flexibleCalibrationResidual = outer_xs - base::as.numeric(flexible_expected_xs)
  )
  base::list(predictions = predictions, tuning = tuning_metrics, coefficients = coefficients)
}

# Fit season expected-size model.
fit_expected_size <- function(data, seed, features = xs_features, repeats = xs_repeats, fit_flexible_calibration = TRUE, fold_group = NULL) {
  indexed_data <- data |>
    dplyr::mutate(.xsRow = dplyr::row_number())
  repeat_fits <- purrr::map(base::seq_len(repeats), function(repeat_id) {
    base::set.seed(seed + repeat_id * 10000L)
    outer_folds <- create_xs_folds(indexed_data, xs_outer_folds, fold_group = fold_group)
    fold_fits <- purrr::map2(outer_folds$splits, base::seq_len(base::nrow(outer_folds)), function(split, outer_fold) {
      fit_outer_xs_fold(
        split,
        repeat_id = repeat_id,
        outer_fold = outer_fold,
        seed = seed + repeat_id * 10000L + outer_fold * 100L,
        features = features,
        fit_flexible_calibration = fit_flexible_calibration,
        fold_group = fold_group
      )
    })
    repeat_predictions <- purrr::map_dfr(fold_fits, 'predictions') |>
      dplyr::arrange(.xsRow)
    if (!base::identical(repeat_predictions$.xsRow, base::seq_len(base::nrow(data)))) base::stop('Outer predictions do not map one-to-one to season rows.', call. = FALSE)
    repeat_predictions <- repeat_predictions |>
      dplyr::mutate(CSAx = standardize_vector(calibrationResidual), flexibleCSAx = standardize_vector(flexibleCalibrationResidual))
    base::list(
      predictions = repeat_predictions,
      tuning = purrr::map_dfr(fold_fits, 'tuning'),
      coefficients = purrr::map_dfr(fold_fits, 'coefficients')
    )
  })
  repeat_predictions <- purrr::map_dfr(repeat_fits, 'predictions')
  prediction_counts <- repeat_predictions |>
    dplyr::count(.xsRow, name = 'predictionCount')
  if (base::nrow(prediction_counts) != base::nrow(data) || base::any(prediction_counts$predictionCount != repeats)) base::stop('Eligible rows do not have one outer prediction per repeat.', call. = FALSE)
  averaged_predictions <- repeat_predictions |>
    dplyr::group_by(.xsRow) |>
    dplyr::summarise(
      xS = base::mean(xS),
      expectedXSGivenS = base::mean(expectedXSGivenS),
      calibrationResidual = base::mean(calibrationResidual),
      flexibleExpectedXSGivenS = base::mean(flexibleExpectedXSGivenS),
      flexibleCalibrationResidual = base::mean(flexibleCalibrationResidual),
      .groups = 'drop'
    ) |>
    dplyr::arrange(.xsRow) |>
    dplyr::transmute(
      xS,
      SAx = xS - data$listedSize,
      expectedXSGivenS,
      CSAx = standardize_vector(calibrationResidual),
      flexibleExpectedXSGivenS,
      flexibleCSAx = standardize_vector(flexibleCalibrationResidual)
    )
  performance <- tibble::tibble(
    n = base::nrow(data),
    rmse = yardstick::rmse_vec(data$listedSize, averaged_predictions$xS),
    rSquared = yardstick::rsq_vec(data$listedSize, averaged_predictions$xS),
    correlation = stats::cor(data$listedSize, averaged_predictions$xS)
  )
  tuning <- purrr::map_dfr(repeat_fits, 'tuning')
  performance <- performance |>
    dplyr::mutate(medianPenalty = stats::median(tuning$penalty), minimumPenalty = base::min(tuning$penalty), maximumPenalty = base::max(tuning$penalty))
  coefficients <- purrr::map_dfr(repeat_fits, 'coefficients') |>
    dplyr::group_by(feature) |>
    dplyr::summarise(coefficient = base::mean(coefficient), coefficientSd = stats::sd(coefficient), .groups = 'drop')
  base::list(
    predictions = averaged_predictions,
    repeatPredictions = repeat_predictions,
    performance = performance,
    tuning = tuning,
    coefficients = coefficients
  )
}

# Fit analysis workflow.
fit_analysis_workflow <- function(data, outcome, predictors, model_type = 'linear') {
  formula <- stats::reformulate(predictors, response = outcome)
  recipe  <- recipes::recipe(formula, data = data) |>
    recipes::step_dummy(recipes::all_nominal_predictors())
  model <- if (model_type == 'logistic') {
    parsnip::logistic_reg() |>
      parsnip::set_engine('glm')
  } else {
    parsnip::linear_reg() |>
      parsnip::set_engine('lm')
  }
  workflows::workflow() |>
    workflows::add_recipe(recipe) |>
    workflows::add_model(model) |>
    parsnip::fit(data = data)
}

# Inference Helpers --------------------------------------------------------

# Calculate normal-theory confidence multiplier.
confidence_multiplier <- function(level = confidence_level) {
  if (!base::is.numeric(level) || base::length(level) != 1L || !base::is.finite(level) || level <= 0 || level >= 1) base::stop('Confidence level must be a finite scalar between zero and one.', call. = FALSE)
  stats::qnorm((1 + level) / 2)
}

# Extract clustered coefficient inference.
clustered_term <- function(model, data, term = 'CSAx', level = confidence_level, cluster_data = NULL) {
  if (base::is.null(cluster_data)) cluster_data <- data$playerId
  engine         <- workflows::extract_fit_engine(model)
  variance       <- sandwich::vcovCL(engine, cluster = cluster_data, type = 'HC1')
  estimate       <- stats::coef(engine)[term]
  standard_error <- base::sqrt(base::diag(variance))[term]
  multiplier     <- confidence_multiplier(level)
  tibble::tibble(
    term = term,
    estimate = base::unname(estimate),
    stdError = base::unname(standard_error),
    statistic = base::unname(estimate / standard_error),
    pValue = base::unname(2 * stats::pnorm(-base::abs(estimate / standard_error))),
    confLow = base::unname(estimate - multiplier * standard_error),
    confHigh = base::unname(estimate + multiplier * standard_error)
  )
}

# Estimate clustered linear combination.
clustered_linear_combination <- function(model, data, weights, label, level = confidence_level) {
  engine         <- workflows::extract_fit_engine(model)
  estimates      <- stats::coef(engine)
  variance       <- sandwich::vcovCL(engine, cluster = data$playerId, type = 'HC1')
  missing_terms  <- base::setdiff(base::names(weights), base::names(estimates))
  if (base::length(missing_terms) > 0L) base::stop(base::paste0('Linear combination terms are unavailable: ', base::paste(missing_terms, collapse = ', '), '.'), call. = FALSE)
  contrast       <- stats::setNames(base::numeric(base::length(estimates)), base::names(estimates))
  contrast[base::names(weights)] <- weights
  estimate       <- base::sum(contrast * estimates)
  standard_error <- base::sqrt(base::drop(base::t(contrast) %*% variance %*% contrast))
  multiplier     <- confidence_multiplier(level)
  tibble::tibble(
    label = label,
    estimate = estimate,
    stdError = standard_error,
    statistic = estimate / standard_error,
    pValue = 2 * stats::pnorm(-base::abs(estimate / standard_error)),
    confLow = estimate - multiplier * standard_error,
    confHigh = estimate + multiplier * standard_error
  )
}

# Test clustered coefficient restrictions.
clustered_joint_wald <- function(model, data, terms) {
  engine        <- workflows::extract_fit_engine(model)
  estimates     <- stats::coef(engine)
  variance      <- sandwich::vcovCL(engine, cluster = data$playerId, type = 'HC1')
  missing_terms <- base::setdiff(terms, base::names(estimates))
  if (base::length(missing_terms) > 0L) base::stop(base::paste0('Wald-test terms are unavailable: ', base::paste(missing_terms, collapse = ', '), '.'), call. = FALSE)
  restriction          <- base::matrix(0, nrow = base::length(terms), ncol = base::length(estimates), dimnames = base::list(terms, base::names(estimates)))
  restriction[base::cbind(base::seq_along(terms), base::match(terms, base::names(estimates)))] <- 1
  restricted_estimates <- restriction %*% estimates
  restricted_variance  <- restriction %*% variance %*% base::t(restriction)
  statistic            <- base::drop(base::t(restricted_estimates) %*% base::solve(restricted_variance) %*% restricted_estimates)
  tibble::tibble(statistic = statistic, degreesFreedom = base::length(terms), pValue = stats::pchisq(statistic, df = base::length(terms), lower.tail = FALSE))
}

# Summarize analysis result.
summarize_analysis_result <- function(model, data, label, outcome, scale = 'linear', level = confidence_level, cluster_data = NULL) {
  result <- clustered_term(model, data, level = level, cluster_data = cluster_data) |>
    dplyr::mutate(label = label, outcome = outcome, sampleSize = base::nrow(data), players = dplyr::n_distinct(data$playerId), scale = scale, .before = 1L)
  if (scale == 'odds ratio') {
    result <- result |>
      dplyr::mutate(effect = base::exp(estimate), effectLow = base::exp(confLow), effectHigh = base::exp(confHigh))
  } else if (scale == 'percent') {
    result <- result |>
      dplyr::mutate(effect = 100 * (base::exp(estimate) - 1), effectLow = 100 * (base::exp(confLow) - 1), effectHigh = 100 * (base::exp(confHigh) - 1))
  } else {
    result <- result |>
      dplyr::mutate(effect = estimate, effectLow = confLow, effectHigh = confHigh)
  }
  result
}

# Estimate average logistic probabilities.
estimate_average_probabilities <- function(model, data, csax_values, contrast_values = base::c(-1, 1), level = confidence_level) {
  engine     <- workflows::extract_fit_engine(model)
  blueprint  <- workflows::extract_mold(model)$blueprint
  variance   <- sandwich::vcovCL(engine, cluster = data$playerId, type = 'HC1')
  terms      <- stats::delete.response(stats::terms(engine))
  estimates  <- stats::coef(engine)
  multiplier <- confidence_multiplier(level)
  # Summarize fixed CSAx value.
  build_summary <- function(csax_value) {
    prediction_data <- data |>
      dplyr::mutate(CSAx = csax_value)
    predictors     <- hardhat::forge(prediction_data, blueprint = blueprint)$predictors
    design         <- stats::model.matrix(terms, data = predictors)
    design         <- design[, base::names(estimates), drop = FALSE]
    probability    <- stats::plogis(base::as.vector(design %*% estimates))
    gradient       <- base::colMeans(design * probability * (1 - probability))
    standard_error <- base::sqrt(base::drop(base::t(gradient) %*% variance %*% gradient))
    base::list(
      summary = tibble::tibble(
        CSAx = csax_value,
        probability = base::mean(probability),
        stdError = standard_error,
        confLow = base::max(0, base::mean(probability) - multiplier * standard_error),
        confHigh = base::min(1, base::mean(probability) + multiplier * standard_error)
      ),
      gradient = gradient
    )
  }
  probability_parts <- purrr::map(csax_values, build_summary)
  contrast_parts    <- purrr::map(contrast_values, build_summary)
  probability_curve <- dplyr::bind_rows(purrr::map(probability_parts, 'summary'))
  contrast_estimate <- contrast_parts[[2L]]$summary$probability - contrast_parts[[1L]]$summary$probability
  contrast_gradient <- contrast_parts[[2L]]$gradient - contrast_parts[[1L]]$gradient
  contrast_error    <- base::sqrt(base::drop(base::t(contrast_gradient) %*% variance %*% contrast_gradient))
  contrast <- tibble::tibble(
    CSAxLow = contrast_values[[1L]],
    CSAxHigh = contrast_values[[2L]],
    estimate = contrast_estimate,
    stdError = contrast_error,
    confLow = contrast_estimate - multiplier * contrast_error,
    confHigh = contrast_estimate + multiplier * contrast_error
  )
  base::list(curve = probability_curve, contrast = contrast)
}

# Bootstrap Helpers --------------------------------------------------------

# Calculate average fitted probabilities without conditional intervals.
estimate_probability_points <- function(model, data, csax_values) {
  purrr::map_dfr(csax_values, function(csax_value) {
    prediction_data <- data |>
      dplyr::mutate(CSAx = csax_value)
    probabilities <- stats::predict(model, new_data = prediction_data, type = 'prob')$.pred_1
    tibble::tibble(CSAx = csax_value, probability = base::mean(probabilities))
  })
}

# Draw complete player histories with replacement.
draw_player_bootstrap <- function(data, seed) {
  player_ids <- base::sort(base::unique(data$playerId))
  base::set.seed(seed)
  draws <- tibble::tibble(bootstrapDrawId = base::seq_along(player_ids), playerId = base::sample(player_ids, base::length(player_ids), replace = TRUE))
  bootstrap_data <- draws |>
    dplyr::left_join(data, by = 'playerId', relationship = 'many-to-many') |>
    dplyr::arrange(seasonId, playerId, bootstrapDrawId) |>
    dplyr::group_by(seasonId) |>
    dplyr::mutate(zHeight = standardize_vector(height), zWeight = standardize_vector(weight), listedSize = standardize_vector((zHeight + zWeight) / base::sqrt(2))) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      ageC = age - base::mean(age),
      ageSquared = ageC^2,
      gamesC = standardize_complete(gamesDressed),
      toiC = standardize_complete(timeOnIcePerGame),
      pointsC = standardize_complete(pointsPer605v5),
      satC = standardize_complete(satRelative5v5),
      bootstrapRow = dplyr::row_number()
    )
  if (base::nrow(draws) != base::length(player_ids) || base::anyNA(bootstrap_data$continued300)) base::stop('Player bootstrap draw is incomplete.', call. = FALSE)
  bootstrap_data
}

# Fit one full-pipeline player-bootstrap replicate.
fit_primary_bootstrap_replicate <- function(data, replicate_id, predictors, probability_grid) {
  replicate_seed <- xs_bootstrap_seed + replicate_id * 100000L
  bootstrap_data <- draw_player_bootstrap(data, replicate_seed)
  season_data    <- base::split(bootstrap_data, bootstrap_data$seasonId)
  unique_groups  <- base::vapply(season_data, function(season) dplyr::n_distinct(season$playerId), base::integer(1L))
  if (!base::identical(base::as.integer(base::names(season_data)), xs_behavior_seasons) || base::any(unique_groups < xs_outer_folds)) base::stop(base::paste0('Bootstrap replicate ', replicate_id, ' has incomplete season coverage.'), call. = FALSE)
  bootstrap_predictions <- purrr::imap_dfr(season_data, function(season, season_name) {
    fit <- fit_expected_size(
      season,
      seed = replicate_seed + base::as.integer(season_name),
      repeats = xs_repeats,
      fit_flexible_calibration = FALSE,
      fold_group = 'playerId'
    )
    dplyr::bind_cols(
      season |>
        dplyr::select(bootstrapRow),
      fit$predictions |>
        dplyr::select(CSAx)
    )
  })
  bootstrap_outcomes <- bootstrap_data |>
    dplyr::select(-CSAx) |>
    dplyr::left_join(bootstrap_predictions, by = 'bootstrapRow')
  if (base::nrow(bootstrap_outcomes) != base::nrow(bootstrap_data) || base::anyNA(bootstrap_outcomes$CSAx)) base::stop(base::paste0('Bootstrap replicate ', replicate_id, ' lacks complete CSAx predictions.'), call. = FALSE)
  model         <- fit_analysis_workflow(bootstrap_outcomes, 'continued300', predictors, model_type = 'logistic')
  engine        <- workflows::extract_fit_engine(model)
  log_odds      <- base::unname(stats::coef(engine)[['CSAx']])
  probabilities <- estimate_probability_points(model, bootstrap_outcomes, probability_grid) |>
    dplyr::mutate(replicateId = replicate_id, .before = 1L)
  probability_low  <- probabilities$probability[dplyr::near(probabilities$CSAx, -1)]
  probability_high <- probabilities$probability[dplyr::near(probabilities$CSAx, 1)]
  if (base::length(probability_low) != 1L || base::length(probability_high) != 1L) base::stop(base::paste0('Bootstrap replicate ', replicate_id, ' lacks the requested probability contrast.'), call. = FALSE)
  result <- tibble::tibble(
    replicateId = replicate_id,
    sampledPlayers = dplyr::n_distinct(bootstrap_outcomes$bootstrapDrawId),
    uniquePlayers = dplyr::n_distinct(bootstrap_outcomes$playerId),
    forwardSeasons = base::nrow(bootstrap_outcomes),
    logOdds = log_odds,
    oddsRatio = base::exp(log_odds),
    probabilityLow = probability_low,
    probabilityHigh = probability_high,
    probabilityContrast = probability_high - probability_low
  )
  assert_finite(result, base::c('logOdds', 'oddsRatio', 'probabilityLow', 'probabilityHigh', 'probabilityContrast'), base::paste0('Bootstrap replicate ', replicate_id))
  assert_finite(probabilities, 'probability', base::paste0('Bootstrap probability curve ', replicate_id))
  base::list(result = result, probabilities = probabilities)
}

# Save resumable bootstrap cache atomically.
save_bootstrap_cache <- function(cache, path) {
  base::dir.create(base::dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary_path <- base::tempfile(pattern = 'primary_bootstrap_', tmpdir = base::dirname(path), fileext = '.rds')
  base::on.exit(base::unlink(temporary_path), add = TRUE)
  base::saveRDS(cache, temporary_path, compress = 'gzip')
  if (!base::file.rename(temporary_path, path)) base::stop('Primary-bootstrap cache could not be saved atomically.', call. = FALSE)
  base::invisible(path)
}

# Run or resume full-pipeline player bootstrap.
run_primary_bootstrap <- function(data, predictors, probability_grid, cache_path = 'data/cache/primary_bootstrap_strict_20260826.rds', replicates = xs_bootstrap_reps, workers = base::min(14L, base::max(1L, parallel::detectCores(logical = FALSE) - 2L))) {
  if (!base::is.numeric(workers) || base::length(workers) != 1L || !base::is.finite(workers) || workers < 1) base::stop('Primary-bootstrap worker count must be a positive scalar.', call. = FALSE)
  workers       <- if (base::.Platform$OS.type == 'windows') 1L else base::min(14L, base::as.integer(workers))
  configuration <- base::list(version = '20260826-v1', seed = xs_bootstrap_seed, replicates = replicates, sampleUnit = 'player', foldGroup = 'original player', repeats = xs_repeats, outerFolds = xs_outer_folds, innerFolds = xs_inner_folds, features = xs_features, probabilityGrid = probability_grid, quantileType = 6L)
  cache         <- if (base::file.exists(cache_path)) base::readRDS(cache_path) else base::list(configuration = configuration, results = tibble::tibble(), probabilities = tibble::tibble())
  if (!base::identical(cache$configuration, configuration)) base::stop('Primary-bootstrap cache configuration changed.', call. = FALSE)
  completed_ids <- if (base::nrow(cache$results) == 0L) base::integer() else cache$results$replicateId
  missing_ids   <- base::setdiff(base::seq_len(replicates), completed_ids)
  batch_size    <- workers * 4L
  batches       <- base::split(missing_ids, base::ceiling(base::seq_along(missing_ids) / batch_size))
  for (batch in batches) {
    batch_fits <- parallel::mclapply(
      batch,
      function(replicate_id) {
        base::tryCatch(fit_primary_bootstrap_replicate(data, replicate_id, predictors, probability_grid), error = function(error) base::list(error = base::conditionMessage(error), replicateId = replicate_id))
      },
      mc.cores = base::min(workers, base::length(batch)),
      mc.preschedule = FALSE,
      mc.set.seed = FALSE
    )
    failures <- purrr::keep(batch_fits, function(fit) !base::is.null(fit$error))
    if (base::length(failures) > 0L) base::stop(base::paste0('Primary bootstrap failed at replicate ', failures[[1L]]$replicateId, ': ', failures[[1L]]$error), call. = FALSE)
    cache$results <- dplyr::bind_rows(cache$results, purrr::map_dfr(batch_fits, 'result')) |>
      dplyr::arrange(replicateId)
    cache$probabilities <- dplyr::bind_rows(cache$probabilities, purrr::map_dfr(batch_fits, 'probabilities')) |>
      dplyr::arrange(replicateId, CSAx)
    save_bootstrap_cache(cache, cache_path)
    base::message('Completed ', base::nrow(cache$results), ' of ', replicates, ' primary-bootstrap replicates.')
  }
  if (base::nrow(cache$results) != replicates || dplyr::n_distinct(cache$results$replicateId) != replicates || base::nrow(cache$probabilities) != replicates * base::length(probability_grid)) base::stop('Primary bootstrap is incomplete.', call. = FALSE)
  cache
}

# Calculate type-six bootstrap percentile interval.
bootstrap_percentile <- function(x, level = confidence_level) {
  probabilities <- base::c((1 - level) / 2, (1 + level) / 2)
  base::as.numeric(stats::quantile(x, probs = probabilities, type = 6L, names = FALSE))
}

# Combine canonical estimates with full-pipeline bootstrap uncertainty.
summarize_primary_bootstrap <- function(bootstrap, canonical_result, canonical_probabilities, canonical_contrast) {
  replicate_results  <- bootstrap$results
  log_interval        <- bootstrap_percentile(replicate_results$logOdds)
  odds_ratio_interval <- bootstrap_percentile(replicate_results$oddsRatio)
  bootstrap_error     <- stats::sd(replicate_results$logOdds)
  lower_tail          <- (base::sum(replicate_results$logOdds <= 0) + 1) / (base::nrow(replicate_results) + 1)
  upper_tail          <- (base::sum(replicate_results$logOdds >= 0) + 1) / (base::nrow(replicate_results) + 1)
  result <- canonical_result |>
    dplyr::mutate(
      stdError = bootstrap_error,
      statistic = estimate / bootstrap_error,
      pValue = base::min(1, 2 * base::min(lower_tail, upper_tail)),
      confLow = log_interval[[1L]],
      confHigh = log_interval[[2L]],
      effectLow = odds_ratio_interval[[1L]],
      effectHigh = odds_ratio_interval[[2L]],
      intervalMethod = 'Full-pipeline player-cluster percentile bootstrap'
    )
  probability_intervals <- base::split(bootstrap$probabilities, bootstrap$probabilities$CSAx) |>
    purrr::map_dfr(function(probabilities) {
      interval <- bootstrap_percentile(probabilities$probability)
      tibble::tibble(CSAx = probabilities$CSAx[[1L]], stdError = stats::sd(probabilities$probability), confLow = interval[[1L]], confHigh = interval[[2L]])
    }) |>
    dplyr::arrange(CSAx)
  probabilities <- canonical_probabilities |>
    dplyr::select(CSAx, probability) |>
    dplyr::left_join(probability_intervals, by = 'CSAx')
  contrast_interval <- bootstrap_percentile(replicate_results$probabilityContrast)
  contrast <- canonical_contrast |>
    dplyr::mutate(stdError = stats::sd(replicate_results$probabilityContrast), confLow = contrast_interval[[1L]], confHigh = contrast_interval[[2L]], intervalMethod = 'Full-pipeline player-cluster percentile bootstrap')
  assert_finite(result, base::c('effect', 'effectLow', 'effectHigh', 'stdError', 'pValue'), 'Primary bootstrap summary')
  assert_finite(probabilities, base::c('probability', 'stdError', 'confLow', 'confHigh'), 'Primary bootstrap probability curve')
  assert_finite(contrast, base::c('estimate', 'stdError', 'confLow', 'confHigh'), 'Primary bootstrap probability contrast')
  base::list(result = result, probabilities = probabilities, contrast = contrast)
}

# Read hash-locked scouting ratings.
read_scouting_validation <- function(ratings_path = 'validation_private/external_validation_ratings.csv', lock_path = 'validation_private/external_validation_hashes.csv', key_path = 'validation_private/external_validation_key.csv') {
  expected_columns <- base::c('studyId', 'reportText', 'playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay', 'overallPhysicality', 'notes')
  binary_columns   <- base::c('playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay')
  if (!base::file.exists(ratings_path) || !base::file.exists(lock_path) || !base::file.exists(key_path)) base::stop('Completed scouting ratings, their lock file, and the private study key are required.', call. = FALSE)
  manifest <- readr::read_csv(lock_path, show_col_types = FALSE, col_types = readr::cols(artifact = readr::col_character(), file = readr::col_character(), sha256 = readr::col_character(), lockedAt = readr::col_date()))
  expected_files <- base::c('external_validation_packet.csv', 'external_validation_ratings.numbers', 'external_validation_ratings.csv', 'external_validation_key.csv')
  if (!base::identical(base::sort(manifest$file), base::sort(expected_files))) base::stop('External-validation lock manifest is incomplete or contains unexpected files.', call. = FALSE)
  assert_unique(manifest, 'file', 'External-validation lock manifest')
  manifest_paths <- base::file.path(base::dirname(lock_path), manifest$file)
  if (base::any(!base::file.exists(manifest_paths))) base::stop('A locked external-validation artifact is missing.', call. = FALSE)
  observed_hashes <- base::vapply(manifest_paths, function(path) digest::digest(file = path, algo = 'sha256'), base::character(1L))
  if (!base::identical(base::unname(observed_hashes), manifest$sha256)) base::stop('A locked external-validation artifact has changed.', call. = FALSE)
  lock <- manifest |>
    dplyr::filter(file == base::basename(ratings_path)) |>
    dplyr::select(file, sha256, lockedAt)
  if (base::nrow(lock) != 1L) base::stop('Completed scouting-ratings lock metadata is invalid.', call. = FALSE)
  ratings <- readr::read_csv(ratings_path, show_col_types = FALSE, col_types = readr::cols(studyId = readr::col_character(), reportText = readr::col_character(), playsBiggerExplicit = readr::col_integer(), activePhysicalEngagement = readr::col_integer(), interiorPlay = readr::col_integer(), overallPhysicality = readr::col_integer(), notes = readr::col_character()))
  if (!base::identical(base::names(ratings), expected_columns)) base::stop('Completed scouting-ratings columns changed.', call. = FALSE)
  assert_unique(ratings, 'studyId', 'Completed scouting ratings')
  if (base::nrow(ratings) != 40L || base::anyNA(ratings$studyId) || base::anyNA(ratings$reportText)) base::stop('Completed scouting ratings must contain 40 identified passages.', call. = FALSE)
  if (base::any(!purrr::map_lgl(ratings[binary_columns], function(values) base::all(values %in% base::c(0L, 1L))))) base::stop('A binary scouting rating uses an invalid or missing code.', call. = FALSE)
  if (base::anyNA(ratings$overallPhysicality) || base::any(!ratings$overallPhysicality %in% base::c(-1L, 0L, 1L))) base::stop('A scouting passage lacks a permitted overall rating.', call. = FALSE)
  planned_columns <- base::c('overallPhysicality', 'playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay')
  missing_variation <- purrr::keep(planned_columns, function(column) dplyr::n_distinct(ratings[[column]]) < 2L)
  if (base::length(missing_variation) > 0L) base::stop(base::paste0('Fresh scouting coding requires consultation because planned comparisons lack variation: ', base::paste(missing_variation, collapse = ', '), '.'), call. = FALSE)
  key <- readr::read_csv(key_path, show_col_types = FALSE)
  assert_columns(key, base::c('studyId', 'playerId', 'redactedTextSha256'), 'Private scouting study key')
  assert_unique(key, 'studyId', 'Private scouting study key')
  if (!base::identical(base::sort(ratings$studyId), base::sort(key$studyId))) base::stop('Completed scouting ratings do not match the locked study key.', call. = FALSE)
  text_checks <- ratings |>
    dplyr::transmute(studyId, redactedTextSha256 = base::vapply(reportText, digest::digest, base::character(1L), algo = 'sha256', serialize = FALSE)) |>
    dplyr::inner_join(key |> dplyr::select(studyId, expectedRedactedTextSha256 = redactedTextSha256), by = 'studyId')
  if (base::nrow(text_checks) != 40L || base::any(text_checks$redactedTextSha256 != text_checks$expectedRedactedTextSha256)) base::stop('A blinded scouting passage changed during coding.', call. = FALSE)
  joined <- ratings |>
    dplyr::select(-reportText) |>
    dplyr::inner_join(key, by = 'studyId') |>
    dplyr::arrange(studyId)
  if (base::nrow(joined) != base::nrow(ratings) || base::anyNA(joined$playerId)) base::stop('Scouting ratings did not join completely to the study key.', call. = FALSE)
  base::list(data = joined, lock = lock)
}

# Reconstruct scouting validation from the public, prose-free data.
read_public_scouting_validation <- function(forward_seasons, public_path = 'validation/external_validation_data.csv', provenance = base::list()) {
  expected_columns <- base::c('studyId', 'playerId', 'player', 'eligibleSeasons', 'firstSeason', 'draftYear', 'draftTeam', 'draftRound', 'draftOverall', 'sourceId', 'reportYear', 'publicationDate', 'sourcePage', 'sourceLocator', 'publicUrl', 'reportTextSha256', 'overallPhysicality', 'playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay', 'meanCSAx')
  binary_columns <- base::c('playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay')
  if (!base::file.exists(public_path)) base::stop('The public scouting-validation data are required when private ratings are unavailable.', call. = FALSE)
  public_data <- readr::read_csv(public_path, show_col_types = FALSE) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(binary_columns), base::as.integer), overallPhysicality = base::as.integer(overallPhysicality))
  if (!base::identical(base::names(public_data), expected_columns)) base::stop('Public scouting-validation columns changed.', call. = FALSE)
  assert_unique(public_data, 'studyId', 'Public scouting validation')
  assert_unique(public_data, 'playerId', 'Public scouting validation')
  if (base::nrow(public_data) != 40L) base::stop('Public scouting-validation cohort changed.', call. = FALSE)
  if (base::any(!base::grepl('^[0-9a-f]{64}$', public_data$reportTextSha256)) || base::any(!base::startsWith(public_data$publicUrl, 'https://'))) base::stop('Public scouting-validation provenance is malformed.', call. = FALSE)
  if (base::any(!purrr::map_lgl(public_data[binary_columns], function(values) base::all(values %in% base::c(0L, 1L))))) base::stop('A public binary scouting rating uses an invalid or missing code.', call. = FALSE)
  if (base::anyNA(public_data$overallPhysicality) || base::any(!public_data$overallPhysicality %in% base::c(-1L, 0L, 1L))) base::stop('A public scouting record lacks a permitted overall rating.', call. = FALSE)
  planned_columns <- base::c('overallPhysicality', 'playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay')
  missing_variation <- purrr::keep(planned_columns, function(column) dplyr::n_distinct(public_data[[column]]) < 2L)
  if (base::length(missing_variation) > 0L) base::stop(base::paste0('Public scouting coding cannot reproduce planned comparisons because these fields lack variation: ', base::paste(missing_variation, collapse = ', '), '.'), call. = FALSE)
  player_profiles <- forward_seasons |>
    dplyr::filter(playerId %in% public_data$playerId) |>
    dplyr::arrange(playerId, seasonId) |>
    dplyr::group_by(playerId) |>
    dplyr::summarise(playerFullName = dplyr::first(playerFullName), eligibleSeasons = base::as.numeric(dplyr::n_distinct(seasonId)), firstSeasonId = base::min(seasonId), meanCSAx = base::mean(CSAx), .groups = 'drop') |>
    dplyr::mutate(firstSeason = base::paste0(firstSeasonId %/% 10000L, '-', base::substr(base::as.character(firstSeasonId), 7L, 8L)))
  public_checks <- public_data |>
    dplyr::inner_join(player_profiles, by = 'playerId', suffix = base::c('Public', 'Recomputed'))
  if (base::nrow(public_checks) != 40L) base::stop('Public scouting players do not match the scientific panel.', call. = FALSE)
  if (base::any(public_checks$player != public_checks$playerFullName) || base::any(public_checks$eligibleSeasonsPublic != public_checks$eligibleSeasonsRecomputed) || base::any(public_checks$firstSeasonPublic != public_checks$firstSeasonRecomputed)) base::stop('Public scouting player metadata do not match the scientific panel.', call. = FALSE)
  if (!base::isTRUE(base::all.equal(public_checks$meanCSAxPublic, base::round(public_checks$meanCSAxRecomputed, 2L), tolerance = 1e-12))) base::stop('Public rounded mean CSAx values do not match full-precision reconstruction.', call. = FALSE)
  joined <- public_data |>
    dplyr::select(-player, -eligibleSeasons, -firstSeason, -meanCSAx) |>
    dplyr::inner_join(player_profiles |> dplyr::select(playerId, playerFullName, eligibleSeasons, firstSeasonId), by = 'playerId') |>
    dplyr::arrange(studyId)
  ratings_hash <- if (!base::is.null(provenance$ratingsSha256)) provenance$ratingsSha256 else digest::digest(file = public_path, algo = 'sha256')
  locked_at <- if (!base::is.null(provenance$lockedAt)) base::as.Date(provenance$lockedAt) else base::as.Date(NA)
  lock <- tibble::tibble(file = 'external_validation_ratings.csv', sha256 = ratings_hash, lockedAt = locked_at)
  base::list(data = joined, lock = lock, source = 'public')
}

# Formatting Helpers -------------------------------------------------------

# Format season identifier.
format_season <- function(season_id) {
  base::paste0(season_id %/% 10000L, '-', base::substr(base::as.character(season_id), 7L, 8L))
}

# Format fixed-decimal value.
format_fixed <- function(x, digits) {
  dplyr::if_else(base::is.na(x), NA_character_, base::formatC(x, format = 'f', digits = digits))
}

# Graphics Helpers ---------------------------------------------------------

# Save PDF figure with embedded Nimbus Sans fonts.
save_pdf_figure <- function(plot, path, width, height) {
  source_path   <- base::tempfile(fileext = '.pdf')
  embedded_path <- base::tempfile(fileext = '.pdf')
  base::on.exit(base::unlink(base::c(source_path, embedded_path)), add = TRUE)
  ggplot2::ggsave(source_path, plot, width = width, height = height, device = 'pdf', family = 'NimbusSan', useDingbats = FALSE)
  grDevices::embedFonts(source_path, outfile = embedded_path)
  if (!base::file.exists(embedded_path) || base::file.info(embedded_path)$size < 1000 || !base::file.copy(embedded_path, path, overwrite = TRUE)) base::stop(base::paste0('Embedded PDF figure could not be written: ', path, '.'), call. = FALSE)
  base::invisible(path)
}

# Define publication theme.
theme_xs <- function(base_size = 9) {
  ggplot2::theme_classic(base_size = base_size, base_family = 'NimbusSan') +
    ggplot2::theme(
      plot.title.position = 'plot',
      plot.title = ggplot2::element_text(face = 'bold', size = base_size + 2),
      plot.subtitle = ggplot2::element_text(color = '#4B5563'),
      axis.title = ggplot2::element_text(face = 'bold'),
      legend.position = 'bottom',
      legend.title = ggplot2::element_text(face = 'bold'),
      strip.text = ggplot2::element_text(face = 'bold'),
      plot.margin = ggplot2::margin(5, 6, 5, 5)
    )
}

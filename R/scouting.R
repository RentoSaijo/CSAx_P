# Scouting Ratings --------------------------------------------------------

# Read reusable physical-engagement codes and expanded-cohort status.
read_physicality_scouting <- function() {
  columns <- base::c('studyId', 'playerId', 'player', 'sourceId', 'reportYear', 'publicationDate', 'sourcePage', 'sourceLocator', 'publicUrl', 'reportTextSha256', 'activePhysicalEngagement', 'interiorPlay')
  original <- readr::read_csv('validation/external_validation_data.csv', show_col_types = FALSE) |>
    dplyr::select(dplyr::all_of(columns)) |>
    dplyr::mutate(reportDate = publicationDate, ratingBatch = 'Frozen forward ratings')
  if (base::file.exists('validation_private/external_validation_hashes.csv')) {
    locked <- read_scouting_validation()$data
    compare <- base::c('studyId', 'playerId', 'activePhysicalEngagement', 'interiorPlay')
    if (!base::isTRUE(base::all.equal(original[compare] |> dplyr::arrange(studyId), locked[compare] |> dplyr::arrange(studyId), check.attributes = FALSE))) base::stop('Frozen physicality codes changed.', call. = FALSE)
  }
  manifest <- readr::read_csv('validation/scouting_expansion_manifest.csv', show_col_types = FALSE)
  planned <- manifest |> dplyr::filter(artifact == 'Blinded packet')
  complete <- base::file.exists('validation/scouting_expansion_lock.csv')
  expanded <- original[0L, ]
  if (complete) {
    lock <- readr::read_csv('validation/scouting_expansion_lock.csv', show_col_types = FALSE)
    code_path <- 'validation/scouting_expansion_data.csv'
    if (base::nrow(lock) != 1L || !base::file.exists(code_path) || !base::identical(digest::digest(file = code_path, algo = 'sha256'), lock$codesSha256)) base::stop('Expanded scouting codes differ from locked data.', call. = FALSE)
    expanded <- readr::read_csv(code_path, show_col_types = FALSE) |>
      dplyr::mutate(ratingBatch = 'Expanded positional ratings')
    if (base::nrow(expanded) != planned$rows) base::stop('Expanded scouting cohort is incomplete.', call. = FALSE)
  }
  data <- dplyr::bind_rows(original, expanded)
  assert_unique(data, 'playerId', 'Physicality scouting cohort')
  base::list(data = data, status = if (complete) 'Complete' else 'Awaiting human ratings', expansionComplete = complete, plannedNewPlayers = planned$rows, plannedNewForwards = planned$forwards, plannedNewDefensemen = planned$defensemen, completedNewPlayers = base::nrow(expanded), raters = 1L, indicators = base::c('activePhysicalEngagement', 'interiorPlay'))
}

# Lock complete human ratings after checking identities and passage integrity.
lock_scouting_expansion <- function() {
  if (base::file.exists('validation/scouting_expansion_lock.csv')) base::stop('Expanded scouting ratings are already locked.', call. = FALSE)
  packet_path <- 'validation_private/scouting_expansion_packet.csv'
  key_path <- 'validation_private/scouting_expansion_key.csv'
  manifest <- readr::read_csv('validation/scouting_expansion_manifest.csv', show_col_types = FALSE)
  key_hash <- manifest$sha256[manifest$artifact == 'Identity key']
  if (!base::identical(digest::digest(file = key_path, algo = 'sha256'), key_hash)) base::stop('Expanded scouting identity key changed.', call. = FALSE)
  ratings <- readr::read_csv(packet_path, col_types = readr::cols(studyId = readr::col_character(), reportText = readr::col_character(), activePhysicalEngagement = readr::col_integer(), interiorPlay = readr::col_integer(), notes = readr::col_character()))
  expected <- base::c('studyId', 'reportText', 'activePhysicalEngagement', 'interiorPlay', 'notes')
  if (!base::identical(base::names(ratings), expected)) base::stop('Expanded scouting packet columns changed.', call. = FALSE)
  key <- readr::read_csv(key_path, show_col_types = FALSE)
  assert_unique(ratings, 'studyId', 'Expanded scouting packet')
  if (!base::identical(base::sort(ratings$studyId), base::sort(key$studyId)) || base::anyNA(ratings$reportText)) base::stop('Expanded scouting packet does not cover every planned passage.', call. = FALSE)
  for (indicator in base::c('activePhysicalEngagement', 'interiorPlay')) {
    if (base::anyNA(ratings[[indicator]]) || !base::all(ratings[[indicator]] %in% base::c(0L, 1L))) base::stop('Complete both 0/1 fields for every passage before locking ratings.', call. = FALSE)
  }
  checked <- ratings |>
    dplyr::mutate(observedTextSha256 = base::vapply(reportText, digest::digest, base::character(1L), algo = 'sha256', serialize = FALSE)) |>
    dplyr::inner_join(key, by = 'studyId')
  if (base::any(checked$observedTextSha256 != checked$redactedTextSha256)) base::stop('A blinded scouting passage changed during coding.', call. = FALSE)
  codes <- checked |>
    dplyr::select(studyId, playerId, player, sourceId, reportYear, publicationDate, reportDate, sourcePage, sourceLocator, publicUrl, reportTextSha256, activePhysicalEngagement, interiorPlay) |>
    dplyr::arrange(studyId)
  code_path <- 'validation/scouting_expansion_data.csv'
  readr::write_csv(codes, code_path)
  lock <- tibble::tibble(rows = base::nrow(codes), raters = 1L, packetSha256 = digest::digest(file = packet_path, algo = 'sha256'), keySha256 = key_hash, codesSha256 = digest::digest(file = code_path, algo = 'sha256'), lockedAt = base::format(base::Sys.time(), tz = 'UTC', usetz = TRUE))
  readr::write_csv(lock, 'validation/scouting_expansion_lock.csv')
  base::message('Locked ', base::nrow(codes), ' expanded scouting ratings.')
  base::invisible(codes)
}

# Compare scored physicality with independently coded scouting descriptions.
analyze_physicality_scouting <- function(predictions, ratings) {
  observations <- predictions |>
    dplyr::filter(!isCenterComparison, model %in% base::c('Forwards', 'Defensemen')) |>
    dplyr::inner_join(ratings$data, by = 'playerId') |>
    dplyr::filter(dplyr::coalesce(publicationDate, reportDate) < base::as.Date(base::paste0(seasonId %/% 10000L, '-09-01')))
  scores <- observations |>
    dplyr::group_by(model, referencePopulation, studyId, playerId, ratingBatch, activePhysicalEngagement, interiorPlay) |>
    dplyr::summarise(meanCSAx = base::mean(CSAx), observedSeasons = dplyr::n(), .groups = 'drop')
  estimates <- purrr::map_dfr(base::c('Forwards', 'Defensemen'), function(population) {
    data <- scores |> dplyr::filter(model == population)
    purrr::map_dfr(ratings$indicators, function(indicator) {
      n <- base::nrow(data)
      positive <- base::sum(data[[indicator]] == 1L)
      available <- n > 2L && positive > 1L && n - positive > 1L
      result <- if (available) {
        fit <- fit_analysis_workflow(data, 'meanCSAx', indicator)
        clustered_term(fit, data, term = indicator)
      } else tibble::tibble(term = indicator, estimate = NA_real_, stdError = NA_real_, confLow = NA_real_, confHigh = NA_real_, pValue = NA_real_)
      result |>
        dplyr::mutate(model = population, referencePopulation = population, indicator = indicator, n = n, positiveReports = positive, absentReports = n - positive, spearman = if (n > 1L && positive > 0L && positive < n && stats::sd(data$meanCSAx) > 0) stats::cor(data$meanCSAx, data[[indicator]], method = 'spearman') else NA_real_, contrastStatus = if (available) 'Available' else 'Insufficient observations or code variation', cohortStatus = ratings$status, intervalMethod = 'Player-clustered HC1; conditional on estimated scores and observed scouting cohort', .before = 1L)
    })
  })
  ratings$data <- NULL
  base::c(ratings, base::list(scores = scores, estimates = estimates))
}

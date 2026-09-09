# Setup --------------------------------------------------------------------

# Load strict definitions and publication paths.
base::source('R/functions.R')
paper_directory  <- 'reports/paper_cmsacrrc'
paper_source     <- base::file.path(paper_directory, 'index.qmd')
rendered_pdf     <- base::file.path(paper_directory, '_manuscript', 'index.pdf')
stable_pdf       <- base::file.path(paper_directory, 'paper_cmsacrrc.pdf')
legacy_pdf       <- base::file.path(paper_directory, 'paper.pdf')
tex_directory    <- base::file.path(paper_directory, '_manuscript', '_tex')
qa_directory     <- base::file.path('tmp', 'cmsacrrc')
raster_directory <- base::file.path('tmp', 'pdfs', 'cmsacrrc')
base::unlink(qa_directory, recursive = TRUE, force = TRUE)
base::unlink(raster_directory, recursive = TRUE, force = TRUE)
base::dir.create(qa_directory, recursive = TRUE, showWarnings = FALSE)
base::dir.create(raster_directory, recursive = TRUE, showWarnings = FALSE)

# Command Helpers ----------------------------------------------------------

# Locate a required executable.
find_command <- function(name, candidates = base::character()) {
  discovered <- base::unique(base::c(base::Sys.which(name), candidates))
  available  <- discovered[base::nzchar(discovered) & base::file.exists(discovered)]
  if (base::length(available) == 0L) base::stop(base::paste0('Required command is unavailable: ', name, '.'), call. = FALSE)
  available[[1L]]
}

# Run a command and retain complete output.
run_command <- function(command, arguments, log_path, working_directory = '.') {
  old_directory <- base::getwd()
  base::on.exit(base::setwd(old_directory), add = TRUE)
  log_path <- base::file.path(base::normalizePath(base::dirname(log_path), mustWork = TRUE), base::basename(log_path))
  base::setwd(working_directory)
  status <- base::system2(command, args = arguments, stdout = log_path, stderr = log_path)
  output <- if (base::file.exists(log_path)) base::readLines(log_path, warn = FALSE) else base::character()
  if (!base::identical(status, 0L)) base::stop(base::paste0('Command failed: ', base::basename(command), '.\n', base::paste(utils::tail(output, 40L), collapse = '\n')), call. = FALSE)
  output
}

# Compare data frames without irrelevant attributes.
assert_equal_data <- function(observed, expected, label, tolerance = 1e-12) {
  if (!base::isTRUE(base::all.equal(observed, expected, tolerance = tolerance, check.attributes = FALSE))) base::stop(base::paste0(label, ' changed.'), call. = FALSE)
  base::invisible(observed)
}

# Locate the publication toolchain.
runtime_poppler <- base::path.expand('~/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/poppler/bin')
quarto    <- find_command('quarto', base::c('/Applications/Positron.app/Contents/Resources/app/quarto/bin/quarto', '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto'))
latexmk   <- find_command('latexmk', '/Library/TeX/texbin/latexmk')
pdfinfo   <- find_command('pdfinfo', base::file.path(runtime_poppler, 'pdfinfo'))
pdffonts  <- find_command('pdffonts', base::file.path(runtime_poppler, 'pdffonts'))
pdftotext <- find_command('pdftotext', base::file.path(runtime_poppler, 'pdftotext'))
pdftoppm  <- find_command('pdftoppm', base::file.path(runtime_poppler, 'pdftoppm'))
git       <- find_command('git')

# Source Verification ------------------------------------------------------

# Parse every active R source before reading results.
r_sources <- base::c('R/functions.R', base::file.path('scripts', base::paste0(base::sprintf('%02d', 1:4), base::c('_prepare_data.R', '_build_csax.R', '_analyze.R', '_render_paper.R'))), base::file.path(paper_directory, 'manuscript_setup.R'))
missing_sources <- r_sources[!base::file.exists(r_sources)]
if (base::length(missing_sources) > 0L) base::stop('An active R source file is missing.', call. = FALSE)
purrr::walk(r_sources, function(path) base::parse(file = path))

# Reject obsolete feature, publication, and validation interfaces in active code.
active_text <- base::paste(base::unlist(purrr::map(base::c('R/functions.R', 'scripts/01_prepare_data.R', 'scripts/02_build_csax.R', 'scripts/03_analyze.R', 'README.md', paper_source, base::file.path(paper_directory, 'manuscript_setup.R')), base::readLines, warn = FALSE)), collapse = '\n')
obsolete_patterns <- base::c('active_engagement_', 'physicalEngagement', 'reports/paper_JSA', 'reports/paper/', 'paper.pdf', 'locationScaleCSAx', 'two_back_contract', 'fold_sensitivity')
matched_obsolete <- obsolete_patterns[base::vapply(obsolete_patterns, function(pattern) base::grepl(pattern, active_text, fixed = TRUE), base::logical(1L))]
if (base::length(matched_obsolete) > 0L) base::stop(base::paste0('Active workflow contains obsolete text: ', base::paste(matched_obsolete, collapse = ', '), '.'), call. = FALSE)

# Scientific Verification -------------------------------------------------

# Load and verify the strict scientific artifact.
analysis         <- base::readRDS('data/analysis_data.rds')
forward_seasons  <- analysis$forward_seasons
roster_outcomes  <- analysis$roster_outcomes
primary_result   <- analysis$application_results |> dplyr::filter(outcome == 'Next-season 300-minute continuation')
strict_columns   <- base::intersect(base::names(forward_seasons), xs_features)
discarded_fields <- base::c('giveawaysPer60', 'takeawaysPer60', 'faceoffsPer60', 'individualSatForPer60', 'individualShotsForPer60', 'slapShare', 'locationScaleCSAx', 'pkToiShare', 'offensiveZoneStartPct')
if (!base::identical(strict_columns, xs_features) || base::any(discarded_fields %in% base::names(forward_seasons))) base::stop('Strict ten-feature provenance failed.', call. = FALSE)
if (!base::identical(analysis$provenance$featureEventScope, 'Regular-season events excluding shootouts')) base::stop('Strict event scope is not recorded.', call. = FALSE)
if (!base::identical(analysis$provenance$expectedGoalSource$scoringScope, xs_xg_scoring_scope)) base::stop('Expected-goal scoring scope is not recorded.', call. = FALSE)
if (base::nrow(forward_seasons) != 1763L || base::nrow(roster_outcomes) != 1763L || dplyr::n_distinct(forward_seasons$playerId) != 613L) base::stop('Scientific panel changed from 1,763 forward-seasons and 613 players.', call. = FALSE)
if (base::sum(roster_outcomes$continued300Flag) != 1486L) base::stop('Continuation count changed from 1,486.', call. = FALSE)
if (base::nrow(analysis$conditioning_results) != 6L || base::nrow(analysis$quartile_profiles) != 4L || base::nrow(analysis$construct_sensitivity) != 2L) base::stop('Focused model summaries are incomplete.', call. = FALSE)
if (base::nrow(analysis$prior_role_coverage) != 4L || base::sum(analysis$prior_role_coverage$forwardSeasons) != 1763L || !base::identical(analysis$prior_role_coverage$priorRoleSeasonId, xs_prior_role_seasons)) base::stop('Prior-role sensitivity coverage is incomplete.', call. = FALSE)
if (base::nrow(analysis$role_timing_results) != 2L || base::any(analysis$role_timing_results$sampleSize != 1664L) || base::any(analysis$role_timing_results$players != 574L) || !base::identical(base::round(analysis$role_timing_results$effect, 2L), base::c(1.21, 1.19))) base::stop('Same-sample role-timing results changed.', call. = FALSE)
role_margin_summary <- analysis$role_margin_summary
role_time_interaction <- analysis$role_time_interaction_result
if (base::nrow(role_margin_summary) != 1L || role_margin_summary$noncontinuations != 277L || role_margin_summary$lowerHalfNoncontinuations != 243L || !base::identical(base::round(base::c(role_margin_summary$thirdQuartileContinuationRate, role_margin_summary$fourthQuartileContinuationRate), 2L), base::c(0.95, 0.97))) base::stop('Roster-margin summary changed.', call. = FALSE)
if (base::nrow(role_time_interaction) != 1L || base::round(role_time_interaction$effect, 2L) != 1.06 || base::round(role_time_interaction$pValue, 3L) != 0.524) base::stop('CSAx-by-current-ice-time interaction changed.', call. = FALSE)
hit_correlation <- analysis$feature_correlations |>
  dplyr::filter(feature == 'hitsPer60') |>
  dplyr::pull(csaxCorrelation)
contact_correlation <- analysis$construct_sensitivity |>
  dplyr::filter(specification == 'Contact actions') |>
  dplyr::pull(csaxCorrelation)
if (base::length(hit_correlation) != 1L || analysis$feature_correlations$feature[[1L]] != 'hitsPer60' || base::length(contact_correlation) != 1L || contact_correlation <= base::abs(hit_correlation)) base::stop('The targeted multivariable construct check changed.', call. = FALSE)

# Verify the fresh 999-replicate bootstrap and its canonical estimate.
bootstrap <- analysis$primary_bootstrap
if (base::nrow(bootstrap$replicates) != 999L || !base::identical(bootstrap$replicates$replicateId, base::seq_len(999L)) || base::nrow(bootstrap$probabilityReplicates) != 999L * base::length(base::seq(-2, 2, by = 0.1))) base::stop('The strict 999-replicate bootstrap is incomplete.', call. = FALSE)
if (!base::identical(bootstrap$configuration$features, xs_features) || bootstrap$configuration$version != '20260826-v1') base::stop('Bootstrap feature specification changed.', call. = FALSE)
reconstructed_primary <- summarize_primary_bootstrap(base::list(results = bootstrap$replicates, probabilities = bootstrap$probabilityReplicates), bootstrap$conditionalResult, bootstrap$conditionalProbabilities, bootstrap$conditionalContrast)
assert_equal_data(primary_result |> dplyr::select(dplyr::all_of(base::names(reconstructed_primary$result))), reconstructed_primary$result, 'Primary bootstrap result')
assert_equal_data(analysis$continuation_probabilities, reconstructed_primary$probabilities, 'Primary probability curve')
assert_equal_data(analysis$continuation_contrast, reconstructed_primary$contrast, 'Primary probability contrast')

# Verify public and private external-validation reconstruction.
public_validation <- read_public_scouting_validation(forward_seasons, provenance = analysis$provenance$externalValidation)
validation_columns <- base::c('studyId', 'playerId', 'overallPhysicality', 'playsBiggerExplicit', 'activePhysicalEngagement', 'interiorPlay')
assert_equal_data(public_validation$data |> dplyr::select(dplyr::all_of(validation_columns)) |> dplyr::arrange(studyId), analysis$external_validation |> dplyr::select(dplyr::all_of(validation_columns)) |> dplyr::arrange(studyId), 'Public external-validation codes')
if (base::nrow(public_validation$data) != 40L || base::sum(public_validation$data$playsBiggerExplicit) != 2L || base::sum(public_validation$data$activePhysicalEngagement) != 16L || base::sum(public_validation$data$interiorPlay) != 16L) base::stop('External-validation code distribution changed.', call. = FALSE)
expected_validation_files <- base::sort(base::c('external_validation_codebook.md', 'external_validation_data.csv', 'external_validation_source_catalog.csv'))
observed_validation_files <- base::sort(base::list.files('validation', all.files = FALSE, no.. = TRUE))
if (!base::identical(observed_validation_files, expected_validation_files)) base::stop('The active public validation directory contains obsolete or missing files.', call. = FALSE)
source_catalog <- readr::read_csv('validation/external_validation_source_catalog.csv', show_col_types = FALSE)
assert_columns(source_catalog, base::c('sourceId', 'privateFile', 'publicUrl', 'sha256'), 'External-validation source catalog')
assert_unique(source_catalog, 'sourceId', 'External-validation source catalog')
if (base::nrow(source_catalog) != 6L || base::any(!base::startsWith(source_catalog$publicUrl, 'https://'))) base::stop('External-validation source provenance is incomplete.', call. = FALSE)
validation_source_checks <- public_validation$data |>
  dplyr::select(studyId, sourceId, reportPublicUrl = publicUrl) |>
  dplyr::left_join(source_catalog |> dplyr::select(sourceId, catalogPublicUrl = publicUrl), by = 'sourceId')
if (base::nrow(validation_source_checks) != 40L || base::anyNA(validation_source_checks$catalogPublicUrl) || base::any(validation_source_checks$reportPublicUrl != validation_source_checks$catalogPublicUrl)) base::stop('External-validation reports do not map completely to the source catalog.', call. = FALSE)
if (base::all(base::file.exists(source_catalog$privateFile))) {
  observed_source_hashes <- base::vapply(source_catalog$privateFile, function(source_file) digest::digest(file = source_file, algo = 'sha256'), base::character(1L))
  if (!base::identical(base::unname(observed_source_hashes), source_catalog$sha256)) base::stop('A private scouting source differs from its public catalog hash.', call. = FALSE)
}
private_paths <- base::c('validation_private/external_validation_ratings.csv', 'validation_private/external_validation_hashes.csv', 'validation_private/external_validation_key.csv')
if (base::all(base::file.exists(private_paths))) {
  private_validation <- read_scouting_validation()
  assert_equal_data(private_validation$data |> dplyr::select(dplyr::all_of(validation_columns)) |> dplyr::arrange(studyId), public_validation$data |> dplyr::select(dplyr::all_of(validation_columns)) |> dplyr::arrange(studyId), 'Private and public external validation')
}

# Verify public rankings against the final object.
latest_season <- base::max(forward_seasons$seasonId)
player_rankings <- readr::read_csv(base::file.path(paper_directory, 'csax_rankings_2024-25.csv'), show_col_types = FALSE)
expected_player_rankings <- forward_seasons |>
  dplyr::filter(seasonId == latest_season, timeOnIce >= 500 * 60) |>
  dplyr::arrange(dplyr::desc(CSAx), playerId) |>
  dplyr::mutate(CSAxRank = dplyr::row_number()) |>
  dplyr::transmute(season = format_season(seasonId), CSAxRank, playerId, player = playerFullName, heightInches = height, weightPounds = weight, S = base::round(listedSize, 2L), xS = base::round(xS, 2L), CSAx = base::round(CSAx, 2L), minutes = base::round(timeOnIce / 60))
if (base::nrow(player_rankings) != 388L) base::stop('Player ranking changed from 388 forwards.', call. = FALSE)
assert_equal_data(player_rankings, expected_player_rankings, 'Player ranking')
team_rankings <- readr::read_csv(base::file.path(paper_directory, 'team_csax_rankings_2024-25.csv'), show_col_types = FALSE)
expected_team_rankings <- analysis$team_style_seasons |>
  dplyr::filter(seasonId == latest_season) |>
  dplyr::arrange(dplyr::desc(teamCSAx), teamId) |>
  dplyr::mutate(teamCSAxRank = dplyr::row_number()) |>
  dplyr::transmute(teamCSAxRank, teamId, teamCSAx = base::round(teamCSAx, 2L))
assert_equal_data(team_rankings |> dplyr::select(teamCSAxRank, teamId, teamCSAx), expected_team_rankings, 'Team ranking')

# Verify the compact publication directory.
expected_figures <- base::sort(base::c('feature_coefficients.pdf', 'roster_continuation.pdf', 'shrinkage.pdf'))
observed_figures <- base::sort(base::list.files(base::file.path(paper_directory, 'figures'), pattern = '\\.pdf$', full.names = FALSE))
if (!base::identical(observed_figures, expected_figures)) base::stop('The paper must contain exactly three vector figures.', call. = FALSE)

# Manuscript Verification --------------------------------------------------

# Validate citations, abstract values, anonymity, and final language.
source_lines <- base::readLines(paper_source, warn = FALSE)
source_text  <- base::paste(source_lines, collapse = '\n')
citation_matches <- base::regmatches(source_lines, base::gregexpr('@[A-Za-z0-9_-]+', source_lines, perl = TRUE))
citation_keys <- base::sort(base::unique(base::sub('^@', '', base::unlist(citation_matches))))
citation_keys <- citation_keys[!base::grepl('^(fig|tbl|eq|sec)-', citation_keys)]
bibliography_lines <- base::readLines(base::file.path(paper_directory, 'references.bib'), warn = FALSE)
bibliography_entries <- base::grep('^@[A-Za-z]+\\{[^,]+,', bibliography_lines, value = TRUE)
bibliography_keys <- base::sort(base::sub('^@[A-Za-z]+\\{([^,]+),.*$', '\\1', bibliography_entries))
if (!base::identical(citation_keys, bibliography_keys)) base::stop('Manuscript citations and bibliography entries do not match exactly.', call. = FALSE)
format_abstract <- function(x) base::formatC(base::round(x, 2L), format = 'f', digits = 2L)
contract_term_result <- analysis$application_results |>
  dplyr::filter(outcome == 'External-contract term')
playoff_dress_result <- analysis$application_results |>
  dplyr::filter(outcome == 'Playoff games-dressed share')
if (base::nrow(contract_term_result) != 1L || base::nrow(playoff_dress_result) != 1L) base::stop('Abstract supporting results are incomplete.', call. = FALSE)
abstract_tokens <- base::c('ten action variables through nested held-out fitting', '1,763 forward-seasons', '613 NHL players', base::paste0(format_abstract(primary_result$effect), ' times the odds'), base::paste0(format_abstract(primary_result$effectLow), ', ', format_abstract(primary_result$effectHigh)), base::paste0(format_abstract(100 * analysis$continuation_contrast$estimate), ' additional continuations'), base::paste0(format_abstract(contract_term_result$effect), ' additional years'), base::paste0(format_abstract(100 * playoff_dress_result$effect), '-percentage-point'), base::paste0('r=', format_abstract(analysis$team_descriptive_summary$correlation)), base::paste0('r=', format_abstract(analysis$team_playoff_shot_summary$correlation)))
missing_abstract <- abstract_tokens[!base::vapply(abstract_tokens, function(token) base::grepl(token, source_text, fixed = TRUE), base::logical(1L))]
if (base::length(missing_abstract) > 0L) base::stop(base::paste0('Static abstract is missing final values: ', base::paste(missing_abstract, collapse = ', '), '.'), call. = FALSE)
expected_scouting_sentence <- 'Blinded pre-NHL ratings of physicality and active engagement align most clearly with later CSAx, while contract duration and playoff availability point in the same direction.'
expected_summary_sentence <- 'Within its present scope, CSAx gives hockey fans, analysts, and decision-makers a common statistical language for asking not simply how big a player is, but how big he plays and, among forwards in comparable current roles, whether that identity accompanies staying in the NHL picture, while opening new questions about the repeatability of roster-level goal generation and the stability of offensive process from the regular season to the playoffs.'
if (!base::grepl(expected_scouting_sentence, source_text, fixed = TRUE) || !base::grepl(expected_summary_sentence, source_text, fixed = TRUE)) base::stop('The conclusion summary changed.', call. = FALSE)

# Verify result order and conclusion-first closing structure.
results_start <- base::match('## Results', source_lines)
closing_start <- base::match('## Conclusion, limitations, and discussion', source_lines)
if (base::anyNA(base::c(results_start, closing_start)) || results_start >= closing_start) base::stop('Results or closing section is unavailable.', call. = FALSE)
result_lines <- source_lines[base::seq.int(results_start, closing_start - 1L)]
result_headings <- result_lines[base::grepl('^### ', result_lines)]
expected_result_headings <- base::c('### The physical backbone', '### Playing big and staying in the NHL', '### Career stage and robustness', '### Players, rankings, and scouting reports', '### Organizational and team-level clues')
if (!base::identical(result_headings, expected_result_headings)) base::stop('Results do not follow the manuscript narrative.', call. = FALSE)
closing_text <- base::paste(source_lines[base::seq.int(closing_start, base::length(source_lines))], collapse = '\n')
closing_anchors <- base::c(expected_summary_sentence, 'Important limitations bound that conclusion', 'These limitations provide clear directions')
closing_positions <- base::vapply(closing_anchors, function(anchor) base::as.integer(base::regexpr(anchor, closing_text, fixed = TRUE)), base::integer(1L))
if (base::any(closing_positions < 1L) || base::is.unsorted(closing_positions, strictly = TRUE)) base::stop('Closing section must present conclusion, limitations, then discussion.', call. = FALSE)
placeholder_failures <- base::c('BOOTSTRAP_OR', 'BOOTSTRAP_LOW', 'BOOTSTRAP_HIGH', 'PROBABILITY_CONTRAST additional')
source_failures      <- base::c('about here', 'PLACEHOLDER', 'TODO', 'TBD', 'author:', 'affiliation:', 'acknowledgments', 'acknowledgements', 'funding:', '/Users/', 'Desktop/', 'wins wall battles', 'wins a puck', 'persepctive', 'outside the primary model', 'goal of the calibration', 'across the observed CSAx range', 'higher CSAx players', 'explanatory lens', 'independent coder', 'tese public events', 'seems to distinguishes', 'further solidifying our calibration', '[@nhlxg2026], Moreover')
matched_source_failures <- base::c(
  placeholder_failures[base::vapply(placeholder_failures, function(pattern) base::grepl(pattern, source_text, fixed = TRUE), base::logical(1L))],
  source_failures[base::vapply(source_failures, function(pattern) base::grepl(base::tolower(pattern), base::tolower(source_text), fixed = TRUE), base::logical(1L))]
)
if (base::length(matched_source_failures) > 0L) base::stop(base::paste0('Manuscript source contains prohibited text: ', base::paste(matched_source_failures, collapse = ', '), '.'), call. = FALSE)

# Rendering ----------------------------------------------------------------

# Render the anonymous manuscript and retain a stable PDF.
quarto_log <- base::file.path(qa_directory, 'quarto.log')
quarto_output <- run_command(quarto, base::c('render', paper_directory, '--to', 'jasa-pdf'), quarto_log)
render_failures <- base::c('Unable to resolve crossref', 'undefined citation', 'Citation.*undefined', 'Missing character', 'Undefined control sequence', 'FATAL', 'ERROR:')
matched_render_failures <- render_failures[base::vapply(render_failures, function(pattern) base::any(base::grepl(pattern, quarto_output, ignore.case = TRUE, perl = TRUE)), base::logical(1L))]
if (base::length(matched_render_failures) > 0L) base::stop(base::paste0('Quarto rendering reported: ', base::paste(matched_render_failures, collapse = ', '), '.'), call. = FALSE)
tex_path <- base::file.path(tex_directory, 'index.tex')
addlinespace_command <- base::paste0(base::intToUtf8(92L), 'addlinespace')
if (!base::file.exists(tex_path) || base::any(base::grepl(addlinespace_command, base::readLines(tex_path, warn = FALSE), fixed = TRUE))) base::stop('Generated table TeX contains nonuniform row spacing.', call. = FALSE)
if (base::file.exists(legacy_pdf)) base::stop('The obsolete paper.pdf artifact remains.', call. = FALSE)
if (!base::file.exists(rendered_pdf) || base::file.info(rendered_pdf)$size < 100000 || !base::file.copy(rendered_pdf, stable_pdf, overwrite = TRUE)) base::stop('The stable paper PDF was not created.', call. = FALSE)

# Recompile generated TeX to retain complete diagnostics.
latex_log <- base::file.path(qa_directory, 'latexmk-console.log')
base::invisible(run_command(latexmk, base::c('-lualatex', '-interaction=nonstopmode', '-halt-on-error', 'index.tex'), latex_log, tex_directory))
tex_log_path <- base::file.path(tex_directory, 'index.log')
tex_log <- base::readLines(tex_log_path, warn = FALSE)
tex_failures <- base::c('Overfull \\\\[hv]box', 'Missing character', 'Citation.*undefined', 'Reference.*undefined', 'There were undefined references', 'Undefined control sequence')
matched_tex_failures <- tex_failures[base::vapply(tex_failures, function(pattern) base::any(base::grepl(pattern, tex_log, ignore.case = TRUE, perl = TRUE)), base::logical(1L))]
if (base::length(matched_tex_failures) > 0L) base::stop(base::paste0('TeX diagnostics reported: ', base::paste(matched_tex_failures, collapse = ', '), '.'), call. = FALSE)

# PDF Verification ---------------------------------------------------------

# Extract PDF metadata, text, and fonts.
pdfinfo_output <- run_command(pdfinfo, stable_pdf, base::file.path(qa_directory, 'pdfinfo.txt'))
page_count <- base::as.integer(base::sub('^Pages:[[:space:]]*', '', pdfinfo_output[base::grepl('^Pages:', pdfinfo_output)]))
if (!base::identical(page_count, 13L)) base::stop('The paper must contain one title page, ten article pages, and two reference pages.', call. = FALSE)
author_line <- pdfinfo_output[base::grepl('^Author:', pdfinfo_output)]
if (base::length(author_line) > 0L && base::nzchar(base::trimws(base::sub('^Author:', '', author_line)))) base::stop('The anonymous PDF contains author metadata.', call. = FALSE)
metadata_failures <- base::c('Rento Saijo', 'Jeff Moher', 'Connecticut College', '/Users/', 'Desktop/Academic')
matched_metadata_failures <- metadata_failures[base::vapply(metadata_failures, function(pattern) base::any(base::grepl(pattern, pdfinfo_output, fixed = TRUE)), base::logical(1L))]
if (base::length(matched_metadata_failures) > 0L) base::stop(base::paste0('Anonymous PDF metadata contains identifying text: ', base::paste(matched_metadata_failures, collapse = ', '), '.'), call. = FALSE)
pdf_text_path <- base::file.path(qa_directory, 'paper.txt')
base::invisible(run_command(pdftotext, base::c('-layout', stable_pdf, pdf_text_path), base::file.path(qa_directory, 'pdftotext.log')))
pdf_text <- base::readChar(pdf_text_path, nchars = base::file.info(pdf_text_path)$size, useBytes = TRUE)
pdf_pages <- base::unname(base::strsplit(pdf_text, '\f', fixed = TRUE)[[1L]])
if (base::length(pdf_pages) > page_count && !base::nzchar(pdf_pages[[base::length(pdf_pages)]])) pdf_pages <- utils::head(pdf_pages, page_count)
if (base::length(pdf_pages) != page_count || base::grepl('Introduction', pdf_pages[[1L]], fixed = TRUE) || !base::grepl('Introduction', pdf_pages[[2L]], fixed = TRUE)) base::stop('Title-page or article-page flow changed.', call. = FALSE)
title_tokens <- base::c('Playing Big for Their Size', 'Anonymous authors', 'Affiliations withheld for anonymous review', 'September 1, 2026', 'Abstract', 'Keywords:')
if (base::any(!base::vapply(title_tokens, function(token) base::grepl(token, pdf_pages[[1L]], fixed = TRUE), base::logical(1L)))) base::stop('Anonymous title page is incomplete.', call. = FALSE)
reference_pages <- base::unname(base::which(base::vapply(pdf_pages, function(page) base::any(base::trimws(base::strsplit(page, '\n', fixed = TRUE)[[1L]]) == 'References'), base::logical(1L), USE.NAMES = FALSE)))
closing_pages <- base::which(base::vapply(pdf_pages, function(page) base::grepl('Conclusion, limitations, and discussion', base::gsub('[[:space:]]+', ' ', page), fixed = TRUE), base::logical(1L)))
if (!base::identical(reference_pages, 12L) || !base::identical(base::unname(closing_pages), 11L)) base::stop('Closing section must begin on numbered page 10, with references beginning on page 11.', call. = FALSE)
last_page_line <- function(page) {
  lines <- base::trimws(base::strsplit(page, '\n', fixed = TRUE)[[1L]])
  utils::tail(lines[base::nzchar(lines)], 1L)[[1L]]
}
if (!base::identical(last_page_line(pdf_pages[[2L]]), '1') || !base::identical(last_page_line(pdf_pages[[11L]]), '10') || !base::identical(last_page_line(pdf_pages[[12L]]), '11')) base::stop('Numbering must begin after the title page and reach references on page 11.', call. = FALSE)
collapsed_pdf_text <- base::gsub('-[[:space:]]+', '', pdf_text)
collapsed_pdf_text <- base::gsub('[[:space:]]+', ' ', collapsed_pdf_text)
if (!base::grepl(expected_summary_sentence, collapsed_pdf_text, fixed = TRUE)) base::stop('The rendered conclusion summary changed.', call. = FALSE)
pdf_failures <- base::c('Figure Figure', 'Equation Equation', 'Table Table', 'BOOTSTRAP_', 'PROBABILITY_CONTRAST', 'about here', 'PLACEHOLDER', 'TODO', 'TBD', '/Users/', 'file://', 'Desktop/Academic', 'Rento Saijo', 'Jeff Moher', 'Connecticut College', 'Acknowledgments', 'Author Contributions', 'Funding')
matched_pdf_failures <- pdf_failures[base::vapply(pdf_failures, function(pattern) base::grepl(base::tolower(pattern), base::tolower(pdf_text), fixed = TRUE), base::logical(1L))]
if (base::length(matched_pdf_failures) > 0L) base::stop(base::paste0('Rendered PDF contains prohibited text: ', base::paste(matched_pdf_failures, collapse = ', '), '.'), call. = FALSE)
font_output <- run_command(pdffonts, stable_pdf, base::file.path(qa_directory, 'pdffonts.txt'))
font_records <- font_output[base::seq_along(font_output) > 2L & base::nzchar(base::trimws(font_output))]
embedded_records <- base::grepl('[[:space:]]yes[[:space:]]+yes[[:space:]]+(yes|no)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]*$', font_records, perl = TRUE)
if (base::length(font_records) == 0L || !base::all(embedded_records)) base::stop('The rendered PDF contains a font that is not embedded and subset.', call. = FALSE)

# Rasterize every page for visual inspection.
raster_prefix <- base::file.path(raster_directory, 'page')
base::invisible(run_command(pdftoppm, base::c('-png', '-r', '150', stable_pdf, raster_prefix), base::file.path(qa_directory, 'pdftoppm.log')))
raster_pages <- base::sort(base::list.files(raster_directory, pattern = '^page-[0-9]+\\.png$', full.names = TRUE))
if (base::length(raster_pages) != 13L || base::any(base::file.info(raster_pages)$size < 10000)) base::stop('The PDF raster inspection set is incomplete.', call. = FALSE)

# Repository checks --------------------------------------------------------

# Reject whitespace errors after a successful render.
base::invisible(run_command(git, base::c('diff', '--check'), base::file.path(qa_directory, 'git-diff-check.log')))
base::message('Rendered and verified ', stable_pdf, ': one unnumbered title page, ten numbered article pages, two reference pages, 999 strict bootstrap replicates, anonymous metadata, embedded fonts, and 13 inspection images.')

# Setup -------------------------------------------------------------------

# Load completed positional analysis.
base::source('R/functions.R')
base::source('R/models.R')
a <- base::readRDS('data/analysis_data.rds')
if (base::is.null(a$inference) || a$bootstrap$replicates != 499L) base::stop('Completed positional analysis is required.', call. = FALSE)
report_directory <- 'reports/paper_mit_ssac'
figure_directory <- base::file.path(report_directory, 'figures')
base::dir.create(figure_directory, recursive = TRUE, showWarnings = FALSE)

# Reporting Helpers -------------------------------------------------------

# Format consistent numerical precision.
fixed <- function(values, digits = 2L) {
  values <- dplyr::if_else(base::abs(values) < 0.5 * 10^(-digits), 0, values)
  dplyr::if_else(base::is.na(values), '\u2014', base::formatC(values, format = 'f', digits = digits))
}

# Format season labels.
season_label <- function(seasons) base::paste0(seasons %/% 10000L, '\u2013', base::substr(base::as.character(seasons %% 10000L), 3L, 4L))

# Format confidence intervals.
interval <- function(effect, low, high, digits = 2L) base::paste0(fixed(effect, digits), ' (', fixed(low, digits), ' to ', fixed(high, digits), ')')

# Format probability values.
p_value <- function(values) dplyr::if_else(values < 0.001, '<0.001', fixed(values, 3L))

# Write compact Markdown tables.
markdown_table <- function(data) {
  data <- data |> dplyr::mutate(dplyr::across(dplyr::where(base::is.numeric), fixed))
  rows <- base::apply(data, 1L, function(row) base::paste0('| ', base::paste(row, collapse = ' | '), ' |'))
  base::paste(base::c(base::paste0('| ', base::paste(base::names(data), collapse = ' | '), ' |'), base::paste0('| ', base::paste(base::rep('---', base::ncol(data)), collapse = ' | '), ' |'), rows), collapse = '\n')
}

# Select positional estimate.
application_result <- function(population, outcome_name) a$applications$estimates |> dplyr::filter(model == population, outcome == outcome_name)

# Create gridless research theme.
research_theme <- function() ggplot2::theme_classic(base_size = 11, base_family = 'sans') + ggplot2::theme(legend.position = 'bottom', strip.background = ggplot2::element_blank(), strip.text = ggplot2::element_text(face = 'bold'), plot.title = ggplot2::element_text(face = 'bold'), panel.spacing = grid::unit(1.2, 'lines'))

# Data Products -----------------------------------------------------------

# Export native rankings among skaters with at least 500 minutes.
metadata <- a$inputs$features |> dplyr::filter(eventScope == 'All situations')
rankings <- a$primary$predictions |>
  dplyr::filter(!isCenterComparison, model %in% base::c('Forwards', 'Defensemen'), timeOnIce >= 500 * 60) |>
  dplyr::left_join(metadata |> dplyr::select(playerId, seasonId, height, weight), by = base::c('playerId', 'seasonId')) |>
  dplyr::group_by(model, seasonId) |>
  dplyr::arrange(dplyr::desc(CSAx), playerId, .by_group = TRUE) |>
  dplyr::mutate(rank = dplyr::row_number()) |>
  dplyr::ungroup() |>
  dplyr::transmute(model, referencePopulation, season = season_label(seasonId), seasonId, rank, playerId, player = playerFullName, heightInches = height, weightPounds = weight, minutes = timeOnIce / 60, listedSize, xS, CSAx, referencePercentile, directContribution, indirectContribution, frameAdjustment) |>
  dplyr::mutate(dplyr::across(dplyr::where(base::is.double), ~ base::round(.x, 2L)))
readr::write_csv(rankings, base::file.path(report_directory, 'player_rankings.csv'))

# Export paired center standing and relevant event denominators.
center_export <- a$centers |>
  dplyr::mutate(wingReference = 'Wings; centers excluded', defensemanReference = 'Defensemen; centers excluded', rankingEligible = timeOnIce >= 500 * 60) |>
  dplyr::left_join(metadata |> dplyr::select(playerId, seasonId, height, weight, defensiveTakeaways, defensivePerimeterTakeaways, locatedAttempts, typedShotsOnNet, dplyr::all_of(xs_direct_features)), by = base::c('playerId', 'seasonId')) |>
  dplyr::select(-rowId) |>
  dplyr::mutate(dplyr::across(dplyr::where(base::is.double), ~ base::round(.x, 2L)))
readr::write_csv(center_export, base::file.path(report_directory, 'center_comparisons.csv'))
readr::write_csv(a$inference$centers, base::file.path(report_directory, 'center_agreement.csv'))

# Export positional team summaries and clearly labeled application intervals.
team_export <- a$applications$teams$seasons |>
  dplyr::left_join(a$applications$teams$playoffQuality |> dplyr::select(model, seasonId, teamId, attempts_2, attempts_3, xGoalsPerAttempt_2, xGoalsPerAttempt_3, absoluteQualityChange), by = base::c('model', 'seasonId', 'teamId'))
readr::write_csv(team_export, base::file.path(report_directory, 'team_summaries.csv'))
primary_export <- a$inference$primary |> dplyr::filter(statistic == 'logOdds') |> dplyr::select(-statistic) |> dplyr::mutate(outcome = 'Next-season continuation', scale = 'odds ratio', label = 'Primary', term = 'CSAx') |>
  dplyr::left_join(a$applications$panel |> dplyr::group_by(model) |> dplyr::summarise(sampleSize = dplyr::n(), players = dplyr::n_distinct(playerId), .groups = 'drop'), by = 'model')
application_export <- dplyr::bind_rows(primary_export, a$applications$estimates |> dplyr::filter(outcome != 'Next-season continuation'), a$applications$sensitivityEstimates) |>
  dplyr::transmute(model, referencePopulation, label, outcome, sampleSize, players, term, scale, effect, effectLow, effectHigh, pValue, intervalMethod, scoreCaution = dplyr::if_else(model == 'Defensemen' & outcome == 'Indirect only', 'Unstable residual calibration; standalone reconstruction is unsuitable', ''))
readr::write_csv(application_export, base::file.path(report_directory, 'application_estimates.csv'))

# Research Figures --------------------------------------------------------

# Show standardized feature weights in separate positional models.
feature_labels <- base::c(hitsPer60 = 'Hits delivered', hitsReceivedPer60 = 'Hits received', blockedShotsPer60 = 'Blocked shots', fightsPer60 = 'Fights', contactPenaltiesTakenPer60 = 'Contact penalties taken', contactPenaltiesDrawnPer60 = 'Contact penalties drawn', netFrontAttemptShare = 'Net-front attempt share', deflectionShare = 'Tip/deflection share', medianShotDistance = 'Median shot distance', backhandShare = 'Backhand share', defensiveTakeawaysPer60 = 'Defensive-zone takeaways', defensivePerimeterTakeawayShare = 'Perimeter takeaway share')
coefficients <- a$primary$coefficients |>
  dplyr::filter(model != 'Wings') |>
  dplyr::group_by(model, component, feature) |>
  dplyr::summarise(coefficient = stats::median(coefficient), .groups = 'drop') |>
  dplyr::mutate(featureLabel = base::factor(feature_labels[feature], levels = base::rev(base::unname(feature_labels))))
coefficient_plot <- ggplot2::ggplot(coefficients, ggplot2::aes(coefficient, featureLabel, color = component)) +
  ggplot2::geom_vline(xintercept = 0, color = '#BBBBBB', linewidth = 0.4) +
  ggplot2::geom_point(size = 2.7) +
  ggplot2::facet_wrap(~model, scales = 'free_y', ncol = 1L) +
  ggplot2::scale_color_manual(values = base::c(Direct = '#17324D', Indirect = '#BD7C27')) +
  ggplot2::labs(title = 'Hits delivered carry largest median weight', subtitle = 'Median of 20 outer-fold coefficients per position; transformed predictors have unit SD', x = 'Coefficient in listed-size units', y = NULL, color = NULL) + research_theme()
ggplot2::ggsave(base::file.path(figure_directory, 'feature_weights.png'), coefficient_plot, width = 8, height = 7, dpi = 180, bg = 'white')

# Display paired center percentiles without pooling reference scales.
center_plot <- ggplot2::ggplot(a$centers |> dplyr::mutate(season = season_label(seasonId), support = dplyr::if_else(supported, 'Within observed ranges', 'Outside range or imputed')), ggplot2::aes(referencePercentile_Wings, referencePercentile_Defensemen, color = support)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = '#BBBBBB', linewidth = 0.4) +
  ggplot2::geom_point(alpha = 0.65, size = 1.4) +
  ggplot2::facet_wrap(~season, ncol = 2L) +
  ggplot2::scale_color_manual(values = base::c('Within observed ranges' = '#17324D', 'Outside range or imputed' = '#BD7C27')) +
  ggplot2::coord_equal(xlim = base::c(0, 100), ylim = base::c(0, 100)) +
  ggplot2::labs(title = 'Centers share rank patterns but change relative standing', subtitle = 'Each point represents one center-season, excluded from both reference populations', x = 'Percentile relative to wings', y = 'Percentile relative to defensemen', color = NULL) + research_theme()
ggplot2::ggsave(base::file.path(figure_directory, 'center_standing.png'), center_plot, width = 8, height = 7, dpi = 180, bg = 'white')

# Plot standardized continuation probabilities and full-pipeline intervals.
probabilities <- a$inference$primary |> dplyr::filter(statistic %in% base::c('probabilityMinusOne', 'probabilityZero', 'probabilityPlusOne')) |> dplyr::mutate(CSAx = dplyr::recode(statistic, probabilityMinusOne = -1, probabilityZero = 0, probabilityPlusOne = 1))
probability_plot <- ggplot2::ggplot(probabilities, ggplot2::aes(CSAx, 100 * estimate)) +
  ggplot2::geom_line(color = '#17324D', linewidth = 0.7) +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = 100 * confLow, ymax = 100 * confHigh), width = 0.12, color = '#17324D') +
  ggplot2::geom_point(size = 2.7, color = '#BD7C27') +
  ggplot2::facet_wrap(~model, nrow = 1L) +
  ggplot2::scale_x_continuous(breaks = base::c(-1, 0, 1)) +
  ggplot2::labs(title = 'Continuation estimates by position', subtitle = 'Average predictions over observed controls; 95% intervals from 499 shared player draws', x = 'CSAx within native reference population', y = 'Probability of 300 next-season minutes (%)') + research_theme()
ggplot2::ggsave(base::file.path(figure_directory, 'continuation.png'), probability_plot, width = 8, height = 4, dpi = 180, bg = 'white')

# Report Tables -----------------------------------------------------------

# Prepare primary inference and model-performance tables.
primary_table <- a$inference$primary |> dplyr::filter(statistic == 'logOdds') |> dplyr::transmute(Position = model, `Continuation odds ratio (95% CI)` = interval(effect, effectLow, effectHigh)) |>
  dplyr::left_join(a$inference$primary |> dplyr::filter(statistic == 'probabilityDifference') |> dplyr::transmute(Position = model, `Difference, +1 versus -1 CSAx (percentage points)` = interval(100 * estimate, 100 * confLow, 100 * confHigh)), by = 'Position')
performance_table <- a$primary$performance |> dplyr::transmute(Season = season_label(seasonId), Reference = model, N = base::as.character(n), RMSE = rmse, `Mean-size RMSE` = baselineRmse, `Predictive R-squared` = predictiveRSquared, `CSAx-size correlation` = residualSizeCorrelation)
center_table <- a$inference$centers |> dplyr::filter(sample == 'All centers', statistic %in% base::c('spearman', 'meanPercentileDifference')) |>
  dplyr::mutate(value = interval(estimate, confLow, confHigh)) |> dplyr::select(seasonId, n, statistic, value) |>
  tidyr::pivot_wider(names_from = statistic, values_from = value) |>
  dplyr::transmute(Season = season_label(seasonId), Centers = base::as.character(n), `Spearman correlation (95% CI)` = spearman, `Mean wing-minus-defenseman percentile (95% CI)` = meanPercentileDifference)
center_supported <- a$inference$centers |> dplyr::filter(sample == 'Within observed ranges', statistic == 'meanPercentileDifference') |>
  dplyr::transmute(Season = season_label(seasonId), Centers = base::as.character(n), `Mean percentile difference (95% CI)` = interval(estimate, confLow, confHigh))
center_examples <- a$centers |> dplyr::filter(seasonId == base::max(xs_behavior_seasons), timeOnIce >= 500 * 60, playerFullName %in% base::c('Alex Turcotte', 'Jason Dickinson', 'Sidney Crosby', 'Aleksander Barkov')) |>
  dplyr::transmute(Player = playerFullName, `Wing percentile` = referencePercentile_Wings, `Defenseman percentile` = referencePercentile_Defensemen, Difference = percentileDifference, Support = dplyr::if_else(supported, 'Within observed ranges', 'Outside defenseman block-rate range'))
applications_table <- a$applications$estimates |> dplyr::filter(outcome %in% base::c('Any next-season appearance', 'Next-season games dressed', 'Next-season TOI per game among returners', 'External-contract duration', 'Cap-adjusted contract AAV', 'Playoff dressing share', 'Playoff minutes per team game')) |>
  dplyr::mutate(multiplier = dplyr::if_else(outcome == 'Playoff dressing share', 100, 1)) |>
  dplyr::transmute(Position = model, Outcome = outcome, N = base::as.character(sampleSize), `Effect per CSAx SD (95% CI)` = interval(multiplier * effect, multiplier * effectLow, multiplier * effectHigh), Units = dplyr::case_when(scale == 'odds ratio' ~ 'Odds ratio', scale == 'percent' ~ 'Percent', outcome == 'External-contract duration' ~ 'Years', outcome == 'Next-season games dressed' ~ 'Games', outcome == 'Playoff dressing share' ~ 'Percentage points', TRUE ~ 'Minutes'))
career_table <- a$applications$estimates |> dplyr::filter(base::startsWith(outcome, 'Continuation:')) |> dplyr::transmute(Position = model, `Prior NHL seasons` = base::sub('Continuation: ', '', outcome), `Odds ratio (95% CI)` = interval(effect, effectLow, effectHigh))
sensitivity_table <- a$applications$sensitivityEstimates |> dplyr::transmute(Position = model, Specification = specification, `Continuation odds ratio (conditional 95% CI)` = interval(effect, effectLow, effectHigh))
team_table <- a$applications$teams$summary |> dplyr::transmute(Position = model, `Team-seasons` = base::as.character(teamSeasons), `GAx correlation` = correlationGAx, `Playoff quality-change correlation` = correlationQualityChange, `Median coverage (%)` = 100 * medianCoverage, `Minimum coverage (%)` = 100 * minimumCoverage)
coefficient_table <- a$primary$coefficients |>
  dplyr::group_by(model, component, feature) |>
  dplyr::summarise(coefficient = stats::median(coefficient), .groups = 'drop') |>
  tidyr::pivot_wider(names_from = model, values_from = coefficient) |>
  dplyr::arrange(base::match(feature, base::names(feature_labels))) |>
  dplyr::transmute(Component = component, Feature = feature_labels[feature], Forwards, Wings, Defensemen)

# Research Summary --------------------------------------------------------

# Extract concise numerical summaries for narrative.
forward_primary <- a$inference$primary |> dplyr::filter(model == 'Forwards', statistic == 'logOdds')
defense_primary <- a$inference$primary |> dplyr::filter(model == 'Defensemen', statistic == 'logOdds')
forward_probability <- a$inference$primary |> dplyr::filter(model == 'Forwards', statistic %in% base::c('probabilityMinusOne', 'probabilityPlusOne')) |> dplyr::arrange(statistic)
latest_takeaways <- a$inputs$provenance$locationQuality |> dplyr::filter(seasonId == base::max(xs_behavior_seasons), eventTypeDescKey == 'takeaway')
previous_takeaways <- a$inputs$provenance$locationQuality |> dplyr::filter(seasonId == 20232024L, eventTypeDescKey == 'takeaway')
forward_stability <- a$applications$stability |> dplyr::filter(model == 'Forwards')
defense_stability <- a$applications$stability |> dplyr::filter(model == 'Defensemen')
components <- a$applications$centerComponents |> dplyr::filter(specification == 'Direct only', sample == 'All centers')
scouting_trend <- a$applications$scouting$estimates |> dplyr::filter(indicator == 'overallPhysicality')
scouting_active <- a$applications$scouting$estimates |> dplyr::filter(indicator == 'activePhysicalEngagement')
scouting_interior <- a$applications$scouting$estimates |> dplyr::filter(indicator == 'interiorPlay')
scouting_explicit <- a$applications$scouting$estimates |> dplyr::filter(indicator == 'playsBiggerExplicit')
center_contributions <- a$primary$predictions |> dplyr::filter(isCenterComparison, model == 'Defensemen') |> dplyr::group_by(seasonId) |> dplyr::summarise(direct = base::mean(directContribution), indirect = base::mean(indirectContribution), frame = base::mean(frameAdjustment), .groups = 'drop')
forward_raw <- a$applications$roster$conditioning |> dplyr::filter(model == 'Forwards', outcome == 'CSAx only')
forward_current_prior <- application_result('Forwards', 'Current role among prior participants')
forward_prior_prior <- application_result('Forwards', 'Prior role among prior participants')
career_wald <- a$applications$roster$careerWald
latest_ranking <- rankings |> dplyr::filter(seasonId == base::max(xs_behavior_seasons), rank <= 5L) |> dplyr::transmute(Position = model, Rank = base::as.character(rank), Player = player, CSAx, `Direct contribution` = directContribution, `Indirect contribution` = indirectContribution, `Frame adjustment` = frameAdjustment)

# Write definition, methods, evidence, and subsequent research questions.
report <- glue::glue('# Playing big across positions: CSAx_P research summary

A player can resemble a larger skater in several ways: by delivering contact, absorbing it, or repeatedly entering areas where possession is contested. We ask how much of that pattern the public record captures, how its meaning changes across positions, and whether it accompanies a sustained NHL role.

> **<<a$definition>>**

We distinguish direct engagement from indirect evidence of contested-space involvement. CSAx expresses behavior-predicted size above the prediction normally associated with a player\'s listed frame. Feature weights come from predicting listed size, so the score describes a learned behavioral pattern. It does not measure force, toughness, injury risk, or overall player value.

The extension uses separate forward and defenseman models. We also score centers against wing and defenseman reference populations that contain no centers. This comparison reveals how the same players look under different positional expectations.

## What the results show

The forward continuation association remains positive after accounting for current role: the odds ratio per CSAx standard deviation is **<<interval(forward_primary$effect, forward_primary$effectLow, forward_primary$effectHigh)>>**. The corresponding defenseman estimate is **<<interval(defense_primary$effect, defense_primary$effectLow, defense_primary$effectHigh)>>**. These are 95% percentile intervals from 499 full-pipeline player bootstrap samples. An odds ratio of 1 represents no conditional association; an odds ratio of 1.25 represents 25% higher odds, not a 25 percentage point increase in probability.

Centers show substantial rank agreement across the two reference models, while their reference-population percentiles can differ considerably. Much of that difference already appears when both models use only the shared direct variables. Meanwhile, the defenseman indirect proxies contribute little reliable size-prediction signal by themselves. These findings support further positional investigation while leaving defensive proxy validity open.

## Data and physicality measures

We study 2021–22 through 2024–25 behavior, followed by 2022–23 through 2025–26 outcomes. The eligible panel contains **1,763 forward-seasons from 613 players** and **968 defenseman-seasons from 343 players**, each with at least 300 regular-season minutes and available height, weight, and birth date. Centers contribute 855 seasons; wings contribute 908. Published player rankings require 500 minutes. Position labels and listed measurements come from the supplied player registry; these labels describe roster categories and may not capture every in-game assignment or historical change in body size.

| Component | Population | Measures and denominators |
| --- | --- | --- |
| Direct engagement | Both positions | Hits delivered, hits received, opponent shots blocked, fights, contact penalties taken, and contact penalties drawn, each per 60 minutes |
| Indirect contested-space behavior | Forwards and wing reference | Net-front unblocked attempts / located unblocked attempts; tips or deflections / typed shots on net; median distance of located unblocked attempts; backhands / typed shots on net |
| Exploratory defensive engagement | Defensemen and defensive reference | Defensive-zone takeaways per 60 minutes; perimeter defensive-zone takeaways / all defensive-zone takeaways |

An unblocked attempt is a goal, shot on goal, or missed shot. Shots on net comprise goals and shots on goal with a recorded shot type. We define the net-front region as normalized x from 82 to 89 feet and |y| at most 8 feet, with the attacking goal at x = 89. Distance is measured from that goal. Undefined shares remain missing until training-sample median imputation. Event numerators and denominators remain in the scientific inputs.

The contact-penalty whitelist includes boarding, charging, checking from behind, clipping, elbowing, illegal checks to the head, kneeing, roughing, slew-footing, cross-checking, high-sticking, holding, holding the stick, hooking, and tripping, including recorded helmet-removal and double-minor variants. Each recorded infraction counts once regardless of penalty minutes; fighting has its own variable. Generic interference, slashing, attempted-contact categories, and administrative infractions remain excluded. NHL rules permit some such penalties without confirmed contact, including slashing. Equipment contact and puck blocking still differ from a body check, so the direct component groups several forms of physical engagement. [NHL rulebook, 2023–24](https://media.nhl.com/site/asset/public/ext/2023-24/2023-24Rulebook.pdf), [NHL rulebook, 2025–26](https://media.nhl.com/site/asset/public/ext/2025-26/2025-26Rules.pdf).

For defensive proxies, we orient coordinates using the event owner\'s attacking direction and the recorded home defending end. The defensive zone is x < −25 feet. A defensive-zone takeaway occurs near the perimeter when |y| ≥ 32.5 feet or x ≤ −89 feet. We check actor-team assignments against game rosters. Teammate-blocked shots are excluded from the block count. Coordinate-derived zones take precedence over zone labels when they disagree.

In 2024–25, **<<latest_takeaways$zoneDisagreement>> of <<latest_takeaways$events>> takeaways (<<fixed(100 * latest_takeaways$zoneDisagreement / latest_takeaways$events)>>%)** have a zone label that differs from this coordinate definition. Some disagreements occur near zone boundaries; others place events at opposite ends. Total recorded takeaways fall from <<previous_takeaways$events>> to <<latest_takeaways$events>> between the final two seasons, a **<<fixed(100 * (1 - latest_takeaways$events / previous_takeaways$events))>>% decline**. We cannot attribute that change uniquely to behavior or recording practice.

Eligible defensemen have median defensive-zone takeaway counts of 12, 13, 11, and 8 across the four seasons; median perimeter counts are 6, 7, 6, and 5. Four defenseman-seasons have no defensive-zone takeaway, leaving their perimeter share undefined. A handful of events can therefore move the share markedly. Takeaways may reflect anticipation or stick skill without substantial contact. More detailed defensive-zone recovery measures demonstrate what richer observations can describe, but do not validate these public-event proxies. [Sportlogiq defensive recovery examples](https://www.sportlogiq.com/2020/08/05/elementor-2567/).

## Estimation and interpretation

Within each season and native reference population, we standardize height and weight, average their standardized values with equal weights, and standardize that combination to obtain listed size S. The fixed native population supplies this descriptive size reference. Centers receive wing-based S for the wing comparison and defenseman-based S for the defensive comparison; no center-specific size or score standardization is applied.

We fit ridge regression through tidymodels with one five-fold outer split and five inner folds. The inner search evaluates 20 penalties from 0.0001 to 100 by mean squared error. Training samples supply median imputation, zero-variance removal, Yeo–Johnson transformations, and predictor standardization. Each outer training sample also supplies a linear calibration of inner held-out predicted size on S. Thus neither feature preprocessing nor frame calibration uses an outer assessment player\'s behavior.

For each player, we obtain one outer assessment prediction xS and subtract the frame-specific expected prediction m(S). We then express this residual in units of the native reference population\'s held-out residual standard deviation:

$$
\\mathrm{CSAx}_i = \\frac{xS_i-m_{-k}(S_i)-\\overline r_{\\mathrm{ref}}}{s_{r,\\mathrm{ref}}}.
$$

Here k identifies the player\'s assessment fold. Calibration addresses regression shrinkage: simply subtracting listed size from a weak size prediction would mechanically favor smaller players. We retain training-based calibration and inspect any remaining size gradient instead of assuming it disappears.

The main forward application trains on centers and wings together. The center comparison trains a separate forward specification on wings only and a defensive specification on defensemen only. Centers enter neither reference population. Each center is assigned to the same numbered assessment fold in both models and receives one prediction from each corresponding fit. Reference players also receive one excluded-sample prediction. This matches prediction procedures without averaging several predictions only for centers.

The score decomposes exactly into direct contribution, indirect contribution, and frame adjustment. For transformed and standardized features z, these terms are the direct weighted sum divided by residual SD, the indirect weighted sum divided by residual SD, and (ridge intercept − m(S) − mean native residual) divided by residual SD. The adjustment is part of the score. Coefficients describe conditional size prediction, not causal effects: a negative weight for hits received or penalties drawn means that, conditional on the other inputs, the action is more characteristic of smaller listed players in that reference sample. It does not mean less physical contact occurs.

## Model performance and components

<<markdown_table(performance_table)>>

Predictive R-squared compares held-out squared error with the outer-training mean-size baseline; it is distinct from squared prediction–outcome correlation. The combined positional models improve on that baseline in each season. Their CSAx–size correlations stay near zero. Adjacent-season CSAx correlations range from **<<fixed(base::min(forward_stability$correlation))>> to <<fixed(base::max(forward_stability$correlation))>>** for forwards and **<<fixed(base::min(defense_stability$correlation))>> to <<fixed(base::max(defense_stability$correlation))>>** for defensemen, among players eligible in consecutive seasons.

![Median standardized feature weights](figures/feature_weights.png)

<<markdown_table(coefficient_table)>>

Hits delivered have the largest median standardized coefficient in both main models. Blocks receive more weight among defensemen. The table includes the wing reference used to score centers; a dash marks a feature outside that specification. Median coefficients summarize 20 season-by-fold fits per reference population. They are descriptive summaries, not coefficient confidence intervals or a single universal scoring formula.

Direct-only and indirect-only reconstructions each relearn their own ridge weights and calibration. They ask how well each block can support a score on its own; the additive contributions above describe the blocks inside the combined model. The defenseman indirect-only model offers essentially no improvement over mean-size prediction. In 2022–23 its residual SD is about 0.01, and its standardized residual has a strong remaining size correlation, about 0.88. We treat that reconstruction as a failed standalone measure. Its downstream associations cannot establish defensive physicality validity.

## Centers under two positional expectations

Reference percentiles use the native held-out score distribution, with midranks for ties. A positive difference means higher relative standing among wings than among defensemen. A difference of 20 percentile points is a change in reference standing; it is not 20 units of physicality.

<<markdown_table(center_table)>>

![Center standing under wing and defenseman models](figures/center_standing.png)

For each center we flag any height, weight, or modeled feature beyond its assigned outer training sample\'s observed range. The supported subset also requires no imputed feature under either model. These marginal range checks cannot guarantee support for every multivariate combination. The supported subset yields:

<<markdown_table(center_supported)>>

The shared direct variables already produce center rank correlations from **<<fixed(base::min(components$spearman))>> to <<fixed(base::max(components$spearman))>>**. Their mean percentile differences are <<base::paste(fixed(components$meanPercentileDifference), collapse = ", ")>> points in season order. Consequently, positional weights and reference distributions explain much of the divergence before we add distinct indirect measures. In the combined defensive reference, centers\' average direct contribution changes from <<fixed(center_contributions$direct[center_contributions$seasonId == 20232024L])>> in 2023–24 to <<fixed(center_contributions$direct[center_contributions$seasonId == 20242025L])>> in 2024–25; their indirect contribution changes from <<fixed(center_contributions$indirect[center_contributions$seasonId == 20232024L])>> to <<fixed(center_contributions$indirect[center_contributions$seasonId == 20242025L])>>. Each season has its own reference scale, but this decomposition locates most of the numerical shift in the direct block. The smaller final-season percentile gap also coincides with the decline in recorded takeaways. That timing motivates closer review without establishing why the gap changes.

The following 2024–25 examples all meet the 500-minute ranking threshold. They illustrate observed differences and range support, without individual rank confidence intervals:

<<markdown_table(center_examples)>>

## NHL continuation and other applications

Continuation means at least 300 minutes in the following regular season. We observe 1,486 continuations among forward-seasons and 813 among defenseman-seasons. Logistic models control for listed size, age and age squared, current games dressed and ice time per game, five-on-five points per 60, relative shot-attempt share, and season. Supporting outcomes preserve the same core controls.

<<markdown_table(primary_table)>>

![Continuation probabilities with full-pipeline intervals](figures/continuation.png)

Average predictions hold each observation\'s controls at its observed values and set CSAx to −1 or +1. Their difference translates the odds ratio into a probability contrast for this sample. These estimates describe associations among comparable observed roles; they do not estimate what would happen if a player changed behavior.

Conditioning matters. The unadjusted forward continuation odds ratio is <<fixed(forward_raw$effect)>>, while the fully adjusted estimate is <<fixed(forward_primary$effect)>>. Physical profiles and existing roles overlap. Among forwards with a prior NHL appearance, the current-role estimate is <<interval(forward_current_prior$effect, forward_current_prior$effectLow, forward_current_prior$effectHigh)>> and the prior-role estimate is <<interval(forward_prior_prior$effect, forward_prior_prior$effectLow, forward_prior_prior$effectHigh)>>. Prior-role comparisons condition on earlier games and ice time while retaining current production controls. Conditioning can also select on consequences of earlier performance, health, and coaching decisions.

Career stage counts completed prior NHL seasons, including seasons below the current eligibility threshold. Pooled interaction models yield:

<<markdown_table(career_table)>>

The joint career-stage interaction p-values are <<p_value(career_wald$pValue[career_wald$model == "Forwards"])>> for forwards and <<p_value(career_wald$pValue[career_wald$model == "Defensemen"])>> for defensemen. These conditional analyses suggest a stronger forward association later in a career, without establishing a developmental trajectory or causal survival mechanism. Listed-size and ice-time interaction estimates appear in the application CSV.

<<markdown_table(applications_table)>>

External contracts include veteran signings at age 27 or older with another team, usable prior contract terms, and an eligible prior-season score. We exclude known announcements at or before the prior regular-season end. Models include prior AAV and duration, signing age, prior playing role and production, size, and signing season. We model log(AAV / salary cap) and report the association as a percentage difference. There are 183 forward contracts and 105 defenseman contracts. Unmatched announcement dates remain a timing limitation.

Playoff dressing share divides games dressed by the final regular-season team\'s playoff games. Playoff minutes also use team games, assigning zero to eligible players who do not dress. Next-season minutes per game are conditional on returning, whereas games dressed include zero for non-returners. These distinct denominators answer different questions and help explain why continued participation need not coincide with higher minutes among those who return.

Supporting intervals use player-clustered HC1 covariance and condition on estimated CSAx. They do not carry the full score-estimation uncertainty. The number of exploratory outcomes also warrants restraint when interpreting isolated intervals that exclude zero.

## Team patterns and scouting evidence

We weight eligible players\' CSAx by games dressed for each team, using separate forward and defenseman aggregates. Centers appear once in the forward group. Team goals above expected are observed goals minus supplied expected goals, standardized within season for descriptive correlations. The playoff comparison relates 2024–25 team CSAx to the absolute change in five-on-five xG per unblocked attempt from regular season to playoffs.

<<markdown_table(team_table)>>

Each position contributes 128 team-seasons to the regular-season comparison and 16 teams to the latest playoff comparison. Eligible-player coverage is reported against all games dressed in that position group. These are descriptive team patterns, with small playoff samples and no claim that increasing a team\'s CSAx improves finishing or preserves shot quality.

We retain the 40 frozen forward scouting ratings and recompute associations with player-average forward CSAx. The ordinal physicality rating has Spearman correlation **<<fixed(a$applications$scouting$spearman)>>** with mean CSAx, and a one-category increase corresponds to **<<interval(scouting_trend$estimate, scouting_trend$confLow, scouting_trend$confHigh)>>** CSAx units. Active-engagement language has association <<interval(scouting_active$estimate, scouting_active$confLow, scouting_active$confHigh)>>; interior-play language has association <<interval(scouting_interior$estimate, scouting_interior$confLow, scouting_interior$confHigh)>>. Explicit plays-bigger language corresponds to <<interval(scouting_explicit$estimate, scouting_explicit$confLow, scouting_explicit$confHigh)>>, although only two reports use that language. The three binary-cue Holm-adjusted p-values are <<p_value(scouting_active$holmPValue)>>, <<p_value(scouting_interior$holmPValue)>>, and <<p_value(scouting_explicit$holmPValue)>>, respectively. All ratings come from one rater and a selected draft-report cohort. Draft-era prose and later NHL behavior are separated in time. This modest external check applies to forwards; defenseman scouting validation remains deferred.

## Focused sensitivity analyses

<<markdown_table(sensitivity_table)>>

These analyses comprise component reconstructions, one forward rebound-share addition, 500-minute eligibility, away-game recording, and five-on-five opportunity. Rebound share uses same-team follow-up unblocked attempts within the package\'s three-second event-sequence rule, divided by unblocked attempts. It represents an inferred shooting sequence, not an observed recovery under pressure. Away and five-on-five reconstructions match event numerators to shift-derived exposure; total regular-season minutes still determine eligibility except in the 500-minute restriction. Shift and official time totals differ slightly: two player-seasons have shift-derived five-on-five exposure exceeding official total time by 113 and 219 seconds. Those source differences limit the precision of the opportunity sensitivity. The higher-minute specification relearns reference scales and scores on its smaller cohort.

We use the same five-fold design and tuning grid for these reconstructions. Their application intervals remain conditional on scores, and the defenseman indirect-only failure described above limits interpretation of that row. We do not use these alternatives to select the primary specification or run separate bootstrap campaigns for them.

## Uncertainty and limits

One shared set of 499 player bootstrap draws underlies the primary continuation and center-agreement intervals. Every draw samples complete player histories with replacement across the eligible panel and refits native size references, nested feature preprocessing and tuning, training-based calibration, residual scales, scores, and continuation models. Duplicate copies of an original player remain together in outer and inner folds. The same draw supplies both positional applications and both center reference scores. Center summary intervals preserve pairing; the range-supported subset is recalculated within each draw.

The bootstrap conditions on the observed seasons and source records. It does not quantify uncertainty from event misclassification, static listed measurements, positional labeling, an unobserved season, or the definition of physical engagement itself. Rink recording and role exposure remain possible influences even after the focused opportunity checks. Marginal range flags identify obvious extrapolation, but observational associations and good size prediction cannot establish that every component measures the intended construct.

## Research roadmap toward Sloan

1. **Resolve defensive construct validity first.** Review a small, prespecified set of defensive-zone takeaway clips spanning high and low perimeter shares, season, and rink. Record whether pressure, body contact, or puck protection is visible, using coding independent of CSAx and outcomes. This is a proposed next study, not completed defenseman scouting validation. If these events mainly reflect stick skill or recording practice, seek observations of contested recoveries and possession retention before expanding claims about defensive physicality.
2. **Explain the positional bridge.** Follow matched center examples through the direct contributions, indirect contributions, and frame adjustment. Prioritize the strong direct-only differences and the smaller 2024–25 mean gap. Document how positional expectations and sparse events combine, while keeping each reference scale intact.
3. **Build the central empirical story around role and continuation.** The forward application extends naturally from the original study; the defensive application tests its reach. Keep contract, playoff, and team results as supporting evidence. Use the probability contrast to explain practical scale and retain the uncertainty around defensive estimates.
4. **Prepare the submission from completed results.** Sloan lists October 1, 2026 at 11:59 p.m. Eastern for abstracts and December 4, 2026 at 11:59 p.m. Eastern for invited full papers. Abstracts must contain fewer than 500 words including title and body, and report actual results. Current guidance also requires an open-source repository link. The repository remains private; public release is a subsequent visibility decision, with the included data and third-party terms reviewed before release. [Sloan research competition guidance](https://www.sloansportsconference.com/research-paper-competition).

## Reproducible results

The repository contains one compact analysis object, `data/analysis_data.rds`, including frozen inputs, source hashes, model summaries, application estimates, and all 499 bootstrap summaries. The numbered R workflow restores the input snapshot, fits models, analyzes applications, and regenerates this report. Locked scouting codes remain separate from derived CSAx summaries. Private scouting prose and local caches stay outside Git.

The accompanying files are [player rankings](player_rankings.csv), [paired center comparisons](center_comparisons.csv), [center agreement intervals](center_agreement.csv), [team summaries](team_summaries.csv), and [application estimates](application_estimates.csv). The five highest 2024–25 scores in each native position group illustrate the additive decomposition:

<<markdown_table(latest_ranking)>>

Small discrepancies in sums can arise from rounding displayed contributions. Scores and rankings retain their own positional reference, and high values describe size-associated behavior beyond frame expectation.
', .open = '<<', .close = '>>')
readr::write_file(report, base::file.path(report_directory, 'research_summary.md'))
base::message('Wrote research summary, five data products, and three figures.')

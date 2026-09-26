# Playing tougher for one’s size

Physical play takes several forms, from delivering contact to competing for possession in crowded areas. We study those behaviors relative to a player’s listed frame, using separate forward and defenseman references.

> **Playing tougher for one’s size means making one’s presence felt beyond what body size would suggest, through both direct physical contact and indirect signs of physicality in battles for the puck and space. We quantify this with CSAx by predicting listed height-and-weight size from shared direct and position-specific indirect measures, calibrating that prediction against the player’s listed frame, and standardizing the resulting residual within each season and reference population.**

Higher CSAx describes playing tougher for one’s size; playing softer for one’s size describes the corresponding lower end of this measured continuum. The score does not establish courage, overall ability, or successful play under pressure. Its weights identify behaviors associated with listed size, so an error count can receive a positive coefficient and a useful skill can receive a negative one.

## Study population and observations

We combine NHL events and shift-derived five-on-five exposure with Corey Sznajder’s All Three Zones (A3Z) player-game records. Behavior seasons span 2021–22 through 2024–25, with next-season continuation observed through 2025–26. Eligibility requires 300 full-season NHL minutes and 150 matched tracked minutes. Published rankings require 500 full-season minutes.

The analysis contains **1485 forward-seasons** and **829 defenseman-seasons**. Centers remain in the main forward model.

| Season | Position | Full-season eligible | Included | Included (%) | Median tracked games | Median tracked minutes |
| --- | --- | --- | --- | --- | --- | --- |
| 2021–22 | Defensemen | 241 | 215 | 89.21 | 25 | 417.50 |
| 2021–22 | Forwards | 451 | 399 | 88.47 | 27 | 317.38 |
| 2022–23 | Defensemen | 233 | 203 | 87.12 | 23 | 364.97 |
| 2022–23 | Forwards | 446 | 374 | 83.86 | 23 | 284.17 |
| 2023–24 | Defensemen | 250 | 204 | 81.60 | 21 | 334.26 |
| 2023–24 | Forwards | 438 | 359 | 81.96 | 23 | 267.77 |
| 2024–25 | Defensemen | 244 | 207 | 84.84 | 19 | 310.78 |
| 2024–25 | Forwards | 428 | 353 | 82.48 | 21 | 266.25 |

| Season | Matched games | Teams | Tracked games per team | Median exposure difference (seconds) |
| --- | --- | --- | --- | --- |
| 2021–22 | 491 | 32 | 20 to 41 | 12.00 |
| 2022–23 | 414 | 32 | 20 to 32 | 11.00 |
| 2023–24 | 390 | 32 | 17 to 38 | 11.00 |
| 2024–25 | 383 | 32 | 16 to 41 | 10.00 |

Tracked games cover all 32 teams in each season, with uneven selection and exposure. Listed frame and playing time also differ between included and excluded observations:

| Position | Sample | Player-seasons | Mean height (in) | Mean weight (lb) | Median full-season minutes |
| --- | --- | --- | --- | --- | --- |
| Defensemen | Below tracking eligibility | 139 | 73.83 | 202.24 | 489.50 |
| Defensemen | Included | 829 | 73.96 | 205.52 | 1384.10 |
| Forwards | Below tracking eligibility | 278 | 73.01 | 199.90 | 460.43 |
| Forwards | Included | 1485 | 72.98 | 199.51 | 1156.78 |

Game identities use NHL schedules and rosters. Player matching uses names, teams, and sweater numbers, including distinct players with shared names. Identical duplicate player-game records collapse; conflicting duplicates and unresolved or incompatible records remain excluded. Counts, original labels, exposure differences, and exclusions remain in the analysis object.

| Disposition | Player-game rows |
| --- | --- |
| Game exposure disagreement | 180 |
| Invalid event counts | 6 |
| Player exposure disagreement | 40 |
| Retained | 60331 |
| Unresolved game | 540 |
| Unresolved player | 1 |

The [A3Z data dictionary](a3z_data_dictionary.md) inventories all 95 source fields, their coverage, definitions, and unresolved labels. These records are player-game aggregates without linked possession sequences or event timestamps.

## Direct and indirect physicality

The six direct measures are shared across positions. Forwards use six indirect measures; defensemen use three. Count rates use matched NHL five-on-five minutes, and undefined shares remain missing before training-sample imputation.

| Component | Population | Measure | Source and denominator | Rationale and qualification |
| --- | --- | --- | --- | --- |
| Direct | Both | Hits delivered | NHL hits credited to hitter, per 60 | Initiating recorded contact; opportunities depend on possession and deployment. |
| Direct | Both | Hits received | NHL hits credited to recipient, per 60 | Exposure to contact; receiving a hit does not establish active engagement. |
| Direct | Both | Opponent shots blocked | NHL opponent attempts credited to blocker, per 60 | Intervention in a shot path; recorded blocks do not uniformly imply body contact. |
| Direct | Both | Fights | Recorded fighting infractions, per 60 | Confrontation with an opponent; counts are sparse. |
| Direct | Both | Contact penalties taken | Whitelisted infractions credited to offender, per 60 | Contact-related behavior; disciplinary acts are distinct from effective play. |
| Direct | Both | Contact penalties drawn | Whitelisted infractions credited to recipient, per 60 | Opponents’ contact-related infractions; puck possession and skill affect exposure. |
| Indirect | Forwards | Net-front attempt share | Unblocked attempts in 82 ≤ x ≤ 89 and absolute y ≤ 8 feet / located unblocked attempts | Shooting involvement near interior space; location alone does not confirm pressure. |
| Indirect | Forwards | Tip/deflection share | Tips and deflections / typed shots on goal, including goals | Redirection opportunities often involve traffic; tactical role affects opportunities. |
| Indirect | Forwards | Median shot distance | Median distance from net for located unblocked attempts, in feet | Proximity of shooting involvement to net; this is a broad positional proxy. |
| Indirect | Forwards | Backhand share | Backhands / typed shots on goal, including goals | Possible constrained shooting situations; open-ice backhands also contribute. |
| Indirect | Forwards | Dump-in recoveries | A3Z Recoveries, per 60 | Recovering possession and making a subsequent play during forechecking sequences. |
| Indirect | Forwards | Forecheck pressures | A3Z Forecheck Pressures, per 60 | Forcing an exiting opponent to act; a hit is not required. |
| Indirect | Defensemen | Clean defensive-zone retrievals | A3Z DZ Retrievals, per 60 | Recovering possession and making a subsequent play; workload and team systems affect frequency. |
| Indirect | Defensemen | Botched retrievals | A3Z Botched Retrievals, per 60 | Retrieval-related breakdowns reflect execution and workload; attribution can involve a receiver. |
| Indirect | Defensemen | Entry denial share | A3Z Denials / Targets | Preventing zone entry; gap control, skating, and tactics also contribute. |

Shot coordinates are normalized to attacking direction. The net-front region extends seven feet in front of the goal line and eight feet to either side of the center line. Located unblocked attempts include goals, saved shots, and misses; shot-type shares use only typed goals and shots on goal.

The contact-penalty whitelist covers boarding, charging, checking from behind, clipping, elbowing, illegal checks to the head, kneeing, roughing, slew-footing, cross-checking, high-sticking, holding, holding the stick, hooking, and tripping, including the corresponding helmet-removal and double-minor variants. We count recorded infractions and keep fighting separate. Generic interference, slashing, attempted contact, and administrative infractions fall outside this definition. [NHL rules](https://media.nhl.com/site/asset/public/ext/2023-24/2023-24Rulebook.pdf).

A3Z retrieval and forechecking measures provide information about recovering possession and responding to pressure. Their counts also reflect deployment, team systems, and opportunities. Clean and botched retrievals do not supply an established common attempt denominator, and a botched event can be attributed to a receiver. Entry denial can result from skating, anticipation, and stick positioning. We therefore treat defensive indirect physicality as a construct requiring external evidence. [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html), [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve).

## Estimation and predictive performance

We fit one selected specification for each reference population and season. Listed size combines standardized height and weight within the native reference. Five outer folds yield one excluded-sample prediction per player-season; five inner folds select ridge penalties from the fixed 20-value grid. Preprocessing, imputation, predictor transformations, and linear frame calibration use training observations. Calibration uses inner held-out predictions within the outer training sample.

Native excluded-sample residuals provide seasonal score means, standard deviations, and percentile references. Feature weights and additive contributions come from the same fitted models; component-only and alternative-specification fits are outside the active workflow.

| Reference | Player-seasons | RMSE | Predictive R² (%) |
| --- | --- | --- | --- |
| Defensemen | 829 | 0.95 | 9.68 |
| Forwards | 1485 | 0.96 | 8.69 |

Predictive R² compares held-out squared error with an outer-training mean-size prediction. A value below zero means the model performs worse than that baseline. Across seasons, forward and defenseman models explain **8.69%** and **9.68%** of held-out variation by this measure. These are checks on the expected-size model, not independent proof of toughness.

| Season | Reference | Predictive R² (%) | CSAx–size correlation |
| --- | --- | --- | --- |
| 2021–22 | Forwards | 12.08 | 0.02 |
| 2021–22 | Defensemen | 15.84 | 0.01 |
| 2022–23 | Forwards | 8.79 | 0.00 |
| 2022–23 | Defensemen | 8.94 | -0.02 |
| 2023–24 | Forwards | 6.57 | -0.01 |
| 2023–24 | Defensemen | 14.17 | 0.06 |
| 2024–25 | Forwards | 6.89 | -0.01 |
| 2024–25 | Defensemen | -0.41 | -0.11 |

The 2024–25 defenseman model has predictive R² of **-0.41%**, with CSAx–size correlation **-0.11**. Its weak size prediction and remaining size gradient limit confidence in that season’s defensive ordering.

| Reference | Players per annual comparison | Annual Spearman range |
| --- | --- | --- |
| Defensemen | 168 to 175 | 0.47 to 0.56 |
| Forwards | 294 to 310 | 0.55 to 0.62 |

Annual correlations describe rank persistence among players eligible in consecutive seasons. Persistence can reflect stable role and opportunity as well as behavior; it does not estimate the precision of every individual score.

## Learned weights and player profiles

| Component | Measure | Defensemen | Forwards |
| --- | --- | --- | --- |
| Direct | Hits delivered | 0.18 | 0.18 |
| Direct | Hits received | -0.06 | -0.05 |
| Direct | Opponent shots blocked | 0.02 | 0.04 |
| Direct | Fights | 0.05 | 0.05 |
| Direct | Contact penalties taken | 0.06 | 0.07 |
| Direct | Contact penalties drawn | -0.07 | -0.03 |
| Indirect | Net-front attempt share | — | 0.02 |
| Indirect | Tip/deflection share | — | 0.00 |
| Indirect | Median shot distance | — | -0.02 |
| Indirect | Backhand share | — | 0.01 |
| Indirect | Dump-in recoveries | — | 0.08 |
| Indirect | Forecheck pressures | — | -0.02 |
| Indirect | Clean defensive-zone retrievals | 0.09 | — |
| Indirect | Botched retrievals | 0.06 | — |
| Indirect | Entry denial share | 0.08 | — |

Coefficients are median fitted weights across the 20 outer fits for each reference. Predictors are transformed and scaled to unit training-sample standard deviation. The weights describe conditional size prediction; a positive botched-retrieval coefficient does not imply that unsuccessful execution is desirable.

![Physicality features and listed-size prediction](figures/feature_weights.png)

Each score equals its direct contribution, indirect contribution, and frame adjustment. The adjustment includes the intercept, expected prediction for listed size, and reference centering. These terms remain visible in the 2024–25 examples below, which show the two highest and two lowest eligible scores in each main positional ranking.

| Position | Player | Tracked games | CSAx | Percentile | Direct | Indirect | Frame adjustment | Season caution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Defensemen | Connor Clifton | 17 | 2.95 | 99.76 | 1.60 | 1.14 | 0.22 | No improvement over mean-size prediction |
| Defensemen | Radko Gudas | 21 | 2.93 | 99.28 | 2.27 | 0.57 | 0.09 | No improvement over mean-size prediction |
| Defensemen | Jaccob Slavin | 27 | -2.41 | 0.72 | -0.70 | -1.59 | -0.13 | No improvement over mean-size prediction |
| Defensemen | Urho Vaakanainen | 12 | -5.01 | 0.24 | -2.46 | -2.63 | 0.08 | No improvement over mean-size prediction |
| Forwards | Sam Carrick | 19 | 4.69 | 99.86 | 2.85 | 1.77 | 0.08 |  |
| Forwards | Mathieu Olivier | 16 | 3.88 | 99.58 | 3.46 | 0.81 | -0.38 |  |
| Forwards | Filip Chytil | 17 | -2.52 | 0.42 | -2.05 | -0.28 | -0.19 |  |
| Forwards | Nazem Kadri | 20 | -3.12 | 0.14 | -2.08 | -1.34 | 0.30 |  |

The defensive examples carry the seasonal prediction caution. Percentiles describe standing within a positional reference; they do not provide a common forward–defenseman physicality scale.

## Positional measurement diagnostics

| Scored group | Reference | Scored | Complete inputs | Within ranges and complete | Every share ≥20 | Both checks |
| --- | --- | --- | --- | --- | --- | --- |
| Forwards | Forwards | 1485 | 1485 | 1403 | 1248 | 1199 |
| Defensemen | Defensemen | 829 | 829 | 749 | 829 | 749 |

The forward population includes centers and wings. Range and denominator columns describe warnings within the included sample. Twenty share opportunities is a caution threshold and does not establish reliability.

| Position | Median fights | Median targeted entries | Median clean retrievals | Median botched retrievals | Median dump-in recoveries |
| --- | --- | --- | --- | --- | --- |
| Defensemen | 0.00 | 137.00 | 113.00 | 20.00 | 0.00 |
| Forwards | 0.00 | 9.00 | 39.00 | 3.00 | 13.00 |

The historical cross-position exercise scores all 724 eligible center-seasons against wing and defenseman references. Centers have a median of **10 targeted entries**, compared with **137 for defensemen**. Among those center-seasons, **638 of 724** have entry-denial shares outside their defensive training range, and only **7** have complete inputs within both references’ ranges. These opportunity differences make the comparison difficult to interpret as physical style. We therefore use the main forward and defenseman models for the paper. Every eligible center remains in the forward model; the diagnostic counts do not represent exclusions from that model.

## Independent scouting descriptions

The scouting collection comprises 40 frozen forward ratings and 43 additional ratings covering 20 forwards and 23 defensemen. All use the same active-engagement coding rules and are locked before linkage to CSAx. We evaluate 82 eligible players: 59 forwards and 23 defensemen. The original collection contributes 39 players; Matthew Poitras has 148.88 matched minutes in his best-covered season and falls below tracking eligibility.

| Position | Players | Mentions | No mention | Spearman | Mean CSAx difference (95% CI) | Contrast status |
| --- | --- | --- | --- | --- | --- | --- |
| Forwards | 59 | 24 | 35 | 0.51 | 0.87 (0.46 to 1.29) | Available |
| Defensemen | 23 | 10 | 13 | 0.53 | 0.65 (0.11 to 1.19) | Available |

Descriptions of active physical engagement align with higher player-average CSAx in both positions. Spearman correlations are **0.51** for forwards and **0.53** for defensemen. Players with a positive code average **0.87 (0.46 to 1.29)** higher CSAx among forwards and **0.65 (0.11 to 1.19)** among defensemen, with 95% conditional intervals. This agreement supplies independent evidence about the physicality interpretation, while the smaller defensive cohort leaves greater uncertainty about its magnitude.

A single human rater codes active physical engagement while blinded to identities, scores, and rankings. The source collection comprises official NHL scouting publications from 2018–2024. Profiles are matched to individual NHL identities and draft years before inclusion, regardless of score or physicality wording. The 2024 source date uses its PDF creation timestamp; the exact publication day is unavailable.

Player-average scores use eligible seasons following the source report. A zero code records absence of the specified description; it does not establish soft play. Mean differences compare players with and without the description. Their HC1 intervals condition on the estimated scores and observed scouting cohort. Draft-era prose, prospect selection, and a single rater constrain interpretation, particularly as players mature.

## Special-teams deployment

We express official power-play and penalty-kill ice time as percentages of total regular-season ice time. Recorded zeros remain observations. The source covers all 2314 scored player-seasons, with 0 missing unit-specific records. Higher CSAx accompanies lower power-play shares and higher penalty-kill shares in both positions. Linear models adjust for current-season listed size, age and age squared, games dressed, ice time per game, five-on-five scoring rate, relative shot attempts, and season. Intervals use player-clustered HC1 uncertainty conditional on the scores.

| Position | Unit | Player-seasons | Mean TOI share (%) | Spearman | Adjusted percentage points per CSAx SD (95% CI) |
| --- | --- | --- | --- | --- | --- |
| Defensemen | Power play | 829 | 4.37 | -0.21 | -0.44 (-0.76 to -0.12) |
| Defensemen | Penalty kill | 829 | 8.27 | 0.15 | 0.66 (0.37 to 0.95) |
| Forwards | Power play | 1485 | 9.84 | -0.36 | -0.61 (-0.89 to -0.33) |
| Forwards | Penalty kill | 1485 | 5.48 | 0.21 | 0.70 (0.37 to 1.03) |

The associations describe how teams deploy players with different physical profiles. Special-teams assignments also reflect skill, tactical needs, and teammates; a power-play or penalty-kill association cannot independently validate toughness.

## Postseason physical engagement

We compare five-on-five observations from regular-season games excluded from score construction with each qualifying team’s first four playoff games. A player enters the paired analysis only with positive exposure in both periods. For traded players, the baseline includes games with their playoff team. The window is common to teams; a player need not dress in all four games.

| Season | Excluded construction games | Available baseline games | First-four playoff games | Full playoff games |
| --- | --- | --- | --- | --- |
| 2021–22 | 491 | 821 | 32 | 89 |
| 2022–23 | 414 | 898 | 32 | 88 |
| 2023–24 | 390 | 922 | 32 | 88 |
| 2024–25 | 383 | 929 | 32 | 86 |

The baseline excludes every game with retained A3Z tracking, including records outside individual scoring eligibility. This conservative separation prevents the same game from contributing to score construction and the regular-season outcome baseline. Selection into the playoffs and the paired sample remains visible:

| Window | Position | Scored player-seasons | Positive playoff exposure | Paired positive exposure |
| --- | --- | --- | --- | --- |
| First four | Defensemen | 829 | 395 | 395 |
| First four | Forwards | 1485 | 752 | 752 |
| Full postseason | Defensemen | 829 | 409 | 409 |
| Full postseason | Forwards | 1485 | 774 | 774 |

We fit separate positional Poisson models for hits delivered, hits received, and opponent shots blocked. Player-season effects absorb each player’s baseline level, ice-time offsets account for exposure, and postseason interactions with CSAx and the existing regular-season controls describe differential changes. Player-clustered HC1 intervals condition on scores and observed pairs. Pairs with zero events across both periods contribute to descriptive totals but contain no information about within-player rate change for that event.

| Window | Position | Measure | Informative pairs | Zero-total pairs | Rate-ratio multiplier per CSAx SD (95% CI) |
| --- | --- | --- | --- | --- | --- |
| First four | Defensemen | Hits delivered | 395 | 0 | 0.95 (0.88 to 1.02) |
| First four | Defensemen | Hits received | 395 | 0 | 0.99 (0.94 to 1.05) |
| First four | Defensemen | Opponent shots blocked | 395 | 0 | 1.01 (0.95 to 1.07) |
| First four | Forwards | Hits delivered | 752 | 0 | 0.88 (0.83 to 0.94) |
| First four | Forwards | Hits received | 751 | 1 | 1.00 (0.95 to 1.06) |
| First four | Forwards | Opponent shots blocked | 751 | 1 | 0.96 (0.87 to 1.05) |
| Full postseason | Defensemen | Hits delivered | 409 | 0 | 0.95 (0.89 to 1.01) |
| Full postseason | Forwards | Hits delivered | 774 | 0 | 0.90 (0.86 to 0.95) |

The forward hits-delivered multiplier is **0.88 (0.83 to 0.94)** per CSAx standard deviation. Higher-scoring forwards show a smaller proportional postseason increase, and the full-postseason check has the same direction. The defenseman estimate is **0.95 (0.88 to 1.02)**; its interval includes no differential change.

A rate-ratio multiplier below one indicates a smaller proportional postseason increase as CSAx rises, after adjustment. It does not by itself establish a physical ceiling or imply lower postseason contact levels. Adjusted ratios below average log-rate changes over the covariate distribution of informative pairs, with CSAx set to −1, 0, or +1:

| Window | Position | CSAx | Adjusted postseason/baseline rate ratio (95% CI) | Rate change (%) |
| --- | --- | --- | --- | --- |
| First four | Defensemen | -1.00 | 1.65 (1.47 to 1.85) | 64.75 |
| First four | Defensemen | 0.00 | 1.56 (1.44 to 1.69) | 56.14 |
| First four | Defensemen | 1.00 | 1.48 (1.33 to 1.64) | 47.98 |
| First four | Forwards | -1.00 | 2.36 (2.15 to 2.59) | 136.27 |
| First four | Forwards | 0.00 | 2.08 (1.97 to 2.21) | 108.40 |
| First four | Forwards | 1.00 | 1.84 (1.70 to 1.99) | 83.82 |
| Full postseason | Defensemen | -1.00 | 1.53 (1.38 to 1.69) | 52.59 |
| Full postseason | Defensemen | 0.00 | 1.45 (1.36 to 1.55) | 45.13 |
| Full postseason | Defensemen | 1.00 | 1.38 (1.27 to 1.50) | 38.03 |
| Full postseason | Forwards | -1.00 | 2.12 (1.96 to 2.28) | 111.66 |
| Full postseason | Forwards | 0.00 | 1.91 (1.82 to 2.01) | 90.99 |
| Full postseason | Forwards | 1.00 | 1.72 (1.62 to 1.84) | 72.34 |

![Postseason changes in hits delivered](figures/postseason_engagement.png)

Fights and contact penalties receive descriptive summaries because their counts are sparse. These observed rates also show the contact levels underlying the fitted changes:

| Position | Period | Measure | Events | Five-on-five minutes | Events per 60 |
| --- | --- | --- | --- | --- | --- |
| Defensemen | Baseline | Hits delivered | 20520 | 283624.58 | 4.34 |
| Defensemen | Baseline | Hits received | 26031 | 283624.58 | 5.51 |
| Defensemen | Baseline | Opponent shots blocked | 19946 | 283624.58 | 4.22 |
| Defensemen | Baseline | Fights | 142 | 283624.58 | 0.03 |
| Defensemen | Baseline | Contact penalties taken | 1917 | 283624.58 | 0.41 |
| Defensemen | Baseline | Contact penalties drawn | 1300 | 283624.58 | 0.28 |
| Defensemen | Postseason | Hits delivered | 2627 | 23330.60 | 6.76 |
| Defensemen | Postseason | Hits received | 3939 | 23330.60 | 10.13 |
| Defensemen | Postseason | Opponent shots blocked | 1893 | 23330.60 | 4.87 |
| Defensemen | Postseason | Fights | 5 | 23330.60 | 0.01 |
| Defensemen | Postseason | Contact penalties taken | 220 | 23330.60 | 0.57 |
| Defensemen | Postseason | Contact penalties drawn | 146 | 23330.60 | 0.38 |
| Forwards | Baseline | Hits delivered | 37003 | 412268.92 | 5.39 |
| Forwards | Baseline | Hits received | 35535 | 412268.92 | 5.17 |
| Forwards | Baseline | Opponent shots blocked | 13738 | 412268.92 | 2.00 |
| Forwards | Baseline | Fights | 265 | 412268.92 | 0.04 |
| Forwards | Baseline | Contact penalties taken | 3203 | 412268.92 | 0.47 |
| Forwards | Baseline | Contact penalties drawn | 3882 | 412268.92 | 0.56 |
| Forwards | Postseason | Hits delivered | 6103 | 34822.08 | 10.52 |
| Forwards | Postseason | Hits received | 4861 | 34822.08 | 8.38 |
| Forwards | Postseason | Opponent shots blocked | 1461 | 34822.08 | 2.52 |
| Forwards | Postseason | Fights | 5 | 34822.08 | 0.01 |
| Forwards | Postseason | Contact penalties taken | 347 | 34822.08 | 0.60 |
| Forwards | Postseason | Contact penalties drawn | 431 | 34822.08 | 0.74 |

The full-postseason check repeats only the primary hits-delivered model. Its longer windows depend on team advancement. All estimates concern participating players; they do not describe what nonqualifiers would do in the playoffs.

## Next-season continuation

Continuation means at least 300 NHL minutes in the following season. CSAx and controls come from season t, and continuation concerns t+1. The primary models condition on current-season role: games dressed and ice time per game in t. Separate positional models also retain listed size, age and age squared, five-on-five scoring rate, relative shot attempts, and season controls.

| Position | Player-seasons | Odds ratio per CSAx SD (95% CI) | p-value |
| --- | --- | --- | --- |
| Defensemen | 829 | 1.322 (1.038 to 1.683) | 0.024 |
| Forwards | 1485 | 1.220 (1.003 to 1.485) | 0.047 |

Both odds ratios exceed one, with intervals that exclude one, although the forward lower bound is close to that value. These estimates support a positive conditional association with continuation. Their magnitude and uncertainty are more informative than the nominal significance threshold alone. [ASA guidance](https://www.amstat.org/asa/files/pdfs/p-valuestatement.pdf).

We also average predicted probabilities over each observed positional sample while setting CSAx to −1, 0, or +1. Other controls retain their observed values.

| Position | CSAx | Adjusted continuation probability (%) | 95% CI (%) |
| --- | --- | --- | --- |
| Defensemen | -1.00 | 86.35 | 83.44 to 89.25 |
| Defensemen | 0.00 | 88.60 | 86.63 to 90.58 |
| Defensemen | 1.00 | 90.58 | 88.14 to 93.02 |
| Forwards | -1.00 | 88.01 | 85.62 to 90.40 |
| Forwards | 0.00 | 89.55 | 88.11 to 90.99 |
| Forwards | 1.00 | 90.93 | 89.26 to 92.61 |

![Adjusted next-season continuation probabilities](figures/continuation.png)

These associations describe roster relevance. They are not causal effects or independent confirmation of the physicality construct. Player-clustered HC1 intervals condition on the estimated scores and tracked sample; uncertainty from reconstructing CSAx is outside these intervals.

### Current and previous roles

The role-timing comparison restricts both models to identical observations with NHL participation and observed role in t−1. We replace only games dressed and ice time per game with their preceding-season values, retaining CSAx and all other controls from t. The full-sample current-role analysis remains primary.

| Position | Role timing | Player-seasons | Odds ratio (95% CI) | p-value |
| --- | --- | --- | --- | --- |
| Defensemen | Current season | 800 | 1.30 (1.01 to 1.67) | 0.043 |
| Defensemen | Previous season | 800 | 1.38 (1.08 to 1.75) | 0.010 |
| Forwards | Current season | 1426 | 1.22 (0.99 to 1.50) | 0.059 |
| Forwards | Previous season | 1426 | 1.26 (1.03 to 1.53) | 0.022 |

| Position | Role timing | CSAx | Adjusted continuation probability (%) | 95% CI (%) |
| --- | --- | --- | --- | --- |
| Defensemen | Current season | -1.00 | 87.06 | 84.16 to 89.97 |
| Defensemen | Current season | 0.00 | 89.07 | 87.11 to 91.03 |
| Defensemen | Current season | 1.00 | 90.84 | 88.41 to 93.26 |
| Defensemen | Previous season | -1.00 | 86.32 | 83.22 to 89.41 |
| Defensemen | Previous season | 0.00 | 89.04 | 87.01 to 91.06 |
| Defensemen | Previous season | 1.00 | 91.32 | 88.95 to 93.69 |
| Forwards | Current season | -1.00 | 88.54 | 86.12 to 90.96 |
| Forwards | Current season | 0.00 | 90.04 | 88.59 to 91.48 |
| Forwards | Current season | 1.00 | 91.37 | 89.69 to 93.06 |
| Forwards | Previous season | -1.00 | 88.06 | 85.46 to 90.66 |
| Forwards | Previous season | 0.00 | 89.95 | 88.46 to 91.44 |
| Forwards | Previous season | 1.00 | 91.59 | 89.94 to 93.24 |

These comparisons address conditioning choices. They do not isolate causal pathways, and differences in nominal significance do not determine which model we prefer.

## Paper structure and reproduction

The [paper roadmap](paper_roadmap.md) follows construction → scouting → deployment → postseason engagement → continuation. This progression first establishes what CSAx measures and how it agrees with independent descriptions, then examines assigned roles, behavioral changes, and practical roster relevance. The [Sloan abstract PDF](../abstract_mitssacrpc/abstract_mitssacrpc.pdf), authored in [Quarto](../abstract_mitssacrpc/abstract_mitssacrpc.qmd) and accompanied by [Markdown](../abstract_mitssacrpc/abstract.md) and [plain text](../abstract_mitssacrpc/abstract.txt), follows the same sequence. Individual shooting-percentage variability, contracts, and numerous career interactions remain outside the paper core.

The compact analysis object retains frozen source inputs, model identities, feature counts, folds, calibration summaries, historical benchmarks, and current results. The numbered workflow fits only the selected positional specification by default. Previous alternative models and bootstrap summaries remain labeled historical results.

Current outputs include [player rankings](player_rankings.csv), [player-period engagement](postseason_engagement.csv), and [application estimates](application_estimates.csv). The [README](../../README.md) supplies reproduction instructions and describes the locked scouting data. NHL inputs use the pinned nhlscraper revision; A3Z observations remain attributed to Corey Sznajder / All Three Zones. Source materials retain their third-party terms.

Sloan requires an abstract under 500 words, including title and body, with Introduction, Methods, Results, and Conclusion sections reporting actual findings. We count the headings toward that limit. Abstracts are due October 1, 2026, at 11:59 p.m. Eastern; invited manuscripts are due December 4 at the same time. The authenticated form’s upload requirements remain unverified. Current guidance requires an open-source repository link. The repository remains private pending a public-release decision, and full-manuscript formatting awaits invitation guidance. [Competition rules](https://www.sloansportsconference.com/research-paper-competition).

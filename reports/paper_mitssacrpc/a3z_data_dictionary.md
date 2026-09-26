# A3Z data inventory and feature opportunities

We inventory all 95 fields in the freely downloaded All Three Zones transition workbook used by CSAx_P: 7 identification or exposure fields, 80 count-valued behavior fields, and 8 provider composite scores. Each source row summarizes a player in a recorded game. These aggregates offer detail about puck play, while preserving limits on what we can infer about individual battles, pressure, and possession.

The inventory describes the complete downloaded extract. A3Z also maintains other products and tracking material whose contents are outside this snapshot. The [research summary](research_summary.md) presents the models, positional comparisons, and findings.

## Source and coverage

Corey Sznajder / All Three Zones supplies the [transition workbook](https://public.tableau.com/app/profile/corey.sznajder/viz/transitionstats/Sheet1), reached through the [official links page](https://www.allthreezones.com/links.html). We retain the September 15, 2026 snapshot with these SHA-256 hashes:

| File | SHA-256 |
| --- | --- |
| Tableau workbook | `0ed9c09819854e6f4b281730ba2d0b3e2dcc629a48ce6fc6fbf9bc35331907fd` |
| Full CSV extract | `18e4d4d49ec3c94e47efda22ee6834a527a21c5c936deb82e9ac244df051d23e` |

The extract contains 67,137 rows. We describe field availability in the 61,098 source skater rows labeled 2021–22 through 2024–25, before NHL identity reconciliation, exposure checks, and player eligibility. Source goalie rows remain outside this coverage calculation. The extract also contains 3,285 rows labeled 2024–25p, 38 rows from one game labeled 2025–26, and one row without a season label. Those records do not extend the four-season study population.

The coverage labels below count populated cells, including recorded zeros. They do not establish complete game tracking, correct event coding, or an opportunity to perform the behavior.

| Coverage label | 2021–22 | 2022–23 | 2023–24 | 2024–25 |
| --- | --- | --- | --- | --- |
| All | 17,885 / 17,885 | 15,292 / 15,292 | 14,071 / 14,071 | 13,850 / 13,850 |
| Zone context | 0 / 17,885 | 2,268 / 15,292 | 14,071 / 14,071 | 13,850 / 13,850 |
| Rush context | 0 / 17,885 | 0 / 15,292 | 14,071 / 14,071 | 13,850 / 13,850 |

The source sweater-number field has three missing values in 2021–22 and one in 2024–25. All other identification fields are populated in the study skater rows. Six rows contain negative defensive retrieval counts; two of those also contain negative defensive puck-touch counts. These six rows are excluded from the analysis. A populated count therefore still requires source checks.

## Reading the inventory

**Basis** distinguishes the evidence behind each description. **Documented** refers to a tracking concept described in the [A3Z glossary](https://www.allthreezones.com/player-cardsfaq.html) or [retrieval methodology](https://allthreezones.substack.com/p/catch-and-retrieve). **Observed** identifies a relationship verified in the extract. **Label** gives the ordinary interpretation of the source name without claiming a complete tracking protocol. **Unresolved** identifies ambiguity that affects interpretation or feature construction. The public descriptions do not provide a field-by-field schema for every exported column.

**Model use** identifies the positional physicality specification. **F** means the forward model, including centers; **D** means the defenseman model. **Retained** means the counter is available for explanation in the compact analysis object but is not a model predictor. **Unused** means it remains available in the full raw extract. The analysis retains 27 behavior counters and the source ice-time field, alongside source identity and mapping records.

Unless a special-teams state is explicit, the analysis treats its selected offense and transition counters as five-on-five observations. Its count rates use matched NHL shift-derived five-on-five minutes; source ice time is retained for comparison. Special-teams counters require their own exposure and tracking-scope checks. A **count** below means recorded occurrences per player-game, not a percentage or rate. Provider counters can overlap, and a zero count cannot establish that a player had an opportunity.

### Identification and exposure

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `#` | Source sweater number; roster matching resolves missing or inconsistent values. It is not a player identifier. | Label | Number label | All except 4 missing | Player matching |
| `Player` | Source player name; names require roster reconciliation and can be shared by different players. | Label | Text | All | Player matching |
| `Team` | Source team abbreviation; spelling variants require normalization. | Label | Text | All | Team and game matching |
| `Pos.` | Source position label, including generic forward and occasional lowercase labels. NHL records supply model positions. | Label | Category | All | Skater selection and source record |
| `5v5 TOI` | Recorded five-on-five ice time; compare with NHL shifts before aggregating player-games. | Label | Minutes | All | Exposure comparison |
| `Year` | Source season label; regular-season and playoff labels remain distinct. | Label | Season label | All | Season selection |
| `Game` | Source date and team pairing; multiple labels can resolve to one NHL game. | Label | Text | All | Game matching |

### Shooting and shot assists

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `Shots` | Recorded shot counter; correspondence with NHL shot-attempt categories requires checking. | Label | Count | All | Retained |
| `Shots On Goal` | Recorded shots reaching the goal; source event exclusions require confirmation. | Label | Count | All | Unused |
| `Chances` | Provider-judged scoring chances, generally from home plate. | Documented | Count | All | Unused |
| `Passes` | Sum of primary, secondary, and tertiary shot assists in every inspected row; it does not count all attempted passes. | Observed | Count | All | Retained |
| `Primary Shot Assists` | Final passing contribution before a recorded shot; sequence eligibility needs confirmation. | Label | Count | All | Retained |
| `Secondary Assists` | Second passing contribution before a shot; do not interpret as NHL secondary goal assists. | Label | Count | All | Unused |
| `Tertiary Assists` | Third passing contribution before a shot; continued possession is not directly observed in this aggregate. | Label | Count | All | Unused |
| `Chance Assists` | Assists associated with recorded scoring chances; included assist orders require confirmation. | Label | Count | All | Unused |

### Passing locations and types

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `Home Plate` | Passing-related home-plate counter; exact geometry and overlap with other passing categories remain unconfirmed. | Unresolved | Count | All | Retained |
| `Low-to-High` | Shot assists setting up shots from the point. | Documented | Count | All | Unused |
| `Behind Net` | Shot assists originating behind the net or goal line. | Documented | Count | All | Retained |
| `Center Lane Assists` | Shot assists from the central lane. | Documented | Count | All | Unused |
| `NZ Assist` | Neutral-zone passing context; exact attribution and distinction from the later similarly named field need confirmation. | Unresolved | Count | All | Unused |
| `DZ Assist` | Defensive-zone passing context; exact attribution and distinction from the later similarly named field need confirmation. | Unresolved | Count | All | Unused |

### Offensive sequence context

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `Shots off Rush` | Shots immediately following controlled entries. | Documented | Count | All | Unused |
| `Assists off Rush` | Shot-assist contributions during rush sequences; included assist orders require confirmation. | Label | Count | All | Unused |
| `Shots off Forecheck or Cycle` | Forecheck/cycle shot-context counter; confirm overlap with the separate cycle field before adding them. | Unresolved | Count | All | Retained |
| `Assists off Forecheck` | Shot assists attributed to forechecking sequences; attribution does not itself confirm contact or pressure on the passer. | Label | Count | All | Retained |
| `Shots off Cycle` | Shots attributed to cycle sequences; overlap with the combined-label field needs confirmation. | Label | Count | All | Unused |
| `Assists off Cycle` | Shot assists attributed to cycle sequences; an offensive context measure. | Label | Count | All | Retained |
| `Shots off HD Passes` | Shots following passes classified as high danger; the precise relationship to exported passing categories needs confirmation. | Label | Count | All | Unused |

### Zone entries and forechecking

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `Zone Entries` | Entry-volume counter; confirm treatment of failed entries before constructing attempt shares. | Label | Count | All | Unused |
| `Carries` | Carry-in counter; confirm how controlled pass-ins are credited before interpreting it as all controlled entries. | Label | Count | All | Unused |
| `Failed Entries` | Unsuccessful entry counter; its inclusion in total entry volume needs confirmation. | Label | Count | All | Unused |
| `Entries w/ Passing Play` | Entries associated with a subsequent passing play; qualifying plays and timing require confirmation. | Label | Count | All | Unused |
| `Recoveries` | Dump-in recoveries followed by a meaningful puck play. | Documented | Count | All | F rate |
| `Carries w/ Chances` | Carry-in contexts producing chances; does not measure pressure or contact directly. | Label | Count | All | Unused |
| `Dump-in Chances` | Chances associated with dump-in sequences; verify whether attribution follows the entrant or another participant. | Label | Count | All | Unused |
| `Forecheck Pressures` | Forechecking actions that force an exiting player to act. | Documented | Count | All | F rate |

### Defensive retrievals and exits

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `DZ Puck Touches` | Defensive-zone touches made while attempting a breakout or exit. | Documented | Count | All | Retained |
| `DZ Retrievals` | Clean recoveries moved to a teammate or out of the zone. | Documented | Count | All | D rate |
| `Zone Exits` | Successful exits; equals possession exits plus clears in every inspected row. | Documented; observed | Count | All | Retained |
| `Exits w/ Possession` | Controlled exits leading to an entry attempt or line change. | Documented | Count | All | Retained |
| `Carried Exits` | Exits credited as carries; the carried and passed counters do not exhaust recorded possession exits. | Label; observed | Count | All | Retained |
| `Passed Exits` | Exits credited as passes; the carried and passed counters do not exhaust recorded possession exits. | Label; observed | Count | All | Retained |
| `Clears` | Recorded clear counter; the observed exit identity places these within successful exits. | Observed | Count | All | Retained |
| `Missed Passes` | Unsuccessful passing exits recorded separately from failed exits. | Documented | Count | All | Retained |
| `Retrievals Leading to Exits` | Retrievals credited with starting a subsequently successful exit. | Documented | Count | All | Retained |
| `Botched Retrievals` | Retrieval-related errors; attribution can involve the receiver as well as the retriever. | Documented | Count | All | D rate |
| `Exchanges` | Puck exchanges within exit sequences; direction, outcome, and credit rules need confirmation. | Label | Count | All | Unused |
| `Failed Exit` | Failed clears or turnovers meeting the provider’s exit-failure rules. | Documented | Count | All | Retained |
| `Rushed Exits` | Exit counter labeled rushed; the triggering condition and outcome categories are unconfirmed. | Unresolved | Count | All | Retained |
| `Second Touch Exits` | Exit counter labeled second touch; the credited player, sequence rule, and successful-outcome requirement are unconfirmed. | Unresolved | Count | All | Retained |

### Entry defense

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `Targets` | Recorded entry targets; supplies the analysis entry-denial denominator. Targeting volume depends strongly on position and role. | Label | Count | All | D entry-denial share denominator |
| `Carries 1` | Carry counter in the entry-defense block; exact mapping to controlled entries allowed requires confirmation. | Unresolved | Count | All | Unused |
| `Denials` | Entry attempts stopped, corresponding to failed attacking entries. | Documented | Count | All | D entry-denial share numerator |
| `Passes Allowed` | Passing plays allowed in entry-defense contexts; qualifying passes and attribution need confirmation. | Label | Count | All | Unused |
| `Carries w/ Chance Against` | Carry-in contexts yielding chances against; subsequent events also depend on teammates and defensive structure. | Label | Count | All | Unused |
| `Dump-in w/ Chance Against` | Dump-in contexts yielding chances against; confirm event linkage and player attribution. | Label | Count | All | Unused |

### Special-teams transition

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `5v4 Entries` | Entries recorded at five-on-four; denominator treatment of failed entries needs confirmation. | Label | Count | All | Unused |
| `5v4 Carries` | Carry-ins recorded at five-on-four; verify pass-in credit and the corresponding opportunity set. | Label | Count | All | Unused |
| `5v4 Setups` | Entry-associated setups at five-on-four; the condition establishing a setup is unconfirmed. | Unresolved | Count | All | Unused |
| `4v5 Entries` | Entries recorded at four-on-five; whether credit represents own entries or entries faced requires confirmation. | Unresolved | Count | All | Unused |
| `4v5 Carry Denials` | Carry-entry denials at four-on-five; an appropriate targeted-entry denominator is not established here. | Label | Count | All | Unused |

### Special-teams offense

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `5v4 Shots` | Shots recorded at five-on-four; requires matching five-on-four exposure for rates. | Label | Count | All | Unused |
| `5v4 Passes` | Passing contribution counter at five-on-four; do not assume it includes all passes. | Label | Count | All | Unused |
| `5v4 Primary Setups` | Primary setup counter at five-on-four; verify correspondence to primary shot assists. | Label | Count | All | Unused |
| `5v4 Chances` | Scoring chances recorded at five-on-four; inherits provider judgment in chance classification. | Label | Count | All | Unused |
| `5v4 Chance Setups` | Setups associated with five-on-four chances; included contribution orders need confirmation. | Label | Count | All | Unused |
| `5v4 Cross-Slot` | Five-on-four cross-slot passing context; precise geometry and shot requirement need confirmation. | Label | Count | All | Unused |
| `5v4 Low-to-High` | Five-on-four passing context from lower areas toward the point; exact qualifying setup rules need confirmation. | Label | Count | All | Unused |
| `5v4 Goal Line` | Five-on-four goal-line passing context; precise origin and shot requirement need confirmation. | Label | Count | All | Unused |

### Shot types and associated assists

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `One-timer` | One-timer shot counter; exact handling and timing criteria are unspecified. | Label | Count | All | Unused |
| `Rebounds` | Rebound-shot counter; the permitted time window and retained-possession rule need confirmation. | Label | Count | All | Retained |
| `Deflections` | Deflected-shot counter; confirm tip classification and shot-outcome exclusions. | Label | Count | All | Retained |
| `One-timer Assists` | Contributions credited with setting up one-timers; precise credit rules need confirmation. | Label | Count | All | Unused |
| `Rebound Assists` | Contributions credited with creating rebound shots; credit need not represent a conventional pass. | Label | Count | All | Unused |
| `Deflection Assists` | Contributions credited with creating deflections; confirm whether the original shooter receives the credit. | Label | Count | All | Unused |

### Additional zone/context fields

These six counters have shorter coverage and limited field-specific documentation. Offensive, neutral, and defensive zone labels identify context, but they do not establish where a particular player makes contact or handles the puck.

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `OZ` | Offensive-zone context counter; the event being credited and zone-assignment rule need confirmation. | Unresolved | Count | Zone context | Unused |
| `NZ` | Neutral-zone context counter; the event being credited and zone-assignment rule need confirmation. | Unresolved | Count | Zone context | Unused |
| `DZ` | Defensive-zone context counter; the event being credited and zone-assignment rule need confirmation. | Unresolved | Count | Zone context | Unused |
| `OZ Assist` | Assist contribution with offensive-zone context; the credited pass and context origin are unconfirmed. | Unresolved | Count | Zone context | Unused |
| `NZ Assist 1` | Additional neutral-zone assist-context counter; preserve its distinction from the earlier field. | Unresolved | Count | Zone context | Unused |
| `DZ Assist 1` | Additional defensive-zone assist-context counter; preserve its distinction from the earlier field. | Unresolved | Count | Zone context | Unused |

### Additional rush-context fields

A3Z discusses classifying rush offense by where and how a sequence begins, including retrievals, turnovers, and regrouping. This supports examining the broader context, while the precise mapping of each exported field to credited events still requires confirmation. [A3Z discussion of rush origins](https://allthreezones.substack.com/p/better-late-than-never-playoffs-post).

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `DZ Retrieval` | Rush-context count labeled defensive-zone retrieval; distinct from the clean-retrieval counter in the exit block. | Unresolved | Count | Rush context | Unused |
| `DZ Counter` | Defensive-zone counterattack context; qualifying events and player credit need confirmation. | Unresolved | Count | Rush context | Unused |
| `NZ Turnover` | Neutral-zone turnover context; does not by itself credit the player with forcing or recovering a turnover. | Unresolved | Count | Rush context | Unused |
| `NZ Regroup` | Neutral-zone regroup context; confirm what action or subsequent chance the count represents. | Unresolved | Count | Rush context | Unused |
| `NZ Reload` | Neutral-zone reload context; the distinction from regroups and other recoveries is unconfirmed. | Unresolved | Count | Rush context | Unused |
| `DZ Controlled Breakout` | Controlled-breakout context; the counter does not independently establish pressure faced or possession retained. | Unresolved | Count | Rush context | Unused |

### Provider composite scores

These eight fields use source-score units. Their decimal and sometimes negative values distinguish them from occurrence counts. A3Z describes weighting microstat components to form a game score; the complete formulas for this snapshot are not supplied in the downloaded workbook. [Microstat game-score description](https://allthreezones.substack.com/p/catch-and-retrieve).

| Source field | Meaning and interpretation | Basis | Unit | Coverage | Model use |
| --- | --- | --- | --- | --- | --- |
| `Microstat Game Score` | Provider’s weighted multi-component game score; it combines multiple behaviors. | Documented | Source score | All | Unused |
| `Offense` | Offensive score component; exact weights require confirmation. | Label | Source score | All | Unused |
| `Zone Entries 1` | Zone-entry score component; distinct from the raw entry count. | Label | Source score | All | Unused |
| `Entry Defense` | Entry-defense score component; exact weights require confirmation. | Label | Source score | All | Unused |
| `Exits` | Zone-exit score component; distinct from the recorded successful-exit count. | Label | Source score | All | Unused |
| `Forechecking` | Forechecking score component; exact weights require confirmation. | Label | Source score | All | Unused |
| `Special Teams` | Special-teams score component; its units are not special-teams minutes or events. | Label | Source score | All | Unused |
| `5v5 Game Score` | Five-on-five composite game score; formula and relationship to the full score require confirmation. | Label | Source score | All | Unused |

## Denominators and observation limits

The field list describes 80 behavioral counters, not 80 independent dimensions. In all 61,098 inspected study skater rows, total shot assists equal the sum of the three assist orders, and successful exits equal possession exits plus clears. However, carried and passed exits sum to possession exits in only 38,899 rows; the remaining 22,199 have larger recorded possession-exit totals. That relationship prevents treating the two narrower counters as an exhaustive partition without clarifying credit rules. We preserve the source totals.

A possession-exit share with recorded successful exits as its denominator describes how completed exits occur. It does not measure the probability of completing an attempted exit. The physicality model uses clean-retrieval and botched-retrieval rates, together with entry denials divided by targeted entries. Botched retrievals, missed passes, and failed exits cannot automatically be combined into a common failure denominator. Similarly, dump-in recoveries cannot be divided by a player’s own dump-ins to obtain a recovery success rate: the player who recovers a puck may differ from the player who sends it in.

Some promising behaviors involve a play occurring under pressure, yet the workbook supplies no event-level timestamps, puck trajectories, contact sequence, continuous possession history, or explicit pressure-intensity variable. The public tracking description gives context to exit observations, but player-game aggregates cannot match one recovery to one exit, identify every contested opportunity, or establish the duration of puck protection. The glossary also describes exit disruptions, while this extract has no separate field with that name.

The additional zone fields and rush-context fields require their own observed-game samples. Missing early-season fields remain unobserved; replacing them with zero would manufacture differences over time. The extract supplies no five-on-four or four-on-five ice-time field, so its special-teams counters cannot use five-on-five minutes as their exposure denominator.

## Feature opportunities

We evaluate new features by the behavior they represent, their opportunity structure, and their repeatability. The following questions concern possible extensions; the current model specification remains the reference for the analysis findings.

| Area | Candidate measures | Research question and qualification |
| --- | --- | --- |
| Defensive workload and execution | Defensive puck touches, missed passes, failed exits, and exchanges as separate rates | How much breakout work does a player undertake, and what happens during those plays? Separate workload from execution. Confirm the exchange definition and attempt structure before constructing success percentages. |
| Creating offense in contested space | Behind-net and center-lane assists per 60; forecheck/cycle shooting; rebound and deflection setup contributions | Does a player create offense in areas where space is limited? Location and sequence context do not establish physical pressure. Confirm overlaps and setup credit before summing counters. |
| Entry defense beyond denials | Passing plays and chances allowed following entries, initially considered separately | What happens after an attacker reaches the line? Establish a common targeted-entry opportunity set before using shares. Defensive systems, partners, and position affect both exposure and outcomes. |
| Turning defense into offense | Retrieval, counterattack, turnover, and regroup context | Which origins of offense reflect a player’s contribution under resistance? Confirm whether credit belongs to the initiator, passer, or shooter, and restrict comparisons to games with observed fields. |

The defensive workload and dangerous-area passing counters offer the most immediate opportunities for descriptive study because their source fields span all four behavior seasons. Rush-origin measures provide a narrower two-season research sample. General entry and passing skill can also help explain player profiles, although an association with skill alone does not establish indirect physicality.

Successful execution and physical engagement remain separate considerations. Adding skill measures to a model that predicts listed size can yield small or negative coefficients for those measures. We therefore examine their relationships with size and role before interpreting higher CSAx as more effective play under pressure. Feature additions require a defensible meaning and observed opportunity structure; improved prediction alone cannot supply construct validity.

## Attribution and access

Credit for the A3Z observations and tracking definitions belongs to Corey Sznajder / All Three Zones. Third-party data retain their source terms; the project’s code license does not replace those terms. The frozen raw workbook and full CSV remain local download caches, while the compact analysis object preserves the selected inputs and their mappings. The repository remains private, and the inventory makes no claim about access to subscription-only or unreleased tracking material.

# Data Decisions
*Pulled: October 2026. Last updated: October 18, 2026.*

## Questions
1. 2026 snapshot: who gave the most and least value for their salary (rate vs availability)?
2. Contract retrospective: how are the big multi-year deals going so far?
3. Remaining surplus value: which contracts are assets or liabilities going forward?
4. Roster value: what is every player the Yankees control worth per season, compared with what he costs?
5. 2027 outlook: how many wins do the players under control project for, and where are the gaps by position?
6. Offseason: which of the Yankees' own free agents are worth bringing back, and which outside free agents fill the gaps?

## Sources
| Source | What it has | Seasons | Player IDs? | Decision |
|---|---|---|---|---|
| B-Ref WAR files (bat + pitch) | WAR, games, PA/IP, age, team for every player-season | 1871-2026 | Yes (`player_ID`) | Use for WAR, playing time, and ages |
| B-Ref Yankees contracts page (manual CSV export) | 2026+ salaries, contract terms, service time, Arb/FA years, dead money, payroll summary | 2026-2032 | Yes (`Name-additional`, same as `player_ID`) | Use for salaries and team control |
| B-Ref 2026 Yankees Appearances table (manual CSV export) | Games at each position for every 2026 Yankee | 2026 | Yes (`Player-additional`) | Use to assign 2027 playing time to positions |
| MLB.com, "All of the 2026-2027 free agents, position by position" (Oct 8, 2026) | Free agents by position, 2027 age, option status | 2026-27 offseason | No | Names, positions, ages, and option notes only, for 2B, 3B, SS, CF, SP, and RP. Matched to B-Ref IDs by name and age |
| Roster checks: FanGraphs RosterResource, MLB.com transactions, RotoWire | Current 40-man roster and recent moves | Oct 2026 | No | Used to add players the contracts page is missing and remove players no longer on the 40-man |
| Chadwick register | ID crosswalk across sites | All | Yes | Not needed: B-Ref IDs match across the B-Ref sources |
| Dollars per WAR estimate | Free agent cost per WAR | 2021-2025 | n/a | Range $8M-$11M; base case $9.5M ([FanGraphs method](https://tht.fangraphs.com/methodology-and-calculations-of-dollars-per-war/)) |

## Terms (Sports Reference, reviewed Oct 2026)
- Using and publishing data from individual pages is permitted with credit to Sports Reference as the source.
- Data is exported manually; no automated scraping.
- Raw files are kept out of the public repo (no bulk republishing).
- No AI or machine learning on this data; the projection is a fixed-weight statistical formula (Marcel-style).
- Every deliverable credits "Data: Baseball-Reference.com (Sports Reference LLC)".
- The MLB.com free-agent list is used only for names, positions, ages, and option status.

## Validation
- WAR files cover 1871-2026 (batting: 126,547 rows; pitching: 57,884 rows).
- Full seasons 2021-2025 have ~1,600-1,700 batting rows; 2026 has 830, apparently because pitcher rows aren't added to the batting file yet. 2026 position player stats match the team page, and the pitching file's 2026 count (~1,000) matches past seasons, so 2026 is usable.
- Judge 2025 WAR matches his B-Ref page: Yes
- All 42 players in the contracts export match the WAR files on player ID.
- Roster checked against the current 40-man: 7 players the contracts page is missing were added (seeds/roster_additions.csv) and 4 players it still lists after they left the 40-man were removed (seeds/roster_removals.csv), each with a note.
- Parsed salaries plus dead money reconcile to B-Ref's Dollars Committed total for 2026-2032, after the documented items in seeds/payroll_reconciling_items.csv.
- Wins formula check: 48 + the 2026 Yankees' WAR (46.9) = 94.9 implied wins, vs 93 actual.
- Original projection backtest (project 2025 from 2022-2024 only, before calibration): average miss of 1.24 WAR for hitters (naive "same as last year": 1.44) and 1.12 WAR for pitchers (naive: 1.34). Correlation with actual 2025: 0.61 hitters, 0.41 pitchers.
- Calibration (backtests for 2023-2026, by projected tier): before, good players delivered about 80% of their projection; after, about 95%. Rate ratio for good players: hitters 0.95, pitchers 0.96. Pitcher playing-time ratio 1.03 and pitcher bias -0.02 WAR. Average miss across all players: hitters 0.92 WAR (was 0.86), pitchers 0.57 (was 0.60). Star hitters beat their projections by about 0.15 WAR, so they're about 4% conservative; no further tuning was done to move one player's number.
- Playing time check: hitters under control for 2027 project 6,310 PA, close to the roughly 6,200 a team uses.
- Free-agent matching: 202 of 203 free agents matched to exactly one B-Ref ID, with one name override (Kiké Hernández is "Enrique Hernández" on B-Ref). Rowan Wick hasn't pitched in MLB since 2022, so he has no projection.

## Assumptions
- Pre-arb players with no listed salary: $780,000 (2026 league minimum)
- Arb (~$X) estimates come from Matt Swartz / MLB Trade Rumors' arbitration model, as shown on B-Ref.
- Arbitration years with no published estimate: 60% of the player's projected value, never less than the minimum.
- Service time format: years.days (172 days = 1 season)
- Dollars per WAR: $9.5M base case, tested at $8M (low) and $11M (high)
- Aging: projected WAR drops 0.5 per season for each year a player is past 30 (never below 0). Players 30 and under don't decline.
- Replacement level: a team of freely available players wins about 48 games, so wins = 48 + team WAR.
- A team uses about 6,200 plate appearances and 1,450 innings a season (about 860 by starters and 590 by relievers), or about 689 PA per lineup spot.
- Money in 2026 dollars: no $/WAR inflation and no discounting, since the two roughly cancel out

## Methodology
- **2026 snapshot uses 2026 cash salary.** Only WAR earned as a Yankee counts.
- **Split-season costs are prorated** by the share of that season's playing time spent with the Yankees (PA for hitters, innings for pitchers). B-Ref doesn't prorate trades, so this corrects it.
- **Rate vs availability:** availability = share of a full season played (600 PA for hitters, 180 IP for starters, 65 IP for relievers). Rate = WAR per full season. Rate x availability = WAR.
- **Small samples** (under 20% of a full season) are kept in totals but not ranked on rate.
- **Excluded from the 2026 rankings:** players with no 2026 games for the Yankees (likely in the minors, joined after their 2026 games, or salary only estimated). Each has a labeled reason.
- **Contract retrospective cost basis:** free agents use actual dollars (contract total minus money still owed after 2026, minus the unpaid part of 2020, plus trade cash). Trade acquisitions use average annual value (AAV) per season as a Yankee, because their contract totals include years with other teams.
- **Contract years counted:** free agents from the first year of the contract; trade acquisitions from their first season as a Yankee. Seasons missed entirely to injury count as a full year of cost with 0 WAR.
- **2020** costs are scaled to 60/162 to match the shortened season's prorated pay.
- **Trade cash** tied to a player on the roster (e.g., the Marlins' payments on Stanton) reduces that player's cost.
- **Projections:** Marcel-style (Tom Tango's method) applied to WAR. Last three seasons weighted 5/4/3 for hitters and 3/2/1 for pitchers, blended with 3,600 PA (hitters) or 720 IP (pitchers) of league-average performance, then adjusted for age (+0.6% per year under 29, -0.3% per year over 29). The regression amounts were set by calibration: WAR needs about three times the regression Marcel uses for batting stats, because it includes noisy defense and runs-allowed pitching.
- **Projected playing time:** hitters 0.5 x last season's PA + 0.1 x the season before + 200. Pitchers 0.5 x last season's IP + 0.1 x the season before + 25 + 35 x share of games started, then x 0.8, because pitchers threw about 20% fewer innings than Marcel projected in the backtests.
- **Remaining contract value:** rate = 2027 projection per full season, minus aging past 30 in later years. Two playing-time cases: expected (weighted share of full seasons played over the last three years, a missed season counts as 0) and healthy (a full season every year). Money still owed = guaranteed salary after 2026, including buyouts (which get 0 WAR), net of trade cash.
- **Roster value:** every season a player is under team control after 2026 (guaranteed, arbitration, or pre-arb). Established players (3+ years of service) use their three-year durability for expected playing time; younger players use Marcel's projected playing time, because a short season for them usually means a mid-season call-up, not an injury.
- **Per season vs totals:** totals measure the whole asset (more years of control are worth more). Per season measures how good a deal each year is, and it's what the rankings use, so players with 2 and 6 years of control compare fairly.
- **2027 outlook:** projected wins = 48 + the projected 2027 WAR of players under control. Players leaving are those who played for the Yankees in 2026 and aren't under control in 2027.
- **Position depth:** each hitter's projected 2027 PA and WAR are split across positions in proportion to his 2026 games there for the Yankees. Pitchers count as starters if they started at least half their 2026 games. Coverage = projected playing time / playing time needed. Gap: under 50%. Thin: 50-89%. Covered: 90% or more. Coverage measures playing time, not quality.
- **Re-sign candidates:** "Strong case" if his position is a Gap or Thin without him and he projects 2+ WAR; "Worth it at the right price" if the position is a Gap or Thin and he projects 0.5-2 WAR; "Replaceable" if the position is covered; "Let go" under 0.5 WAR. Contract length by age: 30 or under, multi-year; 31-34, one to two years; 35 and up, one year.
- **Player summary verdicts (per season):** Core piece (value at least $5M more than cost), Good value ($1M-$5M), Fair price (within $1M), Overpaid unless healthy (negative with expected playing time, positive over a full season), Overpaid (down to -$10M), Big overpay (worse than -$10M).
- **Free-agent board:** names matched to B-Ref IDs on a cleaned name (no accents, periods, or suffixes like Jr.) plus a 2027 age within one year, using seasons since 2023. Same projection and $/WAR as the Yankees' own players. Two prices: expected playing time, and a full healthy season. Buy-low flag: at least 2 WAR per full season but projected to play less than 60% of one. Players with a club, mutual, or player option or an opt-out are flagged as possibly not reaching free agency.
- **WAR is regular season only** and includes the standard positional penalty for designated hitters.

## Cleaning issues found
- 62 rows: 42 players + 20 non-player rows (blank spacers, payroll summaries, dead money notes), all with Name-additional = -9999. Filter on that sentinel.
- Every column was read as text; convert types after filtering.
- Money is stored as text ($40M, $22.02M, Arb (~$2.2M), Arb, FA). All dollar amounts are in millions.
- Pre-arb players have blank salaries; use $780,000.
- Blank salary cells mean two things: blank before any filled cell = pre-arb; blank after = no longer under team control.
- Service time is years.days, not a decimal.
- Yrs is seasons in MLB ("1st" = rookie), not contract length.
- Column names need quotes: "Name-additional", "Contract Status", "2026".
- Dead money rows (buyouts, releases, trades with cash): keep as a separate table so player costs reflect net cost to the Yankees. Negative amounts are cash coming back to the Yankees.
- Dead money descriptions repeat across six columns (one merged cell on the page); read it from Age.
- B-Ref's Dollars Committed appears to subtract the Stanton trade cash twice ($10M a year, 2026-2028). We count it once.
- The contracts page is stale in both directions: it doesn't add 2026 debuts, and it still lists players who were outrighted or are on minor league deals. Both are corrected with seeds checked against the current 40-man roster.
- The Appearances CSV export starts with a citation line and blank lines above the header; they're removed so the header is line 1. Its OF column is LF + CF + RF, so it's skipped.
- Some players go by nicknames (Kiké Hernández is Enrique Hernández on B-Ref). seeds/free_agents_2027.csv has a bref_name column for overrides.

## Risks and open questions
- One season of WAR is noisy (Judge: 66 games in 2026), so split rate from availability.
- Re-check 2026 row counts in the WAR files before any refresh.
- The dollars-per-WAR estimate drives every surplus value number; show results under a range of values.
- In the original 2025 backtest, projections missed by about 1.2 WAR per player-season (about $11M at $9.5M per WAR), so show values as ranges, not points.
- Calibration makes star pitchers conservative (before it, they delivered only about two-thirds of their projections, mostly because of injuries). The free-agent board also shows a price if healthy for that reason.
- WAR undervalues relievers relative to what teams pay them, so reliever fair prices run low. Use them to compare relievers with each other.
- A fair price is what a player is worth at $9.5M per WAR, not a prediction of the contract he'll sign.
- The free-agent list is as of Oct 8, 2026. Options and opt-outs will change who actually reaches the market.
- Service time for Ali Sánchez and Kervin Castro wasn't verified, so their control is only counted through 2027.
- Position depth uses 2026 usage; players who change positions in 2027 will shift the picture.
- Trade acquisitions' cost so far is an AAV estimate, not actual dollars.
- B-Ref says its 2026 total isn't an accurate payroll accounting (trades not prorated, new debuts not added, incentives not included), so a $2.49M gap in 2026 is accepted as a source limitation.

## Go / no-go
Go.
# Data Decisions
*Pulled: October 2026*

## Questions
1. 2026 snapshot: who gave the most and least value for their salary (rate vs availability)?
2. Contract retrospective: how are the big multi-year deals going so far?
3. Remaining surplus value: which contracts are assets or liabilities going forward?

## Sources
| Source | What it has | Seasons | Player IDs? | Decision |
|---|---|---|---|---|
| B-Ref WAR files (bat + pitch) | WAR, games, PA/IP, age, team for every player-season | 1871-2026 | Yes (`player_ID`) | Use for 2021-2026 WAR |
| B-Ref Yankees contracts page (manual CSV export) | 2026+ salaries, contract terms, service time, Arb/FA years, dead money, payroll summary | 2026-2032 | Yes (`Name-additional`, same as `player_ID`) | Use for salaries and team control |
| Chadwick register | ID crosswalk across sites | All | Yes | Not needed: B-Ref IDs match across both sources |
| Dollars per WAR estimate | Free agent cost per WAR | 2021-2025 | n/a | Range $8M-$11M; base case $9.5M ([FanGraphs method](https://tht.fangraphs.com/methodology-and-calculations-of-dollars-per-war/)) |

## Terms (Sports Reference, reviewed Oct 2026)
- Using and publishing data from individual pages is permitted with credit to Sports Reference as the source.
- Data is exported manually; no automated scraping.
- Raw files are kept out of the public repo (no bulk republishing).
- No AI or machine learning on this data; the projection is a fixed-weight statistical formula (Marcel-style).
- Every deliverable credits "Data: Baseball-Reference.com (Sports Reference LLC)".

## Validation
- WAR files cover 1871-2026 (batting: 126,547 rows; pitching: 57,884 rows).
- Full seasons 2021-2025 have ~1,600-1,700 batting rows; 2026 has 830, apparently because pitcher rows aren't added to the batting file yet. 2026 position player stats match the team page, and the pitching file's 2026 count (~1,000) matches past seasons, so 2026 is usable.
- Judge 2025 WAR matches his B-Ref page: Yes
- All 42 players in the contracts export match the WAR files on player ID.
- Parsed salaries plus dead money reconcile to B-Ref's Dollars Committed total for 2026-2032, after the documented items in seeds/payroll_reconciling_items.csv.

## Assumptions
- Pre-arb players with no listed salary: $780,000 (2026 league minimum)
- Arb (~$X) estimates come from Matt Swartz / MLB Trade Rumors' arbitration model, as shown on B-Ref.
- Service time format: years.days (172 days = 1 season)
- Dollars per WAR: $9.5M base case, tested at $8M (low) and $11M (high)

## Methodology
- **2026 snapshot uses 2026 cash salary.** The contract retrospective uses average annual value (AAV = total / years), the same basis as MLB's luxury tax, because salaries before 2026 aren't in the data. AAV also keeps back-loaded deals (like Fried's) from looking artificially cheap or expensive in a single year.
- **Only WAR earned as a Yankee counts.** A player acquired mid-season gets credit only for his time in New York.
- **Split-season costs are prorated** by the share of that season's playing time spent with the Yankees (PA for hitters, innings for pitchers). B-Ref doesn't prorate trades, so this corrects it.
- **Rate vs availability:** availability = share of a full season played (600 PA for hitters, 180 IP for starters, 65 IP for relievers). Rate = WAR per full season. Rate x availability = WAR.
- **Small samples** (under 20% of a full season) are kept in totals but not ranked on rate.
- **Excluded from the 2026 rankings:** players with no 2026 games for the Yankees (likely in the minors, joined after their 2026 games, or salary only estimated). Each has a labeled reason.
- **Contract years counted:** free agents from the first year of the contract; trade acquisitions from their first season as a Yankee. Seasons missed entirely to injury count as a full year of cost with 0 WAR.
- **2020** costs are scaled to 60/162 to match the shortened season's prorated pay.
- **Trade cash** tied to a player on the roster (e.g., the Marlins' payments on Stanton) reduces that player's cost.
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
- Dead money rows (buyouts, releases, trades with cash): keep as a separate table so player costs reflect
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
| Dollars per WAR estimate | Free agent cost per WAR | | n/a | FILL IN: figure + link |

## Terms (Sports Reference, reviewed Oct 2026)
- Using and publishing data from individual pages is permitted with credit to Sports Reference as the source.
- Data is exported manually; no automated scraping.
- Raw files are kept out of the public repo (no bulk republishing).
- No AI or machine learning on this data; the projection is a fixed-weight statistical formula (Marcel-style).
- Every deliverable credits "Data: Baseball-Reference.com (Sports Reference LLC)".

## Validation
- WAR files cover 1871-2026 (batting: 126,547 rows; pitching: 57,884 rows).
- Full seasons 2021-2025 have ~1,600-1,700 batting rows; 2026 has 830, apparently because pitcher rows aren't added to the batting file yet. 2026 position player stats match the team page, and the pitching file's 2026 count (~1,000) matches past seasons, so 2026 is usable.
- Judge 2025 WAR matches his B-Ref page: FILL IN yes/no
- All 42 players in the contracts export match the WAR files on player ID.

## Assumptions
- Pre-arb players with no listed salary: $780,000 (2026 league minimum)
- Service time format: years.days (172 days = 1 season)
- Dollars per WAR: FILL IN

## Cleaning issues found
- 62 rows: 42 players + 20 non-player rows (blank spacers, payroll summaries, dead money notes), all with Name-additional = -9999. Filter on that sentinel.
- Every column was read as text; convert types after filtering.
- Money is stored as text ($40M, $22.02M, Arb (~$2.2M), Arb, FA).
- Pre-arb players have blank salaries; use $780,000.
- Service time is years.days, not a decimal.
- Column names need quotes: "Name-additional", "Contract Status", "2026".
- Dead money rows (buyouts, releases, trades with cash): keep as a separate table so player costs reflect net cost to the Yankees.
- "Dollars Committed" summary row: use it to check that player salaries add up.

## Risks and open questions
- One season of WAR is noisy (Judge: 66 games in 2026), so split rate from availability.
- Re-check 2026 row counts in the WAR files before any refresh.
- The dollars-per-WAR estimate drives every surplus value number; show results under a range of values.

## Go / no-go
Go.
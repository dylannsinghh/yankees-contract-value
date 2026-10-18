# Yankees Contract Value

What public data says about the value of every Yankees player and contract, and what it means for the 2027 offseason. Built with dbt and DuckDB on Baseball-Reference data.

*Independent analysis using public data. Not affiliated with or endorsed by the New York Yankees or Major League Baseball.*

## What it answers
1. **2026 snapshot:** who gave the most and least value for his salary?
2. **Contract retrospective:** how are the big multi-year deals going so far?
3. **Remaining value:** which contracts are assets or liabilities from here?
4. **Roster value:** what is every player under team control worth per season, compared with what he costs?
5. **2027 outlook:** how many wins does the current roster project for, and where are the gaps?
6. **Offseason:** which of the Yankees' own free agents are worth bringing back, and who on the open market fills the gaps?

## Headline findings (October 2026)
- **The value is in the young core.** Per season, Cam Schlittler gives the team about $17.7M more value than he costs and Ben Rice about $11.5M. Seven more players under team control are worth at least $6M a season more than they cost.
- **The big contracts have cost about market price so far** (about $9.6M per WAR), but every one of them projects to lose value per season from here. Gerrit Cole (-$26.6M a season) and Max Fried (-$15.2M) are the largest. Aaron Judge, Ryan McMahon, and Giancarlo Stanton are "overpaid unless healthy": the issue is missed time, not talent.
- **Judge's deal has already paid for itself.** The remaining years project slightly over (about -$32M expected, +$15M if healthy), but the whole contract is still about +$64M.
- **2027 starts at about 88 wins** before any moves. Reaching 95 takes about 7 more wins, roughly $67M at market prices.
- **The gaps:** second base and center field in the lineup, and about 290 innings in the bullpen.
- **The offseason case:** fill second base (Jazz Chisholm on a longer deal or Brandon Lowe on a short one), upgrade center field (Daulton Varsho projects ahead of Trent Grisham), and add four or five relievers.

## How it works

    Baseball-Reference exports  +  MLB.com free-agent list
                |
            staging        clean and type every source, e.g. salaries parsed from text like "Arb (~$2.2M)"
                |
          intermediate     player-seasons, contract-seasons, projections, seasons under team control
                |
             marts         snapshot, retrospective, remaining value, roster value, 2027 outlook,
                |          position depth, re-sign candidates, player summary, free-agent board
                |
            exports        CSVs for the Tableau dashboard

## Method in brief
- **Value = projected WAR x dollars per win - cost.** Base case $9.5M per WAR, tested at $8M and $11M.
- **Projections:** Marcel-style (Tom Tango's method) applied to WAR and calibrated against 2023-2026 backtests. It's a fixed, explainable formula, not machine learning.
- **Rate vs availability:** how good a player is per full season is kept separate from how much he plays, so an injured star doesn't read as a bad player.
- **Per season, not totals,** when comparing players with different years of control.
- **Expected and healthy cases:** expected playing time prices in injury risk; healthy assumes a full season.
- Every decision, source, and assumption is in [docs/data_decisions.md](docs/data_decisions.md).

## Testing
98 dbt tests run on every build, plus checks against known answers. Highlights:
- Parsed salaries plus dead money reconcile to Baseball-Reference's payroll total, and every gap is documented in a seed with a status (a warning fires while any gap is unexplained).
- WAR totals reconcile from the source files to the player-season model.
- The roster model and the contract model produce identical numbers for the same seven contracts.
- The wins formula reproduces the 2026 season: 94.9 implied wins vs 93 actual.
- Every free agent matches exactly one player ID, or gets flagged.

## Run it yourself
Raw data isn't included in this repo. Export these from Baseball-Reference into `data/raw/`:
- `war_daily_bat.txt` and `war_daily_pitch.txt` (Baseball-Reference WAR data files)
- `nyy_contracts_2026.csv` (Yankees contracts page, exported as CSV)
- `nyy_appearances_2026.csv` (2026 Yankees Appearances table, exported as CSV with player IDs)

Then:

    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    dbt build

The tables for the dashboard land in `exports/`.

## Project structure

    models/staging/       one model per source
    models/intermediate/  player-seasons, contracts, projections, team control, free-agent matching
    models/marts/         the answers, one table per question
    models/exports/       CSV exports for Tableau
    seeds/                hand-checked inputs: roster additions and removals, reconciling items, free-agent list
    tests/                reconciliation and data-quality tests
    analyses/             profiling, diagnostics, and calibration backtests
    scripts/              calibrate_regression.sh reruns the model under different settings
    docs/                 data_decisions.md

## Limitations
- WAR is regular season only, penalizes designated hitters, and undervalues relievers. Baseball-Reference's pitcher WAR is based on runs allowed.
- Calibration makes star pitchers conservative on purpose, so the free-agent board also shows a price if healthy.
- Arbitration salaries without a published estimate are modeled at 60% of projected value.
- A fair price is what a player is worth, not a prediction of the contract he'll sign.

## Next steps
- Project offense and defense separately, as ZiPS and Steamer do.
- Run sensitivity checks across the key assumptions.
- Finish the Tableau dashboard and the summary deck.

## Data and credit
Data: Baseball-Reference.com (Sports Reference LLC). Free-agent list: MLB.com, "All of the 2026-2027 free agents, position by position" (October 8, 2026).

Built by Dylan Singh, MS in Information Systems and Operations Management, University of Florida.
# Yankees Contract Value

What public data says about the value of every Yankees player and contract, and what it means for the 2027 offseason. Built with dbt and DuckDB on Baseball-Reference data, with a Tableau Public dashboard on top.

**Dashboard:** [Yankees 2027: What Public Data Says](https://public.tableau.com/app/profile/dylan.singh/viz/YANKEESFINAL/StartHere) (best viewed full screen)

*Independent analysis using public data. Not affiliated with or endorsed by the New York Yankees or Major League Baseball.*

## What it answers
1. **2026 snapshot:** who gave the most and least value for his salary?
2. **Contract retrospective:** how are the big multi-year deals going so far?
3. **Remaining value:** which contracts are assets or liabilities from here?
4. **Roster value:** what is every player under team control worth per season, compared with what he costs?
5. **2027 outlook:** how many wins does the current roster project for, and where are the gaps?
6. **Offseason:** which of the Yankees' own free agents are worth bringing back, and who on the open market fills the gaps?

## Headline findings (October 2026)
- **The value is in the young core.** Nine players are each worth $6M to $18M a season more than they cost, led by Cam Schlittler (+$17.7M a season) and Ben Rice (+$11.5M).
- **The big contracts have broken even so far, but they're underwater from here.** Across the seven multi-year deals: about +$5M so far, and about -$229M from here (-$103M if everyone stays healthy).
  - Aaron Judge has already paid for himself: +$96M so far and +$64M over the whole deal.
  - Giancarlo Stanton is the biggest loss (-$101M), but $93M of it is already spent.
  - The forward risk is Max Fried (-$91M still ahead) and Gerrit Cole (-$53M).
- **2027 starts at about 88 wins** before any moves. Reaching 95 takes about 7 more wins, roughly $67M at market prices.
- **The real needs:** second base (1.7 WAR below an average starter), the bullpen (about 300 innings with no one projected to throw them, with six relievers heading to free agency), and about 100 innings from the rotation. The rotation's quality is already above average. Center field looks short only because of how players were used in 2026; the outfield as a whole has 111% of the playing time it needs.
- **The offseason case:** Brandon Lowe on a short deal or Jazz Chisholm on a longer one at second, two or three relievers such as Adrian Morejon and Sean Newcomb, and a durable starter such as Trevor Rogers or Freddy Peralta (or a buy-low like Kris Bubic). Bringing every weak spot up to an average starter costs about $45M.
- **Value is not market price.** These numbers say what a player is worth at $9.5M per win, not what he'll sign for. Aces like Tarik Skubal usually sign for well above that.

## The dashboard
1. **Start here:** what's inside, the short version, and how to read WAR.
2. **Value per season:** worth minus cost for all 32 players under team control, with a verdict and a one-line reason for each.
3. **Where the gaps are:** how much of each position's 2027 playing time the current roster covers, and how far short of an average starter each spot is.
4. **Who can fill the gaps:** the best free agents at each weak spot who will actually reach the market, with expected and healthy values.
5. **The big contracts:** what's already happened and what's still ahead on each of the seven deals.

## How it works

    Baseball-Reference exports  +  MLB.com free-agent list
                |
            staging        clean and type every source, e.g. salaries parsed from text like "Arb (~$2.2M)"
                |
          intermediate     player-seasons, contracts, projections, seasons under team control,
                |          playing time by position, free-agent name matching
                |
             marts         snapshot, retrospective, remaining value, roster value, 2027 outlook,
                |          position depth, re-sign candidates, player summary, free-agent board
                |
            exports        CSVs for the Tableau dashboard

## Method in brief
- **Value = projected WAR x dollars per win - cost.** Base case $9.5M per WAR, tested at $8M and $11M.
- **Projections:** Marcel-style (Tom Tango's method) applied to WAR and calibrated against 2023-2026 backtests. It's a fixed, explainable formula, not machine learning.
- **Rate vs availability:** how good a player is per full season is kept separate from how much he plays, so an injured star doesn't read as a bad player.
- **Expected and healthy cases:** expected playing time prices in injury risk; healthy assumes a full season.
- **Per season, not totals,** when comparing players with different years of control.
- **Position gaps:** each hitter's projected playing time is split across positions the way he was used in 2026, then compared with what a team needs (about 689 plate appearances per lineup spot, 860 starter innings, 590 bullpen innings) and with what an average starter produces (about 2 WAR per 600 plate appearances).
- **Free agents:** MLB.com's list is matched to Baseball-Reference IDs by cleaned name and age, then projected with the same model as the Yankees' own players. Players with options or opt-outs are flagged, since they may never reach the market.
- Every decision, source, and assumption is in [docs/data_decisions.md](docs/data_decisions.md).

## Testing
98 dbt tests run on every build (135 nodes in all), plus checks against known answers. Highlights:
- Parsed salaries plus dead money reconcile to Baseball-Reference's payroll total, and every gap is documented in a seed with a status (a warning fires while any gap is unexplained).
- WAR totals reconcile from the source files to the player-season model.
- The roster model and the contract model produce identical numbers for the same seven contracts.
- The wins formula reproduces the 2026 season: 94.9 implied wins vs 93 actual.
- Projected 2027 playing time for hitters (6,310 plate appearances) lands close to what a team actually uses (about 6,200), after correcting the contracts page for missing debuts and players who had left the 40-man roster.
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
    macros/               reusable SQL: money parsing, name cleaning
    tests/                reconciliation and data-quality tests
    analyses/             profiling, diagnostics, and calibration backtests
    scripts/              calibrate_regression.sh reruns the model under different settings
    docs/                 data_decisions.md

## Limitations
- WAR is regular season only, penalizes designated hitters, and undervalues relievers. Baseball-Reference's pitcher WAR is based on runs allowed.
- Calibration makes star pitchers conservative on purpose, so the free-agent board also shows a value if healthy.
- Arbitration salaries without a published estimate are modeled at 60% of projected value.
- Position depth uses 2026 usage; players who change positions will shift the picture.
- The age adjustment is gentle for players 33 and older and hasn't been calibrated by age group yet.
- The free-agent list is as of October 8, 2026. Options and opt-outs will change who reaches the market.

## Next steps
- Project offense and defense separately, as ZiPS and Steamer do.
- Calibrate the aging adjustment by age group.
- Run sensitivity checks across the key assumptions.
- A short summary deck.

## Data and credit
Data: Baseball-Reference.com (Sports Reference LLC). Free-agent list: MLB.com, "All of the 2026-2027 free agents, position by position" (October 8, 2026).

Built by Dylan Singh, MS in Information Systems and Operations Management, University of Florida.
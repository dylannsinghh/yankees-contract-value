#!/bin/bash
# Tries different regression amounts for the projection and prints a one-line
# calibration summary for each. Hitters and pitchers use separate settings,
# so each loop changes only one of them.
set -e

echo "=== Hitters: marcel_regression_pa (read the hitter row) ==="
for pa in 1200 2400 3600; do
  echo "--- marcel_regression_pa = $pa"
  dbt run --select int_marcel_projections --vars "{marcel_regression_pa: $pa}" --quiet
  dbt show --select marcel_calibration_summary --quiet
done

echo "=== Pitchers: marcel_regression_ip (read the pitcher row) ==="
for ip in 180 360 540 720; do
  echo "--- marcel_regression_ip = $ip"
  dbt run --select int_marcel_projections --vars "{marcel_regression_ip: $ip}" --quiet
  dbt show --select marcel_calibration_summary --quiet
done

# Put the model back on the settings in dbt_project.yml
dbt run --select int_marcel_projections --quiet
echo "Done. Model restored to dbt_project.yml settings."
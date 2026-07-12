-- Baseline: date-filtered query on the raw public table (unpartitioned).
-- DRY RUN this and note the estimated bytes. It scans the whole table
-- even though we only want one month.

SELECT
  DATE(trip_start_timestamp) AS trip_date,
  COUNT(*) AS trips,
  ROUND(SUM(fare), 2) AS total_fare
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01')
GROUP BY trip_date
ORDER BY trip_date;

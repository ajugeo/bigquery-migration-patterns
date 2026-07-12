-- Prove pruning. Same one-month query, now against the partitioned twin.
-- Dry-run: the estimate drops from the full table to roughly one month
-- of partitions.

SELECT
  DATE(trip_start_timestamp) AS trip_date,
  COUNT(*) AS trips,
  ROUND(SUM(fare), 2) AS total_fare
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01')
GROUP BY trip_date
ORDER BY trip_date;

-- Clustering probe. Add an equality filter on the first clustering column.
-- The ESTIMATE will look the same as above; clustering savings only show
-- in bytes billed after the query actually runs. Compare the two job stats.

SELECT
  DATE(trip_start_timestamp) AS trip_date,
  COUNT(*) AS trips,
  ROUND(SUM(fare), 2) AS total_fare
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01')
  AND payment_type = 'Cash'
GROUP BY trip_date
ORDER BY trip_date;

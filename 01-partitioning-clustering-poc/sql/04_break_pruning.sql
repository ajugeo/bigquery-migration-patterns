-- Four ways to defeat partition pruning while still "filtering by date".
-- Dry-run each one against the twin and watch the estimate stay big.

-- 1. A function BigQuery cannot fold wrapped around the partition column.
--    The filter is logically one month; the estimate is the whole table.
SELECT COUNT(*)
FROM poc.taxi_trips_2023
WHERE FORMAT_TIMESTAMP('%Y-%m', trip_start_timestamp) = '2023-06';

-- 2. The filter arrives through a join instead of a literal.
--    The optimizer cannot use it for estimate-time pruning.
WITH wanted_dates AS (
  SELECT d
  FROM UNNEST(GENERATE_DATE_ARRAY('2023-06-01', '2023-06-30')) AS d
)
SELECT COUNT(*)
FROM poc.taxi_trips_2023 t
JOIN wanted_dates w
  ON DATE(t.trip_start_timestamp) = w.d;

-- 3. OR across the partition column and another column.
--    Because the OR can match any partition, nothing is pruned.
SELECT COUNT(*)
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
   OR payment_type = 'Cash';

-- 4. Non-constant subquery filter. This one may still prune at RUNTIME,
--    but the dry-run estimate shows the full table, which is exactly how
--    it slips through a review that only checks estimates.
SELECT COUNT(*)
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= (SELECT TIMESTAMP('2023-06-01'));

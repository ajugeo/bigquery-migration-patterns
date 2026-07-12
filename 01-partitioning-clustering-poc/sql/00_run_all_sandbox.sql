-- Sandbox-safe one-shot. Use this version in the free BigQuery sandbox.
--
-- Why it exists: the sandbox force-expires time-based partitions older than
-- 60 days, and expiration follows the PARTITION DATE, not creation time.
-- Partition historical data by date in the sandbox and every partition
-- expires the moment it is written; the table looks fine and is empty.
-- Integer-range partitioning has no time-based expiration, so the same
-- experiment survives. Outside the sandbox, 00_run_all.sql is the
-- realistic date-partitioned version.

CREATE SCHEMA IF NOT EXISTS poc;

-- DROP first: CREATE OR REPLACE cannot change an existing table's
-- partitioning spec, so a leftover date-partitioned twin from a previous
-- attempt blocks the range-partitioned one with an "Invalid value" error.
DROP TABLE IF EXISTS poc.taxi_trips_2023;

-- The twin: partitioned by an integer month key, clustered.
CREATE OR REPLACE TABLE poc.taxi_trips_2023
PARTITION BY RANGE_BUCKET(trip_month, GENERATE_ARRAY(202301, 202313, 1))
CLUSTER BY payment_type, company
AS
SELECT
  t.*,
  CAST(FORMAT_TIMESTAMP('%Y%m', trip_start_timestamp) AS INT64) AS trip_month
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips` t
WHERE trip_start_timestamp >= TIMESTAMP('2023-01-01')
  AND trip_start_timestamp <  TIMESTAMP('2024-01-01');

-- Sanity check: the twin must not be empty. If this says 0, stop here.
SELECT 'poc_probe_twin_row_check' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023;

-- Probe 1: date filter on the raw, unpartitioned table.
SELECT 'poc_probe_baseline_raw' AS probe, COUNT(*) AS trips
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01');

-- Probe 2: filter on the partition column. Pruned.
SELECT 'poc_probe_twin_pruned' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023
WHERE trip_month = 202306;

-- Probe 3: partition filter plus the first clustering column.
SELECT 'poc_probe_twin_clustered' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023
WHERE trip_month = 202306
  AND payment_type = 'Cash';

-- Probe 4: the same June, but filtered on the timestamp instead of the
-- partition column. Logically identical rows; the optimizer cannot prune,
-- so it scans the whole twin. The lesson: pruning only works when the
-- filter hits the partition column itself.
SELECT 'poc_probe_twin_no_prune' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01');

-- The report: bytes processed and billed per probe, from job metadata.
SELECT
  REGEXP_EXTRACT(query, r'poc_probe_(\w+)') AS probe,
  ROUND(total_bytes_processed / POW(1024, 3), 3) AS gb_processed,
  ROUND(total_bytes_billed   / POW(1024, 3), 3) AS gb_billed
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND query LIKE '%poc_probe_%'
  AND query NOT LIKE '%INFORMATION_SCHEMA%'
ORDER BY creation_time;

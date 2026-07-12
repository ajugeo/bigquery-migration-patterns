-- Single-paste version of the whole experiment.
-- Builds the twin, runs all four probes, then reports bytes processed and
-- billed per probe straight from BigQuery's own job metadata.
--
-- Run in a PERSONAL project (sandbox is fine). Total scan budget is roughly
-- 160 GB, well inside the 1 TB/month free tier. Individual files 01-04 exist
-- for stepping through by hand with dry runs; this script is the one-shot.

CREATE SCHEMA IF NOT EXISTS poc;

-- Build the partitioned, clustered twin (one full scan of the source).
CREATE OR REPLACE TABLE poc.taxi_trips_2023
PARTITION BY DATE(trip_start_timestamp)
CLUSTER BY payment_type, company
AS
SELECT *
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`
WHERE trip_start_timestamp >= TIMESTAMP('2023-01-01')
  AND trip_start_timestamp <  TIMESTAMP('2024-01-01');

-- Probe 1: date filter on the raw, unpartitioned table. Scans everything.
SELECT 'poc_probe_baseline_raw' AS probe, COUNT(*) AS trips
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01');

-- Probe 2: same filter on the twin. Partition pruning kicks in.
SELECT 'poc_probe_twin_pruned' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01');

-- Probe 3: add an equality filter on the first clustering column.
SELECT 'poc_probe_twin_clustered' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023
WHERE trip_start_timestamp >= TIMESTAMP('2023-06-01')
  AND trip_start_timestamp <  TIMESTAMP('2023-07-01')
  AND payment_type = 'Cash';

-- Probe 4: function wrapped around the partition column. Pruning defeated;
-- logically the same month, but watch the bytes.
SELECT 'poc_probe_twin_function_wrapped' AS probe, COUNT(*) AS trips
FROM poc.taxi_trips_2023
WHERE FORMAT_TIMESTAMP('%Y-%m', trip_start_timestamp) = '2023-06';

-- The report: this script's own child jobs, bytes processed and billed.
SELECT
  REGEXP_EXTRACT(query, r'poc_probe_(\w+)') AS probe,
  ROUND(total_bytes_processed / POW(1024, 3), 2) AS gb_processed,
  ROUND(total_bytes_billed   / POW(1024, 3), 2) AS gb_billed
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND query LIKE '%poc_probe_%'
  AND query NOT LIKE '%INFORMATION_SCHEMA%'
ORDER BY creation_time;

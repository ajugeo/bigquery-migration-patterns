-- One-time setup: one year of data, partitioned by day, clustered.
-- This scans the full source table once. Dry-run first and check the
-- estimate against your budget or free tier before running for real.

CREATE SCHEMA IF NOT EXISTS poc;

CREATE OR REPLACE TABLE poc.taxi_trips_2023
PARTITION BY DATE(trip_start_timestamp)
CLUSTER BY payment_type, company
AS
SELECT *
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`
WHERE trip_start_timestamp >= TIMESTAMP('2023-01-01')
  AND trip_start_timestamp <  TIMESTAMP('2024-01-01');

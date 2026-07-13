-- Template: windowed incremental fact load with working-table staging.
-- Generic names; adapt the business logic, keep the shape.

-- 1. Changed keys: fixed rolling window on the CHANGE timestamp.
--    (Profile the column first; validity timestamps look the same and are not.)
CREATE TEMP TABLE changed_keys AS
SELECT DISTINCT natural_key
FROM source_events
WHERE change_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY);

-- 2. Working table: always start empty. Rerun-safe by construction.
TRUNCATE TABLE stage.fact_example_wrk;

-- 3. Stage the fully prepared rows for the changed keys only.
--    Dedup to the grain with a deterministic tie-break.
INSERT INTO stage.fact_example_wrk
SELECT
  e.natural_key,
  e.source_system,
  -- ... business columns, fully derived here, not in the target load ...
  CURRENT_TIMESTAMP() AS load_ts
FROM source_events e
JOIN changed_keys c USING (natural_key)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY e.natural_key
  ORDER BY e.change_ts DESC, e.event_id DESC  -- deterministic
) = 1;

-- 4. Scoped delete: only this load's slice, only the changed keys.
DELETE FROM core.fact_example t
WHERE t.source_system = 'SRC_A'
  AND t.natural_key IN (SELECT natural_key FROM changed_keys);

-- 5. Load the target from the working table only.
INSERT INTO core.fact_example
SELECT * FROM stage.fact_example_wrk;

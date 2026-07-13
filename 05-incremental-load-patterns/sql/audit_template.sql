-- Template: the one-row audit contract for a windowed incremental load.
-- src_count = what the load prepared; tgt_count = what the target received
-- for this load's slice. PASS iff equal.

SELECT
  (SELECT COUNT(*)
     FROM stage.fact_example_wrk) AS src_count,
  (SELECT COUNT(*)
     FROM core.fact_example
    WHERE source_system = 'SRC_A'
      AND DATE(load_ts) = CURRENT_DATE()) AS tgt_count;

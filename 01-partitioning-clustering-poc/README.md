# Partitioning and clustering, measured

Goal: not "partitioning is good" from a blog post, but actual bytes-scanned numbers from an experiment, including the ways pruning silently fails.

Uses `bigquery-public-data.chicago_taxi_trips.taxi_trips`: large, unpartitioned, and it has a timestamp column, which makes it a good stand-in for a typical fact table before anyone thought about layout.

Dry runs are free. In the console the estimate appears at the top right before you run. From the CLI: `bq query --dry_run --use_legacy_sql=false < file.sql`.

## The experiment

Two ways to run it:

**One-shot:** paste `sql/00_run_all.sql` into the console and run it once. It builds the twin, runs all four probes, and its final statement reports bytes processed and billed per probe from BigQuery's own job metadata. Total scan budget is roughly 160 GB, well inside the free tier.

**In the free sandbox, use `sql/00_run_all_sandbox.sql` instead.** Found the hard way: the sandbox force-expires time-based partitions older than 60 days, and expiration follows the partition date, not creation time. Partition historical data by date there and every partition expires the moment it is written. The table looks fine, has a schema, and is silently empty; the pruned probes all return 0 rows and 0 bytes. The sandbox script partitions by an integer month key instead (range partitioning has no time-based expiration), which keeps the whole experiment intact.

**Step by step**, if you want to watch the dry-run estimates move (the estimator has its own lessons; see the decision note):

1. `sql/01_measure_baseline.sql` - a one-month query on the raw public table. Dry-run it and record the estimate. Expect the full table size: no partitioning means a date filter scans everything.
2. `sql/02_build_partitioned_twin.sql` - copies one year into your own dataset, partitioned by day and clustered. This scans the source once, so check the estimate before running and stay inside your budget or free tier.
3. `sql/03_prove_pruning.sql` - the same one-month query against the twin, then the same query plus a clustering-column filter. Bytes drop to roughly the partitions touched. Note: the estimator shows partition pruning but not clustering savings; for clustering, compare bytes billed after the run.
4. `sql/04_break_pruning.sql` - four query shapes that quietly defeat pruning. The estimates stay near full size even though every query "filters by date".

## My results

| Probe | GB processed | GB billed |
| --- | --- | --- |
| baseline_raw: one month, raw unpartitioned table | (fill) | (fill) |
| twin_pruned: same month, partitioned twin | (fill) | (fill) |
| twin_clustered: month plus payment_type filter | (fill) | (fill) |
| twin_no_prune: filter misses the partition column | (fill) | (fill) |

## Decision note

What I take into design reviews after running this:

- Partition on the column nearly every query filters by. Usually the event date. You get one partition column per table, so choose it for the dominant access pattern, not the edge case.
- Clustering is the second-tier filter and is cheap to add (up to 4 columns). Put the most commonly filtered column first; order matters.
- Small tables (roughly under 1 GB) get neither. The overhead beats the benefit and the estimator will prove it to you.
- Partition count has a hard limit (10,000 per table as of writing). Daily partitions cover decades. Hourly partitions on years of history do not.
- Consider `require_partition_filter = TRUE` on big tables so nobody full-scans by accident. It turns an expensive mistake into an error message.
- The estimator cannot see clustering benefits or runtime pruning from dynamic filters. Judge those by bytes billed after the run, never by the estimate alone.
- Pruning breakers to watch for in code review: functions wrapped around the partition column that BigQuery cannot fold, filters that arrive through a join, OR conditions that mix the partition column with another column, and non-constant subquery filters. The last kind may still prune at runtime, but the estimate will not show it, which is exactly how it sneaks past review.

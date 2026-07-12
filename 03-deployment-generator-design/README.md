# A deployment generator for 100+ SQL files

Design note for a small Python script that turned a folder tree of SQL into deployable artifacts. Pattern only; the code here is illustrative, not the production tool.

## The problem

A warehouse migration grows into DDL, one-time backfills, daily incremental scripts, views and audit queries. Past a certain point that is over a hundred SQL files with real ordering dependencies: tables before backfills, dimensions before facts, base views before the views that read them. Running them by hand in the right order stops scaling at around file twenty.

Three constraints shaped the design:

1. BigQuery's query size limit (about 1 MB unresolved), so one concatenated script will not fit forever.
2. Two different consumers: a dev UI where humans paste SQL with hardcoded names, and an orchestration bundle where everything must be parameterized for promotion across environments.
3. Zero tolerance for silent drops. A file that never runs is worse than a build failure, because nothing tells you.

## Design decisions

- Source folders are the single truth. The generator reads them and writes an output folder that is generated, never hand-edited.
- Explicit ordering list per phase, in the script. Any .sql file not on the list is still appended, sorted, with a loud WARNING in the build output. New files cannot vanish; they can only show up flagged.
- Size-based splitting happens only at whole-file boundaries, under a byte budget per part. A statement split mid-file is a corrupted deployment.
- Environment substitution is a declared map (dev names to parameter placeholders), not scattered string replaces. After substitution the build scans for any surviving environment-specific string and hard-fails if one remains. This single check has caught every "forgot to parameterize" mistake.
- Standard library only. A deployment tool that needs its own dependency management defeats the point of having one.

The shape of it:

```python
PHASES = {
    "01_ddl":       ["dim_customer.sql", "fact_orders.sql", ...],   # explicit order
    "02_backfill":  [...],
    "03_dims":      [...],
    "04_facts":     [...],
    "05_views":     [...],
}

SUBS = {
    "my-dev-project":  "{{params.project_id}}",
    "core_dataset":    "{{params.core_dataset}}",
}

# 1. collect files per phase; anything unlisted appends sorted, with a WARNING
# 2. concatenate under a byte budget, splitting only at file boundaries
# 3. apply SUBS for the promotion bundle
# 4. hard-fail if any dev-only string survives substitution
```

## What I would change next time

Parameterize from day one. Hardcoded dev names felt faster at the start and cost a full retrofit pass later. And generate a manifest with every build (file, phase, position, byte size); you end up wanting exactly that table in every deployment review anyway.

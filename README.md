# bigquery-migration-patterns

Working notes and runnable experiments from real SQL Server to BigQuery migration work. Client specifics are stripped out; the patterns are the part worth keeping.

Everything runnable here uses BigQuery public datasets, so you can execute it in any project. Dry runs are free.

## Contents

| Folder | What it is |
|--------|------------|
| [01-partitioning-clustering-poc](01-partitioning-clustering-poc/) | Measure, build, prove, then deliberately break partition pruning. With bytes-scanned numbers from my runs. |
| [02-sqlserver-to-bigquery-checklist](02-sqlserver-to-bigquery-checklist/) | The checklist I wish I had on day one of the migration. Every item cost something to learn. |
| [03-deployment-generator-design](03-deployment-generator-design/) | Design note: turning 100+ SQL files into ordered, size-safe, parameterized deployments with a small Python script. |
| [04-star-schema-grain-notes](04-star-schema-grain-notes/) | Grain decisions from a multi-source star schema, and the probe that guards them. |
| [05-incremental-load-patterns](05-incremental-load-patterns/) | The working-table load pattern: change windows, scoped deletes, full-refresh dims, and the one-row audit contract. With templates. |

More gets added as I finish things. A topic lands here when there is an artifact, not when I have watched a video about it.

## Who

Ajin G Thomas. Data Architect at ZineMind Technologies, working on healthcare data platforms.

LinkedIn: [linkedin.com/in/ajin-g-thomas](https://www.linkedin.com/in/ajin-g-thomas)

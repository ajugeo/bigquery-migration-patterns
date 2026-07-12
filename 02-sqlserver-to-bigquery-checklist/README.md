# SQL Server to BigQuery: the checklist

The checklist I wish I had on day one of a warehouse migration. Every item here cost something to learn. Sanitized from real project work; no client specifics, the patterns are general.

## Before converting anything

- Inventory the stored procedures and classify each one: convert verbatim, redesign, or retire. Verbatim conversion with parity checks is far safer than improving while migrating. Improve after parity, never during.
- Prove the natural key of every table you will load. Actually run the duplicate check; do not trust the documentation or the primary key definition. Most grain bugs trace back to a wrong assumption someone made here.
- Find out which timestamp column actually tracks change. Columns that look like change timestamps are sometimes effective-dating or validity markers, and the live row can carry a far-future value. Window your incrementals on the wrong one and you reprocess nothing, or everything.

## Semantics that silently differ

- Case sensitivity. SQL Server with a case-insensitive collation joins 'ABC' to 'abc'. BigQuery does not. Every string join key needs a decision: normalize with UPPER(TRIM(...)) or prove the case is consistent.
- Empty strings. Guard with NULLIF(x, '') before normalizing join keys. Blank joining to blank fans out; one unguarded key can multiply a result set by thousands before anyone notices.
- Trailing spaces. SQL Server treats 'a' and 'a ' as equal in comparisons. BigQuery does not. TRIM at the boundary.
- Integer division. 1/2 is 0 in T-SQL and 0.5 in BigQuery. Financial and ratio logic converted verbatim will quietly change values.
- CONCAT and NULL. T-SQL CONCAT treats NULL as empty string; BigQuery CONCAT returns NULL if any argument is NULL. Wrap with IFNULL or COALESCE where the old behavior mattered.
- DATETIME vs TIMESTAMP. Decide the storage timezone policy once (UTC in storage is the normal answer) and be explicit at every boundary where a business-local date is derived. A daily count by UTC date and by business-local date disagree around midnight; know which one each report means.

## Rewriting the code

- #temp tables become TEMP TABLE inside scripts. Watch the scope; they live for the script or session, not the connection pattern you had before.
- Dedup with QUALIFY ROW_NUMBER() OVER (PARTITION BY natural_key ORDER BY tie_break). Make the tie-break deterministic. "Whatever ROW_NUMBER happens to pick" shows up as a diff in every parity run afterwards.
- MERGE errors at runtime if the source matches a target row more than once. Dedup the source to the ON key first, always, even when you are sure it is unique.
- Explicit column lists everywhere. SELECT * breaks silently when schemas drift, and schemas drift.

## Incremental design

- Fixed change windows (say, 3 days on a change timestamp) are simple and predictable. The price: late-arriving data outside the window is missed. Say this trade-off out loud and get it accepted; do not let it be discovered later.
- Stage the final prepared rowset into a working table, then load the target from it. Reruns become safe (truncate the working table at the top of every run) and your audits can count exactly what the load prepared.
- Scope every DELETE to the changed keys and the source being loaded. A DELETE scoped wider than the rows you are about to re-insert is a data loss bug waiting for a partial failure.

## Validation

- Parity gate: EXCEPT DISTINCT in both directions, excluding volatile columns like load timestamps. Zero rows both ways or it is not done.
- Track unknown-member foreign keys (the -1 rows) before and after every dimension change. An increase means the dimension no longer covers members the facts derive. This catches starvation that row counts never show.
- Never reconcile raw source row counts to target counts. Grain changes, filters and synthetic rows make the comparison meaningless, and it will "fail" forever until someone turns it off, which is worse than no check. Audit the staged set against the target instead: one row, src_count vs tgt_count, pass only on equality.

## Deployment and operations

- BigQuery has a query size limit (about 1 MB unresolved). A concatenated deployment script hits it sooner than you expect. Split at whole-file boundaries.
- Keep environment names out of the SQL you promote. Parameterize projects and datasets, and make the build fail if a hardcoded environment string survives substitution. The grep is one line and it catches the mistake every time.
- Generated deployment output is never hand-edited. The moment someone edits generated output, there are two sources of truth and no way to tell which one is lying.

# Incremental load patterns that survive reruns

The load pattern I use for warehouse facts and dimensions, shaped by production incidents rather than theory. Generic names; real decisions. A template lives in `sql/`.

## The working-table pattern

Every incremental load stages its final, fully prepared rowset into a working table, then loads the target only from that table. First statement of every run: TRUNCATE the working table.

Three things this buys:

- Reruns are safe. A failed run leaves the working table in whatever state; the next run truncates and starts clean.
- The audit can count exactly what the load prepared, not an approximation reconstructed from the source.
- Debugging means selecting from the working table, not re-deriving what the load probably staged.

One working table per load script, even when several scripts feed the same target. Sharing looks tidy, but if two loads can write overlapping key slices, a shared working table makes scoped deletes unsafe. We learned this where two source feeds legitimately wrote the same source identifier; per-script working tables ended the ambiguity.

## Change detection: a fixed window on the right column

The shape: distinct changed keys from an N-day rolling window on the change timestamp, then a DELETE scoped to those keys and this load's slice, then insert or merge from the working table.

Two hard-won rules:

- Make sure the column is actually a change timestamp. Validity and effective-dating columns look identical in a schema listing, and the live row can carry a far-future value. Window on the wrong one and you reprocess everything, or nothing. Profile the column before trusting its name.
- Late-arriving data outside the window is missed by design. Say it out loud and get the trade-off accepted; a wider window costs compute, a narrower one misses more. The worst version is the team discovering the gap in production.

## Facts get windows, dimensions get full refresh

A split we landed on after incidents, not from a book. Windowed dimension builds starve: one environmental failure eats the window, the missed member never returns, and the facts point at unknown members forever. A full candidate rebuild every run means any miss self-heals on the next run. The daily compute cost is real and we accepted it.

Facts keep their windows because fact volume makes daily full rebuilds unaffordable, and a missed fact row is recoverable by an explicit backfill.

Consequence worth documenting: under full refresh, the dimension's load timestamp is re-stamped every run and stops meaning "changed recently". Anyone using it as a change signal needs to know.

## MERGE vs delete-and-insert

Both work. MERGE when in-place update semantics matter, for example preserving original created timestamps and surrogate keys on existing members. Delete-and-insert when rows are wholly rebuilt anyway. Either way, dedup the source to the join key first: BigQuery's MERGE errors at runtime the day the source produces a duplicate, which is always a day you had other plans.

## The audit contract

Every load job answers one question: did the target receive exactly what the load prepared? One row, two columns:

```text
src_count = rows staged into the working table
tgt_count = rows in the target for this load's slice
PASS iff equal
```

Never reconcile raw source row counts to target counts. Grain changes, filters and derived rows make that comparison meaningless, and a check that fails forever gets turned off, which is worse than no check. Delete-only jobs get audited too: keys staged for deletion vs keys confirmed absent from the target.

# Grain decisions in a multi-source star schema

Notes from designing a star schema that unifies the same business process from four different source systems. Names and domain details here are generic; the decisions and the incidents behind them are real.

## Declare the grain first, in writing

One sentence per table, before any SQL: "one row per X". Every defect class I have debugged in dimensional models traces back to someone's unstated assumption about what one row means. Write the sentence, put it in the table's header comment, and test it (see the probe at the bottom).

## Event grain and current-state grain are both worth keeping

An event-grain fact ("one row per status change") answers what happened. A current-state fact ("one row per entity per source") answers where things stand. Deriving current state from events at query time pushes window functions into every report and every consumer gets it slightly differently wrong. Load the event fact first, derive the current-state fact from it once, in the pipeline, and let reports read the simple table.

## Natural keys are per source system

The same id in two source systems can be two different real-world things. Every natural key carries the source system as a component: (source_system, natural_id). The quiet benefit: a load can only ever overwrite rows belonging to its own source, so a uniform full-refresh pattern is safe by construction.

## When the same id means two things, the key grows

Real case: a source reused one reason-code id for both cancellations and reschedules, with different meanings. The dimension key had to include the reason type, making them distinct members.

And the exception that cost a production incident: one source system kept a single shared code pool with no type split. Looking its codes up WITH the type filter returned nothing, and the facts flooded with unknown members. The fix was a documented exception: that source's lookup is type-agnostic, and the code says so loudly. Rule of thumb: model the key the source actually has, not the key the other sources made you expect.

## Every dimension has an unknown member, and its rate is a health metric

Foreign keys in facts are never NULL; a failed lookup points at the -1 member. The useful part is monitoring: count the -1 foreign keys per dimension before and after every change. A rising unknown rate is the earliest signal that a dimension stopped covering members the facts derive. Row counts and job successes both look fine while this is happening; only the -1 delta shows it.

## Dedup to the natural key before staging, deterministically

Candidate sets get deduped to the natural key before they touch a staging table, with a deterministic tie-break in the ORDER BY. "Whatever ROW_NUMBER happens to pick" is not idempotent, and it shows up as a fresh diff in every parity run until someone hunts it down.

## Dimensions are not retired

No delete branch in dimension merges. Facts keep history, and history points at members that may no longer exist in the source. A member that stops arriving from the source simply stops being updated.

## Surrogate keys: know when your scheme breaks

MAX(sid) + ROW_NUMBER() over the new members is simple and fine, but only under sequential, single-writer execution. Two loads assigning ids concurrently will collide. If the orchestration ever goes parallel, the scheme has to change first. Cheap now, expensive to discover later.

## The grain probe, run after every change

```sql
SELECT source_system, natural_id, COUNT(*) AS rows_at_key
FROM dim_example
GROUP BY source_system, natural_id
HAVING COUNT(*) > 1;
```

Zero rows or it is a defect. Same probe on every fact's declared grain. It costs nothing and it has caught every duplicate-key regression before a consumer did.

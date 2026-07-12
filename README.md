# 02 — Funnel Conversion Analysis

**Business question:** Users move through a sequence of steps toward a goal (visit → view → cart → purchase). Where do we lose the most people?

## The idea

Every step of a funnel loses people. The point of the analysis is to find the *biggest leak*, because that's where a fix earns the most. Two conversion rates matter:

- **% of top** — of everyone who entered, how many reached this step (the headline number)
- **% of previous step** — of those who survived the last step, how many survived this one (**this is what pinpoints the leak**)

## The core pattern: conditional aggregation

```sql
COUNT(DISTINCT CASE WHEN event = 'view' THEN user_id END) AS viewed
```

Read inside-out: the `CASE` hands back a `user_id` only for 'view' rows (NULL otherwise); `COUNT(DISTINCT ...)` counts unique users and ignores the NULLs. One of these per step measures the whole funnel in a single pass.

## Sample output

| step_name | users | pct_of_top | pct_of_prev |
|---|---|---|---|
| visit | 5 | 100.0 | — |
| view | 4 | 80.0 | 80.0 |
| cart | 3 | 60.0 | 75.0 |
| purchase | 2 | 40.0 | 66.7 |

Reading `pct_of_prev` top to bottom (80 → 75 → 67): the steepest step-drop is cart → purchase, so checkout is where this business should dig first.

## Lessons worth remembering

- One funnel row per step (with a `step_number`) reads like the funnel itself and makes window math natural.
- `FIRST_VALUE(users) OVER (ORDER BY step_number)` = the top-of-funnel denominator; `LAG(users) OVER (ORDER BY step_number)` = the previous step's denominator.
- The first row's `pct_of_prev` is NULL by design — there is no step above the top.
- `COUNT(DISTINCT ...)` again: a user can fire the same event many times.

## Files

- [`funnel_conversion.sql`](funnel_conversion.sql) — 4-step e-commerce funnel with both conversion rates (BigQuery, self-contained sample data)

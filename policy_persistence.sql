-- =====================================================================
-- Insurance Policy Persistence (BigQuery)
-- Question: of the policies that went active in each month (cohort),
--           what % were still active EXACTLY 3 months later?
-- Domain adaptation of the cohort-retention pattern.
-- Self-contained: sample data included, paste and run.
-- =====================================================================

WITH policy_activity AS (
  -- one row = a month the policy was active
  SELECT 101 AS policy_id, DATE '2024-01-01' AS active_month UNION ALL
  SELECT 101, DATE '2024-02-01' UNION ALL
  SELECT 101, DATE '2024-03-01' UNION ALL
  SELECT 101, DATE '2024-04-01' UNION ALL
  SELECT 102, DATE '2024-01-01' UNION ALL
  SELECT 102, DATE '2024-02-01' UNION ALL   -- lapses after Feb
  SELECT 103, DATE '2024-01-01' UNION ALL
  SELECT 103, DATE '2024-05-01' UNION ALL   -- gap, reappears in May
  SELECT 104, DATE '2024-02-01' UNION ALL
  SELECT 104, DATE '2024-03-01' UNION ALL
  SELECT 104, DATE '2024-04-01' UNION ALL
  SELECT 104, DATE '2024-05-01'
),

first_activity AS (
  -- cohort = month the policy first went active
  SELECT
    policy_id,
    DATE_TRUNC(MIN(active_month), MONTH) AS cohort_month
  FROM policy_activity
  GROUP BY policy_id
),

activity AS (
  SELECT
    p.policy_id,
    f.cohort_month,
    DATE_DIFF(DATE_TRUNC(p.active_month, MONTH), f.cohort_month, MONTH) AS month_offset
  FROM policy_activity p
  JOIN first_activity f USING (policy_id)
),

cohort_counts AS (
  SELECT
    cohort_month,
    month_offset,
    COUNT(DISTINCT policy_id) AS active_policies
  FROM activity
  GROUP BY cohort_month, month_offset
),

retention AS (
  -- Window functions computed here, over the FULL data.
  -- KEY LESSON: WHERE runs before window functions. Filtering to
  -- month_offset = 3 in this same SELECT would starve FIRST_VALUE of
  -- the offset-0 row and every cohort would (wrongly) show 100%.
  SELECT
    cohort_month,
    month_offset,
    active_policies,
    FIRST_VALUE(active_policies) OVER (
      PARTITION BY cohort_month ORDER BY month_offset
    ) AS cohort_size,
    ROUND(
      active_policies * 100.0 / FIRST_VALUE(active_policies) OVER (
        PARTITION BY cohort_month ORDER BY month_offset
      ), 1
    ) AS persistence_pct
  FROM cohort_counts
)

-- CLASSIC (bounded) persistence: active in exactly month 3
SELECT cohort_month, persistence_pct
FROM retention
WHERE month_offset = 3
ORDER BY cohort_month;
-- Expected: Jan cohort 33.3 (only policy 101 active in April),
--           Feb cohort 100.0 (policy 104 active in May)


-- =====================================================================
-- VARIANT: RANGE (unbounded) persistence — active in month 3 OR LATER.
-- Answers "did we lose them for good?" instead of "were they active
-- in that exact month". Jan cohort becomes 66.7 (101 in April + 103
-- returning in May). Swap the final SELECT above for this:
-- =====================================================================
-- SELECT
--   f.cohort_month,
--   ROUND(
--     COUNT(DISTINCT CASE WHEN a.month_offset >= 3 THEN a.policy_id END)
--     * 100.0 / COUNT(DISTINCT a.policy_id), 1
--   ) AS range_persistence_pct
-- FROM activity a
-- JOIN first_activity f USING (policy_id)
-- GROUP BY f.cohort_month
-- ORDER BY f.cohort_month;

-- =====================================================================
-- Cohort Retention Analysis (BigQuery)
-- Question: of the users who first appeared in month X, what % were
--           active again 1, 2, 3... months later?
-- Self-contained: sample data included, paste and run.
-- =====================================================================

WITH user_logins AS (
  -- sample activity log: one row per login
  SELECT 1 AS user_id, DATE '2024-01-10' AS login_date UNION ALL
  SELECT 1, DATE '2024-02-05' UNION ALL
  SELECT 1, DATE '2024-03-12' UNION ALL
  SELECT 2, DATE '2024-01-15' UNION ALL
  SELECT 2, DATE '2024-03-20' UNION ALL   -- skips Feb, returns Mar
  SELECT 3, DATE '2024-01-22' UNION ALL
  SELECT 4, DATE '2024-02-08' UNION ALL
  SELECT 4, DATE '2024-03-03' UNION ALL
  SELECT 5, DATE '2024-02-19'
),

first_activity AS (
  -- STEP 1: each user's cohort = month of their FIRST login
  SELECT
    user_id,
    DATE_TRUNC(MIN(login_date), MONTH) AS cohort_month
  FROM user_logins
  GROUP BY user_id
),

activity AS (
  -- STEP 2: tag every login with how many months after the cohort it happened
  SELECT
    l.user_id,
    f.cohort_month,
    DATE_DIFF(DATE_TRUNC(l.login_date, MONTH), f.cohort_month, MONTH) AS month_offset
  FROM user_logins l
  JOIN first_activity f USING (user_id)
),

cohort_counts AS (
  -- STEP 3: distinct active users per cohort per offset
  -- COUNT(DISTINCT ...) so a user with 10 logins counts once
  SELECT
    cohort_month,
    month_offset,
    COUNT(DISTINCT user_id) AS active_users
  FROM activity
  GROUP BY cohort_month, month_offset
)

SELECT
  cohort_month,
  month_offset,
  active_users,
  -- cohort size = the offset-0 count; FIRST_VALUE stamps it onto every row
  FIRST_VALUE(active_users) OVER (
    PARTITION BY cohort_month ORDER BY month_offset
  ) AS cohort_size,
  -- 100.0 (not 100) to avoid integer division
  ROUND(
    active_users * 100.0 / FIRST_VALUE(active_users) OVER (
      PARTITION BY cohort_month ORDER BY month_offset
    ), 1
  ) AS retention_pct
FROM cohort_counts
ORDER BY cohort_month, month_offset;

-- ---------------------------------------------------------------------
-- Portability note (PostgreSQL and others without DATE_DIFF ... MONTH):
--   (EXTRACT(YEAR  FROM d2) - EXTRACT(YEAR  FROM d1)) * 12
-- + (EXTRACT(MONTH FROM d2) - EXTRACT(MONTH FROM d1))
-- ---------------------------------------------------------------------

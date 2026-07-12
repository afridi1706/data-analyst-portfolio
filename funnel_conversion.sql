-- =====================================================================
-- Funnel Conversion Analysis (BigQuery)
-- Question: at which step of visit -> view -> cart -> purchase do we
--           lose the most users?
-- Pattern: conditional aggregation + FIRST_VALUE / LAG windows.
-- Self-contained: sample data included, paste and run.
-- =====================================================================

WITH events AS (
  SELECT 1 AS user_id, 'visit'    AS event UNION ALL
  SELECT 1, 'view'     UNION ALL
  SELECT 1, 'cart'     UNION ALL
  SELECT 1, 'purchase' UNION ALL
  SELECT 2, 'visit'    UNION ALL
  SELECT 2, 'view'     UNION ALL
  SELECT 2, 'cart'     UNION ALL
  SELECT 3, 'visit'    UNION ALL
  SELECT 3, 'view'     UNION ALL
  SELECT 4, 'visit'    UNION ALL
  SELECT 5, 'visit'    UNION ALL
  SELECT 5, 'view'     UNION ALL
  SELECT 5, 'cart'     UNION ALL
  SELECT 5, 'purchase'
),

funnel AS (
  -- one row per step; step_number keeps the funnel in order.
  -- COUNT(DISTINCT CASE WHEN ...) = "distinct users who did this step"
  SELECT 1 AS step_number, 'visit' AS step_name,
         COUNT(DISTINCT CASE WHEN event = 'visit' THEN user_id END) AS users
  FROM events
  UNION ALL
  SELECT 2, 'view',
         COUNT(DISTINCT CASE WHEN event = 'view' THEN user_id END)
  FROM events
  UNION ALL
  SELECT 3, 'cart',
         COUNT(DISTINCT CASE WHEN event = 'cart' THEN user_id END)
  FROM events
  UNION ALL
  SELECT 4, 'purchase',
         COUNT(DISTINCT CASE WHEN event = 'purchase' THEN user_id END)
  FROM events
)

SELECT
  step_name,
  users,
  -- overall conversion: this step vs the very top of the funnel
  ROUND(users * 100.0 / FIRST_VALUE(users) OVER (ORDER BY step_number), 1)
    AS pct_of_top,
  -- step-to-step conversion: this step vs the one directly above
  -- (NULL for the first row by design - nothing precedes the top)
  ROUND(users * 100.0 / LAG(users) OVER (ORDER BY step_number), 1)
    AS pct_of_prev
FROM funnel
ORDER BY step_number;

-- Reading the result: the LOWEST pct_of_prev is the worst leak in the
-- funnel - that is the step the business should investigate first.

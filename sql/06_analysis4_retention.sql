USE FlowDesk;
GO
-- FlowDesk | Analysis 4 (T-SQL): Retention trends
-- (In SQL Server a recursive CTE is written WITH, not WITH RECURSIVE.)

-- 4A. Monthly customers, MRR and churn with LAG()
WITH months(month_start, month_end) AS (
    SELECT CAST('2025-01-01' AS DATE), CAST('2025-01-31' AS DATE)
    UNION ALL
    SELECT DATEADD(month, 1, month_start), EOMONTH(DATEADD(month, 1, month_start))
    FROM months
    WHERE month_start < '2026-09-01'
),
monthly AS (
    SELECT
        m.month_start,
        COUNT(s.subscription_id)                      AS active_customers,
        COALESCE(SUM(s.monthly_recurring_revenue), 0) AS mrr,
        (SELECT COUNT(*) FROM subscriptions n
          WHERE n.start_date  BETWEEN m.month_start AND m.month_end) AS new_customers,
        (SELECT COUNT(*) FROM subscriptions c
          WHERE c.cancel_date BETWEEN m.month_start AND m.month_end) AS churned_customers
    FROM months m
    LEFT JOIN subscriptions s
           ON s.start_date <= m.month_end
          AND (s.cancel_date IS NULL OR s.cancel_date > m.month_end)
    GROUP BY m.month_start, m.month_end
)
SELECT
    CONVERT(CHAR(7), month_start, 23)                          AS [month],
    active_customers, new_customers, churned_customers, mrr,
    LAG(mrr) OVER (ORDER BY month_start)                       AS prev_month_mrr,
    mrr - LAG(mrr) OVER (ORDER BY month_start)                 AS mrr_change,
    ROUND(100.0 * (mrr - LAG(mrr) OVER (ORDER BY month_start))
          / NULLIF(LAG(mrr) OVER (ORDER BY month_start), 0), 1) AS mrr_growth_pct,
    ROUND(100.0 * churned_customers
          / NULLIF(LAG(active_customers) OVER (ORDER BY month_start), 0), 2) AS monthly_churn_pct
FROM monthly
ORDER BY month_start;
GO

-- 4B. Cohort retention (long format: one row per cohort x months-since-signup)
WITH nums(k) AS (
    SELECT 0 UNION ALL SELECT k + 1 FROM nums WHERE k < 20
),
cust AS (
    SELECT
        c.customer_id,
        CONVERT(CHAR(7), c.signup_date, 23)           AS cohort_month,
        YEAR(c.signup_date) * 12 + MONTH(c.signup_date) AS signup_idx,
        CASE WHEN s.cancel_date IS NOT NULL
             THEN YEAR(s.cancel_date) * 12 + MONTH(s.cancel_date) END AS cancel_idx
    FROM customers c
    JOIN subscriptions s ON s.customer_id = c.customer_id
),
asof AS (
    SELECT YEAR(as_of_date) * 12 + MONTH(as_of_date) AS asof_idx FROM analysis_config
),
cohort_size AS (
    SELECT cohort_month, MIN(signup_idx) AS signup_idx, COUNT(*) AS cohort_customers
    FROM cust
    GROUP BY cohort_month
)
SELECT
    cs.cohort_month,
    n.k AS months_since_signup,
    cs.cohort_customers,
    SUM(CASE WHEN c.cancel_idx IS NULL OR c.cancel_idx - c.signup_idx > n.k THEN 1 ELSE 0 END) AS retained_customers,
    ROUND(100.0 * SUM(CASE WHEN c.cancel_idx IS NULL OR c.cancel_idx - c.signup_idx > n.k THEN 1 ELSE 0 END)
          / cs.cohort_customers, 1) AS retention_pct
FROM cohort_size cs
CROSS JOIN asof a
JOIN nums n ON n.k <= a.asof_idx - cs.signup_idx
JOIN cust c ON c.cohort_month = cs.cohort_month
GROUP BY cs.cohort_month, n.k, cs.cohort_customers
ORDER BY cs.cohort_month, n.k;
GO

-- 4C. Fair comparison: churn per 100 customer-months
-- (SQL Server does not allow a sub-query inside SUM(), so analysis_config is CROSS JOINed instead.)
SELECT
    cu.acquisition_channel AS segment,
    COUNT(*)               AS customers,
    SUM(CASE WHEN s.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    ROUND(SUM(DATEDIFF(day, s.start_date, COALESCE(s.cancel_date, cfg.as_of_date)) / 30.4), 0) AS customer_months,
    ROUND(100.0 * SUM(CASE WHEN s.status = 'Cancelled' THEN 1 ELSE 0 END)
          / SUM(DATEDIFF(day, s.start_date, COALESCE(s.cancel_date, cfg.as_of_date)) / 30.4), 2) AS churn_per_100_customer_months
FROM customers cu
JOIN subscriptions s ON s.customer_id = cu.customer_id
CROSS JOIN analysis_config cfg
GROUP BY cu.acquisition_channel
ORDER BY churn_per_100_customer_months DESC;
-- Re-run with  s.[plan]  instead of  cu.acquisition_channel  (also in GROUP BY) to compare plans.
GO

-- 4D. Engagement trend: sessions per active user, month over month
WITH monthly_usage AS (
    SELECT CONVERT(CHAR(7), activity_date, 23) AS [month],
           COUNT(DISTINCT customer_id)         AS active_users,
           SUM(session_count)                  AS sessions
    FROM product_usage
    GROUP BY CONVERT(CHAR(7), activity_date, 23)
),
per_user AS (
    SELECT [month], active_users, sessions,
           1.0 * sessions / active_users AS spu
    FROM monthly_usage
)
SELECT [month], active_users, sessions,
       ROUND(spu, 1) AS sessions_per_user,
       ROUND(100.0 * (spu - LAG(spu) OVER (ORDER BY [month]))
             / NULLIF(LAG(spu) OVER (ORDER BY [month]), 0), 1) AS pct_change_vs_prev_month
FROM per_user
ORDER BY [month];

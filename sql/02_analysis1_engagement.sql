USE FlowDesk;
GO
-- FlowDesk | Analysis 1 (T-SQL): Customer engagement health
-- Config table: the "today" date lives in ONE place
DROP TABLE IF EXISTS analysis_config;
CREATE TABLE analysis_config (as_of_date DATE NOT NULL);
INSERT INTO analysis_config (as_of_date) VALUES ('2026-09-30');
GO

-- CREATE VIEW must be the ONLY statement in its batch, which is why GO is used around it.
CREATE OR ALTER VIEW v_engagement AS
WITH cfg AS (
    SELECT as_of_date AS as_of FROM analysis_config
),
usage_agg AS (
    SELECT
        u.customer_id,
        SUM(CASE WHEN u.activity_date >  DATEADD(day, -30, c.as_of)
                 THEN u.session_count ELSE 0 END)                       AS sessions_last_30d,
        SUM(CASE WHEN u.activity_date <= DATEADD(day, -30, c.as_of)
                  AND u.activity_date >  DATEADD(day, -60, c.as_of)
                 THEN u.session_count ELSE 0 END)                       AS sessions_prev_30d,
        COUNT(DISTINCT CASE WHEN u.activity_date > DATEADD(day, -30, c.as_of)
                            THEN u.activity_date END)                   AS active_days_last_30d,
        COUNT(DISTINCT CASE WHEN u.activity_date > DATEADD(day, -30, c.as_of)
                            THEN u.feature_used END)                    AS features_used_last_30d,
        MAX(u.activity_date)                                            AS last_activity_date
    FROM product_usage u
    CROSS JOIN cfg c
    GROUP BY u.customer_id
),
base AS (
    SELECT
        s.customer_id, cu.signup_date, cu.country, cu.acquisition_channel,
        s.[plan], s.monthly_recurring_revenue AS mrr, s.renewal_date,
        DATEDIFF(day, cu.signup_date, c.as_of)  AS tenure_days,
        c.as_of,
        COALESCE(a.sessions_last_30d, 0)      AS sessions_last_30d,
        COALESCE(a.sessions_prev_30d, 0)      AS sessions_prev_30d,
        COALESCE(a.active_days_last_30d, 0)   AS active_days_last_30d,
        COALESCE(a.features_used_last_30d, 0) AS features_used_last_30d,
        a.last_activity_date
    FROM subscriptions s
    JOIN customers cu     ON cu.customer_id = s.customer_id
    CROSS JOIN cfg c
    LEFT JOIN usage_agg a ON a.customer_id  = s.customer_id
    WHERE s.status = 'Active'
),
calc AS (
    SELECT b.*,
           DATEDIFF(day, b.last_activity_date, b.as_of) AS days_since_last_activity,
           -- % change only if there was a "before" period to compare with
           CASE WHEN b.tenure_days >= 60 AND b.sessions_prev_30d > 0
                THEN ROUND(100.0 * (b.sessions_last_30d - b.sessions_prev_30d) / b.sessions_prev_30d, 1)
           END AS usage_change_pct
    FROM base b
)
SELECT
    customer_id, signup_date, country, acquisition_channel, [plan], mrr, renewal_date,
    tenure_days, sessions_last_30d, sessions_prev_30d, active_days_last_30d,
    features_used_last_30d, last_activity_date, days_since_last_activity, usage_change_pct,
    CASE
        WHEN sessions_last_30d = 0       THEN 'Inactive'
        WHEN usage_change_pct <= -50     THEN 'Sharp decline'
        WHEN usage_change_pct <= -25     THEN 'Declining'
        WHEN usage_change_pct IS NULL    THEN 'New / not enough history'
        WHEN usage_change_pct >= 25      THEN 'Growing'
        ELSE 'Stable'
    END AS engagement_status
FROM calc;
GO

-- Look at the result (NULL change values pushed to the bottom)
SELECT TOP 20 *
FROM v_engagement
ORDER BY CASE WHEN usage_change_pct IS NULL THEN 1 ELSE 0 END, usage_change_pct;

-- Customers per engagement status
SELECT engagement_status, COUNT(*) AS customers, SUM(mrr) AS mrr
FROM v_engagement
GROUP BY engagement_status
ORDER BY customers DESC;

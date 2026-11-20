USE FlowDesk;
GO
-- FlowDesk | Analysis 3 (T-SQL): Explainable risk score (0-100)
-- RULEBOOK
--   Engagement drop : no sessions in 30d = 35 | usage down >=50% = 25 | down >=25% = 15
--   Inactivity      : last activity 14+ days ago = 10
--   Payments        : 2+ failed in 60d = 20 | 1 failed = 10 | latest payment still failed = +10
--   Support         : unresolved HIGH ticket = 15 | any other unresolved ticket = 5
--   Renewal         : renews within 14 days AND < 8 sessions in 30d = 10
-- BANDS: High >= 40 | Medium 20-39 | Low < 20
-- (CONCAT_WS below needs SQL Server 2017 or newer.)

CREATE OR ALTER VIEW v_risk_scores AS
WITH scored AS (
    SELECT
        s.*,
        CASE WHEN sessions_last_30d = 0   THEN 35
             WHEN usage_change_pct <= -50 THEN 25
             WHEN usage_change_pct <= -25 THEN 15
             ELSE 0 END AS pts_engagement,
        CASE WHEN days_since_last_activity >= 14 OR last_activity_date IS NULL THEN 10 ELSE 0 END AS pts_inactivity,
        CASE WHEN failed_payments_60d >= 2 THEN 20
             WHEN failed_payments_60d = 1  THEN 10
             ELSE 0 END
        + CASE WHEN latest_payment_status = 'Failed' THEN 10 ELSE 0 END AS pts_payment,
        CASE WHEN unresolved_high_tickets >= 1 THEN 15
             WHEN unresolved_tickets >= 1      THEN 5
             ELSE 0 END AS pts_support,
        CASE WHEN renews_within_14d = 1 AND sessions_last_30d < 8 THEN 10 ELSE 0 END AS pts_renewal
    FROM v_signals s
),
totals AS (
    SELECT *, pts_engagement + pts_inactivity + pts_payment + pts_support + pts_renewal AS raw_score
    FROM scored
),
capped AS (
    SELECT *, CASE WHEN raw_score > 100 THEN 100 ELSE raw_score END AS risk_score
    FROM totals
)
SELECT
    *,
    CASE WHEN risk_score >= 40 THEN 'High'
         WHEN risk_score >= 20 THEN 'Medium'
         ELSE 'Low' END AS risk_band,
    -- every rule that fired, in plain English (CASE without ELSE gives NULL, which CONCAT_WS skips)
    CONCAT_WS('; ',
        CASE WHEN sessions_last_30d = 0   THEN 'No usage in 30d'
             WHEN usage_change_pct <= -25 THEN CONCAT('Usage down ', CAST(ABS(ROUND(usage_change_pct, 0)) AS INT), '%') END,
        CASE WHEN days_since_last_activity >= 14 THEN CONCAT('Idle ', days_since_last_activity, ' days') END,
        CASE WHEN failed_payments_60d >= 1 THEN CONCAT(failed_payments_60d, ' failed payment(s)') END,
        CASE WHEN latest_payment_status = 'Failed' THEN 'Not recovered' END,
        CASE WHEN unresolved_high_tickets >= 1 THEN 'Open high-priority ticket'
             WHEN unresolved_tickets >= 1      THEN 'Open ticket' END,
        CASE WHEN pts_renewal > 0 THEN 'Renewal soon, low usage' END
    ) AS warning_signs,
    CASE
        WHEN risk_score < 20                      THEN 'Routine monitoring'
        WHEN latest_payment_status = 'Failed'     THEN 'Payment recovery'
        WHEN unresolved_high_tickets >= 1         THEN 'Escalate support ticket'
        WHEN sessions_last_30d = 0                THEN 'Re-activation call'
        WHEN pts_engagement >= 15                 THEN 'Product walkthrough'
        WHEN pts_renewal > 0                      THEN 'Renewal outreach'
        ELSE 'Customer success check-in'
    END AS suggested_action
FROM capped;
GO

-- 3A. Spot-check: do the points add up?
SELECT TOP 10 customer_id, pts_engagement, pts_inactivity, pts_payment, pts_support, pts_renewal,
       risk_score, risk_band, warning_signs, suggested_action
FROM v_risk_scores
ORDER BY risk_score DESC, mrr DESC;

-- 3B. Customers and MRR per band
SELECT risk_band,
       COUNT(*) AS customers,
       SUM(mrr) AS mrr,
       ROUND(100.0 * SUM(mrr) / SUM(SUM(mrr)) OVER (), 1) AS pct_of_active_mrr
FROM v_risk_scores
GROUP BY risk_band
ORDER BY CASE risk_band WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;

-- 3C. Suggested actions
SELECT suggested_action, COUNT(*) AS customers, SUM(mrr) AS mrr
FROM v_risk_scores
GROUP BY suggested_action
ORDER BY customers DESC;

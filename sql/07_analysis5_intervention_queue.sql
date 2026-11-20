USE FlowDesk;
GO
-- FlowDesk | Analysis 5 (T-SQL): Customer intervention queue

-- 5A. Ranked action list: High + Medium, biggest risk-weighted revenue first
SELECT
    ROW_NUMBER() OVER (ORDER BY risk_score * mrr DESC, mrr DESC) AS priority_rank,
    customer_id, [plan], country, mrr, risk_score, risk_band,
    ROUND(mrr * risk_score / 100.0, 0)                            AS risk_weighted_mrr,
    warning_signs, suggested_action, renewal_date,
    RANK() OVER (PARTITION BY suggested_action
                 ORDER BY risk_score DESC, mrr DESC)              AS rank_within_action
FROM v_risk_scores
WHERE risk_band IN ('High', 'Medium')
ORDER BY priority_rank;

-- 5B. Workload per action
SELECT suggested_action,
       COUNT(*)                  AS customers,
       SUM(mrr)                  AS mrr_in_queue,
       ROUND(AVG(1.0 * risk_score), 0) AS avg_risk_score
FROM v_risk_scores
WHERE risk_band IN ('High', 'Medium')
GROUP BY suggested_action
ORDER BY mrr_in_queue DESC;

-- 5C. Executive summary
SELECT
    COUNT(*)                                                              AS active_customers,
    SUM(mrr)                                                              AS total_mrr,
    SUM(CASE WHEN risk_band = 'High' THEN mrr ELSE 0 END)                 AS high_risk_mrr,
    SUM(CASE WHEN risk_band IN ('High','Medium') THEN mrr ELSE 0 END)     AS high_plus_medium_mrr,
    ROUND(100.0 * SUM(CASE WHEN risk_band IN ('High','Medium') THEN mrr ELSE 0 END) / SUM(mrr), 1) AS pct_mrr_at_risk
FROM v_risk_scores;

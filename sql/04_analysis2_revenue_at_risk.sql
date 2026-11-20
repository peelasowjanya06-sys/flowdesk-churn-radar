USE FlowDesk;
GO
-- FlowDesk | Analysis 2 (T-SQL): Revenue at risk
-- At risk = still paying but showing warning signs | Lost = already cancelled

-- 2A. Headline numbers
SELECT
    COUNT(*)  AS active_customers,
    SUM(mrr)  AS total_active_mrr,
    SUM(CASE WHEN flag_usage + flag_payment + flag_ticket > 0 THEN mrr ELSE 0 END) AS mrr_with_any_warning,
    ROUND(100.0 * SUM(CASE WHEN flag_usage + flag_payment + flag_ticket > 0 THEN mrr ELSE 0 END)
          / SUM(mrr), 1) AS pct_mrr_with_warning
FROM v_signals;

-- 2B. Revenue linked to EACH signal (customers can appear in more than one row)
SELECT 'Usage decline / inactive' AS warning_signal, COUNT(*) AS customers, SUM(mrr) AS mrr FROM v_signals WHERE flag_usage = 1
UNION ALL
SELECT 'Failed payment (60d)', COUNT(*), SUM(mrr) FROM v_signals WHERE flag_payment = 1
UNION ALL
SELECT 'Unresolved high-priority ticket', COUNT(*), SUM(mrr) FROM v_signals WHERE flag_ticket = 1;

-- 2C. By plan
SELECT [plan],
       COUNT(*) AS customers,
       SUM(mrr) AS plan_mrr,
       SUM(CASE WHEN flag_usage + flag_payment + flag_ticket > 0 THEN mrr ELSE 0 END) AS mrr_with_warning,
       ROUND(100.0 * SUM(CASE WHEN flag_usage + flag_payment + flag_ticket > 0 THEN mrr ELSE 0 END)
             / SUM(mrr), 1) AS pct_at_risk
FROM v_signals
GROUP BY [plan]
ORDER BY plan_mrr DESC;

-- 2D. Revenue ACTUALLY lost, by cancellation month
SELECT CONVERT(CHAR(7), cancel_date, 23) AS cancel_month,
       COUNT(*)                          AS customers_lost,
       SUM(monthly_recurring_revenue)    AS mrr_lost
FROM subscriptions
WHERE status = 'Cancelled'
GROUP BY CONVERT(CHAR(7), cancel_date, 23)
ORDER BY cancel_month;

-- 2E. Renewals in the next 14 days that carry a warning sign
SELECT customer_id, [plan], mrr, renewal_date, flag_usage, flag_payment, flag_ticket
FROM v_signals
WHERE renews_within_14d = 1
  AND flag_usage + flag_payment + flag_ticket > 0
ORDER BY renewal_date, mrr DESC;

USE FlowDesk;
GO
-- FlowDesk | Analysis 1B (T-SQL): payment + support signals, one row per active customer
CREATE OR ALTER VIEW v_signals AS
WITH cfg AS (
    SELECT as_of_date AS as_of FROM analysis_config
),
payment_agg AS (
    SELECT p.customer_id,
           SUM(CASE WHEN p.payment_status = 'Failed'
                     AND p.payment_date > DATEADD(day, -60, c.as_of) THEN 1 ELSE 0 END) AS failed_payments_60d
    FROM payments p CROSS JOIN cfg c
    GROUP BY p.customer_id
),
latest_payment AS (
    SELECT x.customer_id, x.payment_status AS latest_payment_status
    FROM (
        SELECT customer_id, payment_status,
               ROW_NUMBER() OVER (PARTITION BY customer_id
                                  ORDER BY payment_date DESC, payment_id DESC) AS rn
        FROM payments
    ) x
    WHERE x.rn = 1
),
ticket_agg AS (
    SELECT customer_id,
           SUM(CASE WHEN resolution_status <> 'Resolved' THEN 1 ELSE 0 END)                       AS unresolved_tickets,
           SUM(CASE WHEN resolution_status <> 'Resolved' AND priority = 'High' THEN 1 ELSE 0 END) AS unresolved_high_tickets
    FROM support_tickets
    GROUP BY customer_id
)
SELECT
    e.*,
    COALESCE(pa.failed_payments_60d, 0)        AS failed_payments_60d,
    COALESCE(lp.latest_payment_status, 'None') AS latest_payment_status,
    COALESCE(ta.unresolved_tickets, 0)         AS unresolved_tickets,
    COALESCE(ta.unresolved_high_tickets, 0)    AS unresolved_high_tickets,
    CASE WHEN e.renewal_date <= DATEADD(day, 14, c.as_of) THEN 1 ELSE 0 END AS renews_within_14d,
    CASE WHEN e.sessions_last_30d = 0 OR e.usage_change_pct <= -25 THEN 1 ELSE 0 END AS flag_usage,
    CASE WHEN COALESCE(pa.failed_payments_60d, 0) >= 1             THEN 1 ELSE 0 END AS flag_payment,
    CASE WHEN COALESCE(ta.unresolved_high_tickets, 0) >= 1         THEN 1 ELSE 0 END AS flag_ticket
FROM v_engagement e
CROSS JOIN cfg c
LEFT JOIN payment_agg    pa ON pa.customer_id = e.customer_id
LEFT JOIN latest_payment lp ON lp.customer_id = e.customer_id
LEFT JOIN ticket_agg     ta ON ta.customer_id = e.customer_id;
GO

SELECT TOP 10 * FROM v_signals;

-- Customers by number of warning flags
SELECT flag_usage + flag_payment + flag_ticket AS warning_flags,
       COUNT(*) AS customers, SUM(mrr) AS mrr
FROM v_signals
GROUP BY flag_usage + flag_payment + flag_ticket
ORDER BY warning_flags;

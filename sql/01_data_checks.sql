USE FlowDesk;
GO
-- FlowDesk | Step 1 (T-SQL): know your data BEFORE analysing it

-- 1A. Row counts
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'subscriptions',   COUNT(*) FROM subscriptions
UNION ALL SELECT 'product_usage',   COUNT(*) FROM product_usage
UNION ALL SELECT 'payments',        COUNT(*) FROM payments
UNION ALL SELECT 'support_tickets', COUNT(*) FROM support_tickets;

-- 1B. Date ranges
SELECT MIN(signup_date) AS first_signup, MAX(signup_date) AS last_signup FROM customers;
SELECT MIN(activity_date) AS first_activity, MAX(activity_date) AS last_activity FROM product_usage;

-- 1C. NULLs that are EXPECTED
SELECT COUNT(*) AS total_subscriptions,
       SUM(CASE WHEN cancel_date  IS NULL THEN 1 ELSE 0 END) AS null_cancel_date,
       SUM(CASE WHEN renewal_date IS NULL THEN 1 ELSE 0 END) AS null_renewal_date
FROM subscriptions;

SELECT payment_status, COUNT(*) AS payments,
       SUM(CASE WHEN failure_reason IS NULL THEN 1 ELSE 0 END) AS null_reason
FROM payments
GROUP BY payment_status;

-- 1D. Duplicate check (should return NO rows)
SELECT customer_id, COUNT(*) AS n
FROM subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 1E. Orphan check (should return NO rows)
SELECT p.payment_id
FROM payments p
LEFT JOIN customers c ON p.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 1F. Business snapshot
SELECT status, COUNT(*) AS customers, SUM(monthly_recurring_revenue) AS total_mrr
FROM subscriptions
GROUP BY status;

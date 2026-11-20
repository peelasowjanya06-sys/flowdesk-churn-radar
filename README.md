# flowdesk-churn-radar
SQL Server + Excel churn risk analysis on a synthetic SaaS dataset
# Silent Churn Radar
A SQL Server + Excel project where I try to spot customers who are about to leave a subscription app, and work out how much monthly revenue is at risk.

![Dashboard]("C:\Users\peele\OneDrive\Documents\flowdesk-churn-radar\images\Flow Desk Churn Radar Screenshot .png")

**Note:** the data is synthetic (randomly generated). It is not real customer data.

## The problem
FlowDesk is a made-up subscription app. The customer success team wants to know who is likely to leave, how much monthly revenue (MRR) is at risk, and who they should contact first.

## The data
5 tables (customers, subscriptions, product_usage, payments, support_tickets) with about 49,500 rows in total. Money is in rupees and "today" is 30 Sep 2026.

## What I did
- Checked the data first (duplicates, orphan rows, NULLs)
- Compared each customer's usage in the last 30 days with the 30 days before
- Added failed payments and unresolved support tickets
- Kept "at risk" revenue separate from revenue already lost
- Built a 0 to 100 risk score from simple rules, so every point can be explained
- Looked at monthly MRR, churn and retention by signup month
- Made a ranked list of who to contact first, with a suggested action

## How the score works
Points are added for no or falling usage (up to 35), no activity for 14+ days (10), failed payments (up to 30), open support tickets (up to 15), and a renewal coming up with low usage (10). The maximum is 100. A score of 40 or more is High, 20 to 39 is Medium, and under 20 is Low.

## What I found
- 17% of monthly revenue (₹77,900) sits with 50 customers rated High or Medium risk
- About a third of revenue (33.3%) has at least one warning sign
- 15 customers need payment recovery (₹22,700), which is the quickest revenue to protect
- MRR dropped 3.3% in Sep 2026

If this were real, I would start with the payment recovery cases, then call customers who renew in the next 14 days, and escalate the 7 open high-priority tickets.

## Excel dashboard
It has the key numbers, a few charts, the priority list and a customer look-up. One sheet rebuilds the risk score with Excel formulas and matches the SQL result with 0 mismatches.

## Folders
`sql` for the scripts, `data` for the 5 CSV files, `excel` for the dashboard, `images` for the screenshot.

## How to run
In SQL Server Management Studio, run `00_create_database_and_tables.sql` and `00b_load_data.sql`, then scripts `01` to `07` in order.

## Limitations
The data is synthetic, the score weights are my own judgement and weren't tested against real cancellations, and 320 customers is a small sample.

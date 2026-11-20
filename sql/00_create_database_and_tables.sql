-- FlowDesk | Step 0 (SQL Server / SSMS): create the database and the five tables
-- NOTE: [plan] is in square brackets because PLAN is a reserved word in T-SQL.
IF DB_ID('FlowDesk') IS NULL CREATE DATABASE FlowDesk;
GO
USE FlowDesk;
GO

DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS product_usage;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS customers;
GO

CREATE TABLE customers (
    customer_id          VARCHAR(10)  NOT NULL PRIMARY KEY,
    signup_date          DATE         NOT NULL,
    country              VARCHAR(40)  NULL,
    acquisition_channel  VARCHAR(40)  NULL
);

CREATE TABLE subscriptions (
    subscription_id            VARCHAR(10) NOT NULL PRIMARY KEY,
    customer_id                VARCHAR(10) NOT NULL REFERENCES customers(customer_id),
    [plan]                     VARCHAR(20) NULL,
    monthly_recurring_revenue  INT         NULL,      -- INR
    start_date                 DATE        NULL,
    renewal_date               DATE        NULL,      -- NULL when cancelled
    status                     VARCHAR(20) NULL,      -- Active / Cancelled
    cancel_date                DATE        NULL       -- NULL when still active
);

CREATE TABLE product_usage (
    usage_id        VARCHAR(10) NOT NULL PRIMARY KEY,
    customer_id     VARCHAR(10) NOT NULL REFERENCES customers(customer_id),
    activity_date   DATE        NULL,
    feature_used    VARCHAR(30) NULL,
    session_count   INT         NULL
);

CREATE TABLE payments (
    payment_id      VARCHAR(10) NOT NULL PRIMARY KEY,
    customer_id     VARCHAR(10) NOT NULL REFERENCES customers(customer_id),
    payment_date    DATE        NULL,
    amount          INT         NULL,                 -- INR
    payment_status  VARCHAR(20) NULL,                 -- Success / Failed / Refunded
    failure_reason  VARCHAR(40) NULL                  -- NULL unless Failed
);

CREATE TABLE support_tickets (
    ticket_id          VARCHAR(10) NOT NULL PRIMARY KEY,
    customer_id        VARCHAR(10) NOT NULL REFERENCES customers(customer_id),
    ticket_date        DATE        NULL,
    issue_type         VARCHAR(30) NULL,
    priority           VARCHAR(10) NULL,              -- Low / Medium / High
    resolution_status  VARCHAR(20) NULL,              -- Open / In Progress / Resolved
    resolved_date      DATE        NULL               -- NULL unless Resolved
);
GO

CREATE INDEX ix_subs_cust     ON subscriptions(customer_id);
CREATE INDEX ix_usage_cust    ON product_usage(customer_id);
CREATE INDEX ix_usage_date    ON product_usage(activity_date);
CREATE INDEX ix_pay_cust      ON payments(customer_id);
CREATE INDEX ix_tickets_cust  ON support_tickets(customer_id);
GO
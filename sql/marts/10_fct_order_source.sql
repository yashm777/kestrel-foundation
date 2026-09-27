-- PARTNER_API is suspected of including freight in order_value_gross (open ticket).
-- We keep the raw figure and an 8.5% ex-freight hypothesis; compare means in dq_order_source_profile.
CREATE OR REPLACE TABLE fct_order_source AS
SELECT
  source_system,
  count(*) AS orders,
  round(sum(order_value_gross), 2) AS order_value_gross,
  round(
    sum(
      CASE
        WHEN source_system = 'PARTNER_API' THEN order_value_gross / 1.085
        ELSE order_value_gross
      END
    ),
    2
  ) AS order_value_ex_suspected_freight,
  round(avg(order_value_gross), 2) AS mean_gross,
  round(median(order_value_gross), 2) AS median_gross
FROM stg_orders
GROUP BY source_system;

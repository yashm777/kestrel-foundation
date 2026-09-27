CREATE OR REPLACE TABLE fct_sales_daily AS
SELECT
  p.business_date,
  d.fiscal_year,
  d.fiscal_quarter,
  d.fiscal_month_no,
  d.report_week,
  p.till_channel,
  p.outlet_channel_asof,
  count(*) AS line_count,
  count(DISTINCT p.basket_id) AS basket_count,
  round(sum(p.gross_sales_inr), 2) AS gross_sales_inr,
  round(sum(p.discount_amount), 2) AS discount_inr,
  round(sum(CASE WHEN p.conversion_status = 'CONVERTED' THEN p.eaches END), 2) AS units_eaches,
  count(*) FILTER (WHERE p.conversion_status = 'UNKNOWN') AS units_unknown_lines
FROM fct_pos_line p
LEFT JOIN dim_date d
  ON p.business_date = d.calendar_date
GROUP BY ALL;

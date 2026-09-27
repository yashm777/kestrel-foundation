-- Gross sales by as-of outlet channel. Fiscal year/quarter from dim_date.
-- Params: fy (e.g. FY27), quarter (e.g. Q1)
SELECT
  d.fiscal_year,
  d.fiscal_quarter,
  coalesce(p.outlet_channel_asof, p.till_channel) AS channel,
  round(sum(p.gross_sales_inr), 2) AS gross_sales_inr,
  count(*) AS line_count
FROM fct_pos_line p
JOIN dim_date d
  ON p.business_date = d.calendar_date
WHERE d.fiscal_year = '{{fy}}'
  AND d.fiscal_quarter = '{{quarter}}'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

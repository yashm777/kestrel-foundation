-- Units in eaches for the last complete calendar month present in POS.
WITH last_month AS (
  SELECT date_trunc('month', max(business_date)) AS month_start
  FROM fct_pos_line
)
SELECT
  CAST(lm.month_start AS DATE) AS month_start,
  coalesce(p.outlet_channel_asof, p.till_channel) AS channel,
  round(sum(p.eaches), 2) AS units_eaches,
  count(*) AS converted_lines
FROM fct_pos_line p
CROSS JOIN last_month lm
WHERE p.conversion_status = 'CONVERTED'
  AND p.business_date >= lm.month_start
  AND p.business_date < lm.month_start + INTERVAL 1 MONTH
GROUP BY 1, 2
ORDER BY 1, 2;

-- Trace a published week/channel cell back to canonical POS lines (event-week, deduped).
-- Params: week (report_week origin date, e.g. 2026-04-01), channel (GT/MT/HORECA/ECOM)
SELECT
  txn_id,
  txn_line_no,
  business_date,
  ingest_date,
  till_channel,
  outlet_channel_asof,
  sku_code,
  qty,
  unit_price,
  gross_sales_inr,
  source_file
FROM fct_pos_line
WHERE CAST(report_week(business_date) AS DATE) = DATE '{{week}}'
  AND till_channel = '{{channel}}'
ORDER BY business_date, txn_id, txn_line_no
LIMIT 200;

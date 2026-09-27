CREATE OR REPLACE TABLE fct_pos_line AS
SELECT
  p.txn_id,
  p.txn_line_no,
  p.basket_id,
  p.outlet_code,
  p.till_channel,
  o.channel AS outlet_channel_asof,
  o.outlet_name,
  o.city AS outlet_city,
  o.warehouse_code AS outlet_warehouse,
  p.sku_code,
  pr.product_name,
  pr.category,
  p.event_ts_utc,
  p.event_ts_ist,
  p.business_date,
  p.ingest_date,
  p.qty,
  p.uom,
  p.unit_price,
  p.discount_amount,
  p.tax_amount,
  p.gross_sales_inr,
  p.payment_mode,
  p.source_file,
  pr.case_pack,
  u.eaches_per_case,
  CASE
    WHEN p.uom IS NULL THEN 'UNKNOWN'
    WHEN p.uom = 'EA' THEN 'CONVERTED'
    WHEN p.uom = 'CS' AND u.eaches_per_case IS NOT NULL THEN 'CONVERTED'
    WHEN p.uom = 'CS' AND pr.case_pack IS NOT NULL THEN 'CONVERTED'
    ELSE 'UNKNOWN'
  END AS conversion_status,
  CASE
    WHEN p.uom IS NULL THEN 'UNKNOWN'
    WHEN p.uom = 'EA' THEN 'UOM_REFERENCE'
    WHEN p.uom = 'CS' AND u.eaches_per_case IS NOT NULL THEN 'UOM_REFERENCE'
    WHEN p.uom = 'CS' AND pr.case_pack IS NOT NULL THEN 'CDC_CASE_PACK'
    ELSE 'UNKNOWN'
  END AS conversion_source,
  CASE
    WHEN p.uom IS NULL THEN NULL
    WHEN p.uom = 'EA' THEN p.qty
    WHEN p.uom = 'CS' AND u.eaches_per_case IS NOT NULL THEN p.qty * u.eaches_per_case
    WHEN p.uom = 'CS' AND pr.case_pack IS NOT NULL THEN p.qty * pr.case_pack
    ELSE NULL
  END AS eaches
FROM stg_pos p
LEFT JOIN dim_outlet_scd2 o
  ON p.outlet_code = o.outlet_code
 AND p.event_ts_utc >= o.valid_from
 AND p.event_ts_utc < o.valid_to
LEFT JOIN dim_product pr
  ON p.sku_code = pr.sku_code
LEFT JOIN uom_conversion u
  ON p.sku_code = u.sku_code;

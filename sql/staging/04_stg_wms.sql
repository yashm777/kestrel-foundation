CREATE OR REPLACE TABLE stg_wms AS
SELECT
  scan_id,
  warehouse_code,
  event_type,
  order_number,
  sku_code,
  batch_id,
  qty_cases,
  pallet_id,
  dock_door,
  operator_id,
  handheld_device,
  strptime(CAST(event_ts AS VARCHAR), '%Y-%m-%d %H:%M:%S') AS event_ts,
  CAST(dt AS DATE) AS dt
FROM raw_wms;

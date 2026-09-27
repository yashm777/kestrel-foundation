CREATE OR REPLACE TABLE fct_wms_cycle AS
WITH per_order AS (
  SELECT
    order_number,
    any_value(warehouse_code) AS warehouse_code,
    min(event_ts) FILTER (WHERE event_type = 'RECEIVE') AS receive_ts,
    min(event_ts) FILTER (WHERE event_type = 'DISPATCH') AS dispatch_ts,
    count(*) AS scan_count,
    count(DISTINCT event_type) AS stage_count
  FROM stg_wms
  GROUP BY order_number
)
SELECT
  order_number,
  warehouse_code,
  receive_ts,
  dispatch_ts,
  scan_count,
  stage_count,
  CASE
    WHEN receive_ts IS NOT NULL AND dispatch_ts IS NOT NULL AND dispatch_ts >= receive_ts
    THEN date_diff('second', receive_ts, dispatch_ts)
  END AS cycle_seconds,
  (receive_ts IS NOT NULL AND dispatch_ts IS NOT NULL AND dispatch_ts >= receive_ts) AS complete_journey
FROM per_order;

CREATE OR REPLACE TABLE fct_wms_cycle_warehouse AS
SELECT
  warehouse_code,
  count(*) AS orders_with_scans,
  count(*) FILTER (WHERE complete_journey) AS complete_journeys,
  round(100.0 * count(*) FILTER (WHERE complete_journey) / count(*), 2) AS coverage_pct,
  median(cycle_seconds) FILTER (WHERE complete_journey) AS median_cycle_seconds
FROM fct_wms_cycle
GROUP BY warehouse_code;

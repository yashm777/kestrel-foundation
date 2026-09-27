-- Dispatch-on-request-date proxy. Not OTIF. Not "service level".
-- Numerator: current (non-deleted) orders with a WMS DISPATCH on or before requested_delivery_date.
-- Coverage: share of those orders that have any DISPATCH scan at all.
CREATE OR REPLACE TABLE fct_dispatch_on_request AS
SELECT
  o.order_number,
  o.requested_delivery_date,
  o.order_status,
  o.source_system,
  o.warehouse_code,
  w.dispatch_ts,
  CAST(w.dispatch_ts AS DATE) AS dispatch_date,
  (w.dispatch_ts IS NOT NULL) AS has_dispatch_scan,
  CASE
    WHEN w.dispatch_ts IS NULL THEN NULL
    ELSE CAST(w.dispatch_ts AS DATE) <= o.requested_delivery_date
  END AS on_request_date
FROM stg_orders o
LEFT JOIN (
  SELECT order_number, min(event_ts) AS dispatch_ts
  FROM stg_wms
  WHERE event_type = 'DISPATCH'
  GROUP BY order_number
) w USING (order_number);

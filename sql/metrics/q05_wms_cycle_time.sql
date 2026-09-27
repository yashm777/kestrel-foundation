SELECT
  w.warehouse_code,
  m.warehouse_name,
  m.region_name,
  w.orders_with_scans,
  w.complete_journeys,
  w.coverage_pct,
  w.median_cycle_seconds,
  round(w.median_cycle_seconds / 3600.0, 2) AS median_cycle_hours
FROM fct_wms_cycle_warehouse w
LEFT JOIN warehouse_master m USING (warehouse_code)
ORDER BY w.warehouse_code;

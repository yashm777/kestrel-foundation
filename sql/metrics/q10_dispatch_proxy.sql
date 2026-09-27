SELECT
  count(*) AS orders,
  count(*) FILTER (WHERE has_dispatch_scan) AS orders_with_dispatch_scan,
  round(100.0 * count(*) FILTER (WHERE has_dispatch_scan) / count(*), 2) AS coverage_pct,
  count(*) FILTER (WHERE on_request_date) AS on_request_date_orders,
  round(
    100.0 * count(*) FILTER (WHERE on_request_date)
    / nullif(count(*) FILTER (WHERE has_dispatch_scan), 0),
    2
  ) AS dispatch_on_request_pct
FROM fct_dispatch_on_request;

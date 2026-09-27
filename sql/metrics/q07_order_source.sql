SELECT
  o.source_system,
  o.orders,
  o.order_value_gross,
  o.order_value_ex_suspected_freight,
  o.mean_gross,
  o.median_gross,
  p.mean_gross AS profile_mean_gross
FROM fct_order_source o
LEFT JOIN dq_order_source_profile p USING (source_system)
ORDER BY o.source_system;

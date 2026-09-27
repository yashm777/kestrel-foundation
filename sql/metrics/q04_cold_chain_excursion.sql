-- Documented excursion = any valid reading above 8C on the trip proxy.
-- Carrier is not in the telemetry feed; this is warehouse × vendor × month.
SELECT
  date_trunc('month', business_date)::DATE AS month_start,
  warehouse_code,
  telemetry_vendor,
  count(*) AS trips,
  count(*) FILTER (WHERE valid_readings > 0) AS trips_with_temp,
  count(*) FILTER (WHERE has_above_limit_excursion) AS trips_above_8c,
  round(
    100.0 * count(*) FILTER (WHERE has_above_limit_excursion)
    / nullif(count(*) FILTER (WHERE valid_readings > 0), 0),
    2
  ) AS above_limit_pct,
  count(*) FILTER (WHERE has_outside_band_excursion) AS trips_outside_2_to_8
FROM fct_cold_chain_trip
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

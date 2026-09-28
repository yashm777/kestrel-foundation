-- Trip proxy: vehicle + route + corrected device-clock date. This is not IST.
-- route_code changes on nearly every reading, so most keys are a single reading.
-- There is no trip_id. Do not read this grain as a vehicle-day.
CREATE OR REPLACE TABLE fct_cold_chain_trip AS
SELECT
  trip_key,
  vehicle_registration,
  route_code,
  business_date,
  any_value(warehouse_code) AS warehouse_code,
  any_value(telemetry_vendor) AS telemetry_vendor,
  count(*) AS reading_count,
  count(temperature_c) AS valid_readings,
  count(*) FILTER (WHERE above_limit_flag) AS above_limit_readings,
  count(*) FILTER (WHERE outside_band_flag) AS outside_band_readings,
  bool_or(above_limit_flag) AS has_above_limit_excursion,
  bool_or(outside_band_flag) AS has_outside_band_excursion
FROM stg_telemetry
GROUP BY trip_key, vehicle_registration, route_code, business_date;

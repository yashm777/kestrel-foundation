CREATE OR REPLACE TABLE stg_telemetry AS
WITH inferred AS (
  SELECT
    t.device_id,
    CAST(t.telemetry_vendor AS VARCHAR) AS telemetry_vendor,
    CAST(t.firmware_version AS VARCHAR) AS firmware_version,
    t.vehicle_registration,
    t.route_code,
    t.warehouse_code,
    CAST(t.gateway_id AS VARCHAR) AS gateway_id,
    strptime(replace(CAST(t.reading_ts AS VARCHAR), 'Z', ''), '%Y-%m-%dT%H:%M:%S') AS reading_ts_raw,
    CAST(t.temp_value AS DOUBLE) AS temp_value_raw,
    CAST(t.dt AS DATE) AS partition_date,
    coalesce(c.observed_offset_hours, 0) AS clock_offset_hours,
    CASE
      WHEN CAST(t.temp_unit AS VARCHAR) IN ('C', 'F') THEN CAST(t.temp_unit AS VARCHAR)
      WHEN CAST(t.telemetry_vendor AS VARCHAR) = 'COLDEYE' THEN 'F'
      ELSE 'C'
    END AS temp_unit_inferred
  FROM raw_telemetry t
  LEFT JOIN dq_firmware_clock c
    ON CAST(t.firmware_version AS VARCHAR) = c.firmware_version
),
converted AS (
  SELECT
    device_id,
    telemetry_vendor,
    firmware_version,
    vehicle_registration,
    route_code,
    warehouse_code,
    gateway_id,
    reading_ts_raw,
    partition_date,
    clock_offset_hours,
    temp_unit_inferred,
    reading_ts_raw - (clock_offset_hours * INTERVAL 1 HOUR) AS reading_ts_corrected,
    CAST(reading_ts_raw - (clock_offset_hours * INTERVAL 1 HOUR) AS DATE) AS business_date,
    CASE
      WHEN temp_value_raw IS NULL THEN NULL
      WHEN temp_unit_inferred = 'F' THEN (temp_value_raw - 32.0) * 5.0 / 9.0
      ELSE temp_value_raw
    END AS temperature_c
  FROM inferred
),
flagged AS (
  SELECT
    *,
    (temperature_c IS NOT NULL AND temperature_c > 8) AS above_limit_flag,
    (temperature_c IS NOT NULL AND (temperature_c < 2 OR temperature_c > 8)) AS outside_band_flag,
    vehicle_registration || '|' || route_code || '|' || CAST(business_date AS VARCHAR) AS trip_key,
    row_number() OVER (
      PARTITION BY device_id, reading_ts_raw, round(temperature_c, 4), gateway_id, route_code, vehicle_registration
      ORDER BY partition_date
    ) AS rn
  FROM converted
)
SELECT * EXCLUDE (rn)
FROM flagged
WHERE rn = 1;

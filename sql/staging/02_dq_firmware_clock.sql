-- Device-clock offset vs partition date, by firmware.
-- Baseline is the median of per-firmware medians. A firmware whose device
-- clock runs ahead of the partition date gets a positive observed_offset_hours
-- (subtract it). Offsets of 1 hour are treated as noise on a 0–24h clock.
CREATE OR REPLACE TABLE dq_firmware_clock AS
WITH by_fw AS (
  SELECT
    CAST(firmware_version AS VARCHAR) AS firmware_version,
    median(
      date_diff(
        'hour',
        CAST(dt AS TIMESTAMP),
        strptime(replace(CAST(reading_ts AS VARCHAR), 'Z', ''), '%Y-%m-%dT%H:%M:%S')
      )
    ) AS med_h,
    count(*) AS n
  FROM raw_telemetry
  GROUP BY 1
),
base AS (
  SELECT median(med_h) AS baseline_h FROM by_fw
),
raw AS (
  SELECT
    f.firmware_version,
    f.med_h,
    f.n,
    b.baseline_h,
    CAST(round(f.med_h - b.baseline_h, 0) AS INTEGER) AS raw_offset_hours
  FROM by_fw f
  CROSS JOIN base b
)
SELECT
  firmware_version,
  med_h,
  n,
  baseline_h,
  raw_offset_hours,
  CASE WHEN abs(raw_offset_hours) >= 2 THEN raw_offset_hours ELSE 0 END AS observed_offset_hours
FROM raw;

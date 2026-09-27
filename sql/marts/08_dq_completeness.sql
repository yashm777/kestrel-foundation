CREATE OR REPLACE TABLE dq_partition_recon AS
SELECT
  i.feed,
  i.partition,
  any_value(m.file_count) AS manifest_files,
  any_value(m.row_count) AS manifest_rows,
  count(*) AS observed_files,
  coalesce(sum(CASE WHEN i.read_status = 'OK' THEN i.actual_rows ELSE 0 END), 0) AS observed_rows_ok,
  count(*) FILTER (WHERE i.read_status <> 'OK') AS corrupt_files
FROM file_inventory i
LEFT JOIN ingest_manifest m
  ON i.feed = m.feed AND i.partition = m.partition
GROUP BY i.feed, i.partition;

CREATE OR REPLACE TABLE dq_affected_partitions AS
SELECT path, feed, partition, bytes, actual_rows, read_status, error
FROM file_inventory
WHERE read_status <> 'OK';

-- Primary outage detector: expected gateway × every date that has *any* telemetry.
-- A single dead gateway is visible even if total volume barely moves.
CREATE OR REPLACE TABLE dq_gateway_date AS
WITH gateways AS (
  SELECT DISTINCT CAST(gateway_id AS VARCHAR) AS gateway_id FROM raw_telemetry
),
dates AS (
  SELECT DISTINCT CAST(dt AS DATE) AS dt FROM raw_telemetry
),
expected AS (
  SELECT * FROM gateways CROSS JOIN dates
),
observed AS (
  SELECT
    CAST(gateway_id AS VARCHAR) AS gateway_id,
    CAST(dt AS DATE) AS dt,
    count(*) AS reading_count
  FROM raw_telemetry
  GROUP BY 1, 2
)
SELECT
  e.gateway_id,
  e.dt,
  coalesce(o.reading_count, 0) AS reading_count,
  (o.reading_count IS NULL) AS is_missing
FROM expected e
LEFT JOIN observed o USING (gateway_id, dt);

CREATE OR REPLACE TABLE dq_missing_gateway_days AS
SELECT gateway_id, dt, reading_count
FROM dq_gateway_date
WHERE is_missing
ORDER BY dt, gateway_id;

-- Secondary: daily volume vs the series mean. Not used as the outage detector.
CREATE OR REPLACE TABLE dq_daily_telemetry_volume AS
SELECT
  CAST(dt AS DATE) AS dt,
  count(*) AS readings,
  avg(count(*)) OVER () AS mean_readings
FROM raw_telemetry
GROUP BY 1;

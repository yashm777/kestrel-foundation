SELECT * FROM (
  SELECT 'corrupt_file' AS issue, feed, partition, path AS detail, 1 AS n
  FROM dq_affected_partitions
  UNION ALL
  SELECT
    'manifest_row_mismatch' AS issue,
    feed,
    partition,
    CAST(observed_rows_ok AS VARCHAR) || ' vs ' || CAST(manifest_rows AS VARCHAR) AS detail,
    1 AS n
  FROM dq_partition_recon
  WHERE manifest_rows IS NOT NULL
    AND observed_rows_ok IS DISTINCT FROM manifest_rows
  UNION ALL
  SELECT
    'missing_gateway_day' AS issue,
    'reefer_telemetry' AS feed,
    CAST(dt AS VARCHAR) AS partition,
    gateway_id AS detail,
    1 AS n
  FROM dq_missing_gateway_days
)
ORDER BY issue, feed, partition, detail;

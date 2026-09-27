-- SCD2 from CDC. Order by commit time then capture sequence, not extract file arrival.
-- I/U rows become versions; D closes the prior version via LEAD on the full stream.
CREATE OR REPLACE TABLE dim_outlet_scd2 AS
WITH parsed AS (
  SELECT
    outlet_code,
    outlet_name,
    channel,
    outlet_format,
    city,
    route_code,
    warehouse_code,
    credit_limit,
    credit_terms_days,
    gst_number,
    status,
    __op,
    __seq,
    strptime(replace(CAST(__op_ts AS VARCHAR), 'Z', ''), '%Y-%m-%dT%H:%M:%S') AS op_ts,
    CAST(extract_date AS DATE) AS extract_date
  FROM raw_outlet
),
ordered AS (
  SELECT
    *,
    lead(op_ts) OVER (PARTITION BY outlet_code ORDER BY op_ts, __seq) AS next_ts
  FROM parsed
)
SELECT
  outlet_code,
  outlet_name,
  channel,
  outlet_format,
  city,
  route_code,
  warehouse_code,
  credit_limit,
  credit_terms_days,
  gst_number,
  status,
  __op,
  __seq,
  extract_date,
  op_ts AS valid_from,
  coalesce(next_ts, TIMESTAMP '9999-12-31 00:00:00') AS valid_to
FROM ordered
WHERE __op IN ('I', 'U');

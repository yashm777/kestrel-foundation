CREATE OR REPLACE MACRO report_week(d) AS
  DATE '2025-01-01' + (
    CAST(floor(date_diff('day', DATE '2025-01-01', CAST(d AS DATE)) / 7.0) AS INTEGER) * 7
  ) * INTERVAL 1 DAY;

CREATE OR REPLACE TABLE stg_pos AS
WITH parsed AS (
  SELECT
    txn_id,
    txn_line_no,
    basket_id,
    outlet_code,
    channel AS till_channel,
    sku_code,
    strptime(replace(CAST(event_ts AS VARCHAR), 'Z', ''), '%Y-%m-%dT%H:%M:%S') AS event_ts_utc,
    CAST(ingest_date AS DATE) AS ingest_date,
    CAST(COALESCE(qty, quantity_units) AS DOUBLE) AS qty,
    CAST(uom AS VARCHAR) AS uom,
    CAST(unit_price AS DOUBLE) AS unit_price,
    CAST(discount_amount AS DOUBLE) AS discount_amount,
    CAST(tax_amount AS DOUBLE) AS tax_amount,
    CAST(payment_mode AS VARCHAR) AS payment_mode,
    CAST(source_file AS VARCHAR) AS source_file
  FROM raw_pos
),
enriched AS (
  SELECT
    *,
    event_ts_utc + INTERVAL 5 HOUR + INTERVAL 30 MINUTE AS event_ts_ist,
    CAST(event_ts_utc + INTERVAL 5 HOUR + INTERVAL 30 MINUTE AS DATE) AS business_date,
    qty * unit_price AS gross_sales_inr,
    row_number() OVER (
      PARTITION BY txn_id, txn_line_no
      ORDER BY ingest_date, event_ts_utc
    ) AS rn
  FROM parsed
)
SELECT * EXCLUDE (rn)
FROM enriched
WHERE rn = 1;

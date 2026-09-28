-- Current order header. The attribute row is the latest I/U by (__op_ts, __seq).
-- A hard delete tombstones the order when that delete has the highest __seq.
-- Order deletes copy the insert's __op_ts, so time-order alone would resurrect them.
CREATE OR REPLACE TABLE stg_orders AS
WITH parsed AS (
  SELECT
    order_number,
    outlet_code,
    warehouse_code,
    route_code,
    CAST(order_date AS DATE) AS order_date,
    CAST(requested_delivery_date AS DATE) AS requested_delivery_date,
    order_status,
    line_count,
    CAST(order_value_gross AS DOUBLE) AS order_value_gross,
    CAST(discount_amount AS DOUBLE) AS discount_amount,
    CAST(tax_amount AS DOUBLE) AS tax_amount,
    CAST(source_system AS VARCHAR) AS source_system,
    __op,
    __seq,
    strptime(replace(CAST(__op_ts AS VARCHAR), 'Z', ''), '%Y-%m-%dT%H:%M:%S') AS op_ts
  FROM raw_orders
),
tombstone AS (
  SELECT order_number
  FROM parsed
  GROUP BY order_number
  HAVING max(__seq) = max(CASE WHEN __op = 'D' THEN __seq END)
),
latest AS (
  SELECT * EXCLUDE (rn)
  FROM (
    SELECT
      *,
      row_number() OVER (PARTITION BY order_number ORDER BY op_ts DESC, __seq DESC) AS rn
    FROM parsed
    WHERE __op <> 'D'
      AND order_number NOT IN (SELECT order_number FROM tombstone)
  )
  WHERE rn = 1
)
SELECT * EXCLUDE (__op, __seq)
FROM latest;

CREATE OR REPLACE TABLE dq_order_source_profile AS
SELECT
  source_system,
  count(*) AS orders,
  round(avg(order_value_gross), 2) AS mean_gross,
  round(median(order_value_gross), 2) AS median_gross
FROM stg_orders
GROUP BY 1;

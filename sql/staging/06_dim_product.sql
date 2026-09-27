-- Current product master: latest CDC record by __op_ts, __seq. Tombstones dropped.
-- Historical product SCD2 is intentionally not built (no KPI needs it).
CREATE OR REPLACE TABLE dim_product AS
WITH parsed AS (
  SELECT
    sku_code,
    product_name,
    category,
    brand,
    case_pack,
    mrp,
    list_price,
    gst_rate_pct,
    shelf_life_days,
    is_chilled,
    status,
    __op,
    __seq,
    strptime(replace(CAST(__op_ts AS VARCHAR), 'Z', ''), '%Y-%m-%dT%H:%M:%S') AS op_ts
  FROM raw_product
),
latest AS (
  SELECT * EXCLUDE (rn)
  FROM (
    SELECT
      *,
      row_number() OVER (PARTITION BY sku_code ORDER BY op_ts DESC, __seq DESC) AS rn
    FROM parsed
  )
  WHERE rn = 1
)
SELECT * EXCLUDE (__op, __seq, op_ts)
FROM latest
WHERE __op <> 'D';

CREATE OR REPLACE TABLE dq_uom_vs_case_pack AS
SELECT
  count(*) AS product_skus,
  count(u.sku_code) AS with_uom_row,
  count(*) FILTER (WHERE u.sku_code IS NULL) AS missing_uom_row,
  count(*) FILTER (WHERE u.eaches_per_case = p.case_pack) AS case_pack_matches_uom,
  count(*) FILTER (WHERE u.sku_code IS NOT NULL AND u.eaches_per_case IS DISTINCT FROM p.case_pack) AS case_pack_differs_uom
FROM dim_product p
LEFT JOIN uom_conversion u USING (sku_code);

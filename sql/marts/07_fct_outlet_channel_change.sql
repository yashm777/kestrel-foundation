CREATE OR REPLACE TABLE fct_outlet_channel_change AS
SELECT
  a.outlet_code,
  b.valid_from AS changed_at,
  a.channel AS channel_from,
  b.channel AS channel_to,
  a.outlet_name
FROM dim_outlet_scd2 a
JOIN dim_outlet_scd2 b
  ON a.outlet_code = b.outlet_code
 AND a.valid_to = b.valid_from
 AND a.valid_from < b.valid_from
WHERE a.channel IS DISTINCT FROM b.channel;

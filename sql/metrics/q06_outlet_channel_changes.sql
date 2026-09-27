SELECT
  outlet_code,
  outlet_name,
  changed_at,
  channel_from,
  channel_to
FROM fct_outlet_channel_change
ORDER BY changed_at, outlet_code;

SELECT
  report_week,
  channel,
  canonical_gross,
  legacy_gross,
  published_gross,
  canonical_minus_legacy,
  legacy_minus_published,
  canonical_minus_published,
  impact_dedupe,
  impact_date_attribution
FROM fct_finance_recon
ORDER BY report_week, channel;

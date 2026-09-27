-- Three-way recon at the Finance report grain: 7-day origin buckets from 2025-01-01
-- (the CSV column is named week_ending; it is that origin date) × till channel.
-- Canonical = event-date week, deduped.
-- Legacy method = ingest-date week, not deduped (the bugs Supply Chain described).
-- impact_dedupe: ingest-week, raw minus ingest-week, deduped.
-- impact_date_attribution: ingest-week, deduped minus business-week, deduped.
CREATE OR REPLACE TABLE fct_finance_recon AS
WITH published AS (
  SELECT
    CAST(week_ending AS DATE) AS report_week,
    channel,
    CAST(gross_sales_inr AS DOUBLE) AS published_gross,
    CAST(units_sold AS DOUBLE) AS published_units,
    CAST(basket_count AS DOUBLE) AS published_baskets
  FROM legacy_finance_weekly_report
),
canonical AS (
  SELECT
    CAST(report_week(business_date) AS DATE) AS report_week,
    till_channel AS channel,
    round(sum(gross_sales_inr), 2) AS canonical_gross,
    round(sum(CASE WHEN conversion_status = 'CONVERTED' THEN eaches END), 2) AS canonical_units,
    count(DISTINCT basket_id) AS canonical_baskets
  FROM fct_pos_line
  GROUP BY 1, 2
),
legacy_method AS (
  SELECT
    CAST(report_week(CAST(ingest_date AS DATE)) AS DATE) AS report_week,
    channel,
    round(sum(CAST(COALESCE(qty, quantity_units) AS DOUBLE) * CAST(unit_price AS DOUBLE)), 2) AS legacy_gross
  FROM raw_pos
  GROUP BY 1, 2
),
ingest_deduped AS (
  SELECT
    CAST(report_week(ingest_date) AS DATE) AS report_week,
    till_channel AS channel,
    round(sum(gross_sales_inr), 2) AS ingest_deduped_gross
  FROM stg_pos
  GROUP BY 1, 2
)
SELECT
  coalesce(p.report_week, c.report_week, l.report_week, d.report_week) AS report_week,
  coalesce(p.channel, c.channel, l.channel, d.channel) AS channel,
  c.canonical_gross,
  l.legacy_gross,
  p.published_gross,
  round(c.canonical_gross - l.legacy_gross, 2) AS canonical_minus_legacy,
  round(l.legacy_gross - p.published_gross, 2) AS legacy_minus_published,
  round(c.canonical_gross - p.published_gross, 2) AS canonical_minus_published,
  round(l.legacy_gross - d.ingest_deduped_gross, 2) AS impact_dedupe,
  round(d.ingest_deduped_gross - c.canonical_gross, 2) AS impact_date_attribution
FROM published p
FULL OUTER JOIN canonical c USING (report_week, channel)
FULL OUTER JOIN legacy_method l USING (report_week, channel)
FULL OUTER JOIN ingest_deduped d USING (report_week, channel);

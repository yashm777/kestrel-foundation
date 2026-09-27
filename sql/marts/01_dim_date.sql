CREATE OR REPLACE TABLE dim_date AS
SELECT
  CAST(calendar_date AS DATE) AS calendar_date,
  fiscal_year,
  fiscal_quarter,
  fiscal_month_no,
  iso_week,
  day_of_week,
  CAST(is_weekend AS INTEGER) AS is_weekend,
  CAST(report_week(CAST(calendar_date AS DATE)) AS DATE) AS report_week
FROM fiscal_calendar;

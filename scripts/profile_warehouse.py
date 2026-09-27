import duckdb

con = duckdb.connect(r"warehouse/kestrel.duckdb", read_only=True)
print("=== firmware clock ===")
print(con.execute("SELECT * FROM dq_firmware_clock ORDER BY n DESC").fetchdf().to_string(index=False))
print("\n=== uom vs case_pack ===")
print(con.execute("SELECT * FROM dq_uom_vs_case_pack").fetchdf().to_string(index=False))
print("\n=== conversion_source ===")
print(
    con.execute(
        "SELECT conversion_source, conversion_status, count(*) n FROM fct_pos_line GROUP BY 1,2 ORDER BY 3 DESC"
    ).fetchdf().to_string(index=False)
)
print("\n=== finance recon totals ===")
print(
    con.execute(
        """
        SELECT
          round(sum(canonical_gross)/1e9, 3) canon_bn,
          round(sum(legacy_gross)/1e9, 3) legacy_bn,
          round(sum(published_gross)/1e9, 3) pub_bn,
          round(sum(abs(canonical_minus_published))/1e9, 3) abs_canon_pub_bn,
          round(sum(abs(legacy_minus_published))/1e9, 3) abs_leg_pub_bn,
          round(sum(impact_dedupe)/1e6, 2) dedupe_m,
          round(sum(impact_date_attribution)/1e6, 2) date_m
        FROM fct_finance_recon
        """
    ).fetchdf().to_string(index=False)
)
print("\n=== corr published vs methods ===")
print(
    con.execute(
        """
        SELECT
          corr(canonical_gross, published_gross) corr_canon,
          corr(legacy_gross, published_gross) corr_legacy,
          corr(canonical_gross, legacy_gross) corr_canon_legacy
        FROM fct_finance_recon
        WHERE published_gross IS NOT NULL
        """
    ).fetchdf().to_string(index=False)
)
print("\n=== missing gateway days ===")
print(
    con.execute(
        "SELECT gateway_id, min(dt) a, max(dt) b, count(*) n FROM dq_missing_gateway_days GROUP BY 1 ORDER BY n DESC LIMIT 10"
    ).fetchdf().to_string(index=False)
)
print(con.execute("SELECT * FROM dq_missing_gateway_days WHERE gateway_id='GW-017' ORDER BY dt").fetchdf().to_string(index=False))
print("\n=== affected ===")
print(con.execute("SELECT feed, partition, read_status FROM dq_affected_partitions").fetchdf().to_string(index=False))
print("\n=== partition recon 2025-07-14 ===")
print(con.execute("SELECT * FROM dq_partition_recon WHERE partition LIKE '%2025-07-14%'").fetchdf().to_string(index=False))
print("\n=== order source ===")
print(con.execute("SELECT * FROM dq_order_source_profile").fetchdf().to_string(index=False))
print("\n=== channel changes ===", con.execute("SELECT count(*) FROM fct_outlet_channel_change").fetchone()[0])
print("\n=== wms coverage ===")
print(
    con.execute(
        """
        SELECT sum(orders_with_scans) o, sum(complete_journeys) c,
               round(100.0*sum(complete_journeys)/sum(orders_with_scans),2) pct
        FROM fct_wms_cycle_warehouse
        """
    ).fetchdf().to_string(index=False)
)
print("\n=== cold chain overall ===")
print(
    con.execute(
        """
        SELECT
          round(100.0*count(*) FILTER (WHERE has_above_limit_excursion)/count(*) FILTER (WHERE valid_readings>0), 2) above_pct,
          round(100.0*count(*) FILTER (WHERE has_outside_band_excursion)/count(*) FILTER (WHERE valid_readings>0), 2) outside_pct
        FROM fct_cold_chain_trip
        """
    ).fetchdf().to_string(index=False)
)
print("\n=== raw pos qty vs quantity_units ===")
print(
    con.execute(
        "SELECT count(*) FILTER (WHERE qty IS NOT NULL) qty, count(*) FILTER (WHERE quantity_units IS NOT NULL) q_units FROM raw_pos"
    ).fetchdf().to_string(index=False)
)
con.close()

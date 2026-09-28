import duckdb


def test_pos_line_grain_is_unique(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        dupes = con.execute(
            """
            SELECT count(*) FROM (
              SELECT txn_id, txn_line_no, count(*) AS n
              FROM fct_pos_line
              GROUP BY 1, 2
              HAVING count(*) > 1
            )
            """
        ).fetchone()[0]
        assert dupes == 0
    finally:
        con.close()


def test_canonical_temperature_is_celsius(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        med_c = con.execute(
            """
            SELECT
              median(temperature_c) FILTER (WHERE telemetry_vendor = 'COLDEYE') AS cold,
              median(temperature_c) FILTER (WHERE telemetry_vendor = 'THERMLOG') AS therm
            FROM stg_telemetry
            WHERE temperature_c IS NOT NULL
            """
        ).fetchone()
        assert med_c[0] is not None and med_c[1] is not None
        assert abs(med_c[0] - med_c[1]) < 3, med_c
        hot = con.execute(
            """
            SELECT count(*) FROM stg_telemetry
            WHERE temperature_c IS NOT NULL AND temperature_c > 60
            """
        ).fetchone()[0]
        assert hot == 0
    finally:
        con.close()


def test_conversion_status_populated_and_units_exclude_unknown(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        bad = con.execute(
            "SELECT count(*) FROM fct_pos_line WHERE conversion_status IS NULL"
        ).fetchone()[0]
        assert bad == 0
        leaked = con.execute(
            """
            SELECT count(*) FROM fct_pos_line
            WHERE conversion_status = 'UNKNOWN' AND eaches IS NOT NULL
            """
        ).fetchone()[0]
        assert leaked == 0
    finally:
        con.close()


def test_gateway_coverage_is_reported(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        holes = con.execute(
            "SELECT count(*) FROM dq_missing_gateway_days"
        ).fetchone()[0]
        assert holes >= 1
        cols = [r[0] for r in con.execute("DESCRIBE dq_gateway_date").fetchall()]
        assert "gateway_id" in cols and "is_missing" in cols
    finally:
        con.close()


def test_corrupt_files_remain_visible(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        n = con.execute("SELECT count(*) FROM dq_affected_partitions").fetchone()[0]
        status = con.execute("SELECT status FROM pipeline_run").fetchone()[0]
        assert n >= 1
        assert status in {"DEGRADED", "FAILED"}
    finally:
        con.close()


def test_deleted_orders_stay_tombstoned(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        revived = con.execute(
            """
            WITH tombstone AS (
              SELECT order_number
              FROM raw_orders
              GROUP BY order_number
              HAVING max(__seq) = max(CASE WHEN __op = 'D' THEN __seq END)
            )
            SELECT count(*)
            FROM stg_orders
            WHERE order_number IN (SELECT order_number FROM tombstone)
            """
        ).fetchone()[0]
        assert revived == 0
    finally:
        con.close()


def test_channel_changes_are_unique_and_have_duration(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        zero_len = con.execute(
            "SELECT count(*) FROM dim_outlet_scd2 WHERE valid_from >= valid_to"
        ).fetchone()[0]
        dupes = con.execute(
            """
            SELECT count(*) FROM (
              SELECT outlet_code, changed_at, channel_from, channel_to, count(*) AS n
              FROM fct_outlet_channel_change
              GROUP BY 1, 2, 3, 4
              HAVING count(*) > 1
            )
            """
        ).fetchone()[0]
        assert zero_len == 0
        assert dupes == 0
    finally:
        con.close()


def test_outlet_asof_not_always_current_channel(db_path):
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        mismatches = con.execute(
            """
            WITH current AS (
              SELECT outlet_code, channel AS current_channel
              FROM (
                SELECT outlet_code, channel, row_number() OVER (
                  PARTITION BY outlet_code ORDER BY valid_from DESC
                ) AS rn
                FROM dim_outlet_scd2
              )
              WHERE rn = 1
            )
            SELECT count(*)
            FROM fct_pos_line p
            JOIN current c USING (outlet_code)
            WHERE p.outlet_channel_asof IS NOT NULL
              AND p.outlet_channel_asof IS DISTINCT FROM c.current_channel
            """
        ).fetchone()[0]
        changes = con.execute("SELECT count(*) FROM fct_outlet_channel_change").fetchone()[0]
        if changes == 0:
            assert mismatches == 0
        else:
            assert mismatches >= 1
    finally:
        con.close()

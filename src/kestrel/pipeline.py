"""DuckDB pipeline: inventory, fail-loud ingest, SQL transforms."""

from __future__ import annotations

import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import duckdb
import pandas as pd
import pyarrow.parquet as pq

FEED_DIRS = (
    ("pos_transactions", "raw/pos_transactions"),
    ("reefer_telemetry", "raw/reefer_telemetry"),
    ("wms_scan_events", "raw/wms_scan_events"),
    ("outlet_master", "raw/erp_cdc/outlet_master"),
    ("product_master", "raw/erp_cdc/product_master"),
    ("sales_order_header", "raw/erp_cdc/sales_order_header"),
)

REF_TABLES = (
    ("uom_conversion", "reference/uom_conversion.csv"),
    ("warehouse_master", "reference/warehouse_master.csv"),
    ("carrier_master", "reference/carrier_master.csv"),
    ("fiscal_calendar", "reference/fiscal_calendar.csv"),
    ("legacy_finance_weekly_report", "reference/legacy_finance_weekly_report.csv"),
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _posix(path: Path | str) -> str:
    return str(path).replace("\\", "/")


def inspect_parquet(path: Path) -> dict:
    try:
        pf = pq.ParquetFile(path)
        return {
            "actual_rows": int(pf.metadata.num_rows),
            "read_status": "OK",
            "error": None,
        }
    except Exception as exc:  # noqa: BLE001 — any footer/read failure is CORRUPT
        return {"actual_rows": None, "read_status": "CORRUPT", "error": str(exc)[:500]}


def build_file_inventory(data_dir: Path) -> pd.DataFrame:
    rows = []
    for feed, rel in FEED_DIRS:
        root = data_dir / rel
        if not root.exists():
            continue
        for parquet in sorted(root.rglob("*.parquet")):
            part = parquet.parent.name
            info = inspect_parquet(parquet)
            rows.append(
                {
                    "path": _posix(parquet),
                    "feed": feed,
                    "partition": part,
                    "bytes": parquet.stat().st_size,
                    **info,
                }
            )
    return pd.DataFrame(rows)


def _sql_file_list(paths: list[str]) -> str:
    return "[" + ", ".join("'" + p.replace("'", "''") + "'" for p in paths) + "]"


def _create_parquet_table(
    con: duckdb.DuckDBPyConnection,
    table: str,
    files: list[str],
    union_by_name: bool = False,
) -> None:
    if not files:
        raise RuntimeError(f"No readable parquet files for {table}")
    opts = "hive_partitioning=true"
    if union_by_name:
        opts += ", union_by_name=true"
    con.execute(
        f"CREATE OR REPLACE TABLE {table} AS SELECT * FROM read_parquet({_sql_file_list(files)}, {opts})"
    )


def _run_sql_dir(con: duckdb.DuckDBPyConnection, folder: Path) -> None:
    for path in sorted(folder.glob("*.sql")):
        print(f"  {path.name}", flush=True)
        con.execute(path.read_text(encoding="utf-8"))


def _ensure_pipeline_run_table(con: duckdb.DuckDBPyConnection) -> None:
    con.execute(
        """
        CREATE TABLE IF NOT EXISTS pipeline_run (
            run_id VARCHAR,
            started_at TIMESTAMP,
            finished_at TIMESTAMP,
            status VARCHAR,
            source_row_count BIGINT,
            canonical_row_count BIGINT,
            duplicate_count BIGINT,
            bad_file_count BIGINT,
            warning_count BIGINT,
            message VARCHAR
        )
        """
    )


def _insert_run(con: duckdb.DuckDBPyConnection, row: dict) -> None:
    _ensure_pipeline_run_table(con)
    con.execute("DELETE FROM pipeline_run")
    con.execute(
        """
        INSERT INTO pipeline_run
        (run_id, started_at, finished_at, status, source_row_count, canonical_row_count,
         duplicate_count, bad_file_count, warning_count, message)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            row["run_id"],
            row["started_at"],
            row["finished_at"],
            row["status"],
            row.get("source_row_count"),
            row.get("canonical_row_count"),
            row.get("duplicate_count"),
            row.get("bad_file_count", 0),
            row.get("warning_count", 0),
            row.get("message"),
        ],
    )


def print_run_summary(con: duckdb.DuckDBPyConnection) -> None:
    rec = con.execute("SELECT * FROM pipeline_run LIMIT 1").fetchdf()
    if rec.empty:
        print("No pipeline_run row.", flush=True)
        return
    r = rec.iloc[0]
    print("\n--- pipeline_run ---", flush=True)
    print(f"Run:     {r['started_at']}", flush=True)
    print(f"Status:  {r['status']}", flush=True)
    print(f"POS in:  {r['source_row_count']:,}" if pd.notna(r["source_row_count"]) else "POS in:  n/a", flush=True)
    print(
        f"POS out: {r['canonical_row_count']:,}" if pd.notna(r["canonical_row_count"]) else "POS out: n/a",
        flush=True,
    )
    print(
        f"POS duplicates removed: {r['duplicate_count']:,}"
        if pd.notna(r["duplicate_count"])
        else "POS duplicates removed: n/a",
        flush=True,
    )
    print(f"Unreadable files: {r['bad_file_count']}", flush=True)
    print(f"Warnings: {r['warning_count']}", flush=True)
    if r["message"]:
        print(f"Message: {r['message']}", flush=True)


def run_pipeline(
    data_dir: Path,
    out_path: Path,
    allow_degraded_input: bool = False,
) -> str:
    started = datetime.now(timezone.utc).replace(tzinfo=None)
    run_id = str(uuid.uuid4())
    data_dir = data_dir.resolve()
    out_path = out_path.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print("Inventory ...", flush=True)
    inventory = build_file_inventory(data_dir)
    if inventory.empty:
        raise FileNotFoundError(f"No parquet under {data_dir / 'raw'}. Run generate_dataset.py first.")

    bad = inventory[inventory["read_status"] != "OK"]
    bad_n = int(len(bad))

    if out_path.exists():
        out_path.unlink()
    con = duckdb.connect(str(out_path))
    con.execute("SET preserve_insertion_order = false")
    con.register("inventory_df", inventory)
    con.execute("CREATE OR REPLACE TABLE file_inventory AS SELECT * FROM inventory_df")
    con.unregister("inventory_df")

    manifest = data_dir / "_manifest" / "expected_partitions.csv"
    if manifest.exists():
        con.execute(
            f"""
            CREATE OR REPLACE TABLE ingest_manifest AS
            SELECT * FROM read_csv_auto('{_posix(manifest)}', header=true)
            """
        )
    else:
        con.execute(
            """
            CREATE OR REPLACE TABLE ingest_manifest AS
            SELECT CAST(NULL AS VARCHAR) AS feed, CAST(NULL AS VARCHAR) AS partition,
                   CAST(NULL AS INTEGER) AS file_count, CAST(NULL AS BIGINT) AS row_count,
                   CAST(NULL AS BIGINT) AS bytes WHERE 1=0
            """
        )

    if bad_n and not allow_degraded_input:
        msg = (
            f"{bad_n} unreadable parquet file(s). Refusing to publish metrics. "
            "Re-run with --allow-degraded-input to continue; affected partitions stay in file_inventory."
        )
        _insert_run(
            con,
            {
                "run_id": run_id,
                "started_at": started,
                "finished_at": datetime.now(timezone.utc).replace(tzinfo=None),
                "status": "FAILED",
                "bad_file_count": bad_n,
                "warning_count": bad_n,
                "message": msg,
            },
        )
        print(msg, flush=True)
        print("Corrupt files:", flush=True)
        print(bad[["path", "feed", "partition", "error"]].to_string(index=False), flush=True)
        print_run_summary(con)
        con.close()
        return "FAILED"

    status = "DEGRADED" if bad_n else "SUCCESS"
    ok = inventory[inventory["read_status"] == "OK"]

    print("Reference ...", flush=True)
    for table, rel in REF_TABLES:
        path = data_dir / rel
        if not path.exists():
            raise FileNotFoundError(path)
        con.execute(
            f"CREATE OR REPLACE TABLE {table} AS SELECT * FROM read_csv_auto('{_posix(path)}', header=true)"
        )

    print("Raw feeds ...", flush=True)
    by_feed = {feed: ok.loc[ok.feed == feed, "path"].tolist() for feed, _ in FEED_DIRS}
    _create_parquet_table(con, "raw_pos", by_feed["pos_transactions"], union_by_name=True)
    _create_parquet_table(con, "raw_telemetry", by_feed["reefer_telemetry"])
    _create_parquet_table(con, "raw_wms", by_feed["wms_scan_events"])
    _create_parquet_table(con, "raw_outlet", by_feed["outlet_master"])
    _create_parquet_table(con, "raw_product", by_feed["product_master"])
    _create_parquet_table(con, "raw_orders", by_feed["sales_order_header"])

    sql_root = repo_root() / "sql"
    print("Staging ...", flush=True)
    _run_sql_dir(con, sql_root / "staging")
    print("Marts ...", flush=True)
    _run_sql_dir(con, sql_root / "marts")

    src = con.execute("SELECT count(*) FROM raw_pos").fetchone()[0]
    canon = con.execute("SELECT count(*) FROM fct_pos_line").fetchone()[0]
    holes = con.execute(
        "SELECT count(*) FROM dq_gateway_date WHERE reading_count = 0"
    ).fetchone()[0]
    warnings = bad_n + int(holes > 0)
    msg = None
    if bad_n:
        parts = ", ".join(sorted(bad["partition"].unique()))
        msg = f"DEGRADED: excluded {bad_n} corrupt file(s) in partition(s) {parts}. See dq_affected_partitions."

    _insert_run(
        con,
        {
            "run_id": run_id,
            "started_at": started,
            "finished_at": datetime.now(timezone.utc).replace(tzinfo=None),
            "status": status,
            "source_row_count": src,
            "canonical_row_count": canon,
            "duplicate_count": src - canon,
            "bad_file_count": bad_n,
            "warning_count": warnings,
            "message": msg,
        },
    )
    print_run_summary(con)
    con.close()
    return status

from pathlib import Path

import duckdb

from kestrel.pipeline import build_file_inventory, inspect_parquet, run_pipeline


def test_unreadable_parquet_is_registered(data_dir: Path):
    inv = build_file_inventory(data_dir)
    bad = inv[inv["read_status"] != "OK"]
    assert not bad.empty, "expected at least one unreadable parquet in the landing zone"
    assert (bad["feed"] == "reefer_telemetry").any()


def test_inspect_truncated_telemetry_part(data_dir: Path):
    hits = list((data_dir / "raw" / "reefer_telemetry").rglob("*.parquet"))
    corrupt = [p for p in hits if inspect_parquet(p)["read_status"] != "OK"]
    assert corrupt, "expected a parquet footer/read failure somewhere under reefer_telemetry"


def test_run_fails_without_allow_degraded(data_dir: Path, tmp_path: Path):
    out = tmp_path / "fail.duckdb"
    status = run_pipeline(data_dir, out, allow_degraded_input=False)
    assert status == "FAILED"
    con = duckdb.connect(str(out), read_only=True)
    try:
        inv = con.execute(
            "SELECT count(*) FROM file_inventory WHERE read_status <> 'OK'"
        ).fetchone()[0]
        run = con.execute("SELECT status FROM pipeline_run").fetchone()[0]
        assert inv >= 1
        assert run == "FAILED"
    finally:
        con.close()

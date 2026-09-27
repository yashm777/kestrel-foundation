from __future__ import annotations

import argparse
import sys
from pathlib import Path

from kestrel.pipeline import print_run_summary, run_pipeline
from kestrel.query import ask, list_queries
import duckdb


def _add_src_to_path() -> None:
    """Allow `python -m kestrel` from a clone without an editable install."""
    src = Path(__file__).resolve().parents[1]
    if str(src) not in sys.path:
        sys.path.insert(0, str(src))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="kestrel",
        description="Kestrel Provisions analytical foundation",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    run = sub.add_parser("run", help="Build the DuckDB warehouse from raw feeds")
    run.add_argument("--data-dir", type=Path, default=Path("data"))
    run.add_argument("--out", type=Path, default=Path("warehouse/kestrel.duckdb"))
    run.add_argument(
        "--allow-degraded-input",
        action="store_true",
        help="Continue after unreadable parquet; mark the run DEGRADED and record affected partitions",
    )

    ask_p = sub.add_parser("ask", help="Run a catalogue query and print the SQL")
    ask_p.add_argument("query_id")
    ask_p.add_argument("--db", type=Path, default=Path("warehouse/kestrel.duckdb"))
    ask_p.add_argument("--fy")
    ask_p.add_argument("--quarter")
    ask_p.add_argument("--month")
    ask_p.add_argument("--week")
    ask_p.add_argument("--channel")
    ask_p.add_argument("--warehouse")

    sub.add_parser("list", help="List catalogue KPIs and queries")

    sql_p = sub.add_parser("sql", help="Run ad-hoc SQL against the warehouse (printed first)")
    sql_p.add_argument("statement")
    sql_p.add_argument("--db", type=Path, default=Path("warehouse/kestrel.duckdb"))

    args = parser.parse_args(argv)

    if args.cmd == "run":
        status = run_pipeline(args.data_dir, args.out, args.allow_degraded_input)
        return 0 if status in {"SUCCESS", "DEGRADED"} else 1

    if args.cmd == "list":
        list_queries()
        return 0

    if args.cmd == "ask":
        if not args.db.exists():
            raise SystemExit(f"Warehouse not found: {args.db}. Run `python -m kestrel run` first.")
        ask(
            args.query_id,
            args.db,
            fy=args.fy,
            quarter=args.quarter,
            month=args.month,
            week=args.week,
            channel=args.channel,
            warehouse=args.warehouse,
        )
        return 0

    if args.cmd == "sql":
        print("QUERY")
        print("-----")
        print(args.statement.strip())
        print()
        con = duckdb.connect(str(args.db), read_only=True)
        try:
            df = con.execute(args.statement).fetchdf()
            print("RESULT")
            print("------")
            print(df.to_string(index=False) if not df.empty else "(no rows)")
            print()
            print_run_summary(con)
        finally:
            con.close()
        return 0

    return 2


if __name__ == "__main__":
    _add_src_to_path()
    raise SystemExit(main())

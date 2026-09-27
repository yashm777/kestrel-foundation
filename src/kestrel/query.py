"""Catalogue-backed ask: always print the SQL that ran."""

from __future__ import annotations

from pathlib import Path

import duckdb
import yaml

from kestrel.pipeline import print_run_summary, repo_root


def load_catalogue() -> dict:
    path = repo_root() / "catalogue" / "kpis.yml"
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def list_queries() -> None:
    cat = load_catalogue()
    print("KPIs")
    for kpi in cat.get("kpis", []):
        print(f"  {kpi['id']}: {kpi['name']}")
    print("\nQueries")
    for q in cat.get("queries", []):
        params = ",".join(q.get("params") or []) or "-"
        print(f"  {q['id']:40} source={q.get('source', '-'):24} params={params}")
        print(f"    {q.get('description', '')}")


def _bind(sql: str, params: dict[str, str | None]) -> str:
    out = sql
    for key, value in params.items():
        if value is None:
            continue
        out = out.replace("{{" + key + "}}", value.replace("'", "''"))
    return out


def ask(query_id: str, db_path: Path, **params: str | None) -> None:
    cat = load_catalogue()
    spec = next((q for q in cat.get("queries", []) if q["id"] == query_id), None)
    if spec is None:
        ids = ", ".join(q["id"] for q in cat.get("queries", []))
        raise SystemExit(f"Unknown query '{query_id}'. Known: {ids}")

    sql_path = repo_root() / "sql" / spec["sql"]
    raw_sql = sql_path.read_text(encoding="utf-8")
    missing = [p for p in (spec.get("params") or []) if not params.get(p)]
    if missing:
        raise SystemExit(f"Missing parameters: {', '.join(missing)}")
    sql = _bind(raw_sql, params)

    print("QUERY")
    print("-----")
    print(sql.strip())
    print()
    print("SOURCE")
    print("------")
    print(spec.get("source", sql_path.name))
    print()

    con = duckdb.connect(str(db_path), read_only=True)
    try:
        df = con.execute(sql).fetchdf()
        print("RESULT")
        print("------")
        if df.empty:
            print("(no rows)")
        else:
            print(df.to_string(index=False))
        print()
        print_run_summary(con)
    finally:
        con.close()

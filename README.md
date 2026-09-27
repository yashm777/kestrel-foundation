# Kestrel Provisions — analytical foundation

Canonical POS sales, SCD2 as-of outlet channel, three-way Finance reconciliation, cold-chain and warehouse metrics. DuckDB on a laptop. Every `ask` prints the SQL.

## Cold start

Python 3.10+. One machine.

```bash
pip install -r requirements.txt
pip install -e .

python generate_dataset.py --scale 1 --out data

python -m kestrel run --data-dir data --out warehouse/kestrel.duckdb
```

The first `run` **fails on purpose** if any parquet file is unreadable (the landing zone ships with a truncated telemetry part file). Inspect `file_inventory`, then:

```bash
python -m kestrel run --data-dir data --out warehouse/kestrel.duckdb --allow-degraded-input
```

That second run is `DEGRADED`. Affected partitions stay in `dq_affected_partitions` and are excluded from marts — they are not silently dropped.

```bash
python -m kestrel list
python -m kestrel ask q01_gross_sales_by_channel --fy FY27 --quarter Q1
python -m kestrel ask q02_finance_recon
python -m kestrel ask q09_recon_drilldown --week 2026-04-01 --channel MT
```

Each `ask` prints QUERY, SOURCE, RESULT, and the latest `pipeline_run` status.

If you did not `pip install -e .`:

```bash
# Windows PowerShell
$env:PYTHONPATH = "src"
python -m kestrel run --data-dir data --out warehouse/kestrel.duckdb --allow-degraded-input
```

## What this is

| Layer | Where |
|---|---|
| File inventory + corrupt detection | `file_inventory`, `pipeline_run` |
| Staging | `sql/staging/` |
| Marts | `sql/marts/` |
| KPI definitions | `catalogue/kpis.yml` |
| Runnable questions | `sql/metrics/` |

Do not commit `data/` or `warehouse/`. Regenerating with the vendored generator (seed `20260811`) reproduces the assignment dataset. `--scale 10` writes a larger copy (`--out data_10x`); the SQL is partition-aware via Hive paths but a full 10× load will pressure a laptop.

## Tests

```bash
pytest -q
```

Invariants: unique POS grain, Celsius temperatures, conversion coverage, gateway holes reported, corrupt files visible, as-of channel not always today’s master.

## Docs

- `DECISIONS.md` — what we built, what we did not, assumptions, what breaks first.
- `catalogue/kpis.yml` — metric definitions.

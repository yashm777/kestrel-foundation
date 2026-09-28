# Future enhancements — Cloud and AI

Version 1 is a DuckDB warehouse, a KPI catalogue, and a command-line tool that prints the SQL. This note is only the later path: the same contracts on a cloud runtime, and an assistant that can ask questions without inventing a new sales number.

Cloud and AI share one warehouse. The model does not get a second database. A second canonical number is how four sales figures become five.

---

## Cloud

The laptop is the right shape for about ten million rows. Cloud is the same SQL files and the same metric meanings, on a different runtime, once a nightly job, more than one user, or about ten times the volume makes one DuckDB process the bottleneck.

Move in this order.

### 1. Landing zone first

Copy the raw Hive folders (`ingest_date=`, `dt=`, `extract_date=`) to object storage (S3, GCS, or ADLS) with the same layout. Keep recent partitions hot and older ones on a cheaper tier. The pipeline already thinks in date folders. This is the first fix at ten times the volume.

**Pros.** The files already live in date folders, so ten times the data does not need a new layout. Recent days stay fast and older days stay cheap. The laptop pipeline can keep the same paths.

**Cons.** Storage alone does not make the job faster. A full scan of every temperature file still reads everything. There is now a second copy to secure, and a failed copy can drift from the laptop files.

### 2. Run the job you already have, on a schedule

A daily incremental load, orchestrated by Airflow, Dagster, or Azure Data Factory. `--allow-degraded-input` stays an explicit approval, not the default. Page someone when `pipeline_run` is `FAILED`, and when a new missing gateway-day appears. Target: marts ready by 06:00 India time.

**Pros.** Finance gets the same marts every morning. A failed run or a missing gateway pages someone. The degraded flag stays a human choice, so a bad file cannot become the quiet default.

**Cons.** An orchestrator is another system to run. A daily incremental load is not built yet. Until date filters exist, the schedule repeats the full laptop scan in the cloud.

### 3. Make DuckDB bigger before replacing it

A larger virtual machine, MotherDuck, or DuckDB reading object storage with a date filter. Same `sql/staging` and `sql/marts`. Measure time and memory at ten times the volume before buying a warehouse.

**Pros.** The SQL files stay the same. You learn the real time and memory at ten times the volume before paying for a warehouse. A larger machine or MotherDuck is a smaller jump.

**Cons.** DuckDB is still one engine. It is a weak fit for many people editing jobs at once, for strict role splits, and for disaster recovery. You may do this work and still move later.

### 4. A warehouse only after the SQL is stable

Snowflake, BigQuery, Databricks SQL, or Azure Fabric as a port of the existing SQL files. `catalogue/kpis.yml` stays the contract. A dbt wrapper can come after the models exist, so more than one engineer can own tests. It does not replace the models.

**Pros.** More users, backups, and access control come with the product. The sales definition does not change during the move, because the catalogue stays the contract.

**Cons.** Every SQL file must be ported. A dialect change can silently change a join or a date. Two engineers will be tempted to “improve” a metric during the port. Cost is easy to waste if temperature scans are still unfiltered.

### 5. Change data into a lakehouse table

Iceberg or Delta, so outlet history merges cleanly when a late extract arrives. Still order by `__op_ts`, then `__seq`. A delete with the highest sequence number still tombstones an order.

**Pros.** A late extract can be merged again safely. The current order-delete rule survives the move.

**Cons.** It is a new table format and a new merge job. It does not fix sales, temperature, or the Finance file. Doing it first delays the things that hurt at ten times the volume.

### 6. Access and recovery

Separate dev, stage, and prod. Say who may mark a run degraded and who may restate a Finance week. No secrets in git. A private link from the ERP extract. A backup of the marts. A local `.duckdb` file is not a disaster-recovery plan.

**Pros.** A restated Finance week and a degraded run both have a named owner. Secrets stay out of git. The laptop file is no longer the only copy.

**Cons.** Three environments cost money and slow a small team down. The rules do nothing if people still run the degraded flag by habit.

### Spark first

At a hundred times the volume, the bill is an unfiltered scan of all temperature history, not the sales history join. Spark is a staffing choice until you are well past that, or you need streaming.

**Pros.** It scales out, and it can stream.

**Cons.** This grain does not need a cluster yet, and someone has to operate it. The bill and the staffing arrive before the metric problem is solved.

### A laptop number and a cloud number side by side

One warehouse, one `pipeline_run` identity.

**Pros.** You can compare the two totals during a move.

**Cons.** Finance will quote whichever is convenient. That is the original problem of four sales figures.

**India and client data.** Assume data stays in an India region until told otherwise. Till-level cashier and loyalty ids are sensitive. Raw point-of-sale lines do not go into a training set.

---

## AI

The finance chief already set the product rule: ask anything, but show the query. That is a constraint on the assistant, not a reason to skip one. Free text-to-SQL on the raw files is how you get a sixth sales number and no lineage.

The catalogue and the saved metric SQL are the semantic layer. The assistant sits on top of them. It does not replace them.

### 1. Look up the contract before answering

Retrieve `catalogue/kpis.yml`, `DECISIONS.md`, and the metric SQL. A question first finds the metric id, the grain, the exclusions, and the known limitation. “Sales by carrier for chilled trips” must hit the limitation — telemetry has no `carrier_id` — and refuse with that sentence. It must not invent a join.

**Pros.** A question the catalogue cannot answer stops, and the reply cites the written limitation instead of inventing a join.

**Cons.** It can only answer what is already written. A fair question that is not in the catalogue gets a refusal. If the catalogue is wrong, the assistant repeats the wrong definition with confidence.

### 2. A closed set of tools

The model may only call:

- `list_metrics` and `explain_metric(metric_id)`
- `run_catalogue_query(query_id, params)` — the same path as `python -m kestrel ask`
- `pipeline_status` — the latest run: SUCCESS, DEGRADED, or FAILED
- `dq_holes` — unreadable files and missing gateway-days

Every answer must include the metric id, the SQL text, the source table, the pipeline status, and the limitation. If the run is FAILED, the assistant does not quote a number. If it is DEGRADED, it names the bad partition in the same breath as the figure.

**Pros.** The path is the same as the command-line tool. Every answer can show the SQL, the source table, and the run status. A failed run cannot quote a number.

**Cons.** People will ask for cuts that sit between the saved queries. Those need a human to add a metric file. A closed list feels limited next to a demo that writes any SQL.

### 3. Free-form SQL

Not in production. A developer notebook can draft SQL, and a human merges it into `sql/metrics/`.

**Pros.** A new cut does not wait on a developer, and a notebook draft is a reasonable way to grow the metric library.

**Cons.** In production this is another sales number with no lineage. It can join a carrier that is not on the feed, call orders “sales,” or hide a degraded run. The brief already turned that product down.

### 4. Test it before showing it

Hold out the eight sample questions, paraphrases (“last complete quarter” versus FY27 Q1), and traps (carrier, on-time-in-full, “make the number match Finance exactly”). Score the right query id, the right parameters, SQL shown, and a refusal when the catalogue cannot answer. No production assistant until refusals are reliable.

**Pros.** You catch a flashy demo that answers the trap questions wrong, before a stakeholder sees it.

**Cons.** The test set is small and written by the people who already know the holes. A new phrasing can still slip through. The tests delay the demo.

### 5. A person confirms the loud cases

Confirm before a degraded run is treated as board-ready. Confirm before a published Finance week is restated. The model proposes. Finance or Supply Chain accepts.

**Pros.** The model can prepare the sentence. A person still accepts the number that goes to the board. A bad file stays named out loud.

**Cons.** The assistant is slower than a direct question. If people confirm every time without reading, the control is theatre.

### 6. The model drafts engineer work, not board numbers

- Draft a staging map when a column is renamed (`qty` to `quantity_units`). A human commits it.
- Draft an incident from the missing-days table (“gateway GW-017 sent nothing on 11 and 12 February 2026”), using that table, not invented volumes.
- Draft a new metric file that follows an existing grain. A human merges it.

**Pros.** A rename, an outage note, or a new metric file starts as a draft a human commits. The outage text stays tied to a real table.

**Cons.** Drafts look finished. A human who stops reading them will commit a wrong column map or an incident with a made-up volume.

### 7. Fine-tune on till lines, or send raw lines to a public model

Do not. There is not enough labelled SQL, and the rows are sensitive. Send aggregates from catalogue queries only, through an India-region endpoint in the client’s own tenant (Azure OpenAI, Bedrock, or Vertex).

**Pros.** A fine-tuned model would sound closer to Kestrel’s own questions, and a public API is the fastest prototype.

**Cons.** There is not enough labelled SQL. Cashier and loyalty ids are sensitive. Raw lines should not leave the client’s India-region tenant.

### 8. A second metric layer beside the catalogue

Do not. Also do not demo a chat that cannot print the SQL. Do not call ERP order value “sales.” Do not rename the dispatch proxy to service level. Do not publish the dock-to-dispatch hours as a real cycle time.

**Pros.** A chat team could ship answers without waiting for a SQL change.

**Cons.** Two definitions of gross sales. That is the original meeting problem, with a model in the middle.

```text
User question
    → retrieve catalogue and decisions (limitations first)
    → choose query id and parameters, or refuse with the cited limitation
    → run that catalogue query on the warehouse (DuckDB now, cloud SQL later)
    → return prose, SQL, source table, and pipeline status
```

---

## If a cloud and AI workstream opens

1. Object storage with the same Hive layout, and a nightly incremental run.
2. An evaluation set and the closed tool list on the existing command-line tool.
3. A production chat only after those tests pass, and only while every answer still shows the SQL and the pipeline status.
4. A larger DuckDB, or a warehouse, after date-folder reads are proven at ten times the volume.
5. Lakehouse merges for change data. Still one canonical number.

An assistant without the metric catalogue is a demo. Cloud without reading only the date folders you need is a larger bill for the same full scan.

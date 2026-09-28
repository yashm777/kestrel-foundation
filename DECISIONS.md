# Decisions

Kestrel Provisions, take-home. Judgements that the SQL and CLI implement.

## Built

A DuckDB warehouse from the four raw feeds: fail-loud file inventory, POS unify/dedupe/IST, outlet SCD2 as-of on sales, current product + UOM, telemetry in °C with a profiled firmware clock, WMS cycle time, gateway×date completeness, three-way Finance recon with a duplicate vs ingest-date split, a KPI catalogue, and a CLI that always prints SQL.

## Not built

A dashboard or Streamlit. An LLM. Spark/dbt. Product SCD2 (no KPI needs historical MRP/GST). A carrier join (telemetry has no `carrier_id`). A second warehouse at scale 10. Rewriting source parquet. Treating ERP order value as sales.

## Sales

Canonical gross sales is POS `qty * unit_price` (tax exclusive), grain `txn_id + txn_line_no` after exact-duplicate drop.

- Business date is Asia/Kolkata from UTC `event_ts`, never `ingest_date`.
- Channel for the number the business should use is the outlet record valid at event time. If none covers the event, q01 uses `till_channel` (about 0.5% of lines).
- `till_channel` is kept so Finance recon isolates date and duplicate effects from SCD2.
- ERP headers are orders, not sales.

## Units

`conversion_source` is `UOM_REFERENCE`, `CDC_CASE_PACK`, or `UNKNOWN`. Case-pack fallback is used only when the UOM table misses a SKU and CDC `case_pack` matches the UOM grain on overlapping keys (verified in `dq_uom_vs_case_pack`). Pre-Oct 2025 lines have no `uom`; they stay in sales and drop out of units.

## Finance recon

Three series at the CSV grain (7-day origin from 2025-01-01 × channel): canonical (event week, deduped), legacy method (ingest week, not deduped), published file.

- Pairwise gaps, plus `impact_dedupe` and `impact_date_attribution`.
- Drilldown is `q09_recon_drilldown`.
- Reconciling means explaining. If the published file is not a function of POS, that is the finding.

## Corrupt files

Default `run` exits `FAILED` and still writes `file_inventory`. `--allow-degraded-input` is `DEGRADED`; marts omit the bad file; `dq_affected_partitions` names it. No silent skip.

## Cold chain

Clock correction is `observed_offset_hours` from `dq_firmware_clock` (firmware median hours from partition midnight, minus the cross-firmware median). Sign is not hard-coded.

- KPI excursion is **above 8°C**, as the contract.
- `outside_band_flag` is stored, not the published KPI.
- The key is vehicle + route + corrected device-clock date (not IST). `route_code` changes on nearly every reading, so this is a reading-level rate (~7%), not a vehicle-day rate (~75%).
- "About a third" matches Fahrenheit left unconverted. COLDEYE is about a third of devices.
- Q4 is month × warehouse × vendor. There is no `carrier_id`.

## CDC

Current state is `__op_ts`, then `__seq`. Last row in the latest extract file is wrong (late extracts, tied timestamps). A same-timestamp pair does not create a zero-length outlet version; `__seq` keeps the later row.

A delete tombstones the key when that delete has the highest `__seq`. Order deletes copy the insert timestamp, so time-order alone would resurrect all 2,880 of them. A later outlet update after a real delete is a new version.

## Service

`fct_dispatch_on_request` is a dispatch-on-request-date **proxy** with coverage. It is not OTIF.

`q05` is not a usable dock-to-dispatch time. Scans that share an `order_number` span a median of about 395 days and about four warehouses, so the median (~3,700 hours) is an artefact. Read `coverage_pct` (~15%). `q10` uses the same weak link.

## Assumptions

- POS `event_ts` trailing `Z` is UTC.
- WMS timestamps are site-local IST.
- Finance `week_ending` is the 7-day origin date, not a Sunday week-end.
- PARTNER_API `/1.085` is a suspected freight hypothesis.

## What we measured

Scale-1 landing zone, not from generator comments.

- Firmware `2.1.4` sits 7 hours ahead of other fleets vs partition midnight (`dq_firmware_clock`); we subtract 7 hours. A 1-hour blip on `3.0.2` is ignored as noise (`|offset| < 2`).
- UOM `eaches_per_case` equals CDC `case_pack` on every overlapping SKU (45 SKUs missing from the UOM table → `CDC_CASE_PACK`).
- Published Finance totals are uncorrelated with both canonical and legacy-method POS (`corr ≈ 0.005`); the file is not a function of the feed.
- Duplicate inflation is ~₹116m; date re-bucketing nets to ~0 across all weeks (it is a between-week transfer).
- GW-017 is missing on 2026-02-11 and 2026-02-12 only.
- Truncated file: `reefer_telemetry/dt=2025-07-14/part-00000`.
- PARTNER_API mean order value is ~8.6–8.9% above SFA/ERP.
- Above-8°C rate is ~7% at reading grain and ~28% outside the 2–8 band. Unconverted Fahrenheit is ~38%.
- Pre-drift POS is ~half of lines and cannot convert to eaches.

## Next two weeks

Partition-pruned incremental runs, a schema-drift alarm when a renamed column is not in the staging map, and quarantine plus replay for an unreadable file.

## What breaks first

At 10×, a full `raw_telemetry` scan in one DuckDB process. At 100×, laptop memory on POS as-of and telemetry. Fix: predicate on Hive partitions, spill, then a warehouse. Schema drift is handled with `union_by_name` plus an explicit `coalesce(qty, quantity_units)` map; a third rename still needs a line in staging.

# HiveQL on Retail Supply-Chain Data

HiveQL analysis of weekly retail demand (Walmart M5, CA/TX/WI) and forecast backtests, taken from my [distribution-center-optimization](../distribution-center-optimization) project.

| File | What it shows |
|---|---|
| [`hive/01_create_tables.hql`](hive/01_create_tables.hql) | external tables over CSV, ORC tables partitioned by region + year (dynamic partitioning), bucketed + sorted table |
| [`hive/02_analysis.hql`](hive/02_analysis.hql) | window functions (LAG, RANK, rolling frames, share-of-total), CTAS, partition pruning, EXPLAIN |
| [`hive/run_hive.sh`](hive/run_hive.sh) | runs both scripts on Apache Hive 4 (HiveServer2 + Beeline) in Docker and saves `hive/output.txt` |

## Run
Start Docker Desktop, then:
```bash
./hive/run_hive.sh
```
The first run pulls `apache/hive:4.0.0` (~1 GB).

## Status
Both scripts run end to end on **Apache Hive 4.0.0** (Docker, HiveServer2 + Beeline, Tez local mode) with no errors. Full log: [`hive/output.txt`](hive/output.txt).
* 3 external tables, 18 `region`/`yr` ORC partitions (3 regions × 2011–2016), one 4-bucket sorted table.
* 7 analytical queries plus an `EXPLAIN`. Results match the original Python/SQLite pipeline, e.g. best model per region: West ARIMA+Fourier 3.91% MAPE, South Prophet 4.14%, Midwest Prophet 8.75%.
* One fix while running: Hive's strict type check rejects `BIGINT > DOUBLE`, so the peak-week flag casts `units` to `DOUBLE`.
* Single-node Docker, small data (~800 weekly rows). It shows the HiveQL, not cluster-scale tuning.

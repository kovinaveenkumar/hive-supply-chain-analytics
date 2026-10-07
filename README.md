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
Scripts are written; **not yet run against Hive**. This section gets updated with `hive/output.txt` once they are.

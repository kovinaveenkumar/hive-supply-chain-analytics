-- HiveQL: external tables over the pipeline's processed CSVs, then managed ORC tables
-- Run with hive/run_hive.sh (HiveServer2 in Docker, Beeline client).

CREATE DATABASE IF NOT EXISTS dc_opt;
USE dc_opt;

-- 1. External tables: Hive reads the CSVs in place (no copy, DROP keeps the files)
DROP TABLE IF EXISTS ext_regional_weekly;
CREATE EXTERNAL TABLE ext_regional_weekly (
  region STRING, week_start STRING, units BIGINT)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE LOCATION '/data/regional_weekly'
TBLPROPERTIES ('skip.header.line.count'='1');

DROP TABLE IF EXISTS ext_store_weekly;
CREATE EXTERNAL TABLE ext_store_weekly (
  store_id STRING, wm_yr_wk INT, week_start STRING, units BIGINT, state STRING, region STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE LOCATION '/data/store_weekly'
TBLPROPERTIES ('skip.header.line.count'='1');

DROP TABLE IF EXISTS ext_backtest;
CREATE EXTERNAL TABLE ext_backtest (
  region STRING, fold INT, model STRING, week_start STRING, actual BIGINT, forecast DOUBLE)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE LOCATION '/data/backtest'
TBLPROPERTIES ('skip.header.line.count'='1');

-- 2. Managed ORC table, partitioned by region + year (dynamic partitioning), DATE typed
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

DROP TABLE IF EXISTS regional_weekly;
CREATE TABLE regional_weekly (week_start DATE, units BIGINT)
PARTITIONED BY (region STRING, yr INT)
STORED AS ORC;

INSERT OVERWRITE TABLE regional_weekly PARTITION (region, yr)
SELECT CAST(week_start AS DATE), units, region, YEAR(CAST(week_start AS DATE))
FROM ext_regional_weekly;

-- 3. Bucketed + sorted ORC store table (efficient joins/sampling by store)
DROP TABLE IF EXISTS store_weekly;
CREATE TABLE store_weekly (week_start DATE, store_id STRING, state STRING, region STRING, units BIGINT)
CLUSTERED BY (store_id) SORTED BY (week_start) INTO 4 BUCKETS
STORED AS ORC;

INSERT OVERWRITE TABLE store_weekly
SELECT CAST(week_start AS DATE), store_id, state, region, units FROM ext_store_weekly;

SHOW PARTITIONS regional_weekly;

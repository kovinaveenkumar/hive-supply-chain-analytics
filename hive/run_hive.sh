#!/usr/bin/env bash
# Runs the HiveQL in this folder on a real Hive (Apache Hive 4 in Docker), then saves output to hive/output.txt.
# Requires Docker running. First run pulls apache/hive:4.0.0 (~1 GB).
set -euo pipefail
cd "$(dirname "$0")/.."
IMG=apache/hive:4.0.0
NAME=dc-hive
STAGE=$(mktemp -d)
mkdir -p "$STAGE/regional_weekly" "$STAGE/store_weekly" "$STAGE/backtest"
cp data/regional_weekly_volume.csv "$STAGE/regional_weekly/"
cp data/store_weekly_volume.csv    "$STAGE/store_weekly/"
cp data/backtest_predictions.csv   "$STAGE/backtest/"
chmod -R a+rX "$STAGE"

docker rm -f $NAME >/dev/null 2>&1 || true
docker run -d --name $NAME -p 10002:10002 -p 10000:10000 \
  -e SERVICE_NAME=hiveserver2 -v "$STAGE":/data -v "$PWD/hive":/hql "$IMG" >/dev/null
echo "waiting for HiveServer2..."
for i in $(seq 1 60); do
  docker exec $NAME beeline -u jdbc:hive2://localhost:10000/ -e 'SHOW DATABASES;' >/dev/null 2>&1 && break
  sleep 5
done
{
  docker exec $NAME beeline -u jdbc:hive2://localhost:10000/ -f /hql/01_create_tables.hql
  docker exec $NAME beeline -u jdbc:hive2://localhost:10000/ -f /hql/02_analysis.hql
} 2>&1 | tee hive/output.txt
docker rm -f $NAME >/dev/null

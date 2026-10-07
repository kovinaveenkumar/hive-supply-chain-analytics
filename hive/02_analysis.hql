-- HiveQL analysis on the tables from 01_create_tables.hql (Hive port of sql/01_explore.sql + backtest accuracy)
USE dc_opt;

-- Q1: yearly volume and YoY growth by region (window function: LAG)
SELECT region, yr, units,
       ROUND(100.0 * (units - LAG(units) OVER (PARTITION BY region ORDER BY yr))
             / LAG(units) OVER (PARTITION BY region ORDER BY yr), 1) AS yoy_pct
FROM (SELECT region, yr, SUM(units) AS units FROM regional_weekly GROUP BY region, yr) y
ORDER BY region, yr;

-- Q2: seasonality index by month (full years 2012-2015); partition pruning on yr
SELECT region, MONTH(week_start) AS month,
       ROUND(AVG(units) / MAX(avg_all), 3) AS seasonal_index
FROM (SELECT region, week_start, units,
             AVG(units) OVER (PARTITION BY region) AS avg_all
      FROM regional_weekly WHERE yr BETWEEN 2012 AND 2015) t
GROUP BY region, MONTH(week_start)
ORDER BY region, month;

-- Q3: store concentration within its region (share via window SUM)
SELECT region, store_id, SUM(units) AS units,
       ROUND(100.0 * SUM(units) / SUM(SUM(units)) OVER (PARTITION BY region), 1) AS pct_of_region
FROM store_weekly GROUP BY region, store_id
ORDER BY region, pct_of_region DESC;

-- Q4: data quality - weeks per region and gaps (should be zero gaps of != 7 days)
SELECT region, COUNT(*) AS weeks, MIN(week_start) AS first_week, MAX(week_start) AS last_week,
       SUM(CASE WHEN gap_days <> 7 THEN 1 ELSE 0 END) AS irregular_gaps
FROM (SELECT region, week_start,
             DATEDIFF(week_start, LAG(week_start) OVER (PARTITION BY region ORDER BY week_start)) AS gap_days
      FROM regional_weekly) g
GROUP BY region;

-- Q5: forecast accuracy from backtest (MAPE, WAPE, bias), CTAS into an ORC results table
DROP TABLE IF EXISTS forecast_accuracy;
CREATE TABLE forecast_accuracy STORED AS ORC AS
SELECT region, model,
       ROUND(100 * AVG(ABS(actual - forecast) / actual), 2) AS mape_pct,
       ROUND(100 * SUM(ABS(actual - forecast)) / SUM(actual), 2) AS wape_pct,
       ROUND(100 * SUM(forecast - actual) / SUM(actual), 2) AS bias_pct
FROM ext_backtest GROUP BY region, model;

SELECT * FROM forecast_accuracy ORDER BY region, mape_pct;

-- Q6: best model per region (RANK), the pick the optimizer consumes
SELECT region, model, mape_pct FROM (
  SELECT region, model, mape_pct, RANK() OVER (PARTITION BY region ORDER BY mape_pct) AS rk
  FROM forecast_accuracy) r
WHERE rk = 1;

-- Q7: rolling 4-week average and peak-week flag (window frame)
SELECT region, week_start, units,
       ROUND(AVG(units) OVER (PARTITION BY region ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)) AS ma4,
       CASE WHEN units > 1.15 * AVG(units) OVER (PARTITION BY region, yr) THEN 'peak' ELSE '' END AS flag
FROM regional_weekly
WHERE yr = 2015
ORDER BY region, week_start
LIMIT 30;

EXPLAIN SELECT region, SUM(units) FROM regional_weekly WHERE region='West' AND yr=2015 GROUP BY region;

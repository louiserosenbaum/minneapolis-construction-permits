-- 02_data_quality.sql
-- Quantify the duplicate-row problem before any analysis.

-- How many permits are duplicated, and how badly?
CREATE OR REPLACE TABLE dq_summary AS
SELECT
    COUNT(*)                                   AS raw_rows,
    COUNT(DISTINCT permitNumber)               AS unique_permits,
    COUNT(*) - COUNT(DISTINCT permitNumber)    AS duplicate_rows
FROM raw_permits;

-- Construction value by year: naive raw sum vs. de-duplicated sum.
CREATE OR REPLACE TABLE dq_value_by_year AS
WITH raw_by_year AS (
    SELECT LEFT(issueDate, 4) AS yr, SUM(TRY_CAST(permit_Value AS DOUBLE)) AS raw_value
    FROM raw_permits GROUP BY 1
),
clean_by_year AS (
    SELECT CAST(YEAR(issued_at) AS VARCHAR) AS yr, SUM(permit_value) AS clean_value
    FROM permits GROUP BY 1
)
SELECT
    r.yr                                        AS year,
    ROUND(r.raw_value / 1e9, 2)                 AS raw_value_bn,
    ROUND(c.clean_value / 1e9, 2)               AS clean_value_bn,
    ROUND(r.raw_value / c.clean_value, 1)       AS overstatement_x
FROM raw_by_year r
JOIN clean_by_year c USING (yr)
ORDER BY year;

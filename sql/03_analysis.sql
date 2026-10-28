-- 03_analysis.sql
-- Business questions for a construction technology audience.
-- Full years only (2017-2025); the export starts Dec 2016 and 2026 is partial.

-- Q1. How has permitted construction value changed, residential vs. commercial?
CREATE OR REPLACE TABLE yearly_by_type AS
SELECT
    YEAR(issued_at)                   AS year,
    permit_type,
    COUNT(*)                          AS permits,
    SUM(permit_value)                 AS total_value,
    SUM(COALESCE(units_new, 0))       AS units_new
FROM permits
WHERE YEAR(issued_at) BETWEEN 2017 AND 2025
GROUP BY 1, 2;

-- Q2. Where is construction activity concentrated? Value by neighborhood and year.
CREATE OR REPLACE TABLE neighborhood_year AS
SELECT
    neighborhood,
    YEAR(issued_at)                   AS year,
    COUNT(*)                          AS permits,
    SUM(permit_value)                 AS total_value,
    SUM(COALESCE(units_new, 0))       AS units_new
FROM permits
WHERE YEAR(issued_at) BETWEEN 2017 AND 2025
  AND neighborhood IS NOT NULL
GROUP BY 1, 2;

-- Q3. Who builds commercial projects, and how concentrated is the market?
-- Contractor share of commercial permit value, with a running cumulative share.
CREATE OR REPLACE TABLE commercial_contractors AS
WITH by_contractor AS (
    SELECT
        contractor,
        COUNT(*)                      AS permits,
        SUM(permit_value)             AS total_value,
        MAX(permit_value)             AS largest_project
    FROM permits
    WHERE permit_type = 'Commercial'
      AND YEAR(issued_at) BETWEEN 2017 AND 2025
      AND permit_value > 0
      AND contractor IS NOT NULL AND contractor <> ''
    GROUP BY 1
)
SELECT
    *,
    total_value / SUM(total_value) OVER ()                                   AS value_share,
    SUM(total_value) OVER (ORDER BY total_value DESC)
        / SUM(total_value) OVER ()                                           AS cumulative_share,
    ROW_NUMBER() OVER (ORDER BY total_value DESC)                            AS value_rank
FROM by_contractor;

-- Q4. How long do projects take from permit issue to completion, by work type?
CREATE OR REPLACE TABLE duration_by_work_type AS
SELECT
    permit_type,
    work_type,
    COUNT(*)                                                         AS completed_permits,
    MEDIAN(DATE_DIFF('day', issued_at, completed_at))                AS median_days,
    QUANTILE_CONT(DATE_DIFF('day', issued_at, completed_at), 0.9)    AS p90_days
FROM permits
WHERE status = 'Closed'
  AND completed_at >= issued_at
  AND YEAR(issued_at) BETWEEN 2017 AND 2025
GROUP BY 1, 2
HAVING COUNT(*) >= 100;

-- Q5. Large commercial projects (>= $10M) for the project map. Commercial only;
-- no residential addresses or owner names are exported.
CREATE OR REPLACE TABLE major_projects AS
SELECT
    permit_number,
    YEAR(issued_at)        AS year,
    work_type,
    neighborhood,
    contractor,
    permit_value,
    units_new,
    lat,
    lon,
    LEFT(comments, 140)    AS description
FROM permits
WHERE permit_type = 'Commercial'
  AND permit_value >= 10000000
  AND YEAR(issued_at) BETWEEN 2017 AND 2025;

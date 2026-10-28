-- 01_load_and_clean.sql
-- Load the raw City of Minneapolis CCS Permits export and build one clean row per permit.
--
-- Data-quality issues handled here:
--   1. Duplicate permits. The export repeats a permit once per parcel (APN) it touches.
--      Large condo projects appear up to 510 times with the same permit value, so summing
--      raw rows overstates construction value by up to 4x in some years.
--   2. Text dates in "YYYY/MM/DD HH:MM:SS+00" format, cast to timestamps.
--   3. Contractor names are free text. The same firm appears under many spellings
--      (Mortenson shows up 17 ways). Names are normalized by removing punctuation and
--      legal suffixes, then a short alias list maps known firms to one name.
--   4. Personal fields (property owner name, applicant street address) are dropped.
--      Analysis is done on permits, contractors, and neighborhoods, not individuals.

CREATE OR REPLACE TABLE raw_permits AS
SELECT *
FROM read_csv_auto('data/raw/CCS_Permits.csv', all_varchar = true);

CREATE OR REPLACE TABLE permits AS
WITH typed AS (
    SELECT
        permitNumber                                              AS permit_number,
        permitType                                                AS permit_type,
        workType                                                  AS work_type,
        NULLIF(TRIM(occupancyType), '')                           AS occupancy_type,
        status,
        Neighborhoods_Desc                                        AS neighborhood,
        TRY_CAST(Wards AS INTEGER)                                AS ward,
        UPPER(TRIM(applicantName))                                AS applicant,
        TRY_CAST(permit_Value AS DOUBLE)                          AS permit_value,
        TRY_CAST(totalFees AS DOUBLE)                             AS total_fees,
        TRY_CAST(dwellingUnitsNew AS INTEGER)                     AS units_new,
        TRY_CAST(dwellingUnitsEliminated AS INTEGER)              AS units_eliminated,
        TRY_STRPTIME(LEFT(issueDate, 19), '%Y/%m/%d %H:%M:%S')    AS issued_at,
        TRY_STRPTIME(LEFT(completeDate, 19), '%Y/%m/%d %H:%M:%S') AS completed_at,
        TRY_CAST(Latitude AS DOUBLE)                              AS lat,
        TRY_CAST(Longitude AS DOUBLE)                             AS lon,
        comments
    FROM raw_permits
)
-- Keep one row per permit. Rows for the same permit share the same value, dates and type,
-- they differ only by parcel, so any one row is representative.
SELECT
    typed.*,
    CASE
        WHEN base_name LIKE '%MORTENSON%'                       THEN 'MORTENSON'
        WHEN base_name LIKE '%MCGOUGH%'                         THEN 'MCGOUGH'
        WHEN REPLACE(base_name, ' ', '') LIKE '%KRAUSANDERSON%' THEN 'KRAUS-ANDERSON'
        WHEN base_name LIKE 'RYAN COMPANIES%'                   THEN 'RYAN COMPANIES'
        WHEN base_name LIKE 'JE DUNN%'                          THEN 'JE DUNN'
        ELSE base_name
    END AS contractor
FROM typed,
LATERAL (
    SELECT TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(REGEXP_REPLACE(applicant, '[^A-Z0-9 ]', ' ', 'g'), '\s+', ' ', 'g'),
        '( (INC|LLC|CO|CORP|CORPORATION|COMPANY|CONST|CONSTRUCTION|CONSTRUCTORS|US|LTD))+$', '', 'g'
    )) AS base_name
) AS n
QUALIFY ROW_NUMBER() OVER (PARTITION BY permit_number ORDER BY issued_at) = 1;

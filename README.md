# Minneapolis Construction Permits, 2017–2025

**Question:** What do nine years of City of Minneapolis building permits say about where the local construction market is heading, and who is building it?

**Data:** [CCS Permits](https://opendata.minneapolismn.gov/), City of Minneapolis Open Data. 409,462 rows covering December 2016 to October 2026. Analysis uses full years 2017–2025.

**Tools:** SQL (DuckDB) for cleaning and analysis, Python to run the pipeline, Tableau Public for the dashboard.

**Dashboard:** *coming soon*

---

## Key findings

1. **The raw data overstates construction value by up to 4x.** The export repeats a permit once for every parcel it touches; one condo permit appears 510 times. Summing raw rows makes 2022 look like an $8.3B year. De-duplicated, it was **$2.05B**. 67,028 of the 409,462 rows are duplicates.

2. **New housing has dropped sharply.** Permitted new dwelling units peaked at 4,837 in 2022 and fell to **522 in 2025**, down 89%. Total permitted value in 2025 ($1.17B) was the lowest of the nine years.

3. **A small group of firms builds most commercial projects.** Of 4,712 contractors, **14 account for half** of commercial permit value. Mortenson leads with 9.6%, followed by Frana, Kraus-Anderson, Gardner Builders, and McGough.

4. **Most big-ticket commercial permits are housing.** Of 225 commercial projects worth $10M or more, 128 are apartment or condo buildings, totaling $4.2B, more than offices ($0.9B) and hospitals ($0.7B) combined several times over.

5. **Activity is concentrated downtown.** Downtown West, North Loop, and Midtown Phillips hold a third of all permitted value across 87 neighborhoods.

## So what

For a construction technology company selling into the Twin Cities, the commercial market is a short list of large general contractors, not thousands of small ones. With new multifamily starts down sharply, work on existing homes is the growing segment: residential remodel and repair permits more than doubled, from an average of $108M a year in 2017–2019 to $237M in 2023–2025, while new-home value stayed flat.

## Data quality work

| Issue | Fix |
|---|---|
| Permits duplicated once per parcel (up to 510x) | One row per permit number |
| Contractor names in free text (Mortenson appears 17 ways) | Removed punctuation and legal suffixes, then mapped known firms to one name |
| Dates stored as text | Cast to timestamps |
| No building-use field (hospital, apartments, office) | Classified large projects from the permit description with ordered keyword rules; unclear ones stay "Other / unspecified" |
| Two permits with placeholder (0, 0) coordinates | Excluded from the project map |
| Property owner names and applicant addresses | Dropped; analysis covers permits, contractors, and neighborhoods, not individuals |

See [`sql/02_data_quality.sql`](sql/02_data_quality.sql) for the before-and-after comparison.

## Project structure

```
sql/
  01_load_and_clean.sql   Load raw export, de-duplicate, standardize names
  02_data_quality.sql     Measure the duplicate problem
  03_analysis.sql         Business questions, output tables for Tableau
build.py                  Runs the SQL in order and writes output/*.csv
output/                   Aggregated, Tableau-ready CSVs
```

## How to run

1. Download the CCS Permits CSV from [opendata.minneapolismn.gov](https://opendata.minneapolismn.gov/) and save it as `data/raw/CCS_Permits.csv`.
2. `pip install duckdb`
3. `python build.py`

## Limitations

- Permit value is the applicant's estimate at application, not final project cost.
- The export has no application date, so this measures issue-to-completion time, not approval speed.
- Name standardization covers the largest firms; smaller firms may still appear under more than one spelling.

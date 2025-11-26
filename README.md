# Community Health Worker Performance Analytics

A comprehensive dbt data pipeline for aggregating and analyzing Community Health Worker (CHW) activities to support dashboard performance metrics and operational reporting.

## Project Overview

This dbt project processes raw CHW activity data from the RAW database and transforms it into monthly aggregated metrics in CAP_DB using Snowflake. The solution includes custom data quality tests, incremental processing, and comprehensive documentation.

## Project Architecture

### Data Flow
```
RAW.CHW_DATA.FCT_CHV_ACTIVITY 
    → CAP_DB.CAP_SCHEMA.STG_CHW_ACTIVITY (view)
    → CAP_DB.CAP_SCHEMA.CHW_ACTIVITY_MONTHLY (incremental table)
```

### Key Components
- **Staging Layer**: Data cleaning and standardization (views)
- **Metrics Layer**: Business metrics and aggregations (tables)
- **Data Quality**: Custom tests for freshness, boundaries, and validity
- **Documentation**: Comprehensive data lineage and business logic

## Complete Setup Guide

### Prerequisites

1. **Snowflake Account** with access to:
   - RAW database (source data)
   - CAP_DB (target database)
   - CAP_WH warehouse

2. **Local Development Environment**:
   - Python 3.8+
   - dbt Core installed
   - Git for version control

### Step 1: Project Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/chw-performance-analytics.git
cd chw-performance-analytics

# Create virtual environment
python -m venv venv
source venv/bin/activate  

# Install dependencies
pip install dbt-snowflake
```

### Step 2: Environment Configuration

1. **Copy environment template**:
   ```bash
   cp .env.template .env
   ```

2. **Set up the .env file**:
   ```
   SNOWFLAKE_ACCOUNT=your_account
   SNOWFLAKE_USER=your_username
   SNOWFLAKE_PASSWORD=your_password
   SNOWFLAKE_ROLE=your_role
   SNOWFLAKE_WAREHOUSE=CAP_WH
   SNOWFLAKE_DATABASE=CAP_DB
   SNOWFLAKE_SCHEMA=ANALYTICS
   ```

3. **Configure dbt profile** (`~/.dbt/profiles.yml`):
   ```yaml
   chw_analytics:
     target: dev
     outputs:
       dev:
         type: snowflake
         account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
         user: "{{ env_var('SNOWFLAKE_USER') }}"
         password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
         role: "{{ env_var('SNOWFLAKE_ROLE') }}"
         warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
         database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
         schema: "{{ env_var('SNOWFLAKE_SCHEMA') }}"
         threads: 4
         client_session_keep_alive: False
   ```

### Step 3: Database Setup

1. **Verify source data access**:
   ```sql
   SELECT COUNT(*) FROM RAW.CHW_DATA.FCT_CHV_ACTIVITY;
   ```

2. **Ensure target database permissions**:
   ```sql
   -- Verify you have CREATE TABLE privileges in CAP_DB
   USE ROLE YOUR_ROLE;
   USE WAREHOUSE CAP_WH;
   USE DATABASE CAP_DB;
   USE SCHEMA ANALYTICS;
   ```

### Step 4: Initial Deployment

```bash
# Test connection
dbt debug

# Run all models
dbt run

# Execute all tests
dbt test

# Generate documentation
dbt docs generate

# Serve documentation locally
dbt docs serve
```

## Core Business Logic

### Month Assignment Rule
Activities are assigned to months based on the following logic:
```sql
CASE 
  WHEN DAY(activity_date) >= 26 THEN
    DATE_TRUNC('MONTH', DATEADD(MONTH, 1, activity_date))
  ELSE
    DATE_TRUNC('MONTH', activity_date)
END AS report_month
```
**Example**: An activity on January 26th is counted in February's metrics.

### Data Quality Filters
- Exclude records with NULL activity dates
- Filter out deleted records (`deleted = FALSE`)
- Remove activities with invalid CHW IDs
- Exclude test/data quality records

## Model Implementation

### Staging Model (`models/staging/stg_chw_activity.sql`)
```sql
{{
  config(
    materialized='view',
    schema='CAP_SCHEMA'
  )
}}

SELECT
  chv_id,
  activity_date,
  household_id,
  patient_id,
  activity_type,
  -- ... other fields
FROM {{ source('raw', 'fct_chv_activity') }}
WHERE activity_date IS NOT NULL
  AND deleted = FALSE
  AND chv_id IS NOT NULL
```

### Main Metrics Table (`models/metrics/chw_activity_monthly.sql`)
```sql
{{
  config(
    materialized='incremental',
    unique_key='(chv_id, report_month)',
    strategy='delete+insert'
  )
}}

WITH monthly_aggregation AS (
  SELECT
    chv_id,
    report_month,
    COUNT(*) AS total_activities,
    COUNT(DISTINCT household_id) AS unique_households,
    COUNT(DISTINCT patient_id) AS unique_patients
  FROM {{ ref('stg_chw_activity') }}
  GROUP BY chv_id, report_month
)
SELECT * FROM monthly_aggregation
```

## Testing Strategy

### 1. Built-in dbt Tests

**Schema tests** (`models/schema.yml`):
```yaml
version: 2

models:
  - name: chw_activity_monthly
    columns:
      - name: chv_id
        tests:
          - not_null
          - unique
      - name: report_month
        tests:
          - not_null
      - name: total_activities
        tests:
          - not_null
          - relationships:
              to: ref('stg_chw_activity')
              field: chv_id
```

### 2. Custom Data Quality Tests

**Data Freshness** (`tests/data_freshness.sql`):
```sql
-- Check if source data is current
{% set CURRENT_DATE='2025-02-10' %}

SELECT 
    MAX(REPORT_MONTH) as latest_month,
    DATEDIFF('month', MAX(REPORT_MONTH), CURRENT_DATE) as months_behind
FROM {{ ref('chw_activity_monthly') }}
HAVING months_behind < 3
```

**Date Boundaries** (`tests/date_boundaries.sql`):
```sql
-- Validate activity dates are within expected range
SELECT *
FROM {{ ref('stg_chw_activity') }}
WHERE ACTIVITY_DATE < '2024-12-01'  
   OR ACTIVITY_DATE > CURRENT_DATE  
   OR ACTIVITY_DATE IS NULL
```

**Negative Values** (`tests/negative_values.sql`):
```sql
-- Ensure no negative values in numeric fields
SELECT *
FROM {{ ref('chw_activity_monthly') }}
WHERE TOTAL_ACTIVITIES < 0
   OR UNIQUE_HOUSEHOLDS_VISITED < 0
   OR UNIQUE_PATIENTS_SERVED < 0
   OR PREGNANCY_VISITS < 0
   OR CHILD_ASSESSMENTS < 0
   OR FAMILY_PLANNING_VISITS < 0
```

### 3. Running Tests

```bash
# Run all tests
dbt test

# Run specific test categories
dbt test --select test_type:singular
dbt test --select test_type:generic

# Run tests on specific model
dbt test --select chw_activity_monthly

# Run source data tests
dbt test --select source:raw
```

## Key Metrics

### Activity Metrics
- **Total Activities**: Count of all CHW activities
- **Unique Households Visited**: Distinct households served
- **Unique Patients Served**: Distinct patients assisted
- **Activities per CHW**: Average activities per health worker

### Performance Indicators
- **Monthly Activity Trends**: Growth/decline patterns
- **CHW Productivity**: Activities per worker
- **Household Coverage**: Percentage of target households reached
- **Patient Engagement**: Frequency of patient interactions

## Incremental Processing

The pipeline uses incremental materialization to efficiently handle:

- **New Data**: Daily activity records
- **Late Arrivals**: Historical data corrections
- **Data Updates**: Modified activity records
- **New CHWs**: Recently onboarded health workers

### Processing Strategy
```bash
# Full refresh (when needed)
dbt run --full-refresh

# Incremental run (daily operation)
dbt run --select chw_activity_monthly+

# Specific model only
dbt run --models chw_activity_monthly
```

## Documentation

### Generating Documentation
```bash
# Generate static documentation
dbt docs generate

# Serve documentation locally
dbt docs serve
# Access at http://localhost:8080
```

### Documentation Includes
- Data lineage and dependencies
- Model descriptions and SQL code
- Test definitions and results
- Source data definitions
- Business metrics calculations

## Operational Procedures

### Daily Operation
```bash
# Standard daily run
dbt run
dbt test
dbt docs generate
```

### Monitoring and Alerting
- **Data Freshness**: Monitor source data timeliness
- **Test Failures**: Alert on data quality issues
- **Processing Errors**: Monitor dbt run successes
- **Performance**: Track query execution times

### Troubleshooting Common Issues

**Connection Problems**:
```bash
# Test Snowflake connection
dbt debug

# Verify environment variables
echo $SNOWFLAKE_ACCOUNT
```

**Test Failures**:
```bash
# Investigate specific test failure
dbt test --select test_name:data_freshness
```

**Model Errors**:
```bash
# Run specific model with full logs
dbt run --models stg_chw_activity --debug
```

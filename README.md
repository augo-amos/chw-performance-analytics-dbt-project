# Community Health Worker Performance Analytics

Monthly aggregation of Community Health Worker (CHW) activities for dashboard performance metrics.

## Project Overview

This dbt project processes CHW activity data from the RAW database and materializes models in CAP_DB using the CAP_WH warehouse.

## Key Features

- **Month Assignment Rule**: Activities on/after the 26th are assigned to NEXT month
- **Data Quality Checks**: Filters out NULL dates, deleted records, and invalid CHW IDs
- **Incremental Processing**: Efficiently handles new data with delete+insert strategy
- **Cross-Database Processing**: Sources from RAW, materializes in CAP_DB
- **Custom Data Tests**: Comprehensive data quality validation including freshness, date boundaries, and negative values

## Project Structure

```
models/
├── staging/           # Data cleaning and standardization (views in CAP_DB)
├── metrics/           # Business metrics and aggregations (tables in CAP_DB)
macros/               # Reusable SQL logic
tests/                # Data quality tests
```

## Database Architecture

- **Source**: `RAW.CHW_DATA.FCT_CHV_ACTIVITY`
- **Staging**: `CAP_DB.ANALYTICS.STG_CHW_ACTIVITY` (view)
- **Metrics**: `CAP_DB.ANALYTICS.CHW_ACTIVITY_MONTHLY` (incremental table)
- **Warehouse**: `CAP_WH`

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.template .env
   # Edit .env with your Snowflake credentials
   ```

2. **Setup Snowflake**:
   ```bash
   ./setup_environment.sh
   ```

3. **Run dbt**:
   ```bash
   dbt run
   dbt test
   dbt docs generate
   dbt docs serve
   ```

## Core Models

### `stg_chw_activity`
- Cleans and standardizes source data from RAW database
- Materialized as view in CAP_DB

### `chw_activity_monthly` 
- Main metrics table in CAP_DB
- Applies month assignment logic
- Incremental table with delete+insert strategy
- Primary key: `(chv_id, report_month)`

## Key Business Logic

### Month Assignment
```sql
-- Activities on/after 26th → next month
CASE WHEN DAY(activity_date) >= 26 THEN
    DATE_TRUNC('MONTH', DATEADD(MONTH, 1, activity_date))
ELSE
    DATE_TRUNC('MONTH', activity_date)
END
```

## Metrics Calculated

- **Total Activities**: Count of all activities
- **Unique Households Visited**: Distinct households
- **Unique Patients Served**: Distinct patients
- **Activity Type Breakdown**: Pregnancy visits, child assessments, family planning, etc.

## Testing

### Data Quality Tests

This project includes comprehensive custom data tests to ensure data reliability:

```bash
# Run all tests
dbt test

# Run specific model tests  
dbt test --select chw_activity_monthly

# Run source data tests
dbt test --select source:raw

# Run custom data tests
dbt test --select test_type:singular
```

### Custom Test Coverage

- **`data_freshness.sql`**: Validates that source data is current and up-to-date
- **`date_boundaries.sql`**: Ensures activity dates fall within expected operational ranges
- **`negative_values.sql`**: Checks for invalid negative values in numeric fields

## Incremental Processing

The main model uses incremental materialization with `delete+insert` strategy to handle:
- Late-arriving data (previous months)
- New CHWs
- Data corrections

## Complete Setup Commands:

```bash
# 1. Create project structure
mkdir -p capstone/{models/{staging,metrics},macros,tests,data}
cd capstone

# 2. Create all files (copy the content above into respective files)

# 3. Make setup script executable
chmod +x setup_environment.sh

# 4. Setup environment
cp .env.template .env
# Edit .env with your actual Snowflake credentials

# 5. Run complete setup
./setup_environment.sh
```
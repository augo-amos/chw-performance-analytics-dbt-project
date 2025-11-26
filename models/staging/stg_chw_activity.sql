{{
    config(
        materialized='view',
        tags=['staging', 'chw'],
        database="{{ env_var('SNOWFLAKE_DATABASE') }}"
    )
}}

WITH source_data AS (
    SELECT
        ACTIVITY_ID,
        CHV_ID,
        ACTIVITY_DATE,
        ACTIVITY_TIMESTAMP,
        ACTIVITY_TYPE,
        HOUSEHOLD_ID,
        PATIENT_ID,
        LOCATION_ID,
        IS_DELETED,
        CREATED_AT,
        UPDATED_AT
    FROM {{ source('raw', 'fct_chv_activity') }}
),

cleaned_data AS (
    SELECT
        ACTIVITY_ID,
        CHV_ID,
        ACTIVITY_DATE,
        ACTIVITY_TIMESTAMP,
        ACTIVITY_TYPE,
        HOUSEHOLD_ID,
        PATIENT_ID,
        LOCATION_ID,
        IS_DELETED,
        CREATED_AT,
        UPDATED_AT,
        -- Data quality flags
        CASE WHEN CHV_ID IS NULL THEN 1 ELSE 0 END AS IS_MISSING_CHV_ID,
        CASE WHEN ACTIVITY_DATE IS NULL THEN 1 ELSE 0 END AS IS_MISSING_ACTIVITY_DATE
    FROM source_data
)

SELECT 
    ACTIVITY_ID,
    CHV_ID,
    ACTIVITY_DATE,
    ACTIVITY_TIMESTAMP,
    ACTIVITY_TYPE,
    HOUSEHOLD_ID,
    PATIENT_ID,
    LOCATION_ID,
    IS_DELETED,
    CREATED_AT,
    UPDATED_AT,
    IS_MISSING_CHV_ID,
    IS_MISSING_ACTIVITY_DATE
FROM cleaned_data
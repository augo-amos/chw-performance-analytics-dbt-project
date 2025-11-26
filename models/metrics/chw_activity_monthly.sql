{{
    config(
        materialized='incremental',
        unique_key=['chv_id', 'report_month'],
        incremental_strategy='delete+insert',
        database="{{ env_var('SNOWFLAKE_DATABASE') }}",
        snowflake_warehouse="{{ env_var('SNOWFLAKE_WAREHOUSE') }}",
        tags=['metrics', 'incremental', 'chw']
    )
}}

WITH filtered_activities AS (
    SELECT
        ACTIVITY_ID,
        CHV_ID,
        ACTIVITY_DATE,
        ACTIVITY_TYPE,
        HOUSEHOLD_ID,
        PATIENT_ID
    FROM {{ ref('stg_chw_activity') }}
    WHERE 1=1
        -- Filtering out invalid records as per business requirements
        AND CHV_ID IS NOT NULL
        AND ACTIVITY_DATE IS NOT NULL
        AND IS_DELETED = FALSE
        -- Additional data quality filters
        AND IS_MISSING_CHV_ID = 0
        AND IS_MISSING_ACTIVITY_DATE = 0
),

with_report_month AS (
    SELECT
        *,
        -- Applying month assignment business rule using our macro
        {{ month_assignment('ACTIVITY_DATE') }} AS REPORT_MONTH
    FROM filtered_activities
),

aggregated_metrics AS (
    SELECT
        CHV_ID,
        REPORT_MONTH,
        -- Core metrics
        COUNT(ACTIVITY_ID) AS TOTAL_ACTIVITIES,
        COUNT(DISTINCT HOUSEHOLD_ID) AS UNIQUE_HOUSEHOLDS_VISITED,
        COUNT(DISTINCT PATIENT_ID) AS UNIQUE_PATIENTS_SERVED,
        
        -- Activity type breakdown
        SUM(CASE WHEN ACTIVITY_TYPE = 'pregnancy_visit' THEN 1 ELSE 0 END) AS PREGNANCY_VISITS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'child_assessment' THEN 1 ELSE 0 END) AS CHILD_ASSESSMENTS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'family_planning' THEN 1 ELSE 0 END) AS FAMILY_PLANNING_VISITS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'household_registration' THEN 1 ELSE 0 END) AS HOUSEHOLD_REGISTRATIONS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'postnatal_visit' THEN 1 ELSE 0 END) AS POSTNATAL_VISITS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'nutrition_assessment' THEN 1 ELSE 0 END) AS NUTRITION_ASSESSMENTS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'referral_followup' THEN 1 ELSE 0 END) AS REFERRAL_FOLLOWUPS,
        SUM(CASE WHEN ACTIVITY_TYPE = 'other' THEN 1 ELSE 0 END) AS OTHER_ACTIVITIES,
        
        -- Data quality metrics
        COUNT(*) AS TOTAL_RECORDS_PROCESSED,
        CURRENT_TIMESTAMP() AS _LOADED_AT

    FROM with_report_month
    GROUP BY CHV_ID, REPORT_MONTH
)

SELECT 
    CHV_ID,
    REPORT_MONTH,
    TOTAL_ACTIVITIES,
    UNIQUE_HOUSEHOLDS_VISITED,
    UNIQUE_PATIENTS_SERVED,
    PREGNANCY_VISITS,
    CHILD_ASSESSMENTS,
    FAMILY_PLANNING_VISITS,
    HOUSEHOLD_REGISTRATIONS,
    POSTNATAL_VISITS,
    NUTRITION_ASSESSMENTS,
    REFERRAL_FOLLOWUPS,
    OTHER_ACTIVITIES,
    TOTAL_RECORDS_PROCESSED,
    _LOADED_AT
FROM aggregated_metrics
{% if is_incremental() %}
-- Incremental logic: Process current month + previous month (for late data) and new CHWs
WHERE REPORT_MONTH >= (
    SELECT DATEADD(MONTH, -1, MAX(REPORT_MONTH)) 
    FROM {{ this }}
)
OR CHV_ID NOT IN (SELECT DISTINCT CHV_ID FROM {{ this }})
{% endif %}
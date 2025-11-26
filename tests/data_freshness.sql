{% set CURRENT_DATE='2025-02-10' %}

SELECT 
    MAX(REPORT_MONTH) as latest_month,
    DATEDIFF('month', MAX(REPORT_MONTH), CURRENT_DATE) as months_behind
FROM {{ ref('chw_activity_monthly') }}
HAVING months_behind < 3
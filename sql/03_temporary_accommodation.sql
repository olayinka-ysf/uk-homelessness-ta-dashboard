-- Temporary accommodation: England trend, rates, running total, seasonal patterns
USE HomelessnessDB;
GO

-- England-level TA trend by quarter
SELECT
    year,
    quarter,
    SUM(total_households_in_ta)   AS total_ta,
    SUM(households_with_children) AS ta_with_children,
    SUM(children_in_ta)           AS children_in_ta
FROM dbo.temporary_accommodation
WHERE local_authority_code LIKE 'E%'
GROUP BY year, quarter
ORDER BY year, quarter;
GO

-- TA rate per 1,000 households by quarter
WITH ta_quarterly AS (
    SELECT
        t.year,
        t.quarter,
        SUM(t.total_households_in_ta) AS total_ta,
        SUM(pop.households)           AS total_households
    FROM dbo.temporary_accommodation t
    JOIN dbo.population_estimates pop
        ON t.local_authority_code = pop.local_authority_code
    WHERE t.local_authority_code LIKE 'E0[6-9]%' OR t.local_authority_code LIKE 'E10%'
    GROUP BY t.year, t.quarter
)
SELECT
    year,
    quarter,
    total_ta,
    total_households,
    ROUND(CAST(total_ta AS FLOAT) / NULLIF(total_households, 0) * 1000, 3) AS ta_rate_per_1000
FROM ta_quarterly
ORDER BY year, quarter;
GO

-- Running total of TA households across all quarters
WITH ta_quarterly AS (
    SELECT
        year,
        quarter,
        SUM(total_households_in_ta) AS total_ta
    FROM dbo.temporary_accommodation
    WHERE local_authority_code LIKE 'E%'
    GROUP BY year, quarter
)
SELECT
    year,
    quarter,
    total_ta,
    SUM(total_ta) OVER (
        ORDER BY year, quarter
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM ta_quarterly
ORDER BY year, quarter;
GO

-- Seasonal pattern: average TA volume by quarter number across all years
WITH ta_quarterly AS (
    SELECT
        year,
        quarter,
        SUM(total_households_in_ta) AS total_ta
    FROM dbo.temporary_accommodation
    WHERE local_authority_code LIKE 'E%'
    GROUP BY year, quarter
)
SELECT
    quarter,
    COUNT(*)                        AS years_observed,
    ROUND(AVG(CAST(total_ta AS FLOAT)), 0) AS avg_ta_households,
    MIN(total_ta)                   AS min_ta,
    MAX(total_ta)                   AS max_ta
FROM ta_quarterly
GROUP BY quarter
ORDER BY quarter;

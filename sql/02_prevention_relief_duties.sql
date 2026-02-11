-- Prevention and relief duties: trends, YoY change, outcomes, LA rates
USE HomelessnessDB;
GO

-- England-level quarterly totals and trend
SELECT
    year,
    quarter,
    SUM(prevention_duties) AS prevention_duties,
    SUM(relief_duties)     AS relief_duties,
    SUM(total_duties)      AS total_duties
FROM dbo.prevention_relief_duties
WHERE local_authority_code LIKE 'E%'
GROUP BY year, quarter
ORDER BY year, quarter;
GO

-- Year-on-year change using LAG (4 quarters back = same quarter prior year)
WITH quarterly AS (
    SELECT
        year,
        quarter,
        SUM(prevention_duties) AS prevention_duties,
        SUM(relief_duties)     AS relief_duties
    FROM dbo.prevention_relief_duties
    WHERE local_authority_code LIKE 'E%'
    GROUP BY year, quarter
)
SELECT
    year,
    quarter,
    prevention_duties,
    relief_duties,
    LAG(prevention_duties, 4) OVER (ORDER BY year, quarter) AS prev_year_prevention,
    LAG(relief_duties, 4)     OVER (ORDER BY year, quarter) AS prev_year_relief,
    prevention_duties - LAG(prevention_duties, 4) OVER (ORDER BY year, quarter) AS yoy_prevention_change,
    relief_duties     - LAG(relief_duties, 4)     OVER (ORDER BY year, quarter) AS yoy_relief_change
FROM quarterly
ORDER BY year, quarter;
GO

-- Proportion of duties ending in main duty acceptance (positive outcome proxy)
SELECT
    year,
    quarter,
    SUM(prevention_duties)  AS prevention_duties,
    SUM(relief_duties)      AS relief_duties,
    SUM(main_duty_accepted) AS main_duty_accepted,
    CAST(SUM(main_duty_accepted) AS FLOAT)
        / NULLIF(SUM(relief_duties), 0) AS main_duty_per_relief
FROM dbo.prevention_relief_duties
WHERE local_authority_code LIKE 'E0[6-9]%' OR local_authority_code LIKE 'E10%'
GROUP BY year, quarter
ORDER BY year, quarter;
GO

-- Top 10 local authorities by total duties per 1,000 households
WITH duty_rates AS (
    SELECT
        p.local_authority_code,
        p.local_authority_name,
        SUM(ISNULL(p.prevention_duties, 0) + ISNULL(p.relief_duties, 0)) AS total_duties,
        MAX(pop.households)                                                AS households,
        CAST(SUM(ISNULL(p.prevention_duties, 0) + ISNULL(p.relief_duties, 0)) AS FLOAT)
            / NULLIF(MAX(pop.households), 0) * 1000                        AS duties_per_1000
    FROM dbo.prevention_relief_duties p
    JOIN dbo.population_estimates pop
        ON p.local_authority_code = pop.local_authority_code
    WHERE p.local_authority_code LIKE 'E0[6-9]%' OR p.local_authority_code LIKE 'E10%'
    GROUP BY p.local_authority_code, p.local_authority_name
)
SELECT TOP 10
    local_authority_code,
    local_authority_name,
    total_duties,
    households,
    ROUND(duties_per_1000, 2) AS duties_per_1000
FROM duty_rates
ORDER BY duties_per_1000 DESC;

-- Deprivation overlay: TA rates by IMD decile, prevention duties by decile, high-pressure LA flag
USE HomelessnessDB;
GO

-- Average TA rate per 1,000 households by IMD decile
WITH la_rates AS (
    SELECT
        t.local_authority_code,
        CAST(SUM(t.total_households_in_ta) AS FLOAT)
            / NULLIF(MAX(pop.households), 0) * 1000 AS ta_rate_per_1000
    FROM dbo.temporary_accommodation t
    JOIN dbo.population_estimates pop
        ON t.local_authority_code = pop.local_authority_code
    WHERE t.local_authority_code LIKE 'E0[6-9]%' OR t.local_authority_code LIKE 'E10%'
    GROUP BY t.local_authority_code
)
SELECT
    d.imd_decile,
    COUNT(*)                                 AS la_count,
    ROUND(AVG(lr.ta_rate_per_1000), 3)       AS avg_ta_rate_per_1000,
    ROUND(MIN(lr.ta_rate_per_1000), 3)       AS min_ta_rate,
    ROUND(MAX(lr.ta_rate_per_1000), 3)       AS max_ta_rate
FROM dbo.deprivation_scores d
JOIN la_rates lr ON d.local_authority_code = lr.local_authority_code
GROUP BY d.imd_decile
ORDER BY d.imd_decile;
GO

-- Prevention duty volumes by deprivation decile
WITH la_duties AS (
    SELECT
        p.local_authority_code,
        SUM(ISNULL(p.prevention_duties, 0)) AS total_prevention,
        SUM(ISNULL(p.relief_duties, 0))     AS total_relief
    FROM dbo.prevention_relief_duties p
    WHERE p.local_authority_code LIKE 'E0[6-9]%' OR p.local_authority_code LIKE 'E10%'
    GROUP BY p.local_authority_code
)
SELECT
    d.imd_decile,
    COUNT(*)                               AS la_count,
    SUM(ld.total_prevention)               AS total_prevention_duties,
    SUM(ld.total_relief)                   AS total_relief_duties,
    ROUND(AVG(CAST(ld.total_prevention AS FLOAT)), 0) AS avg_prevention_per_la
FROM dbo.deprivation_scores d
JOIN la_duties ld ON d.local_authority_code = ld.local_authority_code
GROUP BY d.imd_decile
ORDER BY d.imd_decile;
GO

-- CTE: flag LAs in decile 1 (most deprived) with above-average TA rates
WITH england_avg AS (
    SELECT
        CAST(SUM(t.total_households_in_ta) AS FLOAT)
            / NULLIF(SUM(pop.households), 0) * 1000 AS england_avg_rate
    FROM dbo.temporary_accommodation t
    JOIN dbo.population_estimates pop
        ON t.local_authority_code = pop.local_authority_code
    WHERE t.local_authority_code LIKE 'E0[6-9]%' OR t.local_authority_code LIKE 'E10%'
),
la_rates AS (
    SELECT
        t.local_authority_code,
        t.local_authority_name,
        CAST(SUM(t.total_households_in_ta) AS FLOAT)
            / NULLIF(MAX(pop.households), 0) * 1000 AS ta_rate_per_1000
    FROM dbo.temporary_accommodation t
    JOIN dbo.population_estimates pop
        ON t.local_authority_code = pop.local_authority_code
    WHERE t.local_authority_code LIKE 'E0[6-9]%' OR t.local_authority_code LIKE 'E10%'
    GROUP BY t.local_authority_code, t.local_authority_name
)
SELECT
    lr.local_authority_code,
    lr.local_authority_name,
    ROUND(lr.ta_rate_per_1000, 3)  AS ta_rate_per_1000,
    d.imd_decile,
    ROUND(ea.england_avg_rate, 3)  AS england_avg_rate,
    CASE
        WHEN lr.ta_rate_per_1000 > ea.england_avg_rate
        THEN 'High deprivation, above average TA rate'
        ELSE 'High deprivation, at or below average TA rate'
    END AS flag
FROM la_rates lr
JOIN dbo.deprivation_scores d  ON lr.local_authority_code = d.local_authority_code
CROSS JOIN england_avg ea
WHERE d.imd_decile = 1
ORDER BY lr.ta_rate_per_1000 DESC;

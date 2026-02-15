-- TA type breakdown: B&B proportions, children in B&B, out of area rates, LA ranking
USE HomelessnessDB;
GO

-- England quarterly TA type proportions
SELECT
    year,
    quarter,
    SUM(bb_accommodation)       AS bb,
    SUM(nightly_paid)           AS nightly_paid,
    SUM(self_contained)         AS self_contained,
    SUM(total_households_in_ta) AS total_ta,
    ROUND(CAST(SUM(bb_accommodation)  AS FLOAT) / NULLIF(SUM(total_households_in_ta), 0), 4) AS bb_proportion,
    ROUND(CAST(SUM(nightly_paid)      AS FLOAT) / NULLIF(SUM(total_households_in_ta), 0), 4) AS nightly_proportion,
    ROUND(CAST(SUM(self_contained)    AS FLOAT) / NULLIF(SUM(total_households_in_ta), 0), 4) AS self_contained_proportion
FROM dbo.temporary_accommodation
WHERE local_authority_code LIKE 'E%'
GROUP BY year, quarter
ORDER BY year, quarter;
GO

-- Proportion of B&B placements involving households with children
SELECT
    year,
    quarter,
    SUM(bb_accommodation)       AS total_bb,
    SUM(households_with_children) AS hh_with_children,
    ROUND(
        CAST(SUM(CASE WHEN households_with_children > 0 THEN bb_accommodation ELSE 0 END) AS FLOAT)
            / NULLIF(SUM(bb_accommodation), 0),
        4
    ) AS bb_with_children_proportion
FROM dbo.temporary_accommodation
WHERE local_authority_code LIKE 'E%'
GROUP BY year, quarter
ORDER BY year, quarter;
GO

-- Local authorities with highest out of area placement rates
SELECT
    local_authority_code,
    local_authority_name,
    SUM(out_of_area_placements)  AS out_of_area,
    SUM(total_households_in_ta)  AS total_ta,
    ROUND(
        CAST(SUM(out_of_area_placements) AS FLOAT)
            / NULLIF(SUM(total_households_in_ta), 0),
        4
    ) AS out_of_area_rate
FROM dbo.temporary_accommodation
WHERE local_authority_code LIKE 'E0[6-9]%' OR local_authority_code LIKE 'E10%'
GROUP BY local_authority_code, local_authority_name
HAVING SUM(total_households_in_ta) > 0
ORDER BY out_of_area_rate DESC;
GO

-- RANK of local authorities by B&B usage as proportion of total TA
WITH bb_proportions AS (
    SELECT
        local_authority_code,
        local_authority_name,
        SUM(bb_accommodation)       AS bb_households,
        SUM(total_households_in_ta) AS total_ta,
        CAST(SUM(bb_accommodation) AS FLOAT)
            / NULLIF(SUM(total_households_in_ta), 0) AS bb_proportion
    FROM dbo.temporary_accommodation
    WHERE local_authority_code LIKE 'E0[6-9]%' OR local_authority_code LIKE 'E10%'
    GROUP BY local_authority_code, local_authority_name
    HAVING SUM(total_households_in_ta) > 0
)
SELECT
    local_authority_code,
    local_authority_name,
    bb_households,
    total_ta,
    ROUND(bb_proportion, 4)                                   AS bb_proportion,
    RANK() OVER (ORDER BY bb_proportion DESC)                 AS bb_rank
FROM bb_proportions
ORDER BY bb_rank;

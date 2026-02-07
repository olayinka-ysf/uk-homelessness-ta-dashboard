-- Create HomelessnessDB and staging tables
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'HomelessnessDB')
    CREATE DATABASE HomelessnessDB;
GO

USE HomelessnessDB;
GO

IF OBJECT_ID('dbo.prevention_relief_duties', 'U') IS NOT NULL
    DROP TABLE dbo.prevention_relief_duties;

CREATE TABLE dbo.prevention_relief_duties (
    local_authority_code  NVARCHAR(9)   NOT NULL,
    local_authority_name  NVARCHAR(100) NOT NULL,
    quarter               TINYINT       NOT NULL,
    year                  SMALLINT      NOT NULL,
    prevention_duties     INT           NULL,
    relief_duties         INT           NULL,
    main_duty_accepted    INT           NULL,
    total_duties          AS (ISNULL(prevention_duties, 0) + ISNULL(relief_duties, 0)),
    CONSTRAINT PK_prevention_relief_duties PRIMARY KEY (local_authority_code, quarter, year)
);

IF OBJECT_ID('dbo.temporary_accommodation', 'U') IS NOT NULL
    DROP TABLE dbo.temporary_accommodation;

CREATE TABLE dbo.temporary_accommodation (
    local_authority_code       NVARCHAR(9)   NOT NULL,
    local_authority_name       NVARCHAR(100) NOT NULL,
    quarter                    TINYINT       NOT NULL,
    year                       SMALLINT      NOT NULL,
    total_households_in_ta     INT           NULL,
    households_with_children   INT           NULL,
    children_in_ta             INT           NULL,
    bb_accommodation           INT           NULL,
    nightly_paid               INT           NULL,
    self_contained             INT           NULL,
    out_of_area_placements     INT           NULL,
    CONSTRAINT PK_temporary_accommodation PRIMARY KEY (local_authority_code, quarter, year)
);

IF OBJECT_ID('dbo.population_estimates', 'U') IS NOT NULL
    DROP TABLE dbo.population_estimates;

CREATE TABLE dbo.population_estimates (
    local_authority_code  NVARCHAR(9)   NOT NULL,
    local_authority_name  NVARCHAR(100) NOT NULL,
    year                  SMALLINT      NOT NULL,
    population            INT           NULL,
    households            INT           NULL,
    CONSTRAINT PK_population_estimates PRIMARY KEY (local_authority_code, year)
);

IF OBJECT_ID('dbo.deprivation_scores', 'U') IS NOT NULL
    DROP TABLE dbo.deprivation_scores;

CREATE TABLE dbo.deprivation_scores (
    local_authority_code  NVARCHAR(9)   NOT NULL,
    local_authority_name  NVARCHAR(100) NOT NULL,
    imd_score             FLOAT         NULL,
    imd_rank              INT           NULL,
    imd_decile            TINYINT       NULL,
    CONSTRAINT PK_deprivation_scores PRIMARY KEY (local_authority_code)
);

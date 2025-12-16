1.Income vs YearsAtCompany – Who is underpaid & leaving?

WITH Inc_att AS (
    SELECT
        EmployeeNumber,
        Attrition,
        MonthlyIncome,
        YearsAtCompany,
        CASE
            WHEN YearsAtCompany BETWEEN 0 AND 2 THEN '0-2'
            WHEN YearsAtCompany BETWEEN 3 AND 5 THEN '3-5'
            WHEN YearsAtCompany BETWEEN 6 AND 10 THEN '6-10'
            WHEN YearsAtCompany > 10 THEN '>10'
        END AS Experience_Bucket
    FROM cleaned_hr
),
Avg_inco AS (
    SELECT
        Experience_Bucket,
        MonthlyIncome,
        Attrition,
        AVG(MonthlyIncome) OVER (PARTITION BY Experience_Bucket) AS Avg_Income_Bucket
    FROM Inc_att
)
SELECT 
    Experience_Bucket,
    COUNT(*) AS Underpaid_Employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS Underpaid_Left,
    ROUND(SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Underpaid_Attrition_Rate
FROM Avg_inco
WHERE MonthlyIncome < Avg_Income_Bucket
GROUP BY Experience_Bucket
ORDER BY Underpaid_Attrition_Rate DESC;

2.Ranking Top Flight Risks

WITH Risk_Data AS (
    SELECT
        Department,
        EmployeeNumber,
        OverTime,
        JobSatisfaction,
        DistanceFromHome,
        PercentSalaryHike,
        MonthlyIncome,
        (CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) +
        (CASE WHEN JobSatisfaction <= 2 THEN 1 ELSE 0 END) +
        (CASE WHEN DistanceFromHome > 10 THEN 1 ELSE 0 END) +
        (CASE WHEN PercentSalaryHike < 15 THEN 1 ELSE 0 END) AS Risk_Score
    FROM hr_analysis
),
ranked AS (
    SELECT
        Department,
        EmployeeNumber,
        Risk_Score,
        MonthlyIncome,
        ROW_NUMBER() OVER (
            PARTITION BY Department
            ORDER BY Risk_Score DESC, MonthlyIncome ASC
        ) AS Risk_Rank
    FROM Risk_Data
    WHERE Risk_Score >= 2
)
SELECT *
FROM ranked
WHERE Risk_Rank <= 5
ORDER BY Department, Risk_Rank;

3.Career Stagnation vs Attrition

WITH Stagnation AS (
    SELECT
        Attrition,
        YearsInCurrentRole,
        YearsSinceLastPromotion,
        CASE 
            WHEN YearsInCurrentRole > (YearsSinceLastPromotion + 3) THEN 'Stagnant'
            ELSE 'Not_Stagnant'
        END AS Stagnation_Status,
        CASE 
            WHEN YearsInCurrentRole > (YearsSinceLastPromotion + 3) 
                 AND YearsAtCompany > 5 THEN 'High_Tenure_Stagnant'
            ELSE 'Other'
        END AS Severe_Stagnation
    FROM hr_analysis
)
SELECT *
FROM (
    SELECT
        Stagnation_Status AS Category,
        COUNT(*) AS Total_Employees,
        SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS Attrition_Count,
        ROUND(SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100 / COUNT(*), 2) AS Attrition_Rate
    FROM Stagnation
    GROUP BY Stagnation_Status

    UNION ALL

    SELECT
        Severe_Stagnation,
        COUNT(*),
        SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
        ROUND(SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100 / COUNT(*), 2)
    FROM Stagnation
    GROUP BY Severe_Stagnation
) t
ORDER BY Attrition_Rate DESC;


4.Work-Life Balance + OverTime Combo Effect

SELECT
    WorkLifeBalance,
    OverTime,
    COUNT(*) AS Total,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS Lefti,
    ROUND(SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Attrition_Rate
FROM hr_analysis
GROUP BY WorkLifeBalance, OverTime
ORDER BY Attrition_Rate DESC;

5.Salary Hike vs Performance Rating Gap

SELECT
    PerformanceRating,
    PercentSalaryHike < 15 AS Low_Hike,
    COUNT(*) AS Total,
    ROUND(AVG(MonthlyIncome), 0) AS Avg_Income,
    ROUND(SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Attrition_Rate
FROM hr_analysis
GROUP BY PerformanceRating, (PercentSalaryHike < 15)
ORDER BY PerformanceRating, Attrition_Rate DESC;

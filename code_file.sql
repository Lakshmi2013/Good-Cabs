### ADHOC REQUEST 1

SELECT 
    dc.city_name,
    COUNT(ft.trip_id) AS total_trips,
    ROUND(SUM(ft.fare_amount) / NULLIF(SUM(ft.distance_travelled_km), 0), 2) AS avg_fare_per_km,
    ROUND(SUM(ft.fare_amount) / NULLIF(COUNT(ft.trip_id), 0), 2) AS avg_fare_per_trip,
    CONCAT(
        ROUND((COUNT(ft.trip_id) * 100.0) / NULLIF(SUM(COUNT(ft.trip_id)) OVER (), 0), 2),
        '%'
    ) AS Percentage_contribution_to_total_trips
FROM 
    fact_trips ft
JOIN 
    dim_city dc ON ft.city_id = dc.city_id
GROUP BY 
    dc.city_name
ORDER BY 
    total_trips DESC;

### ADHOC REQUEST 2

SELECT 
    dc.city_name,
    dd.month_name,
    COALESCE(COUNT(ft.trip_id), 0) AS actual_trips,
    COALESCE(mtt.total_target_trips, 0) AS target_trips,
    CASE 
        WHEN COALESCE(COUNT(ft.trip_id), 0) > COALESCE(mtt.total_target_trips, 0) THEN 'Above Target'
        WHEN COALESCE(COUNT(ft.trip_id), 0) < COALESCE(mtt.total_target_trips, 0) THEN 'Below Target'
        ELSE 'On Target'
    END AS performance_status,
    ROUND(
        (COALESCE(COUNT(ft.trip_id), 0) - COALESCE(mtt.total_target_trips, 0)) * 100.0 / NULLIF(COALESCE(mtt.total_target_trips, 0), 0), 
        2
    ) AS per_difference
FROM 
    dim_city dc
JOIN 
    fact_trips ft ON dc.city_id = ft.city_id
JOIN 
    dim_date dd ON ft.date = dd.date
LEFT JOIN 
    targets_db.monthly_target_trips mtt ON ft.city_id = mtt.city_id AND dd.start_of_month = mtt.month
GROUP BY 
    dc.city_name, dd.month_name, mtt.total_target_trips
ORDER BY 
    dc.city_name, dd.month_name;
    
    
    
### ADHOC REQUEST 3

WITH TotalRepeatPassengers AS (
    -- Calculate total repeat passengers per city
    SELECT 
        dc.city_name,
        SUM(drtd.repeat_passenger_count) AS total_repeat_passengers
    FROM 
        dim_city dc
    JOIN 
        dim_repeat_trip_distribution drtd ON dc.city_id = drtd.city_id
    GROUP BY 
        dc.city_name
),
PercentageDistribution AS (
    -- Calculate repeat passenger percentage for each trip count
    SELECT 
        dc.city_name,
        drtd.trip_count,
        SUM(drtd.repeat_passenger_count) AS repeat_passenger_count,
        CONCAT(
            ROUND(
                (SUM(drtd.repeat_passenger_count) * 100.0) / NULLIF(tp.total_repeat_passengers, 0), 
                2
            ), '%'
        ) AS percentage_distribution
    FROM 
        dim_city dc
    JOIN 
        dim_repeat_trip_distribution drtd ON dc.city_id = drtd.city_id
    JOIN 
        TotalRepeatPassengers tp ON dc.city_name = tp.city_name
    GROUP BY 
        dc.city_name, drtd.trip_count, tp.total_repeat_passengers
),
PivotedResults AS (
    -- Pivot the results to have separate columns for each trip count
    SELECT 
        city_name,
        MAX(CASE WHEN trip_count = '2-Trips' THEN percentage_distribution ELSE '0%' END) AS `2-Trips`,
        MAX(CASE WHEN trip_count = '3-Trips' THEN percentage_distribution ELSE '0%' END) AS `3-Trips`,
        MAX(CASE WHEN trip_count = '4-Trips' THEN percentage_distribution ELSE '0%' END) AS `4-Trips`,
        MAX(CASE WHEN trip_count = '5-Trips' THEN percentage_distribution ELSE '0%' END) AS `5-Trips`,
        MAX(CASE WHEN trip_count = '6-Trips' THEN percentage_distribution ELSE '0%' END) AS `6-Trips`,
        MAX(CASE WHEN trip_count = '7-Trips' THEN percentage_distribution ELSE '0%' END) AS `7-Trips`,
        MAX(CASE WHEN trip_count = '8-Trips' THEN percentage_distribution ELSE '0%' END) AS `8-Trips`,
        MAX(CASE WHEN trip_count = '9-Trips' THEN percentage_distribution ELSE '0%' END) AS `9-Trips`,
        MAX(CASE WHEN trip_count = '10-Trips' THEN percentage_distribution ELSE '0%' END) AS `10-Trips`
    FROM 
        PercentageDistribution
    GROUP BY 
        city_name
)
-- Final select from the pivoted results
SELECT 
    *
FROM 
    PivotedResults
ORDER BY 
    city_name;
    
    
### ADHOC REQUEST 4

WITH CityPassengerSummary AS (
    -- Calculate total new passengers for each city
    SELECT 
        dc.city_name,
        SUM(fps.new_passengers) AS total_new_passengers
    FROM 
        dim_city dc
    JOIN 
        fact_passenger_summary fps ON dc.city_id = fps.city_id
    GROUP BY 
        dc.city_name
),
RankedCities AS (
    -- Rank cities by total new passengers in descending and ascending order
    SELECT 
        city_name,
        total_new_passengers,
        RANK() OVER (ORDER BY total_new_passengers DESC) AS rank_top,
        RANK() OVER (ORDER BY total_new_passengers ASC) AS rank_bottom
    FROM 
        CityPassengerSummary
),
TopBottomCities AS (
    -- Select the Top 3 and Bottom 3 cities
    SELECT 
        city_name,
        total_new_passengers,
        CASE 
            WHEN rank_top <= 3 THEN 'Top3'
            WHEN rank_bottom <= 3 THEN 'Bottom3'
        END AS city_category
    FROM 
        RankedCities
    WHERE 
        rank_top <= 3 OR rank_bottom <= 3
)
-- Final output
SELECT 
    city_name,
    total_new_passengers,
    city_category
FROM 
    TopBottomCities
ORDER BY 
    city_category, total_new_passengers DESC;
    
    
### ADHOC REQUEST 5

WITH CityMonthRevenue AS (
    -- Calculate total revenue for each city and month
    SELECT 
        dc.city_name,
        dd.month_name,
        SUM(ft.fare_amount) AS revenue
    FROM 
        dim_city dc
    JOIN 
        fact_trips ft ON dc.city_id = ft.city_id
    JOIN 
        dim_date dd ON ft.date = dd.date
    GROUP BY 
        dc.city_name, dd.month_name
),
CityTotalRevenue AS (
    -- Calculate total revenue for each city
    SELECT 
        city_name,
        SUM(revenue) AS total_revenue
    FROM 
        CityMonthRevenue
    GROUP BY 
        city_name
),
CityHighestRevenueMonth AS (
    -- Identify the month with the highest revenue for each city
    SELECT 
        cmr.city_name,
        cmr.month_name AS highest_revenue_month,
        cmr.revenue,
        ROUND((cmr.revenue * 100.0) / ctr.total_revenue, 2) AS percentage_contribution
    FROM 
        CityMonthRevenue cmr
    JOIN 
        CityTotalRevenue ctr ON cmr.city_name = ctr.city_name
    WHERE 
        cmr.revenue = (
            SELECT 
                MAX(revenue)
            FROM 
                CityMonthRevenue cmr_inner
            WHERE 
                cmr_inner.city_name = cmr.city_name
        )
)
-- Final output
SELECT 
    city_name,
    highest_revenue_month,
    revenue,
    CONCAT(percentage_contribution, '%') AS percentage_contribution
FROM 
    CityHighestRevenueMonth
ORDER BY 
    city_name;


## ADHOC REQUEST 6

WITH MonthlyCitySummary AS (
    -- Calculate monthly total passengers and repeat passengers for each city
    SELECT 
        dc.city_name,
        DATE_FORMAT(fps.month, '%Y-%m') AS month,
        SUM(fps.total_passengers) AS total_passengers,
        SUM(fps.repeat_passengers) AS repeat_passengers
    FROM 
        dim_city dc
    JOIN 
        fact_passenger_summary fps ON dc.city_id = fps.city_id
    GROUP BY 
        dc.city_name, DATE_FORMAT(fps.month, '%Y-%m')
),
CityTotalSummary AS (
    -- Calculate overall total and repeat passengers for each city across all months
    SELECT 
        city_name,
        SUM(total_passengers) AS city_total_passengers,
        SUM(repeat_passengers) AS city_total_repeat_passengers
    FROM 
        MonthlyCitySummary
    GROUP BY 
        city_name
),
FinalAnalysis AS (
    -- Combine monthly and city-level data
    SELECT 
        mcs.city_name,
        mcs.month,
        mcs.total_passengers,
        mcs.repeat_passengers,
        CONCAT(ROUND((mcs.repeat_passengers * 100.0) / NULLIF(mcs.total_passengers, 0), 2), '%') AS monthly_total_passengers_rate,
        CONCAT(ROUND((cts.city_total_repeat_passengers * 100.0) / NULLIF(cts.city_total_passengers, 0), 2), '%') AS city_total_passengers_rate
    FROM 
        MonthlyCitySummary mcs
    JOIN 
        CityTotalSummary cts ON mcs.city_name = cts.city_name
)
-- Final output
SELECT 
    city_name,
    month,
    total_passengers,
    repeat_passengers,
    monthly_total_passengers_rate,
    city_total_passengers_rate
FROM 
    FinalAnalysis
ORDER BY 
    city_name, month;


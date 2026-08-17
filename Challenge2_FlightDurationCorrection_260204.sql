/* The Challenge: Is the "actual_elapsed_time" column accurate?
 *
 * As a Data Analyst, it is essential to ensure the reliability of your data.
 * The "actual_elapsed_time" column in the flights table shows the current data on the time from departure 
 * to arrival. Since it's unlikely there is a timer running for each flight, the value is probably 
 * calculated afterward. We might want to double-check this to ensure our analysis and recommendations are 
 * accurate. Verifying it will give us a solid basis for making decisions.
 */

SELECT * FROM countries;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'flights'
ORDER BY ordinal_position;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'airports'
ORDER BY ordinal_position;

/* 1.Using the data in the remaining columns in the flights table, can you think of a way to verify our assumption?
 *   Please provide a text answer below.
 */

SELECT * FROM flights;

-- calculate the difference between departure and arrival time 
-- compare it to actual_elapsed_time `arr_time` - `dep_time`= `actual_elapsed_time` ?

/* 2.1 The first step is to become familiar with the dep_time, arr_time and actual_elapsed_time columns.
 *   Based on the column names and what you already know from previous exercises about the information 
 * that is stored in these three columns, what are your assumptions about the data types of the values?
 * Check the source documentation.
 */

-- According to the documentation:
-- arr_time is a hundred or thousand number
SELECT DISTINCT arr_time, dep_time
FROM flights f
ORDER BY arr_time DESC;


-- dep_time is a hundred or thousand number
SELECT DISTINCT dep_time
FROM flights f
ORDER BY dep_time DESC;


-- actual_elapsed_time is a hundred or thousand number
SELECT DISTINCT actual_elapsed_time 
FROM flights f
ORDER BY actual_elapsed_time DESC;

/* 2.2 Retrieve all unique values from these columns in three separate queries and switch between ascending/descending order.
 *     Did your assumptions turn out to be correct?
 * 	   Please provide the queries and observations as text below.
 */


-- arr_time is a hundred or thousand number
SELECT DISTINCT arr_time
FROM flights f
ORDER BY arr_time DESC;


-- dep_time is a hundred or thousand number
SELECT DISTINCT dep_time
FROM flights f
ORDER BY dep_time DESC;


-- actual_elapsed_time is a hundred or thousand number
SELECT DISTINCT actual_elapsed_time 
FROM flights f
ORDER BY actual_elapsed_time DESC;

/* 3.1 Next, calculate the difference of dep_time and arr_time and call it flight_duration.
 * 	   Please provide the query below.
 */

SELECT arr_time - dep_time, 
		actual_elapsed_time AS flight_duration
FROM flights;


-- Average flight duration grouped by airline

SELECT
    airline,
    ROUND(AVG(actual_elapsed_time),1) AS avg_flight_duration_minutes
FROM flights
WHERE actual_elapsed_time IS NOT NULL
GROUP BY airline
ORDER BY avg_flight_duration_minutes DESC;

/* 3.2 Are the calculated flight duration values correct? Compare it with the actual_elapsed_time column.
 *  If not, what's the problem and how can we solve it?
 *     Please provide the query and a text answer below.
 */

-- No, the values are not correct. 
-- dep_time and arr_time are not in time formats and the difference is not in minutes.

-- actual_elapsed_time = gate-out → gate-in time (in minutes) = clock time difference between departure and arrival

-- Step 1. Convert HHMM format to minutes (since 930 - 845 ≠ 45 minutes)

SELECT
    dep_time,
    (dep_time / 100) * 60 + (dep_time % 100) AS dep_minutes,
    arr_time,
    (arr_time / 100) * 60 + (arr_time % 100) AS arr_minutes
FROM flights
WHERE dep_time IS NOT NULL
  AND arr_time IS NOT NULL
LIMIT 5;

SELECT  dep_time, (dep_time / 100) * 60 + (dep_time % 100) AS dep_minutes FROM flights

/* 4. In order to calculate correct flight duration values we need to convert dep_time, arr_time and actual_elapsed_time 
 *   into useful data types first.
 *   Change dep_time and arr_time into TIME variables, call them dep_time_f and arr_time_f. 
 *   Change actual_elapsed_time into an INTERVAL variable, call it actual_elapsed_time_f.
 *   Query flight_date, origin, dest, dep_time, dep_time_f, arr_time, arr_time_f, actual_elapsed_time and actual_elapsed_time_f.
 *   Please provide the query below.
 */

--- Step 1 — Convert dep_time and arr_time (HHMM integers) to TIME
SELECT
    dep_time,
    MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f
FROM flights
WHERE dep_time IS NOT NULL
LIMIT 10;

-- Step 2 - Convert actual_elapsed_time (minutes) to INTERVAL

SELECT
    actual_elapsed_time,
    actual_elapsed_time * INTERVAL '1 minute' AS actual_elapsed_time_f
FROM flights
WHERE actual_elapsed_time IS NOT NULL
LIMIT 10;

-- Step 3 - Combine everything into the requested query
SELECT
    flight_date,
    origin,
    dest,
    dep_time,
    MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f,
    arr_time,
    MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f,
    actual_elapsed_time,
    actual_elapsed_time * INTERVAL '1 minute' AS actual_elapsed_time_f
FROM flights
WHERE cancelled = 0
  AND dep_time IS NOT NULL
  AND arr_time IS NOT NULL
  AND actual_elapsed_time IS NOT NULL
LIMIT 5;


/* 5.1 Querying the raw columns next to the ones we have transformed, makes it a lot easier to compare the result to the input.
 *     This allows for quick prototyping and debugging and helps to understand how functions work. 
 *     To optimize our query in terms of performance and readability, we can always remove unneccessary columns in the end. 
 *     Use the previous query and calculate the difference of arr_time_f and dep_time_f and call it flight_duration_f.
 * 	   Please provide the query below.
 */
 
-- Step 1 — Confirm TIME subtraction works
SELECT
    dep_time_f,
    arr_time_f,
    arr_time_f - dep_time_f AS raw_duration
FROM (
    SELECT -- MAKE_TIME() specific expression converts an integer representation of time (often seen in datasets like flight schedules) into a standard PostgreSQL TIME format
        MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f, 
        -- dep_time / 100 (Hours): Uses integer division to extract the first one or two digits. For 1345, 1345 / 100 equals 13.
        -- dep_time % 100 (Minutes): Uses the modulo operator to get the remainder, which represents the minutes. For 1345, 1345 % 100 equals 45.
        -- 0 (Seconds): Hardcodes the seconds component to zero.
        MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f
    FROM flights
    WHERE dep_time IS NOT NULL
      AND arr_time IS NOT NULL
) subquery
LIMIT 10;

-- Step 2 — Detect overnight flights [Filtering for Overnight Flights]
/*
 * In PostgreSQL, when you subtract two TIME values where the arrival is earlier than the departure 
 * (e.g., departing at 23:00 and arriving at 02:00), the result is a negative interval. 
 * You can identify overnight flights by filtering for these negative differences.
 * Imagine a flight that departs at 10:00 PM (2200) and arrives at 2:00 AM (0200):
 * 02-22= negative 
 */

SELECT *
FROM (
    SELECT
        MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f,
        MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f,
        (MAKE_TIME(arr_time / 100, arr_time % 100, 0) - MAKE_TIME(dep_time / 100, dep_time % 100, 0)) AS overnight
    FROM flights
    WHERE dep_time IS NOT NULL AND arr_time IS NOT NULL
) subquery
WHERE overnight < '00:00:00'::interval -- Filters for overnight flights
LIMIT 10;

-- Step 3 - Correct for overnight flights [add 24 hours to the arrival time only when needed.]

SELECT 
    dep_time_f, -- column 1
    arr_time_f, -- column 2
    CASE 
        WHEN arr_time_f < dep_time_f THEN (arr_time_f - dep_time_f) + INTERVAL '24 hours' -- correction when overnight flight
        ELSE arr_time_f - dep_time_f
    END AS true_duration -- column 3 
FROM (
    SELECT
        MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f,
        MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f,
        (MAKE_TIME(arr_time / 100, arr_time % 100, 0) - MAKE_TIME(dep_time / 100, dep_time % 100, 0)) AS overnight 
    FROM flights
    WHERE dep_time IS NOT NULL AND arr_time IS NOT NULL
) subquery;

-- Step 3 - Using a Common Table Expression before detecting and correcting for overnight flights

WITH formatted_flights AS (
    SELECT
        MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f,
        MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f,
        -- Calculate the raw difference
        (MAKE_TIME(arr_time / 100, arr_time % 100, 0) - MAKE_TIME(dep_time / 100, dep_time % 100, 0)) AS overnight
    FROM flights
    WHERE dep_time IS NOT NULL 
      AND arr_time IS NOT NULL
)
SELECT 
    dep_time_f, 
    arr_time_f, 
    overnight,
    -- Add 24 hours to negative differences to get the real travel time
    CASE 
        WHEN overnight < '0 hours'::interval THEN diff + INTERVAL '24 hours'
        ELSE overnight
    END AS actual_duration
FROM formatted_flights
WHERE overnight < '0 hours'::interval  -- This filters for ONLY overnight flights
LIMIT 10;


/* 5.2 Compare the calculated flight duration values in flight_duration_f with the values in the actual_elapsed_time_f column:
 * show 
 * 		- total number of "same value" match
 * 		- total count of all values 
 * 		- calculate the percentage of values that are equal in both columns vs total count of all values
 * Please provide the query below.
 */

-- Step 1. Compare flight_duration_f with actual_elapsed_time_f
WITH flight_times AS ( -- Create a CTE that does all transformations
-- A. selecting duration variables 
    SELECT
        flight_date,
        origin,
        dest,
        dep_time,
        MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f,
        arr_time,
        MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f,
        actual_elapsed_time,
        actual_elapsed_time * INTERVAL '1 minute' AS actual_elapsed_time_f, -- Take the number of minutes and turn it into a real time duration
        CASE
            WHEN MAKE_TIME(arr_time / 100, arr_time % 100, 0) < MAKE_TIME(dep_time / 100, dep_time % 100, 0) -- identify overnight flights 
            THEN (MAKE_TIME(arr_time / 100, arr_time % 100, 0) + INTERVAL '24 hours') - MAKE_TIME(dep_time / 100, dep_time % 100, 0)
            ELSE MAKE_TIME(arr_time / 100, arr_time % 100, 0) - MAKE_TIME(dep_time / 100, dep_time % 100, 0)
        END AS flight_duration_f
-- A. selecting from table flights
    FROM flights
-- A. filtering out for cancelled, diverted and missing flight times
    WHERE cancelled = 0
      AND diverted = 0
      AND dep_time IS NOT NULL
      AND arr_time IS NOT NULL
      AND actual_elapsed_time IS NOT NULL
-- B. selecting columns of interest with corrected values
) SELECT
    flight_date,
    origin,
    dest,
    flight_duration_f,
    actual_elapsed_time_f,
    flight_duration_f - actual_elapsed_time_f AS diff_interval --- Comparison of calculated vs actual elapsed time
FROM flight_times;

-- Step 2. Create a View to simpify life

CREATE VIEW flight_times AS
SELECT
    flight_date,
    origin,
    dest,

    dep_time,
    MAKE_TIME(dep_time / 100, dep_time % 100, 0) AS dep_time_f,

    arr_time,
    MAKE_TIME(arr_time / 100, arr_time % 100, 0) AS arr_time_f,

    actual_elapsed_time,
    actual_elapsed_time * INTERVAL '1 minute' AS actual_elapsed_time_f,

    CASE
        WHEN MAKE_TIME(arr_time / 100, arr_time % 100, 0)
             < MAKE_TIME(dep_time / 100, dep_time % 100, 0)
        THEN (MAKE_TIME(arr_time / 100, arr_time % 100, 0) + INTERVAL '24 hours')
             - MAKE_TIME(dep_time / 100, dep_time % 100, 0)
        ELSE MAKE_TIME(arr_time / 100, arr_time % 100, 0)
             - MAKE_TIME(dep_time / 100, dep_time % 100, 0)
    END AS flight_duration_f

FROM flights
WHERE cancelled = 0
  AND diverted = 0
  AND dep_time IS NOT NULL
  AND arr_time IS NOT NULL
  AND actual_elapsed_time IS NOT NULL;

--SANITY CHECK 
SELECT * FROM flight_times LIMIT 10;

--- STEP 3 - calculate the percentage of values that are equal in both columns vs total count of all VALUES

SELECT
    COUNT(*) AS total_flights, -- denominator for the percentage calculation.
    SUM(CASE
	    --- flight_duration_f → calculated from dep/arr times (clock-based)
	    --- actual_elapsed_time_f → reported elapsed time
        	WHEN ABS(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))) > 60 -- absolute value of difference in seconds
          THEN 1 ELSE 0
        END
    ) AS different_flights,
    ROUND(100.0 * SUM(
          CASE
           WHEN ABS(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))) > 60 --- flights where the difference is ≤ 1 minute.
           THEN 1 ELSE 0
          END
        ) / COUNT(*), 2
    ) AS percent_different --- fraction of flights have “matching” durations.
FROM flight_times;

/* 5.3 Given the percentage of matching values, can you come up with possible explanations for why the rate is so low?
 *  The low percentage means that the clock-based duration (dep/arr times) often differs from the reported gate-to-gate elapsed time.
 *    1. Clock times are rounded (precision 1 minute), elapsed times are measured automatically
 * 	 2. Definition mismatch: gate time vs recorded time where e.g., dep_time = Wheels off OR gate pushback
 * 	 3. Overnight and multi-day edge cases:
 * 		3.1  Some flights arrive after more than 24 hours
 * 		3.2. Delays + diversions can distort times
 * 		3.3. Timezone effects (even in domestic datasets)
 * 	 4. Incorrect or inconsistent data entry: e.g., Missing or default values (e.g., 0, 999)
 * 	 5. Cancelled or diverted flights slipping through
 * 	 6. Exact equality is an unrealistically strict criterion
 */

-- NEXT ANALYTICAL STEP: To diagnose which explanation dominates
-- First step Descriptive Statistics of differences
SELECT
    AVG(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS avg_diff_minutes,
    STDDEV(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS std_diff_minutes,
    MIN(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS min_diff_minutes,
    MAX(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS max_diff_minutes
FROM flight_times;

--- Frequency distribution of differences (Long tails → data quality problems)
SELECT
    ROUND(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS diff_minutes,
    COUNT(*) AS num_flights
FROM flight_times
GROUP BY diff_minutes
ORDER BY diff_minutes;

--- Mean differences (ideally Paired t-test BUT need to export to python or r!)
SELECT
    AVG(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS avg_diff_minutes
FROM flight_times; -- if Positive/negative → systematic bias


/* 6.1 Differences due to time zones might be one reason for the low rate of matching values.
 *     To make sure the dep_time and arr_time values are all in the same time zone we need to know in which time zone they are.
 *     Take your query from exercise 5.1 and add the time zone values from the airports table.
 * 	   Make sure to transform them to INTERVAL and change their names to origin_tz and dest_tz.
 *     Please provide the query below.
 */

-- Step 1. Temporary CTE Table with corrected values
WITH flight_times AS (
    SELECT
        f.flight_date,
        f.origin,
        f.dest,

        -- Original HHMM times
        f.dep_time,
        f.arr_time,

        -- Convert HHMM → TIME
        MAKE_TIME(f.dep_time / 100, f.dep_time % 100, 0) AS dep_time_f, -- first extract hour, second extract minutes
        MAKE_TIME(f.arr_time / 100, f.arr_time % 100, 0) AS arr_time_f,

        -- Actual elapsed time
        f.actual_elapsed_time,
        f.actual_elapsed_time * INTERVAL '1 minute' AS actual_elapsed_time_f, -- Take the number of minutes and turn it into a real time duration

        -- Time zone offsets as INTERVALS
        ao.tz * INTERVAL '1 hour' AS origin_tz, -- e.g.,  ao.tz = -5 --> -5 * INTERVAL '1 hour' = -05:00:00
        ad.tz * INTERVAL '1 hour' AS dest_tz, -- Note: INTERVAL is mandatory for valid time arithmetic.

        -- Convert local times to a common (UTC-like) reference
        (MAKE_TIME(f.dep_time / 100, f.dep_time % 100, 0) - ao.tz * INTERVAL '1 hour')
            AS dep_time_utc,

        (MAKE_TIME(f.arr_time / 100, f.arr_time % 100, 0) - ad.tz * INTERVAL '1 hour')
            AS arr_time_utc

    FROM flights f -- INNER JOIN = If an airport code is missing from airports, the flight is dropped
    JOIN airports ao ON f.origin = ao.faa -- “What time zone was the departure in?”
    JOIN airports ad ON f.dest   = ad.faa -- “What time zone was the arrival in?” 

    WHERE f.cancelled = 0
      AND f.diverted = 0
      AND f.dep_time IS NOT NULL
      AND f.arr_time IS NOT NULL
      AND f.actual_elapsed_time IS NOT NULL
)
-- Step 2. 
SELECT
    flight_date,
    origin,
    dest,
    origin_tz,
    dest_tz,

    -- Handle overnight flights AFTER time-zone correction
    CASE
        WHEN arr_time_utc < dep_time_utc
        THEN (arr_time_utc + INTERVAL '24 hours') - dep_time_utc
        ELSE arr_time_utc - dep_time_utc
    END AS flight_duration_f,

    actual_elapsed_time_f,

    -- Final comparison
    CASE
        WHEN arr_time_utc < dep_time_utc
        THEN (arr_time_utc + INTERVAL '24 hours') - dep_time_utc
        ELSE arr_time_utc - dep_time_utc
    END - actual_elapsed_time_f AS diff_interval

FROM flight_times;

--- Step 3. New rate of mismatches




/* 6.2 Use the time zone columns to convert dep_time_f and arr_time_f to UTC and call them dep_time_f_utc and arr_time_f_utc.
 * 	   Calculate the difference of both columns and call it flight_duration_f_utc.
 *     Please provide the query below.
 */





/* 6.3 Again, calculate the percentage of matching records using the new flight_duration_f_utc column.
 *     Try to round the result to two decimals.
 *     Explain the increase in matching records.
 *     Please provide the query and a text answer below.
 */




/* Extra Challenge
 * For the essential part of the SQL challenge, it's ok if you just read through the SQL query.
 * Queries 7.1 and 7.2 are just there to make you aware of the problem...
 * Query 7.3 actual implements a solution. Pay especially attention to the CASE WHEN statement.
 * this is the statement that fixes the issue for overnight flights
 */

/* 7.1 We managed to increase the rate of matching records to >80%, but it's still not at 100%.
 *     Could overnight flights be an issue?
 *     What is special about values in the flight_duration_f_utc column for overnight flights?
 * 	   Hint: order by flight_duration_f_utc
 *     Please provide the query and a text answer below.
 */

-- Answer: ...




/* 7.2 Calculate the total number of flights that arrived after midnight UTC.
 *     Please provide the query below.
 */




/* 7.3 Use your knowledge from 7.1 and 7.2 to increase the rate of matching records even further.
 *     Please provide the query below.
 */




/*
 * ok great! we get a match of >90%! We leave it at that for now...
 * After this long part of verifying the column actual_elapsed_time we feel confident
 * to make analysis based on this column and give out business recommendations.
*/

/* The flight-scheduling department needs support with their monthly review of scheduled 
 * flight durations. Their job is it to define the most accurate flight durations for all
 * available routes. It works the following: you have 'scheduled departing time'
 * and the flight-scheduling department is in charge of defining the 'scheduled arrival time'. 
 * Given these two times, you can calculate the 'scheduled flight duration'.
 * The 'scheduled flight duration' is the metric the department wants to review. 
 * How accurate is the metric 'scheduled flight duration' compared to the 'actual_elapsed_time'? 
 * The team is especially interested if 'scheduled flight duration' is shorter than 'actual_elapsed_time'.
 * They want to know which routes have the highest share of flights where 
 * the 'scheduled flight duration' is shorter than 'actual_elapsed_time'? 
 * and what's the average difference for flights on that route? 
 * To make it worthwhile, they focus on routes that had at least 30 flights in January.
 * You as an analyst are asked to answer these questions with the help of the available data.
 * You are asked to summarize your main findings in a short text.
*/


-- DST
https://openflights.org/help/time.php
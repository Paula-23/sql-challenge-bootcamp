/* -- Reasons for mismatches:
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

/*-- Solution 1: Using view tables to make it easier
 * 
 */

-- Step 1. Temporary View Table with corrected values
CREATE VIEW flight_times_vw AS
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
      AND f.actual_elapsed_time IS NOT NULL; 

SELECT * FROM flight_times_vw ftv 

-- Step 2. Call table with difference comparison
CREATE VIEW indicator_diff_vw AS
SELECT
    flight_date,
    origin,
    dest,
    origin_tz,
    dest_tz,
    -- Handle overnight flights AFTER time-zone correction: Some flights leave before midnight and arrive after midnight.
    CASE
        WHEN arr_time_utc < dep_time_utc --- If you just subtract dep_time_utc from arr_time_utc, you’d get a negative duration.
        THEN (arr_time_utc - dep_time_utc) + INTERVAL '24 hours' --- The CASE fixes this by adding 24 hours to the arrival time for overnight flights.
        ELSE arr_time_utc - dep_time_utc
    END AS flight_duration_f,
    actual_elapsed_time_f,
    -- Final comparison
    CASE
        WHEN arr_time_utc < dep_time_utc
        THEN (arr_time_utc - dep_time_utc) + INTERVAL '24 hours'
        ELSE arr_time_utc - dep_time_utc
    END - actual_elapsed_time_f AS diff_interval -- → how much the computed duration differs from the official duration.
FROM flight_times_vw;

SELECT * FROM flight_times_vw

-- Step 3. Calculate the Rate OF Mismatches

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
FROM indicator_diff_vw;

-- Step 4. Distribution of differences:

--- Frequency distribution of differences (Long tails → data quality problems)
SELECT
    ROUND(EXTRACT(EPOCH FROM (flight_duration_f - actual_elapsed_time_f))/60) AS diff_minutes,
    COUNT(*) AS num_flights
FROM indicator_diff_vw
GROUP BY diff_minutes
ORDER BY diff_minutes;

-- ------------------------------------------------------------------------------------------------ ---

/* -- Solution 2: CTE Table and no storage waste to make it pro:: single query pipeline
 * 
 */

WITH
-- =========================================================
-- Step 1. Base CTE with corrected and normalized time values
-- =========================================================
flight_times_cte AS (
    SELECT
        f.flight_date,
        f.origin,
        f.dest,

        -- Original HHMM times
        f.dep_time,
        f.arr_time,

        -- Convert HHMM → TIME
        MAKE_TIME(f.dep_time / 100, f.dep_time % 100, 0) AS dep_time_f,
        MAKE_TIME(f.arr_time / 100, f.arr_time % 100, 0) AS arr_time_f,

        -- Actual elapsed time (minutes → interval)
        f.actual_elapsed_time,
        f.actual_elapsed_time * INTERVAL '1 minute' AS actual_elapsed_time_f,

        -- Time zone offsets as INTERVALs
        ao.tz * INTERVAL '1 hour' AS origin_tz,
        ad.tz * INTERVAL '1 hour' AS dest_tz,

        -- Convert local clock times to a common UTC-like reference
        (MAKE_TIME(f.dep_time / 100, f.dep_time % 100, 0)
            - ao.tz * INTERVAL '1 hour') AS dep_time_utc,

        (MAKE_TIME(f.arr_time / 100, f.arr_time % 100, 0)
            - ad.tz * INTERVAL '1 hour') AS arr_time_utc

    FROM flights f
    JOIN airports ao ON f.origin = ao.faa   -- departure time zone
    JOIN airports ad ON f.dest   = ad.faa   -- arrival time zone
    WHERE f.cancelled = 0
      AND f.diverted = 0
      AND f.dep_time IS NOT NULL
      AND f.arr_time IS NOT NULL
      AND f.actual_elapsed_time IS NOT NULL
),

-- =========================================================
-- Step 2. Compute flight duration & compare to actual time
-- =========================================================
indicator_diff_cte AS ( --- At this point, all times are already normalized in flight_times_cte
 ---- Step 2.2. Selecting Flight Identifiers
	SELECT
        flight_date,
        origin,
        dest,
        origin_tz,
        dest_tz,

 ---- Step 2.3. Computing the Clock-Based Flight Duration
        CASE -- → departure clock time in a common reference
            WHEN arr_time_utc < dep_time_utc
            THEN (arr_time_utc + INTERVAL '24 hours') - dep_time_utc
            ELSE arr_time_utc - dep_time_utc
        END AS flight_duration_f,

        actual_elapsed_time_f,

 ---- Step 2.4. Computing difference between calculated duration and reported duration
        CASE
            WHEN arr_time_utc < dep_time_utc
            THEN (arr_time_utc + INTERVAL '24 hours') - dep_time_utc
            ELSE arr_time_utc - dep_time_utc
        END - actual_elapsed_time_f AS diff_interval
        
---- Step. 2.1. Input Data Source -------
    FROM flight_times_cte --- This CTE provides: Time-zone–corrected clock times + Pre-filtered valid flights + Elapsed time already converted to an interval
)

-- =========================================================
-- Step 3. Calculate mismatch rate (> 1 minute difference)
-- =========================================================
SELECT
    COUNT(*) AS total_flights, --- Counts all flights that passed the earlier filters: denominator for the percentage calculation
    SUM(
        CASE -- Compare absolute difference in seconds
            WHEN ABS(EXTRACT(EPOCH FROM diff_interval)) > 60  --- convert interval of the clock-based duration - reported elapsed duration into seconds
            THEN 1 ELSE 0 -- flag differences over 60 secons aka 1 minute
        END --- where 1 mismatched flights and 0 matching flight durations
    ) AS different_flights,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN ABS(EXTRACT(EPOCH FROM diff_interval)) > 60
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS percent_different
FROM indicator_diff_cte; --- from the indicator_diff_cte table already created

-- =========================================================
-- Step 4. Diagnostic Analysis:
-- =========================================================
/* Perfect / near-perfect
 *	0 → 1,345,988 ✅
 *	±1–10 → a handful
 *
 * The ±60 minute peaks (DST effect): This is classic Daylight Saving Time (DST) behavior.
 * 	-60 → 19,441
 * 	+60 → 17,087
 * -- uct does not encode DST rules
 * 
 * Huge negative values (≈ −1440, −1380, −1500) (Almost exactly multiples of 24 hours)
 * 
 * 	-1440 → 219,986  = 60 x 24
 * 	-1500 → 2,775 = 62.5 x 24
 * 	-1380 → 5,417 = 57.5 x 24
 * 
 * The arrival time (after tz correction) appears to be one full day earlier than expected.
 * 	The flight arrives after midnight local time
 *	The date rollover is not represented in the data
 *
 * Nulls: These come from rows where something upstream is missing after joins and transformations.
 * 	[null] → 328
 * 
 * Result:
 * | Cause                  | Approx share |
 * | ---------------------- | ------------ |
 * | DST transitions        | ~3–4%        |
 * | Midnight + TZ rollover | ~12–14%      | <<<----
 * | Data gaps / nulls      | ~0.02%       |
 * 
 * Conclusions:
 * Cannot solve the problem: The dataset does not provide variable "TIMESTAMP WITH TIME ZONE" or "Full DST calendars"
 * Remaining errors are structural, not mistakes 
 * The data is not rich enough to reach 100%
 * 
 * In a sentence:
 * The remaining mismatches are dominated by DST transitions and unmodeled date rollovers, producing exact ±60-minute 
 * and ±24-hour peaks that are mathematically inevitable when using fixed UTC offsets and TIME instead of 
 * full time-zone–aware timestamps.
 */




--------------------------Check for a unique column that are shared accross the tables, supposedly 'ID'

SELECT
	COLUMN_NAME,
	COUNT(TABLE_NAME)
FROM
	INFORMATION_SCHEMA.COLUMNS
GROUP BY COLUMN_NAME;



-------------------------------Confirming ID column is in every table

SELECT
	TABLE_NAME,
	check_column = SUM(CASE
	WHEN COLUMN_NAME = 'id' THEN 1
	ELSE 0
	END)
FROM
	fitbit_data.INFORMATION_SCHEMA.COLUMNS
GROUP BY TABLE_NAME

--Check if every table has a proper datetime column
SELECT
	TABLE_NAME,
	check_date = SUM(CASE
					WHEN DATA_TYPE IN ('DATETIME', 'DATE', 'TIME', 'TIMESTAMP') THEN 1
					ELSE 0
					END)
FROM
	fitbit_data.INFORMATION_SCHEMA.COLUMNS
WHERE
	DATA_TYPE IN ('DATETIME', 'DATE', 'TIME', 'TIMESTAMP')
GROUP BY TABLE_NAME
HAVING 'check_date' = '0'



----------------------Join the date across the tables, probe to see if the columns has key words for dates


SELECT
	COLUMN_NAME
FROM FITBIT_DATA.INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%DATE%' OR 
COLUMN_NAME LIKE '%DAY%' OR
COLUMN_NAME LIKE '%DAILY%' OR
COLUMN_NAME LIKE '%DATE%' OR
COLUMN_NAME LIKE '%MINUTE%' OR
COLUMN_NAME LIKE '%HOURLY%' OR
COLUMN_NAME LIKE '%HOUR%'




----------------------List tables that are at the day level so we can perform analysis on daily data

SELECT
	DISTINCT(TABLE_NAME)
FROM
	Fitbit_data.INFORMATION_SCHEMA.COLUMNS
WHERE
	COLUMN_NAME LIKE '%DAY%' OR
	COLUMN_NAME LIKE '%DAILY%'




---------------------------List the columns with date level from the above tables.


SELECT
	COLUMN_NAME,
	TABLE_NAME,
	Date_check = SUM(CASE
					WHEN COLUMN_NAME LIKE '%DAY%' OR
	COLUMN_NAME LIKE '%DAILY%' THEN 1
								ELSE 0
								END)
FROM
	Fitbit_data.INFORMATION_SCHEMA.COLUMNS
WHERE
	COLUMN_NAME LIKE '%DAY%' OR
	COLUMN_NAME LIKE '%DAILY%'
GROUP BY
	TABLE_NAME,
	COLUMN_NAME



--------------------------------another way


SELECT
	COLUMN_NAME,
	TABLE_NAME,
	Date_check = COUNT(table_name)
FROM
	Fitbit_data.INFORMATION_SCHEMA.COLUMNS
WHERE
	COLUMN_NAME LIKE '%DAY%' OR
	COLUMN_NAME LIKE '%DAILY%'
GROUP BY
	TABLE_NAME,
	COLUMN_NAME




--------------------------Make sure data type in those columns alligns


SELECT
	COLUMN_NAME,
	TABLE_NAME,
	DATA_TYPE
FROM
	Fitbit_data.INFORMATION_SCHEMA.COLUMNS
WHERE
	(TABLE_NAME LIKE '%DAY%' OR
	TABLE_NAME LIKE '%DAILY%') AND
	COLUMN_NAME IN (
		SELECT
			COLUMN_NAME
		FROM
			Fitbit_data.INFORMATION_SCHEMA.COLUMNS
		WHERE
			TABLE_NAME LIKE '%DAY%' OR
			TABLE_NAME LIKE '%DAILY%'
		GROUP BY
			COLUMN_NAME
		HAVING 
			COUNT(TABLE_NAME) >=2----condition to set the related columns appear in more than 2 tables
)
ORDER BY COLUMN_NAME;

---------------------------We realized that column 'sleepday' from sleep_day table did not match with other day format from other tables
---------------------------We then fix this issue by create another table
SELECT
	Fitbit_data.dbo.Sleep_day.Id,
	Fitbit_data.dbo.Sleep_day.TotalMinutesAsleep,
	Fitbit_data.dbo.Sleep_day.TotalSleepRecords,
	Fitbit_data.dbo.Sleep_day.TotalTimeInBed,
	LEFT(Fitbit_data.dbo.Sleep_day.SleepDay, (len(Fitbit_data.dbo.Sleep_day.sleepday)-12)) AS sleepday
INTO Fitbit_data.dbo.Sleep_day_alt
FROM Fitbit_data.dbo.Sleep_day



---------------------------Now, join the related tables for a complete table

 SELECT
 A.Id,
 A.Calories,
 A.ActivityDate,
 A.SedentaryMinutes,
 A.LightlyActiveMinutes,
 A.FairlyActiveMinutes,
 A.VeryActiveMinutes,
 A.SedentaryActiveDistance,
 A.LightActiveDistance,
 A.ModeratelyActiveDistance,
 A.VeryActiveDistance,
 Sl.TotalSleepRecords,
 sl.TotalMinutesAsleep,
 sl.TotalTimeInBed,
 ST.steptotal
 FROM
	Fitbit_data.dbo.daily_activity AS A 
	LEFT JOIN Fitbit_data.dbo.daily_calories AS C
	ON 
		A.Calories = C.Calories AND
		a.ActivityDate = c.ActivityDay AND
		A.Id = C.Id
	LEFT JOIN Fitbit_data.dbo.daily_intensities AS I
	ON
		A.FairlyActiveMinutes = I.FairlyActiveMinutes AND
		A.Id = I.ID AND
		A.ActivityDate = I.ActivityDay AND
		A.LightActiveDistance = I.LightActiveDistance AND
		A.LightlyActiveMinutes = I.LightlyActiveMinutes AND
		A.ModeratelyActiveDistance = I.ModeratelyActiveDistance AND
		A.SedentaryActiveDistance = I.ModeratelyActiveDistance AND
		A.SedentaryMinutes = I. SedentaryMinutes AND
		A.VeryActiveDistance = I.VeryActiveDistance AND
		A.VeryActiveMinutes = I. VeryActiveMinutes
	LEFT JOIN Fitbit_data.dbo.daily_steps ST
	ON A.Id = ST.Id AND
		A.ActivityDate = ST.ActivityDay
	LEFT JOIN Fitbit_data.dbo.Sleep_day_alt AS Sl
	ON	A.ID = Sl.Id AND
		A.ActivityDate = Sl.SleepDay



-------------------------------------ANALYSIS ON NAP TIME

SELECT
	id,
	sleep_start AS Sleep_date,
	count(logID) AS number_of_naps,
	SUM(duration) as total_time_nap
FROM
(SELECT 
	slm.Id,
	slm.logId,
	MIN(CAST(slm.date AS date)) AS sleep_start,
	MAX(cast(SLM.DATE as DATE)) AS Sleep_end,
	DATEDIFF(MINUTE,min(cast(slm.date as datetime)), max(cast(slm.date as datetime))) as duration
FROM
	fitbit_data.dbo.Sleep_minutes AS slm
WHERE
	value=1
GROUP BY
	slm.id,
	slm.logId) AS Sleep_duration
WHERE
	sleep_start = sleep_end AND
	Sleep_duration.duration < 180
GROUP BY
	sleep_duration.Id,
	sleep_duration.sleep_start
ORDER BY total_time_nap



---------------------------------------------RUN ANALYSIS ON ACTIVITY

SET DATEFIRST 1 -- (SUNDAY) ---set sunday as 1

WITH User_dow_summary AS
(
SELECT
id,
DATEPART(WEEKDAY, Activityhour) AS dow_number,
DATENAME(WEEKDAY, Activityhour) AS day_of_week,
CASE
	WHEN DATENAME(WEEKDAY, Activityhour) in ('Sunday', 'Saturday') THEN 'weekends'
	Else 'Weekdays'
END AS part_of_week,
CASE
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) BETWEEN 6 AND 12 THEN 'Morning'
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) BETWEEN 12 AND 18 THEN 'Afternoon'
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) BETWEEN 18 AND 22 THEN 'Evening'
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR))>=22 OR CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) <=6 THEN 'Night'
	ELSE 'error'
END AS Time_of_day,
SUM(CAST(TotalIntensity as float)) AS total_intensity,
SUM(CAST(AverageIntensity as float)) AS total_average_intensity,
AVG(CAST(AverageIntensity as float)) AS average_intensity,
MAX(CAST(AverageIntensity as float)) AS max_intensity,
MIN(CAST(AverageIntensity as float)) AS min_intensity
FROM Fitbit_data.DBO.Hourly_intensities
GROUP BY 
id,
DATEPART(WEEKDAY, Activityhour),
DATENAME(WEEKDAY, Activityhour),
CASE
	WHEN DATENAME(WEEKDAY, Activityhour) in ('Sunday', 'Saturday') THEN 'weekends'
	Else 'Weekdays'
END,
CASE
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) BETWEEN 6 AND 12 THEN 'Morning'
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) BETWEEN 12 AND 18 THEN 'Afternoon'
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) BETWEEN 18 AND 22 THEN 'Evening'
	WHEN CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR))>=22 OR CONVERT(INT,DATEPART(HOUR, ACTIVITYHOUR)) <=6 THEN 'Night'
	ELSE 'error'
END
),
intensity_deciles AS
(
SELECT
   DISTINCT dow_number,
   part_of_week,
   day_of_week,
   time_of_day,
   ROUND(PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_first_decile,
  ROUND(PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_second_decile,
   ROUND(PERCENTILE_CONT(0.3) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_third_decile,
   ROUND(PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_fourth_decile,
   ROUND(PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_sixth_decile,
   ROUND(PERCENTILE_CONT(0.7) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_seventh_decile,
   ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_eigth_decile,
   ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY Total_intensity) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS total_intensity_ninth_decile
 FROM
   user_dow_summary
),
basic_summary AS 
(
SELECT
   part_of_week,
   day_of_week,
   time_of_day,
   ROUND(SUM(total_intensity),4) AS total_total_intensity,
   ROUND(AVG(total_intensity),4) AS average_total_intensity,
   ROUND(SUM(total_average_intensity),4) AS total_total_average_intensity,
   ROUND(AVG(total_average_intensity),4) AS average_total_average_intensity,
   ROUND(SUM(average_intensity),4) AS total_average_intensity,
   ROUND(AVG(average_intensity),4) AS average_average_intensity,
   ROUND(AVG(max_intensity),4) AS average_max_intensity,
   ROUND(AVG(min_intensity),4) AS average_min_intensity
 FROM
   user_dow_summary
 GROUP BY
 part_of_week,
 dow_number,
 day_of_week,
 time_of_day)
SELECT
 *
FROM
 basic_summary
LEFT JOIN
 intensity_deciles
ON
 basic_summary.part_of_week = intensity_deciles.part_of_week AND
 basic_summary.day_of_week = intensity_deciles.day_of_week AND
 basic_summary.time_of_day = intensity_deciles.time_of_day
ORDER BY
dow_number,----Keep dow_number so when run order by, they will list correctly from Mon-Sun
BASIC_SUMMARY.part_of_week,
BASIC_SUMMARY.Time_of_day
;


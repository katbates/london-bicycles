-- SQL queries for london_bicycles public dataset on BigQuery

-- Station useage query: This query returns all stations with the total number of times they have been used, also broken down by their usage as a start or end station.

WITH starts AS (
  SELECT
      start_station_id,
      start_station_name,
      count(start_station_id) AS start_count
    FROM 
      `bigquery-public-data.london_bicycles.cycle_hire` 
    GROUP BY
      start_station_id,
      start_station_name
),
ends AS (
  SELECT
    end_station_id,
    count(end_station_id) AS end_count,
  FROM 
    `bigquery-public-data.london_bicycles.cycle_hire`
  GROUP BY
    end_station_id   
)

SELECT 
  starts.start_station_name AS station,
  starts.start_count,
  ends.end_count,
  SUM(ends.end_count + starts.start_count) AS total_count
FROM 
  starts
JOIN 
  ends
ON
  starts.start_station_id = ends.end_station_id
GROUP BY
  station,
  starts.start_count,
  ends.end_count
ORDER BY
  total_count DESC

-- Journeys query: This query returns all journeys taken with their frequency, distance (as the crow flies) and average duration. 

WITH end_locations AS (
  SELECT
    hires.rental_id AS rental_id,
    hires.end_station_name AS end_name,
    hires.end_station_id,
    stations.latitude AS end_lat,
    stations.longitude AS end_long,
    hires.duration AS duration
  FROM 
    `bigquery-public-data.london_bicycles.cycle_hire` AS hires
  INNER JOIN
    `bigquery-public-data.london_bicycles.cycle_stations` AS stations
  ON
    hires.end_station_id = stations.id
  GROUP BY
    rental_id,
    end_name,
    hires.end_station_id,
    stations.latitude,
    stations.longitude,
    duration
),
start_locations AS (
  SELECT
    rental_id,
    hires.start_station_id,
    hires.start_station_name AS start_name,
    stations.latitude AS start_lat,
    stations.longitude AS start_long
  FROM 
    `bigquery-public-data.london_bicycles.cycle_hire` AS hires
  INNER JOIN
    `bigquery-public-data.london_bicycles.cycle_stations` AS stations
  ON
    hires.start_station_id = stations.id
  GROUP BY
    rental_id,
    start_name,
    hires.start_station_id,
    stations.latitude,
    stations.longitude
)

SELECT
  CONCAT(s.start_name, ' to ', e.end_name) AS journey,
  COUNT(CONCAT(s.start_name, ' to ', e.end_name)) AS journey_count,
  ST_DISTANCE(
    ST_GEOGPOINT(s.start_long, s.start_lat),
    ST_GEOGPOINT(e.end_long, e.end_lat)
  ) AS distance_in_meters,
  AVG(duration) AS av_duration_s
FROM
  start_locations AS s
JOIN
  end_locations AS e
ON e.rental_id = s.rental_id
GROUP BY
  journey,
  distance_in_meters
ORDER BY
  journey_count DESC

-- Date query: This query returns number of trips and sum of duration grouped by minute, in preparation to analyse trends over time

SELECT
  start_date,
  count(rental_id) AS number_of_trips,
  SUM(duration) AS total_duration
FROM
  `bigquery-public-data.london_bicycles.cycle_hire`
GROUP BY
  start_date
ORDER BY
  start_date


-- Bike useage query: This query returns useage data for each bike in the dataset. The output includes the number of hours each bike has been used for over the whole period of data collection. It calculates the total possible amount of time using the difference between the start of the bikes first ride and end of their last ride. These values are used to calculate the amount of unused time and percentage of time the bike is used. One consideration is this methodology does not consider if the bike was taken out of operation for any period of time.

WITH hrs_used AS ( 
  SELECT
    bike_id,
    ROUND(SUM(duration) / 3600) AS total_used_hrs,
    EXTRACT(HOUR FROM(MAX(end_date) - MIN(start_date))) AS total_possible_hrs
  FROM
    `bigquery-public-data.london_bicycles.cycle_hire`
  GROUP BY
    bike_id
)

SELECT
  bike_id,
  total_used_hrs,
  total_possible_hrs,
  total_possible_hrs - total_used_hrs AS total_unused_hrs,
  ROUND((total_used_hrs / total_possible_hrs) * 100,2) AS percent_used
FROM
  hrs_used
WHERE
  total_possible_hrs <> 0
GROUP BY
  bike_id,
  total_used_hrs,
  total_possible_hrs,
  total_unused_hrs,
  percent_used

-- Lahman Baseball Database Exercise

/* 1. Find all players in the database who played at Vanderbilt University. 
Create a list showing each player's first and last names as well as the total salary 
they earned in the major leagues. Sort this list in descending order by the total salary earned. 
Which Vanderbilt player earned the most money in the majors? */

SELECT namefirst, namelast, SUM(salary) AS total_salary
FROM people
INNER JOIN salaries
USING (playerid)
WHERE playerid IN
	(SELECT playerid
	 FROM collegeplaying
	 WHERE schoolid = 'vandy')
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;
--David Price, $81,851,296.

/* 2. Using the fielding table, group players into three groups based on their position: 
label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" 
as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts 
made by each of these three groups in 2016. */

SELECT 
	CASE WHEN pos = 'OF' THEN 'Outfield'
	WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
	WHEN pos IN ('P', 'C') THEN 'Battery'
	END AS position_groups,
	SUM(po) AS total_putouts
FROM fielding
WHERE yearid = 2016
GROUP BY position_groups;
--"Battery"	41,424
--"Infield"	58,934
--"Outfield" 29,560

/* 3. Find the average number of strikeouts per game by decade since 1920. 
Round the numbers you report to 2 decimal places. Do the same for home runs per game. 
Do you see any trends? (Hint: For this question, you might find it helpful to look at the generate_series function 
(https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: 
https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6) */

WITH bins AS (
  SELECT generate_series(1920, 2010, 10) AS lower,
		 generate_series(1930, 2020, 10) AS upper
),
hr_so_by_year AS (
	SELECT
		yearid,
		SUM(so) AS total_year_so,
		SUM(hr) AS total_year_hr,
		MAX(g) * COUNT(teamid) AS total_year_games
	FROM teams
	GROUP BY yearid
	ORDER BY yearid
)
SELECT
	lower,
	upper,
	ROUND(SUM(total_year_so)/SUM(total_year_games) * 2::numeric,2) AS average_strikeouts_per_game,
	ROUND(SUM(total_year_hr)/SUM(total_year_games) * 2::numeric,2) AS average_homeruns_per_game
FROM bins
LEFT JOIN hr_so_by_year
ON yearid >= lower
AND yearid < upper
GROUP BY lower, upper
ORDER BY lower;
--Steady increases for both.

/* 4. Find the player who had the most success stealing bases in 2016, where success is measured as the percentage of stolen 
base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) 
Consider only players who attempted at least 20 stolen bases. Report the players' names, number of stolen bases, number of 
attempts, and stolen base percentage. */

SELECT 
	namefirst, 
	namelast,
	SUM(sb) AS total_bases_stolen,
	SUM(sb + cs) AS total_stealing_attempts,
	ROUND(SUM(sb)/SUM(sb + cs)::numeric * 100.0,2) AS stolen_base_percentage
FROM batting
INNER JOIN people
USING (playerid)
WHERE yearid = 2016
GROUP BY namefirst, namelast
HAVING SUM(sb) >= 20
ORDER BY stolen_base_percentage DESC;
--Chris Owings in 2016, 91.30%, though Billy Hamilton is is probably better, 58/66 or 87.88%.

/* 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? */ 

SELECT name, w
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
AND wswin = 'N'
ORDER BY w DESC
LIMIT 10;
-- Seattle Mariners with 116 wins.

/* What is the smallest number of wins for a team that did win the world series? 
Doing this will probably result in an unusually small number of wins for a world 
series champion; determine why this is the case. Then redo your query, excluding the problem year. */ 

SELECT name, w
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
AND wswin = 'Y'
ORDER BY w
LIMIT 10;
--LA Dodgers at 63 wins. Player's strike in 1981.

SELECT name, w
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
AND yearid <> 1981
AND wswin = 'Y'
ORDER BY w
LIMIT 10;
--St. Louis Cardinals with 83 wins.

/* How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time? */

WITH winner_wins AS (
	SELECT 
		yearid, 
		w AS winner_wins
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'Y' 
),
max_wins AS (
	SELECT 
		yearid, 
		MAX(w) AS max_wins
	FROM teams 
	WHERE yearid BETWEEN 1970 AND 2016
	GROUP BY yearid
)

SELECT TO_CHAR(ROUND(SUM(proportion_source)/COUNT(*)::numeric * 100,2),'fm00D00%')
FROM 
	(
	SELECT 
		CASE WHEN winner_wins = max_wins THEN 1
		ELSE 0
		END AS proportion_source
	FROM winner_wins
	INNER JOIN max_wins
	USING (yearid)
		) AS sq;
--~26.09% of the time.

/* 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? 
Give their full name and the teams that they were managing when they won the award. */

WITH nl AS (
	SELECT playerid, yearid, awardid, lgid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
	AND lgid = 'NL'
), 
al AS (
	SELECT playerid, yearid, awardid, lgid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
	AND lgid = 'AL'
),
awards AS (
(SELECT *
FROM nl
WHERE playerid IN (
	SELECT playerid
	FROM al))
UNION
(SELECT *
FROM al
WHERE playerid IN (
	SELECT playerid
	FROM nl
))
ORDER BY playerid
)
SELECT a.awardid, a.lgid, namefirst, namelast, a.yearid, t.name
FROM awards AS a
LEFT JOIN people AS p
USING (playerid)
LEFT JOIN salaries AS s
ON a.playerid = s.playerid
AND a.yearid = s.yearid
LEFT JOIN managers AS m
ON a.playerid = m.playerid
AND a.yearid = m.yearid
LEFT JOIN teams AS t
ON a.yearid = t.yearid
AND m.teamid = t.teamid;
--Jim Leyland and Davey Johnson.

/* 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 
10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting 
all stats for each player. */

WITH strikeouts AS (
	SELECT 
		playerid, 
		SUM(so) AS year_strikeouts
	FROM pitching
	WHERE yearid = 2016
	GROUP BY playerid
	HAVING SUM(gs) >= 10
)

SELECT
	namefirst,
	namelast,
	TO_CHAR(ROUND(salary::numeric/year_strikeouts,2),'l999,999,999D99') AS efficiency
FROM strikeouts
INNER JOIN people
USING (playerid)
INNER JOIN salaries
USING (playerid)
WHERE salaries.yearid = 2016
ORDER BY efficiency DESC;
--Matt Cain. Each strikeout of his cost $289,351.85.

/* 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year 
they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) 
Note that a player being inducted into the hall of fame is indicated by a 'Y' in the inducted column of the halloffame table. */

WITH career_hits AS (
	SELECT
		playerid,
		SUM(h) AS career_hits
	FROM batting
	GROUP BY playerid
	HAVING SUM(h) >= 3000
)

SELECT
	DISTINCT namefirst || ' ' || namelast AS name,
	career_hits,
	CASE WHEN inducted = 'Y' THEN hof.yearid
	ELSE NULL
	END AS hall_of_fame_induction
FROM career_hits
INNER JOIN people
USING (playerid)
LEFT JOIN
	(SELECT *
	FROM halloffame
	WHERE inducted = 'Y') AS hof
USING (playerid)
ORDER BY name;
-- Number of results.

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.

WITH just_players AS (
	SELECT playerid
	FROM 
		(
		SELECT playerid, teamid, SUM(h) AS team_hits
		FROM batting
		GROUP BY playerid, teamid
		HAVING SUM(h) >= 1000
	) AS sq
	GROUP BY playerid
	HAVING COUNT(DISTINCT teamid) > 1
)

SELECT namefirst, namelast
FROM just_players
INNER JOIN people
USING (playerid);
--Number of results.

/* 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played 
in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names 
and the number of home runs they hit in 2016. */

WITH max_hr AS (
	SELECT 
		playerid, 
		MAX(hr) AS max_homeruns
	FROM batting
	GROUP BY playerid
	HAVING MIN(yearid) <= 2006
), 
all_hr AS (
	SELECT
		playerid,
		hr
	FROM batting
	WHERE hr >= 1
	AND yearid = 2016
)

SELECT namefirst, namelast, max_hr.max_homeruns
FROM max_hr
INNER JOIN all_hr
ON max_hr.playerid = all_hr.playerid
AND max_hr.max_homeruns = all_hr.hr
INNER JOIN people
ON max_hr.playerid = people.playerid
ORDER BY max_homeruns DESC;
--Number of results.
---------------------------------------------------------------------------------------------------------------------------

-- Open-ended questions

/* 1. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. 
As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to 
look on a year-by-year basis. */

--QUESTION 1 QUERY

WITH total_salaries AS (
	SELECT
		yearid,
		teamid,
		SUM(salary) AS total_team_salary_that_year
	FROM salaries
	GROUP BY yearid, teamid
),
team_wins AS (
	SELECT
		yearid,
		teamid,
		w,
		name
	FROM teams
	WHERE yearid >= 2000
)

SELECT
	ts.yearid,
	total_team_salary_that_year,
	w,
	tw.name
FROM total_salaries AS ts
INNER JOIN team_wins AS tw
ON ts.yearid = tw.yearid
AND ts.teamid = tw.teamid
ORDER BY ts.yearid;

/* 2. In this question, you will explore the connection between number of wins and attendance. */

-- a. Does there appear to be any correlation between attendance at home games and number of wins?

--QUESTION 2A QUERY

WITH team_wins AS (
	SELECT
		yearid,
		teamid,
		w,
		name
	FROM teams
),
home_game_attendance AS (
SELECT 
	year,
	team,
	ROUND(SUM(attendance)/SUM(games)::numeric,2) AS attendance_per_home_game
FROM homegames
GROUP BY year, team
HAVING SUM(attendance)/SUM(games)::numeric > 0
ORDER BY year
)
SELECT
	year,
	name,
	w,
	attendance_per_home_game
FROM team_wins AS tw
INNER JOIN home_game_attendance AS hga
ON tw.yearid = hga.year
AND tw.teamid = hga.team;

/* b. Do teams that win the world series see a boost in attendance the following year? */

--QUESTION 2B1 QUERY

WITH team_ws_win AS (
	SELECT
		yearid,
		teamid,
		CASE WHEN wswin = 'Y' THEN 'World Series Winner'
		ELSE 'Not World Series Winner'
		END AS ws_win,
		name
	FROM teams
),
home_game_attendance AS (
	SELECT 
		year,
		team,
		LEAD(ROUND(SUM(attendance)/SUM(games)::numeric,2), 1) 
		OVER(PARTITION BY team ORDER BY year) - ROUND(SUM(attendance)/SUM(games)::numeric,2) AS attendance_boost
	FROM homegames
	GROUP BY year, team
	HAVING SUM(attendance)/SUM(games)::numeric > 0
	ORDER BY team
)
SELECT
	year,
	name,
	ws_win,
	attendance_boost
FROM team_ws_win AS tw
INNER JOIN home_game_attendance AS hga
ON tw.yearid = hga.year
AND tw.teamid = hga.team
WHERE ws_win = 'World Series Winner'
AND year <> 2016
ORDER BY year;

/*
What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner. */

--QUESTION 2B2 QUERY

WITH team_playoffs AS (
	SELECT
		yearid,
		teamid,
		CASE WHEN divwin = 'Y' OR wcwin = 'Y' THEN 'Playoffs'
		ELSE 'No Playoffs'
		END AS playoffs,
		name
	FROM teams
),
home_game_attendance AS (
	SELECT 
		year,
		team,
		LEAD(ROUND(SUM(attendance)/SUM(games)::numeric,2), 1) 
		OVER(PARTITION BY team ORDER BY year) - ROUND(SUM(attendance)/SUM(games)::numeric,2) AS attendance_boost
	FROM homegames
	GROUP BY year, team
	HAVING SUM(attendance)/SUM(games)::numeric > 0
	ORDER BY team
)
SELECT
	year,
	name,
	playoffs,
	attendance_boost
FROM team_playoffs AS tp
INNER JOIN home_game_attendance AS hga
ON tp.yearid = hga.year
AND tp.teamid = hga.team
WHERE playoffs = 'Playoffs'
AND year <> 2016
ORDER BY year;

/* 3. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, 
that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. */

--May do additional work on this one.

/* First, determine just how rare left-handed pitchers are compared with right-handed pitchers. */

--QUESTION 3.1 QUERY (No other code needed)

WITH lh_pitchers_only AS (
	SELECT
		DISTINCT playerid,
		CASE WHEN throws = 'L' THEN 1
		ELSE 0
		END AS left_hand_throwers
	FROM pitching
	INNER JOIN people
	USING (playerid)
)

SELECT TO_CHAR(ROUND(SUM(left_hand_throwers)/COUNT(*)::numeric * 100.0, 2),'fm00D00%')
FROM lh_pitchers_only;
--Only 26.63% of all pitchers are left-handed. So, not that rare.

/* Are left-handed pitchers more likely to win the Cy Young Award? */ 

--QUESTION 3.2 QUERY (No other code needed)

WITH throws_cy AS (
	SELECT 
		CASE WHEN throws IS NULL THEN 'Total'
		ELSE throws
		END AS throws,
		COUNT(throws) AS cy_by_hand
	FROM
		(
			SELECT
				DISTINCT playerid,
				throws
			FROM pitching
			INNER JOIN people
			USING (playerid)
			WHERE playerid IN 
				(
					SELECT playerid
					FROM awardsplayers
					WHERE awardid = 'Cy Young Award'
				)) AS sq
	GROUP BY ROLLUP(throws)
)

SELECT
	ROUND((SELECT cy_by_hand FROM throws_cy WHERE throws = 'R')/
	(SELECT cy_by_hand FROM throws_cy WHERE throws = 'Total')::numeric,2) AS right_hand_perc,
	ROUND((SELECT cy_by_hand FROM throws_cy WHERE throws = 'L')/
	(SELECT cy_by_hand FROM throws_cy WHERE throws = 'Total')::numeric,2) AS left_hand_perc
--Odds of left-handed pitchers winning the Cy Young Award are slightly higher than their proportion of pitchers at ~31%.

/* Are they more likely to make it into the hall of fame? */

--QUESTION 3.3 QUERY (No other code needed, for now)

WITH throws_hof AS (
	SELECT 
		CASE WHEN throws IS NULL THEN 'Total'
		ELSE throws
		END AS throws,
		COUNT(throws) AS hof_by_hand
	FROM
		(
			SELECT
				DISTINCT playerid,
				throws
			FROM pitching
			INNER JOIN people
			USING (playerid)
			WHERE playerid IN 
				(
					SELECT playerid
					FROM halloffame
					WHERE inducted = 'Y'
				)) AS sq
	GROUP BY ROLLUP(throws)
)

SELECT
	ROUND((SELECT hof_by_hand FROM throws_hof WHERE throws = 'R')/
	(SELECT hof_by_hand FROM throws_hof WHERE throws = 'Total')::numeric,2) AS right_hand_perc,
	ROUND((SELECT hof_by_hand FROM throws_hof WHERE throws = 'L')/
	(SELECT hof_by_hand FROM throws_hof WHERE throws = 'Total')::numeric,2) AS left_hand_perc
--Left-handed pitchers are less likely to be inducted into the Hall of Fame, at ~23%.

-------------------------------------------------------------------------------------------------------------------------------

/* In these exercises, you'll explore a couple of other advanced features of PostgreSQL. 

1. In this question, you'll get to practice correlated subqueries and learn about the LATERAL keyword. 
Note: This could be done using window functions, but we'll do it in a different way in order to revisit correlated 
subqueries and see another keyword - LATERAL. */

/* a. First, write a query utilizing a correlated subquery to find the team with the most wins from each league in 2016.

If you need a hint, you can structure your query as follows:

SELECT DISTINCT lgid, ( <Write a correlated subquery here that will pull the teamid for the team 
with the highest number of wins from each league> )
FROM teams t
WHERE yearid = 2016; */

SELECT
	DISTINCT lgid,
	(SELECT teamid
	 FROM teams AS t2
	 WHERE yearid = 2016
	 AND t2.lgid = t.lgid
	 AND w = (SELECT MAX(w) AS max_wins
				FROM teams AS t3
				WHERE t3.lgid = t.lgid
				AND yearid = 2016))
FROM teams AS t
WHERE yearid = 2016;

/* b. One downside to using correlated subqueries is that you can only return exactly one row and one column. 
This means, for example that if we wanted to pull in not just the teamid but also the number of wins, we couldn't 
do so using just a single subquery. (Try it and see the error you get). Add another correlated subquery to your 
query on the previous part so that your result shows not just the teamid but also the number of wins by that team. */

SELECT
	DISTINCT lgid,
	(SELECT teamid
	 FROM teams AS t2
	 WHERE yearid = 2016
	 AND t2.lgid = t.lgid
	 AND w = (SELECT MAX(w) AS max_wins
				FROM teams AS t3
				WHERE t3.lgid = t.lgid
				AND yearid = 2016)),
	(SELECT w
	 FROM teams AS t4
	 WHERE yearid = 2016
	 AND t4.lgid = t.lgid
	 AND w = (SELECT MAX(w) AS max_wins
			  FROM teams AS t5
			  WHERE t5.lgid = t.lgid
			  AND yearid = 2016))
FROM teams AS t
WHERE yearid = 2016;

/* c. If you are interested in pulling in the top (or bottom) values by group, you can also use the DISTINCT ON expression 
(https://www.postgresql.org/docs/9.5/sql-select.html#SQL-DISTINCT). Rewrite your previous query into one which uses 
DISTINCT ON to return the top team by league in terms of number of wins in 2016. Your query should return the league, 
the teamid, and the number of wins. */

SELECT DISTINCT ON (lgid) lgid, teamid, w
FROM teams AS t
WHERE yearid = 2016
ORDER BY lgid, w DESC;

/* d. If we want to pull in more than one column in our correlated subquery, another way to do it is to make use of 
the LATERAL keyword (https://www.postgresql.org/docs/9.4/queries-table-expressions.html#QUERIES-LATERAL). 
This allows you to write subqueries in FROM that make reference to columns from previous FROM items. 
This gives us the flexibility to pull in or calculate multiple columns or multiple rows (or both). 
Rewrite your previous query using the LATERAL keyword so that your result shows the teamid and 
number of wins for the team with the most wins from each league in 2016. 

If you want a hint, you can structure your query as follows:

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL ( <Fill in a subquery here to retrieve the teamid and number of wins> ) as top_teams; */
	  
SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL (SELECT teamid, w 
			   FROM teams
			   WHERE yearid = 2016
			   AND teams.lgid = leagues.lgid
			  ORDER BY w DESC
			  LIMIT 1) as top_teams;
	  
/* e. Finally, another advantage of the LATERAL keyword over using correlated subqueries is that you return multiple result 
rows. (Try to return more than one row in your correlated subquery from above and see what type of error you get). 
Rewrite your query on the previous problem set that it returns the top 3 teams from each league in term of number of wins. 
Show the teamid and number of wins.*/

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL (SELECT teamid, w 
			   FROM teams
			   WHERE yearid = 2016
			   AND teams.lgid = leagues.lgid
			  ORDER BY w DESC
			  LIMIT 3) as top_teams;

/* 2. Another advantage of lateral joins is for when you create calculated columns. 
In a regular query, when you create a calculated column, you cannot refer it it when you create other calculated columns. 
This is particularly useful if you want to reuse a calculated column multiple times. For example,

SELECT 
	teamid,
	w,
	l,
	w + l AS total_games,
	w*100.0 / total_games AS winning_pct
FROM teams
WHERE yearid = 2016
ORDER BY winning_pct DESC;

results in the error that "total_games" does not exist. However, I can restructure this query using the LATERAL keyword.

SELECT
	teamid,
	w,
	l,
	total_games,
	w*100.0 / total_games AS winning_pct
FROM teams t,
LATERAL (
	SELECT w + l AS total_games
) AS tg
WHERE yearid = 2016
ORDER BY winning_pct DESC; */

/* a. Write a query which, for each player in the player table, assembles their birthyear, birthmonth, and birthday 
into a single column called birthdate which is of the date type. */

SELECT TO_DATE(CONCAT(birthyear,TO_CHAR(birthmonth,'fm00'),TO_CHAR(birthday,'fm00')),'yyyymmdd') AS birthdate
FROM people;

/* b. Use your previous result inside a subquery using LATERAL 
to calculate for each player their age at debut and age at retirement. 
(Hint: It might be useful to check out the PostgreSQL date and time functions 
https://www.postgresql.org/docs/8.4/functions-datetime.html). */

DROP VIEW IF EXISTS age_table;

CREATE VIEW age_table AS
	SELECT
		namefirst,
		namelast,
		EXTRACT(YEAR FROM AGE(ages.debut, ages.birthdate)) AS debut_age,
		EXTRACT(YEAR FROM AGE(ages.retirement,ages.birthdate)) AS retirement_age
	FROM people AS p,
	LATERAL (
		SELECT 
			TO_DATE(CONCAT(birthyear,TO_CHAR(birthmonth,'fm00'),TO_CHAR(birthday,'fm00')),'YYYYMMDD') AS birthdate,
			TO_DATE(debut, 'YYYY-MM-DD') AS debut,
			TO_DATE(finalgame, 'YYYY-MM-DD') AS retirement
		WHERE TO_DATE(CONCAT(birthyear,TO_CHAR(birthmonth,'fm00'),TO_CHAR(birthday,'fm00')),'YYYYMMDD') <> '0001-01-01-BC'
	) AS ages;

-- c. Who is the youngest player to ever play in the major leagues?

SELECT namefirst, namelast, debut_age
FROM age_table
WHERE debut_age = (SELECT MIN(debut_age)
				  FROM age_table);
--Joe Nuxhall, 15 years old.

/* d. Who is the oldest player to player in the major leagues? You'll likely have a lot of null values resulting 
in your age at retirement calculation. Check out the documentation on sorting rows here 
https://www.postgresql.org/docs/8.3/queries-order.html about how you can change how null values are sorted. */

SELECT namefirst, namelast, retirement_age
FROM age_table
WHERE retirement_age = (SELECT MAX(retirement_age)
				  FROM age_table);
--Satchel Page, 59 years old.

/* 3. For this question, you will want to make use of RECURSIVE CTEs 
(see https://www.postgresql.org/docs/13/queries-with.html). The RECURSIVE keyword allows a CTE to refer to its own output. 
Recursive CTEs are useful for navigating network datasets such as social networks, logistics networks, or employee hierarchies 
(who manages who and who manages that person). To see an example of the last item, see this tutorial: 
https://www.postgresqltutorial.com/postgresql-recursive-query/. In the next couple of weeks, you'll see how the graph database Neo4j 
can easily work with such datasets, but for now we'll see how the RECURSIVE keyword can pull it off (in a much less efficient manner) 
in PostgreSQL. (Hint: You might find it useful to look at this blog post when attempting to answer the following questions: 
https://data36.com/kevin-bacon-game-recursive-sql/.) */

/* a. Willie Mays holds the record of the most All Star Game starts with 18. How many players started in an All Star Game 
with Willie Mays? (A player started an All Star Game if they appear in the allstarfull table with a non-null startingpos value). */

WITH RECURSIVE wmays_connections AS (
	SELECT 
		playerid, 
		gameid, 
		0 AS degrees_of_separation
	FROM allstarfull
	WHERE startingpos IS NOT NULL
	AND playerid = 'mayswi01'
	UNION ALL
	SELECT 
		asf.playerid,
		rc.gameid,
		rc.degrees_of_separation + 1
	FROM allstarfull AS asf
	INNER JOIN wmays_connections AS rc
	ON asf.gameid = rc.gameid
	WHERE startingpos IS NOT NULL
	AND rc.degrees_of_separation <= 1
) 
SELECT COUNT(DISTINCT playerid)
FROM wmays_connections
WHERE playerid <> 'mayswi01';
--125

/* b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game with another player 
who started an All Star Game with Willie Mays? For example, Graig Nettles never started an All Star Game with Willie Mayes, 
but he did star the 1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays. */

WITH RECURSIVE wmays_connections AS (
	SELECT 
		playerid, 
		gameid, 
		0 AS degrees_of_separation
	FROM allstarfull
	WHERE startingpos IS NOT NULL
	AND playerid = 'mayswi01'
	UNION ALL
	SELECT 
		asf.playerid,
		rc.gameid,
		rc.degrees_of_separation + 1
	FROM allstarfull AS asf
	INNER JOIN wmays_connections AS rc
	ON asf.gameid = rc.gameid
	WHERE startingpos IS NOT NULL
	AND rc.degrees_of_separation <= 5
) 
SELECT COUNT(DISTINCT playerid)
FROM wmays_connections
WHERE playerid <> 'mayswi01';

/* c. We'll call two players connected if they both started in the same All Star Game. Using this, we can find chains of players. 
For example, one chain from Carlton Fisk to Willie Mays is as follows: Carlton Fisk started in the 1973 All Star Game with Rod Carew 
who started in the 1972 All Star Game with Willie Mays. Find a chain of All Star starters connecting Babe Ruth to Willie Mays. */

/* d. How large a chain do you need to connect Derek Jeter to Willie Mays? */





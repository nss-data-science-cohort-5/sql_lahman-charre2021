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
--Chris Owings in 2016, at 91.30%, though Billy Hamilton is probably better, at 58/66 or 87.88% (more attempts).

SELECT 
	namefirst, 
	namelast,
	SUM(sb) AS total_bases_stolen,
	SUM(sb + cs) AS total_stealing_attempts,
	ROUND(SUM(sb)/SUM(sb + cs)::numeric * 100.0,2) AS stolen_base_percentage
FROM batting
INNER JOIN people
USING (playerid)
WHERE sb IS NOT NULL
AND cs IS NOT NULL
GROUP BY namefirst, namelast
HAVING SUM(sb) >= 20
ORDER BY total_bases_stolen DESC;

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

/* DROP VIEW IF EXISTS hey_now_youre_an_allstar;
CREATE VIEW player_names AS
	SELECT 
		namefirst || ' ' || namelast AS full_name, 
		gameid
	FROM people
	INNER JOIN allstarfull
	USING (playerid)
	WHERE startingpos IS NOT NULL; */

DROP VIEW IF EXISTS hey_now_youre_an_allstar;
CREATE VIEW hey_now_youre_an_allstar AS
	SELECT
		asf1.playerid AS player_who_played,
		asf1.gameid AS which_game,
		asf2.playerid AS played_with
	FROM allstarfull AS asf1
	INNER JOIN allstarfull AS asf2
	USING(gameid)
	WHERE asf1.playerid <> asf2.playerid
	AND asf1.startingpos IS NOT NULL
	AND asf2.startingpos IS NOT NULL;

SELECT COUNT(DISTINCT played_with)
FROM (
SELECT 
	player_who_played, 
	which_game, 
	played_with
FROM hey_now_youre_an_allstar
WHERE player_who_played = (SELECT playerid
						  FROM people
						  WHERE namefirst = 'Willie'
						  AND namelast = 'Mays')) AS sq;
--125

/* b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game with another player 
who started an All Star Game with Willie Mays? For example, Graig Nettles never started an All Star Game with Willie Mayes, 
but he did star the 1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays. */

WITH RECURSIVE wmays_connections AS (
	SELECT 
		player_who_played, 
		which_game, 
		played_with,
		0 AS degrees_of_separation
	FROM hey_now_youre_an_allstar
	WHERE player_who_played = (SELECT playerid
							   FROM people
							   WHERE namefirst = 'Willie'
							   AND namelast = 'Mays')
	UNION ALL
	SELECT 
		next_iteration.player_who_played,
		next_iteration.which_game,
		next_iteration.played_with,
		cte_output.degrees_of_separation + 1
	FROM hey_now_youre_an_allstar AS next_iteration
	INNER JOIN wmays_connections AS cte_output
	ON next_iteration.player_who_played = cte_output.played_with
	WHERE cte_output.degrees_of_separation < 1
) 
SELECT COUNT(DISTINCT played_with)
FROM wmays_connections
WHERE degrees_of_separation = 1
AND LOWER(played_with) NOT IN
(
	SELECT DISTINCT LOWER(played_with)
	FROM wmays_connections
	WHERE degrees_of_separation < 1
);
--218

/* c. We'll call two players connected if they both started in the same All Star Game. Using this, we can find chains of players. 
For example, one chain from Carlton Fisk to Willie Mays is as follows: Carlton Fisk started in the 1973 All Star Game with Rod Carew 
who started in the 1972 All Star Game with Willie Mays. Find a chain of All Star starters connecting Babe Ruth to Willie Mays. */

WITH RECURSIVE wmays_connections AS (
	SELECT 
		player_who_played, 
		which_game, 
		played_with,
		player_who_played || ' <<<< ' || which_game || ' <<<< ' || played_with AS route,
		0 AS degrees_of_separation
	FROM hey_now_youre_an_allstar
	WHERE player_who_played = (SELECT playerid
							   FROM people
							   WHERE namefirst = 'Willie'
							   AND namelast = 'Mays')
	UNION ALL
	SELECT 
		next_iteration.player_who_played,
		next_iteration.which_game,
		next_iteration.played_with,
		cte_output.route ||E'\n'|| 
	next_iteration.player_who_played || ' <<<< ' || 
	next_iteration.which_game || ' <<<< ' || 
	next_iteration.played_with AS route,
		cte_output.degrees_of_separation + 1
	FROM hey_now_youre_an_allstar AS next_iteration
	INNER JOIN wmays_connections AS cte_output
	ON next_iteration.player_who_played = cte_output.played_with
	WHERE cte_output.degrees_of_separation < 2
)
SELECT 
	p1.namefirst || ' ' || p1.namelast AS first_player_name,
	gameid,
	p2.namefirst || ' ' || p2.namelast AS second_player_name
FROM (
SELECT
	SPLIT_PART(separate_connections,' <<<< ', 1) AS first_player,
	SPLIT_PART(separate_connections,' <<<< ', 2) AS gameid,
	SPLIT_PART(separate_connections,' <<<< ', 3) AS second_player
FROM
	(
	SELECT 
		REGEXP_SPLIT_TO_TABLE(route, E'\n') AS separate_connections
	FROM
		(	
		SELECT route
		FROM wmays_connections
		WHERE route LIKE '%' || (SELECT playerid
								 FROM people
								 WHERE namefirst = 'Willie'
								 AND namelast = 'Mays') || '%'
		AND route LIKE '%' || (SELECT playerid
							   FROM people
							   WHERE namefirst = 'Babe'
							   AND namelast = 'Ruth') ||'%'
		LIMIT 1
		) AS sq1
	) AS sq2
) AS sq3
INNER JOIN people AS p1
ON first_player = p1.playerid
INNER JOIN people AS p2
ON second_player = p2.playerid;
/* "Willie Mays"	"NLS195707090"	"Ted Williams"
"Ted Williams"	"NLS194007090"	"Joe Medwick"
"Joe Medwick"	"NLS193407100"	"Babe Ruth" */

/* d. How large a chain do you need to connect Derek Jeter to Willie Mays? */

WITH RECURSIVE wmays_connections AS (
	SELECT 
		player_who_played, 
		which_game, 
		played_with,
		player_who_played || ' <<<< ' || which_game || ' <<<< ' || played_with AS route,
		0 AS degrees_of_separation
	FROM hey_now_youre_an_allstar
	WHERE player_who_played = (SELECT playerid
							   FROM people
							   WHERE namefirst = 'Willie'
							   AND namelast = 'Mays')
	UNION ALL
	SELECT 
		next_iteration.player_who_played,
		next_iteration.which_game,
		next_iteration.played_with,
		cte_output.route ||E'\n'|| 
	next_iteration.player_who_played || ' <<<< ' || 
	next_iteration.which_game || ' <<<< ' || 
	next_iteration.played_with AS route,
		cte_output.degrees_of_separation + 1
	FROM hey_now_youre_an_allstar AS next_iteration
	INNER JOIN wmays_connections AS cte_output
	ON next_iteration.player_who_played = cte_output.played_with
	WHERE cte_output.degrees_of_separation < 3
)
SELECT 
	p1.namefirst || ' ' || p1.namelast AS first_player_name,
	gameid,
	p2.namefirst || ' ' || p2.namelast AS second_player_name
FROM (
SELECT
	SPLIT_PART(separate_connections,' <<<< ', 1) AS first_player,
	SPLIT_PART(separate_connections,' <<<< ', 2) AS gameid,
	SPLIT_PART(separate_connections,' <<<< ', 3) AS second_player
FROM
	(
	SELECT 
		REGEXP_SPLIT_TO_TABLE(route, E'\n') AS separate_connections
	FROM
		(	
		SELECT route
		FROM wmays_connections
		WHERE route LIKE '%' || (SELECT playerid
								 FROM people
								 WHERE namefirst = 'Willie'
								 AND namelast = 'Mays') || '%'
		AND route LIKE '%' || (SELECT playerid
							   FROM people
							   WHERE namefirst = 'Derek'
							   AND namelast = 'Jeter') ||'%'
		LIMIT 1
		) AS sq1
	) AS sq2
) AS sq3
INNER JOIN people AS p1
ON first_player = p1.playerid
INNER JOIN people AS p2
ON second_player = p2.playerid;
/* "Willie Mays"	"NLS197207250"	"Reggie Jackson"
"Reggie Jackson"	"NLS198407100"	"Darryl Strawberry"
"Darryl Strawberry"	"NLS198607150"	"Roger Clemens"
"Roger Clemens"	"NLS200407130"	"Derek Jeter",
So, 4 degrees of separation */

--See if there's a way to find the level at which Derek Jeter appears programmatically.

----------------------------------------------------------------------------------------------------------------------------
--WINDOW FUNCTION EXERCISES

-- Question 1: Rankings

-- Question 1a: Warmup Question

/* Write a query which retrieves each teamid and number of wins (w) for the 2016 season. 
Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. 
Compare the output from these three functions. What do you notice? */

-- ROW_NUMBER

SELECT
	teamid,
	w,
	ROW_NUMBER() OVER(ORDER BY w DESC)
FROM teams
WHERE yearid = 2016;
-- Continuous incrementation.

--RANK
SELECT
	teamid,
	w,
	RANK() OVER(ORDER BY w DESC)
FROM teams
WHERE yearid = 2016;
--Skips subsequent ranks based on number of ties.

--DENSE_RANK
SELECT
	teamid,
	w,
	DENSE_RANK() OVER(ORDER BY w DESC)
FROM teams
WHERE yearid = 2016;
--Does not skip subsequent ranks based on ties.

-- Question 1b: 

/* Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? 
A team's division is indicated by the divid column in the teams table. */

SELECT
	teamid,
	COUNT(teamid) AS bottom_count
FROM
	(
	SELECT
		teamid,
		name,
		yearid,
		divid,
		w,
		RANK() OVER(PARTITION BY yearid, divid, lgid ORDER BY w) AS least_wins_by_division_and_year
	FROM teams
	WHERE divid IS NOT NULL
	) AS sq
WHERE least_wins_by_division_and_year = 1
GROUP BY teamid
ORDER BY bottom_count DESC;
--San Diego Padres, 18.

-- Question 2: Cumulative Sums

-- Question 2a: 

/* Barry Bonds has the record for the highest career home runs, with 762. Write a query which returns, 
for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. 
(Barry Bonds' playerid is bondsba01.) */

SELECT
	DENSE_RANK() OVER(ORDER BY yearid) AS seasons_played,
	SUM(hr) OVER(ORDER BY yearid) AS career_home_runs
FROM batting
WHERE playerid = 'bondsba01';
-- 22 seasons, 762 home runs (as noted above).

-- Question 2b:

/* How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? For this question, we will 
consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of 
seasons into his career. */

WITH bonds_data AS (
	SELECT
		playerid AS bonds,
		yearid AS bonds_career_year,
		DENSE_RANK() OVER(ORDER BY yearid) AS seasons_played,
		SUM(hr) OVER(ORDER BY yearid) AS career_home_runs
	FROM batting
	WHERE playerid = 'bondsba01'
),
other_player_data AS (
	SELECT
		other_player,
		other_player_year,
		other_player_seasons_played,
		other_player_career_home_runs
	FROM (
		SELECT
			playerid AS other_player,
			yearid AS other_player_year,
			MAX(yearid) OVER(PARTITION BY playerid) AS other_player_last_data_year,
			DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid) AS other_player_seasons_played,
			SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid) AS other_player_career_home_runs
		FROM batting
		) AS sq
	WHERE other_player_last_data_year = 2016
)
SELECT COUNT(*)
FROM 
	(
	SELECT
		bonds,
		other_player,
		CASE WHEN other_player_career_home_runs >= career_home_runs THEN 'Y'
		WHEN other_player_career_home_runs < career_home_runs THEN 'N'
		END AS beat_bonds
	FROM other_player_data
	INNER JOIN bonds_data
	ON seasons_played = other_player_seasons_played
	WHERE other_player_year = 2016
		) AS sq
WHERE beat_bonds = 'Y';
--22

-- Question 2c: 

/* Were there any players who 20 years into their career who had hit more home runs at that point into their career 
than Barry Bonds had hit 20 years into his career? */

WITH bonds_data AS (
	SELECT
		playerid AS bonds,
		yearid AS bonds_career_year,
		DENSE_RANK() OVER(ORDER BY yearid) AS seasons_played,
		SUM(hr) OVER(ORDER BY yearid) AS career_home_runs
	FROM batting
	WHERE playerid = 'bondsba01'
),
other_player_data AS (
	SELECT
		other_player,
		other_player_year,
		other_player_seasons_played,
		other_player_career_home_runs
	FROM (
		SELECT
			playerid AS other_player,
			yearid AS other_player_year,
			MAX(yearid) OVER(PARTITION BY playerid) AS other_player_last_data_year,
			DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid) AS other_player_seasons_played,
			SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid) AS other_player_career_home_runs
		FROM batting
		) AS sq
	WHERE other_player_last_data_year = 2016
)
SELECT
	bonds,
	other_player,
	other_player_career_home_runs,
	career_home_runs
FROM other_player_data
INNER JOIN bonds_data
ON seasons_played = other_player_seasons_played
WHERE seasons_played = 20
AND other_player_seasons_played = 20;
--No

-- Question 3: Anomalous Seasons

/* Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has 
the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider 
the 5-year window centered at that year (the window should include that year, the two years prior and the two years after). */

WITH anomalous_years AS (
	SELECT
		playerid,
		yearid,
		hr,
		ABS(hr - ROUND(AVG(hr::numeric) OVER(PARTITION BY playerid ORDER BY 
										yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING),2)) AS absolute_difference
	FROM batting
)

SELECT
	namefirst,
	namelast,
	yearid,
	hr,
	absolute_difference
FROM anomalous_years
INNER JOIN people
USING (playerid)
ORDER BY absolute_difference DESC
LIMIT 1;
-- Hank Greenberg in 1936, with only 1 home run that year.



-- Question 4: Players Playing for one Team

-- For this question, we'll just consider players that appear in the batting table.

-- Question 4a: 

/* Warmup: How many players played at least 10 years in the league and played for exactly one team? 
(For this question, exclude any players who played in the 2016 season). */

SELECT COUNT(*)
FROM (
	SELECT
		COUNT(DISTINCT playerid)
	FROM
		(
		SELECT 
			playerid,
			yearid,
			teamid,
			DENSE_RANK() OVER(PARTITION BY playerid, teamid ORDER BY yearid) AS years_played_with_a_team
		FROM batting
		WHERE playerid NOT IN
			(
				SELECT playerid
				FROM batting
				WHERE yearid = 2016
			)
		ORDER BY playerid, yearid
			) AS sq
	WHERE years_played_with_a_team >= 10
	GROUP BY playerid
	HAVING COUNT(DISTINCT teamid) = 1) AS sq2;
-- 761 players.

/* Who had the longest career with a single team? 
(You can probably answer this question without needing to use a window function.) */

SELECT
	namefirst,
	namelast,
	teamid,
	years_played_with_a_team
FROM people
INNER JOIN
	(
	SELECT 
		playerid,
		yearid,
		teamid,
		DENSE_RANK() OVER(PARTITION BY playerid, teamid ORDER BY yearid) AS years_played_with_a_team
	FROM batting
	WHERE playerid NOT IN
			(
				SELECT playerid
				FROM batting
				WHERE yearid = 2016
			)
	ORDER BY playerid, yearid
		) AS sq
USING (playerid)
ORDER BY years_played_with_a_team DESC
LIMIT 1;
--Robinson Brooks played with the Baltimore Orioles for 23 years.

-- Question 4b: 

/* Some players start and end their careers with the same team but play for other teams in between. 
For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants 
for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at 
least 10 years in the league and start and end their careers with the same team but played for at least one 
other team during their career? For this question, exclude any players who played in the 2016 season. */

--first solution
WITH years_playing_with_teams AS (
	SELECT 
		playerid,
		yearid,
		teamid,
		DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid) AS years_played,
		FIRST_VALUE(teamid) 
	OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_team,
		LAST_VALUE(teamid) 
	OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_team
	FROM batting
	WHERE playerid NOT IN
				(
					SELECT playerid
					FROM batting
					WHERE yearid = 2016
				)
	ORDER BY playerid, yearid
),
first_solution AS (
SELECT COUNT(DISTINCT playerid)
FROM years_playing_with_teams
WHERE first_team = last_team
AND playerid IN
	(SELECT playerid
	FROM batting
	GROUP BY playerid
	HAVING COUNT(DISTINCT teamid) > 1)
AND years_played >= 10
),
--192 players from first solution
years_playing AS (
	SELECT 
		playerid,
		yearid,
		teamid,
		MIN(yearid) OVER(PARTITION BY playerid) AS first_year,
		MAX(yearid) OVER(PARTITION BY playerid) AS last_year
	FROM batting
	WHERE playerid NOT IN
				(
					SELECT playerid
					FROM batting
					WHERE yearid = 2016
				)
	AND playerid IN
				(
					SELECT playerid
					FROM batting
					GROUP BY playerid
					HAVING COUNT(DISTINCT yearid) >= 10
					AND COUNT(DISTINCT teamid) > 1	
				)
	ORDER BY playerid, yearid
),
first_team AS (
	SELECT
		playerid,
		teamid AS first_team
	FROM years_playing
	WHERE yearid = first_year
),
last_team AS (
	SELECT
		playerid,
		teamid AS last_team
	FROM years_playing
	WHERE yearid = last_year
),
first_and_last_years_and_teams AS (
	SELECT
		years_playing.playerid,
		yearid,
		teamid,
		first_year,
		first_team,
		last_year,
		last_team
	FROM years_playing
	INNER JOIN last_team
	USING (playerid)
	INNER JOIN first_team
	USING (playerid)
),
second_solution AS (
SELECT *
FROM first_and_last_years_and_teams
WHERE first_team = last_team
)

SELECT *
FROM second_solution
WHERE playerid NOT IN 
	(SELECT playerid
	FROM first_solution);
--233 players from second solution

/* The second solution includes playerids where the last year of that player's career, 
that player split the season between different teams. */

-- Question 5: Streaks

-- Question 5a: 

-- How many times did a team win the World Series in consecutive years?

SELECT 
	COUNT(*)
FROM (
	SELECT 
		teamid, 
		yearid, 
		wswin,
		LAG(teamid) OVER(ORDER BY yearid) AS last_years_winner
	FROM teams
	WHERE wswin = 'Y'
	ORDER BY yearid) AS sq
WHERE teamid = last_years_winner;
--22 times.

-- Question 5b: 

/* What is the longest streak of a team winning the World Series? Write a query that produces this result rather 
than scanning the output of your previous answer. */

SELECT
	teams.name,
	consecutive_win_streak
FROM
	(
	SELECT
		teamid,
		yearid,
		last_years_winner,
		teamid_group,
		SUM(1) OVER(PARTITION BY teamid, teamid_group) + 1 AS consecutive_win_streak
	FROM (
		SELECT
			teamid,
			yearid,
			last_years_winner,
			SUM(CASE WHEN teamid = last_years_winner THEN 0 ELSE 1 END) 
			OVER(PARTITION BY teamid ORDER BY yearid) AS teamid_group
		FROM
			(
			SELECT 
				teamid, 
				yearid, 
				wswin,
				LAG(teamid) OVER(ORDER BY yearid) AS last_years_winner
			FROM teams
			WHERE wswin = 'Y'
			ORDER BY yearid) AS sq
		ORDER BY yearid) AS sq2
	WHERE teamid = last_years_winner) AS sq3
INNER JOIN teams
USING (teamid)
ORDER BY consecutive_win_streak DESC
LIMIT 1;
--New York Highlanders with 5 consecutive World Series wins.

-- Question 5c: 

/* A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. 
Which team has the longest streak of making the playoffs? */

WITH initial_playoffs AS (
	SELECT
		teamid,
		yearid,
		CASE WHEN (divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y') THEN 'Y'
		-- Added for Question 5d
		-- WHEN yearid = 1994 THEN 'Y'
		ELSE 'N'
		END AS playoffs_that_year
	FROM teams
	ORDER BY teamid, yearid
),
adding_last_year AS (
	SELECT
		teamid,
		yearid,
		playoffs_that_year,
		COALESCE(LAG(playoffs_that_year) OVER(PARTITION BY teamid ORDER BY yearid),'N') AS playoffs_last_year
	FROM initial_playoffs
),
adding_in_team_groups AS (
	SELECT 
		teamid,
		yearid,
		playoffs_that_year,
		playoffs_last_year,
		SUM(CASE WHEN playoffs_that_year = playoffs_last_year THEN 0 ELSE 1 END) 
		OVER(PARTITION BY teamid ORDER BY yearid) AS teamid_group
	FROM adding_last_year
),
summing_consecutives AS (
	SELECT 
		teamid,
		yearid,
		playoffs_that_year,
		playoffs_last_year,
		teamid_group,
		SUM(1) OVER(PARTITION BY teamid, teamid_group) + 1 AS consecutive_playoffs_streak
	FROM adding_in_team_groups
	WHERE playoffs_that_year = playoffs_last_year
	AND playoffs_last_year = 'Y'
	ORDER BY teamid, yearid
)
SELECT 
	teams.name,
	summing_consecutives.yearid,
	consecutive_playoffs_streak
FROM summing_consecutives
INNER JOIN teams
USING (teamid)
ORDER BY consecutive_playoffs_streak DESC, summing_consecutives.yearid DESC
LIMIT 1;
--5c New York Highlanders with 13 consecutive playoffs appearances ending on 2007.

-- Question 5d: 

/* The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, 
does this change your answer for the previous part? */

--Yes, to the Atlanta Braves with 15 consecutive playoffs appearances ending on 2005.

-- Question 6: Manager Effectiveness

/* Which manager had the most positive effect on a team's winning percentage? 
To determine this, calculate the average winning percentage in the three years before the manager's first full 
season and compare it to the average winning percentage for that manager's 2nd through 4th full season. 
Consider only managers who managed at least 4 full years at the new team and teams that had been in existence 
for at least 3 years prior to the manager's first full season. */

WITH team_winning_perc AS (
	SELECT
		teamid AS team_id,
		yearid AS team_year,
		ROUND(w/g::numeric,2) AS team_winning_perc,
		g AS team_games,
		MIN(yearid) OVER(PARTITION BY teamid) AS first_team_year
	FROM teams
	ORDER BY teamid, yearid
),

managers_winning_perc AS (
	SELECT
		managers.playerid AS manager_id,
		managers.teamid AS manager_team,
		managers.yearid AS manager_year,
		ROUND(managers.w/managers.g::numeric,2) AS manager_winning_perc,
		COUNT(managers.teamid) OVER(PARTITION BY managers.playerid, managers.teamid) AS team_season_count,
		MIN(managers.yearid) OVER(PARTITION BY managers.playerid, managers.teamid) AS managers_first_year_with_team
	FROM managers
	INNER JOIN teams
	ON managers.teamid = teams.teamid
	AND managers.yearid = teams.yearid
	WHERE managers.g >= teams.g * 0.9
	AND inseason = 1
	ORDER BY managers.playerid, managers.yearid
),

managers_and_teams AS (
	SELECT
		manager_id,
		manager_team,
		manager_year,
		manager_winning_perc,
		team_year,
		team_winning_perc,
		managers_first_year_with_team
	FROM managers_winning_perc
	FULL JOIN team_winning_perc
	ON manager_team = team_id
	WHERE team_season_count >= 4
	AND managers_first_year_with_team - first_team_year >= 3
	AND team_year BETWEEN managers_first_year_with_team - 3 AND managers_first_year_with_team - 1
	AND manager_year BETWEEN managers_first_year_with_team AND managers_first_year_with_team + 3
	ORDER BY manager_team, manager_year, team_year
),

combine_columns AS (
	(SELECT
		manager_id,
		manager_team AS team,
		manager_year AS year,
		manager_winning_perc AS winning_perc,
		managers_first_year_with_team
	FROM managers_and_teams)
	UNION
	(SELECT
		manager_id,
		manager_team,
		team_year,
		team_winning_perc,
		managers_first_year_with_team
	FROM managers_and_teams)
	ORDER BY manager_id, team, year
),

adding_in_averages AS (
SELECT
	manager_id,
	team,
	year,
	managers_first_year_with_team,
	ROUND(AVG(winning_perc) 
		  OVER(PARTITION BY manager_id ORDER BY year ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING), 2) AS pre_manager_winning_perc,
	ROUND(AVG(winning_perc) 
		  OVER(PARTITION BY manager_id ORDER BY year ROWS BETWEEN 1 FOLLOWING AND 3 FOLLOWING), 2) AS manager_winning_perc
FROM combine_columns
)

SELECT
	namefirst,
	namelast,
	team,
	year,
	manager_winning_perc - pre_manager_winning_perc AS manager_boost
FROM adding_in_averages
INNER JOIN people
ON manager_id = playerid
WHERE year = managers_first_year_with_team
ORDER BY manager_boost DESC
LIMIT 100;
-- John McGraw, starting with the New York Giants in 1903, at a 0.28 winning percentage point improvement.

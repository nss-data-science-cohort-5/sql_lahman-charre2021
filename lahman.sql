-- Lahman Baseball Database Exercise

/* 1. Find all players in the database who played at Vanderbilt University. 
Create a list showing each player's first and last names as well as the total salary 
they earned in the major leagues. Sort this list in descending order by the total salary earned. 
Which Vanderbilt player earned the most money in the majors? */

SELECT namefirst, namelast, SUM(salary) AS total_salary
FROM people
INNER JOIN collegeplaying
USING (playerid)
INNER JOIN salaries
USING (playerid)
WHERE schoolid = 'vandy'
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;
--David Price, $245,553,888.

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

--Check this one again.

WITH bins AS (
  SELECT generate_series(1920, 2010, 10) AS lower,
		 generate_series(1930, 2020, 10) AS upper
)
SELECT
	lower,
	upper,
	ROUND(AVG(so),2) AS average_strikeouts_per_game,
	ROUND(AVG(hr),2) AS average_homeruns_per_game
FROM bins
LEFT JOIN batting
ON yearid >= lower
AND yearid < upper
GROUP BY lower, upper
ORDER BY lower;
--Both have been relatively steady since the 60's, with slight increases in both recently.

--Check this one again.

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
INNER JOIN halloffame AS hof
USING (playerid)
ORDER BY hall_of_fame_induction;
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

/* 2. In this question, you will explore the connection between number of wins and attendance.

-- a. Does there appear to be any correlation between attendance at home games and number of wins?


/* b. Do teams that win the world series see a boost in attendance the following year? 
What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner. */

/* 3. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, 
that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, 
determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely 
to win the Cy Young Award? Are they more likely to make it into the hall of fame? */


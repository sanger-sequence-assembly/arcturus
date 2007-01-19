DELIMITER $

DROP PROCEDURE IF EXISTS procProjectSummaryByNameLike$

CREATE PROCEDURE procProjectSummaryByNameLike(IN minContigSize INT, IN projectName VARCHAR(30))
  READS SQL DATA
  SQL SECURITY INVOKER
BEGIN
  select PROJECT.name, count(*) as contigs,
    sum(nreads) as nreads, sum(length) as length,
    round(avg(length)) as avglen, round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where length >= minContigSize and name REGEXP projectName
  group by CURRENTCONTIGS.project_id order by name asc;
END;$

DELIMITER ;

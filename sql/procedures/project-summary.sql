DELIMITER $

DROP PROCEDURE IF EXISTS procProjectSummary$

CREATE PROCEDURE procProjectSummary(IN minContigSize INT)
  READS SQL DATA
  SQL SECURITY INVOKER
BEGIN
  select PROJECT.name, count(*) as contigs,
    sum(nreads) as nreads, sum(length) as length,
    round(avg(length)) as avglen, round(std(length)) as stdlen,
    max(length) as maxlen,
    max(CURRENTCONTIGS.created) as newestcontig,
    max(CURRENTCONTIGS.updated) as lastcontigupdate,
    PROJECT.updated as projectupdated
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where length >= minContigSize
  group by CURRENTCONTIGS.project_id order by name asc;
END;$

DELIMITER ;

-- Copyright (c) 2001-2014 Genome Research Ltd.
--
-- Authors: David Harper
--          Ed Zuiderwijk
--          Kate Taylor
--
-- This file is part of Arcturus.
--
-- Arcturus is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program. If not, see <http://www.gnu.org/licenses/>.

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

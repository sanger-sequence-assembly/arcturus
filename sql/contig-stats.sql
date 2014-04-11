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

select 'ALL CONTIGS';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as `reads`,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  group by CURRENTCONTIGS.project_id order by name asc;

select 'CONTIGS 2kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as `reads`,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where length >= 2000
  group by CURRENTCONTIGS.project_id order by name asc;

select 'CONTIGS 5kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as `reads`,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where length >= 5000
  group by CURRENTCONTIGS.project_id order by name asc;

select 'CONTIGS 10kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as `reads`,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where length >= 10000
  group by CURRENTCONTIGS.project_id order by name asc;

select 'CONTIGS 100kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as `reads`,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where length >= 100000
  group by CURRENTCONTIGS.project_id order by name asc;

select 'CONTIGS WITH 3 OR MORE READS';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as `reads`,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from CURRENTCONTIGS left join PROJECT using(project_id)
  where nreads > 2
  group by CURRENTCONTIGS.project_id order by name asc;

select 'CONTIG STATS BY MONTH';

select year(created) as year, month(created) as month, count(*) as contigs,
  sum(nreads) as `reads`, sum(length) as consensus
  from CURRENTCONTIGS
  group by year, month
  order by year asc, month asc;

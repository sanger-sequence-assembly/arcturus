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

drop temporary table if exists readrange;

create temporary table readrange
	(seq_id int primary key, rs int, rf int);

select count(*) as segments
	from MAPPING left join SEGMENT using(mapping_id)
	where contig_id = @contig_id;

insert into readrange(seq_id,rs,rf)
	select seq_id,min(SEGMENT.rstart),max(SEGMENT.rstart+length-1)
	from MAPPING left join SEGMENT using(mapping_id)
	where contig_id = @contig_id and direction = 'Forward' group by seq_id;

insert into readrange(seq_id,rs,rf)
	select seq_id,min(SEGMENT.rstart-length+1),max(SEGMENT.rstart)
	from MAPPING left join SEGMENT using(mapping_id)
	where contig_id = @contig_id and direction = 'Reverse' group by seq_id;

select contig_id,length,nreads,CONTIG.created,CONTIG.updated,PROJECT.name
	from CONTIG left join PROJECT using(project_id)
	where contig_id = @contig_id;

select count(*) as reads,max(rf-qright),avg(rf-qright),std(rf-qright)
	from readrange left join QUALITYCLIP using(seq_id)
	where qright is not null and rf > qright;

select count(*) as reads,max(qleft-rs),avg(qleft-rs),std(qleft-rs)
	from readrange left join QUALITYCLIP using(seq_id)
	where qleft is not null and rs < qleft;

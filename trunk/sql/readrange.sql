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

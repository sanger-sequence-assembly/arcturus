create temporary table currentcontigs as
	select CONTIG.contig_id,nreads,ncntgs,length,created,updated,project_id
	from CONTIG left join C2CMAPPING
	on CONTIG.contig_id = C2CMAPPING.parent_id
	where C2CMAPPING.parent_id is null;

create temporary table curseqs (
	seq_id mediumint unsigned not null,
	contig_id mediumint unsigned not null,
	index(contig_id),
	index(seq_id));

insert into curseqs(seq_id,contig_id)
	select seq_id,MAPPING.contig_id from currentcontigs left join MAPPING using(contig_id);

create temporary table curreads (
	read_id mediumint unsigned not null,
	seq_id mediumint unsigned not null,
	contig_id mediumint unsigned not null,
	index(read_id));

insert into curreads(read_id,seq_id,contig_id)
	select read_id,SEQ2READ.seq_id,contig_id from curseqs left join SEQ2READ using(seq_id);

create temporary table badreads as
	select read_id,count(*) as hits from curreads group by read_id having hits > 1;

select * from badreads;

create temporary table oldc2cmapping (
	contig_id mediumint unsigned not null,
	parent_id mediumint unsigned not null,
	 index (parent_id),
	 index (contig_id));

insert into oldc2cmapping(parent_id,contig_id)
	 select C2CMAPPING.contig_id,parent_id
	 from C2CMAPPING left join CONTIG using(contig_id)
	 where created < @cutoff;

create temporary table oldcontigs as
select CONTIG.contig_id,nreads,ncntgs,length,created,updated,project_id
  from CONTIG left join oldc2cmapping
  on CONTIG.contig_id = oldc2cmapping.parent_id
  where oldc2cmapping.parent_id is null and created < @cutoff;

create temporary table currentcontigs (
  contig_id mediumint unsigned not null,
  gap4name binary(32) not null,
  nreads mediumint unsigned not null,
  ncntgs mediumint unsigned not null,
  length mediumint unsigned not null,
  created datetime not null,
  updated datetime not null,
  project_id int unsigned not null,
  primary key (contig_id),
  key (gap4name),
  key (project_id)
);

insert into currentcontigs(contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id)
select CONTIG.contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id
  from CONTIG left join C2CMAPPING
  on CONTIG.contig_id = C2CMAPPING.parent_id
  where C2CMAPPING.parent_id is null;

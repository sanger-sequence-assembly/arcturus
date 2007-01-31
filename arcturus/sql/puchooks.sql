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
	unique key (gap4name)
);

insert into currentcontigs(contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id)
	select CONTIG.contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id
	from CONTIG left join C2CMAPPING
	on CONTIG.contig_id = C2CMAPPING.parent_id
	where C2CMAPPING.parent_id is null;

create temporary table hooks1 as
	select currentcontigs.contig_id,seq_id,cfinish as pos,'L' as end
	from currentcontigs left join MAPPING using(contig_id)
	where cfinish < 4000 and direction = 'Reverse';

insert into hooks1(contig_id,seq_id,pos,end)
	select currentcontigs.contig_id,seq_id,length - cstart,'R'
	from currentcontigs left join MAPPING using(contig_id)
	where cstart > length - 4000 and direction = 'Forward';

create temporary table hooks2 as
	select contig_id,read_id,pos,end
	from hooks1 left join SEQ2READ using(seq_id);

drop temporary table hooks1;

create temporary table hooks as
	select contig_id,hooks2.read_id,strand,READINFO.template_id,sihigh,pos,end
	from hooks2,READINFO,TEMPLATE,LIGATION
	where hooks2.read_id = READINFO.read_id
		and READINFO.template_id = TEMPLATE.template_id
		and TEMPLATE.ligation_id = LIGATION.ligation_id;

drop temporary table hooks2;

delete from hooks where pos > sihigh;

create temporary table pucbridges as
	select template_id,count(*) as hits
	from hooks
	group by template_id
	having hits > 1;

create temporary table currentcontigs as
select CONTIG.contig_id,nreads,ncntgs,length,updated,created,project_id
  from CONTIG left join C2CMAPPING
  on CONTIG.contig_id = C2CMAPPING.parent_id
  where C2CMAPPING.parent_id is null;

select 'ALL CONTIGS';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as reads,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from currentcontigs left join PROJECT using(project_id)
  group by currentcontigs.project_id order by name asc;

select 'CONTIGS 2kb OR MORE';
                                                                                                                                             
select PROJECT.name,count(*) as contigs,
  sum(nreads) as reads,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from currentcontigs left join PROJECT using(project_id)
  where length >= 2000
  group by currentcontigs.project_id order by name asc;

select 'CONTIGS 5kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as reads,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from currentcontigs left join PROJECT using(project_id)
  where length >= 5000
  group by currentcontigs.project_id order by name asc;

select 'CONTIGS 10kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as reads,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from currentcontigs left join PROJECT using(project_id)
  where length >= 10000
  group by currentcontigs.project_id order by name asc;

select 'CONTIGS 100kb OR MORE';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as reads,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from currentcontigs left join PROJECT using(project_id)
  where length >= 100000
  group by currentcontigs.project_id order by name asc;

select 'CONTIGS WITH 3 OR MORE READINFO';

select PROJECT.name,count(*) as contigs,
  sum(nreads) as reads,
  sum(length) as length,
  round(avg(length)) as avglen,
  round(std(length)) as stdlen,
  max(length) as maxlen
  from currentcontigs left join PROJECT using(project_id)
  where nreads > 2
  group by currentcontigs.project_id order by name asc;

select 'CONTIG STATS BY MONTH';

select year(created) as year, month(created) as month, count(*) as contigs,
  sum(nreads) as reads, sum(length) as consensus
  from currentcontigs
  group by year, month
  order by year asc, month asc;

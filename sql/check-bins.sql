-- check-bins.sql to find discrepancy between OligoFinder.java and the free reads overnight job populate-organism-history.pl
SELECT 'READS IN PROJECTS TRASH, FREEASSEMBLY and BIN' AS ' ';
select 
	sum(C.nreads)
	from CONTIG as C,PROJECT as P  
	where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now() and CA.nreads > 1 and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or CB.created > now()))
    and P.name in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id; 

SELECT 'READS IN PROJECTS TRASH, FREEASSEMBLY and BIN' AS ' ';
select 
	sum(C.nreads)
	from CONTIG as C,PROJECT as P  
	where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now() and CA.nreads > 1 and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or CB.created > now()))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id; 

SELECT 'READS IN ALL CONTIGS' AS ' ';
select sum(nreads) from CONTIG;

SELECT 'READS IN CURRENT CONTIGS' AS ' ';
select sum(nreads) from CURRENTCONTIGS;

SELECT 'READS IN READ TABLE' AS ' ';
select count(*) from READINFO;

-- check-bins.sql to find discrepancy between OligoFinder.java and the free reads overnight job populate-organism-history.pl
select 
	sum(C.nreads) as 'READS IN CONTIGS WITH MORE THAN 1 READ IN PROJECTS TRASH, FREEASSEMBLY and BIN'
	from CONTIG as C,PROJECT as P  
	where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now() and CA.nreads > 1 and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or CB.created > now()))
    and P.name in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id; 

select 
	sum(C.nreads) 'READS IN CONTIGS WITH MORE THAN 1 READ IN PROJECTS TRASH, FREEASSEMBLY and BIN'
	from CONTIG as C,PROJECT as P  
	where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now() and CA.nreads > 1 and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or CB.created > now()))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id; 

select 
	sum(C.nreads) 'READS IN CONTIGS IN ANY PROJECT'
	from CONTIG as C
	where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now() and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or CB.created > now()));

select sum(nreads)  as 'READS IN CURRENT CONTIGS' from CURRENTCONTIGS;

select sum(nreads) as 'READS IN ALL CONTIGS' from CONTIG;

select count(*)  'READS IN READ TABLE' from READINFO;

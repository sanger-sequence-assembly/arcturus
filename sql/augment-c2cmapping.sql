alter table C2CMAPPING add column pstart int unsigned after cfinish;
alter table C2CMAPPING add column pfinish int unsigned after pstart;

create temporary table pstartforward as
	select contig_id,parent_id,min(C2CSEGMENT.pstart) as pstart
	from C2CMAPPING left join C2CSEGMENT using(mapping_id)
	where direction = 'Forward' group by contig_id,parent_id;

create temporary table pstartreverse as
	select contig_id,parent_id,min(C2CSEGMENT.pstart-length+1) as pstart
	from C2CMAPPING left join C2CSEGMENT using(mapping_id)
	where direction = 'Reverse' group by contig_id,parent_id;

create temporary table pfinishforward as
	select contig_id,parent_id,max(C2CSEGMENT.pstart+length-1) as pstart
	from C2CMAPPING left join C2CSEGMENT using(mapping_id)
	where direction = 'Forward' group by contig_id,parent_id;

create temporary table pfinishreverse as
	select contig_id,parent_id,max(C2CSEGMENT.pstart) as pstart
	from C2CMAPPING left join C2CSEGMENT using(mapping_id)
	where direction = 'Reverse' group by contig_id,parent_id;

update C2CMAPPING,pstartforward
	set C2CMAPPING.pstart = pstartforward.pstart
	where C2CMAPPING.contig_id = pstartforward.contig_id
	and C2CMAPPING.parent_id = pstartforward.parent_id;

update C2CMAPPING,pstartreverse
	set C2CMAPPING.pstart = pstartreverse.pstart
	where C2CMAPPING.contig_id = pstartreverse.contig_id
	and C2CMAPPING.parent_id = pstartreverse.parent_id;

update C2CMAPPING,pfinishforward
	set C2CMAPPING.pfinish = pfinishforward.pstart
	where C2CMAPPING.contig_id = pfinishforward.contig_id
	and C2CMAPPING.parent_id = pfinishforward.parent_id;

update C2CMAPPING,pfinishreverse
	set C2CMAPPING.pfinish = pfinishreverse.pstart
	where C2CMAPPING.contig_id = pfinishreverse.contig_id
	and C2CMAPPING.parent_id = pfinishreverse.parent_id;

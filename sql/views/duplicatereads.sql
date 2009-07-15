drop view if exists DUPLICATEREADS;

create
  sql security invoker
view DUPLICATEREADS as
  select read_id,count(*) as hits
  from (CURRENTCONTIGS left join (MAPPING left join SEQ2READ using (seq_id)) using(contig_id))
  group by read_id having hits > 1;

create temporary table CURCTG as
  select CONTIG.contig_id from CONTIG left join C2CMAPPING
  on CONTIG.contig_id = C2CMAPPING.parent_id
  where C2CMAPPING.parent_id is null;

create temporary table CURSEQ
  (seq_id integer not null, contig_id integer not null, key (contig_id)) as
  select seq_id,CURCTG.contig_id from CURCTG left join MAPPING using(contig_id);

create temporary table CURREAD
  (read_id integer not null, seq_id integer not null, contig_id integer not null, key (read_id)) as
  select read_id,SEQ2READ.seq_id,contig_id from CURSEQ left join SEQ2READ using(seq_id);

create temporary table FREEREAD as
  select READINFO.read_id from READINFO left join CURREAD using(read_id)
  where seq_id is null;

-- DDL for new canonical sequence-to-contig mappings

drop table if exists CANON_SEGMENT;

drop table if exists SEQ2CONTIG;

drop table if exists CANON_MAPPING;

create table CANON_MAPPING (
  mapping_id mediumint unsigned not null auto_increment primary key,
  cspan int not null,
  rspan int not null,
  checksum binary(16) not null,

  unique key(checksum(8))
) engine=InnoDB;

create table SEQ2CONTIG (
  contig_id mediumint unsigned not null,
  seq_id mediumint unsigned not null,
  mapping_id mediumint unsigned not null,
  coffset int not null,
  roffset int not null,
  direction enum('Forward','Reverse') NOT NULL default 'Forward',

  unique key (contig_id, seq_id),
  key (seq_id),
  key (mapping_id),

  constraint foreign key (contig_id) references CONTIG (contig_id)
    on delete cascade,
  constraint foreign key (seq_id) references SEQUENCE (seq_id)
    on delete restrict,
  constraint foreign key (mapping_id) references CANON_MAPPING (mapping_id)
    on delete restrict
) engine =InnoDB;

create table CANON_SEGMENT (
  mapping_id mediumint unsigned not null,
  cstart int not null,
  rstart int not null,
  length int not null,

  key (mapping_id),

  constraint foreign key (mapping_id) references CANON_MAPPING (mapping_id)
    on delete cascade
) engine=InnoDB;

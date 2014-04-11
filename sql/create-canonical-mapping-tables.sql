-- Copyright (c) 2001-2014 Genome Research Ltd.
--
-- Authors: David Harper
--          Ed Zuiderwijk
--          Kate Taylor
--
-- This file is part of Arcturus.
--
-- Arcturus is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program. If not, see <http://www.gnu.org/licenses/>.

-- DDL for new canonical sequence-to-contig mappings

create table if not exists CANONICALMAPPING (
  mapping_id mediumint unsigned not null auto_increment primary key,
  cspan int not null,
  rspan int not null,
  checksum binary(16) not null,

  unique key(checksum(8))
) engine=InnoDB;

create table if not exists SEQ2CONTIG (
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
  constraint foreign key (mapping_id) references CANONICALMAPPING (mapping_id)
    on delete restrict
) engine =InnoDB;

create table if not exists CANONICALSEGMENT (
  mapping_id mediumint unsigned not null,
  cstart int not null,
  rstart int not null,
  length int not null,

  key (mapping_id),

  constraint foreign key (mapping_id) references CANONICALMAPPING (mapping_id)
    on delete cascade
) engine=InnoDB;

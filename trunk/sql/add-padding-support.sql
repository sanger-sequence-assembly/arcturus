alter table CONSENSUS
  add column `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

update CONSENSUS CS,CONTIG C
  set CS.updated=C.updated where CS.contig_id=C.contig_id;

CREATE TABLE `CONTIGPADDING` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `pad_list_id` int(11) NOT NULL AUTO_INCREMENT,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `contig_id` (`contig_id`),
  UNIQUE KEY `pad_list_id` (`pad_list_id`),
  constraint foreign key (contig_id)
    references CONTIG(contig_id) on delete cascade
) ENGINE=InnoDB;

CREATE TABLE `PAD` (
  `pad_list_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  UNIQUE KEY `pad_list_id` (`pad_list_id`,`position`),
  constraint foreign key (pad_list_id)
    references CONTIGPADDING(pad_list_id) on delete cascade
) ENGINE=InnoDB;

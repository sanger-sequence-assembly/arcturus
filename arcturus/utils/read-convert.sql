# This MySQL script modifies an Arcturus READS table.
#
# Author: David Harper <adh@sanger.ac.uk>
#
select '[1] Move the DNA sequence and base quality data to a separate table' as COMMENT;

select 'Create the new table' as COMMENT;
create table SEQUENCE select read_id, sequence, quality from READS;

select 'Make read_id the primary key' as COMMENT;
alter table SEQUENCE add primary key(read_id);

select 'Remove the corresponding columns from READS' as COMMENT;
alter table READS drop column sequence, drop column quality;

select '[2] Move the comments to a separate table' as COMMENT;

select 'Create the new table' as COMMENT;
create table READCOMMENT select read_id, comment from READS where comment is not null;

select 'Make read_id the primary key' as COMMENT;
alter table READCOMMENT add primary key(read_id);

select 'Remove the corresponding column from READS' as COMMENT;
alter table READS drop column comment;

select '[3] Create a new dictionary table for the templates' as COMMENT;

select 'Create the new table' as COMMENT;
create table TEMPLATE select distinct template from READS;

select 'Rename the template name column' as COMMENT;
alter table TEMPLATE change template name char(24) binary;

select 'Add a unique ID column' as COMMENT;
alter table TEMPLATE add column (template_id mediumint unsigned not null auto_increment,
                                 primary key(template_id));

select 'Add a corresponding template ID column to the READS table' as COMMENT;
alter table READS add column (template_id mediumint unsigned);

select 'Map the template ID from the TEMPLATE table to each read in the READS table' as COMMENT;
update READS,TEMPLATE set READS.template_id=TEMPLATE.template_id
   where READS.template=TEMPLATE.name;

select 'Make the template ID column an index of the READS table, since we shall be making regular use of this column to find read pairs' as COMMENT;
alter table READS add index(template_id);

select 'Verify that everything is okay. If this query returns any rows, then there are problems' as COMMENT;
select READS.template_id,READS.template,TEMPLATE.template_id,TEMPLATE.name
  from TEMPLATE left join READS using(template_id)
  where READS.template != TEMPLATE.name;

select 'Remove the template column from the READS table' as COMMENT;
alter table READS drop template;

select 'Change the readname column to fixed width' as COMMENT;
alter table READS modify readname char(32) binary;

select 'Finally, optimise the READS table' as COMMENT;
optimize table READS;

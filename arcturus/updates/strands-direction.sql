alter table STRANDS add column direction enum('forward','reverse','unknown')
default 'unknown'

update STRANDS set direction='forward' where description like '%forward%'

update STRANDS set direction='reverse' where description like '%reverse%'

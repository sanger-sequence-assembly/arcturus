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

select CA.contig_id,PA.name,CA.nreads,CA.length,CA.created,CB.contig_id,PB.name,CB.nreads,CB.length,CB.created
   from CONTIG as CA left join (C2CMAPPING M,CONTIG as CB, PROJECT PA,PROJECT PB)
   on (CA.contig_id = M.parent_id and M.contig_id = CB.contig_id)
   where CA.created < '2009-08-21'
   and (M.parent_id is null or CB.created > '2009-08-21')
   and CA.project_id=PA.project_id
   and CB.project_id=PB.project_id
   and PA.name like 'BIG2P_'
   order by PA.name asc,CA.length desc,CB.length desc
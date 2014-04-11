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

DROP VIEW IF EXISTS CURRENTCONTIGS;

CREATE
  SQL SECURITY INVOKER
  VIEW CURRENTCONTIGS
  AS SELECT CONTIG.contig_id,gap4name,nreads,ncntgs,length,created,updated,project_id
  FROM CONTIG LEFT JOIN C2CMAPPING
  ON CONTIG.contig_id = C2CMAPPING.parent_id
  WHERE C2CMAPPING.parent_id IS NULL and nreads > 0;

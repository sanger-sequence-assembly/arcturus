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

# This is an initialisation script for a new MySQL instance. It plugs
# various security holes which the mysql_install_db script leaves open,
# then creates a set of users for the Arcturus system.

# Switch to the access-control database
USE mysql;

# Get rid of the "anonymous" user
DELETE FROM user WHERE user != 'root';

# Create a new root account
GRANT ALL ON *.* TO root@'%' IDENTIFIED BY 'SAO100944' WITH GRANT OPTION;

# Remove all root accounts which have no password
DELETE FROM user WHERE password='';

# Force the access-control tables to be updated
FLUSH PRIVILEGES;

# The following four users have special privileges

# The client for the mysqlping monitoring tool
GRANT PROCESS ON *.* TO ping@'%';

# The client for server shutdown
GRANT SHUTDOWN ON *.* TO terminator@"%" IDENTIFIED BY "hasta la vista baby";

# The client for master/slave replication
GRANT FILE ON *.* TO slave@"%" IDENTIFIED BY "spartacus";

# The client for binlog flushing and rotation
GRANT RELOAD ON *.* TO flusher@"%" IDENTIFIED BY "FlushedWithPride";

# This is the first real user
GRANT ALL ON *.* TO arcturus@"%" IDENTIFIED BY "***REMOVED***";

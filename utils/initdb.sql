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

#!/bin/sh

echo MASTER

mysql -h mcs3a -P 15001 -u monitor --password=WhoWatchesTheWatchers \
    -e 'show master status'

echo SLAVE1

mysql -h mcs1a -P 15002 -u monitor --password=WhoWatchesTheWatchers \
    -e 'show slave status\G'

echo SLAVE2

mysql -h mcs2a -P 15002 -u monitor --password=WhoWatchesTheWatchers \
    -e 'show slave status\G'

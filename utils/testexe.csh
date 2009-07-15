#!/bin/csh

# This mimics (more or less) the environment of a CGI
# script on the Arcturus server


setenv PERL5LIB /nfs/pathsoft/arcturus/dev/lib:/usr/local/badger/bin
setenv MYSQL_TCP_PORT 14642
setenv ORACLE_HOME /usr/local/oracle

setenv PATH /nfs/pathsoft/external/mysql-3.23.49-bugfix/bin:/usr/apps/bin:/nfs/team81/adh/bin:/bin:/usr/bin:/usr/etc:/usr/bin/X11:/usr/openwin/bin:/opt/sfw/bin:/usr/local/bin:/usr/local/badger/bin:/usr/local/lsf/bin:/usr/bsd:/usr/dt/bin:/nfs/disk100/grail/conf:/nfs/disk100/grail/modules/servers:/nfs/disk100/grail/modules/SOCKLSRV:/usr/local/oracle/bin:/usr/local/badger/staden/alpha-bin:/usr/local/badger/staden/seqlibs-alpha-bin:/usr/local/badger/staden/bin:/usr/local/badger/gelminder/bin:/nfs/disk54/badger/packages/finish/fc/bin:/usr/local/badger/consed/bin:/usr/local/pubseq/bin:/usr/local/pubseq/scripts:/nfs/disk100/pubseq/emboss/bin:/nfs/disk222/yeastpub/zoo/general:/nfs/team81/adh/bin/alpha:/nfs/team81/adh/bin:/nfs/pathdb/dev/external/mysql-3.23.38

setenv REQUEST_METHOD GET
setenv QUERY_STRING $<
exec $1

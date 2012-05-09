# Makefile for MySQL client programs

MYSQL_HOME = /nfs/pathsoft/external/mysql-3.23.51

MYSQL_INCLUDE = $(MYSQL_HOME)/include/mysql
MYSQL_LIB = $(MYSQL_HOME)/lib/mysql

CC = gcc

CFLAGS = $(DEBUG) -I$(MYSQL_INCLUDE) -DINCLUDE_EDITRES_SUPPORT
LIBDIRS = -L$(MYSQL_LIB)
LDLIBS = -lXm -lXmu -lXt -lX11 -lmysqlclient -lm

mysqlping: mysqlping.o
	$(CC) -o $@ $(LIBDIRS) mysqlping.o $(LDLIBS)

clean:
	/bin/rm -f mysqlping mysqlping.o

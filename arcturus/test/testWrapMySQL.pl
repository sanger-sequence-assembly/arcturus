#!/usr/local/bin/perl

use WrapMySQL;

$inifile = shift;

WrapMySQL->initFromFile($inifile);

print "Enumerating instances and roles ...\n\n";

@dbs = WrapMySQL->listInstances();

foreach $db (@dbs) {
    printf "%-15s", $db;
    @modes = WrapMySQL->listRolesForInstance($db);
    foreach $mode (@modes) {
	printf " %-8s", $mode;
    }
    print "\n";
}

$savefile = shift || "$inifile.new";

WrapMySQL->addInstance('TABBYCAT', {'host' => 'pcs3',
				    'port' => 14641,
				    'database' => 'dinah'});

WrapMySQL->addRoleToInstance('TABBYCAT', 'read', 'dinah', 'miaow');
WrapMySQL->addRoleToInstance('TABBYCAT', 'write', 'molly', 'yowl');

WrapMySQL->setDatabase('TABBYCAT', 'dinahmatic');

$tabbyport = WrapMySQL->getPort('TABBYCAT');

print "Port for TABBYCAT is $tabbyport\n";

($u, $p) = WrapMySQL->getRole('TABBYCAT', 'read');

print "Read role for TABBYCAT is $u,$p\n";

WrapMySQL->saveToFile($savefile);

exit(0);

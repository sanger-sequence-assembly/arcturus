package ArcturusDatabase::ADBAssembly;

use strict;

use ArcturusDatabase::ADBProject;

our @ISA = qw(ArcturusDatabase::ADBProject);

use ArcturusDatabase::ADBRoot qw(queryFailed);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

sub getAssemblyDataforReadName { # TO BE TESTED
# return project data keyed on contig_id for input readname
    my $this = shift;
    my $readname = shift;

    my $contig_items = "CONTIG.contig_id,gap4name,CONTIG.created";
    my $projectitems = "PROJECT.name,PROJECT.owner,assembly_id";

    my $query = "select distinct $contig_items,$projectitems"
              . "  from READS,SEQ2READ,MAPPING,CONTIG,PROJECT"
              . " where CONTIG.project_id = PROJECT.project_id"
              . "   and CONTIG.contig_id = MAPPING.contig_id"
              . "   and MAPPING.seq_id = SEQ2READ.seq_id"
              . "   and SEQ2READ.read_id = READS.read_id"
	      . "   and READS.readname = ?"
	      . " order by contig_id DESC";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($readname) || &queryFailed($query,$readname);

    my $resultlist = {};
    while (my ($contig_id,@items) = $sth->fetchrow_array()) {
        $resultlist->{$contig_id} = [@items];
    }

    $sth->finish();

    return $resultlist;
}

#------------------------------------------------------------------------------
# methods dealing with Projects 
#------------------------------------------------------------------------------

sub aborttest {

    &queryFailed("TEST ABORT on ArcturusDatabase");
    exit;

}

#------------------------------------------------------------------------------

1;

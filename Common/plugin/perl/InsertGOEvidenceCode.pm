#######################################################################
##                 InsertGOEvidenceCode.pm
##
## Creates a new entry in table SRes.GOEvidenceCode to represent
## a new GO evidence code in GUS
## $Id: InsertGOEvidenceCode.pm 3032 2005-06-24 17:36:15Z msaffitz $
##
#######################################################################
 
package GUS::Common::Plugin::InsertGOEvidenceCode;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Model::SRes::GOEvidenceCode;

my $argsDeclaration = 
  [
   stringArg({name => 'name',
	      descr => 'Synonym of the GO Evidence Code to be inserted',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name=> 'description',
	      descr => 'description of the GO Evidence Code',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     })
  ];

my $purposeBrief = <<PURPOSEBRIEF;
Creates a new entry in table SRes.GOEvideceCode to represent a new GO evidence code in GUS.
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Simple plugin that is the easiest way to create a row representing a new GO evidence code in GUS.  This entry should map the GO evidence codes from http://cvs.sourceforge.net/viewcvs.py/obo/obo/ontology/evidence_code.obo into GUS.  Protects against making multiple entries in GUS for a GO evidence code that already exists there (see notes below).
PLUGIN_PURPOSE

my $tablesAffected = 
	[['SRes.GOEvidenceCode', 'The entry representing the new evidence code is created here']];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
Only one row is created, so if the plugin fails, restart by running it again with the same parameters (accounting for any errors that may have caused the failure.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
If the entry already exists, based on the --name flag and a corresponding name in the table, then the plugin does not submit a new row.  This is not a failure case per se, but will result in no change to the database where one might have been expected.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
The way the plugin checks to make sure there is not already an entry representing this evidence code is by case-insensitive matching against the name.  There is a chance, however, that the user could load a duplicate entry, representing the same evidence code, but with different names, because of a misspelling or alternate naming convention.  This cannot be guarded against, so it is up to the user to avoid duplicate entries when possible.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => {},
		       cvsRevision => '$Revision: 3035 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
    my $self = shift;
    my $evidCode = $self->getArg('name');
    my $description = $self->getArg('description');
    my $msg;

    my $sql = "select name from sres.goevidencecode where lower(name) like '" . lc($evidCode) ."'";
    my $dbh = $self->getDb()->getDbHandle();
    my $sth = $dbh->prepareAndExecute($sql);
    my ($evidCodeId) = $sth->fetchrow_array();

    if ($evidCodeId){
	$msg = "Not creating a new entry for $evidCode as one already exists in the database (id $evidCodeId)";
    }

    else {
	my $newEvidCode = GUS::Model::SRes::GOEvidenceCode->new({
	    name => $evidCode,
	    description => $description
	   });
	$newEvidCode->submit();
	my $newEvidCodePk = $newEvidCode->getId();
	$msg = "created new entry for evidence code $evidCode with primary key $newEvidCodePk";
    }

    return $msg;
}

1;

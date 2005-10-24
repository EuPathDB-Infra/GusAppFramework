#######################################################################
##                 InsertECMapping.pm
##
## Creates new entries in the table DoTS.AASequenceEnzymeClass to represent
## the EC mappings found in a tab delimited file of the form EC number, alias
## $Id$
##
#######################################################################
 
package GUS::Community::Plugin::InsertECMapping;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::SRes::EnzymeClass;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::GeneFeature;
#use GUS::Model::DoTS::NAFeatureNaGene;
use GUS::Model::DoTS::NAGene;


my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in table DoTS.AASequenceEnzymeClass to represent new aa sequence/enzyme class associations.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file of the order EC number, identifier, and creates new entries in table DoTS.AASequenceEnzymeClass to represent new aa sequence/enzyme class associations.
PLUGIN_PURPOSE

my $tablesAffected =
	[['DoTS.AASequenceEnzymeClass', 'The entries representing the new aa_sequence/enzyme class mappings are created here']];

my $tablesDependedOn = [['SRes::EnzymeClass','The EC Numbers from the EC mapping file must have entries in this table to be considered legitimate'],['DoTS::TranslatedAAFeature','The sequences mapped to EC Numbers by the EC mapping file must have entries in this table'],['DoTS::GeneFeature','This table may contain the source ID that will be used to map from the Pfid provided by the mapping file to the entry in DoTS::TranslatedAAFeature'],['DoTS::NAFeatureNaGene','If DoTS::GeneFeature does not contain the Pfid from the mapping file as a source ID, we will need to use this table to check synonyms so that we can map the Pfid to the entry in DoTS::TranslatedAAFeature'],['DoTS::NAGene','If DoTS::GeneFeature does not contain the Pfid from the mapping file as a source ID, we will need to check this table for synonyms so that we can map the Pfid to the entry in DoTS::TranslatedAAFeature']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };


my $argsDeclaration = 
  [
   fileArg({name => 'ECMappingFile',
	  descr => 'pathname for the file containing the EC mapping data',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'Two column tab delimited file in the order EC number, identifier'
        }),
   stringArg({name => 'evidenceCode',
	      descr => 'the evidence code with which data should be entered into the AASequenceEnzymeClass table',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     })
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);


    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 3912 $', # cvs fills this in!
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
  my ($self) = @_;
  my $mappingFile = $self->getArg('ECMappingFile');

  my $msg = $self->getMapping($mappingFile);

  return $msg;
}

sub getMapping {
  my ($self, $mappingFile) = @_;
  my %ecNumbers = ();
  my %ids = ();
  my $enzymeClass;
  my $aaSeqId;
  my $evidCode = $self->getArg('evidenceCode');

  open (ECMAP, "$mappingFile") ||
                    die ("Can't open the file $mappingFile.  Reason: $!\n");

$self->log("The pairs found in the file are:\n");

    while (<ECMAP>) {
	chomp;

	my ($locusTag, $ecNumber) = split('\t', $_);

	if (!$ecNumber || !$locusTag){
	  next;
	}

	$self->log("Processed Pfid: $locusTag, ECNumber: $ecNumber\n");

	if ($ecNumbers{$ecNumber}){
	  $enzymeClass = $ecNumbers{$ecNumber};
	}
	else {
	  $enzymeClass = $self->getEnzymeClass($ecNumber, \%ecNumbers);
	}

	if ($ids{$locusTag}){
	  $aaSeqId = $ids{$locusTag};
	}
	else {
	  $aaSeqId = $self->getAASeqId($locusTag, \%ids);
	}

	my $newAASeqEnzClass =  GUS::Model::DoTS::AASequenceEnzymeClass->new({
					    'aa_sequence_id' => $aaSeqId,
					    'enzyme_class_id' => $enzymeClass,
					    'evidence_code' => $evidCode
	});

	unless (!$enzymeClass || !$aaSeqId){
	  $self->log("submitted enzyme $enzymeClass, seq $aaSeqId\n");
	  $newAASeqEnzClass->submit();
	}
      }

  my $msg = "parsed EC Mapping file\n";

  return $msg;
}

###### FETCH THE EC ID FOR A GIVEN EC NUMBER ######

sub getEnzymeClass {
  my ($self, $ecNumber, $ecHash) = @_;

  my $newEnzymeClass =  GUS::Model::SRes::EnzymeClass->new({
	'ec_number' => $ecNumber
	});

  $newEnzymeClass->retrieveFromDB();
  my $enzymeClass = $newEnzymeClass->getId();

$self->log("Enzyme Class = $enzymeClass\n");

$$ecHash{$ecNumber} = $enzymeClass;

return $enzymeClass;
}

###### FETCH THE AA SEQUNCE ID FOR A GIVEN ALIAS ######

sub getAASeqId {
  my ($self, $locusTag, $aaIdHash) = @_;

my $sql = "select s.aa_sequence_id from DoTS.TranslatedAAFeature s, (SELECT distinct na_feature_id FROM dots.transcript WHERE (LOWER(source_id) LIKE LOWER(REPLACE(REPLACE('$locusTag','',''), '*', '%')) OR na_feature_id IN (SELECT na_feature_id FROM dots.naFeatureNaGene fg, dots.naGene g WHERE LOWER(g.name) LIKE LOWER(REPLACE(REPLACE('$locusTag',' ',''), '*', '%')) AND g.na_gene_id = fg.na_gene_id))) t where t.na_feature_id = s.na_feature_id";

    my $queryHandle = $self->getQueryHandle();
    my $sth = $queryHandle->prepareAndExecute($sql);

    my $aaSequenceId = $sth->fetchrow_array();
    $sth->finish();

$self->log("my aaSeqId = $aaSequenceId\n");

$$aaIdHash{$locusTag} = $aaSequenceId;

return $aaSequenceId;

}


1;

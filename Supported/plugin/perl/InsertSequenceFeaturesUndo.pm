package GUS::Supported::Plugin::InsertSequenceFeaturesUndo;

# todo:
#  - handle seqVersion more robustly
#  - add logging info
#  - undo

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use Bio::SeqIO;
use Bio::Tools::SeqStats;
use Bio::Tools::GFF;
use Bio::SeqFeature::Tools::Unflattener;

use GUS::PluginMgr::Plugin;
use GUS::Supported::BioperlFeatMapperSet;
use GUS::Supported::SequenceIterator;

my $purpose = <<PURPOSE;
Undo one or more runs of GUS::Supported::Plugin::InsertSequenceFeatures.  Uses the algorithm_invocation_id to find the data to remove (find this the log of the plugin run).

If the ISF plugin mapping file uses special case handlers, their undoAll() method is called as part of the undo process.   They are called in the order the handlers are declared in the mapping file.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Undo one or more runs of GUS::Supported::Plugin::InsertSequenceFeatures.
PURPOSEBRIEF

  my $notes = <<NOTES;

NOTES

  my $tablesAffected =
  [
   ['SRes.Reference', ''],
   ['SRes.SequenceOntology', ''],
   ['DoTS.SequenceType', ''],
   ['DoTS.NASequence', ''],
   ['DoTS.ExternalNASequence', ''],
   ['DoTS.VirtualSequence', ''],
   ['DoTS.Assembly', ''],
   ['DoTS.SplicedNASequence', ''],
   ['DoTS.NAEntry', ''],
   ['DoTS.SecondaryAccs', ''],
   ['DoTS.NALocation', ''],
   ['DoTS.NASequenceRef', ''],
   ['DoTS.Keyword', ''],
   ['DoTS.NAComment', ''],
   ['DoTS.TranslatedAAFeature', ''],
   ['DoTS.TranslatedAASequence', ''],
   ['DoTS.NAGene', ''],
   ['DoTS.NAProtein', ''],
   ['SRes.DbRef', ''],
   ['DoTS.NAFeatureComment', ''],
   ['DoTS.NASequenceKeyword', ''],
   ['DoTS.NAFeatureNAGene', ''],
   ['DoTS.NAFeatureNAProtein', ''],
   ['DoTS.DbRefNAFeature', ''],
  ];


  my $tablesDependedOn = 
  [
   ['SRes.TaxonName', ''],
   ['SRes.SequenceOntology', ''],
   ['SRes.ExternalDatabase', ''],
   ['SRes.ExternalDatabaseRelease', ''],
  ];

  my $howToRestart = <<RESTART;
No restart
RESTART

  my $failureCases = <<FAIL;
FAIL

my $documentation = { purpose=>$purpose, 
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

my $argsDeclaration  =
  [

   fileArg({name => 'mapFile',
	    descr => 'XML file with mapping of Sequence Features from BioPerl to GUS.  For an example, see $GUS_HOME/config/genbank2gus.xml',
	    constraintFunc=> undef,
	    reqd  => 1,
	    isList => 0,
	    mustExist => 1,
	    format=>'XML'
	   }),

   stringArg({name => 'algInvocationId',
	      descr => 'A comma delimited list of algorithm invocation ids to undo',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 1,
	     })
  ];


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
		     name => ref($self),
		     argsDeclaration => $argsDeclaration,
		     documentation => $documentation
		    });

  return $self;
}

sub run{
  my ($self) = @_;
  $self->{'commit'} = $self->getArg('commit');
  $self->{'algInvocationIds'} = $self->getArg('algInvocationId');
  $self->{'dbh'} = $self->getQueryHandle();
  $self->{'dbh'}->{AutoCommit}=0;

  $self->undoFeatures();

  $self->undoSequences();

  $self->_deleteFromTable('Core.AlgorithmParam');

  $self->_deleteFromTable('Core.AlgorithmInvocation');

 
}

sub undoFeatures{
   my ($self) = @_;

  my $mapperSet = 
    GUS::Supported::BioperlFeatMapperSet->new($self->getArg('mapFile'));

   $self->undoSpecialCaseQualifiers($mapperSet);

   $self->undoFeatureSkeleton($mapperSet);

   $self->_deleteFromTable('DoTS.NALocation');

#   $self->setParentToNull();

   $self->_deleteFromTable('DoTS.NAFeature');
}

# DELETE THIS METHOD.   NO LONGER NEEDED
sub setParentToNull{
  my ($self) = @_;

  my $algoInvocIds = join(', ', @{$self->{'algInvocationIds'}});
if ($self->getArg('commit')) {
  my $sql =
"UPDATE DoTS.NAFeature
SET parent_id = NULL
WHERE row_alg_invocation_id IN ($algoInvocIds)";

   $self->{'dbh'}->prepareAndExecute($sql);
    print STDERR "Committing updates to DoTS.NAFeature \n";
    $self->{'dbh'}->commit()
      || die "Committing updates to DoTS.NAFeature failed: " . $self->{'dbh'}->errstr() . "\n";
  }


}

sub undoSpecialCaseQualifiers{
  my ($self, $mapperSet) = @_;

  my @handlers = $mapperSet->getAllHandlers();
  foreach my $handler (@handlers){
    no strict 'refs';
    $handler->undoAll($self->{'algInvocationIds'}, $self->{'dbh'});
    if ($self->{'commit} == 1) {
      print STDERR "Committing undoing special case qualifier $handler->getHandlerName() from $handler->getGusTable()\n";
      $self->{'dbh'}->commit()
      || die "Committing undoing special case qualifier $handler->{'name'} failed: " . $self->{'dbh'} ->errstr() . "\n";
    }
  }
}

sub undoFeatureSkeleton {
  my ($self, $mapperSet) = @_;

  my $gusSkeletonMakerClassName = $mapperSet->getGusSkeletonMakerClassName();

  if ($gusSkeletonMakerClassName) {
    eval {
      no strict "refs";
      eval "require $gusSkeletonMakerClassName";
      my $method = "${gusSkeletonMakerClassName}::undoTables";
      my @tableNames = &$method();
      foreach my $tableName (@tableNames) {
	deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'}, $self->{'commit'});
      }
    };
    my $err = $@;
    if ($err) { die "Can't run skeleton undoTables method '${gusSkeletonMakerClassName}::undoTables'.  Error:\n $err\n"; }
  }
}

sub undoSequences{
  my ($self) = @_;

  $self->_deleteFromTable('DoTS.NAEntry');
  $self->_deleteFromTable('DoTS.SecondaryAccs');
  $self->_deleteFromTable('DoTS.NASequenceRef');
  $self->_deleteFromTable('DoTS.NASequenceKeyword');
  $self->_deleteFromTable('DoTS.Keyword');
  $self->_deleteFromTable('Do}S.NAComment');
  $self->_deleteFromTable('DoTS.NASequence');
  $self->_deleteFromTable('SRes.ExternalDatabaseRelease');
  $self->_deleteFromTable('SRes.ExternalDatabase');
}

sub _deleteFromTable{
   my ($self, $tableName) = @_;
  &deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'},$self->{'commit'});
}

sub deleteFromTable{
  my ($tableName, $algInvocationIds, $dbh, $commit) = @_;
  my $algoInvocIds = join(', ', @{$algInvocationIds});
  if ($commit == 1) {
    my $sql = 
    "DELETE FROM $tableName
     WHERE row_alg_invocation_id IN ($algoInvocIds)";

     my $rows = $dbh->do($sql) || die "Failed running sql:\n$sql\n";
     $rows = 0 if $rows eq "0E0";
     print STDERR "Deleted $rows rows from $tableName\n";
     print STDERR "Committing deletions from $tableName\n";
     $dbh->commit()
      || die "Committing deletions from $tableName failed: " . $dbh ->errstr() . "\n";
  }else{
      my $sql =
      "SELECT COUNT(*) FROM $tableName
       WHERE row_alg_invocation_id IN ($algoInvocIds)";
      my $stmt = $dbh->prepareAndExecute($sql);
      if(my ($rows) = $stmt->fetchrow_array()){
         print STDERR "Plugin will attempt to delete $rows rows from $tableName when run in commit mode\n";
       }
     
  }
    

}


1;


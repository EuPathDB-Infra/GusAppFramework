package GUS::Supported::Plugin::LoadOntologyEntryFromMO;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::Model::Study::OntologyEntry;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::SRes::OntologyRelationship;

use GUS::PluginMgr::Plugin;

my $argsDeclaration = 
  [ fileArg({name => 'nameChangesFile',
             descr => 'Any time a something is renamed since the previous version of MO.  This can also be use_def terms upgraded to official terms.  OldName<TAB>NewName',
             constraintFunc => undef,
             reqd => 0,
             isList => 0,
             mustExist => 1,
             format => 'Text'
            }),

    stringArg({name => 'externalDatabase',
               descr => 'External database for the MO Terms',
               constraintFunc=> undef,
               reqd  => 1,
               isList => 0
              }),

    stringArg({name => 'externalDatabaseRls',
               descr => 'Version of external database for the NEW Release existing in SRes::OntologyTerm which we will be updating in Study::OntologyEntry',
               constraintFunc=> undef,
               reqd  => 1,
               isList => 0
              }),
  ];

my $purposeBrief = <<PURPOSEBRIEF;
Update Study::OntologyEntry based on a new release of MGED Ontology loaded into SRes Tables.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Updates or Inserts into Study::OntologyEntry.
PLUGIN_PURPOSE

my $tablesAffected = [['Study.OntologyEntry','Populate the OntologyEntry table']];

my $tablesDependedOn = ['SRes.ExternalDatabase', 'SRes.ExternalDatabaseRelease','SRes.OntologyTerm', 'SRes.OntologyRelationship','Core.TableInfo'];

my $howToRestart = <<PLUGIN_RESTART;
This plugin can be not be restarted.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
Check the SRes.OntologyTerm and SRes.OntologyRelationship tables, then re run
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };

#-------------------------------------------------------------------------------

sub new {
    my ($class) = @_;
    my $self = { names_hash => {},
                 number_processed => 0,
                 seen_ontology_entry => {},};

    bless($self, $class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision =>  '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $argsDeclaration,
		       documentation     => $documentation
		      });

    return $self;
}

#-------------------------------------------------------------------------------

=pod

=head2 Subroutines

=over 4

=cut

sub getNamesHash {$_[0]->{names_hash}}

sub setRelationshipQueryHandle {$_[0]->{relationship_query_handle} = $_[1]}
sub getRelationshipQueryHandle {$_[0]->{relationship_query_handle}}

sub setExternalDatabaseReleaseId {$_[0]->{external_database_release_id} = $_[1]}
sub getExternalDatabaseReleaseId {$_[0]->{external_database_release_id}}

sub getCount { $_[0]->{number_processed} }
sub addToCount {$_[0]->{number_processed}++ }

sub getSeenOntologyEntry {$_[0]->{seen_ontology_entry} }

=pod

=item C<hasSeenOntologyEntry>

Returns true is the combination of parent and child have been seen
and adds the name/parentName combination to the hash

=cut

sub hasSeenOntologyEntry {
  my ($self, $name, $parentName) = @_;

  my $parents = $self->getSeenOntologyEntry()->{$name};
  my $hasSeen = $self->isIncluded($parents, $parentName);

  push(@{$self->getSeenOntologyEntry()->{$name}}, $parentName);
  return($hasSeen);

}

sub getOntologyTermTableId {$_[0]->{ontology_term_table_id}}

=pod

=item C<_setOntologyTermTableId>

Retrieve the core.tableInfo table_id for SRes::OntologyTerm and set the instance variable.

=cut

sub setOntologyTermTableId {
  my ($self) = @_;

  my $sql = "select table_id 
             from CORE.TABLEINFO t, 
                  CORE.DATABASEINFO d
             where t.name = 'OntologyTerm' 
              and d.name = 'SRes'
              and t.database_id = d.database_id";

  my ($tableId) = $self->sqlAsArray( Sql => $sql );

  $self->{ontology_term_table_id} = $tableId;
}

=pod

=item C<isIncluded>

Loop through an arrayref and return true if the value is somewhere in the array.

=cut

sub isIncluded {
  my ($self, $ar, $val) = @_;

  foreach(@$ar) {
    return(1) if($_ eq $val);
  }
  return(0);
}

#-------------------------------------------------------------------------------

=pod

=item C<run>

Read the config file, use args to set instance variables and load OntologyEntry rows

B<Return type:> C<scalar> 

The message describing the number of inserts and updates performed.

=cut

sub run {
  my ($self) = @_;

  my $coreInserts = $self->getTotalInserts();

  my $nameChanges = $self->getArg('nameChangesFile');
  $self->setNamesHashFromConfigFile($nameChanges);

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('externalDatabase'),
				     $self->getArg('externalDatabaseRls'));

  $self->setExternalDatabaseReleaseId($dbRlsId);

  $self->setOntologyTermTableId();

  my $sh = $self->_createAndPrepareSql();
  $self->setRelationshipQueryHandle($sh);

  # Give it the Root node and let it read the Ontology as a Tree
  $self->processOntologyRelationships('MGEDOntology', undef);

  my $insertCount = $self->getTotalInserts() - $coreInserts;
  my $updateCount = $self->getTotalUpdates() || 0;

  my $msg = "Inserted $insertCount and Updated $updateCount for Study::OntologyEntry";

  return($msg);
}

#-------------------------------------------------------------------------------

=pod

=item C<_createAndPrepareSql>

The main sql statement used by this plugin is defined and made into a query handle;

B<Return type:> C<DBI statement handle object> 

=cut

sub _createAndPrepareSql {
  my ($self) = @_;

  my $relationshipSql = "select s.name
                         from SRes.ONTOLOGYRELATIONSHIP r, SRes.ONTOLOGYTERM s, 
                              SRes.ONTOLOGYTERM o, SRes.ONTOLOGYRELATIONSHIPTYPE rt
                         where rt.name in ('instanceOf','subClassOf')
                          and r.subject_term_id = s.ontology_term_id
                          and r.object_term_id = o.ontology_term_id
                          and rt.ontology_relationship_type_id = r.ontology_relationship_type_id
                          and o.external_database_release_id = ?
                          and s.external_database_release_id = ?
                          and o.name = ?";

  return($self->getQueryHandle()->prepare($relationshipSql));
}

#-------------------------------------------------------------------------------

=pod

=item C<_setNamesHashFromConfigFile>

reads the config file and creates a hash of new names to old names

B<Parameters:>

$fn(scalar): path of the file to be read

B<Return type:> C<undef> 

This hash is stored as an instance variable.  

=cut

sub setNamesHashFromConfigFile {
  my ($self, $fn) = @_;

  return unless($fn);

  open(FILE, $fn) or die "Cannot open file $fn for reading: $!";

  while(my $line = readline(*FILE)) {
    chomp($line);

    my ($prevName, $newName) = split(/\t/, $line);
    $self->getNamesHash()->{$newName} = $prevName;
  }
}

#-------------------------------------------------------------------------------

=pod

=item C<_processOntologyRelationships>

This method does most of the work.  Processes SRes::OntologyTerms as a tree (depth first).  The 
top most node in the MO is "MGEDOntology" which does not have a Study::OntologyEntry parent 
(MGEDOntology's parent is 'thing').  

B<Parameters:>

$name(scalar): string which along with the external_database_release_id will define an SRes::OntologyTerm
$parentOntologyEntry(Study::OntologyEntry): The parent for this OntologyEntry (is null for root node)

B<Return type:> C<undef> 

=cut

sub processOntologyRelationships {
  my ($self, $name, $parentOntologyEntry) = @_;

  my $parentName;

  my $term = GUS::Model::SRes::OntologyTerm->
    new({name => $name, external_database_release_id => $self->getExternalDatabaseReleaseId() });

  unless($term->retrieveFromDB()) {
    $self->error("Could not retrieve a recored for ontology_term $name");
  }

  my $existingName = $self->getNamesHash()->{$name};

  unless($existingName) {
    $existingName = $name;
  }

  if($existingName eq 'MGEDOntology') {
    $parentName = 'thing';
  }
  else {
    $parentName = $parentOntologyEntry->getValue();
  }

  my $ontologyEntry = GUS::Model::Study::OntologyEntry->
    new({value => $existingName, category => $parentName});

  if($ontologyEntry->retrieveFromDB() && $existingName ne $name) {
    $self->log("Updating term $existingName to $name");
  }

  $self->updateOntologyEntry($ontologyEntry, $term,  $parentOntologyEntry);

  my $sh = $self->getRelationshipQueryHandle();
  my $bindValues = [$self->getExternalDatabaseReleaseId(),
                    $self->getExternalDatabaseReleaseId(),
                    $term->getName()];

  my @children = $self->sqlAsArray( Handle => $sh, Bind => $bindValues );

  foreach my $kidName (@children) {
    $self->processOntologyRelationships($kidName, $ontologyEntry);
  }
}

#-------------------------------------------------------------------------------

=pod

=item C<updateOntologyEntry>

Every ontologyEntry which has a name in MO or is in the config file is updated

B<Parameters:>

$ontologyEntry(Study::OntologyEntry): The object to be updated
$term(SRes::OntologyTerm): The OntologyTerm which the OntologyEntry is based
$parentOntologyEntry(Study::OntologyEntry): The direct parent for the main ontologyEntry object

B<Return type:> C<undef> 

=cut

sub updateOntologyEntry {
  my ($self, $ontologyEntry, $term, $parentOntologyEntry) = @_;

  my $value = $term->getName();

  my $definition = $term->getDefinition();
  my $externalDatabaseReleaseId =  $term->getExternalDatabaseReleaseId();
  my $rowId = $term->getId();
  my $sourceId = $term->getSourceId();
  my $uri = $term->getUri();

  my $tableId = $self->getOntologyTermTableId();

  my ($parentId, $category);

  if($value eq 'MGEDOntology') {
    $category = 'thing';
  }
  else {
    $parentId = $parentOntologyEntry->getId();
    $category = $parentOntologyEntry->getValue();
  }

  # Don't process the same term with the same parent twice
  return if($self->hasSeenOntologyEntry($value, $category));

  $ontologyEntry->setValue($value);
  $ontologyEntry->setDefinition($definition);
  $ontologyEntry->setExternalDatabaseReleaseId($externalDatabaseReleaseId);
  $ontologyEntry->setRowId($rowId);
  $ontologyEntry->setTableId($tableId);
  $ontologyEntry->setSourceId($sourceId);
  $ontologyEntry->setUri($uri);
  $ontologyEntry->setCategory($category);
  $ontologyEntry->set('parent_id', $parentId);

  $ontologyEntry->submit();

  if($self->addToCount % 100 == 0) {
    my $count = $self->getCount();
    $self->log("Processed $count Study::OntologyEntry Rows");
  }
}


1;

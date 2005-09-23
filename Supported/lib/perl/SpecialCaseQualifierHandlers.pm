package GUS::Supported::SpecialCaseQualifierHandlers;

use strict;

use GUS::Model::DoTS::NAGene;
use GUS::Model::DoTS::NAProtein;
use GUS::Model::SRes::DbRef;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Model::DoTS::NAFeatureNAGene;
use GUS::Model::DoTS::NAFeatureNAProtein;
use GUS::Model::DoTS::DbRefNAFeature;
use GUS::Supported::Plugin::InsertSequenceFeaturesUndo;

# This is a pluggable module for GUS::Supported::Plugin::InsertSequenceFeatures 
# It handles commonly seen qualifiers that need special case treatment (ie,
# their values are not simply stuffed into a column of NAFeature or its 
# subclasses

sub new {
  my ($class, $plugin) = @_;
  my $self = {};
  $self->{plugin} = $plugin;
  bless($self, $class);
  return $self;
}

sub undoAll{
  my ($self, $algoInvocIds, $dbh) = @_;

  $self->{'algInvocationIds'} = $algoInvocIds;
  $self->{'dbh'} = $dbh;

  $self->_undoGene();
  $self->_undoDbXRef();
  $self->_undoNote();
  $self->_undoProtein();
  $self->_undoTranslation();

}

################ Gene ###############################3

sub gene {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @genes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    my $geneID = $self->_getNAGeneId($tagValue);
    my $gene = GUS::Model::DoTS::NAFeatureNAGene->new();
    $gene->setNaGeneId($geneID);
    push(@genes, $gene);
  }
  return @genes;
}

sub _getNAGeneId {   
  my ($self, $geneName) = @_;
  my $truncName = substr($geneName,0,300);

  $self->{geneNameIds} = {} unless $self->{geneNameIds};

  if (!$self->{geneNameIds}->{$truncName}) {
    my $gene = GUS::Model::DoTS::NAGene->new({'name' => $truncName});
    unless ($gene->retrieveFromDB()){
      $gene->setIsVerified(0);
      $gene->submit();
    }
    $self->{geneNameIds}->{$truncName} = $gene->getId();
  }
  return $self->{geneNameIds}->{$truncName};
}

sub _undoGene{
  my ($self) = @_;

  $self->_deleteFromTable('DoTS.NAFeatureNAGene');
  $self->_deleteFromTable('DoTS.NAGene');
}

############### db Xrefs  #########################################

sub dbXRef {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @dbRefNaFeatures;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    push(@dbRefNaFeatures, $self->_buildDbXRef($tagValue));
  }
  return @dbRefNaFeatures;
}

sub _buildDbXRef {
  my ($self, $dbSpecifier) = @_;

  my $dbRefNaFeature = GUS::Model::DoTS::DbRefNAFeature->new();
  my $id = $self->_getDbXRefId($dbSpecifier);
  $dbRefNaFeature->setDbRefId($id);

  ## If DbRef is outside of Genbank, then link directly to sequence
  #if (!($value =~ /taxon|GI|pseudo|dbSTS|dbEST/i)) {
  #  my $o2 = GUS::Model::DoTS::DbRefNASequence->new();
  #  $o2->setDbRefId($id);
  #}
  #else {
  # my $id = &getDbXRefId($value);}

  return $dbRefNaFeature;

}

sub _getDbXRefId {
  my ($self, $dbSpecifier) = @_;

  if (!$self->{dbXrefIds}->{$dbSpecifier}) {
    my ($dbName, $id, $sid)= split(/\:/, $dbSpecifier);
    my $extDbRlsId = $self->_getExtDatabaseRlsId($dbName);
    my $dbref = GUS::Model::SRes::DbRef->new({'external_database_release_id' => $extDbRlsId, 
					      'primary_identifier' => $id});

    if ($sid) {
      $dbref->setSecondaryIdentifier($sid);
    }
    unless ($dbref->retrieveFromDB()) {
      $dbref->submit();
    }

    $self->{dbXrefIds}->{$dbSpecifier} = $dbref->getId();
  }

  return $self->{dbXrefIds}->{$dbSpecifier};
}


sub _getExtDatabaseRlsId {
  my ($self, $name) = @_;

  if (!$self->{extDbRlsIds}->{$name}) {
    my $externalDatabase
      = GUS::Model::SRes::ExternalDatabase->new({"name" => $name});

    unless($externalDatabase->retrieveFromDB()) {
      $externalDatabase->submit();
    }

    my $externalDatabaseRls = GUS::Model::SRes::ExternalDatabaseRelease->
      new ({'external_database_id'=>$externalDatabase->getId(),
	    'version'=>'unknown'});

    unless($externalDatabaseRls->retrieveFromDB()) {
      $externalDatabaseRls->submit();
    }

    $self->{extDbRlsIds}->{$name} = $externalDatabaseRls->getId();
  }
    return $self->{extDbRlsIds}->{$name};
}

sub _undoDbXRef{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.DbRefNAFeature');
  $self->_deleteFromTable('SRes.DbRef');
  $self->_deleteFromTable('SRes.ExternalDatabase');
  $self->_deleteFromTable('SRes.ExternalDatabaseRelease');
}

################ Note ########################################
sub note {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @notes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    my $arg = {comment_string => substr($tagValue, 0, 4000)};
    push(@notes, GUS::Model::DoTS::NAFeatureComment->new($arg));

  }
  return @notes;
}

sub _undoNote{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}

############### Protein ##################################
sub protein {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @naFeatureNaProteins;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    my $nameTrunc = substr($tagValue, 0, 300);

    my $naFeatureNaProtein = GUS::Model::DoTS::NAFeatureNAProtein->new();

    my $protein = GUS::Model::DoTS::NAProtein->new({'name' => $nameTrunc});
    unless ($protein->retrieveFromDB()){
      $protein->setIsVerified(0);
      $protein->submit();
    }

    $naFeatureNaProtein->setNaProteinId($protein->getId());
    push(@naFeatureNaProteins, $naFeatureNaProtein);
  }
  return @naFeatureNaProteins;
}

sub _undoProtein{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAProtein');
  $self->_deleteFromTable('DoTS.NAFeatureNAProtein');
}

############### TranslatedAAFeature  ###############################3

sub translation {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @translatedAAFeatures;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    my $transAaFeat = GUS::Model::DoTS::TranslatedAAFeature->new();
    $transAaFeat->setIsPredicted(1);

    my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->
      new({'sequence' => $tagValue});

    $aaSeq->submit();

    $transAaFeat->setAaSequenceId($aaSeq->getId());
    push(@translatedAAFeatures, $transAaFeat);
  }
  return @translatedAAFeatures;
}

sub _undoTranslation{
  my ($self) = @_;

  $self->_deleteFromTable('DoTS.TranslatedAAFeature');
  $self->_deleteFromTable('DoTS.TranslatedAASequence');

}

#################################################################

sub _deleteFromTable{
   my ($self, $tableName) = @_;

  &GUS::Supported::Plugin::InsertSequenceFeaturesUndo::deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'});
}

1;


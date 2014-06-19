# $Id$
package GUS::Community::Plugin::LoadSageResults;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::Study::Study;
use GUS::Model::RAD::ArrayDesign;
use GUS::Model::RAD::Acquisition;
use GUS::Model::RAD::Assay;
use GUS::Model::RAD::StudyAssay;
use GUS::Model::RAD::Quantification;
use GUS::Model::RAD::SAGETag;
use GUS::Model::RAD::SAGETagResult;
use GUS::Model::SRes::Contact;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     stringArg({name => 'contact',
		 descr => 'name,first,last as they should appear in sres.contact',
		 constraintFunc => undef,
		 reqd => 1,
		 isList => 1
		}),

     stringArg({name => 'arrayDesignName',
		descr => 'rad.ArrayDesign.name used for this set of sage tags',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),

     stringArg({name => 'arrayDesignVersion',
		descr => 'rad.ArrayDesign.version used for this set of sage tags',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),

     stringArg({name => 'studyName',
		 descr => 'value for study.name',
		 constraintFunc => undef,
		 reqd => 1,
		 isList => 0
		}),

     stringArg({name => 'studyDescription',
		descr => 'value for study.description',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),

     fileArg({name => 'freqFile',
	      descr => 'full path of the sage tag frequency filw, tab delimited with tissue/strains as tab delimite header.',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'tab delimited, first column contains tag sequences, first row contains the label tag followed by sample source names'
	     }),

    integerArg({name  => 'restart',
	       descr => 'optional,data file line number to start loading data from(start counting after the header)',
	       constraintFunc=> undef,
	       reqd  => 0,
	       isList => 0
	      }),

     integerArg({name  => 'testnum',
		 descr => 'The number of data lines to read when testing this plugin. Not to be used in commit mode.',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
		})
    ];


  return $argsDeclaration;
}



# --------------------------------------------------------------------------
# Documentation
# --------------------------------------------------------------------------

sub getDocumentation {

my $purposeBrief = <<PURPOSEBRIEF;
Plug_in to populate RAD.SAGETagResult.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
plug_in that inserts frequency results into RAD.SAGETagResult and retrieves or creates supporting objects.
PLUGIN_PURPOSE

my $syntax = <<SYNTAX;
Standard plugin syntax.
SYNTAX

#check the documentation for this
my $tablesAffected = [['GUS::Model::Study::Study', 'inserts a single row for entire set of results'],['GUS::Model::RAD::Assay', 'inserts a row for each tissue/organism source included in result file'],['GUS::Model::RAD::StudyAssay','inserts a linking row for each Assay row'],['GUS::Model::RAD::Acquisition','inserts a single row for each Assay'],['GUS::Model::RAD::Quantification','inserts a single row for each Assay row'],['GUS::Model::RAD::SAGETagResult','inserts frequencies from input file'],['GUS::Model::SRes::Contact','inserts a row if row cannot be retrieved using contact arg']];

my $tablesDependedOn = [['GUS::Model::RAD::ArrayDesign', 'Gets an existing ArrayDesign row'],['GUS::Model::RAD::SAGETag', 'Gets existing sage tag rows for each row in the input file']];

my $howToRestart = <<PLUGIN_RESTART;
Loading can be resumed using the I<--restart n> argument where n is the line number in the data file of the first row to load upon restarting (line 1 is the first line after the header).
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
no ArrayDesign or SAGETag rows corresponding to previously entered and required tags.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
SAGETag with tag sequences must have been previously entered along with the required ArrayDesign row. Input file must be in the correct tab delimited format. First row must contain a beginning label called tag followed by the names of the frequency sources. Subsequent rows must start with the tag sequence followed by the integers representing the frequencies in each of the data sources.
PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     syntax => $syntax,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };

return ($documentation);

}


#############################################################################
# Create a new instance of a SageResultLoader object
#############################################################################

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $arguments     = &getArgumentsDeclaration();

  my $configuration = {requiredDbVersion => 3.6,
	               cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       revisionNotes => 'make consistent with GUS 3.5',
		       argsDeclaration   => $arguments,
		       documentation     => $documentation
		       };

     $self->initialize($configuration);

  return $self;
}

########################################################################
# Main Program
########################################################################

sub run {
  my ($self) = @_;

  $self->logArgs();
  $self->logAlgInvocationId();
  $self->logCommit();

  $self->checkFileFormat();

  my $contact = $self->getContact();

  my $study = $self->getStudy($contact);

  my $assayNames = $self->getAssayNames();

  my $arrayDesign = $self->getArrayDesign();

  my $quantificationIds = $self->getQuantificationIds($assayNames,$study,$contact,$arrayDesign);

  my $numFreqsInserted = $self->insertSageTagResults($quantificationIds, $arrayDesign);

  my $resultDescrip = "$$numFreqsInserted rows inserted into SageTageResults";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}


sub checkFileFormat {
  my ($self) = @_;

  my $file = $self->getArg('freqFile');

  open(FILE,$file);

  my $assayNum;

  while(<FILE>) {
    chomp;
    my @assays = split (/\t/,$_);

    if ($. == 1) {
      $self->userError("Frequency file does not contain a well formatted heading, tab delimited, 'tag' followed by sources of RNA \n") unless ($_ =~ /^tag/ && @assays > 1);
      $assayNum = @assays;
    }

    if ($. != 1) {
      $self->userError("Frequency file does not contain the correct number of columns\n") unless (@assays == $assayNum);
      $self->userError("The first column of the frequency file does not contain a tag sequence\n") unless ($assays[0] =~ /[ACTGNactgn]+/);
      for (my $i=1;$i<$assayNum;$i++) {
	$self->userError("At least one frequency in the frequency file does not contain an integer\n") unless ($assays[$i] =~ /\d*/);
      }
    }
  }

  $self->log("Frequency file format is correct\n");

  close (FILE);
}


sub getContact {
  my ($self) = @_;

  my $contactHash;

  if(defined $self->getArg('contact')->[0])  {  $contactHash->{name}=$self->getArg('contact')->[0];}
  if(defined $self->getArg('contact')->[1])  {  $contactHash->{first}=$self->getArg('contact')->[1];}
  if(defined $self->getArg('contact')->[2])  {  $contactHash->{last}=$self->getArg('contact')->[2];}

  my $contact = GUS::Model::SRes::Contact->new($contactHash);

  if ($contact) {
    $self->log("Obtained contact object\n");
  }
  else {
    $self->userError("Unable to obtain contact object\n");
  }

  if (! $contact->retrieveFromDB()) {

    $contact->submit();
  }

  return $contact
}

sub getStudy {
   my ($self, $contact) = @_;

   my $study = GUS::Model::Study::Study->new({'name'=>$self->getArg('studyName')});

   $study->retrieveFromDB();

   if ($self->getArg('studyDescription') && ($study->getDescription() ne $self->getArg('studyDescription'))) {
     $study->setDescription($self->getArg('studyDescription'));
   }

   $study->setParent($contact);

   my $subNum = $study->submit();

   $self->log("$subNum rows submitted with study\n");

   return $study;
}

sub getAssayNames{
  my ($self) = @_;

  my $file = $self->getArg('freqFile');

  open(FILE,$file);

  my @assayNames;

  while(<FILE>) {
    chomp;
    if ($_ =~ /tag/) {
      @assayNames = split (/\t/,$_);
    }
  }

  my $num = @assayNames;

  $self->log("$num assay names found\n");

  close (FILE);

  return \@assayNames;
}

sub getArrayDesign {
  my ($self) = @_;

  my $arrayDesign = GUS::Model::RAD::ArrayDesign->new({'name'=>$self->getArg('arrayDesignName'),'version'=>$self->getArg('arrayDesignVersion')});

  if (! $arrayDesign->retrieveFromDB()) {
    $self->userError("--arrayDesignName " . $self->getArg('arrayDesignName') . "and --arrayDesignVersion " . $self->getArg('arrayDesignVersion') . " do not return a valid ArrayDesign object\n");
  }
  else {
    $self->log("ArrayDesign row located\n");
  }

  return $arrayDesign;
}


sub getQuantificationIds {
  my ($self,$assayNames,$study,$contact,$arrayDesign) = @_;

  my $tableId = $self->getTableId();

  my @quantificationIds;

  for (my $i = 1;$i < @$assayNames;$i++) {

    my $assayName = $assayNames->[$i];

    my $assay = $self->getAssay($assayName,$arrayDesign,$contact);

    $assay->getChild('GUS::Model::RAD::StudyAssay',1) ? $assay->getChild('GUS::Model::RAD::StudyAssay') : $self->makeStudyAssay($assay,$study);

    my $acquisition = $assay->getChild('GUS::Model::RAD::Acquisition',1) ? $assay->getChild('GUS::Model::RAD::Acquisition') : $self->makeAcquisition($assay,$assayName);

    my $quantification = $acquisition->getChild('GUS::Model::RAD::Quantification',1) ? $acquisition->getChild('GUS::Model::RAD::Quantification') : $self->makeQuantification($acquisition,$assayName,$tableId);

    $assay->submit();

    my $quantificationId = $quantification->getId();

    $quantificationIds[$i] = $quantificationId;

  }

  my $num = @quantificationIds;

  $self->log("$num quantification_ids obtained\n");

  $self->undefPointerCache();

  return \@quantificationIds;
}

sub getAssay {
  my ($self,$assayName,$arrayDesign,$contact) = @_;

  my $assay = GUS::Model::RAD::Assay->new({'name' => $assayName});

  $assay->retrieveFromDB();

  $assay->setParent($arrayDesign);

  $assay->setParent($contact);

  return $assay;
}

sub makeStudyAssay {
  my ($self,$assay,$study) = @_;

  my $studyAssay = GUS::Model::RAD::StudyAssay->new();

  if ($studyAssay) {
    $self->log("Obtained StudyAssay object\n");
  }
  else {
    $self->userError("Unable to obtain StudyAssay object\n");
  }

  $studyAssay->setParent($assay);

  $studyAssay->setParent($study);
}

sub makeAcquisition {
  my ($self,$assay,$assayName) = @_;

  my $acquisition = GUS::Model::RAD::Acquisition->new({'name'=>$assayName});

  if ($acquisition) {
    $self->log("Obtained acquisition object\n");
  }
  else {
    $self->userError("Unable to obtain acquisition object\n");
  }

  $acquisition->setParent($assay);

  return $acquisition;
}

sub makeQuantification {
  my ($self,$acquisition,$assayName,$tableId) = @_;

  my $quantification = GUS::Model::RAD::Quantification->new({'name'=>$assayName,'uri'=>$self->getArg('freqFile'),'result_table_id'=>$tableId});

  if ($quantification) {
    $self->log("Obtained quantification object\n");
  }
  else {
    $self->userError("Unable to obtain quantification object\n");
  }

  $quantification->setParent($acquisition);

  return $quantification;
}

sub getTableId {
  my ($self) = @_;

  my $query="select t.table_id from core.tableinfo t, core.databaseinfo d where t.name='SAGETagResult' and d.name = 'RAD' and t.database_id = d.database_id";
  my $dbh = $self->getQueryHandle();

  my $sth = $dbh->prepare($query);

  $sth->execute();

  my ($id) = $sth->fetchrow_array();

  $sth->finish();

  if (defined $id) {
    return $id;
  }
  else {
    $self->log("Can't retrieve table_id for SAGETagResult\n");
  }
}

sub insertSageTagResults {
  my ($self,$quantificationIds, $arrayDesign) = @_;

  my $file = $self->getArg('freqFile');

  my $num;

  open(FILE,$file);

  my $linenum = 0;

  while(<FILE>) {
    chomp;

    if ($_ =~ /tag/) {
      next;
    }

    $linenum++;

    if ($self->getArg('testnum') && $linenum >= $self->getArg('testnum')) {
      return \$num;
    }

     if ($self->getArg('restart') && $linenum < $self->getArg('restart')) {
         $self->log("$linenum lines from the frequency file have been processed before restart\n"); 
	 next;
     }

    my @line = split(/\t/, $_);

    $self->processLine(\@line,$arrayDesign,$quantificationIds,\$num);



    $self->log("$linenum lines from the frequency file have been processed\n") if $linenum % 1000 == 0;
  }

  $self->log("$linenum lines from the frequency file have been processed\n");

  return \$num;

}


sub processLine {
  my ($self,$line,$arrayDesign,$quantificationIds,$num) = @_;

  my $numQ = @$quantificationIds;

  my $arrayDesignId = $arrayDesign->get('array_design_id');

   my $sageTag = GUS::Model::RAD::SAGETag->new({'tag'=>$line->[0], 'array_design_id'=>$arrayDesignId});

    if (! $sageTag->retrieveFromDB()) {
      $self->userError("SAGE tag $line->[0] with array_design_id = $arrayDesignId not in db\n");
    } 

  for (my $i=1;$i < @$line;$i++) {

    my $sageTagResult = GUS::Model::RAD::SAGETagResult->new({'subclass_view'=>"SAGETagResult", 'quantification_id'=>$quantificationIds->[$i],'tag_count'=>$line->[$i]});

    $sageTagResult->setParent($sageTag);

    $$num += $sageTagResult->submit();
  }

  $self->undefPointerCache();

}

sub undoTables {
  my ($self) = @_;

  return ('RAD.SAGETagResult',
	  'RAD.Quantification',
	  'RAD.Acquisition',
	  'RAD.StudyAssay',
	  'RAD.Assay',
	  'Study.Study',
	  'SRes.Contact',
	 );
}

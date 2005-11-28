##
## InsertPhylogeneticProfiles.pm
## $Id$
##

package GUS::Community::Plugin::InsertPhylogeneticProfiles;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::PhylogeneticProfileSet;
use GUS::Model::DoTS::PhylogeneticProfile;
use GUS::Model::DoTS::PhylogeneticProfileMember;

use PlasmoDBData::Load::Util;

use FileHandle;

my $purposeBrief = "Load phylogenetic profiles from a file.";

my $purpose = <<PLUGIN_PURPOSE;
This plugin loads phylogenetic profiles.  Each of these profiles describes
a gene in terms of which organisms' genomes contain orthologs of it.
PLUGIN_PURPOSE

my $tablesAffected =
  [ ['DoTS::PhylogeneticProfile', 'Insert one record per gene'],
    ['DoTS::PhylogeneticProfileMember',
     'For each profile, insert one record per genome'],
  ];

my $tablesDependedOn =
  [
  ];

my $howToRestart = <<PLUGIN_RESTART;
This plugin has no restart facility.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases,
		      notes            => $notes
		    };

my $argsDeclaration = 
  [

   stringArg({ descr => 'Desciption of the PhylogeneticProfileSet',
               name  => 'ProfileSetDescription',
               isList    => 0,
               reqd  => 1,
               constraintFunc => undef,
             }),

   booleanArg ({name => 'tolerateMissingIds',
                descr => 'Set this to tolerate (and log) source ids in the input that do not find an oligo or gene in the database.  
                          If not set, will fail on that condition',
                reqd => 0,
                default =>0
               }),

 fileArg({name           => 'headerFile',
	  descr          => 'File containing Genbank Taxon Names',
	  reqd           => 1,
	  mustExist      => 1,
	  format         => 'Each Line Contains a Taxon Names',
	  constraintFunc => undef,
	  isList         => 0, 
	 }),

   fileArg({name            => 'datafile',
	    descr           => '',
	    reqd            => 1,
	    mustExist       => 1,
	    format          =>
'This file (can be .gz) contains a record for each gene.  The gene records are as in this example:
>pfalciparum|Pfa3D7|pfal_chr1|PFA0135w|Annotation|Sanger        1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 0.062 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 1.000 0.002 1.000 1.000 
where:
pfalciparum is a taxon name
PFA0135w is the Dots.GeneFeature.source_id of the gene
and the remaining values after the tab are presence-or-absence calls for homologs of this genein each of the taxa whose IDs are given in the first record
',
	    constraintFunc  => undef,
	    isList          => 0, }),
                      ];

sub new {
  my ($class) = @_;
  my $self    = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 3.5,
                     cvsRevision       => '$Revision$',
                     name              => ref($self),
                     argsDeclaration   => $argsDeclaration,
                     documentation     => $documentation
                    });

  return $self;
}

sub run {
  my ($self) = @_;
  $self->logAlgInvocationId;
  $self->logCommit;

  my $phylogeneticProfileSet = GUS::Model::DoTS::PhylogeneticProfileSet->
    new({DESCRIPTION => $self->getArg('ProfileSetDescription'),
         PRED_ALG_INVOCATION_ID => $self->getAlgInvocation()->getId(),
         });

  $phylogeneticProfileSet->submit();

  my $datafile = $self->getArg('datafile');
  my $fileName;

  if ($datafile =~ /(.*)\.gz$/){
    system("gunzip $datafile");
    $fileName = $1;
  }
  else {
    $fileName = $datafile;
  }

  open(FILE, "< $fileName") || die "Can't open datafile $fileName";

  my $taxonIdList = $self->_getTaxonIds();

  my ($cCalls, $hCalls, $eCalls, $aa_sequence_id);
  while (<FILE>) {
      chomp;

      my ($geneDoc, $valueString) = split(/\t/, $_);
      my $sourceId = (split(/\|/, $geneDoc))[3];

      print STDERR "sourceId:  $sourceId\n";

      if(my $naFeatureId = PlasmoDBData::Load::Util::getGeneFeatureId($self, $sourceId)) {
        my $profile = GUS::Model::DoTS::PhylogeneticProfile->
          new({phylogenetic_profile_set_id => $phylogeneticProfileSet->getId(),
               na_feature_id => $naFeatureId,
              });

        $profile->submit();

        my @values = split(/ /, $valueString);
        if(scalar(@values) != scalar(@$taxonIdList)) {
          die "There are ".scalar(@values)." values and ".scalar(@$taxonIdList)." TaxonNames";
        }

        for (my $i=0; $i <= $#values; $i++) {

	  my $profileMember = GUS::Model::DoTS::PhylogeneticProfileMember->
            new({taxon_id => $taxonIdList->[$i],
                 minus_log_e_value => $values[$i]*1000,
                 PHYLOGENETIC_PROFILE_ID => $profile->getId()
                });

	  $profileMember->submit();
        }
      }
      elsif($self->getArgs()->{tolerateMissingIds}) {
          $self->log("No na_Feature_id found for '$sourceId'");
        }
      else {
        $self->userError("Can't find naFeatureId for source id '$sourceId'");
      }
  $self->undefPointerCache();
    }
  close(FILE);
  system("gzip $fileName");

}

sub _getTaxonIds {
  my ($self) = @_;

  my $fn = $self->getArgs()->{headerFile};

  open(HEADER, "< $fn") || die "Cannot open $fn for reading: $!";

  my @rv;
  my $count = 0;

  while(my $name = <HEADER>) {
    chomp($name);
    $count++;

    my $sql = "SELECT taxon_id, UNIQUE_NAME_VARIANT FROM SRes.TaxonName WHERE name = '$name'";
    my $sh = $self->getQueryHandle->prepare($sql);
    $sh->execute();

    while(my ($taxonId, $unv) = $sh->fetchrow_array()) {
      #Buchnera sp is a special case
      if($name eq 'Buchnera' && $unv ne 'Buchnera <proteobacteria>') {}
      else {
        push(@rv, $taxonId);
      }
    }
  }

  if($count != scalar(@rv)) {
    die "There are $count rows of Taxon names in the headerFile but ".scalar(@rv)." entries in the db";
  }

  close(HEADER);

  return(\@rv);
}

1;

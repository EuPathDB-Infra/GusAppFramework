package GUS::Supported::Plugin::CalculateAASequenceMolWt;

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use base qw(GUS::PluginMgr::Plugin);

use Bio::Tools::SeqStats;

my $argsDeclaration =
  [
   stringArg({ name => 'extDbRlsName',
	       descr => 'External Database Release name of the AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),

   stringArg({ name => 'extDbRlsVer',
	       descr => 'External Database Release version of the AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),

   stringArg({ name => 'seqTable',
	       descr => 'where to find the target AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),
  ];


my $purposeBrief = <<PURPOSEBRIEF;
Calculates molecular weights of amino acid sequences.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Calculates molecular weights of amino acid sequences.
PLUGIN_PURPOSE

my $tablesAffected =
  [
   ['DoTS.AASequence' =>
    'molecular_weight field is updated'
   ],
  ];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purposeBrief => $purposeBrief,
		      purpose => $purpose,
		      tablesAffected => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart => $howToRestart,
		      failureCases => $failureCases,
		      notes => $notes,
		    };

sub new {

  my $class = shift;
  $class = ref $class || $class;
  my $self = {};

  bless $self, $class;

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision =>  '$Revision: 4147 $',
		      name => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });
  return $self;
}

sub run {

  my ($self) = @_;

  my $extDbRlsName = $self->getArg("extDbRlsName");
  my $extDbRlsVer = $self->getArg("extDbRlsVer");

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);

  unless ($extDbRlsId) {
    die "No such External Database Release / Version:\n $extDbRlsName / $extDbRlsVer\n";
  }

  my $dbh = $self->getQueryHandle();

  my $sth = $dbh->prepare(<<EOSQL);

  SELECT aa_sequence_id, sequence
  FROM   @{[$self->getArg('seqTable')]}
  WHERE  external_database_release_id = ?

EOSQL

  my $update = $dbh->prepare(<<EOSQL);

  UPDATE @{[$self->getArg('seqTable')]}
  SET    molecular_weight = ?
  WHERE  aa_sequence_id = ?

EOSQL

  $sth->execute($extDbRlsId);

  my $count = 0;
  while (my ($aaSeqId, $seq) = $sth->fetchrow_array()) {
    my $seq = Bio::PrimarySeq->new(-id => $aaSeqId,
				   -seq => $seq,
				   -alphabet => "protein",
				  );
    my ($minWt, $maxWt) =
      @{Bio::Tools::SeqStats->get_mol_wt($seq)};

    my $aveWt = sprintf("%d", ($minWt + $maxWt) / 2);

    $update->execute($aveWt, $aaSeqId);
    $count++;
  }

  warn "Done; updated $count sequences\n";
}

1;

package GUS::Common::Plugin::LoadSequenceOntology;

@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;
use FileHandle;
use GUS::ObjRelP::DbiDatabase;

use GUS::Model::SRes::SequenceOntology;

$| = 1;

#on command line need input file, so version, so cvs version
#InputFile has format SOid\tTerm\tdefinition\n



sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);
    my $usage = 'Loads Sequence Ontology from tab delimited file';
    my $easycsp =
        [{o => 'inputFile',
          t => 'string',
          h => 'name of the file',
          },

          { h => 'version of SeqOntology',
          t => 'string',
          o => 'so_version',
          },

          { h => 'cvs version of SeqOntology',
          t => 'string',
          o => 'so_cvs_version',

         },];

     $self->initialize({requiredDbVersion => {Core => '3'},
                       cvsRevision => '$Revision$', #CVS fills this in
                       cvsTag => '$Name$', #CVS fills this in
                       name => ref($self),
                       revisionNotes => 'make consistent with GUS 3.0',
                       easyCspOptions => $easycsp,
                       usage => $usage
                      });
    return $self;
}


sub run {
        my $self = shift;

        $self->getArgs()->{'commit'} ? $self->log("***COMMIT ON***\n") : $self->log("**COMMIT TURNED OFF**\n");
        $self->getArgs->{'inputFile'};

        if (!$self->getArgs->{'inputFile'}) {
          die "provide --inputFile name on the command line\n";
        }
        my $Input = FileHandle->new('<' . $self->getArgs->{inputFile});

        while (<$Input>){

          chomp;

       my ($SOid, $Term, $definition) = split (/\t/, $_);


        $self->Insert($SOid,$Term,$definition);


        }

     $Input->close;

        return "LoadedSOontologyFromFile";
}

sub Insert {

   my $self = shift;

   my ($SOid, $Term, $definition) = @_;

   my $so_version =  $self->getArgs->{'so_version'};
   my $so_cvs_version = $self->getArgs->{'so_cvs_version'};

   my $ontology_name = 'sequence';

   my $SOterm = GUS::Model::SRes::SequenceOntology->new({'so_id' => $SOid,
                                                         'ontology_name' => $ontology_name,
                                                         'so_version' => $so_version,
                                                         'so_cvs_version' => $so_cvs_version,
                                                         'term_name' => $Term,
                                                         'definition' => $definition });

   print STDERR "$SOid\t$ontology_name\t$so_version\t$so_cvs_version\t$Term\t$definition\n";



   $SOterm->submit();

}





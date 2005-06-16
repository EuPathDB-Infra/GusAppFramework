#######################################################################
##                InsertExternalDatabaseRls.pm
##
## Creates new entry in table SRes.ExternalDatabaseRelease
## for new external database versions
## $Id$
##
#######################################################################
 
package GUS::Supported::Plugin::InsertExternalDatabaseRls;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Model::SRes::ExternalDatabaseRelease;

my $argsDeclaration = 
	[
	 stringArg({name => 'databaseName',
		    descr => 'Name in GUS of database for which we are creating a new release',
		    reqd => 1,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg ({name=> 'releaseDate',
		     descr => 'release date; format must conform to DATE format in your database instance',
		     reqd => 0,
		     constraintFunc => undef,
		     isList =>0,
		 }),
	 
	 stringArg ({name => 'databaseVersion',
		    descr => 'New version of external database for which we are creating a new release',
		    reqd => 1,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 
	 stringArg({name => 'downloadUrl',
		    descr => 'full url of external site from where new release can be downloaded',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg({name => 'idType',
		    descr => 'brief description of the format of the primary identifier of entries in the release',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 stringArg({name => 'idUrl',
		    descr => 'url to look up entries for a particular id.  If possible, replace a specific id with <ID> to provide a generalized url',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg({name => 'secondaryIdType',
		    descr => 'brief description of the format of the secondary identifier of entries in the release',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 stringArg({name => 'secondaryIdUrl',
		    descr => 'url to look up entries for a particular id, by their secondary identifier.  If possible, replace a specific id with <ID> to provide a generalized url',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 stringArg({name => 'description',
		    descr => 'description of the new release.  If possible, make the description specific to the release rather than a general description of the database itself',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 
	 #not using fileArg for this since file is not actually opened in this plugin
	 stringArg({name => 'file_name',
		    descr => 'name of file representing this release, and if it exists, link to local location where file can be found',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg({name => 'file_md5',
		    descr => 'md5 checksum for verifying the file was downloaded successfully, and if it exists, link to local location where file can be found',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		})
	 ];

my $purposeBrief = <<PURPOSEBRIEF;
Creates new entry in table SRes.ExternalDatabaseRelease for new external database versions 
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Simple plugin that is the easiest way to create a row representing a new release of a database from an external source.  Protects against making an entry for a version that already exists for a particular database.
PLUGIN_PURPOSE

my $tablesAffected = 
	[['SRes.ExternalDatabaseRelease', 'The entry representing the new release is created here']];

my $tablesDependedOn = 
	[['SRes.ExternalDatabase', 'There must be an entry in this table representing the database itself; the release to be created will point to it'],
	 ['SRes.ExternalDatabaseRelease', 'If there is already an entry in this table with the same version as the release to be created, then no action is taken']];
	 
my $howToRestart = <<PLUGIN_RESTART;
Only one row is created, so if the plugin fails, restart by running it again with the same parameters (accounting for any errors that may have caused the failure.
PLUGIN_RESTART
    
my $failureCases = <<PLUGIN_FAILURE_CASES;
Neither the name of the database nor the database ID is required as input; however, if neither is provided, the plugin will fail.  Also, If there is already an entry in SRes.ExternalDatabaseRelease that has the same version number as the entry to be created, then no new row is submitted.  This is not a failure case per se, but will result in no change to the database where one might have been expected.  Finally, if including --releaseDate in the command line, the format of the date must be the same as that expected by the DATE datatype in your database instance.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Although currently SRes.ExternalDatabaseRelease contains attributes named blast_file and blast_file_md5, they are unpopulated in CBIL's instance and it is unclear what they are used for, so the ability to load data into them is not provided here.
One of either --databaseName (as it appears in SRes.ExternalDatabase) or --databaseId must be provided as an argument to this plugin.  They are not listed as required because there is no way to specify conditional requirements.
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

  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });

  return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
    my ($self) = @_;

    my $dbName = $self->getArg('databaseName');
    my $dbVer = $self->getArg('databaseVersion'); 
    my $msg;

    $dbId = $self->getExtDbId($dbName);

    if ($self->releaseAlreadyExists($dbId)){
	$msg = "Not creating a new release Id for $dbName as there is already one for $dbName version $dbVer";
    }

    else{
	my $extDbRelId = $self->makeNewReleaseId($dbId);
	$msg = "Created new release id for $dbName with version $dbVer and release id $extDbRelId";
    }

    return $msg;
}

#######################################################################
# Subroutines
#######################################################################

# ---------------------------------------------------------------------
# releaseAlreadyExists
# ---------------------------------------------------------------------

sub releaseAlreadyExists{
    my ($self, $id) = @_;

    my $dbVer = $self->getArg('databaseVersion'); 

    my $sql = "select external_database_release_id 
               from SRes.ExternalDatabaseRelease
               where external_database_id = $id
               and version = '$dbVer'";

    my $sth = $self->prepareAndExecute($sql);
    my ($relId) = $sth->fetchrow_array();

    return $relId; #if exists, entry has already been made for this version

}

# ---------------------------------------------------------------------
# makeNewReleaseId
# ---------------------------------------------------------------------

sub makeNewReleaseId{
    my ($self, $id) = @_;
    my $dbVer = $self->getArg('databaseVersion'); 

    my $newRelease = GUS::Model::SRes::ExternalDatabaseRelease->new({
	external_database_id => $id,
	version => $dbVer,
	download_url => $self->getArg('downloadUrl'),
	id_type => $self->getArg('idType'),
	id_url => $self->getArg('idUrl'),
	secondary_id_type => $self->getArg('secondaryIdType'),
	secondary_id_url => $self->getArg('secondaryIdUrl'),
	description => $self->getArg('description'),
	file_name => $self->getArg('fileName'),
	file_md5 => $self->getArg('fileMd5'),
	
    });

    $newRelease->submit();
    my $newReleasePk = $newRelease->getId();

    return $newReleasePk;

}

# ---------------------------------------------------------------------
# getExtDbId
# ---------------------------------------------------------------------

sub getExtDbId{
    my ($self, $name, ) = @_;
	my $lcName = lc($name);
    my $sql = "select external_database_id from SRes.ExternalDatabase where lower(name) = '$lcName'";

    my $sth = $self->prepareAndExecute($sql);
   
    my ($id) = $sth->fetchrow_array();

    if (!($id)){
	$self->userError("no entry in SRes.ExternalDatabase for database $name");
    }
    else{
	return $id;
    }
}


1;

package GUS::GOPredict::Plugin::LoadGoAssoc;
@ISA = qw( GUS::PluginMgr::Plugin);
use CBIL::Bio::DbFfWrapper::GeneAssoc::Parser;

use lib "$ENV{GUS_HOME}/lib/perl";

use strict 'vars';

use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociation;
use GUS::Model::DoTS::GOAssocInstEvidCode;
use GUS::Model::Core::TableInfo;
use FileHandle;

# ---------------------------------------------------------------------- #
# ---------------------------------------------------------------------- #

sub new {
    
    my $class = shift;
    # create

    my $self = bless {}, $class;
    
    
    # initialize--for now do not override initialize in plugin.pm just set methods
    my $usage = 'loads associations of external sequences to GO terms into GUS';

    
    my $easycsp =
	[
	 {o=> 'go_version',
	  h=> 'version of GO Terms to download',
	  t=> 'string', 
	  r=> 1,
      },
	 {o=> 'flat_file',
	  h=> 'read data from this flat file.  If blank, read data from all gene_association files in filepath',
	  t=> 'string',
	  
      },
	 {o=> 'file_path',
	  h=> 'location of gene_association files to read',
	  t=> 'string',
	  r=> 1,
      },
	 
#	 {o => 'organism',
#	  h => 'what organism is the data for',
#	  t => 'string',
#	  r => 1,
#      },
	
	 {o => 'id_file',
	  h => 'read and append successfully processed ID here',
	  t => 'string',
	  r => 1,
      }
	 ];

    $self->initialize({requiredDbVersion => {},
		       cvsRevision => '$Revision$', # cvs fills this in!
		     cvsTag => '$Name$', # cvs fills this in!
		       name => ref($self),
		       revisionNotes => 'make consistent with GUS 3.0',
		       easyCspOptions => $easycsp,
		       usage => $usage
		       });


    
    #set private configuration data for this plugin
    
    

      
    $self->{ orgInfo } = {
	sgd => { id_col   => 'secondary_identifier', #yeast
		 id_tbl   => 'Dots.ExternalAASequence',
		 db_id    => [ 2794 ],
		 clean_id => sub { [ $_[ 0 ] ] },
		 assoc_meth    => 'getDBObjectId',
	     },
	fb  => { id_col   => 'source_id',
		 id_tbl   => 'Dots.ExternalAASequence',
		 db_id    => [ 2193, 144 ], #flybase, flybase
		 clean_id => sub { [ $_[ 0 ] ] },
		 assoc_meth    => 'getDBObjectId',
	     },
	wb  => { id_col   => 'source_id',
		 id_tbl   => 'Dots.ExternalAASequence',
		 db_id    => [ 145, 2993 ], #c. elegans, wormpep
		 clean_id => sub { $_[0] =~ s/WP\://g; [ $_[0] ]; },
		 assoc_meth    => 'getDBObjectSymbol',
	     },
	tair => { id_col   => 'source_id',
		  id_tbl   => 'Dots.ExternalAASequence',
		  db_id    => [ 2693 ], #arabdosis
		  clean_id => sub { [ $_[ 0 ] ] },
		  assoc_meth    => 'getDBObjectSymbol',
	      },
	mgi => { id_col   => 'source_id',
		 id_tbl   => 'Dots.ExternalAASequence',
		 db_id    => [ 22, 2893, 3093 ], #medline, swissprot, trembl
		 clean_id => sub { $self->{ maps }->{ mgi }->{ $_[ 0 ] } },
		 assoc_meth    => 'getDBObjectId',
	     },
	hum => { id_col   => 'source_id',
		 id_tbl   => 'Dots.ExternalAASequence',
		 db_id    => [2893, 3093 ], #swissprot, trembl
		 clean_id => sub { [ $_[ 0 ] ] },
		 assoc_meth    => "\t+",
	     },
	goa_sptr => { id_col => 'source_id',
		      id_tbl => 'Dots.ExternalAASequence',
		      db_id => [2893, 3093],
		      clean_id => sub { [ $_[ 0 ] ] },
		      assoc_meth => 'getDBObjectId',
		  },
    };
    
    # load mapping MGI: to SwissProt/TrEMBL
    {  
	my $fh = new FileHandle '<'. 'Mappings/MRK_SwissProt.rpt';
	while ( <$fh> ) {
	    chomp;
	    my @parts = split /\t/, $_;
	    my @id_sp = split /\s/, $parts[ 5 ];
	    $self->{ maps }->{ mgi }->{ $parts[ 0 ] } = \@id_sp;
	}
		
	$fh->close if $fh;
    }
    
    # return object.
    print STDERR "LoadGoAssoc::new() is finished \n";
    return $self;
}

# ---------------------------------------------------------------------- #
# ---------------------------------------------------------------------- #

sub isReadOnly { 0 }

#---------------------------------------------------------------------- #
# ---------------------------------------------------------------------- #

 
# ---------------------------------------------------------------------- #
# ---------------------------------------------------------------------- #

sub run {
    my $self = shift;
    
    # open the file
    # .................................................................
    print STDERR "beginning method LoadGoAssoc::run \n";
    use FileHandle;

    my $path = $self->getCla->{file_path};
    my $parser = CBIL::Bio::DbFfWrapper::GeneAssoc::Parser->new($path);


    my $fileName = $self->getCla->{flat_file};

    if ($fileName){
	$parser->loadFile($fileName);
    }
    else {
	$parser->loadAllFiles();
    }
    $parser->parseAllFiles();
        
    my $msg;
    
    $msg = $self->__load_associations($parser);
    
     
    # return value
     return $msg
}

# ---------------------------------------------------------------------- #
# ---------------------------------------------------------------------- #


sub __load_associations {
    my ($self, $parser) = @_;

    my $logFile;
    # get the list of sequences we've already annotated.
    #right now should be empty
    my $old_seqs = $self->__load_processed_sequences();
    
    my $id_file = $self->getCla->{id_file}; 
    if ($id_file){
	$logFile = FileHandle->new( '>>'. $self->getCla->{ id_file } ); 
    }
    # get the GO graph
    my $goGraph = $self->__load_go_graph( );
    
    # measure of progress
    my $termCount      = 0;
    my $ancestorCount  = 0;
    my $skipCount      = 0;
    my $oldCount       = 0;
    my $unknownCount   = 0;
    my $evidenceCount = 0;
   

    my $stores = $parser->getFileStores();
    foreach my $file (keys %$stores){
	my $fileStore = $stores->{$file};
	
	my $allEntries = $fileStore->getParsedEntries();
	my ($organism) = $file =~ /gene_association\.(\w+)$/;

	open (BIGLOG, ">>logs/pluginLog$organism") || die "pluginLog could not be opened";

	print STDERR "loading organism $organism\n";
	my $tempOrgInfo = $self->{orgInfo}->{$organism};
	my $assocMethod = $tempOrgInfo->{assoc_meth};
	
	#retrieve Ids for external info 
	my $allGusIds = $self->__get_sequence_id($organism, $allEntries);
	my $allEvdIds = $self->__get_evidence_ids($allEntries);
	my $evidenceMap = $self->__get_evidence_review_status_map();
	
	#get table id for table name that external sequences are in
	#for some reason need to have a GusRow subclass instantiated to do this
	my $tableIdGetter = GUS::Model::Core::TableInfo->new({});
	my $tableNameO = $tempOrgInfo->{id_tbl};
	$tableNameO =~ s/\./::/; 
	my $tableId = $tableIdGetter->getTableIdFromTableName($tableNameO);
	
	#convert file store into hash to be used by algorithm
	
	my $assocData = $self->__createAssocData($allEntries, $allGusIds, $assocMethod);
	
        
	#for each external sequence
	foreach my $key (keys %$assocData){
	    
	    print BIGLOG "loading association for $key\n";

	    my $goIds = $assocData->{$key}->{goTerms};
	    my $extSeqGusId = $assocData->{$key}->{extSeqGusId};
	    
	    my $ancestorsMade;
	    
	    unless ($goIds) {
		print BIGLOG "LoadAssoc:  no entry for key: $key";
	    }
	    
	    # reasons not to process this line
	    
	    if ( ! $extSeqGusId ){ 
		$skipCount++; next
		}
	    elsif ( $old_seqs->{ $key  } ) {
		$oldCount++; next
		}
	    
	    #for each go term associated with this external sequence
	    foreach my $goId (keys %$goIds){
		
		print BIGLOG "making association with GOTerm $goId \n";   
		# GUS id for this GO id
		my $goTermGusId = $goGraph->{ goToGus }->{ $goId };
		unless ( $goTermGusId ) {
		    $unknownCount++;
		    print BIGLOG "could not find goTermGusId for goId $goId $unknownCount \n";
		    next
		    }
		
		my @goAncestors = @{ $self->__get_ancestors( $goTermGusId, $goGraph ) };
		
		my $entry = $goIds->{$goId}->{entry};
		
		my $evdIds = $goIds->{$goId}->{evidence};
		#make association for the term itself
		
	        $evidenceCount += 
		    $self->__make_association( $entry, $tableId, $extSeqGusId, 
					       $goTermGusId, $evdIds, $evidenceMap, 
					       $organism, 1);
		$termCount++;
		
		if ($entry->getIsNot()){
		    $ancestorsMade->{$key}->{$goId} = -1; }
		else {$ancestorsMade->{$key}->{$goId} = 1;}
		
		
		#make association for terms on path to root.
		foreach my $goAncestor ( @goAncestors ) {
		    my $ancestorGoId = $goGraph->{gusToGo}->{$goAncestor};		
		    print BIGLOG "\t\tmaking ancestor association for $ancestorGoId and " . $entry->getDBObjectId . "\n";
		    
		    #don't make if already made from common descendant
		    #or if other descendant is 'isnot'
		    if ($ancestorsMade->{$key}->{$ancestorGoId} == 1){
			print BIGLOG "\t\t skipping this ancestor assignment as $key  mapped to $ancestorGoId is true\n";
			next;}
		    
		    $self->__make_association( $entry,
					       $tableId,
					       $extSeqGusId,
					       $goAncestor,
					       $evdIds,
					       $evidenceMap,
					       $organism,
					       0
					       );
		    $ancestorCount++;
		    
		    print BIGLOG "\t\t made ancestor\n";
		    if ($entry->getIsNot()){
			$ancestorsMade->{$key}->{$ancestorGoId} = -1; }
		    else {$ancestorsMade->{$key}->{$ancestorGoId} = 1;}	       
		} # end ancestor association
	    }  #end this go term    
	} #end this external sequence
	close BIGLOG;
    }#end this association file


#	print $fh_log $assocRow->{ id }, "\n" if $fh_log;
    

# return value
	"loaded: ". join( ', ',
			  "terms=$termCount",
			  "ancestors=$ancestorCount",
			  "old=$oldCount",
			  "unknown=$unknownCount",
			  "and skipped=$skipCount"
			  );
}


# ......................................................................

sub __make_association {
    
    my ($self, $entry, $tableId, $externalSeqGusId, $goTermGusId,  $evdIds, $evidenceMap, $organism, $defining) = @_; 
    
    open (ASSOCLOG, ">>logs/assocLog$organism") || die "assocLog could not be opened";
    open (AILOG, ">>logs/assocInstLog$organism") || die "assocInstLog could not be opened";
    
    my $evidenceCount = 0;
    my $orgInfo = $self->{ orgInfo }->{ $organism };
    my $extEvd = $entry->getEvidence();
    my $reviewStatus = $evidenceMap->{$extEvd}->{reviewStatus};
    
    my $dbs = $orgInfo->{db_id};
    my $is_not = $entry->getIsNot(); #test this with both cases;
    
    
    my $gusAssoc = GUS::Model::DoTS::GOAssociation->new( {
 	table_id => $tableId,
	row_id => $externalSeqGusId,
 	go_term_id => $goTermGusId,
 	is_not => $is_not, #make sure this works
 	review_status_id => $reviewStatus, 
 	defining=> $defining, 
    });
    
    my $gusAssocInst = GUS::Model::DoTS::GOAssociationInstance->new( {
 	external_database_release_id=> $dbs->[0], #take first db for now
 	is_not => $is_not,
 	review_status_id => $reviewStatus,
 	defining => $defining,
 	go_assoc_inst_loe_id => 1, #hardcoded for now
    });
    if ($defining){
	foreach my $evdId (keys %$evdIds){
	    my $evdCodeInst = $self->__make_evidence_code_inst($evdId, $evidenceMap);
	    $gusAssocInst->addChild($evdCodeInst);
	    $evidenceCount++;
	}
    }
    $gusAssoc->addChild($gusAssocInst); #big test
    
    print ASSOCLOG $gusAssoc->toString() . "\n";
    print AILOG $gusAssocInst->toString() . "\n";
    
    
    #$gusAssoc->submit() unless isReadOnly();
    $self->undefPointerCache();
    return $evidenceCount;
    #return $gusAssocInst;

}

# ......................................................................

sub __get_evidence_ids{
    my ($self, $assocData) = @_;
    print STDERR "running get_evidence_ids\n";
    my %evdIds = {};
    my $queryHandle = $self->getQueryHandle();
    my $sql =  
	"select go_evidence_code_id from SRes.GOEvidenceCode 
         where name = ?";
    my $sth = $queryHandle->prepare($sql);
    foreach my $key (keys %$assocData){
	my $entry = $assocData->{$key};
	my $evdName = $entry->getEvidence;
	$sth->execute($evdName);
	while (my ($evdId) = $sth->fetchrow_array()){
	    %evdIds->{$key} = $evdId;
	}
    }
    print STDERR "end get_evidence_ids\n";
    return \%evdIds;
}
	

sub __get_sequence_id {
    my ($self, $organism, $assocData) = @_;
    print STDERR "running LoadGoAssoc::get_sequence_id\n";
    # prepare SQL to get GUS id.
    my $orgInfo = $self->{ orgInfo }->{ $organism };
    my %gusIds = {};
    open (GETSEQID, ">>logs/getSeqLog") || die "getSeqLog could not be opened";


    my $queryHandle = $self->getQueryHandle();

    my $dbList = '( '. join( ', ', @{ $orgInfo->{ db_id } } ). ' )';
    my $assocMethod = $orgInfo->{assoc_meth};
    my $fromTbl = $orgInfo-> { id_tbl};
    my $whereCol = $orgInfo -> {id_col};

    my $prepareSql = "
                select aa_sequence_id 
                from $fromTbl 
                where external_database_release_id in $dbList
                and $whereCol in ?" ;
    my $sth = $queryHandle->prepare($prepareSql);
    
    foreach my $key (keys %$assocData){
	my $entry = $assocData->{$key};
	my $extId = $entry->$assocMethod;
	my @cleanIds =  @{$orgInfo->{ clean_id }-> ($extId)};
	my $cleanId = "(" . join (', ', @cleanIds) . ")";
#my $cleanId = $cleanIds[0];
	$sth->execute($cleanId);
	while (my ($gusId) = $sth->fetchrow_array()){
	    %gusIds->{$key}= $gusId;
	    
	    if ($gusId){
	       print GETSEQID "$extId, $cleanId, $gusId \n";
	    }
	    else{
		print GETSEQID "no GUS for $extId \n";
	    }
	}
    }

	#old version of plugin, clean id could be @.  Find out if this can really happen (mgi maybe?)

   #    return [] unless scalar @cleanId;
      #?
 # my $cleanId = join( ', ', map { "'$_'" } @cleanId );
    

    close (GETSEQID);
    # return value
    print STDERR "end get_sequence_id\n";
    return \%gusIds;
    }


# ......................................................................

sub __load_processed_sequences {
    my $self = shift;
    
    my $old_seqs = {};
    
    my $fh = FileHandle->new( '<'. $self->getCla ->{ id_file } );
    if ( $fh ) {
	while ( <$fh> ) {
	    chomp; 
	    $old_seqs->{ $_ } = 1 
	    }
	$fh->close;
    }
    
    # return the set
    return $old_seqs
    }

# ......................................................................

sub __load_go_graph {
    my ($self) = @_;
    print STDERR "Running LoadGoAssoc::load_go_graph";
    my $queryHandle = $self->getQueryHandle();
    # object to return
    my $graph;
    
    #temp output file for debugging:
#    open (GOGRAPH, ">>./goGraphLog") || die "go graph log could not be opened";
    my $goVersion = $self->getCla->{go_version};

    my $verSql = "
       select external_database_release_id 
       from Sres.externalDatabaseRelease
       where version = $goVersion
    ";

    my $sql = "

    select h.child_term_id, h.parent_term_id, f.go_id, f.name
      from SRes.GOTerm f, SRes.GORelationship h
     where f.go_term_id = h.child_term_id

  "; #and f.name <> 'root'
    
    # execute the SQL and get the graph
    my $sth = $queryHandle->prepareAndExecute($sql);
    while ( my ( $childId, $parentId, $childGoId, $name ) = $sth->fetchrow_array()) {
	
	# parent link for child
	$graph->{ childToParent }->{ $childId }->{ $parentId } = 1;
	  #print GOGRAPH "$parentId is parent of $childId\t";
	 
        # child link for parent
	$graph->{ parentToChild }->{ $parentId }->{ $childId } = 1;
	  #print GOGRAPH "$childId is child of $parentId\t";

	# map from (GUS) child to GO id
	$graph->{ gusToGo }->{ $childId } = $childGoId;
	#if we don't need the above then don't store it

	# map from GO id to (GUS) child
	$graph->{ goToGus }->{ $childGoId } = $childId;
	  #print GOGRAPH "GUS id of $childGoId is $childId\n"; 

	# name of function
	$graph->{ name }->{ $childId } = $name;
    }
#    close (GOGRAPH);
    # return value
    return $graph
    }

# ......................................................................

sub __get_ancestors {
    my ($self, $goTermGusId, $goGraph) = @_;

    # set (hash) of nodes on path to root.
    my $path;
    
    # breadth first queue
    my @queue = ( $goTermGusId );
    
    while ( my $nextTerm = shift @queue ) {
	foreach my $parentOfNextTerm ( keys %{ $goGraph->{ childToParent }->{ $nextTerm } }) {
	    next if $path->{ $parentOfNextTerm };
	    $path->{ $parentOfNextTerm } = 1;
	    push( @queue, $parentOfNextTerm );
	}
    }
    
    # return value;
    [ sort { $goGraph->{ gusToGo }->{ $a } <=> $goGraph->{ gusToGo }->{ $b } } keys %{ $path } ];
}


sub __make_evidence_code_inst{
    
    my ($self, $extEvd, $evidenceMap) = @_;
    open (EVDLOG, ">>logs/evdLog") || die "evdlog could not be opened";
    my $reviewStatus = $evidenceMap->{$extEvd}->{reviewStatus};
    my $realEvidGusCode = $evidenceMap->{$extEvd}->{evdGusId};
    
    my $evidCodeInst = GUS::Model::DoTS::GOAssocInstEvidCode->new ({
	go_evidence_code_id => $realEvidGusCode,
     	review_status_id => $reviewStatus,
    });
    print EVDLOG $evidCodeInst->toString();
    return $evidCodeInst;
}

sub __createAssocData{
    my ($self, $allEntries, $allGusIds, $assocMethod) = @_;
    my $assocData;
    foreach my $key (keys %$allEntries){
	my $entry = $allEntries->{$key};
	my $tempGoTerm = $entry->getGOId();
	
	my $tempEvd = $entry->getEvidence();
	my $newKey = $entry->$assocMethod;
	$assocData->{$newKey}->{goTerms}->{$tempGoTerm}->{evidence}->{$tempEvd} = 1;
	$assocData->{$newKey}->{goTerms}->{$tempGoTerm}->{entry} = $entry;
	#necessary to have a different entry each time because of is_not
	$assocData->{$newKey}->{extSeqGusId} = $allGusIds->{$key};
    }
    return $assocData;
}


sub __get_evidence_review_status_map {
    my ($self) = @_;
    my $queryHandle = $self->getQueryHandle();
    my $sql = "select name, go_evidence_code_id from sres.goevidencecode";
    my $sth = $queryHandle->prepareAndExecute($sql);
    my $evidenceMap;
    while (my ($name, $evdGusId) = $sth->fetchrow_array()){
	$evidenceMap->{$name}->{evdGusId} = $evdGusId;
    }
    
    $evidenceMap->{IC}-> {reviewStatus} = 1; 
    $evidenceMap->{IDA}->{reviewStatus} = 1;
    $evidenceMap->{IEA}->{reviewStatus} = 0;
    $evidenceMap->{IEP}->{reviewStatus} = 1,
    $evidenceMap->{IGI}->{reviewStatus} = 1;
    $evidenceMap->{IMP}->{reviewStatus} = 1;
    $evidenceMap->{IPI}->{reviewStatus} = 1;
    $evidenceMap->{ISS}->{reviewStatus} = 1;
    $evidenceMap->{NAS}->{reviewStatus} = 1;
    $evidenceMap->{ND}-> {reviewStatus} = 0;
    $evidenceMap->{TAS}->{reviewStatus} = 1;
    $evidenceMap->{NR}-> {reviewStatus} = 0;
    
    return $evidenceMap;
}






# ---------------------------------------------------------------------- #
# ---------------------------------------------------------------------- #

1;


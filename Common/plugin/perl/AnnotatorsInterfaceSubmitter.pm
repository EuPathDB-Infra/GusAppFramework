############################################################
# 01/06/03 JM ConvertPlugin for use with GUS30
# 08/07/00  SJD    Modified to support facts/evidence for 
#                  specific attributes in the special cases
#                  file.
#                  Added code to support GOFunction 
#                  assignment and ProteinGOFunction evidence
# 01/10/01 SJD     Modified for Oracle (dbi) and removed
#                  unnecessary database connection. Also,
#                  added setting of description for 
#                  Assembly when RNA desc is updated. 
############################################################

package GUS::Common::Plugin::AnnotatorsInterfaceSubmitter;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::Model::DoTS::Gene;
use GUS::Model::DoTS::RNA;

#need to add GO tables that will be used here

use GUS::Model::DoTS::Protein;
use GUS::Model::DoTS::GeneSynonym;
use GUS::Model::DoTS::MergeSplit;

use GUS::Model::Core::AlgorithmInvocation;

#use Objects::dbiperl_utils::DbiDatabase; ./GUS/ObjRelP/lib/perl/DbiDatabase.pm path changed to for GUS30:
use GUS::ObjRelP::DbiDatabase;


#$| = 1;

sub new {
	my ($class) = @_;
        my $self = {};
	bless ($self,$class);

        my $usage = 'Inserts information from the annotator\'s interface servlet to GUS.';


 my $easycsp = [
            { o => 'xmlfile',
              t => 'string',
              h => 'file containing xml to be parsed',

             },
	    { o => 'specialfile',
              t => 'string',
              h => 'file containing formatted text describing special cases',
	     },
             ];

        $self->initialize({

                     requiredDbVersion => {},
                     cvsRevision => '$Revision$', # cvs fills this in!
                     cvsTag => '$Name$', # cvs fills this in
                     name => ref($self),
                     revisionNotes => 'make consistent with GUS 3.0',
                     easyCspOptions =>$easycsp,
                     usage =>$usage                });

        return  $self;
}



sub run {
	my $self  = shift;
	open( F, $self->getCla->{'xmlfile'} ) || die($!);

	my @xml = <F>;

	close F;
	my $fact_hash= {};
	$fact_hash = $self->parseFactObjects($self->getCla->{'specialfile'}, $self->{self_inv});
	my $has_evidence = 0;
	my $remove = 0;

print STDERR "HERE";
	$self->getSelfInv->parseXML(\@xml);

	my @children = $self->getSelfInv->getAllChildren();
	my $curr_gene;


  if(!$self->getCla->{refresh}){

		foreach my $child ( @children ) {
			print STDERR "Child class name: ", $child->getClassName(), " \n";
			print STDERR "Concat prim key: " , $child->getConcatPrimKey(), "\n";
      if ($child->getClassName() eq "GUS::Model:DoTS::Gene"){
        $curr_gene = $child;  # save off the current gene...
      }
  		# add the evidence.
			if ( $fact_hash ) {
				# get all facts (hash) for the current object (based on prim key)
				# loop through all the attributes (again in a hash)
				# iterate through all facts for each attribute (an array)
				my $all_facts = $$fact_hash{$child->getConcatPrimKey()};
				foreach my $attribute (keys %$all_facts){
					print STDERR "\tEvidence for attribute ", $attribute, " pk: ", $child->getConcatPrimKey(), " \n";
					my $facts = $$all_facts{$attribute};
					foreach my $fact ( @$facts ) {
						if ( $fact ) {
							print STDERR "\t\tAdding fact: ", $fact->getClassName(), ", fact pk: ", $fact->getConcatPrimKey(), "\n";
							# was ignoring the similarity evidence cause throws error.
							if ($fact->getClassName() ne "GUS::Model::DoTS::Similarity"){
								$fact->review_status_id(1);
							}
              $child->addEvidence( $fact, 1, $attribute );
							$has_evidence = 1;
						}
					}
				}
			}
			print STDERR $child->getClassName(), " has evidence: ", $has_evidence, "\n";
      		# need to check that a copy does not already exist in db - i.e. for GeneSynonyms.  Will retreivefromDB work?  
			if ( !$child->hasChangedAttributes() ) {
				$remove = 1;
				print STDERR $child->getClassName(), " retrieved from database.\n";
			}
			if ( $has_evidence ) {
				$remove = 0;
			}

			if ( $remove ) {
				$self->getCla->{'self_inv'}->removeChild($child);
				print STDERR $child->getClassName(), " is not changed, not submitting to db.\n";
			} else {
				print STDERR $child->getClassName(), " IS changed, submitting to db.\n";
        if ($child->getClassName() ne "GUS::Model::DoTS::Assembly"){
          $child->setReviewStatusId(1);
        }
			}

			$has_evidence = 0;
			$remove = 0;
		}
	}

	# deal with deleted TS ids. They all will be added to a new TU which will be added to a new gene.
        # 1/0/03 just add deleted TSs to new gene GUS30 no transcript unit



        my( $deleted ) = $self->getDeletedTsIds( $self->getCla->{'specialfile'} );
	if ( $deleted ) {
		if ($self->getCla->{'debug'} ) {
			print STDERR "Deleted TS: ", join " ", @$deleted, "\n";
		}
		my $new_gene = $self->createEmptyGene();

                #1/06/03 modified createEmptyGene() subroutine
		# create a tu here.
		#my $new_tu = $new_gene->getChild("TranscriptUnit");
		# add TS objects to new empty gene as children.

  	        foreach my $tsid ( @$deleted ) {
			my %loadHash;
			$loadHash{'rna_id'} = $tsid;
			my $ts = GUS::Model::DoTS::RNA->new(\%loadHash);
      $ts->retrieveFromDB(1);
			$new_gene->addChild( $ts );
		}
    # NOTE: as per discussion 9/7 there will be NO entry made 
    # in MergeSplit when removing rnas from the cluster/gene.
    # MergeSplit will only be used when the old_id is deleted.
    #$ctx->{'self_inv'}->addChild( $new_tu );

       $self->getCla->{'self_inv'}->addChild( $new_gene );
	}


  # Now deal with the added RNAs.  The getAddedRNAObjects will return
  # a list ref of RNA objects.
  my $added_rnas = $self->getAddedRNAObjects( $self->getCla->{'specialfile'});
	if ( $added_rnas ) {
		foreach my $rna ( @$added_rnas ) {
   		$self->getCla->{'self_inv'}->addChild( $rna );  #add all rnas so will be submitted.
    }
  }

  #get the list of deleted genes so can create MergeSplit entries.
  #deleted genes implies the gene has been merged with the current gene.




 my( $del_genes ) = $self->getGeneAndTUIdsForAddedTSs($self->getCla->{'specialfile'} );

#HERE Check Query Handle


  # Add the MergeSplit entries if there are deleted genes.
  # this means that genes have been merged.
	if ( $del_genes ) {
    my $sth = $self->getCla->{'self_inv'}->getDb()->getQueryHandle()->prepareAndExecute("select max(merge_split_group_id)+1 from MergeSplit");
    if (my ($group_id) = $sth->fetchrow_array()){
      foreach my $del_gene ( @$del_genes ) {
        next if ( $del_gene == "" );
        my $merge_split = GUS::Model::DoTS::MergeSplit->new({'old_id' => $del_gene,
                                       'new_id' => $curr_gene->getGeneId(),
                                       'is_merge' => 1,
                                       'merge_split_group_id' => $group_id,
                                       'table_id' => $curr_gene->getTableIdFromTableName($curr_gene->getClassName())});
        $self->getCla->{'self_inv'}->addChild( $merge_split );
      }
    } else {
      print STDERR "AnnotatorsInterfaceSubmitter: Failed to obtain merge_split_group_id, could not insert into MergeSplit Table!\n";
    }
  }

        #Joan need to change this when GO tasks added back to interface
	# deal with the special deleted ProteinGOFunction objects here.
	my $pgfs = $self->getPGFDeleteObjects( $self->getCla->{'specialfile'});
	if ( $pgfs ) {
		foreach my $pgf ( @$pgfs ) {
			$pgf->markDeleted(1);
			$self->getCla->{'self_inv'}->addChild( $pgf );
		}
              }

	# deal with the special deleted PCR objects here.
	#my $pcrs = &getPCRDeleteObjects( $ctx->{'specialfile'});
        #	if ( $pcrs ) {
		#foreach my $pcr ( @$pcrs ) {
      #print STDERR "Deleted PCR:", $pcr->getProteinCellRoleId();
			#$pcr->markDeleted(1);
			#$ctx->{'self_inv'}->addChild( $pcr );
	#	}
	#   }

	# deal with the special deleted GeneSynonym objects here.
	my $gss = $self->getGeneSynonymDeleteObjects( $self->getCla->{'specialfile'});
	if ( $gss ) {
		foreach my $gs ( @$gss ) {
			$gs->markDeleted(1);
			$self->getCla->{'self_inv'}->addChild( $gs );
		}
              }

	# deal with adding pcrs newly to a TS - needs a new Protein.
#	my $new_pcrs = &getGetHashRefOfCellRolesNeedingAProtein( $ctx->{'specialfile'} );
 #  if ( $new_pcrs ) {
	#	foreach my $crid ( keys %{$new_pcrs} ) {
			#print STDERR "***Creating a new protein object for cell_role_id: $crid***\n";

		      #	my %loadHash;
		#	$loadHash{'rna_id'} = $$new_pcrs{$crid};
     # my $temp_r = RNA->new(\%loadHash);
	#		$temp_r->retrieveFromDB(1);

		#	my $p = &createEmptyProtein();
			#$temp_r->addChild( $p );
		#	undef %loadHash;

		#	my %loadHash2;
		#	$loadHash2{'cell_role_id'} = $crid;
		#	$loadHash2{'manually_reviewed'} = 0;
     # my $pcr_t = new ProteinCellRole(\%loadHash2);
	#		$p->addChild( $pcr_t );

		#	$ctx->{'self_inv'}->addChild( $temp_r );
	#	}
 #  }



	############################################################
	# Put loop here...remember to undefPointerCache()!
	############################################################


        $self->getCla->{'self_inv'}->submit(); #submit all but delete of gene(s) (not anymore) and tu(s)



	# now deal with deleting Gene and TU objects from added TSs.
	my $i;
	if ( $del_genes ) {
		foreach my $del_gene ( @$del_genes ) {
			next if ( $del_gene == "" );
			$i++;
		# then delete the Gene and TU objects, first the Gene
			my %loadHash;
			$loadHash{'gene_id'} = $del_gene;
      my $delete_gene = new GUS::Model::DoTS::Gene(\%loadHash);
			$delete_gene->retrieveFromDB(1);
			$delete_gene->markDeleted(1);

			# now the TU
			#undef %loadHash;
			#my %loadHash2;
			#$loadHash2{'transcript_unit_id'} = $$del_tus[$i];
			#print STDERR "Delete TU: ", $$del_tus[$i];
      #my $delete_tu = new TranscriptUnit(\%loadHash2);
	#		$delete_tu->retrieveFromDB(1);
	#		$delete_tu->markDeleted(1);
	#		$delete_tu->setParent( $delete_gene );

		        $delete_gene->submit(); # Now, delete the gene and tu 1/7/03 need just gene deleted now
                      }
              }

#try this

	$self->undefPointerCache();

	my $message;
	if ( $deleted ) {
		$message = "Deleted ", scalar @$deleted, " TS\'s: ", join " ", @$deleted, "\n";
		$message .= "Deleted gene";
	}
	return $message;

}

# gets a list ref of TS ids to be deleted.  Also get the gene_id and transcript_unit_id
# of the cluster containing the deleted ts's.  Returns 0 if there are none.
sub getDeletedTsIds {

        my $self = shift;

	my $file = shift;
	my $del_ts;
	open( SF, "$file" );
	while( <SF> ) {
		if ( $_ =~ s/delete ts\: // ) {
			if ( $_ =~ /\d/ ) {
				# i.e. we have some ids
				chomp;
				@$del_ts = split(/\s+/,$_);
			} else {
				return 0;
			}
		}
	}
	return $del_ts;
}

# 01/06/03 need to change sub for GUS30 new name sub getGeneForAddedTSs
# get full set of gene and tu ids for added tss.

sub getGeneAndTUIdsForAddedTSs {
#need this here now -check
        my $self = shift;

	my $file = shift;
	#my( $del_genes, $del_tus );

        my ($del_genes);
	my $ok;
	open( GTID, "$file" ) || die();
	while( <GTID> ) {
		if ( $_ =~ s/delete gene\: // ) {
			if ( $_ =~ /\d/ ) {
				chomp;
				@$del_genes = split(/\s+/,$_);
				print STDERR "Del genes in sub: ", @$del_genes, "\n";
				$ok = 1;
			}
		#} elsif ( $_ =~ s/delete transcript_unit\: // ) {
			#if ( $_ =~ /\d/ ) {
				#chomp;
				#@$del_tus = split(/\s+/,$_);
				#print STDERR "Del tus in sub: ", @$del_tus, "\n";
                 #     }
                      }
              }
	close GTID;
	if ( $ok ) {
		return( $del_genes);
	} else {
		return( 0 );
	}
     }

# get a list ref of the ProteinGOFunction objects to delete.
# Joan 1/9/03 need to come back to this when converting interface to handle GO Function updates

sub getPGFDeleteObjects {

  my( $file ) = @_;
	my $pgfs;
	open( PGFF, "$file" );
	while( <PGFF> ) {
		if ( $_ =~ s/deleted protein_go_function: // ) {
			if ( $_ =~ /\d/ ) {
				chomp;
				my @data = split(/\s+/,$_);
				foreach my $pgf_id ( @data ) {
					my %loadHash;
					$loadHash{'protein_go_function_id'} = $pgf_id;
          my $pgf = ProteinGOFunction->new(\%loadHash);
					$pgf->retrieveFromDB();
					push( @$pgfs, $pgf );
				}
			} else {
				return 0;
			}
		}
	}
	close PGFF;
	return $pgfs;
}

# get a list ref of the RNA objects to add.
sub getAddedRNAObjects {

  my $self = shift;
  my( $file ) = @_;
	my $rnas;
	open( SPEC, "$file" );
	while( <SPEC> ) {
		if ( $_ =~ s/add RNA: // ) {
			if ( $_ =~ /\d/ ) {
				chomp;
				my @data = split(/\s+/,$_);
				foreach my $set ( @data ) {
					my @data2 = split(/\|/,$set);
					my %loadHash;
				  #print STDERR "Adding RNA: ", $data2[0], "\n";

					$loadHash{'rna_id'} = $data2[0]; # the rna id being added

#this need to be setGeneIDforRNA have to get geneid from file (which now should only have gene_id)


	#my $transcript_unit_id = $data2[1]; # this is the new transcript_unit_id
        #file now has to have RNA_id|Gene_id ie add RNA: 36942532|gene_id
        my $gene_id = $data2[1]; # this is the new gene_id

                                        my $rna = GUS::Model::DoTS::RNA->new(\%loadHash);
					$rna->retrieveFromDB(); # get existing RNA entry
        #$rna->setTranscriptUnitId($transcript_unit_id); # update the tu id, no longer now need gene_id
         $rna->setGeneId ($gene_id);
					push( @$rnas, $rna );
				}
			} else {
				return 0;
			}
		}
	}
	close SPEC;
	return $rnas;
}




# get a list ref of the protein_cell_role objects to delete.
#sub getPCRDeleteObjects {
 # my ( $file )  = @_;
	#my $pcrs;
#	open( PCRF, "$file" );
	#while( <PCRF> ) {
		#if ( $_ =~ s/deleted protein_cell_role: // ) {
			#if ( $_ =~ /\d/ ) {
				#chomp;
			#	my @data = split(/\s+/,$_);
			#	foreach my $pcr_id ( @data ) {
				#	my %loadHash;
				#	$loadHash{'protein_cell_role_id'} = $pcr_id;
         # my $pcr = ProteinCellRole->new(\%loadHash);
		#			$pcr->retrieveFromDB();
			#		push( @$pcrs, $pcr );
			#	}
		#	} else {
			#	return 0;
		#	}
	#	}
#	}
#	close PCRF;
#	return $pcrs;
  #  }

# get list ref of GeneSynonym objects to delete.

sub getGeneSynonymDeleteObjects {

  my $self = shift;

  my( $file ) = @_;
	my $gss;
	open( SPEC, "$file" );
	while( <SPEC> ) {
		if ( $_ =~ s/delete_synonyms\: // ) {
			if ( $_ =~ /\d/ ) {
				chomp;
				my @data = split(/\s+/,$_);
				foreach my $id ( @data ) {
					my %loadHash;
          $loadHash{'gene_synonym_id'} = $id; 
          my $gs = GUS::Model::DoTS::GeneSynonym->new(\%loadHash);
					$gs->retrieveFromDB();
					push( @$gss, $gs );
				}
			} else {
				return 0;
			}
		}
	}
	close SPEC;
	return $gss;
}

# get list ref of RNA objects to add.
# hash ref with keys pcr ids, vals is rna id?
#sub getGetHashRefOfCellRolesNeedingAProtein {
	#my $file = shift;
	#my %hash;
	#open PCH, "$file" || die($!);
	#my $x;
	#while( <PCH> ) {
		#if ( $_ =~ s/added pcr\|rna\: // ) {
			#$x = 1;
			#chomp;
			#my @data = split(/\s+/,$_);
			#foreach ( @data ) {
				#my @spl = split(/\|/,$_);
				#$hash{$spl[0]} = $spl[1];
		#	}
	#	}
	#}
#	close PCH;
	#if ( $x ) {
		#return \%hash;
#	} else {
	#	return 0;
#	}
#  }

# returns a hash ref with fact object as value and primary_key as key.
sub parseFactObjects {

     my $self = shift;

     my ($file, $ai) = @_;


	my $hash;
	open( FF, "$file" ) || die($!);
	my $ready = 0;
	my $id;
	my @xml;
	my $table;
	my $attribute;

	while( <FF> ) {
		if ( $_ =~ /^FACTS\:/ ) {
			$ready = 1;
			next;
		}
		if ( $_ =~ /^ENDFACTS/ ) {
			$ready = 0;
		}
		if ( $ready ) {
			#if ( $_ !~ /\</ ) { # not part of the xml so must be pk and possibly attribute.
			if ( $_ =~ /^Evidence:/ ) { # not part of the xml so must be pk and possibly attribute.
				if ( @xml ) {
					$ai->parseXML(\@xml);
					print STDERR "XML: @xml\n";
					undef @xml;
					foreach my $child ( $ai->getAllChildren() ) {
						push( @{$$hash{$id}{$attribute}}, $child );
						print STDERR "AI child: ", $child->getClassName(), "\n";
					}
					$ai->removeAllChildren();  #WHY?
				}
				$attribute = "";
				if ($_ =~ /^(.*)\s(.*)\s(.*)\n/){
					$table = $1;
					$id = $2;
					$attribute = $3;
				} else { #no attribute specified - must be evidence for entire row.
					$_ =~ /^(.*)\s(.*)\n/;
					$table = $1;
					$id = $2;
				}
				next;
			} else {
				push @xml, $_;
			}
		} 
	}
	if ( @xml ) {
		$ai->parseXML(\@xml);
		print STDERR "XML: @xml\n";

		foreach my $child ( $ai->getAllChildren() ) {
			push( @{$$hash{$id}{$attribute}}, $child );
			#push( @{$$hash{$id}}, $child );
			print STDERR "AI child: ", $child->getClassName(), "\n";
		}
		$ai->removeAllChildren();
	}
	return $hash;
}


#01/06/03 modified subroutine
sub createEmptyProtein {

        my $self = shift;
	my $protein = GUS::Model::DoTS::Protein->new({'is_reference' => 0,														'review_status_id' => 0 });
	return $protein;
}

#01/06/03 modified subroutine

  sub createEmptyGene {

  my $self = shift;

  my $gene = GUS::Model::DoTS::Gene->new({'is_reference' => 0,
                        'review_status_id' => 0 });


  ##add a transcriptUnit no longer applicable
  #$gene->addChild(TranscriptUnit->new({'is_reference' => 0,
  #                                    'manually_reviewed' => 0 }));
  return $gene;
}

1;
__END__

=pod
=head1 Description
B<Template> - a template plug-in for C<ga> (GUS application) package.

=head1 Purpose
B<Template> is a minimal 'plug-in' GUS application.

=cut



    

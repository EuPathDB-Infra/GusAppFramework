package GUS::Common::Plugin::LoadBlastSimFast;
@ISA = qw(GUS::PluginMgr::Plugin); 
use strict;

use FileHandle;
use CBIL::Util::Disp;

use GUS::Model::DoTS::Protein;
use GUS::Model::DoTS::ExternalAASequence;
use GUS::Model::DoTS::ExternalNASequence;

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $usage = 'Load a set of BLAST similarities from a file in the form generated by generateBlastSimilarity.pl.';

  my $easycsp =
    [{o => 'file',
      t => 'string',
      h => 'read condensed results from this file',
      r => 1,
     },
     {o => 'subjectTable',
      t => 'string',
      h => 'subjects are taken from this table (schema::table format).',
      r => 1,
     },
     {o => 'queryTable',
      t => 'string',
      h => 'queries are taken from this table (schema::table format). ',
      r => 1,
     },
     {o => 'batchSize',
      t => 'int',
      h => 'Number of spans to write in one transaction',
      d => 1000,
     },
     {o => 'noHSPs',
      t => 'boolean',
      h => 'if true, load only subject summaries, not HSPs',
      d => 0,
     },
     {o => 'testnumber',
      t => 'int',
      h => 'number of queries to process for testing',
     },
     {o => 'restartAlgInvs',
      t => 'string',
      h => 'a comma delimited list of row_alg_invocation_ids.  Queries in the input file which have rows in the Similarity table marked with one or more of these row_alg_invocation_ids will be ignored',
     },
     {o => 'subjectsLimit',
      t => 'int',
      h => 'maximum number of subjects to load per query'
     },
     {o => 'hspsLimit',
      t => 'int',
      h => 'maximum number of hsps to load per subject'
     },
     {o => 'minSubjects',
      t => 'int',
      h => 'reject queries with less than this number of subjects'
     },
     {o => 'maxSubjects',
      t => 'int',
      h => 'reject queries with more than this number of subjects'
     },
     {o => 'subjectPvalue',
      t => 'float',
      h => 'reject subjects with pvalues greater than this'
     },
     {o => 'subjectPctIdent',
      t => 'float',
      h => 'reject subjects with percent identity less than this'
     },
     {o => 'subjectMatchLength',
      t => 'int',
      h => 'reject subjects with match length less than this'
     },
     {o => 'hspPvalue',
      t => 'float',
      h => 'reject HSPs with pvalues greater than this'
     },
     {o => 'hspPctIdent',
      t => 'float',
      h => 'reject HSPs with percent identity greater than this'
     },
     {o => 'hspMatchLength',
      t => 'int',
      h => 'reject HSPs wth match length less than this'
     },
    ];

  $self->initialize({requiredDbVersion => {},
		     cvsRevision => '$Revision$', # cvs fills this in!
		     cvsTag => '$Name$', # cvs fills this in!
		     name => ref($self),
		     revisionNotes => 'initial writing',
		     easyCspOptions => $easycsp,
		     usage => $usage,
		     queryTable   => undef,
		     subjectTable => undef,
		    });
  return $self;
}

$| = 1;

sub run {
  my ($self) = @_;

  my $args = $self->getArgs();
  my $algInv = $self->getAlgInvocation();
  my $dbh = $self->getDb()->getDbHandle();

  $self->{queryTable}   = $args->{queryTable};
  $self->{subjectTable} = $args->{subjectTable};
  
  my $query_tbl_id = $algInv->getTableIdFromTableName($args->{queryTable});
  my $subj_tbl_id = $algInv->getTableIdFromTableName($args->{subjectTable});

  $self->logArgs();
  $self->logCommit();

  print "Testing on $args->{testnumber} queries\n" if $args->{testnumber};

  my %ignore = &handleRestart($args->{restartAlgInvs}, $dbh);

  my $fh  = $args->{file} =~ /\.gz$|\.Z$/ ?
    FileHandle->new("zcat $args->{file}|") : FileHandle->new("$args->{file}");

  die "Can't open file $args->{file}" unless $fh;

  $self->{queryCount} = 0;
  $self->{subjectCount} = 0;
  $self->{spanCount} = 0;
  $self->{ignoredQueries} = 0;
  $self->{filteredQueries} = 0;
  $self->{filteredSubjects} = 0;
  $self->{filteredHSPs} = 0;

  my $eof;
  while(!$eof) {
    my $subjects;
    ($subjects, $eof) = $self->parseQueries($fh, $args->{batchSize}, \%ignore, $args,
					    $args->{testnumber});
    $self->insertSubjects($self->getDb(), $subjects, $query_tbl_id, $subj_tbl_id);
  }
}

sub handleRestart {
  my ($restartAlgInvs, $dbh) = @_;

  my %ignore;
  if ($restartAlgInvs) {
    my $query = "select distinct query_id from dots.Similarity where row_alg_invocation_id in ($restartAlgInvs)";
    print "Restarting: Querying for the ids to ignore\n$query\n";
    my $stmt = $dbh->prepare($query);
    $stmt->execute()|| die $stmt->errstr;
    while ( my($id) = $stmt->fetchrow_array()) {
      $ignore{$id} = 1;
    }
    print "Ignoring ".scalar(keys%ignore)." entries\n";
  }
  return %ignore;
}

sub parseQueries {
  my ($self, $fh, $batchSize, $ignore, $filter, $testnumber) = @_;

  my $batchSpanCount = 0;

  my @subjects;
  my $eof;
  while ($batchSpanCount < $batchSize) {
    if ($testnumber && $self->{queryCount} >= $testnumber) {
      $eof = 1;
      last;
    }
    my ($queryId, $spanCount, $querySubjects);
    ($queryId, $spanCount, $querySubjects, $eof) = $self->parseQuery($fh, $filter);
    last if $eof;
    if ($ignore->{$queryId}) {
      $self->{ignoredQueries} += 1;
      next;
    }
    $batchSpanCount += $spanCount;
    push(@subjects, @$querySubjects);
  }
  return (\@subjects, $eof);
}

sub parseQuery {
  my ($self, $fh, $filter) = @_;

  my @subjects;
  my $spanCount;
  my $subjectsLimit = $filter->{subjectsLimit};
  my $maxSubjects = $filter->{maxSubjects};
  my $maxSubjects = $filter->{maxSubjects};
  my $pvalueF = $filter->{subjectPvalue};
  my $pctIdentF = $filter->{subjectPctIdent};
  my $matchLengthF = $filter->{subjectMatchLength};

  my $queryLine = <$fh>;
  while ($queryLine && (not $queryLine =~ /^\>/)) {
    $queryLine = <$fh>;
  }

  my $queryPK;
  if ($queryLine) {
    #>99929462 (2 subjects)
    $queryLine =~ /^\>*(\S+)\s\((\d+)/ || die "Invalid query line: '$_'\n";

    $queryPK = $1;
    my $subjCount = $2;

    # filter query
    my $filterQuery = ($filter->{maxSubjects} && $subjCount > $filter->{maxSubjects})
      || ($filter->{minSubjects} && $subjCount < $filter->{minSubjects});

    if ($filterQuery) {
      $self->{filteredQueries} += 1;
    } else {
      $self->{queryCount} += 1 unless $subjCount == 0;
    }

    my $c = 0;
    while ($c++ < $subjCount) {
      my ($subjSpanCount, $subject) = $self->parseSubject($fh, $queryPK, $filter);

      next if ($filterQuery);

      # filter subject
      if (($subjectsLimit && $c > $subjectsLimit)
	  || ($pvalueF && $subject->{pvalue} > $pvalueF)
	  || ($pctIdentF
	      && $subject->{number_identical}/$subject->{total_match_length}*100 <$pctIdentF)
	  || ($matchLengthF && $subject->{total_match_length} < $matchLengthF)) {
	$self->{filteredSubjects} += 1;
	next;
      }

      $spanCount += $subjSpanCount;
      push(@subjects, $subject);
    }
  }
  return ($queryPK, $spanCount, \@subjects, !$queryLine);
}

sub parseSubject {
  my ($self, $fh, $queryPK, $filter) = @_;

#  Sum: 13058520:483:4e-49:1:193:175:642:2:290:126:172:0:+1

  my $sumLine = <$fh>;

  my @vals = split(/:/, $sumLine);
  die "invalid Sum line: '$sumLine'\n" unless $vals[0] =~ /Sum/;
  die "invalid Sum line (wrong number of columns):  '$sumLine'\n" unless scalar @vals == 13;

  my %subj;
  $subj{query_id} = $queryPK;
  $subj{subject_id} = $vals[1];
  
  $subj{score} = $vals[2];
  $subj{pvalue} = $vals[3];
  ($subj{pvalue_mant}, $subj{pvalue_exp}) = split(/e/, $subj{pvalue});
  $subj{pvalue_mant} = 1 unless $subj{pvalue_mant} ;
  $subj{pvalue_exp} = 1 unless $subj{pvalue_exp} ;
  $subj{min_subject_start} = $vals[4];
  $subj{max_subject_end} = $vals[5];
  $subj{min_query_start} = $vals[6];
  $subj{max_query_end} = $vals[7];
  $subj{number_of_matches} = $vals[8];
  $subj{total_match_length} = $vals[9];
  $subj{number_identical} = $vals[10];
  $subj{number_positive} = $vals[11];
  $subj{is_reversed} = $vals[12];
  $subj{reading_frame} = $vals[13];
  $subj{reading_frame} =~ s/\D//g;   # get rid of (+-)

  my $hspsLimit = $filter->{hspsLimit};
  my $pvalueF = $filter->{hspPvalue};
  my $pctIdentF = $filter->{hspPctIdent};
  my $matchLengthF = $filter->{hspMatchLength};

  my $c = 0;
  my @subjSpans;
  while ($c++ < $subj{number_of_matches}) {
    my $span = &parseSpan($fh, $filter);

    # filter
    if (($hspsLimit && $c > $hspsLimit) 
	|| ($pvalueF && $span->{pvalue} > $pvalueF)
	|| ($pctIdentF
	    && $span->{number_identical}/$span->{match_length}*100 < $pctIdentF)
	|| ($matchLengthF && $span->{match_length} < $matchLengthF)) {
      $self->{filteredHSPs} += 1;
      next;
    }


    push(@subjSpans, $span);
  }
  $subj{spans} = \@subjSpans;



  return ($subj{number_of_matches}, \%subj);
}

sub parseSpan {
  my ($fh, $filter) = @_;

#   HSP1: 13058520:84:108:156:483:4e-49:1:155:175:642:0:+1

  my $pvalueF = $filter->{hspPvalue};
  my $pctIdentF = $filter->{hspPctIdent};
  my $matchLengthF = $filter->{hspMatchLength};
  my $spanLine = <$fh>;

  my @vals = split(/:/, $spanLine);
  die "invalid HSP line: '$spanLine'\n" unless $vals[0] =~ /HSP/;
  my $columnCount = scalar @vals;
  die "invalid HSP line (wrong number of columns, have $columnCount , should be 13):  '$spanLine'\n" unless $columnCount == 12;

  my %span;
  $span{number_identical} = $vals[2];
  $span{number_positive} = $vals[3];
  $span{match_length} = $vals[4];
  $span{score} = $vals[5];
  ($span{pvalue_mant}, $span{pvalue_exp}) = split(/e/, $vals[6]);
  $span{pvalue_mant} = 1 unless $span{pvalue_mant} ;
  $span{pvalue_exp} = 1 unless $span{pvalue_exp} ;
  $span{subject_start} = $vals[7];
  $span{subject_end} = $vals[8];
  $span{query_start} = $vals[9];
  $span{query_end} = $vals[10];
  $span{is_reversed} = $vals[11];
  $span{reading_frame} = $vals[12];
  $span{reading_frame} =~ s/\D//g;   # get rid of (+-)

  return \%span
}

# insert a batch of subjects (with their spans)
sub insertSubjects {
  my ($self, $db, $subjects, $query_table_id, $subj_table_id) = @_;

  my $simStmt = $self->getInsertSubjStmt($db->getDbHandle(), $query_table_id,$subj_table_id);

  my $spanStmt = $self->getInsertSpanStmt($db);

  my $nextvalSql = $db->getDbPlatform()->nextValSelect("dots.similarity");

  my $nextIdStmt = $db->getDbHandle()->prepare($nextvalSql);

  my $verbose = $self->getArgs()->{verbose};
  my $noHSPs = $self->getArgs()->{noHSPs};

  foreach my $s (@$subjects) {

    my $simPK = &getNextId($nextIdStmt);

    next if (scalar @{$s->{spans}} == 0);

    # Get query & subject objects GUS PK if necessary

    my $queryTable   = $self->{queryTable};
    my $subjectTable = $self->{subjectTable};
    
    my $query_id = $s->{query_id};
    
    # Get rid of the spaces
    $query_id =~ s/\s//g;
    
    if (not $query_id =~ /^\d+$/) {
      # must be the sequence entry identifier, get the GUS PK then
      my $queryobj = $queryTable->new ({'name' => $query_id});
      my $is_in = $queryobj->retrieveFromDB;
      
      if (! $is_in) {
	die "can't get the GUS entry for query, $query_id!\n";
      }
      else {
	$s->{query_id} = $queryobj->getId;
      }
	
    }
    
    my $subject_id = $s->{subject_id};
    
    # Get rid of the spaces
    $subject_id =~ s/\s//g;
    
    if (not $subject_id =~ /^\d+$/) {
      # must be the sequence entry identifier, get the GUS PK then
      my $subjectobj = $subjectTable->new ({'name' => $subject_id});
      my $is_in = $subjectobj->retrieveFromDB;
      
      if (! $is_in) {
	die "can't get the GUS entry for subject, $subject_id!\n";
      }
      else {
	$s->{subject_id} = $subjectobj->getId;
      }
    }
    
    my @simVals = ($simPK, $s->{subject_id}, $s->{query_id},
		   $s->{score}, undef,
		   $s->{pvalue_mant}, $s->{pvalue_exp},
		   $s->{min_subject_start}, $s->{max_subject_end},
		   $s->{min_query_start}, $s->{max_query_end},
		   $s->{number_of_matches}, $s->{total_match_length},
		   $s->{number_identical}, $s->{number_positive},
		   $s->{is_reversed}, $s->{reading_frame});

    $simStmt->execute(@simVals) || die $simStmt->errstr;
    $self->log("Inserting Similarity: ", @simVals) if $verbose;

    $self->{subjectCount} += 1;
    if (!$noHSPs) {
      foreach my $span (@{$s->{spans}}) {
	my @spanVals = ($simPK, $span->{match_length},
			$span->{number_identical}, $span->{number_positive},
			$span->{score},  undef,
			$span->{pvalue_mant}, $span->{pvalue_exp},
			$span->{subject_start}, $span->{subject_end},
			$span->{query_start}, $span->{query_end},
			$span->{is_reversed}, $span->{reading_frame});
	$spanStmt->execute(@spanVals) || die $spanStmt->errstr;
	$self->log("Inserting SimilaritySpan: ", @spanVals) if $verbose;
	$self->{spanCount} += 1;
      }
    }

  }

  # Sum it all up in a message for the log and AlgInv.result
  my $summaryMessage = "$self->{queryCount} Queries parsed.  Inserted $self->{subjectCount} subj, $self->{spanCount} hsp.  Filtered $self->{filteredQueries} q, $self->{filteredSubjects} subj, $self->{filteredHSPs} hsp.  Restart past $self->{ignoredQueries} q";

  $self->log($summaryMessage);
  $self->setResultDescr($summaryMessage);

  if ($self->getArgs()->{commit}) {
    print STDERR "Committing\n";
    $db->getDbHandle()->commit();
  } else {
    $db->getDbHandle()->rollback();
    print STDERR "Rolling back\n";
  }
}

sub getInsertSubjStmt {
  my ($self, $dbh, $query_tbl_id, $subj_tbl_id) = @_;

  my $algInvId = $self->getAlgInvocation()->getId();
  my $rowUserId = $self->getAlgInvocation()->getRowUserId();
  my $rowGroupId = $self->getAlgInvocation()->getRowGroupId();
  my $rowProjectId = $self->getAlgInvocation()->getRowProjectId();

  my $sql =
"insert into dots.Similarity Values " .
"(?, $subj_tbl_id, ?, $query_tbl_id, ?, " .
#score, bit_score_summary, pvalue_mant, pvalue_exp, min_subject_start,
"?,     ?,                 ?,           ?,          ?, " .
#min_subject_end, min_query_start, min_query_end, number_of_matches
"?,               ?,               ?,             ?, " .
#total_match_length, number_identical, number_positive, is_reversed, reading_fr
"?,                  ?,                ?,               ?,           ?, ".
" null, SYSDATE, 1, 1, 1, 1, 1, 0, $rowUserId, $rowGroupId, $rowProjectId, $algInvId)";

  return $dbh->prepare($sql);
}

sub getInsertSpanStmt {
  my ($self, $db) = @_;

  my $algInvId = $self->getAlgInvocation()->getId();
  my $rowUserId = $self->getAlgInvocation()->getRowUserId();
  my $rowGroupId = $self->getAlgInvocation()->getRowGroupId();
  my $rowProjectId = $self->getAlgInvocation()->getRowProjectId();


  my $nextVal = $db->getDbPlatform()->nextVal("dots.SimilaritySpan");


  my $sql = 
"insert into dots.SimilaritySpan Values " .
#similarity_span_id, similarity_id, match_length, number_identical,
"($nextVal,                  ?,             ?,            ?, ".
#number_positive, score, bit_score, pvalue_mant, pvalue_exp,
"?,               ?,     ?,         ?,           ?,".
#subject_start, subject_end, query_start, query_end,
"?,             ?,           ?,           ?, " .
#is_reversed, reading_frame
"?,           ?, ".
"SYSDATE, 1, 1, 1, 1, 1, 0, $rowUserId, $rowGroupId, $rowProjectId, $algInvId)";
  return $db->getDbHandle()->prepare($sql);
}

sub getNextId {
  my ($nextIdStmt) = @_;
  $nextIdStmt->execute();
  while ((my $result) = $nextIdStmt->fetchrow_array()) {
    $nextIdStmt->finish();
    return $result;
  }
}

1;


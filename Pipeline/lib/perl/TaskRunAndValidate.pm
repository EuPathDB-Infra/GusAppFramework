package GUS::Pipeline::TaskRunAndValidate;

##############################################################################
# Subroutines that run and validate Liniac DistribJob Tasks
#
# These subroutines are designed to be called by a script which:
#   - is provided as the 'jobcmd' arg to submitPipelineJob
#   - is therefore called by submitPipelineJob (on the liniac)
#   - will run one or more tasks (ie, is a mini-pipeline on the liniac)
#   - by virtue of using the subroutines, may safely be restarted
#
# The subroutines provides these services:
#   - check for the prior existence of a task's output 
#   - if found, validate it
#   - only run the task if no valid prior output found
#   - after running a task, validate its output, and return validation status
#   - print to the log the details of what is happening, including validation
#
# This allows you to create a script which runs a pipeline of tasks,
# where subsequent tasks depend on the valid results of previous steps.
# Steps whose valid input exists can run; those without don't run.  After
# you correct the problems in the failed tasks, you can safely run the whole
# script again and only tasks which haven't completed run again.
#
# Assumes a "pipelineDir" with the following structure:
#  pipelineDir/
#    seqfiles/                (where input seq files are)
#    logs/                    (where logs go)
#    tasktype/                (eg, repeatmask, matrix, similarity)
#      name_of_dataset/       (eg, seqs-nrdb)
#        input/               (input for liniac run)
#          controller.prop
#          task.prop     
#        master/              (the master dir for the distribjob run)
##############################################################################

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(runRepeatMask runMatrix runSimilarity runGenomeAlign); 

use strict;
use Carp;

sub runRepeatMask {
    my ($pipelineDir, $name) = @_;
    
    print "\nRunning repeatmask on $name\n";

    my $resultFile = 
	"$pipelineDir/repeatmask/$name/master/mainresult/blocked.seq";
    my $errFile = 
	"$pipelineDir/repeatmask/$name/master/mainresult/blocked.err";
    my $inputFile = "$pipelineDir/seqfiles/$name.fsa";
    my $propFile = "$pipelineDir/repeatmask/$name/input/controller.prop";

    my $valid = 0;
    if (-e $resultFile || -e $errFile) {
	print "  previous result found\n";
	$valid = &validateRM($inputFile, $resultFile, $errFile);
	if (!$valid) {
	    print "  trying again...\n";
	}
    }
    if (!$valid) {
	&run($propFile, "$pipelineDir/logs/$name.mask.log", $resultFile);
	$valid = &validateRM($inputFile, $resultFile, $errFile);
	if  (!$valid) {
	    print "  please correct failures (delete them from failures/ when done), and set restart=yes in $propFile\n";
	}
    }

    return $valid;
}

sub runGenomeAlign {
    my ($pipelineDir, $queryName, $subjectName) = @_;
    
    my $name = "$queryName-$subjectName";
    print "\nRunning alignment of $queryName against $name\n";

    my $resultDir = 
	"$pipelineDir/genome/$name/master/mainresult/";
    # TODO: handle the case when query is not from repeatmask
    #       (i.e. final DoTS minus troublesome deflines)
    my $queryFile = 
	"$pipelineDir/repeatmask/$queryName/master/mainresult/blocked.seq";
    my $subjectDir = "$pipelineDir/seqfiles/$subjectName";
    my $propFile = "$pipelineDir/genome/$name/input/controller.prop";
    my $logFile = "$pipelineDir/logs/$name.genomealign.log";

    my $valid = 0;
    # TODO: validate previous results

    if (!$valid) {
	&run($propFile, $logFile);
	# TODO: validate results
    }

    return $valid;
}

sub runMatrix {
    my ($pipelineDir, $queryname, $subjectname) = @_;
    
    my $name = "$queryname-$subjectname";
    print "\nRunning blastmatrix on $name\n";

    my $resultFile = 
	"$pipelineDir/matrix/$name/master/mainresult/blastMatrix.out";
    my $inputFile = 
	"$pipelineDir/repeatmask/$queryname/master/mainresult/blocked.seq";
    my $propFile = "$pipelineDir/matrix/$name/input/controller.prop";
    my $logFile = "$pipelineDir/logs/$name.matrix.log";

    my $valid = 
      &runMatrixOrSimilarity($resultFile, $inputFile, $propFile, $logFile);

    return $valid;
}

sub runSimilarity {
    my ($pipelineDir, $queryname, $subjectname) = @_;
    
    my $name = "$queryname-$subjectname";
    print "\nRunning blastsimilarity on $name\n";

    my $resultFile = 
	"$pipelineDir/similarity/$name/master/mainresult/blastSimilarity.out";
    my $inputFile = 
	"$pipelineDir/seqfiles/$queryname.fsa";
    my $propFile = "$pipelineDir/similarity/$name/input/controller.prop";
    my $logFile = "$pipelineDir/logs/$name.sim.log";

    my $valid = 
      &runMatrixOrSimilarity($resultFile, $inputFile, $propFile, $logFile);

    return $valid;
}

sub runMatrixOrSimilarity {
    my ($resultFile, $inputFile, $propFile, $logFile) = @_;
    
    my $valid = 0;
    
    my $propfile = "$pipelineDir/similarity/$name/input/controller.prop";
    
  if (-e $resultFile) {
	print "  previous (unzipped) result found\n";
	$valid = &validateBM($inputFile, $resultFile);
	if (!$valid) {
	    print "  trying again...\n";
	}
    }

    if (-e "${resultFile}.gz") {
	print "  previous (zipped) result found\n";
	$valid = &validateBM($inputFile, "${resultFile}.gz");
	if (!$valid) {
	  print "  trying again...\n";
	  print "  unzipping ${resultFile}.gz\n";
	  my $cmd = "gunzip ${resultFile}.gz";
	  my $status = system($cmd);
	  die "failed running '$cmd' with stderr:\n $!" if ($status >> 8);
	}
    }

    if (!$valid) {
	&runAndZip($propFile,$logFile, $resultFile);
	my $valid = &validateBM($inputFile, "${resultFile}.gz");
	if  (!$valid) {
	    print "  please correct failures (delete them from failures/ when done), and set restart=yes in $propFile\n";
	}
    }

}

sub validateRM {
    my ($inputFile, $blockedFile, $errFile) = @_;

    print "  validating...\n";

    if (! -e $blockedFile) {
	print "  INVALID  ($blockedFile not found)\n";
	return 0;
    }

    if (! -e $errFile) {
	print "  INVALID  ($errFile not found)\n";
	return 0;
    }

    my $blockedCount = &countSeqs($blockedFile);
    my $errCount = &countSeqs($errFile);
    my $inputCount = &countSeqs($inputFile);
    my $missing = $inputCount - ($blockedCount + $errCount);
    if ($missing) {
	print "  INVALID (in: $inputCount blocked: $blockedCount reject: $errCount diff: $missing)\n";
	return 0;
    }
    print "  valid\n";
    return 1;
}

sub validateBM {
    my ($inputFile, $resultFile) = @_;

    print "  validating...\n";

    if (! -e $resultFile) {
	print "  INVALID  ($resultFile not found)\n";
	return 0;
    }

    my $inputCount = &countSeqs($inputFile);
    my $resultCount = &countSeqs($resultFile);
    my $missing = $inputCount - $resultCount;

    if ($missing) {
	print "  INVALID (in: $inputCount result: $resultCount diff: $missing)\n";
	return 0;
    }
    print "  valid\n";
    return 1;
}

sub runAndZip {
  my ($propFile, $logFile, $resultFile) = @_;

  my ($cmd, $status);

  $cmd = "liniacjob $propFile >& $logFile";
  $status = system($cmd);
  &confess ("failed running '$cmd' with stderr:\n $!") if ($status >> 8);

  print "  zipping $resultFile...\n";
  
  $cmd = "gzip $resultFile";
  $status = system($cmd);
  die "failed running '$cmd' with stderr:\n $!" if ($status >> 8);
}

sub run {
  my ($propFile, $logFile, $resultFile) = @_;

  my ($cmd, $status);

  $cmd = "liniacjob $propFile >& $logFile";
  $status = system($cmd);
  die "failed running '$cmd' with stderr:\n $!" if ($status >> 8);

}

sub countSeqs {
    my ($file) = @_;

    if ($file =~ /.gz/) {
      open(F, "zcat $file |") || die "Couldn't open file $file";
    } else {
      open(F, $file) || die "Couldn't open file $file";
    }
    my $c =0;
    while(<F>) {
	$c++ if /\>/;
    }
    close(F);
    return $c;
}

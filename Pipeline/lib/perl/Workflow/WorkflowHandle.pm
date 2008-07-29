package GUS::Pipeline::Workflow::WorkflowHandle;

@ISA = qw(GUS::Pipeline::Workflow::Base);
use strict;
use GUS::Pipeline::Workflow::Base;

##
## lite workflow object (handle on workflow row in db) used in three contexts:
##  - quick reporting of workflow state
##  - reseting the workflow
##  - workflowstep command changing state of a step
##
## (it avoids the overhead and stringency of parsing and validating
## all workflow steps)

# very light reporting of state of workflow
sub reportState {
  my ($self) = @_;

  $self->getDbState();

  print "
Workflow '$self->{name} $self->{version}'
workflow_id:           $self->{workflow_id}
state:                 $self->{state}
process_id:            $self->{process_id}
start_time:            $self->{start_time}
end_time:              $self->{end_time}
allowed_running_steps: $self->{allowed_running_steps}
\n\n";
}


sub getDbState {
  my ($self) = @_;
  if (!$self->{workflow_id}) {
    $self->{name} = $self->getWorkflowConfig('name');
    $self->{version} = $self->getWorkflowConfig('version');
    my $sql = "
select workflow_id, state, process_id, start_time, end_time, allowed_running_steps
from apidb.workflow
where name = '$self->{name}'
and version = '$self->{version}'
";
    ($self->{workflow_id}, $self->{state}, $self->{process_id},
     $self->{start_time}, $self->{end_time}, $self->{allowed_running_steps})
      = $self->runSqlQuery_single_array($sql);
    $self->error("workflow '$self->{name}' version '$self->{version}' not in database")
      unless $self->{workflow_id};
  }
}

sub getId {
  my ($self) = @_;

  $self->getDbState();
  return $self->{workflow_id};
}

sub runCmd {
    my ($self, $cmd) = @_;

    my $output = `$cmd`;
    my $status = $? >> 8;
    $self->error("Failed with status $status running: \n$cmd") if ($status);
    return $output;
}

1;

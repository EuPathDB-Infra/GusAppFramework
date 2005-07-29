#  $Revision$   $Date$   $Author$

package GUS::Community::FileTranslator::Functions;

sub new {
  my ($M) = @_;
  my $self = {};
  bless $self,$M;
  
  return $self;
}

sub coordGenePix2RAD{
  my ($self, $n_ar, $n_ac, $n_gr, $n_gc, $n_sr, $n_sc) = @_;
  my $mapping;
  
  for (my $ar=1; $ar<=$n_ar; $ar++) {
    for (my $ac=1; $ac<=$n_ac; $ac++) {
      for (my $gr=1; $gr<=$n_gr; $gr++) {
        for (my $gc=1; $gc<=$n_gc; $gc++) {
          for (my $sr=1; $sr<=$n_sr; $sr++) {
            for (my $sc=1; $sc<=$n_sc; $sc++) {
              my $b = ($ar-1)*$n_ac*$n_gr*$n_gc+($gr-1)*$n_ac*$n_gc+($ac-1)*$n_gc+$gc;
              $mapping->{"$b\t$sr\t$sc"} = "$ar\t$ac\t$gr\t$gc\t$sr\t$sc";
            }
          }
        }
      }
    }
  }
  return $mapping;
}

sub coordArrayVision2RAD{
  my ($self, $n_ar, $n_ac, $n_gr, $n_gc, $n_sr, $n_sc) =@_;
  my $mapping;

  if ($n_ar==1 && $n_ac==1 && $n_gr==1 && $n_gc==1) {
    for (my $sr=1; $sr<=$n_sr; $sr++) {
      for (my $sc=1; $sc<=$n_sc; $sc++) {
        $mapping->{"$sr - $sc"} = "1\t1\t1\t1\t$sr\t$sc";
        # below are 2 safety nets
        $mapping->{"1 - 1 : $sr - $sc"} = "1\t1\t1\t1\t$sr\t$sc";
        $mapping->{"1 - 1 : 1 - 1 : $sr - $sc"} = "1\t1\t1\t1\t$sr\t$sc";
      }
    }
  }
  elsif ($n_ar==1 && $n_ac==1) {
    for (my $gr=1; $gr<=$n_gr; $gr++) {
      for (my $gc=1; $gc<=$n_gc; $gc++) {
        for (my $sr=1; $sr<=$n_sr; $sr++) {
          for (my $sc=1; $sc<=$n_sc; $sc++) {
            $mapping->{"$gr - $gc : $sr - $sc"} = "1\t1\t$gr\t$gc\t$sr\t$sc";
            # below is a safety net
            $mapping->{"1 - 1 : $gr - $gc : $sr - $sc"} = "1\t1\t$gr\t$gc\t$sr\t$sc";
          }
        }
      }
    }
  }
  else {
    for (my $ar=1; $ar<=$n_ar; $ar++) {
      for (my $ac=1; $ac<=$n_ac; $ac++) {
        for (my $gr=1; $gr<=$n_gr; $gr++) {
          for (my $gc=1; $gc<=$n_gc; $gc++) {
            for (my $sr=1; $sr<=$n_sr; $sr++) {
              for (my $sc=1; $sc<=$n_sc; $sc++) {
                $mapping->{"$ar - $ac : $gr - $gc : $sr - $sc"} = "$ar\t$ac\t$gr\t$gc\t$sr\t$sc";
              }
            }
          }
        }
      }
    }
  }
  return $mapping;
}

1;
__END__

=head1 GUS::Community::FileTranslator::Functions

=head2 Methods

=head3 sub new();

 Purpose:
  Creates a new instance of GUS::Community::FileTranslator::Functions
 Returns:
  GUS::Community::FileTranslator::Functions object instance.

=head3 sub coordGenePix2RAD($num_array_rows, $num_array_columns, $num_grid_rows, $num_grid_columns, $num_sub_rows, $num_sub_columns);

 Purpose:
  Creates a hash for the mapping of GenePix coordinates (Block, Row, Columns) to RAD coordinates (array_row, array_column, grid_row, grid_column, sub_row, sub_column), using information on the array layout.
 Returns:
  A reference to a hash whose keys are tab-delimited triplets of GenePix coordinates and whose values are tab-delimited 6-ples of RAD coordinates.

=head3 sub coordArrayVision2RAD($num_array_rows, $num_array_columns, $num_grid_rows, $num_grid_columns, $num_sub_rows, $num_sub_columns);

 Purpose:
  Creates a hash for the mapping of ArrayVision Spot Labels column (with dashes and colons) to RAD coordinates (array_row, array_column, grid_row, grid_column, sub_row, sub_column), using information on the array layout.
 Returns:
  A reference to a hash whose keys are the strings in the Spot Labels column of an ArrayVision output file and whose values are tab-delimited 6-ples of RAD coordinates.

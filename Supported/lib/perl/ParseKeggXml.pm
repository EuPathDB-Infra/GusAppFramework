#!/usr/bin/perl

# =================================================
# Package ParseKeggXml
# =================================================

package GUS::Supported::ParseKeggXml;

# =================================================
# Documentation
# =================================================

=pod

=head1 Description

Parses a KeggXML File and returns a hash that stores 
the pathway relationships

=cut

# =================================================
# Pragmas
# =================================================

use strict;

# =================================================
# Includes
# =================================================

use Data::Dumper;
use FileHandle;
use XML::LibXML;
use File::Basename;
# =================================================
# Package Methods
# =================================================

# -------------------------------------------------
# Subroutine: parseKGML
# Description: parses a kegg xml file
# Inputs: the filename
# Outputs: a hash data structure that stores
#          the kegg entries, relations and reactions
# -------------------------------------------------

sub new {
  my ($class) = @_;
  my $parser = new XML::LibXML;
  my $self = {parser => $parser};
  bless($self, $class);
  return $self;
}



sub parseKGML {
  my ($self, $filename) = @_;

  my ($pathway, $nodeEntryMapping);

  if (!$filename) {
   die "Error: KGML file not found!";
  }

  #initialize parser
  # ===================================
  my $parser = $self->{parser};
  my $doc = $parser->parse_file($filename);
  my $rid = 0;


  # get pathway name and id info
  # ===================================
  my @nodes = $doc->findnodes('/pathway');

  $pathway->{SOURCE_ID} = $nodes[0]->getAttribute('name');
  $pathway->{NAME} = $nodes[0]->getAttribute('title');
  $pathway->{URI} = $nodes[0]->getAttribute('link');
  $pathway->{IMAGE_FILE} = basename($nodes[0]->getAttribute('image'));
  $pathway->{NCOMPLEXES} = 0;
  

  # get "entries"
  # ===================================
  @nodes = $doc->findnodes('/pathway/entry');
  foreach my $entry (@nodes) {
    my $type = $entry->getAttribute('type');
 

    my $enzymeNames = $entry->getAttribute('name');
    $enzymeNames =~ s/ec:|cpd:|dr://g;
    $nodeEntryMapping->{$entry->getAttribute('id')} = $enzymeNames;

    my @nodeIds = split(/ /,$enzymeNames);

    foreach my $id (@nodeIds) {
      # Here $id needs to include X and Y positions (be unique)

      my @graphicsNode = $entry->getChildrenByTagName('graphics');

      foreach my $gn (@graphicsNode) {
       my $gnName = $gn->getAttribute('name');
       my ($xPosition, $yPosition) = ($gn->getAttribute('x'), $gn->getAttribute('y'));
       my $uniqId = $id . "_X:" . $xPosition . "_Y:" . $yPosition;

      $pathway->{NODES}->{$uniqId}->{SOURCE_ID} = $id;
      $pathway->{NODES}->{$uniqId}->{UNIQ_ID} = $uniqId;
      $pathway->{NODES}->{$uniqId}->{TYPE} = $type;
      $pathway->{NODES}->{$uniqId}->{ENTRY_ID} = $entry->getAttribute('id');
      $pathway->{NODES}->{$uniqId}->{REACTION} = $entry->getAttribute('reaction');
      $pathway->{NODES}->{$uniqId}->{LINK} = $entry->getAttribute('link');

       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{NAME} = $gn->getAttribute('name');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{FGCOLOR} = $gn->getAttribute('fgcolor');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{BGCOLOR} = $gn->getAttribute('bgcolor');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{TYPE} = $gn->getAttribute('type');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{X} = $gn->getAttribute('x');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{Y} = $gn->getAttribute('y');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{WIDTH} = $gn->getAttribute('width');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{HEIGHT} = $gn->getAttribute('height');
       $pathway->{NODES}->{$uniqId}->{GRAPHICS}->{LINECOORDS} = $gn->getAttribute('coords');
      }


    }  # end entries
  }
 
  # read in the relations
  # ===================================

  my @relations = $doc->findnodes('/pathway/relation');

  foreach my $relation (@relations) {
    my $type = $relation->getAttribute('type');
 
    my $rtype = "Protein-Protein"; # if type = PPrel
    $rtype = "Enzyme-Enyzme" if $type eq "ECrel";
    $rtype = "Gene Expression" if $type eq "GErel";
    $rtype = "Protein-Compound" if $type eq "PCrel";
    $rtype = "Maplink" if $type eq "maplink";

    my $entryId = $relation->getAttribute('entry1');
    my $associatedEntryId =  $relation->getAttribute('entry2');
    my $entry = $pathway->{ENTRY}->{$entryId};
    my $associatedEntry = $pathway->{ENTRY}->{$associatedEntryId};
    my @entries = ($entryId);
    my @associatedEntries = ($associatedEntryId);

    my @subtype = $relation->getChildrenByTagName('subtype');  
 
    foreach my $e (@entries) {
      foreach my $a (@associatedEntries) {
	if (!defined $subtype[0]) {
	  $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{ENTRY} = $e;
	  $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{ASSOCIATED_ENTRY} = $a;
	  $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{INTERACTION_TYPE} = $rtype;
	  $rid++;
	}
	else {
	  foreach my $st (@subtype) {
	    $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{ENTRY} = $e;
	    $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{ASSOCIATED_ENTRY} = $a;
	    $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{INTERACTION_TYPE} = $rtype;
	    $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{INTERACTION_ENTITY} = $st->getAttribute('name');
	    $pathway->{RELATIONS}->{$rtype}->{"Relation".$rid}->{INTERACTION_ENTITY_ENTRY} = $st->getAttribute('value');
	    $rid++;
	  }
	}
     }
    }
 
 
  } #end relations

  # read in the reactions
  # ===================================

 my @reactions = $doc->findnodes('/pathway/reaction');

  foreach my $reaction (@reactions) {

      #a complex reaction key to uniquely identify an 'Interaction'. To be noted that a single reaction can have multiple interactions
      #like substrateA <-> Enzyme1 <-> ProductA and SubstrateA <->EnzymeB <-> ProductA
      #which is a single reaction in KEGG but two separate network interactions
      my $reactionName = $reaction->getAttribute('id')."_".$reaction->getAttribute('name');

      my @enzymes = split(/ /,$reaction->getAttribute('id'));

      my (@substrates, @products);

      my @substrate = $reaction->getChildrenByTagName('substrate');
      foreach my $sbstr (@substrate) {
        my $substrId = $sbstr->getAttribute('id');
        my $name = $sbstr->getAttribute('name');
        $name =~ s/ec:|cpd:|dr://g;
        push (@substrates,({ENTRY => $substrId, NAME => $name}));
      } 

      my @product = $reaction->getChildrenByTagName('product');
      foreach my $prd (@product) {
        my $prdId = $prd->getAttribute('id');
        my $name = $prd->getAttribute('name');
        $name =~ s/ec:|cpd:|dr://g;
        push (@products, ({ENTRY => $prdId, NAME => $name}));
      }

      $pathway->{REACTIONS}->{$reactionName} = {PRODUCTS => [@products],
                                                SUBSTRATES => [@substrates],
                                                ENZYMES => [@enzymes],
                                                NAME => $reaction->getAttribute('name'),
                                                TYPE => $reaction->getAttribute('type')};
  }

  #print  Dumper $pathway;
  return $pathway;
}  # end parseKeggXml


# =================================================
# End Module
# =================================================
1; 

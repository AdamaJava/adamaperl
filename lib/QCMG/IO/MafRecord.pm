package QCMG::IO::MafRecord;

###########################################################################
#
#  Module:   QCMG::IO::MafRecord
#  Creator:  John V Pearson
#  Created:  2010-02-12
#
#  Data container for a MAF (Mutation Annotation Format) record as
#  specified by NCI and used by TCGA and the QCMG/Baylor/OICR ABO
#  collaboration.
#
#  $Id$
#
###########################################################################

use strict;
use warnings;

use Carp qw( carp croak confess );
use Data::Dumper;
use Memoize;
use vars qw( $SVNID $REVISION $VALID_HEADERS $VALID_AUTOLOAD_METHODS );

use QCMG::Util::QLog;

( $REVISION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
( $SVNID ) = '$Id$'
    =~ /\$Id:\s+(.*)\s+/;

our $AUTOLOAD;  # it's a package global

BEGIN {
    # According to the NCI guidelines, MAF headers must match one of the
    # following lists (dependent on version) exactly including case.
    # Any difference will cause the MAF to not validate.  QCMG should
    # endeavour to make NCI-compliant MAFs (see wiki for links).

    my @v_1 = qw( 
           Hugo_Symbol Entrez_Gene_Id GSC_Center NCBI_Build Chromosome
           Start_Position End_Position Strand
           Variant_Classification Variant_Type
           Reference_Allele Tumor_Seq_Allele1 Tumor_Seq_Allele2
           dbSNP_RS dbSNP_Val_Status
           Tumor_Sample_Barcode Matched_Norm_Sample_Barcode
           Match_Norm_Seq_Allele1 Match_Norm_Seq_Allele2
           Tumor_Validation_Allele1 Tumor_Validation_Allele2
           Match_Norm_Validation_Allele1 Match_Norm_Validation_Allele2
           Verification_Status Validation_Status Mutation_Status
           Validation_Method Sequencing_Phase );
    my @v_2 = qw( 
           Hugo_Symbol Entrez_Gene_Id Center NCBI_Build Chromosome
           Start_Position End_Position Strand
           Variant_Classification Variant_Type
           Reference_Allele Tumor_Seq_Allele1 Tumor_Seq_Allele2
           dbSNP_RS dbSNP_Val_Status
           Tumor_Sample_Barcode Matched_Norm_Sample_Barcode
           Match_Norm_Seq_Allele1 Match_Norm_Seq_Allele2
           Tumor_Validation_Allele1 Tumor_Validation_Allele2
           Match_Norm_Validation_Allele1 Match_Norm_Validation_Allele2
           Verification_Status Validation_Status Mutation_Status
           Sequencing_Phase Sequence_Source Validation_Method
           Score BAM_File Sequencer );

    $VALID_HEADERS = {
       '1.0'   => \@v_1,
       '2.0'   => \@v_2,
       '2.1'   => \@v_2,
       '2.2'   => \@v_2,
       '2.4.1' => \@v_2,
    };

    # The version-specific headers are doubly important to use because
    # we are going to use them to create a hashref ($VALID_AUTOLOAD_METHODS)
    # that will hold the names of all the methods that we will try to handle
    # via AUTOLOAD.  We are using AUTOLOAD because with a little planning,
    # it lets us avoid defining and maintaining a lot of basically identical
    # accessor methods.

    $VALID_AUTOLOAD_METHODS = {
       '1.0' => {},
       '2.0' => {},
       '2.1' => {},
       '2.2' => {},
    };

    foreach my $version (keys %{$VALID_HEADERS}) {
        foreach my $method (@{$VALID_HEADERS->{$version}}) {
            $VALID_AUTOLOAD_METHODS->{$version}->{$method} = 1;
        }
    }

}

###########################################################################
#                             PUBLIC METHODS                              #
###########################################################################


sub new {
    my $class  = shift;
    my %params = @_;

    croak "no version parameter to new()" unless
        (exists $params{version} and defined $params{version});
    croak "no data parameter to new()" unless
        (exists $params{data} and defined $params{data});
    croak "no headers parameter to new()" unless
        (exists $params{headers} and defined $params{headers});

    my $self = { maf_version   => $params{version},
                 extra_fields  => [],
                 verbose       => $params{verbose} || 0 };
    bless $self, $class;

    my $dcount = scalar @{$params{data}};
    my $hcount = scalar @{$params{headers}};
    carp "data [$dcount] and header [$hcount] counts do not match" 
        if ($dcount != $hcount and $self->verbose);

    # These are the expected headers
    my @headers = @{ $VALID_HEADERS->{$params{version}} };

    # Copy the expected fields across first
    foreach my $ctr (0..(scalar(@headers)-1)) {
        if (! defined $params{headers}->[$ctr]) {
            carp "Empty header value in column [$ctr] - ignoring data"
                if $self->verbose;
            next;
        }
        $self->{ $params{headers}->[$ctr] } = $params{data}->[$ctr];
    }

    # We have to keep a track of any extra fields by name and we are
    # going to copy them into the hash with an 'opt_' prefix to prevent
    # any collisions with "real" columns (already seen this!)
    if ($hcount > scalar(@headers)) {
        foreach my $ctr (scalar(@headers)..($hcount-1)) {
            if (! defined $params{headers}->[$ctr]) {
                carp "Empty header value in column [$ctr] - ignoring data"
                    if $self->verbose;
                next;
            }
            $self->{ 'opt_'.$params{headers}->[$ctr] } = $params{data}->[$ctr];
            push @{ $self->{extra_fields} }, $params{headers}->[$ctr];
        }
    }

    return $self;
}


sub AUTOLOAD {
    my $self  = shift;
    my $value = shift || undef;

    my $type       = ref($self) or confess "$self is not an object";
    my $invocation = $AUTOLOAD;
    my $method     = undef;
    my $version    = $self->{maf_version};

    if ($invocation =~ m/^.*::([^:]*)$/) {
        $method = $1;
    }
    else {
        croak "QCMG::IO::MafRecord AUTOLOAD problem with [$invocation]";
    }

    # We don't need to report on missing DESTROY methods.
    return undef if ($method eq 'DESTROY');

    croak "QCMG::IO::MafRecord can't access method [$method] via AUTOLOAD"
        unless (exists $VALID_AUTOLOAD_METHODS->{$version}->{$method});

    # If this is a setter call then do the set
    if (defined $value) {
        $self->{$method} = $value;
    }
    # Return current value
    return $self->{$method};

}  


# Return a list of all extra columns
sub extra_fields {
    my $self = shift;
    return @{ $self->{extra_fields} };
}


# Add a new "extra" field.  Also check whether the field already exists.
sub add_extra_field {
    my $self  = shift;
    my $field = shift;

    # Create hgash of current extra fields
    my %current_fields = ();
    $current_fields{$_} = 1 foreach  @{ $self->{extra_fields} };

    # Add field if it's not already in our hash
    push @{ $self->{extra_fields} }, $field unless (exists $current_fields{$field});
}


sub to_text {
    my $self    = shift;
    my $ra_opts = shift;

    my @columns = @{ $VALID_HEADERS->{$self->{maf_version}} };
    my @values  = map { $self->{ $_ } } @columns;

    # Don't forget extra fields if any.  This is complicated because in
    # most cases we are outputting lots of MAF records to a file so if
    # the MAF records have different extra columns or they are in a
    # different order, we will output a chaotic mess.  The safest way to
    # handle this is to force the user to supply a list of any extra columns
    # they want output.

    if (defined $ra_opts) {
        foreach my $opt (@{ $ra_opts }) {
             # If this record does not have a value for the requested
             # extra column then we need to still output a blank
             # field so the spacing is preserved.
             my $val = ( exists $self->{ 'opt_'.$opt } and
                         defined $self->{ 'opt_'.$opt } ) ?
                       $self->{ 'opt_'.$opt } : '';
             push @values, $val;
        }
    }

    return join("\t",@values);
}


sub verbose {
    my $self = shift;
    return $self->{verbose} = shift if @_;
    return $self->{verbose};
}


sub version {
    my $self = shift;
    return $self->{version};
}


sub extra_field {
    my $self = shift;
    my $type = shift;

    # We will need to implement set and get

    if (@_) {
        my $val = shift;
        $self->{'opt_'.$type} = $val;
        #push @{ $self->{extra_field} }, $type;
        return $val;
    }
    else {
        # Check for existence;
        if (exists $self->{'opt_'.$type}) {
            return $self->{'opt_'.$type};
        }
        else {
            return undef;
        }
    }
}


sub allele_freq {
    my $self = shift;

    # Return a 6-element arrayref:
    # 1. Reference Alelle
    # 2. Variant Allele
    # 3. Reference Allele count in Normal
    # 4. Variant Allele count in Normal
    # 5. Reference Allele count in Tumour
    # 6. Variant Allele count in Tumour

    my $return = { ref_allele              => '',
                   var_allele              => '',
                   ref_allele_normal_count => 0,
                   var_allele_normal_count => 0,
                   ref_allele_tumour_count => 0,
                   var_allele_tumour_count => 0 };

    $return->{ref_allele} = $self->Reference_Allele;
    $return->{var_allele} = ($self->Tumor_Seq_Allele1 ne $return->{ref_allele})
                            ? $self->Tumor_Seq_Allele1 
                            : $self->Tumor_Seq_Allele2; 

    # This is what the ND/TD fields look like:
    #G:94[37.88],7[38.43],T:1[39],0[0]   A:37[35.95],3[36],G:102[36.91],6[38]

    my $pattern = '([ACGTN]{1}):(\d+)\[[\d.]+\],(\d+)\[[\d.]+\]';
    my $normal = $self->extra_field('ND');
    my %normal = ();
    while ($normal =~ /$pattern/g) {
        #print "normal   $1 : $2 : $3  -  $normal\n";
        $normal{ $1 } = $2+$3;
    }
    my $tumour = $self->extra_field('TD');
    my %tumour = ();
    while ($tumour =~ /$pattern/g) {
        #print "tumour   $1 : $2 : $3  -  $tumour\n";
        $tumour{ $1 } = $2+$3;
    }

    $return->{ref_allele_normal_count} =
        (defined $normal{ $return->{ref_allele} })
            ? $normal{ $return->{ref_allele} } : 0;
    $return->{var_allele_normal_count} =
        (defined $normal{ $return->{var_allele} })
            ? $normal{ $return->{var_allele} } : 0;

    $return->{ref_allele_tumour_count} =
        (defined $tumour{ $return->{ref_allele} })
            ? $tumour{ $return->{ref_allele} } : 0;
    $return->{var_allele_tumour_count} =
        (defined $tumour{ $return->{var_allele} })
            ? $tumour{ $return->{var_allele} } : 0;

    return [ $return->{ref_allele},
             $return->{var_allele},
             $return->{ref_allele_normal_count},
             $return->{var_allele_normal_count},
             $return->{ref_allele_tumour_count},
             $return->{var_allele_tumour_count} ];
}


# undef = unable to make decision
# 0 = is not a CpG
# 1 = is a CpG

sub is_cpg {
    my $self = shift;

    # Exit immediately for non-SNP mutations
    return undef unless ($self->Variant_Type eq 'SNP');

    # Exit immediately if CPG column is not available
    my $cpg_seq = $self->extra_field( 'CPG' );
    return undef unless (defined $cpg_seq);

    # Assume CPG has 11 bases - the SNP plus 5 bases before and after so
    # if we don't have 11 then we must be an indel or MNP or something
    # weird so we exit.
    return undef unless (length($cpg_seq) == 11);

    # Check that the reference is in the correct place
    my $ref = $self->Reference_Allele;
    if (substr($cpg_seq,5,1) ne $ref) {
        warn "Reference allele [$ref] does not match base 6 of CPG field [$cpg_seq]\n";
        return undef;
    }

    # If we got this far then it is time to make a decision about the
    # CPG-ness of this SNP
 
    if ($ref eq 'C') {
        # If base after C is G, is CpG
        return (substr($cpg_seq,6,1) eq 'G') ? 1 : 0;
    }
    elsif ($ref eq 'G') {
        # If base before G is C, is CpG
        return (substr($cpg_seq,4,1) eq 'C') ? 1 : 0;
    }
    else {
        return 0;
    }
}


sub snp_mutation {
    my $self = shift;

    # This routine returns the following values:
    # 1. 'MNP' for substitutions of greater than one base (DNP, TNP etc)
    # 2. a string of the form 'Ref -> Alt' for SNPs, e.g 'A -> C'
    # 3. undef for anything else including indels

    my $id   = $self->Tumor_Sample_Barcode;
    my $gene = $self->Hugo_Symbol;
    my $var  = $self->Variant_Type;
    my $refl = length($self->Reference_Allele);

    # Code 'MNP' for DNP/TNP/ONP
    my $type = undef;
    if ($var =~ /^.NP$/ and $refl > 1) {
        #warn "found an MNP : $id $gene $var($refl)\n";
        $type = 'MNP';
    }
    elsif ($var eq 'SNP') {
        # This code handles the standard SNP case
        $type = $self->Reference_Allele .' -> ';
        if ($self->Tumor_Seq_Allele1 ne $self->Reference_Allele and
            $self->Tumor_Seq_Allele2 ne $self->Reference_Allele and
            $self->Tumor_Seq_Allele1 ne $self->Tumor_Seq_Allele2) {
            # If this is a weird case, warn and skip to next record
            qlogprint( {l=>'WARN'}, "patient $id in gene $gene has an unusual".
                       " SNV variant: $type ". $self->Tumor_Seq_Allele1 .'/'.
                       $self->Tumor_Seq_Allele2 .
                       " - record dropped from further analyses\n" );
            return undef;
        }
        elsif ($self->Tumor_Seq_Allele1 ne $self->Reference_Allele) {
            $type .= $self->Tumor_Seq_Allele1;
        }
        elsif ($self->Tumor_Seq_Allele2 ne $self->Reference_Allele) {
            $type .= $self->Tumor_Seq_Allele2;
        }
    }

    # Indels and other weird cases should fall through and so return
    # undef which is the behaviour we rely on elsewhere so DO NOT place
    # an else{ die; } at the end of the conditional block above!

    return $type;
}


sub categorise_jones {
    my $self = shift;

    my $var = $self->Variant_Type;
    my $snp = $self->snp_mutation;

    # Return immediately for indels and MNPs
    if ($var eq 'INS' or $var eq 'DEL') {
        return 'indel';
    }
    elsif ($snp eq 'MNP') {
        return 'MNP';
    }

    # For SNPs we must have both type and cpg.  Also not that is_cpg()
    # will barf on MNPs so they must be handled before this check.
    #return undef unless (defined $type and defined $cpg);

    my $code = undef;
    if ($snp eq 'C -> T' or $snp eq 'G -> A') {
        $code= 'C:G to T:A';
    }
    elsif ($snp eq 'C -> G' or $snp eq 'G -> C') {
        $code = 'C:G to G:C';
    }
    elsif ($snp eq 'C -> A' or $snp eq 'G -> T') {
        $code = 'C:G to A:T';
    }
    elsif ($snp eq 'T -> C' or $snp eq 'A -> G') {
        $code = 'T:A to C:G';
    }
    elsif ($snp eq 'T -> G' or $snp eq 'A -> C') {
        $code = 'T:A to G:C';
    }
    elsif ($snp eq 'T -> A' or $snp eq 'A -> T') {
        $code = 'T:A to A:T';
    }
    else {
        print Dumper $self, $var, $snp;
        confess "cannot categorise (jones) variant type [$var]\n";
    }

    return $code;
}


sub categorise_kassahn {
    my $self = shift;

    my $var = $self->Variant_Type;
    my $snp = $self->snp_mutation;
    my $cpg = $self->is_cpg;

    # Return immediately for indels and MNPs
    if ($var eq 'INS' or $var eq 'DEL') {
        return 'indel';
    }
    elsif ($snp eq 'MNP') {
        return 'MNP';
    }

    # For SNPs we must have both $snp and $cpg and we assume that
    # $cpg == 1 means CpG positive.

    return undef unless (defined $snp and defined $cpg);

    my $code = undef;
    if ($snp eq 'A -> G' or $snp eq 'T -> C') {
        $code = 'A.T -> G.C';
    }
    elsif ($cpg == 1 and ($snp eq 'C -> T' or $snp eq 'G -> A')) {
        $code = 'CpG+ C.G -> T.A';
    }
    elsif ($cpg == 0 and ($snp eq 'C -> T' or $snp eq 'G -> A')) {
        $code = 'CpG- C.G -> T.A';
    }
    elsif ($snp eq 'A -> C' or $snp eq 'T -> G') {
        $code = 'A.T -> C.G';
    }
    elsif ($snp eq 'A -> T' or $snp eq 'T -> A') {
        $code = 'A.T -> T.A';
    }
    elsif ($snp eq 'C -> G' or $snp eq 'G -> C') {
        $code = 'C.G -> G.C';
    }
    elsif ($cpg == 1 and ($snp eq 'C -> A' or $snp eq 'G -> T')) {
        $code = 'CpG+ C.G -> A.T';
    }
    elsif ($cpg == 0 and ($snp eq 'C -> A' or $snp eq 'G -> T')) {
        $code = 'CpG- C.G -> A.T';
    }
    else {
        print Dumper $self, $var, $snp, $cpg;
        confess "cannot categorise (kassahn) variant type [$var]\n";
    }

    return $code;
}


sub categorise_stransky {
    my $self = shift;

    my $var = $self->Variant_Type;
    my $snp = $self->snp_mutation;
    my $cpg = $self->is_cpg;
    
    # Return immediately for indels and MNPs
    if ($var eq 'INS' or $var eq 'DEL') {
        return 'indel';
    }
    elsif ($snp eq 'MNP') {
        return 'MNP';
    }

    # For SNPs we must have both $snp and $cpg and we assume that
    # $cpg == 1 means CpG positive.

    return undef unless (defined $snp and defined $cpg);

    my $code = undef;
    if ($snp eq 'A -> G' or $snp eq 'T -> C' or
        $snp eq 'A -> C' or $snp eq 'T -> G' or
        $snp eq 'A -> T' or $snp eq 'T -> A') {
        $code = 'A -> mut';
    }
    elsif ($cpg == 1 and ($snp eq 'C -> G' or $snp eq 'C -> A' or
                          $snp eq 'G -> C' or $snp eq 'G -> T')) {
        $code = 'CpG+ C -> G/A';
    }
    elsif ($cpg == 1 and ($snp eq 'C -> T' or $snp eq 'G -> A')) {
        $code = 'CpG+ C -> T';
    }
    elsif ($cpg == 0 and ($snp eq 'G -> A' or $snp eq 'G -> C' or
                          $snp eq 'C -> T' or $snp eq 'C -> G')) {
        $code = 'CpG- G -> A/C';
    }
    elsif ($cpg == 0 and ($snp eq 'C -> A' or $snp eq 'G -> T')) {
        $code = 'CpG- G -> T';
    }
    else {
        print Dumper $self, $var, $snp, $cpg;
        croak "cannot categorise (stransky) variant type [$var]\n";
    }

    return $code;
}


sub categorise_quiddell {
    my $self = shift;

    my $var   = $self->Variant_Type;
    my $class = $self->Variant_Classification;

    # Codes:
    # non-silent sub
    # indel

    my $code = undef;
    if ($var eq 'INS' or $var eq 'DEL') {
        $code = 'indel';
    }
    elsif ($var =~ /^.NP$/ and $class !~ /^silent$/i) {
        $code = 'non-silent sub';
    }
    elsif ($var =~ /^.NP$/ and $class =~ /^silent$/i) {
        # we cannot categorise silent substitutions
    }
    elsif ($var eq 'SV') {
        # we cannot categorise SVs in quiddell system
    }
    else {
        confess "cannot categorise (quiddell) variant type/class [$var/$class]\n";
    }

    return $code;
}


sub categorise_synonymous {
    my $self = shift;

    my $var   = $self->Variant_Type;
    my $class = $self->Variant_Classification;

    # Codes:
    # synonymous
    # non-synonymous

    # Example summary from brain_met project showing the info we have
    # available to make the synon/nonsynon decision:
    #
    #   Count Class               Type  Syn/NonSyn
    # -------------------------------------------- 
    #     191 Frame_Shift_Del     DEL   NS
    #      49 Frame_Shift_Ins     INS   NS
    #      53 In_Frame_Del        DEL   NS
    #   12466 Missense_Mutation   SNP   NS
    #     975 Nonsense_Mutation   SNP   NS
    #      20 Nonstop_Mutation    SNP   NS
    #    5598 Silent              SNP   S
    #      33 Splice_Site         DEL   -
    #       3 Splice_Site         INS   -
    #    2058 Splice_Site         SNP   -

    # 2015-08
    # Updated example summary from the melanoma project showing the info
    # we have available to make the synon/nonsynon decision.  A couple
    # of differeneces to note - we now have DNP and TNP in addition to
    # SNP.
    #
    #   Count Class                  Type  Syn/NonSyn
    # ---------------------------===----------------- 
    #     396 Frame_Shift_Del         DEL  NS
    #     140 Frame_Shift_Ins         INS  NS
    #     100 In_Frame_Del            DEL  NS
    #    4686 Missense_Mutation       DNP  NS
    #   90527 Missense_Mutation       SNP  NS
    #      36 Missense_Mutation       TNP  NS
    #     346 Nonsense_Mutation       DNP  NS
    #       3 Nonsense_Mutation       INS  NS
    #    5788 Nonsense_Mutation       SNP  NS
    #       1 Nonstop_Mutation        DNP  NS
    #      40 Nonstop_Mutation        SNP  NS
    #     360 RNA                     DNP  -
    #   11018 RNA                     SNP  -
    #       1 RNA                     TNP  -
    #     130 Silent                  DNP  S
    #   48819 Silent                  SNP  S
    #     140 Splice_Site             DEL  -
    #     154 Splice_Site             DNP  -
    #      33 Splice_Site             INS  -
    #    1665 Splice_Site             SNP  -
    #       2 Splice_Site             TNP  -
    #       6 Translation_Start_Site  DNP  -
    #    3757 Translation_Start_Site  SNP  -

    my $code = undef;
    if ($class =~ /^Splice_/i or
        $class =~ /^Translation_/i or
        $class =~ /^RNA/i) {
        # do nothing - we are not counting splice sites in either category
    }
    elsif ($var eq 'SV') {
        # do nothing - we are not counting structural variants in either category
    }
    elsif ($var eq 'INS' or $var eq 'DEL' ) {
        # All # do nothing - we are not counting structural variants in either category
        $code = 'non-synonymous';
    }
    elsif ($var =~ /^.NP/ and $class !~ /^silent$/i) {
        $code = 'non-synonymous';
    }
    elsif ($var =~ /^.NP/ and $class =~ /^silent$/i) {
        $code = 'synonymous';
    }
    else {
        confess "cannot categorise (synonymous) variant type/class [$var/$class]\n";
    }

    return $code;
}


1;


__END__


=head1 NAME

QCMG::IO::MafRecord - MAF Record data container


=head1 SYNOPSIS

 use QCMG::IO::MafRecord;


=head1 DESCRIPTION

This module provides a data container for a MAF Record.

=head1 METHODS

=over

=item B<extra_field()>

  $rec->extra_field( 'Status', 'qSNP-only' );
  my $status = $rec->extra_field( 'Status' );

Setter and getter for non-standard attributes.  These will be output at
the end of the record.

=item B<allele_freq()>

Returns a 6-element arrayref providing information about the refernce
and variant allele counts for this record in the normal and tumour
samples.  Note that it collapses the forward and reverse strand counts
into single numbers.

 0. Reference Alelle
 1. Variant Allele
 2. Reference Allele count in Normal
 3. Variant Allele count in Normal
 4. Reference Allele count in Tumour
 5. Variant Allele count in Tumour

=item B<is_cpg()>

This routine returns 0 or 1 depending on whether the record is a SNP
that is part of a CpG, i.e it is at a point where the reference is a C
followed by a G or a G preceded by a C.
This method relies on the extra field "CPG" being present.
If extra field CPG is not present or the variant is not a SNP or there
is some problem with the CPG contents (not 11 chars or ref allele is not
the 6th char) then the routine returns undef.

=item B<snp_mutation()>

For records with Variant_Type of 'SNP', it returns the mutation as a
string of the form 'Ref -> Alt', e.g. 'A -> C'.  For
substitutions of greater than 1 base (DNP, TNP, etc) it returns 'MNP'
and for anything else (indels and odd cases), it returns undef.


=item B<categorise_jones()>

 indel
 MNP
 C:G to T:A
 C:G to G:C
 C:G to A:T
 T:A to C:G
 T:A to G:C
 T:A to A:T

Return values are shown above.
Undef is returned if the variant could not be categorised using this scheme.
This scheme does not distinguish between silent and non-silent mutations.

=item B<categorise_kassahn()>

 indel
 MNP
 A.T -> G.C
 CpG+ C.G -> T.A
 CpG- C.G -> T.A
 A.T -> C.G
 A.T -> T.A
 C.G -> G.C
 CpG+ C.G -> A.T
 CpG- C.G -> A.T

Return values are shown above.
Undef is returned if the variant could not be categorised using this scheme.
This scheme does not distinguish between silent and non-silent mutations.

=item B<categorise_stransky()>

 indel
 MNP
 A -> mut
 CpG+ C -> G/A
 CpG+ C -> T
 CpG- G -> A/C
 CpG- G -> T

Return values are shown above.
Undef is returned if the variant could not be categorised using this scheme.
This scheme does not distinguish between silent and non-silent mutations.

=item B<categorise_quiddell()>
=item B<categorise_quiddell2()>

 non-silent sub
 indel

These 2 schemes are currently (2015-11-12) identical because the only
deifference between the schemes is the way CNV data is overlaid on top
of the MAF (SNV/indel) info.

=item B<categorise_synonymous()>

 synonymous
 non-synonymous

Return values are shown above.
Undef is returned if the variant could not be categorised using this scheme.
For all it's apparent simplicity, this is one of the more complicated
categorisation scheme because it has to also tak int account the
Variant_Classification value.

This table is from plotting the brain_met project MAF file in 2014.  It
shows the information we have available to make the synon/non-synon
decision.

    Count Class               Type  Syn/NonSyn
  -------------------------------------------- 
      191 Frame_Shift_Del     DEL   NS
       49 Frame_Shift_Ins     INS   NS
       53 In_Frame_Del        DEL   NS
    12466 Missense_Mutation   SNP   NS
      975 Nonsense_Mutation   SNP   NS
       20 Nonstop_Mutation    SNP   NS
     5598 Silent              SNP   S
       33 Splice_Site         DEL   -
        3 Splice_Site         INS   -
     2058 Splice_Site         SNP   -

In August 2015, we plotting the MAF for the melanoma project and saw a
significant change.  In part this is because between the 2014 QCMG logic
and the 2015 QIMR logic, we have swapped annotation engines from Ensembl
to SNPEff.  We have also updated qSNP to call multi-base substitutions
so we can now see di- and tri- nucleotide polymorphisms (DNP, TNP).

    Count Class                  Type  Syn/NonSyn
  ---------------------------===----------------- 
      396 Frame_Shift_Del         DEL  NS
      140 Frame_Shift_Ins         INS  NS
      100 In_Frame_Del            DEL  NS
     4686 Missense_Mutation       DNP  NS
    90527 Missense_Mutation       SNP  NS
       36 Missense_Mutation       TNP  NS
      346 Nonsense_Mutation       DNP  NS
        3 Nonsense_Mutation       INS  NS
     5788 Nonsense_Mutation       SNP  NS
        1 Nonstop_Mutation        DNP  NS
       40 Nonstop_Mutation        SNP  NS
      360 RNA                     DNP  -
    11018 RNA                     SNP  -
        1 RNA                     TNP  -
      130 Silent                  DNP  S
    48819 Silent                  SNP  S
      140 Splice_Site             DEL  -
      154 Splice_Site             DNP  -
       33 Splice_Site             INS  -
     1665 Splice_Site             SNP  -
        2 Splice_Site             TNP  -
        6 Translation_Start_Site  DNP  -
     3757 Translation_Start_Site  SNP  -

=item B<categorise_quiddell()>

 non-silent sub
 indel

Return values are shown above.
Undef is returned if the variant could not be categorised using this scheme.
This scheme distinguishes between silent and non-silent mutations for
substitutions but assumes all indels are non-silent.

=item B<categorise_stratton()>

These methods implement categorisation schemes for variants.  Note that
for the methods B<categorise_quiddell()> and B<categorise_stratton()>
the full scale includes copy-number variants and since a copy number
variant may be present without a MAF variant, these schemes cannot be
fully implemented here.  For the other methods, the full categorisation 
scheme can be done here.

N.B. These routines always code the variant as a string.  qmaftools.pl
holds the mappings that turn the strings into integers output to the
text matrices used in R to generate the plots.

=back

=head1 AUTHORS

John Pearson L<mailto:grendeloz@gmail.com>


=head1 VERSION

$Id$


=head1 COPYRIGHT

Copyright (c) The University of Queensland 2010-2014
Copyright (c) QIMR Berghofer Medical Research Institute 2015

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

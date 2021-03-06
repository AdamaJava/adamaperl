package QCMG::IO::DccSnpWriter;

###########################################################################
#
#  Module:   QCMG::IO::DccSnpWriter
#  Creator:  John V Pearson
#  Created:  2012-11-22
#
#  Writes ICGC DCC SNP data submission tab-separated text file tables.
#
#  $Id$
#
###########################################################################

use strict;
use warnings;

use Carp qw( croak confess );
use Data::Dumper;
use IO::File;
use IO::Zlib;
use QCMG::IO::DccSnpRecord;
use QCMG::Util::QLog;

use vars qw( $SVNID $REVISION );

( $REVISION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
( $SVNID ) = '$Id$'
    =~ /\$Id:\s+(.*)\s+/;


sub new {
    my $class = shift;
    my %params = @_;

    confess "QCMG::IO::DccSnpWriter:new() requires filename parameter" 
        unless (exists $params{filename} and defined $params{filename});
    confess "QCMG::IO::DccSnpWriter:new() requires version parameter" 
        unless (exists $params{version} and defined $params{version});

    confess 'Unknown DccSnpWriter version [',$params{version},"]\n" 
        unless exists $QCMG::IO::DccSnpRecord::VALID_HEADERS->{$params{version}};

    my $self = { filename        => $params{filename},
                 filehandle      => undef,
                 headers         => [],
                 qmeta           => '',
                 annotations     => {},
                 record_ctr      => 0,
                 version         => $params{version},
                 verbose         => ($params{verbose} ?
                                     $params{verbose} : 0),
               };

    bless $self, $class;

    # If there was an annotations hash passed in and the filetype is a
    # DCCQ then insert them
    if (exists $params{annotations} and $self->version =~ /dccq/) {
        foreach my $key (keys %{ $params{annotations} }) {
            $self->{annotations}->{$key} = $params{annotations}->{$key};
        }
    }

    my $fh = IO::File->new( $params{filename}, 'w' );
    confess 'Unable to open ', $params{filename}, " for writing: $!"
        unless defined $fh;
    $self->filename( $params{filename} );
    $self->filehandle( $fh );

    qlogprint( 'Writing version '. $self->version .' DCC file '.
               $self->filename ."\n") if $self->verbose;

    # Write out #Q_* lines if supplied
    $fh->print( $params{meta} ) if (exists $params{meta} and
                                    defined $params{meta});

    $self->_write_headers();

    return $self;
}


sub _write_headers {
    my $self = shift;

    my $fh = $self->{filehandle};

    # Check for annotations, if any
    my @annots = sort keys %{ $self->{annotations} };
    foreach my $annot (@annots) {
         $fh->print( "#$annot:", $self->{annotations}->{$annot}, "\n" );   
    }

    # Get appropriate headers and write them out
    my @headers =
        @{ $QCMG::IO::DccSnpRecord::VALID_HEADERS->{$self->version} };
    $fh->print( join("\t", @headers), "\n" );

    $self->{headers} = \@headers;
}


sub filename {
    my $self = shift;
    return $self->{filename} = shift if @_;
    return $self->{filename};
}

sub filehandle {
    my $self = shift;
    return $self->{filehandle} = shift if @_;
    return $self->{filehandle};
}

sub _incr_record_ctr {
    my $self = shift;
    return $self->{record_ctr}++;
}

sub record_ctr {
    my $self = shift;
    return $self->{record_ctr};
}

sub version {
    my $self = shift;
    return $self->{version};
}

sub verbose {
    my $self = shift;
    return $self->{verbose};
}

sub close {
    my $self = shift;
    return $self->filehandle->close;
}


sub write_record {
    my $self   = shift;
    my $record = shift;

    # Check that record is for the same version as the writer
    die 'version mismatch between record [', $record->version,
        '] and writer [', $self->version, "]\n"
        unless ($record->version eq $self->version);

    $self->_incr_record_ctr;
    if ($self->verbose) {
        # Print progress messages for every 100K records
        qlogprint( $self->record_ctr, ' ', $self->version,
                   " DCC records written\n" )
            if $self->record_ctr % 100000 == 0;
    }
    $self->{filehandle}->print( $record->to_text, "\n" );
}


1;

__END__


=head1 NAME

QCMG::IO::DccSnpWriter - ICGC DCC SNP annotation file IO


=head1 SYNOPSIS

 use QCMG::IO::DccSnpWriter;


=head1 DESCRIPTION

This module provides an interface for writing SNP annotation
files in the format(s) required by the ICGC DCC.


=head1 AUTHORS

John Pearson L<mailto:j.pearson@uq.edu.au>


=head1 METHODS

=over

=item B<new()>

my $dccw = QCMG::IO::DccSnpWriter->new(
               filename    => 'mydcc.dccq',
               version     => 'dccq_dbssm_somatic_r11',
               annotations => {
                   PatientID        => 'APGI_2160',
                   AnalyzedSampleID => 'ICGC-ABMJ-20110401-05-TD',
                   ControlSampleID  => 'ICGC-ABMJ-20110401-04-ND',
                   Tool             => 'qSNP',
                   AnalysisDate     => '20121113',
                   AnalysisID       => '1A', 
                   },
               verbose  => 1 );

The version parameter determines the column headers that will be wrtten
to the output file and that all records must match before they are
written out.  filename and version are mandatory parameters.

The annotations hash shown in the exomaple above is only appropriate for
files with a version that indicates that they are DCCQ format.  For any
other file version, the annotations hash will be ignored if it is
supplied.  If supplied for DCCQ files, the annotations will be written
out as comment lines before the headers and records.

=item B<write_record()>

 $dccw->write_record( $my_dcc_rec );

Writes out a QCMG::IO::DccSnpRecord.  The version of the record must
match the version of the writer or the writer will confess.

=item B<record_ctr()>

Returns a count of how many records have been written.

=back


=head1 VERSION

$Id$


=head1 COPYRIGHT

Copyright (c) The University of Queensland 2012-2014

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

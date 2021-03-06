package Genome::Model::Tools::Sx::Split::ByNs;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::Split::ByNs {
    is  => 'Genome::Model::Tools::Sx::Base',
    has => {
        number_of_ns => {
            is => 'Integer',
            doc => 'Number of Ns to split sequence.',
        },
    },
};

sub help_brief { 'Split sequences by Ns' }

sub help_detail { 'Split sequences by a set number of Ns.' }
    
sub execute {
    my $self = shift;

    return if not $self->_init;

    my $reader = $self->_reader;
    while ( my $seqs = $reader->read ) {
        for my $seq ( @$seqs ) {
            $self->_split_and_write_seq($seq);
        }
    }

    return 1;
}

sub _split_and_write_seq {
    my ($self, $seq) = @_;

    my ($split_bases, $ns);
    my $n = $self->number_of_ns;
    my $remaining_bases = $seq->{seq};
    my $cnt = 0;
    my $start = 0;
    while ( $remaining_bases && length $remaining_bases ) {
        ($split_bases, $ns, $remaining_bases) = split(/(n{$n,})/i, $remaining_bases, 2);
        my %split_seq = (
            id => join('.', $seq->{id}, ++$cnt),
            seq => $split_bases,
        );
        $split_seq{qual} = substr($seq->{qual}, $start, length($split_bases)) if $seq->{qual};

        $self->_writer->write([ \%split_seq ]);
        $start += length($split_bases);
        $start += length($ns) if $ns;
    }

    return 1;
}

1;


package Genome::File::Vep::Writer;

use Genome;
use Genome::File::Vep::Header;
use Genome::File::Vep::Entry;
use Data::Dumper;
use Carp qw/confess/;
use strict;
use warnings;

sub new {
    my ($class, $path) = @_;
    return $class->fhopen(Genome::Sys->open_file_for_writing($path), $path);
}

sub fhopen {
    my ($class, $fh, $name) = @_;
    $name |= "unknown file path";
    my $header = new Genome::File::Vep::Header;
    $fh->print($header->to_string . "\n");

    my $self = {
        name => $name,
        filehandle => $fh,
    };

    return bless $self, $class;
}

sub write {
    my ($self, @entries) = @_;
    for my $entry (@entries) {
        my $type = ref $entry;
        confess "Attempted to write class $type to Vep file, expected a Vep entry"
            unless $type eq 'Genome::File::Vep::Entry';
        $self->{filehandle}->print($entry->to_string . "\n");
    }
}

1;

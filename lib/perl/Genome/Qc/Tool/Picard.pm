package Genome::Qc::Tool::Picard;

use strict;
use warnings;
use Genome;

class Genome::Qc::Tool::Picard {
    is => 'Genome::Qc::Tool',
    is_abstract => 1,
};

sub cmd_line {
    my $self = shift;
    my $cmd = $self->gmt_class->create($self->gmt_params);
    return $cmd->build_cmdline_list;
}

sub get_metrics {
    my $self = shift;

    my $file = $self->output_file;
    my $gmt_class = $self->gmt_class;
    my %metrics = $self->metrics;
    my $metric_results = $gmt_class->parse_file_into_metrics_hashref($file);
    return $self->_get_metrics(\%metrics, $metric_results);
}

sub metrics {
    my $self = shift;
    die $self->error_message("Abstract method metrics must be overridden by subclass");
}

sub gmt_class {
    my $self = shift;
    die $self->error_message("Abstract method gmt_class must be overridden by subclass");
}

sub _get_metrics {
    my ($self, $metrics, $metric_results) = @_;

    my %desired_metric_results;
    while (my ($metric, $metric_details) = each %{$metrics}) {
        my $metric_key = $metric_details->{metric_key};
        unless (defined($metric_key)) {
            my @metric_keys = keys %{$metric_results};
            if (scalar(@metric_keys) == 1) {
                $metric_key = $metric_keys[0];
            }
            else {
                my $library_name = $self->alignment_result->instrument_data->library->name;
                my @matching_metric_keys = grep {$_ =~ m/$library_name/} @metric_keys;
                if (scalar(@matching_metric_keys) == 1) {
                    $metric_key = $matching_metric_keys[0];
                }
                elsif (scalar(@matching_metric_keys) == 0) {
                    die $self->error_message("No matching metric key found for library (%s) in metric keys list: %s", $library_name, join(', ', @metric_keys));
                }
                else {
                    die $self->error_message("More than one metrics key found for library (%s) in metric keys list: %s", $library_name, join(', ', @metric_keys));
                }
            }
        }
        my $picard_metric = $metric_details->{picard_metric};
        $desired_metric_results{$metric} = $metric_results->{$metric_key}{$picard_metric};
    }
    return %desired_metric_results;
}

1;

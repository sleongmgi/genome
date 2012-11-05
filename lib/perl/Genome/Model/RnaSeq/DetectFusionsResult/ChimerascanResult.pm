package Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult;

use strict;
use warnings;

use above 'Genome';

# Notes from Chris Miller:
# bsub -oo err.log -q long
# -M 16000000 -R 'select[type==LINUX64 && mem>16000] span[hosts=1] rusage[mem=16000]' -n 8
# -J chimera -oo outputdir/chimera.err
# "python /gsc/bin/chimerascan_run.py -v -p 8
#   /gscmnt/sata921/info/medseq/cmiller/annotations/chimeraScanIndex/
#   $fastq1 $fastq2 $outputdir"

class Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult {
    is => "Genome::Model::RnaSeq::DetectFusionsResult",
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    $self->_prepare_output_directory();
    $self->_prepare_staging_directory();

    my $cmd_path = $self->_path_for_version($self->version);
    unless ($cmd_path) {
        die $self->error_message("Failed to find a path for chimerascan for version " . $self->version . "!");
    }

    my $index_dir = $self->_resolve_index_dir;

    my ($fastq1, $fastq2) = $self->_get_fastq_files_for_model();
    my $params = $self->detector_params;
    my $output_directory = $self->output_dir;

    my $cmd = "python $cmd_path/chimerascan_run.py -v $params $index_dir $fastq1 $fastq2 $output_directory >$output_directory/chimera_result.out";

    local $ENV{PYTHONPATH} =  ($ENV{PYTHONPATH} ? $ENV{PYTHONPATH} . ":" : "")  . $self->_python_path_for_version($self->version);

    $self->_put_bowtie_version_in_path();

    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$fastq1, $fastq2, $index_dir, $output_directory],
    );

    $self->_promote_data();
    $self->_remove_staging_directory();
    $self->_reallocate_disk_allocation();

    return $self;
}

sub _staging_disk_usage {
    #return enough to cover our temp dir (which will be under staging)
    return 60 * 1024 * 1024;
}

sub _path_for_version {
    my ($class, $version) = @_;

    my ($base_path, $bin_sub, $python_sub) = _get_chimerascan_path_for_version($version);
    my $result = join('/', $base_path, $bin_sub);

    if (-e $result) {
        return $result;
    } else {
        die("Binary path ($bin_sub) does not exist under chimerascan path ($base_path)!");
    }
}

sub _python_path_for_version {
    my ($class, $version) = @_;

    my ($base_path, $bin_sub, $python_sub) = _get_chimerascan_path_for_version($version);
    my $result = join('/', $base_path, $python_sub);

    if (-e $result) {
        return $result;
    } else {
        die("Python path ($python_sub) does not exist under chimerascan path ($base_path)!");
    }
}

sub _get_chimerascan_path_for_version {
    my ($version) = @_;

    my $path = sprintf("/usr/lib/chimerascan%s", $version);
    if (-e $path) {
        # installed via deb-package method
        my $bin_sub = 'bin';
        my $python_sub = join('/', 'lib', 'python2.6', 'site-packages');
        return $path, $bin_sub, $python_sub;
    } else {
        # fall back to old installation method
        $path = $ENV{GENOME_SW} . "/chimerascan/chimerascan-$version";
        if (-e $path) {
            my $bin_sub = 'chimerascan';
            my $python_sub = join('/', 'build', 'lib.linux-x86_64-2.6');
            return $path, $bin_sub, $python_sub;
        } else {
            die("You requested an unavailable version of Chimerascan. Requested: $version");
        }
    }
}

sub _resolve_index_dir {
    my $self = shift;

    my $index = Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult::Index->get_or_create(
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
        version => $self->version,
        bowtie_version => $self->alignment_result->bowtie_version,
        reference_build => $self->alignment_result->reference_build,
        annotation_build => $self->annotation_build,
    );

    unless($index){
        die("Unable to get a chimerascan index result");
    }

    return $index->output_dir;
}

sub resolve_allocation_subdirectory {
    my $self = shift;
    return 'build_merged_alignments/chimerascan/' . $self->id;
}

1;

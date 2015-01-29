#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Genome::Utility::Test qw(command_execute_ok compare_ok);
use Genome::Test::Factory::SoftwareResult::User;
use Test::More;

my $pkg = "Genome::Db::Ensembl::Command::Run::Vep";
use_ok($pkg);

my $TEST_VERSION = 2;
my $test_dir = Genome::Utility::Test->data_dir_ok($pkg, $TEST_VERSION);

for my $file_type ('ensembl', 'vcf', 'vcf.gz') {
    my $input_file = File::Spec->join($test_dir, "input.$file_type");
    my $expected_output_file = File::Spec->join($test_dir, "output.$file_type");
    my $output_file = Genome::Sys->create_temp_file_path;

    # We have different input and output files, but we still tell the tool we are 'vcf'
    my $format;
    if ($file_type eq "vcf.gz") {
        $format = "vcf";
    } else {
        $format = $file_type;
    }

    my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash();

    my %params = (
        input_file => $input_file,
        format => $format,
        output_file => $output_file,
        sift => "b",
        regulatory => 1,
        plugins => ["Condel\@PLUGIN_DIR\@b\@2"],
        ensembl_version => "74",
        quiet => 1,
        hgnc => 1,
        hgvs => 1,
        fasta => "/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa",
        analysis_build => $result_users->{requestor},
    );

    if ($file_type eq 'vcf' || $file_type eq 'vcf.gz') {
        $params{'vcf'} = 1;
    }

    my $cmd_1 = Genome::Db::Ensembl::Command::Run::Vep->create(%params);

    isa_ok($cmd_1, 'Genome::Db::Ensembl::Command::Run::Vep');
    Genome::Sys->dump_status_messages(0);
    command_execute_ok($cmd_1,
        { error_messages => [],
            status_messages => undef, },
        'execute');
    ok(-s $output_file, 'output file is non-zero');
    compare_ok($expected_output_file, $output_file, filters => [qr(^## Output produced at.*$), qr(^## Using cache in.*$)]);
}
done_testing();

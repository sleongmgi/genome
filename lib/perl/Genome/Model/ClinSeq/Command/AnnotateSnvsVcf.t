#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw (compare_ok);
use Genome::Test::Factory::SoftwareResult::User;
use Genome::Test::Factory::Model::SomaticValidation;
use Genome::Test::Factory::Model::ImportedVariationList;
use Genome::Test::Factory::Build;
use Sub::Override;

my $pkg = 'Genome::Model::ClinSeq::Command::AnnotateSnvsVcf';
use_ok($pkg);

my $test_dir = __FILE__.'.d';

my $dbsnp_model = Genome::Test::Factory::Model::ImportedVariationList->setup_object();
my $dbsnp_build = Genome::Test::Factory::Build->setup_object(
    model_id => $dbsnp_model->id,
    version  => "fake",
);

my $annotation_file = File::Spec->join($test_dir, 'annotation.vcf');
my $override2 = Sub::Override->new(
    'Genome::Model::Build::ImportedVariationList::snvs_vcf',
    sub { return $annotation_file }
);

my $somatic_model = Genome::Test::Factory::Model::SomaticValidation->setup_object();
my $somatic_build = Genome::Test::Factory::Build->setup_object(
    model_id                               => $somatic_model->id,
    previously_discovered_variations_build => $dbsnp_build,
);

my $input_file = File::Spec->join($test_dir, 'snvs.vcf');
my $override = Sub::Override->new(
    'Genome::Model::Build::RunsDV2::get_snvs_vcf',
    sub { return $input_file }
);

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash;

my $cmd = $pkg->create(
    somatic_build => $somatic_build,
    info => 0,
    result_users => $result_users,
);
isa_ok($cmd, $pkg);
ok($cmd->execute, 'Command executes correctly');

my $result = $cmd->output_result;
isa_ok($result, 'Genome::Model::ClinSeq::Command::AnnotateSnvsVcf::Result');
compare_ok($result->file_path, File::Spec->join($test_dir, 'expected', 'snvs.annotated.vcf'), 'File content as expected');

done_testing;

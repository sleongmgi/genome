use strict;
use warnings;

use above 'Genome';
use Cwd qw(realpath);
use File::Basename qw(dirname);
use lib realpath(dirname(__FILE__));
use Test::Music qw(run_test_case);

my $input_dir = Test::Music->input_dir;
my $actual_output_dir = Test::Music->output_dir;
run_test_case(
    run => "music proximity\n"
         . " --maf-file $input_dir/ucec_test.maf\n"
         . " --output-dir $actual_output_dir\n"
         . " --noskip-non-coding",
    expect => [
        'proximity_report'
    ],
);

#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

my $lims_class = 'Genome::Site::TGI::Synchronize::Classes::LimsProjectInstrumentData';
use_ok($lims_class) or die;

is($lims_class->entity_base_name, 'instrument data', 'entity_base_name');
my $entity_name = $lims_class->entity_name;
is($entity_name, 'project instrument data', 'entity name');
is($lims_class->genome_class_for_comparison, 'Genome::Site::TGI::Synchronize::Classes::ProjectInstrumentData', 'genome class for comparison');
is($lims_class->genome_class_for_create, 'Genome::ProjectPart', 'genome class for create');

my @properties_to_copy = $lims_class->properties_to_copy;
ok(@properties_to_copy, 'properties to copy');
my $i = -10;
my %properties = map { $_ => --$i } @properties_to_copy;
my $lims_object = $lims_class->__define__(%properties);
ok($lims_object, "define lims $entity_name object");

my $genome_object = $lims_object->create_in_genome;
ok($genome_object, "create genome $entity_name object");
isa_ok($genome_object, 'Genome::ProjectPart');

is($genome_object->project_id, $properties{project_id}, 'project_id matches');
is($genome_object->entity_id, $properties{entity_id}, 'entity_id matches');
is($genome_object->entity_class_name, 'Genome::InstrumentData', 'correct entity_class_name');
is($genome_object->label, 'instrument_data', 'correct label');

done_testing();

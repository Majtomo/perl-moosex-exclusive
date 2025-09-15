#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

# Test class with init-only exclusive attributes
{
    package InitConflictClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'config_a' => (
        is               => 'rw',
        isa              => 'Str',
        init_conflicts_with => 'config_b',
    );

    has 'config_b' => (
        is  => 'rw',
        isa => 'Str',
    );
}

# Test that init conflicts are checked during construction
dies_ok {
    InitConflictClass->new( config_a => 'value_a', config_b => 'value_b' );
} 'Cannot instantiate with both init-conflicting attributes';

# Test that init conflicts allow runtime setting
my $obj = InitConflictClass->new();
lives_ok { $obj->config_a('value_a') } 'Can set config_a at runtime';
lives_ok { $obj->config_b('value_b') } 'Can set config_b at runtime even when config_a is set';
is( $obj->config_a, 'value_a', 'config_a value is correct' );
is( $obj->config_b, 'value_b', 'config_b value is correct' );

# Test setting one attribute during construction works
my $obj2 = InitConflictClass->new( config_a => 'init_value_a' );
is( $obj2->config_a, 'init_value_a', 'config_a set during construction' );
ok( !$obj2->config_b, 'config_b not set' );

# Test setting the other attribute during construction works
my $obj3 = InitConflictClass->new( config_b => 'init_value_b' );
is( $obj3->config_b, 'init_value_b', 'config_b set during construction' );
ok( !$obj3->config_a, 'config_a not set' );

# Test with multiple init conflicts
{
    package MultiInitConflictClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'primary' => (
        is               => 'rw',
        isa              => 'Str',
        init_conflicts_with => ['alt1', 'alt2'],
    );

    has 'alt1' => (
        is  => 'rw',
        isa => 'Str',
    );

    has 'alt2' => (
        is  => 'rw',
        isa => 'Str',
    );
}

# Test multiple init conflicts during construction
dies_ok {
    MultiInitConflictClass->new( primary => 'primary_value', alt1 => 'alt1_value' );
} 'Cannot instantiate with primary and alt1';

dies_ok {
    MultiInitConflictClass->new( primary => 'primary_value', alt2 => 'alt2_value' );
} 'Cannot instantiate with primary and alt2';

# Test runtime setting with multiple init conflicts works
my $multi_obj = MultiInitConflictClass->new();
lives_ok { $multi_obj->primary('primary_value') } 'Can set primary at runtime';
lives_ok { $multi_obj->alt1('alt1_value') } 'Can set alt1 at runtime even when primary is set';
lives_ok { $multi_obj->alt2('alt2_value') } 'Can set alt2 at runtime even when primary is set';

# Test self-exclusion validation for init conflicts
dies_ok {
    package BadInitClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'self_init_exclude' => (
        is               => 'rw',
        init_conflicts_with => 'self_init_exclude',
    );
} 'Cannot init_conflict with self';

# Test non-existent attribute validation for init conflicts
dies_ok {
    package NonExistentInitClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'valid_init_attr' => (
        is               => 'rw',
        init_conflicts_with => 'non_existent_init_attr',
    );

    # Trigger validation by creating an instance
    NonExistentInitClass->new();
} 'Cannot init_conflict with non-existent attribute';

done_testing();
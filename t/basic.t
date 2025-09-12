#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

# Test class with exclusive attributes
{

    package TestClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'mode_a' => (
        is      => 'rw',
        isa     => 'Str',
        conflicts_with => 'mode_b',
    );

    has 'mode_b' => (
        is  => 'rw',
        isa => 'Str',
    );
}

# Test basic functionality
my $obj = TestClass->new();

# Test exclusive attributes throw error
$obj->mode_b('value_b');
is( $obj->mode_b, 'value_b', 'mode_b initially set' );

dies_ok { $obj->mode_a('value_a') } 'Setting mode_a when mode_b is set throws error';

# Test setting mode_a when mode_b is not set works
my $obj2 = TestClass->new();
eval { $obj2->mode_a('value_a') };
ok( !$@, 'Setting mode_a when mode_b is not set works' ) or diag("Error: $@");
is( $obj2->mode_a, 'value_a', 'mode_a set correctly' );

# Test self-exclusion validation
dies_ok {
    package BadClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'self_exclude' => (
        is      => 'rw',
        conflicts_with => 'self_exclude',
    );
} 'Cannot conflict with self';

# Test with readonly attributes during instantiation
{
    package ROClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'option_a' => (
        is      => 'ro',
        isa     => 'Str',
        conflicts_with => 'option_b',
    );

    has 'option_b' => (
        is  => 'ro',
        isa => 'Str',
    );
}

# Test instantiation with one readonly attribute
my $ro_obj1 = ROClass->new( option_a => 'value_a' );
is( $ro_obj1->option_a, 'value_a', 'option_a set during instantiation' );
ok( !$ro_obj1->option_b, 'option_b not set' );

# Test instantiation with the other readonly attribute
my $ro_obj2 = ROClass->new( option_b => 'value_b' );
is( $ro_obj2->option_b, 'value_b', 'option_b set during instantiation' );
ok( !$ro_obj2->option_a, 'option_a not set' );

# Test instantiation with both readonly attributes (should fail)
dies_ok {
    ROClass->new( option_a => 'value_a', option_b => 'value_b' );
} 'Cannot instantiate with both exclusive readonly attributes';

# Test with multiple attribute exclusion
{
    package MultiExcludeClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'primary' => (
        is      => 'rw',
        isa     => 'Str',
        conflicts_with => ['alt1', 'alt2'],
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

# Test setting primary attribute works
my $multi_obj = MultiExcludeClass->new();
eval { $multi_obj->primary('primary_value') };
ok( !$@, 'Setting primary when no alternatives are set works' ) or diag("Error: $@");
is( $multi_obj->primary, 'primary_value', 'primary set correctly' );

# Test setting primary when alt1 is set fails
my $multi_obj2 = MultiExcludeClass->new();
$multi_obj2->alt1('alt1_value');
dies_ok { $multi_obj2->primary('primary_value') } 'Cannot set primary when alt1 is already set';

# Test setting primary when alt2 is set fails
my $multi_obj3 = MultiExcludeClass->new();
$multi_obj3->alt2('alt2_value');
dies_ok { $multi_obj3->primary('primary_value') } 'Cannot set primary when alt2 is already set';

# Test constructor exclusion with multiple attributes
dies_ok {
    MultiExcludeClass->new( primary => 'primary_value', alt1 => 'alt1_value' );
} 'Cannot instantiate with primary and alt1';

dies_ok {
    MultiExcludeClass->new( primary => 'primary_value', alt2 => 'alt2_value' );
} 'Cannot instantiate with primary and alt2';

# Test array self-exclusion validation
dies_ok {
    package BadMultiClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'self_multi_exclude' => (
        is      => 'rw',
        conflicts_with => ['other', 'self_multi_exclude'],
    );
} 'Cannot conflict with self in array';

# Test non-existent attribute exclusion validation
dies_ok {
    package NonExistentClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'valid_attr' => (
        is      => 'rw',
        conflicts_with => 'non_existent_attr',
    );

    # Trigger validation by creating an instance
    NonExistentClass->new();
} 'Cannot conflict with non-existent attribute';

# Test non-existent attribute in array exclusion
dies_ok {
    package NonExistentArrayClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'valid_attr' => (
        is      => 'rw',
        conflicts_with => ['existing_attr', 'non_existent_attr'],
    );

    has 'existing_attr' => (
        is => 'rw',
    );

    # Trigger validation by creating an instance
    NonExistentArrayClass->new();
} 'Cannot conflict with non-existent attribute in array';

# Test inheritance support
{
    package BaseClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'base_attr' => (
        is  => 'rw',
        isa => 'Str',
    );
}

{
    package ChildClass;
    use MooseX::Trait::ExclusiveAttributes;
    extends 'BaseClass';

    has 'child_attr' => (
        is           => 'rw',
        isa          => 'Str',
        conflicts_with => 'base_attr',
    );
}

# Test runtime conflict checking with inheritance
my $inherit_obj = ChildClass->new();
$inherit_obj->base_attr('base_value');
is( $inherit_obj->base_attr, 'base_value', 'inherited attribute set' );

dies_ok {
    $inherit_obj->child_attr('child_value');
} 'Child attribute conflicts with inherited attribute';

# Test constructor conflict checking with inheritance
dies_ok {
    ChildClass->new(
        base_attr  => 'base_value',
        child_attr => 'child_value'
    );
} 'Constructor rejects conflicting inherited attributes';

# Test valid inheritance usage
my $valid_inherit = ChildClass->new( base_attr => 'base_only' );
is( $valid_inherit->base_attr, 'base_only', 'Valid inherited attribute usage' );

done_testing();

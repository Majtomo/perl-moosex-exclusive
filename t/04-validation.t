#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

# Test self-exclusion validation
dies_ok {
    package BadClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'self_exclude' => (
        is      => 'rw',
        conflicts_with => 'self_exclude',
    );
} 'Cannot conflict with self';

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

done_testing();
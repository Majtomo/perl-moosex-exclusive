#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

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

done_testing();
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
        is             => 'rw',
        isa            => 'Str',
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

dies_ok { $obj->mode_a('value_a') }
'Setting mode_a when mode_b is set throws error';

# Test setting mode_a when mode_b is not set works
my $obj2 = TestClass->new();
eval { $obj2->mode_a('value_a') };
ok( !$@, 'Setting mode_a when mode_b is not set works' ) or diag("Error: $@");
is( $obj2->mode_a, 'value_a', 'mode_a set correctly' );

done_testing();

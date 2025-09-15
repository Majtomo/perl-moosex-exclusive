#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

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
        is             => 'rw',
        isa            => 'Str',
        conflicts_with => 'base_attr',
    );
}

# Test runtime conflict checking with inheritance
my $inherit_obj = ChildClass->new();
$inherit_obj->base_attr('base_value');
is( $inherit_obj->base_attr, 'base_value', 'inherited attribute set' );

dies_ok {
    $inherit_obj->child_attr('child_value');
}
'Child attribute conflicts with inherited attribute';

# Test constructor conflict checking with inheritance
dies_ok {
    ChildClass->new(
        base_attr  => 'base_value',
        child_attr => 'child_value'
    );
}
'Constructor rejects conflicting inherited attributes';

# Test valid inheritance usage
my $valid_inherit = ChildClass->new( base_attr => 'base_only' );
is( $valid_inherit->base_attr, 'base_only', 'Valid inherited attribute usage' );

done_testing();

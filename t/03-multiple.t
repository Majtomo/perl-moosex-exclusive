#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

# Test with multiple attribute exclusion
{

    package MultiExcludeClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'primary' => (
        is             => 'rw',
        isa            => 'Str',
        conflicts_with => [ 'alt1', 'alt2' ],
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
ok( !$@, 'Setting primary when no alternatives are set works' )
  or diag("Error: $@");
is( $multi_obj->primary, 'primary_value', 'primary set correctly' );

# Test setting primary when alt1 is set fails
my $multi_obj2 = MultiExcludeClass->new();
$multi_obj2->alt1('alt1_value');
dies_ok { $multi_obj2->primary('primary_value') }
'Cannot set primary when alt1 is already set';

# Test setting primary when alt2 is set fails
my $multi_obj3 = MultiExcludeClass->new();
$multi_obj3->alt2('alt2_value');
dies_ok { $multi_obj3->primary('primary_value') }
'Cannot set primary when alt2 is already set';

# Test constructor exclusion with multiple attributes
dies_ok {
    MultiExcludeClass->new( primary => 'primary_value', alt1 => 'alt1_value' );
}
'Cannot instantiate with primary and alt1';

dies_ok {
    MultiExcludeClass->new( primary => 'primary_value', alt2 => 'alt2_value' );
}
'Cannot instantiate with primary and alt2';

done_testing();

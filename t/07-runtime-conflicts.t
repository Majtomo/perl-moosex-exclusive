#!/usr/bin/perl
use v5.36;
use Test::More;
use Test::Exception;

use_ok('MooseX::Trait::ExclusiveAttributes');

# Test class with runtime-only exclusive attributes
{

    package RuntimeConflictClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'runtime_a' => (
        is                     => 'rw',
        isa                    => 'Str',
        runtime_conflicts_with => 'runtime_b',
    );

    has 'runtime_b' => (
        is  => 'rw',
        isa => 'Str',
    );
}

# Test that runtime conflicts allow construction with both attributes
my $obj = RuntimeConflictClass->new(
    runtime_a => 'init_value_a',
    runtime_b => 'init_value_b'
);
is( $obj->runtime_a, 'init_value_a', 'runtime_a set during construction' );
is( $obj->runtime_b, 'init_value_b', 'runtime_b set during construction' );

# Test that runtime conflicts are checked at runtime
my $obj2 = RuntimeConflictClass->new();
$obj2->runtime_b('runtime_value_b');
is( $obj2->runtime_b, 'runtime_value_b', 'runtime_b set at runtime' );

dies_ok { $obj2->runtime_a('runtime_value_a') }
'Cannot set runtime_a when runtime_b is already set';

# Test setting runtime_a first works
my $obj3 = RuntimeConflictClass->new();
lives_ok { $obj3->runtime_a('runtime_value_a') }
'Can set runtime_a when runtime_b is not set';
is( $obj3->runtime_a, 'runtime_value_a', 'runtime_a value is correct' );

lives_ok { $obj3->runtime_b('runtime_value_b') }
'Can set runtime_b when runtime_a is set (conflicts are not bidirectional)';

# Test with multiple runtime conflicts
{

    package MultiRuntimeConflictClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'primary' => (
        is                     => 'rw',
        isa                    => 'Str',
        runtime_conflicts_with => [ 'alt1', 'alt2' ],
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

# Test multiple runtime conflicts allow construction
my $multi_obj = MultiRuntimeConflictClass->new(
    primary => 'primary_value',
    alt1    => 'alt1_value',
    alt2    => 'alt2_value'
);
is( $multi_obj->primary, 'primary_value', 'primary set during construction' );
is( $multi_obj->alt1,    'alt1_value',    'alt1 set during construction' );
is( $multi_obj->alt2,    'alt2_value',    'alt2 set during construction' );

# Test runtime conflicts with multiple attributes
my $multi_obj2 = MultiRuntimeConflictClass->new();
$multi_obj2->alt1('alt1_runtime');
dies_ok { $multi_obj2->primary('primary_runtime') }
'Cannot set primary when alt1 is already set';

my $multi_obj3 = MultiRuntimeConflictClass->new();
$multi_obj3->alt2('alt2_runtime');
dies_ok { $multi_obj3->primary('primary_runtime') }
'Cannot set primary when alt2 is already set';

# Test self-exclusion validation for runtime conflicts
dies_ok {

    package BadRuntimeClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'self_runtime_exclude' => (
        is                     => 'rw',
        runtime_conflicts_with => 'self_runtime_exclude',
    );
}
'Cannot runtime_conflict with self';

# Test non-existent attribute validation for runtime conflicts
dies_ok {

    package NonExistentRuntimeClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'valid_runtime_attr' => (
        is                     => 'rw',
        runtime_conflicts_with => 'non_existent_runtime_attr',
    );

    # Trigger validation by creating an instance
    NonExistentRuntimeClass->new();
}
'Cannot runtime_conflict with non-existent attribute';

# Test that runtime conflicts and init conflicts can coexist
{

    package MixedConflictClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'init_only' => (
        is                  => 'rw',
        isa                 => 'Str',
        init_conflicts_with => 'other',
    );

    has 'runtime_only' => (
        is                     => 'rw',
        isa                    => 'Str',
        runtime_conflicts_with => 'different',
    );

    has 'other'     => ( is => 'rw', isa => 'Str' );
    has 'different' => ( is => 'rw', isa => 'Str' );
}

# Test mixed conflicts - init conflicts prevent construction
dies_ok {
    MixedConflictClass->new( init_only => 'value', other => 'value' );
}
'init_conflicts_with still prevents construction';

# Test mixed conflicts - runtime conflicts allow construction but prevent runtime setting
my $mixed_obj = MixedConflictClass->new(
    runtime_only => 'runtime_val',
    different    => 'diff_val'
);
is( $mixed_obj->runtime_only, 'runtime_val',
    'runtime_only set during construction' );
is( $mixed_obj->different, 'diff_val', 'different set during construction' );

# But runtime conflicts still work at runtime
my $mixed_obj2 = MixedConflictClass->new();
$mixed_obj2->different('diff_runtime');
dies_ok { $mixed_obj2->runtime_only('runtime_val') }
'runtime_conflicts_with prevents runtime setting';

done_testing();

package MooseX::Trait::ExclusiveAttributes;
use v5.36;

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;

our $VERSION = '0.01';

Moose::Exporter->setup_import_methods(
    also      => 'Moose',
    meta_lookup => sub { Class::MOP::class_of(shift) },
);

sub init_meta ( $class, %args ) {
    my $for_class = $args{for_class};

    # Initialize Moose first
    Moose->init_meta(for_class => $for_class);

    Moose::Util::MetaRole::apply_metaroles(
        for             => $for_class,
        class_metaroles => {
            class => ['MooseX::Trait::ExclusiveAttributes::Meta::Class'],
        },
    );

    return $for_class->meta;
}

package MooseX::Trait::ExclusiveAttributes::Meta::Class;
use Moose::Role;

has '_exclusive_attributes' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

has '_init_exclusive_attributes' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

has '_runtime_exclusive_attributes' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

has '_exclusions_validated' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub _process_conflict_options ( $self, $name, $options ) {
    my $conflicts_with;
    my $init_conflicts_with;
    my $runtime_conflicts_with;

    if ( exists $options->{conflicts_with} ) {
        $conflicts_with = delete $options->{conflicts_with};
        $conflicts_with = $self->_normalize_and_validate_conflicts( $name, $conflicts_with, 'conflict' );
    }

    if ( exists $options->{init_conflicts_with} ) {
        $init_conflicts_with = delete $options->{init_conflicts_with};
        $init_conflicts_with = $self->_normalize_and_validate_conflicts( $name, $init_conflicts_with, 'init_conflict' );
    }

    if ( exists $options->{runtime_conflicts_with} ) {
        $runtime_conflicts_with = delete $options->{runtime_conflicts_with};
        $runtime_conflicts_with = $self->_normalize_and_validate_conflicts( $name, $runtime_conflicts_with, 'runtime_conflict' );
    }

    return ( $conflicts_with, $init_conflicts_with, $runtime_conflicts_with );
}

sub _normalize_and_validate_conflicts ( $self, $attr_name, $conflicts, $conflict_type ) {
    # Normalize to arrayref
    my $normalized = ref($conflicts) eq 'ARRAY' ? $conflicts : [$conflicts];

    # Validate that conflicts does not contain the attribute itself
    for my $conflicting_attr (@$normalized) {
        if ( $conflicting_attr eq $attr_name ) {
            my $error_msg = $conflict_type eq 'init_conflict' 
                ? "Attribute '$attr_name' cannot init_conflict with itself"
                : $conflict_type eq 'runtime_conflict'
                ? "Attribute '$attr_name' cannot runtime_conflict with itself"
                : "Attribute '$attr_name' cannot conflict with itself";
            Moose->throw_error($error_msg);
        }
    }

    return $normalized;
}

sub _register_conflicts ( $self, $name, $conflicts_with, $init_conflicts_with, $runtime_conflicts_with ) {
    if ( $conflicts_with ) {
        # Store conflict relationship
        $self->_exclusive_attributes->{$name} = $conflicts_with;
        # Install conflict checking behavior after attribute creation
        $self->_setup_exclusion( $name, $conflicts_with );
    }

    if ( $init_conflicts_with ) {
        # Store init-only conflict relationship (no runtime checking)
        $self->_init_exclusive_attributes->{$name} = $init_conflicts_with;
    }

    if ( $runtime_conflicts_with ) {
        # Store runtime-only conflict relationship
        $self->_runtime_exclusive_attributes->{$name} = $runtime_conflicts_with;
        # Install conflict checking behavior after attribute creation
        $self->_setup_exclusion( $name, $runtime_conflicts_with );
    }
}

around '_process_new_attribute' => sub ( $orig, $self, $name, %options ) {
    my ( $conflicts_with, $init_conflicts_with, $runtime_conflicts_with ) = $self->_process_conflict_options( $name, \%options );

    my $attr = $self->$orig( $name, %options );

    $self->_register_conflicts( $name, $conflicts_with, $init_conflicts_with, $runtime_conflicts_with );

    return $attr;
};

# Also catch add_attribute calls to ensure we handle all cases
around 'add_attribute' => sub ( $orig, $self, $name, %options ) {
    my ( $conflicts_with, $init_conflicts_with, $runtime_conflicts_with ) = $self->_process_conflict_options( $name, \%options );

    my $attr = $self->$orig( $name, %options );

    $self->_register_conflicts( $name, $conflicts_with, $init_conflicts_with, $runtime_conflicts_with );

    return $attr;
};

around 'new_object' => sub {
    my $orig = shift;
    my $self = shift;
    my $params = shift;  # First parameter is typically a hashref

    # Validate exclusions before proceeding
    $self->_validate_exclusions;

    # Check for conflicting attributes in constructor parameters
    if ( ref($params) eq 'HASH' ) {
        $self->_check_constructor_conflicts( $params, $self->_exclusive_attributes, 'runtime' );
        $self->_check_constructor_conflicts( $params, $self->_init_exclusive_attributes, 'init' );
    }

    return $self->$orig($params, @_);
};

after 'make_immutable' => sub {
    my ($self) = @_;
    $self->_validate_exclusions;
};

sub _validate_exclusions ($self) {
    return if $self->_exclusions_validated;

    $self->_validate_exclusion_group( $self->_exclusive_attributes, 'conflicts' );
    $self->_validate_exclusion_group( $self->_init_exclusive_attributes, 'init_conflicts' );
    $self->_validate_exclusion_group( $self->_runtime_exclusive_attributes, 'runtime_conflicts' );

    $self->_exclusions_validated(1);
}

sub _validate_exclusion_group ( $self, $exclusions, $conflict_type ) {
    for my $attr_name (keys %$exclusions) {
        my $conflicting_attrs = $exclusions->{$attr_name};

        for my $conflicting_attr (@$conflicting_attrs) {
            unless ($self->find_attribute_by_name($conflicting_attr)) {
                my $error_msg = $conflict_type eq 'init_conflicts'
                    ? "Attribute '$attr_name' init_conflicts with non-existent attribute '$conflicting_attr'"
                    : $conflict_type eq 'runtime_conflicts'
                    ? "Attribute '$attr_name' runtime_conflicts with non-existent attribute '$conflicting_attr'"
                    : "Attribute '$attr_name' conflicts with non-existent attribute '$conflicting_attr'";
                Moose->throw_error($error_msg);
            }
        }
    }
}

sub _check_constructor_conflicts ( $self, $params, $exclusions, $conflict_type ) {
    for my $attr_name ( keys %$exclusions ) {
        my $conflicting_attrs = $exclusions->{$attr_name};

        if ( exists $params->{$attr_name} ) {
            for my $conflicting_attr (@$conflicting_attrs) {
                # Check if the conflicting attribute exists in this class hierarchy
                if ( $self->find_attribute_by_name($conflicting_attr) && exists $params->{$conflicting_attr} ) {
                    my $error_msg = $conflict_type eq 'init'
                        ? "Cannot set both '$attr_name' and '$conflicting_attr' during initialization - they conflict with each other"
                        : "Cannot set both '$attr_name' and '$conflicting_attr' - they conflict with each other";
                    Moose->throw_error($error_msg);
                }
            }
        }
    }
}

sub _setup_exclusion ( $self, $name, $conflicts_with ) {
    my $attr = $self->get_attribute($name);
    return unless $attr;

    my $writer = $attr->get_write_method;
    return unless $writer;

    $self->add_around_method_modifier(
        $writer,
        sub {
            my ( $orig, $instance, @args ) = @_;

            # Only check conflicts if we're setting a value (i.e., arguments are provided)
            if ( @args ) {
                # Validate exclusions before proceeding
                $self->_validate_exclusions;

                # Check if any of the conflicting attributes has been set (has a value)
                for my $conflicting_attr_name (@$conflicts_with) {
                    my $conflicting_attr = $self->find_attribute_by_name($conflicting_attr_name);
                    if ( $conflicting_attr ) {
                        if ( $conflicting_attr->has_value($instance) ) {
                            Moose->throw_error("Cannot set '$name' because '$conflicting_attr_name' is already set (they conflict)");
                        }
                    }
                }
            }

            return $orig->($instance, @args);
        }
    );
}

1;

__END__

=head1 NAME

MooseX::Trait::ExclusiveAttributes - A trait for mutually exclusive attributes

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    package MyClass;
    use MooseX::Trait::ExclusiveAttributes;

    has 'mode_a' => (
        is           => 'rw',
        isa          => 'Str',
        conflicts_with => 'mode_b',  # Cannot set mode_a when mode_b is already set
    );

    has 'mode_b' => (
        is  => 'rw',
        isa => 'Str',
    );

    # Multiple conflicts
    has 'primary' => (
        is           => 'rw',
        isa          => 'Str',
        conflicts_with => ['alt1', 'alt2'],  # Cannot set primary when alt1 or alt2 is set
    );

    # Init-only conflicts (only checked during object construction)
    has 'config_a' => (
        is               => 'rw',
        isa              => 'Str',
        init_conflicts_with => 'config_b',  # Cannot construct with both, but can set after construction
    );

    # Runtime-only conflicts (only checked during runtime, not construction)
    has 'runtime_a' => (
        is                    => 'rw',
        isa                   => 'Str',
        runtime_conflicts_with => 'runtime_b',  # Can construct with both, but cannot set when other is set
    );

    has 'alt1' => ( is => 'rw', isa => 'Str' );
    has 'alt2' => ( is => 'rw', isa => 'Str' );
    has 'config_b' => ( is => 'rw', isa => 'Str' );
    has 'runtime_b' => ( is => 'rw', isa => 'Str' );

    my $obj = MyClass->new();
    $obj->mode_b('some_value');
    eval { $obj->mode_a('other_value') }; # Dies: Cannot set mode_a because mode_b is already set (they conflict)

=head1 DESCRIPTION

This module provides a trait for creating mutually exclusive attributes. When an attribute with a 'conflicts_with' option is set, it will throw an error if any of the conflicting attributes already has a value.

The 'conflicts_with' option can reference a single attribute (as a string) or multiple attributes (as an arrayref). Conflicting attributes must be in the same class, and an attribute cannot conflict with itself.

Conflict checking is performed both at runtime (when calling setters) and during object construction (when passing conflicting attributes to new()).

The 'init_conflicts_with' option works like 'conflicts_with' but only checks conflicts during object construction, not at runtime. This allows you to prevent conflicting attributes from being set together during initialization while still allowing them to be set independently after construction.

The 'runtime_conflicts_with' option works like 'conflicts_with' but only checks conflicts at runtime, not during object construction. This allows you to construct objects with conflicting attributes set, but prevents them from being modified when the conflicting attribute already has a value.

=head1 AUTHORS

Jean-Antoine RINALDY <m4jtom@gmail.com>

Claude (Anthropic AI Assistant)

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2025 by Jean-Antoine RINALDY.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

This program is distributed under the Artistic License 2.0.

=cut

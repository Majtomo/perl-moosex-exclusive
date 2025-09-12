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

has '_exclusions_validated' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

around '_process_new_attribute' => sub ( $orig, $self, $name, %options ) {
    my $conflicts_with;

    if ( exists $options{conflicts_with} ) {
        $conflicts_with = delete $options{conflicts_with};

        # Normalize conflicts_with to arrayref
        $conflicts_with = ref($conflicts_with) eq 'ARRAY' ? $conflicts_with : [$conflicts_with];

        # Validate that conflicts_with does not contain the attribute itself
        for my $conflicting_attr (@$conflicts_with) {
            if ( $conflicting_attr eq $name ) {
                Moose->throw_error("Attribute '$name' cannot conflict with itself");
            }
        }
    }

    my $attr = $self->$orig( $name, %options );

    if ( $conflicts_with ) {
        # Store conflict relationship
        $self->_exclusive_attributes->{$name} = $conflicts_with;
        # Install conflict checking behavior after attribute creation
        $self->_setup_exclusion( $name, $conflicts_with );
    }

    return $attr;
};

# Also catch add_attribute calls to ensure we handle all cases
around 'add_attribute' => sub ( $orig, $self, $name, %options ) {
    my $conflicts_with;

    if ( exists $options{conflicts_with} ) {
        $conflicts_with = delete $options{conflicts_with};

        # Normalize conflicts_with to arrayref
        $conflicts_with = ref($conflicts_with) eq 'ARRAY' ? $conflicts_with : [$conflicts_with];

        # Validate that conflicts_with does not contain the attribute itself
        for my $conflicting_attr (@$conflicts_with) {
            if ( $conflicting_attr eq $name ) {
                Moose->throw_error("Attribute '$name' cannot conflict with itself");
            }
        }
    }

    my $attr = $self->$orig( $name, %options );

    if ( $conflicts_with ) {
        # Store conflict relationship
        $self->_exclusive_attributes->{$name} = $conflicts_with;
        # Install conflict checking behavior after attribute creation
        $self->_setup_exclusion( $name, $conflicts_with );
    }

    return $attr;
};

around 'new_object' => sub {
    my $orig = shift;
    my $self = shift;
    my $params = shift;  # First parameter is typically a hashref

    # Validate exclusions before proceeding
    $self->_validate_exclusions;

    # Check for conflicting attributes in constructor parameters
    my $exclusions = $self->_exclusive_attributes;

    if ( ref($params) eq 'HASH' ) {
        for my $attr_name ( keys %$exclusions ) {
            my $conflicting_attrs = $exclusions->{$attr_name};

            if ( exists $params->{$attr_name} ) {
                for my $conflicting_attr (@$conflicting_attrs) {
                    # Check if the conflicting attribute exists in this class hierarchy
                    if ( $self->find_attribute_by_name($conflicting_attr) && exists $params->{$conflicting_attr} ) {
                        Moose->throw_error("Cannot set both '$attr_name' and '$conflicting_attr' - they conflict with each other");
                    }
                }
            }
        }
    }

    return $self->$orig($params, @_);
};

after 'make_immutable' => sub {
    my ($self) = @_;
    $self->_validate_exclusions;
};

sub _validate_exclusions ($self) {
    return if $self->_exclusions_validated;

    my $exclusions = $self->_exclusive_attributes;

    for my $attr_name (keys %$exclusions) {
        my $conflicting_attrs = $exclusions->{$attr_name};

        for my $conflicting_attr (@$conflicting_attrs) {
            unless ($self->find_attribute_by_name($conflicting_attr)) {
                Moose->throw_error("Attribute '$attr_name' conflicts with non-existent attribute '$conflicting_attr'");
            }
        }
    }

    $self->_exclusions_validated(1);
}

sub _setup_exclusion ( $self, $name, $conflicts_with ) {
    my $attr = $self->get_attribute($name);
    return unless $attr;

    my $writer = $attr->get_write_method;
    return unless $writer;

    $self->add_around_method_modifier(
        $writer,
        sub {
            my ( $orig, $instance, $value ) = @_;

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

            return $orig->(@_[1..$#_]);
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

    has 'alt1' => ( is => 'rw', isa => 'Str' );
    has 'alt2' => ( is => 'rw', isa => 'Str' );

    my $obj = MyClass->new();
    $obj->mode_b('some_value');
    eval { $obj->mode_a('other_value') }; # Dies: Cannot set mode_a because mode_b is already set (they conflict)

=head1 DESCRIPTION

This module provides a trait for creating mutually exclusive attributes. When an attribute with a 'conflicts_with' option is set, it will throw an error if any of the conflicting attributes already has a value.

The 'conflicts_with' option can reference a single attribute (as a string) or multiple attributes (as an arrayref). Conflicting attributes must be in the same class, and an attribute cannot conflict with itself.

Conflict checking is performed both at runtime (when calling setters) and during object construction (when passing conflicting attributes to new()).

=head1 AUTHORS

Jean-Antoine RINALDY <m4jtom@gmail.com>

Claude (Anthropic AI Assistant)

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2025 by Jean-Antoine RINALDY.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

This program is distributed under the Artistic License 2.0.

=cut

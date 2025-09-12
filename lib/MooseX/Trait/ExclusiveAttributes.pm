package MooseX::Trait::ExclusiveAttributes;
use strict;
use warnings;
use v5.10;

use Moose::Role;

our $VERSION = '0.01';

1;

__END__

=head1 NAME

MooseX::Trait::ExclusiveAttributes - A trait for mutually exclusive attributes

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    with 'MooseX::Trait::ExclusiveAttributes';

=head1 DESCRIPTION

This module provides a trait for creating mutually exclusive attributes.

=head1 AUTHOR

Jean-Antoine RINALDY <m4jtom@gmail.com>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2025.

=cut
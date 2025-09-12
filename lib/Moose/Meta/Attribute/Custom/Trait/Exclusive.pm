package Moose::Meta::Attribute::Custom::Trait::Exclusive;
use v5.36;

sub register_implementation {
    return
      'MooseX::Trait::ExclusiveAttributes::Meta::Attribute::Trait::Exclusive';
}

package MooseX::Trait::ExclusiveAttributes::Meta::Attribute::Trait::Exclusive;
use Moose::Role;

has 'excluded_by' => (
    is  => 'ro',
    isa => 'Str',
);

1;

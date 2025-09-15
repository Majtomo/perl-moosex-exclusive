#!/usr/bin/perl
use v5.36;
use Test::More;

eval "use Test::Pod::Coverage 1.08";
plan skip_all => "Test::Pod::Coverage 1.08 required for testing POD coverage"
  if $@;

eval "use Pod::Coverage 0.18";
plan skip_all => "Pod::Coverage 0.18 required for testing POD coverage" if $@;

pod_coverage_ok( "MooseX::Trait::ExclusiveAttributes" );

done_testing();
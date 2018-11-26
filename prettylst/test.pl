#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(abs_path $0) . '/lib';

BEGIN {

   use Pretty::Options ();
   no strict 'refs';
   *getOption = *{'Pretty::Options::getOption'}{CODE};

}

my $return = Pretty::Options::parseOptions(@ARGV);

print "$return\n";

my $basepath = getOption( 'basepath' );

if (defined $basepath) {
	print "\n$basepath\n";
} else {
	print "no opion\n"
}


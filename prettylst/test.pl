#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(abs_path $0) . '/lib';
use Pretty::Options ('getOption');

my $VERSION        = "7.00.00";
my $VERSION_DATE   = "2018-11-26";
my ($PROGRAM_NAME) = "PCGen PrettyLST";
my ($SCRIPTNAME)   = ( $PROGRAM_NAME =~ m{ ( [^/\\]* ) \z }xms );
my $VERSION_LONG   = "$SCRIPTNAME version: $VERSION -- $VERSION_DATE";

my $today = localtime;

my $return = Pretty::Options::parseOptions(@ARGV);

print "$return";

# Test function or display variables or anything else I need.
if ( getOption('test') ) {

   print "No tests set\n";
   exit;
}

# Fix Warning Level
my $error_message = Pretty::Options::fixWarningLevel();

# Check input path is set
$error_message .= Pretty::Options::checkInputPath(); 

# Redirect STDERR if needed

if (getOption('outputerror')) {
   open STDERR, '>', getOption('outputerror');
   print STDERR "Error log for ", $VERSION_LONG, "\n";
   print STDERR "At ", $today, " on the data files in the \'", getOption('inputpath')  , "\' directory\n";
}

print $error_message;

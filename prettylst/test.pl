#!/usr/bin/perl

use strict;
use warnings;

# expand library path so we can find Pretty modules
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(abs_path $0) . '/lib';

use Pretty::Options ('getOption');

use Pod::Html   (); # We do not import any function for
use Pod::Text   (); # the modules other than "system" modules
use Pod::Usage  ();

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

# Diplay usage information
if ( getOption('help') or $Getopt::Long::error ) {
   Pod::Usage::pod2usage(
      {  -msg     => $error_message,
         -exitval => 1,
         -output  => \*STDERR
      }
   );
   exit;
}

# Display the man page
if (getOption('man')) {
   Pod::Usage::pod2usage(
      {  -msg     => $error_message,
         -verbose => 2,
         -output  => \*STDERR
      }
   );
   exit;
}

# Generate the HTML man page and display it

if ( getOption('htmlhelp') ) {
   if( !-e "$PROGRAM_NAME.css" ) {
      generate_css("$PROGRAM_NAME.css");
   }

   Pod::Html::pod2html(
      "--infile=$PROGRAM_NAME",
      "--outfile=$PROGRAM_NAME.html",
      "--css=$PROGRAM_NAME.css",
      "--title=$PROGRAM_NAME -- Reformat the PCGEN .lst files",
      '--header',
   );

   `start /max $PROGRAM_NAME.html`;

   exit;
}

# If present, call the function to generate the "game mode" variables.
if ( getOption('systempath') ne q{} ) {
   Pretty::Conversion::sparse_system_files();
}

print $error_message;

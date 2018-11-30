package Pretty::Conversions;

use 5.010_001;         # Perl 5.10.1 or better is now mandantory
use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = wq();

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0);

use Pretty::Logging;
use Pretty::Options (qw(getOption setOption));

our $logging = Pretty::Logging->new(warningLevel => getOption('warninglevel'));

our @xcheck_to_process; # Will hold the information for the entries that must


our %referer;           # Will hold the tags that refer to other entries
                        # Format: push @{$referer{$EntityType}{$entryname}},
                        #               [ $tags{$column}, $fileForError, $lineForError ]

our %valid_entities;    # Will hold the entries that may be refered
                        # by other tags
                        # Format $valid_entities{$entitytype}{$entityname}
                        # We initialise the hash with global system values
                        # that are valid but never defined in the .lst files.

our @xcheck_to_process; # Will hold the information for the entries that must
                        # be added in %referer or %referer_types. The array
                        # is needed because all the files must have been
                        # parsed before processing the information to be added.
                        # The function add_to_xcheck_tables will be called with
                        # each line of the array.








=head2 registerCrossCheck

   Register data to be checked later

=cut

sub registerXCheck {
   push @xcheck_to_process, [ @_ ];
}

if ( getOption('xcheck') ) {

        #####################################################
        # First we process the information that must be added
        # to the %referer and %referer_types;
        for my $parameter_ref (@xcheck_to_process) {
                add_to_xcheck_tables( @{$parameter_ref} );
        }

        #####################################################
        # Print a report with the problems found with xcheck

        my %to_report;

        # Find the entries that need to be reported
        for my $linetype ( sort %referer ) {
                for my $entry ( sort keys %{ $referer{$linetype} } ) {

                # Special case for EQUIPMOD Key
                # -----------------------------
                # If an EQUIPMOD Key entry doesn't exists, we can use the
                # EQUIPMOD name but we have to throw a warning.
                if ( $linetype eq 'EQUIPMOD Key' ) {
                        if ( !exists $valid_entities{'EQUIPMOD Key'}{$entry} ) {

                                # There is no key but it might be just a warning
                                if ( exists $valid_entities{'EQUIPMOD'}{$entry} ) {

                                        # It's a warning
                                        for my $array ( @{ $referer{$linetype}{$entry} } ) {

                                                # It's not a warning, not EQUIPMOD were found.
                                                push @{ $to_report{ $array->[1] } },
                                                        [ $array->[2], 'EQUIPMOD Key', $array->[0] ];
                                        }
                                }
                                else {
                                        for my $array ( @{ $referer{$linetype}{$entry} } ) {

                                                # It's not a warning, no EQUIPMOD were found.
                                                push @{ $to_report{ $array->[1] } },
                                                        [ $array->[2], 'EQUIPMOD Key or EQUIPMOD', $array->[0] ];
                                        }
                                }
                        }
                }
#               elsif ( $linetype eq 'RACE' && $entry =~ / [%] /xms ) {
#                       # Special PRERACE:xxx% case
#                       my $race_text   = $1;
#                       my $after_wildcard = $2;
#
#                       for my $array ( @{ $referer{$linetype}{$entry} } ) {
#                               if ( $after_wildcard ne q{} ) {
#                                       $logging->notice(
#                                               qq{Wildcard context for %, nothing should follow the % in }
#                                               . ,
#
#                               }
#                       }
#               }
                elsif ( $linetype =~ /,/ ) {

                        # Special case if there is a , (comma) in the
                        # entry.
                        # We must check multiple possible linetypes.
                        my $found = 0;

                        ITEM:
                        for my $item ( split ',', $linetype ) {
                                if ( exists $valid_entities{$item}{$entry} ) {
                                $found = 1;
                                last ITEM;
                                }
                        }

                        if (!$found) {

                                # Let's have a cute message
                                my @list = split ',', $linetype;
                                my $end_of_message = $list[-2] . ' or ' . $list[-1];
                                pop @list;
                                pop @list;

                                my $message = ( join ', ', @list ) . $end_of_message;

        # push @{$referer{$FileType}{$entry}}, [ $tags{$column}, $file_for_error, $line_for_error ]
                                for my $array ( @{ $referer{$linetype}{$entry} } ) {
                                push @{ $to_report{ $array->[1] } },
                                        [ $array->[2], $message, $array->[0] ];
                                }
                        }
                }
                else {
                        unless ( exists $valid_entities{$linetype}{$entry} ) {
        # push @{$referer{$FileType}{$entry}}, [$tags{$column}, $file_for_error, $line_for_error]
                                for my $array ( @{ $referer{$linetype}{$entry} } ) {
                                        push @{ $to_report{ $array->[1] } },
                                                [ $array->[2], $linetype, $array->[0] ];
                                }
                        }
                }
                }
        }

        # Print the report sorted by file name and line number.
        $logging->set_header(constructLoggingHeader('CrossRef'));

        # This will add a message for every message in to_report - which should be every message
        # that was added to to_report.
        for my $file ( sort keys %to_report ) {
           for my $line_ref ( sort { $a->[0] <=> $b->[0] } @{ $to_report{$file} } ) {
              my $message = qq{No $line_ref->[1] entry for "$line_ref->[2]"};

              # If it is an EQMOD Key missing, it is less severe
              if ($line_ref->[1] eq 'EQUIPMOD Key' ) {
                 $logging->info($message, $file, $line_ref->[0] );
              } else {
                 $logging->notice($message, $file, $line_ref->[0] );
              }
           }
        }

        ###############################################
        # Type report
        # This is the code used to change what types are/aren't reported.
        # Find the type entries that need to be reported
        %to_report = ();
        for my $linetype ( sort %referer_types ) {
                for my $entry ( sort keys %{ $referer_types{$linetype} } ) {
                        unless ( exists $valid_types{$linetype}{$entry} ) {
                                for my $array ( @{ $referer_types{$linetype}{$entry} } ) {
                                        push @{ $to_report{ $array->[1] } }, [ $array->[2], $linetype, $array->[0] ];
                                }
                        }
                }
        }

        # Print the type report sorted by file name and line number.
        $logging->set_header(constructLoggingHeader('Type CrossRef'));

        for my $file ( sort keys %to_report ) {
                for my $line_ref ( sort { $a->[0] <=> $b->[0] } @{ $to_report{$file} } ) {
                $logging->notice(
                        qq{No $line_ref->[1] type found for "$line_ref->[2]"},
                        $file,
                        $line_ref->[0]
                );
                }
        }

        ###############################################
        # Category report
        # Needed for full support for [ 1671407 ] xcheck PREABILITY tag
        # Find the category entries that need to be reported
        %to_report = ();
        for my $linetype ( sort %referer_categories ) {
                for my $entry ( sort keys %{ $referer_categories{$linetype} } ) {
                unless ( exists $valid_categories{$linetype}{$entry} ) {
                        for my $array ( @{ $referer_categories{$linetype}{$entry} } ) {
                                push @{ $to_report{ $array->[1] } }, [ $array->[2], $linetype, $array->[0] ];
                        }
                }
                }
        }

        # Print the category report sorted by file name and line number.
        $logging->set_header(constructLoggingHeader('Category CrossRef'));

        for my $file ( sort keys %to_report ) {
                for my $line_ref ( sort { $a->[0] <=> $b->[0] } @{ $to_report{$file} } ) {
                $logging->notice(
                        qq{No $line_ref->[1] category found for "$line_ref->[2]"},
                        $file,
                        $line_ref->[0]
                );
                }
        }


        #################################
        # Print the tag that do not have defined headers if requested
        if ( getOption('missingheader') ) {
                my $firsttime = 1;
                for my $linetype ( sort keys %missing_headers ) {
                if ($firsttime) {
                        print STDERR "\n================================================================\n";
                        print STDERR "List of TAGs without defined header in \%tagheader\n";
                        print STDERR "----------------------------------------------------------------\n";
                }

                print STDERR "\n" unless $firsttime;
                print STDERR "Line Type: $linetype\n";

                for my $header ( sort report_tag_sort keys %{ $missing_headers{$linetype} } ) {
                        print STDERR "  $header\n";
                }

                $firsttime = 0;
                }
        }

}

#########################################
# Close the files that were opened for
# special conversion

if ( Pretty::Options::isConversionActive('Export lists') ) {
        # Close all the files in reverse order that they were opened
        for my $line_type ( reverse sort keys %filehandle_for ) {
                close $filehandle_for{$line_type};
        }
}

#########################################
# Close the redirected STDERR if needed

if (getOption('outputerror')) {
        close STDERR;
        print STDOUT "\cG";                     # An audible indication that PL has finished.
}

###############################################################################
###############################################################################
####                                                                       ####
####                            Subroutine Definitions                     ####
####                                                                       ####
###############################################################################
###############################################################################

###############################################################
# parse_ADD_tag
# -------------
#
# The ADD tag has a very adlib form. It can be many of the
# ADD:Token define in the master_list but is also can be
# of the form ADD:Any test whatsoever(...). And there is also
# the fact that the ':' is used in the name...
#
# In short, it's a pain.
#
# The above describes the pre 5.12 syntax
# For 5.12, the syntax has changed.
# It is now:
# ADD:subtoken[|number]|blah
#
# This function return a list of three elements.
#   The first one is a return code
#   The second one is the effective TAG if any
#   The third one is anything found after the tag if any
#   The fourth one is the count if one is detected
#
#   Return code 0 = no valid ADD tag found,
#                       1 = old format token ADD tag found,
#                       2 = old format adlib ADD tag found.
#                       3 = 5.12 format ADD tag, using known token.
#                       4 = 5.12 format ADD tag, not using token.

sub parse_ADD_tag {
        my $tag = shift;

        my ($token, $therest, $num_count, $optionlist) = ("", "", 0, "");

        # Old Format
        if ($tag =~ /\s*ADD:([^\(]+)\((.+)\)(\d*)/) {
        ($token, $therest, $num_count) = ($1, $2, $3);
        if (!$num_count) { $num_count = 1; }
                # Is it a known token?
                if ( exists $token_ADD_tag{"ADD:$token"} ) {
                return ( 1, "ADD:$token", $therest, $num_count );
                }
                # Is it the right form? => ADD:any text(any text)
                # Note that no check is done to see if the () are balanced.
                # elsif ( $therest =~ /^\((.*)\)(\d*)\s*$/ ) {
        else {
                return ( 2, "ADD:$token", $therest, $num_count);
                }
        }

        # New format ADD tag.
#       if ($tag =~ /\s*ADD:([^\|]+)(\|[^\|]*)\|(.+)/) {
        if ($tag =~ /\s*ADD:([^\|]+)(\|\d+)?\|(.+)/) {

        ($token, $num_count, $optionlist) = ($1, $2, $3);
        if (!$num_count) { $num_count = 1; }

        if ( exists $token_ADD_tag{"ADD:$token"}) {
                return ( 3, "ADD:$token", $optionlist, $num_count);
        }
        else {
                return ( 4, "ADD:$token", $optionlist, $num_count);
        }
        }

        # Not a good ADD tag.
        return ( 0, "", undef, 0 );
}

###############################################################
# parse_tag
# ---------
#
# This function
#
# Most commun use is for addition, conversion or removal of tags.
#
# Paramter: $tag_text           Text to parse
#               $linetype               Type for the current line
#               $file_for_error   Name of the current file
#               $line_for_error   Number of the current line
#
# Return:   in scallar context, return $tag
#               in array context, return ($tag,$value)

sub parse_tag {
        my ( $tag_text, $linetype, $file_for_error, $line_for_error ) = @_;
        my $no_more_error = 0;  # Set to 1 if no more error must be displayed.

        # We remove the enclosing quotes if any
        $logging->warning( qq{Removing quotes around the '$tag_text' tag}, $file_for_error, $line_for_error)
                if $tag_text =~ s/^"(.*)"$/$1/;

        # Is this a pragma?
        if ( $tag_text =~ /^(\#.*?):(.*)/ ) {
                return wantarray ? ( $1, $2 ) : $1 if exists $valid_tags{$linetype}{$1};
        }

        # Return already if no text to parse (comment)
        return wantarray ? ( "", "" ) : ""
                if length $tag_text == 0 || $tag_text =~ /^\s*\#/;

        # Remove any spaces before and after the tag
        $tag_text =~ s/^\s+//;
        $tag_text =~ s/\s+$//;

        # Separate the tag name from its value
        my ( $tag, $value ) = split ':', $tag_text, 2;

        # All PCGen should at least have TAG_NAME:TAG_VALUE, anything else
        # is an anomaly. The only exception to this rule is LICENSE that
        # can be used without value to display empty line.
        if ( (!defined $value || $value eq q{})
                && $tag_text ne 'LICENSE:'
                ) {
                $logging->warning(
                        qq(The tag "$tag_text" is missing a value (or you forgot a : somewhere)),
                        $file_for_error,
                        $line_for_error
                );

                # We set the value to prevent further errors
                $value = q{};
        }

        # If there is a ! in front of a PRExxx tag, we remove it
        my $negate_pre = $tag =~ s/^!(pre)/$1/i ? 1 : 0;

        # [ 1387361 ] No KIT STARTPACK entry for \"KIT:xxx\"
        # STARTPACK lines in Kit files weren't getting added to $valid_entities.
        # If they aren't added to valid_entities, since the verify flag is set,
        # each Kit will
        # cause a spurious error. I've added them to valid entities to prevent
        # that.
        if ($tag eq 'STARTPACK') {
                $valid_entities{'KIT STARTPACK'}{"KIT:$value"}++;
                $valid_entities{'KIT STARTPACK'}{"$value"}++;
        }

        # [ 1678570 ] Correct PRESPELLTYPE syntax
        # PRESPELLTYPE conversion
        if (Pretty::Options::isConversionActive('ALL:PRESPELLTYPE Syntax') &&
                $tag eq 'PRESPELLTYPE' &&
                $tag_text =~ /^PRESPELLTYPE:([^\d]+),(\d+),(\d+)/)
        {
                my ($spelltype, $num_spells, $num_levels) = ($1, $2, $3);
                #$tag_text =~ /^PRESPELLTYPE:([^,\d]+),(\d+),(\d+)/;
                $value = "$num_spells,";
                # Common homebrew mistake is to include Arcade|Divine, since the
                # 5.8 documentation had an example that showed this. Might
                # as well handle it while I'm here.
                my @spelltypes = split(/\|/,$spelltype);
                foreach my $st (@spelltypes) {
                        $value .= "$st=$num_levels";
                }
                $logging->notice(
                                qq{Invalid standalone PRESPELLTYPE tag "$tag_text" found and converted in $linetype.},
                                $file_for_error,
                                $line_for_error
                                );
        }
        # Continuing the fix - fix it anywhere. This is meant to address PRE tags
        # that are on the end of other tags or in PREMULTS.
        # I'll leave out the pipe-delimited error here, since it's more likely
        # to end up with confusion when the tag isn't standalone.
        elsif (Pretty::Options::isConversionActive('ALL:PRESPELLTYPE Syntax')
                && $tag_text =~ /PRESPELLTYPE:([^\d]+),(\d+),(\d+)/)
        {
                $value =~ s/PRESPELLTYPE:([^\d,]+),(\d+),(\d+)/PRESPELLTYPE:$2,$1=$3/g;
                                $logging->notice(
                                        qq{Invalid embedded PRESPELLTYPE tag "$tag_text" found and converted $linetype.},
                                        $file_for_error,
                                        $line_for_error
                                );
        }

        # Special cases like ADD:... and BONUS:...
        if ( $tag eq 'ADD' ) {
                my ( $type, $addtag, $therest, $add_count )
                = parse_ADD_tag( $tag_text );
                #       Return code     0 = no valid ADD tag found,
                #                       1 = old format token ADD tag found,
                #                       2 = old format adlib ADD tag found.
                #                       3 = 5.12 format ADD tag, using known token.
                #                       4 = 5.12 format ADD tag, not using token.

                if ($type) {
                # It's a ADD:token tag
                if ( $type == 1) {
                        $tag   = $addtag;
                        $value = "($therest)$add_count";
                }
                        if ((($type == 1) || ($type == 2)) && (Pretty::Options::isConversionActive('ALL:ADD Syntax Fix')))
                        {
                                $tag = "ADD:";
                                $addtag =~ s/ADD://;
                                $value = "$addtag|$add_count|$therest";
                        }
                }
                else {
                        unless ( index( $tag_text, '#' ) == 0 ) {
                                $logging->notice(
                                        qq{Invalid ADD tag "$tag_text" found in $linetype.},
                                        $file_for_error,
                                        $line_for_error
                                );
                                $count_tags{"Invalid"}{"Total"}{$addtag}++;
                                $count_tags{"Invalid"}{$linetype}{$addtag}++;
                                $no_more_error = 1;
                        }
                }
        }

        if ( $tag eq 'QUALIFY' ) {
                my ($qualify_type) = ($value =~ /^([^=:|]+)/ );
                if ($qualify_type && exists $token_QUALIFY_tag{$qualify_type} ) {
                        $tag .= ':' . $qualify_type;
                        $value =~ s/^$qualify_type(.*)/$1/;
                }
                elsif ($qualify_type) {
                        # No valid Qualify type found
                        $count_tags{"Invalid"}{"Total"}{"$tag:$qualify_type"}++;
                        $count_tags{"Invalid"}{$linetype}{"$tag:$qualify_type"}++;
                        $logging->notice(
                                qq{Invalid QUALIFY:$qualify_type tag "$tag_text" found in $linetype.},
                                $file_for_error,
                                $line_for_error
                        );
                        $no_more_error = 1;
                }
                else {
                        $count_tags{"Invalid"}{"Total"}{"QUALIFY"}++;
                        $count_tags{"Invalid"}{$linetype}{"QUALIFY"}++;
                        $logging->notice(
                                qq{Invalid QUALIFY tag "$tag_text" found in $linetype},
                                $file_for_error,
                                $line_for_error
                        );
                        $no_more_error = 1;
                }
        }

        if ( $tag eq 'BONUS' ) {
                my ($bonus_type) = ( $value =~ /^([^=:|]+)/ );

                if ( $bonus_type && exists $token_BONUS_tag{$bonus_type} ) {

                        # Is it valid for the curent file type?
                        $tag .= ':' . $bonus_type;
                        $value =~ s/^$bonus_type(.*)/$1/;
                }
                elsif ($bonus_type) {

                        # No valid bonus type was found
                        $count_tags{"Invalid"}{"Total"}{"$tag:$bonus_type"}++;
                        $count_tags{"Invalid"}{$linetype}{"$tag:$bonus_type"}++;
                        $logging->notice(
                                qq{Invalid BONUS:$bonus_type tag "$tag_text" found in $linetype.},
                                $file_for_error,
                                $line_for_error
                        );
                        $no_more_error = 1;
                }
                else {
                        $count_tags{"Invalid"}{"Total"}{"BONUS"}++;
                        $count_tags{"Invalid"}{$linetype}{"BONUS"}++;
                        $logging->notice(
                                qq{Invalid BONUS tag "$tag_text" found in $linetype},
                                $file_for_error,
                                $line_for_error
                        );
                        $no_more_error = 1;
                }
        }

        if ( $tag eq 'PROFICIENCY' ) {
                my ($prof_type) = ( $value =~ /^([^=:|]+)/ );

                if ( $prof_type && exists $token_PROFICIENCY_tag{$prof_type} ) {

                        # Is it valid for the curent file type?
                        $tag .= ':' . $prof_type;
                        $value =~ s/^$prof_type(.*)/$1/;
                }
                elsif ($prof_type) {

                        # No valid bonus type was found
                        $count_tags{"Invalid"}{"Total"}{"$tag:$prof_type"}++;
                        $count_tags{"Invalid"}{$linetype}{"$tag:$prof_type"}++;
                        $logging->notice(
                                qq{Invalid PROFICIENCY:$prof_type tag "$tag_text" found in $linetype.},
                                $file_for_error,
                                $line_for_error
                        );
                        $no_more_error = 1;
                }
                else {
                        $count_tags{"Invalid"}{"Total"}{"PROFICIENCY"}++;
                        $count_tags{"Invalid"}{$linetype}{"PROFICIENCY"}++;
                        $logging->notice(
                                qq{Invalid PROFICIENCY tag "$tag_text" found in $linetype},
                                $file_for_error,
                                $line_for_error
                        );
                        $no_more_error = 1;
                }
        }


        # [ 832171 ] AUTO:* needs to be separate tags
        if ( $tag eq 'AUTO' ) {
                my $found_auto_type;
                AUTO_TYPE:
                for my $auto_type ( sort { length($b) <=> length($a) || $a cmp $b } @token_AUTO_tag ) {
                        if ( $value =~ s/^$auto_type// ) {
                                # We found what we were looking for
                                $found_auto_type = $auto_type;
                                last AUTO_TYPE;
                        }
                }

                if ($found_auto_type) {
                        $tag .= ':' . $found_auto_type;
                }
                else {

                        # No valid auto type was found
                        if ( $value =~ /^([^=:|]+)/ ) {
                                $count_tags{"Invalid"}{"Total"}{"$tag:$1"}++;
                                $count_tags{"Invalid"}{$linetype}{"$tag:$1"}++;
                                $logging->notice(
                                        qq{Invalid $tag:$1 tag "$tag_text" found in $linetype.},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                        else {
                                $count_tags{"Invalid"}{"Total"}{"AUTO"}++;
                                $count_tags{"Invalid"}{$linetype}{"AUTO"}++;
                                $logging->notice(
                                        qq{Invalid AUTO tag "$tag_text" found in $linetype},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                        $no_more_error = 1;

                }
        }

        # [ 813504 ] SPELLLEVEL:DOMAIN in domains.lst
        # SPELLLEVEL is now a multiple level tag like ADD and BONUS

        if ( $tag eq 'SPELLLEVEL' ) {
                if ( $value =~ s/^CLASS(?=\|)// ) {
                        # It's a SPELLLEVEL:CLASS tag
                        $tag = "SPELLLEVEL:CLASS";
                }
                elsif ( $value =~ s/^DOMAIN(?=\|)// ) {
                        # It's a SPELLLEVEL:DOMAIN tag
                        $tag = "SPELLLEVEL:DOMAIN";
                }
                else {
                        # No valid SPELLLEVEL subtag was found
                        if ( $value =~ /^([^=:|]+)/ ) {
                                $count_tags{"Invalid"}{"Total"}{"$tag:$1"}++;
                                $count_tags{"Invalid"}{$linetype}{"$tag:$1"}++;
                                $logging->notice(
                                        qq{Invalid SPELLLEVEL:$1 tag "$tag_text" found in $linetype.},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                        else {
                                $count_tags{"Invalid"}{"Total"}{"SPELLLEVEL"}++;
                                $count_tags{"Invalid"}{$linetype}{"SPELLLEVEL"}++;
                                $logging->notice(
                                        qq{Invalid SPELLLEVEL tag "$tag_text" found in $linetype},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                        $no_more_error = 1;
                }
        }

        # [ 2544134 ] New Token - SPELLKNOWN

        if ( $tag eq 'SPELLKNOWN' ) {
                if ( $value =~ s/^CLASS(?=\|)// ) {
                        # It's a SPELLKNOWN:CLASS tag
                        $tag = "SPELLKNOWN:CLASS";
                }
                elsif ( $value =~ s/^DOMAIN(?=\|)// ) {
                        # It's a SPELLKNOWN:DOMAIN tag
                        $tag = "SPELLKNOWN:DOMAIN";
                }
                else {
                        # No valid SPELLKNOWN subtag was found
                        if ( $value =~ /^([^=:|]+)/ ) {
                                $count_tags{"Invalid"}{"Total"}{"$tag:$1"}++;
                                $count_tags{"Invalid"}{$linetype}{"$tag:$1"}++;
                                $logging->notice(
                                        qq{Invalid SPELLKNOWN:$1 tag "$tag_text" found in $linetype.},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                        else {
                                $count_tags{"Invalid"}{"Total"}{"SPELLKNOWN"}++;
                                $count_tags{"Invalid"}{$linetype}{"SPELLKNOWN"}++;
                                $logging->notice(
                                        qq{Invalid SPELLKNOWN tag "$tag_text" found in $linetype},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                        $no_more_error = 1;
                }
        }

        # All the .CLEAR must be separated tags to help with the
        # tag ordering. That is, we need to make sure the .CLEAR
        # is ordered before the normal tag.
        # If the .CLEAR version of the tag doesn't exists, we do not
        # change the tag name but we give a warning.
        #$logging->debug ( qq{parse_tag:$tag_text}, $file_for_error, $line_for_error );
        if ( defined $value && $value =~ /^.CLEAR/i ) {
                if ( exists $valid_tags{$linetype}{"$tag:.CLEARALL"} ) {
                        # Nothing to see here. Move on.
                }
                elsif ( !exists $valid_tags{$linetype}{"$tag:.CLEAR"} ) {
                        $logging->notice(
                                qq{The tag "$tag:.CLEAR" from "$tag_text" is not in the $linetype tag list\n},
                                $file_for_error,
                                $line_for_error
                        );
                        $count_tags{"Invalid"}{"Total"}{"$tag:.CLEAR"}++;
                        $count_tags{"Invalid"}{$linetype}{"$tag:.CLEAR"}++;
                        $no_more_error = 1;
                }
                else {
                        $value =~ s/^.CLEAR//i;
                        $tag .= ':.CLEAR';
                }
        }

        # Verify if the tag is valid for the line type
        my $real_tag = ( $negate_pre ? "!" : "" ) . $tag;

        if ( !$no_more_error && !exists $valid_tags{$linetype}{$tag} && index( $tag_text, '#' ) != 0 ) {
                my $do_warn = 1;
                if ($tag_text =~ /^ADD:([^\(\|]+)[\|\(]+/) {
                        my $tag_text = ($1);
                        if (exists $valid_tags{$linetype}{"ADD:$tag_text"}) {
                                $do_warn = 0;
                        }
                }
                if ($do_warn) {
                        $logging->notice(
                                qq{The tag "$tag" from "$tag_text" is not in the $linetype tag list\n},
                                $file_for_error,
                                $line_for_error
                                );
                        $count_tags{"Invalid"}{"Total"}{$real_tag}++;
                        $count_tags{"Invalid"}{$linetype}{$real_tag}++;
                }
        }
        elsif ( exists $valid_tags{$linetype}{$tag} ) {

                # Statistic gathering
                $count_tags{"Valid"}{"Total"}{$real_tag}++;
                $count_tags{"Valid"}{$linetype}{$real_tag}++;
        }

        # Check and reformat the values for the tags with
        # only a limited number of values.

        if ( exists $tag_fix_value{$tag} ) {

                # All the limited value are uppercase except the alignment value 'Deity'
                my $newvalue = uc($value);
                my $is_valid = 1;

                # Special treament for the ALIGN tag
                if ( $tag eq 'ALIGN' || $tag eq 'PREALIGN' ) {
                # It is possible for the ALIGN and PREALIGN tags to have more then
                # one value

                # ALIGN use | for separator, PREALIGN use ,
                my $slip_patern = $tag eq 'PREALIGN' ? qr{[,]}xms : qr{[|]}xms;

                for my $align (split $slip_patern, $newvalue) {
                        if ( $align eq 'DEITY' ) { $align = 'Deity'; }
                        # Is it a number?
                        my $number;
                        if ( (($number) = ($align =~ / \A (\d+) \z /xms))
                                && $number >= 0
                                && $number < scalar @valid_system_alignments
                        ) {
                                $align = $valid_system_alignments[$number];
                                $newvalue =~ s{ (?<! \d ) ($number) (?! \d ) }{$align}xms;
                        }

                        # Is it a valid alignment?
                        if (!exists $tag_fix_value{$tag}{$align}) {
                                $logging->notice(
                                        qq{Invalid value "$align" for tag "$real_tag"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                $is_valid = 0;
                        }
                }
                }
                else {
                # Standerdize the YES NO and other such tags
                if ( exists $tag_proper_value_for{$newvalue} ) {
                        $newvalue = $tag_proper_value_for{$newvalue};
                }

                # Is this a proper value for the tag?
                if ( !exists $tag_fix_value{$tag}{$newvalue} ) {
                        $logging->notice(
                                qq{Invalid value "$value" for tag "$real_tag"},
                                $file_for_error,
                                $line_for_error
                        );
                        $is_valid = 0;
                }
                }



                # Was the tag changed ?
                if ( $is_valid && $value ne $newvalue && !( $tag eq 'ALIGN' || $tag eq 'PREALIGN' )) {
                $logging->warning(
                        qq{Replaced "$real_tag:$value" by "$real_tag:$newvalue"},
                        $file_for_error,
                        $line_for_error
                );
                $value = $newvalue;
                }
        }

        ############################################################
        ######################## Conversion ########################
        # We manipulate the tag here
        additionnal_tag_parsing( $real_tag, $value, $linetype, $file_for_error, $line_for_error );

        ############################################################
        # We call the validating function if needed
        validate_tag( $real_tag, $value, $linetype, $file_for_error, $line_for_error )
                if getOption('xcheck');

        # If there is already a :  in the tag name, no need to add one more
        my $need_sep = index( $real_tag, ':' ) == -1 ? q{:} : q{};

        $logging->debug ( qq{parse_tag: $tag_text}, $file_for_error, $line_for_error ) if $value eq q{};

        # We change the tag_text value from the caller
        # This is very ugly but it gets th job done
        $_[0] = $real_tag;
        $_[0] .= $need_sep . $value if defined $value;

        # Return the tag
        wantarray ? ( $real_tag, $value ) : $real_tag;

}

BEGIN {

        # EQUIPMENT types that are valid in NATURALATTACKS tags
        my %valid_NATURALATTACKS_type = (

                # WEAPONTYPE defined in miscinfo.lst
                Bludgeoning => 1,
                Piercing        => 1,
                Slashing        => 1,
                Fire            => 1,
                Acid            => 1,
                Electricity => 1,
                Cold            => 1,
                Poison  => 1,
                Sonic           => 1,

                # WEAPONCATEGORY defined in miscinfo.lst 3e and 35e
                Simple  => 1,
                Martial => 1,
                Exotic  => 1,
                Natural => 1,

                # Additional WEAPONCATEGORY defined in miscinfo.lst Modern and Sidewinder
                HMG                     => 1,
                RocketLauncher  => 1,
                GrenadeLauncher => 1,

                # Additional WEAPONCATEGORY defined in miscinfo.lst Spycraft
                Hurled   => 1,
                Melee   => 1,
                Handgun  => 1,
                Rifle   => 1,
                Tactical => 1,

                # Additional WEAPONCATEGORY defined in miscinfo.lst Xcrawl
                HighTechMartial => 1,
                HighTechSimple  => 1,
                ShipWeapon      => 1,
        );

        my %valid_WIELDCATEGORY = map { $_ => 1 } (

                # From miscinfo.lst 35e
                'Light',
                'OneHanded',
                'TwoHanded',
                'ToSmall',
                'ToLarge',
                'Unusable',
                'None',

                # Hardcoded
                'ALL',
        );

###############################################################
# validate_tag
# ------------
#
# This function stores data for later validation. It also checks
# the syntax of certain tags and detects common errors and
# deprecations.
#
# The %referer hash must be populated following this format
# $referer{$lintype}{$name} = [ $err_desc, $file_for_error, $line_for_error ]
#
# Paramter: $tag_name           Name of the tag (before the :)
#               $tag_value              Value of the tag (after the :)
#               $linetype               Type for the current file
#               $file_for_error   Name of the current file
#               $line_for_error   Number of the current line

        sub validate_tag {
                my ( $tag_name, $tag_value, $linetype, $file_for_error, $line_for_error ) = @_;
        study $tag_value;

                if ($tag_name eq 'STARTPACK')
                {
                        $valid_entities{'KIT STARTPACK'}{"KIT:$tag_value"}++;
                        $valid_entities{'KIT'}{"KIT:$tag_value"}++;
                }

                elsif ( $tag_name =~ /^\!?PRE/ ) {

                        # It's a PRExxx tag, we delegate
                        return validate_pre_tag( $tag_name,
                                $tag_value,
                                "",
                                $linetype,
                                $file_for_error,
                                $line_for_error
                        );
                }
                elsif (index( $tag_name, 'PROFICIENCY' ) == 0 ) {

                }
                elsif ( index( $tag_name, 'BONUS' ) == 0 ) {

                # Are there any PRE tags in the BONUS tag.
                if ( $tag_value =~ /(!?PRE[A-Z]*):([^|]*)/ ) {

                        # A PRExxx tag is present
                        validate_pre_tag($1,
                                                $2,
                                                "$tag_name$tag_value",
                                                $linetype,
                                                $file_for_error,
                                                $line_for_error
                        );
                }

                if ( $tag_name eq 'BONUS:CHECKS' ) {
                        # BONUS:CHECKS|<check list>|<jep> {|TYPE=<bonus type>} {|<pre tags>}
                        # BONUS:CHECKS|ALL|<jep>                {|TYPE=<bonus type>} {|<pre tags>}
                        # <check list> :=   ( <check name 1> { | <check name 2> } { | <check name 3>} )
                        #                       | ( BASE.<check name 1> { | BASE.<check name 2> } { | BASE.<check name 3>} )

                        # We get parameter 1 and 2 (0 is empty since $tag_value begins with a |)
                        my ($check_names,$jep) = ( split /[|]/, $tag_value ) [1,2];

                        # The checkname part
                        if ( $check_names ne 'ALL' ) {
                                # We skip ALL as it is a special value that must be used alone

                                # $check_name => YES or NO to indicates if BASE. is used
                                my ($found_base, $found_non_base) = ( NO, NO );

                                for my $check_name ( split q{,}, $check_names ) {
                                # We keep the original name for error messages
                                my $clean_check_name = $check_name;

                                # Did we use BASE.? is yes, we remove it
                                if ( $clean_check_name =~ s/ \A BASE [.] //xms ) {
                                        $found_base = YES;
                                }
                                else {
                                        $found_non_base = YES;
                                }

                                # Is the check name valid
                                if ( !exists $valid_check_name{$clean_check_name} ) {
                                        $logging->notice(
                                                qq{Invalid save check name "$clean_check_name" found in "$tag_name$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                }

                                # Verify if there is a mix of BASE and non BASE
                                if ( $found_base && $found_non_base ) {
                                $logging->info(
                                        qq{Are you sure you want to mix BASE and non-BASE in "$tag_name$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }

                        # The formula part
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq{@@" in "$tag_name$tag_value},
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $jep,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];

                }
                elsif ( $tag_name eq 'BONUS:FEAT' ) {

                        # BONUS:FEAT|POOL|<formula>|<prereq list>|<bonus type>

                        # @list_of_param will contains all the non-empty parameters
                        # included in $tag_value. The first one should always be
                        # POOL.
                        my @list_of_param = grep {/./} split '\|', $tag_value;

                        if ( ( shift @list_of_param ) ne 'POOL' ) {

                                # For now, only POOL is valid here
                                $logging->notice(
                                qq{Only POOL is valid as second paramater for BONUS:FEAT "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                                );
                        }

                        # The next parameter is the formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        ( shift @list_of_param ),
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];

                        # For the rest, we need to check if it is a PRExxx tag or a TYPE=
                        my $type_present = 0;
                        for my $param (@list_of_param) {
                                if ( $param =~ /^(!?PRE[A-Z]+):(.*)/ ) {

                                # It's a PRExxx tag, we delegate the validation
                                validate_pre_tag($1,
                                                        $2,
                                                        "$tag_name$tag_value",
                                                        $linetype,
                                                        $file_for_error,
                                                        $line_for_error
                                );
                                }
                                elsif ( $param =~ /^TYPE=(.*)/ ) {
                                $type_present++;
                                }
                                else {
                                $logging->notice(
                                        qq{Invalid parameter "$param" found in "$tag_name$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }

                        if ( $type_present > 1 ) {
                                $logging->notice(
                                qq{There should be only one "TYPE=" in "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                }
                if (   $tag_name eq 'BONUS:MOVEADD'
                        || $tag_name eq 'BONUS:MOVEMULT'
                        || $tag_name eq 'BONUS:POSTMOVEADD' )
                {

                        # BONUS:MOVEMULT|<list of move types>|<number to add or mult>
                        # <list of move types> is a comma separated list of a weird TYPE=<move>.
                        # The <move> are found in the MOVE tags.
                        # <number to add or mult> can be a formula

                        my ( $type_list, $formula ) = ( split '\|', $tag_value )[ 1, 2 ];

                        # We keep the move types for validation
                        for my $type ( split ',', $type_list ) {
                                if ( $type =~ /^TYPE(=|\.)(.*)/ ) {
                                push @xcheck_to_process,
                                        [
                                        'MOVE Type',    qq(TYPE$1@@" in "$tag_name$tag_value),
                                        $file_for_error, $line_for_error,
                                        $2
                                        ];
                                }
                                else {
                                $logging->notice(
                                        qq(Missing "TYPE=" for "$type" in "$tag_name$tag_value"),
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }

                        # Then we deal with the var in formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $formula,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];
                }
                elsif ( $tag_name eq 'BONUS:SLOTS' ) {

                        # BONUS:SLOTS|<slot types>|<number of slots>
                        # <slot types> is a comma separated list.
                        # The valid types are defined in %token_BONUS_SLOTS_types
                        # <number of slots> could be a formula.

                        my ( $type_list, $formula ) = ( split '\|', $tag_value )[ 1, 2 ];

                        # We first check the slot types
                        for my $type ( split ',', $type_list ) {
                                unless ( exists $token_BONUS_SLOTS_types{$type} ) {
                                $logging->notice(
                                        qq{Invalid slot type "$type" in "$tag_name$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }

                        # Then we deal with the var in formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $formula,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];
                }
                elsif ( $tag_name eq 'BONUS:VAR' ) {

                        # BONUS:VAR|List of Names|Formula|... only the first two values are variable related.
                        my ( $var_name_list, @formulas )
                                = ( split '\|', $tag_value )[ 1, 2 ];

                        # First we store the DEFINE variable name
                        for my $var_name ( split ',', $var_name_list ) {
                                if ( $var_name =~ /^[a-z][a-z0-9_\s]*$/i ) {
                                # LIST is filtered out as it may not be valid for the
                                # other places were a variable name is used.
                                if ( $var_name ne 'LIST' ) {
                                        push @xcheck_to_process,
                                                [
                                                'DEFINE Variable',
                                                qq(@@" in "$tag_name$tag_value),
                                                $file_for_error,
                                                $line_for_error,
                                                $var_name,
                                                ];
                                }
                                }
                                else {
                                $logging->notice(
                                        qq{Invalid variable name "$var_name" in "$tag_name$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }

                        # Second we deal with the formula
                        # %CHOICE is filtered out as it may not be valid for the
                        # other places were a variable name is used.
                        for my $formula ( grep { $_ ne '%CHOICE' } @formulas ) {
                                push @xcheck_to_process,
                                        [
                                        'DEFINE Variable',
                                        qq(@@" in "$tag_name$tag_value),
                                        $file_for_error,
                                        $line_for_error,
                                        parse_jep(
                                                $formula,
                                                "$tag_name$tag_value",
                                                $file_for_error,
                                                $line_for_error
                                        )
                                        ];
                        }
                }
                elsif ( $tag_name eq 'BONUS:WIELDCATEGORY' ) {

                        # BONUS:WIELDCATEGORY|<List of category>|<formula>
                        my ( $category_list, $formula ) = ( split '\|', $tag_value )[ 1, 2 ];

                        # Validate the category to see if valid
                        for my $category ( split ',', $category_list ) {
                                if ( !exists $valid_WIELDCATEGORY{$category} ) {
                                $logging->notice(
                                        qq{Invalid category "$category" in "$tag_name$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }

                        # Second, we deal with the formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $formula,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];

                }
                }
                elsif ( $tag_name eq 'CLASSES' || $tag_name eq 'DOMAINS' ) {
                if ( $linetype eq 'SPELL' ) {
                        my %seen;
                        my $tag_to_check = $tag_name eq 'CLASSES' ? 'CLASS' : 'DOMAIN';

                        # First we find all the classes used
                        for my $level ( split '\|', $tag_value ) {
                                if ( $level =~ /(.*)=(\d+)/ ) {
                                for my $entity ( split ',', $1 ) {

                                        # [ 849365 ] CLASSES:ALL
                                        # CLASSES:ALL is OK
                                        # Arcane and Divine are not really OK but they are used
                                        # as placeholders for use in the MSRD.
                                        if ((  $tag_to_check eq "CLASS"
                                                && (   $entity ne "ALL"
                                                        && $entity ne "Arcane"
                                                        && $entity ne "Divine" )
                                                )
                                                || $tag_to_check eq "DOMAIN"
                                                )
                                        {
                                                push @xcheck_to_process,
                                                [
                                                $tag_to_check,   $tag_name,
                                                $file_for_error, $line_for_error,
                                                $entity
                                                ];

                                                if ( $seen{$entity}++ ) {
                                                $logging->notice(
                                                        qq{"$entity" found more then once in $tag_name},
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                                }
                                        }
                                }
                                }
                                else {
                                        if ( "$tag_name:$level" eq 'CLASSES:.CLEARALL' ) {
                                                # Nothing to see here. Move on.
                                        }
                                        else {
                                                $logging->warning(
                                                        qq{Missing "=level" after "$tag_name:$level"},
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                        }
                                }
                        }
                }
                elsif ( $linetype eq 'SKILL' ) {

                        # Only CLASSES in SKILL
                        CLASS_FOR_SKILL:
                        for my $class ( split '\|', $tag_value ) {

                                # ALL is valid here
                                next CLASS_FOR_SKILL if $class eq 'ALL';

                                push @xcheck_to_process,
                                [
                                'CLASS',                $tag_name,
                                $file_for_error, $line_for_error,
                                $class
                                ];
                        }
                }
                elsif (   $linetype eq 'DEITY' ) {
                        # Only DOMAINS in DEITY
                        if ($tag_value =~ /\|/ ) {
                        $tag_value = substr($tag_value, 0, rindex($tag_value, "\|"));
                        }
                        DOMAIN_FOR_DEITY:
                        for my $domain ( split ',', $tag_value ) {

                                # ALL is valid here
                                next DOMAIN_FOR_DEITY if $domain eq 'ALL';

                                push @xcheck_to_process,
                                [
                                'DOMAIN',               $tag_name,
                                $file_for_error, $line_for_error,
                                $domain
                                ];
                        }
                }
                }
                elsif ( $tag_name eq 'CLASS'
                        && $linetype ne 'PCC'
                ) {
                # Note: The CLASS linetype doesn't have any CLASS tag, it's
                #               called 000ClassName internaly. CLASS is a tag used
                #               in other line types like KIT CLASS.
                # CLASS:<class name>,<class name>,...[BASEAGEADD:<dice expression>]

                # We remove and ignore [BASEAGEADD:xxx] if present
                my $list_of_class = $tag_value;
                $list_of_class =~ s{ \[ BASEAGEADD: [^]]* \] }{}xmsg;

                push @xcheck_to_process,
                        [
                                'CLASS',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                (split /[|,]/, $list_of_class),
                        ];
                }
                elsif ( $tag_name eq 'DEITY'
                        && $linetype ne 'PCC'
                ) {
                # DEITY:<deity name>|<deity name>|etc.
                push @xcheck_to_process,
                        [
                                'DEITY',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                (split /[|]/, $tag_value),
                        ];
                }
                elsif ( $tag_name eq 'DOMAIN'
                        && $linetype ne 'PCC'
                ) {
                # DOMAIN:<domain name>|<domain name>|etc.
                push @xcheck_to_process,
                        [
                                'DOMAIN',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                (split /[|]/, $tag_value),
                        ];
                }
                elsif ( $tag_name eq 'ADDDOMAINS' ) {

                # ADDDOMAINS:<domain1>.<domain2>.<domain3>. etc.
                push @xcheck_to_process,
                        [
                        'DOMAIN',               $tag_name,
                        $file_for_error, $line_for_error,
                        split '\.',     $tag_value
                        ];
                }
                elsif ( $tag_name eq 'ADD:SPELLCASTER' ) {

                # ADD:SPELLCASTER(<list of classes>)<formula>
                if ( $tag_value =~ /\((.*)\)(.*)/ ) {
                        my ( $list, $formula ) = ( $1, $2 );

                        # First the list of classes
                        # ANY, ARCANA, DIVINE and PSIONIC are spcial hardcoded cases for
                        # the ADD:SPELLCASTER tag.
                        push @xcheck_to_process, [
                                'CLASS',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                grep {
                                                uc($_) ne 'ANY'
                                        && uc($_) ne 'ARCANE'
                                        && uc($_) ne 'DIVINE'
                                        && uc($_) ne 'PSIONIC'
                                }
                                split ',', $list
                        ];

                        # Second, we deal with the formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" from "$formula" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $formula,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];
                }
                else {
                        $logging->notice(
                                qq{Invalid syntax: "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ( $tag_name eq 'ADD:EQUIP' ) {

                # ADD:EQUIP(<list of equipments>)<formula>
                if ( $tag_value =~ m{ [(]   # Opening brace
                                                (.*)  # Everything between braces include other braces
                                                [)]   # Closing braces
                                                (.*)  # The rest
                                                }xms ) {
                        my ( $list, $formula ) = ( $1, $2 );

                        # First the list of equipements
                        # ANY is a spcial hardcoded cases for ADD:EQUIP
                        push @xcheck_to_process,
                                [
                                'EQUIPMENT',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                grep { uc($_) ne 'ANY' }
                                        split ',', $list
                                ];

                        # Second, we deal with the formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" from "$formula" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $formula,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                )
                                ];
                }
                else {
                        $logging->notice(
                                qq{Invalid syntax: "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ($tag_name eq 'EQMOD'
                || $tag_name eq 'IGNORES'
                || $tag_name eq 'REPLACES'
                || ( $tag_name =~ /!?PRETYPE/ && $tag_value =~ /(\d+,)?EQMOD=/ )
                ) {

                # This section check for any reference to an EQUIPMOD key
                if ( $tag_name eq 'EQMOD' ) {

                        # The higher level for the EQMOD is the . (who's the genius who
                        # dreamed that up...
                        my @key_list = split '\.', $tag_value;

                        # The key name is everything found before the first |
                        for $_ (@key_list) {
                                my ($key) = (/^([^|]*)/);
                                if ($key) {

                                # To be processed later
                                push @xcheck_to_process,
                                        [
                                        'EQUIPMOD Key',  qq(@@" in "$tag_name:$tag_value),
                                        $file_for_error, $line_for_error,
                                        $key
                                        ];
                                }
                                else {
                                $logging->warning(
                                        qq(Cannot find the key for "$_" in "$tag_name:$tag_value"),
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }
                }
                elsif ( $tag_name eq "IGNORES" || $tag_name eq "REPLACES" ) {

                        # Comma separated list of KEYs
                        # To be processed later
                        push @xcheck_to_process,
                                [
                                'EQUIPMOD Key',  qq(@@" in "$tag_name:$tag_value),
                                $file_for_error, $line_for_error,
                                split ',',              $tag_value
                                ];
                }
                }
                elsif (
                $linetype ne 'PCC'
                && (   $tag_name eq 'ADD:FEAT'
                        || $tag_name eq 'AUTO:FEAT'
                        || $tag_name eq 'FEAT'
                        || $tag_name eq 'FEATAUTO'
                        || $tag_name eq 'VFEAT'
                        || $tag_name eq 'MFEAT' )
                )
                {
                my @feats;
                my $parent = NO;

                # ADD:FEAT(feat,feat,TYPE=type)formula
                # FEAT:feat|feat|feat(xxx)
                # FEAT:feat,feat,feat(xxx)  in the TEMPLATE and DOMAIN
                # FEATAUTO:feat|feat|...
                # VFEAT:feat|feat|feat(xxx)|PRExxx:yyy
                # MFEAT:feat|feat|feat(xxx)|...
                # All these type may have embeded [PRExxx tags]
                if ( $tag_name eq 'ADD:FEAT' ) {
                        if ( $tag_value =~ /^\((.*)\)(.*)?$/ ) {
                                $parent = YES;
                                my $formula = $2;

                                # The ADD:FEAT list may contains list elements that
                                # have () and will need the special split.
                                # The LIST special feat name is valid in ADD:FEAT
                                # So is ALL now.
                                @feats = grep { $_ ne 'LIST' } grep { $_ ne 'ALL' } embedded_coma_split($1);

                                #               # We put the , back in place
                                #               s/&comma;/,/g for @feats;

                                # Here we deal with the formula part
                                push @xcheck_to_process,
                                        [
                                        'DEFINE Variable',
                                        qq(@@" in "$tag_name$tag_value),
                                        $file_for_error,
                                        $line_for_error,
                                        parse_jep(
                                                $formula,
                                                "$tag_name$tag_value",
                                                $file_for_error,
                                                $line_for_error
                                        )
                                        ] if $formula;
                        }
                        else {
                                $logging->notice(
                                qq{Invalid systax: "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                                ) if $tag_value;
                        }
                }
                elsif ( $tag_name eq 'FEAT' ) {

                        # FEAT tags sometime use , and sometime use | as separator.

                        # We can now safely split on the ,
                        @feats = embedded_coma_split( $tag_value, qr{,|\|} );

                        #       # We put the , back in place
                        #       s/&coma;/,/g for @feats;
                }
                else {
                        @feats = split '\|', $tag_value;
                }

                FEAT:
                for my $feat (@feats) {

                        # If it is a PRExxx tag section, we validate teh PRExxx tag.
                        if ( $tag_name eq 'VFEAT' && $feat =~ /^(!?PRE[A-Z]+):(.*)/ ) {
                                validate_pre_tag($1,
                                                        $2,
                                                        "$tag_name:$tag_value",
                                                        $linetype,
                                                        $file_for_error,
                                                        $line_for_error
                                );
                                $feat = "";
                                next FEAT;
                        }

                        # We strip the embeded [PRExxx ...] tags
                        if ( $feat =~ /([^[]+)\[(!?PRE[A-Z]*):(.*)\]$/ ) {
                                $feat = $1;
                                validate_pre_tag($2,
                                                        $3,
                                                        "$tag_name:$tag_value",
                                                        $linetype,
                                                        $file_for_error,
                                                        $line_for_error
                                );
                        }

                }

                my $message_format = $tag_name;
                if ($parent) {
                        $message_format = "$tag_name(@@)";
                }

                # To be processed later
                push @xcheck_to_process,
                        [ 'FEAT', $message_format, $file_for_error, $line_for_error, @feats ];
                }
                elsif ( $tag_name eq 'KIT' && $linetype ne 'PCC' ) {
                # KIT:<number of choice>|<kit name>|<kit name>|etc.
                # KIT:<kit name>
                my @kit_list = split /[|]/, $tag_value;

                # The first item might be a number
                if ( $kit_list[0] =~ / \A \d+ \z /xms ) {
                        # We discard the number
                        shift @kit_list;
                }

                push @xcheck_to_process,
                        [
                                'KIT STARTPACK',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                @kit_list,
                        ];
                }
                elsif ( $tag_name eq 'LANGAUTOxxx' || $tag_name eq 'LANGBONUS' ) {

                # To be processed later
                # The ALL keyword is removed here since it is not usable everywhere there are language
                # used.
                push @xcheck_to_process,
                        [
                        'LANGUAGE', $tag_name, $file_for_error, $line_for_error,
                        grep { $_ ne 'ALL' } split ',', $tag_value
                        ];
                }
                elsif ( $tag_name eq 'ADD:LANGUAGE' ) {

                        # Syntax: ADD:LANGUAGE(<coma separated list of languages)<number>
                        if ( $tag_value =~ /\((.*)\)/ ) {
                                push @xcheck_to_process,
                                        [
                                        'LANGUAGE', 'ADD:LANGUAGE(@@)', $file_for_error, $line_for_error,
                                        split ',',  $1
                                        ];
                        }
                        else {
                                $logging->notice(
                                        qq{Invalid syntax for "$tag_name$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                }
                elsif ( $tag_name eq 'MOVE' ) {

                        # MOVE:<move type>,<value>
                        # ex. MOVE:Walk,30,Fly,20,Climb,10,Swim,10

                        my @list = split ',', $tag_value;

                        MOVE_PAIR:
                        while (@list) {
                                my ( $type, $value ) = ( splice @list, 0, 2 );
                                $value = "" if !defined $value;

                                # $type should be a word and $value should be a number
                                if ( $type =~ /^\d+$/ ) {
                                        $logging->notice(
                                        qq{I was expecting a move type where I found "$type" in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                        );
                                        last;
                                }
                                else {

                                        # We keep the move type for future validation
                                        $valid_entities{'MOVE Type'}{$type}++;
                                }

                                unless ( $value =~ /^\d+$/ ) {
                                        $logging->notice(
                                        qq{I was expecting a number after "$type" and found "$value" in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                        );
                                        last MOVE_PAIR;
                                }
                        }
                } 
                elsif ( $tag_name eq 'MOVECLONE' ) {
                # MOVECLONE:A,B,formula  A and B must be valid move types.
                        if ( $tag_value =~ /^(.*),(.*),(.*)/ ) {
                                # Error if more parameters (Which will show in the first group)
                                if ( $1 =~ /,/ ) {
                                        $logging->warning(
                                        qq{Found too many parameters in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                        );
                                } 
                                else {
                                        # Cross check for used MOVE Types.
                                        push @xcheck_to_process,
                                                [
                                                'MOVE Type', $tag_name, 
                                                $file_for_error, $line_for_error,
                                                $1, $2
                                                ];
                                }
                        }
                        else {
                                # Report missing requisite parameters.
                                $logging->warning(
                                qq{Missing a parameter in in "$tag_name:$tag_value"},
                                $file_for_error,
                                $line_for_error
                                );
                        }


                }
                elsif ( $tag_name eq 'RACE' && $linetype ne 'PCC' ) {
                # There is only one race per RACE tag
                push @xcheck_to_process,
                        [  'RACE',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                $tag_value,
                        ];
                }
                elsif ( $tag_name eq 'SWITCHRACE' ) {

                # To be processed later
                # Note: SWITCHRACE actually switch the race TYPE
                push @xcheck_to_process,
                        [   'RACE TYPE',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                (split '\|',  $tag_value),
                        ];
                }
                elsif ( $tag_name eq 'CSKILL'
                        || $tag_name eq 'CCSKILL'
                        || $tag_name eq 'MONCSKILL'
                        || $tag_name eq 'MONCCSKILL'
                        || ($tag_name eq 'SKILL' && $linetype ne 'PCC')
                ) {
                my @skills = split /[|]/, $tag_value;

                # ALL is a valid use in BONUS:SKILL, xCSKILL  - [ 1593872 ] False warning: No SKILL entry for CSKILL:ALL
                @skills = grep { $_ ne 'ALL' } @skills;

                # We need to filter out %CHOICE for the SKILL tag
                if ( $tag_name eq 'SKILL' ) {
                        @skills = grep { $_ ne '%CHOICE' } @skills;
                }

                # To be processed later
                push @xcheck_to_process,
                        [   'SKILL',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                @skills,
                        ];
                }
                elsif ( $tag_name eq 'ADD:SKILL' ) {

                # ADD:SKILL(<list of skills>)<formula>
                if ( $tag_value =~ /\((.*)\)(.*)/ ) {
                        my ( $list, $formula ) = ( $1, $2 );

                        # First the list of skills
                        # ANY is a spcial hardcoded cases for ADD:EQUIP
                        push @xcheck_to_process,
                                [
                                'SKILL',
                                qq(@@" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                grep { uc($_) ne 'ANY' } split ',', $list
                                ];

                        # Second, we deal with the formula
                        push @xcheck_to_process,
                                [
                                'DEFINE Variable',
                                qq(@@" from "$formula" in "$tag_name$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                        $formula,
                                        "$tag_name$tag_value",
                                        $file_for_error,
                                        $line_for_error
                                ),
                                ];
                }
                else {
                        $logging->notice(
                                qq{Invalid syntax: "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ( $tag_name eq 'SPELLS' ) {
                if ( $linetype ne 'KIT SPELLS' ) {
 # Syntax: SPELLS:<spellbook>|[TIMES=<times per day>|][TIMEUNIT=<unit of time>|][CASTERLEVEL=<CL>|]<Spell list>[|<prexxx tags>]
 # <Spell list> = <Spell name>,<DC> [|<Spell list>]
                        my @list_of_param = split '\|', $tag_value;
                        my @spells;

                        # We drop the Spell book name
                        shift @list_of_param;

                        my $nb_times            = 0;
                        my $nb_timeunit         = 0;
                        my $nb_casterlevel      = 0;
                        my $AtWill_Flag         = NO;
                        for my $param (@list_of_param) {
                                if ( $param =~ /^(TIMES)=(.*)/ || $param =~ /^(TIMEUNIT)=(.*)/ || $param =~ /^(CASTERLEVEL)=(.*)/ ) {
                                        if ( $1 eq 'TIMES' ) {
#                                               $param =~ s/TIMES=-1/TIMES=ATWILL/g;   # SPELLS:xxx|TIMES=-1 to SPELLS:xxx|TIMES=ATWILL conversion
                                                $AtWill_Flag = $param =~ /TIMES=ATWILL/;
                                                $nb_times++;
                                                push @xcheck_to_process,
                                                        [
                                                                'DEFINE Variable',
                                                                qq(@@" in "$tag_name:$tag_value),
                                                                $file_for_error,
                                                                $line_for_error,
                                                                parse_jep(
                                                                        $2,
                                                                        "$tag_name:$tag_value",
                                                                        $file_for_error,
                                                                        $line_for_error
                                                                )
                                                        ];
                                        }
                                        elsif ( $1 eq 'TIMEUNIT' ) {
                                                $nb_timeunit++;
                                                # Is it a valid alignment?
                                                if (!exists $tag_fix_value{$1}{$2}) {
                                                        $logging->notice(
                                                                qq{Invalid value "$2" for tag "$1"},
                                                                $file_for_error,
                                                                $line_for_error
                                                        );
#                                                       $is_valid = 0;
                                                }
                                        }
                                        else {
                                                $nb_casterlevel++;
                                                                                                push @xcheck_to_process,
                                                        [
                                                                'DEFINE Variable',
                                                                qq(@@" in "$tag_name:$tag_value),
                                                                $file_for_error,
                                                                $line_for_error,
                                                                parse_jep(
                                                                        $2,
                                                                        "$tag_name:$tag_value",
                                                                        $file_for_error,
                                                                        $line_for_error
                                                                )
                                                        ];
                                        }
                                }
                                elsif ( $param =~ /^(PRE[A-Z]+):(.*)/ ) {

                                # Embeded PRExxx tags
                                validate_pre_tag($1,
                                                        $2,
                                                        "$tag_name:$tag_value",
                                                        $linetype,
                                                        $file_for_error,
                                                        $line_for_error
                                );
                                }
                                else {
                                my ( $spellname, $dc ) = ( $param =~ /([^,]+),(.*)/ );

                                if ($dc) {

                                        # Spell name must be validated with the list of spells and DC is a formula
                                        push @spells, $spellname;

                                        push @xcheck_to_process,
                                                [
                                                'DEFINE Variable',
                                                qq(@@" in "$tag_name:$tag_value),
                                                $file_for_error,
                                                $line_for_error,
                                                parse_jep(
                                                        $dc,
                                                        "$tag_name:$tag_value",
                                                        $file_for_error,
                                                        $line_for_error
                                                )
                                                ];
                                }
                                else {

                                        # No DC present, the whole param is the spell name
                                        push @spells, $param;

                                        $logging->info(
                                                qq(the DC value is missing for "$param" in "$tag_name:$tag_value"),
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                }
                        }

                        push @xcheck_to_process,
                                [
                                'SPELL',                $tag_name,
                                $file_for_error, $line_for_error,
                                @spells
                                ];

                        # Validate the number of TIMES, TIMEUNIT, and CASTERLEVEL parameters
                        if ( $nb_times != 1 ) {
                                if ($nb_times) {
                                        $logging->notice(
                                                qq{TIMES= should not be used more then once in "$tag_name:$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                else {
                                        $logging->info(
                                                qq(the TIMES= parameter is missing in "$tag_name:$tag_value"),
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                        }

                        if ( $nb_timeunit != 1 ) {
                                if ($nb_timeunit) {
                                        $logging->notice(
                                                qq{TIMEUNIT= should not be used more then once in "$tag_name:$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                else {
                                        if ( $AtWill_Flag ) {
                                                # Do not need a TIMEUNIT tag if the TIMES tag equals AtWill
                                                # Nothing to see here. Move along.
                                        }
                                        else {
                                                # [ 1997408 ] False positive: TIMEUNIT= parameter is missing
                                                # $logging->info(
                                                #       qq(the TIMEUNIT= parameter is missing in "$tag_name:$tag_value"),
                                                #       $file_for_error,
                                                #       $line_for_error
                                                # );
                                        }
                                }
                        }

                        if ( $nb_casterlevel != 1 ) {
                                if ($nb_casterlevel) {
                                $logging->notice(
                                        qq{CASTERLEVEL= should not be used more then once in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                                else {
                                $logging->info(
                                        qq(the CASTERLEVEL= parameter is missing in "$tag_name:$tag_value"),
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }
                }
                else {
                        # KIT SPELLS line type
                        # SPELLS:<parameter list>|<spell list>
                        # <parameter list> = <param id> = <param value { | <parameter list> }
                        # <spell list> := <spell name> { = <number> } { | <spell list> }
                        my @spells = ();

                        for my $spell_or_param (split q{\|}, $tag_value) {
                                # Is it a parameter?
                                if ( $spell_or_param =~ / \A ([^=]*) = (.*) \z/xms ) {
                                my ($param_id,$param_value) = ($1,$2);

                                if ( $param_id eq 'CLASS' ) {
                                        push @xcheck_to_process,
                                                [
                                                'CLASS',
                                                qq{@@" in "$tag_name:$tag_value},
                                                $file_for_error,
                                                $line_for_error,
                                                $param_value,
                                                ];

                                }
                                elsif ( $param_id eq 'SPELLBOOK') {
                                        # Nothing to do
                                }
                                elsif ( $param_value =~ / \A \d+ \z/mxs ) {
                                        # It's a spell after all...
                                        push @spells, $param_id;
                                }
                                else {
                                        $logging->notice(
                                                qq{Invalide SPELLS parameter: "$spell_or_param" found in "$tag_name:$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                }
                                else {
                                # It's a spell
                                push @spells, $spell_or_param;
                                }
                        }

                        if ( scalar @spells ) {
                                push @xcheck_to_process,
                                        [
                                        'SPELL',
                                        $tag_name,
                                        $file_for_error,
                                        $line_for_error,
                                        @spells,
                                        ];
                        }
                }
                }
                elsif ( index( $tag_name, 'SPELLLEVEL:' ) == 0 
                        || index( $tag_name, 'SPELLKNOWN:' ) == 0
                ) {

                # [ 813504 ] SPELLLEVEL:DOMAIN in domains.lst
                # [ 2544134 ] New Token - SPELLKNOWN
                # -------------------------------------------
                # There are two different SPELLLEVEL tags that must
                # be x-check. SPELLLEVEL:CLASS and SPELLLEVEL:DOMAIN.
                #
                # The CLASS type have CLASSes and SPELLs to check and
                # the DOMAIN type have DOMAINs and SPELLs to check.
                #
                # SPELLKNOWN has exact same syntax as SPELLLEVEL, so doing both checks at once.

                if ( $tag_name eq "SPELLLEVEL:CLASS" 
                        || $tag_name eq "SPELLKNOWN:CLASS"
                ) {

                        # The syntax for SPELLLEVEL:CLASS is
                        # SPELLLEVEL:CLASS|<class-list of spells>
                        # <class-list of spells> := <class> | <list of spells> [ | <class-list of spells> ]
                        # <class>                       := <class name> = <level>
                        # <list of spells>              := <spell name> [, <list of spells>]
                        # <class name>          := ASCII WORDS that must be validated
                        # <level>                       := INTEGER
                        # <spell name>          := ASCII WORDS that must be validated
                        #
                        # ex. SPELLLEVEL:CLASS|Wizard=0|Detect Magic,Read Magic|Wizard=1|Burning Hands

                        # [ 1958872 ] trim PRExxx before checking SPELLLEVEL
                        # Work with a copy because we do not want to change the original
                        my $tag_line = $tag_value;
                        study $tag_line;
                        # Remove the PRExxx tags at the end of the line.
                        $tag_line =~ s/\|PRE\w+\:.+$//;

                        # We extract the classes and the spell names
                        if ( my $working_value = $tag_line ) {
                                while ($working_value) {
                                        if ( $working_value =~ s/\|([^|]+)\|([^|]+)// ) {
                                                my $class  = $1;
                                                my $spells = $2;

                                                # The CLASS
                                                if ( $class =~ /([^=]+)\=(\d+)/ ) {

                                                        # [ 849369 ] SPELLCASTER.Arcane=1
                                                        # SPELLCASTER.Arcane and SPELLCASTER.Divine are specials
                                                        # CLASS names that should not be cross-referenced.
                                                        # To be processed later
                                                        push @xcheck_to_process, [
                                                                'CLASS', qq(@@" in "$tag_name$tag_value),
                                                                $file_for_error, $line_for_error, $1
                                                        ];
                                                }
                                                else {
                                                        $logging->notice(
                                                                qq{Invalid syntax for "$class" in "$tag_name$tag_value"},
                                                                $file_for_error,
                                                                $line_for_error
                                                        );
                                                }

                                                # The SPELL names
                                                # To be processed later
                                                push @xcheck_to_process,
                                                        [
                                                                'SPELL',                qq(@@" in "$tag_name$tag_value),
                                                                $file_for_error, $line_for_error,
                                                                split ',',              $spells
                                                        ];
                                        }
                                        else {
                                                $logging->notice(
                                                        qq{Invalid class/spell list paring in "$tag_name$tag_value"},
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                                $working_value = "";
                                        }
                                }
                        }
                        else {
                                $logging->notice(
                                qq{No value found for "$tag_name"},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                }
                if ( $tag_name eq "SPELLLEVEL:DOMAIN" 
                        || $tag_name eq "SPELLKNOWN:DOMAIN"
                ) {

                        # The syntax for SPELLLEVEL:DOMAIN is
                        # SPELLLEVEL:CLASS|<domain-list of spells>
                        # <domain-list of spells> := <domain> | <list of spells> [ | <domain-list of spells> ]
                        # <domain>                      := <domain name> = <level>
                        # <list of spells>              := <spell name> [, <list of spells>]
                        # <domain name>         := ASCII WORDS that must be validated
                        # <level>                       := INTEGER
                        # <spell name>          := ASCII WORDS that must be validated
                        #
                        # ex. SPELLLEVEL:DOMAIN|Air=1|Obscuring Mist|Animal=4|Repel Vermin

                        # We extract the classes and the spell names
                        if ( my $working_value = $tag_value ) {
                                while ($working_value) {
                                if ( $working_value =~ s/\|([^|]+)\|([^|]+)// ) {
                                        my $domain = $1;
                                        my $spells = $2;

                                        # The DOMAIN
                                        if ( $domain =~ /([^=]+)\=(\d+)/ ) {
                                                push @xcheck_to_process,
                                                [
                                                'DOMAIN', qq(@@" in "$tag_name$tag_value),
                                                $file_for_error, $line_for_error, $1
                                                ];
                                        }
                                        else {
                                                $logging->notice(
                                                qq{Invalid syntax for "$domain" in "$tag_name$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                                );
                                        }

                                        # The SPELL names
                                        # To be processed later
                                        push @xcheck_to_process,
                                                [
                                                'SPELL',                qq(@@" in "$tag_name$tag_value),
                                                $file_for_error, $line_for_error,
                                                split ',',              $spells
                                                ];
                                }
                                else {
                                        $logging->notice(
                                                qq{Invalid domain/spell list paring in "$tag_name$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                        $working_value = "";
                                }
                                }
                        }
                        else {
                                $logging->notice(
                                qq{No value found for "$tag_name"},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                }
                }
                elsif ( $tag_name eq 'STAT' ) {
                if ( $linetype eq 'KIT STAT' ) {
                        # STAT:STR=17|DEX=10|CON=14|INT=8|WIS=12|CHA=14
                        my %stat_count_for = map { $_ => 0 } @valid_system_stats;

                        STAT:
                        for my $stat_expression (split /[|]/, $tag_value) {
                                my ($stat) = ( $stat_expression =~ / \A ([A-Z]{3}) [=] (\d+|roll\(\"\w+\"\)((\+|\-)var\(\"STAT.*\"\))*) \z /xms );
                                if ( !defined $stat ) {
                                # Syntax error
                                $logging->notice(
                                        qq{Invalid syntax for "$stat_expression" in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );

                                next STAT;
                                }

                                if ( !exists $stat_count_for{$stat} ) {
                                # The stat is not part of the official list
                                $logging->notice(
                                        qq{Invalid attribute name "$stat" in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                                else {
                                $stat_count_for{$stat}++;
                                }
                        }

                        # We check to see if some stat are repeated
                        for my $stat (@valid_system_stats) {
                                if ( $stat_count_for{$stat} > 1 ) {
                                $logging->notice(
                                        qq{Found $stat more then once in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                                }
                        }
                }
                }
                elsif ( $tag_name eq 'TEMPLATE' && $linetype ne 'PCC' ) {
                # TEMPLATE:<template name>|<template name>|etc.
                push @xcheck_to_process,
                        [  'TEMPLATE',
                                $tag_name,
                                $file_for_error,
                                $line_for_error,
                                (split /[|]/, $tag_value),
                        ];
                }
                ######################################################################
                # Here we capture data for later validation
                elsif ( $tag_name eq 'RACESUBTYPE' ) {
                for my $race_subtype (split /[|]/, $tag_value) {
                        my $new_race_subtype = $race_subtype;
                        if ( $linetype eq 'RACE' ) {
                                # The RACE sub-type are created in the RACE file
                                if ( $race_subtype =~ m{ \A [.] REMOVE [.] }xmsi ) {
                                # The presence of a remove means that we are trying
                                # to modify existing data and not create new one
                                push @xcheck_to_process,
                                        [  'RACESUBTYPE',
                                                $tag_name,
                                                $file_for_error,
                                                $line_for_error,
                                                $race_subtype,
                                        ];
                                }
                                else {
                                $valid_entities{'RACESUBTYPE'}{$race_subtype}++
                                }
                        }
                        else {
                                # The RACE type found here are not create, we only
                                # get rid of the .REMOVE. part
                                $race_subtype =~ m{ \A [.] REMOVE [.] }xmsi;

                                push @xcheck_to_process,
                                        [  'RACESUBTYPE',
                                        $tag_name,
                                        $file_for_error,
                                        $line_for_error,
                                        $race_subtype,
                                ];
                        }
                }
                }
                elsif ( $tag_name eq 'RACETYPE' ) {
                for my $race_type (split /[|]/, $tag_value) {
                        if ( $linetype eq 'RACE' ) {
                                # The RACE type are created in the RACE file
                                if ( $race_type =~ m{ \A [.] REMOVE [.] }xmsi ) {
                                # The presence of a remove means that we are trying
                                # to modify existing data and not create new one
                                push @xcheck_to_process,
                                        [  'RACETYPE',
                                                $tag_name,
                                                $file_for_error,
                                                $line_for_error,
                                                $race_type,
                                        ];
                                }
                                else {
                                $valid_entities{'RACETYPE'}{$race_type}++
                                }
                        }
                        else {
                                # The RACE type found here are not create, we only
                                # get rid of the .REMOVE. part
                                $race_type =~ m{ \A [.] REMOVE [.] }xmsi;

                                push @xcheck_to_process,
                                        [  'RACETYPE',
                                        $tag_name,
                                        $file_for_error,
                                        $line_for_error,
                                        $race_type,
                                ];
                        }
                }
                }
                elsif ( $tag_name eq 'TYPE' ) {
                        # The types go into valid_types
                        $valid_types{$linetype}{$_}++ for ( split '\.', $tag_value );
                }
                elsif ( $tag_name eq 'CATEGORY' ) {
                        # The types go into valid_types
                        $valid_categories{$linetype}{$_}++ for ( split '\.', $tag_value );
                }
                ######################################################################
                # Tag with numerical values
                elsif ( $tag_name eq 'STARTSKILLPTS'
                        || $tag_name eq 'SR'
                        ) {

                # These tags should only have a numeribal value
                push @xcheck_to_process,
                        [
                                'DEFINE Variable',
                                qq(@@" in "$tag_name:$tag_value),
                                $file_for_error,
                                $line_for_error,
                                parse_jep(
                                $tag_value,
                                "$tag_name:$tag_value",
                                $file_for_error,
                                $line_for_error
                                ),
                        ];
                }
                elsif ( $tag_name eq 'DEFINE' ) {
                        my ( $var_name, @formulas ) = split '\|', $tag_value;

                        # First we store the DEFINE variable name
                        if ($var_name) {
                                if ( $var_name =~ /^[a-z][a-z0-9_]*$/i ) {
                                        $valid_entities{'DEFINE Variable'}{$var_name}++;

                                        #####################################################
                                        # Export a list of variable names if requested
                                        if ( Pretty::Options::isConversionActive('Export lists') ) {
                                                my $file = $file_for_error;
                                                $file =~ tr{/}{\\};
                                                print { $filehandle_for{VARIABLE} }
                                                        qq{"$var_name","$line_for_error","$file"\n};
                                        }

                                }

                                # LOCK.xxx and BASE.xxx are not error (even if they are very ugly)
                                elsif ( $var_name !~ /(BASE|LOCK)\.(STR|DEX|CON|INT|WIS|CHA|DVR)/ ) {
                                        $logging->notice(
                                                qq{Invalid variable name "$var_name" in "$tag_name:$tag_value"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                        }
                        else {
                                $logging->notice(
                                        qq{I was not able to find a proper variable name in "$tag_name:$tag_value"},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }

                        # Second we deal with the formula
                        for my $formula (@formulas) {
                                push @xcheck_to_process,
                                        [
                                                'DEFINE Variable',
                                                qq(@@" in "$tag_name:$tag_value),
                                                $file_for_error,
                                                $line_for_error,
                                                parse_jep(
                                                        $formula,
                                                        "$tag_name:$tag_value",
                                                        $file_for_error,
                                                        $line_for_error
                                                )
                                        ];
                        }
                }
                elsif ( $tag_name eq 'SA' ) {
                        my ($var_string) = ( $tag_value =~ /[^|]\|(.*)/ );
                        if ($var_string) {
                                FORMULA:
                                for my $formula ( split '\|', $var_string ) {

                                        # Are there any PRE tags in the SA tag.
                                        if ( $formula =~ /(^!?PRE[A-Z]*):(.*)/ ) {

                                                # A PRExxx tag is present
                                                validate_pre_tag($1,
                                                        $2,
                                                        "$tag_name:$tag_value",
                                                        $linetype,
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                                next FORMULA;
                                        }

                                        push @xcheck_to_process,
                                                [
                                                        'DEFINE Variable',
                                                        qq(@@" in "$tag_name:$tag_value),
                                                        $file_for_error,
                                                        $line_for_error,
                                                        parse_jep(
                                                                $formula,
                                                                "$tag_name:$tag_value",
                                                                $file_for_error,
                                                                $line_for_error
                                                        )
                                                ];
                                }
                        }
                }
                elsif ( $linetype eq 'SPELL'
                        && ( $tag_name eq 'TARGETAREA' || $tag_name eq 'DURATION' || $tag_name eq 'DESC' ) )
                {

                        # Inline f*#king tags.
                        # We need to find CASTERLEVEL between ()
                        my $value = $tag_value;
                        pos $value = 0;

                        FIND_BRACKETS:
                        while ( pos $value < length $value ) {
                                my $result;
                                # Find the first set of ()
                                if ( (($result) = Text::Balanced::extract_bracketed( $value, '()' ))
                                        && $result
                                ) {
                                        # Is there a CASTERLEVEL inside?
                                        if ( $result =~ / CASTERLEVEL /xmsi ) {
                                        push @xcheck_to_process,
                                                [
                                                        'DEFINE Variable',
                                                        qq(@@" in "$tag_name:$tag_value),
                                                        $file_for_error,
                                                        $line_for_error,
                                                        parse_jep(
                                                        $result,
                                                        "$tag_name:$tag_value",
                                                        $file_for_error,
                                                        $line_for_error
                                                        )
                                                ];
                                        }
                                }
                                else {
                                        last FIND_BRACKETS;
                                }
                        }
                }
                elsif ( $tag_name eq 'NATURALATTACKS' ) {

                        # NATURALATTACKS:<Natural weapon name>,<List of type>,<attacks>,<damage>|...
                        #
                        # We must make sure that there are always four , separated parameters
                        # between the |.

                        for my $entry ( split '\|', $tag_value ) {
                                my @parameters = split ',', $entry;

                                my $NumberOfParams = scalar @parameters;

                                # must have 4 or 5 parameters
                                if ($NumberOfParams == 5 or $NumberOfParams == 4) { 
                                
                                        # If Parameter 5 exists, it must be an SPROP
                                        if (defined $parameters[4]) {
                                                $logging->notice(
                                                        qq{5th parameter should be an SPROP in "NATURALATTACKS:$entry"},
                                                        $file_for_error,
                                                        $line_for_error
                                                ) unless $parameters[4] =~ /^SPROP=/;
                                        }

                                        # Parameter 3 is a number
                                        $logging->notice(
                                                qq{3rd parameter should be a number in "NATURALATTACKS:$entry"},
                                                $file_for_error,
                                                $line_for_error
                                        ) unless $parameters[2] =~ /^\*?\d+$/;

                                        # Are the types valid EQUIPMENT types?
                                        push @xcheck_to_process,
                                                [
                                                        'EQUIPMENT TYPE', qq(@@" in "$tag_name:$entry),
                                                        $file_for_error,  $line_for_error,
                                                        grep { !$valid_NATURALATTACKS_type{$_} } split '\.', $parameters[1]
                                                ];
                                }
                                else {
                                        $logging->notice(
                                                qq{Wrong number of parameter for "NATURALATTACKS:$entry"},
                                                $file_for_error,
                                        $line_for_error
                                        );
                                }
                        }
                }
                elsif ( $tag_name eq 'CHANGEPROF' ) {

                # "CHANGEPROF:" <list of weapons> "=" <new prof> { "|"  <list of weapons> "=" <new prof> }*
                # <list of weapons> := ( <weapon> | "TYPE=" <weapon type> ) { "," ( <weapon> | "TYPE=" <weapon type> ) }*

                        for my $entry ( split '\|', $tag_value ) {
                                if ( $entry =~ /^([^=]+)=([^=]+)$/ ) {
                                        my ( $list_of_weapons, $new_prof ) = ( $1, $2 );

                                        # First, the weapons (equipment)
                                        push @xcheck_to_process,
                                                [
                                                        'EQUIPMENT', $tag_name, $file_for_error, $line_for_error,
                                                        split ',',   $list_of_weapons
                                                ];

                                        # Second, the weapon prof.
                                        push @xcheck_to_process,
                                                [
                                                        'WEAPONPROF', $tag_name, $file_for_error, $line_for_error,
                                                        $new_prof
                                                ];

                                }
                                else {
                                }
                        }
                }

##  elsif($tag_name eq 'CHOOSE')
##  {
##      # Is the CHOOSE type valid?
##      my ($choose_type) = ($tag_value =~ /^([^=|]+)/);
##
##      if($choose_type && !exists $token_CHOOSE_tag{$choose_type})
##      {
##      if(index($choose_type,' ') != -1)
##      {
##              # There is a space in the choose type, it must be a
##              # typeless CHOOSE (darn).
##              $logging->notice(  "** Typeless CHOOSE found: \"$tag_name:$tag_value\" in $linetype.",
##                      $file_for_error, $line_for_error );
##      }
##      else
##      {
##              $count_tags{"Invalid"}{"Total"}{"$tag_name:$choose_type"}++;
##              $count_tags{"Invalid"}{$linetype}{"$tag_name:$choose_type"}++;
##              $logging->notice(  "Invalid CHOOSE:$choose_type tag \"$tag_name:$tag_value\" found in $linetype.",
##                      $file_for_error, $line_for_error );
##      }
##      }
##      elsif(!$choose_type)
##      {
##      $count_tags{"Invalid"}{"Total"}{"CHOOSE"}++;
##      $count_tags{"Invalid"}{$linetype}{"CHOOSE"}++;
##      $logging->notice(  "Invalid CHOOSE tag \"$tag_name:$tag_value\" found in $linetype",
##              $file_for_error, $line_for_error );
##      }
##  }

        }

}       # BEGIN End

###############################################################
# scan_for_deprecated_tags
# ------------------------
#
# This function establishes a centralized location to search
# each line for deprecated tags.
#
# Parameters:   $line   = The line to be searched
#                       $linetype               = The type of line
#                       $file_for_error = File name to use with log
#                       $line_for_error = The currrent line's number within the file
#
sub scan_for_deprecated_tags {
        my ( $line, $linetype, $file_for_error, $line_for_error ) = @_ ;

        # Deprecated tags
        if ( $line =~ /\scl\(/ ) {
                $logging->info(
                        qq{The Jep function cl() is deprecated, use classlevel() instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1938933 ] BONUS:DAMAGE and BONUS:TOHIT should be Deprecated
        if ( $line =~ /\sBONUS:DAMAGE\s/ ) {
                $logging->info(
                        qq{BONUS:DAMAGE is deprecated 5.5.8 - Remove 5.16.0 - Use BONUS:COMBAT|DAMAGE.x|y instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1938933 ] BONUS:DAMAGE and BONUS:TOHIT should be Deprecated
        if ( $line =~ /\sBONUS:TOHIT\s/ ) {
                $logging->info(
                        qq{BONUS:TOHIT is deprecated 5.3.12 - Remove 5.16.0 - Use BONUS:COMBAT|TOHIT|x instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1973497 ] HASSPELLFORMULA is deprecated
        if ( $line =~ /\sHASSPELLFORMULA/ ) {
                $logging->warning(
                        qq{HASSPELLFORMULA is no longer needed and is deprecated in PCGen 5.15},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /[\d+|\)]MAX\d+/ ) {
                $logging->info(
                        qq{The function aMAXb is deprecated, use the Jep function max(a,b) instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /[\d+|\)]MIN\d+/ ) {
                $logging->info(
                        qq{The function aMINb is deprecated, use the Jep function min(a,b) instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\b]TRUNC\b/ ) {
                $logging->info(
                        qq{The function TRUNC is deprecated, use the Jep function floor(a) instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\sHITDICESIZE\s/ ) {
                $logging->info(
                        qq{HITDICESIZE is deprecated, use HITDIE instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\sSPELl\s/ && $linetype ne 'PCC' ) {
                $logging->info(
                        qq{SPELL is deprecated, use SPELLS instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\sWEAPONAUTO\s/ ) {
                $logging->info(
                        qq{WEAPONAUTO is deprecated, use AUTO:WEAPONPROF instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\sADD:WEAPONBONUS\s/ ) {
                $logging->info(
                        qq{ADD:WEAPONBONUS is deprecated, use BONUS instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\sADD:LIST\s/ ) {
                $logging->info(
                        qq{ADD:LIST is deprecated, use BONUS instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        if ( $line =~ /\sFOLLOWERALIGN/) {
                $logging->info(
                        qq{FOLLOWERALIGN is deprecated, use PREALIGN on Domain instead. Use the -c=pcgen5120 command line switch to fix this problem},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1905481 ] Deprecate CompanionMod SWITCHRACE
        if ( $line =~ /\sSWITCHRACE\s/) {
                $logging->info(
                        qq{SWITCHRACE is deprecated 5.13.11 - Remove 6.0 - Use RACETYPE:x tag instead },
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1804786 ] Deprecate SA: replace with SAB:
        if ( $line =~ /\sSA:/) {
                $logging->info(
                        qq{SA is deprecated 5.x.x - Remove 6.0 - use SAB instead },
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1804780 ] Deprecate CHOOSE:EQBUILDER|1
        if ( $line =~ /\sCHOOSE:EQBUILDER\|1/) {
                $logging->info(
                        qq{CHOOSE:EQBUILDER|1 is deprecated use CHOOSE:NOCHOICE instead },
                        $file_for_error,
                        $line_for_error
                );
        }


        # [ 1864704 ] AUTO:ARMORPROF|TYPE=x is deprecated
        if ( $line =~ /\sAUTO:ARMORPROF\|TYPE\=/) {
                $logging->info(
                        qq{AUTO:ARMORPROF|TYPE=x is deprecated Use AUTO:ARMORPROF|ARMORTYPE=x instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ 1870482 ] AUTO:SHIELDPROF changes
        if ( $line =~ /\sAUTO:SHIELDPROF\|TYPE\=/) {
                $logging->info(
                        qq{AUTO:SHIELDPROF|TYPE=x is deprecated Use AUTO:SHIELDPROF|SHIELDTYPE=x instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ NEWTAG-19 ] CHOOSE:ARMORPROF= is deprecated
        if ( $line =~ /\sCHOOSE:ARMORPROF\=/) {
                $logging->info(
                        qq{CHOOSE:ARMORPROF= is deprecated 5.15 - Remove 6.0. Use CHOOSE:ARMORPROFICIENCY instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ NEWTAG-17 ] CHOOSE:FEATADD= is deprecated
        if ( $line =~ /\sCHOOSE:FEATADD\=/) {
                $logging->info(
                        qq{CHOOSE:FEATADD= is deprecated 5.15 - Remove 6.0. Use CHOOSE:FEAT instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ NEWTAG-17 ] CHOOSE:FEATLIST= is deprecated
        if ( $line =~ /\sCHOOSE:FEATLIST\=/) {
                $logging->info(
                        qq{CHOOSE:FEATLIST= is deprecated 5.15 - Remove 6.0. Use CHOOSE:FEAT instead},
                        $file_for_error,
                        $line_for_error
                );
        }

        # [ NEWTAG-17 ] CHOOSE:FEATSELECT= is deprecated
        if ( $line =~ /\sCHOOSE:FEATSELECT\=/) {
                $logging->info(
                        qq{CHOOSE:FEATSELECT= is deprecated 5.15 - Remove 6.0. Use CHOOSE:FEAT instead},
                        $file_for_error,
                        $line_for_error
                );
        }


        # [ 1888288 ] CHOOSE:COUNT= is deprecated
        if ( $line =~ /\sCHOOSE:COUNT\=/) {
                $logging->info(
                        qq{CHOOSE:COUNT= is deprecated 5.13.9 - Remove 6.0. Use SELECT instead},
                        $file_for_error,
                        $line_for_error
                );
        }
}
### end of the function scan_for_deprecated_tags

###############################################################
# add_to_xcheck_tables
# --------------------
#
# This function adds entries that will need to cross-checked
# against existing entities.
#
# It also filter the global entries and other weirdness.
#
# Pamameter:  $entry_type               Type of the entry that must be cheacked
#                       $tag_name               Name of the tag for message display
#                                               If tag name contains @@, it will be replaced
#                                               by the entry text from the list for the message.
#                                               Otherwise, the format $tag_name:$list_entry will
#                                               be used.
#                       $file_for_error   Name of the current file
#                       $line_for_error   Number of the current line
#                       @list                   List of entries to be added

BEGIN {

        # Variables names that must be skiped for the DEFINE variable section
        # entry type.

        my %Hardcoded_Variables = map { $_ => 1 } (
                # Real hardcoded variables
                'ACCHECK',
#               'ARMORACCHECK',
                'BAB',
                'BASESPELLSTAT',
                '%CHOICE',
                'CASTERLEVEL',
                'CL',
#               'CLASSLEVEL',
                'ENCUMBERANCE',
#               'GRAPPLESIZEMOD',
                'HD',
                '%LIST',
                'MOVEBASE',
                'SIZE',
#               'SPELLSTAT',
                'TL',

                # Functions for the JEP parser
                'ceil',
                'floor',
                'if',
                'min',
                'max',
                'roll',
                'var',
                'mastervar',
                'APPLIEDAS',
        );

        sub add_to_xcheck_tables {
                my ($entry_type,                # Type of the entry that must be cheacked
                        $tag_name,              # Name of the tag for message display
                                                # If tag name contains @@, it will be replaced
                                                # by the entry text from the list for the message.
                                                # Otherwise, the format $tag_name:$list_entry will
                                                # be used.
                        $file_for_error,        # Name of the current file
                        $line_for_error,        # Number of the current line
                        @list                   # List of entries to be added
                ) = ( @_, "" );

                # If $file_for_error is not under $cl_options{input_path}, we do not add
                # it to be validated. This happens when a -basepath parameter is used
                # with the script.
                return if $file_for_error !~ / \A $cl_options{input_path} /xmsi;

                # We remove the empty elements in the list
                @list = grep { $_ ne "" } @list;

                # If the list of entry is empty, we retrun immediately
                return if scalar @list == 0;

                # We set $tag_name properly for the substitution
                $tag_name .= ":@@" unless $tag_name =~ /@@/;

                if ( $entry_type eq 'CLASS' ) {
                        for my $class (@list) {

                                # Remove the =level if there is one
                                $class =~ s/(.*)=\d+$/$1/;

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$class/;

                                # Spellcaster is a special PCGEN keyword, not a real class
                                push @{ $referer{'CLASS'}{$class} },
                                        [ $message_name, $file_for_error, $line_for_error ]
                                        if ( uc($class) ne "SPELLCASTER"
                                                && uc($class) ne "SPELLCASTER.ARCANE"
                                                && uc($class) ne "SPELLCASTER.DIVINE"
                                                && uc($class) ne "SPELLCASTER.PSIONIC" );
                        }
                }
                elsif ( $entry_type eq 'DEFINE Variable' ) {
                        VARIABLE:
                        for my $var (@list) {

                                # We skip, the COUNT[] thingy must not be validated
                                next VARIABLE if $var =~ /^COUNT\[/;

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$var/;

                                push @{ $referer{'DEFINE Variable'}{$var} },
                                        [ $message_name, $file_for_error, $line_for_error ]
                                        unless $Hardcoded_Variables{$var};
                        }
                }
                elsif ( $entry_type eq 'DEITY' ) {
                        for my $deity (@list) {
                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$deity/;

                                push @{ $referer{'DEITY'}{$deity} },
                                        [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                elsif ( $entry_type eq 'DOMAIN' ) {
                        for my $domain (@list) {

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$domain/;

                                push @{ $referer{'DOMAIN'}{$domain} },
                                        [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                elsif ( $entry_type eq 'EQUIPMENT' ) {
                        for my $equipment (@list) {

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$equipment/;

                                if ( $equipment =~ /^TYPE=(.*)/ ) {
                                        push @{ $referer_types{'EQUIPMENT'}{$1} },
                                        [ $message_name, $file_for_error, $line_for_error ];
                                }
                                else {
                                        push @{ $referer{'EQUIPMENT'}{$equipment} },
                                        [ $message_name, $file_for_error, $line_for_error ];
                                }
                        }
                }
                elsif ( $entry_type eq 'EQUIPMENT TYPE' ) {
                        for my $type (@list) {

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$type/;

                                push @{ $referer_types{'EQUIPMENT'}{$type} },
                                        [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                elsif ( $entry_type eq 'EQUIPMOD Key' ) {
                        for my $key (@list) {

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$key/;

                                push @{ $referer{'EQUIPMOD Key'}{$key} },
                                        [ $message_name, $file_for_error, $line_for_error ];
                                }
                        }
                        elsif ( $entry_type eq 'FEAT' ) {
                                # Note - ABILITY code is below. If you need to make changes here
                                # to the FEAT code, please also review the ABILITY code to ensure
                                # that your changes aren't needed there.
                                FEAT:
                                for my $feat (@list) {

                                        # We ignore CHECKMULT if used within a PREFEAT tag
                                        next FEAT if $feat eq 'CHECKMULT' && $tag_name =~ /PREFEAT/;

                                        # We ignore LIST if used within an ADD:FEAT tag
                                        next FEAT if $feat eq 'LIST' && $tag_name eq 'ADD:FEAT';

                                        # We stript the () if any
                                        if ( $feat =~ /(.*?[^ ]) ?\((.*)\)/ ) {

                                                # We check to see if the FEAT is a compond tag
                                                if ( $valid_sub_entities{'FEAT'}{$1} ) {
                                                        my $original_feat = $feat;
                                                        my $feat_to_check = $feat = $1;
                                                        my $entity              = $2;
                                                        my $sub_tag_name  = $tag_name;
                                                        $sub_tag_name =~ s/@@/$feat (@@)/;

                                                        # Find the real entity type in case of FEAT=
                                                        FEAT_ENTITY:
                                                        while ( $valid_sub_entities{'FEAT'}{$feat_to_check} =~ /^FEAT=(.*)/ ) {
                                                                $feat_to_check = $1;
                                                                if ( !exists $valid_sub_entities{'FEAT'}{$feat_to_check} ) {
                                                                        $logging->notice(
                                                                                qq{Cannot find the sub-entity for "$original_feat"},
                                                                                $file_for_error,
                                                                                $line_for_error
                                                                        );
                                                                        $feat_to_check = "";
                                                                        last FEAT_ENTITY;
                                                                }
                                                        }

                                                        add_to_xcheck_tables(
                                                                $valid_sub_entities{'FEAT'}{$feat_to_check},
                                                                $sub_tag_name,
                                                                $file_for_error,
                                                                $line_for_error,
                                                                $entity
                                                        ) if $feat_to_check && $entity ne 'Ad-Lib';
                                                }
                                        }

                                        # Put the entry name in place
                                        my $message_name = $tag_name;
                                        $message_name =~ s/@@/$feat/;

                                        if ( $feat =~ /^TYPE[=.](.*)/ ) {
                                                push @{ $referer_types{'FEAT'}{$1} },
                                                        [ $message_name, $file_for_error, $line_for_error ];
                                        }
                                        else {
                                                push @{ $referer{'FEAT'}{$feat} },
                                                        [ $message_name, $file_for_error, $line_for_error ];
                                        }
                                }
                        }
                                elsif ( $entry_type eq 'ABILITY' ) {
                                        #[ 1671407 ] xcheck PREABILITY tag
                                        # Note - shamelessly cut/pasting from the FEAT code, as it's
                                        # fairly similar.
                                        ABILITY:
                                        for my $feat (@list) {

                                                # We ignore CHECKMULT if used within a PREFEAT tag
                                                next ABILITY if $feat eq 'CHECKMULT' && $tag_name =~ /PREABILITY/;

                                                # We ignore LIST if used within an ADD:FEAT tag
                                                next ABILITY if $feat eq 'LIST' && $tag_name eq 'ADD:ABILITY';

                                                # We stript the () if any
                                                if ( $feat =~ /(.*?[^ ]) ?\((.*)\)/ ) {

                                                        # We check to see if the FEAT is a compond tag
                                                        if ( $valid_sub_entities{'ABILITY'}{$1} ) {
                                                                my $original_feat = $feat;
                                                                my $feat_to_check = $feat = $1;
                                                                my $entity              = $2;
                                                                my $sub_tag_name  = $tag_name;
                                                                $sub_tag_name =~ s/@@/$feat (@@)/;

                                                                # Find the real entity type in case of FEAT=
                                                                ABILITY_ENTITY:
                                                                while ( $valid_sub_entities{'ABILITY'}{$feat_to_check} =~ /^ABILITY=(.*)/ ) {
                                                                        $feat_to_check = $1;
                                                                        if ( !exists $valid_sub_entities{'ABILITY'}{$feat_to_check} ) {
                                                                                $logging->notice(
                                                                                        qq{Cannot find the sub-entity for "$original_feat"},
                                                                                        $file_for_error,
                                                                                        $line_for_error
                                                                                );
                                                                        $feat_to_check = "";
                                                                        last ABILITY_ENTITY;
                                                                }
                                                        }

                                                        add_to_xcheck_tables(
                                                                $valid_sub_entities{'ABILITY'}{$feat_to_check},
                                                                $sub_tag_name,
                                                                $file_for_error,
                                                                $line_for_error,
                                                                $entity
                                                        ) if $feat_to_check && $entity ne 'Ad-Lib';
                                                }
                                        }

                                # Put the entry name in place
                                my $message_name = $tag_name;
                                $message_name =~ s/@@/$feat/;

                                if ( $feat =~ /^TYPE[=.](.*)/ ) {
                                        push @{ $referer_types{'ABILITY'}{$1} },
                                                [ $message_name, $file_for_error, $line_for_error ];
                                }
                                elsif ( $feat =~ /^CATEGORY[=.](.*)/ ) {
                                        push @{ $referer_categories{'ABILITY'}{$1} },
                                                [ $message_name, $file_for_error, $line_for_error ];
                                }
                                else {
                                        push @{ $referer{'ABILITY'}{$feat} },
                                                [ $message_name, $file_for_error, $line_for_error ];
                                }
                        }
                }
                elsif ( $entry_type eq 'KIT STARTPACK' ) {
                for my $kit (@list) {

                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$kit/;

                        push @{ $referer{'KIT STARTPACK'}{$kit} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                elsif ( $entry_type eq 'LANGUAGE' ) {
                for my $language (@list) {

                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$language/;

                        if ( $language =~ /^TYPE=(.*)/ ) {
                                push @{ $referer_types{'LANGUAGE'}{$1} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                        else {
                                push @{ $referer{'LANGUAGE'}{$language} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                }
                elsif ( $entry_type eq 'MOVE Type' ) {
                MOVE_TYPE:
                for my $move (@list) {

                        # The ALL move type is always valid
                        next MOVE_TYPE if $move eq 'ALL';

                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$move/;

                        push @{ $referer{'MOVE Type'}{$move} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                elsif ( $entry_type eq 'RACE' ) {
                for my $race (@list) {
                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$race/;

                        if ( $race =~ / \A TYPE= (.*) /xms ) {
                                push @{ $referer_types{'RACE'}{$1} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                        elsif ( $race =~ / \A RACETYPE= (.*) /xms ) {
                                push @{ $referer{'RACETYPE'}{$1} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                        elsif ( $race =~ / \A RACESUBTYPE= (.*) /xms ) {
                                push @{ $referer{'RACESUBTYPE'}{$1} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                        else {
                                push @{ $referer{'RACE'}{$race} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                }
                elsif ( $entry_type eq 'RACE TYPE' ) {
                for my $race_type (@list) {
                        # RACE TYPE is use for TYPE tags in RACE object
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$race_type/;

                        push @{ $referer_types{'RACE'}{$race_type} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                elsif ( $entry_type eq 'RACESUBTYPE' ) {
                for my $race_subtype (@list) {
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$race_subtype/;

                        # The RACESUBTYPE can be .REMOVE.<race subtype name>
                        $race_subtype =~ s{ \A [.] REMOVE [.] }{}xms;

                        push @{ $referer{'RACESUBTYPE'}{$race_subtype} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                elsif ( $entry_type eq 'RACETYPE' ) {
                for my $race_type (@list) {
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$race_type/;

                        # The RACETYPE can be .REMOVE.<race type name>
                        $race_type =~ s{ \A [.] REMOVE [.] }{}xms;

                        push @{ $referer{'RACETYPE'}{$race_type} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                elsif ( $entry_type eq 'SKILL' ) {
                SKILL:
                for my $skill (@list) {

                        # LIST alone is OK, it is a special variable
                        # used to tie in the CHOOSE result
                        next SKILL if $skill eq 'LIST';

                        # Remove the =level if there is one
                        $skill =~ s/(.*)=\d+$/$1/;

                        # If there are (), we must verify if it is
                        # a compond skill
                        if ( $skill =~ /(.*?[^ ]) ?\((.*)\)/ ) {

                                # We check to see if the SKILL is a compond tag
                                if ( $valid_sub_entities{'SKILL'}{$1} ) {
                                $skill = $1;
                                my $entity = $2;

                                my $sub_tag_name = $tag_name;
                                $sub_tag_name =~ s/@@/$skill (@@)/;

                                add_to_xcheck_tables(
                                        $valid_sub_entities{'SKILL'}{$skill},
                                        $sub_tag_name,
                                        $file_for_error,
                                        $line_for_error,
                                        $entity
                                ) if $entity ne 'Ad-Lib';
                                }
                        }

                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$skill/;

                        if ( $skill =~ / \A TYPE [.=] (.*) /xms ) {
                                push @{ $referer_types{'SKILL'}{$1} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                        else {
                                push @{ $referer{'SKILL'}{$skill} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                }
                elsif ( $entry_type eq 'SPELL' ) {
                for my $spell (@list) {

                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$spell/;

                        if ( $spell =~ /^TYPE=(.*)/ ) {
                                push @{ $referer_types{'SPELL'}{$1} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                        else {
                                push @{ $referer{'SPELL'}{$spell} },
                                [ $message_name, $file_for_error, $line_for_error ];
                        }
                }
                }
                elsif ( $entry_type eq 'TEMPLATE' ) {
                for my $template (@list) {
                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$template/;

                        # We clean up the unwanted stuff
                        my $template_copy = $template;
                        $template_copy =~ s/ CHOOSE: //xms;
                        $message_name =~ s/ CHOOSE: //xms;

                        push @{ $referer{'TEMPLATE'}{$template_copy} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                elsif ( $entry_type eq 'WEAPONPROF' ) {
#               for my $weaponprof (@list) {
#
#                       # Put the entry name in place
#                       my $message_name = $tag_name;
#                       $message_name =~ s/@@/$weaponprof/;
#
#                       if ( $spell =~ /^TYPE=(.*)/ ) {
#                               push @{ $referer_types{'WEAPONPROF'}{$1} },
#                               [ $message_name, $file_for_error, $line_for_error ];
#                       }
#                       else {
#                               push @{ $referer{'WEAPONPROF'}{$weaponprof} },
#                               [ $message_name, $file_for_error, $line_for_error ];
#                       }
#               }
                }
                elsif ( $entry_type eq 'SPELL_SCHOOL' || $entry_type eq 'Ad-Lib' ) {
                # Nothing is done yet.
                }
                elsif ( $entry_type =~ /,/ ) {

                # There is a , in the name so it is a special
                # validation case that is defered until the validation time.
                # In short, the entry must exists in one of the type list.
                for my $entry (@list) {

                        # Put the entry name in place
                        my $message_name = $tag_name;
                        $message_name =~ s/@@/$entry/;

                        push @{ $referer{$entry_type}{$entry} },
                                [ $message_name, $file_for_error, $line_for_error ];
                }
                }
                else {
                $logging->error(
                        "Invalid Entry type for $tag_name (add_to_xcheck_tables): $entry_type",
                        $file_for_error,
                        $line_for_error
                );
                }
        }

}       # BEGIN end

###############################################################
# parse_jep
# ----------------
#
# Extract the variable names from a PCGEN formula
#
# Parameter:  $formula          : String containing the formula
#                       $tag            : Tag containing the formula
#                       $file_for_error : Filename to use with log
#                       $line_for_error : Line number to use with log

#open FORMULA, ">formula.txt" or die "Can't open formula: $OS_ERROR";

sub extract_var_name {
        my ( $formula, $tag, $file_for_error, $line_for_error ) = @_;

        return () unless $formula;

#       my @variables = parse_jep(@_);

        #  print FORMULA "$formula\n" unless $formula =~ /^[0-9]+$/;

        # Will hold the result values
        my @variable_names = ();

        # We remove the COUNT[xxx] from the formulas
        while ( $formula =~ s/(COUNT\[[^]]*\])//g ) {
                push @variable_names, $1;
        }

        # We have to catch all the VAR=Funky Text before anything else
        while ( $formula =~ s/([a-z][a-z0-9_]*=[a-z0-9_ =\{\}]*)//i ) {
                my @values = split '=', $1;
                if ( @values > 2 ) {

                        # There should only be one = per variable
                        $logging->warning(
                                qq{Too many = in "$1" found in "$tag"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                # [ 1104117 ] BL is a valid variable, like CL
                elsif ( $values[0] eq 'BL' || $values[0] eq 'CL' ||
                                $values[0] eq 'CLASS' || $values[0] eq 'CLASSLEVEL' ) {
                        # Convert {} to () for proper validation
                        $values[1] =~ tr/{}/()/;
                        push @xcheck_to_process,
                                [
                                        'CLASS',                qq(@@" in "$tag),
                                        $file_for_error, $line_for_error,
                                        $values[1]
                                ];
                }
                elsif ($values[0] eq 'SKILLRANK' || $values[0] eq 'SKILLTOTAL' ) {
                        # Convert {} to () for proper validation
                        $values[1] =~ tr/{}/()/;
                        push @xcheck_to_process,
                                [
                                        'SKILL',                qq(@@" in "$tag),
                                        $file_for_error, $line_for_error,
                                        $values[1]
                                ];
                }
                else {
                        $logging->notice(
                                qq{Invalid variable "$values[0]" before the = in "$1" found in "$tag"},
                                $file_for_error,
                                $line_for_error
                        );
                }
        }

        # Variables begin with a letter or the % and are followed
        # by letters, numbers, or the _
        VAR_NAME:
        for my $var_name ( $formula =~ /([a-z%][a-z0-9_]*)/gi ) {
                # If it's an operator, we skip it.
                next VAR_NAME
                if ( index( $var_name, 'MAX'   ) != -1
                        || index( $var_name, 'MIN'   ) != -1
                        || index( $var_name, 'TRUNC' ) != -1
                );

                push @variable_names, $var_name;
        }

        return @variable_names;
}

###############################################################
###############################################################
####
#### Start of parse_jep and related function closure
####

BEGIN {
        # List of keywords Jep functions names. The fourth and fifth rows are for
        # functions defined by the PCGen libraries that do not exists in
        # the standard Jep library.
        my %is_jep_function = map { $_ => 1 } qw(
                sin     cos     tan     asin    acos    atan    atan2   sinh
                cosh    tanh    asinh   acosh   atanh   ln      log     exp
                abs     rand    mod     sqrt    sum     if      str

                ceil    cl      classlevel      count   floor   min
                max     roll    skillinfo       var     mastervar       APPLIEDAS
        );

        # Definition of a valid Jep identifiers. Note that all functions are
        # identifiers followed by a parentesis.
        my $is_ident = qr{ [a-z_][a-z_0-9]* }xmsi;

        # Valid Jep operators
        my $is_operators_text = join( '|', map { quotemeta } (
                                '^', '%',  '/',  '*',  '+',  '-', '<=', '>=',
                                '<', '>', '!=', '==', '&&', '||', '=',  '!', '.',
                                                        )
                                        );

        my $is_operator = qr{ $is_operators_text }xms;

        my $is_number = qr{ (?: \d+ (?: [.] \d* )? ) | (?: [.] \d+ ) }xms;

###############################################################
# parse_jep
# ---------
#
# Parse a Jep formula expression and return a list of variables
# found.
#
# parse_jep is just a stub to call parse_jep_rec the first time
#
# Parameter:  $formula          : String containing the formula
#                       $tag            : Tag containing the formula
#                       $file_for_error : Filename to use with log
#                       $line_for_error : Line number to use with log
#
# Return a list of variables names found in the formula

        sub parse_jep {
                # We abosulutely need to be called in array context.
                croak q{parse_jep must be called in list context}
                if !wantarray;

                # Sanity check on the number of parameters
                croak q{Wrong number of parameters for parse_jep} if scalar @_ != 4;
                # If the -nojep command line option was used, we
                # call the old parser
                if ( getOption('nojep') ) {
                        return extract_var_name(@_);
                }
                else {
                        return parse_jep_rec( @_, NO );
                }
        }

###############################################################
# parse_jep_rec
# -------------
#
# Parse a Jep formula expression and return a list of variables
# found.
#
# Parameter:  $formula          : String containing the formula
#                       $tag            : Tag containing the formula
#                       $file_for_error : Filename to use with log
#                       $line_for_error : Line number to use with log
#                       $is_param               : Indicate if the Jep expression
#                                               is a function parameter
#
# Return a list of variables names found in the formula

        sub parse_jep_rec {
                my ($formula, $tag, $file_for_error, $line_for_error, $is_param) = @_;

                return () if !defined $formula;

                my @variables_found = ();       # Will contain the return values
                my $last_token  = q{};  # Only use for error messages
                my $last_token_type = q{};

                pos $formula = 0;

                while ( pos $formula < length $formula ) {
                        # Identifiers are only valid after an operator or a separator
                        if ( my ($ident) = ( $formula =~ / \G ( $is_ident ) /xmsgc ) ) {
                                # It's an identifier or a function
                                if ( $last_token_type && $last_token_type ne 'operator' && $last_token_type ne 'separator' ) {
                                        # We "eat" the rest of the string and report an error
                                        my ($bogus_text) = ( $formula =~ / \G (.*) /xmsgc );
                                        $logging->notice(
                                                qq{Jep syntax error near "$ident$bogus_text" found in "$tag"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                # Indentificator followed by bracket = function
                                elsif ( $formula =~ / \G [(] /xmsgc ) {
                                        # It's a function, is it valid?
                                        if ( !$is_jep_function{$ident} ) {
                                                $logging->notice(
                                                        qq{Not a valid Jep function: $ident() found in $tag},
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                        }

                                        # Reset the regex position just before the parantesis
                                        pos $formula = pos($formula) - 1;

                                        # We extract the function parameters
                                        my ($extracted_text) = Text::Balanced::extract_bracketed( $formula, '(")' );

                                        carp $formula if !$extracted_text;

                                        $last_token = "$ident$extracted_text";
                                        $last_token_type = 'function';

                                        # We remove the enclosing brackets
                                        ($extracted_text) = ( $extracted_text =~ / \A [(] ( .* ) [)] \z /xms );

                                        # For the var() function, we call the old parser
                                        if ( $ident eq 'var' ) {
                                                my ($var_text,$reminder) = Text::Balanced::extract_delimited( $extracted_text );

                                                # Verify that the values are between ""
                                                if ( $var_text ne q{} && $reminder eq q{} ) {
                                                        # Revove the ""
                                                        ($var_text) = ( $var_text =~ / \A [\"] ( .* ) [\"] \z /xms );

                                                        push @variables_found,
                                                                extract_var_name(
                                                                        $var_text,
                                                                        $tag,
                                                                        $file_for_error,
                                                                        $line_for_error
                                                                );
                                                }
                                                else {
                                                        $logging->notice(
                                                                qq{Quote missing for the var() parameter in "$tag"},
                                                                $file_for_error,
                                                                $line_for_error
                                                        );

                                                        # We use the original extracted text with the old var parser
                                                        push @variables_found,
                                                                extract_var_name(
                                                                        $extracted_text,
                                                                        $tag,
                                                                        $file_for_error,
                                                                        $line_for_error
                                                                );
                                                }
                                        }
                                        else {
                                                # Otherwise, each of the function parameters should be a valid Jep expression
                                                push @variables_found,
                                                parse_jep_rec( $extracted_text, $tag, $file_for_error, $line_for_error, YES );
                                        }
                                }
                                else {
                                        # It's an identifier
                                        push @variables_found, $ident;
                                        $last_token = $ident;
                                        $last_token_type = 'ident';
                                }
                        }
                        elsif ( my ($operator) = ( $formula =~ / \G ( $is_operator ) /xmsgc ) ) {
                                # It's an operator

                                if ( $operator eq '=' ) {
                                        if ( $last_token_type eq 'ident' ) {
                                                $logging->notice(
                                                        qq{Forgot to use var()? Dubious use of Jep variable assignation near }
                                                                . qq{"$last_token$operator" in "$tag"},
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                        }
                                        else {
                                                $logging->notice(
                                                        qq{Did you want the logical "=="? Dubious use of Jep variable assignation near }
                                                                . qq{"$last_token$operator" in "$tag"},
                                                        $file_for_error,
                                                        $line_for_error
                                                );
                                        }
                                }

                                $last_token = $operator;
                                $last_token_type = 'operator';
                        }
                        elsif ( $formula =~ / \G [(] /xmsgc ) {
                                # Reset the regex position just before the bracket
                                pos $formula = pos($formula) - 1;

                                # Extract what is between the () and call recursivly
                                my ($extracted_text)
                                        = Text::Balanced::extract_bracketed( $formula, '(")' );

                                if ($extracted_text) {
                                        $last_token = $extracted_text;
                                        $last_token_type = 'expression';

                                        # Remove the outside brackets
                                        ($extracted_text) = ( $extracted_text =~ / \A [(] ( .* ) [)] \z /xms );

                                        # Recursive call
                                        push @variables_found,
                                                parse_jep_rec( $extracted_text, $tag, $file_for_error, $line_for_error, NO );
                                }
                                else {
                                        # We "eat" the rest of the string and report an error
                                        my ($bogus_text) = ( $formula =~ / \G (.*) /xmsgc );
                                        $logging->notice(
                                                qq{Unbalance () in "$bogus_text" found in "$tag"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                        }
                        elsif ( my ($number) = ( $formula =~ / \G ( $is_number ) /xmsgc ) ) {
                                # It's a number
                                $last_token = $number;
                                $last_token_type = 'number';
                        }
                        elsif ( $formula =~ / \G [\"'] /xmsgc ) {
                                # It's a string
                                # Reset the regex position just before the quote
                                pos $formula = pos($formula) - 1;

                                # Extract what is between the () and call recursivly
                                my ($extracted_text)
                                        = Text::Balanced::extract_delimited( $formula );

                                if ($extracted_text) {
                                        $last_token = $extracted_text;
                                        $last_token_type = 'string';
                                }
                                else {
                                        # We "eat" the rest of the string and report an error
                                        my ($bogus_text) = ( $formula =~ / \G (.*) /xmsgc );
                                        $logging->notice(
                                                qq{Unbalance quote in "$bogus_text" found in "$tag"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                        }
                        elsif ( my ($separator) = ( $formula =~ / \G ( [,] ) /xmsgc ) ) {
                                # It's a comma
                                if ( $is_param == NO ) {
                                        # Commas are allowed only as parameter separator
                                        my ($bogus_text) = ( $formula =~ / \G (.*) /xmsgc );
                                        $logging->notice(
                                                qq{Jep syntax error found near "$separator$bogus_text" in "$tag"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                                $last_token = $separator;
                                $last_token_type = 'separator';
                        }
                        elsif ( $formula =~ / \G \s+ /xmsgc ) {
                                # Spaces are allowed in Jep expressions, we simply ignore them
                        }
                        else {
                                if ( $formula =~ /\G\[.+\]/gc ) {
                                        # Allow COUNT[something]
                                }
                                else {
                                        # If we are here, all is not well
                                        my ($bogus_text) = ( $formula =~ / \G (.*) /xmsgc );
                                        $logging->notice(
                                                qq{Jep syntax error found near unknown function "$bogus_text" in "$tag"},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }
                        }
                }

                return @variables_found;
        }

}

####
#### End of parse_jep and related function closure
####
###############################################################
###############################################################

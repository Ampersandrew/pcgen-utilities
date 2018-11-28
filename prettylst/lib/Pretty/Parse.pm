#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0);

use Pretty::Options qw{getOption};

# Constants for the master_line_type
use constant {
   # Line importance (Mode)
   MAIN           => 1, # Main line type for the file
   SUB            => 2, # Sub line type, must be linked to a MAIN
   SINGLE         => 3, # Idependant line type
   COMMENT        => 4, # Comment or empty line.

   # Line formatting option
   LINE           => 1, # Every line formatted by itself
   BLOCK          => 2, # Lines formatted as a block
   FIRST_COLUMN   => 3, # Only the first column of the block gets aligned

   # Line header option
   NO_HEADER      => 1, # No header
   LINE_HEADER    => 2, # One header before each line
   BLOCK_HEADER   => 3, # One header for the block

   # Standard YES NO constants
   NO             => 0,
   YES            => 1,
};

# The SOURCE line is use in nearly all file type
my %SOURCE_file_type_def = (
   Linetype  => 'SOURCE',
   RegEx     => qr(^SOURCE\w*:([^\t]*)),
   Mode      => SINGLE,
   Format    => LINE,
   Header    => NO_HEADER,
   SepRegEx  => qr{ (?: [|] ) | (?: \t+ ) }xms,  # Catch both | and tab
);

# Some ppl may still want to use the old ways (for PCGen v5.9.5 and older)
if( getOption('oldsourcetag') ) {
   $SOURCE_file_type_def{Sep} = q{|};  # use | instead of [tab] to split
}

# Information needed to parse the line type
our %master_file_type = (

   ABILITY => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'ABILITY',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   ABILITYCATEGORY => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'ABILITYCATEGORY',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   BIOSET => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'BIOSET AGESET',
         RegEx          => qr(^AGESET:([^\t]*)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => NO_HEADER,
         ValidateKeep   => YES,
         RegExIsMod     => qr(AGESET:(.*)\.([^\t]+)),
         RegExGetEntry  => qr(AGESET:(.*)),
      },
      {  Linetype       => 'BIOSET RACENAME',
         RegEx          => qr(^RACENAME:([^\t]*)),
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
   ],

   CLASS => [
      {  Linetype       => 'CLASS Level',
         RegEx          => qr(^(\d+)($|\t|:REPEATLEVEL:\d+)),
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'CLASS',
         RegEx          => qr(^CLASS:([^\t]*)),
         Mode           => MAIN,
         Format         => LINE,
         Header         => LINE_HEADER,
         ValidateKeep   => YES,
         RegExIsMod     => qr(CLASS:(.*)\.(MOD|FORGET|COPY=[^\t]+)),
         RegExGetEntry  => qr(CLASS:(.*)),
      },
      \%SOURCE_file_type_def,
      {  Linetype          => 'SUBCLASS',
         RegEx             => qr(^SUBCLASS:([^\t]*)),
         Mode              => SUB,
         Format            => BLOCK,
         Header            => NO_HEADER,
         ValidateKeep      => YES,
         RegExIsMod        => qr(SUBCLASS:(.*)\.(MOD|FORGET|COPY=[^\t]+)),
         RegExGetEntry     => qr(SUBCLASS:(.*)),
         # SUBCLASS can be refered to anywhere CLASS works.
         OtherValidEntries => ['CLASS'],
      },
      {  Linetype          => 'SUBSTITUTIONCLASS',
         RegEx             => qr(^SUBSTITUTIONCLASS:([^\t]*)),
         Mode              => SUB,
         Format            => BLOCK,
         Header            => NO_HEADER,
         ValidateKeep      => YES,
         RegExIsMod        => qr(SUBSTITUTIONCLASS:(.*)\.(MOD|FORGET|COPY=[^\t]+)),
         RegExGetEntry     => qr(SUBSTITUTIONCLASS:(.*)),
         # SUBSTITUTIONCLASS can be refered to anywhere CLASS works.
         OtherValidEntries => ['CLASS'],
      },
      {  Linetype          => 'SUBCLASSLEVEL',
         RegEx             => qr(^SUBCLASSLEVEL:([^\t]*)),
         Mode              => SUB,
         Format            => BLOCK,
         Header            => NO_HEADER,
      },
      {  Linetype          => 'SUBSTITUTIONLEVEL',
         RegEx             => qr(^SUBSTITUTIONLEVEL:([^\t]*)),
         Mode              => SUB,
         Format            => BLOCK,
         Header            => NO_HEADER,
      },
   ],

   COMPANIONMOD => [
      \%SOURCE_file_type_def,
      { Linetype        => 'SWITCHRACE',
         RegEx          => qr(^SWITCHRACE:([^\t]*)),
         Mode           => SINGLE,
         Format         => LINE,
         Header         => NO_HEADER,
      },
      { Linetype        => 'COMPANIONMOD',
         RegEx          => qr(^FOLLOWER:([^\t]*)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
         RegExIsMod     => qr(FOLLOWER:(.*)\.(MOD|FORGET|COPY=[^\t]+)),
         RegExGetEntry  => qr(FOLLOWER:(.*)),

         # Identifier that refer to other entry type
         IdentRefType   => 'CLASS,DEFINE Variable',
         IdentRefTag    => 'FOLLOWER',  # Tag name for the reference check
         # Get the list of reference identifiers
         # The syntax is FOLLOWER:class1,class2=level
         # We need to extract the class names.
         GetRefList     => sub { split q{,}, ( $_[0] =~ / \A ( [^=]* ) /xms )[0]  },
      },
      { Linetype        => 'MASTERBONUSRACE',
         RegEx          => qr(^MASTERBONUSRACE:([^\t]*)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
         RegExIsMod     => qr(MASTERBONUSRACE:(.*)\.(MOD|FORGET|COPY=[^\t]+)),
         RegExGetEntry  => qr(MASTERBONUSRACE:(.*)),
         IdentRefType   => 'RACE',                 # Identifier that refer to other entry type
         IdentRefTag    => 'MASTERBONUSRACE',      # Tag name for the reference check
         # Get the list of reference identifiers
         # The syntax is MASTERBONUSRACE:race
         # We need to extract the race name.
         GetRefList     => sub { return @_ },
      },
   ],

   DEITY => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'DEITY',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   DOMAIN => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'DOMAIN',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   EQUIPMENT => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'EQUIPMENT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   EQUIPMOD => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'EQUIPMOD',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   FEAT => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'FEAT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   KIT => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'KIT REGION',                 # Kits are grouped by Region.
         RegEx          => qr{^REGION:([^\t]*)},         # So REGION has a line of its own.
         Mode           => SINGLE,
         Format         => LINE,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT STARTPACK',              # The KIT name is defined here
         RegEx          => qr{^STARTPACK:([^\t]*)},
         Mode           => MAIN,
         Format         => LINE,
         Header         => NO_HEADER,
         ValidateKeep   => YES,
      },
      {  Linetype       => 'KIT ABILITY',
         RegEx          => qr{^ABILITY:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT ALIGN',
         RegEx          => qr{^ALIGN:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT CLASS',
         RegEx          => qr{^CLASS:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT DEITY',
         RegEx          => qr{^DEITY:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT FEAT',
         RegEx          => qr{^FEAT:([^\t]*)},
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT FUNDS',
         RegEx          => qr{^FUNDS:([^\t]*)},
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT GEAR',
         RegEx          => qr{^GEAR:([^\t]*)},
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT GENDER',
         RegEx          => qr{^GENDER:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT KIT',
         RegEx          => qr{^KIT:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT LANGAUTO',
         RegEx          => qr{^LANGAUTO:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT LANGBONUS',
         RegEx          => qr{^LANGBONUS:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT LEVELABILITY',
         RegEx          => qr{^LEVELABILITY:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT NAME',
         RegEx          => qr{^NAME:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT PROF',
         RegEx          => qr{^PROF:([^\t]*)},
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT RACE',
         RegEx          => qr{^RACE:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT SELECT',
         RegEx          => qr{^SELECT:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT SKILL',
         RegEx          => qr{^SKILL:([^\t]*)},
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT STAT',
         RegEx          => qr{^STAT:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT SPELLS',
         RegEx          => qr{^SPELLS:([^\t]*)},
         Mode           => SUB,
         Format         => BLOCK,
         Header         => NO_HEADER,
      },
      {  Linetype       => 'KIT TABLE',
         RegEx          => qr{^TABLE:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
         ValidateKeep   => YES,
      },
      {  Linetype       => 'KIT TEMPLATE',
         RegEx          => qr{^TEMPLATE:([^\t]*)},
         Mode           => SUB,
         Format         => FIRST_COLUMN,
         Header         => NO_HEADER,
      },
   ],

   LANGUAGE => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'LANGUAGE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   RACE => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'RACE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SKILL => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'SKILL',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SPELL => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'SPELL',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   TEMPLATE => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'TEMPLATE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   WEAPONPROF => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'WEAPONPROF',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   ARMORPROF => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'ARMORPROF',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SHIELDPROF => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'SHIELDPROF',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   VARIABLE => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'VARIABLE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   DATACONTROL => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'DATACONTROL',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],
   GLOBALMOD => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'GLOBALMOD',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SAVE => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'SAVE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],
   STAT => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'STAT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],
   ALIGNMENT => [
      \%SOURCE_file_type_def,
      {  Linetype       => 'ALIGNMENT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

);




# FILETYPE_parse
# --------------
#
# This function uses the information of master_file_type to
# identify the curent line type and parse it.
#
# Parameters: $file_type      = The type of the file has defined by the .PCC file
#             $lines_ref      = Reference to an array containing all the lines of the file
#             $file_for_error = File name to use with log

sub FILETYPE_parse {
   my ($file_type, $lines_ref, $file_for_error) = @_;

   # Working variables

   my $curent_linetype = "";
   my $last_main_line  = -1;

   my $curent_entity;

   my @newlines;   # New line generated

   # Phase I - Split line in tokens and parse
   #               the tokens

   my $line_for_error = 1;
   LINE:
   for my $line (@ {$lines_ref} ) {
      my $line_info;
      my $new_line = $line;   # We work on a copy
      study $new_line;        # Make the substitution work.

      # Remove spaces at the end of the line
      $new_line =~ s/\s+$//;

      # Remove spaces at the begining of the line
      $new_line =~ s/^\s+//;

      ## Start by replacing the smart quotes and other similar characters.
      if (Pretty::Options::isConversionActive('ALL:Fix Common Extended ASCII')) {
         $new_line =~ s/\x82/,/g;
         $new_line =~ s/\x84/,,/g;
         $new_line =~ s/\x85/.../g;
         $new_line =~ s/\x88/^/g;
         $new_line =~ s/\x8B/</g;
         $new_line =~ s/\x8C/Oe/g;
         $new_line =~ s/\x91/\'/g;
         $new_line =~ s/\x92/\'/g;
         $new_line =~ s/\x93/\"/g;
         $new_line =~ s/\x94/\"/g;
         $new_line =~ s/\x95/*/g;
         $new_line =~ s/\x96/-/g;
         $new_line =~ s/\x97/-/g;
         $new_line =~ s-\x98-<sup>~</sup>-g;
         $new_line =~ s-\x99-<sup>TM</sup>-g;
         $new_line =~ s/\x9B/>/g;
         $new_line =~ s/\x9C/oe/g;
      }

      # Skip comments and empty lines
      if ( length($new_line) == 0 || $new_line =~ /^\#/ ) {

         # We push the line as is.
         push @newlines,
         [
            $curent_linetype,
            $new_line,
            $last_main_line,
            undef,
            undef,
         ];
         next LINE;
      }

      # Find the line type
      my $index = 0;
      LINE_SPEC:
      for my $line_spec ( @{ $master_file_type{$file_type} } ) {
         if ( $new_line =~ $line_spec->{RegEx} ) {

            # Found it !!!
            $line_info     = $line_spec;
            $curent_entity = $1;
            last LINE_SPEC;
         }
      }
      continue { $index++ }

                # If we didn't find a line type
                if ( $index >= @{ $master_file_type{$file_type} } ) {

                        $logging->warning(
                                qq(Can\'t find the line type for "$new_line"),
                                $file_for_error,
                                $line_for_error
                        );

                        # We push the line as is.
                        push @newlines,
                                [
                                $curent_linetype,
                                $new_line,
                                $last_main_line,
                                undef,
                                undef,
                                ];
                        next LINE;
                }

                # What type of line is it?
                $curent_linetype = $line_info->{Linetype};
                if ( $line_info->{Mode} == MAIN ) {
                        $last_main_line = $line_for_error - 1;
                }
                elsif ( $line_info->{Mode} == SUB ) {
                        $logging->warning(
                                qq{SUB line "$curent_linetype" is not preceded by a MAIN line},
                                $file_for_error,
                                $line_for_error
                        ) if $last_main_line == -1;
                }
                elsif ( $line_info->{Mode} == SINGLE ) {
                        $last_main_line = -1;
                }
                else {
                        die qq(Invalid type for $curent_linetype);
                }

                # Identify the deprecated tags.
                &scan_for_deprecated_tags( $new_line, $curent_linetype, $file_for_error, $line_for_error );

                # Split the line in tokens
                my %line_tokens;

                # By default, the tab character is used
                my $sep = $line_info->{SepRegEx} || qr(\t+);

                # We split the tokens, strip the spaces and silently remove the empty tags
                # (empty tokens are the result of [tab][space][tab] type of chracter
                # sequences).
                # [ 975999 ] [tab][space][tab] breaks prettylst
                my @tokens = grep { $_ ne q{} } map { s{ \A \s* | \s* \z }{}xmsg; $_ } split $sep, $new_line;

                #First, we deal with the tag-less columns
                COLUMN:
                for my $column ( @{ $column_with_no_tag{$curent_linetype} } ) {
                        last COLUMN if ( scalar @tokens == 0 );

                        # We remove the space before and after the token
                        #       $tokens[0] =~ s/\s+$//;
                        #       $tokens[0] =~ s/^\s+//;

                        # We remove the enclosing quotes if any
                        $logging->warning(
                                qq{Removing quotes around the '$tokens[0]' tag},
                                $file_for_error,
                                $line_for_error
                        ) if $tokens[0] =~ s/^"(.*)"$/$1/;

                        my $curent_token = shift @tokens;
                        $line_tokens{$column} = [$curent_token];

                        # Statistic gathering
                        $count_tags{"Valid"}{"Total"}{$column}++;
                        $count_tags{"Valid"}{$curent_linetype}{$column}++;

                        # Are we dealing with a .MOD, .FORGET or .COPY type of tag?
                        if ( index( $column, '000' ) == 0 ) {
                                my $check_mod = $line_info->{RegExIsMod} || qr{ \A (.*) [.] (MOD|FORGET|COPY=[^\t]+) }xmsi;

                                if ( $line_info->{ValidateKeep} ) {
                                        if ( my ($entity_name, $mod_part) = ($curent_token =~ $check_mod) ) {

                                                # We keep track of the .MOD type tags to
                                                # later validate if they are valid
                                                push @{ $referer{$curent_linetype}{$entity_name} },
                                                        [ $curent_token, $file_for_error, $line_for_error ]
                                                        if getOption('xcheck');

                                                # Special case for .COPY=<new name>
                                                # <new name> is a valid entity
                                                if ( my ($new_name) = ( $mod_part =~ / \A COPY= (.*) /xmsi ) ) {
                                                        $valid_entities{$curent_linetype}{$new_name}++;
                                                }

                                                last COLUMN;
                                        }
                                        else {
                                                if ( getOption('xcheck') ) {

                                                        # We keep track of the entities that could be used
                                                        # with a .MOD type of tag for later validation.
                                                        #
                                                        # Some line type need special code to extract the
                                                        # entry.
                                                        my $entry = $curent_token;
                                                        if ( $line_info->{RegExGetEntry} ) {
                                                                if ( $entry =~ $line_info->{RegExGetEntry} ) {
                                                                        $entry = $1;

                                                                        # Some line types refer to other line entries directly
                                                                        # in the line identifier.
                                                                        if ( exists $line_info->{GetRefList} ) {
                                                                                add_to_xcheck_tables(
                                                                                        $line_info->{IdentRefType},
                                                                                        $line_info->{IdentRefTag},
                                                                                        $file_for_error,
                                                                                        $line_for_error,
                                                                                        &{ $line_info->{GetRefList} }($entry)
                                                                                );
                                                                        }
                                                                }
                                                                else {
                                                                        $logging->warning(
                                                                                qq(Cannot find the $curent_linetype name),
                                                                                $file_for_error,
                                                                                $line_for_error
                                                                        );
                                                                }
                                                        }
                                                        $valid_entities{$curent_linetype}{$entry}++;

                                                        # Check to see if the entry must be recorded for other
                                                        # entry types.
                                                        if ( exists $line_info->{OtherValidEntries} ) {
                                                                for my $entry_type ( @{ $line_info->{OtherValidEntries} } ) {
                                                                        $valid_entities{$entry_type}{$entry}++;
                                                                }
                                                        }
                                                }
                                        }
                                }
                        }
                }

                #Second, let's parse the regular columns
                for my $token (@tokens) {
                        my $key = parse_tag($token, $curent_linetype, $file_for_error, $line_for_error);

                        if ($key) {
                                if ( exists $line_tokens{$key} && !exists $master_mult{$curent_linetype}{$key} ) {
                                        $logging->notice(
                                                qq{The tag "$key" should not be used more than once on the same $curent_linetype line.\n},
                                                $file_for_error,
                                                $line_for_error
                                        );
                                }

                        $line_tokens{$key}
                                = exists $line_tokens{$key} ? [ @{ $line_tokens{$key} }, $token ] : [$token];
                        }
                        else {
                                $logging->warning( "No tags in \"$token\"\n", $file_for_error, $line_for_error );
                                $line_tokens{$token} = $token;
                        }
                }

                my $newline = [
                        $curent_linetype,
                        \%line_tokens,
                        $last_main_line,
                        $curent_entity,
                        $line_info,
                ];

                ############################################################
                ######################## Conversion ########################
                # We manipulate the tags for the line here
                # This function call will parse individual lines, which will
                # in turn parse the tags within the lines.

                additionnal_line_parsing(\%line_tokens,
                                                $curent_linetype,
                                                $file_for_error,
                                                $line_for_error,
                                                $newline
                );

                ############################################################
                # Validate the line
                validate_line(\%line_tokens, $curent_linetype, $file_for_error, $line_for_error)
                if getOption('xcheck');

                ############################################################
                # .CLEAR order verification
                check_clear_tag_order(\%line_tokens, $file_for_error, $line_for_error);

                #Last, we put the tokens and other line info in the @newlines array
                push @newlines, $newline;

        }
        continue { $line_for_error++ }

        #####################################################
        #####################################################
        # We find all the header lines
        for ( my $line_index = 0; $line_index < @newlines; $line_index++ ) {
                my $curent_linetype = $newlines[$line_index][0];
                my $line_tokens = $newlines[$line_index][1];
                my $next_linetype;
                $next_linetype = $newlines[ $line_index + 1 ][0]
                if $line_index + 1 < @newlines;

                # A header line either begins with the curent line_type header
                # or the next line header.
                #
                # Only comment -- $line_token is not a hash --  can be header lines
                if ( ref($line_tokens) ne 'HASH' ) {

                        # We are on a comment line, we need to find the
                        # curent and the next line header.

                        # Curent header
                        my $this_header =
                                $curent_linetype
                                ? get_header( $master_order{$curent_linetype}[0], $curent_linetype )
                                : "";

                        # Next line header
                        my $next_header =
                                $next_linetype
                                ? get_header( $master_order{$next_linetype}[0], $next_linetype )
                                : "";

                        if (   ( $this_header && index( $line_tokens, $this_header ) == 0 )
                                || ( $next_header && index( $line_tokens, $next_header ) == 0 ) )
                        {

                                # It is a header, let's tag it as such.
                                $newlines[$line_index] = [
                                        'HEADER',
                                        $line_tokens,
                                ];
                        }
                        else {

                                # It is just a comment, we won't botter with it ever again.
                                $newlines[$line_index] = $line_tokens;
                        }
                }
        }

        #my $line_index = 0;
        #for my $line_ref (@newlines)
        #{
        #  my ($curent_linetype, $line_tokens, $main_linetype,
        #       $curent_entity, $line_info) = @$line_ref;
        #
        #  if(ref($line_tokens) ne 'HASH')
        #  {
        #
        #       # Header begins with the line type header.
        #       my $this_header = $curent_linetype
        #                               ? get_header($master_order{$curent_linetype}[0],$file_type)
        #                               : "";
        #       my $next_header = $line_index <= @newlines && ref($newlines[$line_index+1]) eq 'ARRAY' &&
        #                               $newlines[$line_index+1][0]
        #                               ? get_header($master_order{$newlines[$line_index+1][0]}[0],$file_type)
        #                               : "";
        #       if(($this_header && index($line_tokens, $this_header) == 0) ||
        #               ($next_header && index($line_tokens,$next_header) == 0))
        #       {
        #       $line_ref = [ 'HEADER',
        #                               $line_tokens,
        #                       ];
        #       }
        #       else
        #       {
        #               $line_ref = $line_tokens;
        #       }
        #       next;
        #  }
        #
        #} continue { $line_index++ };

        #################################################################
        ######################## Conversion #############################
        # We manipulate the tags for the whole file here

        additionnal_file_parsing(\@newlines, $file_type, $file_for_error);

        ##################################################
        ##################################################
        # Phase II - Reformating the lines

        # No reformating needed?
        return $lines_ref unless getOption('outputpath') && $writefiletype{$file_type};

        # Now on to all the non header lines.
        CORE_LINE:
        for ( my $line_index = 0; $line_index < @newlines; $line_index++ ) {

                # We skip the text lines and the header lines
                next CORE_LINE
                if ref( $newlines[$line_index] ) ne 'ARRAY'
                || $newlines[$line_index][0] eq 'HEADER';

                my $line_ref = $newlines[$line_index];
                my ($curent_linetype, $line_tokens, $last_main_line,
                $curent_entity,   $line_info
                )
                = @$line_ref;
                my $newline = "";

                # If the separator is not a tab, with just join the
                # tag in order
                my $sep = $line_info->{Sep} || "\t";
                if ( $sep ne "\t" ) {

                # First, the tag known in master_order
                for my $tag ( @{ $master_order{$curent_linetype} } ) {
                        if ( exists $line_tokens->{$tag} ) {
                                $newline .= join $sep, @{ $line_tokens->{$tag} };
                                $newline .= $sep;
                                delete $line_tokens->{$tag};
                        }
                }

                # The remaining tag are not in the master_order list
                for my $tag ( sort keys %$line_tokens ) {
                        $newline .= join $sep, @{ $line_tokens->{$tag} };
                        $newline .= $sep;
                }

                # We remove the extra separator
                for ( my $i = 0; $i < length($sep); $i++ ) {
                        chop $newline;
                }

                # We replace line_ref with the new line
                $newlines[$line_index] = $newline;
                next CORE_LINE;
                }

                ##################################################
                # The line must be formatted according to its
                # TYPE, FORMAT and HEADER parameters.

                my $mode   = $line_info->{Mode};
                my $format = $line_info->{Format};
                my $header = $line_info->{Header};

                if ( $mode == SINGLE || $format == LINE ) {

                # LINE: the line if formatted independently.
                #               The FORMAT is ignored.
                if ( $header == NO_HEADER ) {

                        # Just put the line in order and with a single tab
                        # between the columns. If there is a header in the previous
                        # line, we remove it.

                        # First, the tag known in master_order
                        for my $tag ( @{ $master_order{$curent_linetype} } ) {
                                if ( exists $line_tokens->{$tag} ) {
                                $newline .= join $sep, @{ $line_tokens->{$tag} };
                                $newline .= $sep;
                                delete $line_tokens->{$tag};
                                }
                        }

                        # The remaining tag are not in the master_order list
                        for my $tag ( sort keys %$line_tokens ) {
                                $newline .= join $sep, @{ $line_tokens->{$tag} };
                                $newline .= $sep;
                        }

                        # We remove the extra separator
                        for ( my $i = 0; $i < length($sep); $i++ ) {
                                chop $newline;
                        }

                        # If there was an header before this line, we remove it
                        if ( ref( $newlines[ $line_index - 1 ] ) eq 'ARRAY'
                                && $newlines[ $line_index - 1 ][0] eq 'HEADER' )
                        {
                                splice( @newlines, $line_index - 1, 1 );
                                $line_index--;
                        }

                        # Replace the array with the new line
                        $newlines[$line_index] = $newline;
                        next CORE_LINE;
                }
                elsif ( $header == LINE_HEADER ) {

                        # Put the line with a header in front of it.
                        my %col_length  = ();
                        my $header_line = "";
                        my $line_entity = "";

                        # Find the length for each column
                        $col_length{$_} = mylength( $line_tokens->{$_} ) for ( keys %$line_tokens );

                        # Find the columns order and build the header and
                        # the curent line
                        TAG_NAME:
                        for my $tag ( @{ $master_order{$curent_linetype} } ) {

                                # We skip the tag is not present
                                next TAG_NAME if !exists $col_length{$tag};

                                # The first tag is the line entity and most be kept
                                $line_entity = $line_tokens->{$tag}[0] unless $line_entity;

                                # What is the length of the column?
                                my $header_text   = get_header( $tag, $curent_linetype );
                                my $header_length = mylength($header_text);
                                my $col_length  =
                                        $header_length > $col_length{$tag}
                                ? $header_length
                                : $col_length{$tag};

                                # Round the col_length up to the next tab
                                $col_length = $tablength * ( int( $col_length / $tablength ) + 1 );

                                # The header
                                my $tab_to_add = int( ( $col_length - $header_length ) / $tablength )
                                + ( ( $col_length - $header_length ) % $tablength ? 1 : 0 );
                                $header_line .= $header_text . $sep x $tab_to_add;

                                # The line
                                $tab_to_add = int( ( $col_length - $col_length{$tag} ) / $tablength )
                                + ( ( $col_length - $col_length{$tag} ) % $tablength ? 1 : 0 );
                                $newline .= join $sep, @{ $line_tokens->{$tag} };
                                $newline .= $sep x $tab_to_add;

                                # Remove the tag we just dealt with
                                delete $line_tokens->{$tag};
                        }

                        # Add the tags that were not in the master_order
                        for my $tag ( sort keys %$line_tokens ) {

                                # What is the length of the column?
                                my $header_text   = get_header( $tag, $curent_linetype );
                                my $header_length = mylength($header_text);
                                my $col_length  =
                                        $header_length > $col_length{$tag}
                                ? $header_length
                                : $col_length{$tag};

                                # Round the col_length up to the next tab
                                $col_length = $tablength * ( int( $col_length / $tablength ) + 1 );

                                # The header
                                my $tab_to_add = int( ( $col_length - $header_length ) / $tablength )
                                + ( ( $col_length - $header_length ) % $tablength ? 1 : 0 );
                                $header_line .= $header_text . $sep x $tab_to_add;

                                # The line
                                $tab_to_add = int( ( $col_length - $col_length{$tag} ) / $tablength )
                                + ( ( $col_length - $col_length{$tag} ) % $tablength ? 1 : 0 );
                                $newline .= join $sep, @{ $line_tokens->{$tag} };
                                $newline .= $sep x $tab_to_add;
                        }

                        # Remove the extra separators (tabs) at the end of both lines
                        $header_line =~ s/$sep$//g;
                        $newline        =~ s/$sep$//g;

                        # Put the header in place
                        if ( ref( $newlines[ $line_index - 1 ] ) eq 'ARRAY'
                                && $newlines[ $line_index - 1 ][0] eq 'HEADER' )
                        {

                                # We replace the existing header
                                $newlines[ $line_index - 1 ] = $header_line;
                        }
                        else {

                                # We add the header before the line
                                splice( @newlines, $line_index++, 0, $header_line );
                        }

                        # Add an empty line in front of the header unless
                        # there is already one or the previous line
                        # match the line entity.
                        if ( $newlines[ $line_index - 2 ] ne ''
                                && index( $newlines[ $line_index - 2 ], $line_entity ) != 0 )
                        {
                                splice( @newlines, $line_index - 1, 0, '' );
                                $line_index++;
                        }

                        # Replace the array with the new line
                        $newlines[$line_index] = $newline;
                        next CORE_LINE;
                }
                else {

                        # Invalid option
                        die "Invalid \%master_file_type options: $file_type:$curent_linetype:$mode:$header";
                }
                }
                elsif ( $mode == MAIN ) {
                if ( $format == BLOCK ) {
                        #####################################
                        # All the main lines must be found
                        # up until a different main line type
                        # or a ###Block comment.
                        my @main_lines;
                        my $main_linetype = $curent_linetype;

                        BLOCK_LINE:
                        for ( my $index = $line_index; $index < @newlines; $index++ ) {

                                # If the line_type  change or
                                # if a '###Block' comment is found,
                                # we are out of the block
                                last BLOCK_LINE
                                if ( ref( $newlines[$index] ) eq 'ARRAY'
                                && ref $newlines[$index][4] eq 'HASH'
                                && $newlines[$index][4]{Mode} == MAIN
                                && $newlines[$index][0] ne $main_linetype )
                                || ( ref( $newlines[$index] ) ne 'ARRAY'
                                && index( lc( $newlines[$index] ), '###block' ) == 0 );

                                # Skip the lines already dealt with
                                next BLOCK_LINE
                                if ref( $newlines[$index] ) ne 'ARRAY'
                                || $newlines[$index][0] eq 'HEADER';

                                push @main_lines, $index
                                if $newlines[$index][4]{Mode} == MAIN;
                        }

                        #####################################
                        # We find the length of each tag for the block
                        my %col_length;
                        for my $block_line (@main_lines) {
                                for my $tag ( keys %{ $newlines[$block_line][1] } ) {
                                my $col_length = mylength( $newlines[$block_line][1]{$tag} );
                                $col_length{$tag} = $col_length
                                        if !exists $col_length{$tag} || $col_length > $col_length{$tag};
                                }
                        }

                        if ( $header != NO_HEADER ) {

                                # We add the length of the headers if needed.
                                for my $tag ( keys %col_length ) {
                                my $length = mylength( get_header( $tag, $file_type ) );

                                $col_length{$tag} = $length if $length > $col_length{$tag};
                                }
                        }

                        #####################################
                        # Find the columns order
                        my %seen;
                        my @col_order;

                        # First, the columns included in master_order
                        for my $tag ( @{ $master_order{$curent_linetype} } ) {
                                push @col_order, $tag if exists $col_length{$tag};
                                $seen{$tag}++;
                        }

                        # Put the unknown columns at the end
                        for my $tag ( sort keys %col_length ) {
                                push @col_order, $tag unless $seen{$tag};
                        }

                        # Each of the block lines must be reformated
                        for my $block_line (@main_lines) {
                                my $newline;

                                for my $tag (@col_order) {
                                my $col_max_length
                                        = $tablength * ( int( $col_length{$tag} / $tablength ) + 1 );

                                # Is the tag present in this line?
                                if ( exists $newlines[$block_line][1]{$tag} ) {
                                        my $curent_length = mylength( $newlines[$block_line][1]{$tag} );

                                        my $tab_to_add
                                                = int( ( $col_max_length - $curent_length ) / $tablength )
                                                + ( ( $col_max_length - $curent_length ) % $tablength ? 1 : 0 );
                                        $newline .= join $sep, @{ $newlines[$block_line][1]{$tag} };
                                        $newline .= $sep x $tab_to_add;
                                }
                                else {

                                        # We pad with tabs
                                        $newline .= $sep x ( $col_max_length / $tablength );
                                }
                                }

                                # We remove the extra $sep at the end
                                $newline =~ s/$sep+$//;

                                # We replace the array with the new line
                                $newlines[$block_line] = $newline;
                        }

                        if ( $header == NO_HEADER ) {

                                # If there are header before any of the block line,
                                # we need to remove them
                                for my $block_line ( reverse @main_lines ) {
                                if ( ref( $newlines[ $block_line - 1 ] ) eq 'ARRAY'
                                        && $newlines[ $block_line - 1 ][0] eq 'HEADER' )
                                {
                                        splice( @newlines, $block_line - 1, 1 );
                                        $line_index--;
                                }
                                }
                        }
                        elsif ( $header == LINE_HEADER ) {
                                die "MAIN:BLOCK:LINE_HEADER not implemented yet";
                        }
                        elsif ( $header == BLOCK_HEADER ) {

                                # We must add the header line at the top of the block
                                # and anywhere else we find them whitin the block.

                                my $header_line;
                                for my $tag (@col_order) {

                                # Round the col_length up to the next tab
                                my $col_max_length
                                        = $tablength * ( int( $col_length{$tag} / $tablength ) + 1 );
                                my $curent_header = get_header( $tag, $main_linetype );
                                my $curent_length = mylength($curent_header);
                                my $tab_to_add  = int( ( $col_max_length - $curent_length ) / $tablength )
                                        + ( ( $col_max_length - $curent_length ) % $tablength ? 1 : 0 );
                                $header_line .= $curent_header . $sep x $tab_to_add;
                                }

                                # We remove the extra $sep at the end
                                $header_line =~ s/$sep+$//;

                                # Before the top of the block
                                my $need_top_header = NO;
                                if ( ref( $newlines[ $main_lines[0] - 1 ] ) ne 'ARRAY'
                                || $newlines[ $main_lines[0] - 1 ][0] ne 'HEADER' )
                                {
                                $need_top_header = YES;
                                }

                                # Anywhere in the block
                                for my $block_line (@main_lines) {
                                if ( ref( $newlines[ $block_line - 1 ] ) eq 'ARRAY'
                                        && $newlines[ $block_line - 1 ][0] eq 'HEADER' )
                                {
                                        $newlines[ $block_line - 1 ] = $header_line;
                                }
                                }

                                # Add a header line at the top of the block
                                if ($need_top_header) {
                                splice( @newlines, $main_lines[0], 0, $header_line );
                                $line_index++;
                                }

                        }
                }
                else {
                        die "Invalid \%master_file_type format: $file_type:$curent_linetype:$mode:$header";
                }
                }
                elsif ( $mode == SUB ) {
                if ( $format == LINE ) {
                        die "SUB:LINE not implemented yet";
                }
                elsif ( $format == BLOCK || $format == FIRST_COLUMN ) {
                        #####################################
                        # Need to find all the file in the SUB BLOCK i.e. same
                        # line type within two MAIN lines.
                        # If we encounter a ###Block comment, that's the end
                        # of the block
                        my @sub_lines;
                        my $begin_block  = $last_main_line;
                        my $sub_linetype = $curent_linetype;

                        BLOCK_LINE:
                        for ( my $index = $line_index; $index < @newlines; $index++ ) {

                                # If the last_main_line change or
                                # if a '###Block' comment is found,
                                # we are out of the block
                                last BLOCK_LINE
                                if ( ref( $newlines[$index] ) eq 'ARRAY'
                                && $newlines[$index][0] ne 'HEADER'
                                && $newlines[$index][2] != $begin_block )
                                || ( ref( $newlines[$index] ) ne 'ARRAY'
                                && index( lc( $newlines[$index] ), '###block' ) == 0 );

                                # Skip the lines already dealt with
                                next BLOCK_LINE
                                if ref( $newlines[$index] ) ne 'ARRAY'
                                || $newlines[$index][0] eq 'HEADER';

                                push @sub_lines, $index
                                if $newlines[$index][0] eq $curent_linetype;
                        }

                        #####################################
                        # We find the length of each tag for the block
                        my %col_length;
                        for my $block_line (@sub_lines) {
                                for my $tag ( keys %{ $newlines[$block_line][1] } ) {
                                my $col_length = mylength( $newlines[$block_line][1]{$tag} );
                                $col_length{$tag} = $col_length
                                        if !exists $col_length{$tag} || $col_length > $col_length{$tag};
                                }
                        }

                        if ( $header == BLOCK_HEADER ) {

                                # We add the length of the headers if needed.
                                for my $tag ( keys %col_length ) {
                                my $length = mylength( get_header( $tag, $file_type ) );

                                $col_length{$tag} = $length if $length > $col_length{$tag};
                                }
                        }

                        #####################################
                        # Find the columns order
                        my %seen;
                        my @col_order;

                        # First, the columns included in master_order
                        for my $tag ( @{ $master_order{$curent_linetype} } ) {
                                push @col_order, $tag if exists $col_length{$tag};
                                $seen{$tag}++;
                        }

                        # Put the unknown columns at the end
                        for my $tag ( sort keys %col_length ) {
                                push @col_order, $tag unless $seen{$tag};
                        }

                        # Each of the block lines must be reformated
                        if ( $format == BLOCK ) {
                                for my $block_line (@sub_lines) {
                                my $newline;

                                for my $tag (@col_order) {
                                        my $col_max_length
                                                = $tablength * ( int( $col_length{$tag} / $tablength ) + 1 );

                                        # Is the tag present in this line?
                                        if ( exists $newlines[$block_line][1]{$tag} ) {
                                                my $curent_length = mylength( $newlines[$block_line][1]{$tag} );

                                                my $tab_to_add
                                                = int( ( $col_max_length - $curent_length ) / $tablength )
                                                + ( ( $col_max_length - $curent_length ) % $tablength ? 1 : 0 );
                                                $newline .= join $sep, @{ $newlines[$block_line][1]{$tag} };
                                                $newline .= $sep x $tab_to_add;
                                        }
                                        else {

                                                # We pad with tabs
                                                $newline .= $sep x ( $col_max_length / $tablength );
                                        }
                                }

                                # We replace the array with the new line
                                $newlines[$block_line] = $newline;
                                }
                        }
                        else {

                                # $format == FIRST_COLUMN

                                for my $block_line (@sub_lines) {
                                my $newline;
                                my $first_column = YES;
                                my $tab_to_add;

                                TAG:
                                for my $tag (@col_order) {

                                        # Is the tag present in this line?
                                        next TAG if !exists $newlines[$block_line][1]{$tag};

                                        if ($first_column) {
                                                my $col_max_length
                                                = $tablength * ( int( $col_length{$tag} / $tablength ) + 1 );
                                                my $curent_length = mylength( $newlines[$block_line][1]{$tag} );

                                                $tab_to_add
                                                = int( ( $col_max_length - $curent_length ) / $tablength )
                                                + ( ( $col_max_length - $curent_length ) % $tablength ? 1 : 0 );

                                                # It's no longer the first column
                                                $first_column = NO;
                                        }
                                        else {
                                                $tab_to_add = 1;
                                        }

                                        $newline .= join $sep, @{ $newlines[$block_line][1]{$tag} };
                                        $newline .= $sep x $tab_to_add;
                                }

                                # We replace the array with the new line
                                $newlines[$block_line] = $newline;
                                }
                        }

                        if ( $header == NO_HEADER ) {

                                # If there are header before any of the block line,
                                # we need to remove them
                                for my $block_line ( reverse @sub_lines ) {
                                if ( ref( $newlines[ $block_line - 1 ] ) eq 'ARRAY'
                                        && $newlines[ $block_line - 1 ][0] eq 'HEADER' )
                                {
                                        splice( @newlines, $block_line - 1, 1 );
                                        $line_index--;
                                }
                                }
                        }
                        elsif ( $header == LINE_HEADER ) {
                                die "SUB:BLOCK:LINE_HEADER not implemented yet";
                        }
                        elsif ( $header == BLOCK_HEADER ) {

                                # We must add the header line at the top of the block
                                # and anywhere else we find them whitin the block.

                                my $header_line;
                                for my $tag (@col_order) {

                                # Round the col_length up to the next tab
                                my $col_max_length
                                        = $tablength * ( int( $col_length{$tag} / $tablength ) + 1 );
                                my $curent_header = get_header( $tag, $sub_linetype );
                                my $curent_length = mylength($curent_header);
                                my $tab_to_add  = int( ( $col_max_length - $curent_length ) / $tablength )
                                        + ( ( $col_max_length - $curent_length ) % $tablength ? 1 : 0 );
                                $header_line .= $header . $sep x $tab_to_add;
                                }

                                # Before the top of the block
                                my $need_top_header = NO;
                                if ( ref( $newlines[ $sub_lines[0] - 1 ] ) ne 'ARRAY'
                                || $newlines[ $sub_lines[0] - 1 ][0] ne 'HEADER' )
                                {
                                $need_top_header = YES;
                                }

                                # Anywhere in the block
                                for my $block_line (@sub_lines) {
                                if ( ref( $newlines[ $block_line - 1 ] ) eq 'ARRAY'
                                        && $newlines[ $block_line - 1 ][0] eq 'HEADER' )
                                {
                                        $newlines[ $block_line - 1 ] = $header_line;
                                }
                                }

                                # Add a header line at the top of the block
                                if ($need_top_header) {
                                splice( @newlines, $sub_lines[0], 0, $header_line );
                                $line_index++;
                                }

                        }
                        else {
                                die "Invalid \%master_file_type: $curent_linetype:$mode:$format:$header";
                        }
                }
                else {
                        die "Invalid \%master_file_type: $curent_linetype:$mode:$format:$header";
                }
                }
                else {
                die "Invalide \%master_file_type mode: $file_type:$curent_linetype:$mode";
                }

        }

        # If there are header lines remaining, we keep the old value
        for (@newlines) {
                $_ = $_->[1] if ref($_) eq 'ARRAY' && $_->[0] eq 'HEADER';
        }

        return \@newlines;

}

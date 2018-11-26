package Pretty::Options;

use 5.008_001;				# Perl 5.8.1 or better is now mandantory
use strict;
use warnings;

use Scalar::Util qw(reftype);
use Getopt::Long qw(GetOptionsFromArray);
use Exporter qw(import);

our (@ISA, @EXPORT_OK);

@EXPORT_OK = qw(getOption setOption);

# Default command line options
our (%cl_options, %activate, %conversion_enable);

%activate = (
  'ADD:SAB'          => 'ALL:Convert ADD:SA to ADD:SAB',
  'ASCII'            => 'ALL:Fix Common Extended ASCII',
  'classskill'       => 'CLASSSKILL conversion to CLASS',
  'classspell'       => 'CLASSSPELL conversion to SPELL',
  'foldbacklines'    => 'ALL:Multiple lines to one',
  'Followeralign'    => 'DEITY:Followeralign conversion',
  'gmconv'           => 'PCC:GAMEMODE Add to the CMP DnD_',
  'ml21'             => 'ALL:Multiple lines to one',
  'natattackfix'     => 'ALL:CMP NatAttack fix',
  'noprofreq'        => 'RACE:NoProfReq',
  'notready'         => 'ALL:BONUS:MOVE conversion',
  'pcgen433'         => 'ALL: 4.3.3 Weapon name change',
  'pcgen438'         => [ 'ALL:PRESTAT needs a ,', 'EQUIPMENT: remove ATTACKS', 'EQUIPMENT: SLOTS:2 for plurals', ],
  'pcgen511'         => [ 'ALL: , to | in VISION', 'ALL:PRECLASS needs a ,', ],
  'pcgen5120'        => [ 'DEITY:Followeralign conversion', 'ALL:ADD Syntax Fix', 'ALL:PRESPELLTYPE Syntax', 'ALL:EQMOD has new keys', ],
  'pcgen534'         => [ 'PCC:GAME to GAMEMODE', 'ALL:Add TYPE=Base.REPLACE', ],
  'pcgen541'         => 'WEAPONPROF:No more SIZE',
  'pcgen54cmp'       => [ 'PCC:GAME to GAMEMODE', 'ALL:Add TYPE=Base.REPLACE', 'RACE:CSKILL to MONCSKILL', ],
  'pcgen54'          => [ 'PCC:GAMEMODE DnD to 3e', 'PCC:GAME to GAMEMODE', 'ALL:Add TYPE=Base.REPLACE', 'RACE:CSKILL to MONCSKILL', ],
  'pcgen555'         => 'EQUIP:no more MOVE',
  'pcgen5713'        => [ 'ALL:Convert SPELL to SPELLS', 'TEMPLATE:HITDICESIZE to HITDIE', 'ALL:PRECLASS needs a ,', ],
  'pcgen574'         => [ 'CLASS:CASTERLEVEL for all casters', 'ALL:MOVE:nn to MOVE:Walk,nn', ],
  'pcgen580'         => 'ALL:PREALIGN conversion',
  'pcgen60'          => 'CLASS:no more HASSPELLFORMULA',
  'RACETYPE'         => 'RACE:TYPE to RACETYPE',
  'rmprealign'       => 'ALL:CMP remove PREALIGN',
  'skillbonusfix'    => 'RACE:BONUS SKILL Climb and Swim',
  'Weaponauto'       => 'ALL:Weaponauto simple conversion',
  'Willpower'        => 'ALL:Willpower to Will',
  );

# The active conversions
%conversion_enable =
(
   'Generate BONUS and PRExxx report'   => 0,
                                                 # After PCGEN 2.7.3
   'ALL: 4.3.3 Weapon name change'      => 0,    # Bunch of name changed for SRD compliance
   'EQUIPMENT: remove ATTACKS'          => 0,    # [ 686169 ] remove ATTACKS: tag
   'EQUIPMENT: SLOTS:2 for plurals'     => 0,    # [ 695677 ] EQUIPMENT: SLOTS for gloves, bracers and boots
   'PCC:GAME to GAMEMODE'               => 0,    # [ 707325 ] PCC: GAME is now GAMEMODE
   'ALL: , to | in VISION'              => 0,    # [ 699834 ] Incorrect loading of multiple vision types
                                                 # [ 728038 ] BONUS:VISION must replace VISION:
   'ALL:PRESTAT needs a ,'              => 0,    # PRESTAT now only accepts the format PRESTAT:1,<stat>=<n>
   'ALL:BONUS:MOVE conversion'          => 0,    # [ 711565 ] BONUS:MOVE replaced with BONUS:MOVEADD
   'ALL:PRECLASS needs a ,'             => 0,    # [ 731973 ] ALL: new PRECLASS syntax
   'ALL:COUNT[FEATTYPE=...'             => 0,    # [ 737718 ] COUNT[FEATTYPE] data change
   'ALL:Add TYPE=Base.REPLACE'          => 0,    # [ 784363 ] Add TYPE=Base.REPLACE to most BONUS:COMBAT|BAB
   'PCC:GAMEMODE DnD to 3e'             => 0,    # [ 825005 ] convert GAMEMODE:DnD to GAMEMODE:3e
   'RACE:CSKILL to MONCSKILL'           => 0,    # [ 831569 ] RACE:CSKILL to MONCSKILL
   'RACE:NoProfReq'                     => 0,    # [ 832164 ] Adding NoProfReq to AUTO:WEAPONPROF for most races
   'RACE:BONUS SKILL Climb and Swim'    => 0,    # Fix for Barak files
   'WEAPONPROF:No more SIZE'            => 0,    # [ 845853 ] SIZE is no longer valid in the weaponprof files
   'EQUIP:no more MOVE'                 => 0,    # [ 865826 ] Remove the deprecated MOVE tag in EQUIPMENT files
   'ALL:EQMOD has new keys'             => 0,    # [ 892746 ] KEYS entries were changed in the main files
   'CLASS:CASTERLEVEL for all casters'  => 0,    # [ 876536 ] All spell casting classes need CASTERLEVEL
   'ALL:MOVE:nn to MOVE:Walk,nn'        => 0,    # [ 1006285 ] Convertion MOVE:<number> to MOVE:Walk,<Number>
   'ALL:Convert SPELL to SPELLS'        => 0,    # [ 1070084 ] Convert SPELL to SPELLS
   'TEMPLATE:HITDICESIZE to HITDIE'     => 0,    # [ 1070344 ] HITDICESIZE to HITDIE in templates.lst
   'ALL:PREALIGN conversion'            => 0,    # [ 1173567 ] Convert old style PREALIGN to new style
   'ALL:PRERACE needs a ,'              => 0,
   'ALL:Willpower to Will'              => 0,    # [ 1398237 ] ALL: Convert Willpower to Will
   'ALL:New SOURCExxx tag format'       => 1,    # [ 1444527 ] New SOURCE tag format
   'RACE:Remove MFEAT and HITDICE'      => 0,    # [ 1514765 ] Conversion to remove old defaultmonster tags
   'EQUIP: ALTCRITICAL to ALTCRITMULT'  => 1,    # [ 1615457 ] Replace ALTCRITICAL with ALTCRITMULT'
   'Export lists'                       => 0,    # Export various lists of entities
   'SOURCE line replacement'            => 1,
   'CLASSSKILL conversion to CLASS'     => 0,
   'CLASS:Four lines'                   => 1,    # [ 626133 ] Convert CLASS lines into 3 lines
   'ALL:Multiple lines to one'          => 0,    # Reformat multiple lines to one line for RACE and TEMPLATE
   'CLASSSPELL conversion to SPELL'     => 0,    # [ 641912 ] Convert CLASSSPELL to SPELL
   'SPELL:Add TYPE tags'                => 0,    # [ 653596 ] Add a TYPE tag for all SPELLs
   'BIOSET:generate the new files'      => 0,    # [ 663491 ] RACE: Convert AGE, HEIGHT and WEIGHT tags
   'EQUIPMENT: generate EQMOD'          => 0,    # [ 677962 ] The DMG wands have no charge.
   'CLASS: SPELLLIST from Spell.MOD'    => 0,    # [ 779341 ] Spell Name.MOD to CLASS's SPELLLEVEL
   'PCC:GAMEMODE Add to the CMP DnD_'   => 0,    # In order for the CMP files to work with the  normal PCGEN files
   'ALL:Find Willpower'                 => 1,    # `Find the tags that use Willpower so that we can plan the conversion to Will
   'RACE:TYPE to RACETYPE'              => 0,    # [ 1353255 ] TYPE to RACETYPE conversion
   'ALL:CMP NatAttack fix'              => 0,    # Fix STR bonus for Natural Attacks in CMP files
   'ALL:CMP remove PREALIGN'            => 0,    # Remove the PREALIGN tag everywhere (to help my CMP friends)
   'RACE:Fix PREDEFAULTMONSTER bonuses' => 0,    # [ 1514765] Conversion to remove old defaultmonster tags
   'ALL:Fix Common Extended ASCII'      => 0,    # [ 1324519 ] ASCII characters
   'ALL:Weaponauto simple conversion'   => 0,    # [ 1223873 ] WEAPONAUTO is no longer valid
   'DEITY:Followeralign conversion'     => 0,    # [ 1689538 ] Conversion: Deprecation of FOLLOWERALIGN
   'ALL:ADD Syntax Fix'                 => 0,    # [ 1678577 ] ADD: syntax no longer uses parens
   'ALL:PRESPELLTYPE Syntax'            => 0,    # [ 1678570 ] Correct PRESPELLTYPE syntax
   'ALL:Convert ADD:SA to ADD:SAB'      => 0,    # [ 1864711 ] Convert ADD:SA to ADD:SAB
   'CLASS:no more HASSPELLFORMULA'      => 0,    # [ 1973497 ] HASSPELLFORMULA is deprecated
);

sub parseOptions {

   local @ARGV = @_;

   # Set up the defaults for each of the options
   my $basepath       = q{};     # Base path for the @ replacement
   my $convert        = q{};     # Activate a standard conversion
   my $exportlist     = 0;       # Export lists of object in CVS format
   my $file_type      = q{};     # File type to use if no PCC are read
   my $gamemode       = q{};     # GAMEMODE filter for the PCC files
   my $help           = 0;       # Need help? Display the usage
   my $html_help      = 0;       # Generate the HTML doc
   my $input_path     = q{};     # Path for the input directory
   my $man            = 0;       # Display the complete doc (man page)
   my $missing_header = 0;       # Report the tags that have no defined header.
   my $nojep          = 0;       # Do not use the new parse_jep function
   my $nowarning      = 0;       # Do not display warning messages in the report
   my $noxcheck       = 0;       # Disable the x-check validations
   my $old_source_tag = 0;       # Use | instead of \t for the SOURCExxx line
   my $output_error   = q{};     # Path and file name of the error log
   my $output_path    = q{};     # Path for the ouput directory
   my $report         = 0;       # Generate tag usage report
   my $system_path    = q{};     # Path to the system (game mode) files
   my $test           = 0;       # Internal; for tests only
   my $warning_level  = 'info';  # Warning level for error output
   my $xcheck         = 1;       # Perform cross-check validation

   my $error_message = "\n";

   if ( scalar @ARGV ) {

      GetOptions(
         'basepath|b=s'      =>  \$basepath,  
         'convert|c=s'       =>  \$convert,
         'exportlist'        =>  \$exportlist,
         'filetype|f=s'      =>  \$file_type,
         'gamemode|gm=s'     =>  \$gamemode,
         'help|h|?'          =>  \$help,
         'htmlhelp'          =>  \$html_help,
         'inputpath|i=s'     =>  \$input_path,
         'man'               =>  \$man,
         'missingheader|mh'  =>  \$missing_header,
         'nojep'             =>  \$nojep,
         'nowarning|nw'      =>  \$nowarning,
         'noxcheck|nx'       =>  \$noxcheck,
         'old_source_tag'    =>  \$old_source_tag,
         'outputerror|e=s'   =>  \$output_error,
         'outputpath|o=s'    =>  \$output_path,
         'report|r'          =>  \$report,
         'systempath|s=s'    =>  \$system_path,
         'test'              =>  \$test,
         'warninglevel|wl=s' =>  \$warning_level,
         'xcheck|x'          =>  \$xcheck);

      %cl_options = (
         'basepath'        =>  $basepath,  
         'convert'         =>  $convert,
         'exportlist'      =>  $exportlist,
         'filetype'        =>  $file_type,
         'gamemode'        =>  $gamemode,
         'help'            =>  $help,
         'htmlhelp'        =>  $html_help,
         'inputpath'       =>  $input_path,
         'man'             =>  $man,
         'missingheader'   =>  $missing_header,
         'nojep'           =>  $nojep,
         'nowarning'       =>  $nowarning,
         'noxcheck'        =>  $noxcheck,
         'old_source_tag'  =>  $old_source_tag,
         'outputerror'     =>  $output_error,
         'outputpath'      =>  $output_path,
         'report'          =>  $report,
         'systempath'      =>  $system_path,
         'test'            =>  $test,
         'warninglevel'    =>  $warning_level,
         'xcheck'          =>  $xcheck);

      # Has a conversion been requested
      turnOns ($cl_options{convert}) if $cl_options{convert};

      processOptions();

      # Print message for unknown options
      if ( scalar @ARGV ) {
         $error_message = "\nUnknown option:";

         while (@ARGV) {
            $error_message .= q{ };
            $error_message .= shift;
         }
         $error_message .= "\n";
         $cl_options{help} = 1;

         return $error_message;
      }

   } else {
      $cl_options{help} = 0;
   }
   return "";
}

=head2 getOption

   get the current value of option.

   C<getOption( 'basepath' )> 

=cut

sub getOption {
   my $opt = shift;

   return $cl_options{$opt};
};

=head2 setOption

   Set a new value in option, returns the current value of the option.

   C<$result = setOption( 'basepath', './working' )> 

=cut


sub setOption {
   my ($opt, $value) = @_;

   my $current = $cl_options{$opt};

   $cl_options{$opt} = $value;

   return $current;
};

sub isConversionActive {
   my ($opt) = @_;

   return $conversion_enable{$opt};
};

=head2 turnOns

   Turn on any conversions that have been requested via command line options

=cut

sub turnOns {
   my ($convert) = @_;

   my $entry   = $activate{ $convert };
   my $isArray = reftype $entry eq 'ARRAY';

   # Convert whatever we got to an array
   my @conv = $isArray ?  @$entry : ( $entry );

   # Turn on each entry of the array
   for my $conversion ( @conv ) {
      $conversion_enable{$conversion} = 1;
   }
}

sub process_options {

   # No-warning option
   # level 6 is info, level 5 is notice
   if ( getOption('nowarning') && getOption('warning_level') >= 6 ) {
      putOption('warning_level', 5);
   }

   # old_source_tag option
   if ( getOption('old_source_tag') ) {
      # We disable the conversion if the -old_source_tag option is used
      $conversion_enable{'ALL:New SOURCExxx tag format'} = 0;
   }

   # exportlist option
   if ( getOption('exportlist') ) {
      $conversion_enable{'Export lists'} = 1;
   }

   # noxcheck option
   if ( getOption('noxcheck') ) {

      # The xcheck option is now on by default. Using noxcheck is the only way to
      # disable it
      $cl_options{xcheck} = 0;
   }

   # basepath option
   # If no basepath was given, use input_dir
   if ( getOption('basepath') eq q{} ) {
      $cl_options{basepath} = $cl_options{'input_path'};
   }

   $cl_options{basepath} =~ tr{\\}{/};
};





1;

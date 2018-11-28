package Pretty::Reformat;

use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0);

use Pretty::Options qw{getOption};
# use Pretty::Conversions;

# Constants for the master_line_type
use constant {
   # Line importance (Mode)
   MAIN           => 1, # Main line type for the file
   SUB            => 2, # Sub line type, must be linked to a MAIN
   SINGLE         => 3, # Idependant line type
   COMMENT        => 4, # Comment or empty line.

   # Line formatting option (Format)
   LINE           => 1, # Every line formatted by itself
   BLOCK          => 2, # Lines formatted as a block
   FIRST_COLUMN   => 3, # Only the first column of the block gets aligned

   # Line header option (Header)
   NO_HEADER      => 1, # No header
   LINE_HEADER    => 2, # One header before each line
   BLOCK_HEADER   => 3, # One header for the block

   # Standard YES NO constants
   NO             => 0,
   YES            => 1,

   # The defined (non-standard) size of a tab
   TABSIZE        => 6,
};

our %count_tags;        # Will hold the number of each tag found (by linetype)

our %referer;           # Will hold the tags that refer to other entries
                           # Format: push @{$referer{$EntityType}{$entryname}},
                           #               [ $tags{$column}, $file_for_error, $line_for_error ]

our %valid_entities;    # Will hold the entries that may be refered
                           # by other tags
                           # Format $valid_entities{$entitytype}{$entityname}
                           # We initialise the hash with global system values
                           # that are valid but never defined in the .lst files.

our %master_mult;       # Will hold the tags that can be there more then once



# The SOURCE line is use in nearly all file types
my %SourceLineDef = (
   Linetype  => 'SOURCE',
   RegEx     => qr(^SOURCE\w*:([^\t]*)),
   Mode      => SINGLE,
   Format    => LINE,
   Header    => NO_HEADER,
   SepRegEx  => qr{ (?: [|] ) | (?: \t+ ) }xms,  # Catch both | and tab
);

# Some ppl may still want to use the old ways (for PCGen v5.9.5 and older)
if( getOption('oldsourcetag') ) {
   $SourceLineDef{Sep} = q{|};  # use | instead of [tab] to split
}

# The file type that will be rewritten.
my %writefiletype = (
   'ABILITY'         => 1,
   'ABILITYCATEGORY' => 1,
   'BIOSET'          => 1,
   'CLASS'           => 1,
   'CLASS Level'     => 1,
   'COMPANIONMOD'    => 1,
   'COPYRIGHT'       => 0,
   'COVER'           => 0,
   'DEITY'           => 1,
   'DOMAIN'          => 1,
   'EQUIPMENT'       => 1,
   'EQUIPMOD'        => 1,
   'FEAT'            => 1,
   'KIT',            => 1,
   'LANGUAGE'        => 1,
   'LSTEXCLUDE'      => 0,
   'INFOTEXT'        => 0,
   'PCC'             => 1,
   'RACE'            => 1,
   'SKILL'           => 1,
   'SPELL'           => 1,
   'TEMPLATE'        => 1,
   'WEAPONPROF'      => 1,
   'ARMORPROF'       => 1,
   'SHIELDPROF'      => 1,
   '#EXTRAFILE'      => 0,
   'VARIABLE'        => 1,
   'DATACONTROL'     => 1,
   'GLOBALMOD'       => 1,
   'SAVE'            => 1,
   'STAT'            => 1,
   'ALIGNMENT'       => 1,
);


# Information needed to parse the line type
our %masterFileType = (

   ABILITY => [
      \%SourceLineDef,
      {  Linetype       => 'ABILITY',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   ABILITYCATEGORY => [
      \%SourceLineDef,
      {  Linetype       => 'ABILITYCATEGORY',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   BIOSET => [
      \%SourceLineDef,
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
      \%SourceLineDef,
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
      \%SourceLineDef,
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
         IdentRefType   => 'RACE',                 # Identifier that refers to other entry type
         IdentRefTag    => 'MASTERBONUSRACE',      # Tag name for the reference check
         # Get the list of reference identifiers
         # The syntax is MASTERBONUSRACE:race
         # We need to extract the race name.
         GetRefList     => sub { return @_ },
      },
   ],

   DEITY => [
      \%SourceLineDef,
      {  Linetype       => 'DEITY',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   DOMAIN => [
      \%SourceLineDef,
      {  Linetype       => 'DOMAIN',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   EQUIPMENT => [
      \%SourceLineDef,
      {  Linetype       => 'EQUIPMENT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   EQUIPMOD => [
      \%SourceLineDef,
      {  Linetype       => 'EQUIPMOD',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   FEAT => [
      \%SourceLineDef,
      {  Linetype       => 'FEAT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   KIT => [
      \%SourceLineDef,
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
      \%SourceLineDef,
      {  Linetype       => 'LANGUAGE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   RACE => [
      \%SourceLineDef,
      {  Linetype       => 'RACE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SKILL => [
      \%SourceLineDef,
      {  Linetype       => 'SKILL',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SPELL => [
      \%SourceLineDef,
      {  Linetype       => 'SPELL',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   TEMPLATE => [
      \%SourceLineDef,
      {  Linetype       => 'TEMPLATE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   WEAPONPROF => [
      \%SourceLineDef,
      {  Linetype       => 'WEAPONPROF',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   ARMORPROF => [
      \%SourceLineDef,
      {  Linetype       => 'ARMORPROF',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SHIELDPROF => [
      \%SourceLineDef,
      {  Linetype       => 'SHIELDPROF',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   VARIABLE => [
      \%SourceLineDef,
      {  Linetype       => 'VARIABLE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   DATACONTROL => [
      \%SourceLineDef,
      {  Linetype       => 'DATACONTROL',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],
   GLOBALMOD => [
      \%SourceLineDef,
      {  Linetype       => 'GLOBALMOD',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

   SAVE => [
      \%SourceLineDef,
      {  Linetype       => 'SAVE',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],
   STAT => [
      \%SourceLineDef,
      {  Linetype       => 'STAT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],
   ALIGNMENT => [
      \%SourceLineDef,
      {  Linetype       => 'ALIGNMENT',
         RegEx          => qr(^([^\t:]+)),
         Mode           => MAIN,
         Format         => BLOCK,
         Header         => BLOCK_HEADER,
         ValidateKeep   => YES,
      },
   ],

);


# The PRExxx tags. These are used in many of the line types, but they are only
# defined once and every line type will get the same sort order.

my @PRETags = (
   'PRE:.CLEAR',
   'PREABILITY:*',
   '!PREABILITY',
   'PREAGESET',
   '!PREAGESET',
   'PREALIGN:*',
   '!PREALIGN:*',
   'PREARMORPROF:*',
   '!PREARMORPROF',
   'PREARMORTYPE',
   '!PREARMORTYPE',
   'PREATT',
   '!PREATT',
   'PREBASESIZEEQ',
   '!PREBASESIZEEQ',
   'PREBASESIZEGT',
   '!PREBASESIZEGT',
   'PREBASESIZEGTEQ',
   '!PREBASESIZEGTEQ',
   'PREBASESIZELT',
   '!PREBASESIZELT',
   'PREBASESIZELTEQ',
   '!PREBASESIZELTEQ',
   'PREBASESIZENEQ',
   'PREBIRTHPLACE',
   '!PREBIRTHPLACE',
   'PRECAMPAIGN',
   '!PRECAMPAIGN',
   'PRECHECK',
   '!PRECHECK',
   'PRECHECKBASE',
   '!PRECHECKBASE',
   'PRECITY',
   '!PRECITY',
   'PRECHARACTERTYPE',
   '!PRECHARACTERTYPE',
   'PRECLASS',
   '!PRECLASS',
   'PRECLASSLEVELMAX',
   '!PRECLASSLEVELMAX',
   'PRECSKILL',
   '!PRECSKILL',
   'PREDEITY',
   '!PREDEITY',
   'PREDEITYALIGN',
   '!PREDEITYALIGN',
   'PREDEITYDOMAIN',
   '!PREDEITYDOMAIN',
   'PREDOMAIN',
   '!PREDOMAIN',
   'PREDR',
   '!PREDR',
   'PREEQUIP',
   '!PREEQUIP',
   'PREEQUIPBOTH',
   '!PREEQUIPBOTH',
   'PREEQUIPPRIMARY',
   '!PREEQUIPPRIMARY',
   'PREEQUIPSECONDARY',
   '!PREEQUIPSECONDARY',
   'PREEQUIPTWOWEAPON',
   '!PREEQUIPTWOWEAPON',
   'PREFEAT:*',
   '!PREFEAT',
   'PREFACT:*',
   '!PREFACT',
   'PREGENDER',
   '!PREGENDER',
   'PREHANDSEQ',
   '!PREHANDSEQ',
   'PREHANDSGT',
   '!PREHANDSGT',
   'PREHANDSGTEQ',
   '!PREHANDSGTEQ',
   'PREHANDSLT',
   '!PREHANDSLT',
   'PREHANDSLTEQ',
   '!PREHANDSLTEQ',
   'PREHANDSNEQ',
   'PREHD',
   '!PREHD',
   'PREHP',
   '!PREHP',
   'PREITEM',
   '!PREITEM',
   'PRELANG',
   '!PRELANG',
   'PRELEGSEQ',
   '!PRELEGSEQ',
   'PRELEGSGT',
   '!PRELEGSGT',
   'PRELEGSGTEQ',
   '!PRELEGSGTEQ',
   'PRELEGSLT',
   '!PRELEGSLT',
   'PRELEGSLTEQ',
   '!PRELEGSLTEQ',
   'PRELEGSNEQ',
   'PRELEVEL',
   '!PRELEVEL',
   'PRELEVELMAX',
   '!PRELEVELMAX',
   'PREKIT',
   '!PREKIT',
   'PREMOVE',
   '!PREMOVE',
   'PREMULT:*',
   '!PREMULT:*',
   'PREPCLEVEL',
   '!PREPCLEVEL',
   'PREPROFWITHARMOR',
   '!PREPROFWITHARMOR',
   'PREPROFWITHSHIELD',
   '!PREPROFWITHSHIELD',
   'PRERACE:*',
   '!PRERACE:*',
   'PREREACH',
   '!PREREACH',
   'PREREACHEQ',
   '!PREREACHEQ',
   'PREREACHGT',
   '!PREREACHGT',
   'PREREACHGTEQ',
   '!PREREACHGTEQ',
   'PREREACHLT',
   '!PREREACHLT',
   'PREREACHLTEQ',
   '!PREREACHLTEQ',
   'PREREACHNEQ',
   'PREREGION',
   '!PREREGION',
   'PRERULE',
   '!PRERULE',
   'PRESA',
   '!PRESA',
   'PRESITUATION',
   '!PRESITUATION',
   'PRESHIELDPROF',
   '!PRESHIELDPROF',
   'PRESIZEEQ',
   '!PRESIZEEQ',
   'PRESIZEGT',
   '!PRESIZEGT',
   'PRESIZEGTEQ',
   '!PRESIZEGTEQ',
   'PRESIZELT',
   '!PRESIZELT',
   'PRESIZELTEQ',
   '!PRESIZELTEQ',
   'PRESIZENEQ',
   'PRESKILL:*',
   '!PRESKILL',
   'PRESKILLMULT',
   '!PRESKILLMULT',
   'PRESKILLTOT',
   '!PRESKILLTOT',
   'PRESPELL:*',
   '!PRESPELL',
   'PRESPELLBOOK',
   '!PRESPELLBOOK',
   'PRESPELLCAST:*',
   '!PRESPELLCAST:*',
   'PRESPELLDESCRIPTOR',
   'PRESPELLSCHOOL:*',
   '!PRESPELLSCHOOL',
   'PRESPELLSCHOOLSUB',
   '!PRESPELLSCHOOLSUB',
   'PRESPELLTYPE:*',
   '!PRESPELLTYPE',
   'PRESREQ',
   '!PRESREQ',
   'PRESRGT',
   '!PRESRGT',
   'PRESRGTEQ',
   '!PRESRGTEQ',
   'PRESRLT',
   '!PRESRLT',
   'PRESRLTEQ',
   '!PRESRLTEQ',
   'PRESRNEQ',
   'PRESTAT:*',
   '!PRESTAT',
   'PRESTATEQ',
   '!PRESTATEQ',
   'PRESTATGT',
   '!PRESTATGT',
   'PRESTATGTEQ',
   '!PRESTATGTEQ',
   'PRESTATLT',
   '!PRESTATLT',
   'PRESTATLTEQ',
   '!PRESTATLTEQ',
   'PRESTATNEQ',
   'PRESUBCLASS',
   '!PRESUBCLASS',
   'PRETEMPLATE:*',
   '!PRETEMPLATE:*',
   'PRETEXT',
   '!PRETEXT',
   'PRETYPE:*',
   '!PRETYPE:*',
   'PRETOTALAB:*',
   '!PRETOTALAB:*',
   'PREUATT',
   '!PREUATT',
   'PREVAREQ:*',
   '!PREVAREQ:*',
   'PREVARGT:*',
   '!PREVARGT:*',
   'PREVARGTEQ:*',
   '!PREVARGTEQ:*',
   'PREVARLT:*',
   '!PREVARLT:*',
   'PREVARLTEQ:*',
   '!PREVARLTEQ:*',
   'PREVARNEQ:*',
   'PREVISION',
   '!PREVISION',
   'PREWEAPONPROF:*',
   '!PREWEAPONPROF:*',
   'PREWIELD',
   '!PREWIELD',

   # Removed tags
   #       'PREVAR',
);

# Hash used by validate_pre_tag to verify if a PRExxx tag exists
our %preTags = (
   'PREAPPLY'          => 1,  # Only valid when embeded - THIS IS DEPRECATED
# Uncommenting until conversion for monster kits is done to prevent error messages.
   'PREDEFAULTMONSTER' => 1,  # Only valid when embeded
);

# Now use the array of pre tags to populate the preTags hash
for my $preTag (@PRETags) {

   # We need a copy since we don't want to modify the original
   my $preTagName = $preTag;

   # We strip the :* at the end to get the real name for the lookup table
   $preTagName =~ s/ [:][*] \z//xms;

   $preTags{$preTagName} = 1;
}

# Global tags allowed in PCC files.
our @doublePCCTags = (
   'BONUS:ABILITYPOOL:*',
   'BONUS:CASTERLEVEL:*',
   'BONUS:CHECKS:*',
   'BONUS:COMBAT:*',
   'BONUS:CONCENTRATION:*',
   'BONUS:DC:*',
   'BONUS:DOMAIN:*',
   'BONUS:DR:*',
   'BONUS:FEAT:*',
   'BONUS:FOLLOWERS',
   'BONUS:HP:*',
   'BONUS:MISC:*',
   'BONUS:MOVEADD:*',
   'BONUS:MOVEMULT:*',
   'BONUS:PCLEVEL:*',
   'BONUS:POSTMOVEADD:*',
   'BONUS:POSTRANGEADD:*',
   'BONUS:RANGEADD:*',
   'BONUS:RANGEMULT:*',
   'BONUS:SAVE:*',
   'BONUS:SIZEMOD:*',
   'BONUS:SKILL:*',
   'BONUS:SKILLPOINTS:*',
   'BONUS:SKILLPOOL:*',
   'BONUS:SKILLRANK:*',
   'BONUS:SLOTS:*',
   'BONUS:SPECIALTYSPELLKNOWN:*',
   'BONUS:SPELLCAST:*',
   'BONUS:SPELLCASTMULT:*',
   'BONUS:SPELLKNOWN:*',
   'BONUS:STAT:*',
   'BONUS:UDAM:*',
   'BONUS:VAR:*',
   'BONUS:VISION:*',
   'BONUS:WEAPONPROF:*',
   'BONUS:WIELDCATEGORY:*',
);

our %doublePCCTags = ();

# Now use the array of valid double tags to populate the hash
for my $doubleTag (@PRETags) {

   # We need a copy since we don't want to modify the original
   my $doubleTagName = $doubleTag;

   # We strip the :* at the end to get the real name for the lookup table
   $doubleTagName =~ s/ [:][*] \z//xms;

   $doublePCCTags{$doubleTagName} = 1;
}

our @SOURCETags = (
   'SOURCELONG',
   'SOURCESHORT',
   'SOURCEWEB',
   'SOURCEPAGE:.CLEAR',
   'SOURCEPAGE',
   'SOURCELINK',
);

our @QUALIFYTags = (
   'QUALIFY:ABILITY',
   'QUALIFY:CLASS',
   'QUALIFY:DEITY',
   'QUALIFY:DOMAIN',
   'QUALIFY:EQUIPMENT',
   'QUALIFY:EQMOD',
   'QUALIFY:FEAT',
   'QUALIFY:RACE',
   'QUALIFY:SPELL',
   'QUALIFY:SKILL',
   'QUALIFY:TEMPLATE',
   'QUALIFY:WEAPONPROF',
);

# Working variables
my %columnWithNoTag = (

   'ABILITY' => [
      '000AbilityName',
   ],

   'ABILITYCATEGORY' => [
      '000AbilityCategory',
   ],

   'ARMORPROF' => [
      '000ArmorName',
   ],

   'CLASS' => [
      '000ClassName',
   ],

   'CLASS Level' => [
      '000Level',
   ],

   'COMPANIONMOD' => [
      '000Follower',
   ],

   'DEITY' => [
      '000DeityName',
   ],

   'DOMAIN' => [
      '000DomainName',
   ],

   'EQUIPMENT' => [
      '000EquipmentName',
   ],

   'EQUIPMOD' => [
      '000ModifierName',
   ],

   'FEAT' => [
      '000FeatName',
   ],

   'LANGUAGE' => [
      '000LanguageName',
   ],

   'MASTERBONUSRACE' => [
      '000MasterBonusRace',
   ],

   'RACE' => [
      '000RaceName',
   ],

   'SHIELDPROF' => [
      '000ShieldName',
   ],

   'SKILL' => [
      '000SkillName',
   ],

   'SPELL' => [
      '000SpellName',
   ],

   'SUBCLASS' => [
      '000SubClassName',
   ],

   'SUBSTITUTIONCLASS' => [
      '000SubstitutionClassName',
   ],

   'TEMPLATE' => [
      '000TemplateName',
   ],

   'WEAPONPROF' => [
      '000WeaponName',
   ],

   'VARIABLE' => [
      '000VariableName',
   ],

   'DATACONTROL' => [
      '000DatacontrolName',
   ],

   'GLOBALMOD' => [
      '000GlobalmodName',
   ],

   'ALIGNMENT' => [
      '000AlignmentName',
   ],

   'SAVE' => [
      '000SaveName',
   ],

   'STAT' => [
      '000StatName',
   ],

);

# [ 1956340 ] Centralize global BONUS tags
# The global BONUS:xxx tags. They are used in many of the line types.  They are
# defined in one place, and every line type will get the same sort order.
# BONUSes only valid for specific line types are listed on those line types
my @globalBONUSTags = (
   'BONUS:ABILITYPOOL:*',           # Global
   'BONUS:CASTERLEVEL:*',           # Global
   'BONUS:CHECKS:*',                # Global       DEPRECATED
   'BONUS:COMBAT:*',                # Global
   'BONUS:CONCENTRATION:*',         # Global
   'BONUS:DC:*',                    # Global
   'BONUS:DOMAIN:*',                # Global
   'BONUS:DR:*',                    # Global
   'BONUS:FEAT:*',                  # Global
   'BONUS:FOLLOWERS',               # Global
   'BONUS:HP:*',                    # Global
   'BONUS:MISC:*',                  # Global
   'BONUS:MOVEADD:*',               # Global
   'BONUS:MOVEMULT:*',              # Global
   'BONUS:PCLEVEL:*',               # Global
   'BONUS:POSTMOVEADD:*',           # Global
   'BONUS:POSTRANGEADD:*',          # Global
   'BONUS:RANGEADD:*',              # Global
   'BONUS:RANGEMULT:*',             # Global
   'BONUS:SAVE:*',                  # Global       Replacement for CHECKS
   'BONUS:SITUATION:*',             # Global
   'BONUS:SIZEMOD:*',               # Global
   'BONUS:SKILL:*',                 # Global
   'BONUS:SKILLPOINTS:*',           # Global
   'BONUS:SKILLPOOL:*',             # Global
   'BONUS:SKILLRANK:*',             # Global
   'BONUS:SLOTS:*',                 # Global
   'BONUS:SPECIALTYSPELLKNOWN:*',   # Global
   'BONUS:SPELLCAST:*',             # Global
   'BONUS:SPELLCASTMULT:*',         # Global
   'BONUS:SPELLKNOWN:*',            # Global
   'BONUS:STAT:*',                  # Global
   'BONUS:UDAM:*',                  # Global
   'BONUS:VAR:*',                   # Global
   'BONUS:VISION:*',                # Global
   'BONUS:WEAPONPROF:*',            # Global
   'BONUS:WIELDCATEGORY:*',         # Global
);


# Order for the tags for each line type.
our %master_order = (
   'ABILITY' => [
      '000AbilityName',
      'KEY',
      'SORTKEY',
      'NAMEISPI',
      'OUTPUTNAME',
      'CATEGORY',
      'TYPE:.CLEAR',
      'TYPE:*',
      'VISIBLE',
      @PRETags,
      @QUALIFYTags,
      'SERVESAS',
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      'SPELL:*',
      'SPELLS:*',
      'DESCISPI',
      'DESC:.CLEAR',
      'DESC:*',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'MOVE',
      'MOVECLONE',
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'UDAM',
      'UMULT',
      'ABILITY:*',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FAVOREDCLASS',
      'ADD:FORCEPOINT',
      'ADD:LANGUAGE:*',
      'ADD:SKILL:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ADD:WEAPONPROFS',
      'ADDSPELLLEVEL',
      'REMOVE',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'FOLLOWERS',
      'CHANGEPROF',
      'COMPANIONLIST:*',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL',
      'VISION',
      'SR',
      'DR',
      'REP',
      'COST',
      'KIT',
      @SOURCETags,
      'NATURALATTACKS',
      'ASPECT:*',
      'BENEFIT:*',
      'TEMPDESC',
      'SPELLKNOWN:CLASS:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:CLASS:*',
      'SPELLLEVEL:DOMAIN:*',
      'UNENCUMBEREDMOVE',
      'TEMPBONUS:*',
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'APPLIEDNAME',                   # Deprecated 6.05.01
      'SA:.CLEAR',                     # Deprecated
      'SA:*',                          # Deprecated
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'LANGAUTO:.CLEAR',               # Deprecated - 6.0
      'LANGAUTO:*',                    # Deprecated - 6.0
   ],

   'ABILITYCATEGORY' => [
      '000AbilityCategory',
      'VISIBLE',
      'EDITABLE',
      'EDITPOOL',
      'FRACTIONALPOOL',
      'POOL',
      'CATEGORY',
      'TYPE',
      'ABILITYLIST',
      'PLURAL',
      'DISPLAYNAME',
      'DISPLAYLOCATION',
   ],

   'ARMORPROF' => [
      '000ArmorName',
      'KEY',
      'NAMEISPI',
      'OUTPUTNAME',
      'TYPE',
      'HANDS',
      @PRETags,
      @SOURCETags,
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'SAB:.CLEAR',
      'SAB:*',
      'SA:.CLEAR',                     # Deprecated
      'SA:*',                          # Deprecated
   ],

   'BIOSET AGESET' => [
      'AGESET',
      'BONUS:STAT:*',
   ],

   'BIOSET RACENAME' => [
      'RACENAME',
      'CLASS',
      'SEX',
      'BASEAGE',
      'MAXAGE',
      'AGEDIEROLL',
      'HAIR',
      'EYES',
      'SKINTONE',
   ],

   'CLASS' => [
      '000ClassName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'HD',
      'XTRAFEATS',
      'SPELLSTAT',
      'BONUSSPELLSTAT',
      'FACT:SpellType:*',
      'SPELLTYPE',
      'TYPE',
      'CLASSTYPE',
      'FACT:Abb:*',
      'ABB',
      'MAXLEVEL',
      'CASTAS',
      'MEMORIZE',
      'KNOWNSPELLS',
      'SPELLBOOK',
      'HASSUBCLASS',
      'ALLOWBASECLASS',
      'HASSUBSTITUTIONLEVEL',
      'EXCLASS',
      @SOURCETags,
      'LANGBONUS:.CLEAR',
      'LANGBONUS:*',
      'WEAPONBONUS',
      'VISION',
      'SR',
      'DR',
      'ATTACKCYCLE',
      'DEF',
      'ITEMCREATE',
      'KNOWNSPELLSFROMSPECIALTY',
      'PROHIBITED',
      'PROHIBITSPELL:*',
      'LEVELSPERFEAT',
      'ABILITY:*',
      'VFEAT:*',
      'MULTIPREREQS',
      'VISIBLE',
      'DEFINE:*',
      'DEFINESTAT:*',
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:FEAT:*',
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',
      'ADD:LANGUAGE:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',
      'CHANGEPROF',
      'DOMAIN:*',                      # [ 1973526 ] DOMAIN is supported on Class line
      'ADDDOMAINS:*',
      'REMOVE',
      'BONUS:HD:*',                    # Class Lines
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:WEAPON:*',
      'REP:*',
      'SPELLLIST',
      'GENDER',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'KIT',
      'DEITY',
      @PRETags,
      'PRERACETYPE',
      '!PRERACETYPE',
      'STARTSKILLPTS',
      'MODTOSKILLS',
      'SKILLLIST',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'MONSKILL',
      'MONNONSKILLHD:*',
      'SPELLKNOWN:CLASS:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:CLASS',
      'SPELLLEVEL:DOMAIN',
      'UNENCUMBEREDMOVE',
      'TEMPBONUS',
      'ROLE',
      'HASSPELLFORMULA',               # [ 1893279 ] HASSPELLFORMULA Class Line tag  # [ 1973497 ] HASSPELLFORMULA is deprecated
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'LANGAUTO:.CLEAR',               # Deprecated - 6.0
      'LANGAUTO:*',                    # Deprecated - 6.0
   ],

   'CLASS Level' => [
      '000Level',
      'REPEATLEVEL',
      'DONOTADD',
      'UATT',
      'UDAM',
      'UMULT',
      'ADD:SPELLCASTER',
      'CAST',
      'KNOWN',
      'SPECIALTYKNOWN',
      'KNOWNSPELLS',
      'PROHIBITSPELL:*',
      'HITDIE',
      'MOVE',
      'VISION',
      'SR',
      'DR',
      'DOMAIN:*',
      'DEITY',
      @PRETags,
      'SAB:.CLEAR',
      'SAB:*',
      'BONUS:HD:*',                    # Class Lines
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:WEAPON:*',
      'TEMPDESC',
      'DEFINE:*',
      'DEFINESTAT:*',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:LANGUAGE:*',
      'ADD:TEMPLATE:*',
      'REMOVE',
      'LANGBONUS:.CLEAR',
      'LANGBONUS:*',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'EXCHANGELEVEL',
      'ABILITY:*',
      'SPELL',
      'SPELLS:*',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'KIT',
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'CHANGEPROF:*',
      'ADDDOMAINS',                    # [ 1973660 ] ADDDOMAINS is supported on Class Level lines
      @QUALIFYTags,
      'SERVESAS',
      'WEAPONBONUS',
      'SUBCLASS',
      'SPELLKNOWN:CLASS:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:CLASS',
      'SPELLLEVEL:DOMAIN',
      'SPELLLIST',
      'NATURALATTACKS',
      'UNENCUMBEREDMOVE',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'SPECIALS',                      # Deprecated 6.05.01
      'FEAT',                          # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'SA:.CLEAR:*',                   # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'LANGAUTO:.CLEAR',               # Deprecated - 6.0
      'LANGAUTO:*',                    # Deprecated - 6.0
      'FEATAUTO:.CLEAR',               # Deprecated - 6.0
      'FEATAUTO:*',                    # Deprecated - 6.0
   ],

   'COMPANIONMOD' => [
      '000Follower',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'FOLLOWER',
      'TYPE',
      'HD',
      'DR',
      'SR',
      'ABILITY:.CLEAR',
      'ABILITY:*',
      'COPYMASTERBAB',
      'COPYMASTERCHECK',
      'COPYMASTERHP',
      'USEMASTERSKILL',
      'GENDER',
      'PRERACE',
      '!PRERACE',
      'MOVE',
      'KIT',
      'AUTO:ARMORPROF:*',
      'SAB:.CLEAR',
      'SAB:*',
      'ADD:LANGUAGE',
      'DEFINE:*',
      'DEFINESTAT:*',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'RACETYPE',
      'SWITCHRACE:*',
      'TEMPLATE:*',                    # [ 2946558 ] TEMPLATE can be used in COMPANIONMOD lines
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'DESC:.CLEAR',
      'DESC:*',
      'FEAT:.CLEAR',                   # Deprecated 6.05.01
      'FEAT:*',                        # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'AUTO:FEAT:.CLEAR',              # Deprecated 6.05.01
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'SA:.CLEAR',                     # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
   ],

   'DEITY' => [
      '000DeityName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'DOMAINS:*',
      'FOLLOWERALIGN',
      'DESCISPI',
      'DESC',
      'FACT:*',
      'FACTSET:*',
      'DEITYWEAP',
      'ALIGN',
      @SOURCETags,
      @PRETags,
      @QUALIFYTags,
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'DEFINE:*',
      'DEFINESTAT:*',
      'SR',
      'DR',
      'AUTO:WEAPONPROF',
      'SAB:.CLEAR',
      'SAB:*',
      'ABILITY:*',
      'UNENCUMBEREDMOVE',
      'SYMBOL',                        # Deprecated 6.05.01
      'PANTHEON',                      # Deprecated 6.05.01
      'TITLE',                         # Deprecated 6.05.01
      'WORSHIPPERS',                   # Deprecated 6.05.01
      'APPEARANCE',                    # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'SA:.CLEAR',                     # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
      'RACE:*',                        # Deprecated 6.05.01
   ],

   'DOMAIN' => [
      '000DomainName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      @PRETags,
      @QUALIFYTags,
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'SPELL',
      'SPELLS:*',
      'VISION',
      'SR',
      'DR',
      'ABILITY:*',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:LANGUAGE:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      @SOURCETags,
      'DESCISPI',
      'DESC:.CLEAR',
      'DESC:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:DOMAIN',
      'UNENCUMBEREDMOVE',
      'FEAT:*',                        # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'FEATAUTO',                      # Deprecated
      'SA:*',                          # Deprecated
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
   ],

   'EQUIPMENT' => [
      '000EquipmentName',
      'KEY',
      'SORTKEY',
      'NAMEISPI',
      'OUTPUTNAME',
      'PROFICIENCY:WEAPON',
      'PROFICIENCY:ARMOR',
      'PROFICIENCY:SHIELD',
      'TYPE:.CLEAR',
      'TYPE:*',
      'ALTTYPE',
      'RESIZE',                        # [ 1956719 ] Add RESIZE tag to Equipment file
      'CONTAINS',
      'NUMPAGES',
      'PAGEUSAGE',
      'COST',
      'WT',
      'SLOTS',
      @PRETags,
      @QUALIFYTags,
      'DEFINE:*',
      'DEFINESTAT:*',
      'ACCHECK:*',
      'BASEITEM',
      'BASEQTY',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'CRITMULT',
      'CRITRANGE',
      'ALTCRITMULT',
      'ALTCRITRANGE',
      'FUMBLERANGE',
      'DAMAGE',
      'ALTDAMAGE',
      'EQMOD:*',
      'ALTEQMOD',
      'HANDS',
      'WIELD',
      'MAXDEX',
      'MODS',
      'RANGE',
      'REACH',
      'REACHMULT',
      'SIZE',
      'MOVE',
      'MOVECLONE',
      @SOURCETags,
      'SPELLFAILURE',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:LANGUAGE:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ABILITY:*',
      'VISION',
      'SR',
      'DR',
      'SPELL:*',
      'SPELLS:*',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:EQM:*',
      'BONUS:EQMARMOR:*',
      'BONUS:EQMWEAPON:*',
      'BONUS:ESIZE:*',
      'BONUS:ITEMCOST:*',
      'BONUS:WEAPON:*',
      'QUALITY:*',                     # [ 1593868 ] New equipment tag "QUALITY"
      'SPROP:.CLEAR',
      'SPROP:*',
      'SAB:.CLEAR',
      'SAB:*',
      'CSKILL:.CLEAR',
      'CSKILL',
      'UDAM',
      'UMULT',
      'AUTO:EQUIP:*',
      'AUTO:WEAPONPROF:*',
      'DESC:*',
      'TEMPDESC',
      'UNENCUMBEREDMOVE',
      'ICON',
      'VFEAT:.CLEAR',                  # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'LANGAUTO:.CLEAR',               # Deprecated - replaced by AUTO:LANG
      'LANGAUTO:*',                    # Deprecated - replaced by AUTO:LANG
      'RATEOFFIRE',                    # Deprecated 6.05.01 - replaced by FACT
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'SA:.CLEAR',                     # Deprecated - replaced by SAB
      'SA:*',                          # Deprecated
#     'ALTCRITICAL',                   # Removed [ 1615457 ] Replace ALTCRITICAL with ALTCRITMULT
   ],

   'EQUIPMOD' => [
      '000ModifierName',
      'KEY',
      'NAMEISPI',
      'OUTPUTNAME',
      'FORMATCAT',
      'NAMEOPT',
      'TYPE:.CLEAR',
      'TYPE:*',
      'PLUS',
      'COST',
      'VISIBLE',
      'ITYPE',
      'IGNORES',
      'REPLACES',
      'COSTPRE',
      @SOURCETags,
      @PRETags,
      @QUALIFYTags,
      'ADDPROF',
      'VISION',
      'SR',
      'DR',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:EQM:*',
      'BONUS:EQMARMOR:*',
      'BONUS:EQMWEAPON:*',
      'BONUS:ITEMCOST:*',
      'BONUS:WEAPON:*',
      'SPROP:*',
      'ABILITY',
      'FUMBLERANGE',
      'SAB:.CLEAR',
      'SAB:*',
      'ARMORTYPE:*',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'ASSIGNTOALL',
      'CHARGES',
      'DEFINE:*',
      'DEFINESTAT:*',
      'SPELL',
      'SPELLS:*',
      'AUTO:EQUIP:*',
      'UNENCUMBEREDMOVE',
      'RATEOFFIRE',                    #  Deprecated 6.05.01
      'VFEAT:*',                       #  Deprecated 6.05.01
      'SA:.CLEAR',                     #  Deprecated 6.05.01
      'SA:*',                          #  Deprecated 6.05.01
   ],

# This entire File is being deprecated
   'FEAT' => [
      '000FeatName',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'TYPE:.CLEAR',
      'TYPE',
      'VISIBLE',
      'CATEGORY',                      # [ 1671410 ] xcheck CATEGORY:Feat in Feat object.
      @PRETags,
      @QUALIFYTags,
      'SERVESAS',
      'SA:.CLEAR',
      'SA:*',
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      'SPELL:*',
      'SPELLS:*',
      'DESCISPI',
      'DESC:.CLEAR',                   # [ 1594651 ] New Tag: Feat.lst: DESC:.CLEAR and multiple DESC tags
      'DESC:*',                        # [ 1594651 ] New Tag: Feat.lst: DESC:.CLEAR and multiple DESC tags
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'MOVE',
      'MOVECLONE',
      'REMOVE',
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:FEAT:*',
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'UDAM',
      'UMULT',
      'VFEAT:*',
      'ABILITY:*',
      'ADD:*',
      'ADD:.CLEAR',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FAVOREDCLASS',
      'ADD:FEAT:*',
      'ADD:FORCEPOINT',
      'ADD:LANGUAGE:*',
      'ADD:SKILL',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',
      'ADD:WEAPONPROFS',
      'ADDSPELLLEVEL',
      'APPLIEDNAME',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:WEAPON:*',
      'CHANGEPROF:*',
      'FOLLOWERS',
      'COMPANIONLIST:*',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL',
      'VISION',
      'SR',
      'DR:.CLEAR',
      'DR:*',
      'REP',
      'COST',
      'KIT',
      @SOURCETags,
      'NATURALATTACKS',
      'ASPECT:*',
      'BENEFIT:*',
      'TEMPDESC',
      'SPELLKNOWN:CLASS:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:CLASS:*',
      'SPELLLEVEL:DOMAIN:*',
      'UNENCUMBEREDMOVE',
      'TEMPBONUS',
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'LANGAUTO:.CLEAR',               # Deprecated - 6.0
      'LANGAUTO:*',                    # Deprecated - 6.0
   ],

   'KIT ALIGN' => [
      'ALIGN',
      'OPTION',
      @PRETags,
   ],

   'KIT CLASS' => [
      'CLASS',
      'LEVEL',
      'SUBCLASS',
      'OPTION',
      @PRETags,
   ],

   'KIT DEITY' => [
      'DEITY',
      'DOMAIN',
      'COUNT',
      'OPTION',
      @PRETags,
   ],

   'KIT FEAT' => [
      'FEAT',
      'FREE',
      'COUNT',
      'OPTION',
      @PRETags,
   ],
   'KIT ABILITY' => [
      'ABILITY',
      'FREE',
      'OPTION',
      @PRETags,
   ],

   'KIT FUNDS' => [
      'FUNDS',
      'QTY',
      'OPTION',
      @PRETags,
   ],

   'KIT GEAR' => [
      'GEAR',
      'QTY',
      'SIZE',
      'MAXCOST',
      'LOCATION',
      'EQMOD',
      'LOOKUP',
      'LEVEL',
      'SPROP',
      'OPTION',
      @PRETags,
   ],

   'KIT GENDER' => [
      'GENDER',
      'OPTION',
      @PRETags,
   ],

   'KIT KIT' => [
      'KIT',
      'OPTION',
      @PRETags,
   ],

   'KIT LANGBONUS' => [
      'LANGBONUS',
      'OPTION',
      @PRETags,
   ],

   'KIT LEVELABILITY' => [
      'LEVELABILITY',
      'ABILITY',
      @PRETags,
   ],

   'KIT NAME' => [
      'NAME',
      @PRETags,
   ],

   'KIT PROF' => [
      'PROF',
      'RACIAL',
      'COUNT',
      @PRETags,
   ],

   'KIT RACE' => [
      'RACE',
      @PRETags,
   ],

   'KIT REGION' => [
      'REGION',
      @PRETags,
   ],

   'KIT SELECT' => [
      'SELECT',
      @PRETags,
   ],

   'KIT SKILL' => [
      'SKILL',
      'RANK',
      'FREE',
      'COUNT',
      'OPTION',
      'SELECTION',
      @PRETags,
   ],

   'KIT SPELLS' => [
      'SPELLS',
      'COUNT',
      'OPTION',
      @PRETags,
   ],

   'KIT STARTPACK' => [
      'STARTPACK',
      'TYPE',
      'VISIBLE',
      'APPLY',
      'EQUIPBUY',
      'EQUIPSELL',
      @PRETags,
      'SOURCEPAGE',
   ],

   'KIT STAT' => [
      'STAT',
      'OPTION',
      @PRETags,
   ],

   'KIT TABLE' => [
      'TABLE',
      'LOOKUP',
      'VALUES',
      @PRETags,
   ],

   'KIT TEMPLATE' => [
      'TEMPLATE',
      'OPTION',
      @PRETags,
   ],

   'LANGUAGE' => [
      '000LanguageName',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'TYPE',
      'SOURCEPAGE',
      @PRETags,
      @QUALIFYTags,
   ],

   'MASTERBONUSRACE' => [
      '000MasterBonusRace',
      'TYPE',
      'BONUS:ABILITYPOOL:*',
      'BONUS:CASTERLEVEL:*',
      'BONUS:CHECKS:*',
      'BONUS:COMBAT:*',
      'BONUS:CONCENTRATION:*',
      'BONUS:DC:*',
      'BONUS:FEAT:*',
      'BONUS:MOVEADD:*',
      'BONUS:HP:*',
      'BONUS:MOVEMULT:*',
      'BONUS:POSTMOVEADD:*',
      'BONUS:SAVE:*',                  # Global        Replacement for CHECKS
      'BONUS:SKILL:*',
      'BONUS:STAT:*',
      'BONUS:UDAM:*',
      'BONUS:VAR:*',
      'ADD:LANGUAGE',
      'ABILITY:*',                     # [ 2596967 ] ABILITY not recognized for MASTERBONUSRACE
      'VFEAT:*',                       # Deprecated 6.05.01
      'SA:.CLEAR',                     # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
      'SAB:.CLEAR',
      'SAB:*',

   ],

   'PCC' => [
      'ALLOWDUPES',
      'CAMPAIGN',
      'GAMEMODE',
      'GENRE',
      'BOOKTYPE',
      'KEY',                           # KEY is allowed
      'PUBNAMELONG',
      'PUBNAMESHORT',
      'PUBNAMEWEB',
      'RANK',
      'SETTING',
      'TYPE',
      'PRECAMPAIGN',
      '!PRECAMPAIGN',
      'SHOWINMENU',                    # [ 1718370 ] SHOWINMENU tag missing for PCC files
      'SOURCELONG',
      'SOURCESHORT',
      'SOURCEWEB',
      'SOURCEDATE',                    # [ 1584007 ] New Tag: SOURCEDATE in PCC
      'COVER',
      'COPYRIGHT',
      'LOGO',
      'DESC',
      'URL',
      'LICENSE',
      'HELP',
      'INFOTEXT',
      'ISD20',
      'ISLICENSED',
      'ISOGL',
      'ISMATURE',
      'BIOSET',
      'HIDETYPE',
      'COMPANIONLIST',                 # [ 1672551 ] PCC tag COMPANIONLIST
      'REQSKILL',
      'STATUS',
      'FORWARDREF',
      'OPTION',

      # These tags load files
      'DATACONTROL',
      'STAT',
      'SAVE',
      'ALIGNMENT',
      'ABILITY',
      'ABILITYCATEGORY',
      'ARMORPROF',
      'CLASS',
      'CLASSSKILL',
      'CLASSSPELL',
      'COMPANIONMOD',
      'DEITY',
      'DOMAIN',
      'EQUIPMENT',
      'EQUIPMOD',
      'FEAT',
      'KIT',
      'LANGUAGE',
      'LSTEXCLUDE',
      'PCC',
      'RACE',
      'SHIELDPROF',
      'SKILL',
      'SPELL',
      'TEMPLATE',
      'WEAPONPROF',
      '#EXTRAFILE',                    # Fix #EXTRAFILE so it recognizes #EXTRAFILE references (so OGL is a known referenced file again.)

      #These tags are normal file global tags....
      @doublePCCTags,                  # Global tags that are double - $tag has an embeded ':'
   ],

   'RACE' => [
      '000RaceName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'FAVCLASS',
      'XTRASKILLPTSPERLVL',
      'STARTFEATS',
      'FACT:*',
      'SIZE',
      'MOVE',
      'MOVECLONE',
      'UNENCUMBEREDMOVE',
      'FACE',
      'REACH',
      'VISION',
      @PRETags,
      @QUALIFYTags,
      'SERVESAS',
      'LANGBONUS:.CLEAR',
      'LANGBONUS:*',
      'WEAPONBONUS:*',
      'CHANGEPROF:*',
      'PROF',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL',
      'MONCSKILL',
      'MONCCSKILL',
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:FEAT:*',                   #  Deprecated 6.05.01
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'VFEAT:*',                       #  Deprecated 6.05.01
      'FEAT:*',                        #  Deprecated 6.05.01
      'ABILITY:*',
      'MFEAT:*',
      'LEGS',
      'HANDS',
      'GENDER',
      'NATURALATTACKS:*',
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      'HITDICE',
      'SR',
      'DR:.CLEAR',
      'DR:*',
      'SKILLMULT',
      'BAB',
      'HITDIE',
      'MONSTERCLASS',
      'RACETYPE:.CLEAR',
      'RACETYPE:*',
      'RACESUBTYPE:.CLEAR',
      'RACESUBTYPE:*',
      'TYPE',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'HITDICEADVANCEMENT',
      'LEVELADJUSTMENT',
      'CR',
      'CRMOD',
      'ROLE',
      @SOURCETags,
      'SPELL:*',
      'SPELLS:*',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:LANGUAGE:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'REGION',
      'SUBREGION',
      'SPELLKNOWN:CLASS:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:CLASS:*',
      'SPELLLEVEL:DOMAIN:*',
      'KIT',
      'SA:.CLEAR',                     # Deprecated
      'SA:*',                          # Deprecated
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'LANGAUTO:.CLEAR',               # Deprecated - 6.0
      'LANGAUTO:*',                    # Deprecated - 6.0
   ],

   'SHIELDPROF' => [
      '000ShieldName',
      'KEY',
      'NAMEISPI',
      'OUTPUTNAME',
      'TYPE',
      'HANDS',
      @PRETags,
      @SOURCETags,
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'SAB:.CLEAR',
      'SAB:*',
      'SA:.CLEAR',                     # Deprecated
      'SA:*',                          # Deprecated
   ],

   'SKILL' => [
      '000SkillName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'KEYSTAT',
      'USEUNTRAINED',
      'ACHECK',
      'EXCLUSIVE',
      'CLASSES',
      'TYPE',
      'VISIBLE',
      @PRETags,
      @QUALIFYTags,
      'SERVESAS',
      @SOURCETags,
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'SITUATION',
      'DEFINE',
      'DEFINESTAT:*',
      'VFEAT:*',                       # Deprecated 6.05.01
      'AUTO:EQUIP:*',
      'ABILITY',
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:WEAPON:*',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'REQ',
      'SAB:.CLEAR',
      'SAB:*',
      'DESC',
      'TEMPDESC',
      'TEMPBONUS',
      'SA:.CLEAR:*',                   # Deprecated
      'SA:*',                          # Deprecated
   ],

   'SOURCE' => [
      'SOURCELONG',
      'SOURCESHORT',
      'SOURCEWEB',
      'SOURCEDATE',                    # [ 1584007 ] New Tag: SOURCEDATE in PCC
   ],

   'SPELL' => [
      '000SpellName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'TYPE',
      'CLASSES:.CLEARALL',
      'CLASSES:*',
      'DOMAINS',
      'STAT:*',
      'PPCOST',
#     'SPELLPOINTCOST:*',              # Delay implementing this until SPELLPOINTCOST is documented
      'SCHOOL:.CLEAR',
      'SCHOOL:*',
      'SUBSCHOOL',
      'DESCRIPTOR:.CLEAR',
      'DESCRIPTOR:*',
      'VARIANTS:.CLEAR',
      'VARIANTS:*',
      'COMPS',
      'CASTTIME:.CLEAR',
      'CASTTIME:*',
      'RANGE:.CLEAR',
      'RANGE:*',
      'ITEM:*',
      'TARGETAREA:.CLEAR',
      'TARGETAREA:*',
      'DURATION:.CLEAR',
      'DURATION:*',
      'CT',
      'SAVEINFO',
      'SPELLRES',
      'COST',
      'XPCOST',
      @PRETags,
      'DEFINE',
      'DEFINESTAT:*',
#     @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:PPCOST',                  # SPELL has a short list of BONUS tags
      'BONUS:CASTERLEVEL:*',
      'BONUS:CHECKS',
      'BONUS:COMBAT:*',
      'BONUS:DAMAGE:*',
      'BONUS:DR:*',
      'BONUS:FEAT:*',
      'BONUS:HP',
      'BONUS:MISC:*',
      'BONUS:MOVEADD',
      'BONUS:MOVEMULT:*',
      'BONUS:POSTMOVEADD',
      'BONUS:RANGEMULT:*',
      'BONUS:SAVE:*',                  # Global        Replacement for CHECKS
      'BONUS:SIZEMOD',
      'BONUS:SKILL:*',
      'BONUS:STAT:*',
      'BONUS:UDAM:*',
      'BONUS:VAR:*',
      'BONUS:VISION',
      'BONUS:WEAPON:*',
      'BONUS:WEAPONPROF:*',
      'BONUS:WIELDCATEGORY:*',
      'DR:.CLEAR',
      'DR:*',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      @SOURCETags,
      'DESCISPI',
      'DESC:.CLEAR',
      'DESC:*',
      'TEMPDESC',
      'TEMPBONUS',
#     'SPELLPOINTCOST:*',
   ],

   'SUBCLASS' => [
      '000SubClassName',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'HD',
#     'ABB',                           # Invalid for SubClass
      'COST',
      'PROHIBITCOST',
      'CHOICE',
      'SPELLSTAT',
      'SPELLTYPE',
      'LANGAUTO:.CLEAR',               # Deprecated 6.05.01
      'LANGAUTO:*',                    # Deprecated 6.05.01
      'LANGBONUS:.CLEAR',
      'LANGBONUS:*',
      'BONUS:ABILITYPOOL:*',           # SubClass has a short list of BONUS tags
      'BONUS:CASTERLEVEL:*',
      'BONUS:CHECKS:*',
      'BONUS:COMBAT:*',
      'BONUS:DC:*',
      'BONUS:FEAT:*',                  # Deprecated 6.05.01
      'BONUS:HD:*',
      'BONUS:SAVE:*',                  # Global Replacement for CHECKS
      'BONUS:SKILL:*',
      'BONUS:UDAM:*',
      'BONUS:VAR:*',
      'BONUS:WEAPON:*',
      'BONUS:WIELDCATEGORY:*',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:LANGUAGE:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'REMOVE',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'SPELLLIST',
      'KNOWNSPELLSFROMSPECIALTY',
      'PROHIBITED',
      'PROHIBITSPELL:*',
      'STARTSKILLPTS',
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE',
      'DEFINESTAT:*',
      @PRETags,
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'DOMAIN:*',                      # [ 1973526 ] DOMAIN is supported on Class line
      'ADDDOMAINS',
      'UNENCUMBEREDMOVE',
      @SOURCETags,
      'SA:.CLEAR:*',                   # Deprecated
      'SA:*',                          # Deprecated
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
   ],

   'SUBSTITUTIONCLASS' => [
      '000SubstitutionClassName',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
#     'ABB',                           # Invalid for SubClass
      'COST',
      'PROHIBITCOST',
      'CHOICE',
      'SPELLSTAT',
      'SPELLTYPE',
      'BONUS:ABILITYPOOL:*',           # Substitution Class has a short list of BONUS tags
      'BONUS:CASTERLEVEL:*',
      'BONUS:CHECKS:*',
      'BONUS:COMBAT:*',
      'BONUS:DC:*',
      'BONUS:FEAT:*',                  # Deprecated 6.05.01
      'BONUS:HD:*',
      'BONUS:SAVE:*',                  # Global Replacement for CHECKS
      'BONUS:SKILL:*',
      'BONUS:UDAM:*',
      'BONUS:VAR:*',
      'BONUS:WEAPON:*',
      'BONUS:WIELDCATEGORY:*',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:LANGUAGE:*',
      'ADD:SPELLCASTER:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'REMOVE',
      'SPELLLIST',
      'KNOWNSPELLSFROMSPECIALTY',
      'PROHIBITED',
      'PROHIBITSPELL:*',
      'STARTSKILLPTS',
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE',
      'DEFINESTAT:*',
      @PRETags,
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'ADDDOMAINS',
      'UNENCUMBEREDMOVE',
      @SOURCETags,
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'SA:.CLEAR:*',                   # Deprecated
      'SA:*',                          # Deprecated
   ],

   'SUBCLASSLEVEL' => [
      'SUBCLASSLEVEL',
      'REPEATLEVEL',
      @QUALIFYTags,
      'SERVESAS',
      'UATT',
      'UDAM',
      'UMULT',
      'ADD:SPELLCASTER:*',
      'SPELLKNOWN:CLASS:*',
      'SPELLLEVEL:CLASS:*',
      'CAST',
      'KNOWN',
      'SPECIALTYKNOWN',
      'KNOWNSPELLS',
      'PROHIBITSPELL:*',
      'VISION',
      'SR',
      'DR',
      'DOMAIN:*',
      'SA:.CLEAR:*',                   # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
      'SAB:.CLEAR',
      'SAB:*',
      'BONUS:HD:*',                    # Class Lines
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:WEAPON:*',
      'HITDIE',
      'ABILITY:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      'CSKILL:.CLEAR',
      'CSKILL:*',
      'CCSKILL:.CLEAR',
      'CCSKILL:*',
      'LANGAUTO.CLEAR',                # Deprecated - Remove 6.0
      'LANGAUTO:*',                    # Deprecated - Remove 6.0
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:LANGUAGE:*',
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'EXCHANGELEVEL',
      'SPELLS:*',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'VFEAT:*',                       # Deprecated 6.05.01
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'CHANGEPROF:*',
      'REMOVE',
      'ADDDOMAINS',
      'WEAPONBONUS',
      'FEATAUTO:.CLEAR',               # Deprecated 6.05.01
      'FEATAUTO:*',                    # Deprecated 6.05.01
      'SUBCLASS',
      'SPELLLIST',
      'NATURALATTACKS',
      'UNENCUMBEREDMOVE',
      'SPECIALS',                      # Deprecated
      'SPELL',                         # Deprecated
   ],

   'SUBSTITUTIONLEVEL' => [
      'SUBSTITUTIONLEVEL',
      'REPEATLEVEL',
      @QUALIFYTags,
      'SERVESAS',
      'HD',
      'STARTSKILLPTS',
      'UATT',
      'UDAM',
      'UMULT',
      'ADD:SPELLCASTER',
      'SPELLKNOWN:CLASS:*',
      'SPELLLEVEL:CLASS:*',
      'CAST',
      'KNOWN',
      'SPECIALTYKNOWN',
      'KNOWNSPELLS',
      'PROHIBITSPELL:*',
      'VISION',
      'SR',
      'DR',
      'DOMAIN',
      'SA:.CLEAR:*',                   # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
      'SAB:.CLEAR',
      'SAB:*',
      'BONUS:HD:*',                    # Class Lines
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUS:WEAPON:*',
      'HITDIE',
      'ABILITY:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:LANGUAGE:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'EXCHANGELEVEL',
      'SPECIALS',                      # Deprecated 6.05.01
      'SPELL',
      'SPELLS:*',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      'VFEAT:*',                       # Deprecated 6.05.01
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'CHANGEPROF:*',
      'REMOVE',
      'ADDDOMAINS',
      'WEAPONBONUS',
      'FEATAUTO:.CLEAR',               # Deprecated 6.05.01
      'FEATAUTO:*',                    # Deprecated 6.05.01
      'SUBCLASS',
      'SPELLLIST',
      'NATURALATTACKS',
      'UNENCUMBEREDMOVE',
      'LANGAUTO.CLEAR',                # Deprecated - Remove 6.0
      'LANGAUTO:*',                    # Deprecated - Remove 6.0
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
   ],

   'SWITCHRACE' => [
      'SWITCHRACE',
   ],

   'TEMPLATE' => [
      '000TemplateName',
      'SORTKEY',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'HITDIE',
      'HITDICESIZE',
      'CR',
      'SIZE',
      'FACE',
      'REACH',
      'LEGS',
      'HANDS',
      'GENDER',
      'VISIBLE',
      'REMOVEABLE',
      'DR:*',
      'LEVELADJUSTMENT',
      'TEMPLATE:.CLEAR',
      'TEMPLATE:*',
      @SOURCETags,
      'SA:.CLEAR',                     # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
      'SAB:.CLEAR',
      'SAB:*',
      'DEFINE:*',
      'DEFINESTAT:*',
      'LEVEL:*',
      @PRETags,
      @QUALIFYTags,
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'BONUSFEATS',                    # Template Bonus
      'BONUS:MONSKILLPTS',             # Template Bonus
      'BONUSSKILLPOINTS',              # Template Bonus
      'BONUS:WEAPON:*',
      'NONPP',
      'STACK',
      'MULT',
      'CHOOSE',
      'SELECT',
      'CSKILL:.CLEAR',
      'CSKILL',
      'CCSKILL:.CLEAR',
      'CCSKILL',
      'ADD:.CLEAR',
      'ADD:*',
      'ADD:ABILITY:*',
      'ADD:CLASSSKILLS',
      'ADD:EQUIP:*',
      'ADD:FEAT:*',                    # Deprecated 6.05.01
      'ADD:LANGUAGE:*',
      'ADD:TEMPLATE:*',
      'ADD:VFEAT:*',                   # Deprecated 6.05.01
      'FAVOREDCLASS',
      'ABILITY:*',
      'FEAT:*',                        # Deprecated 6.05.01
      'VFEAT:*',                       # Deprecated 6.05.01
      'AUTO:ARMORPROF:*',
      'AUTO:EQUIP:*',
      'AUTO:FEAT:*',                   # Deprecated 6.05.01
      'AUTO:LANG:*',
      'AUTO:SHIELDPROF:*',
      'AUTO:WEAPONPROF:*',
      'REMOVE:*',
      'CHANGEPROF:*',
      'KIT',
      'LANGBONUS:.CLEAR',
      'LANGBONUS:*',
      'MOVE',
      'MOVEA',                         # Deprecated 6.05.01
      'MOVECLONE',
      'REGION',
      'SUBREGION',
      'REMOVABLE',
      'SR:*',
      'SUBRACE',
      'RACETYPE',
      'RACESUBTYPE:.REMOVE',
      'RACESUBTYPE:*',
      'TYPE',
      'ADDLEVEL',
      'VISION',
      'HD:*',
      'WEAPONBONUS',
      'GENDERLOCK',
      'SPELLS:*',
      'SPELLKNOWN:CLASS:*',
      'SPELLKNOWN:DOMAIN:*',
      'SPELLLEVEL:CLASS:*',
      'SPELLLEVEL:DOMAIN:*',
      'ADD:SPELLCASTER',
      'NATURALATTACKS:*',
      'UNENCUMBEREDMOVE',
      'COMPANIONLIST',
      'FOLLOWERS',
      'DESC:.CLEAR',
      'DESC:*',
      'TEMPDESC',
      'TEMPBONUS',
      'SPELL:*',                       # Deprecated 5.x.x - Remove 6.0 - use SPELLS
      'ADD:SPECIAL',                   # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats 0r Abilities.
#     'HEIGHT',                        # Deprecated
      'LANGAUTO:.CLEAR',               # Deprecated - 6.0
      'LANGAUTO:*',                    # Deprecated - 6.0
#     'WEIGHT',                        # Deprecated
   ],

   'WEAPONPROF' => [
      '000WeaponName',
      'KEY',                           # [ 1695877 ] KEY tag is global
      'NAMEISPI',
      'OUTPUTNAME',
      'TYPE',
      'HANDS',
      @PRETags,
      @SOURCETags,
      @globalBONUSTags,              # [ 1956340 ] Centralize global BONUS tags
      'SAB:.CLEAR',
      'SAB:*',
      'SA:.CLEAR',                     # Deprecated 6.05.01
      'SA:*',                          # Deprecated 6.05.01
   ],

   'VARIABLE' => [
      '000VariableName',
      'EXPLANATION',
   ],

   'DATACONTROL' => [
      '000DatacontrolName',
      'DATAFORMAT',
      'REQUIRED',
      'SELECTABLE',
      'VISIBLE',
      'DISPLAYNAME',
      'EXPLANATION',
   ],

   'GLOBALMOD' => [
      '000GlobalmonName',
      'EXPLANATION',
   ],

   'ALIGNMENT' => [
      '000AlignmentName',
      'SORTKEY',
      'ABB',
      'KEY',
      'VALIDFORDEITY',
      'VALIDFORFOLLOWER',
   ],

   'STAT' => [
      '000StatName',
      'SORTKEY',
      'ABB',
      'KEY',
      'STATMOD',
      'DEFINE:MAXLEVELSTAT',
      'DEFINE',
      @globalBONUSTags,
      'ABILITY',
   ],

   'SAVE' => [
      '000SaveName',
      'SORTKEY',
      'KEY',
      @globalBONUSTags,
   ],

);

#################################################################
######################## Conversion #############################
# Tags that must be seen as valid to allow conversion.

if (Pretty::Options::isConversionActive('ALL:Convert ADD:SA to ADD:SAB')) {
   push @{ $master_order{'CLASS'} },         'ADD:SA';
   push @{ $master_order{'CLASS Level'} },   'ADD:SA';
   push @{ $master_order{'COMPANIONMOD'} },  'ADD:SA';
   push @{ $master_order{'DEITY'} },         'ADD:SA';
   push @{ $master_order{'DOMAIN'} },        'ADD:SA';
   push @{ $master_order{'EQUIPMENT'} },     'ADD:SA';
   push @{ $master_order{'EQUIPMOD'} },      'ADD:SA';
   push @{ $master_order{'FEAT'} },          'ADD:SA';
   push @{ $master_order{'RACE'} },          'ADD:SA';
   push @{ $master_order{'SKILL'} },         'ADD:SA';
   push @{ $master_order{'SUBCLASSLEVEL'} }, 'ADD:SA';
   push @{ $master_order{'TEMPLATE'} },      'ADD:SA';
   push @{ $master_order{'WEAPONPROF'} },    'ADD:SA';
}
if (Pretty::Options::isConversionActive('EQUIP: ALTCRITICAL to ALTCRITMULT')) {
   push @{ $master_order{'EQUIPMENT'} }, 'ALTCRITICAL';
}

if (Pretty::Options::isConversionActive('BIOSET:generate the new files')) {
   push @{ $master_order{'RACE'} }, 'AGE', 'HEIGHT', 'WEIGHT';
}

if (Pretty::Options::isConversionActive('EQUIPMENT: remove ATTACKS')) {
   push @{ $master_order{'EQUIPMENT'} }, 'ATTACKS';
}

if (Pretty::Options::isConversionActive('PCC:GAME to GAMEMODE')) {
   push @{ $master_order{'PCC'} }, 'GAME';
}

if (Pretty::Options::isConversionActive('ALL:BONUS:MOVE conversion')) {
   push @{ $master_order{'CLASS'} },         'BONUS:MOVE:*';
   push @{ $master_order{'CLASS Level'} },   'BONUS:MOVE:*';
   push @{ $master_order{'COMPANIONMOD'} },  'BONUS:MOVE:*';
   push @{ $master_order{'DEITY'} },         'BONUS:MOVE:*';
   push @{ $master_order{'DOMAIN'} },        'BONUS:MOVE:*';
   push @{ $master_order{'EQUIPMENT'} },     'BONUS:MOVE:*';
   push @{ $master_order{'EQUIPMOD'} },      'BONUS:MOVE:*';
   push @{ $master_order{'FEAT'} },          'BONUS:MOVE:*';
   push @{ $master_order{'RACE'} },          'BONUS:MOVE:*';
   push @{ $master_order{'SKILL'} },         'BONUS:MOVE:*';
   push @{ $master_order{'SUBCLASSLEVEL'} }, 'BONUS:MOVE:*';
   push @{ $master_order{'TEMPLATE'} },      'BONUS:MOVE:*';
   push @{ $master_order{'WEAPONPROF'} },    'BONUS:MOVE:*';
}

if (Pretty::Options::isConversionActive('WEAPONPROF:No more SIZE')) {
   push @{ $master_order{'WEAPONPROF'} }, 'SIZE';
}

if (Pretty::Options::isConversionActive('EQUIP:no more MOVE')) {
   push @{ $master_order{'EQUIPMENT'} }, 'MOVE';
}

#   vvvvvv This one is disactivated
if (0 && Pretty::Options::isConversionActive('ALL:Convert SPELL to SPELLS')) {
        push @{ $master_order{'CLASS Level'} },    'SPELL:*';
        push @{ $master_order{'DOMAIN'} },         'SPELL:*';
        push @{ $master_order{'EQUIPMOD'} },       'SPELL:*';
        push @{ $master_order{'SUBCLASSLEVEL'} },  'SPELL:*';
}

#   vvvvvv This one is disactivated
if (0 && Pretty::Options::isConversionActive('TEMPLATE:HITDICESIZE to HITDIE')) {
        push @{ $master_order{'TEMPLATE'} }, 'HITDICESIZE';
}




# FILETYPE_parse
# --------------
#
# This function uses the information of masterFileType to
# identify the current line type and parse it.
#
# Parameters: $file_type      = The type of the file has defined by the .PCC file
#             $lines_ref      = Reference to an array containing all the lines of the file
#             $file_for_error = File name to use with log

sub FILETYPE_parse {
   my ($file_type, $lines_ref, $file_for_error, $logging) = @_;

   # Working variables

   my $current_linetype = "";
   my $last_main_line  = -1;


   my @newlines;   # New line generated

   # Phase I - Split line in tokens and parse
   #               the tokens

   my $line_for_error = 1;
   LINE:
   for my $line (@ {$lines_ref} ) {

      # Start by replacing the smart quotes and other similar characters, if necessary.
      # In either case, make a copy of the line to work on.
      # my $new_line = Pretty::Options::isConversionActive('ALL:Fix Common Extended ASCII')
      #                   ? Pretty::Conversions::convertEntities($line) : 
      #                   : $line;

      # Remove spaces at the end of the line
      my $new_line =~ s/\s+$//;

      # Remove spaces at the begining of the line
      $new_line =~ s/^\s+//;

      # If this line is empty, a comment, or we can't determine its type, we
      # push it onto @newlines as is. 
      my ($pushAsIs, $current_entity, $line_info) = (0);

      if ( length($new_line) == 0 || $new_line =~ /^\#/ ) {
         $pushAsIs = 1;
      } else {
         ($current_entity, $line_info) = _getLineType($file_type, $new_line);

         # If we didn't find a line type
         if (not defined $current_entity ) {
            $pushAsIs = 1;

            $logging->warning(
               qq(Can\'t find the line type for "$new_line"),
               $file_for_error,
               $line_for_error
            );
         }
      }

      # We push the line as is.
      if ($pushAsIs) {
         push @newlines,
         [
            $current_linetype,
            $new_line,
            $last_main_line,
            undef,
            undef,
         ];
         next LINE;
      }

                # What type of line is it?
                $current_linetype = $line_info->{Linetype};
                if ( $line_info->{Mode} == MAIN ) {
                        $last_main_line = $line_for_error - 1;
                }
                elsif ( $line_info->{Mode} == SUB ) {
                        $logging->warning(
                                qq{SUB line "$current_linetype" is not preceded by a MAIN line},
                                $file_for_error,
                                $line_for_error
                        ) if $last_main_line == -1;
                }
                elsif ( $line_info->{Mode} == SINGLE ) {
                        $last_main_line = -1;
                }
                else {
                        die qq(Invalid type for $current_linetype);
                }

                # Identify the deprecated tags.
                &scan_for_deprecated_tags( $new_line, $current_linetype, $file_for_error, $line_for_error );

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
                for my $column ( @{ $columnWithNoTag{$current_linetype} } ) {
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

                        my $current_token = shift @tokens;
                        $line_tokens{$column} = [$current_token];

                        # Statistic gathering
                        $count_tags{"Valid"}{"Total"}{$column}++;
                        $count_tags{"Valid"}{$current_linetype}{$column}++;

                        # Are we dealing with a .MOD, .FORGET or .COPY type of tag?
                        if ( index( $column, '000' ) == 0 ) {
                                my $check_mod = $line_info->{RegExIsMod} || qr{ \A (.*) [.] (MOD|FORGET|COPY=[^\t]+) }xmsi;

                                if ( $line_info->{ValidateKeep} ) {
                                        if ( my ($entity_name, $mod_part) = ($current_token =~ $check_mod) ) {

                                                # We keep track of the .MOD type tags to
                                                # later validate if they are valid
                                                push @{ $referer{$current_linetype}{$entity_name} },
                                                        [ $current_token, $file_for_error, $line_for_error ]
                                                        if getOption('xcheck');

                                                # Special case for .COPY=<new name>
                                                # <new name> is a valid entity
                                                if ( my ($new_name) = ( $mod_part =~ / \A COPY= (.*) /xmsi ) ) {
                                                        $valid_entities{$current_linetype}{$new_name}++;
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
                                                        my $entry = $current_token;
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
                                                                                qq(Cannot find the $current_linetype name),
                                                                                $file_for_error,
                                                                                $line_for_error
                                                                        );
                                                                }
                                                        }
                                                        $valid_entities{$current_linetype}{$entry}++;

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
                        my $key = parse_tag($token, $current_linetype, $file_for_error, $line_for_error);

                        if ($key) {
                                if ( exists $line_tokens{$key} && !exists $master_mult{$current_linetype}{$key} ) {
                                        $logging->notice(
                                                qq{The tag "$key" should not be used more than once on the same $current_linetype line.\n},
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
                        $current_linetype,
                        \%line_tokens,
                        $last_main_line,
                        $current_entity,
                        $line_info,
                ];

                ############################################################
                ######################## Conversion ########################
                # We manipulate the tags for the line here
                # This function call will parse individual lines, which will
                # in turn parse the tags within the lines.

                additionnal_line_parsing(\%line_tokens,
                                                $current_linetype,
                                                $file_for_error,
                                                $line_for_error,
                                                $newline
                );

                ############################################################
                # Validate the line
                validate_line(\%line_tokens, $current_linetype, $file_for_error, $line_for_error)
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
                my $current_linetype = $newlines[$line_index][0];
                my $line_tokens = $newlines[$line_index][1];
                my $next_linetype;
                $next_linetype = $newlines[ $line_index + 1 ][0]
                if $line_index + 1 < @newlines;

                # A header line either begins with the current line_type header
                # or the next line header.
                #
                # Only comment -- $line_token is not a hash --  can be header lines
                if ( ref($line_tokens) ne 'HASH' ) {

                        # We are on a comment line, we need to find the
                        # current and the next line header.

                        # current header
                        my $this_header =
                                $current_linetype
                                ? get_header( $master_order{$current_linetype}[0], $current_linetype )
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
        #  my ($current_linetype, $line_tokens, $main_linetype,
        #       $current_entity, $line_info) = @$line_ref;
        #
        #  if(ref($line_tokens) ne 'HASH')
        #  {
        #
        #       # Header begins with the line type header.
        #       my $this_header = $current_linetype
        #                               ? get_header($master_order{$current_linetype}[0],$file_type)
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
                my ($current_linetype, $line_tokens, $last_main_line,
                $current_entity,   $line_info
                )
                = @$line_ref;
                my $newline = "";

                # If the separator is not a tab, with just join the
                # tag in order
                my $sep = $line_info->{Sep} || "\t";
                if ( $sep ne "\t" ) {

                # First, the tag known in master_order
                for my $tag ( @{ $master_order{$current_linetype} } ) {
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
                        for my $tag ( @{ $master_order{$current_linetype} } ) {
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
                        # the current line
                        TAG_NAME:
                        for my $tag ( @{ $master_order{$current_linetype} } ) {

                                # We skip the tag is not present
                                next TAG_NAME if !exists $col_length{$tag};

                                # The first tag is the line entity and most be kept
                                $line_entity = $line_tokens->{$tag}[0] unless $line_entity;

                                # What is the length of the column?
                                my $header_text   = get_header( $tag, $current_linetype );
                                my $header_length = mylength($header_text);
                                my $col_length  =
                                        $header_length > $col_length{$tag}
                                ? $header_length
                                : $col_length{$tag};

                                # Round the col_length up to the next tab
                                $col_length = TABSIZE * ( int( $col_length / TABSIZE ) + 1 );

                                # The header
                                my $tab_to_add = int( ( $col_length - $header_length ) / TABSIZE )
                                + ( ( $col_length - $header_length ) % TABSIZE ? 1 : 0 );
                                $header_line .= $header_text . $sep x $tab_to_add;

                                # The line
                                $tab_to_add = int( ( $col_length - $col_length{$tag} ) / TABSIZE )
                                + ( ( $col_length - $col_length{$tag} ) % TABSIZE ? 1 : 0 );
                                $newline .= join $sep, @{ $line_tokens->{$tag} };
                                $newline .= $sep x $tab_to_add;

                                # Remove the tag we just dealt with
                                delete $line_tokens->{$tag};
                        }

                        # Add the tags that were not in the master_order
                        for my $tag ( sort keys %$line_tokens ) {

                                # What is the length of the column?
                                my $header_text   = get_header( $tag, $current_linetype );
                                my $header_length = mylength($header_text);
                                my $col_length  =
                                        $header_length > $col_length{$tag}
                                ? $header_length
                                : $col_length{$tag};

                                # Round the col_length up to the next tab
                                $col_length = TABSIZE * ( int( $col_length / TABSIZE ) + 1 );

                                # The header
                                my $tab_to_add = int( ( $col_length - $header_length ) / TABSIZE )
                                + ( ( $col_length - $header_length ) % TABSIZE ? 1 : 0 );
                                $header_line .= $header_text . $sep x $tab_to_add;

                                # The line
                                $tab_to_add = int( ( $col_length - $col_length{$tag} ) / TABSIZE )
                                + ( ( $col_length - $col_length{$tag} ) % TABSIZE ? 1 : 0 );
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
                        die "Invalid \%masterFileType options: $file_type:$current_linetype:$mode:$header";
                }
                }
                elsif ( $mode == MAIN ) {
                if ( $format == BLOCK ) {
                        #####################################
                        # All the main lines must be found
                        # up until a different main line type
                        # or a ###Block comment.
                        my @main_lines;
                        my $main_linetype = $current_linetype;

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
                        for my $tag ( @{ $master_order{$current_linetype} } ) {
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
                                        = TABSIZE * ( int( $col_length{$tag} / TABSIZE ) + 1 );

                                # Is the tag present in this line?
                                if ( exists $newlines[$block_line][1]{$tag} ) {
                                        my $current_length = mylength( $newlines[$block_line][1]{$tag} );

                                        my $tab_to_add
                                                = int( ( $col_max_length - $current_length ) / TABSIZE )
                                                + ( ( $col_max_length - $current_length ) % TABSIZE ? 1 : 0 );
                                        $newline .= join $sep, @{ $newlines[$block_line][1]{$tag} };
                                        $newline .= $sep x $tab_to_add;
                                }
                                else {

                                        # We pad with tabs
                                        $newline .= $sep x ( $col_max_length / TABSIZE );
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
                                my $col_max_length = TABSIZE * ( int( $col_length{$tag} / TABSIZE ) + 1 );
                                my $current_header = get_header( $tag, $main_linetype );
                                my $current_length = mylength($current_header);
                                my $tab_to_add  = int( ( $col_max_length - $current_length ) / TABSIZE )
                                        + ( ( $col_max_length - $current_length ) % TABSIZE ? 1 : 0 );
                                $header_line .= $current_header . $sep x $tab_to_add;
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
                        die "Invalid \%masterFileType format: $file_type:$current_linetype:$mode:$header";
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
                        my $sub_linetype = $current_linetype;

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
                                if $newlines[$index][0] eq $current_linetype;
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
                        for my $tag ( @{ $master_order{$current_linetype} } ) {
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
                                                = TABSIZE * ( int( $col_length{$tag} / TABSIZE ) + 1 );

                                        # Is the tag present in this line?
                                        if ( exists $newlines[$block_line][1]{$tag} ) {
                                                my $current_length = mylength( $newlines[$block_line][1]{$tag} );

                                                my $tab_to_add
                                                = int( ( $col_max_length - $current_length ) / TABSIZE )
                                                + ( ( $col_max_length - $current_length ) % TABSIZE ? 1 : 0 );
                                                $newline .= join $sep, @{ $newlines[$block_line][1]{$tag} };
                                                $newline .= $sep x $tab_to_add;
                                        }
                                        else {

                                                # We pad with tabs
                                                $newline .= $sep x ( $col_max_length / TABSIZE );
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
                                                = TABSIZE * ( int( $col_length{$tag} / TABSIZE ) + 1 );
                                                my $current_length = mylength( $newlines[$block_line][1]{$tag} );

                                                $tab_to_add
                                                = int( ( $col_max_length - $current_length ) / TABSIZE )
                                                + ( ( $col_max_length - $current_length ) % TABSIZE ? 1 : 0 );

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
                                        = TABSIZE * ( int( $col_length{$tag} / TABSIZE ) + 1 );
                                my $current_header = get_header( $tag, $sub_linetype );
                                my $current_length = mylength($current_header);
                                my $tab_to_add  = int( ( $col_max_length - $current_length ) / TABSIZE )
                                        + ( ( $col_max_length - $current_length ) % TABSIZE ? 1 : 0 );
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
                                die "Invalid \%masterFileType: $current_linetype:$mode:$format:$header";
                        }
                }
                else {
                        die "Invalid \%masterFileType: $current_linetype:$mode:$format:$header";
                }
                }
                else {
                die "Invalid \%masterFileType mode: $file_type:$current_linetype:$mode";
                }

             }

             # If there are header lines remaining, we keep the old value
             for (@newlines) {
                $_ = $_->[1] if ref($_) eq 'ARRAY' && $_->[0] eq 'HEADER';
             }

             return \@newlines;

}

=head2 _getLineType

   Search using the master file type, to find out what kind of line we have.

   The Regex used to identify the line extracts the tag, this is returned,
   along with the entry from the master file type that will allow further
   processing of this line type.

=cut

sub _getLineType {

   my ($fileType, $line) = @_;
   
   my ($current_entity, $line_info);

   # Find the line type
   LINE_SPEC:
   for my $line_spec ( @{ $masterFileType{$fileType} } ) {
      if ( $line =~ $line_spec->{RegEx} ) {

         # Found it !!!
         $line_info     = $line_spec;
         $current_entity = $1;
         last LINE_SPEC;
      }
   }

   return ($current_entity, $line_info);
}

1;

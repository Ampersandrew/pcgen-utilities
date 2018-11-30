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


our $logger;            # The singleton logger.

our %count_tags;        # Will hold the number of each tag found (by linetype)

our %missing_headers;   # Will hold the tags that do not have defined headers for each linetype.

our %valid_entities;    # Will hold the entries that may be refered to

our %token_FACT_tag = map { $_ => 1 } (
   'FACT:Abb',
   'FACT:AppliedName',
   'FACT:BaseSize',
   'FACT:ClassType',
   'FACT:SpellType',
   'FACT:Symbol',
   'FACT:Worshippers',
   'FACT:Title',
   'FACT:Appearance',
   'FACT:RateOfFire',
);

our %token_FACTSET_tag = map { $_ => 1 } (
   'FACTSET:Pantheon',
   'FACTSET:Race',
);



# The SOURCE line is use in nearly all file types
our %SourceLineDef = (
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
our %writefiletype = (
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

# Hash used by validatePreTag to verify if a PRExxx tag exists
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

# Working variables
our %columnWithNoTag = (

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
our @globalBONUSTags = (
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

=head2 getLogger

   Get the logger singleton.

=cut

sub getLogger {

   if (not defined $logger) {
      $logger = Pretty::logger->new(warningLevel => getOption('warninglevel'));
   }

   return $logger;
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




# FILETYPE_parse
# --------------
#
# This function uses the information of masterFileType to
# identify the current line type and parse it.
#
# Parameters: $fileType      = The type of the file has defined by the .PCC file
#             $linesRef      = Reference to an array containing all the lines of the file
#             $fileForError = File name to use with log

sub FILETYPE_parse {
   my ($fileType, $linesRef, $fileForError) = @_;

   # Make sure the logger is initialised
   getLogger();

   # Working variables

   my $currentLinetype = "";
   my $lastMainLine  = -1;


   my @newlines;   # New line generated

   # Phase I - Split line in tokens and parse
   #               the tokens

   my $lineForError = 1;
   LINE:
   for my $line (@ {$linesRef} ) {

      # Start by replacing the smart quotes and other similar characters, if necessary.
      # In either case, make a copy of the line to work on.
      # my $newLine = Pretty::Options::isConversionActive('ALL:Fix Common Extended ASCII')
      #                   ? Pretty::Conversions::convertEntities($line) : 
      #                   : $line;

      # Remove spaces at the end of the line
      my $newLine =~ s/\s+$//;

      # Remove spaces at the begining of the line
      $newLine =~ s/^\s+//;

      # If this line is empty, a comment, or we can't determine its type, we
      # push it onto @newlines as is. 
      my ($pushAsIs, $current_entity, $line_info) = (0);

      if ( length($newLine) == 0 || $newLine =~ /^\#/ ) {
         $pushAsIs = 1;
      } else {
         ($current_entity, $line_info) = _getLineType($fileType, $newLine);

         # If we didn't find a line type
         if (not defined $current_entity ) {
            $pushAsIs = 1;

            $logger->warning(
               qq(Can\'t find the line type for "$newLine"),
               $fileForError,
               $lineForError
            );
         }
      }

      # We push the line as is.
      if ($pushAsIs) {
         push @newlines,
         [
            $currentLinetype,
            $newLine,
            $lastMainLine,
            undef,
            undef,
         ];
         next LINE;
      }

                # What type of line is it?
                $currentLinetype = $line_info->{Linetype};
                if ( $line_info->{Mode} == MAIN ) {
                        $lastMainLine = $lineForError - 1;
                }
                elsif ( $line_info->{Mode} == SUB ) {
                        $logger->warning(
                                qq{SUB line "$currentLinetype" is not preceded by a MAIN line},
                                $fileForError,
                                $lineForError
                        ) if $lastMainLine == -1;
                }
                elsif ( $line_info->{Mode} == SINGLE ) {
                        $lastMainLine = -1;
                }
                else {
                        die qq(Invalid type for $currentLinetype);
                }

                # Identify the deprecated tags.
                &scan_for_deprecated_tags( $newLine, $currentLinetype, $fileForError, $lineForError );

                # Split the line in tokens
                my %line_tokens;

                # By default, the tab character is used
                my $sep = $line_info->{SepRegEx} || qr(\t+);

                # We split the tokens, strip the spaces and silently remove the empty tags
                # (empty tokens are the result of [tab][space][tab] type of chracter
                # sequences).
                # [ 975999 ] [tab][space][tab] breaks prettylst
                my @tokens = grep { $_ ne q{} } map { s{ \A \s* | \s* \z }{}xmsg; $_ } split $sep, $newLine;

                #First, we deal with the tag-less columns
                COLUMN:
                for my $column ( @{ $columnWithNoTag{$currentLinetype} } ) {
                        last COLUMN if ( scalar @tokens == 0 );

                        # We remove the space before and after the token
                        #       $tokens[0] =~ s/\s+$//;
                        #       $tokens[0] =~ s/^\s+//;

                        # We remove the enclosing quotes if any
                        $logger->warning(
                                qq{Removing quotes around the '$tokens[0]' tag},
                                $fileForError,
                                $lineForError
                        ) if $tokens[0] =~ s/^"(.*)"$/$1/;

                        my $current_token = shift @tokens;
                        $line_tokens{$column} = [$current_token];

                        # Statistic gathering
                        $count_tags{"Valid"}{"Total"}{$column}++;
                        $count_tags{"Valid"}{$currentLinetype}{$column}++;

                        # Are we dealing with a .MOD, .FORGET or .COPY type of tag?
                        if ( index( $column, '000' ) == 0 ) {
                                my $check_mod = $line_info->{RegExIsMod} || qr{ \A (.*) [.] (MOD|FORGET|COPY=[^\t]+) }xmsi;

                                if ( $line_info->{ValidateKeep} ) {
                                        if ( my ($entity_name, $mod_part) = ($current_token =~ $check_mod) ) {

                                                # We keep track of the .MOD type tags to
                                                # later validate if they are valid
                                                push @{ $referer{$currentLinetype}{$entity_name} },
                                                        [ $current_token, $fileForError, $lineForError ]
                                                        if getOption('xcheck');

                                                # Special case for .COPY=<new name>
                                                # <new name> is a valid entity
                                                if ( my ($new_name) = ( $mod_part =~ / \A COPY= (.*) /xmsi ) ) {
                                                        $valid_entities{$currentLinetype}{$new_name}++;
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
                                                                                        $fileForError,
                                                                                        $lineForError,
                                                                                        &{ $line_info->{GetRefList} }($entry)
                                                                                );
                                                                        }
                                                                }
                                                                else {
                                                                        $logger->warning(
                                                                                qq(Cannot find the $currentLinetype name),
                                                                                $fileForError,
                                                                                $lineForError
                                                                        );
                                                                }
                                                        }
                                                        $valid_entities{$currentLinetype}{$entry}++;

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
                        my $key = parse_tag($token, $currentLinetype, $fileForError, $lineForError);

                        if ($key) {
                           Pretty::Data::isMultOk($currentLinetype, $key)
                                if (exists $line_tokens{$key} && ! Pretty::Data::isMultOk($currentLinetype, $key)) {
                                        $logger->notice(
                                                qq{The tag "$key" should not be used more than once on the same $currentLinetype line.\n},
                                                $fileForError,
                                                $lineForError
                                        );
                                }

                        $line_tokens{$key}
                                = exists $line_tokens{$key} ? [ @{ $line_tokens{$key} }, $token ] : [$token];
                        }
                        else {
                                $logger->warning( "No tags in \"$token\"\n", $fileForError, $lineForError );
                                $line_tokens{$token} = $token;
                        }
                }

                my $newline = [
                        $currentLinetype,
                        \%line_tokens,
                        $lastMainLine,
                        $current_entity,
                        $line_info,
                ];

                ############################################################
                ######################## Conversion ########################
                # We manipulate the tags for the line here
                # This function call will parse individual lines, which will
                # in turn parse the tags within the lines.

                additionnal_line_parsing(\%line_tokens,
                                                $currentLinetype,
                                                $fileForError,
                                                $lineForError,
                                                $newline
                );

                ############################################################
                # Validate the line
                validate_line(\%line_tokens, $currentLinetype, $fileForError, $lineForError) if getOption('xcheck');

                ############################################################
                # .CLEAR order verification
                check_clear_tag_order(\%line_tokens, $fileForError, $lineForError);

                #Last, we put the tokens and other line info in the @newlines array
                push @newlines, $newline;

        }
        continue { $lineForError++ }

        #####################################################
        #####################################################
        # We find all the header lines
        for ( my $line_index = 0; $line_index < @newlines; $line_index++ ) {
                my $currentLinetype = $newlines[$line_index][0];
                my $line_tokens = $newlines[$line_index][1];
                my $nextLineType;
                $nextLineType = $newlines[ $line_index + 1 ][0] if $line_index + 1 < @newlines;
                
                # A header line either begins with the current line_type header
                # or the next line header.
                #
                # Only comment -- $line_token is not a hash --  can be header lines
                if ( ref($line_tokens) ne 'HASH' ) {

                   # We are on a comment line, we need to find the current and
                   # the next line header.

                   # current header
                   my $currentTag  = getFirstTagForType($currentLinetype);
                   my $this_header = $currentLinetype ? Pretty::Data::getHeader( $currentTag, $currentLinetype ) : "";

                   # Next line header
                   my $nextTag     = getFirstTagForType($nextLinetype);
                   my $next_header = $nextLineType ? Pretty::Data::getHeader( $nextTag, $nextLineType ) : "";

                   if (   ( $this_header && index( $line_tokens, $this_header ) == 0 )
                      || ( $next_header && index( $line_tokens, $next_header ) == 0 ) )
                   {

                      # It is a header, let's tag it as such.
                      $newlines[$line_index] = [ 'HEADER', $line_tokens, ];
                   }
                   else {

                      # It is just a comment, we won't botter with it ever again.
                      $newlines[$line_index] = $line_tokens;
                   }
                }
             }

        #################################################################
        ######################## Conversion #############################
        # We manipulate the tags for the whole file here

        additionnal_file_parsing(\@newlines, $fileType, $fileForError);

        ##################################################
        ##################################################
        # Phase II - Reformating the lines

        # No reformating needed?
        return $linesRef unless getOption('outputpath') && $writefiletype{$fileType};

        # Now on to all the non header lines.
        CORE_LINE:
        for ( my $line_index = 0; $line_index < @newlines; $line_index++ ) {

                # We skip the text lines and the header lines
                next CORE_LINE if ref( $newlines[$line_index] ) ne 'ARRAY' || $newlines[$line_index][0] eq 'HEADER';

                my $line_ref = $newlines[$line_index];
                my ($currentLinetype, $line_tokens, $lastMainLine, $current_entity, $line_info) = @$line_ref;
                my $newline = "";

                # If the separator is not a tab, with just join the
                # tag in order
                my $sep = $line_info->{Sep} || "\t";
                if ( $sep ne "\t" ) {

                   # First, the tag known in masterOrder
                   for my $tag (getMasterOrderEntry($currentLinetype)) {
                      if ( exists $line_tokens->{$tag} ) {
                         $newline .= join $sep, @{ $line_tokens->{$tag} };
                         $newline .= $sep;
                         delete $line_tokens->{$tag};
                      }
                   }

                # The remaining tag are not in the masterOrder list
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

                        # First, the tag known in masterOrder
                        for my $tag (getMasterOrderEntry($currentLinetype)) {
                           if ( exists $line_tokens->{$tag} ) {
                              $newline .= join $sep, @{ $line_tokens->{$tag} };
                              $newline .= $sep;
                              delete $line_tokens->{$tag};
                           }
                        }

                        # The remaining tag are not in the masterOrder list
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
                        for my $tag (getMasterOrderEntry($currentLinetype)) {

                                # We skip the tag is not present
                                next TAG_NAME if !exists $col_length{$tag};

                                # The first tag is the line entity and most be kept
                                $line_entity = $line_tokens->{$tag}[0] unless $line_entity;

                                # What is the length of the column?
                                my $header_text   = Pretty::Data::getHeader( $tag, $currentLinetype );
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

                        # Add the tags that were not in the masterOrder
                        for my $tag ( sort keys %$line_tokens ) {

                                # What is the length of the column?
                                my $header_text   = Pretty::Data::getHeader( $tag, $currentLinetype );
                                my $header_length = mylength($header_text);
                                my $col_length  = $header_length > $col_length{$tag} ? $header_length : $col_length{$tag};

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
                        die "Invalid \%masterFileType options: $fileType:$currentLinetype:$mode:$header";
                }
                }
                elsif ( $mode == MAIN ) {
                if ( $format == BLOCK ) {
                        #####################################
                        # All the main lines must be found
                        # up until a different main line type
                        # or a ###Block comment.
                        my @main_lines;
                        my $main_linetype = $currentLinetype;

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
                                my $length = mylength( Pretty::Data::getHeader( $tag, $fileType ) );

                                $col_length{$tag} = $length if $length > $col_length{$tag};
                                }
                        }

                        #####################################
                        # Find the columns order
                        my %seen;
                        my @col_order;

                        # First, the columns included in masterOrder
                        for my $tag (getMasterOrderEntry($currentLinetype)) {
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
                                my $current_header = Pretty::Data::getHeader( $tag, $main_linetype );
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
                        die "Invalid \%masterFileType format: $fileType:$currentLinetype:$mode:$header";
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
                        my $begin_block  = $lastMainLine;
                        my $sub_linetype = $currentLinetype;

                        BLOCK_LINE:
                        for ( my $index = $line_index; $index < @newlines; $index++ ) {

                                # If the lastMainLine change or
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
                                if $newlines[$index][0] eq $currentLinetype;
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
                                my $length = mylength( Pretty::Data::getHeader( $tag, $fileType ) );

                                $col_length{$tag} = $length if $length > $col_length{$tag};
                                }
                        }

                        #####################################
                        # Find the columns order
                        my %seen;
                        my @col_order;

                        # First, the columns included in masterOrder
                        for my $tag (getMasterOrderEntry($currentLinetype)) {
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
                                my $current_header = Pretty::Data::getHeader( $tag, $sub_linetype );
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
                                die "Invalid \%masterFileType: $currentLinetype:$mode:$format:$header";
                        }
                }
                else {
                        die "Invalid \%masterFileType: $currentLinetype:$mode:$format:$header";
                }
                }
                else {
                die "Invalid \%masterFileType mode: $fileType:$currentLinetype:$mode";
                }

             }

             # If there are header lines remaining, we keep the old value
             for (@newlines) {
                $_ = $_->[1] if ref($_) eq 'ARRAY' && $_->[0] eq 'HEADER';
             }

             return \@newlines;

}

###############################################################
# additionnal_line_parsing
# ------------------------
#
# This function does additional parsing on each line once
# they have been seperated in tags.
#
# Most commun use is for addition, conversion or removal of tags.
#
# Paramter: $lineTokens           Ref to a hash containing the tags of the line
#               $filetype               Type for the current file
#               $file_for_error   Name of the current file
#               $line_for_error   Number of the current line
#               $line_info              (Optional) structure generated by FILETYPE_parse
#


=head2  checkEquipment

   Check equipment for consistency of Spellbooks and Containers

   Check to see if the TYPE contains Spellbook, if so, warn if NUMPAGES or
   PAGEUSAGE aren't there.
   
   Then check to see if NUMPAGES or PAGEUSAGE are there, and if they are there,
   but the TYPE doesn't contain Spellbook, warn.

   Also, check containers for CONTAINS and TYPE:Container

=cut

sub checkEquipment {
   my ($lineTokens, $file, $line) = @_;

   if (exists $lineTokens->{'TYPE'} && $lineTokens->{'TYPE'}[0] =~ /Spellbook/) {
      if (not exists $lineTokens->{'NUMPAGES'} || not exists $lineTokens->{'PAGEUSAGE'}) {
         $logger->info(
            qq{You have a Spellbook defined without providing NUMPAGES or PAGEUSAGE.} . 
            qq{ If you want a spellbook of finite capacity, consider adding these tags.},
            $file,
            $line
         );
      }
   } else {

      if (exists $lineTokens->{'NUMPAGES'} ) {
         $logger->warning(
            qq{Invalid use of NUMPAGES tag in a non-spellbook. Remove this tag, or correct the TYPE.},
            $file,
            $line
         );
      }

      if  (exists $lineTokens->{'PAGEUSAGE'}) {
         $logger->warning(
            qq{Invalid use of PAGEUSAGE tag in a non-spellbook. Remove this tag, or correct the TYPE.},
            $file,
            $line
         );
      }
   }

   #  Do the same for Type Container with and without CONTAINS

   if (exists $lineTokens->{'TYPE'} && $lineTokens->{'TYPE'}[0] =~ /Container/) {
      if (not exists $lineTokens->{'CONTAINS'}) {
         $logger->warning(
            qq{Any object with TYPE:Container must also have a CONTAINS tag to be activated.},
            $file,
            $line
         );
      }
   } elsif (exists $lineTokens->{'CONTAINS'}) {
      $logger->warning(
         qq{Any object with CONTAINS must also be TYPE:Container for the CONTAINS tag to be activated.},
         $file,
         $line
      );
   }
}

my $class_name = "";

sub additionnal_line_parsing {
   my ($lineTokens, $filetype, $file, $line, $line_info) = @_;

   if ($filetype eq 'EQUIPMENT') {
      checkEquipment($lineTokens, $file, $line);
   }

   # check if the line contains ADD:SA, convert if necessary
   Pretty::Conversions::convertAddSA($lineTokens, $file, $line);

   # Remove the PREDEFAULTMONSTER tags if that conversion is switched on 
   Pretty::Conversions::removePREDefaultMonster($lineTokens, $filetype, $file, $line);

   # Convert ALTCRITICAL to ALTCRITMULT if that conversion is switched on
   Pretty::Conversions::removeALTCRITICAL($lineTokens, $filetype, $file, $line);
  
   Pretty::Conversions::removeMonsterTags($lineTokens, $filetype, $file, $line,);
   
   # Convert Flollower align if that conversion is switched on 
   Pretty::Conversions::removeFollowAlign($lineTokens, $filetype, $file, $line);
  
   # Convert RACE:TYPE to RACETYPE
   Pretty::Conversions::convertTypeToRacetype($lineTokens, $filetype, $file, $line);

   Pretty::Conversions::convertSourceTags($lineTokens, $file, $line);


   my ($lineTokens, $filetype, $file, $line, $line_info) = @_;

                ##################################################################
                # [ 1070084 ] Convert SPELL to SPELLS
                #
                # Convert the old SPELL tags to the new SPELLS format.
                #
                # Old SPELL:<spellname>|<nb per day>|<spellbook>|...|PRExxx|PRExxx|...
                # New SPELLS:<spellbook>|TIMES=<nb per day>|<spellname>|<spellname>|PRExxx...

                if ( Pretty::Options::isConversionActive('ALL:Convert SPELL to SPELLS')
                && exists $lineTokens->{'SPELL'} )
                {
                my %spellbooks;

                # We parse all the existing SPELL tags
                for my $tag ( @{ $lineTokens->{'SPELL'} } ) {
                        my ( $tag_name, $tag_value ) = ( $tag =~ /^([^:]*):(.*)/ );
                        my @elements = split '\|', $tag_value;
                        my @pretags;

                        while ( $elements[ +@elements - 1 ] =~ /^!?PRE\w*:/ ) {

                                # We keep the PRE tags separated
                                unshift @pretags, pop @elements;
                        }

                        # We classify each triple <spellname>|<nb per day>|<spellbook>
                        while (@elements) {
                                if ( +@elements < 3 ) {
                                $logger->warning(
                                        qq(Wrong number of elements for "$tag_name:$tag_value"),
                                        $file,
                                        $line
                                );
                                }

                                my $spellname = shift @elements;
                                my $times       = +@elements ? shift @elements : 99999;
                                my $pretags   = join '|', @pretags;
                                $pretags = "NONE" unless $pretags;
                                my $spellbook = +@elements ? shift @elements : "MISSING SPELLBOOK";

                                push @{ $spellbooks{$spellbook}{$times}{$pretags} }, $spellname;
                        }

                        $logger->warning(
                                qq{Removing "$tag_name:$tag_value"},
                                $file,
                                $line
                        );
                }

                # We delete the SPELL tags
                delete $lineTokens->{'SPELL'};

                # We add the new SPELLS tags
                for my $spellbook ( sort keys %spellbooks ) {
                        for my $times ( sort keys %{ $spellbooks{$spellbook} } ) {
                                for my $pretags ( sort keys %{ $spellbooks{$spellbook}{$times} } ) {
                                my $spells = "SPELLS:$spellbook|TIMES=$times";

                                for my $spellname ( sort @{ $spellbooks{$spellbook}{$times}{$pretags} } ) {
                                        $spells .= "|$spellname";
                                }

                                $spells .= "|$pretags" unless $pretags eq "NONE";

                                $logger->warning( qq{Adding   "$spells"}, $file, $line );

                                push @{ $lineTokens->{'SPELLS'} }, $spells;
                                }
                        }
                }
                }

                ##################################################################
                # We get rid of all the PREALIGN tags.
                #
                # This is needed by my good CMP friends.

                if ( Pretty::Options::isConversionActive('ALL:CMP remove PREALIGN') ) {
                if ( exists $lineTokens->{'PREALIGN'} ) {
                        my $number = +@{ $lineTokens->{'PREALIGN'} };
                        delete $lineTokens->{'PREALIGN'};
                        $logger->warning(
                                qq{Removing $number PREALIGN tags},
                                $file,
                                $line
                        );
                }

                if ( exists $lineTokens->{'!PREALIGN'} ) {
                        my $number = +@{ $lineTokens->{'!PREALIGN'} };
                        delete $lineTokens->{'!PREALIGN'};
                        $logger->warning(
                                qq{Removing $number !PREALIGN tags},
                                $file,
                                $line
                        );
                }
                }

                ##################################################################
                # Need to fix the STR bonus when the monster have only one
                # Natural Attack (STR bonus is then 1.5 * STR).
                # We add it if there is only one Melee attack and the
                # bonus is not already present.

                if ( Pretty::Options::isConversionActive('ALL:CMP NatAttack fix')
                && exists $lineTokens->{'NATURALATTACKS'} )
                {

                # First we verify if if there is only one melee attack.
                if ( @{ $lineTokens->{'NATURALATTACKS'} } == 1 ) {
                        my @NatAttacks = split '\|', $lineTokens->{'NATURALATTACKS'}[0];
                        if ( @NatAttacks == 1 ) {
                                my ( $NatAttackName, $Types, $NbAttacks, $Damage ) = split ',', $NatAttacks[0];
                                if ( $NbAttacks eq '*1' && $Damage ) {

                                # Now, at last, we know there is only one Natural Attack
                                # Is it a Melee attack?
                                my @Types       = split '\.', $Types;
                                my $IsMelee  = 0;
                                my $IsRanged = 0;
                                for my $type (@Types) {
                                        $IsMelee  = 1 if uc($type) eq 'MELEE';
                                        $IsRanged = 1 if uc($type) eq 'RANGED';
                                }

                                if ( $IsMelee && !$IsRanged ) {

                                        # We have a winner!!!
                                        ($NatAttackName) = ( $NatAttackName =~ /:(.*)/ );

                                        # Well, maybe the BONUS:WEAPONPROF is already there.
                                        if ( exists $lineTokens->{'BONUS:WEAPONPROF'} ) {
                                                my $AlreadyThere = 0;
                                                FIND_BONUS:
                                                for my $bonus ( @{ $lineTokens->{'BONUS:WEAPONPROF'} } ) {
                                                if ( $bonus eq "BONUS:WEAPONPROF=$NatAttackName|DAMAGE|STR/2" )
                                                {
                                                        $AlreadyThere = 1;
                                                        last FIND_BONUS;
                                                }
                                                }

                                                unless ($AlreadyThere) {
                                                push @{ $lineTokens->{'BONUS:WEAPONPROF'} },
                                                        "BONUS:WEAPONPROF=$NatAttackName|DAMAGE|STR/2";
                                                $logger->warning(
                                                        qq{Added "$lineTokens->{'BONUS:WEAPONPROF'}[0]"}
                                                                . qq{ to go with "$lineTokens->{'NATURALATTACKS'}[0]"},
                                                        $file,
                                                        $line
                                                );
                                                }
                                        }
                                        else {
                                                $lineTokens->{'BONUS:WEAPONPROF'}
                                                = ["BONUS:WEAPONPROF=$NatAttackName|DAMAGE|STR/2"];
                                                $logger->warning(
                                                qq{Added "$lineTokens->{'BONUS:WEAPONPROF'}[0]"}
                                                        . qq{to go with "$lineTokens->{'NATURALATTACKS'}[0]"},
                                                $file,
                                                $line
                                                );
                                        }
                                }
                                elsif ( $IsMelee && $IsRanged ) {
                                        $logger->warning(
                                                qq{This natural attack is both Melee and Ranged}
                                                . qq{"$lineTokens->{'NATURALATTACKS'}[0]"},
                                                $file,
                                                $line
                                        );
                                }
                                }
                        }
                }
                }

                ##################################################################
                # [ 865826 ] Remove the deprecated MOVE tag in EQUIPMENT files
                # No conversion needed. We just have to remove the MOVE tags that
                # are doing nothing anyway.

                if (   Pretty::Options::isConversionActive('EQUIP:no more MOVE')
                && $filetype eq "EQUIPMENT"
                && exists $lineTokens->{'MOVE'} )
                {
                $logger->warning( qq{Removed MOVE tags}, $file, $line );
                delete $lineTokens->{'MOVE'};
                }

                if (   Pretty::Options::isConversionActive('CLASS:no more HASSPELLFORMULA')
                && $filetype eq "CLASS"
                && exists $lineTokens->{'HASSPELLFORMULA'} )
                {
                $logger->warning( qq{Removed deprecated HASSPELLFORMULA tags}, $file, $line );
                delete $lineTokens->{'HASSPELLFORMULA'};
                }


                ##################################################################
                # Every RACE that has a Climb or a Swim MOVE must have a
                # BONUS:SKILL|Climb|8|TYPE=Racial. If there is a
                # BONUS:SKILLRANK|Swim|8|PREDEFAULTMONSTER:Y present, it must be
                # removed or lowered by 8.

                if (   Pretty::Options::isConversionActive('RACE:BONUS SKILL Climb and Swim')
                && $filetype eq "RACE"
                && exists $lineTokens->{'MOVE'} )
                {
                my $swim  = $lineTokens->{'MOVE'}[0] =~ /swim/i;
                my $climb = $lineTokens->{'MOVE'}[0] =~ /climb/i;

                if ( $swim || $climb ) {
                        my $need_swim  = 1;
                        my $need_climb = 1;

                        # Is there already a BONUS:SKILL|Swim of at least 8 rank?
                        if ( exists $lineTokens->{'BONUS:SKILL'} ) {
                                for my $skill ( @{ $lineTokens->{'BONUS:SKILL'} } ) {
                                if ( $skill =~ /^BONUS:SKILL\|([^|]*)\|(\d+)\|TYPE=Racial/i ) {
                                        my $skill_list = $1;
                                        my $skill_rank = $2;

                                        $need_swim  = 0 if $skill_list =~ /swim/i;
                                        $need_climb = 0 if $skill_list =~ /climb/i;

                                        if ( $need_swim && $skill_rank == 8 ) {
                                                $skill_list
                                                = join( ',', sort( split ( ',', $skill_list ), 'Swim' ) );
                                                $skill = "BONUS:SKILL|$skill_list|8|TYPE=Racial";
                                                $logger->warning(
                                                qq{Added Swim to "$skill"},
                                                $file,
                                                $line
                                                );
                                        }

                                        if ( $need_climb && $skill_rank == 8 ) {
                                                $skill_list
                                                = join( ',', sort( split ( ',', $skill_list ), 'Climb' ) );
                                                $skill = "BONUS:SKILL|$skill_list|8|TYPE=Racial";
                                                $logger->warning(
                                                qq{Added Climb to "$skill"},
                                                $file,
                                                $line
                                                );
                                        }

                                        if ( ( $need_climb || $need_swim ) && $skill_rank != 8 ) {
                                                $logger->info(
                                                qq{You\'ll have to deal with this one yourself "$skill"},
                                                $file,
                                                $line
                                                );
                                        }
                                }
                                }
                        }
                        else {
                                $need_swim  = $swim;
                                $need_climb = $climb;
                        }

                        # Is there a BONUS:SKILLRANK to remove?
                        if ( exists $lineTokens->{'BONUS:SKILLRANK'} ) {
                                for ( my $index = 0; $index < @{ $lineTokens->{'BONUS:SKILLRANK'} }; $index++ ) {
                                my $skillrank = $lineTokens->{'BONUS:SKILLRANK'}[$index];

                                if ( $skillrank =~ /^BONUS:SKILLRANK\|(.*)\|(\d+)\|PREDEFAULTMONSTER:Y/ ) {
                                        my $skill_list = $1;
                                        my $skill_rank = $2;

                                        if ( $climb && $skill_list =~ /climb/i ) {
                                                if ( $skill_list eq "Climb" ) {
                                                $skill_rank -= 8;
                                                if ($skill_rank) {
                                                        $skillrank
                                                                = "BONUS:SKILLRANK|Climb|$skill_rank|PREDEFAULTMONSTER:Y";
                                                        $logger->warning(
                                                                qq{Lowering skill rank in "$skillrank"},
                                                                $file,
                                                                $line
                                                        );
                                                }
                                                else {
                                                        $logger->warning(
                                                                qq{Removing "$skillrank"},
                                                                $file,
                                                                $line
                                                        );
                                                        delete $lineTokens->{'BONUS:SKILLRANK'}[$index];
                                                        $index--;
                                                }
                                                }
                                                else {
                                                $logger->info(
                                                        qq{You\'ll have to deal with this one yourself "$skillrank"},
                                                        $file,
                                                        $line
                                                );;
                                                }
                                        }

                                        if ( $swim && $skill_list =~ /swim/i ) {
                                                if ( $skill_list eq "Swim" ) {
                                                $skill_rank -= 8;
                                                if ($skill_rank) {
                                                        $skillrank
                                                                = "BONUS:SKILLRANK|Swim|$skill_rank|PREDEFAULTMONSTER:Y";
                                                        $logger->warning(
                                                                qq{Lowering skill rank in "$skillrank"},
                                                                $file,
                                                                $line
                                                        );
                                                }
                                                else {
                                                        $logger->warning(
                                                                qq{Removing "$skillrank"},
                                                                $file,
                                                                $line
                                                        );
                                                        delete $lineTokens->{'BONUS:SKILLRANK'}[$index];
                                                        $index--;
                                                }
                                                }
                                                else {
                                                $logger->info(
                                                        qq{You\'ll have to deal with this one yourself "$skillrank"},
                                                        $file,
                                                        $line
                                                );
                                                }
                                        }
                                }
                                }

                                # If there are no more BONUS:SKILLRANK, we remove the tag entry
                                delete $lineTokens->{'BONUS:SKILLRANK'}
                                unless @{ $lineTokens->{'BONUS:SKILLRANK'} };
                        }
                }
                }

                ##################################################################
                # [ 845853 ] SIZE is no longer valid in the weaponprof files
                #
                # The SIZE tag must be removed from all WEAPONPROF files since it
                # cause loading problems with the latest versio of PCGEN.

                if (   Pretty::Options::isConversionActive('WEAPONPROF:No more SIZE')
                && $filetype eq "WEAPONPROF"
                && exists $lineTokens->{'SIZE'} )
                {
                $logger->warning(
                        qq{Removing the SIZE tag in line "$lineTokens->{$master_order{'WEAPONPROF'}[0]}[0]"},
                        $file,
                        $line
                );
                delete $lineTokens->{'SIZE'};
                }

                ##################################################################
                # [ 832164 ] Adding NoProfReq to AUTO:WEAPONPROF for most races
                #
                # NoProfReq must be added to AUTO:WEAPONPROF if the race has
                # at least one hand and if NoProfReq is not already there.

                if (   Pretty::Options::isConversionActive('RACE:NoProfReq')
                && $filetype eq "RACE" )
                {
                my $needNoProfReq = 1;

                # Is NoProfReq already present?
                if ( exists $lineTokens->{'AUTO:WEAPONPROF'} ) {
                        $needNoProfReq = 0 if $lineTokens->{'AUTO:WEAPONPROF'}[0] =~ /NoProfReq/;
                }

                my $nbHands = 2;        # Default when no HANDS tag is present

                # How many hands?
                if ( exists $lineTokens->{'HANDS'} ) {
                        if ( $lineTokens->{'HANDS'}[0] =~ /HANDS:(\d+)/ ) {
                                $nbHands = $1;
                        }
                        else {
                                $logger->info(
                                        qq(Invalid value in tag "$lineTokens->{'HANDS'}[0]"),
                                        $file,
                                        $line
                                );
                                $needNoProfReq = 0;
                        }
                }

                if ( $needNoProfReq && $nbHands ) {
                        if ( exists $lineTokens->{'AUTO:WEAPONPROF'} ) {
                                $logger->warning(
                                qq{Adding "TYPE=NoProfReq" to tag "$lineTokens->{'AUTO:WEAPONPROF'}[0]"},
                                $file,
                                $line
                                );
                                $lineTokens->{'AUTO:WEAPONPROF'}[0] .= "|TYPE=NoProfReq";
                        }
                        else {
                                $lineTokens->{'AUTO:WEAPONPROF'} = ["AUTO:WEAPONPROF|TYPE=NoProfReq"];
                                $logger->warning(
                                qq{Creating new tag "AUTO:WEAPONPROF|TYPE=NoProfReq"},
                                $file,
                                $line
                                );
                        }
                }
                }

                ##################################################################
                # [ 831569 ] RACE:CSKILL to MONCSKILL
                #
                # In the RACE files, all the CSKILL must be replaced with MONCSKILL
                # but only if MONSTERCLASS is present and there is not already a
                # MONCSKILL present.

                if (   Pretty::Options::isConversionActive('RACE:CSKILL to MONCSKILL')
                && $filetype eq "RACE"
                && exists $lineTokens->{'CSKILL'}
                && exists $lineTokens->{'MONSTERCLASS'}
                && !exists $lineTokens->{'MONCSKILL'} )
                {
                $logger->warning(
                        qq{Change CSKILL for MONSKILL in "$lineTokens->{'CSKILL'}[0]"},
                        $file,
                        $line
                );

                $lineTokens->{'MONCSKILL'} = [ "MON" . $lineTokens->{'CSKILL'}[0] ];
                delete $lineTokens->{'CSKILL'};
                }

                ##################################################################
                # [ 728038 ] BONUS:VISION must replace VISION:.ADD
                #
                # VISION:.ADD must be converted to BONUS:VISION
                # Some exemple of VISION:.ADD tags:
                #   VISION:.ADD,Darkvision (60')
                #   VISION:1,Darkvision (60')
                #   VISION:.ADD,See Invisibility (120'),See Etheral (120'),Darkvision (120')

                if (   Pretty::Options::isConversionActive('ALL: , to | in VISION')
                && exists $lineTokens->{'VISION'}
                && $lineTokens->{'VISION'}[0] =~ /(\.ADD,|1,)(.*)/i )
                {
                $logger->warning(
                        qq{Removing "$lineTokens->{'VISION'}[0]"},
                        $file,
                        $line
                );

                my $newvision = "VISION:";
                my $coma;

                for my $vision_bonus ( split ',', $2 ) {
                        if ( $vision_bonus =~ /(\w+)\s*\((\d+)\'\)/ ) {
                                my ( $type, $bonus ) = ( $1, $2 );
                                push @{ $lineTokens->{'BONUS:VISION'} }, "BONUS:VISION|$type|$bonus";
                                $logger->warning(
                                qq{Adding "BONUS:VISION|$type|$bonus"},
                                $file,
                                $line
                                );
                                $newvision .= "$coma$type (0')";
                                $coma = ',';
                        }
                        else {
                                $logger->error(
                                qq(Do not know how to convert "VISION:.ADD,$vision_bonus"),
                                $file,
                                $line
                                );
                        }
                }

                $logger->warning( qq{Adding "$newvision"}, $file, $line );

                $lineTokens->{'VISION'} = [$newvision];
                }

                ##################################################################
                #
                #
                # For items with TYPE:Boot, Glove, Bracer, we must check for plural
                # form and add a SLOTS:2 tag is the item is plural.

                if (   Pretty::Options::isConversionActive('EQUIPMENT: SLOTS:2 for plurals')
                && $filetype            eq 'EQUIPMENT'
                && $line_info->[0] eq 'EQUIPMENT'
                && !exists $lineTokens->{'SLOTS'} )
                {
                my $equipment_name = $lineTokens->{ $master_order{'EQUIPMENT'}[0] }[0];

                if ( exists $lineTokens->{'TYPE'} ) {
                        my $type = $lineTokens->{'TYPE'}[0];
                        if ( $type =~ /(Boot|Glove|Bracer)/ ) {
                                if (   $1 eq 'Boot' && $equipment_name =~ /boots|sandals/i
                                || $1 eq 'Glove'  && $equipment_name =~ /gloves|gauntlets|straps/i
                                || $1 eq 'Bracer' && $equipment_name =~ /bracers|bracelets/i )
                                {
                                $lineTokens->{'SLOTS'} = ['SLOTS:2'];
                                $logger->warning(
                                        qq{"SLOTS:2" added to "$equipment_name"},
                                        $file,
                                        $line
                                );
                                }
                                else {
                                $logger->error(qq{"$equipment_name" is a $1}, $file, $line );
                                }
                        }
                }
                else {
                        $logger->warning(
                                qq{$equipment_name has no TYPE.},
                                $file,
                                $line
                        ) unless $equipment_name =~ /.MOD$/i;
                }
                }

                ##################################################################
                # #[ 677962 ] The DMG wands have no charge.
                #
                # Any Wand that do not have a EQMOD tag most have one added.
                #
                # The syntax for the new tag is
                # EQMOD:SE_50TRIGGER|SPELLNAME[$spell_name]SPELLLEVEL[$spell_level]CASTERLEVEL[$caster_level]CHARGES[50]
                #
                # The $spell_level will also be extracted from the CLASSES tag.
                # The $caster_level will be $spell_level * 2 -1

                if ( Pretty::Options::isConversionActive('EQUIPMENT: generate EQMOD') ) {
                if (   $filetype eq 'SPELL'
                        && $line_info->[0] eq 'SPELL'
                        && ( exists $lineTokens->{'CLASSES'} ) )
                {
                        my $spell_name  = $lineTokens->{'000SpellName'}[0];
                        my $spell_level = -1;

                        CLASS:
                        for ( split '\|', $lineTokens->{'CLASSES'}[0] ) {
                                if ( index( $_, 'Wizard' ) != -1 || index( $_, 'Cleric' ) != -1 ) {
                                $spell_level = (/=(\d+)$/)[0];
                                last CLASS;
                                }
                        }

                        $Spells_For_EQMOD{$spell_name} = $spell_level
                                if $spell_level > -1;

                }
                elsif ($filetype eq 'EQUIPMENT'
                        && $line_info->[0] eq 'EQUIPMENT'
                        && ( !exists $lineTokens->{'EQMOD'} ) )
                {
                        my $equip_name = $lineTokens->{'000EquipmentName'}[0];
                        my $spell_name;

                        if ( $equip_name =~ m{^Wand \((.*)/(\d\d?)(st|rd|th) level caster\)} ) {
                                $spell_name = $1;
                                my $caster_level = $2;

                                if ( exists $Spells_For_EQMOD{$spell_name} ) {
                                my $spell_level = $Spells_For_EQMOD{$spell_name};
                                my $eqmod_tag   = "EQMOD:SE_50TRIGGER|SPELLNAME[$spell_name]"
                                        . "SPELLLEVEL[$spell_level]"
                                        . "CASTERLEVEL[$caster_level]CHARGES[50]";
                                $lineTokens->{'EQMOD'}    = [$eqmod_tag];
                                $lineTokens->{'BASEITEM'} = ['BASEITEM:Wand']
                                        unless exists $lineTokens->{'BASEITEM'};
                                delete $lineTokens->{'COST'} if exists $lineTokens->{'COST'};
                                $logger->warning(
                                        qq{$equip_name: removing "COST" and adding "$eqmod_tag"},
                                        $file,
                                        $line
                                );
                                }
                                else {
                                $logger->warning(
                                        qq($equip_name: not enough information to add charges),
                                        $file,
                                        $line
                                );
                                }
                        }
                        elsif ( $equip_name =~ /^Wand \((.*)\)/ ) {
                                $spell_name = $1;
                                if ( exists $Spells_For_EQMOD{$spell_name} ) {
                                my $spell_level  = $Spells_For_EQMOD{$spell_name};
                                my $caster_level = $spell_level * 2 - 1;
                                my $eqmod_tag   = "EQMOD:SE_50TRIGGER|SPELLNAME[$spell_name]"
                                        . "SPELLLEVEL[$spell_level]"
                                        . "CASTERLEVEL[$caster_level]CHARGES[50]";
                                $lineTokens->{'EQMOD'} = [$eqmod_tag];
                                delete $lineTokens->{'COST'} if exists $lineTokens->{'COST'};
                                $logger->warning(
                                        qq{$equip_name: removing "COST" and adding "$eqmod_tag"},
                                        $file,
                                        $line
                                );
                                }
                                else {
                                $logger->warning(
                                        qq{$equip_name: not enough information to add charges},
                                        $file,
                                        $line
                                );
                                }
                        }
                        elsif ( $equip_name =~ /^Wand/ ) {
                                $logger->warning(
                                qq{$equip_name: not enough information to add charges},
                                $file,
                                $line
                                );
                        }
                }
                }

                ##################################################################
                # [ 663491 ] RACE: Convert AGE, HEIGHT and WEIGHT tags
                #
                # For each HEIGHT, WEIGHT or AGE tags found in a RACE file,
                # we must call record_bioset_tags to record the AGE, HEIGHT and
                # WEIGHT tags.

                if (   Pretty::Options::isConversionActive('BIOSET:generate the new files')
                && $filetype            eq 'RACE'
                && $line_info->[0] eq 'RACE'
                && (   exists $lineTokens->{'AGE'}
                        || exists $lineTokens->{'HEIGHT'}
                        || exists $lineTokens->{'WEIGHT'} )
                ) {
                my ( $dir, $race, $age, $height, $weight );

                $dir  = File::Basename::dirname($file);
                $race = $lineTokens->{ $master_order{'RACE'}[0] }[0];
                if ( $lineTokens->{'AGE'} ) {
                        $age = $lineTokens->{'AGE'}[0];
                        $logger->warning( qq{Removing "$lineTokens->{'AGE'}[0]"}, $file, $line );
                        delete $lineTokens->{'AGE'};
                }
                if ( $lineTokens->{'HEIGHT'} ) {
                        $height = $lineTokens->{'HEIGHT'}[0];
                        $logger->warning( qq{Removing "$lineTokens->{'HEIGHT'}[0]"}, $file, $line );
                        delete $lineTokens->{'HEIGHT'};
                }
                if ( $lineTokens->{'WEIGHT'} ) {
                        $weight = $lineTokens->{'WEIGHT'}[0];
                        $logger->warning( qq{Removing "$lineTokens->{'WEIGHT'}[0]"}, $file, $line );
                        delete $lineTokens->{'WEIGHT'};
                }

                record_bioset_tags( $dir, $race, $age, $height, $weight, $file,
                        $line );
                }

                ##################################################################
                # [ 653596 ] Add a TYPE tag for all SPELLs
                # .

                if (   Pretty::Options::isConversionActive('SPELL:Add TYPE tags')
                && exists $lineTokens->{'SPELLTYPE'}
                && $filetype            eq 'CLASS'
                && $line_info->[0] eq 'CLASS'
                ) {

                # We must keep a list of all the SPELLTYPE for each class.
                # It is assumed that SPELLTYPE cannot be found more than once
                # for the same class. It is also assumed that SPELLTYPE has only
                # one value. SPELLTYPE:Any is ignored.

                my $class_name = $lineTokens->{ $master_order{'CLASS'}[0] }[0];
                SPELLTYPE_TAG:
                for my $spelltype_tag ( values %{ $lineTokens->{'SPELLTYPE'} } ) {
                        my $spelltype = "";
                        ($spelltype) = ($spelltype_tag =~ /SPELLTYPE:(.*)/);
                        next SPELLTYPE_TAG if $spelltype eq "" or uc($spelltype) eq "ANY";
                        $class_spelltypes{$class_name}{$spelltype}++;
                }
                }

                if (   Pretty::Options::isConversionActive('SPELL:Add TYPE tags')
                && $filetype                    eq 'SPELL'
                && $line_info->{Linetype} eq 'SPELL' )
                {

                # For each SPELL we build the TYPE tag or we add to the
                # existing one.
                # The .MOD SPELL are ignored.

                }

                # SOURCE line replacement
                # =======================
                # Replace the SOURCELONG:xxx|SOURCESHORT:xxx|SOURCEWEB:xxx
                # with the values found in the .PCC of the same directory.
                #
                # Only the first SOURCE line found is replaced.

                if (   Pretty::Options::isConversionActive('SOURCE line replacement')
                && defined $line_info
                && $line_info->[0] eq 'SOURCE'
                && $source_curent_file ne $file )
                {

                # Only the first SOURCE tag is replace.
                if ( exists $source_tags{ File::Basename::dirname($file) } ) {

                        # We replace the line with a concatanation of SOURCE tags found in
                        # the directory .PCC
                        my %line_tokens;
                        while ( my ( $tag, $value ) = each %{ $source_tags{ File::Basename::dirname($file) } } )
                        {
                           $line_tokens{$tag} = [$value];
                           $source_curent_file = $file;
                        }

                        $line_info->[1] = \%line_tokens;
                }
                elsif ( $file =~ / \A $cl_options{input_path} /xmsi ) {
                        # We give this notice only if the curent file is under getOption('inputpath').
                        # If -basepath is used, there could be files loaded outside of the -inputpath
                        # without their PCC.
                        $logger->notice( "No PCC source information found", $file, $line );
                }
                }

                # Extract lists
                # ====================
                # Export each file name and log them with the filename and the
                # line number

                if ( Pretty::Options::isConversionActive('Export lists') ) {
                my $filename = $file;
                $filename =~ tr{/}{\\};

                if ( $filetype eq 'SPELL' ) {

                        # Get the spell name
                        my $spellname  = $lineTokens->{'000SpellName'}[0];
                        my $sourcepage = "";
                        $sourcepage = $lineTokens->{'SOURCEPAGE'}[0] if exists $lineTokens->{'SOURCEPAGE'};

                        # Write to file
                        print { $filehandle_for{SPELL} }
                                qq{"$spellname","$sourcepage","$line","$filename"\n};
                }
                if ( $filetype eq 'CLASS' ) {
                        my $class = ( $lineTokens->{'000ClassName'}[0] =~ /^CLASS:(.*)/ )[0];
                        print { $filehandle_for{CLASS} } qq{"$class","$line","$filename"\n} if $class_name ne $class;
                        $class_name = $class;
                }

                if ( $filetype eq 'DEITY' ) {
                        print { $filehandle_for{DEITY} }
                                qq{"$lineTokens->{'000DeityName'}[0]","$line","$filename"\n};
                }

                if ( $filetype eq 'DOMAIN' ) {
                        print { $filehandle_for{DOMAIN} }
                                qq{"$lineTokens->{'000DomainName'}[0]","$line","$filename"\n};
                }

                if ( $filetype eq 'EQUIPMENT' ) {
                        my $equipname  = $lineTokens->{ $master_order{$filetype}[0] }[0];
                        my $outputname = "";
                        $outputname = substr( $lineTokens->{'OUTPUTNAME'}[0], 11 )
                                if exists $lineTokens->{'OUTPUTNAME'};
                        my $replacementname = $equipname;
                        if ( $outputname && $equipname =~ /\((.*)\)/ ) {
                                $replacementname = $1;
                        }
                        $outputname =~ s/\[NAME\]/$replacementname/;
                        print { $filehandle_for{EQUIPMENT} }
                                qq{"$equipname","$outputname","$line","$filename"\n};
                }

                if ( $filetype eq 'EQUIPMOD' ) {
                        my $equipmodname = $lineTokens->{ $master_order{$filetype}[0] }[0];
                        my ( $key, $type ) = ( "", "" );
                        $key  = substr( $lineTokens->{'KEY'}[0],  4 ) if exists $lineTokens->{'KEY'};
                        $type = substr( $lineTokens->{'TYPE'}[0], 5 ) if exists $lineTokens->{'TYPE'};
                        print { $filehandle_for{EQUIPMOD} }
                                qq{"$equipmodname","$key","$type","$line","$filename"\n};
                }

                if ( $filetype eq 'FEAT' ) {
                        my $featname = $lineTokens->{ $master_order{$filetype}[0] }[0];
                        print { $filehandle_for{FEAT} } qq{"$featname","$line","$filename"\n};
                }

                if ( $filetype eq 'KIT STARTPACK' ) {
                        my ($kitname)
                                = ( $lineTokens->{ $master_order{$filetype}[0] }[0] =~ /\A STARTPACK: (.*) \z/xms );
                        print { $filehandle_for{KIT} } qq{"$kitname","$line","$filename"\n};
                }

                if ( $filetype eq 'KIT TABLE' ) {
                        my ($tablename)
                                = ( $lineTokens->{ $master_order{$filetype}[0] }[0] =~ /\A TABLE: (.*) \z/xms );
                        print { $filehandle_for{TABLE} } qq{"$tablename","$line","$filename"\n};
                }

                if ( $filetype eq 'LANGUAGE' ) {
                        my $languagename = $lineTokens->{ $master_order{$filetype}[0] }[0];
                        print { $filehandle_for{LANGUAGE} } qq{"$languagename","$line","$filename"\n};
                }

                if ( $filetype eq 'RACE' ) {
                        my $racename            = $lineTokens->{ $master_order{$filetype}[0] }[0];

                        my $race_type = q{};
                        $race_type = $lineTokens->{'RACETYPE'}[0] if exists $lineTokens->{'RACETYPE'};
                        $race_type =~ s{ \A RACETYPE: }{}xms;

                        my $race_sub_type = q{};
                        $race_sub_type = $lineTokens->{'RACESUBTYPE'}[0] if exists $lineTokens->{'RACESUBTYPE'};
                        $race_sub_type =~ s{ \A RACESUBTYPE: }{}xms;

                        print { $filehandle_for{RACE} }
                                qq{"$racename","$race_type","$race_sub_type","$line","$filename"\n};
                }

                if ( $filetype eq 'SKILL' ) {
                        my $skillname = $lineTokens->{ $master_order{$filetype}[0] }[0];
                        print { $filehandle_for{SKILL} } qq{"$skillname","$line","$filename"\n};
                }

                if ( $filetype eq 'TEMPLATE' ) {
                        my $template_name = $lineTokens->{ $master_order{$filetype}[0] }[0];
                        print { $filehandle_for{TEMPLATE} } qq{"$template_name","$line","$filename"\n};
                }
                }

                ############################################################
                ######################## Conversion ########################
                # We manipulate the tags for the line here

                if ( Pretty::Options::isConversionActive('Generate BONUS and PRExxx report') ) {
                for my $tag_type ( sort keys %$lineTokens ) {
                        if ( $tag_type =~ /^BONUS|^!?PRE/ ) {
                                $bonus_prexxx_tag_report{$filetype}{$_} = 1 for ( @{ $lineTokens->{$tag_type} } );
                        }
                }
                }

                1;
        }

}       # End of BEGIN


=head2 normalizeFile 

   Detect filetype and normalize lines
   
   Parameters: $buffer => raw file data in a single string (embeded newlines \n)
   
   Returns: $filetype => either 'tab-based' or 'multi-line'
            $lines => arrayref containing logical lines normalized to tab-based format

=cut

sub normalizeFile {

   # TODO: handle empty buffers, other corner-cases
   my $buffer = shift || "";    # default to empty line when passed undef
   my $filetype;
   my @lines;

   # first, we clean out empty lines that contain only white-space. Otherwise,
   # we could have false positives on the filetype
   $buffer =~ s/^\s*$//g;

   # detect file-type multi-line

   # having a tab as a first character on a non-whitespace line is a sign of a
   # multi-line file
   if ($buffer =~ /^\t+\S/m) {

      $filetype = "multi-line";

      # Normalize to tab-based
      # 1) All lines that start with a tab belong to the previous line.
      # 2) Copy the lines as-is to the end of the previous line
      #
      # We use a regexp that just removes the newlines, which is easier than copying

      $buffer =~ s/\n\t/\t/mg;

      @lines = split /\n/, $buffer;

   } else {
      $filetype = "tab-based";
   }

   # The buffer iw not normalized. Split on newline
   @lines = split /\n/, $buffer;

   # return a arrayref so we are a little more efficient
   return (\@lines, $filetype);
}

=head2 missingValue

   There is a pre tag with no value and no .CLEAR

=cut

sub missingValue {

   my ($tagName, $enclosingTag, $file, $line) = @_;

   # No value found
   my $message = qq{Check for missing ":", no value for "$tagName"};
   $message .= qq{ found in "$enclosingTag"} if $enclosingTag;

   my $logging = getLogger();

   $logging->warning($message, $file, $line);
};

=head2 processPREABILITY

   Process the PREABILITY tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPREABILITY {

   my ( $tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # [ 1671407 ] xcheck PREABILITY tag
   # Shamelessly copied from the above FEAT code.
   # PREABILITY:number,feat,feat,TYPE=type,CATEGORY=category

   # We get the list of abilities and ability types
   my @abilities = embedded_coma_split($tagValue);

   if ( $abilities[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @abilities;       

   } else {

      # The PREtag doesn't begin by a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('ABILITY', $tag, $file, $line, @abilities);
}

=head2 processPRECLASS

   Process the PRECSKILL tags

   Ensure they start with a number and if so, queue for cross checking.

=cut

sub processPRECLASS {
   my ( $tag, $tagValue, $enclosingTag, $file, $line) = @_;

   #PRECLASS:number,Class,Class=ClassLevel
   my @classes = split ',', $tagValue;

   if ( $classes[0] =~ /^\d+$/ ) {

      # We drop the number at the beginning
      shift @classes;

   } else {

      # The PREtag doesn't begin with a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck( 'CLASS', $tag, $file, $line, @classes );
};

=head2 processPRECHECK

   Check the PRECHECK familiy of PRE tags for validity.

   Ensures they start with a number.

   Ensures that the checks are valid.

=cut

sub processPRECHECK {

   my ( $tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # PRECHECK:<number>,<check equal value list>
   # PRECHECKBASE:<number>,<check equal value list>
   # <check equal value list> := <check name> "=" <number>
   my @items = split q{,}, $tagValue;

   if ( $items[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @items;
   
   } else {

      # The PREtag doesn't begin by a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }
   
   my $logging = getLogger();

   for my $item ( @items ) {

      # Extract the check name
      if ( my ($check_name,$value) = ( $item =~ / \A ( \w+ ) = ( \d+ ) \z /xms ) ) {

         # If we don't recognise it.
         if ( !exists $valid_check_name{$check_name} ) {
            $logging->notice(
               qq{Invalid save check name "$check_name" found in "$tag:$tagValue"},
               $file,
               $line
            );
         }
      } else {
         $logging->notice(
            qq{$tag syntax error in "$item" found in "$tag:$tagValue"},
            $file,
            $line
         );
      }
   }
}

=head2 processPRECSKILL

   Process the PRECSKILL tags

   Ensure they start with a number and if so, queue for cross checking.

=cut

sub processPRECSKILL {

   my ( $tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # We get the list of skills and skill types
   my @skills = split ',', $tagValue;

   if ( $skills[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @skills;

   } else {

      # The PREtag doesn't begin with a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('SKILL', $tag, $file, $line, @skills);
};

=head2 processPREDIETY

   Process the PREDIETY tags

   Queue up for Cross check.

=cut

sub processPREDIETY {

   my ( $tag, $tagValue, $file, $line) = @_;

   #PREDEITY:Y
   #PREDEITY:YES
   #PREDEITY:N
   #PREDEITY:NO
   #PREDEITY:1,<deity name>,<deity name>,etc.
   
   if ( $tagValue !~ / \A (?: Y(?:ES)? | N[O]? ) \z /xms ) {
      #We ignore the single yes or no
      registerXCheck('DEITY', $tag, $file, $line, (split /[,]/, $tagValue)[1,-1],);
   }
};

=head2 processPREDOMAIN

   Process the PREDOMAIN tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPREDOMAIN {

   my ( $tag, $tagValue, $enclosingTag, $file, $line) = @_;

   #PREDOMAIN:number,Domain,Domain
   my @domains = split ',', $tagValue;

   if ( $domains[0] =~ /^\d+$/ ) {

      # We drop the number at the beginning
      shift @domains;
   
   } else {

      # The PREtag doesn't begin with a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('DOMAIN', $tag, $file, $line, @domains);
}

=head2 processPREFEAT

   Process the PREFEAT tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPREFEAT {

   my ( $tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # PREFEAT:number,feat,feat,TYPE=type

   # We get the list of feats and feat types
   my @feats = embedded_coma_split($tagValue);

   if ( $feats[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @feats;

   } else {

      # The PREtag doesn't begin with a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('FEAT', $tag, $file, $line, @feats);
}

=head2 processPREITEM

   Process the PREITEM tags

   Check for deprecated syntax and quque up for cross check.

=cut 

processPREITEM {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # PRETIEM:number,item,TYPE=itemtype
   # The list of items may include () with embeded coma
   my @items = embedded_coma_split($tagValue);

   if ( $items[0] =~ / \A \d+ \z /xms ) {
      shift @items;   # We drop the number at the beginning
   }
   else {

      # The PREtag doesn't begin by a number
      warn_deprecate( "$tag:$tagValue",
         $file,
         $line,
         $enclosingTag
      );
   }

   registerXCheck('EQUIPMENT', $tag, $file, $line, @items);
}
      
=head2 processPRELANG

   Process the PRELANG tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPRELANG {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # PRELANG:number,language,language,TYPE=type

   # We get the list of feats and feat types
   my @languages = split ',', $tagValue;

   if ( $languages[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @languages;

   } else {

      # The PREtag doesn't begin by a number
      warn_deprecate( "$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('LANGUAGE', $tag, $file, $line, grep { $_ ne 'ANY' } @languages);
}

=head2 processPREMOVE

   Process the PREMOVE tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPREMOVE {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # PREMOVE:[<number>,]<move>=<number>,<move>=<number>,...

   my @moves = split ',', $tagValue;

   if ( $moves[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @moves;

   } else { 

      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   for my $move (@moves) {

      # Verify that the =<number> is there
      if ( $move =~ /^([^=]*)=([^=]*)$/ ) {

         registerXCheck('MOVE Type', $tag, $file, $line, $1);

         # The value should be a number
         my $value = $2;

         if ($value !~ /^\d+$/ ) {
            my $message = qq{Not a number after the = for "$move" in "$tag:$tagValue"};
            $message .= qq{ found in "$enclosingTag"} if $enclosingTag;
   
            my $logging = getLogger();
            $logging->notice( $message, $file, $line );
         }

      } else {

         my $message = qq{Invalid "$move" in "$tag:$tagValue"};
         $message .= qq{ found in "$enclosingTag"} if $enclosingTag;
   
         my $logging = getLogger();
         $logging->notice( $message, $file, $line );

      }
   }
}

=head2 processPREMULT

   split and check the PREMULT tags

   Each PREMULT tag has two or more embedded PRE tags, which are individually
   checked using validatePreTag.

=cut

sub processPREMULT {

   my ($tag, $tagValue, $enclosingTag, $lineType, $file, $line) = @_;

   my $working_value = $tagValue;
   my $inside;

   # We add only one level of PREMULT to the error message.
   my $emb_tag;
   if ($enclosingTag) {

      $emb_tag = $enclosingTag;
      $emb_tag .= ':PREMULT' unless $emb_tag =~ /PREMULT$/;

   } else {

      $emb_tag .= 'PREMULT';
   }

   FIND_BRACE:
   while ($working_value) {

      ( $inside, $working_value ) = Text::Balanced::extract_bracketed( $working_value, '[]', qr{[^[]*} );

      last FIND_BRACE if !$inside;

      # We extract what we need
      my ( $XXXPREXXX, $value ) = ( $inside =~ /^\[(!?PRE[A-Z]+):(.*)\]$/ );

      if ($XXXPREXXX) {

         validatePreTag($XXXPREXXX, $value, $emb_tag, $lineType, $file, $line);
      
      } else {

         my $logging = getLogger();

         # No PRExxx tag found inside the PREMULT
         $logging->warning(
            qq{No valid PRExxx tag found in "$inside" inside "PREMULT:$tagValue"},
            $file,
            $line
         );
      }
   }
}

=head2 processPRERACE


=cut

sub processPRERACE {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # We get the list of races
   my @races_tmp = split ',', $tagValue;

   # Validate that the first entry is a number
   if ( $races_tmp[0] =~ / \A \d+ \z /xms ) {
      
      # We drop the number at the beginning
      shift @races_tmp;

   } else {

      # The PREtag doesn't begin by a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   my ( @races, @races_wild );

   for my $race (@races_tmp)
   {
      if ( $race =~ / (.*?) [%] (.*?) /xms ) {
         # Special case for PRERACE:xxx%
         my $race_wild  = $1;
         my $after_wild = $2;

         push @races_wild, $race_wild;

         if ( $after_wild ne q{} ) {

            my $logging = getLogger();

            $logging->notice(
               qq{% used in wild card context should end the race name in "$race"},
               $file,
               $line
            );

         } else {

            # Don't bother warning if it matches everything.
            # For now, we warn and do nothing else.
            if ($race_wild eq '') {

               ## Matches everything, no reason to warn.

            } elsif ($valid_entities{'RACE'}{$race_wild}) {

               ## Matches an existing race, no reason to warn.

            } elsif ($race_partial_match{$race_wild}) {

               ## Partial match already confirmed, no need to confirm.
               #
            } else {

               my $found = 0;

               while (($found == 0) && ((my $check_race,my $val) = each(%{$valid_entities{'RACE'}}))) {

                  if ( $check_race =~ m/^\Q$race_wild/) {
                     $found=1;
                     $race_partial_match{$race_wild} = 1;
                  }
               }

               if ($found == 0) {

                  my $logging = getLogger();

                  $logging->info(
                     qq{Not able to validate "$race" in "PRERACE:$tagValue." This warning is order dependent. If the race is defined in a later file, this warning may not be accurate.},
                     $file,
                     $line
                  )
               }
            }
         }
      } else {
         push @races, $race;
      }
   }

   registerXCheck('RACE', $tag, $file, $line, @races);
}


=head2 processPRESKILL

   Process the PRESKILL tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPRESKILL {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # We get the list of skills and skill types
   my @skills = split ',', $tagValue;

   if ( $skills[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @skills;

   } else {

      # The PREtag doesn't begin by a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('SKILL', $tag, $file, $line, @skills);
}

=head2 processPRESPELL

   Process the PRESPELL tags

   Check for deprecated syntax and quque up for cross check.

=cut

sub processPRESPELL {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   # We get the list of skills and skill types
   my @spells = split ',', $tagValue;

   if ( $spells[0] =~ / \A \d+ \z /xms ) {

      # We drop the number at the beginning
      shift @spells;

   } else {

      # The PREtag doesn't begin by a number
      warn_deprecate("$tag:$tagValue", $file, $line, $enclosingTag);
   }

   registerXCheck('SPELL', "$tag:@@", $file, $line, @spells);
}

=head2 processPREVAR

=cut

sub processPREVAR {

   my ($tag, $tagValue, $enclosingTag, $file, $line) = @_;

   my ( $var_name, @formulas ) = split ',', $tagValue;

   registerXCheck('DEFINE Variable', qq(@@" in "$tag:$tagValue), $file, $line, $var_name,);

   for my $formula (@formulas) {
      registerXCheck('DEFINE Variable', qq(@@" in "$tag:$tagValue), $file, $line, parse_jep( $formula, "$tag:$tagValue", $file, $line),);
   }
}



=head2 validatePreTag

   Validate the PRExxx tags. This function is reentrant and can be called
   recursivly.

   $tag,             # Name of the tag (before the :)
   $tagValue,        # Value of the tag (after the :)
   $enclosingTag,    # When the PRExxx tag is used in another tag
   $lineType,        # Type for the current file
   $file,            # Name of the current file
   $line             # Number of the current line

   preforms checks that pre tags are valid. 

=cut

sub validatePreTag {
   my ( $tag, $tagValue, $enclosingTag, $lineType, $file, $line) = @_;

   # get the logger
   my $logging = getLogger();

   if ( !length($tagValue) && $tag ne "PRE:.CLEAR" ) {
      missingValue();
      return;
   }

   $logging->debug( 
      qq{validatePreTag: $tag; $tagValue; $enclosingTag; $lineType;},
      $file,
      $line
   );

   my $is_neg = 1 if $tag =~ s/^!(.*)/$1/;
   my $comp_op;

   # Special treatment for tags ending in MULT because of PREMULT and
   # PRESKILLMULT
   if ($tag !~ /MULT$/) {
      ($comp_op) = ( $tag =~ s/(.*)(EQ|GT|GTEQ|LT|LTEQ|NEQ)$/$1/ )[1];
   }

   if ( $tag eq 'PRECLASS' || $tag eq 'PRECLASSLEVELMAX' ) {

      processPRECLASS($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PRECHECK' || $tag eq 'PRECHECKBASE') {

      processPRECHECK ( $tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PRECSKILL' ) {

      processPRECSKILL($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREDEITY' ) {

      processPREDIETY($tag, $tagValue, $file, $line);

   } elsif ( $tag eq 'PREDEITYDOMAIN' || $tag eq 'PREDOMAIN' ) {

      processPREDOMAIN($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREFEAT' ) {

      processPREFEAT($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREABILITY' ) {

      processPREABILITY($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREITEM' ) {

      processPREITEM($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PRELANG' ) {
      
      processPRELANG($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREMOVE' ) {

      processPREMOVE($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREMULT' ) {

      # This tag is the reason why validatePreTag exists
      # PREMULT:x,[PRExxx 1],[PRExxx 2]
      # We need for find all the [] and call validatePreTag with the content
   
      processPREMULT($tag, $tagValue, $enclosingTag, $lineType, $file, $line);

   } elsif ( $tag eq 'PRERACE' ) {

      processPRERACE($tag, $tagValue, $enclosingTag, $file, $line);

   }
   elsif ( $tag eq 'PRESKILL' ) {

      processPRESKILL($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PRESPELL' ) {

      processPRESPELL($tag, $tagValue, $enclosingTag, $file, $line);

   } elsif ( $tag eq 'PREVAR' ) {

      processPREVAR($tag, $tagValue, $enclosingTag, $file, $line);

   }

   # No Check for Variable File #

   # Check for PRExxx that do not exist. We only check the
   # tags that are embeded since parse_tag already took care
   # of the PRExxx tags on the entry lines.
   elsif ( $enclosingTag && !exists $PRE_Tags{$tag} ) {
      
      my $logging = getLogger();
      
      $logging->notice(
         qq{Unknown PRExxx tag "$tag" found in "$enclosingTag"},
         $file,
         $line
      );
   }
}


###############################################################
# validate_line
# -------------
#
# This function perform validation that must be done on a
# whole line at a time.
#
# Paramter: $line_ref           Ref to a hash containing the tags of the line
#               $linetype               Type for the current line
#               $file_for_error   Name of the current file
#               $line_for_error   Number of the current line

sub validate_line {
        my ( $line_ref, $linetype, $file_for_error, $line_for_error ) = @_;

        ########################################################
        # Validation for the line identifier
        ########################################################

        if ( !($linetype eq 'SOURCE'
                || $linetype eq 'KIT LANGAUTO'
                || $linetype eq 'KIT NAME'
                || $linetype eq 'KIT FEAT'
                || $file_for_error =~ m{ [.] PCC \z }xmsi
                || $linetype eq 'COMPANIONMOD') # FOLLOWER:Class1,Class2=level
        ) {

                # We get the line identifier.
                my $identifier = $line_ref->{ $master_order{$linetype}[0] }[0];

                # We hunt for the bad comma.
                if($identifier =~ /,/) {
                        $logging->notice(
                                qq{"," (comma) should not be used in line identifier name: $identifier},
                                $file_for_error,
                                $line_for_error
                        );
                }
        }

        ########################################################
        # Special validation for specific tags
        ########################################################

        if ( 0 && $linetype eq 'SPELL' )        # disabled for now.
        {

                # Either or both CLASSES and DOMAINS tags must be
                # present in a normal SPELL line

                if (  exists $line_ref->{'000SpellName'}
                        && $line_ref->{'000SpellName'}[0] !~ /\.MOD$/
                        && exists $line_ref->{'TYPE'}
                        && $line_ref->{'TYPE'}[0] ne 'TYPE:Psionic.Attack Mode'
                        && $line_ref->{'TYPE'}[0] ne 'TYPE:Psionic.Defense Mode' )
                {
                        $logging->info(
                                qq(No CLASSES or DOMAINS tag found for SPELL "$line_ref->{'000SpellName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        ) if !( exists $line_ref->{'CLASSES'} || exists $line_ref->{'DOMAINS'} );
                }
        }
        elsif ( $linetype eq "ABILITY" ) {

                # On an ABILITY line type:
                # 0) MUST contain CATEGORY tag
                # 1) if it has MULT:YES, it  _has_ to have CHOOSE
                # 2) if it has CHOOSE, it _has_ to have MULT:YES
                # 3) if it has STACK:YES, it _has_ to have MULT:YES (and CHOOSE)

                # Find lines that modify or remove Categories of Abilityies without naming the Abilities
                my $MOD_Line = $line_ref->{'000AbilityName'}[0];
                study $MOD_Line;

                if ( $MOD_Line =~ /\.(MOD|FORGET|COPY=)/ ) {
                        # Nothing to see here. Move on.
                }
                # Find the Abilities lines without Categories
                elsif ( !$line_ref->{'CATEGORY'} ) {
                        $logging->warning(
                                qq(The CATEGORY tag is required in ABILITY "$line_ref->{'000AbilityName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                my ( $hasCHOOSE, $hasMULT, $hasSTACK );

                $hasCHOOSE = 1 if exists $line_ref->{'CHOOSE'};
                $hasMULT   = 1 if exists $line_ref->{'MULT'} && $line_ref->{'MULT'}[0] =~ /^MULT:Y/i;
                $hasSTACK  = 1 if exists $line_ref->{'STACK'} && $line_ref->{'STACK'}[0] =~ /^STACK:Y/i;

                if ( $hasMULT && !$hasCHOOSE ) {
                        $logging->info(
                                qq(The CHOOSE tag is mandantory when MULT:YES is present in ABILITY "$line_ref->{'000AbilityName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                elsif ( $hasCHOOSE && !$hasMULT && $line_ref->{'CHOOSE'}[0] !~ /CHOOSE:SPELLLEVEL/i ) {
                        # The CHOOSE:SPELLLEVEL is exempted from this particular rule.
                        $logging->info(
                                qq(The MULT:YES tag is mandatory when CHOOSE is present in ABILITY "$line_ref->{'000AbilityName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                elsif ( $hasCHOOSE && !$hasMULT && $line_ref->{'CHOOSE'}[0] !~ /CHOOSE:NUMBER/i ) {
                        # The CHOOSE:NUMBER is exempted from this particular rule.
                        $logging->info(
                                qq(The MULT:YES tag is mandatory when CHOOSE is present in ABILITY "$line_ref->{'000AbilityName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }

                if ( $hasSTACK && !$hasMULT ) {
                        $logging->info(
                                qq(The MULT:YES tag is mandatory when STACK:YES is present in ABILITY "$line_ref->{'000AbilityName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }

                # We identify the feats that can have sub-entities. e.g. Spell Focus(Spellcraft)
                if ($hasCHOOSE) {

                        # The CHOSE type tells us the type of sub-entities
                        my $choose      = $line_ref->{'CHOOSE'}[0];
                        my $ability_name = $line_ref->{'000AbilityName'}[0];
                        $ability_name =~ s/.MOD$//;

                        if ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?(FEAT=[^|]*)/ ) {
                                $valid_sub_entities{'ABILITY'}{$ability_name} = $1;
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?FEATLIST/ ) {
                                $valid_sub_entities{'ABILITY'}{$ability_name} = 'FEAT';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?(?:WEAPONPROFS|Exotic|Martial)/ ) {
                                $valid_sub_entities{'ABILITY'}{$ability_name} = 'WEAPONPROF';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SKILLSNAMED/ ) {
                                $valid_sub_entities{'ABILITY'}{$ability_name} = 'SKILL';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SCHOOLS/ ) {
                                $valid_sub_entities{'ABILITY'}{$ability_name} = 'SPELL_SCHOOL';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SPELLLIST/ ) {
                                $valid_sub_entities{'ABILITY'}{$ability_name} = 'SPELL';
                        }
                        elsif ($choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SPELLLEVEL/
                                || $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?HP/ )
                        {

                                # Ad-Lib is a special case that means "Don't look for
                                # anything else".
                                $valid_sub_entities{'ABILITY'}{$ability_name} = 'Ad-Lib';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:COUNT=\d+\|)?(.*)/ ) {

                                # ad-hod/special list of thingy
                                # It adds to the valid entities instead of the
                                # valid sub-entities.
                                # We do this when we find a CHOOSE but we do not
                                # know what it is for.
                                for my $sub_type ( split '\|', $1 ) {
                                        $valid_entities{'ABILITY'}{"$ability_name($sub_type)"}  = $1;
                                        $valid_entities{'ABILITY'}{"$ability_name ($sub_type)"} = $1;
                                }
                        }
                }
        }

        elsif ( $linetype eq "FEAT" ) {

                # [ 1671410 ] xcheck CATEGORY:Feat in Feat object.
                my $hasCategory = 0;
                $hasCategory = 1 if exists $line_ref->{'CATEGORY'};
                if ($hasCategory) {
                        if ($line_ref->{'CATEGORY'}[0] eq "CATEGORY:Feat" ||
                            $line_ref->{'CATEGORY'}[0] eq "CATEGORY:Special Ability") {
                                # Good
                        }
                        else {
                                $logging->info(
                                        qq(The CATEGORY tag must have the value of Feat or Special Ability when present on a FEAT. Remove or replace "$line_ref->{'CATEGORY'}[0]"),
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                }

                # On a FEAT line type:
                # 1) if it has MULT:YES, it  _has_ to have CHOOSE
                # 2) if it has CHOOSE, it _has_ to have MULT:YES
                # 3) if it has STACK:YES, it _has_ to have MULT:YES (and CHOOSE)
                my ( $hasCHOOSE, $hasMULT, $hasSTACK );

                $hasCHOOSE = 1 if exists $line_ref->{'CHOOSE'};
                $hasMULT   = 1 if exists $line_ref->{'MULT'} && $line_ref->{'MULT'}[0] =~ /^MULT:Y/i;
                $hasSTACK  = 1 if exists $line_ref->{'STACK'} && $line_ref->{'STACK'}[0] =~ /^STACK:Y/i;

                if ( $hasMULT && !$hasCHOOSE ) {
                        $logging->info(
                                qq(The CHOOSE tag is mandatory when MULT:YES is present in FEAT "$line_ref->{'000FeatName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                elsif ( $hasCHOOSE && !$hasMULT && $line_ref->{'CHOOSE'}[0] !~ /CHOOSE:SPELLLEVEL/i ) {

                        # The CHOOSE:SPELLLEVEL is exampted from this particular rule.
                        $logging->info(
                                qq(The MULT:YES tag is mandatory when CHOOSE is present in FEAT "$line_ref->{'000FeatName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                elsif ( $hasCHOOSE && !$hasMULT && $line_ref->{'CHOOSE'}[0] !~ /CHOOSE:NUMBER/i ) {

                        # The CHOOSE:NUMBER is exampted from this particular rule.
                        $logging->info(
                                qq(The MULT:YES tag is mandatory when CHOOSE is present in FEAT "$line_ref->{'000FeatName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }

                if ( $hasSTACK && !$hasMULT ) {
                        $logging->info(
                                qq(The MULT:YES tag is mandatory when STACK:YES is present in FEAT "$line_ref->{'000FeatName'}[0]"),
                                $file_for_error,
                                $line_for_error
                        );
                }

                # We identify the feats that can have sub-entities. e.g. Spell Focus(Spellcraft)
                if ($hasCHOOSE) {

                        # The CHOSE type tells us the type of sub-entities
                        my $choose      = $line_ref->{'CHOOSE'}[0];
                        my $feat_name = $line_ref->{'000FeatName'}[0];
                        $feat_name =~ s/.MOD$//;

                        if ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?(FEAT=[^|]*)/ ) {
                                $valid_sub_entities{'FEAT'}{$feat_name} = $1;
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?FEATLIST/ ) {
                                $valid_sub_entities{'FEAT'}{$feat_name} = 'FEAT';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?(?:WEAPONPROFS|Exotic|Martial)/ ) {
                                $valid_sub_entities{'FEAT'}{$feat_name} = 'WEAPONPROF';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SKILLSNAMED/ ) {
                                $valid_sub_entities{'FEAT'}{$feat_name} = 'SKILL';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SCHOOLS/ ) {
                                $valid_sub_entities{'FEAT'}{$feat_name} = 'SPELL_SCHOOL';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SPELLLIST/ ) {
                                $valid_sub_entities{'FEAT'}{$feat_name} = 'SPELL';
                        }
                        elsif ($choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?SPELLLEVEL/
                                || $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?HP/ )
                        {

                                # Ad-Lib is a special case that means "Don't look for
                                # anything else".
                                $valid_sub_entities{'FEAT'}{$feat_name} = 'Ad-Lib';
                        }
                        elsif ( $choose =~ /^CHOOSE:(?:COUNT=\d+\|)?(.*)/ ) {

                                # ad-hod/special list of thingy
                                # It adds to the valid entities instead of the
                                # valid sub-entities.
                                # We do this when we find a CHOOSE but we do not
                                # know what it is for.
                                for my $sub_type ( split '\|', $1 ) {
                                        $valid_entities{'FEAT'}{"$feat_name($sub_type)"}  = $1;
                                        $valid_entities{'FEAT'}{"$feat_name ($sub_type)"} = $1;
                                }
                        }
                }
        }
        elsif ( $linetype eq "EQUIPMOD" ) {

                # We keep track of the KEYs for the equipmods.
                if ( exists $line_ref->{'KEY'} ) {

                        # The KEY tag should only have one value and there should always be only
                        # one KEY tag by EQUIPMOD line.

                        # We extract the key name
                        my ($key) = ( $line_ref->{'KEY'}[0] =~ /KEY:(.*)/ );

                        if ($key) {
                                $valid_entities{"EQUIPMOD Key"}{$key}++;
                        }
                        else {
                                $logging->warning(
                                        qq(Could not parse the KEY in "$line_ref->{'KEY'}[0]"),
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                }
                else {
                        # [ 1368562 ] .FORGET / .MOD don\'t need KEY entries
                        my $report_tag = $line_ref->{$columnWithNoTag{'EQUIPMOD'}[0]}[0];
                        if ($report_tag =~ /.FORGET$|.MOD$/) {
                        }
                        else {
                                $logging->info(
                                qq(No KEY tag found for "$report_tag"),
                                $file_for_error,
                                $line_for_error
                                );
                        }
                }
                if ( exists $line_ref->{'CHOOSE'} ) {               # [ 1870825 ] EqMod CHOOSE Changes
                        my $choose = $line_ref->{'CHOOSE'}[0];
                        my $eqmod_name = $line_ref->{'000ModifierName'}[0];
                        $eqmod_name =~ s/.MOD$//;
                        if ( $choose =~ /^CHOOSE:(NUMBER[^|]*)/ ) {
                        # Valid: CHOOSE:NUMBER|MIN=1|MAX=99129342|TITLE=Whatever
                        # Valid: CHOOSE:NUMBER|1|2|3|4|5|6|7|8|TITLE=Whatever
                        # Valid: CHOOSE:NUMBER|MIN=1|MAX=99129342|INCREMENT=5|TITLE=Whatever
                        # Valid: CHOOSE:NUMBER|MAX=99129342|INCREMENT=5|MIN=1|TITLE=Whatever
                        # Only testing for TITLE= for now.
                                # Test for TITLE= and warn if not present.
                                if ( $choose !~ /(TITLE[=])/ ) {
                                        $logging->info(
                                        qq(TITLE= is missing in CHOOSE:NUMBER for "$choose"),
                                        $file_for_error,
                                        $line_for_error
                                        );
                                }
                        }
                        # Only CHOOSE:NOCHOICE is Valid
                        elsif ( $choose =~ /^CHOOSE:NOCHOICE/ ) {
                        }
                        # CHOOSE:STRING|Foo|Bar|Monkey|Poo|TITLE=these are choices
                        elsif ( $choose =~ /^CHOOSE:?(STRING)[^|]*/ ) {
                                # Test for TITLE= and warn if not present.
                                if ( $choose !~ /(TITLE[=])/ ) {
                                        $logging->info(
                                        qq(TITLE= is missing in CHOOSE:STRING for "$choose"),
                                        $file_for_error,
                                        $line_for_error
                                        );
                                }
                        }
                        # CHOOSE:STATBONUS|statname|MIN=2|MAX=5|TITLE=Enhancement Bonus
                        # Statname is what I'd want to check to verify against the defined stats, but since it is optional....
                        elsif ( $choose =~ /^CHOOSE:?(STATBONUS)[^|]*/ ) {
#                               my $checkstat = $choose;
#                               $checkstat =~ s/(CHOOSE:STATBONUS)// ;
#                               $checkstat =~ s/[|]MIN=[-]?\d+\|MAX=\d+\|TITLE=.*//;
                        }
                        elsif ( $choose =~ /^CHOOSE:?(SKILLBONUS)[^|]*/ ) {
                        }
                        elsif ( $choose =~ /^CHOOSE:?(SKILL)[^|]*/ ) {
                                if ( $choose !~ /(TITLE[=])/ ) {
                                        $logging->info(
                                        qq(TITLE= is missing in CHOOSE:SKILL for "$choose"),
                                        $file_for_error,
                                        $line_for_error
                                        );
                                }
                        }
                        elsif ( $choose =~ /^CHOOSE:?(EQBUILDER.SPELL)[^|]*/ ) {
                        }
                        elsif ( $choose =~ /^CHOOSE:?(EQBUILDER.EQTYPE)[^|]*/ ) {
                        }
                        # If not above, invaild CHOOSE for equipmod files.
                        else {
                                        $logging->warning(
                                        qq(Invalid CHOOSE for Equipmod spells for "$choose"),
                                        $file_for_error,
                                        $line_for_error
                                        );
                        }
                }
        }
        elsif ( $linetype eq "CLASS" ) {

                # [ 876536 ] All spell casting classes need CASTERLEVEL
                #
                # If SPELLTYPE is present and BONUS:CASTERLEVEL is not present,
                # we warn the user.

                if ( exists $line_ref->{'SPELLTYPE'} && !exists $line_ref->{'BONUS:CASTERLEVEL'} ) {
                        $logging->info(
                                qq{Missing BONUS:CASTERLEVEL for "$line_ref->{$columnWithNoTag{'CLASS'}[0]}[0]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
        }
                elsif ( $linetype eq "CLASS" ) {

                # [ 876536 ] All spell casting classes need CASTERLEVEL
                #
                # If SPELLTYPE is present and BONUS:CASTERLEVEL is not present,
                # we warn the user.

                if ( exists $line_ref->{'FACT:SPELLTYPE'} && !exists $line_ref->{'BONUS:CASTERLEVEL'} ) {
                        $logging->info(
                                qq{Missing BONUS:CASTERLEVEL for "$line_ref->{$columnWithNoTag{'CLASS'}[0]}[0]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
        }

        elsif ( $linetype eq 'SKILL' ) {

                # We must identify the skills that have sub-entity e.g. Speak Language (Infernal)

                if ( exists $line_ref->{'CHOOSE'} ) {

                        # The CHOSE type tells us the type of sub-entities
                        my $choose      = $line_ref->{'CHOOSE'}[0];
                        my $skill_name = $line_ref->{'000SkillName'}[0];
                        $skill_name =~ s/.MOD$//;

                        if ( $choose =~ /^CHOOSE:(?:NUMCHOICES=\d+\|)?Language/ ) {
                                $valid_sub_entities{'SKILL'}{$skill_name} = 'LANGUAGE';
                        }
                }
        }
}

1;

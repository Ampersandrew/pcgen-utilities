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

# File handles for the Export Lists
my %filehandle_for;

my %headings = (
   'Category CrossRef'  => "Category cross-reference problems found\n",
   'Created'            => "List of files that were created in the directory\n",
   'CrossRef'           => "Cross-reference problems found\n",
   'Type CrossRef'      => "Type cross-reference problems found\n",
   'LST'                => "Messages generated while parsing the .LST files\n",
   'Missing'            => "List of files used in a .PCC that do not exist\n",
   'PCC'                => "Messages generated while parsing the .PCC files\n",
   'System'             => "Messages generated while parsing the system files\n",
   'Unreferenced'       => "List of files that are not referenced by any .PCC files\n",
);

# Valid filetype are the only ones that will be parsed
# Some filetype are valid but not parsed yet (no function name)
my %validfiletype = (
   'ABILITY'         => \&FILETYPE_parse,
   'ABILITYCATEGORY' => \&FILETYPE_parse,
   'BIOSET'          => \&FILETYPE_parse,
   'CLASS'           => \&FILETYPE_parse,
   'COMPANIONMOD'    => \&FILETYPE_parse,
   'DEITY'           => \&FILETYPE_parse,
   'DOMAIN'          => \&FILETYPE_parse,
   'EQUIPMENT'       => \&FILETYPE_parse,
   'EQUIPMOD'        => \&FILETYPE_parse,
   'FEAT'            => \&FILETYPE_parse,
   'INFOTEXT'        => 0,
   'KIT'             => \&FILETYPE_parse,
   'LANGUAGE'        => \&FILETYPE_parse,
   'LSTEXCLUDE'      => 0,
   'PCC'             => 1,
   'RACE'            => \&FILETYPE_parse,
   'SKILL'           => \&FILETYPE_parse,
   'SOURCELONG'      => 0,
   'SOURCESHORT'     => 0,
   'SOURCEWEB'       => 0,
   'SOURCEDATE'      => 0,
   'SOURCELINK'      => 0,
   'SPELL'           => \&FILETYPE_parse,
   'TEMPLATE'        => \&FILETYPE_parse,
   'WEAPONPROF'      => \&FILETYPE_parse,
   'ARMORPROF'       => \&FILETYPE_parse,
   'SHIELDPROF'      => \&FILETYPE_parse,
   'VARIABLE'        => \&FILETYPE_parse,
   'DATACONTROL'     => \&FILETYPE_parse,
   'GLOBALMOD'       => \&FILETYPE_parse,
   '#EXTRAFILE'      => 1,
   'SAVE'            => \&FILETYPE_parse,
   'STAT'            => \&FILETYPE_parse,
   'ALIGNMENT'       => \&FILETYPE_parse,
);

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

# List of default for values defined in system files
my @valid_system_alignments = qw(LG LN LE NG TN NE CG CN CE NONE Deity);

my @valid_system_check_names = qw(Fortitude Reflex Will);

my @valid_system_game_modes  = ( 
   # Main PCGen Release
   qw(35e 3e Deadlands Darwins_World_2 FantasyCraft Gaslight Killshot LoE Modern
   Pathfinder Sidewinder Spycraft Xcrawl OSRIC),
   
   # Third Party/Homebrew Support
   qw(DnD CMP_D20_Fantasy_v30e CMP_D20_Fantasy_v35e CMP_D20_Fantasy_v35e_Kalamar
   CMP_D20_Modern CMP_DnD_Blackmoor CMP_DnD_Dragonlance CMP_DnD_Eberron
   CMP_DnD_Forgotten_Realms_v30e CMP_DnD_Forgotten_Realms_v35e
   CMP_DnD_Oriental_Adventures_v30e CMP_DnD_Oriental_Adventures_v35e CMP_HARP
   SovereignStoneD20) );

# This meeds replaced, we should be getting this information from the STATS file.
my @valid_system_stats          = qw(
   STR DEX CON INT WIS CHA NOB FAM PFM
   
   DVR WEA AGI QUI SDI REA INS PRE
);

my @valid_system_var_names      = qw(
   ACTIONDICE                    ACTIONDIEBONUS          ACTIONDIETYPE
   Action                        ActionLVL               BUDGETPOINTS
   CURRENTVEHICLEMODS            ClassDefense            DamageThreshold
   EDUCATION                     EDUCATIONMISC           FAVORCHECK
   FIGHTINGDEFENSIVELYAC         FightingDefensivelyAC   FightingDefensivelyACBonus
   GADGETPOINTS                  INITCOMP                INSPIRATION
   INSPIRATIONMISC               LOADSCORE               MAXLEVELSTAT
   MAXVEHICLEMODS                MISSIONBUDGET           MUSCLE
   MXDXEN                        NATIVELANGUAGES         NORMALMOUNT
   OFFHANDLIGHTBONUS             PSIONLEVEL              Reputation
   TWOHANDDAMAGEDIVISOR          TotalDefenseAC          TotalDefenseACBonus
   UseAlternateDamage            VEHICLECRUISINGMPH      VEHICLEDEFENSE
   VEHICLEHANDLING               VEHICLEHARDNESS         VEHICLESPEED
   VEHICLETOPMPH                 VEHICLEWOUNDPOINTS      Wealth
   CR                            CL                      ECL
   SynergyBonus                  NoTypeProficiencies     NormalMount
   CHOICE                        BAB                     NormalFollower

   Action                        ActionLVL               ArmorQui
   ClassDefense                  DamageThreshold         DenseMuscle
   FIGHTINGDEFENSIVELYACBONUS    Giantism                INITCOMP
   LOADSCORE                     MAXLEVELSTAT            MUSCLE
   MXDXEN                        Mount                   OFFHANDLIGHTBONUS
   TOTALDEFENSEACBONUS           TWOHANDDAMAGEDIVISOR

   ACCHECK                       ARMORACCHECK            BASESPELLSTAT
   CASTERLEVEL                   INITIATIVEMISC          INITIATIVEMOD
   MOVEBASE                      SHIELDACCHECK           SIZE
   SKILLRANK                     SKILLTOTAL              SPELLFAILURE
   SR                            TL                      LIST
   MASTERVAR                     APPLIEDAS
);

# Valid check name
my %valid_check_name = map { $_ => 1} @valid_system_check_names, '%LIST', '%CHOICE';

# Valid game type (for the .PCC files)
my %valid_game_modes = map { $_ => 1 } (
   @valid_system_game_modes,

   # CMP game modes
   'CMP_OGL_Arcana_Unearthed',
   'CMP_DnD_Blackmoor',
   'CMP_DnD_Dragonlance',
   'CMP_DnD_Eberron',
   'CMP_DnD_Forgotten_Realms_v30e',
   'CMP_DnD_Forgotten_Realms_v35e',
   'CMP_HARP',
   'CMP_D20_Modern',
   'CMP_DnD_Oriental_Adventures_v30e',
   'CMP_DnD_Oriental_Adventures_v35e',
   'CMP_D20_Fantasy_v30e',
   'CMP_D20_Fantasy_v35e',
   'CMP_D20_Fantasy_v35e_Kalamar',
   'DnD_v3.5e_VPWP',
   'CMP_D20_Fantasy_v35e_VPWP',
   '4e',
   '5e',
   'DnDNext',
   'AE',
   'Arcana_Evolved',
   'Dragon_Age',
   'MC_WoD',
   'MutantsAndMasterminds3e',
   'Starwars_SE',
   'SWSE',
   'Starwars_Edge',
   'T20',
   'Traveller20',
);

# Limited choice tags
my %tag_fix_value = (
   ACHECK               => { YES => 1, NO => 1, WEIGHT => 1, PROFICIENT => 1, DOUBLE => 1 },
   ALIGN                => { map { $_ => 1 } @valid_system_alignments },
   APPLY                => { INSTANT => 1, PERMANENT => 1 },
   BONUSSPELLSTAT       => { map { $_ => 1 } ( @valid_system_stats, 'NONE' ) },
   DESCISIP             => { YES => 1, NO => 1 },
   EXCLUSIVE            => { YES => 1, NO => 1 },
   FORMATCAT            => { FRONT => 1, MIDDLE => 1, PARENS => 1 },       # [ 1594671 ] New tag: equipmod FORMATCAT
   FREE                 => { YES => 1, NO => 1 },
   KEYSTAT              => { map { $_ => 1 } @valid_system_stats },
   HASSUBCLASS          => { YES => 1, NO => 1 },
   ALLOWBASECLASS       => { YES => 1, NO => 1 },
   HASSUBSTITUTIONLEVEL => { YES => 1, NO => 1 },
   ISD20                => { YES => 1, NO => 1 },
   ISLICENSED           => { YES => 1, NO => 1 },
   ISOGL                => { YES => 1, NO => 1 },
   ISMATURE             => { YES => 1, NO => 1 },
   MEMORIZE             => { YES => 1, NO => 1 },
   MULT                 => { YES => 1, NO => 1 },
   MODS                 => { YES => 1, NO => 1, REQUIRED => 1 },
   MODTOSKILLS          => { YES => 1, NO => 1 },
   NAMEISPI             => { YES => 1, NO => 1 },
   RACIAL               => { YES => 1, NO => 1 },
   REMOVABLE            => { YES => 1, NO => 1 },
   RESIZE               => { YES => 1, NO => 1 },                          # [ 1956719 ] Add RESIZE tag to Equipment file
   PREALIGN             => { map { $_ => 1 } @valid_system_alignments }, 
   PRESPELLBOOK         => { YES => 1, NO => 1 },
   SHOWINMENU           => { YES => 1, NO => 1 },                          # [ 1718370 ] SHOWINMENU tag missing for PCC files
   STACK                => { YES => 1, NO => 1 },
   SPELLBOOK            => { YES => 1, NO => 1 },
   SPELLSTAT            => { map { $_ => 1 } ( @valid_system_stats, 'SPELL', 'NONE', 'OTHER' ) },
   TIMEUNIT             => { map { $_ => 1 } qw( Year Month Week Day Hour Minute Round Encounter Charges ) },
   USEUNTRAINED         => { YES => 1, NO => 1 },
   USEMASTERSKILL       => { YES => 1, NO => 1 },
   #[ 1593907 ] False warning: Invalid value "CSHEET" for tag "VISIBLE"
   VISIBLE              => { map { $_ => 1 } qw( YES NO EXPORT DISPLAY QUALIFY CSHEET GUI ALWAYS ) },
);

# This hash is used to convert 1 character choices to proper fix values.
my %tag_proper_value_for = (
   'Y'     =>  'YES',
   'N'     =>  'NO',
   'W'     =>  'WEIGHT',
   'Q'     =>  'QUALIFY',
   'P'     =>  'PROFICIENT',
   'R'     =>  'REQUIRED',
   'true'  =>  'YES',
   'false' =>  'NO',
);

my %source_tags               = ()  if Pretty::Options::isConversionActive('SOURCE line replacement');
my $source_curent_file        = q{} if Pretty::Options::isConversionActive('SOURCE line replacement');
                                       
my %classskill_files          = ()  if Pretty::Options::isConversionActive('CLASSSKILL conversion to CLASS');
                                       
my %classspell_files          = ()  if Pretty::Options::isConversionActive('CLASSSPELL conversion to SPELL');
                                       
my %class_files               = ()  if Pretty::Options::isConversionActive('SPELL:Add TYPE tags');
my %class_spelltypes          = ()  if Pretty::Options::isConversionActive('SPELL:Add TYPE tags');
                                       
my %Spells_For_EQMOD          = ()  if Pretty::Options::isConversionActive('EQUIPMENT: generate EQMOD');
my %Spell_Files               = ()  if Pretty::Options::isConversionActive('EQUIPMENT: generate EQMOD') || 
                                        Pretty::Options::isConversionActive('CLASS: SPELLLIST from Spell.MOD');

my %bonus_prexxx_tag_report   = ()  if Pretty::Options::isConversionActive('Generate BONUS and PRExxx report');

my %PREALIGN_conversion_5715  = qw(
        0       LG
        1       LN
        2       LE
        3       NG
        4       TN
        5       NE
        6       CG
        7       CN
        8       CE
        9       NONE
        10      Deity
) if Pretty::Options::isConversionActive('ALL:PREALIGN conversion');

my %Key_conversion_56 = qw(
        BIND            BLIND
) if Pretty::Options::isConversionActive('ALL:EQMOD has new keys');
#       ABENHABON       BNS_ENHC_AB
#       ABILITYMINUS    BNS_ENHC_AB
#       ABILITYPLUS     BNS_ENHC_AB
#       ACDEFLBON       BNS_AC_DEFL
#       ACENHABON       BNS_ENHC_AC
#       ACINSIBON       BNS_AC_INSI
#       ACLUCKBON       BNS_AC_LUCK
#       ACOTHEBON       BNS_AC_OTHE
#       ACPROFBON       BNS_AC_PROF
#       ACSACRBON       BNS_AC_SCRD
#       ADAARH          ADAM
#       ADAARH          ADAM
#       ADAARL          ADAM
#       ADAARM          ADAM
#       ADAWE           ADAM
#       AMINAT          ANMATD
#       AMMO+1          PLUS1W
#       AMMO+2          PLUS2W
#       AMMO+3          PLUS3W
#       AMMO+4          PLUS4W
#       AMMO+5          PLUS5W
#       AMMODARK        DARK
#       AMMOSLVR        SLVR
#       ARFORH          FRT_HVY
#       ARFORL          FRT_LGHT
#       ARFORM          FRT_MOD
#       ARMFOR          FRT_LGHT
#       ARMFORH         FRT_HVY
#       ARMFORM         FRT_MOD
#       ARMORENHANCE    BNS_ENHC_AC
#       ARMR+1          PLUS1A
#       ARMR+2          PLUS2A
#       ARMR+3          PLUS3A
#       ARMR+4          PLUS4A
#       ARMR+5          PLUS5A
#       ARMRADMH        ADAM
#       ARMRADML        ADAM
#       ARMRADMM        ADAM
#       ARMRMITH        MTHRL
#       ARMRMITL        MTHRL
#       ARMRMITM        MTHRL
#       ARWCAT          ARW_CAT
#       ARWDEF          ARW_DEF
#       BANEA           BANE_A
#       BANEM           BANE_M
#       BANER           BANE_R
#       BASHH           BASH_H
#       BASHL           BASH_L
#       BIND            BLIND
#       BONSPELL        BNS_SPELL
#       BONUSSPELL      BNS_SPELL
#       BRIENAI         BRI_EN_A
#       BRIENM          BRI_EN_M
#       BRIENT          BRI_EN_T
#       CHAOSA          CHAOS_A
#       CHAOSM          CHAOS_M
#       CHAOSR          CHAOS_R
#       CLDIRNAI        CIRON
#       CLDIRNW         CIRON
#       DAGSLVR         SLVR
#       DEFLECTBONUS    BNS_AC_DEFL
#       DRGNAR          DRACO
#       DRGNSH          DRACO
#       DRKAMI          DARK
#       DRKSH           DARK
#       DRKWE           DARK
#       ENBURM          EN_BUR_M
#       ENBURR          EN_BUR_R
#       ENERGM          ENERG_M
#       ENERGR          ENERG_R
#       FLAMA           FLM_A
#       FLAMM           FLM_M
#       FLAMR           FLM_R
#       FLBURA          FLM_BR_A
#       FLBURM          FLM_BR_M
#       FLBURR          FLM_BR_R
#       FROSA           FROST_A
#       FROSM           FROST_M
#       FROSR           FROST_R
#       GHTOUA          GHOST_A
#       GHTOUAM         GHOST_AM
#       GHTOUM          GHOST_M
#       GHTOUR          GHOST_R
#       HCLDIRNW        CIRON/2
#       HOLYA           HOLY_A
#       HOLYM           HOLY_M
#       HOLYR           HOLY_R
#       ICBURA          ICE_BR_A
#       ICBURM          ICE_BR_M
#       ICBURR          ICE_BR_R
#       LAWA            LAW_A
#       LAWM            LAW_M
#       LAWR            LAW_R
#       LUCKBONUS       BNS_SAV_LUC
#       LUCKBONUS2      BNS_SKL_LCK
#       MERCA           MERC_A
#       MERCM           MERC_M
#       MERCR           MERC_R
#       MICLE           MI_CLE
#       MITHAMI         MTHRL
#       MITHARH         MTHRL
#       MITHARL         MTHRL
#       MITHARM         MTHRL
#       MITHGO          MTHRL
#       MITHSH          MTHRL
#       MITHWE          MTHRL
#       NATENHA         BNS_ENHC_NAT
#       NATURALARMOR    BNS_ENHC_NAT
#       PLUS1AM         PLUS1W
#       PLUS1AMI        PLUS1W
#       PLUS1WI         PLUS1W
#       PLUS2AM         PLUS2W
#       PLUS2AMI        PLUS2W
#       PLUS2WI         PLUS2W
#       PLUS3AM         PLUS3W
#       PLUS3AMI        PLUS3W
#       PLUS3WI         PLUS3W
#       PLUS4AM         PLUS4W
#       PLUS4AMI        PLUS4W
#       PLUS4WI         PLUS4W
#       PLUS5AM         PLUS5W
#       PLUS5AMI        PLUS5W
#       PLUS5WI         PLUS5W
#       RESIMP          RST_IMP
#       RESIST          RST_IST
#       RESISTBONUS     BNS_SAV_RES
#       SAVINSBON       BNS_SAV_INS
#       SAVLUCBON       BNS_SAV_LUC
#       SAVOTHBON       BNS_SAV_OTH
#       SAVPROBON       BNS_SAV_PRO
#       SAVRESBON       BNS_SAV_RES
#       SAVSACBON       BNS_SAV_SAC
#       SE50CST         SPL_CHRG
#       SECW            SPL_CMD
#       SESUCAMA        A_1USEMI
#       SESUCAME        A_1USEMI
#       SESUCAMI        A_1USEMI
#       SESUCDMA        D_1USEMI
#       SESUCDME        D_1USEMI
#       SESUCDMI        D_1USEMI
#       SESUUA          SPL_1USE
#       SEUA            SPL_ACT
#       SE_1USEACT      SPL_1USE
#       SE_50TRIGGER    SPL_CHRG
#       SE_COMMANDWORD  SPL_CMD
#       SE_USEACT       SPL_ACT
#       SHBURA          SHK_BR_A
#       SHBURM          SHK_BR_M
#       SHBURR          SHK_BR_R
#       SHDGRT          SHDW_GRT
#       SHDIMP          SHDW_IMP
#       SHDOW           SHDW
#       SHFORH          FRT_HVY
#       SHFORL          FRT_LGHT
#       SHFORM          FRT_MOD
#       SHLDADAM        ADAM
#       SHLDDARK        DARK
#       SHLDMITH        MTHRL
#       SHOCA           SHOCK_A
#       SHOCM           SHOCK_M
#       SHOCR           SHOCK_R
#       SKILLBONUS      BNS_SKL_CIR
#       SKILLBONUS2     BNS_SKL_CMP
#       SKLCOMBON       BNS_SKL_CMP
#       SLICK           SLK
#       SLKGRT          SLK_GRT
#       SLKIMP          SLK_IMP
#       SLMV            SLNT_MV
#       SLMVGRT         SLNT_MV_GRT
#       SLMVIM          SLNT_MV_IM
#       SLVRAMI         ALCHM
#       SLVRWE1         ALCHM
#       SLVRWE2         ALCHM
#       SLVRWEF         ALCHM
#       SLVRWEH         ALCHM/2
#       SLVRWEL         ALCHM
#       SPELLRESI       BNS_SPL_RST
#       SPELLRESIST     BNS_SPL_RST
#       SPLRES          SPL_RST
#       SPLSTR          SPL_STR
#       THNDRA          THNDR_A
#       THNDRM          THNDR_M
#       THNDRR          THNDR_R
#       UNHLYA          UNHLY_A
#       UNHLYM          UNHLY_M
#       UNHLYR          UNHLY_R
#       WEAP+1          PLUS1W
#       WEAP+2          PLUS2W
#       WEAP+3          PLUS3W
#       WEAP+4          PLUS4W
#       WEAP+5          PLUS5W
#       WEAPADAM        ADAM
#       WEAPDARK        DARK
#       WEAPMITH        MTHRL
#       WILDA           WILD_A
#       WILDS           WILD_S
#) if Pretty::Options::isConversionActive('ALL:EQMOD has new keys');

if (Pretty::Options::isConversionActive('ALL:EQMOD has new keys')) {
   my ($old_key,$new_key);
   while (($old_key,$new_key) = each %Key_conversion_56)
   {
      if($old_key eq $new_key) {
         print "==> $old_key\n";
         delete $Key_conversion_56{$old_key};
      }
   }
}

my %srd_weapon_name_conversion_433 = (
   q{Sword (Great)}                 => q{Greatsword},
   q{Sword (Long)}                  => q{Longsword},
   q{Dagger (Venom)}                => q{Venom Dagger},
   q{Dagger (Assassin's)}           => q{Assassin's Dagger},
   q{Mace (Smiting)}                => q{Mace of Smiting},
   q{Mace (Terror)}                 => q{Mace of Terror},
   q{Greataxe (Life-Drinker)}       => q{Life Drinker},
   q{Rapier (Puncturing)}           => q{Rapier of Puncturing},
   q{Scimitar (Sylvan)}             => q{Sylvan Scimitar},
   q{Sword (Flame Tongue)}          => q{Flame Tongue},
   q{Sword (Planes)}                => q{Sword of the Planes},
   q{Sword (Luck Blade)}            => q{Luck Blade},
   q{Sword (Subtlety)}              => q{Sword of Subtlety},
   q{Sword (Holy Avenger)}          => q{Holy Avenger},
   q{Sword (Life Stealing)}         => q{Sword of Life Stealing},
   q{Sword (Nine Lives Stealer)}    => q{Nine Lives Stealer},
   q{Sword (Frost Brand)}           => q{Frost Brand},
   q{Trident (Fish Command)}        => q{Trident of Fish Command},
   q{Trident (Warning)}             => q{Trident of Warning},
   q{Warhammer (Dwarven Thrower)}   => q{Dwarven Thrower},
) if Pretty::Options::isConversionActive('ALL: 4.3.3 Weapon name change');


# Constants for master_line_type

# Line importance (Mode)
use constant MAIN          => 1;      # Main line type for the file
use constant SUB           => 2;      # Sub line type, must be linked to a MAIN
use constant SINGLE        => 3;      # Idependant line type
use constant COMMENT       => 4;      # Comment or empty line.

# Line formatting option
use constant LINE          => 1;   # Every line formatted by itself
use constant BLOCK         => 2;   # Lines formatted as a block
use constant FIRST_COLUMN  => 3;   # Only the first column of the block
                                                 # gets aligned

# Line header option
use constant NO_HEADER     => 1;   # No header
use constant LINE_HEADER   => 2;   # One header before each line
use constant BLOCK_HEADER  => 3;   # One header for the block

# Standard YES NO constants
use constant NO  => 0;
use constant YES => 1;

# Working variables

my %token_ADD_tag = map { $_ => 1 } (
        'ADD:.CLEAR',
        'ADD:CLASSSKILLS',
        'ADD:DOMAIN',
        'ADD:EQUIP',
        'ADD:FAVOREDCLASS',
        'ADD:FEAT',                     # Deprecated
        'ADD:FORCEPOINT',               # Deprecated, never heard of this!
        'ADD:INIT',                     # Deprecated
        'ADD:LANGUAGE',
        'ADD:SAB',
        'ADD:SPECIAL',          # Deprecated - Remove 5.16 - Special abilities are now set using hidden feats or Abilities.
        'ADD:SPELLCASTER',
        'ADD:SKILL',
        'ADD:TEMPLATE',
        'ADD:WEAPONPROFS',
        'ADD:VFEAT',            # Deprecated
);

my %token_BONUS_tag = map { $_ => 1 } (
        'ABILITYPOOL',
        'CASTERLEVEL',
        'CHECKS',               # Deprecated
        'COMBAT',
        'CONCENTRATION',
        'DAMAGE',               # Deprecated 4.3.8 - Remove 5.16.0 - Use BONUS:COMBAT|DAMAGE.x|y
        'DC',
        'DOMAIN',
        'DR',
        'EQM',
        'EQMARMOR',
        'EQMWEAPON',
        'ESIZE',                # Not listed in the Docs
        'FEAT',         # Deprecated
        'FOLLOWERS',
        'HD',
        'HP',
        'ITEMCOST',
        'LANGUAGES',    # Not listed in the Docs
        'MISC',
        'MONSKILLPTS',
        'MOVE',         # Deprecated 4.3.8 - Remove 5.16.0 - Use BONUS:MOVEADD or BONUS:POSTMOVEADD
        'MOVEADD',
        'MOVEMULT',
        'POSTRANGEADD',
        'POSTMOVEADD',
        'PCLEVEL',
        'RANGEADD',
        'RANGEMULT',
        'REPUTATION',   # Not listed in the Docs
        'SIZEMOD',
        'SAVE',
        'SKILL',
        'SITUATION',
        'SKILLPOINTS',
        'SKILLPOOL',
        'SKILLRANK',
        'SLOTS',
        'SPELL',
        'SPECIALTYSPELLKNOWN',
        'SPELLCAST',
        'SPELLCASTMULT',
        'SPELLKNOWN',
        'VISION',
        'STAT',
        'TOHIT',                # Deprecated 5.3.12 - Remove 5.16.0 - Use BONUS:COMBAT|TOHIT|x
        'UDAM',
        'VAR',
        'WEAPON',
        'WEAPONPROF',
        'WIELDCATEGORY',
);

my %token_PROFICIENCY_tag = map { $_ => 1 } (
        'WEAPON',
        'ARMOR',
        'SHIELD',
);

my %token_QUALIFY_tag = map { $_ => 1 } (
        'ABILITY',
        'CLASS',
        'DEITY',
        'DOMAIN',
        'EQUIPMENT',
        'EQMOD',
        'FEAT',         # Deprecated
        'RACE',
        'SPELL',
        'SKILL',
        'TEMPLATE',
        'WEAPONPROF',
);

my %token_BONUS_MONSKILLPTS_types = map { $_ => 1 } (
        'LOCKNUMBER',
);

# List of types that are valid in BONUS:SLOTS
# 
my %token_BONUS_SLOTS_types = map { $_ => 1 } (
        'AMULET',
        'ARMOR',
        'BELT',
        'BOOT',
        'BRACER',
        'CAPE',
        'CLOTHING',
        'EYEGEAR',
        'GLOVE',
        'HANDS',
        'HEADGEAR',
        'LEGS',
        'PSIONICTATTOO',
        'RING',
        'ROBE',
        'SHIELD',
        'SHIRT',
        'SUIT',
        'TATTOO',
        'TRANSPORTATION',
        'VEHICLE',
        'WEAPON',

        # Special value for the CHOOSE tag
        'LIST',
);

# [ 832171 ] AUTO:* needs to be separate tags
my @token_AUTO_tag = (
        'ARMORPROF',
        'EQUIP',
        'FEAT',         # Deprecated
        'LANG',
        'SHIELDPROF',
        'WEAPONPROF',
);

# Add the CHOOSE type.
# CHOOSE:xxx will not become separate tags but we need to be able to
# validate the different CHOOSE types.
my %token_CHOOSE_tag = map { $_ => 1 } (
        'ABILITY',
        'ABILITYSELECTION',
        'ALIGNMENT',
        'ARMORPROFICIENCY',
        'CHECK',
        'CLASS',
        'DEITY',
        'DOMAIN',
        'EQBUILDER.SPELL',              # EQUIPMENT ONLY
        'EQUIPMENT',
        'FEAT',
        'FEATSELECTION',
        'LANG',
        'LANGAUTO',                             # Deprecated
        'NOCHOICE',
        'NUMBER',
        'NUMCHOICES',
        'PCSTAT',
        'RACE',
        'SCHOOLS',
        'SHIELDPROFICIENCY',
        'SIZE',
        'SKILL',
        'SKILLBONUS',
        'SPELLLEVEL',
        'SPELLS',
        'STATBONUS',                    # EQUIPMENT ONLY
        'STRING',
        'TEMPLATE',
        'USERINPUT',
        'WEAPONFOCUS',
        'WEAPONPROFICIENCY',
        'STAT',                         # Deprecated
        'WEAPONPROF',                   # Deprecated
        'WEAPONPROFS',                  # Deprecated
        'SPELLLIST',                    # Deprecated
        'SPELLCLASSES',                 # Deprecated
        'PROFICIENCY',                  # Deprecated
        'SHIELDPROF',                   # Deprecated
        'EQUIPTYPE',                    # Deprecated
        'CSKILLS',                              # Deprecated
        'HP',                                   # Deprecated 6.00 - Remove 6.02
        'CCSKILLLIST',                  # Deprecated 5.13.9 - Remove 5.16. Use CHOOSE:SKILLSNAMED instead.
        'ARMORTYPE',                    # Deprecated 
        'ARMORPROF',                    # Deprecated 5.15 - Remove 6.0
        'SKILLSNAMED',                  # Deprecated
        'SALIST',                               # Deprecated 6.00 - Remove 6.02
        'FEATADD',                              # Deprecated 5.15 - Remove 6.00
        'FEATLIST',                             # Deprecated 5.15 - Remove 6.00
        'FEATSELECT',                   # Deprecated 5.15 - Remove 6.00
);

my %valid_tags;         # Will hold the valid tags for each type of file.

my %count_tags;         # Will hold the number of each tag found (by linetype)

my %missing_headers;    # Will hold the tags that do not have defined headers
                                # for each linetype.

################################################################################
# Global variables used by the validation code

my %race_partial_match; # Will hold the portions of a race that have been matched with wildcards.
                                # For example, if Elf% has been matched (given no default Elf races).

my %valid_entities;     # Will hold the entries that may be refered
                                # by other tags
                                # Format $valid_entities{$entitytype}{$entityname}
                                # We initialise the hash with global system values
                                # that are valid but never defined in the .lst files.

my %valid_types;                # Will hold the valid types for the TYPE. or TYPE=
                                # found in different tags.
                                # Format valid_types{$entitytype}{$typename}

my %valid_categories;   # Will hold the valid categories for CATEGORY=
                                # found in abilities.
                                # [ 1671407 ] xcheck PREABILITY tag

my %valid_sub_entities; # Will hold the entities that are allowed to include
                                # a sub-entity between () in their name.
                                # e.g. Skill Focus(Spellcraft)
                                # Format: $valid_sub_entities{$entity_type}{$entity_name}
                                #               = $sub_entity_type;
                                # e.g. :  $valid_sub_entities{'FEAT'}{'Skill Focus'} = 'SKILL';

# Add pre-defined valid entities
                                for my $var_name (@valid_system_var_names) {
                                   $valid_entities{'DEFINE Variable'}{$var_name}++;
                                }

                                for my $stat (@valid_system_stats) {
                                   $valid_entities{'DEFINE Variable'}{ $stat               }++;
                                   $valid_entities{'DEFINE Variable'}{ $stat . 'SCORE' }++;
                                }
# Add the magical values 'ATWILL' fot the SPELLS tag's TIMES= component.
                                $valid_entities{'DEFINE Variable'}{ 'ATWILL' }++;
# Add the magical values 'UNLIM' fot the CONTAINS tag.
                                $valid_entities{'DEFINE Variable'}{ 'UNLIM'  }++;


################################################################################

my $tablength = 6;      # Tabulation each 6 characters

my %files_to_parse;     # Will hold the file to parse (including path)
my @lines;                      # Will hold all the lines of the file
my @modified_files;     # Will hold the name of the modified files

#####################################
# Verify if the inputpath was given


$logging->set_header(constructLoggingHeader('LST'));

my @files_to_parse_sorted = ();
my %temp_files_to_parse   = %files_to_parse;

if ( Pretty::Options::isConversionActive('SPELL:Add TYPE tags') ) {

        # The CLASS files must be put at the start of the
        # files_to_parse_sorted array in order for them
        # to be dealt with before the SPELL files.

        for my $class_file ( sort keys %class_files ) {
                push @files_to_parse_sorted, $class_file;
                delete $temp_files_to_parse{$class_file};
        }
}

if ( Pretty::Options::isConversionActive('CLASSSPELL conversion to SPELL') ) {

        # The CLASS and DOMAIN files must be put at the start of the
        # files_to_parse_sorted array in order for them
        # to be dealt with before the CLASSSPELL files.
        # The CLASSSPELL needs to be processed before the SPELL files.

        # CLASS first
        for my $filetype (qw(CLASS DOMAIN CLASSSPELL)) {
                for my $file_name ( sort keys %{ $classspell_files{$filetype} } ) {
                push @files_to_parse_sorted, $file_name;
                delete $temp_files_to_parse{$file_name};
                }
        }
}

if ( keys %Spell_Files ) {

        # The SPELL file must be loaded before the EQUIPMENT
        # in order to properly generate the EQMOD tags or do
        # the Spell.MOD conversion to SPELLLEVEL.

        for my $file_name ( sort keys %Spell_Files ) {
                push @files_to_parse_sorted, $file_name;
                delete $temp_files_to_parse{$file_name};
        }
}

if ( Pretty::Options::isConversionActive('CLASSSKILL conversion to CLASS') ) {

        # The CLASSSKILL files must be put at the start of the
        # files_to_parse_sorted array in order for them
        # to be dealt with before the CLASS files
        for my $file_name ( sort keys %classskill_files ) {
                push @files_to_parse_sorted, $file_name;
                delete $temp_files_to_parse{$file_name};
        }
}

# We sort the files that need to be parsed.
push @files_to_parse_sorted, sort keys %temp_files_to_parse;



###############################################################
# additionnal_tag_parsing
# -----------------------
#
# This function does additional parsing on each line once
# they have been seperated in tags.
#
# Most commun use is for addition, conversion or removal of tags.
#
# Paramter: $tag_name           Name of the tag (before the :)
#               $tag_value              Value of the tag (after the :)
#               $linetype               Type for the current file
#               $file_for_error   Name of the current file
#               $line_for_error   Number of the current line

sub additionnal_tag_parsing {
        my ( $tag_name, $tag_value, $linetype, $file_for_error, $line_for_error ) = @_;

        ##################################################################
        # [ 1514765 ] Conversion to remove old defaultmonster tags
        # Gawaine42 (Richard Bowers)
        # Bonuses associated with a PREDEFAULTMONSTER:Y need to be removed
        # Bonuses associated with a PREDEFAULTMONSTER:N are retained without
        #               the PREDEFAULTMONSTER:N
        if ( Pretty::Options::isConversionActive('RACE:Fix PREDEFAULTMONSTER bonuses')
                && $tag_name =~ /BONUS/ ) {
        if ($tag_value =~ /PREDEFAULTMONSTER:N/ ) {
                $_[1] =~ s/[|]PREDEFAULTMONSTER:N//;
                $logging->warning(
                        qq(Replacing "$tag_name:$tag_value" by "$_[0]:$_[1]"),
                        $file_for_error,
                        $line_for_error
                        );
        }
        }

        if ( Pretty::Options::isConversionActive('ALL:Weaponauto simple conversion')
                && $tag_name =~ /WEAPONAUTO/)
                {
                $_[0] = 'AUTO';
                $_[1] =~ s/Simple/TYPE.Simple/;
                $_[1] =~ s/Martial/TYPE.Martial/;
                $_[1] =~ s/Exotic/TYPE.Exotic/;
                $_[1] =~ s/SIMPLE/TYPE.Simple/;
                $_[1] =~ s/MARTIAL/TYPE.Martial/;
                $_[1] =~ s/EXOTIC/TYPE.Exotic/;
                $_[1] = "WEAPONPROF|$_[1]";
                $logging->warning(
                        qq(Replacing "$tag_name:$tag_value" by "$_[0]:$_[1]"),
                        $file_for_error,
                        $line_for_error
                        );
                }

        ##################################################################
        # [ 1398237 ] ALL: Convert Willpower to Will
        #
        # The BONUS:CHECKS and PRECHECKBASE tags must be converted
        #
        # BONUS:CHECKS|<list of save types>|<other tag parameters>
        # PRECHECKBASE:<number>,<list of saves>

        if ( Pretty::Options::isConversionActive('ALL:Willpower to Will') ) {
                if ( $tag_name eq 'BONUS:CHECKS' ) {
                # We split the tag parameters
                my @tag_params = split q{\|}, $tag_value;


                # The Willpower keyword must be replace only in parameter 1
                # (parameter 0 is empty since the tag_value begins by | )
                if ( $tag_params[1] =~ s{ \b Willpower \b }{Will}xmsg ) {
                        # We plug the new value in the calling parameter
                        $_[1] = join q{|}, @tag_params;

                        $logging->warning(
                                qq{Replacing "$tag_name$tag_value" by "$_[0]$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );

                }

                }
                elsif ( $tag_name eq 'PRECHECKBASE' ){
                # Since the first parameter is a number, no need to
                # split before replacing.

                # Yes, we change directly the calling parameter
                if ( $_[1] =~ s{ \b Willpower \b }{Will}xmsg ) {
                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" by "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
        }


        ##################################################################
        # We find the tags that use the word Willpower

        if ( Pretty::Options::isConversionActive('ALL:Find Willpower') && getOption('exportlist') ) {
                if ( $tag_value
                        =~ m{ \b                # Word boundary
                                Willpower       # We need to find the word Willpower
                                \b              # Word boundary
                                }xmsi
                ) {
                # We write the tag and related information to the willpower.csv file
                my $tag_separator = $tag_name =~ / : /xms ? q{} : q{:};
                my $file_name = $file_for_error;
                $file_name =~ tr{/}{\\};
                print { $filehandle_for{Willpower} }
                        qq{"$tag_name$tag_separator$tag_value","$line_for_error","$file_name"\n};
                }
        }

        ##################################################################
        # PRERACE now only accepts the format PRERACE:<number>,<race list>
        # All the PRERACE tags must be reformated to use the default way.

        if ( Pretty::Options::isConversionActive('ALL:PRERACE needs a ,') ) {
                if ( $tag_name eq 'PRERACE' || $tag_name eq '!PRERACE' ) {
                if ( $tag_value !~ / \A \d+ [,], /xms ) {
                        $_[1] = '1,' . $_[1];
                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" by "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ( index( $tag_name, 'BONUS' ) == 0 && $tag_value =~ /PRERACE:([^]|]*)/ ) {
                my $prerace_value = $1;
                if ( $prerace_value !~ / \A \d+ [,] /xms ) {

                        # There is no ',', we need to add one
                        $_[1] =~ s/ PRERACE: (?!\d) /PRERACE:1,/xmsg;

                        $logging->warning(
                                qq{Replacing "$tag_name$tag_value" by "$_[0]$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ( ( $tag_name eq 'SA' || $tag_name eq 'PREMULT' )
                && $tag_value =~ / PRERACE: ( [^]|]* ) /xms
                ) {
                my $prerace_value = $1;
                if ( $prerace_value !~ / \A \d+ [,] /xms ) {

                        # There is no ',', we need to add one
                        $_[1] =~ s/ PRERACE: (?!\d) /PRERACE:1,/xmsg;

                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" by "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
        }
        ##################################################################
        # [ 1173567 ] Convert old style PREALIGN to new style
        # PREALIGN now accept letters instead of numbers to specify alignments
        # All the PREALIGN tags must be reformated to the letters.

        if ( Pretty::Options::isConversionActive('ALL:PREALIGN conversion') ) {
                if ( $tag_name eq 'PREALIGN' || $tag_name eq '!PREALIGN' ) {
                my $new_value = join ',', map { $PREALIGN_conversion_5715{$_} || $_ } split ',',
                        $tag_value;

                if ( $tag_value ne $new_value ) {
                        $_[1] = $new_value;
                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" by "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif (index( $tag_name, 'BONUS' ) == 0
                || $tag_name eq 'SA'
                || $tag_name eq 'PREMULT' )
                {
                while ( $tag_value =~ /PREALIGN:([^]|]*)/g ) {
                        my $old_value = $1;
                        my $new_value = join ',', map { $PREALIGN_conversion_5715{$_} || $_ } split ',',
                                $old_value;

                        if ( $new_value ne $old_value ) {

                                # There is no ',', we need to add one
                                $_[1] =~ s/PREALIGN:$old_value/PREALIGN:$new_value/;
                        }
                }

                $logging->warning(
                        qq{Replacing "$tag_name$tag_value" by "$_[0]$_[1]"},
                        $file_for_error,
                        $line_for_error
                ) if $_[1] ne $tag_value;
                }
        }

        ##################################################################
        # [ 1070344 ] HITDICESIZE to HITDIE in templates.lst
        #
        # HITDICESIZE:.* must become HITDIE:.* in the TEMPLATE line types.

        if (   Pretty::Options::isConversionActive('TEMPLATE:HITDICESIZE to HITDIE')
                && $tag_name eq 'HITDICESIZE'
                && $linetype eq 'TEMPLATE'
        ) {
                # We just change the tag name, the value remains the same.
                $_[0] = 'HITDIE';
                $logging->warning(
                qq{Changing "$tag_name:$tag_value" to "$_[0]:$_[1]"},
                $file_for_error,
                $line_for_error
                );
        }

        ##################################################################
        # Remove all the PREALIGN tag from within BONUS, SA and
        # VFEAT tags.
        #
        # This is needed by my CMP friends .

        if ( Pretty::Options::isConversionActive('ALL:CMP remove PREALIGN') ) {
                if ( $tag_value =~ /PREALIGN/ ) {
                my $ponc = $tag_name =~ /:/ ? "" : ":";

                if ( $tag_value =~ /PREMULT/ ) {
                        $logging->warning(
                                qq(PREALIGN found in PREMULT, you will have to remove it yourself "$tag_name$ponc$tag_value"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                elsif ( $tag_name =~ /^BONUS/ || $tag_name eq 'SA' || $tag_name eq 'VFEAT' ) {
                        $_[1] = join( '|', grep { !/^(!?)PREALIGN/ } split '\|', $tag_value );
                        $logging->warning(
                                qq{Replacing "$tag_name$ponc$tag_value" with "$_[0]$ponc$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                else {
                        $logging->warning(
                                qq(Found PREALIGN where I was not expecting it "$tag_name$ponc$tag_value"),
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
        }

        ##################################################################
        # [ 1006285 ] Convertion MOVE:<number> to MOVE:Walk,<Number>
        #
        # All the MOVE:<number> tags must be converted to
        # MOVE:Walk,<number>

        if (   Pretty::Options::isConversionActive('ALL:MOVE:nn to MOVE:Walk,nn')
                && $tag_name eq "MOVE"
        ) {
                if ( $tag_value =~ /^(\d+$)/ ) {
                $_[1] = "Walk,$1";
                $logging->warning(
                        qq{Changing "$tag_name:$tag_value" to "$_[0]:$_[1]"},
                        $file_for_error,
                        $line_for_error
                );
                }
        }

        ##################################################################
        # [ 892746 ] KEYS entries were changed in the main files
        #
        # All the EQMOD and PRETYPE:EQMOD tags must be scanned for
        # possible KEY replacement.

        if(Pretty::Options::isConversionActive('ALL:EQMOD has new keys') &&
                ($tag_name eq "EQMOD" || $tag_name eq "REPLACES" || ($tag_name eq "PRETYPE" && $tag_value =~ /^(\d+,)?EQMOD/)))
        {
                for my $old_key (keys %Key_conversion_56)
                {
                        if($tag_value =~ /\Q$old_key\E/)
                        {
                                $_[1] =~ s/\Q$old_key\E/$Key_conversion_56{$old_key}/;
                                $logging->notice(
                                        qq(=> Replacing "$old_key" with "$Key_conversion_56{$old_key}" in "$tag_name:$tag_value"),
                                        $file_for_error,
                                        $line_for_error
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
                && $linetype eq "RACE"
                && $tag_name eq "CSKILL"
        ) {
                $logging->warning(
                qq{Found CSKILL in RACE file},
                $file_for_error,
                $line_for_error
                );
        }

        ##################################################################
        # GAMEMODE DnD is now 3e

        if (   Pretty::Options::isConversionActive('PCC:GAMEMODE DnD to 3e')
                && $tag_name  eq "GAMEMODE"
                && $tag_value eq "DnD"
        ) {
                $_[1] = "3e";
                $logging->warning(
                qq{Changing "$tag_name:$tag_value" to "$_[0]:$_[1]"},
                $file_for_error,
                $line_for_error
                );
        }

        ##################################################################
        # Add 3e to GAMEMODE:DnD_v30e and 35e to GAMEMODE:DnD_v35e

        if (   Pretty::Options::isConversionActive('PCC:GAMEMODE Add to the CMP DnD_')
                && $tag_name eq "GAMEMODE"
                && $tag_value =~ /DnD_/
        ) {
                my ( $has_3e, $has_35e, $has_DnD_v30e, $has_DnD_v35e );

#               map {
#               $has_3e = 1
#                       if $_ eq "3e";
#               $has_DnD_v30e = 1 if $_ eq "DnD_v30e";
#               $has_35e        = 1 if $_ eq "35e";
#               $has_DnD_v35e = 1 if $_ eq "DnD_v35e";
#               } split '\|', $tag_value;

                for my $game_mode (split q{\|}, $tag_value) {
                $has_3e         = 1 if $_ eq "3e";
                $has_DnD_v30e = 1 if $_ eq "DnD_v30e";
                $has_35e        = 1 if $_ eq "35e";
                $has_DnD_v35e = 1 if $_ eq "DnD_v35e";
                }

                $_[1] =~ s/(DnD_v30e)/3e\|$1/  if !$has_3e  && $has_DnD_v30e;
                $_[1] =~ s/(DnD_v35e)/35e\|$1/ if !$has_35e && $has_DnD_v35e;

                #$_[1] =~ s/(DnD_v30e)\|(3e)/$2\|$1/;
                #$_[1] =~ s/(DnD_v35e)\|(35e)/$2\|$1/;
                $logging->warning(
                qq{Changing "$tag_name:$tag_value" to "$_[0]:$_[1]"},
                $file_for_error,
                $line_for_error
                ) if "$tag_name:$tag_value" ne "$_[0]:$_[1]";
        }

        ##################################################################
        # [ 784363 ] Add TYPE=Base.REPLACE to most BONUS:COMBAT|BAB
        # The BONUS:COMBAT|BAB found in CLASS, CLASS Level,
        # SUBCLASS and SUBCLASSLEVEL lines must have a |TYPE=Base.REPLACE added to them.
        # The same BONUSes found in RACE files with PREDEFAULTMONSTER tags
        # must also have the TYPE added.
        # All the other BONUS:COMBAT|BAB should be reported since there
        # should not be any really.

        if (   Pretty::Options::isConversionActive('ALL:Add TYPE=Base.REPLACE')
                && $tag_name eq "BONUS:COMBAT"
                && $tag_value =~ /^\|(BAB)\|/i
        ) {

                # Is the BAB in uppercase ?
                if ( $1 ne 'BAB' ) {
                $_[1] =~ s/\|bab\|/\|BAB\|/i;
                $logging->warning(
                        qq{Changing "$tag_name$tag_value" to "$_[0]$_[1]" (BAB must be in uppercase)},
                        $file_for_error,
                        $line_for_error
                );
                $tag_value = $_[1];
                }

                # Is there already a TYPE= in the tag?
                my $is_type = $tag_value =~ /TYPE=/;

                # Is it the good one?
                my $is_type_base = $is_type && $tag_value =~ /TYPE=Base/;

                # Is there a .REPLACE at after the TYPE=Base?
                my $is_type_replace = $is_type_base && $tag_value =~ /TYPE=Base\.REPLACE/;

                # Is there a PREDEFAULTMONSTER tag embedded?
                my $is_predefaultmonster = $tag_value =~ /PREDEFAULTMONSTER/;

                # We must replace the CLASS, CLASS Level, SUBCLASS, SUBCLASSLEVEL
                # and PREDEFAULTMONSTER RACE lines
                if (   $linetype eq 'CLASS'
                || $linetype eq 'CLASS Level'
                || $linetype eq 'SUBCLASS'
                || $linetype eq 'SUBCLASSLEVEL'
                || ( ( $linetype eq 'RACE' || $linetype eq 'TEMPLATE' ) && $is_predefaultmonster ) )
                {
                if ( !$is_type ) {

                        # We add the TYPE= statement at the end
                        $_[1] .= '|TYPE=Base.REPLACE';
                        $logging->warning(
                                qq{Adding "|TYPE=Base.REPLACE" to "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                else {

                        # The TYPE is already there but is it the correct one?
                        if ( !$is_type_replace && $is_type_base ) {

                                # We add the .REPLACE part
                                $_[1] =~ s/\|TYPE=Base/\|TYPE=Base.REPLACE/;
                                $logging->warning(
                                qq{Adding ".REPLACE" to "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                        elsif ( !$is_type_base ) {
                                $logging->info(
                                qq{Verify the TYPE of "$tag_name$tag_value"},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                }
                }
                else {

                # If there is a BONUS:COMBAT elsewhere, we report it for manual
                # inspection.
                $logging->info(qq{Verify this tag "$tag_name$tag_value"}, $file_for_error, $line_for_error);
                }
        }

        ##################################################################
        # [ 737718 ] COUNT[FEATTYPE] data change
        # A ALL. must be added at the end of every COUNT[FEATTYPE=FooBar]
        # found in the DEFINE tags if not already there.

        if (   Pretty::Options::isConversionActive('ALL:COUNT[FEATTYPE=...')
                && $tag_name eq "DEFINE"
        ) {
                if ( $tag_value =~ /COUNT\[FEATTYPE=/i ) {
                my $value = $tag_value;
                my $new_value;
                while ( $value =~ /(.*?COUNT\[FEATTYPE=)([^\]]*)(\].*)/i ) {
                        $new_value .= $1;
                        my $count_value = $2;
                        my $remaining   = $3;

                        # We found a COUNT[FEATTYPE=, let's see if there is already
                        # a ALL keyword in it.
                        if ( $count_value !~ /^ALL\.|\.ALL\.|\.ALL$/i ) {
                                $count_value = 'ALL.' . $count_value;
                        }

                        $new_value .= $count_value;
                        $value = $remaining;

                }
                $new_value .= $value;

                if ( $new_value ne $tag_value ) {
                        $_[1] = $new_value;
                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" with "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
        }

        ##################################################################
        # PRECLASS now only accepts the format PRECLASS:1,<class>=<n>
        # All the PRECLASS tags must be reformated to use the default way.

        if ( Pretty::Options::isConversionActive('ALL:PRECLASS needs a ,') ) {
                if ( $tag_name eq 'PRECLASS' || $tag_name eq '!PRECLASS' ) {
                unless ( $tag_value =~ /^\d+,/ ) {
                        $_[1] = '1,' . $_[1];
                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" with "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ( index( $tag_name, 'BONUS' ) == 0 && $tag_value =~ /PRECLASS:([^]|]*)/ ) {
                my $preclass_value = $1;
                unless ( $preclass_value =~ /^\d+,/ ) {

                        # There is no ',', we need to add one
                        $_[1] =~ s/PRECLASS:(?!\d)/PRECLASS:1,/g;

                        $logging->warning(
                                qq{Replacing "$tag_name$tag_value" with "$_[0]$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
                elsif ( ( $tag_name eq 'SA' || $tag_name eq 'PREMULT' )
                && $tag_value =~ /PRECLASS:([^]|]*)/
                ) {
                my $preclass_value = $1;
                unless ( $preclass_value =~ /^\d+,/ ) {

                        # There is no ',', we need to add one
                        $_[1] =~ s/PRECLASS:(?!\d)/PRECLASS:1,/g;

                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" with "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
                }
        }

        ##################################################################
        # [ 711565 ] BONUS:MOVE replaced with BONUS:MOVEADD
        #
        # BONUS:MOVE must be replaced by BONUS:MOVEADD in all line types
        # except EQUIPMENT and EQUIPMOD where it most be replaced by
        # BONUS:POSTMOVEADD

        if (   Pretty::Options::isConversionActive('ALL:BONUS:MOVE conversion') && $tag_name eq 'BONUS:MOVE' ){
                if ( $linetype eq "EQUIPMENT" || $linetype eq "EQUIPMOD" ) {
                        $_[0] = "BONUS:POSTMOVEADD";
                }
                else {
                        $_[0] = "BONUS:MOVEADD";
                }

                $logging->warning(
                qq{Replacing "$tag_name$tag_value" with "$_[0]$_[1]"},
                $file_for_error,
                $line_for_error
                );
        }

        ##################################################################
        # [ 699834 ] Incorrect loading of multiple vision types
        # All the , in the VISION tags must be converted to | except for the
        # VISION:.ADD (these will be converted later to BONUS:VISION)
        #
        # [ 728038 ] BONUS:VISION must replace VISION:.ADD
        # Now doing the VISION:.ADD conversion

        if (   Pretty::Options::isConversionActive('ALL: , to | in VISION') && $tag_name eq 'VISION' ) {
                unless ( $tag_value =~ /(\.ADD,|1,)/i ) {
                        if ( $_[1] =~ tr{,}{|} ) {
                                $logging->warning(
                                        qq{Replacing "$tag_name:$tag_value" with "$_[0]:$_[1]"},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                }
        }

        ##################################################################
        # PRESTAT now only accepts the format PRESTAT:1,<stat>=<n>
        # All the PRESTAT tags must be reformated to use the default way.

        if ( Pretty::Options::isConversionActive('ALL:PRESTAT needs a ,') && $tag_name eq 'PRESTAT' ) {
                if ( index( $tag_value, ',' ) == -1 ) {
                        # There is no ',', we need to add one
                        $_[1] = '1,' . $_[1];
                        $logging->warning(
                                qq{Replacing "$tag_name:$tag_value" with "$_[0]:$_[1]"},
                                $file_for_error,
                                $line_for_error
                        );
                }
        }

        ##################################################################
        # [ 686169 ] remove ATTACKS: tag
        # ATTACKS:<attacks> must be replaced by BONUS:COMBAT|ATTACKS|<attacks>

        if ( Pretty::Options::isConversionActive('EQUIPMENT: remove ATTACKS')
                && $tag_name eq 'ATTACKS'
                && $linetype eq 'EQUIPMENT' ) {
                my $number_attacks = $tag_value;
                $_[0] = 'BONUS:COMBAT';
                $_[1] = '|ATTACKS|' . $number_attacks;

                $logging->warning(
                        qq{Replacing "$tag_name:$tag_value" with "$_[0]$_[1]"},
                        $file_for_error,
                        $line_for_error
                );
        }

        ##################################################################
        # Name change for SRD compliance (PCGEN 4.3.3)

        if (Pretty::Options::isConversionActive('ALL: 4.3.3 Weapon name change')
                && (   $tag_name eq 'WEAPONBONUS'
                || $tag_name eq 'WEAPONAUTO'
                || $tag_name eq 'PROF'
                || $tag_name eq 'GEAR'
                || $tag_name eq 'FEAT'
                || $tag_name eq 'PROFICIENCY'
                || $tag_name eq 'DEITYWEAP'
                || $tag_name eq 'MFEAT' )
        ) {
                for ( keys %srd_weapon_name_conversion_433 ) {
                        if ( $_[1] =~ s/\Q$_\E/$srd_weapon_name_conversion_433{$_}/ig ) {
                                $logging->warning(
                                        qq{Replacing "$tag_name:$tag_value" with "$_[0]:$_[1]"},
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                }
        }
}

###############################################################
# additionnal_file_parsing
# ------------------------
#
# This function does additional parsing on each file once
# they have been seperated in lines of tags.
#
# Most commun use is for addition, conversion or removal of tags.
#
# Paramter: $lines_ref  Ref to an array containing lines of tags
#               $filetype   Type for the current file
#               $filename   Name of the current file
#
#               The $line_ref entries may now be in a new format, we need to find out
#               before using it. ref($line_ref) eq 'ARRAY'means new format.
#
#               The format is: [ $curent_linetype,
#                                       \%line_tokens,
#                                       $last_main_line,
#                                       $curent_entity,
#                                       $line_info,
#                                       ];
#

{

        my %class_skill;
        my %class_spell;
        my %domain_spell;

        sub additionnal_file_parsing {
                my ( $lines_ref, $filetype, $filename ) = @_;

                ##################################################################
                # [ 779341 ] Spell Name.MOD to CLASS's SPELLLEVEL
                #

#  if(Pretty::Options::isConversionActive('CLASS: SPELLLIST from Spell.MOD'))
#  {
#       if($filetype eq 'SPELL')
#       {
#       # All the Spell Name.MOD entries must be parsed to find the
#       # CLASSES and DOMAINS tags.
#       #
#       # The .MOD lines that have no other tags then CLASSES or DOMAINS
#       # will be removed entirely.
#
#       my ($directory,$spellfile) = File::Basename::dirname($filename);
#
#       for(my $i = 0; $i < @$lines_ref; $i++)
#       {
#               # Is this a .MOD line?
#               next unless ref($lines_ref->[$i]) eq 'ARRAY' &&
#                               $lines_ref->[$i][0] eq 'SPELL';
#
#               my $is_mod = $lines_ref->[$i][3] =~ /(.*)\.MOD$/;
#               my $spellname = $is_mod ? $1 : $lines_ref->[$i][3];
#
#               # Is there a CLASSES tag?
#               if(exists $lines_ref->[$i][1]{'CLASSES'})
#               {
#               my $tag = substr($lines_ref->[$i][1]{'CLASSES'}[0],8);
#
#               # We find each group of classes of the same level
#               for (split /\|/, $tag)
#               {
#               if(/(.*)=(\d+)$/)
#               {
#                       my $level = $2;
#                       my $classes = $1;
#
#                       for my $class (split /,/, $classes)
#                       {
#                       #push @{$class_spell{
#                       }
#               }
#               else
#               {
#                       $logging->notice(  qq(!! No level were given for "$_" found in "$lines_ref->[$i][1]{'CLASSES'}[0]"),
#                       $filename,$i );
#               }
#               }
#
##              notice(  qq(**** $spellname: $_),$filename,$i for @classes_by_level );
                #               }
                #
                #               if(exists $lines_ref->[$i][1]{'DOMAINS'})
                #               {
                #               my $tag = substr($lines_ref->[$i][1]{'DOMAINS'}[0],8);
                #               my @domains_by_level = split /\|/, $tag;
                #
                #               notice(  qq(**** $spellname: $_),$filename,$i for @domains_by_level );
                #               }
                #       }
                #       }
                #  }

                ###############################################################
                # Reformat multiple lines to one line for RACE and TEMPLATE.
                #
                # This is only useful for those who like to start new entries
                # with multiple lines (for clarity) and then want them formatted
                # properly for submission.

                if ( Pretty::Options::isConversionActive('ALL:Multiple lines to one') ) {
                my %valid_line_type = (
                        'RACE'  => 1,
                        'TEMPLATE' => 1,
                );

                if ( exists $valid_line_type{$filetype} ) {
                        my $last_main_line = -1;

                        # Find all the lines with the same identifier
                        ENTITY:
                        for ( my $i = 0; $i < @{$lines_ref}; $i++ ) {

                                # Is this a linetype we are interested in?
                                if ( ref $lines_ref->[$i] eq 'ARRAY'
                                && exists $valid_line_type{ $lines_ref->[$i][0] } )
                                {
                                my $first_line = $i;
                                my $last_line  = $i;
                                my $old_length;
                                my $curent_linetype = $lines_ref->[$i][0];
                                my %new_line            = %{ $lines_ref->[$i][1] };
                                $last_main_line = $i;
                                my $entity_name  = $lines_ref->[$i][3];
                                my $line_info   = $lines_ref->[$i][4];
                                my $j           = $i + 1;
                                my $extra_entity = 0;
                                my @new_lines;

                                #Find all the line with the same entity name
                                ENTITY_LINE:
                                for ( ; $j < @{$lines_ref}; $j++ ) {

                                        # Skip empty and comment lines
                                        next ENTITY_LINE
                                                if ref( $lines_ref->[$j] ) ne 'ARRAY'
                                                || $lines_ref->[$j][0] eq 'HEADER'
                                                || ref( $lines_ref->[$j][1] ) ne 'HASH';

                                        # Is it an entity of the same name?
                                        if (   $lines_ref->[$j][0] eq $curent_linetype
                                                && $entity_name eq $lines_ref->[$j][3] )
                                        {
                                                $last_line = $j;
                                                $extra_entity++;
                                                my @validTags = Pretty::Data:getMasterOrder($curent_linetype);

                                                ITERATE_LINE_TAGS: 
                                                for my $key ( keys %{ $lines_ref->[$j][1] } ) {

                                                   # We add the tags except for the first one (the entity tag)
                                                   # that is already there.
                                                   
                                                   next ITERATE_LINE_TAGS if $key eq $validTags[0]; 

                                                   push @{ $new_line{$key} }, @{ $lines_ref->[$j][1]{$key} };
                                                }
                                        }
                                        else {
                                                last ENTITY_LINE;
                                        }
                                }

                                # If there was only one line for the entity, we do nothing
                                next ENTITY if !$extra_entity;

                                # Number of lines included in the CLASS
                                $old_length = $last_line - $first_line + 1;

                                # We prepare the replacement lines
                                $j = 0;

                                # The main line
                                if ( keys %new_line > 1 ) {
                                        push @new_lines,
                                                [
                                                $curent_linetype,
                                                \%new_line,
                                                $last_main_line,
                                                $entity_name,
                                                $line_info,
                                                ];
                                        $j++;
                                }

                                # We splice the new class lines in place
                                splice @$lines_ref, $first_line, $old_length, @new_lines;

                                # Continue with the rest
                                $i = $first_line + $j - 1;      # -1 because the $i++ happen right after
                                }
                                elsif (ref $lines_ref->[$i] eq 'ARRAY'
                                && $lines_ref->[$i][0] ne 'HEADER'
                                && defined $lines_ref->[$i][4]
                                && $lines_ref->[$i][4]{Mode} == SUB )
                                {

                                # We must replace the last_main_line with the correct value
                                $lines_ref->[$i][2] = $last_main_line;
                                }
                                elsif (ref $lines_ref->[$i] eq 'ARRAY'
                                && $lines_ref->[$i][0] ne 'HEADER'
                                && defined $lines_ref->[$i][4]
                                && $lines_ref->[$i][4]{Mode} == MAIN )
                                {

                                # We update the last_main_line value and
                                # put the correct value in the curent line
                                $lines_ref->[$i][2] = $last_main_line = $i;
                                }
                        }
                }
                }

                ###############################################################
                # [ 641912 ] Convert CLASSSPELL to SPELL
                #
                #
                # "CLASSSPELL"  => [
                #   'CLASS',
                #   'SOURCEPAGE',
                #   '#HEADER#SOURCE',
                #   '#HEADER#SOURCELONG',
                #   '#HEADER#SOURCESHORT',
                #   '#HEADER#SOURCEWEB',
                # ],
                #
                # "CLASSSPELL Level"    => [
                #   '000ClassSpellLevel',
                #   '001ClassSpells'

                if ( Pretty::Options::isConversionActive('CLASSSPELL conversion to SPELL') ) {
                if ( $filetype eq 'CLASSSPELL' ) {

                        # Here we will put aside all the CLASSSPELL that
                        # we find for later use.

                        my $dir = File::Basename::dirname($filename);

                        $logging->warning(
                                qq(Already found a CLASSSPELL file in $dir),
                                $filename
                        ) if exists $class_spell{$dir};

                        my $curent_name;
                        my $curent_type = 2;    # 0 = CLASS, 1 = DOMAIN, 2 = invalid
                        my $line_number = 1;

                        LINE:
                        for my $line (@$lines_ref) {

                                # We skip all the lines that do not begin by CLASS or a number
                                next LINE
                                if ref($line) ne 'HASH'
                                || ( !exists $line->{'CLASS'} && !exists $line->{'000ClassSpellLevel'} );

                                if ( exists $line->{'CLASS'} ) {

                                # We keep the name
                                $curent_name = ( $line->{'CLASS'}[0] =~ /CLASS:(.*)/ )[0];

                                # Is it a CLASS or a DOMAIN ?
                                if ( exists $valid_entities{'CLASS'}{$curent_name} ) {
                                        $curent_type = 0;
                                }
                                elsif ( exists $valid_entities{'DOMAIN'}{$curent_name} ) {
                                        $curent_type = 1;
                                }
                                else {
                                        $curent_type = 2;
                                        $logging->warning(
                                                qq(Don\'t know if "$curent_name" is a CLASS or a DOMAIN),
                                                $filename,
                                                $line_number
                                        );
                                }
                                }
                                else {
                                next LINE if $curent_type == 2 || !exists $line->{'001ClassSpells'};

                                # We store the CLASS name and Level

                                for my $spellname ( split '\|', $line->{'001ClassSpells'}[0] ) {
                                        push @{ $class_spell{$dir}{$spellname}[$curent_type]
                                                { $line->{'000ClassSpellLevel'}[0] } }, $curent_name;

                                }
                                }
                        }
                        continue { $line_number++; }
                }
                elsif ( $filetype eq 'SPELL' ) {
                        my $dir = File::Basename::dirname($filename);

                        if ( exists $class_spell{$dir} ) {

                                # There was a CLASSSPELL in the directory, we need to add
                                # the CLASSES and DOMAINS tag for it.

                                # First we find all the SPELL lines and add the CLASSES
                                # and DOMAINS tags if needed
                                my $line_number = 1;
                                LINE:
                                for my $line (@$lines_ref) {
                                next LINE if ref($line) ne 'ARRAY' || $line->[0] ne 'SPELL';
                                $_ = $line->[1];

                                next LINE if ref ne 'HASH' || !exists $_->{'000SpellName'};
                                my $spellname = $_->{'000SpellName'}[0];

                                if ( exists $class_spell{$dir}{$spellname} ) {
                                        if ( defined $class_spell{$dir}{$spellname}[0] ) {

                                                # We have classes
                                                # Is there already a CLASSES tag?
                                                if ( exists $_->{'CLASSES'} ) {
                                                $logging->warning(
                                                        qq(The is already a CLASSES tag for "$spellname"),
                                                        $filename,
                                                        $line_number
                                                );
                                                }
                                                else {
                                                my @new_levels;
                                                for my $level ( sort { $a <=> $b }
                                                        keys %{ $class_spell{$dir}{$spellname}[0] } )
                                                {
                                                        my $new_level = join ',',
                                                                @{ $class_spell{$dir}{$spellname}[0]{$level} };
                                                        push @new_levels, "$new_level=$level";
                                                }
                                                my $new_classes = 'CLASSES:' . join '|', @new_levels;
                                                $_->{'CLASSES'} = [$new_classes];

                                                $logging->warning(
                                                        qq{SPELL $spellname: adding "$new_classes"},
                                                        $filename,
                                                        $line_number
                                                );
                                                }
                                        }

                                        if ( defined $class_spell{$dir}{$spellname}[1] ) {

                                                # We have domains
                                                # Is there already a CLASSES tag?
                                                if ( exists $_->{'DOMAINS'} ) {
                                                $logging->warning(
                                                        qq(The is already a DOMAINS tag for "$spellname"),
                                                        $filename,
                                                        $line_number
                                                );
                                                }
                                                else {
                                                my @new_levels;
                                                for my $level ( sort { $a <=> $b }
                                                        keys %{ $class_spell{$dir}{$spellname}[1] } )
                                                {
                                                        my $new_level = join ',',
                                                                @{ $class_spell{$dir}{$spellname}[1]{$level} };
                                                        push @new_levels, "$new_level=$level";
                                                }
                                                my $new_domains = 'DOMAINS:' . join '|', @new_levels;
                                                $_->{'DOMAINS'} = [$new_domains];

                                                $logging->warning(
                                                        qq{SPELL $spellname: adding "$new_domains"},
                                                        $filename,
                                                        $line_number
                                                );
                                                }
                                        }

                                        # We remove the curent spell from the list.
                                        delete $class_spell{$dir}{$spellname};
                                }
                                }
                                continue { $line_number++; }

                                # Second, we add .MOD line for the SPELL that were not present.
                                if ( keys %{ $class_spell{$dir} } ) {

                                # Put a comment line and a new header line
                                push @$lines_ref, "",
                                        "###Block:SPELL.MOD generated from the old CLASSSPELL files";

                                for my $spellname ( sort keys %{ $class_spell{$dir} } ) {
                                        my %newline = ( '000SpellName' => ["$spellname.MOD"] );
                                        $line_number++;

                                        if ( defined $class_spell{$dir}{$spellname}[0] ) {

                                                # New CLASSES
                                                my @new_levels;
                                                for my $level ( sort { $a <=> $b }
                                                keys %{ $class_spell{$dir}{$spellname}[0] } )
                                                {
                                                my $new_level = join ',',
                                                        @{ $class_spell{$dir}{$spellname}[0]{$level} };
                                                push @new_levels, "$new_level=$level";
                                                }
                                                my $new_classes = 'CLASSES:' . join '|', @new_levels;
                                                $newline{'CLASSES'} = [$new_classes];

                                                $logging->warning(
                                                qq{SPELL $spellname.MOD: adding "$new_classes"},
                                                $filename,
                                                $line_number
                                                );
                                        }

                                        if ( defined $class_spell{$dir}{$spellname}[1] ) {

                                                # New DOMAINS
                                                my @new_levels;
                                                for my $level ( sort { $a <=> $b }
                                                keys %{ $class_spell{$dir}{$spellname}[1] } )
                                                {
                                                my $new_level = join ',',
                                                        @{ $class_spell{$dir}{$spellname}[1]{$level} };
                                                push @new_levels, "$new_level=$level";
                                                }

                                                my $new_domains = 'DOMAINS:' . join '|', @new_levels;
                                                $newline{'DOMAINS'} = [$new_domains];

                                                $logging->warning(
                                                qq{SPELL $spellname.MOD: adding "$new_domains"},
                                                $filename,
                                                $line_number
                                                );
                                        }

                                        push @$lines_ref, [
                                                'SPELL',
                                                \%newline,
                                                1 + @$lines_ref,
                                                $spellname,
                                                $master_file_type{SPELL}[1],    # Watch for the 1
                                        ];

                                }
                                }
                        }
                }
                }

                ###############################################################
                # [ 626133 ] Convert CLASS lines into 4 lines
                #
                # The 3 lines are:
                #
                # General (all tags not put in the two other lines)
                # Prereq. (all the PRExxx tags)
                # Class skills (the STARTSKILLPTS, the CKSILL and the CCSKILL tags)
                #
                # 2003.07.11: a fourth line was added for the SPELL related tags

                if (   Pretty::Options::isConversionActive('CLASS:Four lines')
                && $filetype eq 'CLASS' )
                {
                my $last_main_line = -1;

                # Find all the CLASS lines
                for ( my $i = 0; $i < @{$lines_ref}; $i++ ) {

                        # Is this a CLASS line?
                        if ( ref $lines_ref->[$i] eq 'ARRAY' && $lines_ref->[$i][0] eq 'CLASS' ) {
                                my $first_line = $i;
                                my $last_line  = $i;
                                my $old_length;
                                my %new_class_line = %{ $lines_ref->[$i][1] };
                                my %new_pre_line;
                                my %new_skill_line;
                                my %new_spell_line;
                                my %skill_tags = (
                                'CSKILL:.CLEAR' => 1,
                                CCSKILL         => 1,
                                CSKILL          => 1,
                                MODTOSKILLS             => 1,   #
                                MONSKILL                => 1,   # [ 1097487 ] MONSKILL in class.lst
                                MONNONSKILLHD   => 1,
                                SKILLLIST                       => 1,   # [ 1580059 ] SKILLLIST tag
                                STARTSKILLPTS   => 1,
                                );
                                my %spell_tags = (
                                BONUSSPELLSTAT                  => 1,
                                'BONUS:CASTERLEVEL'             => 1,
                                'BONUS:DC'                              => 1,  #[ 1037456 ] Move BONUS:DC on class line to the spellcasting portion
                                'BONUS:SCHOOL'                  => 1,
                                'BONUS:SPELL'                   => 1,
                                'BONUS:SPECIALTYSPELLKNOWN'     => 1,
                                'BONUS:SPELLCAST'                       => 1,
                                'BONUS:SPELLCASTMULT'           => 1,
                                'BONUS:SPELLKNOWN'              => 1,
                                CASTAS                          => 1,
                                ITEMCREATE                              => 1,
                                KNOWNSPELLS                             => 1,
                                KNOWNSPELLSFROMSPECIALTY        => 1,
                                MEMORIZE                                => 1,
                                HASSPELLFORMULA                 => 1, # [ 1893279 ] HASSPELLFORMULA Class Line tag
                                PROHIBITED                              => 1,
                                SPELLBOOK                               => 1,
                                SPELLKNOWN                              => 1,
                                SPELLLEVEL                              => 1,
                                SPELLLIST                               => 1,
                                SPELLSTAT                               => 1,
                                SPELLTYPE                               => 1,
                                );
                                $last_main_line = $i;
                                my $class               = $lines_ref->[$i][3];
                                my $line_info   = $lines_ref->[$i][4];
                                my $j                   = $i + 1;
                                my @new_class_lines;

                                #Find the next line that is not empty or of the same CLASS
                                CLASS_LINE:
                                for ( ; $j < @{$lines_ref}; $j++ ) {

                                # Skip empty and comment lines
                                next CLASS_LINE
                                        if ref( $lines_ref->[$j] ) ne 'ARRAY'
                                        || $lines_ref->[$j][0] eq 'HEADER'
                                        || ref( $lines_ref->[$j][1] ) ne 'HASH';

                                # Is it a CLASS line of the same CLASS?
                                if ( $lines_ref->[$j][0] eq 'CLASS' && $class eq $lines_ref->[$j][3] ) {
                                        $last_line = $j;
                                        for ( keys %{ $lines_ref->[$j][1] } ) {
                                                push @{ $new_class_line{$_} }, @{ $lines_ref->[$j][1]{$_} }
                                                if $_ ne $master_order{'CLASS'}[0];
                                        }
                                } else {
                                        last CLASS_LINE;
                                }
                                }

                                # Number of lines included in the CLASS
                                $old_length = $last_line - $first_line + 1;

                                # We build the two other lines.
                                for ( keys %new_class_line ) {

                                # Is it a SKILL tag?
                                if ( exists $skill_tags{$_} ) {
                                        $new_skill_line{$_} = delete $new_class_line{$_};
                                }

                                # Is it a PRExxx tag?
                                elsif (/^\!?PRE/
                                        || /^DEITY/ ) {
                                        $new_pre_line{$_} = delete $new_class_line{$_};
                                }

                                # Is it a SPELL tag?
                                elsif ( exists $spell_tags{$_} ) {
                                        $new_spell_line{$_} = delete $new_class_line{$_};
                                }
                                }

                                # We prepare the replacement lines
                                $j = 0;

                                # The main line
                                if ( keys %new_class_line > 1
                                || ( !keys %new_pre_line && !keys %new_skill_line && !keys %new_spell_line )
                                )
                                {
                                push @new_class_lines,
                                        [
                                        'CLASS',
                                        \%new_class_line,
                                        $last_main_line,
                                        $class,
                                        $line_info,
                                        ];
                                $j++;
                                }

                                # The PRExxx line
                                if ( keys %new_pre_line ) {

                                # Need to tell what CLASS we are dealing with
                                $new_pre_line{ $master_order{'CLASS'}[0] }
                                        = $new_class_line{ $master_order{'CLASS'}[0] };
                                push @new_class_lines,
                                        [
                                        'CLASS',
                                        \%new_pre_line,
                                        ++$last_main_line,
                                        $class,
                                        $line_info,
                                        ];
                                $j++;
                                }

                                # The skills line
                                if ( keys %new_skill_line ) {

                                # Need to tell what CLASS we are dealing with
                                $new_skill_line{ $master_order{'CLASS'}[0] }
                                        = $new_class_line{ $master_order{'CLASS'}[0] };
                                push @new_class_lines,
                                        [
                                        'CLASS',
                                        \%new_skill_line,
                                        ++$last_main_line,
                                        $class,
                                        $line_info,
                                        ];
                                $j++;
                                }

                                # The spell line
                                if ( keys %new_spell_line ) {

                                # Need to tell what CLASS we are dealing with
                                $new_spell_line{ $master_order{'CLASS'}[0] }
                                        = $new_class_line{ $master_order{'CLASS'}[0] };

                                ##################################################################
                                # [ 876536 ] All spell casting classes need CASTERLEVEL
                                #
                                # BONUS:CASTERLEVEL|<class name>|CL will be added to all classes
                                # that have a SPELLTYPE tag except if there is also an
                                # ITEMCREATE tag present.

                                if (   Pretty::Options::isConversionActive('CLASS:CASTERLEVEL for all casters')
                                        && exists $new_spell_line{'SPELLTYPE'}
                                        && !exists $new_spell_line{'BONUS:CASTERLEVEL'} )
                                {
                                        my $class = $new_spell_line{ $master_order{'CLASS'}[0] }[0];

                                        if ( exists $new_spell_line{'ITEMCREATE'} ) {

                                                # ITEMCREATE is present, we do not convert but we warn.
                                                $logging->warning(
                                                        "Can't add BONUS:CASTERLEVEL for class \"$class\", "
                                                        . "\"$new_spell_line{'ITEMCREATE'}[0]\" was found.",
                                                        $filename
                                                );
                                        }
                                        else {

                                                # We add the missing BONUS:CASTERLEVEL
                                                $class =~ s/^CLASS:(.*)/$1/;
                                                $new_spell_line{'BONUS:CASTERLEVEL'}
                                                = ["BONUS:CASTERLEVEL|$class|CL"];
                                                $logging->warning(
                                                qq{Adding missing "BONUS:CASTERLEVEL|$class|CL"},
                                                $filename
                                                );
                                        }
                                }

                                push @new_class_lines,
                                        [
                                        'CLASS',
                                        \%new_spell_line,
                                        ++$last_main_line,
                                        $class,
                                        $line_info,
                                        ];
                                $j++;
                                }

                                # We splice the new class lines in place
                                splice @{$lines_ref}, $first_line, $old_length, @new_class_lines;

                                # Continue with the rest
                                $i = $first_line + $j - 1;      # -1 because the $i++ happen right after
                        }
                        elsif (ref $lines_ref->[$i] eq 'ARRAY'
                                && $lines_ref->[$i][0] ne 'HEADER'
                                && defined $lines_ref->[$i][4]
                                && $lines_ref->[$i][4]{Mode} == SUB )
                        {

                                # We must replace the last_main_line with the correct value
                                $lines_ref->[$i][2] = $last_main_line;
                        }
                        elsif (ref $lines_ref->[$i] eq 'ARRAY'
                                && $lines_ref->[$i][0] ne 'HEADER'
                                && defined $lines_ref->[$i][4]
                                && $lines_ref->[$i][4]{Mode} == MAIN )
                        {

                                # We update the last_main_line value and
                                # put the correct value in the curent line
                                $lines_ref->[$i][2] = $last_main_line = $i;
                        }
                }
                }

                ###############################################################
                # The CLASSSKILL files must be deprecated in favor of extra
                # CSKILL in the CLASS files.
                #
                # For every CLASSSKILL found, an extra line must be added after
                # the CLASS line with the class name and the list of
                # CSKILL in the first CLASS file on the same directory as the
                # CLASSSKILL.
                #
                # If no CLASS with the same name can be found in the same
                # directory, entries with class name.MOD must be generated
                # at the end of the first CLASS file in the same directory.

                if ( Pretty::Options::isConversionActive('CLASSSKILL conversion to CLASS') ) {
                if ( $filetype eq 'CLASSSKILL' ) {

                        # Here we will put aside all the CLASSSKILL that
                        # we find for later use.

                        my $dir = File::Basename::dirname($filename);
                        LINE:
                        for ( @{ $lines_ref } ) {

                                # Only the 000ClassName are of interest to us
                                next LINE
                                if ref ne 'HASH'
                                || !exists $_->{'000ClassName'}
                                || !exists $_->{'001SkillName'};

                                # We preserve the list of skills for the class
                                $class_skill{$dir}{ $_->{'000ClassName'} } = $_->{'001SkillName'};
                        }
                }
                elsif ( $filetype eq 'CLASS' ) {
                        my $dir = File::Basename::dirname($filename);
                        my $skipnext = 0;
                        if ( exists $class_skill{$dir} ) {

                                # There was a CLASSSKILL file in this directory
                                # We need to incorporate it

                                # First, we find all of the existing CLASS and
                                # add an extra line to them
                                my $index = 0;
                                LINE:
                                for (@$lines_ref) {

                                # If the line is text only, skip
                                next LINE if ref ne 'ARRAY';

                                my $line_tokens = $_->[1];

                                # If it is not a CLASS line, we skip it
                                next LINE
                                        if ref($line_tokens) ne 'HASH'
                                        || !exists $line_tokens->{'000ClassName'};

                                my $class = ( $line_tokens->{'000ClassName'}[0] =~ /CLASS:(.*)/ )[0];

                                if ( exists $class_skill{$dir}{$class} ) {
                                        my $line_no = $- > [2];

                                        # We build a new CLASS, CSKILL line to add.
                                        my $newskills = join '|',
                                                sort split( '\|', $class_skill{$dir}{$class} );
                                        $newskills =~ s/Craft[ %]\|/TYPE.Craft\|/;
                                        $newskills =~ s/Knowledge[ %]\|/TYPE.Knowledge\|/;
                                        $newskills =~ s/Profession[ %]\|/TYPE.Profession\|/;
                                        splice @$lines_ref, $index + 1, 0,
                                                [
                                                'CLASS',
                                                {   '000ClassName' => ["CLASS:$class"],
                                                'CSKILL'                => ["CSKILL:$newskills"]
                                                },
                                                $line_no, $class,
                                                $master_file_type{CLASS}[1],
                                                ];
                                        delete $class_skill{$dir}{$class};

                                        $logging->warning( qq{Adding line "CLASS:$class\tCSKILL:$newskills"}, $filename );
                                }
                                }
                                continue { $index++ }

                                # If there are any CLASSSKILL remaining for the directory,
                                # we have to create .MOD entries

                                if ( exists $class_skill{$dir} ) {
                                for ( sort keys %{ $class_skill{$dir} } ) {
                                        my $newskills = join '|', sort split( '\|', $class_skill{$dir}{$_} );
                                        $newskills =~ s/Craft \|/TYPE.Craft\|/;
                                        $newskills =~ s/Knowledge \|/TYPE.Knowledge\|/;
                                        $newskills =~ s/Profession \|/TYPE.Profession\|/;
                                        push @$lines_ref,
                                                [
                                                'CLASS',
                                                {   '000ClassName' => ["CLASS:$_.MOD"],
                                                'CSKILL'                => ["CSKILL:$newskills"]
                                                },
                                                scalar(@$lines_ref),
                                                "$_.MOD",
                                                $master_file_type{CLASS}[1],
                                                ];

                                        delete $class_skill{$dir}{$_};

                                        $logging->warning( qq{Adding line "CLASS:$_.MOD\tCSKILL:$newskills"}, $filename );
                                }
                                }
                        }
                }
                }

                1;
        }

}

###############################################################
# mylength
# --------
#
# Find the number of characters for a string or a list of strings
# that would be separated by tabs.

sub mylength {
        return 0 unless defined $_[0];

        my @list;

        if ( ref( $_[0] ) eq 'ARRAY' ) {
                @list = @{ $_[0] };
        }
        else {
                @list = @_;
        }

        my $Length      = 0;
        my $beforelast = scalar(@list) - 2;

        if ( $beforelast > -1 ) {

                # All the elements except the last must be rounded to the next tab
                for my $subtag ( @list[ 0 .. $beforelast ] ) {
                $Length += ( int( length($subtag) / $tablength ) + 1 ) * $tablength;
                }
        }

        # The last item is not rounded to the tab length
        $Length += length( $list[-1] );

}

###############################################################
# check_clear_tag_order
# ---------------------
#
# Verify that the .CLEAR tags are put correctly before the
# tags that they clear.
#
# Parameter:  $line_ref         : Hash reference to the line
#                       $file_for_error
#                       $line_for_error

sub check_clear_tag_order {
        my ( $line_ref, $file_for_error, $line_for_error ) = @_;

        TAG:
        for my $tag ( keys %$line_ref ) {

                # if the current value is not an array, there is only one
                # tag and no order to check.
                next unless ref( $line_ref->{$tag} );

                # if only one of a kind, skip the rest
                next TAG if scalar @{ $line_ref->{$tag} } <= 1;

                my %value_found;

                if ( $tag eq "SA" ) {

                # The SA tag is special because it is only checked
                # up to the first (
                for ( @{ $line_ref->{$tag} } ) {
                        if (/:\.?CLEAR.?([^(]*)/) {

                                # clear tag either clear the whole thing,
                                # in which case it must be the very beginning,
                                # or it clear a particular value, in which case
                                # it must be before any such value.
                                if ( $1 ne "" ) {

                                # Let's check if the value was found before
                                $logging->notice(  qq{"$tag:$1" found before "$_"}, $file_for_error, $line_for_error )
                                        if exists $value_found{$1};
                                }
                                else {

                                # Let's check if any value was found before
                                $logging->notice(  qq{"$tag" tag found before "$_"}, $file_for_error, $line_for_error )
                                        if keys %value_found;
                                }
                        }
                        elsif ( / : ([^(]*) /xms ) {

                                # Let's store the value
                                $value_found{$1} = 1;
                        }
                        else {
                                $logging->error(
                                "Didn't anticipate this tag: $_",
                                $file_for_error,
                                $line_for_error
                                );
                        }
                }
                }
                else {
                for ( @{ $line_ref->{$tag} } ) {
                        if (/:\.?CLEAR.?(.*)/) {

                                # clear tag either clear the whole thing,
                                # in which case it must be the very beginning,
                                # or it clear a particular value, in which case
                                # it must be before any such value.
                                if ( $1 ne "" ) {

                                # Let's check if the value was found before
                                $logging->notice( qq{"$tag:$1" found before "$_"}, $file_for_error, $line_for_error )
                                        if exists $value_found{$1};
                                }
                                else {

                                # Let's check if any value was found before
                                $logging->notice( qq{"$tag" tag found before "$_"}, $file_for_error, $line_for_error )
                                        if keys %value_found;
                                }
                        }
                        elsif (/:(.*)/) {

                                # Let's store the value
                                $value_found{$1} = 1;
                        }
                        else {
                                $logging->error(
                                        "Didn't anticipate this tag: $_",
                                        $file_for_error,
                                        $line_for_error
                                );
                        }
                }
                }
        }
}

###############################################################
# find_full_path
# --------------
#
# Change the @ and relative paths found in the .lst for
# the real thing.
#
# Parameters: $file_name                File name
#                       $current_base_dir       Current directory
#                       $base_path              Origin for the @ replacement

sub find_full_path {
        my ( $file_name, $current_base_dir, $base_path ) = @_;

        # Change all the \ for / in the file name
        $file_name =~ tr{\\}{/};

        # Replace @ by the base dir or add the current base dir to the file name.
        if( $file_name !~ s{ ^[@] }{$base_path}xmsi )
        {
                $file_name = "$current_base_dir/$file_name";
        }

        # Remove the /xxx/../ for the directory
        if ($file_name =~ / [.][.] /xms ) {
                if( $file_name !~ s{ [/] [^/]+ [/] [.][.] [/] }{/}xmsg ) {
                die qq{Cannot des with the .. directory in "$file_name"};
                }
        }

        return $file_name;
}

###############################################################
# create_dir
# ----------
#
# Create any part of a subdirectory structure that is not
# already there.

sub create_dir {
        my ( $dir, $outputdir ) = @_;

        # Only if the directory doesn't already exist
        if ( !-d $dir ) {
                my $parentdir = File::Basename::dirname($dir);

                # If the $parentdir doesn't exist, we create it
                if ( $parentdir ne $outputdir && !-d $parentdir ) {
                create_dir( $parentdir, $outputdir );
                }

                # Create the curent level directory
                mkdir $dir, oct(755) or die "Cannot create directory $dir: $OS_ERROR";
        }
}

###############################################################
# report_tag_sort
# ---------------
#
# Sort used for the tag when reporting them.
#
# Basicaly, it's a normal ASCII sort except that the ! are removed
# when found (the PRExxx and !PRExxx are sorted one after the orther).

sub report_tag_sort {
        my ( $left, $right ) = ( $a, $b );      # We need a copy in order to modify

        # Remove the !. $not_xxx contains 1 if there was a !, otherwise
        # it contains 0.
        my $not_left  = $left  =~ s{^!}{}xms;
        my $not_right = $right =~ s{^!}{}xms;

        $left cmp $right || $not_left <=> $not_right;

}

###############################################################
# embedded_coma_split
# -------------------
#
# split a list using the comma but part of the list may be
# between brackets and the comma must be ignored there.
#
# Parameter: $list      List that need to be splited
#               $separator      optionnal expression used for the
#                               split, ',' is the default.
#
# Return the splited list.

sub embedded_coma_split {

        # The list may contain other lists between brackets.
        # We will first change all the , in within brackets
        # before doing our split.
        my ( $list, $separator ) = ( @_, ',' );

        return () unless $list;

        my $newlist;
        my @result;

        BRACE_LIST:
        while ($list) {

                # We find the next text within ()
                @result = Text::Balanced::extract_bracketed( $list, '()', qr([^()]*) );

                # If we didn't find any (), it's over
                if ( !$result[0] ) {
                $newlist .= $list;
                last BRACE_LIST;
                }

                # The prefix is added to $newlist
                $newlist .= $result[2];

                # We replace every , with &comma;
                $result[0] =~ s/,/&coma;/xmsg;

                # We add the bracket section
                $newlist .= $result[0];

                # We start again with what's left
                $list = $result[1];
        }

        # Now we can split
        return map { s/&coma;/,/xmsg; $_ } split $separator, $newlist;
}

###############################################################
# parse_system_files
# ------------------
#
# Parameter: $system_file_path  Path where the game mode folders can be found.

{
   # Needed for the Find function
   my @system_files;

   sub parse_system_files {
      my $system_file_path = getOption('systempath');
      my $original_system_file_path = $system_file_path;

      my @verified_allowed_modes      = ();
      my @verified_stats              = ();
      my @verified_alignments = ();
      my @verified_var_names  = ();
      my @verified_check_names        = ();

      # Set the header for the error messages
      $logging->set_header(constructLoggingHeader('System'));

      # Get the Unix direcroty separator even in a Windows environment
      $system_file_path =~ tr{\\}{/};

      # Verify if the gameModes directory is present
      if ( !-d "$system_file_path/gameModes" ) {
         die qq{No gameModes directory found in "$original_system_file_path"};
      }

      # We will now find all of the miscinfo.lst and statsandchecks.lst files
      @system_files = ();

      File::Find::find( \&want_system_info, $system_file_path );

      # Did we find anything (hopefuly yes)
      if ( scalar @system_files == 0 ) {
         $logging->error(
            qq{No miscinfo.lst or statsandchecks.lst file were found in the system directory},
            getOption('systempath')
         );
      }

      # We only keep the files that correspond to the selected
      # game mode
      if (getOption('gamemode')) {
         @system_files
         = grep { m{ \A $system_file_path
            [/] gameModes
            [/] (?: $cl_options{gamemode} ) [/]
         }xmsi;
         }
         @system_files;
      }

      # Anything left?
      if ( scalar @system_files == 0 ) {
         $logging->error(
            qq{No miscinfo.lst or statsandchecks.lst file were found in the gameModes/$cl_options{gamemode}/ directory},
            getOption('systempath')
         );
      }

      # Now we search for the interesting part in the miscinfo.lst files
      for my $system_file (@system_files) {
         open my $system_file_fh, '<', $system_file;

         LINE:
         while ( my $line = <$system_file_fh> ) {
            chomp $line;

            # Skip comment lines
            next LINE if $line =~ / \A [#] /xms;

            # ex. ALLOWEDMODES:35e|DnD
            if ( my ($modes) = ( $line =~ / ALLOWEDMODES: ( [^\t]* )/xms ) ) {
               push @verified_allowed_modes, split /[|]/, $modes;
               next LINE;
            }
            # ex. STATNAME:Strength ABB:STR DEFINE:MAXLEVELSTAT=STR|STRSCORE-10
            elsif ( $line =~ / \A STATNAME: /xms ) {
               LINE_TAG:
               for my $line_tag (split /\t+/, $line) {
                  # STATNAME lines have more then one interesting tags
                  if ( my ($stat) = ( $line_tag =~ / \A ABB: ( .* ) /xms ) ) {
                     push @verified_stats, $stat;
                  }
                  elsif ( my ($define_expression) = ( $line_tag =~ / \A DEFINE: ( .* ) /xms ) ) {
                     if ( my ($var_name) = ( $define_expression =~ / \A ( [\t=|]* ) /xms ) ) {
                        push @verified_var_names, $var_name;
                     }
                     else {
                        $logging->error(
                           qq{Cannot find the variable name in "$define_expression"},
                           $system_file,
                           $INPUT_LINE_NUMBER
                        );
                     }
                  }
               }
            }
            # ex. ALIGNMENTNAME:Lawful Good ABB:LG
            elsif ( my ($alignment) = ( $line =~ / \A ALIGNMENTNAME: .* ABB: ( [^\t]* ) /xms ) ) {
               push @verified_alignments, $alignment;
            }
            # ex. CHECKNAME:Fortitude   BONUS:CHECKS|Fortitude|CON
            elsif ( my ($check_name) = ( $line =~ / \A CHECKNAME: .* BONUS:CHECKS [|] ( [^\t|]* ) /xms ) ) {
               # The check name used by PCGen is actually the one defined with the first BONUS:CHECKS.
               # CHECKNAME:Sagesse     BONUS:CHECKS|Will|WIS would display Sagesse but use Will internaly.
               push @verified_check_names, $check_name;
            }
         }

         close $system_file_fh;
      }

      # We keep only the first instance of every list items and replace
      # the default values with the result.
      # The order of elements must be preserved
      my %seen = ();
      @valid_system_alignments = grep { !$seen{$_}++ } @verified_alignments;

      %seen = ();
      @valid_system_game_modes = grep { !$seen{$_}++ } @verified_allowed_modes;

      %seen = ();
      @valid_system_stats = grep { !$seen{$_}++ } @verified_stats;

      %seen = ();
      @valid_system_var_names = grep { !$seen{$_}++ } @verified_var_names;

      %seen = ();
      @valid_system_check_names = grep { !$seen{$_}++ } @verified_check_names;

      # Now we bitch if we are not happy
      if ( scalar @verified_stats == 0 ) {
         $logging->error(
            q{Could not find any STATNAME: tag in the system files},
            $original_system_file_path
         );
      }

      if ( scalar @valid_system_game_modes == 0 ) {
         $logging->error(
            q{Could not find any ALLOWEDMODES: tag in the system files},
            $original_system_file_path
         );
      }

      if ( scalar @valid_system_check_names == 0 ) {
         $logging->error(
            q{Could not find any valid CHECKNAME: tag in the system files},
            $original_system_file_path
         );
      }

      # If the -exportlist option was used, we generate a system.csv file
      if ( getOption('exportlist') ) {

         open my $csv_file, '>', 'system.csv';

         print {$csv_file} qq{"System Directory","$original_system_file_path"\n};

         if ( getOption('gamemode') ) {
            print {$csv_file} qq{"Game Mode Selected","$cl_options{gamemode}"\n};
         }
         print {$csv_file} qq{\n};

         print {$csv_file} qq{"Alignments"\n};
         for my $alignment (@valid_system_alignments) {
            print {$csv_file} qq{"$alignment"\n};
         }
         print {$csv_file} qq{\n};

         print {$csv_file} qq{"Allowed Modes"\n};
         for my $mode (sort @valid_system_game_modes) {
            print {$csv_file} qq{"$mode"\n};
         }
         print {$csv_file} qq{\n};

         print {$csv_file} qq{"Stats Abbreviations"\n};
         for my $stat (@valid_system_stats) {
            print {$csv_file} qq{"$stat"\n};
         }
         print {$csv_file} qq{\n};

         print {$csv_file} qq{"Variable Names"\n};
         for my $var_name (sort @valid_system_var_names) {
            print {$csv_file} qq{"$var_name"\n};
         }
         print {$csv_file} qq{\n};

         close $csv_file;
      }

      return;
   }

   sub want_system_info {
      push @system_files, $File::Find::name
      if lc $_ eq 'miscinfo.lst' || lc $_ eq 'statsandchecks.lst';
   };
}


###############################################################
# warn_deprecate
# --------------
#
# Generate a warning message about a deprecated tag.
#
# Parameters: $bad_tag          Tag that has been deprecated
#                       $files_for_error        File name when the error is found
#                       $line_for_error Line number where the error is found
#                       $enclosing_tag  (Optionnal) tag into which the
#                                       deprecated tag is included

sub warn_deprecate {
        my ($bad_tag, $file_for_error, $line_for_error, $enclosing_tag) = (@_, "");

        my $message = qq{Deprecated syntax: "$bad_tag"};

        if($enclosing_tag) {
                $message .= qq{ found in "$enclosing_tag"};
        }

        $logging->info( $message, $file_for_error, $line_for_error );

}



###############################################################
###############################################################
###
### Start of closure for BIOSET generation functions
### [ 663491 ] RACE: Convert AGE, HEIGHT and WEIGHT tags
###

{

        # Moving this out of the BEGIN as a workaround for bug
        # [perl #30058] Perl 5.8.4 chokes on perl -e 'BEGIN { my %x=(); }'

        my %RecordedBiosetTags;

        BEGIN {

                my %DefaultBioset = (

                # Race          AGE                             HEIGHT                                  WEIGHT
                'Human' =>      [ 'AGE:15:1:4:1:6:2:6',   'HEIGHT:M:58:2:10:0:F:53:2:10:0',   'WEIGHT:M:120:2:4:F:85:2:4'       ],
                'Dwarf' =>      [ 'AGE:40:3:6:5:6:7:6',   'HEIGHT:M:45:2:4:0:F:43:2:4:0',       'WEIGHT:M:130:2:6:F:100:2:6'    ],
                'Elf' =>        [ 'AGE:110:4:6:6:6:10:6', 'HEIGHT:M:53:2:6:0:F:53:2:6:0',       'WEIGHT:M:85:1:6:F:80:1:6'      ],
                'Gnome' =>      [ 'AGE:40:4:6:6:6:9:6',   'HEIGHT:M:36:2:4:0:F:34:2:4:0',       'WEIGHT:M:40:1:1:F:35:1:1'      ],
                'Half-Elf' => [ 'AGE:20:1:6:2:6:3:6',   'HEIGHT:M:55:2:8:0:F:53:2:8:0', 'WEIGHT:M:100:2:4:F:80:2:4'     ],
                'Half-Orc' => [ 'AGE:14:1:4:1:6:2:6',   'HEIGHT:M:58:2:10:0:F:52:2:10:0',   'WEIGHT:M:130:2:4:F:90:2:4' ],
                'Halfling' => [ 'AGE:20:2:4:3:6:4:6',   'HEIGHT:M:32:2:4:0:F:30:2:4:0', 'WEIGHT:M:30:1:1:F:25:1:1'      ],
                );

                ###############################################################
                # record_bioset_tags
                # ------------------
                #
                # This function record the BIOSET information found in the
                # RACE files so that the BIOSET files can later be generated.
                #
                # If the value are equal to the default, they are not generated
                # since the default apply.
                #
                # Parameters: $dir              Directory where the RACE file was found
                #                       $race           Name of the race
                #                       $age                    AGE tag
                #                       $height         HEIGHT tag
                #                       $weight         WEIGHT tag
                #                       $file_for_error To use with log
                #                       $line_for_error To use with log

                sub record_bioset_tags {
                my ($dir,
                        $race,
                        $age,
                        $height,
                        $weight,
                        $file_for_error,
                        $line_for_error
                ) = @_;

                # Check to see if default apply
                RACE:
                for my $master_race ( keys %DefaultBioset ) {
                        if ( index( $race, $master_race ) == 0 ) {

                                # The race name is included in the default
                                # We now verify the values
                                $age    = "" if $DefaultBioset{$master_race}[0] eq $age;
                                $height = "" if $DefaultBioset{$master_race}[1] eq $height;
                                $weight = "" if $DefaultBioset{$master_race}[2] eq $weight;
                                last RACE;
                        }
                }

                # Everything that is not blank must be kept
                if ($age) {
                        if ( exists $RecordedBiosetTags{$dir}{$race}{AGE} ) {
                                $logging->notice(
                                qq{BIOSET generation: There is already a AGE tag recorded}
                                        . qq{ for a race named "$race" in this directory.},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                        else {
                                $RecordedBiosetTags{$dir}{$race}{AGE} = $age;
                        }
                }

                if ($height) {
                        if ( exists $RecordedBiosetTags{$dir}{$race}{HEIGHT} ) {
                                $logging->notice(
                                qq{BIOSET generation: There is already a HEIGHT tag recorded}
                                        . qq{ for a race named "$race" in this directory.},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                        else {
                                $RecordedBiosetTags{$dir}{$race}{HEIGHT} = $height;
                        }
                }

                if ($weight) {
                        if ( exists $RecordedBiosetTags{$dir}{$race}{WEIGHT} ) {
                                $logging->notice(
                                qq{BIOSET generation: There is already a WEIGHT tag recorded}
                                        . qq{ for a race named "$race" in this directory.},
                                $file_for_error,
                                $line_for_error
                                );
                        }
                        else {
                                $RecordedBiosetTags{$dir}{$race}{WEIGHT} = $weight;
                        }
                }
                }

                ###############################################################
                # generate_bioset_files
                # ---------------------
                #
                # Generate the new BIOSET files from the data included in the
                # %RecordedBiosetTags hash.
                #
                # The new files will all be named bioset.lst and will required
                # to be renames and included in the .PCC manualy.
                #
                # No parameter

                sub generate_bioset_files {
                for my $dir ( sort keys %RecordedBiosetTags ) {
                        my $filename = $dir . '/biosettings.lst';
                        $filename =~ s/$cl_options{input_path}/$cl_options{output_path}/i;

                        open my $bioset_fh, '>', $filename;

                        # Printing the name of the new file generated
                        print STDERR $filename, "\n";

                        # Header part.
                        print {$bioset_fh} << "END_OF_HEADER";
AGESET:0|Adulthood
END_OF_HEADER

                        # Let's find the longest race name
                        my $racename_length = 0;
                        for my $racename ( keys %{ $RecordedBiosetTags{$dir} } ) {
                                $racename_length = length($racename) if length($racename) > $racename_length;
                        }

                        # Add the length for RACENAME:
                        $racename_length += 9;

                        # Bring the length to the next tab
                        if ( $racename_length % $tablength ) {

                                # We add the remaining spaces to get to the tab
                                $racename_length += $tablength - ( $racename_length % $tablength );
                        }
                        else {

                                # Already on a tab length, we add an extra tab
                                $racename_length += $tablength;
                        }

                        # We now format and print the lines for each race
                        for my $racename ( sort keys %{ $RecordedBiosetTags{$dir} } ) {
                                my $height_weight_line = "";
                                my $age_line            = "";

                                if (   exists $RecordedBiosetTags{$dir}{$racename}{HEIGHT}
                                && exists $RecordedBiosetTags{$dir}{$racename}{WEIGHT} )
                                {
                                my $space_to_add = $racename_length - length($racename) - 9;
                                my $tab_to_add   = int( $space_to_add / $tablength )
                                        + ( $space_to_add % $tablength ? 1 : 0 );
                                $height_weight_line = 'RACENAME:' . $racename . "\t" x $tab_to_add;

                                my ($m_ht_min, $m_ht_dice, $m_ht_sides, $m_ht_bonus,
                                        $f_ht_min, $f_ht_dice, $f_ht_sides, $f_ht_bonus
                                        )
                                        = ( split ':', $RecordedBiosetTags{$dir}{$racename}{HEIGHT} )
                                        [ 2, 3, 4, 5, 7, 8, 9, 10 ];

                                my ($m_wt_min, $m_wt_dice, $m_wt_sides,
                                        $f_wt_min, $f_wt_dice, $f_wt_sides
                                        )
                                        = ( split ':', $RecordedBiosetTags{$dir}{$racename}{WEIGHT} )
                                                [ 2, 3, 4, 6, 7, 8 ];

# 'HEIGHT:M:58:2:10:0:F:53:2:10:0'
# 'WEIGHT:M:120:2:4:F:85:2:4'
#
# SEX:Male[BASEHT:58|HTDIEROLL:2d10|BASEWT:120|WTDIEROLL:2d4|TOTALWT:BASEWT+(HTDIEROLL*WTDIEROLL)]Female[BASEHT:53|HTDIEROLL:2d10|BASEWT:85|WTDIEROLL:2d4|TOTALWT:BASEWT+(HTDIEROLL*WTDIEROLL)]

                                # Male height caculation
                                $height_weight_line .= 'SEX:Male[BASEHT:'
                                        . $m_ht_min
                                        . '|HTDIEROLL:'
                                        . $m_ht_dice . 'd'
                                        . $m_ht_sides;
                                $height_weight_line .= '+' . $m_ht_bonus if $m_ht_bonus > 0;
                                $height_weight_line .= $m_ht_bonus              if $m_ht_bonus < 0;

                                # Male weight caculation
                                $height_weight_line .= '|BASEWT:'
                                        . $m_wt_min
                                        . '|WTDIEROLL:'
                                        . $m_wt_dice . 'd'
                                        . $m_wt_sides;
                                $height_weight_line .= '|TOTALWT:BASEWT+(HTDIEROLL*WTDIEROLL)]';

                                # Female height caculation
                                $height_weight_line .= 'Female[BASEHT:'
                                        . $f_ht_min
                                        . '|HTDIEROLL:'
                                        . $f_ht_dice . 'd'
                                        . $f_ht_sides;
                                $height_weight_line .= '+' . $f_ht_bonus if $f_ht_bonus > 0;
                                $height_weight_line .= $f_ht_bonus              if $f_ht_bonus < 0;

                                # Female weight caculation
                                $height_weight_line .= '|BASEWT:'
                                        . $f_wt_min
                                        . '|WTDIEROLL:'
                                        . $f_wt_dice . 'd'
                                        . $f_wt_sides;
                                $height_weight_line .= '|TOTALWT:BASEWT+(HTDIEROLL*WTDIEROLL)]';
                                }

                                if ( exists $RecordedBiosetTags{$dir}{$racename}{AGE} ) {

                                # We only generate a comment from the AGE tag
                                $age_line = '### Old tag for race '
                                        . $racename . '=> '
                                        . $RecordedBiosetTags{$dir}{$racename}{AGE};
                                }

                                print {$bioset_fh} $height_weight_line, "\n" if $height_weight_line;
                                print {$bioset_fh} $age_line,           "\n" if $age_line;

                                #       print BIOSET "\n";
                        }

                        close $bioset_fh;
                }
                }

        }       # BEGIN

}       # The entra encapsulation is a workaround for the bug
        # [perl #30058] Perl 5.8.4 chokes on perl -e 'BEGIN { my %x=(); }'

###
### End of  closure for BIOSET generation funcitons
###
###############################################################
###############################################################

###############################################################
# generate_css
# ------------
#
# Generate a new .css file for the .html help file.

sub generate_css {
        my ($newfile) = shift;

        open my $css_fh, '>', $newfile;

        print {$css_fh} << 'END_CSS';
BODY {
        font: small verdana, arial, helvetica, sans-serif;
        color: black;
        background-color: white;
}

A:link  {color: #0000FF}
A:visited   {color: #666666}
A:active        {color: #FF0000}


H1 {
        font: bold large verdana, arial, helvetica, sans-serif;
        color: black;
}


H2 {
        font: bold large verdana, arial, helvetica, sans-serif;
        color: maroon;
}


H3 {
        font: bold medium verdana, arial, helvetica, sans-serif;
                color: blue;
}


H4 {
        font: bold small verdana, arial, helvetica, sans-serif;
                color: maroon;
}


H5 {
        font: bold small verdana, arial, helvetica, sans-serif;
                color: blue;
}


H6 {
        font: bold small verdana, arial, helvetica, sans-serif;
                color: black;
}


UL {
        font: small verdana, arial, helvetica, sans-serif;
                color: black;
}


OL {
        font: small verdana, arial, helvetica, sans-serif;
                color: black;
}


LI
{
        font: small verdana, arial, helvetica, sans-serif;
        color: black;
}

TH {
        font: small verdana, arial, helvetica, sans-serif;
        color: blue;
}


TD {
        font: small verdana, arial, helvetica, sans-serif;
        color: black;
}

TD.foot {
        font: medium sans-serif;
        color: #eeeeee;
        background-color="#cc0066"
}

DL {
        font: small verdana, arial, helvetica, sans-serif;
        color: black;
}


DD {
        font: small verdana, arial, helvetica, sans-serif;
        color: black;
}


DT {
        font: small verdana, arial, helvetica, sans-serif;
                color: black;
}


CODE {
        font: small Courier, monospace;
}


PRE {
        font: small Courier, monospace;
}


P.indent {
        font: small verdana, arial, helvetica, sans-serif;
        color: black;
        background-color: white;
        list-style-type : circle;
        list-style-position : inside;
        margin-left : 16.0pt;
}

PRE.programlisting
{
        list-style-type : disc;
        margin-left : 16.0pt;
        margin-top : -14.0pt;
}


INPUT {
        font: bold small verdana, arial, helvetica, sans-serif;
        color: black;
        background-color: white;
}


TEXTAREA {
        font: bold small verdana, arial, helvetica, sans-serif;
        color: black;
        background-color: white;
}

.BANNER {
        background-color: "#cccccc";
        font: bold medium verdana, arial, helvetica, sans-serif;

}
END_CSS

        close $css_fh;
}

=head2 constructLoggingHeader

   This operation constructs a headeing for the logging program.

=cut

sub constructLoggingHeader {
   my ($headerRef, $path) = @_;

   my $header = "================================================================\n";

   if (exists $headings{$headerRef}) {
      $header .= $headings{$headerRef};
   }

   if (defined $path) {
      $header .= $path . "\n";
   }

   $header   .= "----------------------------------------------------------------\n";
}

=head2 convertEntities

   This subroutine converts all special characters in a string to an ascii equivalent

=cut

sub convertEntities {
   my ($line) = @_;

   $line =~ s/\x82/,/g;
   $line =~ s/\x84/,,/g;
   $line =~ s/\x85/.../g;
   $line =~ s/\x88/^/g;
   $line =~ s/\x8B/</g;
   $line =~ s/\x8C/Oe/g;
   $line =~ s/\x91/\'/g;
   $line =~ s/\x92/\'/g;
   $line =~ s/\x93/\"/g;
   $line =~ s/\x94/\"/g;
   $line =~ s/\x95/*/g;
   $line =~ s/\x96/-/g;
   $line =~ s/\x97/-/g;
   $line =~ s-\x98-<sup>~</sup>-g;
   $line =~ s-\x99-<sup>TM</sup>-g;
   $line =~ s/\x9B/>/g;
   $line =~ s/\x9C/oe/g;

   return $line;
}

=head2 modifyMasterOrderForConversions

   This subroutine alters the list of valid tags as necessary for various
   conversions.

   If a tag is to be converted, it must be accepted by the system as valid,
   after it has been converted, the master list of tags no longer needs to contain
   it unless it is being converted.

   If the tag is not being converted (i.e. the relevant conversion is not 
   active), then it will be rejected as erronous by the system.

=cut

sub modifyMasterOrderForConversions {
   my ($masterTagOrder) = @_;

#################################################################
######################## Conversion #############################
# Tags that must be seen as valid to allow conversion.

   if (Pretty::Options::isConversionActive('ALL:Convert ADD:SA to ADD:SAB')) {
      push @{ $masterTagOrder->{'CLASS'} },         'ADD:SA';
      push @{ $masterTagOrder->{'CLASS Level'} },   'ADD:SA';
      push @{ $masterTagOrder->{'COMPANIONMOD'} },  'ADD:SA';
      push @{ $masterTagOrder->{'DEITY'} },         'ADD:SA';
      push @{ $masterTagOrder->{'DOMAIN'} },        'ADD:SA';
      push @{ $masterTagOrder->{'EQUIPMENT'} },     'ADD:SA';
      push @{ $masterTagOrder->{'EQUIPMOD'} },      'ADD:SA';
      push @{ $masterTagOrder->{'FEAT'} },          'ADD:SA';
      push @{ $masterTagOrder->{'RACE'} },          'ADD:SA';
      push @{ $masterTagOrder->{'SKILL'} },         'ADD:SA';
      push @{ $masterTagOrder->{'SUBCLASSLEVEL'} }, 'ADD:SA';
      push @{ $masterTagOrder->{'TEMPLATE'} },      'ADD:SA';
      push @{ $masterTagOrder->{'WEAPONPROF'} },    'ADD:SA';
   }
   if (Pretty::Options::isConversionActive('EQUIP: ALTCRITICAL to ALTCRITMULT')) {
      push @{ $masterTagOrder->{'EQUIPMENT'} }, 'ALTCRITICAL';
   }

   if (Pretty::Options::isConversionActive('BIOSET:generate the new files')) {
      push @{ $masterTagOrder->{'RACE'} }, 'AGE', 'HEIGHT', 'WEIGHT';
   }

   if (Pretty::Options::isConversionActive('EQUIPMENT: remove ATTACKS')) {
      push @{ $masterTagOrder->{'EQUIPMENT'} }, 'ATTACKS';
   }

   if (Pretty::Options::isConversionActive('PCC:GAME to GAMEMODE')) {
      push @{ $masterTagOrder->{'PCC'} }, 'GAME';
   }

   if (Pretty::Options::isConversionActive('ALL:BONUS:MOVE conversion')) {
      push @{ $masterTagOrder->{'CLASS'} },         'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'CLASS Level'} },   'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'COMPANIONMOD'} },  'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'DEITY'} },         'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'DOMAIN'} },        'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'EQUIPMENT'} },     'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'EQUIPMOD'} },      'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'FEAT'} },          'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'RACE'} },          'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'SKILL'} },         'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'SUBCLASSLEVEL'} }, 'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'TEMPLATE'} },      'BONUS:MOVE:*';
      push @{ $masterTagOrder->{'WEAPONPROF'} },    'BONUS:MOVE:*';
   }

   if (Pretty::Options::isConversionActive('WEAPONPROF:No more SIZE')) {
      push @{ $masterTagOrder->{'WEAPONPROF'} }, 'SIZE';
   }

   if (Pretty::Options::isConversionActive('EQUIP:no more MOVE')) {
      push @{ $masterTagOrder->{'EQUIPMENT'} }, 'MOVE';
   }

#   vvvvvv This one is disactivated
   if (0 && Pretty::Options::isConversionActive('ALL:Convert SPELL to SPELLS')) {
      push @{ $masterTagOrder->{'CLASS Level'} },    'SPELL:*';
      push @{ $masterTagOrder->{'DOMAIN'} },         'SPELL:*';
      push @{ $masterTagOrder->{'EQUIPMOD'} },       'SPELL:*';
      push @{ $masterTagOrder->{'SUBCLASSLEVEL'} },  'SPELL:*';
   }

#   vvvvvv This one is disactivated
   if (0 && Pretty::Options::isConversionActive('TEMPLATE:HITDICESIZE to HITDIE')) {
      push @{ $masterTagOrder->{'TEMPLATE'} }, 'HITDICESIZE';
   }

}

sub convertAddSA {
   my ($lineTokens, $file, $line) = @_;

   # [ 1864711 ] Convert ADD:SA to ADD:SAB
   # In most files, take ADD:SA and replace with ADD:SAB

   if (Pretty::Options::isConversionActive('ALL:Convert ADD:SA to ADD:SAB') && exists $lineTokens->{'ADD:SA'})) {

      my $logger = Pretty::Reformat::getLogger();

      $logger->warning(
         qq{Change ADD:SA for ADD:SAB in "$lineTokens->{'ADD:SA'}[0]"},
         $file_for_error,
         $line_for_error
      );

      # copy the array into the correct tag and then delete the origianal
      $lineTokens->{'ADD:SAB'} = $lineTokens->{'ADD:SA'}; 
      delete $lineTokens->{'ADD:SA'};

      # modify the copies (possibly only one) so they have the correct tag
      for my $tok ( @{ $lineTokens->{'ADD:SAB'} } ) {
         $tok =~ s/ADD:SA/ADD:SAB/;
      }
   }
}

=head2 removePREDefaultMonster

   [ 1514765 ] Conversion to remove old defaultmonster tags

   Bonuses associated with a PREDEFAULTMONSTER:Y need to be removed This should remove the whole tag.

=cut 

sub removePREDefaultMonster {

   my ($lineTokens, $filetype, $file_for_error, $line_for_error) = @_;

   if (Pretty::Options::isConversionActive('RACE:Fix PREDEFAULTMONSTER bonuses') && $filetype eq "RACE") {
      for my $key ( keys %$lineTokens ) {
         my $ary = $lineTokens->{$key};
         my $iCount = 0;
         foreach (@$ary) {
            my $ttag = $$ary[$iCount];
            if ($ttag =~ /PREDEFAULTMONSTER:Y/) {
               $$ary[$iCount] = "";
               $logger->warning(
                  qq{Removing "$ttag".},
                  $file_for_error,
                  $line_for_error
               );
            }
            $iCount++;
         }
      }
   }
}



=head2 removeALTCRITICAL

   [ 1615457 ] Replace ALTCRITICAL with ALTCRITMULT'

   In EQUIPMENT files, take ALTCRITICAL and replace with ALTCRITMULT'

=cut

sub removeALTCRITICAL {

   my ($lineTokens, $filetype, $file_for_error, $line_for_error) = @_;

   if (
      Pretty::Options::isConversionActive('EQUIP: ALTCRITICAL to ALTCRITMULT')
      && $filetype eq "EQUIPMENT"
      && exists $lineTokens->{'ALTCRITICAL'}) {

      # Throw warning if both ALTCRITICAL and ALTCRITMULT are on the same line,
      #   then remove ALTCRITICAL.
      if ( exists $lineTokens->{ALTCRITMULT} ) {

         my $logger = Pretty::Reformat::getLogger();

         $logger->warning(
            qq{Removing ALTCRITICAL, ALTCRITMULT already present on same line.},
            $file_for_error,
            $line_for_error
         );
         delete $lineTokens->{'ALTCRITICAL'};

      } else {

         my $logger = Pretty::Reformat::getLogger();

         $logger->warning(
            qq{Change ALTCRITICAL for ALTCRITMULT in "$lineTokens->{'ALTCRITICAL'}[0]"},
            $file_for_error,
            $line_for_error
         );
         my $ttag;
         $ttag = $lineTokens->{'ALTCRITICAL'}[0];
         $ttag =~ s/ALTCRITICAL/ALTCRITMULT/;
         $lineTokens->{'ALTCRITMULT'}[0] = $ttag;
         delete $lineTokens->{'ALTCRITICAL'};
      }
   }
}

=head2 removeMonsterTags

   [ 1514765 ] Conversion to remove old defaultmonster tags
   
   In RACE files, remove all MFEAT and HITDICE tags, but only if
   there is a MONSTERCLASS present.

=cut

sub removeMonsterTags {

   my ($lineTokens, $filetype, $file, $line,) = @_;

   if (Pretty::Options::isConversionActive('RACE:Remove MFEAT and HITDICE') && $filetype eq "RACE") {

      # We remove MFEAT or warn of missing MONSTERCLASS tag.
      if (exists $lineTokens->{'MFEAT'}) { 
         if ( exists $lineTokens->{'MONSTERCLASS'}) { 
            for my $tag ( @{ $lineTokens->{'MFEAT'} } ) {
               $logger->warning(
                  qq{Removing "$tag".},
                  $file,
                  $line
               );
            }
            delete $lineTokens->{'MFEAT'};
         } else {
            warning(
               qq{MONSTERCLASS missing on same line as MFEAT, need to look at by hand.},
               $file,
               $line
            )
         }
      }

      # We remove HITDICE or warn of missing MONSTERCLASS tag.
      if (exists $lineTokens->{'HITDICE'}) { 
         if ( exists $lineTokens->{'MONSTERCLASS'}) { 
            for my $tag ( @{ $lineTokens->{'HITDICE'} } ) {
               $logger->warning(
                  qq{Removing "$tag".},
                  $file,
                  $line
               );
            }
            delete $lineTokens->{'HITDICE'};
         } else {
            warning(
               qq{MONSTERCLASS missing on same line as HITDICE, need to look at by hand.},
               $file,
               $line
            )
         }
      }
   }
}



=head2 removeFollowAlign

   [ 1689538 ] Conversion: Deprecation of FOLLOWERALIGN

   Note: Makes simplifying assumption that FOLLOWERALIGN
   will occur only once in a given line, although DOMAINS may
   occur multiple times.

=cut

sub removeFollowAlign {
   my ($lineTokens, $filetype, $file, $line) = @_;

   if ((Pretty::Options::isConversionActive('DEITY:Followeralign conversion'))
      && $filetype eq "DEITY"
      && (exists $lineTokens->{'FOLLOWERALIGN'}))
   {
      my $followeralign = $lineTokens->{'FOLLOWERALIGN'}[0];
      $followeralign =~ s/^FOLLOWERALIGN://;
      my $newprealign = "";

      for my $align (split //, $followeralign) {
         # Is it a number?
         my $number;
         if ( (($number) = ($align =~ / \A (\d+) \z /xms)) && $number >= 0 && $number < scalar @valid_system_alignments) {

            my $newalign = $valid_system_alignments[$number];
            $newprealign .= ($newprealign ne qq{}) ? ", $newalign" : "$newalign";

         } else {
            $logger->notice(
               qq{Invalid value "$align" for tag "$lineTokens->{'FOLLOWERALIGN'}[0]"},
               $file,
               $line
            );
         }
      }

      my $dom_count=0;

      if (exists $lineTokens->{'DOMAINS'}) {
         for my $line ($lineTokens->{'DOMAINS'})
         {
            $lineTokens->{'DOMAINS'}[$dom_count] .= "|PREALIGN:$newprealign";
            $dom_count++;
         }
         $logger->notice(
            qq{Adding PREALIGN to domain information and removing "$lineTokens->{'FOLLOWERALIGN'}[0]"},
            $file,
            $line
         );

         delete $lineTokens->{'FOLLOWERALIGN'};
      }
   }
}

=head2 convertTypeToRacetype

   [ 1353255 ] TYPE to RACETYPE conversion
   
   Checking race files for TYPE. and if no RACETYPE, convert TYPE to RACETYPE.
   if Race file has no TYPE or RACETYPE, report as 'Info'

=cut

sub convertTypeToRacetype {

   my ($lineTokens, $filetype, $file, $line) = @_;

   # Conversion is only valid for Race or Template
   return unless $filetype eq "RACE" || $filetype eq "TEMPLATE";

   # Do this check no matter what - valid any time
   if ($filetype eq "RACE") {

      my $race_name = $lineTokens->{'000RaceName'}[0];

      # .MOD / .FORGET / .COPY don't need RACETYPE or TYPE'
      if ($race_name !~ /\.(FORGET|MOD|COPY=.+)$/) {

         if (not exists $lineTokens->{'RACETYPE'} && not exists $lineTokens->{'TYPE'}) {

            $logger->warning(
               qq{Race entry missing both TYPE and RACETYPE.},
               $file,
               $line
            );
         }
      };

      if (Pretty::Options::isConversionActive('RACE:TYPE to RACETYPE') 
         && ( $filetype eq "RACE" || $filetype eq "TEMPLATE" )
         && not (exists $lineTokens->{'RACETYPE'})
         && exists $lineTokens->{'TYPE'}) { 

         my $logger = Pretty::Reformat::getLogger();

         $logger->warning(
            qq{Changing TYPE for RACETYPE in "$lineTokens->{'TYPE'}[0]".},
            $file,
            $line
         );
         $lineTokens->{'RACETYPE'} = [ "RACE" . $lineTokens->{'TYPE'}[0] ];
         delete $lineTokens->{'TYPE'};
      };

   }
}

=head2 convertSourceTags

   [ 1444527 ] New SOURCE tag format

   The SOURCELONG tags found on any linetype but the SOURCE line type must
   be converted to use tab if | are found.

=cut

sub convertSourceTags {

   # Don't bother if the conversion is not active
   return unless Pretty::Options::isConversionActive('ALL:New SOURCExxx tag format');

   my ($lineTokens, $file, $line) = @_;

   # nothing to do if there is no SOURCELONG tag
   return unless exists $lineTokens->{'SOURCELONG'};

   my @new_tags;

   for my $tag ( @{ $lineTokens->{'SOURCELONG'} } ) {
      if( $tag =~ / [|] /xms ) {
         push @new_tags, split '\|', $tag;
         $logger->warning(
            qq{Spliting "$tag"},
            $file,
            $line
         );
      }
   }

   if( @new_tags ) {
      delete $lineTokens->{'SOURCELONG'};

      for my $new_tag (@new_tags) {
         my ($tag_name) = ( $new_tag =~ / ( [^:]* ) [:] /xms );
         push @{ $lineTokens->{$tag_name} }, $new_tag;
      }
   }
}

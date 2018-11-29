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

my %SOURCE_file_type_def = ();
my %master_file_type = ();
my @PRE_Tags = ();
my %PRE_Tags = ();
my @double_PCC_tags = ();      
my %double_PCC_tags = ();
my @SOURCE_Tags = ();
my @QUALIFY_Tags = ();
my @Global_BONUS_Tags = ();

# Working variables
my %column_with_no_tag = (

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

# Added FACT:BaseSize despite the fact that this appears to be unused arw - 20180830
my %token_FACT_tag = map { $_ => 1 } (
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

my %token_FACTSET_tag = map { $_ => 1 } (
        'FACTSET:Pantheon',
        'FACTSET:Race',
);


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

my %master_mult;                # Will hold the tags that can be there more then once

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

my %referer;            # Will hold the tags that refer to other entries
                                # Format: push @{$referer{$EntityType}{$entryname}},
                                #               [ $tags{$column}, $file_for_error, $line_for_error ]

my %referer_types;      # Will hold the type used by some of the tags
                                # to allow validation.
                                # Format: push @{$referer_types{$EntityType}{$typename}},
                                #               [ $tags{$column}, $file_for_error, $line_for_error ]

my %referer_categories; # Will hold the categories used by abilities
                                # to allow validation;
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

# Header use for the comment for each of the tag used in the script
my %tagheader = (
        default => {
                '000ClassName'                  => '# Class Name',
                '001SkillName'                  => 'Class Skills (All skills are seperated by a pipe delimiter \'|\')',

                '000DomainName'                 => '# Domain Name',
                '001DomainEffect'                       => 'Description',

                'DESC'                          => 'Description',

                '000AbilityName'                        => '# Ability Name',
                '000FeatName'                   => '# Feat Name',

                '000AbilityCategory',           => '# Ability Category Name',

                '000LanguageName'                       => '# Language',

                'FAVCLASS'                              => 'Favored Class',
                'XTRASKILLPTSPERLVL'            => 'Skills/Level',
                'STARTFEATS'                    => 'Starting Feats',

                '000SkillName'                  => '# Skill Name',

                'KEYSTAT'                               => 'Key Stat',
                'EXCLUSIVE'                             => 'Exclusive?',
                'USEUNTRAINED'                  => 'Untrained?',
                'SITUATION'                             => 'Situational Skill',

                '000TemplateName'                       => '# Template Name',

                '000WeaponName'                 => '# Weapon Name',
                '000ArmorName'                  => '# Armor Name',
                '000ShieldName'                 => '# Shield Name',

                '000VariableName'                       => '# Name',
                '000GlobalmodName'              => '# Name',
                '000DatacontrolName'            => '# Name',
                '000SaveName'                   => '# Name',
                '000StatName'                   => '# Name',
                '000AlignmentName'              => '# Name',
                'DATAFORMAT'                    => 'Dataformat',
                'REQUIRED'                              => 'Required',
                'SELECTABLE'                    => 'Selectable',
                'DISPLAYNAME'                   => 'Displayname',

                'ABILITY'                               => 'Ability',
                'ACCHECK'                               => 'AC Penalty Check',
                'ACHECK'                                => 'Skill Penalty?',
                'ADD'                                   => 'Add',
                'ADD:EQUIP'                             => 'Add Equipment',
                'ADD:FEAT'                              => 'Add Feat',
                'ADD:SAB'                               => 'Add Special Ability',
                'ADD:SKILL'                             => 'Add Skill',
                'ADD:TEMPLATE'                  => 'Add Template',
                'ADDDOMAINS'                    => 'Add Divine Domain',
                'ADDSPELLLEVEL'                 => 'Add Spell Lvl',
                'APPLIEDNAME'                   => 'Applied Name',
                'AGE'                                   => 'Age',
                'AGESET'                                => 'Age Set',
                'ALIGN'                         => 'Align',
                'ALTCRITMULT'                   => 'Alt Crit Mult',
#               'ALTCRITICAL'                   => 'Alternative Critical',
                'ALTCRITRANGE'                  => 'Alt Crit Range',
                'ALTDAMAGE'                             => 'Alt Damage',
                'ALTEQMOD'                              => 'Alt EQModifier',
                'ALTTYPE'                               => 'Alt Type',
                'ATTACKCYCLE'                   => 'Attack Cycle',
                'ASPECT'                                => 'Aspects',
                'AUTO'                          => 'Auto',
                'AUTO:ARMORPROF'                        => 'Auto Armor Prof',
                'AUTO:EQUIP'                    => 'Auto Equip',
                'AUTO:FEAT'                             => 'Auto Feat',
                'AUTO:LANG'                             => 'Auto Language',
                'AUTO:SHIELDPROF'                       => 'Auto Shield Prof',
                'AUTO:WEAPONPROF'                       => 'Auto Weapon Prof',
                'BASEQTY'                               => 'Base Quantity',
                'BENEFIT'                               => 'Benefits',
                'BONUS'                         => 'Bonus',
                'BONUSSPELLSTAT'                        => 'Spell Stat Bonus',
                'BONUS:ABILITYPOOL'             => 'Bonus Ability Pool',
                'BONUS:CASTERLEVEL'             => 'Caster level',
                'BONUS:CHECKS'                  => 'Save checks bonus',
                'BONUS:CONCENTRATION'           => 'Concentration bonus',
                'BONUS:SAVE'                    => 'Save bonus',
                'BONUS:COMBAT'                  => 'Combat bonus',
                'BONUS:DAMAGE'                  => 'Weapon damage bonus',
                'BONUS:DOMAIN'                  => 'Add domain number',
                'BONUS:DC'                              => 'Bonus DC',
                'BONUS:DR'                              => 'Bonus DR',
                'BONUS:EQMARMOR'                        => 'Bonus Armor Mods',
                'BONUS:EQM'                             => 'Bonus Equip Mods',
                'BONUS:EQMWEAPON'                       => 'Bonus Weapon Mods',
                'BONUS:ESIZE'                   => 'Modify size',
                'BONUS:FEAT'                    => 'Number of Feats',
                'BONUS:FOLLOWERS'                       => 'Number of Followers',
                'BONUS:HD'                              => 'Modify HD type',
                'BONUS:HP'                              => 'Bonus to HP',
                'BONUS:ITEMCOST'                        => 'Modify the item cost',
                'BONUS:LANGUAGES'                       => 'Bonus language',
                'BONUS:MISC'                    => 'Misc bonus',
                'BONUS:MOVEADD'                 => 'Add to base move',
                'BONUS:MOVEMULT'                        => 'Multiply base move',
                'BONUS:POSTMOVEADD'             => 'Add to magical move',
                'BONUS:PCLEVEL'                 => 'Caster level bonus',
                'BONUS:POSTRANGEADD'            => 'Bonus to Range',
                'BONUS:RANGEADD'                        => 'Bonus to base range',
                'BONUS:RANGEMULT'                       => '% bonus to range',
                'BONUS:REPUTATION'              => 'Bonus to Reputation',
                'BONUS:SIZEMOD'                 => 'Adjust PC Size',
                'BONUS:SKILL'                   => 'Bonus to skill',
                'BONUS:SITUATION'                       => 'Bonus to Situation',
                'BONUS:SKILLPOINTS'             => 'Bonus to skill point/L',
                'BONUS:SKILLPOOL'                       => 'Bonus to skill point for a level',
                'BONUS:SKILLRANK'                       => 'Bonus to skill rank',
                'BONUS:SLOTS'                   => 'Bonus to nb of slots',
                'BONUS:SPELL'                   => 'Bonus to spell attribute',
                'BONUS:SPECIALTYSPELLKNOWN'     => 'Bonus Specialty spells',
                'BONUS:SPELLCAST'                       => 'Bonus to spell cast/day',
                'BONUS:SPELLCASTMULT'           => 'Multiply spell cast/day',
                'BONUS:SPELLKNOWN'              => 'Bonus to spell known/L',
                'BONUS:STAT'                    => 'Stat bonus',
                'BONUS:TOHIT'                   => 'Attack roll bonus',
                'BONUS:UDAM'                    => 'Unarmed Damage Level bonus',
                'BONUS:VAR'                             => 'Modify VAR',
                'BONUS:VISION'                  => 'Add to vision',
                'BONUS:WEAPON'                  => 'Weapon prop. bonus',
                'BONUS:WEAPONPROF'              => 'Weapon prof. bonus',
                'BONUS:WIELDCATEGORY'           => 'Wield Category bonus',
                'TEMPBONUS'                             => 'Temporary Bonus',
                'CAST'                          => 'Cast',
                'CASTAS'                                => 'Cast As',
                'CASTTIME:.CLEAR'                       => 'Clear Casting Time',
                'CASTTIME'                              => 'Casting Time',
                'CATEGORY'                              => 'Category of Ability',
                'CCSKILL:.CLEAR'                        => 'Remove Cross-Class Skill',
                'CCSKILL'                               => 'Cross-Class Skill',
                'CHANGEPROF'                    => 'Change Weapon Prof. Category',
                'CHOOSE'                                => 'Choose',
                'CLASSES'                               => 'Classes',
                'COMPANIONLIST'                 => 'Allowed Companions',
                'COMPS'                         => 'Components',
                'CONTAINS'                              => 'Contains',
                'COST'                          => 'Cost',
                'CR'                                    => 'Challenge Rating',
                'CRMOD'                         => 'CR Modifier',
                'CRITMULT'                              => 'Crit Mult',
                'CRITRANGE'                             => 'Crit Range',
                'CSKILL:.CLEAR'                 => 'Remove Class Skill',
                'CSKILL'                                => 'Class Skill',
                'CT'                                    => 'Casting Threshold',
                'DAMAGE'                                => 'Damage',
                'DEF'                                   => 'Def',
                'DEFINE'                                => 'Define',
                'DEFINESTAT'                    => 'Define Stat',
                'DEITY'                         => 'Deity',
                'DESC'                          => 'Description',
                'DESC:.CLEAR'                   => 'Clear Description',
                'DESCISPI'                              => 'Desc is PI?',
                'DESCRIPTOR:.CLEAR'             => 'Clear Spell Descriptors',
                'DESCRIPTOR'                    => 'Descriptor',
                'DOMAIN'                                => 'Domain',
                'DOMAINS'                               => 'Domains',
                'DONOTADD'                              => 'Do Not Add',
                'DR:.CLEAR'                             => 'Remove Damage Reduction',
                'DR'                                    => 'Damage Reduction',
                'DURATION:.CLEAR'                       => 'Clear Duration',
                'DURATION'                              => 'Duration',
#               'EFFECTS'                               => 'Description',                               # Deprecated a long time ago for TARGETAREA
                'EQMOD'                         => 'Modifier',
                'EXCLASS'                               => 'Ex Class',
                'EXPLANATION'                   => 'Explanation',
                'FACE'                          => 'Face/Space',
                'FACT:Abb'                              => 'Abbreviation',
                'FACT:SpellType'                        => 'Spell Type',
                'FEAT'                          => 'Feat',
                'FEATAUTO'                              => 'Feat Auto',
                'FOLLOWERS'                             => 'Allow Follower',
                'FREE'                          => 'Free',
                'FUMBLERANGE'                   => 'Fumble Range',
                'GENDER'                                => 'Gender',
                'HANDS'                         => 'Nb Hands',
                'HASSUBCLASS'                   => 'Subclass?',
                'ALLOWBASECLASS'                        => 'Base class as subclass?',
                'HD'                                    => 'Hit Dice',
                'HEIGHT'                                => 'Height',
                'HITDIE'                                => 'Hit Dice Size',
                'HITDICEADVANCEMENT'            => 'Hit Dice Advancement',
                'HITDICESIZE'                   => 'Hit Dice Size',
                'ITEM'                          => 'Item',
                'KEY'                                   => 'Unique Key',
                'KIT'                                   => 'Apply Kit',
                'KNOWN'                         => 'Known',
                'KNOWNSPELLS'                   => 'Automatically Known Spell Levels',
                'LANGAUTO'                              => 'Automatic Languages',               # Deprecated
                'LANGAUTO:.CLEAR'                       => 'Clear Automatic Languages', # Deprecated
                'LANGBONUS'                             => 'Bonus Languages',
                'LANGBONUS:.CLEAR'              => 'Clear Bonus Languages',
                'LEGS'                          => 'Nb Legs',
                'LEVEL'                         => 'Level',
                'LEVELADJUSTMENT'                       => 'Level Adjustment',
#               'LONGNAME'                              => 'Long Name',                         # Deprecated in favor of OUTPUTNAME
                'MAXCOST'                               => 'Maximum Cost',
                'MAXDEX'                                => 'Maximum DEX Bonus',
                'MAXLEVEL'                              => 'Max Level',
                'MEMORIZE'                              => 'Memorize',
                'MFEAT'                         => 'Default Monster Feat',
                'MONSKILL'                              => 'Monster Initial Skill Points',
                'MOVE'                          => 'Move',
                'MOVECLONE'                             => 'Clone Movement',
                'MULT'                          => 'Multiple?',
                'NAMEISPI'                              => 'Product Identity?',
                'NATURALARMOR'                  => 'Natural Armor',
                'NATURALATTACKS'                        => 'Natural Attacks',
                'NUMPAGES'                              => 'Number of Pages',                   # [ 1450980 ] New Spellbook tags
                'OUTPUTNAME'                    => 'Output Name',
                'PAGEUSAGE'                             => 'Page Usage',                                # [ 1450980 ] New Spellbook tags
                'PANTHEON'                              => 'Pantheon',
                'PPCOST'                                => 'Power Points',                      # [ 1814797 ] PPCOST needs to added as valid tag in SPELLS
                'PRE:.CLEAR'                    => 'Clear Prereq.',
                'PREABILITY'                    => 'Required Ability',
                '!PREABILITY'                   => 'Restricted Ability',
                'PREAGESET'                             => 'Minimum Age',
                '!PREAGESET'                    => 'Maximum Age',
                'PREALIGN'                              => 'Required AL',
                '!PREALIGN'                             => 'Restricted AL',
                'PREATT'                                => 'Req. Att.',
                'PREARMORPROF'                  => 'Req. Armor Prof.',
                '!PREARMORPROF'                 => 'Prohibited Armor Prof.',
                'PREBASESIZEEQ'                 => 'Required Base Size',
                '!PREBASESIZEEQ'                        => 'Prohibited Base Size',
                'PREBASESIZEGT'                 => 'Minimum Base Size',
                'PREBASESIZEGTEQ'                       => 'Minimum Size',
                'PREBASESIZELT'                 => 'Maximum Base Size',
                'PREBASESIZELTEQ'                       => 'Maximum Size',
                'PREBASESIZENEQ'                        => 'Prohibited Base Size',
                'PRECAMPAIGN'                   => 'Required Campaign(s)',
                '!PRECAMPAIGN'                  => 'Prohibited Campaign(s)',
                'PRECHECK'                              => 'Required Check',
                '!PRECHECK'                             => 'Prohibited Check',
                'PRECHECKBASE'                  => 'Required Check Base',
                'PRECITY'                               => 'Required City',
                '!PRECITY'                              => 'Prohibited City',
                'PRECLASS'                              => 'Required Class',
                '!PRECLASS'                             => 'Prohibited Class',
                'PRECLASSLEVELMAX'              => 'Maximum Level Allowed',
                '!PRECLASSLEVELMAX'             => 'Should use PRECLASS',
                'PRECSKILL'                             => 'Required Class Skill',
                '!PRECSKILL'                    => 'Prohibited Class SKill',
                'PREDEITY'                              => 'Required Deity',
                '!PREDEITY'                             => 'Prohibited Deity',
                'PREDEITYDOMAIN'                        => 'Required Deitys Domain',
                'PREDOMAIN'                             => 'Required Domain',
                '!PREDOMAIN'                    => 'Prohibited Domain',
                'PREDSIDEPTS'                   => 'Req. Dark Side',
                'PREDR'                         => 'Req. Damage Resistance',
                '!PREDR'                                => 'Prohibited Damage Resistance',
                'PREEQUIP'                              => 'Req. Equipement',
                'PREEQMOD'                              => 'Req. Equipment Mod.',
                '!PREEQMOD'                             => 'Prohibited Equipment Mod.',
                'PREFEAT'                               => 'Required Feat',
                '!PREFEAT'                              => 'Prohibited Feat',
                'PREGENDER'                             => 'Required Gender',
                '!PREGENDER'                    => 'Prohibited Gender',
                'PREHANDSEQ'                    => 'Req. nb of Hands',
                'PREHANDSGT'                    => 'Min. nb of Hands',
                'PREHANDSGTEQ'                  => 'Min. nb of Hands',
                'PREHD'                         => 'Required Hit Dice',
                'PREHP'                         => 'Required Hit Points',
                'PREITEM'                               => 'Required Item',
                'PRELANG'                               => 'Required Language',
                'PRELEVEL'                              => 'Required Lvl',
                'PRELEVELMAX'                   => 'Maximum Level',
                'PREKIT'                                => 'Required Kit',
                '!PREKIT'                               => 'Prohibited Kit',
                'PREMOVE'                               => 'Required Movement Rate',
                '!PREMOVE'                              => 'Prohibited Movement Rate',
                'PREMULT'                               => 'Multiple Requirements',
                '!PREMULT'                              => 'Multiple Prohibitions',
                'PREPCLEVEL'                    => 'Required Non-Monster Lvl',
                'PREPROFWITHARMOR'              => 'Required Armor Proficiencies',
                '!PREPROFWITHARMOR'             => 'Prohibited Armor Proficiencies',
                'PREPROFWITHSHIELD'             => 'Required Shield Proficiencies',
                '!PREPROFWITHSHIELD'            => 'Prohbited Shield Proficiencies',
                'PRERACE'                               => 'Required Race',
                '!PRERACE'                              => 'Prohibited Race',
                'PRERACETYPE'                   => 'Reg. Race Type',
                'PREREACH'                              => 'Minimum Reach',
                'PREREACHEQ'                    => 'Required Reach',
                'PREREACHGT'                    => 'Minimum Reach',
                'PREREGION'                             => 'Required Region',
                '!PREREGION'                    => 'Prohibited Region',
                'PRERULE'                               => 'Req. Rule (in options)',
                'PRESA'                         => 'Req. Special Ability',
                '!PRESA'                                => 'Prohibite Special Ability',
                'PRESHIELDPROF'                 => 'Req. Shield Prof.',
                '!PRESHIELDPROF'                        => 'Prohibited Shield Prof.',
                'PRESIZEEQ'                             => 'Required Size',
                'PRESIZEGT'                             => 'Must be Larger',
                'PRESIZEGTEQ'                   => 'Minimum Size',
                'PRESIZELT'                             => 'Must be Smaller',
                'PRESIZELTEQ'                   => 'Maximum Size',
                'PRESKILL'                              => 'Required Skill',
                '!PRESITUATION'                 => 'Prohibited Situation',
                'PRESITUATION'                  => 'Required Situation',
                '!PRESKILL'                             => 'Prohibited Skill',
                'PRESKILLMULT'                  => 'Special Required Skill',
                'PRESKILLTOT'                   => 'Total Skill Points Req.',
                'PRESPELL'                              => 'Req. Known Spell',
                'PRESPELLBOOK'                  => 'Req. Spellbook',
                'PRESPELLBOOK'                  => 'Req. Spellbook',
                'PRESPELLCAST'                  => 'Required Casting Type',
                '!PRESPELLCAST'                 => 'Prohibited Casting Type',
                'PRESPELLDESCRIPTOR'            => 'Required Spell Descriptor',
                '!PRESPELLDESCRIPTOR'           => 'Prohibited Spell Descriptor',
                'PRESPELLSCHOOL'                        => 'Required Spell School',
                'PRESPELLSCHOOLSUB'             => 'Required Sub-school',
                '!PRESPELLSCHOOLSUB'            => 'Prohibited Sub-school',
                'PRESPELLTYPE'                  => 'Req. Spell Type',
                'PRESREQ'                               => 'Req. Spell Resist',
                'PRESRGT'                               => 'SR Must be Greater',
                'PRESRGTEQ'                             => 'SR Min. Value',
                'PRESRLT'                               => 'SR Must be Lower',
                'PRESRLTEQ'                             => 'SR Max. Value',
                'PRESRNEQ'                              => 'Prohibited SR Value',
                'PRESTAT'                               => 'Required Stat',
                '!PRESTAT',                             => 'Prohibited Stat',
                'PRESUBCLASS'                   => 'Required Subclass',
                '!PRESUBCLASS'                  => 'Prohibited Subclass',
                'PRETEMPLATE'                   => 'Required Template',
                '!PRETEMPLATE'                  => 'Prohibited Template',
                'PRETEXT'                               => 'Required Text',
                'PRETYPE'                               => 'Required Type',
                '!PRETYPE'                              => 'Prohibited Type',
                'PREVAREQ'                              => 'Required Var. value',
                '!PREVAREQ'                             => 'Prohibited Var. Value',
                'PREVARGT'                              => 'Var. Must Be Grater',
                'PREVARGTEQ'                    => 'Var. Min. Value',
                'PREVARLT'                              => 'Var. Must Be Lower',
                'PREVARLTEQ'                    => 'Var. Max. Value',
                'PREVARNEQ'                             => 'Prohibited Var. Value',
                'PREVISION'                             => 'Required Vision',
                '!PREVISION'                    => 'Prohibited Vision',
                'PREWEAPONPROF'                 => 'Req. Weapond Prof.',
                '!PREWEAPONPROF'                        => 'Prohibited Weapond Prof.',
                'PREWIELD'                              => 'Required Wield Category',
                '!PREWIELD'                             => 'Prohibited Wield Category',
                'PROFICIENCY:WEAPON'            => 'Required Weapon Proficiency',
                'PROFICIENCY:ARMOR'             => 'Required Armor Proficiency',
                'PROFICIENCY:SHIELD'            => 'Required Shield Proficiency',
                'PROHIBITED'                    => 'Spell Scoll Prohibited',
                'PROHIBITSPELL'                 => 'Group of Prohibited Spells',
                'QUALIFY:CLASS'                 => 'Qualify for Class',
                'QUALIFY:DEITY'                 => 'Qualify for Deity',
                'QUALIFY:DOMAIN'                        => 'Qualify for Domain',
                'QUALIFY:EQUIPMENT'             => 'Qualify for Equipment',
                'QUALIFY:EQMOD'                 => 'Qualify for Equip Modifier',
                'QUALIFY:FEAT'                  => 'Qualify for Feat',
                'QUALIFY:RACE'                  => 'Qualify for Race',
                'QUALIFY:SPELL'                 => 'Qualify for Spell',
                'QUALIFY:SKILL'                 => 'Qualify for Skill',
                'QUALIFY:TEMPLATE'              => 'Qualify for Template',
                'QUALIFY:WEAPONPROF'            => 'Qualify for Weapon Proficiency',
                'RACESUBTYPE:.CLEAR'            => 'Clear Racial Subtype',
                'RACESUBTYPE'                   => 'Race Subtype',
                'RACETYPE:.CLEAR'                       => 'Clear Main Racial Type',
                'RACETYPE'                              => 'Main Race Type',
                'RANGE:.CLEAR'                  => 'Clear Range',
                'RANGE'                         => 'Range',
                'RATEOFFIRE'                    => 'Rate of Fire',
                'REACH'                         => 'Reach',
                'REACHMULT'                             => 'Reach Multiplier',
                'REGION'                                => 'Region',
                'REPEATLEVEL'                   => 'Repeat this Level',
                'REMOVABLE'                             => 'Removable?',
                'REMOVE'                                => 'Remove Object',
                'REP'                                   => 'Reputation',
                'ROLE'                          => 'Monster Role',
                'SA'                                    => 'Special Ability',
                'SA:.CLEAR'                             => 'Clear SAs',
                'SAB:.CLEAR'                    => 'Clear Special ABility',
                'SAB'                                   => 'Special ABility',
                'SAVEINFO'                              => 'Save Info',
                'SCHOOL:.CLEAR'                 => 'Clear School',
                'SCHOOL'                                => 'School',
                'SELECT'                                => 'Selections',
                'SERVESAS'                              => 'Serves As',
                'SIZE'                          => 'Size',
                'SKILLLIST'                             => 'Use Class Skill List',
                'SOURCE'                                => 'Source Index',
                'SOURCEPAGE:.CLEAR'             => 'Clear Source Page',
                'SOURCEPAGE'                    => 'Source Page',
                'SOURCELONG'                    => 'Source, Long Desc.',
                'SOURCESHORT'                   => 'Source, Short Desc.',
                'SOURCEWEB'                             => 'Source URI',
                'SOURCEDATE'                    => 'Source Pub. Date',
                'SOURCELINK'                    => 'Source Pub Link',
                'SPELLBOOK'                             => 'Spellbook',
                'SPELLFAILURE'                  => '% of Spell Failure',
                'SPELLLIST'                             => 'Use Spell List',
                'SPELLKNOWN:CLASS'              => 'List of Known Class Spells by Level',
                'SPELLKNOWN:DOMAIN'             => 'List of Known Domain Spells by Level',
                'SPELLLEVEL:CLASS'              => 'List of Class Spells by Level',
                'SPELLLEVEL:DOMAIN'             => 'List of Domain Spells by Level',
                'SPELLRES'                              => 'Spell Resistance',
                'SPELL'                         => 'Deprecated Spell tag',
                'SPELLS'                                => 'Innate Spells',
                'SPELLSTAT'                             => 'Spell Stat',
                'SPELLTYPE'                             => 'Spell Type',
                'SPROP:.CLEAR'                  => 'Clear Special Property',
                'SPROP'                         => 'Special Property',
                'SR'                                    => 'Spell Res.',
                'STACK'                         => 'Stackable?',
                'STARTSKILLPTS'                 => 'Skill Pts/Lvl',
                'STAT'                          => 'Key Attribute',
                'SUBCLASSLEVEL'                 => 'Subclass Level',
                'SUBRACE'                               => 'Subrace',
                'SUBREGION'                             => 'Subregion',
                'SUBSCHOOL'                             => 'Sub-School',
                'SUBSTITUTIONLEVEL'             => 'Substitution Level',
                'SYNERGY'                               => 'Synergy Skill',
                'TARGETAREA:.CLEAR'             => 'Clear Target Area or Effect',
                'TARGETAREA'                    => 'Target Area or Effect',
                'TEMPDESC'                              => 'Temporary effect description',
                'TEMPLATE'                              => 'Template',
                'TEMPLATE:.CLEAR'                       => 'Clear Templates',
                'TYPE'                          => 'Type',
                'TYPE:.CLEAR'                   => 'Clear Types',
                'UDAM'                          => 'Unarmed Damage',
                'UMULT'                         => 'Unarmed Multiplier',
                'UNENCUMBEREDMOVE'              => 'Ignore Encumberance',
                'VARIANTS'                              => 'Spell Variations',
                'VFEAT'                         => 'Virtual Feat',
                'VFEAT:.CLEAR'                  => 'Clear Virtual Feat',
                'VISIBLE'                               => 'Visible',
                'VISION'                                => 'Vision',
                'WEAPONBONUS'                   => 'Optionnal Weapon Prof.',
                'WEIGHT'                                => 'Weight',
                'WT'                                    => 'Weight',
                'XPCOST'                                => 'XP Cost',
                'XTRAFEATS'                             => 'Extra Feats',
        },

        'ABILITYCATEGORY' => {
                '000AbilityCategory'            => '# Ability Category',
                'CATEGORY'                              => 'Category of Object',
                'DISPLAYLOCATION'                       => 'Display Location',
                'DISPLAYNAME'                   => 'Display where?',
                'EDITABLE'                              => 'Editable?',
                'EDITPOOL'                              => 'Change Pool?',
                'FRACTIONALPOOL'                        => 'Fractional values?',
                'PLURAL'                                => 'Plural description for UI',
                'POOL'                          => 'Base Pool number',
                'TYPE'                          => 'Type of Object',
                'ABILITYLIST'                   => 'Specific choices list',
                'VISIBLE'                               => 'Visible',
        },

        'BIOSET AGESET' => {
                'AGESET'                                => '# Age set',
        },

        'BIOSET RACENAME' => {
                'RACENAME'                              => '# Race name',
        },

        'CLASS' => {
                '000ClassName'                  => '# Class Name',
                'FACT:CLASSTYPE'                        => 'Class Type',
                'CLASSTYPE'                             => 'Class Type',
                'FACT:Abb'                              => 'Abbreviation',
                'ABB'                                   => 'Abbreviation',
                'ALLOWBASECLASS',                       => 'Base class as subclass?',
                'HASSUBSTITUTIONLEVEL'          => 'Substitution levels?',
#               'HASSPELLFORMULA'                       => 'Spell Fomulas?',                    # [ 1893279 ] HASSPELLFORMULA Class Line tag # [ 1973497 ] HASSPELLFORMULA is deprecated
                'ITEMCREATE'                    => 'Craft Level Mult.',
                'LEVELSPERFEAT'                 => 'Levels per Feat',
                'MODTOSKILLS'                   => 'Add INT to Skill Points?',
                'MONNONSKILLHD'                 => 'Extra Hit Die Skills Limit',
                'MULTIPREREQS'                  => 'MULTIPREREQS',
                'SPECIALS'                              => 'Class Special Ability',             # Deprecated - Use SA
                'DEITY'                         => 'Deities allowed',
                'ROLE'                          => 'Monster Role',
        },

        'CLASS Level' => {
                '000Level'                              => '# Level',
        },

        'COMPANIONMOD' => {
                '000Follower'                   => '# Class of the Master',
                '000MasterBonusRace'            => '# Race of familiar',
                'COPYMASTERBAB'                 => 'Copy Masters BAB',
                'COPYMASTERCHECK'                       => 'Copy Masters Checks',
                'COPYMASTERHP'                  => 'HP formula based on Master',
                'FOLLOWER'                              => 'Added Value',
                'SWITCHRACE'                    => 'Change Racetype',
                'USEMASTERSKILL'                => 'Use Masters skills?',
        },

        'DEITY' => {
                '000DeityName'                  => '# Deity Name',
                'DOMAINS'                               => 'Domains',
                'FOLLOWERALIGN'                 => 'Clergy AL',
                'DESC'                          => 'Description of Deity/Title',
                'FACT:SYMBOL'                   => 'Holy Item',
                'SYMBOL'                                => 'Holy Item',
                'DEITYWEAP'                             => 'Deity Weapon',
                'FACT:TITLE'                    => 'Deity Title',
                'TITLE'                         => 'Deity Title',
                'FACTSET:WORSHIPPERS'           => 'Usual Worshippers',
                'WORSHIPPERS'                   => 'Usual Worshippers',
                'FACT:APPEARANCE'                       => 'Deity Appearance',
                'APPEARANCE'                    => 'Deity Appearance',
                'ABILITY'                               => 'Granted Ability',
        },

        'EQUIPMENT' => {
                '000EquipmentName'              => '# Equipment Name',
                'BASEITEM'                              => 'Base Item for EQMOD',
                'RESIZE'                                => 'Can be Resized',
                'QUALITY'                               => 'Quality and value',
                'SLOTS'                         => 'Slot Needed',
                'WIELD'                         => 'Wield Category',
                'MODS'                          => 'Requires Modification?',
        },

        'EQUIPMOD' => {
                '000ModifierName'                       => '# Modifier Name',
                'ADDPROF'                               => 'Add Req. Prof.',
                'ARMORTYPE'                             => 'Change Armor Type',
                'ASSIGNTOALL'                   => 'Apply to both heads',
                'CHARGES'                               => 'Nb of Charges',
                'COSTPRE'                               => 'Cost before resizing',
                'FORMATCAT'                             => 'Naming Format',                     #[ 1594671 ] New tag: equipmod FORMATCAT
                'IGNORES'                               => 'Keys to ignore',
                'ITYPE'                         => 'Type granted',
                'KEY'                                   => 'Unique Key',
                'NAMEOPT'                               => 'Naming Option',
                'PLUS'                          => 'Plus',
                'REPLACES'                              => 'Keys to replace',
        },

        'KIT STARTPACK' => {
                'STARTPACK'                             => '# Kit Name',
                'APPLY'                         => 'Apply method to char',              #[ 1593879 ] New Kit tag: APPLY
        },

        'KIT CLASS' => {
                'CLASS'                         => '# Class',
        },

        'KIT FUNDS' => {
                'FUNDS'                         => '# Funds',
        },

        'KIT GEAR' => {
                'GEAR'                          => '# Gear',
        },

        'KIT LANGBONUS' => {
                'LANGBONUS'                             => '# Bonus Language',
        },

        'KIT NAME' => {
                'NAME'                          => '# Name',
        },

        'KIT RACE' => {
                'RACE'                          => '# Race',
        },

        'KIT SELECT' => {
                'SELECT'                                => '# Select choice',
        },

        'KIT SKILL' => {
                'SKILL'                         => '# Skill',
                'SELECTION'                             => 'Selections',
        },

        'KIT TABLE' => {
                'TABLE'                         => '# Table name',
                'VALUES'                                => 'Table Values',
        },

        'MASTERBONUSRACE' => {
                '000MasterBonusRace'            => '# Race of familiar',
        },

        'RACE' => {
                '000RaceName'                   => '# Race Name',
                'FACT'                          => 'Base size',
                'FAVCLASS'                              => 'Favored Class',
                'SKILLMULT'                             => 'Skill Multiplier',
                'MONCSKILL'                             => 'Racial HD Class Skills',
                'MONCCSKILL'                    => 'Racial HD Cross-class Skills',
                'MONSTERCLASS'                  => 'Monster Class Name and Starting Level',
        },

        'SPELL' => {
                '000SpellName'                  => '# Spell Name',
                'CLASSES'                               => 'Classes of caster',
                'DOMAINS'                               => 'Domains granting the spell',
        },

        'SUBCLASS' => {
                '000SubClassName'                       => '# Subclass',
        },

        'SUBSTITUTIONCLASS' => {
                '000SubstitutionClassName'      => '# Substitution Class',
        },

        'TEMPLATE' => {
                '000TemplateName'                       => '# Template Name',
                'ADDLEVEL'                              => 'Add Levels',
                'BONUS:MONSKILLPTS'             => 'Bonus Monster Skill Points',
                'BONUSFEATS'                    => 'Number of Bonus Feats',
                'FAVOREDCLASS'                  => 'Favored Class',
                'GENDERLOCK'                    => 'Lock Gender Selection',
        },

        'VARIABLE' => {
                '000VariableName'                       => '# Variable Name',
                'EXPLANATION'                   => 'Explanation',
        },

        'GLOBALMOD' => {
                '000GlobalmodName'              => '# Name',
                'EXPLANATION'                   => 'Explanation',
        },

        'DATACONTROL' => {
                '000DatacontrolName'            => '# Name',
                'EXPLANATION'                   => 'Explanation',
        },
        'ALIGNMENT' => {
                '000AlignmentName'              => '# Name',
        },
        'STAT' => {
                '000StatName'                   => '# Name',
        },
        'SAVE' => {
                '000SaveName'                   => '# Name',
        },

);

my $tablength = 6;      # Tabulation each 6 characters

my %files_to_parse;     # Will hold the file to parse (including path)
my @lines;                      # Will hold all the lines of the file
my @modified_files;     # Will hold the name of the modified files

#####################################
# Verify if the inputpath was given

if (getOption('inputpath')) {

   # Construct the data structure that tells us whcih tags are valid for a line.
   Pretty::Reformat::constructValidTags();

   ##########################################################
   # Files that needs to be open for special conversions

   

   if ( Pretty::Options::isConversionActive('Export lists') ) {
      # The files should be opened in alpha order since they will
      # be closed in reverse alpha order.

      # Will hold the list of all classes found in CLASS filetypes
      open $filehandle_for{CLASS}, '>', 'class.csv';
      print { $filehandle_for{CLASS} } qq{"Class Name","Line","Filename"\n};

      # Will hold the list of all deities found in DEITY filetypes
      open $filehandle_for{DEITY}, '>', 'deity.csv';
      print { $filehandle_for{DEITY} } qq{"Deity Name","Line","Filename"\n};

      # Will hold the list of all domains found in DOMAIN filetypes
      open $filehandle_for{DOMAIN}, '>', 'domain.csv';
      print { $filehandle_for{DOMAIN} } qq{"Domain Name","Line","Filename"\n};

      # Will hold the list of all equipements found in EQUIPMENT filetypes
      open $filehandle_for{EQUIPMENT}, '>', 'equipment.csv';
      print { $filehandle_for{EQUIPMENT} } qq{"Equipment Name","Output Name","Line","Filename"\n};

      # Will hold the list of all equipmod entries found in EQUIPMOD filetypes
      open $filehandle_for{EQUIPMOD}, '>', 'equipmod.csv';
      print { $filehandle_for{EQUIPMOD} } qq{"Equipmod Name","Key","Type","Line","Filename"\n};

      # Will hold the list of all feats found in FEAT filetypes
      open $filehandle_for{FEAT}, '>', 'feat.csv';
      print { $filehandle_for{FEAT} } qq{"Feat Name","Line","Filename"\n};

      # Will hold the list of all kits found in KIT filetypes
      open $filehandle_for{KIT}, '>', 'kit.csv';
      print { $filehandle_for{KIT} } qq{"Kit Startpack Name","Line","Filename"\n};

      # Will hold the list of all kit Tables found in KIT filetypes
      open $filehandle_for{TABLE}, '>', 'kit-table.csv';
      print { $filehandle_for{TABLE} } qq{"Table Name","Line","Filename"\n};

      # Will hold the list of all language found in LANGUAGE linetypes
      open $filehandle_for{LANGUAGE}, '>', 'language.csv';
      print { $filehandle_for{LANGUAGE} } qq{"Language Name","Line","Filename"\n};

      # Will hold the list of all PCC files found
      open $filehandle_for{PCC}, '>', 'pcc.csv';
      print { $filehandle_for{PCC} } qq{"SOURCELONG","SOURCESHORT","GAMEMODE","Full Path"\n};

      # Will hold the list of all races and race types found in RACE filetypes
      open $filehandle_for{RACE}, '>', 'race.csv';
      print { $filehandle_for{RACE} } qq{"Race Name","Race Type","Race Subtype","Line","Filename"\n};

      # Will hold the list of all skills found in SKILL filetypes
      open $filehandle_for{SKILL}, '>', 'skill.csv';
      print { $filehandle_for{SKILL} } qq{"Skill Name","Line","Filename"\n};

      # Will hold the list of all spells found in SPELL filetypes
      open $filehandle_for{SPELL}, '>', 'spell.csv';
      print { $filehandle_for{SPELL} } qq{"Spell Name","Source Page","Line","Filename"\n};

      # Will hold the list of all templates found in TEMPLATE filetypes
      open $filehandle_for{TEMPLATE}, '>', 'template.csv';
      print { $filehandle_for{TEMPLATE} } qq{"Tempate Name","Line","Filename"\n};

      # Will hold the list of all variables found in DEFINE tags
      if ( getOption('xcheck') ) {
         open $filehandle_for{VARIABLE}, '>', 'variable.csv';
         print { $filehandle_for{VARIABLE} } qq{"Var Name","Line","Filename"\n};
      }

      # We need to list the tags that use Willpower
      if ( Pretty::Options::isConversionActive('ALL:Find Willpower') ) {
         open $filehandle_for{Willpower}, '>', 'willpower.csv';
         print { $filehandle_for{Willpower} } qq{"Tag","Line","Filename"\n};
      }
   }

        ##########################################################
        # Cross-checking must be activated for the CLASSSPELL
        # conversion to work
        if ( Pretty::Options::isConversionActive('CLASSSPELL conversion to SPELL') ) {

                setOption(xcheck, 1);
        }

        ##########################################################
        # Parse all the .pcc file to find the other file to parse

        # First, we list the .pcc files in the directory
        my @filelist;
        my %filelist_notpcc;
        my %filelist_missing;

        # Regular expressions for the files that must be skiped by mywanted.
        my @filetoskip = (
                qr(^\.\#),                      # Files begining with .# (CVS conflict and deleted files)
                qr(^custom),            # Customxxx files generated by PCGEN
                qr(placeholder\.txt$),  # The CMP directories are full of these
                qr(\.zip$)i,            # Archives present in the directories
                qr(\.rar$)i,
                qr(\.jpg$),                     # JPEG image files present in the directories
                qr(\.png$),                     # PNG image files present in the directories
#               gr(Thumbs\.db$),                # thumbnails image files used with Win32 OS
                qr(readme\.txt$),               # Readme files
#               qr(notes\.txt$),                # Notes files
                qr(\.bak$),                     # Backup files
                qr(\.java$),            # Java code files
                qr(\.htm$),                     # HTML files
                qr(\.xml$),
                qr(\.css$),

                qr(\.DS_Store$),                # Used with Mac OS
        );

        # Regular expressions for the directory that must be skiped by mywanted
        my @dirtoskip = (
                qr(cvs$)i,                      # /cvs directories
                qr([.]svn[/])i,         # All .svn directories
                qr([.]svn$)i,           # All .svn directories
                qr([.]git[/])i,         # All .git directories
                qr([.]git$)i,           # All .git directories
                qr(customsources$)i,    # /customsources (for files generated by PCGEN)
                qr(gamemodes)i,         # for the system gameModes directories
#               qr(alpha)i
        );

        sub mywanted {

                # We skip the files from directory matching the REGEX in @dirtoskip
                for my $regex (@dirtoskip) {
                        return if $File::Find::dir =~ $regex;
                }

                # We also skip the files that match the REGEX in @filetoskip
                for my $regex (@filetoskip) {
                        return if $_ =~ $regex;
                }

                if ( !-d && / [.] pcc \z /xmsi ) {
                        push @filelist, $File::Find::name;
                }

                if ( !-d && !/ [.] pcc \z /xmsi ) {
                        $filelist_notpcc{$File::Find::name} = lc $_;
                }
        }
        File::Find::find( \&mywanted, getOption('inputpath') );

        $logging->set_header(constructLoggingHeader('PCC'));

        # Second we parse every .PCC and look for filetypes
        for my $pcc_file_name ( sort @filelist ) {
                open my $pcc_fh, '<', $pcc_file_name;

                # Needed to find the full path
                my $currentbasedir = File::Basename::dirname($pcc_file_name);

                my $must_write          = NO;
                my $BOOKTYPE_found      = NO;
                my $GAMEMODE_found      = q{};          # For the PCC export list
                my $SOURCELONG_found    = q{};          #
                my $SOURCESHORT_found   = q{};          #
                my $LST_found           = NO;
                my @pcc_lines           = ();
                my %found_filetype;
                my $continue            = YES;

                PCC_LINE:
                while ( <$pcc_fh> ) {
                last PCC_LINE if !$continue;

                chomp;
                $must_write += s/[\x0d\x0a]//g; # Remove the real and weird CR-LF
                $must_write += s/\s+$//;                # Remove the tralling white spaces

                push @pcc_lines, $_;

                my ( $tag, $value ) = parse_tag( $_, 'PCC', $pcc_file_name, $INPUT_LINE_NUMBER );

                if ( $tag && "$tag:$value" ne $pcc_lines[-1] ) {

                        # The parse_tag function modified the values.
                        $must_write = YES;
                        if ( $double_PCC_tags{$tag} ) {
                                $pcc_lines[-1] = "$tag$value";
                        }
                        else { 
                                $pcc_lines[-1] = "$tag:$value";
                        }
                }

                if ($tag) {
                        if ( $validfiletype{$tag} ) {

                                # Keep track of the filetypes found
                                $found_filetype{$tag}++;

                                $value =~ s/^([^|]*).*/$1/;
                                my $lstfile = find_full_path( $value, $currentbasedir, getOption('basepath') );
                                $files_to_parse{$lstfile} = $tag;

                                # Check to see if the file exists
                                if ( !-e $lstfile ) {
                                        $filelist_missing{$lstfile} = [ $pcc_file_name, $INPUT_LINE_NUMBER ];
                                        delete $files_to_parse{$lstfile};
                                }
                                elsif (Pretty::Options::isConversionActive('SPELL:Add TYPE tags')
                                && $tag eq 'CLASS' )
                                {

                                        # [ 653596 ] Add a TYPE tag for all SPELLs
                                        #
                                        # The CLASS files must be read before any other
                                        $class_files{$lstfile} = 1;
                                }
                                elsif ( $tag eq 'SPELL' && ( Pretty::Options::isConversionActive('EQUIPMENT: generate EQMOD')
                                        || Pretty::Options::isConversionActive('CLASS: SPELLLIST from Spell.MOD') ) )
                                {

                                        #[ 677962 ] The DMG wands have no charge.
                                        #[ 779341 ] Spell Name.MOD to CLASS's SPELLLEVEL
                                        #
                                        # We keep a list of the SPELL files because they
                                        # need to be put in front of the others.

                                        $Spell_Files{$lstfile} = 1;
                                }
                                elsif ( Pretty::Options::isConversionActive('CLASSSPELL conversion to SPELL')
                                && ( $tag eq 'CLASSSPELL' || $tag eq 'CLASS' || $tag eq 'DOMAIN' ) )
                                {

                                        # CLASSSPELL conversion
                                        # We keep the list of CLASSSPELL, CLASS and DOMAIN
                                        # since they must be parse before all the orthers.
                                        $classspell_files{$tag}{$lstfile} = 1;

                                        # We comment out the CLASSSPELL line
                                        if ( $tag eq 'CLASSSPELL' ) {
                                                push @pcc_lines, q{#} . pop @pcc_lines;
                                                $must_write = YES;

                                                $logging->warning(
                                                        qq{Commenting out "$pcc_lines[$#pcc_lines]"},
                                                        $pcc_file_name,
                                                        $INPUT_LINE_NUMBER
                                                );
                                        }
                                }
                                elsif (Pretty::Options::isConversionActive('CLASSSKILL conversion to CLASS')
                                && $tag eq 'CLASSSKILL' )
                                {

                                        # CLASSSKILL conversion
                                        # We keep the list of CLASSSKILL files
                                        $classskill_files{$lstfile} = 1;

                                        # Make a comment out of the line.
                                        push @pcc_lines, q{#} . pop @pcc_lines;
                                        $must_write = YES;

                                        $logging->warning(
                                                qq{Commenting out "$pcc_lines[$#pcc_lines]"},
                                                $pcc_file_name,
                                                $INPUT_LINE_NUMBER
                                        );

                                }

                                #               ($lstfile) = ($lstfile =~ m{/([^/]+)$});
                                delete $filelist_notpcc{$lstfile} if exists $filelist_notpcc{$lstfile};
                                $LST_found = YES;
                        }
                        elsif ( $valid_tags{'PCC'}{$tag} ) {

                                # All the tags that do not have file should be cought here

                                # Get the SOURCExxx tags for future ref.
                                if (Pretty::Options::isConversionActive('SOURCE line replacement')
                                && ( $tag eq 'SOURCELONG'
                                        || $tag eq 'SOURCESHORT'
                                        || $tag eq 'SOURCEWEB'
                                        || $tag eq 'SOURCEDATE' ) )
                                {
                                        my $path = File::Basename::dirname($pcc_file_name);
                                        if ( exists $source_tags{$path}{$tag}
                                                && $path !~ /custom|altpcc/i )
                                        {
                                                $logging->notice(
                                                        "$tag already found for $path",
                                                        $pcc_file_name,
                                                        $INPUT_LINE_NUMBER
                                                );
                                        }
                                        else {
                                                $source_tags{$path}{$tag} = "$tag:$value";
                                        }

                                        # For the PCC report
                                        if ( $tag eq 'SOURCELONG' ) {
                                                $SOURCELONG_found = $value;
                                        }
                                        elsif ( $tag eq 'SOURCESHORT' ) {
                                                $SOURCESHORT_found = $value;
                                        }
                                }
                                elsif ( $tag eq 'GAMEMODE' ) {

                                        # Verify that the GAMEMODEs are valid
                                        # and match the filer.
                                        $GAMEMODE_found = $value;       # The GAMEMODE tag we found
                                        my @modes = split /[|]/, $value;
                                        my $gamemode_regex =
                                                $cl_options{gamemode}
                                                ? qr{ \A (?: $cl_options{gamemode} ) \z }xmsi
                                                : qr{ . }xms;
                                        my $valid_game_mode = $cl_options{gamemode} ? 0 : 1;

                                        # First the filter is applied
                                        for my $mode (@modes) {
                                                if ( $mode =~ $gamemode_regex ) {
                                                        $valid_game_mode = 1;
                                                }
                                        }

                                        # Then we check if the game mode is valid only if
                                        # the game modes have not been filtered out
                                        if ($valid_game_mode) {
                                                for my $mode (@modes) {
                                                        if ( !$valid_game_modes{$mode} ) {
                                                                $logging->notice(
                                                                        qq{Invalid GAMEMODE "$mode" in "$_"},
                                                                        $pcc_file_name,
                                                                        $INPUT_LINE_NUMBER
                                                                );
                                                        }
                                                }
                                        }

                                        if ( !$valid_game_mode ) {
                                                # We set the variables that will kick us out of the
                                                # while loop that read the file and that will
                                                # prevent the file from being written.
                                                $continue               = NO;
                                                $must_write     = NO;
                                        }
                                }
                                elsif ( $tag eq 'BOOKTYPE' || $tag eq 'TYPE' ) {

                                        # Found a TYPE tag
                                        #$logging->notice("TYPE should be Publisher.Format.Setting, something is wrong with \"$_\"",
                                        #               $pcc_file_name, $INPUT_LINE_NUMBER ) if 2 != tr!.!.!;
                                        $BOOKTYPE_found = YES;
                                }
                                elsif ( $tag eq 'GAME' && Pretty::Options::isConversionActive('PCC:GAME to GAMEMODE') ) {

                                        # [ 707325 ] PCC: GAME is now GAMEMODE
                                        $pcc_lines[-1] = "GAMEMODE:$value";
                                        $logging->warning(
                                                qq{Replacing "$tag:$value" by "GAMEMODE:$value"},
                                                $pcc_file_name,
                                                $INPUT_LINE_NUMBER
                                        );
                                        $GAMEMODE_found = $value;
                                        $must_write     = YES;
                                }
                        }
                }
                elsif ( / <html> /xmsi ) {
                        $logging->error(
                                "HTML file detected. Maybe you had a problem with your CSV checkout.\n",
                                $pcc_file_name
                        );
                        $must_write = NO;
                        last PCC_LINE;
                }
                }

                close $pcc_fh;

                if ( Pretty::Options::isConversionActive('CLASSSPELL conversion to SPELL')
                        && $found_filetype{'CLASSSPELL'}
                        && !$found_filetype{'SPELL'} )
                {
                        $logging->warning(
                                'No SPELL file found, create one.',
                                $pcc_file_name
                        );
                }

                if ( Pretty::Options::isConversionActive('CLASSSKILL conversion to CLASS')
                        && $found_filetype{'CLASSSKILL'}
                        && !$found_filetype{'CLASS'} )
                {
                        $logging->warning(
                                'No CLASS file found, create one.',
                                $pcc_file_name
                        );
                }

                if ( !$BOOKTYPE_found && $LST_found ) {
                        $logging->notice( 'No BOOKTYPE tag found', $pcc_file_name );
                }

                if (!$GAMEMODE_found) {
                        $logging->notice( 'No GAMEMODE tag found', $pcc_file_name );
                }

                if ( $GAMEMODE_found && getOption('exportlist') ) {
                        print { $filehandle_for{PCC} }
                                qq{"$SOURCELONG_found","$SOURCESHORT_found","$GAMEMODE_found","$pcc_file_name"\n};
                }

                # Do we copy the .PCC???
                if ( getOption('outputpath') && ( $must_write ) && $writefiletype{"PCC"} ) {
                        my $new_pcc_file = $pcc_file_name;
                        $new_pcc_file =~ s/$cl_options{input_path}/$cl_options{output_path}/i;

                        # Create the subdirectory if needed
                        create_dir( File::Basename::dirname($new_pcc_file), getOption('outputpath') );

                        open my $new_pcc_fh, '>', $new_pcc_file;

                        # We keep track of the files we modify
                        push @modified_files, $pcc_file_name;

                        for my $line (@pcc_lines) {
                                print {$new_pcc_fh} "$line\n";
                        }

                        close $new_pcc_fh;
                }
        }

        # Is there anything to parse?
        if ( !keys %files_to_parse ) {
                $logging->error(
                        qq{Could not find any .lst file to parse.},
                        getOption('inputpath')
                );
                $logging->error(
                        qq{Is your -inputpath parameter valid? ($cl_options{input_path})},
                        getOption('inputpath')
                );
                if ( getOption('gamemode') ) {
                $logging->error(
                        qq{Is your -gamemode parameter valid? ($cl_options{gamemode})},
                        getOption('inputpath')
                );
                exit;
                }
        }

        # Missing .lst files must be printed
        if ( keys %filelist_missing ) {
                $logging->set_header(constructLoggingHeader('Missing'));

                for my $lstfile ( sort keys %filelist_missing ) {
                        $logging->notice(
                                "Can't find the file: $lstfile",
                                $filelist_missing{$lstfile}[0],
                                $filelist_missing{$lstfile}[1]
                        );
                }
        }

        # If the gamemode filter is active, we do not report files not refered to.
        if ( keys %filelistnotpcc && !getOption('gamemode') ) {
                $logging->set_header(constructLoggingHeader('Unreferenced'));

                for my $file ( sort keys %filelist_notpcc ) {
                        $file =~ s/$cl_options{basepath}//i;
                        $file =~ tr{/}{\\} if $^O eq "MSWin32";
                        $logging->notice(  "$file\n", "" );
                }
        }
}
else {
   $files_to_parse{'STDIN'} = getOption('filetype');
}

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

FILE_TO_PARSE:
for my $file (@files_to_parse_sorted) {
        my $numberofcf = 0;     # Number of extra CF found in the file.

        my $filetype = "tab-based";   # can be either 'tab-based' or 'multi-line'

        if ( $file eq "STDIN" ) {

                # We read from STDIN
                # henkslaaf - Multiline parsing
                #       1) read all to a buffer (files are not so huge that it is a memory hog)
                #       2) send the buffer to a method that splits based on the type of file
                #       3) let the method return split and normalized entries
                #       4) let the method return a variable that says what kind of file it is (multi-line, tab-based)
                local $/ = undef; # read all from buffer
                my $buffer = <>;

                (my $lines, $filetype) = normalizeFile($buffer);
                @lines = @$lines;
        }
        else {

                # We read only what we know needs to be processed
                next FILE_TO_PARSE if ref( $validfiletype{ $files_to_parse{$file} } ) ne 'CODE';

                # We try to read the file and continue to the next one even if we
                # encounter problems
                #
                # henkslaaf - Multiline parsing
                #       1) read all to a buffer (files are not so huge that it is a memory hog)
                #       2) send the buffer to a method that splits based on the type of file
                #       3) let the method return split and normalized entries
                #       4) let the method return a variable that says what kind of file it is (multi-line, tab-based)

                eval {
                        local $/ = undef; # read all from buffer
                        open my $lst_fh, '<', $file;
                        my $buffer = <$lst_fh>;
                        close $lst_fh;

                        (my $lines, $filetype) = normalizeFile($buffer);
                        @lines = @$lines;
                };

                if ( $EVAL_ERROR ) {
                # There was an error in the eval
                $logging->error($EVAL_ERROR, $file );
                next FILE_TO_PARSE;
                }
        }

        # If the file is empty, we skip it
        unless (@lines) {
                $logging->notice(  "Empty file.", $file );
                next FILE_TO_PARSE;
        }

        # Check to see if we deal with a HTML file
        if ( grep /<html>/i, @lines ) {
                $logging->error("HTML file detected. Maybe you had a problem with your CSV checkout.\n", $file );
                next FILE_TO_PARSE;
        }

        # Read the full file into the @lines array
        chomp(@lines);

        # Remove and count the abnormal EOL character i.e. anything
        # that reminds after the chomp
        for my $line (@lines) {
                $numberofcf += $line =~ s/[\x0d\x0a]//g;
        }

        if($numberofcf) {
                $logging->warning( "$numberofcf extra CF found and removed.", $file );
        }

        if ( ref( $validfiletype{ $files_to_parse{$file} } ) eq "CODE" ) {

                #       $file_for_error = $file;
                my ($newlines_ref) = &{ $validfiletype{ $files_to_parse{$file} } }(
                                                $files_to_parse{$file},
                                                \@lines,
                                                $file
                                        );

                # Let's remove the tralling white spaces
                for my $line (@$newlines_ref) {
                $line =~ s/\s+$//;
                }

                # henkslaaf - we need to handle this in multi-line object files
                #       take the multi-line variable and use it to determine
                #       if we should skip writing this file

                # Some file types are never written
                warn "SKIP rewrite for $file because it is a multi-line file" if $filetype eq 'multi-line';
                next FILE_TO_PARSE if $filetype eq 'multi-line';                # we still need to implement rewriting for multi-line
                next FILE_TO_PARSE if !$writefiletype{ $files_to_parse{$file} };

                # We compare the result with the orginal file.
                # If there are no modification, we do not create the new files
                my $same  = NO;
                my $index = 0;

                # First, we check if there are obvious resons not to write the new file
                if (    !$numberofcf                                            # No extra CRLF char. were removed
                        && scalar(@lines) == scalar(@$newlines_ref)     # Same number of lines
                ) {
                        # We assume the arrays are the same ...
                        $same = YES;

                        # ... but we check every line
                        $index = -1;
                        while ( $same && ++$index < scalar(@lines) ) {
                                if ( $lines[$index] ne $newlines_ref->[$index] ) {
                                        $same = NO;
                                }
                        }
                }

                next FILE_TO_PARSE if $same;

                my $write_fh;

                if (getOption('outputpath')) {
                        my $newfile = $file;
                        $newfile =~ s/$cl_options{input_path}/$cl_options{output_path}/i;

                        # Create the subdirectory if needed
                        create_dir( File::Basename::dirname($newfile), getOption('outputpath') );

                        open $write_fh, '>', $newfile;

                        # We keep track of the files we modify
                        push @modified_files, $file;
                }
                else {
                        # Output to standard output
                        $write_fh = *STDOUT;
                }

                # The first line of the new file will be a comment line.
                print {$write_fh} "$today -- reformated by $SCRIPTNAME v$VERSION\n";

                # We print the result
                LINE:
                for my $line ( @{$newlines_ref} ) {
                        #$line =~ s/\s+$//;
                        print {$write_fh} "$line\n" if getOption('outputpath');
                }

                close $write_fh if getOption('outputpath');
        }
        else {
                warn "Didn't process filetype \"$files_to_parse{$file}\".\n";
        }
}

###########################################
# Generate the new BIOSET files

if ( Pretty::Options::isConversionActive('BIOSET:generate the new files') ) {
        print STDERR "\n================================================================\n";
        print STDERR "List of new BIOSET files generated\n";
        print STDERR "----------------------------------------------------------------\n";

        generate_bioset_files();
}

###########################################
# Print a report with the modified files
if ( getOption('outputpath') && scalar(@modified_files) ) {
   $cl_options{output_path} =~ tr{/}{\\} if $^O eq "MSWin32";

   my $path = getOption('output_path');

   $logging->set_header(constructLoggingHeader('Created'), $path);

        for my $file (@modified_files) {
                $file =~ s{ $cl_options{input_path} }{}xmsi;
                $file =~ tr{/}{\\} if $^O eq "MSWin32";
                $logging->notice( "$file\n", "" );
        }

        print STDERR "================================================================\n";
}

###########################################
# Print a report for the BONUS and PRExxx usage
if ( Pretty::Options::isConversionActive('Generate BONUS and PRExxx report') ) {
        $cl_options{output_path} =~ tr{/}{\\} if $^O eq "MSWin32";

        print STDERR "\n================================================================\n";
        print STDERR "List of BONUS and PRExxx tags by linetype\n";
        print STDERR "----------------------------------------------------------------\n";

        my $first = 1;
        for my $line_type ( sort keys %bonus_prexxx_tag_report ) {
                print STDERR "\n" unless $first;
                $first = 0;
                print STDERR "Line Type: $line_type\n";

                for my $tag ( sort keys %{ $bonus_prexxx_tag_report{$line_type} } ) {
                print STDERR "  $tag\n";
                }
        }

        print STDERR "================================================================\n";
}

if ( getOption('report') ) {
        ###########################################
        # Print a report for the number of tag
        # found.

        print STDERR "\n================================================================\n";
        print STDERR "Valid tags found\n";
        print STDERR "----------------------------------------------------------------\n";

        my $first = 1;
        REPORT_LINE_TYPE:
        for my $line_type ( sort keys %{ $count_tags{"Valid"} } ) {
                next REPORT_LINE_TYPE if $line_type eq "Total";

                print STDERR "\n" unless $first;
                print STDERR "Line Type: $line_type\n";

                for my $tag ( sort report_tag_sort keys %{ $count_tags{"Valid"}{$line_type} } ) {
                        my $tagdisplay = $tag;
                        $tagdisplay .= "*" if $master_mult{$line_type}{$tag};
                        my $line = "    $tagdisplay";
                        $line .= ( " " x ( 26 - length($tagdisplay) ) ) . $count_tags{"Valid"}{$line_type}{$tag};
                        print STDERR "$line\n";
                }

                $first = 0;
        }

        print STDERR "\nTotal:\n";

        for my $tag ( sort report_tag_sort keys %{ $count_tags{"Valid"}{"Total"} } ) {
                my $line = "    $tag";
                $line .= ( " " x ( 26 - length($tag) ) ) . $count_tags{"Valid"}{"Total"}{$tag};
                print STDERR "$line\n";
        }
}

if ( exists $count_tags{"Invalid"} ) {

        print STDERR "\n================================================================\n";
        print STDERR "Invalid tags found\n";
        print STDERR "----------------------------------------------------------------\n";

        my $first = 1;
        INVALID_LINE_TYPE:
        for my $linetype ( sort keys %{ $count_tags{"Invalid"} } ) {
                next INVALID_LINE_TYPE if $linetype eq "Total";

                print STDERR "\n" unless $first;
                print STDERR "Line Type: $linetype\n";

                for my $tag ( sort report_tag_sort keys %{ $count_tags{"Invalid"}{$linetype} } ) {

                my $line = "    $tag";
                $line .= ( " " x ( 26 - length($tag) ) ) . $count_tags{"Invalid"}{$linetype}{$tag};
                print STDERR "$line\n";
                }

                $first = 0;
        }

        print STDERR "\nTotal:\n";

        for my $tag ( sort report_tag_sort keys %{ $count_tags{"Invalid"}{"Total"} } ) {
                my $line = "    $tag";
                $line .= ( " " x ( 26 - length($tag) ) ) . $count_tags{"Invalid"}{"Total"}{$tag};
                print STDERR "$line\n";
        }
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
              my $message_level = ? :;
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
                        my $report_tag = $line_ref->{$column_with_no_tag{'EQUIPMOD'}[0]}[0];
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
                                qq{Missing BONUS:CASTERLEVEL for "$line_ref->{$column_with_no_tag{'CLASS'}[0]}[0]"},
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
                                qq{Missing BONUS:CASTERLEVEL for "$line_ref->{$column_with_no_tag{'CLASS'}[0]}[0]"},
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
                                                for ( keys %{ $lines_ref->[$j][1] } ) {

                                                # We add the tags except for the first one (the entity tag)
                                                # that is already there.
                                                push @{ $new_line{$_} }, @{ $lines_ref->[$j][1]{$_} }
                                                        if $_ ne $master_order{$curent_linetype}[0];
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
                                }
                                else {
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
   my ($master_order) = @_;

#################################################################
######################## Conversion #############################
# Tags that must be seen as valid to allow conversion.

   if (Pretty::Options::isConversionActive('ALL:Convert ADD:SA to ADD:SAB')) {
      push @{ $master_order->{'CLASS'} },         'ADD:SA';
      push @{ $master_order->{'CLASS Level'} },   'ADD:SA';
      push @{ $master_order->{'COMPANIONMOD'} },  'ADD:SA';
      push @{ $master_order->{'DEITY'} },         'ADD:SA';
      push @{ $master_order->{'DOMAIN'} },        'ADD:SA';
      push @{ $master_order->{'EQUIPMENT'} },     'ADD:SA';
      push @{ $master_order->{'EQUIPMOD'} },      'ADD:SA';
      push @{ $master_order->{'FEAT'} },          'ADD:SA';
      push @{ $master_order->{'RACE'} },          'ADD:SA';
      push @{ $master_order->{'SKILL'} },         'ADD:SA';
      push @{ $master_order->{'SUBCLASSLEVEL'} }, 'ADD:SA';
      push @{ $master_order->{'TEMPLATE'} },      'ADD:SA';
      push @{ $master_order->{'WEAPONPROF'} },    'ADD:SA';
   }
   if (Pretty::Options::isConversionActive('EQUIP: ALTCRITICAL to ALTCRITMULT')) {
      push @{ $master_order->{'EQUIPMENT'} }, 'ALTCRITICAL';
   }

   if (Pretty::Options::isConversionActive('BIOSET:generate the new files')) {
      push @{ $master_order->{'RACE'} }, 'AGE', 'HEIGHT', 'WEIGHT';
   }

   if (Pretty::Options::isConversionActive('EQUIPMENT: remove ATTACKS')) {
      push @{ $master_order->{'EQUIPMENT'} }, 'ATTACKS';
   }

   if (Pretty::Options::isConversionActive('PCC:GAME to GAMEMODE')) {
      push @{ $master_order->{'PCC'} }, 'GAME';
   }

   if (Pretty::Options::isConversionActive('ALL:BONUS:MOVE conversion')) {
      push @{ $master_order->{'CLASS'} },         'BONUS:MOVE:*';
      push @{ $master_order->{'CLASS Level'} },   'BONUS:MOVE:*';
      push @{ $master_order->{'COMPANIONMOD'} },  'BONUS:MOVE:*';
      push @{ $master_order->{'DEITY'} },         'BONUS:MOVE:*';
      push @{ $master_order->{'DOMAIN'} },        'BONUS:MOVE:*';
      push @{ $master_order->{'EQUIPMENT'} },     'BONUS:MOVE:*';
      push @{ $master_order->{'EQUIPMOD'} },      'BONUS:MOVE:*';
      push @{ $master_order->{'FEAT'} },          'BONUS:MOVE:*';
      push @{ $master_order->{'RACE'} },          'BONUS:MOVE:*';
      push @{ $master_order->{'SKILL'} },         'BONUS:MOVE:*';
      push @{ $master_order->{'SUBCLASSLEVEL'} }, 'BONUS:MOVE:*';
      push @{ $master_order->{'TEMPLATE'} },      'BONUS:MOVE:*';
      push @{ $master_order->{'WEAPONPROF'} },    'BONUS:MOVE:*';
   }

   if (Pretty::Options::isConversionActive('WEAPONPROF:No more SIZE')) {
      push @{ $master_order->{'WEAPONPROF'} }, 'SIZE';
   }

   if (Pretty::Options::isConversionActive('EQUIP:no more MOVE')) {
      push @{ $master_order->{'EQUIPMENT'} }, 'MOVE';
   }

#   vvvvvv This one is disactivated
   if (0 && Pretty::Options::isConversionActive('ALL:Convert SPELL to SPELLS')) {
      push @{ $master_order->{'CLASS Level'} },    'SPELL:*';
      push @{ $master_order->{'DOMAIN'} },         'SPELL:*';
      push @{ $master_order->{'EQUIPMOD'} },       'SPELL:*';
      push @{ $master_order->{'SUBCLASSLEVEL'} },  'SPELL:*';
   }

#   vvvvvv This one is disactivated
   if (0 && Pretty::Options::isConversionActive('TEMPLATE:HITDICESIZE to HITDIE')) {
      push @{ $master_order->{'TEMPLATE'} }, 'HITDICESIZE';
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

sub removePREDefaultMonster {

   # [ 1514765 ] Conversion to remove old defaultmonster tags
   # Gawaine42 (Richard Bowers)
   # Bonuses associated with a PREDEFAULTMONSTER:Y need to be removed
   # This should remove the whole tag.
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

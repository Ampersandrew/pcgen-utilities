package Pretty::Data;

use 5.010_001;         # Perl 5.10.1 or better is now mandantory
use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = wq();

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0);

use Pretty::Options (qw(getOption setOption));

our %masterMult;        # Will hold the tags that can be there more then once

our %missing_headers;   # Will hold the tags that do not have defined headers for each linetype.

our %referer;           # Will hold the tags that refer to other entries
                        # Format: push @{$referer{$EntityType}{$entryname}},
                        #               [ $tags{$column}, $fileForError, $lineForError ]

our %valid_entities;    # Will hold the entries that may be refered
                        # by other tags
                        # Format $valid_entities{$entitytype}{$entityname}
                        # We initialise the hash with global system values
                        # that are valid but never defined in the .lst files.

our %validTags;         # Will hold the valid tags for each type of file.

our %headings = (
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

=head2 getLogHeader

   This operation constructs a headeing for the logging program.

=cut

sub getLogHeader {
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


# The PRExxx tags. They are used in many of the line types.
# From now on, they are defined in only one place and every
# line type will get the same sort order.
my @PRE_Tags = (
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
my %PRE_Tags = (
        'PREAPPLY'              => 1,   # Only valid when embeded - THIS IS DEPRECATED
# Uncommenting until conversion for monster kits is done to prevent error messages.
        'PREDEFAULTMONSTER' => 1,       # Only valid when embeded
);

for my $pre_tag (@PRE_Tags) {
        # We need a copy since we don't want to modify the original
        my $pre_tag_name = $pre_tag;

        # We strip the :* at the end to get the real name for the lookup table
        $pre_tag_name =~ s/ [:][*] \z//xms;

        $PRE_Tags{$pre_tag_name} = 1;
}

my %double_PCC_tags = (
        'BONUS:ABILITYPOOL',            => 1,
        'BONUS:CASTERLEVEL',            => 1,
        'BONUS:CHECKS',                 => 1,
        'BONUS:COMBAT',                 => 1,
        'BONUS:DC',                             => 1,
        'BONUS:DOMAIN',                 => 1,
        'BONUS:DR',                             => 1,
        'BONUS:FEAT',                   => 1,
        'BONUS:FOLLOWERS',              => 1,
        'BONUS:HP',                             => 1,
        'BONUS:MISC',                   => 1,
        'BONUS:MOVEADD',                        => 1,
        'BONUS:MOVEMULT',                       => 1,
        'BONUS:PCLEVEL',                        => 1,
        'BONUS:POSTMOVEADD',            => 1,
        'BONUS:POSTRANGEADD',           => 1,
        'BONUS:RANGEADD',                       => 1,
        'BONUS:RANGEMULT',              => 1,
        'BONUS:SITUATION',              => 1,
        'BONUS:SIZEMOD',                        => 1,
        'BONUS:SKILL',                  => 1,
        'BONUS:SKILLPOINTS',            => 1,
        'BONUS:SKILLPOOL',              => 1,
        'BONUS:SKILLRANK',              => 1,
        'BONUS:SLOTS',                  => 1,
        'BONUS:SPECIALTYSPELLKNOWN',    => 1,
        'BONUS:SPELLCAST',              => 1,
        'BONUS:SPELLCASTMULT',          => 1,
        'BONUS:SPELLKNOWN',             => 1,
        'BONUS:STAT',                   => 1,
        'BONUS:UDAM',                   => 1,
        'BONUS:VAR',                    => 1,
        'BONUS:VISION',                 => 1,
        'BONUS:WEAPONPROF',             => 1,
        'BONUS:WIELDCATEGORY',          => 1,
 );


my @SOURCE_Tags = (
        'SOURCELONG',
        'SOURCESHORT',
        'SOURCEWEB',
        'SOURCEPAGE:.CLEAR',
        'SOURCEPAGE',
        'SOURCELINK',
);

my @QUALIFY_Tags = (
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

# [ 1956340 ] Centralize global BONUS tags
# The global BONUS:xxx tags. They are used in many of the line types.
# From now on, they are defined in only one place and every
# line type will get the same sort order.
# BONUSes only valid for specific line types are listed on those line types
my @Global_BONUS_Tags = (
        'BONUS:ABILITYPOOL:*',                  # Global
        'BONUS:CASTERLEVEL:*',                  # Global
        'BONUS:CHECKS:*',                               # Global        DEPRECATED
        'BONUS:COMBAT:*',                               # Global
        'BONUS:CONCENTRATION:*',                # Global
        'BONUS:DC:*',                           # Global
        'BONUS:DOMAIN:*',                               # Global
        'BONUS:DR:*',                           # Global
        'BONUS:FEAT:*',                         # Global
        'BONUS:FOLLOWERS',                      # Global
        'BONUS:HP:*',                           # Global
        'BONUS:MISC:*',                         # Global
        'BONUS:MOVEADD:*',                      # Global
        'BONUS:MOVEMULT:*',                     # Global
        'BONUS:PCLEVEL:*',                      # Global
        'BONUS:POSTMOVEADD:*',                  # Global
        'BONUS:POSTRANGEADD:*',                 # Global
        'BONUS:RANGEADD:*',                     # Global
        'BONUS:RANGEMULT:*',                    # Global
        'BONUS:SAVE:*',                         # Global        Replacement for CHECKS
        'BONUS:SITUATION:*',                    # Global
        'BONUS:SIZEMOD:*',                      # Global
        'BONUS:SKILL:*',                                # Global
        'BONUS:SKILLPOINTS:*',                  # Global
        'BONUS:SKILLPOOL:*',                    # Global
        'BONUS:SKILLRANK:*',                    # Global
        'BONUS:SLOTS:*',                                # Global
        'BONUS:SPECIALTYSPELLKNOWN:*',  # Global
        'BONUS:SPELLCAST:*',                    # Global
        'BONUS:SPELLCASTMULT:*',                # Global
#       'BONUS:SPELLPOINTCOST:*',               # Global
        'BONUS:SPELLKNOWN:*',                   # Global
        'BONUS:STAT:*',                         # Global
        'BONUS:UDAM:*',                         # Global
        'BONUS:VAR:*',                          # Global
        'BONUS:VISION:*',                               # Global
        'BONUS:WEAPONPROF:*',                   # Global
        'BONUS:WIELDCATEGORY:*',                # Global
#       'BONUS:DAMAGE:*',                               # Deprecated
#       'BONUS:DEFINE:*',                               # Not listed in the Docs
#       'BONUS:EQM:*',                          # Equipment and EquipMod files only
#       'BONUS:EQMARMOR:*',                     # Equipment and EquipMod files only
#       'BONUS:EQMWEAPON:*',                    # Equipment and EquipMod files only
#       'BONUS:ESIZE:*',                                # Not listed in the Docs
#       'BONUS:HD',                                     # Class Lines
#       'BONUS:LANGUAGES:*',                    # Not listed in the Docs
#       'BONUS:LANG:*',                         # BONUS listed in the Code which is to be used instead of the deprecated BONUS:LANGNUM tag.
#       'BONUS:MONSKILLPTS',                    # Templates
#       'BONUS:REPUTATION:*',                   # Not listed in the Docs
#       'BONUS:RING:*',                         # Not listed in the Docs
#       'BONUS:SCHOOL:*',                               # Not listed in the Docs
#       'BONUS:SPELL:*',                                # Not listed in the Docs
#       'BONUS:TOHIT:*',                                # Deprecated
#       'BONUS:WEAPON:*',                               # Equipment and EquipMod files only
);

# Global tags allowed in PCC files.
my @double_PCC_tags = (
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

# Order for the tags for each line type.
our %masterOrder = (
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

my @xcheck_to_process;  # Will hold the information for the entries that must
                                # be added in %referer or %referer_types. The array
                                # is needed because all the files must have been
                                # parsed before processing the information to be added.
                                # The function add_to_xcheck_tables will be called with
                                # each line of the array.

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
      '000ClassName'                => '# Class Name',
      '001SkillName'                => 'Class Skills (All skills are seperated by a pipe delimiter \'|\')',

      '000DomainName'               => '# Domain Name',
      '001DomainEffect'             => 'Description',

      'DESC'                        => 'Description',

      '000AbilityName'              => '# Ability Name',
      '000FeatName'                 => '# Feat Name',

      '000AbilityCategory',         => '# Ability Category Name',

      '000LanguageName'             => '# Language',

      'FAVCLASS'                    => 'Favored Class',
      'XTRASKILLPTSPERLVL'          => 'Skills/Level',
      'STARTFEATS'                  => 'Starting Feats',

      '000SkillName'                => '# Skill Name',

      'KEYSTAT'                     => 'Key Stat',
      'EXCLUSIVE'                   => 'Exclusive?',
      'USEUNTRAINED'                => 'Untrained?',
      'SITUATION'                   => 'Situational Skill',

      '000TemplateName'             => '# Template Name',

      '000WeaponName'               => '# Weapon Name',
      '000ArmorName'                => '# Armor Name',
      '000ShieldName'               => '# Shield Name',

      '000VariableName'             => '# Name',
      '000GlobalmodName'            => '# Name',
      '000DatacontrolName'          => '# Name',
      '000SaveName'                 => '# Name',
      '000StatName'                 => '# Name',
      '000AlignmentName'            => '# Name',
      'DATAFORMAT'                  => 'Dataformat',
      'REQUIRED'                    => 'Required',
      'SELECTABLE'                  => 'Selectable',
      'DISPLAYNAME'                 => 'Displayname',

      'ABILITY'                     => 'Ability',
      'ACCHECK'                     => 'AC Penalty Check',
      'ACHECK'                      => 'Skill Penalty?',
      'ADD'                         => 'Add',
      'ADD:EQUIP'                   => 'Add Equipment',
      'ADD:FEAT'                    => 'Add Feat',
      'ADD:SAB'                     => 'Add Special Ability',
      'ADD:SKILL'                   => 'Add Skill',
      'ADD:TEMPLATE'                => 'Add Template',
      'ADDDOMAINS'                  => 'Add Divine Domain',
      'ADDSPELLLEVEL'               => 'Add Spell Lvl',
      'APPLIEDNAME'                 => 'Applied Name',
      'AGE'                         => 'Age',
      'AGESET'                      => 'Age Set',
      'ALIGN'                       => 'Align',
      'ALTCRITMULT'                 => 'Alt Crit Mult',
#     'ALTCRITICAL'                 => 'Alternative Critical',
      'ALTCRITRANGE'                => 'Alt Crit Range',
      'ALTDAMAGE'                   => 'Alt Damage',
      'ALTEQMOD'                    => 'Alt EQModifier',
      'ALTTYPE'                     => 'Alt Type',
      'ATTACKCYCLE'                 => 'Attack Cycle',
      'ASPECT'                      => 'Aspects',
      'AUTO'                        => 'Auto',
      'AUTO:ARMORPROF'              => 'Auto Armor Prof',
      'AUTO:EQUIP'                  => 'Auto Equip',
      'AUTO:FEAT'                   => 'Auto Feat',
      'AUTO:LANG'                   => 'Auto Language',
      'AUTO:SHIELDPROF'             => 'Auto Shield Prof',
      'AUTO:WEAPONPROF'             => 'Auto Weapon Prof',
      'BASEQTY'                     => 'Base Quantity',
      'BENEFIT'                     => 'Benefits',
      'BONUS'                       => 'Bonus',
      'BONUSSPELLSTAT'              => 'Spell Stat Bonus',
      'BONUS:ABILITYPOOL'           => 'Bonus Ability Pool',
      'BONUS:CASTERLEVEL'           => 'Caster level',
      'BONUS:CHECKS'                => 'Save checks bonus',
      'BONUS:CONCENTRATION'         => 'Concentration bonus',
      'BONUS:SAVE'                  => 'Save bonus',
      'BONUS:COMBAT'                => 'Combat bonus',
      'BONUS:DAMAGE'                => 'Weapon damage bonus',
      'BONUS:DOMAIN'                => 'Add domain number',
      'BONUS:DC'                    => 'Bonus DC',
      'BONUS:DR'                    => 'Bonus DR',
      'BONUS:EQMARMOR'              => 'Bonus Armor Mods',
      'BONUS:EQM'                   => 'Bonus Equip Mods',
      'BONUS:EQMWEAPON'             => 'Bonus Weapon Mods',
      'BONUS:ESIZE'                 => 'Modify size',
      'BONUS:FEAT'                  => 'Number of Feats',
      'BONUS:FOLLOWERS'             => 'Number of Followers',
      'BONUS:HD'                    => 'Modify HD type',
      'BONUS:HP'                    => 'Bonus to HP',
      'BONUS:ITEMCOST'              => 'Modify the item cost',
      'BONUS:LANGUAGES'             => 'Bonus language',
      'BONUS:MISC'                  => 'Misc bonus',
      'BONUS:MOVEADD'               => 'Add to base move',
      'BONUS:MOVEMULT'              => 'Multiply base move',
      'BONUS:POSTMOVEADD'           => 'Add to magical move',
      'BONUS:PCLEVEL'               => 'Caster level bonus',
      'BONUS:POSTRANGEADD'          => 'Bonus to Range',
      'BONUS:RANGEADD'              => 'Bonus to base range',
      'BONUS:RANGEMULT'             => '% bonus to range',
      'BONUS:REPUTATION'            => 'Bonus to Reputation',
      'BONUS:SIZEMOD'               => 'Adjust PC Size',
      'BONUS:SKILL'                 => 'Bonus to skill',
      'BONUS:SITUATION'             => 'Bonus to Situation',
      'BONUS:SKILLPOINTS'           => 'Bonus to skill point/L',
      'BONUS:SKILLPOOL'             => 'Bonus to skill point for a level',
      'BONUS:SKILLRANK'             => 'Bonus to skill rank',
      'BONUS:SLOTS'                 => 'Bonus to nb of slots',
      'BONUS:SPELL'                 => 'Bonus to spell attribute',
      'BONUS:SPECIALTYSPELLKNOWN'   => 'Bonus Specialty spells',
      'BONUS:SPELLCAST'             => 'Bonus to spell cast/day',
      'BONUS:SPELLCASTMULT'         => 'Multiply spell cast/day',
      'BONUS:SPELLKNOWN'            => 'Bonus to spell known/L',
      'BONUS:STAT'                  => 'Stat bonus',
      'BONUS:TOHIT'                 => 'Attack roll bonus',
      'BONUS:UDAM'                  => 'Unarmed Damage Level bonus',
      'BONUS:VAR'                   => 'Modify VAR',
      'BONUS:VISION'                => 'Add to vision',
      'BONUS:WEAPON'                => 'Weapon prop. bonus',
      'BONUS:WEAPONPROF'            => 'Weapon prof. bonus',
      'BONUS:WIELDCATEGORY'         => 'Wield Category bonus',
      'TEMPBONUS'                   => 'Temporary Bonus',
      'CAST'                        => 'Cast',
      'CASTAS'                      => 'Cast As',
      'CASTTIME:.CLEAR'             => 'Clear Casting Time',
      'CASTTIME'                    => 'Casting Time',
      'CATEGORY'                    => 'Category of Ability',
      'CCSKILL:.CLEAR'              => 'Remove Cross-Class Skill',
      'CCSKILL'                     => 'Cross-Class Skill',
      'CHANGEPROF'                  => 'Change Weapon Prof. Category',
      'CHOOSE'                      => 'Choose',
      'CLASSES'                     => 'Classes',
      'COMPANIONLIST'               => 'Allowed Companions',
      'COMPS'                       => 'Components',
      'CONTAINS'                    => 'Contains',
      'COST'                        => 'Cost',
      'CR'                          => 'Challenge Rating',
      'CRMOD'                       => 'CR Modifier',
      'CRITMULT'                    => 'Crit Mult',
      'CRITRANGE'                   => 'Crit Range',
      'CSKILL:.CLEAR'               => 'Remove Class Skill',
      'CSKILL'                      => 'Class Skill',
      'CT'                          => 'Casting Threshold',
      'DAMAGE'                      => 'Damage',
      'DEF'                         => 'Def',
      'DEFINE'                      => 'Define',
      'DEFINESTAT'                  => 'Define Stat',
      'DEITY'                       => 'Deity',
      'DESC'                        => 'Description',
      'DESC:.CLEAR'                 => 'Clear Description',
      'DESCISPI'                    => 'Desc is PI?',
      'DESCRIPTOR:.CLEAR'           => 'Clear Spell Descriptors',
      'DESCRIPTOR'                  => 'Descriptor',
      'DOMAIN'                      => 'Domain',
      'DOMAINS'                     => 'Domains',
      'DONOTADD'                    => 'Do Not Add',
      'DR:.CLEAR'                   => 'Remove Damage Reduction',
      'DR'                          => 'Damage Reduction',
      'DURATION:.CLEAR'             => 'Clear Duration',
      'DURATION'                    => 'Duration',
#     'EFFECTS'                     => 'Description',                               # Deprecated a long time ago for TARGETAREA
      'EQMOD'                       => 'Modifier',
      'EXCLASS'                     => 'Ex Class',
      'EXPLANATION'                 => 'Explanation',
      'FACE'                        => 'Face/Space',
      'FACT:Abb'                    => 'Abbreviation',
      'FACT:SpellType'              => 'Spell Type',
      'FEAT'                        => 'Feat',
      'FEATAUTO'                    => 'Feat Auto',
      'FOLLOWERS'                   => 'Allow Follower',
      'FREE'                        => 'Free',
      'FUMBLERANGE'                 => 'Fumble Range',
      'GENDER'                      => 'Gender',
      'HANDS'                       => 'Nb Hands',
      'HASSUBCLASS'                 => 'Subclass?',
      'ALLOWBASECLASS'              => 'Base class as subclass?',
      'HD'                          => 'Hit Dice',
      'HEIGHT'                      => 'Height',
      'HITDIE'                      => 'Hit Dice Size',
      'HITDICEADVANCEMENT'          => 'Hit Dice Advancement',
      'HITDICESIZE'                 => 'Hit Dice Size',
      'ITEM'                        => 'Item',
      'KEY'                         => 'Unique Key',
      'KIT'                         => 'Apply Kit',
      'KNOWN'                       => 'Known',
      'KNOWNSPELLS'                 => 'Automatically Known Spell Levels',
      'LANGAUTO'                    => 'Automatic Languages',               # Deprecated
      'LANGAUTO:.CLEAR'             => 'Clear Automatic Languages', # Deprecated
      'LANGBONUS'                   => 'Bonus Languages',
      'LANGBONUS:.CLEAR'            => 'Clear Bonus Languages',
      'LEGS'                        => 'Nb Legs',
      'LEVEL'                       => 'Level',
      'LEVELADJUSTMENT'             => 'Level Adjustment',
#     'LONGNAME'                    => 'Long Name',                         # Deprecated in favor of OUTPUTNAME
      'MAXCOST'                     => 'Maximum Cost',
      'MAXDEX'                      => 'Maximum DEX Bonus',
      'MAXLEVEL'                    => 'Max Level',
      'MEMORIZE'                    => 'Memorize',
      'MFEAT'                       => 'Default Monster Feat',
      'MONSKILL'                    => 'Monster Initial Skill Points',
      'MOVE'                        => 'Move',
      'MOVECLONE'                   => 'Clone Movement',
      'MULT'                        => 'Multiple?',
      'NAMEISPI'                    => 'Product Identity?',
      'NATURALARMOR'                => 'Natural Armor',
      'NATURALATTACKS'              => 'Natural Attacks',
      'NUMPAGES'                    => 'Number of Pages',                   # [ 1450980 ] New Spellbook tags
      'OUTPUTNAME'                  => 'Output Name',
      'PAGEUSAGE'                   => 'Page Usage',                                # [ 1450980 ] New Spellbook tags
      'PANTHEON'                    => 'Pantheon',
      'PPCOST'                      => 'Power Points',                      # [ 1814797 ] PPCOST needs to added as valid tag in SPELLS
      'PRE:.CLEAR'                  => 'Clear Prereq.',
      'PREABILITY'                  => 'Required Ability',
      '!PREABILITY'                 => 'Restricted Ability',
      'PREAGESET'                   => 'Minimum Age',
      '!PREAGESET'                  => 'Maximum Age',
      'PREALIGN'                    => 'Required AL',
      '!PREALIGN'                   => 'Restricted AL',
      'PREATT'                      => 'Req. Att.',
      'PREARMORPROF'                => 'Req. Armor Prof.',
      '!PREARMORPROF'               => 'Prohibited Armor Prof.',
      'PREBASESIZEEQ'               => 'Required Base Size',
      '!PREBASESIZEEQ'              => 'Prohibited Base Size',
      'PREBASESIZEGT'               => 'Minimum Base Size',
      'PREBASESIZEGTEQ'             => 'Minimum Size',
      'PREBASESIZELT'               => 'Maximum Base Size',
      'PREBASESIZELTEQ'             => 'Maximum Size',
      'PREBASESIZENEQ'              => 'Prohibited Base Size',
      'PRECAMPAIGN'                 => 'Required Campaign(s)',
      '!PRECAMPAIGN'                => 'Prohibited Campaign(s)',
      'PRECHECK'                    => 'Required Check',
      '!PRECHECK'                   => 'Prohibited Check',
      'PRECHECKBASE'                => 'Required Check Base',
      'PRECITY'                     => 'Required City',
      '!PRECITY'                    => 'Prohibited City',
      'PRECLASS'                    => 'Required Class',
      '!PRECLASS'                   => 'Prohibited Class',
      'PRECLASSLEVELMAX'            => 'Maximum Level Allowed',
      '!PRECLASSLEVELMAX'           => 'Should use PRECLASS',
      'PRECSKILL'                   => 'Required Class Skill',
      '!PRECSKILL'                  => 'Prohibited Class SKill',
      'PREDEITY'                    => 'Required Deity',
      '!PREDEITY'                   => 'Prohibited Deity',
      'PREDEITYDOMAIN'              => 'Required Deitys Domain',
      'PREDOMAIN'                   => 'Required Domain',
      '!PREDOMAIN'                  => 'Prohibited Domain',
      'PREDSIDEPTS'                 => 'Req. Dark Side',
      'PREDR'                       => 'Req. Damage Resistance',
      '!PREDR'                      => 'Prohibited Damage Resistance',
      'PREEQUIP'                    => 'Req. Equipement',
      'PREEQMOD'                    => 'Req. Equipment Mod.',
      '!PREEQMOD'                   => 'Prohibited Equipment Mod.',
      'PREFEAT'                     => 'Required Feat',
      '!PREFEAT'                    => 'Prohibited Feat',
      'PREGENDER'                   => 'Required Gender',
      '!PREGENDER'                  => 'Prohibited Gender',
      'PREHANDSEQ'                  => 'Req. nb of Hands',
      'PREHANDSGT'                  => 'Min. nb of Hands',
      'PREHANDSGTEQ'                => 'Min. nb of Hands',
      'PREHD'                       => 'Required Hit Dice',
      'PREHP'                       => 'Required Hit Points',
      'PREITEM'                     => 'Required Item',
      'PRELANG'                     => 'Required Language',
      'PRELEVEL'                    => 'Required Lvl',
      'PRELEVELMAX'                 => 'Maximum Level',
      'PREKIT'                      => 'Required Kit',
      '!PREKIT'                     => 'Prohibited Kit',
      'PREMOVE'                     => 'Required Movement Rate',
      '!PREMOVE'                    => 'Prohibited Movement Rate',
      'PREMULT'                     => 'Multiple Requirements',
      '!PREMULT'                    => 'Multiple Prohibitions',
      'PREPCLEVEL'                  => 'Required Non-Monster Lvl',
      'PREPROFWITHARMOR'            => 'Required Armor Proficiencies',
      '!PREPROFWITHARMOR'           => 'Prohibited Armor Proficiencies',
      'PREPROFWITHSHIELD'           => 'Required Shield Proficiencies',
      '!PREPROFWITHSHIELD'          => 'Prohbited Shield Proficiencies',
      'PRERACE'                     => 'Required Race',
      '!PRERACE'                    => 'Prohibited Race',
      'PRERACETYPE'                 => 'Reg. Race Type',
      'PREREACH'                    => 'Minimum Reach',
      'PREREACHEQ'                  => 'Required Reach',
      'PREREACHGT'                  => 'Minimum Reach',
      'PREREGION'                   => 'Required Region',
      '!PREREGION'                  => 'Prohibited Region',
      'PRERULE'                     => 'Req. Rule (in options)',
      'PRESA'                       => 'Req. Special Ability',
      '!PRESA'                      => 'Prohibite Special Ability',
      'PRESHIELDPROF'               => 'Req. Shield Prof.',
      '!PRESHIELDPROF'              => 'Prohibited Shield Prof.',
      'PRESIZEEQ'                   => 'Required Size',
      'PRESIZEGT'                   => 'Must be Larger',
      'PRESIZEGTEQ'                 => 'Minimum Size',
      'PRESIZELT'                   => 'Must be Smaller',
      'PRESIZELTEQ'                 => 'Maximum Size',
      'PRESKILL'                    => 'Required Skill',
      '!PRESITUATION'               => 'Prohibited Situation',
      'PRESITUATION'                => 'Required Situation',
      '!PRESKILL'                   => 'Prohibited Skill',
      'PRESKILLMULT'                => 'Special Required Skill',
      'PRESKILLTOT'                 => 'Total Skill Points Req.',
      'PRESPELL'                    => 'Req. Known Spell',
      'PRESPELLBOOK'                => 'Req. Spellbook',
      'PRESPELLBOOK'                => 'Req. Spellbook',
      'PRESPELLCAST'                => 'Required Casting Type',
      '!PRESPELLCAST'               => 'Prohibited Casting Type',
      'PRESPELLDESCRIPTOR'          => 'Required Spell Descriptor',
      '!PRESPELLDESCRIPTOR'         => 'Prohibited Spell Descriptor',
      'PRESPELLSCHOOL'              => 'Required Spell School',
      'PRESPELLSCHOOLSUB'           => 'Required Sub-school',
      '!PRESPELLSCHOOLSUB'          => 'Prohibited Sub-school',
      'PRESPELLTYPE'                => 'Req. Spell Type',
      'PRESREQ'                     => 'Req. Spell Resist',
      'PRESRGT'                     => 'SR Must be Greater',
      'PRESRGTEQ'                   => 'SR Min. Value',
      'PRESRLT'                     => 'SR Must be Lower',
      'PRESRLTEQ'                   => 'SR Max. Value',
      'PRESRNEQ'                    => 'Prohibited SR Value',
      'PRESTAT'                     => 'Required Stat',
      '!PRESTAT',                   => 'Prohibited Stat',
      'PRESUBCLASS'                 => 'Required Subclass',
      '!PRESUBCLASS'                => 'Prohibited Subclass',
      'PRETEMPLATE'                 => 'Required Template',
      '!PRETEMPLATE'                => 'Prohibited Template',
      'PRETEXT'                     => 'Required Text',
      'PRETYPE'                     => 'Required Type',
      '!PRETYPE'                    => 'Prohibited Type',
      'PREVAREQ'                    => 'Required Var. value',
      '!PREVAREQ'                   => 'Prohibited Var. Value',
      'PREVARGT'                    => 'Var. Must Be Grater',
      'PREVARGTEQ'                  => 'Var. Min. Value',
      'PREVARLT'                    => 'Var. Must Be Lower',
      'PREVARLTEQ'                  => 'Var. Max. Value',
      'PREVARNEQ'                   => 'Prohibited Var. Value',
      'PREVISION'                   => 'Required Vision',
      '!PREVISION'                  => 'Prohibited Vision',
      'PREWEAPONPROF'               => 'Req. Weapond Prof.',
      '!PREWEAPONPROF'              => 'Prohibited Weapond Prof.',
      'PREWIELD'                    => 'Required Wield Category',
      '!PREWIELD'                   => 'Prohibited Wield Category',
      'PROFICIENCY:WEAPON'          => 'Required Weapon Proficiency',
      'PROFICIENCY:ARMOR'           => 'Required Armor Proficiency',
      'PROFICIENCY:SHIELD'          => 'Required Shield Proficiency',
      'PROHIBITED'                  => 'Spell Scoll Prohibited',
      'PROHIBITSPELL'               => 'Group of Prohibited Spells',
      'QUALIFY:CLASS'               => 'Qualify for Class',
      'QUALIFY:DEITY'               => 'Qualify for Deity',
      'QUALIFY:DOMAIN'              => 'Qualify for Domain',
      'QUALIFY:EQUIPMENT'           => 'Qualify for Equipment',
      'QUALIFY:EQMOD'               => 'Qualify for Equip Modifier',
      'QUALIFY:FEAT'                => 'Qualify for Feat',
      'QUALIFY:RACE'                => 'Qualify for Race',
      'QUALIFY:SPELL'               => 'Qualify for Spell',
      'QUALIFY:SKILL'               => 'Qualify for Skill',
      'QUALIFY:TEMPLATE'            => 'Qualify for Template',
      'QUALIFY:WEAPONPROF'          => 'Qualify for Weapon Proficiency',
      'RACESUBTYPE:.CLEAR'          => 'Clear Racial Subtype',
      'RACESUBTYPE'                 => 'Race Subtype',
      'RACETYPE:.CLEAR'             => 'Clear Main Racial Type',
      'RACETYPE'                    => 'Main Race Type',
      'RANGE:.CLEAR'                => 'Clear Range',
      'RANGE'                       => 'Range',
      'RATEOFFIRE'                  => 'Rate of Fire',
      'REACH'                       => 'Reach',
      'REACHMULT'                   => 'Reach Multiplier',
      'REGION'                      => 'Region',
      'REPEATLEVEL'                 => 'Repeat this Level',
      'REMOVABLE'                   => 'Removable?',
      'REMOVE'                      => 'Remove Object',
      'REP'                         => 'Reputation',
      'ROLE'                        => 'Monster Role',
      'SA'                          => 'Special Ability',
      'SA:.CLEAR'                   => 'Clear SAs',
      'SAB:.CLEAR'                  => 'Clear Special ABility',
      'SAB'                         => 'Special ABility',
      'SAVEINFO'                    => 'Save Info',
      'SCHOOL:.CLEAR'               => 'Clear School',
      'SCHOOL'                      => 'School',
      'SELECT'                      => 'Selections',
      'SERVESAS'                    => 'Serves As',
      'SIZE'                        => 'Size',
      'SKILLLIST'                   => 'Use Class Skill List',
      'SOURCE'                      => 'Source Index',
      'SOURCEPAGE:.CLEAR'           => 'Clear Source Page',
      'SOURCEPAGE'                  => 'Source Page',
      'SOURCELONG'                  => 'Source, Long Desc.',
      'SOURCESHORT'                 => 'Source, Short Desc.',
      'SOURCEWEB'                   => 'Source URI',
      'SOURCEDATE'                  => 'Source Pub. Date',
      'SOURCELINK'                  => 'Source Pub Link',
      'SPELLBOOK'                   => 'Spellbook',
      'SPELLFAILURE'                => '% of Spell Failure',
      'SPELLLIST'                   => 'Use Spell List',
      'SPELLKNOWN:CLASS'            => 'List of Known Class Spells by Level',
      'SPELLKNOWN:DOMAIN'           => 'List of Known Domain Spells by Level',
      'SPELLLEVEL:CLASS'            => 'List of Class Spells by Level',
      'SPELLLEVEL:DOMAIN'           => 'List of Domain Spells by Level',
      'SPELLRES'                    => 'Spell Resistance',
      'SPELL'                       => 'Deprecated Spell tag',
      'SPELLS'                      => 'Innate Spells',
      'SPELLSTAT'                   => 'Spell Stat',
      'SPELLTYPE'                   => 'Spell Type',
      'SPROP:.CLEAR'                => 'Clear Special Property',
      'SPROP'                       => 'Special Property',
      'SR'                          => 'Spell Res.',
      'STACK'                       => 'Stackable?',
      'STARTSKILLPTS'               => 'Skill Pts/Lvl',
      'STAT'                        => 'Key Attribute',
      'SUBCLASSLEVEL'               => 'Subclass Level',
      'SUBRACE'                     => 'Subrace',
      'SUBREGION'                   => 'Subregion',
      'SUBSCHOOL'                   => 'Sub-School',
      'SUBSTITUTIONLEVEL'           => 'Substitution Level',
      'SYNERGY'                     => 'Synergy Skill',
      'TARGETAREA:.CLEAR'           => 'Clear Target Area or Effect',
      'TARGETAREA'                  => 'Target Area or Effect',
      'TEMPDESC'                    => 'Temporary effect description',
      'TEMPLATE'                    => 'Template',
      'TEMPLATE:.CLEAR'             => 'Clear Templates',
      'TYPE'                        => 'Type',
      'TYPE:.CLEAR'                 => 'Clear Types',
      'UDAM'                        => 'Unarmed Damage',
      'UMULT'                       => 'Unarmed Multiplier',
      'UNENCUMBEREDMOVE'            => 'Ignore Encumberance',
      'VARIANTS'                    => 'Spell Variations',
      'VFEAT'                       => 'Virtual Feat',
      'VFEAT:.CLEAR'                => 'Clear Virtual Feat',
      'VISIBLE'                     => 'Visible',
      'VISION'                      => 'Vision',
      'WEAPONBONUS'                 => 'Optionnal Weapon Prof.',
      'WEIGHT'                      => 'Weight',
      'WT'                          => 'Weight',
      'XPCOST'                      => 'XP Cost',
      'XTRAFEATS'                   => 'Extra Feats',
   },

   'ABILITYCATEGORY' => {
      '000AbilityCategory'          => '# Ability Category',
      'CATEGORY'                    => 'Category of Object',
      'DISPLAYLOCATION'             => 'Display Location',
      'DISPLAYNAME'                 => 'Display where?',
      'EDITABLE'                    => 'Editable?',
      'EDITPOOL'                    => 'Change Pool?',
      'FRACTIONALPOOL'              => 'Fractional values?',
      'PLURAL'                      => 'Plural description for UI',
      'POOL'                        => 'Base Pool number',
      'TYPE'                        => 'Type of Object',
      'ABILITYLIST'                 => 'Specific choices list',
      'VISIBLE'                     => 'Visible',
   },

   'BIOSET AGESET' => {
      'AGESET'                      => '# Age set',
   },

   'BIOSET RACENAME' => {
      'RACENAME'                    => '# Race name',
   },

   'CLASS' => {
      '000ClassName'                => '# Class Name',
      'FACT:CLASSTYPE'              => 'Class Type',
      'CLASSTYPE'                   => 'Class Type',
      'FACT:Abb'                    => 'Abbreviation',
      'ABB'                         => 'Abbreviation',
      'ALLOWBASECLASS',             => 'Base class as subclass?',
      'HASSUBSTITUTIONLEVEL'        => 'Substitution levels?',
      'ITEMCREATE'                  => 'Craft Level Mult.',
      'LEVELSPERFEAT'               => 'Levels per Feat',
      'MODTOSKILLS'                 => 'Add INT to Skill Points?',
      'MONNONSKILLHD'               => 'Extra Hit Die Skills Limit',
      'MULTIPREREQS'                => 'MULTIPREREQS',
      'SPECIALS'                    => 'Class Special Ability',             # Deprecated - Use SA
      'DEITY'                       => 'Deities allowed',
      'ROLE'                        => 'Monster Role',
   },

   'CLASS Level' => {
      '000Level'                    => '# Level',
   },

   'COMPANIONMOD' => {
      '000Follower'                 => '# Class of the Master',
      '000MasterBonusRace'          => '# Race of familiar',
      'COPYMASTERBAB'               => 'Copy Masters BAB',
      'COPYMASTERCHECK'             => 'Copy Masters Checks',
      'COPYMASTERHP'                => 'HP formula based on Master',
      'FOLLOWER'                    => 'Added Value',
      'SWITCHRACE'                  => 'Change Racetype',
      'USEMASTERSKILL'              => 'Use Masters skills?',
   },

   'DEITY' => {
      '000DeityName'                => '# Deity Name',
      'DOMAINS'                     => 'Domains',
      'FOLLOWERALIGN'               => 'Clergy AL',
      'DESC'                        => 'Description of Deity/Title',
      'FACT:SYMBOL'                 => 'Holy Item',
      'SYMBOL'                      => 'Holy Item',
      'DEITYWEAP'                   => 'Deity Weapon',
      'FACT:TITLE'                  => 'Deity Title',
      'TITLE'                       => 'Deity Title',
      'FACTSET:WORSHIPPERS'         => 'Usual Worshippers',
      'WORSHIPPERS'                 => 'Usual Worshippers',
      'FACT:APPEARANCE'             => 'Deity Appearance',
      'APPEARANCE'                  => 'Deity Appearance',
      'ABILITY'                     => 'Granted Ability',
   },

   'EQUIPMENT' => {
      '000EquipmentName'            => '# Equipment Name',
      'BASEITEM'                    => 'Base Item for EQMOD',
      'RESIZE'                      => 'Can be Resized',
      'QUALITY'                     => 'Quality and value',
      'SLOTS'                       => 'Slot Needed',
      'WIELD'                       => 'Wield Category',
      'MODS'                        => 'Requires Modification?',
   },

   'EQUIPMOD' => {
      '000ModifierName'             => '# Modifier Name',
      'ADDPROF'                     => 'Add Req. Prof.',
      'ARMORTYPE'                   => 'Change Armor Type',
      'ASSIGNTOALL'                 => 'Apply to both heads',
      'CHARGES'                     => 'Nb of Charges',
      'COSTPRE'                     => 'Cost before resizing',
      'FORMATCAT'                   => 'Naming Format',                     #[ 1594671 ] New tag: equipmod FORMATCAT
      'IGNORES'                     => 'Keys to ignore',
      'ITYPE'                       => 'Type granted',
      'KEY'                         => 'Unique Key',
      'NAMEOPT'                     => 'Naming Option',
      'PLUS'                        => 'Plus',
      'REPLACES'                    => 'Keys to replace',
   },

   'KIT STARTPACK' => {
      'STARTPACK'                   => '# Kit Name',
      'APPLY'                       => 'Apply method to char',              #[ 1593879 ] New Kit tag: APPLY
   },

   'KIT CLASS' => {
      'CLASS'                       => '# Class',
   },

   'KIT FUNDS' => {
      'FUNDS'                       => '# Funds',
   },

   'KIT GEAR' => {
      'GEAR'                        => '# Gear',
   },

   'KIT LANGBONUS' => {
      'LANGBONUS'                   => '# Bonus Language',
   },

   'KIT NAME' => {
      'NAME'                        => '# Name',
   },

   'KIT RACE' => {
      'RACE'                        => '# Race',
   },

   'KIT SELECT' => {
      'SELECT'                      => '# Select choice',
   },

   'KIT SKILL' => {
      'SKILL'                       => '# Skill',
      'SELECTION'                   => 'Selections',
   },

   'KIT TABLE' => {
      'TABLE'                       => '# Table name',
      'VALUES'                      => 'Table Values',
   },

   'MASTERBONUSRACE' => {
      '000MasterBonusRace'          => '# Race of familiar',
   },

   'RACE' => {
      '000RaceName'                 => '# Race Name',
      'FACT'                        => 'Base size',
      'FAVCLASS'                    => 'Favored Class',
      'SKILLMULT'                   => 'Skill Multiplier',
      'MONCSKILL'                   => 'Racial HD Class Skills',
      'MONCCSKILL'                  => 'Racial HD Cross-class Skills',
      'MONSTERCLASS'                => 'Monster Class Name and Starting Level',
   },

   'SPELL' => {
      '000SpellName'                => '# Spell Name',
      'CLASSES'                     => 'Classes of caster',
      'DOMAINS'                     => 'Domains granting the spell',
   },

   'SUBCLASS' => {
      '000SubClassName'             => '# Subclass',
   },

   'SUBSTITUTIONCLASS' => {
      '000SubstitutionClassName'    => '# Substitution Class',
   },

   'TEMPLATE' => {
      '000TemplateName'             => '# Template Name',
      'ADDLEVEL'                    => 'Add Levels',
      'BONUS:MONSKILLPTS'           => 'Bonus Monster Skill Points',
      'BONUSFEATS'                  => 'Number of Bonus Feats',
      'FAVOREDCLASS'                => 'Favored Class',
      'GENDERLOCK'                  => 'Lock Gender Selection',
   },

   'VARIABLE' => {
      '000VariableName'             => '# Variable Name',
      'EXPLANATION'                 => 'Explanation',
   },

   'GLOBALMOD' => {
      '000GlobalmodName'            => '# Name',
      'EXPLANATION'                 => 'Explanation',
   },

   'DATACONTROL' => {
      '000DatacontrolName'          => '# Name',
      'EXPLANATION'                 => 'Explanation',
   },
   'ALIGNMENT' => {
      '000AlignmentName'            => '# Name',
   },
   'STAT' => {
      '000StatName'                 => '# Name',
   },
   'SAVE' => {
      '000SaveName'                 => '# Name',
   },

);

my $tablength = 6;      # Tabulation each 6 characters

my %files_to_parse;     # Will hold the file to parse (including path)
my @lines;                      # Will hold all the lines of the file
my @modified_files;     # Will hold the name of the modified files


modifyMasterOrderForConversions(\%masterOrder);

=head2 constructValidTags

   Populate %validTags for all file types from masterOrder

=cut

sub constructValidTags {

   for my $lineType ( keys %masterOrder ) {
      for my $tag ( @{ $masterOrder{$lineType} } ) {
         if ( $tag =~ / ( .* ) [:][*] \z /xms ) {
            # Tag that end by :* in @masterOrder are allowed
            # to be present more then once on the same line
            $tag = $1;
            $masterMult{$lineType}{$tag} = 1;
         }

         if ( exists $validTags{$lineType}{$tag} ) {
            die "Tag $tag found more then once for $lineType";
         } else { 
            $validTags{$lineType}{$tag} = 1;
         }
      }
   }
}

=head2 isValidTag

   Is there an entry for tag in this line type.

   C<isValidTag('linetype', 'tag')>

=cut

sub isValidTag {
   my ($lineType, $tag) = @_;
   return exists $validTags{$lineType}{$tag};
}


#####################################
# Verify if the inputpath was given

if (getOption('inputpath')) {

   #################################################
   # We populate %valid_tags for all file types.

   constructValidTags();


        ##########################################################
        # Files that needs to be open for special conversions

        if ( $conversion_enable{'Export lists'} ) {
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
                if ( $conversion_enable{'ALL:Find Willpower'} ) {
                open $filehandle_for{Willpower}, '>', 'willpower.csv';
                print { $filehandle_for{Willpower} } qq{"Tag","Line","Filename"\n};
                }
        }

        ##########################################################
        # Cross-checking must be activated for the CLASSSPELL
        # conversion to work
        if ( $conversion_enable{'CLASSSPELL conversion to SPELL'} ) {
                $cl_options{xcheck} = 1;
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

        $logging->set_header(getLogHeader('PCC'));

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
                                elsif ($conversion_enable{'SPELL:Add TYPE tags'}
                                && $tag eq 'CLASS' )
                                {

                                        # [ 653596 ] Add a TYPE tag for all SPELLs
                                        #
                                        # The CLASS files must be read before any other
                                        $class_files{$lstfile} = 1;
                                }
                                elsif ( $tag eq 'SPELL' && ( $conversion_enable{'EQUIPMENT: generate EQMOD'}
                                        || $conversion_enable{'CLASS: SPELLLIST from Spell.MOD'} ) )
                                {

                                        #[ 677962 ] The DMG wands have no charge.
                                        #[ 779341 ] Spell Name.MOD to CLASS's SPELLLEVEL
                                        #
                                        # We keep a list of the SPELL files because they
                                        # need to be put in front of the others.

                                        $Spell_Files{$lstfile} = 1;
                                }
                                elsif ( $conversion_enable{'CLASSSPELL conversion to SPELL'}
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
                                elsif ($conversion_enable{'CLASSSKILL conversion to CLASS'}
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
                                if ($conversion_enable{'SOURCE line replacement'}
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
                                elsif ( $tag eq 'GAME' && $conversion_enable{'PCC:GAME to GAMEMODE'} ) {

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

                if ( $conversion_enable{'CLASSSPELL conversion to SPELL'}
                        && $found_filetype{'CLASSSPELL'}
                        && !$found_filetype{'SPELL'} )
                {
                        $logging->warning(
                                'No SPELL file found, create one.',
                                $pcc_file_name
                        );
                }

                if ( $conversion_enable{'CLASSSKILL conversion to CLASS'}
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
                $logging->set_header(getLogHeader('Missing'));

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
                $logging->set_header(getLogHeader('Unreferenced'));

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

$logging->set_header(getLogHeader('LST'));

my @files_to_parse_sorted = ();
my %temp_files_to_parse   = %files_to_parse;

if ( $conversion_enable{'SPELL:Add TYPE tags'} ) {

        # The CLASS files must be put at the start of the
        # files_to_parse_sorted array in order for them
        # to be dealt with before the SPELL files.

        for my $class_file ( sort keys %class_files ) {
                push @files_to_parse_sorted, $class_file;
                delete $temp_files_to_parse{$class_file};
        }
}

if ( $conversion_enable{'CLASSSPELL conversion to SPELL'} ) {

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

if ( $conversion_enable{'CLASSSKILL conversion to CLASS'} ) {

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

                (my $lines, $filetype) = normalize_file($buffer);
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

                        (my $lines, $filetype) = normalize_file($buffer);
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

if ( $conversion_enable{'BIOSET:generate the new files'} ) {
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

   $logging->set_header(getLogHeader('Created'), $path);

        for my $file (@modified_files) {
                $file =~ s{ $cl_options{input_path} }{}xmsi;
                $file =~ tr{/}{\\} if $^O eq "MSWin32";
                $logging->notice( "$file\n", "" );
        }

        print STDERR "================================================================\n";
}

###########################################
# Print a report for the BONUS and PRExxx usage
if ( $conversion_enable{'Generate BONUS and PRExxx report'} ) {
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
                        $tagdisplay .= "*" if $masterMult{$line_type}{$tag};
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
        $logging->set_header(getLogHeader('CrossRef'));

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
        $logging->set_header(getLogHeader('Type CrossRef'));

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
        $logging->set_header(getLogHeader('Category CrossRef'));

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

if ( $conversion_enable{'Export lists'} ) {
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

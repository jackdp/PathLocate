unit PLOC.Types;

{
  Jacek Pazera
  http://www.pazera-software.com
  Last mod: 2018.03.19
 }

{$mode objfpc}{$H+}

interface

uses
  JPL.StrList, JPLM.Files, JPL.Console
  ;


const

  {$IFDEF MSWINDOWS}
  PATH_VAR = '%PATH%';
  PATH_SEPARATOR = ';';
  {$ELSE}
  PATH_VAR = '$PATH';
  PATH_SEPARATOR = ':';
  {$ENDIF}

  DASH_LINE = '--------------------------------------------------------------------------------';

  BOOL_STR_TRUE = '1';
  BOOL_STR_FALSE = '0';


  EXIT_OK = JPL.Console.CON_EXIT_CODE_OK;
  EXIT_ERROR = JPL.Console.CON_EXIT_CODE_ERROR;
  EXIT_NO_FILES = 2;


  {$IFDEF MSWINDOWS}
  COLOR_EXE_TEXT = TConsole.clLightGreenText;
  COLOR_EXE_BG = TConsole.clNone;

  COLOR_DLL_TEXT = TConsole.clLightCyanText;
  COLOR_DLL_BG = TConsole.clNone;

  COLOR_BAT_TEXT = TConsole.clLightYellowText;
  COLOR_BAT_BG = TConsole.clNone;

  COLOR_CMD_TEXT = TConsole.clDarkYellowText;
  COLOR_CMD_BG = TConsole.clNone;

  COLOR_BPL_TEXT = TConsole.clWhiteText;
  COLOR_BPL_BG = TConsole.clDarkGrayText;

  {$ELSE}

  COLOR_SH_TEXT = TConsole.clLightYellowText;
  COLOR_SH_BG = TConsole.clNone;

  COLOR_SO_TEXT = TConsole.clLightCyanText;
  COLOR_SO_BG = TConsole.clNone;

  {$ENDIF}

  COLOR_HIGHLIGHT_FG1 = TConsole.clWhiteText;
  COLOR_HIGHLIGHT_BG1 = TConsole.clLightBlueBg;

  COLOR_HIGHLIGHT_FG2 = TConsole.clBlackText;
  COLOR_HIGHLIGHT_BG2 = TConsole.clLightGreenBg;

type

  TFileExtInfo = record
    FileName: string;
    Dates: TFileDates;
    Attrs: LongInt;
    Size: Int64;
  end;


  TDisplayParams = record
    Separator: string;
    Separator_DateTime: string;
    Numbering: Boolean;
    SizeBytes: Boolean;
    SizeHuman: Boolean;
    FileAttributes: Boolean;
    Date_Creation: Boolean;
    Date_LastWrite: Boolean;
    Date_LastAccess: Boolean;
    Hash_Crc: Boolean;
    Hash_MD5: Boolean;
    Hash_SHA1: Boolean;
    Hash_SHA2: Boolean;
  end;

  TFileInfoArray = array of TFileExtInfo;

  TLimitMode = (lmNoLimit, lmFirst, lmLast); // All files / fisrt X files / last X files

  TSortDirection = (sdAscending, sdDescending);
  TSortByField = (sbfNone, sbfFileName, sbfSize, sbfDateCreation, sbfDateLastWrite, sbfDateLastAccess);
  TSortFIACompareFunc = function (const fei1, fei2: TFileExtInfo; const sbf: TSortByField; const bAscending: Boolean): integer;


  TAppParams = record
    FileMasks: TJPStrList;         // -f
    Dirs: TJPStrList;              // -p
    SizeBytes: Boolean;            // -s
    SizeHuman: Boolean;            // -S
    {$IFDEF MSWINDOWS}
    DateCreation: Boolean;         // -dc
    FileAttrs: Boolean;            // -a
    {$ENDIF}
    DateLastWrite: Boolean;        // -dw
    DateLastAccess: Boolean;       // -da
    Numbering: Boolean;            // -n
    CaseSensitive: Boolean;        // -cs
    AlsoCurrentDir: Boolean;       // -c
    ShowSummary: Boolean;          // -u
    CalcCrc32: Boolean;            // --crc
    CalcHashMD5: Boolean;          // --md5
    CalcHashSha1: Boolean;         // --sha1
    CalcHashSha2_256: Boolean;     // --sha2
    LimitMode: TLimitMode;         // -lm
    FileCountLimit: integer;       // -lm firstX | lastX
    SortDirection: TSortDirection; // -sd
    SortByField: TSortByField;     // -sb
    ListDirs: Boolean;             // -ld
    ListSeparator: string;         // -sl  - list items separator
    DateTimeSeparator: string;     // -sdt - date / time separator
    DisplayErrors: Boolean;        // -err
    {$IFDEF MSWINDOWS}
    ReadVersionInfo: Boolean;      // -vi
    {$ENDIF}

    HighlightErrors: Boolean;
    ConColor_Error: TConsoleColors;
    UserHighlightStr1: string;           // -hus  : highlight string specified by the user
    UserHighlightStr2: string;           // -hus2 : highlight string specified by the user
    UserHighlightCaseSensitive: Boolean; // -husc
    ConColor_USER_1: TConsoleColors;    // używane przy podświetlaniu tekstu podanego przez użytkownika
    ConColor_USER_2: TConsoleColors;    // używane przy podświetlaniu tekstu podanego przez użytkownika

    {$IFDEF MSWINDOWS}
    HighlightExes: Boolean;        // -he
    HighlightDlls: Boolean;        // -hd
    HighlightBats: Boolean;        // -hb
    HighlightCmds: Boolean;        // -hc
    HighlightBpls: Boolean;        // -hp

    ConColor_EXE: TConsoleColors;
    ConColor_DLL: TConsoleColors;
    ConColor_BAT: TConsoleColors;
    ConColor_CMD: TConsoleColors;
    ConColor_BPL: TConsoleColors;
    {$ELSE} // Linux
    HighlightBashScripts: Boolean; // -hs
    HighlightSoLibs: Boolean;      // -hl

    ConColor_SH: TConsoleColors;
    ConColor_SO: TConsoleColors;
    {$ENDIF}
  end;

implementation

end.


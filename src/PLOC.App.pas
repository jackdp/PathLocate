unit PLOC.App;

{
  Jacek Pazera
  http://www.pazera-software.com
  Last mod: 2018.03.19
 }

{$mode objfpc}{$H+}

interface

uses
  // FPC units
  MFPC.LazUtils.LazUTF8,
  SysUtils, StrUtils,

  // Windows only
  {$IFDEF MSWINDOWS}Windows, {$ENDIF}

  // JPLib / JPLib (M)
  JPL.Console, JPL.ConsoleApp, JPL.Console.ColorParser, JPL.CmdLineParser, JPL.StrList,
  JPL.Strings, JPL.Conversion, JPL.TimeLogger, JPL.SimpleLogger,
  JPLM.FileSearch, JPLM.FileSearcher,

  // App units
  PLOC.Types,
  PLOC.PROCS;


type

  TApp = class(TJPConsoleApp)
  private
    AppParams: TAppParams;
  public
    constructor Create;

    procedure Init;
    procedure Run;
    procedure Done;

    procedure RegisterOptions;
    procedure ProcessOptions;

    procedure SearchFiles;
    procedure ListDirs;

    procedure DisplayHelpAndTerminate(const ExCode: integer);
    procedure DisplayShortUsageAndTerminate(const Msg: string; const ExCode: integer);
    procedure DisplayBannerAndTerminate(const ExCode: integer);
    procedure DisplayMessageAndTerminate(const Msg: string; const ExCode: integer);

  end;



implementation



constructor TApp.Create;
begin
  inherited;
end;


{$region '                            Init                                      '}
procedure TApp.Init;
begin
  //----------------------------------------------------------------------------

  AppName := 'PathLocate';
  MajorVersion := 1;
  MinorVersion := 1;
  Date := EncodeDate(2018, 3, 19);
  FullNameFormat := '%AppName% %MajorVersion%.%MinorVersion% [%OSShort% %Bits%-bit] (%AppDate%)';
  Description := 'Searches for files in the directories specified in the ' + PATH_VAR + ' environment variable.';
  LicenseName := 'Freeware, OpenSource';
  Author := 'Jacek Pazera';
  HomePage := 'http://www.pazera-software.com/products/path-locate/';
  HelpPage := HomePage + 'help.html';

  {$IFDEF MSWINDOWS}
  Console.OutputCodePage := CP_UTF8;
  Console.TextCodePage := CP_UTF8;
  RestoreOutputCodePageOnExit := True;
  {$ENDIF}

  //-----------------------------------------------------------------------------

  TryHelpStr := ENDL + 'Try <color=yellow>' + ExeShortName + ' --help</color> for more info.';

  //-----------------------------------------------------------------------------

  ShortUsageStr :=
    ENDL +
    'Usage: ' + ExeShortName +
    ' FILES [-c] [-n] [-s] [-S]' +
    {$IFDEF MSWINDOWS}' [-dc]' +{$ENDIF}
    ' [-dw] [-da]' +


    {$IFDEF MSWINDOWS}' [-a] [-vi]' +{$ENDIF}

    ' [-u]' +
    ' [-of=s|l|w] [-l] [-cs=1|0] [-sd=a|d] [-sb=[name|size|dw|' +
    {$IFDEF MSWINDOWS} 'dc|' + {$ENDIF} 'da]]' +

    ' [-hus=STR] [-hus2=STR] [-husc=[1|0]]' +
    {$IFDEF MSWINDOWS}
    ' [-he] [-hd] [-hb] [-hc] [-hp]' +
    {$ELSE}
    ' [-hs] [-hl]' +
    {$ENDIF}
    ' [-hn]' + // highlight none


    ' [-lm=n|X|fX|lX] [--crc] [--md5] [--sha1] [--sha2] [-ld] [-err=[1|0]]' +

    ' [-h]' +
    {$IFDEF MSWINDOWS}
    ' [-hh]' +
    {$ENDIF}
    ' [-V] [-vs]' +

    {$IFDEF MSWINDOWS} ' [--home]' + {$ENDIF}
    ENDL + ENDL +
    'Mandatory arguments to long options are mandatory for short options too.' + ENDL +
    'Options are <color=cyan>case-sensitive</color>. Options in square brackets are optional.' + ENDL +
    'All parameters that do not start with the "-" or "/" sign are treated as file names/masks.' + ENDL +
    'Options and input files can be placed in any order, but -- (double dash)' + ENDL +
    'indicates the end of parsing options and all subsequent parameters are treated as file names/masks.';

  //-----------------------------------------------------------------------------

  ExamplesStr :=
    DASH_LINE +
    {$IFDEF MSWINDOWS}
    ENDL +
    '<color=cyan>Examples:</color>' + ENDL +
    ENDL +
    'Show all files from directories listed in the %PATH% environment variable:' + ENDL +
    '  ' + ExeShortName + ' *' + ENDL +
    ENDL +
    'Show the first 10 EXE and/or DLL files from directories listed in the %PATH% environment variable:' + ENDL +
    '  ' + ExeShortName + ' *.exe *.dll -lm 10' + ENDL +
    ENDL +
    'Display VersionInfo block from the msvcrt.dll file and calculate its CRC32 cheksum:' + ENDL +
    '  ' + ExeShortName + ' msvcrt.dll -vi --crc';
    {$ELSE}
    ENDL +
    '<color=cyan>Examples:</color>' + ENDL +
    ENDL +
    'Show all files from directories listed in the $PATH environment variable:' + ENDL +
    '  ' + ExeShortName + ' "*"' + ENDL +
    ENDL +
    'Show the first file from directories listed in the $PATH environment variable, whose name begins with "gcc":' + ENDL +
    '  ' + ExeShortName + ' gcc* -lm 1' + ENDL +
    ENDL +
    'Show files from directories listed in the $PATH environment variable, whose names contain the text "README", ' +
            'not case-sensitive:' + ENDL +
    '  ' + ExeShortName + ' *README* -s 0';

    {$ENDIF}


  //------------------------------------------------------------------------------


  AppParams.FileMasks := TJPStrList.Create;
  AppParams.Dirs := TJPStrList.Create;

  AppParams.Numbering := False;
  AppParams.SizeBytes := False;
  AppParams.SizeHuman := False;
  {$IFDEF MSWINDOWS}
  AppParams.DateCreation := False;
  AppParams.FileAttrs := False;
  {$ENDIF}
  AppParams.DateLastWrite := False;
  AppParams.DateLastAccess := False;
  AppParams.CaseSensitive := JPFileSearchCaseSensitive; // Default: True on Linux, False on Windows
  AppParams.AlsoCurrentDir := False;
  AppParams.CalcCrc32 := False;
  AppParams.CalcHashMD5 := False;
  AppParams.CalcHashSha1 := False;
  AppParams.CalcHashSha2_256 := False;
  AppParams.LimitMode := lmNoLimit;
  AppParams.FileCountLimit := 0;
  AppParams.SortDirection := TSortDirection.sdAscending;
  AppParams.SortByField := sbfNone;
  AppParams.ListDirs := False;
  AppParams.ListSeparator := ' | ';
  AppParams.DateTimeSeparator := ' - ';
  AppParams.UserHighlightStr1 := '';
  AppParams.UserHighlightStr2 := '';
  AppParams.UserHighlightCaseSensitive := False;
  AppParams.ConColor_USER_1.Text := COLOR_HIGHLIGHT_FG1;
  AppParams.ConColor_USER_1.Background := COLOR_HIGHLIGHT_BG1;
  AppParams.ConColor_USER_2.Text := COLOR_HIGHLIGHT_FG2;
  AppParams.ConColor_USER_2.Background := COLOR_HIGHLIGHT_BG2;
  AppParams.DisplayErrors := True;

  {$IFDEF MSWINDOWS}
  AppParams.HighlightExes := True;
  AppParams.HighlightDlls := True;
  AppParams.HighlightBats := True;
  AppParams.HighlightCmds := True;
  AppParams.HighlightBpls := True;

  AppParams.ConColor_EXE.Text := COLOR_EXE_TEXT;
  AppParams.ConColor_EXE.Background := COLOR_EXE_BG;

  AppParams.ConColor_DLL.Text := COLOR_DLL_TEXT;
  AppParams.ConColor_DLL.Background := COLOR_DLL_BG;

  AppParams.ConColor_BAT.Text := COLOR_BAT_TEXT;
  AppParams.ConColor_BAT.Background := COLOR_BAT_BG;

  AppParams.ConColor_CMD.Text := COLOR_CMD_TEXT;
  AppParams.ConColor_CMD.Background := COLOR_CMD_BG;

  AppParams.ConColor_BPL.Text := COLOR_BPL_TEXT;
  AppParams.ConColor_BPL.Background := COLOR_BPL_BG;
  {$ELSE}
  AppParams.HighlightBashScripts := True;
  AppParams.HighlightSoLibs := True;

  AppParams.ConColor_SH.Text := COLOR_SH_TEXT;
  AppParams.ConColor_SH.Background := COLOR_SH_BG;

  AppParams.ConColor_SO.Text := COLOR_SO_TEXT;
  AppParams.ConColor_SO.Background := COLOR_SO_BG;
  {$ENDIF}


end;
{$endregion Init}


procedure TApp.Run;
begin

  RegisterOptions;
  Cmd.Parse;
  ProcessOptions;

  if Terminated then Exit;

  if not AppParams.ListDirs then SearchFiles
  else ListDirs;

end;

procedure TApp.Done;
begin
  if Assigned(AppParams.FileMasks) then FreeAndNil(AppParams.FileMasks);
  if Assigned(AppParams.Dirs) then FreeAndNil(AppParams.Dirs);
end;

{$region '                            RegisterOptions                           '}
procedure TApp.RegisterOptions;
const
  MAX_LINE_LEN = 102;
var
  s, Category: string;
  sCatTagStart, sCatTagEnd: string;
  xpad: integer;
begin
  sCatTagStart := '<color=yellow>';
  sCatTagEnd := '</color>';

  {$IFDEF MSWINDOWS} Cmd.CommandLineParsingMode := cpmCustom; {$ELSE} Cmd.CommandLineParsingMode := cpmDelphi; {$ENDIF}
  Cmd.UsageFormat := cufWget;
  Cmd.AllowDuplicates := True;
  Cmd.AcceptAllNonOptions := True;


  {$region ' ------------ Main ---------------------- '}
  Category := 'main';
  xpad := Length('  -cs,  --case-sensitive=1|0') + 4;


  // -c : Current directory -----------------
  Cmd.RegisterOption( 'c', 'current-dir', cvtNone, False, False, 'Also searches for files in the current directory.', '', Category);

  // - ld : List firectories from %PATH% var
  Cmd.RegisterOption('ld', 'list-dirs', cvtNone, False, False,
  'List directories specified in the ' + PATH_VAR + ' and exit. You can sort list of directories with "-sb" switch in ascending ' +
  '("-sd=a") or descending ("-sd=d") order.',
  '', Category);

  // -cs : Case sensitive --------------------
  {$IFDEF MSWINDOWS} s := 'Default: 0'; {$ELSE} s := 'Default: 1'; {$ENDIF}
  Cmd.RegisterOption(
    'cs', 'case-sensitive', cvtRequired, False, False,
    'Case sensitive. 1 - enabled, 0 - disabled. ' + s + '. Used when searching and sorting files.',
    '1|0', Category
  );

  // -l : Limit ----------------------------
  Cmd.RegisterOption('lm', 'limit', cvtRequired, False, False, 'File count limit:', 'n|X|fX|lX', Category);
  Cmd.SetOptionExtraInfo(
    'lm',
    'n | none - no limit (show all files). Default.' + ENDL +
    'X - show only the first X files.' + ENDL +
    'fX | firstX - as above' + ENDL +
    'lX | lastX - show only the last X files.',
    xpad
  );

  // -n : Numbering -------------------------
  Cmd.RegisterOption('n', 'numbers', cvtNone, False, False, 'Display file numbers.', '', Category);

  // - s AND -S : Display file size
  Cmd.RegisterOption('s', 'size-bytes', cvtNone, False, False, 'Display file size in bytes.', '', Category);
  Cmd.RegisterOption('S', 'size', cvtNone, False, False, 'Display file size in human readable format (e.g. 8KB, 16MB).', '', Category);

  // -dc, -dw, -da : File dates
  {$IFDEF MSWINDOWS}
  Cmd.RegisterOption('dc', 'date-creation', cvtNone, False, False, 'Display file creation time.', '', Category);
  {$ENDIF}
  Cmd.RegisterOption('dw', 'date-write', cvtNone, False, False, 'Display file last write (modification) time.', '', Category);
  Cmd.RegisterOption('da', 'date-access', cvtNone, False, False, 'Display file last access time.', '', Category);

  {$IFDEF MSWINDOWS}
  Cmd.RegisterOption('a', 'attributes', cvtNone, False, False, 'Display file attributes (HSRALCE). See additional info below.', '', Category);
  Cmd.RegisterOption('vi', 'version-info', cvtNone, False, False, 'Displays VersionInfo block from executable files, if available.', '', Category);
  {$ENDIF}

  Cmd.RegisterOption('u', 'summary', cvtNone, False, False, 'Show summary: the number of files found, their total size, elapsed time.', '', Category);

  // -of : Output format --------------------
  Cmd.RegisterOption('of', 'out-format', cvtRequired, False, False, 'Output format: s, l, f', 's|l|f', Category);
  Cmd.SetOptionExtraInfo(
    'of',
    's | Simple - only file names (default)' + ENDL +
    'l | Long - file names with additional information.' + ENDL + '    Alias for: -n -S -dw' + {$IFDEF MSWINDOWS} ' -a' + {$ENDIF} ' -u.' + ENDL +
    'f | Full - displays full information.' + ENDL +
    '    Alias for: -n -s -S' + {$IFDEF MSWINDOWS} ' -dc' + {$ENDIF} ' -dw -da' + {$IFDEF MSWINDOWS} ' -a -vi' + {$ENDIF} ' -u.',
    xpad
  );

  // -l : Long format
  Cmd.RegisterOption('l', 'long', cvtNone, False, False, 'Long format. Alias for --out-format=long', '', Category);

  // -sl : List separator
  Cmd.RegisterOption('sl', 'list-separator', cvtRequired, False, False, 'List separator. Default: "' + AppParams.ListSeparator + '"', 'STR', Category);

  // -sdt : Date - time separator
  Cmd.RegisterOption('sdt', 'dt-separator', cvtRequired, False, False, 'Date-time separator. Default: "' + AppParams.DateTimeSeparator + '"', 'STR', Category);

  // -err : Display errors
  Cmd.RegisterOption(
    'err', 'show-errors', cvtRequired, False, False,
    'Display errors. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.DisplayErrors), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  {$endregion Main}


  {$region ' ------------ Sorting ------------------- '}
  Category := 'sorting';

  // -sb : Sort by field ---------------------
  Cmd.RegisterOption('sb', 'sort-by', cvtOptional, False, False,
    'Sort results by specified column. Available values:', 'COL', Category
  );
  Cmd.SetOptionExtraInfo(
    'sb',
    'name - Sort results by file name. Default.' + ENDL +
    'size - Sort results by file size.' + ENDL +
    {$IFDEF MSWINDOWS} 'dc - Sort results by file creation date.' + ENDL + {$ENDIF}
    'dw - Sort results by file last write date.' + ENDL +
    'da - Sort results by file last access date.' + ENDL +
    'none - Do not sort results.',
    xpad
  );

  // -sd : Sort direction --------------------
  Cmd.RegisterOption('sd', 'sort-direction', cvtRequired, False, False,
    'Sorting order. The "-sb" switch should be specified. Available values:', 'a|d', Category
  );
  Cmd.SetOptionExtraInfo(
    'sd',
    'a | Ascending - Sort results in ascending order. Default.' + ENDL +
    'd | Descending - Sort results in descending order.',
    xpad
  );
  {$endregion Sorting}


  {$region ' ------------ Highlighting -------------- '}
  Category := 'colors';

  Cmd.RegisterOption('hus', 'highlight-str', cvtRequired, False, False, 'Highlight string specified by the user.', 'STR', Category);
  Cmd.RegisterOption('hus2', 'highlight-str2', cvtRequired, False, False, 'Highlight string specified by the user.', 'STR', Category);

  Cmd.RegisterOption(
    'husc', 'highlight-str-cs',cvtOptional, False, False,
    'Take into account (or not) the character size when highlighting the text provided by the user. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.UserHighlightCaseSensitive), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  Cmd.RegisterOption('hn', 'highlight-none', cvtNone, False, False, 'Don''t highlight any files.', '', Category);

  {$IFDEF MSWINDOWS}

  Cmd.RegisterOption(
    'he', 'highlight-exe', cvtRequired, False, False,
    'Highlight executable files - EXE. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightExes), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  Cmd.RegisterOption(
    'hd', 'highlight-dll', cvtRequired, False, False,
    'Highlight DLL libraries. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightDlls), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  Cmd.RegisterOption(
    'hb', 'highlight-bat', cvtRequired, False, False,
    'Highlight batch scripts - BAT. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightBats), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  Cmd.RegisterOption(
    'hc', 'highlight-cmd', cvtRequired, False, False,
    'Highlight CMD scripts. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightCmds), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  Cmd.RegisterOption(
    'hp', 'highlight-bpl', cvtRequired, False, False,
    'Highlight BPL libraries. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightBpls), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  {$ELSE} // Linux

  Cmd.RegisterOption(
    'hs', 'highlight-sh', cvtRequired, False, False,
    'Highlight shell scripts - SH. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightBashScripts), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  Cmd.RegisterOption(
    'hl', 'highlight-so', cvtRequired, False, False,
    'Highlight SO libraries. ' +
    BOOL_STR_TRUE + ' - enabled, ' + BOOL_STR_FALSE + ' - disabled. ' +
    'Default: ' + BoolToStr10(AppParams.HighlightSoLibs), BOOL_STR_TRUE + '|' + BOOL_STR_FALSE,
    Category
  );

  {$ENDIF}


  {$endregion Highlighting}


  {$region ' ------------ Hash ---------------------- '}
  Category := 'hash';
  Cmd.RegisterLongOption('crc', cvtNone, False, False, 'Calculate CRC32 checksums of found files.', '', Category);
  Cmd.RegisterLongOption('md5', cvtNone, False, False, 'Calculate MD5 hash of found files.', '', Category);
  Cmd.RegisterLongOption('sha1', cvtNone, False, False, 'Calculate SHA-1 hash of found files.', '', Category);
  Cmd.RegisterLongOption('sha2', cvtNone, False, False, 'Calculate SHA-2-256 hash of found files.', '', Category);
  {$endregion Hash}


  {$region ' ------------ Info ---------------------- '}
  Category := 'info';
  Cmd.RegisterOption('h', 'help', cvtNone, False, False, 'Show this help.', '', Category);
  {$IFDEF MSWINDOWS}
  Cmd.RegisterOption('hh', 'help-online', cvtNone, False, False, 'Online help.', '', Category);
  {$ENDIF}
  Cmd.RegisterShortOption('?', cvtNone, False, True, '', '', '');
  Cmd.RegisterOption('V', 'version', cvtNone, False, False, 'Show application name and version.', '', Category);
  Cmd.RegisterOption('vs', 'version-short', cvtNone, False, False, 'Show only the version number and exit.', '', Category);
  {$IFDEF MSWINDOWS}
  Cmd.RegisterLongOption('home', cvtNone, False, False, 'Opens program home page in the default browser.', '', Category);
  {$ENDIF}
  {$endregion Info}


  UsageStr :=
    DASH_LINE + ENDL +
    '<color=yellow>FILES</color> - Any combination of file names / masks.' + ENDL +
    '        E.g.: picture.png *build*.log "long file name*"' + ENDL +
    DASH_LINE +
    ENDL + sCatTagStart + 'Main options:' + sCatTagEnd + ENDL + Cmd.OptionsUsageStr('  ', 'main', MAX_LINE_LEN, '  ', 30) +
    ENDL + ENDL + sCatTagStart + 'Sorting:' + sCatTagEnd + ENDL + Cmd.OptionsUsageStr('  ', 'sorting', MAX_LINE_LEN, '  ', 30) +
    ENDL + ENDL + sCatTagStart + 'Highlighting:' + sCatTagEnd + ENDL + Cmd.OptionsUsageStr('  ', 'colors', MAX_LINE_LEN, '  ', 30) +
    ENDL + ENDL + sCatTagStart + 'Checksum & hash:' + sCatTagEnd + ENDL + Cmd.OptionsUsageStr('  ', 'hash', MAX_LINE_LEN, '  ', 30) +
    ENDL + ENDL + sCatTagStart + 'Information:' + sCatTagEnd + ENDL + Cmd.OptionsUsageStr('  ', 'info', MAX_LINE_LEN, '  ', 30) + ENDL;

  {$IFDEF MSWINDOWS}
  UsageStr := UsageStr +
    DASH_LINE + ENDL +
    '<color=cyan>File attributes:</color>' + ENDL +
    '  H - hidden          S - system' + ENDL +
    '  R - read only       A - archive' + ENDL +
    '  L - symbolic link   C - compressed' + ENDL +
    '  E - encrypted';
  {$ENDIF}

end;
{$endregion RegisterOptions}


{$region '                            ProcessOptions                            '}
procedure TApp.ProcessOptions;
var
  s, us, sErr: string;
  i: integer;
  b: Boolean;
begin
  if Cmd.IsOptionExists('vs') then
  begin
    Write(VersionStr(False));
    ExitCode := CON_EXIT_CODE_OK;
    Terminate;
    Exit;
  end;

  // Show help and exit
  if (ParamCount = 0) or (Cmd.IsLongOptionExists('help')) or (Cmd.IsOptionExists('?')) then
  begin
    DisplayHelpAndTerminate(CON_EXIT_CODE_OK);
    Exit;
  end;

  // Display version nad exit
  if Cmd.IsOptionExists('version') then
  begin
    DisplayBannerAndTerminate(CON_EXIT_CODE_OK);
    Exit;
  end;

  {$IFDEF MSWINDOWS}
  // Open program home page and exit
  if Cmd.IsLongOptionExists('home') then
  begin
    GoToHomePage;
    ExitCode := CON_EXIT_CODE_OK;
    Terminate;
    Exit;
  end;

  // Online help
  if Cmd.IsOptionExists('hh') then
  begin
    GoToHelpPage;
    ExitCode := CON_EXIT_CODE_OK;
    Terminate;
    Exit;
  end;
  {$ENDIF}


  if Cmd.ErrorCount > 0 then
  begin
    DisplayShortUsageAndTerminate(Cmd.ErrorsStr, CON_EXIT_CODE_SYNTAX_ERROR);
    Exit;
  end;


  // -l, --long
  if Cmd.IsOptionExists('l') then
  begin
    AppParams.Numbering := True;
    AppParams.SizeHuman := True;
    AppParams.DateLastWrite := True;
    {$IFDEF MSWINDOWS}
    AppParams.FileAttrs := True;
    {$ENDIF}
    AppParams.ShowSummary := True;
  end;

  // -of, --out-format
  if Cmd.IsOptionExists('of') then
  begin
    s := Cmd.GetOptionValue('of');
    us := TrimUp(s);
    if (us = 'S') or (us = 'SIMPLE') then
    begin
      // nothing to change!
    end
    else if (us = 'L') or (us = 'LONG') then
    begin
      AppParams.Numbering := True;
      AppParams.SizeHuman := True;
      AppParams.DateLastWrite := True;
      {$IFDEF MSWINDOWS}
      AppParams.FileAttrs := True;
      {$ENDIF}
      AppParams.ShowSummary := True;
    end
    else if (us = 'F') or (us = 'FULL') then
    begin
      AppParams.Numbering := True;
      AppParams.SizeBytes := True;
      AppParams.SizeHuman := True;
      AppParams.DateLastWrite := True;
      {$IFDEF MSWINDOWS}
      AppParams.DateCreation := True;
      AppParams.FileAttrs := True;
      AppParams.ReadVersionInfo := True;
      {$ENDIF}
      AppParams.DateLastAccess := True;
      AppParams.ShowSummary := True;
    end
    else
    begin
      sErr := 'Invalid value for output format: ' + s + ENDL + 'Valid values: s, Simple, l, Long, f, Full';
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;
  end;

  if Cmd.IsOptionExists('s') then AppParams.SizeBytes := True; //Cmd.IsOptionExists('s');
  if Cmd.IsOptionExists('S') then AppParams.SizeHuman := True; //Cmd.IsOptionExists('S');

  {$IFDEF MSWINDOWS}
  if Cmd.IsOptionExists('dc') then AppParams.DateCreation := True; //Cmd.IsOptionExists('dc');
  if Cmd.IsOptionExists('a') then AppParams.FileAttrs := True; //Cmd.IsOptionExists('a');
  {$ENDIF}
  if Cmd.IsOptionExists('dw') then AppParams.DateLastWrite := True; //Cmd.IsOptionExists('dw');
  if Cmd.IsOptionExists('da') then AppParams.DateLastAccess := True; //Cmd.IsOptionExists('da');


  // -lm --limit=n|X|fX|lX
  if Cmd.IsOptionExists('lm') then
  begin
    s := Cmd.GetOptionValue('lm');
    if not TryGetLimitValue(s, AppParams.LimitMode, AppParams.FileCountLimit, sErr) then
    begin
      if sErr <> '' then sErr := 'Invalid value for "--limit" option: ' + s + ENDL + sErr
      else sErr := 'Invalid value for "--limit" option: ' + s;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;
  end;


  // -sl, --list-separator
  if Cmd.IsOptionExists('sl') then AppParams.ListSeparator := Cmd.GetOptionValue('sl');

  // -sdt, --dt-separator  (Date-time separator)
  if Cmd.IsOptionExists('sdt') then AppParams.DateTimeSeparator := Cmd.GetOptionValue('sdt');

  // -s, --case-sensitive
  if Cmd.IsOptionExists('cs') then
    if Cmd.TryGetOptionValueAsBool('cs', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.CaseSensitive := b
    else
    begin
      sErr :=
        'Invalid value for option "-cs": ' + Cmd.GetOptionValue('cs') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  // -err, --show-errors
  if Cmd.IsOptionExists('err') then
    if Cmd.TryGetOptionValueAsBool('err', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.DisplayErrors := b
    else
    begin
      sErr :=
        'Invalid value for option "-err": ' + Cmd.GetOptionValue('err') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;


  // -sb, --sort-by
  if Cmd.IsOptionExists('sb') then
  begin
    s := Cmd.GetOptionValue('sb', '');
    if s = '' then s := 'name'; // default
    if not TryGetSortByFieldValue(s, AppParams.SortByField) then
    begin
      sErr :=
        'Invalid value for "-sb" option: ' + s + ENDL +
        'Available values: "name", "size", ';
      {$IFDEF MSWINDOWS} sErr += '"dc", ';{$ENDIF}
      sErr += '"dw", "da".';
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;
  end;

  // -sd, --sort-direction
  if Cmd.IsOptionExists('sd') then
  begin
    s := Cmd.GetOptionValue('sd', '');
    if not TryGetSortDirectionValue(s, AppParams.SortDirection) then
    begin
      sErr :=
        'Invalid value for "-sd" option: ' + s + ENDL +
        'Expected: "a" or "ascending" or "d" or "descending".';
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

    if AppParams.SortByField = sbfNone then
      DisplayHint('Hint: Option "-sd" will not be used. Not specified column to sort in the "-sb" option.');
  end;

  // -n, --numbers
  if Cmd.IsOptionExists('n') then AppParams.Numbering := Cmd.IsOptionExists('n');

  // -c, --current-dir
  AppParams.AlsoCurrentDir := Cmd.IsOptionExists('c');

  // --crc32
  AppParams.CalcCrc32 := Cmd.IsLongOptionExists('crc');

  // --md5
  AppParams.CalcHashMD5 := Cmd.IsLongOptionExists('md5');

  // --sha1
  AppParams.CalcHashSha1 := Cmd.IsLongOptionExists('sha1');

  // --sha2
  AppParams.CalcHashSha2_256 := Cmd.IsLongOptionExists('sha2');

  // -ld
  AppParams.ListDirs := Cmd.IsOptionExists('ld');

  {$IFDEF MSWINDOWS}
  // -vi, --version-info
  if Cmd.IsOptionExists('vi') then AppParams.ReadVersionInfo := Cmd.IsOptionExists('vi');
  {$ENDIF}

  // -u, --summary
  if Cmd.IsOptionExists('u') then AppParams.ShowSummary := Cmd.IsOptionExists('u');


  {$region ' ------------ COLORS -------------- '}


  if Cmd.IsOptionExists('hus') then AppParams.UserHighlightStr1 := Cmd.GetOptionValue('hus');
  if Cmd.IsOptionExists('hus2') then AppParams.UserHighlightStr2 := Cmd.GetOptionValue('hus2');

  if Cmd.IsOptionExists('husc') then
    if Cmd.GetOptionValue('husc') = '' then AppParams.UserHighlightCaseSensitive := True
    else
      if Cmd.TryGetOptionValueAsBool('husc', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.UserHighlightCaseSensitive := b
      else
      begin
        sErr :=
          'Invalid value for option "-husc": ' + Cmd.GetOptionValue('husc') + ENDL +
          'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
        DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
        Exit;
      end;

  {$IFDEF MSWINDOWS}

  if Cmd.IsOptionExists('hn') then
  begin
    AppParams.HighlightExes := False;
    AppParams.HighlightDlls := False;
    AppParams.HighlightBats := False;
    AppParams.HighlightCmds := False;
    AppParams.HighlightBpls := False;
  end;

  // EXE
  if Cmd.IsOptionExists('he') then
    if Cmd.TryGetOptionValueAsBool('he', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightExes := b
    else
    begin
      sErr :=
        'Invalid value for option "-he": ' + Cmd.GetOptionValue('he') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  // DLL
  if Cmd.IsOptionExists('hd') then
    if Cmd.TryGetOptionValueAsBool('hd', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightDlls := b
    else
    begin
      sErr :=
        'Invalid value for option "-hd": ' + Cmd.GetOptionValue('hd') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  // BAT
  if Cmd.IsOptionExists('hb') then
    if Cmd.TryGetOptionValueAsBool('hb', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightBats := b
    else
    begin
      sErr :=
        'Invalid value for option "-hb": ' + Cmd.GetOptionValue('hb') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  // CMD
  if Cmd.IsOptionExists('hc') then
    if Cmd.TryGetOptionValueAsBool('hc', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightCmds := b
    else
    begin
      sErr :=
        'Invalid value for option "-hc": ' + Cmd.GetOptionValue('hc') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  // BPL
  if Cmd.IsOptionExists('hp') then
    if Cmd.TryGetOptionValueAsBool('hp', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightBpls := b
    else
    begin
      sErr :=
        'Invalid value for option "-hp": ' + Cmd.GetOptionValue('hp') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;


  {$ELSE} // Linux

  if Cmd.IsOptionExists('hs') then
    if Cmd.TryGetOptionValueAsBool('hs', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightBashScripts := b
    else
    begin
      sErr :=
        'Invalid value for option "-hs": ' + Cmd.GetOptionValue('hs') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  if Cmd.IsOptionExists('hl') then
    if Cmd.TryGetOptionValueAsBool('hl', b, BOOL_STR_TRUE, BOOL_STR_FALSE, True) then AppParams.HighlightSoLibs := b
    else
    begin
      sErr :=
        'Invalid value for option "-hl": ' + Cmd.GetOptionValue('hl') + ENDL +
        'Expected: ' + BOOL_STR_TRUE + ' or ' + BOOL_STR_FALSE;
      DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;

  {$ENDIF}

  {$endregion COLORS}


  // Parameters that do not start with the "-" or "/" sign are treated as file names/masks
  for i := 0 to Cmd.UnknownParamCount - 1 do
    AppParams.FileMasks.Add(Cmd.UnknownParams[i].ParamStr);


  // Parameters that occurred after the stop parsing switch "--" are treated as file names/masks.
  for i := 0 to Cmd.SkippedParamsCount - 1 do
    AppParams.FileMasks.Add(Cmd.SkippedParams[i]);


  if (AppParams.FileMasks.Count = 0) and (not AppParams.ListDirs) then
  begin
    sErr := 'You must provide at least one file name/mask.';
    DisplayShortUsageAndTerminate(sErr, CON_EXIT_CODE_SYNTAX_ERROR);
    Exit;
  end;
end;

{$endregion ProcessOptions}


{$region '                            SearchFiles                               '}
procedure TApp.SearchFiles;
var
  fs: TJPFileSearcher;
  slFiles: TJPStrList;
  FileName, Line, s: string;
  {$IFDEF MSWINDOWS}svi: string;{$ENDIF}
  i, xFirstFileNo, xFileNo, xfn: integer;
  sl: TJPStrList;
  ArrMasks: array of string;
  xTotalSize, xMaxFileSize: Int64;
  ArrFileInfo: TFileInfoArray;
  xPadSizeMax: integer;
  dp: TDisplayParams;
  bError: Boolean;
  ccError: TConsoleColors;
  ccp: TConColorParser;
  li: TLogItem;

begin

  xFileNo := 0;
  xTotalSize := 0;
  TTimeLogger.StartLog;

  AppParams.FileMasks.RemoveDuplicates(AppParams.CaseSensitive);
  AppParams.FileMasks.SaveToArray(ArrMasks);


  // Pobranie listy katalogów do przeszukania
  s := SysUtils.GetEnvironmentVariable('PATH');
  sl := TJPStrList.Create;
  try
    StrToList(s, sl, PATH_SEPARATOR);
    for i := 0 to sl.Count - 1 do sl[i] := IncludeTrailingPathDelimiter(sl[i]);
    AppParams.Dirs.AddStrings(sl);
  finally
    sl.Free;
  end;

  if AppParams.AlsoCurrentDir then AppParams.Dirs.Insert(0, IncludeTrailingPathDelimiter(GetCurrentDir));
  AppParams.Dirs.RemoveDuplicates(AppParams.CaseSensitive);

  {$region '       Wyszukiwanie plików         '}
  slFiles := TJPStrList.Create;
  fs := TJPFileSearcher.Create;
  try

    // Dodanie katalogów z maskami plików do JPFileSearchera
    for i := 0 to AppParams.Dirs.Count - 1 do
    begin
      s := Trim(AppParams.Dirs[i]);
      if s = '' then Continue;
      fs.AddInput(s, ArrMasks, 0);
    end;


    // JPFileSearchCaseSensitive decyduje o rozróżnianiu wielkości znaków przy wyszukiwaniu
    JPLM.FileSearch.JPFileSearchCaseSensitive := AppParams.CaseSensitive;


    // Jeśli ustawiono limit na pierwsze(ych) X pliki(ów), przekazuję limit do FileSearchera, który
    // automatycznie przerwie wyszukiwanie po znalezieniu X plików. Nie ma tutaj potrzeby pobierania pełnej listy plików,
    // w przeciwieństwie do limitu plików "od końca" (last X).
    if (AppParams.LimitMode = PLOC.Types.lmFirst) and (AppParams.FileCountLimit > 0) then fs.FileCountLimit := AppParams.FileCountLimit;


    // Tylko nazwy plików. Dodatkowe informacje będą pobierane później w GetFilesExtInfo.
    fs.FileInfoMode := fimOnlyFileNames;

    ////////////////////////////
    fs.Search;
    ////////////////////////////


    // Zapisanie wszystkich znalezionych plików do slFiles
    fs.GetFileList(slFiles);
    fs.ClearAll; // fs już nie jest potrzebny

    if AppParams.SortByField = sbfFileName then
      case AppParams.SortDirection of
        TSortDirection.sdAscending: slFiles.Sort(AppParams.CaseSensitive, TSLSortDirection.sdAscending);
        TSortDirection.sdDescending: slFiles.Sort(AppParams.CaseSensitive, TSLSortDirection.sdDescending);
      end;

    // Usuwanie duplikatów wywołać po ewentualnym sortowaniu!
    // Usuwanie duplikatów z posortowanej listy jest dużo szybsze.
    slFiles.RemoveDuplicates(OS_ID <> OS_ID_WINDOWS);

    // Pobranie dodatkowych informacji o plikach i zapisanie wyniku w ArrFileInfo
    GetFilesExtInfo(slFiles, ArrFileInfo, False);

  finally
    fs.Free;
    slFiles.Free;
  end;
  {$endregion Wyszukiwanie plików}


  xMaxFileSize := GetMaxFileSize(ArrFileInfo);
  xPadSizeMax := Length(IntToStrEx(xMaxFileSize));

  // sbfFileName - ewentualne sortowanie wg nazwy plików odbywa się wcześniej (slFiles.Sort).
  if (AppParams.SortByField <> sbfNone) and (AppParams.SortByField <> sbfFileName) then
    SortFileInfoArray(ArrFileInfo, AppParams.SortByField, AppParams.SortDirection = TSortDirection.sdAscending);


  // Gdy ustalono limit na X ostanich plików, szukamy numeru pierwszego pliku,
  // od którego będziemy wyświetlać pliki w konsoli/terminalu.
  // Jeśli limit ten nie jest ustawiony, xFirstFileNo przyjmuje wartość 0 i wszystkie
  // pliki zostaną wyświetlone.
  if AppParams.LimitMode = lmLast then xFirstFileNo := Length(ArrFileInfo) - AppParams.FileCountLimit + 1
  else xFirstFileNo := 0;

  xfn := 0; //<-- tu będzie pamiętany numer bieżącego pliku w pętli "for i".


  {$region '       Wyświetlanie wyników           '}

  // Nie znaleziono plików lub numer pierwszego pliku jest większy od liczby znalezionych plików
  if (Length(ArrFileInfo) = 0) or (xFirstFileNo > Length(ArrFileInfo)) then
  begin
    ExitCode := EXIT_NO_FILES;
    Writeln('No files found.');
  end

  else

  begin

    FillChar(dp, SizeOf(dp), 0);
    dp.Separator := AppParams.ListSeparator;
    dp.Separator_DateTime := AppParams.DateTimeSeparator;
    dp.Numbering := AppParams.Numbering;
    dp.SizeBytes := AppParams.SizeBytes;
    dp.SizeHuman := AppParams.SizeHuman;
    {$IFDEF MSWINDOWS}
    dp.FileAttributes := AppParams.FileAttrs;
    dp.Date_Creation := AppParams.DateCreation;
    {$ENDIF}
    dp.Date_LastWrite := AppParams.DateLastWrite;
    dp.Date_LastAccess := AppParams.DateLastAccess;
    dp.Hash_Crc := AppParams.CalcCrc32;
    dp.Hash_MD5 := AppParams.CalcHashMD5;
    dp.Hash_SHA1 := AppParams.CalcHashSha1;
    dp.Hash_SHA2 := AppParams.CalcHashSha2_256;

    ccError.Text := Self.ErrorTextColor;
    ccError.Background := Self.ErrorBackgroundColor;

    ccp := TConColorParser.Create;
    try

      ccp.CaseSensitive := AppParams.UserHighlightCaseSensitive;
      ccp.AddHighlightedText(AppParams.UserHighlightStr1, COLOR_HIGHLIGHT_FG1, COLOR_HIGHLIGHT_BG1);
      ccp.AddHighlightedText(AppParams.UserHighlightStr2, COLOR_HIGHLIGHT_FG2, COLOR_HIGHLIGHT_BG2);

      for i := 0 to High(ArrFileInfo) do
      begin

        Inc(xfn);
        if xFirstFileNo > xfn then Continue;

        Inc(xFileNo);
        xTotalSize += ArrFileInfo[i].Size;

        FileName := ArrFileInfo[i].FileName;
        Line := GetOutputLine(ArrFileInfo[i], xFileNo, xPadSizeMax, dp, bError, Logger);

        ccp.ClearResult;
        ccp.Text := Line;
        if bError then ccp.SetDefaultColors(ccError)
        else ccp.SetDefaultColors(CON_COLOR_NONE, CON_COLOR_NONE);

        {$IFDEF MSWINDOWS}

        if not bError then
          if AppParams.HighlightExes and IsExeFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_EXE)
          else if AppParams.HighlightDlls and IsDllFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_DLL)
          else if AppParams.HighlightBats and IsBatFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_BAT)
          else if AppParams.HighlightCmds and IsCmdFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_CMD)
          else if AppParams.HighlightBpls and IsBplFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_BPL);

        {$ELSE} // Linux

        if not bError then
          if AppParams.HighlightBashScripts and IsShellScriptFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_SH)
          else if AppParams.HighlightBashScripts and IsSoLibFile(FileName) then ccp.SetDefaultColors(AppParams.ConColor_SO);

        {$ENDIF}

        ccp.Parse;
        ccp.WriteText;
        Writeln;

        {$IFDEF MSWINDOWS}
        if AppParams.ReadVersionInfo then
        begin
          svi := GetVersionInfoStr(FileName);
          if svi <> '' then
          begin
            svi := ReplaceAll(svi, #174, '®');
            svi := ReplaceAll(svi, #169, '©');
            ccp.ClearResult;
            ccp.SetDefaultColors(CON_COLOR_NONE, CON_COLOR_NONE);
            ccp.Text := svi;
            ccp.Parse;
            ccp.WriteText;
            Writeln;
          end;
        end;
        {$ENDIF}


      end; // for i

    finally
      ccp.Free;
    end;

  end;
    {$endregion Wyświetlanie wyników}


  if AppParams.ShowSummary then
  begin
    Writeln('Files: ' + IntToStrEx(xFileNo));
    Writeln('Total size: ', IntToStrEx(xTotalSize), ' bytes  [', GetFileSizeString(xTotalSize), ']');
    TTimeLogger.EndLog;
    Writeln('Elapsed time: ', TTimeLogger.ElapsedTimeStr);
  end;


  if (AppParams.DisplayErrors) and (Logger.ErrorCount > 0) then
  begin
    ConWriteColoredTextLine('Errors: ' + IntToStrEx(Logger.ErrorCount), ccError);
    xFileNo := 0;
    for i := 0 to Logger.Count - 1 do
    begin
      li := Logger[i];
      if not li.IsError then Continue;
      Inc(xFileNo);
      ConWriteTaggedTextLine(' ' + Pad(IntToStrEx(xFileNo), 3, ' ') + '. [' + li.Context + '] ' + li.Text);
    end;
  end;

end;

{$endregion SearchFiles}


{$region '                            ListDirs                                  '}
procedure TApp.ListDirs;
var
  sPath, fName, sNum, Line: string;
  {$IFDEF MSWINDOWS}wd: string;{$ENDIF}
  sl: TJPStrList;
  i: integer;
  ccp: TConColorParser;
begin
  sPath := SysUtils.GetEnvironmentVariable('PATH');
  sl := TJPStrList.Create;
  ccp := TConColorParser.Create;
  try

    StrToList(sPath, sl, PATH_SEPARATOR);

    if AppParams.SortByField <> sbfNone then
      case AppParams.SortDirection of
        TSortDirection.sdAscending: sl.Sort(OS_ID <> OS_ID_WINDOWS, TSLSortDirection.sdAscending);
        TSortDirection.sdDescending: sl.Sort(OS_ID <> OS_ID_WINDOWS, TSLSortDirection.sdDescending);
      end;

    {$IFDEF MSWINDOWS} wd := UpperCase(WinDir); {$ENDIF}

    ccp.Clear;
    ccp.CaseSensitive := AppParams.UserHighlightCaseSensitive;
    ccp.AddHighlightedText(AppParams.UserHighlightStr1, COLOR_HIGHLIGHT_FG1, COLOR_HIGHLIGHT_BG1);
    ccp.AddHighlightedText(AppParams.UserHighlightStr2, COLOR_HIGHLIGHT_FG2, COLOR_HIGHLIGHT_BG2);

    for i := 0 to sl.Count - 1 do
    begin

      fName := sl[i];
      if AppParams.Numbering then sNum := Pad(IntToStrEx(i + 1), 2, ' ') + '.  ' else sNum := '';
      Line := sNum + fName;

      ccp.Text := Line;
      ccp.ClearResult;
      ccp.SetDefaultColors(CON_COLOR_NONE, CON_COLOR_NONE);

      {$IFDEF MSWINDOWS}
      if AnsiContainsText(Line, wd) then ccp.DefaultTextColor := CON_COLOR_YELLOW_LIGHT
      else if AnsiContainsText(Line, '\Program Files (x86)') then ccp.DefaultTextColor := CON_COLOR_CYAN_LIGHT
      else if AnsiContainsText(Line, '\Program Files') then ccp.DefaultTextColor := CON_COLOR_GREEN_LIGHT
      else if AnsiContainsText(Line, '\ConEmu') then
      begin
        ccp.DefaultTextColor := CON_COLOR_WHITE;
        ccp.DefaultBackgroundColor := CON_COLOR_GREEN_DARK;
      end;
      {$ELSE} // Linux
      if AnsiStartsStr('/usr/', fName) then ccp.DefaultTextColor := CON_COLOR_YELLOW_LIGHT_FG
      else if AnsiStartsStr('/home/', fName) then ccp.DefaultTextColor := CON_COLOR_CYAN_LIGHT_FG;
      //else if AnsiStartsStr('/mnt/', fName) then ccp.DefaultTextColor := CON_COLOR_GREEN_LIGHT_FG;
      {$ENDIF}

      ccp.Parse;
      ccp.WriteText;
      Writeln;

    end;

  finally
    ccp.Free;
    sl.Free;
  end;
end;
{$endregion ListDirs}

procedure TApp.DisplayHelpAndTerminate(const ExCode: integer);
begin
  DisplayBanner;
  DisplayShortUsage;
  DisplayUsage;
  DisplayExamples;
  ExitCode := ExCode;
  Terminate;
end;

procedure TApp.DisplayShortUsageAndTerminate(const Msg: string; const ExCode: integer);
begin
  if Msg <> '' then
  begin
    if (ExCode = CON_EXIT_CODE_SYNTAX_ERROR) or (ExCode = CON_EXIT_CODE_ERROR) then DisplayError(Msg)
    else Writeln(Msg);
  end;
  DisplayShortUsage;
  DisplayTryHelp;
  ExitCode := ExCode;
  Terminate;
end;

procedure TApp.DisplayBannerAndTerminate(const ExCode: integer);
begin
  DisplayBanner;
  ExitCode := ExCode;
  Terminate;
end;

procedure TApp.DisplayMessageAndTerminate(const Msg: string; const ExCode: integer);
begin
  Writeln(Msg);
  ExitCode := ExCode;
  Terminate;
end;


end.

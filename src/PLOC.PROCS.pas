unit PLOC.PROCS;

{
  Jacek Pazera
  http://www.pazera-software.com
  Last mod: 2018.03.19
 }

{$mode objfpc}{$H+}

interface

uses
  // FPC units
  SysUtils, DateUtils,
  MFPC.Classes.SHARED,

  // App units
  PLOC.Types,

  // JPLib / JPLib (M) units
  JPL.Console,
  JPL.StrList, JPL.Strings, JPL.CmdLineParser, JPL.DateTime, JPLM.Files,
  JPLM.FileSearch, JPL.SimpleLogger,

  // Hash
  JPLM.Hash.Common,
  JPLM.Hash.CRC32, JPLM.Hash.WE_MD5, JPLM.Hash.WE_SHA1, JPLM.Hash.WE_SHA2_256

  // Windows only
  {$IFDEF MSWINDOWS}, Windows, JPL.Win.VersionInfo {$ENDIF}

  ;


function GetOutputLine(const FileInfo: TFileExtInfo; const FileNo: integer; PadSizeMax: Integer; const dp: TDisplayParams; out bError: Boolean;
  Logger: TJPSimpleLogger = nil): string;

{$IFDEF MSWINDOWS}
function GetVersionInfoStr(const FileName: string): string;
function WinDir: string;
{$ENDIF}

function IsExeFile(const FileName: string): Boolean;
function IsDllFile(const FileName: string): Boolean;
function IsBatFile(const FileName: string): Boolean;
function IsCmdFile(const FileName: string): Boolean;
function IsBplFile(const FileName: string): Boolean;
function IsShellScriptFile(const FileName: string): Boolean;
function IsSoLibFile(const FileName: string): Boolean;

function TryGetLimitValue(s: string; out LM: TLimitMode; out xFiles: integer; out sErr: string): Boolean;
function TryGetSortDirectionValue(s: string; out SortMode: TSortDirection): Boolean;
function TryGetSortByFieldValue(s: string; out sbf: TSortByField): Boolean;

procedure StrToList(LineToParse: string; var List: TJPStrList; Separator: string = ',');

procedure GetFilesExtInfo(sl: TJPStrList; var Arr: TFileInfoArray; bOnlyNameAndSize: Boolean);
function GetMaxFileSize(Arr: TFileInfoArray): Int64;

procedure WriteColoredTextLine(const s: string; const ccNormal, ccError: TConsoleColors; bError: Boolean);

procedure SortFileInfoArray(var Arr: TFileInfoArray; sbf: TSortByField; const bAscending: Boolean);




implementation



procedure WriteColoredTextLine(const s: string; const ccNormal, ccError: TConsoleColors; bError: Boolean);
begin
  if bError then TConsole.WriteColoredTextLine(s, ccError) // ConWriteColoredTextLine(s, ccError)
  else
    if (ccNormal.Text = TConsole.clNone) and (ccNormal.Background = TConsole.clNone) then Writeln(s)
    else TConsole.WriteColoredTextLine(s, ccNormal); // ConWriteColoredTextLine(s, ccNormal);
end;

{$IFDEF MSWINDOWS}
function WinDir: string;
var
  Buffer: array[0..MAX_PATH - 1] of Char;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  GetWindowsDirectory(Buffer, SizeOf(Buffer));
  Result := Buffer;
end;
{$ENDIF}

procedure StrToList(LineToParse: string; var List: TJPStrList; Separator: string = ',');
var
  xp: integer;
  s: string;
begin

  xp := Pos(Separator, LineToParse);
  while xp > 0 do
  begin
    s := Trim(Copy(LineToParse, 1, xp - 1));
    List.Add(s);
    Delete(LineToParse, 1, xp + Length(Separator) - 1);
    LineToParse := Trim(LineToParse);
    xp := Pos(Separator, LineToParse);
  end;

  if LineToParse <> '' then
  begin
    LineToParse := Trim(LineToParse);
    if LineToParse <> '' then List.Add(LineToParse);
  end;

end;


{$region '                            Sorting                          '}

procedure _ExchangeItems(var Arr: TFileInfoArray; const Index1, Index2: integer);
var
  Temp: TFileExtInfo;
begin
  Temp := Arr[Index1];
  Arr[Index1] := Arr[Index2];
  Arr[Index2] := Temp;
end;

function _CompareFunc(const fei1, fei2: TFileExtInfo; const sbf: TSortByField; const bAscending: Boolean): integer;
begin
  case sbf of

    sbfSize:
      begin
        if fei1.Size < fei2.Size then Result := -1
        else if fei1.Size = fei2.Size then Result := 0
        else Result := 1;
      end;

    sbfDateCreation: Result := CompareDateTime(fei1.Dates.Creation, fei2.Dates.Creation);
    sbfDateLastWrite: Result := CompareDateTime(fei1.Dates.LastWrite, fei2.Dates.LastWrite);
    sbfDateLastAccess: Result := CompareDateTime(fei1.Dates.LastAccess, fei2.Dates.LastAccess);

  else
    Result := 0;
  end;

  if not bAscending then Result := -Result;
end;


procedure _SortFEIArray(var Arr: TFileInfoArray; LeftIndex, RightIndex: Integer; CompareProc: TSortFIACompareFunc; const sbf: TSortByField; const bAscending: Boolean);
var
  I, J, PivotIndex: Integer;
begin
  repeat

    I := LeftIndex;
    J := RightIndex;
    PivotIndex := (LeftIndex + RightIndex) shr 1;

    repeat

      while _CompareFunc(Arr[I], Arr[PivotIndex], sbf, bAscending) < 0 do Inc(I);
      while _CompareFunc(Arr[J], Arr[PivotIndex], sbf, bAscending) > 0 do Dec(J);

      if I <= J then
      begin
        if I <> J then _ExchangeItems(Arr, I, J);

        if PivotIndex = I then PivotIndex := J
        else if PivotIndex = J then PivotIndex := I;
        Inc(I);
        Dec(J);
      end;

    until I > J;

    if LeftIndex < J then _SortFEIArray(Arr, LeftIndex, J, CompareProc, sbf, bAscending);
    LeftIndex := I;

  until I >= RightIndex;
end;

procedure SortFileInfoArray(var Arr: TFileInfoArray; sbf: TSortByField; const bAscending: Boolean);
begin
  if Length(Arr) < 2 then Exit;
  _SortFEIArray(Arr, 0, High(Arr), @_CompareFunc, sbf, bAscending);
end;


function TryGetSortDirectionValue(s: string; out SortMode: TSortDirection): Boolean;
begin
  Result := True;
  s := TrimUp(s);

  if {(s = '') or} (s = 'A') or (s = 'ASCENDING') then SortMode := TSortDirection.sdAscending
  else if (s = 'D') or (s = 'DESCENDING') then SortMode := TSortDirection.sdDescending
  else Result := False;
end;

function TryGetSortByFieldValue(s: string; out sbf: TSortByField): Boolean;
begin
  Result := True;
  s := TrimUp(s);
  case s of
    'NAME': sbf := sbfFileName;
    'SIZE': sbf := sbfSize;
    {$IFDEF MSWINDOWS}'DC': sbf := sbfDateCreation;{$ENDIF}
    'DW': sbf := sbfDateLastWrite;
    'DA': sbf := sbfDateLastAccess;
    'NONE': sbf := sbfNone;
  else
    Result := False;
  end;
end;

{$endregion Sorting}


procedure GetFilesExtInfo(sl: TJPStrList; var Arr: TFileInfoArray; bOnlyNameAndSize: Boolean);
var
  i: integer;
  fName: string;
  fei: TFileExtInfo;
  fir: TFileInfoRec;
  bOK: Boolean;
begin
  for i := 0 to sl.Count - 1 do
  begin

    fName := sl[i];
    fei.FileName := fName;

    bOK := GetFileInfoRec(fName, fir, bOnlyNameAndSize);
    if not bOK then fei.Size := FileSizeInt(fName)
    else fei.Size := fir.Size;

    if not bOnlyNameAndSize then
    begin

      {$IFDEF MSWINDOWS}
      fei.Dates.Creation := fir.CreationTime;
      if fir.AttrsOK then fei.Attrs := fir.FileAttrs.Attrs
      else fei.Attrs := -1;
      {$ENDIF}
      fei.Dates.LastWrite := fir.LastWriteTime;
      fei.Dates.LastAccess := fir.LastAccessTime;
    end;

    SetLength(Arr, Length(Arr) + 1);
    Arr[High(Arr)] := fei;

  end;
end;

function GetMaxFileSize(Arr: TFileInfoArray): Int64;
var
  MaxSize: Int64;
  i: integer;
begin
  MaxSize := 0;
  for i := 0 to High(Arr) do
    if Arr[i].Size > MaxSize then MaxSize := Arr[i].Size;
  Result := MaxSize;
end;



{$region '                    GetOutputLine                     '}
function GetOutputLine(const FileInfo: TFileExtInfo; const FileNo: integer; PadSizeMax: Integer; const dp: TDisplayParams; out bError: Boolean;
  Logger: TJPSimpleLogger): string;
var
  dwCrc32: DWORD;
  FileName, sErr, sNum, sSizeBytes, sSizeHuman, sDateCreation, sDateWrite, sDateAccess, sAttrs, Sep, SepDT, sCrc, sMd5, sSha1, sSha2: string;
  hrr: THashResultRec;
  xPadSizeLong: integer;
  clErr1, clErr2: string;

  function _GetDateStr(const dt: TDateTime): string;
  begin
    if dt <> 0 then Result := GetDateTimeStr(dt, '$Y-$M-$D' + SepDT + '$H:$MIN:$S') + Sep
    else Result := 'xxxx-xx-xx' + SepDT + 'xx:xx:xx' + Sep;
  end;

  procedure _LogE(const Text, Context: string);
  begin
    if Assigned(Logger) then Logger.LogError(Text, Context);
  end;

begin
  FileName := FileInfo.FileName;
  Sep := dp.Separator;
  SepDT := dp.Separator_DateTime;
  xPadSizeLong := 10;
  bError := False;
  clErr1 := 'magenta';
  clErr2 := 'yellow';

  //-------------------------------------------------------
  if dp.Numbering then sNum := Pad(IntToStrEx(FileNo), 3, ' ') + '.' + Sep else sNum := '';

  //-------------------------------------------------------
  if dp.Hash_Crc then
  begin
    dwCrc32 := CalcFileCRC32(FileName, nil, True);
    if dwCrc32 = 0 then
    begin
      sCrc := StringOfChar('-', HASH_LEN_CRC32) + Sep;
      bError := True;
      _LogE('Cannot calculate the <color=' + clErr1 + '>CRC32</color> cheksum of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'CRC32');
    end
    else sCrc := IntToHex(dwCrc32, 8) + Sep;
  end
  else sCrc := '';

  //-------------------------------------------------------
  sMd5 := '';
  if dp.Hash_MD5 then
  begin
    sErr := StringOfChar('-', HASH_LEN_MD5) + Sep;
    try
      if WeGetFileHash_Md5(FileName, hrr, nil) then sMd5 := hrr.StrValueUpper + Sep
      else sMd5 := sErr;
    except
      on E: EFopenError do sMd5 := sErr;
    end;
    if sMd5 = sErr then
    begin
      bError := True;
      _LogE('Cannot calculate the <color=' + clErr1 + '>MD5</color> hash of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'MD5');
    end;
  end;

  //-------------------------------------------------------
  sSha1 := '';
  if dp.Hash_SHA1 then
  begin
    sErr := StringOfChar('-', HASH_LEN_SHA1) + Sep;
    try
      if WeGetFileHash_Sha1(FileName, hrr, nil) then sSha1 := hrr.StrValueUpper + Sep
      else sSha1 := sErr;
    except
      on E: EFopenError do sSha1 := sErr;
    end;
    if sSha1 = sErr then
    begin
      bError := True;
      _LogE('Cannot calculate the <color=' + clErr1 + '>SHA-1</color> hash of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'SHA-1');
    end;
  end;

  //-------------------------------------------------------
  sSha2 := '';
  if dp.Hash_SHA2 then
  begin
    sErr := StringOfChar('-', HASH_LEN_SHA2_256) + Sep;
    try
      if WeGetFileHash_SHA2_256(FileName, hrr, nil) then sSha2 := hrr.StrValueUpper + Sep
      else sSha2 := sErr;
    except
      on E: EFopenError do sSha2 := sErr;
    end;
    if sSha2 = sErr then
    begin
      bError := True;
      _LogE('Cannot calculate the <color=' + clErr1 + '>SHA-2</color> hash of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'SHA-2');
    end;
  end;

  //-------------------------------------------------------
  sSizeBytes := '';
  if dp.SizeBytes then
    if FileInfo.Size >= 0 then sSizeBytes := Pad(IntToStrEx(FileInfo.Size), PadSizeMax, ' ') + Sep
    else
    begin
      sSizeBytes := Pad('-', PadSizeMax, ' ') + Sep;
      bError := True;
    end;

  //-------------------------------------------------------
  sSizeHuman := '';
  if dp.SizeHuman then
    if FileInfo.Size >= 0 then sSizeHuman := Pad(GetFileSizeString(FileInfo.Size, '  B'), xPadSizeLong, ' ') + Sep
    else
    begin
      sSizeHuman := Pad('-', xPadSizeLong, ' ') + Sep;
      bError := True;
    end;


  if ( (dp.SizeBytes) or (dp.SizeHuman) ) and (FileInfo.Size < 0) then
    _LogE('Cannot read <color=' + clErr1 + '>size</color> of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'FileSize');


  //-------------------------------------------------------
  sDateCreation := '';
  {$IFDEF MSWINDOWS}
  if dp.Date_Creation then
  begin
    sDateCreation := _GetDateStr(FileInfo.Dates.Creation);
    if FileInfo.Dates.Creation = 0 then
    begin
      bError := True;
      _LogE('Cannot read <color=' + clErr1 + '>creation date</color> of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'C-Date');
    end;
  end;
  {$ENDIF}

  sDateWrite := '';
  if dp.Date_LastWrite then
  begin
    sDateWrite := _GetDateStr(FileInfo.Dates.LastWrite);
    if FileInfo.Dates.LastWrite = 0 then
    begin
      bError := True;
      _LogE('Cannot read <color=' + clErr1 + '>last write date</color> of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'LW-Date');
    end;
  end;

  sDateAccess := '';
  if dp.Date_LastAccess then
  begin
    sDateAccess := _GetDateStr(FileInfo.Dates.LastAccess);
    if FileInfo.Dates.LastAccess = 0 then
    begin
      bError := True;
      _LogE('Cannot read <color=' + clErr1 + '>last access date</color> of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'LA-Date');
    end;
  end;

  //-------------------------------------------------------
  sAttrs := '';
  {$IFDEF MSWINDOWS}
  if dp.FileAttributes then
    if FileInfo.Attrs >= 0 then sAttrs := FileAttributesToStr(FileInfo.Attrs, '-', True) + Sep
    else
    begin
      sAttrs := StringOfChar('-', 7) + Sep;
      bError := True;
      _LogE('Cannot read <color=' + clErr1 + '>attributes</color> of the file: <color=' + clErr2 + '>"' + FileName + '"</color>', 'Attrs');
    end;
  {$ENDIF}



  Result := sNum + sSizeBytes + sSizeHuman + sDateCreation + sDateWrite + sDateAccess + sAttrs + sCrc + sMd5 + sSha1 + sSha2 + FileName;

end;
{$endregion GetOutputLine}



{$region '                  TryGetLimitValue                '}
// No RegEx, only Pos, Copy, etc.
function TryGetLimitValue(s: string; out LM: TLimitMode; out xFiles: integer; out sErr: string): Boolean;
var
  xd: integer;
  sName, sVal: string;
begin
  Result := False;
  sErr := '';

  s := TrimUp(s);


  // First X files (1)
  if TryStrToInt(s, xFiles) then
  begin
    if xFiles < 0 then
    begin
      sErr := 'The number of files must be non-negative integer.';
      Exit;
    end
    else
    begin
      Result := True;
      LM := lmFirst;
      Exit;
    end;
  end;


  // no limit
  if (s = 'N') or (s = 'NONE') then
  begin
    Result := True;
    xFiles := 0;
    LM := lmNoLimit;
    Exit;
  end;


  // First X files (2)
  if (Copy(s, 1, 5) = 'FIRST') or (Copy(s, 1, 1) = 'F') then
  begin

    xd := GetFirstDigitIndex(s);
    if xd = 0 then Exit;
    sName := Trim(Copy(s, 1, xd - 1));
    sVal := Trim(Copy(s, xd, Length(s)));
    if (sName <> 'F') and (sName <> 'FIRST') then Exit;

    if TryStrToInt(sVal, xFiles) then
    begin
      if xFiles <= 0 then
      begin
        sErr := 'The number of files must be non-negative integer.';
        Exit;
      end
      else
      begin
        Result := True;
        LM := lmFirst;
        Exit;
      end;
    end
    else
    begin
      sErr := 'Invalid or too large number: ' + sVal;
      Exit;
    end;

  end;


  // Last X files (2)
  if (Copy(s, 1, 5) = 'LAST') or (Copy(s, 1, 1) = 'L') then
  begin

    xd := GetFirstDigitIndex(s);
    if xd = 0 then Exit;
    sName := Trim(Copy(s, 1, xd - 1));
    sVal := Trim(Copy(s, xd, Length(s)));
    if (sName <> 'L') and (sName <> 'LAST') then Exit;

    if TryStrToInt(sVal, xFiles) then
    begin
      if xFiles <= 0 then
      begin
        sErr := 'The number of files must be non-negative integer.';
        Exit;
      end
      else
      begin
        Result := True;
        LM := lmLast;
        Exit;
      end;
    end
    else
    begin
      sErr := 'Invalid or too large number: ' + sVal;
      Exit;
    end;

  end;

end;

{$endregion TryGetLimitValue}


{$IFDEF MSWINDOWS}
function GetVersionInfoStr(const FileName: string): string;
const
  ExeExts: array [0..13] of string = ('EXE', 'DLL', 'BPL', 'OCX', 'TLB', 'SYS', 'CPL', 'SCR', 'RS', 'RLL', 'MUI', 'DRV', 'AX', 'ACM');
var
  i, xInd: integer;
  Ext: string;
  vi: TJPVersionInfo;
  sii: TVIStringInfoItem;
begin
  Result := '';

  Ext := UpperCase(GetFileExt(FileName, True));
  for i := 0 to High(ExeExts) do

    if Ext = ExeExts[i] then
    begin

      vi := TJPVersionInfo.Create(FileName);
      try
        if not vi.ValidVersionInfo then Exit;
        if vi.StringItemsCount = 0 then Exit;
        if vi.EnglishStringItemIndex >= 0 then xInd := vi.EnglishStringItemIndex else xInd := 0;
        sii := vi.StringItems[xInd];
        Result := VIStringInfoItemToStr(sii, False, False, '       ');
      finally
        vi.Free;
      end;

      Break;
    end;

end;
{$ENDIF}

function IsExeFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'EXE';
end;

function IsDllFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'DLL';
end;

function IsBatFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'BAT';
end;

function IsCmdFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'CMD';
end;

function IsBplFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'BPL';
end;

function IsShellScriptFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'SH';
end;

function IsSoLibFile(const FileName: string): Boolean;
begin
  Result := UpperCase(GetFileExt(FileName, True)) = 'SO';
end;








end.


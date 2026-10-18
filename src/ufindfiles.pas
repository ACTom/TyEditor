unit ufindfiles;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs;

type
  TFindFileOptions = record
    Directory: string;
    Mask: string;
    FindText: string;
    ReplaceText: string;
    CaseSensitive: Boolean;
    WholeWord: Boolean;
    Regex: Boolean;
    IncludeSubdirs: Boolean;
    DoReplace: Boolean;
    ExcludeDirs: string; // semicolon-separated directory names/fragments
  end;

  TFindFileResultEvent = procedure(const AFileName: string;
    ALine, ACol: Integer; const AText: string) of object;

  TFindFileJob = class(TThread)
  private
    FOptions: TFindFileOptions;
    FLock: TCriticalSection;
    FHits: TList;
    FCount: Integer;
    FFileCount: Integer;
    FScanned: Integer;
    FDone: Boolean;
    FCancelled: Boolean;
    FError: string;
    procedure AddHit(const AFileName: string; ALine, ACol: Integer;
      const AText: string);
    procedure Finish(const AError: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const AOptions: TFindFileOptions); reintroduce;
    destructor Destroy; override;
    procedure Cancel;
    function TakeHit(out AFileName: string; out ALine, ACol: Integer;
      out AText: string): Boolean;
    function Snapshot(out ACount, AFiles, AScanned: Integer;
      out ADone, ACancelled: Boolean; out AError: string): Boolean;
  end;


implementation

uses
  Forms, Controls, FileUtil, LazUTF8,
  ATStrings, ATStringProc, ATSynEdit_RegExpr;

function RegExEscape(const S: string): string;
const
  Meta = '.[]{}()*+-?^$|\';
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    if Pos(S[i], Meta) > 0 then
      Result := Result + '\';
    Result := Result + S[i];
  end;
end;

function MakePattern(const AOptions: TFindFileOptions): string;
begin
  if AOptions.Regex then
    Result := AOptions.FindText
  else
    Result := RegExEscape(AOptions.FindText);
  if AOptions.WholeWord then
    Result := '\b(?:' + Result + ')\b';
end;

function IsProbablyBinary(const AFileName: string): Boolean;
var
  F: TFileStream;
  Buf: array[0..4095] of Byte;
  N, i: Integer;
begin
  Result := False;
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  except
    Exit(True);
  end;
  try
    if F.Size = 0 then Exit;
    N := F.Read(Buf, SizeOf(Buf));
    // UTF-16/32 BOMs are not binary, even though they contain NUL bytes.
    if (N >= 2) and (Buf[0] = $FF) and (Buf[1] = $FE) then Exit;
    if (N >= 2) and (Buf[0] = $FE) and (Buf[1] = $FF) then Exit;
    for i := 0 to N - 1 do
      if Buf[i] = 0 then
        Exit(True);
  finally
    F.Free;
  end;
end;

function IsExcludedPath(const AFileName, AExclude: string): Boolean;
var
  Parts: TStringList;
  i: Integer;
  P: string;
begin
  Result := False;
  if Trim(AExclude) = '' then Exit;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ';';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := AExclude;
    P := LowerCase(AFileName);
    for i := 0 to Parts.Count - 1 do
    begin
      if Trim(Parts[i]) = '' then Continue;
      if Pos(LowerCase(Trim(Parts[i])), P) > 0 then Exit(True);
    end;
  finally
    Parts.Free;
  end;
end;

type
  TFindFileHit = class
  public
    FileName: string;
    Line: Integer;
    Col: Integer;
    Text: string;
  end;

constructor TFindFileJob.Create(const AOptions: TFindFileOptions);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOptions := AOptions;
  FLock := TCriticalSection.Create;
  FHits := TList.Create;
  FCount := 0;
  FFileCount := 0;
  FScanned := 0;
  FDone := False;
  FCancelled := False;
  FError := '';
  Start;
end;

destructor TFindFileJob.Destroy;
var
  i: Integer;
begin
  Cancel;
  WaitFor;
  for i := 0 to FHits.Count - 1 do
    TFindFileHit(FHits[i]).Free;
  FHits.Free;
  FLock.Free;
  inherited;
end;

procedure TFindFileJob.Cancel;
begin
  FLock.Enter;
  try
    FCancelled := True;
  finally
    FLock.Leave;
  end;
end;

procedure TFindFileJob.AddHit(const AFileName: string; ALine, ACol: Integer;
  const AText: string);
var
  H: TFindFileHit;
begin
  H := TFindFileHit.Create;
  H.FileName := AFileName;
  H.Line := ALine;
  H.Col := ACol;
  H.Text := AText;
  FLock.Enter;
  try
    FHits.Add(H);
    Inc(FCount);
  finally
    FLock.Leave;
  end;
end;

procedure TFindFileJob.Finish(const AError: string);
begin
  FLock.Enter;
  try
    FError := AError;
    FDone := True;
  finally
    FLock.Leave;
  end;
end;

function TFindFileJob.TakeHit(out AFileName: string; out ALine, ACol: Integer;
  out AText: string): Boolean;
var
  H: TFindFileHit;
begin
  Result := False;
  AFileName := '';
  ALine := 0;
  ACol := 0;
  AText := '';
  FLock.Enter;
  try
    if FHits.Count = 0 then Exit;
    H := TFindFileHit(FHits[0]);
    AFileName := H.FileName;
    ALine := H.Line;
    ACol := H.Col;
    AText := H.Text;
    FHits.Delete(0);
    H.Free;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TFindFileJob.Snapshot(out ACount, AFiles,
  AScanned: Integer; out ADone, ACancelled: Boolean; out AError: string): Boolean;
begin
  FLock.Enter;
  try
    ACount := FCount;
    AFiles := FFileCount;
    AScanned := FScanned;
    ADone := FDone;
    ACancelled := FCancelled;
    AError := FError;
    Result := FDone;
  finally
    FLock.Leave;
  end;
end;

procedure TFindFileJob.Execute;
var
  Files, Masks: TStringList;
  i, j, k, LineCount: Integer;
  St: TATStrings;
  Re: TRegExpr;
  Pattern, Line, Text, NewLine: string;
  MatchCount: Integer;
  Changed: Boolean;
  Cancelled: Boolean;
begin
  try
    if (FOptions.Directory = '') or (not DirectoryExists(FOptions.Directory)) then
    begin
      Finish('Directory does not exist: ' + FOptions.Directory);
      Exit;
    end;
    if FOptions.FindText = '' then
    begin
      Finish('Search text is empty.');
      Exit;
    end;
    try
      Pattern := MakePattern(FOptions);
      Re := TRegExpr.Create;
    except
      on E: Exception do
      begin
        Finish('Invalid regular expression: ' + E.Message);
        Exit;
      end;
    end;
    try
      try
        Re.Expression := Pattern;
        Re.ModifierI := not FOptions.CaseSensitive;
      except
        on E: Exception do
        begin
          Finish('Invalid regular expression: ' + E.Message);
          Exit;
        end;
      end;

      Files := TStringList.Create;
      Masks := TStringList.Create;
      try
        Masks.Delimiter := ';';
        Masks.StrictDelimiter := True;
        Masks.DelimitedText := FOptions.Mask;
        for k := 0 to Masks.Count - 1 do
          if Trim(Masks[k]) <> '' then
            FindAllFiles(Files, FOptions.Directory, Trim(Masks[k]), FOptions.IncludeSubdirs);
        Files.Sort;

        for i := 0 to Files.Count - 1 do
        begin
          FLock.Enter;
          try
            Cancelled := FCancelled;
          finally
            FLock.Leave;
          end;
          if Cancelled then Break;

          FLock.Enter;
          try
            Inc(FScanned);
          finally
            FLock.Leave;
          end;
          if IsExcludedPath(Files[i], FOptions.ExcludeDirs) then Continue;
          if IsProbablyBinary(Files[i]) then Continue;
          St := TATStrings.Create(0);
          try
            try
              St.EncodingDetect := True;
              St.LoadFromFile(Files[i], []);
            except
              Continue;
            end;
            Changed := False;
            LineCount := St.Count;
            for j := 0 to LineCount - 1 do
            begin
              FLock.Enter;
              try
                Cancelled := FCancelled;
              finally
                FLock.Leave;
              end;
              if Cancelled then Break;

              Line := St.Lines[j];
              MatchCount := 0;
              try
                if Re.Exec(Line) then
                begin
                  repeat
                    Inc(MatchCount);
                    if Length(Line) > 160 then
                      Text := Copy(Line, 1, 160) + '...'
                    else
                      Text := Line;
                    AddHit(Files[i], j + 1, Re.MatchPos[0], Text);
                  until not Re.ExecNext;

                  if FOptions.DoReplace then
                  begin
                    if FOptions.Regex then
                      NewLine := Re.Replace(Line, FOptions.ReplaceText, True)
                    else
                      NewLine := Re.Replace(Line, FOptions.ReplaceText, False);
                    if NewLine <> Line then
                    begin
                      St.Lines[j] := NewLine;
                      Changed := True;
                    end;
                  end;
                end;
              except
                // one bad line must not abort a whole directory search
              end;
            end;
            if Changed then
              try
                St.SaveToFile(Files[i]);
              except
                on E: Exception do
                begin
                  FLock.Enter;
                  try
                    FError := FError + Files[i] + ': ' + E.Message + LineEnding;
                  finally
                    FLock.Leave;
                  end;
                end;
              end;
          finally
            St.Free;
          end;
          FLock.Enter;
          try
            Inc(FFileCount);
          finally
            FLock.Leave;
          end;
        end;
      finally
        Masks.Free;
        Files.Free;
      end;
    finally
      Re.Free;
    end;
    FLock.Enter;
    try
      Cancelled := FCancelled;
    finally
      FLock.Leave;
    end;
    Finish(FError);
  except
    on E: Exception do
      Finish(E.Message);
  end;
end;

end.

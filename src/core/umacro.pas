unit umacro;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser,
  ATSynEdit, ATSynEdit_Commands;

type
  TMacroItem = record
    Command: Integer;
    Invoke: TATCommandInvoke;
    Text: string;
  end;

  TMacro = class
  private
    FItems: array of TMacroItem;
    FRecording: Boolean;
    FPlaying: Boolean;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TMacroItem;
  public
    procedure Clear;
    procedure Add(ACommand: Integer; AInvoke: TATCommandInvoke; const AText: string);
    procedure RecordCommand(ACommand: Integer; AInvoke: TATCommandInvoke; const AText: string);
    procedure Play(AEditor: TATSynEdit; ARepeatCount: Integer = 1);
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TMacroItem read GetItem; default;
    property Recording: Boolean read FRecording write FRecording;
    property Playing: Boolean read FPlaying;
  end;

implementation

function TMacro.GetCount: Integer;
begin
  Result := Length(FItems);
end;

function TMacro.GetItem(AIndex: Integer): TMacroItem;
begin
  Result := FItems[AIndex];
end;

procedure TMacro.Clear;
begin
  SetLength(FItems, 0);
end;

procedure TMacro.Add(ACommand: Integer; AInvoke: TATCommandInvoke; const AText: string);
var
  N: Integer;
begin
  N := Length(FItems);
  SetLength(FItems, N + 1);
  FItems[N].Command := ACommand;
  FItems[N].Invoke := AInvoke;
  FItems[N].Text := AText;
end;

procedure TMacro.RecordCommand(ACommand: Integer; AInvoke: TATCommandInvoke;
  const AText: string);
begin
  if FRecording and (not FPlaying) then
    Add(ACommand, AInvoke, AText);
end;

procedure TMacro.Play(AEditor: TATSynEdit; ARepeatCount: Integer);
var
  i, j: Integer;
begin
  if (AEditor = nil) or (Length(FItems) = 0) then Exit;
  if ARepeatCount < 1 then ARepeatCount := 1;
  FPlaying := True;
  try
    for j := 1 to ARepeatCount do
      for i := 0 to High(FItems) do
      begin
        if not AEditor.Enabled then Break;
        AEditor.DoCommand(FItems[i].Command, FItems[i].Invoke, FItems[i].Text);
      end;
  finally
    FPlaying := False;
  end;
end;

procedure TMacro.SaveToFile(const AFileName: string);
var
  Root: TJSONObject;
  Arr: TJSONArray;
  Obj: TJSONObject;
  i: Integer;
  S: TStringList;
begin
  Root := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    for i := 0 to High(FItems) do
    begin
      Obj := TJSONObject.Create;
      Obj.Add('command', FItems[i].Command);
      Obj.Add('invoke', Ord(FItems[i].Invoke));
      Obj.Add('text', FItems[i].Text);
      Arr.Add(Obj);
    end;
    Root.Add('version', 1);
    Root.Add('items', Arr);
    S := TStringList.Create;
    try
      S.Text := Root.FormatJSON;
      S.SaveToFile(AFileName);
    finally
      S.Free;
    end;
  finally
    Root.Free;
  end;
end;

procedure TMacro.LoadFromFile(const AFileName: string);
var
  S: TStringList;
  Data: TJSONData;
  Root: TJSONObject;
  Arr: TJSONArray;
  Obj: TJSONObject;
  i: Integer;
begin
  Clear;
  S := TStringList.Create;
  try
    S.LoadFromFile(AFileName);
    Data := GetJSON(S.Text);
    try
      if not (Data is TJSONObject) then Exit;
      Root := TJSONObject(Data);
      if not (Root.Find('items') is TJSONArray) then Exit;
      Arr := TJSONArray(Root.Find('items'));
      for i := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[i] is TJSONObject) then Continue;
        Obj := Arr.Items[i] as TJSONObject;
        Add(Obj.Get('command', 0), TATCommandInvoke(Obj.Get('invoke', Ord(TATCommandInvoke.AppInternal))),
          Obj.Get('text', ''));
      end;
    finally
      Data.Free;
    end;
  finally
    S.Free;
  end;
end;

end.

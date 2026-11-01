unit ubookmarklist;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.ListBox, tyControls.Button, tyControls.TyLabel,
  utranslation;

type
  TBookmarkEntry = class
  public
    FileName: string;
    Line: Integer;
    Text: string;
    Group: Integer;
  end;

  TBookmarkJumpEvent = procedure(AEntry: TBookmarkEntry) of object;
  TBookmarkDeleteEvent = procedure(AEntry: TBookmarkEntry) of object;

  TBookmarkListForm = class(TTyForm)
  private
    FList: TTyListBox;
    FOnJump: TBookmarkJumpEvent;
    FOnDelete: TBookmarkDeleteEvent;
    procedure BuildUI;
    procedure DoJump(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoClose(Sender: TObject);
    procedure DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
    function SelectedEntry: TBookmarkEntry;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Clear;
    procedure Add(AEntry: TBookmarkEntry);
    procedure RefreshView;
    procedure ShowList;
    property OnJump: TBookmarkJumpEvent read FOnJump write FOnJump;
    property OnDelete: TBookmarkDeleteEvent read FOnDelete write FOnDelete;
  end;

implementation

constructor TBookmarkListForm.Create(AOwner: TComponent);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  BorderIcons := [biSystemMenu];
  Position := poDesigned;
  SetBounds(300, 180, 620, 420);
  Caption := Tr('Bookmarks');
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  OnClose := @DoFormClose;
end;

procedure TBookmarkListForm.BuildUI;
var
  B: TTyButton;
begin
  FList := TTyListBox.Create(Self);
  FList.Parent := Self;
  FList.SetBounds(16, 48, 588, 300);
  FList.OnDblClick := @DoJump;

  B := TTyButton.Create(Self);
  B.Parent := Self; B.SetBounds(16, 364, 100, 32);
  B.Caption := Tr('Jump'); B.OnClick := @DoJump;
  B := TTyButton.Create(Self);
  B.Parent := Self; B.SetBounds(126, 364, 100, 32);
  B.Caption := Tr('Delete'); B.OnClick := @DoDelete;
  B := TTyButton.Create(Self);
  B.Parent := Self; B.SetBounds(504, 364, 100, 32);
  B.Caption := Tr('Close'); B.OnClick := @DoClose;
end;

procedure TBookmarkListForm.Clear;
var
  i: Integer;
begin
  for i := 0 to FList.Items.Count - 1 do
    if FList.Items.Objects[i] <> nil then FList.Items.Objects[i].Free;
  FList.Items.Clear;
end;

procedure TBookmarkListForm.Add(AEntry: TBookmarkEntry);
begin
  if AEntry = nil then Exit;
  FList.Items.AddObject(Format('[G%d] %s:%d: %s',
    [AEntry.Group, ExtractFileName(AEntry.FileName), AEntry.Line, AEntry.Text]), AEntry);
end;

procedure TBookmarkListForm.RefreshView;
begin
  if Visible then BringToFront;
end;

procedure TBookmarkListForm.ShowList;
begin
  if not Visible then Show;
  BringToFront;
end;

function TBookmarkListForm.SelectedEntry: TBookmarkEntry;
begin
  Result := nil;
  if (FList.ItemIndex >= 0) and (FList.ItemIndex < FList.Items.Count) then
    if FList.Items.Objects[FList.ItemIndex] is TBookmarkEntry then
      Result := TBookmarkEntry(FList.Items.Objects[FList.ItemIndex]);
end;

procedure TBookmarkListForm.DoJump(Sender: TObject);
var
  E: TBookmarkEntry;
begin
  E := SelectedEntry;
  if (E <> nil) and Assigned(FOnJump) then FOnJump(E);
end;

procedure TBookmarkListForm.DoDelete(Sender: TObject);
var
  E: TBookmarkEntry;
begin
  E := SelectedEntry;
  if (E <> nil) and Assigned(FOnDelete) then FOnDelete(E);
end;

procedure TBookmarkListForm.DoClose(Sender: TObject);
begin
  Hide;
end;

procedure TBookmarkListForm.DoFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  Hide;
  CloseAction := caNone;
end;

end.

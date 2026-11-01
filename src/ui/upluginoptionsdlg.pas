unit upluginoptionsdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.TyLabel, tyControls.Edit, tyControls.CheckBox,
  tyControls.Button, tyControls.ComboBox,
  upluginapi, utranslation;

type
  TPluginOptionsForm = class(TTyForm)
  private
    FPlugin: TPluginInfo;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FContent: TTyPanel;
    FOK, FCancel: TTyButton;
    FEdits: TStringList;
    FChecks: TStringList;
    FCombos: TStringList;
    FValues: TStringList;
    procedure BuildUI;
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; APlugin: TPluginInfo);
    destructor Destroy; override;
    function Execute(out AValues: TStringList): Boolean;
  end;

implementation

constructor TPluginOptionsForm.Create(AOwner: TComponent; APlugin: TPluginInfo);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FPlugin := APlugin;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := Tr('Plugin Options');
  FEdits := TStringList.Create;
  FChecks := TStringList.Create;
  FCombos := TStringList.Create;
  FValues := TStringList.Create;
  FValues.CaseSensitive := False;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
end;

destructor TPluginOptionsForm.Destroy;
begin
  FValues.Free;
  FCombos.Free;
  FChecks.Free;
  FEdits.Free;
  inherited;
end;

procedure TPluginOptionsForm.BuildUI;
var
  i, Y, H, Index: Integer;
  Option: TPluginOption;
  Lbl: TTyLabel;
  Edit: TTyEdit;
  Check: TTyCheckBox;
  Combo: TTyComboBox;
begin
  H := 130 + FPlugin.Options.Count * 44;
  if H < 230 then H := 230;
  SetBounds(0, 0, 520, H);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Plugin Options');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FContent := TTyPanel.Create(Self);
  FContent.Parent := FSurface;
  FContent.SetBounds(16, 52, 488, H - 110);

  Y := 14;
  for i := 0 to FPlugin.Options.Count - 1 do
  begin
    Option := TPluginOption(FPlugin.Options[i]);
    Lbl := TTyLabel.Create(Self);
    Lbl.Parent := FContent;
    Lbl.SetBounds(12, Y, 210, 24);
    Lbl.Caption := FPlugin.OptionLabel(Option);
    if Option.Kind = pokBoolean then
    begin
      Check := TTyCheckBox.Create(Self);
      Check.Parent := FContent;
      Check.SetBounds(230, Y, 220, 26);
      Check.Caption := '';
      Check.Checked := SameText(Option.DefaultValue, 'true') or
        (Option.DefaultValue = '1');
      FChecks.AddObject(Option.Id, Check);
    end
    else if Option.Kind = pokChoice then
    begin
      Combo := TTyComboBox.Create(Self);
      Combo.Parent := FContent;
      Combo.SetBounds(230, Y, 220, 30);
      for Index := 0 to Option.Choices.Count - 1 do
        Combo.Items.Add(FPlugin.ChoiceLabel(Option, Option.Choices[Index]));
      Index := Option.Choices.IndexOf(Option.DefaultValue);
      if Index < 0 then Index := 0;
      Combo.ItemIndex := Index;
      FCombos.AddObject(Option.Id, Combo);
    end
    else
    begin
      Edit := TTyEdit.Create(Self);
      Edit.Parent := FContent;
      Edit.SetBounds(230, Y, 220, 30);
      Edit.Text := Option.DefaultValue;
      FEdits.AddObject(Option.Id, Edit);
    end;
    Inc(Y, 44);
  end;

  FOK := TTyButton.Create(Self);
  FOK.Parent := FSurface;
  FOK.SetBounds(300, H - 46, 90, 32);
  FOK.Caption := Tr('Run');
  FOK.OnClick := @DoOK;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(400, H - 46, 90, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TPluginOptionsForm.DoOK(Sender: TObject);
var
  i, Index: Integer;
  Option: TPluginOption;
  Check: TTyCheckBox;
  Combo: TTyComboBox;
  Edit: TTyEdit;
begin
  FValues.Clear;
  for i := 0 to FPlugin.Options.Count - 1 do
  begin
    Option := TPluginOption(FPlugin.Options[i]);
    if Option.Kind = pokBoolean then
    begin
      Index := FChecks.IndexOf(Option.Id);
      if Index >= 0 then
      begin
        Check := TTyCheckBox(FChecks.Objects[Index]);
        if Check.Checked then FValues.Values[Option.Id] := 'true'
        else FValues.Values[Option.Id] := 'false';
      end;
    end
    else if Option.Kind = pokChoice then
    begin
      Index := FCombos.IndexOf(Option.Id);
      if Index >= 0 then
      begin
        Combo := TTyComboBox(FCombos.Objects[Index]);
        if (Combo.ItemIndex >= 0) and (Combo.ItemIndex < Option.Choices.Count) then
          FValues.Values[Option.Id] := Option.Choices[Combo.ItemIndex];
      end;
    end
    else
    begin
      Index := FEdits.IndexOf(Option.Id);
      if Index >= 0 then
      begin
        Edit := TTyEdit(FEdits.Objects[Index]);
        FValues.Values[Option.Id] := Edit.Text;
      end;
    end;
  end;
  ModalResult := mrOk;
end;

procedure TPluginOptionsForm.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TPluginOptionsForm.Execute(out AValues: TStringList): Boolean;
begin
  AValues := nil;
  Result := ShowModal = mrOk;
  if Result then
  begin
    AValues := TStringList.Create;
    AValues.CaseSensitive := False;
    AValues.Assign(FValues);
  end;
end;

end.

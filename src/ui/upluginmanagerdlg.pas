unit upluginmanagerdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, LCLIntf,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.CheckListBox, tyControls.Memo,
  tyControls.TyLabel, tyControls.Button, tyControls.Dialogs,
  upluginapi, upluginmanager, utranslation, uutils;

type
  TPluginManagerForm = class(TTyForm)
  private
    FManager: TPluginManager;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FList: TTyCheckListBox;
    FDetails: TTyMemo;
    FInstall, FUninstall, FReload, FOpenFolder, FClose: TTyButton;
    FRefreshing: Boolean;
    procedure BuildUI;
    procedure RefreshList;
    procedure ListChanged(Sender: TObject);
    procedure CheckChanged(Sender: TObject);
    procedure DoInstall(Sender: TObject);
    procedure DoUninstall(Sender: TObject);
    procedure DoReload(Sender: TObject);
    procedure DoOpenFolder(Sender: TObject);
    procedure DoCloseClick(Sender: TObject);
    function SelectedPlugin: TPluginInfo;
  public
    constructor Create(AOwner: TComponent; AManager: TPluginManager);
    function Execute: Boolean;
  end;

implementation

constructor TPluginManagerForm.Create(AOwner: TComponent; AManager: TPluginManager);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FManager := AManager;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := Tr('Manage Plugins');
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  RefreshList;
end;

procedure TPluginManagerForm.BuildUI;
begin
  SetBounds(0, 0, 760, 540);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Manage Plugins');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FList := TTyCheckListBox.Create(Self);
  FList.Parent := FSurface;
  FList.SetBounds(16, 52, 390, 380);
  FList.OnChange := @ListChanged;
  FList.OnClickCheck := @CheckChanged;

  FDetails := TTyMemo.Create(Self);
  FDetails.Parent := FSurface;
  FDetails.SetBounds(420, 52, 324, 380);
  FDetails.ReadOnly := True;
  FDetails.ScrollBars := ssAutoVertical;
  FDetails.WordWrap := True;

  FInstall := TTyButton.Create(Self);
  FInstall.Parent := FSurface;
  FInstall.SetBounds(16, 448, 120, 32);
  FInstall.Caption := Tr('Install...');
  FInstall.OnClick := @DoInstall;

  FUninstall := TTyButton.Create(Self);
  FUninstall.Parent := FSurface;
  FUninstall.SetBounds(146, 448, 120, 32);
  FUninstall.Caption := Tr('Uninstall');
  FUninstall.OnClick := @DoUninstall;

  FReload := TTyButton.Create(Self);
  FReload.Parent := FSurface;
  FReload.SetBounds(276, 448, 100, 32);
  FReload.Caption := Tr('Reload');
  FReload.OnClick := @DoReload;

  FOpenFolder := TTyButton.Create(Self);
  FOpenFolder.Parent := FSurface;
  FOpenFolder.SetBounds(386, 448, 120, 32);
  FOpenFolder.Caption := Tr('Open Folder');
  FOpenFolder.OnClick := @DoOpenFolder;

  FClose := TTyButton.Create(Self);
  FClose.Parent := FSurface;
  FClose.SetBounds(644, 448, 100, 32);
  FClose.Caption := Tr('Close');
  FClose.OnClick := @DoCloseClick;
end;

function TPluginManagerForm.SelectedPlugin: TPluginInfo;
var
  Index: Integer;
begin
  Result := nil;
  Index := FList.ItemIndex;
  if (Index >= 0) and (Index < FManager.Plugins.Count) then
    Result := TPluginInfo(FManager.Plugins[Index]);
end;

procedure TPluginManagerForm.RefreshList;
var
  i: Integer;
  Plugin: TPluginInfo;
  SourceText, LineText: string;
  OldIndex: Integer;
begin
  FRefreshing := True;
  try
    OldIndex := FList.ItemIndex;
    FList.Items.BeginUpdate;
    try
      FList.Items.Clear;
      for i := 0 to FManager.Plugins.Count - 1 do
      begin
        Plugin := TPluginInfo(FManager.Plugins[i]);
        if Plugin.Bundled then SourceText := Tr('Bundled') else SourceText := Tr('User');
        LineText := Format('%s  (%s)  [%s]', [Plugin.LocalizedName, Plugin.Version, SourceText]);
        FList.Items.Add(LineText);
        FList.Checked[i] := Plugin.Enabled;
        FList.ItemEnabled[i] := Plugin.DisabledReason = '';
      end;
    finally
      FList.Items.EndUpdate;
    end;
    if FList.Items.Count = 0 then
    begin
      FList.Items.Add(Tr('No plugins found'));
      FList.ItemEnabled[0] := False;
    end;
    if (OldIndex >= 0) and (OldIndex < FList.Items.Count) then
      FList.ItemIndex := OldIndex
    else if FList.Items.Count > 0 then
      FList.ItemIndex := 0;
  finally
    FRefreshing := False;
  end;
  ListChanged(nil);
end;

procedure TPluginManagerForm.ListChanged(Sender: TObject);
var
  Plugin: TPluginInfo;
  InfoText: string;
  i: Integer;
begin
  Plugin := SelectedPlugin;
  if Plugin = nil then
  begin
    FDetails.Text := '';
    Exit;
  end;
  InfoText := Plugin.LocalizedName + LineEnding + LineEnding;
  InfoText := InfoText + Tr('ID:') + ' ' + Plugin.Id + LineEnding;
  InfoText := InfoText + Tr('Version:') + ' ' + Plugin.Version + LineEnding;
  InfoText := InfoText + Tr('Runtime:') + ' ' + Plugin.RuntimeType + LineEnding;
  if Plugin.Bundled then
    InfoText := InfoText + Tr('Source:') + ' ' + Tr('Bundled')
  else
    InfoText := InfoText + Tr('Source:') + ' ' + Tr('User');
  InfoText := InfoText + LineEnding + Plugin.LocalizedDescription + LineEnding;
  if Plugin.DisabledReason <> '' then
    InfoText := InfoText + LineEnding + Tr('Compatibility:') + ' ' + Plugin.DisabledReason + LineEnding;
  if Plugin.Commands.Count > 0 then
  begin
    InfoText := InfoText + LineEnding + Tr('Commands:') + LineEnding;
    for i := 0 to Plugin.Commands.Count - 1 do
      InfoText := InfoText + '  ' + Plugin.CommandTitle(TPluginCommand(Plugin.Commands[i])) + LineEnding;
  end;
  if Plugin.Options.Count > 0 then
  begin
    InfoText := InfoText + LineEnding + Tr('Options:') + LineEnding;
    for i := 0 to Plugin.Options.Count - 1 do
      InfoText := InfoText + '  ' + Plugin.OptionLabel(TPluginOption(Plugin.Options[i])) + LineEnding;
  end;
  if FManager.Errors.Count > 0 then
  begin
    InfoText := InfoText + LineEnding + Tr('Plugin errors:') + LineEnding;
    for i := 0 to FManager.Errors.Count - 1 do
      InfoText := InfoText + '  ' + FManager.Errors[i] + LineEnding;
  end;
  FDetails.Text := InfoText;
end;

procedure TPluginManagerForm.CheckChanged(Sender: TObject);
var
  Plugin: TPluginInfo;
  Index: Integer;
begin
  if FRefreshing then Exit;
  Index := FList.ItemIndex;
  if (Index < 0) or (Index >= FManager.Plugins.Count) then Exit;
  Plugin := TPluginInfo(FManager.Plugins[Index]);
  if not FManager.SetEnabled(Plugin.Id, FList.Checked[Index]) then
    FList.Checked[Index] := Plugin.Enabled;
  ListChanged(nil);
end;

procedure TPluginManagerForm.DoInstall(Sender: TObject);
var
  Dialog: TOpenDialog;
  ErrorText: string;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'TyEditor plugins (*.typlugin)|*.typlugin|All files (*.*)|*.*';
    Dialog.Options := [ofFileMustExist];
    if not Dialog.Execute then Exit;
    if FManager.InstallPackage(Dialog.FileName, ErrorText) then
    begin
      FManager.Refresh;
      RefreshList;
      TyMessageDlg(Tr('Plugin package installed.'), mtInformation, [mbOK]);
    end
    else
      TyMessageDlg(Format(Tr('Unable to install plugin: %s'), [ErrorText]),
        mtError, [mbOK]);
  finally
    Dialog.Free;
  end;
end;

procedure TPluginManagerForm.DoUninstall(Sender: TObject);
var
  Plugin: TPluginInfo;
  ErrorText: string;
begin
  Plugin := SelectedPlugin;
  if Plugin = nil then Exit;
  if Plugin.Bundled then
  begin
    TyMessageDlg(Tr('Bundled plugins cannot be uninstalled.'), mtInformation, [mbOK]);
    Exit;
  end;
  if TyMessageDlg(Format(Tr('Remove plugin "%s"?'), [Plugin.LocalizedName]),
    mtConfirmation, [mbYes, mbNo]) <> mrYes then Exit;
  if FManager.UninstallPlugin(Plugin.Id, ErrorText) then
  begin
    FManager.Refresh;
    RefreshList;
  end
  else
    TyMessageDlg(Format(Tr('Unable to remove plugin: %s'), [ErrorText]),
      mtError, [mbOK]);
end;

procedure TPluginManagerForm.DoReload(Sender: TObject);
begin
  FManager.Refresh;
  RefreshList;
end;

procedure TPluginManagerForm.DoOpenFolder(Sender: TObject);
begin
  OpenDocument(FManager.UserDir);
end;

procedure TPluginManagerForm.DoCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

function TPluginManagerForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.

unit upluginrun;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, LCLType, Dialogs, ExtCtrls,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.TyLabel, tyControls.Button,
  fpjson, upluginapi, upluginmanager, upluginruntime, utranslation;

type
  TPluginRunThread = class(TThread)
  private
    FManager: TPluginManager;
    FPlugin: TPluginInfo;
    FCommand: TPluginCommand;
    FRequest: TJSONObject;
    FResponse: TJSONObject;
    FError: string;
    FSucceeded: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AManager: TPluginManager; APlugin: TPluginInfo;
      ACommand: TPluginCommand; ARequest: TJSONObject);
    function TakeResponse: TJSONObject;
    property Succeeded: Boolean read FSucceeded;
    property ErrorText: string read FError;
  end;

  TPluginProgressForm = class(TTyForm)
  private
    FThread: TPluginRunThread;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FStatus: TTyLabel;
    FCancel: TTyButton;
    FTimer: TTimer;
    FCancelled: Boolean;
    procedure BuildUI;
    procedure DoTimer(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create(AOwner: TComponent; AManager: TPluginManager;
      APlugin: TPluginInfo; ACommand: TPluginCommand; ARequest: TJSONObject);
    destructor Destroy; override;
    function Run(out AResponse: TJSONObject; out AError: string): Boolean;
    property Cancelled: Boolean read FCancelled;
  end;

implementation

constructor TPluginRunThread.Create(AManager: TPluginManager;
  APlugin: TPluginInfo; ACommand: TPluginCommand; ARequest: TJSONObject);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FManager := AManager;
  FPlugin := APlugin;
  FCommand := ACommand;
  FRequest := ARequest;
  FResponse := nil;
  FError := '';
  FSucceeded := False;
end;

procedure TPluginRunThread.Execute;
begin
  try
    FSucceeded := FManager.Execute(FPlugin, FCommand, FRequest, FResponse, FError);
  except
    on E: Exception do
    begin
      FSucceeded := False;
      FError := E.Message;
    end;
  end;
end;

function TPluginRunThread.TakeResponse: TJSONObject;
begin
  Result := FResponse;
  FResponse := nil;
end;

constructor TPluginProgressForm.Create(AOwner: TComponent;
  AManager: TPluginManager; APlugin: TPluginInfo; ACommand: TPluginCommand;
  ARequest: TJSONObject);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := Tr('Running Plugin');
  FCancelled := False;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  FStatus.Caption := Format(Tr('Running %s...'), [APlugin.LocalizedName]);
  FThread := TPluginRunThread.Create(AManager, APlugin, ACommand, ARequest);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.Enabled := False;
  FTimer.OnTimer := @DoTimer;
  OnClose := @DoFormClose;
end;

destructor TPluginProgressForm.Destroy;
begin
  FTimer.Enabled := False;
  if FThread <> nil then
  begin
    if not FThread.Finished then
    begin
      CancelPluginExecution;
      FThread.WaitFor;
    end;
    FThread.Free;
  end;
  FTimer.Free;
  inherited;
end;

procedure TPluginProgressForm.BuildUI;
begin
  SetBounds(0, 0, 440, 190);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Running Plugin');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FStatus := TTyLabel.Create(Self);
  FStatus.Parent := FSurface;
  FStatus.SetBounds(20, 60, 400, 50);
  FStatus.Caption := '';
  FStatus.WordWrap := True;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(320, 130, 100, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TPluginProgressForm.DoTimer(Sender: TObject);
begin
  if (FThread <> nil) and FThread.Finished then
  begin
    FTimer.Enabled := False;
    FThread.WaitFor;
    ModalResult := mrOk;
  end;
end;

procedure TPluginProgressForm.DoCancel(Sender: TObject);
begin
  FCancelled := True;
  CancelPluginExecution;
  FCancel.Enabled := False;
  FStatus.Caption := Tr('Cancelling...');
end;

procedure TPluginProgressForm.DoFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if (FThread <> nil) and (not FThread.Finished) then
  begin
    CloseAction := caNone;
    DoCancel(nil);
  end;
end;

function TPluginProgressForm.Run(out AResponse: TJSONObject;
  out AError: string): Boolean;
begin
  AResponse := nil;
  AError := '';
  FTimer.Enabled := True;
  FThread.Start;
  ShowModal;
  if not FThread.Finished then
  begin
    CancelPluginExecution;
    FThread.WaitFor;
  end;
  Result := FThread.Succeeded and (not FCancelled);
  AResponse := FThread.TakeResponse;
  AError := FThread.ErrorText;
  if FCancelled or (FThread.ErrorText = 'Plugin cancelled') then
  begin
    AError := 'Plugin cancelled';
    if AResponse <> nil then
      FreeAndNil(AResponse);
    Result := False;
  end;
end;

end.

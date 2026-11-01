unit utoolrun;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, LCLType, Dialogs, ExtCtrls, StdCtrls, Clipbrd,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.Memo, tyControls.TyLabel, tyControls.Button,
  utools, utranslation;

type
  TToolRunThread = class(TThread)
  private
    FTool: TExternalTool;
    FContext: TToolContext;
    FState: TToolRunState;
    FOutput, FErrOutput, FError: string;
    FExitCode: Integer;
    FTimedOut, FSucceeded: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(ATool: TExternalTool; const AContext: TToolContext;
      AState: TToolRunState);
    property Succeeded: Boolean read FSucceeded;
    property ErrorText: string read FError;
    property OutputText: string read FOutput;
    property ErrOutputText: string read FErrOutput;
    property ExitCode: Integer read FExitCode;
    property TimedOut: Boolean read FTimedOut;
  end;

  TToolProgressForm = class(TTyForm)
  private
    FThread: TToolRunThread;
    FState: TToolRunState;
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
    constructor Create(AOwner: TComponent; ATool: TExternalTool;
      const AContext: TToolContext);
    destructor Destroy; override;
    function Run(out AOutput, AErrOutput, AError: string): Boolean;
    property Cancelled: Boolean read FCancelled;
  end;

  TToolOutputForm = class(TTyForm)
  private
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FMemo: TTyMemo;
    FCopy, FClose: TTyButton;
    procedure BuildUI;
    procedure DoCopy(Sender: TObject);
    procedure DoCloseClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; const ACaption, AText: string);
    function Execute: Boolean;
  end;

implementation

constructor TToolRunThread.Create(ATool: TExternalTool;
  const AContext: TToolContext; AState: TToolRunState);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FTool := ATool;
  FContext := AContext;
  FState := AState;
  FOutput := '';
  FErrOutput := '';
  FError := '';
  FExitCode := -1;
  FTimedOut := False;
  FSucceeded := False;
end;

procedure TToolRunThread.Execute;
begin
  try
    FSucceeded := ExecuteTool(FTool, FContext, FState, FOutput, FErrOutput,
      FExitCode, FError, FTimedOut);
  except
    on E: Exception do
    begin
      FSucceeded := False;
      FError := E.Message;
    end;
  end;
end;

constructor TToolProgressForm.Create(AOwner: TComponent; ATool: TExternalTool;
  const AContext: TToolContext);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := Tr('Running Tool');
  FCancelled := False;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  if ATool <> nil then
    FStatus.Caption := Format(Tr('Running %s...'), [ATool.Name])
  else
    FStatus.Caption := Tr('Running...');
  FState := TToolRunState.Create;
  FThread := TToolRunThread.Create(ATool, AContext, FState);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.Enabled := False;
  FTimer.OnTimer := @DoTimer;
  OnClose := @DoFormClose;
end;

destructor TToolProgressForm.Destroy;
begin
  FTimer.Enabled := False;
  if FThread <> nil then
  begin
    if not FThread.Finished then
    begin
      FState.Cancelled := True;
      FThread.WaitFor;
    end;
    FThread.Free;
  end;
  FState.Free;
  FTimer.Free;
  inherited;
end;

procedure TToolProgressForm.BuildUI;
begin
  SetBounds(0, 0, 460, 190);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Running Tool');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FStatus := TTyLabel.Create(Self);
  FStatus.Parent := FSurface;
  FStatus.SetBounds(20, 60, 420, 50);
  FStatus.Caption := '';
  FStatus.WordWrap := True;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(340, 130, 100, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TToolProgressForm.DoTimer(Sender: TObject);
begin
  if (FThread <> nil) and FThread.Finished then
  begin
    FTimer.Enabled := False;
    FThread.WaitFor;
    ModalResult := mrOk;
  end;
end;

procedure TToolProgressForm.DoCancel(Sender: TObject);
begin
  FCancelled := True;
  FState.Cancelled := True;
  FCancel.Enabled := False;
  FStatus.Caption := Tr('Cancelling...');
end;

procedure TToolProgressForm.DoFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if (FThread <> nil) and (not FThread.Finished) then
  begin
    CloseAction := caNone;
    DoCancel(nil);
  end;
end;

function TToolProgressForm.Run(out AOutput, AErrOutput, AError: string): Boolean;
begin
  AOutput := '';
  AErrOutput := '';
  AError := '';
  FTimer.Enabled := True;
  FThread.Start;
  ShowModal;
  if not FThread.Finished then
  begin
    FState.Cancelled := True;
    FThread.WaitFor;
  end;
  Result := FThread.Succeeded and (not FCancelled);
  AOutput := FThread.OutputText;
  AErrOutput := FThread.ErrOutputText;
  AError := FThread.ErrorText;
end;

constructor TToolOutputForm.Create(AOwner: TComponent; const ACaption, AText: string);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := ACaption;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  FTitle.Caption := ACaption;
  FMemo.Text := AText;
end;

procedure TToolOutputForm.BuildUI;
begin
  SetBounds(0, 0, 700, 480);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Tool Output');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FMemo := TTyMemo.Create(Self);
  FMemo.Parent := FSurface;
  FMemo.SetBounds(16, 52, 668, 360);
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoBoth;
  FMemo.WordWrap := False;

  FCopy := TTyButton.Create(Self);
  FCopy.Parent := FSurface;
  FCopy.SetBounds(484, 424, 100, 32);
  FCopy.Caption := Tr('Copy');
  FCopy.OnClick := @DoCopy;

  FClose := TTyButton.Create(Self);
  FClose.Parent := FSurface;
  FClose.SetBounds(594, 424, 90, 32);
  FClose.Caption := Tr('Close');
  FClose.OnClick := @DoCloseClick;
end;

procedure TToolOutputForm.DoCopy(Sender: TObject);
begin
  Clipboard.AsText := FMemo.Text;
end;

procedure TToolOutputForm.DoCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

function TToolOutputForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.

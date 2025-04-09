unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.WinXCtrls,
  System.Generics.Collections;

//
// Demo app by Ian Barker - ian.barker@embarcadero.com showing how to detect applications on your Windows PC along
// with Idle time (time when the user is NOT clicking/moving the mouse or typing on the keyboard).
// This would make a great foundation for a work monitoring or automated activity tracker if you wanted to see
// what you really got up to in an average working day and how much of that time was spent on sites like Reddit ;)
//
// In a live, shipping, commercial app you would of course not keep updating the display of the Windows detected on
// the system - and even if you did you would probably use a grid or similar control - I just added this in for the
// purposes of the demo so I could show that we were able to detect which app was active and how long for.
//
/// You would also likely do something such as minimize an actual commerical app to the system tray or even implement
// it as a service which started automatically tracking when a user logged in. You could easily do all of this with
// Delphi using the VCL
//
// Accompanying blog post and webinar video replay can be found here: https://tinyurl.com/ib30for30timetracker
//
// Ian Barker ian.barker@embarcadero.com April 9th 2025
//

type
  TForm1 = class(TForm)
    ListBox1: TListBox;
    Timer1: TTimer;
    Panel1: TPanel;
    TrackingButton: TButton;
    ActivityIndicator1: TActivityIndicator;
    cbListWithZeroSeconds: TCheckBox;
    cbStayOnTop: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure TrackingButtonClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ListBox1DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure cbStayOnTopClick(Sender: TObject);
  private
    FIsTracking: boolean;
    FTotalIdle, FTotalSeconds: Integer;
    FWindowsList: TDictionary<string, Integer>;
    function SecondsIdle: DWord;
    procedure GetWindowsList;
    procedure RefreshData(const Init: Boolean);
    procedure AddWindowToStats(const WindowName: string; IsActive: boolean);
    procedure ListWindows;
    procedure ListStatistics;
  end;

var
  Form1: TForm1;
  FActiveWindows: TStringList;

implementation

{$R *.dfm}

uses modules.listtaskwindows;


const
  CurrentSuffix      = ' <-- current';
  StatsLabel         = 'Statistics';
  ActiveWindowsLabel = 'Active Windows';

procedure TForm1.GetWindowsList;
begin
  RefreshData(False);
end;

procedure TForm1.RefreshData(const Init: Boolean);
begin
  GetAllTaskWindows(FActiveWindows, Init);
end;

procedure TForm1.ListBox1DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  // Make some of the lisbox lines appear in bold if they are headings
  // Also, remove the focus/selected rectangle/backgrounds
  if odSelected in State then
  begin
    (Control as TListBox).Canvas.Brush.Color := (Control as TListBox).Color;
    (Control as TListBox).Canvas.Font.Color := (Control as TListBox).Font.Color;
  end;
  if (Control as TListBox).Items[Index].Contains(CurrentSuffix) then
     (Control as TListBox).Canvas.Font.Color := clRed;
  if (Control as TListBox).Items[Index].Contains(StatsLabel) or (Control as TListBox).Items[Index].Contains(ActiveWindowsLabel) then
    (Control as TListBox).Canvas.Font.Style := [TFontStyle.fsBold];
  (Control as TListBox).Canvas.FillRect(Rect);
  (Control as TListBox).Canvas.TextOut(Rect.Left, Rect.Top, (Control as TListBox).Items[Index]);
  if odFocused in State then  // Remove focus rectangle
    (Control as TListBox).Canvas.DrawFocusRect(Rect);
end;

procedure TForm1.ListStatistics;

  function Plural(const TheVal: integer): string;
  begin
    if TheVal = 1 then
      Result := ' second'
    else
      Result := ' seconds';
  end;

begin
  // Lists a summary of the statistics - how much time was used in each app Window, to the nearest
  // second.
  //
  // In a live app you would emit this to a report such as a PDF or email - or to a more suitable
  // visual control such as a grid - not a listbox!
  //
  ListBox1.Items.Add(' ');
  ListBox1.Items.Add(' ');
  ListBox1.Items.Add(StatsLabel);
  if cbListWithZeroSeconds.Checked then ListBox1.Items.Add('Apps actually used');
  ListBox1.Items.Add('-----------------------------------');
  for var Stat: TPair<string, integer> in FWindowsList do
  begin
    if Stat.Key.Length = 0 then
      Continue;
    if cbListWithZeroSeconds.Checked and (Stat.Value = 0) then
      Continue;
    if not SameText(Stat.Key, Form1.Caption) then  // Ignore our own window
      ListBox1.Items.Add(Stat.Key + ' = ' + Stat.Value.ToString + Plural(Stat.Value));
  end;
end;

procedure TForm1.AddWindowToStats(const WindowName: string; IsActive: boolean);
var
  CurrentValue, NewValue: integer;
begin
  // This adds the currently in use/visible app Windows to our statistics.
  // If the Window is the active window then we add 1 second to the value
  // which is the number of seconds the app window has been active and in use
  //
  // Note that we also track the time spent in our own Window - but we filter
  // it out in the display of statistics when we stop tracking.
  //
  // We also count time spent in the window even if the system has been idle
  // during that period of time. This is so we count activity in windows that
  // do not require input - such as watching a YouTube video, attending a Zoom
  // meeting, or presenting a webinar ;)

  if IsActive then NewValue := 1 else NewValue := 0;
  CurrentValue := 0;

  if FWindowsList.ContainsKey(WindowName) then
    FWindowsList.TryGetValue(WindowName, CurrentValue);

  NewValue := CurrentValue + NewValue;
  FWindowsList.AddOrSetValue(WindowName, NewValue);
end;

procedure TForm1.ListWindows;
var
  IsActiveWindow: boolean;

begin
  // List all the currently active visible application windows on the system
  // We also indicate which one is the active window (the one with the focus)
  // In a live app you would not do this display, it would not be efficient
  // but you would maintain the statistics so they could be offered to the
  // end user when they wanted a report on what apps they had been using.
  var CurrentlyActive: string := GetWindowCaption(GetForegroundWindow);
  ListBox1.Items.BeginUpdate;
  try
    LockWindowUpdate(Form1.Handle); // Prevent the form's controls from flashing
    ListBox1.Items.Clear;
    ListBox1.Items.Add(ActiveWindowsLabel);
    ListBox1.Items.Add('-----------------------------------');
    for var DetectedWindows in FActiveWindows do
    begin
      if DetectedWindows.Length = 0 then
        Continue;
      if SameText(DetectedWindows, Form1.Caption) then // Ignore our own window
        Continue;
      IsActiveWindow := SameText(CurrentlyActive, DetectedWindows);
      AddWindowToStats(DetectedWindows, IsActiveWindow);
      if IsActiveWindow then
        ListBox1.Items.Add(DetectedWindows + CurrentSuffix)
      else
        ListBox1.Items.Add(DetectedWindows);
    end;
  finally
    ListBox1.Items.EndUpdate;
    LockWindowUpdate(0); // Make sure you do this or the screen will not repaint!
  end;
end;

function TForm1.SecondsIdle: DWord;
var
  LInfo: TLastInputInfo;
begin
  // How many seconds has there been no activity - keyboard presses or mouse movements?
  LInfo.cbSize := SizeOf(TLastInputInfo) ;
  GetLastInputInfo(LInfo) ;
  Result := (GetTickCount - LInfo.dwTime) DIV 1000;
end;

procedure TForm1.cbStayOnTopClick(Sender: TObject);
begin
  // Make the tracking app stay floating above other app windows?
  if cbStayOnTop.Checked then
    Form1.FormStyle := fsStayOnTop
  else
    Form1.FormStyle := fsNormal;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // In a real app you would trap this event and emit the statistics on
  // recorded time to a report such as a PDF, a database, or some other
  // method - otherwise you would lose all record of the recorded time
  Timer1.Enabled := False;
  FreeAndNil(FActiveWindows);
  FreeAndNil(FWindowsList);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FIsTracking               := False;
  FActiveWindows            := TStringList.Create;
  FActiveWindows.Sorted     := True;
  FActiveWindows.Duplicates := dupIgnore;
  // Make the height of a listbox line big enough to fit in the text despite scaling etc
  ListBox1.ItemHeight       := (ListBox1.Canvas.TextHeight('g|^`y') + 6);
  FWindowsList              := TDictionary<string, Integer>.Create;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  // Main work routine, triggered every 1000 milliseconds (1 second)
  Inc(FTotalSeconds);
  var LastIdle := SecondsIdle;
  if LastIdle > 0 then Inc(FTotalIdle);
  GetWindowsList;
  ListWindows;
end;

procedure TForm1.TrackingButtonClick(Sender: TObject);
begin
  // The start tracking button also stops the time tracking and lists the results
  if FIsTracking then
    begin
      TrackingButton.Caption := 'Start Tracking';
      Timer1.Enabled := False;
      ListWindows;
      ListStatistics;
      ListBox1.Items.Add('');
      ListBox1.Items.Add(Format('System IDLE for %d seconds out of %d', [FTotalIdle, FTotalSeconds]));
      FActiveWindows.Clear;
      FWindowsList.Clear;
      FTotalSeconds := 0;
      FTotalIdle    := 0;
    end
  else
    begin
      TrackingButton.Caption := 'Stop Tracking';
      FTotalSeconds  := 0;
      FTotalIdle     := 0;
      RefreshData(True);
      ListBox1.Visible := True;
      Timer1.Enabled := True;
    end;
  FIsTracking := not FIsTracking;
  ActivityIndicator1.Animate := FIsTracking;
end;

end.

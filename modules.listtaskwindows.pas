unit modules.listtaskwindows;

interface
uses
  System.SysUtils,
  Winapi.Windows,
  System.Classes;

procedure GetAllTaskWindows(AActiveWindows: TStringList; const ClearList: boolean);
function GetWindowCaption(AWnd: HWND):string;

implementation

function EnumWindowsProc(AWnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  Result := True; // carry on enumerating
  if IsWindowVisible(AWnd) then
//    if GetWindow(AWnd, GW_OWNER) <> 0 then <-- uncomment this depending on the type of app you're looking to write
     if GetWindowLongPtr(AWnd, GWL_STYLE) and WS_EX_APPWINDOW <> 0 then  // Only count visible main app windows
       TStringList(lParam).Add(GetWindowCaption(AWnd)); // add the title of the window to the list
end;

procedure GetAllTaskWindows(AActiveWindows: TStringList; const ClearList: boolean);
begin
  if ClearList then
  begin
    // Make sure the list is sorted alphabetically and that windows captions only appear once
    AActiveWindows.Clear;
    AActiveWindows.Sorted := True;
    AActiveWindows.Duplicates := dupIgnore;
  end;
  EnumWindows(@EnumWindowsProc, LParam(AActiveWindows));
end;

function GetWindowCaption(AWnd: HWND):string;
var
  LWindowName: string;
  ALen: Integer;
begin
  ALen := GetWindowTextLength(AWnd);
  if ALen > 0 then
  begin
    SetLength(LWindowName, ALen);
    GetWindowText(AWnd, PChar(LWindowName), Succ(Alen));
    Result := LWindowName;
  end;
end;

end.

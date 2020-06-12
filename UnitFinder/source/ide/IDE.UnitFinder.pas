unit IDE.UnitFinder;

interface

uses
  ActnList, Menus, Windows, Messages, SysUtils, Classes,
  Core.IDE, Core.ShellExecute, Core.PopupListEx,
  IDE.Interfaces, IDE.Task, IDE.FinderFiller;

type
  TUnitFinder = class
  private
    class function GetInstance: TUnitFinder; static;
    class var FInstance: TUnitFinder;
  private
    FActionList: TActionList;
    FPopupMenu: TPopupMenuEx;
    FHandle: HWND;
    FTargetSelection: word;

    FToken: string;
    FTasks: TAsyncQueuedTasks;
    FFinder: IUnitFormFinder;
    FFiller: IUnitMenuFiller;
  private
    procedure WndProc(var Message: TMessage);
    procedure WMHotKey(var Msg: TWMHotKey); message WM_HOTKEY;
  private
    function RegisterHotKey(): boolean;
    procedure UnRegisterHotKey;
  private
    function GetMousePoint(): TPoint;
    function GetCurWinHwnd(): HWND;
    function GetCurWinClassName(): string;
    function GetActionByName(const AActionName: string): TCustomAction;

    procedure DoCopyClassName(Sender: TObject);
    procedure DoOpenDir(Sender: TObject);
    procedure DoCloseMenu(Sender: TObject);
    procedure CreateActions();

    procedure OnFillMenu();
    procedure OnUnitFound(const AToken: string; const ADir: string; const AFileName: TFileName);
    procedure OnClosePopup(Sender: TObject);

    procedure CreateMenuUnits(const AMenuItem: TMenuItem;
      const AFormName: string);
    procedure CreateMenus(const AFormName: string);
    procedure DoPopup(Sender: TObject);

    procedure Show(); overload;
    procedure Show(const APoint: TPoint); overload;

    constructor Create();
  public
    destructor Destroy(); override;
    
    class procedure Initialize();
    class procedure Finalize();

    function StartMonitor(): boolean;
    procedure StopMonitor();

    property Finder: IUnitFormFinder read FFinder write FFinder;
    property Filler: IUnitMenuFiller read FFiller write FFiller;

    class property Instance: TUnitFinder read GetInstance;
  end;

implementation

uses
  Clipbrd, ShellAPI;

const
  LOADING = ' (carregando)';

{ TFrmCtxWndProc }

constructor TUnitFinder.Create;
begin
  FActionList := TActionList.Create(nil);
  CreateActions();
  FPopupMenu := TPopupMenuEx.Create(nil);
  FPopupMenu.OnPopup := DoPopup;
  FPopupMenu.OnClose := OnClosePopup;
  FHandle := Classes.AllocateHWnd(WndProc);
  FTasks := TAsyncQueuedTasks.Create();
  FFinder := TUnitFinderAndMenuFiller.Create();
  FFiller := FFinder as IUnitMenuFiller;
end;

destructor TUnitFinder.Destroy;
begin
  UnRegisterHotKey();
  FTasks.Free();
  Classes.DeallocateHWnd(FHandle);
  FPopupMenu.Free();
  FActionList.Free();
  inherited;
end;

class procedure TUnitFinder.Initialize;
begin
  FInstance := TUnitFinder.Create();
end;

class procedure TUnitFinder.Finalize;
begin
  FInstance.Free();
end;

procedure TUnitFinder.OnClosePopup(Sender: TObject);
begin
  FToken := EmptyStr;
end;

procedure TUnitFinder.OnFillMenu;
var
  LTask: TAsyncQueuedTasks.TQueuedTask;
begin
  LTask := FTasks.Pop();
  try
    if (LTask.Token = FToken) then begin
      if (LTask.FileName <> EmptyStr) then begin
        FFiller.Fill(LTask.FileName, FTasks.MenuItem);
      end;
      FTasks.MenuItem.Caption := StringReplace(FTasks.MenuItem.Caption,
        LOADING, EmptyStr, []);
    end;
  finally
    LTask.Free();
  end;           
end;

procedure TUnitFinder.OnUnitFound(const AToken: string; const ADir: string;
  const AFileName: TFileName);
begin
  FTasks.Push(AToken, AFileName);
  TThread.Queue(nil, OnFillMenu);
end;

class function TUnitFinder.GetInstance: TUnitFinder;
begin
  Result := TUnitFinder.FInstance;
end;

procedure TUnitFinder.WMHotKey(var Msg: TWMHotKey);
begin
  if (Msg.HotKey = FTargetSelection) then begin
    Show();
  end;
end;

procedure TUnitFinder.WndProc(var Message: TMessage);
begin
  Dispatch(Message);
end;

function TUnitFinder.RegisterHotKey: boolean;

  function TryRegisterHotKey: boolean;
  const
    ATOM = 'LMBTEC.IDE.FORMCONTEXT';
  begin
    FTargetSelection := GlobalAddAtom(PChar(ATOM));
    Result := (FTargetSelection <> 0)
          and Windows.RegisterHotKey(FHandle,
                         FTargetSelection,
                         MOD_CONTROL,
                         VK_F1);
  end;

var
  LTries: integer;
begin
  LTries := 0;
  Result := TryRegisterHotKey();
  while not Result and (LTries < 5) do begin
    Inc(LTries);
    Sleep(110);
    Result := TryRegisterHotKey();
  end; 
end;

procedure TUnitFinder.UnRegisterHotKey;
begin
  Windows.UnregisterHotKey(FHandle, FTargetSelection);
  GlobalDeleteAtom(FTargetSelection);
end;

procedure TUnitFinder.CreateActions;
var
  LAction: TAction;
begin
  LAction := TAction.Create(FActionList);
  LAction.Name := 'actClassName';
  LAction.Caption := '[...]';
  LAction.ActionList := FActionList;

  LAction := TAction.Create(FActionList);
  LAction.Name := 'actCopyClassName';
  LAction.Caption := 'Copiar nome da classe';
  LAction.OnExecute := DoCopyClassName;
  LAction.ActionList := FActionList;

  LAction := TAction.Create(FActionList);
  LAction.Name := 'actOpenUnit';
  LAction.Caption := 'Abrir local do arquivo';
  LAction.OnExecute := DoOpenDir;
  LAction.ActionList := FActionList;

  LAction := TAction.Create(FActionList);
  LAction.Name := 'actClose';
  LAction.Caption := 'Fechar';
  LAction.OnExecute := DoCloseMenu;
  LAction.ActionList := FActionList;
end;

procedure TUnitFinder.CreateMenus(const AFormName: string);
var
  LMenuItem: TMenuItem;
  LAction: TCustomAction;
begin
  FPopupMenu.Items.Clear();

  LMenuItem := TMenuItem.Create(FPopupMenu);
  LAction := GetActionByName('actClassName');
  LAction.Caption := AFormName;
  LMenuItem.Action := LAction;
  FPopupMenu.Items.Add(LMenuItem);

  LMenuItem := TMenuItem.Create(FPopupMenu);
  LMenuItem.Action := GetActionByName('actCopyClassName');
  FPopupMenu.Items.Add(LMenuItem);

  LMenuItem := TMenuItem.Create(FPopupMenu);
  LMenuItem.Name := 'miUnits';
  LMenuItem.Caption := 'Units';
  FPopupMenu.Items.Add(LMenuItem);
  CreateMenuUnits(LMenuItem, AFormName); 
  
  LMenuItem := TMenuItem.Create(FPopupMenu);
  LMenuItem.Action := GetActionByName('actClose');
  FPopupMenu.Items.Add(LMenuItem);
end;

procedure TUnitFinder.CreateMenuUnits(const AMenuItem: TMenuItem;
  const AFormName: string);
begin
  AMenuItem.Caption := AMenuItem.Caption + LOADING;
  FTasks.MenuItem := AMenuItem;
  FFinder.Find(FToken, AFormName, OnUnitFound);
end;

procedure TUnitFinder.DoCloseMenu(Sender: TObject);
begin
  //
end;

procedure TUnitFinder.DoCopyClassName(Sender: TObject);
var
  LFileName: string;
begin
  LFileName := GetActionByName('actClassName').Caption;
  Clipboard.SetTextBuf(PChar(LFileName));
end;

procedure TUnitFinder.DoOpenDir(Sender: TObject);
var
  LFileName: string;
begin
  if Sender is TMenuItem then begin
    LFileName := StringReplace((Sender as TMenuItem).Parent.Caption, '&', EmptyStr, [rfReplaceAll]);
    LFileName := Format('/select,%s', [LFileName]);
    ShellExecute(0, nil, PChar('explorer.exe'), PChar(LFileName), nil, SW_SHOWNORMAL);
  end;
end;

procedure TUnitFinder.DoPopup(Sender: TObject);
begin
  CreateMenus(GetCurWinClassName());
end;

function TUnitFinder.GetActionByName(
  const AActionName: string): TCustomAction;
var
  I: Integer;
  LAction: TContainedAction;
begin
  Result := nil; 
  for I := 0 to FActionList.ActionCount - 1 do begin
    LAction := FActionList.Actions[I];
    if LAction.Name = AActionName then begin
      Result := LAction as TCustomAction;
      Exit;
    end;
  end;
end;

function TUnitFinder.GetCurWinClassName: string;
var
  LHWND: HWND;
  LClassName: array [0..255] of char;
begin
  LHWND := GetCurWinHwnd();
  GetClassName(LHWND, LClassName, 255);
  Result := string(LClassName);
end;

function TUnitFinder.GetCurWinHwnd: HWND;
begin
  Result := GetForegroundWindow();
end;

function TUnitFinder.GetMousePoint: TPoint;
begin
  GetCursorPos(Result);
end;

procedure TUnitFinder.Show(const APoint: TPoint);
begin
  FToken := FormatDateTime('ddmmyyyyhhmmsszzz', Now());
  FPopupMenu.Popup(APoint.X, APoint.Y);
end;

function TUnitFinder.StartMonitor: boolean;
begin
  Result := RegisterHotKey();
end;

procedure TUnitFinder.StopMonitor;
begin
  UnRegisterHotKey();
end;

procedure TUnitFinder.Show;
begin
  Show(GetMousePoint());
end;

initialization
  TUnitFinder.Initialize();

finalization
  TUnitFinder.Finalize();

end.

unit Core.IDE;

interface

uses
  Windows, Classes, Menus, Contnrs, ToolsAPI;

type
  TIDE = class
  private
    class function GetInstance: TIDE; static;
    class var FInstance: TIDE;
  private
    FOTAActions: TObjectList;

    constructor Create();
  public
    destructor Destroy(); override;
    
    class procedure Initialize(); static;
    class procedure Finalize(); static;

    function GetCurrentProjectGroup(): IOTAProjectGroup;

    function AddImageToIDE(const AImageName: string): integer;
    function FindMenuItem(const AMenu: string): TMenuItem;
    function CreateMenuItem(AName, ACaption, AParentMenu : string;
      AClickProc, AUpdateProc : TNotifyEvent; AInsertBefore,
      AIsChildMenu : boolean; AShortCut : string;
      const ACheckIfExists: boolean = true) : TMenuItem;

    class property Instance: TIDE read GetInstance;
  end;

implementation

uses
  SysUtils, ActnList, Controls, Graphics;

{ TIDEMenuHelper }

constructor TIDE.Create;
begin
  FOTAActions := TObjectList.Create();
end;

destructor TIDE.Destroy;
begin
  FOTAActions.Destroy();
  inherited;
end;

class procedure TIDE.Initialize;
begin
  FInstance := TIDE.Create();
end;

class procedure TIDE.Finalize;
begin
  FInstance.Free();
end;

function TIDE.AddImageToIDE(const AImageName: string): integer;
var
  LINTAService: INTAServices;
  LImages : TImageList;
  LBitMap : TBitMap;
begin
  Result := -1;
  if FindResource(hInstance, PChar(AImageName + 'Image'), RT_BITMAP) > 0 then begin
    LINTAService := (BorlandIDEServices As INTAServices);
    LImages := TImageList.Create(Nil);
    try
      LBitMap := TBitMap.Create;
      try
        LBitMap.LoadFromResourceName(hInstance, AImageName + 'Image');
        {$IFDEF D2005_UP}
        LImages.AddMasked(LBitMap, clLime);
        Result := LINTAService.AddImages(LImages);
        {$ELSE}
        Result := LINTAService.AddMasked(LBitMap, clLime);
        {$ENDIF}
      finally
        LBitMap.Free;
      end;
    finally
      LImages.Free;
    end;
  end;
end;

function TIDE.CreateMenuItem(AName, ACaption,
  AParentMenu: string; AClickProc, AUpdateProc: TNotifyEvent; AInsertBefore,
  AIsChildMenu: boolean; AShortCut: string;
  const ACheckIfExists: boolean): TMenuItem;
var
  LINTAService : INTAServices;
  LAction : TAction;
  LParentMenuItem : TMenuItem;
  LIxImage : Integer;
begin
  if ACheckIfExists then begin
    Result := FindMenuItem(AName + 'Menu');
    if Assigned(Result) then begin
      Exit;
    end;
  end;

  LINTAService := (BorlandIDEServices As INTAServices);
  LIxImage := AddImageToIDE(AName);
  LAction := nil;
  Result := TMenuItem.Create(LINTAService.MainMenu);
  if Assigned(AClickProc) then begin
    LAction := TAction.Create(LINTAService.ActionList);
    LAction.ActionList := LINTAService.ActionList;
    LAction.Name := AName + 'Action';
    LAction.Caption := ACaption;
    LAction.OnExecute := AClickProc;
    LAction.OnUpdate := AUpdateProc;
    LAction.ShortCut := TextToShortCut(AShortCut);
    LAction.Tag := TextToShortCut(AShortCut);
    LAction.ImageIndex := LIxImage;
    LAction.Category := 'OTAEntityMenus';
    FOTAActions.Add(LAction);
  end else if ACaption <> '' then begin
    Result.Caption := ACaption;
    Result.ShortCut := TextToShortCut(AShortCut);
    Result.ImageIndex := LIxImage;
  end else begin
    Result.Caption := '-';
  end;

  Result.Action := LAction;
  Result.Name := AName + 'Menu';
  LParentMenuItem := FindMenuItem(AParentMenu + 'Menu');
  if LParentMenuItem <> nil then begin
    if not AIsChildMenu then begin
      if AInsertBefore then
        LParentMenuItem.Parent.Insert(LParentMenuItem.MenuIndex, Result)
      else begin
        LParentMenuItem.Parent.Insert(LParentMenuItem.MenuIndex + 1, Result);
      end;
    end else begin
      LParentMenuItem.Add(Result);
    end;
  end;
end;

function TIDE.FindMenuItem(const AMenu: string): TMenuItem;

  function IterateSubMenus(Menu : TMenuItem) : TMenuItem;
  var
    LSubMenu : Integer;
  begin
    Result := nil;
    for LSubMenu := 0 To Menu.Count - 1 do begin
      if CompareText(AMenu, Menu[LSubMenu].Name) = 0 then
        Result := Menu[LSubMenu]
      else
        Result := IterateSubMenus(Menu[LSubMenu]);
      if Result <> nil then
      Break;
    end;
  end;var  LIxMenu : Integer;
  LINTAService : INTAServices;
  LItems : TMenuItem;begin
  Result := nil;
  LINTAService := (BorlandIDEServices As INTAServices);
  for LIxMenu := 0 to LINTAService.MainMenu.Items.Count - 1 do begin
    LItems := LINTAService.MainMenu.Items;
    if CompareText(AMenu, LItems[LIxMenu].Name) = 0 then
      Result := LItems[LIxMenu]
    else
      Result := IterateSubMenus(LItems);
    if Result <> nil then Break;
  end;

end;

function TIDE.GetCurrentProjectGroup: IOTAProjectGroup;
var
  I: Integer;
  ModSvc: IOTAModuleServices;
begin
  ModSvc := BorlandIDEServices as IOTAModuleServices;
  for I := 0 to ModSvc.ModuleCount-1 do begin
    if ModSvc.Modules[I].QueryInterface(IOTAProjectGroup,Result) = 0 then Exit;
  end;
  Result := nil;
end;

class function TIDE.GetInstance: TIDE;
begin
  Result := TIDE.FInstance;
end;

initialization
  TIDE.Initialize();

finalization
  TIDE.Finalize();

end.

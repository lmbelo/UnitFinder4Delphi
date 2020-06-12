unit IDE.Menu;

interface

uses
  Menus, IDE.UnitFinder;

type
  TIDEMenu = class
  private
    class var FInstance: TIDEMenu;
  private
    FOTAMainMenu: TMenuItem;
    FUnitFinderMenu: TMenuItem;
  private
    procedure DoInstall();

    procedure MakeUnitFinderClick(Sender: TObject);
    procedure MakeUnitFinderUpdate(Sender: TObject);
  public
    class procedure Install();
    class procedure Uninstall();
  end;

implementation

uses
  ToolsAPI, Windows, Classes, SysUtils, ActnList, Controls, Graphics,
  Contnrs, Core.IDE;

{ TIDEMenu }

procedure TIDEMenu.DoInstall;
var
  LINTAService: INTAServices;
begin
  LINTAService := (BorlandIDEServices as INTAServices);
  if (LINTAService <> nil) and (LINTAService.MainMenu <> nil) then begin
    FOTAMainMenu := TIDE.Instance.CreateMenuItem('LMBTec', '&LMBTec', 'Tools',
                    nil, nil, false, false, EmptyStr);

    FUnitFinderMenu := TIDE.Instance.CreateMenuItem('UnitFinder', '&Unit Finder', 'LMBTec',
                    MakeUnitFinderClick, MakeUnitFinderUpdate, false, true, ShortCutToText(Menus.ShortCut(Ord('U'), [ssCtrl, ssShift, ssAlt])));
    TAction(FUnitFinderMenu.Action).AutoCheck := true;
    FUnitFinderMenu.AutoCheck := true;
  end;
end;

class procedure TIDEMenu.Install;
begin
  FInstance := TIDEMenu.Create();
  FInstance.DoInstall();
end;

procedure TIDEMenu.MakeUnitFinderClick(Sender: TObject);
begin
  if FUnitFinderMenu.Checked then begin
    FUnitFinderMenu.Checked := TUnitFinder.Instance.StartMonitor();
  end else begin
    TUnitFinder.Instance.StopMonitor();
  end;
end;

procedure TIDEMenu.MakeUnitFinderUpdate(Sender: TObject);
begin
  (Sender as TCustomAction).Enabled := true;
end;

class procedure TIDEMenu.Uninstall;
begin
  FreeAndNil(FInstance);
end;

end.

unit IDE.Registration;

interface

procedure Register;

implementation

uses
  IDE.Menu;

procedure Register;
begin
  TIDEMenu.Install();
end;

initialization

finalization
  TIDEMenu.Uninstall();

end.

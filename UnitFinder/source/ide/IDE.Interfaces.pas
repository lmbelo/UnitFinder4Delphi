unit IDE.Interfaces;

interface

uses
  Classes, Menus, SysUtils;

type
  TUnitFinderCallback = procedure(const AToken: string; const ADir: string; const AFileName: TFileName) of object;
  
  IUnitFormFinder = interface
    ['{FD30E8E7-08CB-4001-B0EE-2939CCC2ECEF}']
    procedure Find(const AToken: string; const AFormName: string; const ACallback: TUnitFinderCallback);
  end;

  IUnitMenuFiller = interface
    ['{6FA613F7-26FC-4715-A99E-D72139C9625B}']
    procedure Fill(const AFileName: TFileName; const AMenuItem: TMenuItem);
  end;

implementation

end.

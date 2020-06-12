unit IDE.FinderFiller;

interface

uses
  IDE.Interfaces, Classes, SysUtils, Menus;

type
  TUnitFinderAndMenuFiller = class(TInterfacedObject, IUnitFormFinder, IUnitMenuFiller)
  private
    procedure LookupDirs(const ALookupDirs: TStrings);
    procedure DoCopyFilePath(Sender: TObject);
    procedure DoOpenDelphi(Sender: TObject);
    procedure DoOpenDir(Sender: TObject);
  public
    procedure Find(const AToken: string; const AFormName: string; const ACallback: TUnitFinderCallback);
    procedure Fill(const AFileName: TFileName; const AMenuItem: TMenuItem);
  end;

implementation

uses
  Clipbrd, ToolsAPI, ShellAPI, Windows, StrUtils, Core.IDE, Core.ShellExecute;

type
  TAsyncFormFinder = class(TThread)
  private
    FCallback: TUnitFinderCallback;
    FFormName: string;
    FDir: string;
    FToken: string;
    procedure WaitEvt(var AKeepWaiting: boolean);
    procedure FindFiles(var LFiles: TStrings);
  protected
    procedure Execute(); override;
  public
    constructor Create(const AToken: string; const AFormName, ADir: string;
      const ACallback: TUnitFinderCallback);
  end;

{ TUnitFinderAndMenuFiller }

procedure TUnitFinderAndMenuFiller.DoCopyFilePath(Sender: TObject);
var
  LFileName: string;
begin
  if Sender is TMenuItem then begin
    LFileName := StringReplace((Sender as TMenuItem).Parent.Caption, '&', EmptyStr, [rfReplaceAll]);
    Clipboard.SetTextBuf(PChar(LFileName));
  end;
end;

procedure TUnitFinderAndMenuFiller.DoOpenDelphi(Sender: TObject);
var
  LIOTAModuleServices: IOTAModuleServices;
  LFileName: string;
  LIOTAModule: IOTAModule;
begin
  if Sender is TMenuItem then begin
    LFileName := StringReplace((Sender as TMenuItem).Parent.Caption, '&', EmptyStr, [rfReplaceAll]);
    LIOTAModuleServices := (BorlandIDEServices as IOTAModuleServices);
    LIOTAModule := LIOTAModuleServices.FindModule(LFileName);
    if not Assigned(LIOTAModule) then begin
      LIOTAModule := LIOTAModuleServices.OpenModule(LFileName);
      if Assigned(LIOTAModule) then begin    
        LIOTAModule.ShowFilename(LFileName);
      end;
    end;
  end;
end;

procedure TUnitFinderAndMenuFiller.DoOpenDir(Sender: TObject);
var
  LFileName: string;
begin
  if Sender is TMenuItem then begin
    LFileName := StringReplace((Sender as TMenuItem).Parent.Caption, '&', EmptyStr, [rfReplaceAll]);
    LFileName := Format('/select,%s', [LFileName]);
    ShellExecute(0, nil, PChar('explorer.exe'), PChar(LFileName), nil, SW_SHOWNORMAL)
  end;
end;

procedure TUnitFinderAndMenuFiller.Find(const AToken: string; const AFormName: string;
  const ACallback: TUnitFinderCallback);
var
  LLookupDirs: TStrings;
  I: Integer;
begin
  LLookupDirs := TStringList.Create();
  try
    LookupDirs(LLookupDirs);
    if (LLookupDirs.Count = 0) then
      ACallback(AToken, EmptyStr, EmptyStr)
    else for I := 0 to LLookupDirs.Count - 1 do begin
      TAsyncFormFinder.Create(AToken, AFormName, LLookupDirs[I], ACallback);
    end;
  finally
    LLookupDirs.Free();
  end;
end;

procedure TUnitFinderAndMenuFiller.LookupDirs(const ALookupDirs: TStrings);
var
  LGrp: IOTAProjectGroup;
  LProj: IOTAProject;
  LDir: string;
begin               
  LGrp := TIDE.Instance.GetCurrentProjectGroup();
  if LGrp <> nil then begin
    LProj := LGrp.GetActiveProject();
    if LProj <> nil then begin
      LDir := ExtractFileDir(LProj.FileName);
      ALookupDirs.Add(LDir);

      //Put all your unit directories here

    end;
  end;   
end;

procedure TUnitFinderAndMenuFiller.Fill(const AFileName: TFileName; const AMenuItem: TMenuItem);
var
  LName: string;
  LMenuItem: TMenuItem;
  LSubMenuItem: TMenuItem;
begin
  LMenuItem := TMenuItem.Create(AMenuItem);
  LName := 'miUnit' + FormatDateTime('hhmmsszzz', Now());
  while Assigned(AMenuItem.FindComponent(LName)) do begin
    LName := 'miUnit' + FormatDateTime('hhmmsszzz', Now());
  end;      
  LMenuItem.Name := LName;
  LMenuItem.Caption := AFileName;
  AMenuItem.Add(LMenuItem);

  LSubMenuItem := TMenuItem.Create(LMenuItem);
  LSubMenuItem.Name := Format('%s%s', ['miUnitsCopyFile', LName]);
  LSubMenuItem.Caption := 'Copiar caminho completo';
  LSubMenuItem.OnClick := DoCopyFilePath;
  LMenuItem.Add(LSubMenuItem);

  LSubMenuItem := TMenuItem.Create(LMenuItem);
  LSubMenuItem.Name := Format('%s%s', ['miUnitsOpenDir', LName]);
  LSubMenuItem.Caption := 'Abrir no diretório';
  LSubMenuItem.OnClick := DoOpenDir;
  LMenuItem.Add(LSubMenuItem);

  LSubMenuItem := TMenuItem.Create(LMenuItem);
  LSubMenuItem.Name := Format('%s%s', ['miUnitsOpenDelphi', LName]);
  LSubMenuItem.Caption := 'Abrir no Delphi';
  LSubMenuItem.OnClick := DoOpenDelphi;
  LMenuItem.Add(LSubMenuItem);
end;

{ TAsyncFormFinder }

constructor TAsyncFormFinder.Create(const AToken: string; const AFormName, ADir: string;
  const ACallback: TUnitFinderCallback);
begin
  FToken := AToken;
  FCallback := ACallback;
  FFormName := AFormName;
  FDir := ADir;
  FreeOnTerminate := true;
  inherited Create(false);
end;

procedure TAsyncFormFinder.FindFiles(var LFiles: TStrings);
const
  GREP_STR = 'grep.exe -d -i -l -r "(%0:s\ *\=\ *\class)|(%0:s\ *\=)" %1:s';
var
  LCmd: string;
  LDir: string;
begin
  LDir := '"' + IncludeTrailingPathDelimiter(FDir) + '*.pas' + '"';
  LCmd := Format(GREP_STR, [FFormName, LDir]);
  LFiles.Text := TShellExecute.ExecuteCommand(LCmd, EmptyStr, SW_HIDE, WaitEvt);
end;

procedure TAsyncFormFinder.WaitEvt(var AKeepWaiting: boolean);
begin
  AKeepWaiting := true;
end;

procedure TAsyncFormFinder.Execute;
var
  LFiles: TStrings;
  LFile: string;
  I: Integer;
begin
  inherited;
  try
    LFiles := TStringList.Create();
    try
      FindFiles(LFiles);
      if LFiles.Count > 0 then begin
        for I := 0 to LFiles.Count - 1 do begin
          LFile := Trim(LFiles[I]);
          if (LFile <> EmptyStr) then begin
            LFile := StringReplace(LFile, 'File ', EmptyStr, [rfReplaceAll, rfIgnoreCase]);
            if AnsiEndsText(':', LFile) then begin
              LFile := Copy(LFile, 1, LastDelimiter(':', LFile) - 1);
            end;
            LFile :=  ChangeFileExt(LFile, '.pas');
            if FileExists(LFile) and Assigned(FCallback) then begin
              FCallback(FToken, FDir, LFile);
            end;
          end;
        end;
      end else begin
        FCallback(FToken, FDir, EmptyStr);
      end;
    finally
      LFiles.Free();
    end;
  except
    raise;
  end;
end;

end.

unit Core.ShellExecute;

interface

uses
  Classes;

type
  TWaitEvt = procedure(var AKeepWaiting: boolean) of object;
  TShellExecute = class
	public
		class function ExecuteCommand(ACommandLine: string; AWork: string; const AShowWindow: word; const AWaitEvt: TWaitEvt = nil): string;
  end;

implementation

uses
  Windows, SysUtils;

{ TShellExecution }

class function TShellExecute.ExecuteCommand(ACommandLine, AWork: string;
  const AShowWindow: word; const AWaitEvt: TWaitEvt): string;
var
	SecAtrrs: TSecurityAttributes;
	StartupInfo: TStartupInfo;
	ProcessInfo: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
	pCommandLine: array[0..255] of AnsiChar;
  LPipeSize: Cardinal;
  LTextString: string;
  BytesRead: Cardinal;
  WorkDir: PAnsiChar;
	Handle: Boolean;
  LExternalWaitSignal: Boolean;
  LExitCode: Cardinal;
begin
	Result := '';
	with SecAtrrs do begin
    nLength := SizeOf(SecAtrrs);
    bInheritHandle := True;
		lpSecurityDescriptor := nil;
  end;
  
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecAtrrs, 0);
	try
    with StartupInfo do begin
			FillChar(StartupInfo, SizeOf(StartupInfo), 0);
      cb := SizeOf(StartupInfo);
			dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow := AShowWindow;
			hStdInput := GetStdHandle(STD_INPUT_HANDLE); // don't redirect stdin
      hStdOutput := StdOutPipeWrite;
			hStdError := StdOutPipeWrite;
		end;

		if (AWork <> EmptyStr) then WorkDir := PAnsiChar(AWork) else WorkDir := nil;

		Handle := CreateProcess(nil, PChar('cmd.exe /C ' + ACommandLine),	nil, nil,
                            true, 0, nil, WorkDir, StartupInfo, ProcessInfo);

		CloseHandle(StdOutPipeWrite);
    if Handle then begin
			try
        LExternalWaitSignal := true;
        if Assigned(AWaitEvt) then AWaitEvt(LExternalWaitSignal);
        LExitCode := WaitForSingleObject(ProcessInfo.hProcess, 100);
        while (LExitCode = WAIT_TIMEOUT) and LExternalWaitSignal do begin
            if Assigned(AWaitEvt) then AWaitEvt(LExternalWaitSignal);
          LExitCode := WaitForSingleObject(ProcessInfo.hProcess, 50);
        end;

        if (LExitCode = WAIT_TIMEOUT) then begin
          TerminateProcess(ProcessInfo.hProcess, 0);
        end else if (LExitCode = WAIT_OBJECT_0) then begin  
          LPipeSize := SizeOf(pCommandLine);
          repeat
            ReadFile(StdOutPipeRead, pCommandLine, LPipeSize, BytesRead, nil);
            if BytesRead > 0 then begin
              // a requirement for Windows OS system components
              OemToChar(@pCommandLine, @pCommandLine);
              LTextString := String(pCommandLine);
              SetLength(LTextString, BytesRead);
              Result := Result + LTextString;
            end;
          until (BytesRead < LPipeSize);
        end;
			finally
        if ProcessInfo.hProcess <> 0 then begin
          CloseHandle(ProcessInfo.hThread);
        end;
        if ProcessInfo.hThread <> 0 then begin
				  CloseHandle(ProcessInfo.hProcess);
        end;
			end;
    end;
	finally    
		CloseHandle(StdOutPipeRead);
	end;
end;

end.

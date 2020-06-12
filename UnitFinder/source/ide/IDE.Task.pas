unit IDE.Task;

interface

uses
  Contnrs, SysUtils, SyncObjs, Menus;

type
  TAsyncQueuedTasks = class(TObjectQueue)
  public type
    TQueuedTask = class
    strict private
      FFileName: TFileName;
      FToken: string;
    public
      constructor Create(const AToken: string; const AFileName: TFileName);

      property Token: string read FToken;
      property FileName: TFileName read FFileName;
    end;
  strict private
    FSync: TCriticalSection;
    FMenuItem: TMenuItem;
  public
    constructor Create;
    destructor Destroy; override;

    function Push(const AToken: string; const AFileName: TFileName): TQueuedTask;
    function Pop: TQueuedTask;

    property MenuItem: TMenuItem read FMenuItem write FMenuItem;
  end;

implementation

{ TQueuedTasks }

constructor TAsyncQueuedTasks.Create;
begin
  inherited;
  FSync := TCriticalSection.Create();
end;

destructor TAsyncQueuedTasks.Destroy;
begin
  FSync.Free();
  inherited;
end;

function TAsyncQueuedTasks.Pop: TQueuedTask;
begin
  FSync.Acquire();
  try
    Result := inherited Pop() as TQueuedTask;
  finally
    FSync.Release();
  end;
end;

function TAsyncQueuedTasks.Push(const AToken: string; const AFileName: TFileName): TQueuedTask;
begin
  FSync.Acquire();
  try
    Result := inherited Push(TQueuedTask.Create(AToken, AFileName)) as TQueuedTask;
  finally
    FSync.Release();
  end;
end;

{ TQueuedTasks.TQueuedTask }

constructor TAsyncQueuedTasks.TQueuedTask.Create(const AToken: string;
  const AFileName: TFileName);
begin
  FToken := AToken;
  FFileName := AFileName;
end;

end.

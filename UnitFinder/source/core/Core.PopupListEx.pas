unit Core.PopupListEx;

interface

uses
  Controls, Menus, Classes;

type
  TPopupMenuEx = class(TPopupMenu)
  private
    FOnClose: TNotifyEvent;
  public
    function Perform(Msg: Cardinal; WParam, LParam: Longint): Longint;

    property OnClose: TNotifyEvent read FOnClose write FOnClose; 
  end;

const
  CM_MENU_CLOSED = CM_BASE + 1001;
  CM_ENTER_MENU_LOOP = CM_BASE + 1002;
  CM_EXIT_MENU_LOOP = CM_BASE + 1003;

implementation

uses
  Messages;

type
  TPopupListEx = class(TPopupList)
  protected
    procedure WndProc(var Message: TMessage) ; override;
  private
    procedure PerformMessage(CM_MSG: integer; Msg: TMessage);
  end;

{ TPopupListEx }

procedure TPopupListEx.PerformMessage(CM_MSG: integer; Msg: TMessage);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do begin
    if (TObject(Items[I]) is TPopupMenuEx) then
      TPopupMenuEx(Items[I]).Perform(CM_MSG, Msg.WParam, Msg.LParam);
  end;
end;

procedure TPopupListEx.WndProc(var Message: TMessage);
begin
  case message.Msg of
    WM_ENTERMENULOOP: PerformMessage(CM_ENTER_MENU_LOOP, Message) ;
    WM_EXITMENULOOP: PerformMessage(CM_EXIT_MENU_LOOP, Message) ;
    WM_MENUSELECT:
      with TWMMenuSelect(Message) do begin
        if (Menu = 0) and (Menuflag = $FFFF) then begin
          PerformMessage(CM_MENU_CLOSED, Message) ;
        end;
      end;
  end;
  inherited;
end;

{ TPopupMenuEx }

function TPopupMenuEx.Perform(Msg: Cardinal; WParam, LParam: Integer): Longint;
begin
  if (Msg = CM_MENU_CLOSED) and Assigned(FOnClose) then
    FOnClose(Self);
  Result := -1;
end;

initialization
  PopupList.Free();
  PopupList:= TPopupListEx.Create();

finalization

end.

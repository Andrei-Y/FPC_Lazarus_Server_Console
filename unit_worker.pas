unit Unit_Worker;

interface

uses
  Classes, SysUtils, Unit_DB;

type
  { Переносим тип сюда, ПЕРЕД описанием класса }
  TLogEvent = procedure(const AMsg: string) of object;
  THTMLEvent = procedure(const AHtml: string) of object; // Добавь это
  TExtractMode = (emToViewer, emToArtist, emToNetwork);
  TWorkerTask = (wtIdle, wtModeration, wtForecast, wtVacuum);
  TArtistGoal = (agWebSync, agDeepAnalysis);

  TServerWorker = class(TThread)
  private
    FDB: TDatabaseModule;
    FOnLog: TLogEvent; // Теперь компилятор знает, что это такое
    FMsgForLog: string;
    FMode: TExtractMode; // Скрытое поле режима
    FOnHtml: THTMLEvent; // Ссылка на вывод HTML
    function RenderNodeHTML(AID, ALevel, ALastLevel: Integer; const AContent: string): string;
    procedure DoLog(const AMsg: string);
    procedure SyncLog;  // Метод для синхронизации ..................................................................................................................
    procedure SyncHtml;
    procedure ArtistDispatcher(AID, ALevel: Integer; const AChrono: string);
   function RenderNodeArtist(AID, ALevel: Integer; const AChrono: string): string;
  protected
    procedure Execute; override;
  public
    FHtmlBuffer: string; // Временный буфер
    FArtistBuffer: string;
    ArtistGoal: TArtistGoal; // Кто нас вызвал?
    constructor Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; AMode: TExtractMode; CreateSuspended: boolean);
    procedure AddMessageTask(AParentID: Integer; AContent: string);
    procedure ExposeSystem(AStartID: Integer);
  end;

  type
  TMapNode = record
    ID, ParentID, Level: Integer;
  end;

implementation

function TServerWorker.RenderNodeArtist(AID, ALevel: Integer; const AChrono: string): string;
begin
  // Формируем простую строку данных для JavaScript: ID|Уровень|Хроно;
  Result := IntToStr(AID) + '|' + IntToStr(ALevel) + '|' + AChrono + ';';
end;

procedure TServerWorker.ArtistDispatcher(AID, ALevel: Integer; const AChrono: string);
begin
  case ArtistGoal of
    agWebSync:
      // Быстрая подготовка данных для JS
      FArtistBuffer := FArtistBuffer + RenderNodeArtist(AID, ALevel, AChrono);

    agDeepAnalysis:
      // Вызов тяжелых методов аналитики, нейросетей и т.д.
//      PerformDeepAnalysis(AID, ALevel); // для будущего анализа
  end;
end;


function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer; const AContent: string): string;
var
  S_Prefix, LineColor: string;
  j: Integer;
begin
  S_Prefix := '';
  for j := 1 to ALevel do
  begin
    LineColor := '#4A90E2';
    if (j = ALevel) then
    begin
      if ALevel < ALastLevel then LineColor := '#FF0000'; // Всплытие
      if ALevel > ALastLevel then LineColor := '#00FFFF'; // Нырок
    end;

    if j < ALevel then
      S_Prefix := S_Prefix + '<font color="#4A90E2">┃&nbsp;&nbsp;</font>'
    else
      S_Prefix := S_Prefix + '<font color="' + LineColor + '">┃(' + IntToStr(ALevel) + ')━&nbsp;</font>';
  end;

  Result :=
    '<table border="0" cellpadding="0" cellspacing="0" width="100%"><tr>' +
    '<td valign="top" style="white-space:nowrap;">' + S_Prefix + '</td>' +
    '<td width="100%">' +
    '<div style="color: #6a9955; font-size: 14px; font-weight: bold; margin-bottom: 4px;">ID: ' + IntToStr(AID) + '</div>' +
    '<table border="1" bordercolor="#2d5a27" cellpadding="10" cellspacing="0" width="100%" bgcolor="#3d3d3d" style="border-collapse: collapse;">' +
    '<tr><td><font color="#FFFFFF">' + AContent + '</font></td></tr></table>' +
    '</td></tr></table><br>';
end;


constructor TServerWorker.Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; AMode: TExtractMode; CreateSuspended: boolean);
begin
  inherited Create(CreateSuspended);
  FDB := ADB;
  FOnLog := ALogEv;
  FOnHtml := AHtmlEv;
  FMode := AMode; // Запоминаем режим при создании
  FreeOnTerminate := True;
end;


procedure TServerWorker.SyncHtml;
begin
  if Assigned(FOnHtml) then FOnHtml(FHtmlBuffer);
end;


procedure TServerWorker.AddMessageTask(AParentID: Integer; AContent: string);
var
  NewID: Integer;
  CheckChrono: string;
begin
  // 1. Приземляем
  NewID := FDB.LandingNode(AParentID, AContent);

  if NewID > 0 then
  begin
    // 2. СРАЗУ ПРОВЕРЯЕМ РОДИТЕЛЯ
    CheckChrono := FDB.GetNodeChrono(AParentID);

    // 3. Докладываем в TMemo
    DoLog('ВОРКЕР: Приземлил ID ' + IntToStr(NewID) +
          '. У родителя ' + IntToStr(AParentID) +
          ' Хроно теперь = "' + CheckChrono + '"');
  end
  else
    DoLog('ВОРКЕР: Ошибка приземления к ID ' + IntToStr(AParentID));
end;



procedure TServerWorker.SyncLog;
begin
  // Вызываем событие лога, которое привязано к твоему TMemo
  if Assigned(FOnLog) then FOnLog(FMsgForLog);
end;

procedure TServerWorker.DoLog(const AMsg: string);
begin
  // Просто выводим в консоль Linux напрямую
  WriteLn('[Worker Log] ' + AMsg);
   // 2. Оставляем механизм для совместимости, но БЕЗ Synchronize
  FMsgForLog := AMsg;
end;




procedure TServerWorker.ExposeSystem(AStartID: Integer);
var
  CurrentID, NodeB, NodeT, i, VisualLevel: Integer;
  Chrono: string;
  StrList: TStringList;
   TailStack: array of Integer; // Теперь это массив чисел, а не строк
    LastLevel: Integer;
       HTML_Acc: TStringBuilder; // Переименовали тип, сохранили имя
begin
  LastLevel := 0;
  TailStack := nil; // Явно говорим компилятору: "Массив пуст, я это знаю"
   HTML_Acc := TStringBuilder.Create;
  // Темная тема: фон #1e1e1e, текст #d4d4d4
  HTML_Acc.Append('<html><body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:15px;">');

  DoLog('--- СТАРТ ФОРМИРОВАНИЯ СТРУКТУРЫ ---');
    WriteLn('   [DEBUG] Создаю списки...');
  CurrentID := AStartID;
  StrList := TStringList.Create;
  SetLength(TailStack, 0);
   // МАЯК Б: После создания
  WriteLn('   [DEBUG] Списки созданы. ID старта: ', AStartID);
  try
    StrList.Delimiter := '.';
    StrList.StrictDelimiter := True;

    while (CurrentID <> 0) do
    begin
      // --- Вот этот "датчик" ---
  if Terminated then Exit;
      Chrono := FDB.GetNodeChrono(CurrentID);
      StrList.DelimitedText := Chrono;
      if StrList.Count < 3 then Break;

      NodeB := StrToIntDef(StrList[1], 0);
      NodeT := StrToIntDef(StrList[2], 0);

      // --- ШАГ 1: НЫРОК ---
      if (NodeT <> 0) and
         ((Length(TailStack) = 0) or (TailStack[High(TailStack)] <> CurrentID)) then
      begin
        DoLog('>>> НЫРОК В ВЕТКУ (из ' + IntToStr(CurrentID) + ')');
        SetLength(TailStack, Length(TailStack) + 1);
        TailStack[High(TailStack)] := CurrentID;
        CurrentID := NodeT;
        Continue;
      end;

      // --- ШАГ 2: ОПРЕДЕЛЯЕМ ВИЗУАЛЬНЫЙ УРОВЕНЬ ---
      // Если узел в стеке — значит это РОДИТЕЛЬ, из которого мы вынырнули.
      // Чтобы дети были ПРАВЕЕ него, его уровень должен быть меньше.
      if (Length(TailStack) > 0) and (TailStack[High(TailStack)] = CurrentID) then
        VisualLevel := Length(TailStack) - 1
      else
        VisualLevel := Length(TailStack);

      // Защита от отрицательного уровня

      if VisualLevel < 0 then VisualLevel := 0;

      // --- ШАГ 3: ФИКСАЦИЯ И ОТРИСОВКА ---

    DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));

    // Вычисляем уровень вложенности
      if (Length(TailStack) > 0) and (TailStack[High(TailStack)] = CurrentID) then
        i := Length(TailStack) - 1
      else
        i := Length(TailStack);

    if (CurrentID <> AStartID) and (i = 0) then i := 1;
    //   LastLevel := i; // возможно понадобится где-то ещё
    // 1. Формируем префикс (только линии и уровень)

     case FMode of //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      emToViewer:
        begin
        // Вызываем генерацию HTML function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer; const AContent: string): string;
         // и сразу кладем в список
        HTML_Acc.Append(RenderNodeHTML(CurrentID, i, LastLevel, FDB.GetNodeContent(CurrentID)));
        LastLevel := i;
        end;

      emToArtist:
        begin
          DoLog('ПОСЫЛКА ХУДОЖНИКУ: ID ' + IntToStr(CurrentID) + ' L:' + IntToStr(VisualLevel));
                    // Просто передаем управление диспетчеру
          ArtistDispatcher(CurrentID, i, Chrono);
        end;

      emToNetwork:
        begin
          // Пока пусто, здесь будет сборка для веб-клиента
        end;

    end; // Конец case
      // --- ШАГ 4: ВСПЛЫТИЕ ---
      if (Length(TailStack) > 0) and (TailStack[High(TailStack)] = CurrentID) then
      begin
         SetLength(TailStack, Length(TailStack) - 1);
         DoLog('<<< ВСПЛЫТИЕ ИЗ ВЕТКИ (возврат в ' + IntToStr(CurrentID) + ')');
      end;

           if (CurrentID = AStartID) and (Length(TailStack) = 0) then Break;
      CurrentID := NodeB;
    end;

    HTML_Acc.Append('</body></html>');
    FHtmlBuffer := HTML_Acc.ToString;
  finally
    HTML_Acc.Free;
    StrList.Free;
  end;
  DoLog('--- СТРУКТУРА ЗАВЕРШЕНА ---');
end;








procedure TServerWorker.Execute;
begin
  while not Terminated do
  begin
    //Sleep(1000);
  end;
end;

end.

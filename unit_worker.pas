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

  TServerWorker = class(TThread)


  private
    FDB: TDatabaseModule;
    FOnLog: TLogEvent; // Теперь компилятор знает, что это такое
    FMsgForLog: string;
    FMode: TExtractMode; // Скрытое поле режима
    FOnHtml: THTMLEvent; // Ссылка на вывод HTML

    // ... остальное

    procedure DoLog(const AMsg: string);
    procedure SyncLog;  // Метод для синхронизации
    procedure SyncHtml;
  protected
    procedure Execute; override;
  public
    FHtmlBuffer: string; // Временный буфер
    constructor Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; AMode: TExtractMode; CreateSuspended: boolean);
    procedure AddMessageTask(AParentID: Integer; AContent: string);
    procedure ExposeSystem(AStartID: Integer);
  end;

  type
  TMapNode = record
    ID, ParentID, Level: Integer;
  end;

implementation

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
  CurrentID, NodeB, NodeT, i, j, VisualLevel: Integer;
  Chrono, NodeContent, S_Open, S_Close, HTML_Row: string;
  StrList, TailStack, HTML_Acc: TStringList;
    S_Prefix: string; // ВОТ ОНА! Добавь эту строчку
    LastLevel: Integer;
      LineColor: string;
begin
  LastLevel := 0;
  HTML_Acc := TStringList.Create;
  // Темная тема: фон #1e1e1e, текст #d4d4d4
  HTML_Acc.Add('<html><body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:15px;">');

  DoLog('--- СТАРТ ФОРМИРОВАНИЯ СТРУКТУРЫ ---');
    WriteLn('   [DEBUG] Создаю списки...');
  CurrentID := AStartID;
  StrList := TStringList.Create;
  TailStack := TStringList.Create;
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
      if (NodeT <> 0) and (TailStack.IndexOf(IntToStr(CurrentID)) = -1) then
      begin
        DoLog('>>> НЫРОК В ВЕТКУ (из ' + IntToStr(CurrentID) + ')');
        TailStack.Add(IntToStr(CurrentID));
        CurrentID := NodeT;
        Continue;
      end;

      // --- ШАГ 2: ОПРЕДЕЛЯЕМ ВИЗУАЛЬНЫЙ УРОВЕНЬ ---
      // Если узел в стеке — значит это РОДИТЕЛЬ, из которого мы вынырнули.
      // Чтобы дети были ПРАВЕЕ него, его уровень должен быть меньше.
      if TailStack.IndexOf(IntToStr(CurrentID)) <> -1 then
        VisualLevel := TailStack.Count - 1
      else
        VisualLevel := TailStack.Count;

      // Защита от отрицательного уровня

      if VisualLevel < 0 then VisualLevel := 0;

      // --- ШАГ 3: ФИКСАЦИЯ И ОТРИСОВКА ---

    DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));

    // Вычисляем уровень вложенности
    if TailStack.IndexOf(IntToStr(CurrentID)) <> -1 then
      i := TailStack.Count - 1
    else
      i := TailStack.Count;

    if (CurrentID <> AStartID) and (i = 0) then i := 1;
    //   LastLevel := i; // возможно понадобится где-то ещё
    // 1. Формируем префикс (только линии и уровень)

     case FMode of

      emToViewer:
        begin
          // Весь твой "шикарный" код отрисовки карточек переезжает сюда:
          NodeContent := FDB.GetNodeContent(CurrentID);

         S_Prefix := '';
    for j := 1 to i do
    begin
      LineColor := '#4A90E2';
      if (j = i) then
      begin
        if i < LastLevel then LineColor := '#FF0000'; // Всплытие
        if i > LastLevel then LineColor := '#00FFFF'; // Нырок
      end;

      if j < i then
        S_Prefix := S_Prefix + '<font color="#4A90E2">┃&nbsp;&nbsp;</font>'
      else
        S_Prefix := S_Prefix + '<font color="' + LineColor + '">┃(' + IntToStr(i) + ')━&nbsp;</font>';
    end;
    LastLevel := i;

    // 2. СТРОИМ СТРУКТУРУ: Заголовок с ID сверху, Карточка снизу
    HTML_Row :=
      '<table border="0" cellpadding="0" cellspacing="0" width="100%">' +
      '<tr>' +
        // Колонка отступа для всей конструкции
        '<td valign="top" style="white-space:nowrap;">' + S_Prefix + '</td>' +
        '<td width="100%">' +
        // 2.1. Заголовок с ID (стал крупнее и чуть ярче)
        '<div style="color: #6a9955; font-size: 14px; font-weight: bold; margin-bottom: 4px;">' +
        'ID: ' + IntToStr(CurrentID) +
        '</div>' +
          // 2.2. Сама карточка сообщения
          '<table border="1" bordercolor="#2d5a27" cellpadding="10" cellspacing="0" width="100%" bgcolor="#3d3d3d" style="border-collapse: collapse;">' +
          '<tr><td>' +
            '<font color="#FFFFFF">' + NodeContent + '</font>' +
          '</td></tr>' +
          '</table>' +
        '</td>' +
      '</tr>' +
      '</table><br>';

    HTML_Acc.Add(HTML_Row);
        end;

      emToArtist:
        begin
          // Режим Художника: только структура
          // Здесь мы НЕ вызываем GetNodeContent — это экономит время
          DoLog('ПОСЫЛКА ХУДОЖНИКУ: ID ' + IntToStr(CurrentID) + ' L:' + IntToStr(VisualLevel));
          // В будущем здесь будет: FArtist.AddPlanet(CurrentID, NodeB, VisualLevel, Chrono);
        end;

      emToNetwork:
        begin
          // Пока пусто, здесь будет сборка для веб-клиента
        end;

    end; // Конец case
      // --- ШАГ 4: ВСПЛЫТИЕ ---
      if TailStack.IndexOf(IntToStr(CurrentID)) <> -1 then
      begin
         TailStack.Delete(TailStack.IndexOf(IntToStr(CurrentID)));
         DoLog('<<< ВСПЛЫТИЕ ИЗ ВЕТКИ (возврат в ' + IntToStr(CurrentID) + ')');
      end;

      if (CurrentID = AStartID) and (TailStack.Count = 0) then Break;
      CurrentID := NodeB;
    end;

    HTML_Acc.Add('</body></html>');
    FHtmlBuffer := HTML_Acc.Text;
        if Assigned(FOnHtml) then SyncHtml;

  finally
    HTML_Acc.Free;
    StrList.Free;
    TailStack.Free;
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

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
    function RenderNodeHTML(AID, ALevel, ALastLevel: Integer;
                            const AContent: string;
                            const AStack: array of Integer): string;

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
        // ВОТ ОНО! Добавь это поле для хранения лимита:
    FMaxNodes: Integer;
        FNextStartID: Integer;
    FSavedStack: string;
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


//function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer; const AContent: string): string;
//var
//  S_Prefix, LineColor: string;
//  j: Integer;
//begin
//  S_Prefix := '';
//  for j := 1 to ALevel do
//  begin
//    LineColor := '#4A90E2';
//    if (j = ALevel) then
//    begin
//      if ALevel < ALastLevel then LineColor := '#FF0000'; // Всплытие
//      if ALevel > ALastLevel then LineColor := '#00FFFF'; // Нырок
//    end;
//
//    if j < ALevel then
//      S_Prefix := S_Prefix + '<font color="#4A90E2">┃&nbsp;&nbsp;</font>'
//    else
//      S_Prefix := S_Prefix + '<font color="' + LineColor + '">┃(' + IntToStr(ALevel) + ')━&nbsp;</font>';
//  end;
//
//  Result :=
//    '<table border="0" cellpadding="0" cellspacing="0" width="100%"><tr>' +
//    '<td valign="top" style="white-space:nowrap;">' + S_Prefix + '</td>' +
//    '<td width="100%">' +
//    '<div style="color: #6a9955; font-size: 14px; font-weight: bold; margin-bottom: 4px;">ID: ' + IntToStr(AID) + '</div>' +
//    '<table border="1" bordercolor="#2d5a27" cellpadding="10" cellspacing="0" width="100%" bgcolor="#3d3d3d" style="border-collapse: collapse;">' +
//    '<tr><td><font color="#FFFFFF">' + AContent + '</font></td></tr></table>' +
//    '</td></tr></table><br>';
//end;

  function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer;
                                       const AContent: string;
                                       const AStack: array of Integer): string;
var
  S_Prefix, LineColor: string;
  j: Integer;
  TargetParentID: Integer;
begin
  S_Prefix := '';

  for j := 1 to ALevel do
  begin
    if (j - 1 >= 0) and (j - 1 < Length(AStack)) then
      TargetParentID := AStack[j - 1]
    else
      TargetParentID := 0;

    if j < ALevel then
      // 1. Промежуточные синие палочки-ссылки
      S_Prefix := S_Prefix + '<a href="#node_' + IntToStr(TargetParentID) +
                  '" style="color:#4A90E2; text-decoration:none; font-weight:bold;">┃</a>&nbsp;&nbsp;'
    else
      begin
        // 2. Последняя палочка: вычисляем её цвет по твоей изначальной логике
        LineColor := '#00FFFF'; // По умолчанию бирюзовый (нырок)
        if ALevel < ALastLevel then LineColor := '#FF0000'; // Всплытие красным

        // Оставляем красивое раздельное оформление, где палочка красится в нужный цвет,
        // но при этом ВСЁ остается кликабельной ссылкой
        S_Prefix := S_Prefix + '<a href="#node_' + IntToStr(TargetParentID) +
                    '" style="color:' + LineColor + '; text-decoration:none; font-weight:bold;">' +
                    '┃(' + IntToStr(TargetParentID) + ')━&nbsp;</a>';
      end;
  end;

  // Оставшаяся часть функции Result := ... остается без изменений
  Result :=
    '<div id="node_' + IntToStr(AID) + '">' +
    '<table border="0" cellpadding="0" cellspacing="0" width="100%"><tr>' +
    '<td valign="top" style="white-space:nowrap;">' + S_Prefix + '</td>' +
    '<td width="100%">' +
      '<div style="color: #6a9955; font-size: 11px; font-weight: bold; margin-bottom: 2px;">ID: ' + IntToStr(AID) + '</div>' +
      '<table border="1" bordercolor="#2d5a27" cellpadding="10" cellspacing="0" width="100%" bgcolor="#3d3d3d" style="border-collapse: collapse;">' +
      '<tr><td>' +
        '<div style="color: #FFFFFF; line-height: 1.4; margin-bottom: 10px;">' + AContent + '</div>' +
        '<div style="border-top: 1px dotted #555; padding-top: 5px; font-size: 11px; display: flex; justify-content: space-between;">' +
          '<a href="/edit?pid='+IntToStr(AID)+'" style="color:#4A90E2; text-decoration:none; font-weight:bold;">[ ДЕЙСТВИЕ ]</a>' +
          '<a href="/report?id='+IntToStr(AID)+'" style="color:#888; text-decoration:none;">[ Позвать бота ]</a>' +
        '</div>' +
      '</td></tr></table>' +
    '</td></tr></table><br></div>';
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
  CurrentID, NodeB, NodeT, VisualLevel: Integer;
  Chrono: string;
  StrList: TStringList;
  TailStack: array of Integer; // Теперь это массив чисел, а не строк
  LastLevel: Integer;
  HTML_Acc: TStringBuilder; // Переименовали тип, сохранили имя
  NodeCount: Integer; // <--- ДОБАВЬ ЭТУ СТРОКУ
begin
    NodeCount := 0;
    if FMaxNodes <= 0 then FMaxNodes := 50; // Страховка
    LastLevel := 0;
    TailStack := nil; // Явно говорим компилятору: "Массив пуст, я это знаю"
    CurrentID := AStartID;
    StrList := TStringList.Create;
    SetLength(TailStack, 0);
          DoLog('--- СТАРТ ФОРМИРОВАНИЯ СТРУКТУРЫ ---');
         {$REGION'ПОДГОТОВКА ПАКЕТА В ДОСТАВКУ'}
    case FMode of
emToViewer:
        begin
    HTML_Acc := TStringBuilder.Create;
    HTML_Acc.Append('<html><body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:15px;">');
        end;
emToArtist:
        begin
        // ПОКА ПУСТО
        end;
        end;
    {$ENDREGION} // КОНЕЦ ПОДГОТОВКИ ПАКЕТА В ДОСТАВКУ
  try
    StrList.Delimiter := '.';
    StrList.StrictDelimiter := True;
    {$REGION 'ЦИКЛ ФОРМИРОВАНИЯ ПАКЕТА СООБЩЕНИЙ'}
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
         ((Length(TailStack) = 0) or (TailStack[High(TailStack)] <> CurrentID)) then  // ЕСЛИ ЭТО КОРЕНЬ, ИЛИ ЭТО УЗЕЛ В ХВОСТ КОТОРОГО МЫ НЕ НЫРЯЛИ, ТО НЫРЯЕМ
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
      else VisualLevel := Length(TailStack);
      // Защита от отрицательного уровня

      if VisualLevel < 0 then VisualLevel := 0;

      // --- ШАГ 3: ФИКСАЦИЯ И ОТРИСОВКА ---

    DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));

    // Вычисляем уровень вложенности
    if (CurrentID <> AStartID) and (VisualLevel = 0) then VisualLevel := 1;
    //   LastLevel := i; // возможно понадобится где-то ещё
    // 1. Формируем префикс (только линии и уровень)

    {$REGION 'ЗАПЕКАНИЕ СООБЩЕНИЯ'}

     case FMode of //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      emToViewer:
        begin
        // Вызываем генерацию HTML function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer; const AContent: string): string;
         // и сразу кладем в список
        HTML_Acc.Append(RenderNodeHTML(CurrentID, VisualLevel, LastLevel, FDB.GetNodeContent(CurrentID), TailStack));
        LastLevel := VisualLevel;
        end;

      emToArtist:
        begin
        // Пока пусто
        end;

      emToNetwork:
        begin
          // Пока пусто
        end;

    end; // Конец case

                     // ВОТ СЮДА МЫ ПЕРЕМЕЩАЕМ ОБРЫВАНИЕ ЦИКЛА:
          Inc(NodeCount);
          if NodeCount >= FMaxNodes then
          begin
            WriteLn('   [ВОРКЕР] Достигнут лимит пилота в ', FMaxNodes, ' узлов. Эстафета прервана на ID: ', CurrentID);
            Break; // Мгновенно выходим из цикла while, завершая генерацию страницы
          end;

    {$ENDREGION}
      // --- ШАГ 4: ВСПЛЫТИЕ ---
      if (Length(TailStack) > 0) and (TailStack[High(TailStack)] = CurrentID) then
      begin
         SetLength(TailStack, Length(TailStack) - 1);
         DoLog('<<< ВСПЛЫТИЕ ИЗ ВЕТКИ (возврат в ' + IntToStr(CurrentID) + ')');
      end;

           if (CurrentID = AStartID) and (Length(TailStack) = 0) then Break;
      CurrentID := NodeB;
    end;
    {$ENDREGION} // КОНЕЦ ЦИКЛА ФОРМИРОВАНИЯ ПАКЕТА

    {$REGION'ПЕРЕДАЧА ПАКЕТА В ДОСТАВКУ'}
    case FMode of
emToViewer:
        begin
    HTML_Acc.Append('</body></html>');
    HTML_Acc.Append('<div style="text-align:center; margin:20px;"><a href="/forum?start=' + IntToStr(FNextStartID) + '&stack=' + FSavedStack + '" style="...">👉 Загрузить еще сообщения</a></div>');
    FHtmlBuffer := HTML_Acc.ToString;
        end;
emToArtist:
        begin
        // ПОКА ПУСТО
        end;
        end;
    {$ENDREGION} // КОНЕЦ ПЕРЕДАЧИ ПАКЕТА В ДОСТАВКУ
    finally
      // ЮВЕЛИРНАЯ И БЕЗОПАСНАЯ ОЧИСТКА:
      if Assigned(HTML_Acc) then HTML_Acc.Free;
      if Assigned(StrList) then StrList.Free;
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

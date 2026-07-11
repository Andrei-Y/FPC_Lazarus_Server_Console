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
   TIntStack = array of Integer;

  TServerWorker = class(TThread)
  private
    FDB: TDatabaseModule;
    FOnLog: TLogEvent; // Теперь компилятор знает, что это такое
    FMsgForLog: string;
    FMode: TExtractMode; // Скрытое поле режима
    FOnHtml: THTMLEvent; // Ссылка на вывод HTML

    function RenderNodeHTML(AID, ALevel, ALastLevel: Integer;
                            const AContent: string;
                            const AStack: TIntStack; AIsParent: Boolean): string;

    procedure DoLog(const AMsg: string);
    procedure SyncLog;  // Метод для синхронизации ..................................................................................................................
    procedure SyncHtml;
    procedure ArtistDispatcher(AID, ALevel: Integer; const AChrono: string);
   function RenderNodeArtist(AID, ALevel: Integer; const AChrono: string): string;
  protected
    procedure Execute; override;
  public
       FChunk: Boolean; // ⚡ ВОЗВРАЩАЕМ НАШЕ ЛОГИЧЕСКОЕ ПОЛЕ СЮДА
    FHtmlBuffer: string; // Временный буфер
    FArtistBuffer: string;
        // ВОТ ОНО! Добавь это поле для хранения лимита:
    FMaxNodes: Integer;
        FNextStartID: Integer;
    FSavedStack: string;
        // ⚡ ДЕЛАЕМ МАССИВ ГЛОБАЛЬНЫМ ПОЛЕМ КЛАССА В ОЗУ:
    TailStack: TIntStack;
    ArtistGoal: TArtistGoal; // Кто нас вызвал?
    constructor Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; AMode: TExtractMode; CreateSuspended: boolean);
    procedure AddMessageTask(AParentID: Integer; AContent: string);
    procedure ExposeSystem( AStrRaw: string);
        function StackToString(const AStack: TIntStack): string;
    procedure StringToStack(const AStr: string);
  end;

  type
  TMapNode = record
    ID, ParentID, Level: Integer;
  end;

implementation

// 1. МЕТОД УПАКОВКИ: Твой быстрый StringBuilder (Green Computing)
function TServerWorker.StackToString(const AStack: TIntStack): string;
var
  j: Integer;
  SB: TStringBuilder;
begin
  Result := '';
  if Length(AStack) = 0 then Exit;
  SB := TStringBuilder.Create;
  try
    for j := 0 to High(AStack) do
    begin
      SB.Append(IntToStr(AStack[j]));
      if j < High(AStack) then SB.Append(',');
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// 2. МЕТОД РАСПАКОВКИ: Разворачивает прилетевшие запятые '1,5,12' обратно в ОЗУ
procedure TServerWorker.StringToStack(const AStr: string);
var
  List: TStringList;
  j: Integer;
begin
  // Напрямую чистим и заполняем поле текущего объекта класса
  SetLength(TailStack, 0);
  WriteLn(AStr);
  if AStr = '' then Exit;

  List := TStringList.Create;
  try
    List.Delimiter := ',';
    List.StrictDelimiter := True;
    List.DelimitedText := AStr;

    SetLength(TailStack, List.Count);
    for j := 0 to List.Count - 1 do
    begin
      TailStack[j] := StrToIntDef(List[j], 0);
    end;
       WriteLn('Извлекаем'+StackToString(TailStack));
  finally
    List.Free;
  end;
   if (Length(TailStack) > 0) and (TailStack[High(TailStack)] = FNextStartID) then
    begin
      WriteLn(' [ОЗУ ПРЕДОХРАНИТЕЛЬ] Поймано равенство на узле ', FNextStartID, '.  Не Выталкиваем из стека!');
    end;
end;



function RenderAjaxButton(ANextID: Integer; ASavedStack: string): string;
begin
  Result :=
    '<div id="ajax-gate-container" style="text-align:center; margin:20px 0; clear:both; display:block;">' +
    '  <button onclick="fetch(''/forum_chunk?start=' + IntToStr(ANextID) + '&stack=' + ASavedStack + ''')' +
    '    .then(r => r.text()).then(html => {' +
    '       document.getElementById(''ajax-gate-container'').insertAdjacentHTML(''beforebegin'', html);' +
    '       document.getElementById(''ajax-gate-container'').remove();' +
    '    });" ' +
    '    style="color:#00FFFF; background:#252526; border:1px dashed #555; padding:8px 16px; border-radius:4px; font-weight:bold; cursor:pointer;">' +
    '     👉 Загрузить еще сообщения' +
    '  </button>' +
    '</div>';
end;

//function StackToString(const AStack: TIntStack): string;
//var
//  j: Integer;
//  SB: TStringBuilder;
//begin
//  Result := '';
//  if Length(AStack) = 0 then Exit;
//  SB := TStringBuilder.Create;
//  try
//    for j := 0 to High(AStack) do
//    begin
//      SB.Append(IntToStr(AStack[j]));
//      if j < High(AStack) then SB.Append(',');
//    end;
//    Result := SB.ToString;
//  finally
//    SB.Free;
//  end;
//end;

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


  function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer;
                                       const AContent: string;
                                       const AStack: TIntStack; AIsParent: Boolean): string;
var
  S_Prefix, LineColor: string;
  j: Integer;
  TargetParentID: Integer;
  ButtonGateStack: string;
begin
    if AIsParent then
    ButtonGateStack := StackToString(AStack)
  else
    ButtonGateStack := StackToString(AStack) + ',' + IntToStr(AID);
    //////////////////////////////////////////////

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
                  '" style="color:#4A90E2; text-decoration:none; font-weight:bold;">┊</a>&nbsp;&nbsp;'
    else
      begin
        // 2. Последняя палочка: вычисляем её цвет по твоей изначальной логике
        LineColor := '#00FFFF'; // По умолчанию бирюзовый (нырок)
        if ALevel < ALastLevel then LineColor := '#FF0000'; // Всплытие красным

        // Оставляем красивое раздельное оформление, где палочка красится в нужный цвет,
        // но при этом ВСЁ остается кликабельной ссылкой
        S_Prefix := S_Prefix + '<a href="#node_' + IntToStr(TargetParentID) +
                    '" style="color:' + LineColor + '; text-decoration:none; font-weight:bold;">' +
                    '┊(' + IntToStr(TargetParentID) + ')━&nbsp;</a>';
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
          '<a href="/edit?pid='+ IntToStr(AID) + '&gate_stack=' + ButtonGateStack + '" ' +
                     '    style="color: #00FFFF; text-decoration: none; font-size: 12px; font-weight: bold; ' +
                     '           margin-left: 8px; border-bottom: 1px dashed #00FFFF;">' +
                     '    ↩ Ответить' +
                     ' </a>' + //////////////////////////////////////
          '<a href="/report?id='+IntToStr(AID)+'" style="color:#888; text-decoration:none;">[ Позвать бота ]</a>' +
        '</div>' +
      '</td></tr></table>' +
    '</td></tr></table><br></div>';
  ///////////////////////////////////////////////////////////

end;



constructor TServerWorker.Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; AMode: TExtractMode; CreateSuspended: boolean);
begin
  inherited Create(CreateSuspended);
  FDB := ADB;
  FOnLog := ALogEv;
  FOnHtml := AHtmlEv;
  FMode := AMode; // Запоминаем режим при создании
 // FreeOnTerminate := True;
  // ⚡ ФИКСИРУЕМ ФЛАГ: Если сервер создал воркер в режиме чанка, поле FChunk станет True!
  //FChunk := False;
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




procedure TServerWorker.ExposeSystem(AStrRaw: string);
var
  CurrentID, NodeB, NodeT, VisualLevel: Integer;
  Chrono: string;
  StrList, NetParser: TStringList;
  LastLevel: Integer;
  HTML_Acc: TStringBuilder;
  NodeCount: Integer;
  IsParentNode: Boolean;
  AStartID: Integer;
begin
    NodeCount := 0;
    NetParser := TStringList.Create;
    LastLevel := 0;
    ////////////////////////////////////////////////////////////////////////
    try
    NetParser.Delimiter := '&'; // Разделитель параметров в HTTP-строке (start=11&stack=1,4,7,9)
    //NetParser.StrictDelimiter := True;
    //NetParser.DelimitedText := AStrRaw;
    NetParser.Text := AStrRaw;
    DoLog('AStrRaw = ??? ' + AStrRaw);
    // Записываем данные СТРОГО в твоё родное поле класса из репозитория!
    AStartID := StrToIntDef(NetParser.Values['start'], 0);
    DoLog(' AStartID = ' + IntToStr(AStartID));
    FSavedStack := NetParser.Values['stack'];
    DoLog('>>> Обходим в ' + FSavedStack + ')');

    // 🎯 ЗАЩИТА ГЛАВНОЙ СТРАНИЦЫ: Если строка пуста (первый заход), принудительно стартуем с корня 1
    if AStartID = 0 then
    begin
      AStartID := 1;
    end;
  finally
    NetParser.Free;
  end;

          DoLog('>>> Обходим в ' + IntToStr(FNextStartID) + ')');
  //if FChunk then //////////////////////////////////////////////////////////////
  //begin
  //  StringToStack(AStrStack);
  //  if (Length(TailStack) > 0) and (TailStack[High(TailStack)] = AStartID) then
  //begin
  //  //WriteLn('Условие проверки выполнено');
  //  DoLog('>>> Условие проверки выполнено' );
  //  // 1. Выводим головной узел в буфер, используя правильное локальное имя билдера!
  //  HTML_Acc.Append(RenderNodeHTML(
  //    AStartID,
  //    High(TailStack),
  //    High(TailStack),
  //    FDB.GetNodeContent(AStartID),
  //    TailStack,
  //    True
  //  ));
  //
  //  // 2. Извлекаем строку хронологии, чтобы узнать ID предшественника (NodeB)
  //  StrList := TStringList.Create;
  //  try
  //    StrList.Delimiter := ',';
  //    StrList.StrictDelimiter := True;
  //    StrList.DelimitedText := FDB.GetNodeChrono(AStartID);
  //
  //    // Сдвигаем стартовую координату цикла на предшественника (NodeB), пролетая мимо хвоста!
  //    if StrList.Count >= 2 then
  //      FNextStartID := StrToIntDef(StrList[1], 0);
  //    AStartID := FNextStartID;
  //    //WriteLn('Обходим в '+IntToStr(AStartID));
  //    DoLog('>>> Обходим в ' + IntToStr(AStartID) + ')');
  //  finally
  //    StrList.Free;
  //  end;
  //           SetLength(TailStack, Length(TailStack) - 1);
  //                           Inc(NodeCount);
  //end;
  //
  //end;
    if FChunk then
  begin
    StringToStack(FSavedStack);
        DoLog('>>> Обходим в ' + FSavedStack + ')');


  // 3. ⚡ ЗРЯЧИЙ СДВИГ ПОРШНЯ (СКЛЕЙКА СЛОЕВ НА СТЫКЕ ЧАНКОВ):
  // Работаем строго с твоим полем класса FNextStartID
  if FChunk and (Length(TailStack) > 0) and (TailStack[High(TailStack)] = FNextStartID) then
  begin
    DoLog('>>> Условие проверки выполнено на узелке ' + IntToStr(FNextStartID));

    // Выводим головную карточку стыка
    HTML_Acc.Append(RenderNodeHTML(
      AStartID,
      High(TailStack),
      High(TailStack),
      FDB.GetNodeContent(AStartID),
      TailStack,
      True
    ));

    // Извлекаем строку хронологии предшественников
    StrList := TStringList.Create;
    try
      StrList.Delimiter := ','; // Наша родная запятая из базы данных SQLite
      StrList.StrictDelimiter := True;
      StrList.DelimitedText := FDB.GetNodeChrono(AStartID);

      // Сдвигаем поршень старта на предшественника NodeB (индекс 1) через Strings
      if StrList.Count >= 2 then
      begin
        FNextStartID := StrToIntDef(StrList.Strings[1], 0); // Твой Strings-индекс
        DoLog('>>> Обход сдвинут на предшественника: ' + IntToStr(FNextStartID) + ')');
      end;
    finally
      StrList.Free;
    end;

    // Почистили край массива, учли выведенный узел и погасили детонатор чанка
    SetLength(TailStack, Length(TailStack) - 1);
    Inc(NodeCount);
  end;
  FChunk := False;
    end;
  //////////////////////////////////////////////////////////////////////////////////////////////
//    TailStack := nil;
    CurrentID := AStartID;
    StrList := TStringList.Create;
//    SetLength(TailStack, 0);
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
      // Чтобы дети были ПРАВЕЕ него, его уровень должен быть меньше.////////////////////////////////////////////////////////////////////////////
      IsParentNode := (Length(TailStack) > 0) and (TailStack[High(TailStack)] = CurrentID);
      if IsParentNode then
     VisualLevel := Length(TailStack) - 1
      else
        VisualLevel := Length(TailStack);
      // Защита от отрицательного уровня
      if VisualLevel < 0 then VisualLevel := 0;
      // --- ШАГ 3: ФИКСАЦИЯ И ОТРИСОВКА ---
    //DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));
    // Вычисляем уровень вложенности
    if (CurrentID <> FNextStartID) and (VisualLevel = 0) then VisualLevel := 1;
    //   LastLevel := i; // возможно понадобится где-то ещё
    // 1. Формируем префикс (только линии и уровень)

    {$REGION 'ЗАПЕКАНИЕ СООБЩЕНИЯ'}

     case FMode of //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      emToViewer:
        begin
        // Вызываем генерацию HTML function TServerWorker.RenderNodeHTML(AID, ALevel, ALastLevel: Integer; const AContent: string): string;
         // и сразу кладем в список
        HTML_Acc.Append(RenderNodeHTML(CurrentID, VisualLevel, LastLevel, FDB.GetNodeContent(CurrentID), TailStack, IsParentNode));
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


    {$ENDREGION}
    // --- ШАГ 4: ВСПЛЫТИЕ ---
      if IsParentNode then ////////////////////////////////////////////////////////////////////////
      begin
         SetLength(TailStack, Length(TailStack) - 1);
         DoLog('<<< ВСПЛЫТИЕ ИЗ ВЕТКИ (возврат в ' + IntToStr(CurrentID) + ')');
      end;

           if (CurrentID = FNextStartID) and (Length(TailStack) = 0) then begin
             FSavedStack := StackToString(TailStack);
            FNextStartID := CurrentID;
            WriteLn('Запекаем'+IntToStr(FNextStartID)+ 'стёк-'+FSavedStack+'NodeB='+IntToStr(CurrentID));
             Break;
           end;
      CurrentID := NodeB;
                Inc(NodeCount);
          if NodeCount >= FMaxNodes then
          begin
            FSavedStack := StackToString(TailStack);
            FNextStartID := CurrentID;
            WriteLn('Запекаем'+IntToStr(FNextStartID)+ 'стёк-'+FSavedStack+'NodeB='+IntToStr(CurrentID));
            Break; // Очищаем ОЗУ и мгновенно выходим
          end;
    end;
    {$ENDREGION} // КОНЕЦ ЦИКЛА ФОРМИРОВАНИЯ ПАКЕТА

    {$REGION'ПЕРЕДАЧА ПАКЕТА В ДОСТАВКУ'}
    case FMode of
emToViewer:

  begin
        // ⚡ 1. ЕСЛИ ЦИКЛ ПРЕРВАН ПО ЛИМИТУ — СРАЗУ ГЕНЕРИРУЕМ КНОПКУ:
        if NodeCount >= FMaxNodes then
        begin
          // ТвойStringBuilder упаковывает бинарный канат в строку '1,5,12'
//          FSavedStack := StackToString(TailStack);

          // Вызываем твою автономную утилиту кнопки!
                      WriteLn('Запекаем'+IntToStr(FNextStartID)+ 'стёк-'+FSavedStack+'NodeB='+IntToStr(CurrentID));
          HTML_Acc.Append(RenderAjaxButton(FNextStartID, FSavedStack));


        end;

        // ⚡ 2. ЗАКРЫВАЕМ СТРАНИЦУ СТРОГО ДЛЯ ГЛАВНОГО ОКНА (ЕСЛИ ЭТО НЕ ЧАНК):
        // Используем твое реальное поле из репозитория — FChunk!
        if not FChunk then
        begin
          HTML_Acc.Append('</body></html>');
        end;

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

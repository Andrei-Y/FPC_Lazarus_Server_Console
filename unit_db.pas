unit Unit_DB;

{$mode objfpc}{$H+}
interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, DateUtils;

type
  TDatabaseModule = class
  private
    FConn: TSQLite3Connection;
    FTran: TSQLTransaction;
    FQuery: TSQLQuery;
  public
    constructor Create(ADBPath: string);
    destructor Destroy; override;
   // Получить физический ID из постоянного (Маппинг)
    function GetPhysicalID(APermanentID: Integer): Integer;
    // Добавление узла с автоматическим созданием маппинга
    function AddNode(AParentID: Integer; AContent: string; AX, AY: Double): Integer;
    // Получение данных для пульсации и рендера
    procedure GetSystemData(ARootID: Integer; AList: TList);
    procedure ExecuteMaintenance; // Для запуска VACUUM воркером
      function GetTailFromDB(AID: Integer): Integer;
      function GetNodeChronoFromDB(AID: Integer): string;
      function LandingNode(AParentID: Integer; AContent: string): Integer;
      //function LandingNode(AParentID: Integer; AContent: string; const ATailStackStr: string): Integer;

      function GetNodeChrono(AID: Integer): string;
      function GetNodeContent(AID: Integer): string;
//      function RegisterUser(const AName, APassHash: string; AProfileNodeID: Integer = 0): Boolean;
   function VerifyUser(const AName, APassHash: string): Boolean;//    function VerifyUser(const AName, APassHash: string; out AUserID, ANodesLimit: Integer; out ATheme: string): Boolean;
      procedure ExecSQL(const ASQL: string);
      function CreateHead(AContent: string): Integer;
      procedure GetUserLimit(const AName: string; out ANodesLimit, ADepthLimit: Integer);
  function UpdateUserPrefs(const AName: string; ALimit, ADepthLimit: Integer): Boolean;
  function GetUserRank(const AUsername: string): Integer;
   function RegisterUser(const AUser, APass: string): Boolean; //  рабочая функция
  function LogBotAttempt(const AMachineName: string; AIsMiss: Boolean): Integer; // НОВЫЙ МЕТОД ЩИТА
  function IsUsernameBusy(const AUsername: string): Boolean;// проверка совпадения ника с существующим в таблицах
  procedure AddPending(const AToken, AUser, AEmail, APasswordHash: string);
  function ConfirmRegistration(const AToken: string): Boolean;

  end;

implementation

//procedure TDatabaseModule.AddPending(const AToken, AUser, AEmail: string);
//begin
//  FQuery.Close;
//  FQuery.SQL.Text := 'INSERT INTO pending_registrations (token, username, email) VALUES (' +
//                     QuotedStr(AToken) + ', ' + QuotedStr(AUser) + ', ' + QuotedStr(AEmail) + ');';
//  FQuery.ExecSQL;
//    WriteLn(' Запись пользователя произведена "', AUser);
//end;

 procedure TDatabaseModule.AddPending(const AToken, AUser, AEmail, APasswordHash: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'INSERT INTO pending_registrations (token, username, email, password) VALUES (' +
                     QuotedStr(AToken) + ', ' + QuotedStr(AUser) + ', ' + QuotedStr(AEmail) + ', ' + QuotedStr(APasswordHash) + ');';
  FQuery.ExecSQL;

  // 🎯 ВРЕЗАЕМ СНАЙПЕРСКИЙ КОММИТ: Принудительно впекаем данные в кремний диска!
  FTran.CommitRetaining; // или просто FTran.Commit; в зависимости от твоей структуры

  WriteLn(' Запись пользователя произведена "', AUser, '"');
end;


  function TDatabaseModule.IsUsernameBusy(const AUsername: string): Boolean;
var
  FoundCount: Integer; // Временный цифровой фиксатор
begin
  Result := False;
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT COUNT(*) FROM (' +
                     '  SELECT 1 FROM users WHERE username = ' + QuotedStr(AUsername) +
                     '  UNION ALL ' +
                     '  SELECT 1 FROM pending_registrations WHERE username = ' + QuotedStr(AUsername) +
                     ');';
  FQuery.Open;

  // Считываем точную цифру из первой ячейки СУБД [1.3]
  FoundCount := FQuery.Fields[0].AsInteger;

  // 🎯 ВЫВОД В КОНСОЛЬ JUNI BOX:
  WriteLn(' ');
  WriteLn(' 📡 [РАДАР СУБД] Проверка позывного: "', AUsername, '"');
  if FoundCount = 0 then
    WriteLn('    -> Совпадений не найдено! Путь свободен.')
  else
    WriteLn('    -> ВНИМАНИЕ! Найдено совпадений: ', FoundCount, '. Вход заблокирован.');
  WriteLn(' ');

  // Бронированный контроль на основе считанного числа
  if FoundCount > 0 then
    Result := True;
  WriteLn('    [ФИНАЛ СУБД] Функция IsUsernameBusy возвращает значение -> ', Result);
  FQuery.Close;
end;


function TDatabaseModule.CreateHead(AContent: string): Integer;
begin
  Result := -1;
  if not FTran.Active then FTran.StartTransaction;
  try
    FQuery.Close;
    // Создаем голову с начальной хронологией Тип 1 (Голова)
    FQuery.SQL.Text := 'INSERT INTO nodes (content, chronology) VALUES (:cnt, ''1.0.0.'') RETURNING id;';
    FQuery.ParamByName('cnt').AsString := AContent;
    FQuery.Open;
    Result := FQuery.Fields[0].AsInteger;
    FQuery.Close;
    FTran.CommitRetaining;
  except
    on E: Exception do begin FTran.RollbackRetaining; raise; end;
  end;
end;


procedure TDatabaseModule.ExecSQL(const ASQL: string);
begin
  if not FTran.Active then FTran.StartTransaction;
  try
    FQuery.Close;
    FQuery.SQL.Text := ASQL;
    FQuery.ExecSQL;
    FTran.CommitRetaining; // Сохраняем изменения, но оставляем транзакцию живой
  except
    on E: Exception do begin FTran.RollbackRetaining; raise; end;
  end;
end;


function TDatabaseModule.GetNodeChrono(AID: Integer): string;
begin
  Result := '';

   //МАЯК 1: Проверка соединения
  if not Assigned(FConn) or not FConn.Connected then
  begin
    WriteLn('!!! [БАЗА] ОШИБКА: FConn не подключен !!!');
    Exit;
  end;
  try
    FQuery.Close;
    FQuery.SQL.Text := 'SELECT chronology FROM nodes WHERE id = :id';
    FQuery.ParamByName('id').AsInteger := AID;

     WriteLn('   [БАЗА] Выполняю запрос для ID: ', AID); // МАЯК 2
    FQuery.Open;

    if not FQuery.EOF then
    begin
      Result := FQuery.Fields[0].AsString;
      WriteLn('   [БАЗА] Найдено Chrono: "', Result, '"'); // МАЯК 3
    end
    else
      WriteLn('   [БАЗА] ПРЕДУПРЕЖДЕНИЕ: ID ', AID, ' не найден в таблице!');

    FQuery.Close;
  except
    on E: Exception do
      WriteLn('!!! [БАЗА] КРИТИЧЕСКАЯ ОШИБКА: ', E.Message);
  end;
end;

//function TDatabaseModule.LandingNode(AParentID: Integer; AContent: string): Integer;
//var
//  ParentChrono, OldTailID, NewChrono, UpdatedParentChrono: string;
//  Parts, NewParts: TStringArray;
//  NewID: Integer;
//begin
//  Result := -1;
//  if not FTran.Active then FTran.StartTransaction;
//  try
//        // 1. Узнаем, кто сейчас хвост у предшественника (AParentID)
//    ParentChrono := GetNodeChrono(AParentID);
//    Parts := ParentChrono.Split('.');
//
//    if Length(Parts) > 2 then
//      OldTailID := Parts[2]
//    else
//      OldTailID := '0';
//    // Если хвоста у родителя нет (0), то наш "предшественник" — это сам родитель (AParentID)
//    if OldTailID = '0' then
//       OldTailID := IntToStr(AParentID);
//
//    // Теперь NewChrono будет "0.ParentID.0", а не "0.0.0"
//    NewChrono := '0.' + OldTailID + '.0.';
////    NewChrono := '0.' + OldTailID + '.0.';
//
//    // Вставляем новый узел
//    FQuery.Close;
//
//// ЮВЕЛИРНАЯ СБОРКА ТЕКСТОВОГО ЗАПРОСА С ДЕЙСТВУЮЩИМИ КООРДИНАТАМИ-ЗАГЛУШКАМИ
//FQuery.SQL.Text := 'INSERT INTO nodes (content, chronology, activity_index) VALUES (' +
//                   QuotedStr(AContent) + ', ' + QuotedStr(NewChrono) + ', 1.0) RETURNING id;';
//
//// Открываем запрос, так как SQLite вернет нам ID новой записи через RETURNING
//FQuery.Open;
//NewID := FQuery.Fields[0].AsInteger;
//FQuery.Close;
//    //////// ниже до комментария надо удалить
//     FQuery.SQL.Text := 'SELECT content FROM nodes WHERE id = last_insert_rowid();';
//    FQuery.Open;
//    WriteLn('[DIAG] РЕАЛЬНО ЗАПИСАНО В ТАБЛИЦУ: "', FQuery.Fields[0].AsString, '"');
//    FQuery.Close;
//    // ОБНОВЛЯЕМ РОДИТЕЛЯ
//    Parts[2] := IntToStr(NewID); // Теперь индекс 2 точно есть
//    UpdatedParentChrono := string.Join('.', Parts);
//
//    FQuery.SQL.Text := 'UPDATE nodes SET chronology = :nc WHERE id = :id';
//    FQuery.ParamByName('nc').AsString := UpdatedParentChrono;
//    FQuery.ParamByName('id').AsInteger := AParentID;
//    FQuery.ExecSQL;
//
//    FTran.CommitRetaining;
//    Result := NewID;
//  except
//    on E: Exception do begin FTran.RollbackRetaining; raise; end;
//  end;
//end;

function TDatabaseModule.LandingNode(AParentID: Integer; AContent: string): Integer;
var
  ParentChrono, OldTailID, NewChrono, UpdatedParentChrono, UpdatedTailChrono: string;
  Parts, NewParts: TStringArray;
  NewID: Integer;
begin
    Result := -1;
  if not FTran.Active then FTran.StartTransaction;
  try
     ParentChrono := GetNodeChrono(AParentID);
     Parts := ParentChrono.Split('.');
         if Length(Parts) > 2 then
      OldTailID := Parts[2];
  // =========================================================================
    //  ШАГ 1: СБОРКА NEWPARTS (Индексы 0..6, длина 7) СТРОГО ЧЕРЕЗ МАССИВЫ
    // =========================================================================
    SetLength(NewParts, 7);
    NewParts[0] := '0';          // Собственный ID нового узла (на случай)
    //NewParts[1] := IntToStr(AParentID);    // предшественник
        if OldTailID = '0' then
      NewParts[1] := IntToStr(AParentID)
    else
      NewParts[1] := OldTailID;
    NewParts[2] := '0';          // Окончание собственного хвоста пока нет
    NewParts[3] := '0';          // Последователя пока нет
    NewParts[4] := '0';          // Начало собственного хвоста пока нет

    //  НАШЕ СВЯЩЕННОЕ НАСЛЕДОВАНИЕ СТЕКА: Стек предка + ',' + ID самого предка
    // Выуживаем прямо из уже поднятого на строке 7 массива Parts!
    if (Length(Parts) > 5) and (Parts[5] <> '') then
      NewParts[5] := Parts[5] + ',' + IntToStr(AParentID)
    else
      NewParts[5] := IntToStr(AParentID);

    NewParts[6] := ''; // Замыкающая точка

    NewChrono := string.Join('.', NewParts);
  /////////////////////////////////////////////////////////////////////////////////////////////////////////
      // =========================================================================
    //  ШАГ 2: Новый узел в базу и перехват его ID
    // =========================================================================
    FQuery.Close;
    FQuery.SQL.Text := 'INSERT INTO nodes (content, chronology, activity_index) VALUES (' +
                       QuotedStr(AContent) + ', ' + QuotedStr(NewChrono) + ', 1.0) RETURNING id;';
    FQuery.Open;
    NewID := FQuery.Fields[0].AsInteger;
    FQuery.Close;

    // =========================================================================
    //  ШАГ 3: Впекаем NewID в хронологию нового узла!
    // =========================================================================
    NewParts[0] := IntToStr(NewID);
    NewChrono := string.Join('.', NewParts);

    FQuery.SQL.Text := 'UPDATE nodes SET chronology = :nc WHERE id = :id';
    FQuery.ParamByName('nc').AsString := NewChrono;
    FQuery.ParamByName('id').AsInteger := NewID;
    FQuery.ExecSQL;
    // =========================================================================
    //  ШАГ 4: Указание конца и начала хвоста
    // =========================================================================
    // Если OldTailID  равен '0', значит, предшественником нового узла
    // является корневой узел, а не его хвост, и тогда новый узел является и началом и концом хвоста, состоящего всего из одного узла.
    if OldTailID = '0' then
    begin
     Parts[2] := IntToStr(NewID);//конец хвоста
     Parts[4] := IntToStr(NewID);//начало хвоста
        // Склеиваем массив обратно в дисковую строку хронологии
        UpdatedParentChrono := string.Join('.', Parts);

        // Запекаем обновленный двухсвязный паспорт предшественника на диск SQLite3!
        FQuery.SQL.Text := 'UPDATE nodes SET chronology = :nc WHERE id = :id';
        FQuery.ParamByName('nc').AsString := UpdatedParentChrono;
        FQuery.ParamByName('id').AsInteger := AParentID;

        FQuery.ExecSQL;
    end else

    // =========================================================================
    //  ШАГ 5: Указание хвоста и последователя в разных узлах
    // =========================================================================
    // Если OldTailID  не равен '0'
    // Обновляем родителю индекс 2 — прописываем туда наш NewID как край нового хвоста
    Parts[2] := IntToStr(NewID);
    UpdatedParentChrono := string.Join('.', Parts);

    FQuery.SQL.Text := 'UPDATE nodes SET chronology = :nc WHERE id = :id';
    FQuery.ParamByName('nc').AsString := UpdatedParentChrono;
    FQuery.ParamByName('id').AsInteger := AParentID;
    FQuery.ExecSQL;
    // Обновляем последователя в окончании хвоста
    UpdatedTailChrono := GetNodeChrono(StrToIntDef(OldTailID, 0));
    Parts := UpdatedTailChrono.Split('.');
    Parts[3]:= IntToStr(NewID);
    UpdatedTailChrono := string.Join('.', Parts);
    FQuery.SQL.Text := 'UPDATE nodes SET chronology = :nc WHERE id = :id';
    FQuery.ParamByName('nc').AsString := UpdatedTailChrono;
    FQuery.ParamByName('id').AsInteger := StrToIntDef(OldTailID, 0);
    FQuery.ExecSQL;

    FTran.CommitRetaining;
    Result := NewID;

  except
    on E: Exception do begin FTran.RollbackRetaining; raise; end;
  end;
end;

constructor TDatabaseModule.Create(ADBPath: string);
begin
  inherited Create; // Хороший тон для классов

  FConn := TSQLite3Connection.Create(nil);
  FTran := TSQLTransaction.Create(FConn);
  FQuery := TSQLQuery.Create(nil);

  FConn.Transaction := FTran;
  FQuery.Database := FConn;
  FQuery.Transaction := FTran;

  // Указываем полный путь к базе в папке с программой
  FConn.DatabaseName := ExtractFilePath(ParamStr(0)) + ADBPath;

  try
    //FConn.Open;
    //FTran.Active := True;
    //
    //// Включаем режим WAL и быструю синхронизацию для оптимизации I/O
    //FConn.ExecuteDirect('PRAGMA journal_mode=WAL;');
    //FConn.ExecuteDirect('PRAGMA synchronous=NORMAL;');
    FConn.Open;

    // ЭТИ СТРОКИ ОСТАВЛЯЕМ (Они безопасны внутри транзакций)
    //FConn.ExecuteDirect('PRAGMA synchronous=NORMAL;');
    //FConn.ExecuteDirect('PRAGMA busy_timeout = 5000;');

    // СТРОКУ С WAL ПОЛНОСТЬЮ УДАЛЯЕМ ИЗ КОДА!

    FTran.Active := True;

    // ... дальше твой стандартный код создания таблиц ...

    // Создаем таблицы
    // 1. Nodes - Хранилище данных
    //FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS nodes (' +
    //      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    //      'content TEXT, ' +
    //      'coords_x REAL, coords_y REAL, ' +
    //      'chronology TEXT, ' +
    //      'node_rank INTEGER NOT NULL DEFAULT 1, ' +
    //      'activity_index REAL DEFAULT 0);');

        // Инициализация финальной структуры таблицы НОД (Задача №4)
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS nodes (' +
                        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
                        'content TEXT NOT NULL, ' +                   { Текст сообщения }
                        'chronology TEXT NOT NULL, ' +                { Хронология }
                        'node_rank INTEGER NOT NULL DEFAULT 1, ' +    { Ранг }
                        'node_sign TEXT NOT NULL DEFAULT ''+'', ' +   { Знак }
                        'activity_index REAL DEFAULT 0, ' +           { Индекс активности}
                        'node_clean_weight REAL DEFAULT 1.0, ' +      { Вес }
                        'dust_cloud_weight REAL DEFAULT 0.0, ' +      { Пыль }
                        'created_at DATETIME DEFAULT CURRENT_TIMESTAMP, ' + { Создано }
                        'updated_at DATETIME DEFAULT CURRENT_TIMESTAMP);');{ Изменено }

    //FConn.ExecuteDirect('INSERT OR IGNORE INTO nodes (id, content, chronology, node_rank, node_sign, activity_index) ' +
    //                    'VALUES (1, ''Корень дерева сервера'', ''1.0.0.'', 1, ''+'', 1.0);');
    FConn.ExecuteDirect('INSERT OR IGNORE INTO nodes (id, content, chronology, node_rank, node_sign, activity_index) ' +
                    'VALUES (1, ''Корень дерева сервера'', ''1.0.0.0.0.0.'', 1, ''+'', 1.0);');



    // 2. ID_Map - Таблица переадресации (Маппинг)
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS id_map (' +
      'perm_id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'phys_id INTEGER);');

    // 3. Mod_Queue - Очередь для Бота/модератора
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS mod_queue (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'node_id INTEGER, report TEXT, status INTEGER DEFAULT 0);');

    // 4. RenderCache - кэш отрисованных объектов (звезд, планет, систем)
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS render_cache (' +
      'perm_id INTEGER PRIMARY KEY, ' + // Вечный ID из маппинга
      'img_data BLOB, ' +               // Бинарные данные картинки (PNG/BMP)
      'last_update INTEGER);');         // Когда кэш был создан (хронология)



        // 5. Users - Единая расширенная таблица (Авторизация + Настройки + Карма + Профиль)
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS users (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' + // Уникальный ID пользователя
      'username TEXT UNIQUE, ' +                 // Уникальный логин (позывной)
      'password TEXT, ' +                        // Хэшированный пароль для безопасности
      'reg_date DATETIME DEFAULT CURRENT_TIMESTAMP, ' + // Дата регистрации
      'karma INTEGER DEFAULT 100, ' +            // Карма для модератора
      'pref_nodes_limit INTEGER DEFAULT 50, ' +  // Лимит "эстафеты"
      'pref_depth_limit INTEGER DEFAULT 2, ' +   //  ПРОСТО ДОПИСАЛИ СЮДА НАШ НАВИГАТОР ГЛУБИНЫ!
      'pref_theme TEXT DEFAULT "dark", ' +       // Тема оформления (dark/light)
      'profile_node_id INTEGER DEFAULT 0, ' +    // Идентификатор узла профиля
      'email TEXT UNIQUE, ' +                    //  ВРЕЗАЛИ ПОЧТУ, УНИКАЛЬНУЮ КАК ИМЯ!
      'access_rank INTEGER DEFAULT 1);');        // Поле ранга прав (1 - Исследователь)


     //    // 6. ТАБЛИЦА ПОЛЬЗОВАТЕЛЬСКИХ НАСТРОЕК (ПЕРЕНОС ИНТЕРФЕЙСНЫХ КАСТОМИЗАЦИЙ) ---
     //FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS user_preferences (' +
     //  'user_id INTEGER PRIMARY KEY, ' +
     //  'pref_nodes_limit INTEGER DEFAULT 50, ' + // ГОРИЗОНТАЛЬНЫЙ ЧАНК (ЛИНЕЙНАЯ ПАГИНАЦИЯ)
     //  'pref_depth_limit INTEGER DEFAULT 2);');   // ВЕРТИКАЛЬНЫЙ НАВИГАТОР ГЛУБИНЫ ВЛОЖЕНИЙ



     // 7. ДОБАВОЧНЫЙ КОД ВРЕМЕННОГО АНГАРА РЕГИСТРАЦИИ (ВАРИАНТ А) ---
     FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS pending_registrations (' +
       'token TEXT PRIMARY KEY, ' +
       'username TEXT UNIQUE, ' +
       'email TEXT UNIQUE, ' + //  ЗАПЕКЛИ UNIQUE СЮДА!
       'password TEXT, ' +     //  ДОБАВИЛИ ПОЛЕ ХРАНЕНИЯ ПАРОЛЯ!
       'created_at DATETIME DEFAULT CURRENT_TIMESTAMP);');

    // 8. МАТЕРИАЛИЗАЦИЯ ЩИТА БОТОВ (ДЛЯ РЕГИСТРАЦИИ) ---
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS bot_shield (' +
      'machine_name TEXT PRIMARY KEY, ' +          // Сетевое имя машины (хостнейм) или спец-ключ
      'miss_count INTEGER DEFAULT 0, ' +           // Число промахов ползунка
      'unlock_time DATETIME);');                    // Штамп времени блокировки на 1 час

        // --- ТАКТ 8. ИНИЦИАЛИЗАЦИЯ ЕДИНСТВЕННОЙ ГЛОБАЛЬНОЙ ПЕРЕМЕННОЙ СЧЁТЧИКА ---
    // INSERT OR IGNORE гарантирует, что строка запечётся только один раз при самом первом старте сервера с нуля
    FConn.ExecuteDirect('INSERT OR IGNORE INTO bot_shield (machine_name, miss_count) ' +
      'VALUES (''GLOBAL_BOT_MISS_COUNT'', 0);');

    FTran.Commit;
    WriteLn('   [БАЗА] Все таблицы успешно инициализированы в режиме WAL.');
  except
    on E: Exception do
      raise Exception.Create('Ошибка БД: ' + E.Message);
  end;
end;


// 1. Тело функции GetPhysicalID
function TDatabaseModule.GetPhysicalID(APermanentID: Integer): Integer;
begin
  // Пока заглушка, завтра напишем логику маппинга
  Result := APermanentID;
end;

// 2. Тело функции AddNode
function TDatabaseModule.AddNode(AParentID: Integer; AContent: string; AX, AY: Double): Integer;
begin
  // Пока заглушка
  Result := 0;
end;

// 3. Тело процедуры GetSystemData
procedure TDatabaseModule.GetSystemData(ARootID: Integer; AList: TList);
begin
  // Пока пусто
end;

// 4. Тело процедуры ExecuteMaintenance
procedure TDatabaseModule.ExecuteMaintenance;
begin
  FConn.ExecuteDirect('VACUUM;');
end;

 function TDatabaseModule.GetTailFromDB(AID: Integer): Integer;
var Parts: TStringArray;
begin
  Result := 0;
  // Парсим хронологию и берем второй элемент (Tail)
  Parts := GetNodeChronoFromDB(AID).Split('.');
  if Length(Parts) > 2 then Result := StrToIntDef(Parts[2], 0);
end;

 function TDatabaseModule.GetNodeChronoFromDB(AID: Integer): string;
 begin
   Result := '';
   FQuery.Close;
   FQuery.SQL.Text := 'SELECT chronology FROM nodes WHERE id = :id';
   FQuery.ParamByName('id').AsInteger := AID;
   FQuery.Open;

   // ОШИБКА БЫЛА ТУТ: нужно Fields[0] или FieldByName
   if not FQuery.EOF then
     Result := FQuery.Fields[0].AsString;

   FQuery.Close;
 end;


// function TDatabaseModule.RegisterUser(const AName, APassHash: string; AProfileNodeID: Integer = 0): Boolean;
//begin
//  Result := False;
//  try
//    // РАБОТАЕМ СТРОГО ЧЕРЕЗ ГЛОБАЛЬНЫЙ FQuery (Как до внедрения лимитов!)
//    FQuery.Close;
//    FQuery.SQL.Clear;
//
//    FQuery.SQL.Text := 'INSERT INTO users (username, password, profile_node_id) VALUES (:name, :pass, :pid);';
//    FQuery.ParamByName('name').AsString := AName;
//    FQuery.ParamByName('pass').AsString := APassHash;
//    FQuery.ParamByName('pid').AsInteger := AProfileNodeID;
//
//    // Выполняем атомарную запись
//    FQuery.ExecSQL;
//
//    // Обязательно фиксируем транзакцию, чтобы данные физически легли на диск
//    FTran.CommitRetaining;
//
//    Result := True;
//    WriteLn('   [БАЗА] Успешно создан аккаунт для: ', AName);
//  except
//    on E: Exception do
//    begin
//      FTran.RollbackRetaining;
//      WriteLn('!!! [БАЗА] Сбой при регистрации пользователя: ', E.Message);
//    end;
//  end;
//end;



function TDatabaseModule.VerifyUser(const AName, APassHash: string): Boolean;
var
  LConn: TSQLite3Connection;
  LTran: TSQLTransaction;
  LQuery: TSQLQuery;
begin
  Result := False;
  LConn := TSQLite3Connection.Create(nil);
  LTran := TSQLTransaction.Create(LConn);
  LQuery := TSQLQuery.Create(nil);
  try
    LConn.Transaction := LTran;
    LQuery.Database := LConn;
    LQuery.Transaction := LTran;
    LConn.DatabaseName := FConn.DatabaseName;
    LConn.Open;

    // Чистая проверка без лимитов
    LQuery.SQL.Text := 'SELECT id FROM users WHERE username = :name AND password = :pass;';
    LQuery.ParamByName('name').AsString := AName;
    LQuery.ParamByName('pass').AsString := APassHash;
    LQuery.Open;

    if not LQuery.EOF then
      Result := True;

    LQuery.Close;
  except
    on E: Exception do
      WriteLn('!!! [ПОТОК БД] Ошибка авторизации: ', E.Message);
  end;
  LQuery.Free; LTran.Free; LConn.Free;
end;





 function TDatabaseModule.GetNodeContent(AID: Integer): string;
 begin
   Result := '';
   FQuery.Close;
   FQuery.SQL.Text := 'SELECT content FROM nodes WHERE id = :id';
   FQuery.ParamByName('id').AsInteger := AID;
   FQuery.Open;
   if not FQuery.EOF then Result := FQuery.Fields[0].AsString;
   FQuery.Close;
 end;


procedure TDatabaseModule.GetUserLimit(const AName: string; out ANodesLimit, ADepthLimit: Integer);
var
  LConn: TSQLite3Connection; LTran: TSQLTransaction; LQuery: TSQLQuery;
begin
 // Result := 50; // Жесткий дефолт-предохранитель от мусора в памяти

  if AName = '' then Exit;
  try
    LConn := TSQLite3Connection.Create(nil); LTran := TSQLTransaction.Create(LConn); LQuery := TSQLQuery.Create(nil);
    LConn.Transaction := LTran; LQuery.Database := LConn; LQuery.Transaction := LTran;
    LConn.DatabaseName := FConn.DatabaseName; LConn.Open;

//    LQuery.SQL.Text := 'SELECT pref_nodes_limit FROM users WHERE username = :name;';
    LQuery.SQL.Text := 'SELECT pref_nodes_limit, pref_depth_limit FROM users WHERE username = ' + QuotedStr(AName) + ';';
    LQuery.Open;

    if not LQuery.EOF then
      ANodesLimit := LQuery.FieldByName('pref_nodes_limit').AsInteger;
      //  ЧИТАЕМ НАШ НОВЫЙ ВЕРТИКАЛЬНЫЙ НАВИГАТОР ГЛУБИНЫ (ЛЕГАЛИЗОВАННЫЙ НУЛЬ):
      ADepthLimit := LQuery.FieldByName('pref_depth_limit').AsInteger;
            WriteLn('💾 [БАЗА ДАННЫХ] Успешная выборка для пилота: ', AName);
      WriteLn('   -> Из полей SQLite вытянуто: nodes_limit = ', ANodesLimit, ', depth_limit = ', ADepthLimit);

    LQuery.Close;
    LQuery.Free; LTran.Free; LConn.Free;
  except
    on E: Exception do WriteLn('!!! [ПОТОК БД] Ошибка в GetUserLimit: ', E.Message);
  end;
end;

//function TDatabaseModule.UpdateUserPrefs(const AName: string; ALimit, ADepthLimit: Integer): Boolean;
//var
//  LConn: TSQLite3Connection; LTran: TSQLTransaction; LQuery: TSQLQuery;
//begin
//  Result := False; if AName = '' then Exit;
//  try
//    LConn := TSQLite3Connection.Create(nil); LTran := TSQLTransaction.Create(LConn); LQuery := TSQLQuery.Create(nil);
//    LConn.Transaction := LTran; LQuery.Database := LConn; LQuery.Transaction := LTran;
//    LConn.DatabaseName := FConn.DatabaseName; LConn.Open;
//
//    //  ОДИН КРАСИВЫЙ СНАЙПЕРСКИЙ UPDATE НА ОБА ПОЛЯ НА ДИСКЕ:
//    LQuery.SQL.Text := 'UPDATE users SET pref_nodes_limit = ' + IntToStr(ALimit) +
//                       ', pref_depth_limit = ' + IntToStr(ADepthLimit) +
//                       ' WHERE username = ' + QuotedStr(AName) + ';';
//    LQuery.ExecSQL;
//    LTran.Commit;
//    Result := True;
//    WriteLn('  [ПОТОК БД] Настройки изменены: limit=', ALimit, ', depth=', ADepthLimit, ' для ', AName);
//
//    LQuery.Free; LTran.Free; LConn.Free;
//  except
//    on E: Exception do WriteLn('!!! [ПОТОК БД] Ошибка в UpdateUserPrefs: ', E.Message);
//  end;
//end;

function TDatabaseModule.UpdateUserPrefs(const AName: string; ALimit, ADepthLimit: Integer): Boolean;
begin
  Result := False;
  if AName = '' then Exit;

  // Если главная транзакция модуля почему-то не взведена — ламинарно запускаем её
  if not FTran.Active then FTran.StartTransaction;

  try
    // Используем строго наше родное, проверенное оборудование!
    FQuery.Close;
    FQuery.SQL.Text := 'UPDATE users SET pref_nodes_limit = ' + IntToStr(ALimit) +
                       ', pref_depth_limit = ' + IntToStr(ADepthLimit) +
                       ' WHERE username = ' + QuotedStr(AName) + ';';
    FQuery.ExecSQL;

    // Фиксируем настройки на диске JUNI BOX единым монолитом
    FTran.CommitRetaining;

    Result := True;
    WriteLn('  [ПОТОК БД] Настройки изменены: limit=', ALimit, ', depth=', ADepthLimit, ' для ', AName);
  except
    on E: Exception do
    begin
      FTran.RollbackRetaining; // В случае сбоя ламинарно откатываем затвор назад
      WriteLn('!!! [ПОТОК БД] Ошибка в UpdateUserPrefs: ', E.Message);
    end;
  end;
end;

function TDatabaseModule.GetUserRank(const AUsername: string): Integer;
var
  LocalQuery: TSQLQuery;
begin
  Result := 1; // По умолчанию ранг = 1 (рядовой Исследователь)
  if AUsername = '' then Exit;

  LocalQuery := TSQLQuery.Create(nil);
  try
    LocalQuery.Database := Self.FConn; // Твоё прямое подключение к базе forum.db
    LocalQuery.SQL.Text := 'SELECT access_rank FROM users WHERE username = ' + QuotedStr(AUsername) + ';';
    LocalQuery.Open;

    if not LocalQuery.EOF then
      Result := LocalQuery.Fields[0].AsInteger;
  except
    on E: Exception do
      WriteLn('   [БАЗА ДАННЫХ-ОШИБКА] Осечка чтения access_rank: ', E.Message);
  end;
  LocalQuery.Free; // Намертво освобождаем ОЗУ ноутбука!
end;

{=== 1. ТВОЯ ВОССТАНОВЛЕННАЯ РАБОЧАЯ ФУНКЦИЯ РЕГИСТРАЦИИ ПОЛЬЗОВАТЕЛЕЙ ===}
function TDatabaseModule.RegisterUser(const AUser, APass: string): Boolean;
begin
  Result := False;
  try
    // Запекаем проверенного пилота прямо в твою основную таблицу users в SQLite.
    // access_rank = 1 выставляется автоматически по дефолту структуры таблицы.
    FConn.ExecuteDirect('INSERT INTO users (username, password) VALUES (' +
                        QuotedStr(AUser) + ', ' + QuotedStr(APass) + ');');
    Result := True;
  except
    // Если ник уже занят, SQLite выбросит ошибку уникальности (UNIQUE constraint failed),
    // функция ламинарно вернет False, и роутер зряче попросит гостя сменить позывной.
    Result := False;
  end;
end;

{=== 2. НАШ НОВЫЙ МЕТОД ЩИТА БОТОВ ===}
   function TDatabaseModule.LogBotAttempt(const AMachineName: string; AIsMiss: Boolean): Integer;
var
  TempQuery: TSQLQuery;
  HasRecord: Boolean;
begin
  Result := 0;

  // 🎯 ОПТИМИЗАЦИЯ ДЛЯ СНАЙПЕРОВ (ЧЕЛОВЕКА):
  if not AIsMiss then
  begin
    // Быстро проверяем в ОЗУ через SELECT, есть ли вообще этот IP в таблице
    HasRecord := False;
    TempQuery := TSQLQuery.Create(nil);
    try
      TempQuery.Database := FConn;
      TempQuery.SQL.Text := 'SELECT 1 FROM bot_shield WHERE machine_name = ' + QuotedStr(AMachineName) + ' LIMIT 1;';
      TempQuery.Open;
      HasRecord := not TempQuery.EOF;
      TempQuery.Close;
    finally
      TempQuery.Free;
    end;

    // Если промахов за этой машиной не числилось — тихо выходим. Сбрасывать нечего!
    if not HasRecord then
    begin
      Result := 0;
      Exit;
    end;
  end;

  // --- ДАЛЬШЕ КОД СРАБАТЫВАЕТ СТРОГО ЕСЛИ БЫЛ ПРОМАХ ИЛИ НАДО СБРОСИТЬ СУЩЕСТВУЮЩИЙ БАН ---
  if not FConn.Transaction.Active then
    FConn.Transaction.StartTransaction;

  try
    if AIsMiss then
    begin
      {=== ТАКТ ПРОМАХА БОТА ===}
      // 1. Апдейтим глобальный счетчик интернета (факт каждого промаха для истории)
      FConn.ExecuteDirect('UPDATE bot_shield SET miss_count = miss_count + 1 WHERE machine_name = ''GLOBAL_BOT_MISS_COUNT'';');

      // 2. Инкрементируем личные промахи этой конкретной машине (IP-адресу)
      FConn.ExecuteDirect('INSERT INTO bot_shield (machine_name, miss_count) VALUES (' + QuotedStr(AMachineName) + ', 1) ' +
                          'ON CONFLICT(machine_name) DO UPDATE SET miss_count = miss_count + 1;');

      // 3. ЗРЯЧЕЕ ЧТЕНИЕ: Вытаскиваем реальный miss_count нарушителя из SQLite
      TempQuery := TSQLQuery.Create(nil);
      try
        TempQuery.Database := FConn;
        TempQuery.SQL.Text := 'SELECT miss_count FROM bot_shield WHERE machine_name = ' + QuotedStr(AMachineName) + ';';
        TempQuery.Open;
        if not TempQuery.EOF then
          Result := TempQuery.Fields[0].AsInteger // Твоя снайперская поправка индекса!
        else
          Result := 1;
        TempQuery.Close;
      finally
        TempQuery.Free;
      end;
    end
    else
    begin
      {=== ТАКТ УСПЕШНОГО СБРОСА СУЩЕСТВОВАВШЕГО НАРУШЕНИЯ ===}
      FConn.ExecuteDirect('UPDATE bot_shield SET miss_count = 0, unlock_time = NULL WHERE machine_name = ' + QuotedStr(AMachineName) + ';');
      Result := 0;
    end;

    FConn.Transaction.Commit; // Запекаем изменения в файл базы на диске!

  except
    FConn.Transaction.Rollback;
    Result := 0;
  end;
end;

   function TDatabaseModule.ConfirmRegistration(const AToken: string): Boolean;
var
  SavedUser, SavedEmail, SavedPass: string;
begin
  Result := False;
  SavedUser := '';
  SavedEmail := '';
  SavedPass := '';

  // 1. Ищем токен во временном ангаре ожидания
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT username, email, password FROM pending_registrations WHERE token = ' + QuotedStr(AToken) + ';'; //
  FQuery.Open;

  // Если токен найден — фиксируем данные в ОЗУ
  if not FQuery.EOF then
  begin
    SavedUser  := FQuery.FieldByName('username').AsString;
    SavedEmail := FQuery.FieldByName('email').AsString;
    SavedPass :=  FQuery.FieldByName('password').AsString;
  end;
  FQuery.Close;

  // Если переменные пустые — токен фальшивый, выходим со сбоем!
  if SavedUser = '' then Exit;

  try
    // 2. Впекаем пилота в постоянную таблицу пользователей users!
    FQuery.SQL.Text := 'INSERT INTO users (username, email, password) VALUES (' +
                       QuotedStr(SavedUser) + ', ' + QuotedStr(SavedEmail) + ', ' + QuotedStr(SavedPass) + ');';
    FQuery.ExecSQL;

    // 3. Выжигаем временный след из ангара ожидания, чтобы исключить повторы!
    FQuery.SQL.Text := 'DELETE FROM pending_registrations WHERE token = ' + QuotedStr(AToken) + ';';
    FQuery.ExecSQL;

    // 4. Намертво прижимаем транзакцию к физическому накопителю!
    FTran.CommitRetaining;

    WriteLn(' 🛰 [СУБД УСПЕХ] Пользователь "', SavedUser, '" успешно верифицирован и перенесён в users!');
    Result := True;
  except
    on E: Exception do
    begin
      WriteLn(' ⚠️ [КРИТИЧЕСКИЙ СБОЙ СУБД ПРИ АКТИВАЦИИ]: ', E.Message);
      // Если что-то пошло не так (например, ник успели занять) — откатываемся, не ломая базу
      FTran.RollbackRetaining;
      Result := False;
    end;
  end;
end;


destructor TDatabaseModule.Destroy;
begin
  FQuery.Free;
  FTran.Free;
  FConn.Free;
  inherited Destroy;
end;

end.

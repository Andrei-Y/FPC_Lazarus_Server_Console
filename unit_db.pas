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
      function GetNodeChrono(AID: Integer): string;
      function GetNodeContent(AID: Integer): string;
      function RegisterUser(const AName, APassHash: string; AProfileNodeID: Integer = 0): Boolean;
      function VerifyUser(const AName, APassHash: string; out AUserID, ANodesLimit: Integer; out ATheme: string): Boolean;
      procedure ExecSQL(const ASQL: string);
      function CreateHead(AContent: string): Integer;

  end;

implementation

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

//function TDatabaseModule.GetNodeChrono(AID: Integer): string;
//begin
//  Result := '';
//  FQuery.Close;
//  FQuery.SQL.Text := 'SELECT chronology FROM nodes WHERE id = :id';
//  FQuery.ParamByName('id').AsInteger := AID;
//  FQuery.Open;
//  if not FQuery.EOF then Result := FQuery.Fields[0].AsString;
//  FQuery.Close;
//end;

function TDatabaseModule.GetNodeChrono(AID: Integer): string;
begin
  Result := '';

  // МАЯК 1: Проверка соединения
  if not Assigned(FConn) or not FConn.Connected then
  begin
    WriteLn('!!! [БАЗА] ОШИБКА: FConn не подключен !!!');
    Exit;
  end;
  try
    FQuery.Close;
    FQuery.SQL.Text := 'SELECT chronology FROM nodes WHERE id = :id';
    FQuery.ParamByName('id').AsInteger := AID;

     //WriteLn('   [БАЗА] Выполняю запрос для ID: ', AID); // МАЯК 2
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

function TDatabaseModule.LandingNode(AParentID: Integer; AContent: string): Integer;
var
  ParentChrono, OldTailID, NewChrono, UpdatedParentChrono: string;
  Parts: TStringArray;
  NewID: Integer;
begin
  Result := -1;
  if not FTran.Active then FTran.StartTransaction;
  try
        // 1. Узнаем, кто сейчас хвост у родителя (AParentID)
    ParentChrono := GetNodeChrono(AParentID);
    Parts := ParentChrono.Split('.');

    if Length(Parts) > 2 then
      OldTailID := Parts[2]
    else
      OldTailID := '0';

    // ВОТ ТУТ РЕШЕНИЕ ПРОБЛЕМЫ:
    // Если хвоста у родителя нет (0), то наш "предшественник"
    // — это сам родитель (AParentID)
    if OldTailID = '0' then
       OldTailID := IntToStr(AParentID);

    // Теперь NewChrono будет "0.ParentID.0", а не "0.0.0"
    NewChrono := '0.' + OldTailID + '.0.';
    NewChrono := '0.' + OldTailID + '.0.';

    // Вставляем новый узел
    FQuery.Close;
    FQuery.SQL.Text := 'INSERT INTO nodes (content, chronology) VALUES (:cnt, :chr) RETURNING id;';
    FQuery.ParamByName('cnt').AsString := AContent;
    FQuery.ParamByName('chr').AsString := NewChrono;
    FQuery.Open;
    NewID := FQuery.Fields[0].AsInteger;
    FQuery.Close;

    // ОБНОВЛЯЕМ РОДИТЕЛЯ
    Parts[2] := IntToStr(NewID); // Теперь индекс 2 точно есть
    UpdatedParentChrono := string.Join('.', Parts);

    FQuery.SQL.Text := 'UPDATE nodes SET chronology = :nc WHERE id = :id';
    FQuery.ParamByName('nc').AsString := UpdatedParentChrono;
    FQuery.ParamByName('id').AsInteger := AParentID;
    FQuery.ExecSQL;

    FTran.CommitRetaining;
    Result := NewID;
  except
    on E: Exception do begin FTran.RollbackRetaining; raise; end;
  end;
end;

constructor TDatabaseModule.Create(ADBPath: string);
begin
    //FConn := TSQLite3Connection.Create(nil);
    //FTran := TSQLTransaction.Create(FConn);
    //FQuery := TSQLQuery.Create(nil);
    //FQuery.Database := FConn;
    //FQuery.Transaction := FTran;
    //
    //FConn.DatabaseName := ADBPath;
    //FConn.Open;
    //
    //// Включаем режим WAL и быструю синхронизацию
    //FConn.ExecuteDirect('PRAGMA journal_mode=WAL;');
    //FConn.ExecuteDirect('PRAGMA synchronous=NORMAL;');
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
    FConn.Open;
    FTran.Active := True;

    // Создаем таблицы
    // 1. Nodes - Хранилище данных
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS nodes (' +
          'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
          'content TEXT, ' +
          'coords_x REAL, coords_y REAL, ' +
          'chronology TEXT, ' +         // ТЕПЕРЬ ЭТО ТЕКСТ
          'activity_index REAL DEFAULT 0);');


    // 2. ID_Map - Таблица переадресации (Маппинг)
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS id_map (' +
      'perm_id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'phys_id INTEGER);');

    // 3. Users - Карма и баллы
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS users (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'name TEXT, karma INTEGER DEFAULT 100);');

    // 4. Mod_Queue - Очередь для "Судьи"
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS mod_queue (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'node_id INTEGER, report TEXT, status INTEGER DEFAULT 0);');

      // 5. RenderCache - кэш отрисованных объектов (звезд, планет, систем)
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS render_cache (' +
    'perm_id INTEGER PRIMARY KEY, ' + // Вечный ID из маппинга
    'img_data BLOB, ' +               // Бинарные данные картинки (PNG/BMP)
    'last_update INTEGER);');         // Когда кэш был создан (хронология)

    //  6 Инициализация таблицы пользователей (Авторизация + Настройки + Связь с графом)
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS users (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ' + // Уникальный ID пользователя
    'username TEXT UNIQUE, ' +                 // Уникальный логин
    'pass_hash TEXT, ' +                       // Хеш пароля для безопасности
    'reg_date DATETIME DEFAULT CURRENT_TIMESTAMP, ' + // Дата регистрации

    // НАСТРОЙКИ (Воркер подхватит их мгновенно при входе)
    'pref_nodes_limit INTEGER DEFAULT 50, ' +  // Лимит узлов на страницу
    'pref_theme TEXT DEFAULT "dark", ' +       // Тема оформления (dark/light)

    // СВЯЗЬ С СЕМАНТИЧЕСКИМ ПРОФИЛЕМ В ТАБЛИЦЕ NODES
    'profile_node_id INTEGER DEFAULT 0);');    // ID корня личной ветки

      FTran.Commit;
  except
    on E: Exception do raise Exception.Create('Ошибка БД: ' + E.Message);
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

 function TDatabaseModule.RegisterUser(const AName, APassHash: string; AProfileNodeID: Integer = 0): Boolean;
begin
  Result := False;
  try
    // Стартуем транзакцию, чтобы гарантировать целостность данных
    FTran.StartTransaction;

    FQuery.SQL.Text := 'INSERT INTO users (username, pass_hash, profile_node_id) ' +
                       'VALUES (:name, :pass, :pid)';

    FQuery.ParamByName('name').AsString := AName;
    FQuery.ParamByName('pass').AsString := APassHash;
    FQuery.ParamByName('pid').AsInteger := AProfileNodeID;
    FQuery.ExecSQL;

    // Фиксируем изменения в базе данных
    FTran.Commit;
    Result := True;
    WriteLn('   [БАЗА] Успешно создан аккаунт для: ', AName);
  except
    on E: Exception do
    begin
      // В случае любой ошибки (например, имя уже занято) откатываем изменения
      FTran.Rollback;
      WriteLn('!!! [БАЗА] Сбой при регистрации пользователя: ', E.Message);
    end;
  end;
end;


 function TDatabaseModule.VerifyUser(const AName, APassHash: string; out AUserID, ANodesLimit: Integer; out ATheme: string): Boolean;
begin
  Result := False;
  AUserID := 0;
  ANodesLimit := 50;
  ATheme := 'dark';

  try
    FQuery.SQL.Text := 'SELECT id, pref_nodes_limit, pref_theme FROM users WHERE username = :name AND pass_hash = :pass';
    FQuery.ParamByName('name').AsString := AName;
    FQuery.ParamByName('pass').AsString := APassHash;
    FQuery.Open;

    if not FQuery.EOF then
    begin
      AUserID := FQuery.FieldByName('id').AsInteger;
      ANodesLimit := FQuery.FieldByName('pref_nodes_limit').AsInteger;
      ATheme := FQuery.FieldByName('pref_theme').AsString;
      Result := True;
    end;
    FQuery.Close;
  except
    on E: Exception do
      WriteLn('!!! [БАЗА] Ошибка авторизации: ', E.Message);
  end;
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




destructor TDatabaseModule.Destroy;
begin
  FQuery.Free;
  FTran.Free;
  FConn.Free;
  inherited Destroy;
end;

end.

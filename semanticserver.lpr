program semanticserver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, CustApp, fphttpserver, Unit_DB, Unit_Worker;

type
  TSemanticApp = class(TCustomApplication)
  private
    FServer: TFPHTTPServer;
    FDB: TDatabaseModule;
    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
                           var AResponse: TFPHTTPConnectionResponse);
  protected
    procedure DoRun; override;
  end;

//procedure TSemanticApp.HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
//                                    var AResponse: TFPHTTPConnectionResponse);
//var
//  TempWorker: TServerWorker;
//
//begin
//  WriteLn(FormatDateTime('hh:nn:ss', Now) + ' [СЕТЬ] Запрос: ' + ARequest.PathInfo);
//
//  if ARequest.PathInfo = '/forum' then
//  begin
//    WriteLn('   [СИСТЕМА] Запуск эстафеты для ID=1...');
//
//    // Создаем воркер. Вместо логов формы передаем nil (будем писать в консоль напрямую)
//    TempWorker := TServerWorker.Create(Self.FDB, nil, nil, emToViewer, True);
//    try
//      TempWorker.ExposeSystem(1); // Твоя оригинальная процедура обхода
//
//      AResponse.Content := TempWorker.FHtmlBuffer;
//      AResponse.ContentType := 'text/html; charset=utf-8';
//    finally
//      TempWorker.Free;
//    end;
//  end
//  else
//  begin
//    AResponse.Content := '<html><body><h1>Semantic Server</h1><p><a href="/forum">Перейти к форуму</a></p></body></html>';
//    AResponse.ContentType := 'text/html; charset=utf-8';
//  end;
//end;


procedure TSemanticApp.HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
                                     var AResponse: TFPHTTPConnectionResponse);
var
  Path: string;
  TempWorker: TServerWorker;
  ReqUser, ReqPass: string;
  UID, ULimit: Integer;
  UTheme: string;
  UserBlock: string;
begin
  // НАДЁЖНЫЙ И КАНАНИЧЕСКИЙ ПУТЬ FPC: достаем значение "auth_user" из полей кук запроса
    ReqUser := ARequest.CookieFields.Values['auth_user'];
   // Если куки нет, ReqUser автоматически останется пустой строкой





  Path := ARequest.PathInfo;

  // 1. Корень (Главная страница)
  if (Path = '/') or (Path = '') then
  begin
     AResponse.ContentType := 'text/html; charset=utf-8';

     // Формируем блок профиля на основе значения ReqUser
     if ReqUser <> '' then
       UserBlock := 'Привет, <b>' + ReqUser + '</b>! | ' +
                    '<a href="/profile" style="color: #4A90E2; text-decoration: none;">[ Личный кабинет ]</a> | ' +
                    '<a href="/logout" style="color: #F44336; text-decoration: none;">[ Выход ]</a>'
     else
       UserBlock := '<a href="/login" style="color: #4A90E2; text-decoration: none;">[ Авторизация ]</a> | ' +
                    '<a href="/register" style="color: #4A90E2; text-decoration: none;">[ Регистрация ]</a>';

     AResponse.Content :=
       '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Semantic Space</title>' +
       '<style>' +
       '  body { background: #121212; color: #eee; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }' +
       '  .container { background: #1e1e1e; padding: 40px; border-radius: 8px; border: 1px solid #333; text-align: center; max-width: 500px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }' +
       '  h1 { margin-top: 0; color: #00FFFF; font-size: 28px; letter-spacing: 1px; }' +
       '  .user-bar { background: #252525; padding: 10px 15px; border-radius: 4px; margin-bottom: 30px; font-size: 14px; border: 1px solid #3c3c3c; }' +
       '  .btn-galaxy { display: inline-block; padding: 15px 35px; background: linear-gradient(135deg, #4A90E2, #00FFFF); color: #fff; font-weight: bold; font-size: 18px; text-decoration: none; border-radius: 5px; box-shadow: 0 4px 15px rgba(0, 255, 255, 0.3); transition: 0.3s; }' +
       '  .btn-galaxy:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0, 255, 255, 0.5); }' +
       '  .footer { margin-top: 25px; font-size: 11px; color: #555; }' +
       '</style></head><body>' +

       '<div class="container">' +
       '  <h1>Семантический Сервер</h1>' +

       '  <!-- Блок авторизации / профиля -->' +
       '  <div class="user-bar">' + UserBlock + '</div>' +

       '  <!-- Наша "Галактика" -->' +
       '  <p style="color: #aaa; font-size: 14px; margin-bottom: 30px;">Ультракомпактный движок направленных графов смыслов без использования рекурсии.</p>' +
       '  <a href="/forum" class="btn-galaxy">🌌 Галактика</a>' +

       '  <div class="footer">FPC Релиз • Архитектура Green Computing</div>' +
       '</div>' +

       '</body></html>';
   end // <--- Обрати внимание: тут нет точки с запятой, если следующим идет else if!

  // 2. Твой рабочий блок Форума
  //else if Path = '/forum' then
  //begin
  //  WriteLn('   [СИСТЕМА] Запуск обхода дерева для браузера...');
  //  // Создаем воркер (Self.FDB - наша база)
  //  TempWorker := TServerWorker.Create(Self.FDB, nil, nil, emToViewer, True);
  //  try
  //    TempWorker.ExposeSystem(1); // Твоя ювелирная процедура
  //
  //    AResponse.ContentType := 'text/html; charset=utf-8';
  //    // Если буфер пуст (не настроено накопление), выдаст ошибку
  //    if TempWorker.FHtmlBuffer = '' then
  //      AResponse.Content := '<html><body><h1>Ошибка: Буфер пуст</h1></body></html>'
  //    else
  //      AResponse.Content := TempWorker.FHtmlBuffer;
  //
  //  finally
  //    TempWorker.Free;
  //  end;
  //end

    else if Path = '/forum' then
  begin
    WriteLn('   [СИСТЕМА] Запуск обхода дерева для браузера...');
    TempWorker := TServerWorker.Create(Self.FDB, nil, nil, emToViewer, True);
    try
      TempWorker.ExposeSystem(1);

      AResponse.ContentType := 'text/html; charset=utf-8';

      if TempWorker.FHtmlBuffer = '' then
        AResponse.Content := '<html><body><h1>Ошибка: Буфер пуст</h1></body></html>'
      else
        // Формируем "умную" оболочку вокруг буфера
        AResponse.Content :=
          '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Semantic Artist</title>' +
          '<style>' +
          '  body { margin: 0; padding: 0; overflow: hidden; display: flex; height: 100vh; background: #1e1e1e; color: #d4d4d4; font-family: sans-serif; }' +
          '  #left-panel { width: 50%; min-width: 150px; overflow-y: auto; padding: 10px; box-sizing: border-box; }' +
          '  #resizer { width: 6px; cursor: col-resize; background: #333; transition: 0.2s; }' +
          '  #resizer:hover { background: #4A90E2; }' +
          '  #right-panel { flex-grow: 1; background: #111; position: relative; overflow: hidden; }' +
          '  canvas { display: block; width: 100%; height: 100%; }' +
          '</style></head><body>' +

          // Левая часть: твое дерево
          '<div id="left-panel">' + TempWorker.FHtmlBuffer + '</div>' +

          // Разделитель
          '<div id="resizer"></div>' +

          // Правая часть: будущая графика
          '<div id="right-panel"><canvas id="artistCanvas"></canvas></div>' +

          '<script>' +
          '  const left = document.getElementById("left-panel");' +
          '  const resizer = document.getElementById("resizer");' +
          '  let isResizing = false;' +

          '  resizer.addEventListener("mousedown", (e) => { isResizing = true; document.body.style.userSelect = "none"; });' +
          '  document.addEventListener("mouseup", () => { isResizing = false; document.body.style.userSelect = "auto"; });' +
          '  document.addEventListener("mousemove", (e) => {' +
          '    if (!isResizing) return;' +
          '    left.style.width = e.clientX + "px";' +
          '  });' +

          // Проверка посылки для Художника (которую мы добавили в воркер)
          '  console.log("Artist Data Ready: ' + TempWorker.FArtistBuffer + '");' +
          '</script>' +
          '</body></html>';

    finally
      TempWorker.Free;
    end;
  end

      else if Path = '/register' then
  begin
    AResponse.ContentType := 'text/html; charset=utf-8';

    // Если это обычный запрос страницы (GET) — показываем форму
    if ARequest.Method = 'GET' then
    begin
      AResponse.Content :=
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Регистрация</title>' +
        '<style>' +
        '  body { background: #1e1e1e; color: #eee; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }' +
        '  .reg-box { background: #2d2d2d; padding: 30px; border-radius: 5px; border: 1px solid #444; width: 300px; }' +
        '  h2 { margin-top: 0; color: #4A90E2; text-align: center; }' +
        '  input[type="text"], input[type="password"] { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #555; background: #111; color: #fff; box-sizing: border-box; }' +
        '  input[type="submit"] { width: 100%; padding: 10px; background: #4A90E2; border: none; color: white; font-weight: bold; cursor: pointer; transition: 0.2s; }' +
        '  input[type="submit"]:hover { background: #357ABD; }' +
        '  .link { text-align: center; margin-top: 15px; font-size: 13px; }' +
        '  .link a { color: #888; text-decoration: none; }' +
        '</style></head><body>' +

        '<div class="reg-box">' +
        '  <h2>Создать аккаунт</h2>' +
        '  <form method="POST" action="/register">' +
        '    <label>Имя пользователя:</label>' +
        '    <input type="text" name="user" required autocomplete="off">' +
        '    <label>Пароль:</label>' +
        '    <input type="password" name="pass" required>' +
        '    <input type="submit" value="Зарегистрироваться">' +
        '  </form>' +
        '  <div class="link"><a href="/forum">← Вернуться на форум</a></div>' +
        '</div>' +

        '</body></html>';
    end
    else
    // Если пользователь нажал кнопку (POST) — обрабатываем данные
    if ARequest.Method = 'POST' then
    begin
      ReqUser := ARequest.ContentFields.Values['user'];
      ReqPass := ARequest.ContentFields.Values['pass'];

      if Self.FDB.RegisterUser(ReqUser, ReqPass) then
      begin
        // Нативный редирект на авторизацию
        AResponse.SendRedirect('/login');
      end
      else
      begin
        AResponse.Content := '<html><body><h2>Ошибка регистрации. Возможно, имя уже занято.</h2><a href="/register">Назад</a></body></html>';
      end;
    end

        else if Path = '/login' then
  begin
    AResponse.ContentType := 'text/html; charset=utf-8';

    // GET: Показываем форму входа
    if ARequest.Method = 'GET' then
    begin
      AResponse.Content :=
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Вход</title>' +
        '<style>' +
        '  body { background: #1e1e1e; color: #eee; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }' +
        '  .login-box { background: #2d2d2d; padding: 30px; border-radius: 5px; border: 1px solid #444; width: 300px; }' +
        '  h2 { margin-top: 0; color: #4A90E2; text-align: center; }' +
        '  input[type="text"], input[type="password"] { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #555; background: #111; color: #fff; box-sizing: border-box; }' +
        '  input[type="submit"] { width: 100%; padding: 10px; background: #4A90E2; border: none; color: white; font-weight: bold; cursor: pointer; }' +
        '  .link { text-align: center; margin-top: 15px; font-size: 13px; }' +
        '  .link a { color: #888; text-decoration: none; }' +
        '</style></head><body>' +

        '<div class="login-box">' +
        '  <h2>Авторизация</h2>' +
        '  <form method="POST" action="/login">' +
        '    <label>Имя пользователя:</label>' +
        '    <input type="text" name="user" required autocomplete="off">' +
        '    <label>Пароль:</label>' +
        '    <input type="password" name="pass" required>' +
        '    <input type="submit" value="Войти">' +
        '  </form>' +
        '  <div class="link"><a href="/register">Регистрация</a> | <a href="/forum">На форум</a></div>' +
        '</div>' +
        '</body></html>';
    end
    else
    // POST: Проверяем данные и ставим Cookie
    begin
      ReqUser := ARequest.ContentFields.Values['user'];
      ReqPass := ARequest.ContentFields.Values['pass'];

      if Self.FDB.VerifyUser(ReqUser, ReqPass, UID, ULimit, UTheme) then
      begin
        // ПРАВИЛЬНАЯ РАБОТА С COOKIES В FPC:
        // Метод Add создает объект, и мы настраиваем его свойства
        with AResponse.Cookies.Add do
        begin
          Name := 'auth_user';
          Value := ReqUser;
          Path := '/';
          HttpOnly := True;
        end;

        // НАТИВНЫЙ РЕДИРЕКТ НА ФОРУМ (устанавливает 302 и Location автоматически)
        AResponse.SendRedirect('/forum');
        WriteLn('   [СЕРВЕР] Пользователь ', ReqUser, ' успешно авторизован.');
      end
      else
      begin
        AResponse.Content := '<html><body><h2>Ошибка: Неверный логин или пароль</h2><a href="/login">Попробуйте снова</a></body></html>';
      end;
    end;
  end
        else if Path = '/logout' then
        begin
          // Очищаем куку по стандартам Free Pascal
          with AResponse.Cookies.Add do
          begin
            Name := 'auth_user';
            Value := '';
            Path := '/';
            Expires := 0; // Или любая прошедшая дата, компилятор сбросит её
          end;
          AResponse.SendRedirect('/forum');
        end

  // 3. Если зашли по непонятному адресу
  else
  begin
    AResponse.Code := 404;
    AResponse.Content := '<html><body><h1>404 Not Found</h1></body></html>';
  end;
end;

end;




//procedure TSemanticApp.DoRun;
//begin
//  FServer := TFPHTTPServer.Create(nil);
//  try
//    FServer.Port := 8080;
//    FServer.OnRequest := @HandleRequest;
//    FServer.Threaded :=  True;/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    WriteLn('=== SEMANTIC SERVER STARTED ===');
//    WriteLn('URL: http://localhost:8080');
//    WriteLn('Press [ENTER] to stop...');
//
//    FServer.Active := True;
//    ReadLn; // Ожидание команды на выход
//
//    WriteLn('Stopping server...');
//    FServer.Active := False;
//  finally
//    FServer.Free;
//  end;
//  Terminate;
//end;

procedure TSemanticApp.DoRun;
begin
  // 1. ПЕРВЫМ ДЕЛОМ создаем базу.
  // Теперь она будет доступна всем потокам сервера через Self.FDB
  FDB := TDatabaseModule.Create('forum.db');

  FServer := TFPHTTPServer.Create(nil);
  try
    FServer.Port := 8080;
    FServer.OnRequest := @HandleRequest;
    FServer.Threaded := True;

    WriteLn('=== SEMANTIC SERVER STARTED ===');
    FServer.Active := True;

    ReadLn; // Программа стоит тут, пока ты не нажмешь Enter

    FServer.Active := False;
    // Обязательно удаляем базу при выходе, чтобы закрыть файл forum.db
    FDB.Free;
  finally
    FServer.Free;
  end;
  Terminate;
end;


var
  Application: TSemanticApp;
begin
  Application := TSemanticApp.Create(nil);
  Application.Title := 'Semantic Server';
  Application.Run;
  Application.Free;
end.



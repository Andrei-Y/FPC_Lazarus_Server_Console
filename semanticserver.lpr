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
begin
  Path := ARequest.PathInfo;

  // 1. Корень (Главная страница)
  if (Path = '/') or (Path = '') then
  begin
    AResponse.ContentType := 'text/html; charset=utf-8';
    AResponse.Content :=
      '<html><head><meta charset="utf-8"><title>Semantic Server</title></head>' +
      '<body style="background:#1e1e1e; color:#d4d4d4; font-family:sans-serif; padding:30px;">' +
      '  <h1 style="color:#4A90E2;">=== SEMANTIC CORE SYSTEM ===</h1>' +
      '  <p>Добро пожаловать в систему управления графами.</p>' +
      '  <hr border="0" style="border-top:1px solid #333;">' +
      '  <ul style="list-style:none; padding:0;">' +
      '    <li style="margin-bottom:10px;">' +
      '      <a href="/forum" style="color:#00ff00; text-decoration:none; font-size:1.2em;">' +
      '        [ Перейти к просмотру Эстафеты (Форум) ]' +
      '      </a>' +
      '    </li>' +
      '  </ul>' +
      '</body></html>';
  end

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

  // 3. Если зашли по непонятному адресу
  else
  begin
    AResponse.Code := 404;
    AResponse.Content := '<html><body><h1>404 Not Found</h1></body></html>';
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



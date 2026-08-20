program semanticserver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, CustApp, fphttpserver, Unit_DB, Unit_Worker, md5, DateUtils, netdb;

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




 // 0. КОНСТРУКТОР СТРАНИЦЫ РЕГИСТРАЦИИ
// function HTML_RenderRegisterForm(ANum1, ANum2: Integer; const AErrorMsg: string): string;
//var
//  ErrorBlock: string;
//begin
//  // Если бэкенд передал ошибку (например, "Ник уже занят"), формируем зрячий блок
//  if AErrorMsg <> '' then
//    ErrorBlock := '<div style="background:#CC3355; color:#fff; padding:10px; border-radius:4px; margin-bottom:15px; font-size:13px; font-weight:bold; border:1px solid #ff3366;">⚠️ ' + AErrorMsg + '</div>'
//  else
//    ErrorBlock := '';
//
//  Result :=
//    '<html><head><meta charset="utf-8"></head>' + // 🎯 НАМЕРТВО ЛЕЧИТ КРАКОЗЯБРЫ В БРАУЗЕРЕ
//    '<body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:40px; margin:0; display:flex; align-items:center; justify-content:center; min-height:100vh;">' +
//    '  <div style="width:100%; max-width: 400px; background:#111; border:1px solid #333; padding:30px; border-radius:8px; box-shadow: 0 0 20px rgba(0,255,255,0.05);">' +
//    '    ' +
//    '    <div style="text-align:center; margin-bottom:25px;">' +
//    '      <div style="font-size:24px; font-weight:bold; color:#00FFFF; letter-spacing:1px; margin-bottom:8px;">🛰️ РЕГИСТРАЦИЯ ПИЛОТА</div>' +
//    '      <div style="font-size:12px; color:#888;">Подайте заявку на подключение к графу созвездий</div>' +
//    '    </div>' +
//    '    ' +
//    '    ' + ErrorBlock +
//    '    ' +
//    '    <form action="/do_register" method="POST" style="margin:0; padding:0;">' +
//    '      ' +
//    '      <div style="margin-bottom:15px;">' +
//    '        <label style="display:block; font-size:12px; color:#aaa; font-weight:bold; margin-bottom:6px; letter-spacing:0.5px;">ПОЗЫВНОЙ (USERNAME):</label>' +
//    '        <input type="text" name="username" required autocomplete="off" placeholder="Введите уникальный ник..." ' +
//    '               style="width:100%; background:#252526; color:#fff; border:1px solid #444; border-radius:4px; padding:10px; font-size:14px; outline:none; box-sizing:border-box;">' +
//    '      </div>' +
//    '      ' +
//    '      <div style="margin-bottom:20px;">' +
//    '        <label style="display:block; font-size:12px; color:#aaa; font-weight:bold; margin-bottom:6px; letter-spacing:0.5px;">СТОРОННЯЯ ПОЧТА (EMAIL):</label>' +
//    '        <input type="email" name="email" required autocomplete="off" placeholder="your-mail@domain.com" ' +
//    '               style="width:100%; background:#252526; color:#fff; border:1px solid #444; border-radius:4px; padding:10px; font-size:14px; outline:none; box-sizing:border-box;">' +
//    '      </div>' +
//    '      ' +
//    '      <div style="margin-bottom:25px; background:#161616; border:1px dashed #333; padding:12px; border-radius:4px;">' +
//    '        <label style="display:block; font-size:11px; color:#888; font-weight:bold; margin-bottom:8px; letter-spacing:0.5px;">ЗАЩИТА ОТ АВТОМАТИЧЕСКИХ БОТОВ:</label>' +
//    '        <div style="display:flex; align-items:center; gap:10px;">' +
//    '          <div style="font-size:16px; font-weight:bold; color:#00FFaa; background:#252526; border:1px solid #444; padding:6px 12px; border-radius:4px; white-space:nowrap;">' +
//               IntToStr(ANum1) + ' + ' + IntToStr(ANum2) + ' = ' +
//    '          </div>' +
//    '          <input type="number" name="captcha_answer" required autocomplete="off" placeholder="Ответ" ' +
//    '                 style="width:100%; background:#252526; color:#fff; border:1px solid #444; border-radius:4px; padding:8px; font-size:14px; outline:none; box-sizing:border-box; text-align:center;">' +
//    '        </div>' +
//    '      </div>' +
//    '      ' +
//    '      <input type="hidden" name="c_n1" value="' + IntToStr(ANum1) + '">' +
//    '      <input type="hidden" name="c_n2" value="' + IntToStr(ANum2) + '">' +
//    '      ' +
//    '      <button type="submit" style="width:100%; background:transparent; border:1px solid #00FFFF; color:#00FFFF; padding:12px; border-radius:4px; font-size:14px; font-weight:bold; cursor:pointer; outline:none; transition: 0.2s; letter-spacing:1px;">' +
//    '        ОТПРАВИТЬ ССЫЛКУ АКТИВАЦИИ' +
//    '      </button>' +
//    '      ' +
//    '    </form>' +
//    '  </div>' +
//    '</body></html>';
//end;
  // 1. КОНСТРУКТОР ГЛАВНОЙ СТРАНИЦЫ

 function HTML_RenderRegisterForm(const AErrorMsg: string): string;
var
  ErrorBlock: string;
  TargetX: Integer;
begin
  // Генерируем случайную координату для символа-цели на треке (ширина трека 300px, бегунок 32px)
  // Безопасный диапазон для центровки символа: от 40 до 240 пикселей
  TargetX := Random(200) + 40;

  if AErrorMsg <> '' then
    ErrorBlock := '<div style="background:#CC3355; color:#fff; padding:10px; border-radius:4px; margin-bottom:15px; font-size:13px; font-weight:bold; border:1px solid #ff3366;">⚠️ ' + AErrorMsg + '</div>'
  else
    ErrorBlock := '';

  Result :=
    '<html><head><meta charset="utf-8"></head>' +
    '<body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:40px; margin:0; display:flex; align-items:center; justify-content:center; min-height:100vh; user-select:none;">' +
    '  <div style="width:100%; max-width: 400px; background:#111; border:1px solid #333; padding:30px; border-radius:8px; box-shadow: 0 0 20px rgba(0,255,255,0.05);">' +
    '    ' +
    '    <div style="text-align:center; margin-bottom:25px;">' +
    '      <div style="font-size:24px; font-weight:bold; color:#00FFFF; letter-spacing:1px; margin-bottom:8px;">🛰️ РЕГИСТРАЦИЯ ПИЛОТА</div>' +
    '      <div style="font-size:12px; color:#888;">Подайте заявку на подключение к графу созвездий</div>' +
    '    </div>' +
    '    ' +
    '    ' + ErrorBlock +
    '    ' +
    '    <form action="/do_register" method="POST" style="margin:0; padding:0;">' +
    '      ' +
    '      <div style="margin-bottom:15px;">' +
    '        <label style="display:block; font-size:12px; color:#aaa; font-weight:bold; margin-bottom:6px; letter-spacing:0.5px;">ПОЗЫВНОЙ (USERNAME):</label>' +
    '        <input type="text" name="username" required autocomplete="off" placeholder="Введите уникальный ник..." ' +
    '               style="width:100%; background:#252526; color:#fff; border:1px solid #444; border-radius:4px; padding:10px; font-size:14px; outline:none; box-sizing:border-box;">' +
    '      </div>' +
    '      ' +
    '      <div style="margin-bottom:20px;">' +
    '        <label style="display:block; font-size:12px; color:#aaa; font-weight:bold; margin-bottom:6px; letter-spacing:0.5px;">СТОРОННЯЯ ПОЧТА (EMAIL):</label>' +
    '        <input type="email" name="email" required autocomplete="off" placeholder="your-mail@domain.com" ' +
    '               style="width:100%; background:#252526; color:#fff; border:1px solid #444; border-radius:4px; padding:10px; font-size:14px; outline:none; box-sizing:border-box;">' +
    '      </div>' +
    '      ' +
    '      {--- ИНТЕРАКТИВНЫЙ КООРДИНАТНЫЙ ПОЛЗУНОК ---}' +
    '      <div style="margin-bottom:25px; background:#161616; border:1px solid #444; padding:15px; border-radius:4px;">' +
    '        <label style="display:block; font-size:11px; color:#888; font-weight:bold; margin-bottom:10px; letter-spacing:0.5px;">КАЛИБРОВКА ПРИБОРОВ: СОВМЕСТИТЕ МЕТКУ С СИМВОЛОМ §</label>' +
    '        ' +
    '        <div id="slider-track" style="position:relative; width:300px; height:32px; background:#0b0b0b; border:1px solid #333; border-radius:16px; margin:0 auto; overflow:hidden;">' +
    '          ' +
    '          {--- Лавандовая мишень §, намертво запечённая бэкендом на случайную позицию ---}' +
    '          <div style="position:absolute; left:' + IntToStr(TargetX) + 'px; top:0; width:32px; height:32px; display:flex; align-items:center; justify-content:center; color:#BB99FF; font-weight:bold; font-size:16px; z-index:1;">§</div>' +
    '          ' +
    '          {--- Подвижный бирюзовый прицел ---}' +
    '          <div id="slider-thumb" style="position:absolute; left:0; top:0; width:32px; height:32px; background:transparent; border:1px solid #00FFFF; border-radius:50%; box-shadow:0 0 8px rgba(0,255,255,0.3); cursor:grab; z-index:2; display:flex; align-items:center; justify-content:center; background:#111;">' +
    '            <div style="width:6px; height:6px; background:#00FFFF; border-radius:50%;"></div>' +
    '          </div>' +
    '        </div>' +
    '      </div>' +
    '      ' +
    '      {--- СКРЫТЫЕ ПОЛЯ ДЛЯ СЕРВЕРНОЙ ПРОВЕРКИ ПРОМАХА ---}' +
    '      <input type="hidden" id="user_answer" name="user_answer" value="0">' +
    '      <input type="hidden" name="target_x" value="' + IntToStr(TargetX) + '">' +
    '      ' +
    '      <button type="submit" style="width:100%; background:transparent; border:1px solid #00FFFF; color:#00FFFF; padding:12px; border-radius:4px; font-size:14px; font-weight:bold; cursor:pointer; outline:none; letter-spacing:1px;">' +
    '        ОТПРАВИТЬ ССЫЛКУ АКТИВАЦИИ' +
    '      </button>' +
    '    </form>' +
    '  </div>' +
    '  ' +
    '  {--- БЕСШУМНЫЙ МЕХАНИЗМ КАЛИБРОВКИ ---}' +
    '  <script>' +
    '    (function() {' +
    '      var thumb = document.getElementById("slider-thumb");' +
    '      var track = document.getElementById("slider-track");' +
    '      var input = document.getElementById("user_answer");' +
    '      var isDragging = false;' +
    '      var startX, startLeft;' +
    '      ' +
    '      thumb.onmousedown = function(e) {' +
    '        isDragging = true;' +
    '        thumb.style.cursor = "grabbing";' +
    '        startX = e.clientX;' +
    '        startLeft = parseInt(thumb.style.left) || 0;' +
    '        return false;' +
    '      };' +
    '      ' +
    '      document.onmousemove = function(e) {' +
    '        if (!isDragging) return;' +
    '        var deltaX = e.clientX - startX;' +
    '        var newLeft = startLeft + deltaX;' +
    '        var maxLeft = track.clientWidth - thumb.clientWidth;' +
    '        if (newLeft < 0) newLeft = 0;' +
    '        if (newLeft > maxLeft) newLeft = maxLeft;' +
    '        thumb.style.left = newLeft + "px";' +
    '        input.value = newLeft;' + // Бесшумно пишем текущую координату в скрытый инпут
    '      };' +
    '      ' +
    '      document.onmouseup = function() {' +
    '        if (isDragging) {' +
    '          isDragging = false;' +
    '          thumb.style.cursor = "grab";' +
    '        }' +
    '      };' +
    '    })();' +
    '  </script>' +
    '</body></html>';
end;

  function HTML_RenderIndexPage(const ReqUser: string): string;
  var
   UserBlock: string;
  begin
     // Формируем блок профиля на основе значения ReqUser
     if ReqUser <> '' then
       UserBlock := 'Привет, <b>' + ReqUser + '</b>! | ' +
                    '<a href="/profile" style="color: #4A90E2; text-decoration: none;">[ Личный кабинет ]</a> | ' +
                    '<a href="/logout" style="color: #F44336; text-decoration: none;">[ Выход ]</a>'
     else
       UserBlock := '<a href="/login" style="color: #4A90E2; text-decoration: none;">[ Авторизация ]</a> | ' +
                    '<a href="/register" style="color: #4A90E2; text-decoration: none;">[ Регистрация ]</a>';

         Result :=
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

       '  <!-- Семантический Срез" -->' +
       '  <p style="color: #aaa; font-size: 14px; margin-bottom: 30px;">Ультракомпактный движок для работы с древовидными структурами данных без использования рекурсии.</p>' +
       '  <a href="/forum" class="btn-galaxy">🌌 Срез</a>' +

       '  <div class="footer">FPC Релиз • Архитектура Green Computing</div>' +
       '</div>' +

       '</body></html>';


  end;
  // 2. КОНСТРУКТОР СТРАНИЦЫ форума
  function HTML_RenderForumPage(const AReqUser, FHtmlBuffer: string): string;
  var
    ForumHeader: string;
     begin
          // Формируем сквозную шапку, которая встанет НАД обоими окнами
          if AReqUser <> '' then
            ForumHeader := '<div id="top-bar">' +
                           '  <div class="logo">🌌 Срез</div>' +
                           '  <div class="user-info">' +
                           '    Пилот: <b>' + AReqUser + '</b> | ' +
                           '    <a href="/profile" class="nav-btn">[ Личный кабинет ]</a> | ' +
                           '    <a href="/logout" class="nav-btn-exit">[ Выход ]</a> | ' +
                           '    <a href="/" class="nav-btn-gray">Главная</a>' +
                           '  </div>' +
                           '</div>'
          else
            ForumHeader := '<div id="top-bar">' +
                           '  <div class="logo">🌌 Срез</div>' +
                           '  <div class="user-info">' +
                           '    Вы зашли как гость | ' +
                           '    <a href="/login" class="nav-btn">[ Авторизация ]</a> | ' +
                           '    <a href="/register" class="nav-btn">[ Регистрация ]</a> | ' +
                           '    <a href="/" class="nav-btn-gray">Главная</a>' +
                           '  </div>' +
                           '</div>';

          Result :=
            '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Semantic Artist</title>' +
            '<style>' +
            '  body { margin: 0; padding: 0; overflow: hidden; display: flex; flex-direction: column; height: 100vh; background: #1e1e1e; color: #d4d4d4; font-family: sans-serif; }' +
            '  #top-bar { height: 45px; background: #252525; border-bottom: 1px solid #3c3c3c; display: flex; justify-content: space-between; align-items: center; padding: 0 20px; box-sizing: border-box; z-index: 10; }' +
            '  .logo { font-weight: bold; color: #00FFFF; letter-spacing: 0.5px; font-size: 15px; }' +
            '  .user-info { font-size: 13px; }' +
            '  .nav-btn { color: #00FFFF; text-decoration: none; margin-left: 10px; font-weight: bold; }' +
            '  .nav-btn-exit { color: #F44336; text-decoration: none; margin-left: 10px; }' +
            '  .nav-btn-gray { color: #aaa; text-decoration: none; margin-left: 10px; }' +
            '  #main-container { display: flex; flex-grow: 1; height: calc(100vh - 45px); overflow: hidden; }' +
            '  #left-panel { width: 50%; min-width: 150px; overflow-y: auto; padding: 10px; box-sizing: border-box; }' +
            '  #resizer { width: 6px; cursor: col-resize; background: #333; transition: 0.2s; }' +
            '  #resizer:hover { background: #4A90E2; }' +
            '  #right-panel { flex-grow: 1; background: #111; position: relative; overflow: hidden; }' +
            '  canvas { display: block; width: 100%; height: 100%; }' +
            '  html { scroll-behavior: smooth; }' +
            '</style></head><body>' +
            ForumHeader +
             '<div id="main-container">' +
            '  <div id="left-panel">' + FHtmlBuffer + '</div>' +
            '  <div id="resizer"></div>' +

            // 🎯 НАШЕ ОТРЕГУЛИРОВАННОЕ ДВУХРЕЖИМНОЕ ПРАВОЕ ОКНО:

                         '  <div id="right-panel" style="position: relative; display: flex; flex-direction: column;">' +

            // 1. Узкая, строгая футуристичная полоска вкладок (высота 30px) на самом чердаке окна:
            '    <div id="right-panel-tabs" style="height: 30px; background: #252526; border-bottom: 1px solid #333; display: flex; align-items: center; padding: 0 10px; box-sizing: border-box;">' +
            '      <button id="btn-tab-map" onclick="CloseEditorTab()" style="background: #1e1e1e; color: #00FFFF; border: 1px solid #00FFFF; padding: 2px 12px; font-size: 11px; font-weight: bold; cursor: pointer; border-radius: 4px; margin-right: 8px; outline: none;">🗺️ КАРТА</button>' +
            '      <button id="btn-tab-edit" onclick="OpenEditorTab()" style="background: transparent; color: #888; border: 1px solid #444; padding: 2px 12px; font-size: 11px; font-weight: bold; cursor: pointer; border-radius: 4px; outline: none;">📝 РЕДАКТОР</button>' +
            '    </div>' +

            // 2. Слой №1: Наш родной Canvas графической карты (занимает всё оставшееся пространство)
            '    <div id="tab-graph-map" style="flex: 1; display: block; width: 100%; position: relative;">' +
            '      <canvas id="artistCanvas"></canvas>' +
            '    </div>' +

            // 3. Слой №2: Изолированный контейнер фрейма редактора (абсолютно перекрывает карту по сигналу)
            '    <div id="tab-editor-container" style="display: none; position: absolute; top: 30px; bottom: 0; left: 0; right: 0; background: #1e1e1e; z-index: 10;">' +
            '      <iframe name="editor-viewport" id="editor-viewport" style="width: 100%; height: 100%; border: none;"></iframe>' +
            '    </div>' +

            '  </div>' + // Конец #right-panel

            '</div>' +
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

            // 🎯 МОДЕРНИЗИРОВАННЫЕ ФУНКЦИИ ПЕРЕКЛЮЧЕНИЯ (ОБНОВЛЯЮТ ЕЩЁ И СТИЛИ КНОПОК ДЛЯ НАГЛЯДНОСТИ):
            '  window.OpenEditorTab = function() {' +
            '    document.getElementById("tab-graph-map").style.display = "none";' +
            '    document.getElementById("tab-editor-container").style.display = "block";' +
            '    document.getElementById("btn-tab-edit").style.background = "#1e1e1e";' +
            '    document.getElementById("btn-tab-edit").style.color = "#00FFFF";' +
            '    document.getElementById("btn-tab-edit").style.border = "1px solid #00FFFF";' +
            '    document.getElementById("btn-tab-map").style.background = "transparent";' +
            '    document.getElementById("btn-tab-map").style.color = "#888";' +
            '    document.getElementById("btn-tab-map").style.border = "1px solid #444";' +
            '  };' +
            '  window.CloseEditorTab = function() {' +
            '    document.getElementById("tab-editor-container").style.display = "none";' +
            '    document.getElementById("tab-graph-map").style.display = "block";' +
            '    document.getElementById("btn-tab-map").style.background = "#1e1e1e";' +
            '    document.getElementById("btn-tab-map").style.color = "#00FFFF";' +
            '    document.getElementById("btn-tab-map").style.border = "1px solid #00FFFF";' +
            '    document.getElementById("btn-tab-edit").style.background = "transparent";' +
            '    document.getElementById("btn-tab-edit").style.color = "#888";' +
            '    document.getElementById("btn-tab-edit").style.border = "1px solid #444";' +
            '  };' +

            '</script></body></html>';
        end;
  // 3. КОНСТРУКТОР ОКНА взаимодействия
 // 3. КОНСТРУКТОР окна взаимодействия
  // 3. КОНСТРУКТОР окна взаимодействия
function HTML_RenderInteraction(const AParentID, AGateStack: string; ARank: Integer): string;
begin
  Result :=
      '<html><body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:20px; margin:0;">' +
      '  <script>' +
      '    if (parent && typeof parent.OpenEditorTab === "function") { parent.OpenEditorTab(); }' +
      '  </script>' +
      '  <div style="max-width: 700px; margin: 0 auto;">' +
      '    ' +
      '    <div style="margin-bottom:20px; font-weight:bold; font-size:15px;">' +
      '      <span style="color:#00FFFF; margin-right:10px;">🛰️ Интеракция с узлом ветки:</span>' + AGateStack +
      '    </div>' +
      '    ' +
      '    <form action="/save_reply" method="POST" style="margin:0; padding:0;">' +
      '      <input type="hidden" name="parent_id" value="' + AParentID + '">' +
      '      <input type="hidden" name="gate_stack" value="' + AGateStack + '">' +
      '      ' +
      '      <textarea name="reply_text" rows="8" placeholder="Введите ваше высказывание, описание синтаксических ошибок или аргументацию для модерации..." ' +
      '                style="width:100%; background:#252526; color:#fff; border:1px solid #444; border-radius:4px; padding:12px; resize:vertical; box-sizing:border-box; font-size:14px; font-family:sans-serif; margin-bottom:20px; outline:none; line-height:1.5;"></textarea>' +
      '      ' +
      '      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px; margin-bottom:15px;">' +
      '          <button type="button" onclick="if(parent && typeof parent.CloseEditorTab === &apos;function&apos;){parent.CloseEditorTab();}" ' +
      '                  style="background:transparent; border:1px solid #444; color:#888; padding:0 12px; border-radius:4px; cursor:pointer; font-size:13px; font-weight:bold; height:32px; outline:none; display:flex; align-items:center;">' +
      '            ◀ К карте ' +
      '          </button>' +
      '          ' +
      '          <div style="display:flex; gap:6px; flex-wrap:wrap;">' +


      '   <button type="submit" name="action_type" value="request_text_edit" ' +
      '     style="background:transparent; border:1px solid #00FFFF; color:#00FFFF; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:16px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '     ?' +
      '   </button>' +

      '            <button type="submit" name="action_type" value="apply_moderation" ' +
      '                    style="background:transparent; border:1px solid #BB99FF; color:#BB99FF; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:15px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               §' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="syntax_error" ' +
      '                    style="background:transparent; border:1px solid #ff9900; color:#ff9900; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:16px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               !' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="report_deletion" ' +
      '                    style="background:transparent; border:1px solid #ff9900; color:#ff9900; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:16px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               X' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="reply_confirm" ' +
      '                    style="background:transparent; border:1px solid #00FFaa; color:#00FFaa; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:16px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               +' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="reply_refuse" ' +
      '                    style="background:transparent; border:1px solid #00FFaa; color:#00FFaa; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:16px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               -' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="alternative" ' +
      '                    style="background:transparent; border:1px solid #00FFFF; color:#00FFFF; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:14px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               &lt;' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="merge_request" ' +
      '                    style="background:transparent; border:1px solid #00FFFF; color:#00FFFF; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:15px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               &amp;' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="merge_proposal" ' +
      '                    style="background:transparent; border:1px solid #00FFFF; color:#00FFFF; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:14px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               &gt;' +
      '            </button>' +
      '            ' +
      '            <button type="submit" name="action_type" value="request_edit" ' +
      '                    style="background:transparent; border:1px solid #00FFFF; color:#00FFFF; width:32px; height:32px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:16px; outline:none; display:flex; align-items:center; justify-content:center;">' +
      '               ≈' +
      '            </button>' +
      '          </div>' +
      '      </div>' +
      '      ' +
      '    </form>' +
      '  </div>' +
      '</body></html>';
end;
 // 4. КОНСТРУКТОР СТРАНИЦЫ РЕГИСТРАЦИИ
 function HTML_RenderRegisterPage: string;
begin
  Result :=  '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Регистрация</title>' +
          '<style>' +
          '  body { background: #1e1e1e; color: #eee; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }' +
          '  .reg-box { background: #2d2d2d; padding: 30px; border-radius: 5px; border: 1px solid #444; width: 300px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }' +
          '  h2 { margin-top: 0; color: #4A90E2; text-align: center; font-size: 22px; }' +
          '  label { display: block; font-size: 13px; color: #aaa; margin-top: 10px; }' +
          '  input[type="text"], input[type="password"] { width: 100%; padding: 10px; margin: 5px 0 15px 0; border: 1px solid #555; background: #111; color: #fff; box-sizing: border-box; border-radius: 3px; }' +
          '  input[type="submit"] { width: 100%; padding: 12px; background: #4A90E2; border: none; color: white; font-weight: bold; cursor: pointer; border-radius: 3px; font-size: 14px; transition: 0.2s; }' +
          '  input[type="submit"]:hover { background: #357ABD; }' +
          '  .link { text-align: center; margin-top: 15px; font-size: 13px; }' +
          '  .link a { color: #888; text-decoration: none; }' +
          '  .link a:hover { color: #4A90E2; }' +
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
          '  <div class="link"><a href="/login">Уже есть аккаунт? Войти</a> | <a href="/">На главную</a></div>' +
          '</div>' +
          '</body></html>';
end;
 // 5. КОНСТРУКТОР СТРАНИЦЫ АВТОРИЗАЦИИ
function HTML_RenderLoginPage: string;
begin
  Result :=           '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Вход</title>' +
          '<style>' +
          '  body { background: #1e1e1e; color: #eee; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }' +
          '  .login-box { background: #2d2d2d; padding: 30px; border-radius: 5px; border: 1px solid #444; width: 300px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }' +
          '  h2 { margin-top: 0; color: #4A90E2; text-align: center; font-size: 22px; }' +
          '  label { display: block; font-size: 13px; color: #aaa; margin-top: 10px; }' +
          '  input[type="text"], input[type="password"] { width: 100%; padding: 10px; margin: 5px 0 15px 0; border: 1px solid #555; background: #111; color: #fff; box-sizing: border-box; border-radius: 3px; }' +
          '  input[type="submit"] { width: 100%; padding: 12px; background: #4A90E2; border: none; color: white; font-weight: bold; cursor: pointer; border-radius: 3px; font-size: 14px; transition: 0.2s; }' +
          '  input[type="submit"]:hover { background: #357ABD; }' +
          '  .link { text-align: center; margin-top: 15px; font-size: 13px; }' +
          '  .link a { color: #888; text-decoration: none; }' +
          '  .link a:hover { color: #4A90E2; }' +
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
          '  <div class="link"><a href="/register">Регистрация</a> | <a href="/">На главную</a></div>' +
          '</div>' +
          '</body></html>';
end;
 // 6. КОНСТРУКТОР ЛИЧНОГО КАБИНЕТА
function HTML_RenderProfilePage(const ReqUser: string; ULimit: Integer): string;
begin
  Result :=           '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Личный кабинет</title>' +
          '<style>' +
          '  body { background: #1e1e1e; color: #eee; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }' +
          '  .profile-box { background: #2d2d2d; padding: 30px; border-radius: 5px; border: 1px solid #444; width: 350px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }' +
          '  h2 { margin-top: 0; color: #00FFFF; text-align: center; }' +
          '  .info { font-size: 14px; color: #aaa; margin-bottom: 20px; text-align: center; }' +
          '  label { display: block; font-size: 13px; color: #ccc; margin-top: 15px; }' +
          '  input[type="number"], select { width: 100%; padding: 10px; margin: 5px 0 15px 0; border: 1px solid #555; background: #111; color: #fff; box-sizing: border-box; border-radius: 3px; }' +
          '  input[type="submit"] { width: 100%; padding: 12px; background: #00FFFF; border: none; color: #111; font-weight: bold; cursor: pointer; border-radius: 3px; font-size: 14px; transition: 0.2s; }' +
          '  input[type="submit"]:hover { background: #00b3b3; }' +
          '  .link { text-align: center; margin-top: 20px; font-size: 13px; }' +
          '  .link a { color: #888; text-decoration: none; }' +
          '</style></head><body>' +
          '<div class="profile-box">' +
          '  <h2>Личный кабинет</h2>' +
          '  <div class="info">Пилот семантического пространства: <b>' + ReqUser + '</b></div>' +
          '  <form method="POST" action="/profile">' +
          '    <label>Лимит узлов среза на страницу:</label>' +
          '    <input type="number" name="limit" value="' + IntToStr(ULimit) + '" min="1" max="500" required>' +
          '    <input type="submit" value="Сохранить настройки">' +
          '  </form>' +
          '  <div class="link"><a href="/forum">🌌 Назад к срезу</a> | <a href="/">Главная</a></div>' +
          '</div>' +
          '</body></html>';
end;

procedure TSemanticApp.HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
                                     var AResponse: TFPHTTPConnectionResponse);
var
  Path: string;
  TempWorker: TServerWorker;
  ReqUser, ReqPass: string;
  UID, ULimit,UserRankInt: Integer;
  UTheme: string;
  UserBlock: string;
  ForumHeader: string;
    TargetParent: string;
  GateStackDNA, TextContent: string;
  IsUserAuth: Boolean;
  ////////////////////////////////////////////
   ClientIP: string;
  MachineName: string;
  ShieldQuery: string;
  HasBan: Boolean;
  CurrentMisses: Integer;
  TargetX, UserAnswer, Delta: Integer;
  ReqEmail: string;       // УБРАЛ ОТСЮДА ReqUser, ТАК КАК ОН УЖЕ ОБЪЯВЛЕН ВЫШЕ!
  UnlockTimeStr , Dummy: string;
begin
 /////////////////////////////////////////////////////////
  ReqUser := '';
   IsUserAuth := False;
  // ВЫВОДИМ В КОНСОЛЬ ВСЕ ВХОДЯЩИЕ КУКИ ДЛЯ ПРОВЕРКИ
  WriteLn('   [ОТЛАДКА] Сырая строка CookieFields: "', ARequest.CookieFields.Text, '"');
  WriteLn('   [ОТЛАДКА] Сырой заголовок Cookie: "', ARequest.CustomHeaders.Values['Cookie'], '"');

  // Пытаемся прочитать
  if ARequest.CookieFields <> nil then
    ReqUser := Trim(ARequest.CookieFields.Values['auth_user']);

  if ReqUser <> '' then
    begin
    WriteLn('   [СЕРВЕР] Распознан пользователь из сессии: "', ReqUser, '"');
    IsUserAuth := True;

    end
  else
    WriteLn('   [СЕРВЕР] Запрос от неавторизованного гостя.');


  Path := ARequest.PathInfo;

  // 1. Корень (Главная страница)
  if (Path = '/') or (Path = '') then
  begin
     AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content := HTML_RenderIndexPage(UserBlock);
   end

    else  if (Path = '/') or (Path = '') then
  begin
    AResponse.ContentType := 'text/html; charset=utf-8';
    // ... логика определения UserBlock ...
    AResponse.Content := HTML_RenderIndexPage(UserBlock);
  end

  // 2. рабочий блок Форума

  else if Path = '/forum' then
  begin
         TempWorker.TailStack := nil;
        SetLength(TempWorker.TailStack, 0);
    WriteLn('   [СИСТЕМА] Запуск обхода дерева для браузера...');
    ULimit := 50;
    UTheme := 'dark';
        //  Если пользователь распознан (ReqUser не пустой) — вытягиваем ЕГО личный лимит из базы
    if ReqUser <> '' then
    begin
      // Вместо VerifyUser просто берем лимит по имени из куки
//ULimit := Self.FDB.GetUserLimit(ReqUser);
WriteLn('   [СЕРВЕР] Для пользователя ', ReqUser, ' применен лимит: ', ULimit);
    end;
        if ReqUser <> '' then
    begin
      // Вызываем  рабочий метод модуля базы данных:
      ULimit := FDB.GetUserLimit(ReqUser);
    end;
    TempWorker := TServerWorker.Create(Self.FDB, nil, nil, emToViewer, IsUserAuth);

     //Прошиваем лимит ЛК внутрь публичного поля воркера!
    TempWorker.FMaxNodes := ULimit;
    //TempWorker.FChunk := True;
    try
       TempWorker.FMaxNodes := ULimit;
      TempWorker.ExposeSystem('');
      AResponse.ContentType := 'text/html; charset=utf-8';

      if TempWorker.FHtmlBuffer = '' then
        AResponse.Content := '<html><body><h1>Ошибка: Буфер пуст</h1></body></html>'
      else
        AResponse.Content := HTML_RenderForumPage(ReqUser, TempWorker.FHtmlBuffer);/////////////////////////////////////////////////////////////////////////////////////////////
      if TempWorker.Suspended then
        TempWorker.Start;
    finally
      TempWorker.Free;
    end;
  end // <--- Конец блока /forum

    // ЗАПРОС НА БЕСШОВНУЮ ПОДГРУЗКУ ЧАНКА СЛОЯ
  else if (Path = '/forum_chunk') or (Path = '/forum_chunk/') then
  begin
    // Считываем лимит из СУБД (ReqUser у тебя вычислен сервером выше по коду)
    ULimit := 50; // Базовый предохранитель
    if ReqUser <> '' then ULimit := FDB.GetUserLimit(ReqUser);
        // Создаем экземпляр воркера (False на конце — поток не заморожен)
    TempWorker := TServerWorker.Create(Self.FDB, nil, nil, emToViewer, IsUserAuth);
    TempWorker.FMaxNodes := ULimit;
    TempWorker.FChunk := True; // Включаем режим чанка

    try
      // ВЫЗОВ С ЕДИНЫМ СТРОКОВЫМ ПАРАМЕТРОМ:
      // Склеиваем параметры URL и тела POST, воркер внутри сам во всём разберётся
      TempWorker.ExposeSystem(ARequest.QueryFields.Text + '&' + ARequest.ContentFields.Text);

      AResponse.ContentType := 'text/html; charset=utf-8';
      AResponse.Content := TempWorker.FHtmlBuffer;
      AResponse.SendContent;
      if TempWorker.Suspended then
        TempWorker.Start;
    finally
      TempWorker.Free;
    end;
  end


  else if Path = '/interaction' then
    begin
    // 1. Первый барьер безопасности: гостя отсекаем сразу
    if ReqUser = '' then
    begin
      AResponse.ContentType := 'text/html; charset=utf-8';
      AResponse.Content := '<html><body>🚨 Доступ ограничен. Авторизуйтесь.</body></html>';
      Exit;
    end;

    // 2. Считываем параметры "мелкоты" из сетевого кабеля
    TargetParent := ARequest.QueryFields.Values['pid'];
    GateStackDNA := ARequest.QueryFields.Values['gate_stack'];

    // 🎯 3. ИДЕАЛЬНЫЙ АКАДЕМИЧЕСКИЙ ВЫЗОВ:
    // Роутер больше не занимается черновой SQL-работой. Он просто просит модуль FDB
    // узнать ранг пользователя по имени через вылеченную функцию GetUserRank!
    UserRankInt := Self.FDB.GetUserRank(ReqUser);


    AResponse.ContentType := 'text/html; charset=utf-8';

    // Скармливаем функции конструктора живую роль, вычисленную по числу из SQLite!
    AResponse.Content := HTML_RenderInteraction(TargetParent, GateStackDNA, UserRankInt);
  end
  // -----МАРШРУТ : ПРИЁМ ОТВЕТА
    else if Path = '/save_reply' then
  begin
    //// Извлекаем "мелкоту" и текст ответа из POST-параметров сетевого кабеля:
    //TargetParent := ARequest.ContentFields.Values['parent_id'];
    //GateStackDNA := ARequest.ContentFields.Values['gate_stack'];
    //TextContent  := ARequest.ContentFields.Values['reply_text'];
    //
    //// Пишем зрячий лог в консоль Jetson Nano для контроля транзита данных:
    //WriteLn('   [БЭКЕНД] Принят пакет сохранения ответа!');
    //WriteLn('            Родительский узел: #', TargetParent);
    //WriteLn('            Родословная (DNA): ', GateStackDNA);
    //WriteLn('            Текст сообщения  : "', TextContent, '"');
    //
    //AResponse.ContentType := 'text/html; charset=utf-8';
    //
    //// Временно выдаем во фрейм текстовое подтверждение, чтобы проверить физику моста:
    //AResponse.Content :=
    //  '<html><body style="font-family:sans-serif; background:#1e1e1e; color:#00FFFF; padding:20px;">' +
    //  '  <h4 style="margin:0 0 10px 0;">✔ Пакет успешно доставлен на Jetson Nano!</h4>' +
    //  '  <p style="color:#aaa; font-size:13px; margin:0;">Текст зафиксирован в ОЗУ сервера. База данных SQLite готова к записи.</p>' +
    //  '</body></html>';
    //
    //// Никаких ручных SendContent! Паскаль вытолкнет буфер автоматически при выходе из процедуры
  // Вытягиваем текст и хронологию из полей формы Хрома
  // 1. Принудительно заставляем Паскаль распарсить POST-тело из сети
  // 1. Принудительно заставляем Паскаль распарсить POST-тело из сети
   // 1. Извлекаем данные запроса
   // 🎯 ТОТ САМЫЙ СЕТЕВОЙ ПИНОК: принудительно выкачиваем POST-тело из сети в ОЗУ
  // 1. Сетевой пинок — выкачиваем буфер POST

  //Dummy := ARequest.ContentFields.Text;

  // 2. Считываем данные строго в твои родные переменные
  TextContent := ARequest.ContentFields.Values['reply_text'];
  TargetParent := ARequest.ContentFields.Values['parent_id'];
  ShieldQuery  := ARequest.ContentFields.Values['action_type'];

  // 3. Обработка импульса кнопки [+]
  if (ShieldQuery = 'reply_confirm') and (TargetParent <> '') then
  begin
    try
      // Просто вызываем твой готовый метод! SQLite сама выдаст ID новой записи
      Self.FDB.LandingNode(StrToIntDef(TargetParent, 0), TextContent);
      WriteLn(' [БЭКЕНД] Кнопка [+] успешно отработала через LandingNode!');
    except
      on E: Exception do WriteLn(' !!! [БЭКЕНД ОШИБКА]: ', E.Message);
    end;
  end;

  // 4. Бесшумно закрываем фрейм редактора через JavaScript
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content := '<html><body><script>if (parent && parent.CloseEditorTab) parent.CloseEditorTab();</script></body></html>';


  end
    // --- МАРШРУТ : РЕГИСТРАЦИЯ ---
    else if Path = '/register' then
    begin
      //AResponse.ContentType := 'text/html; charset=utf-8';
      //if ARequest.Method = 'GET' then
      //begin
      //  AResponse.Content := HTML_RenderRegisterPage();
      //end
      //else if ARequest.Method = 'POST' then
      //begin
      //  ReqUser := Trim(ARequest.ContentFields.Values['user']); // Исправлен пробел
      // // ReqPass := Trim(ARequest.ContentFields.Values['pass']);
      //       // ХЭШИРУЕМ ПАРОЛЬ ПЕРЕД ОТПРАВКОЙ В БАЗУ:
      //ReqPass := MD5Print(MD5String(ARequest.ContentFields.Values['pass'])); //поставил точку с запятой, теперь эта строка
      //  if Self.FDB.RegisterUser(ReqUser, ReqPass) then
      //  begin
      //    AResponse.SendRedirect('/login');
      //    Exit; // Жесткая изоляция от проваливания кода вниз
      //  end
      //  else
      //    AResponse.Content := '<html><body><h2>Ошибка регистрации</h2></body></html>';
      //end;
    // Генерируем два случайных числа для математической капчи (от 1 до 9)
    // Randomize вызывается один раз при старте сервера, здесь просто берем такты
        AResponse.ContentType := 'text/html; charset=utf-8';
    AResponse.Content := HTML_RenderRegisterForm('');
    end

    // --- МАРШРУТ : ВХОД (ЛОГИН) ---
    else if Path = '/login' then
    begin
      AResponse.ContentType := 'text/html; charset=utf-8';
      if ARequest.Method = 'GET' then
      begin
        AResponse.Content :=  HTML_RenderLoginPage();
      end
      else if ARequest.Method = 'POST' then
      begin
        ReqUser := Trim(ARequest.ContentFields.Values['user']);
        //ReqPass := ARequest.ContentFields.Values['pass']; // БЕЗ Trim! В первозданном виде
        // ХЭШИРУЕМ ПАРОЛЬ ДЛЯ СВЕРКИ С БАЗОЙ:
            ReqPass := MD5Print(MD5String(ARequest.ContentFields.Values['pass']));
        // Вызываем строго с ДВУМЯ параметрами, как сейчас реализовано в unit_db.pas
        if Self.FDB.VerifyUser(ReqUser, ReqPass) then
        begin
          with AResponse.Cookies.Add do
          begin
            Name := 'auth_user';
            Value := ReqUser;
            Path := '/';
            HttpOnly := True;
          end;
          AResponse.SendRedirect('/forum');
          Exit; // Защита от проваливания кода вниз
        end
        else
        begin
          AResponse.Content := '<html><body><h2>Неверный логин или пароль</h2><a href="/login">Назад</a></body></html>';
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
     // --- МАРШРУТ : ЛИЧНЫЙ КАБИНЕТ ---
   else if Path = '/profile' then
  begin
    // Дублируем чтение куки прямо внутри маршрута для максимальной надежности
    if ARequest.CookieFields <> nil then
      ReqUser := Trim(ARequest.CookieFields.Values['auth_user']);

    if ReqUser = '' then
    begin
      WriteLn('   [СЕРВЕР] Попытка несанкционированного входа в ЛК. Перенаправление на /login');
      AResponse.SendRedirect('/login');
      Exit; // Жестко прерываем поток выполнения запроса!
    end
    else
    begin
      AResponse.ContentType := 'text/html; charset=utf-8';

      // GET: Запрашиваем страницу кабинета
      if ARequest.Method = 'GET' then
      begin
        // ПРИНУДИТЕЛЬНО ОБНУЛЯЕМ МУСОР В ПАМЯТИ ПЕРЕД ВЫЗОВОМ БАЗЫ!
        ULimit := 0;

        // Запрашиваем лимит у базы данных
        ULimit := Self.FDB.GetUserLimit(ReqUser);

        // Страховочный предохранитель: если база почему-то вернула 0, ставим жесткие 50
        if ULimit <= 0 then ULimit := 50;

        WriteLn('   [СЕРВЕР] ЛК отображается для пилота: "', ReqUser, '". Выводимый лимит: ', ULimit);

        AResponse.Content := HTML_RenderProfilePage(ReqUser, ULimit);
      end

      // POST: Принимаем измененные настройки от пользователя
      else if ARequest.Method = 'POST' then
      begin
        ReqPass := ARequest.ContentFields.Values['limit'];
        ULimit := StrToIntDef(ReqPass, 50);

        WriteLn('   [СЕРВЕР] Получен POST-запрос на смену лимита для "', ReqUser, '": ', ULimit);

        if Self.FDB.UpdateUserPrefs(ReqUser, ULimit) then
        begin
          AResponse.SendRedirect('/forum');
          Exit;
        end
        else
        begin
          AResponse.Content := '<html><body><h2>Ошибка сохранения настроек</h2><a href="/profile">Назад</a></body></html>';
        end;
      end;
    end;
  end
   else if Path = '/do_register' then
  begin
 //WriteLn(' [СЕТЕВОЙ ТЕСТ] Сырой POST: ', ARequest.ContentFields.Text);
 //   WriteLn(' [СЕТЕВОЙ ТЕСТ] Считано из формы -> TargetX: ', TargetX, ' | UserAnswer: ', UserAnswer);
 //   AResponse.ContentType := 'text/html; charset=utf-8';
 //
 //   // 1. ИДЕНТИФИКАЦИЯ МАШИНЫ: Берем чистый IP-адрес Хрома в качестве хостнейма
 //   ClientIP := ARequest.RemoteAddr;
 //   MachineName := ClientIP;
 //
 //   // 2. СБОР КООРДИНАТ ИЗ ФОРМЫ
 //   TargetX := StrToIntDef(ARequest.ContentFields.Values['target_x'], 0);
 //   UserAnswer := StrToIntDef(ARequest.ContentFields.Values['user_answer'], 0);
 //   ReqEmail := Trim(ARequest.ContentFields.Values['email']);

  AResponse.ContentType := 'text/html; charset=utf-8';

    // 1. ИДЕНТИФИКАЦИЯ МАШИНЫ
    ClientIP := ARequest.RemoteAddr;
    MachineName := ClientIP;

    // 🎯 КРИТИЧЕСКИЙ МАНЕВР: Принудительно заставляем Паскаль распарсить POST-тело прямо сейчас
    // (Это гарантирует, что ContentFields мгновенно заполнится данными из сети)
    Dummy := ARequest.ContentFields.Text;

    // 2. СБОР КООРДИНАТ ИЗ ФОРМЫ (Теперь строки стоят на своём законном, зрячем месте!)
    TargetX := StrToIntDef(ARequest.ContentFields.Values['target_x'], 0);
    UserAnswer := StrToIntDef(ARequest.ContentFields.Values['user_answer'], 0);
    ReqEmail := Trim(ARequest.ContentFields.Values['email']);

    // НАШ ОТЛАДОЧНЫЙ ТЕСТ (Посмотришь, как изменятся цифры в консоли!)
    WriteLn(' [СЕТЕВОЙ ТЕСТ] Сырой POST: ', ARequest.ContentFields.Text);
    WriteLn(' [СЕТЕВОЙ ТЕСТ] Считано из формы -> TargetX: ', TargetX, ' | UserAnswer: ', UserAnswer);

    // 3. МАТЕМАТИКА КАЛИБРОВКИ: Вычисляем дельту попадания ползунка (допуск 15 пикселей)
    Delta := Abs(TargetX - UserAnswer);

    // 4. ТАКТ ПРОВЕРКИ ПРОМАХА
    if Delta > 15 then
    begin
      // Стучимся в твою БД через новый метод (его структуру мы пропишем в модуле базы)
      // Передаем MachineName и флаг IsMiss = True
      // Функция запишет промах в SQLite и вернет текущее количество осечек
      CurrentMisses := Self.FDB.LogBotAttempt(MachineName, True);

      if CurrentMisses >= 3 then
      begin
        AResponse.Content := HTML_RenderRegisterForm('Калибровка провалена 3 раза подряд. Система заблокировала доступ для вашей машины на 1 час.');
      end
      else
      begin
        AResponse.Content := HTML_RenderRegisterForm('Приборы не откалиброваны (промах на ' + IntToStr(Delta) + 'px). Попробуйте совместить метку точнее.');
      end;
      Exit;
    end;

    {=== ТАКТ СНАЙПЕРСКОГО ПОПАДАНИЯ (ЧЕЛОВЕК ПРОШЁЛ) ===}
    // Сбрасываем промахи в ноль внутри БД (IsMiss = False)
    Self.FDB.LogBotAttempt(MachineName, False);

    // Блокируем дублирование ника по твоей классической схеме:
    // (Пока выводим успешный маркер прохождения калибровки)
    AResponse.Content := '<html><head><meta charset="utf-8"></head><body><h2>Калибровка успешна! Проверка ника и отправка письма...</h2></body></html>';
  end
  // 3. Если зашли по непонятному адресу
  else
  begin
    AResponse.Code := 404;
    AResponse.Content := '<html><body><h1>404 Not Found</h1></body></html>';
  end;
end;


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



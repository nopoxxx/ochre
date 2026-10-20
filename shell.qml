import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

ShellRoot {
    // синглтоны создаются при первом обращении — проверка обновлений должна работать,
    // даже если модуль ochre ↑ убран с панели
    readonly property var _shellUpdate: ShellUpdate
    readonly property var _binds: Binds   // пишет ochre/keys.kdl при старте
    readonly property var _appTheme: AppTheme   // темы GTK и Qt вслед за shell
    readonly property var _defaultApps: DefaultApps   // оболочка и браузер — из системы в настройки
    readonly property var _muteNotify: MuteNotify   // уведомление при мьюте микрофона и звука
    readonly property var _clipboard: Clipboard   // запись истории буфера (cliphist), даже если окно не открывали
    readonly property var _home: Home             // IPC home: меню открывается и биндом, до первого клика
    readonly property var _night: NightLight      // ночной режим держится с запуска shell
    readonly property var _recorder: Recorder     // IPC record (Mod+Alt+R)
    readonly property var _countdown: Countdown   // таймер: конец отсчёта, даже если модуль timer убран
    readonly property var _cast: Cast             // бэкенд портала для демонстрации экрана: файлы и мост к демону
    readonly property var _game: Game             // IPC game (Mod+Shift+G)
    readonly property var _songRec: SongRec       // IPC songrec (Mod+Shift+M)
    readonly property var _errors: Errors         // ошибки shell и niri — с запуска, а не с первой ошибки
    readonly property var _hooks: Hooks           // ~/.config/ochre/hooks/<событие>
    readonly property var _screenTime: ScreenTime // время за экраном считается с запуска, а не с открытия home
    readonly property var _wallPalette: WallPalette

    // поставлен пакетом: pacman меняет файлы под работающим shell, и перезагрузка посреди обновления
    // ломает его — перезапуск только по уведомлению после обновления (ShellUpdate)
    Component.onCompleted: {
        if (Ochre.system) Quickshell.watchFiles = false;
        ShellUpdate.booted();
    }

    // перечитать весь конфиг (и .js) в том же процессе: без qs kill, который в Quickshell 0.3.2 может упасть на выходе
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(true); }
    }

    Variants {
        model: Quickshell.screens
        Background {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Settings.get("shell.bar.monitors") === "primary" ? [Quickshell.screens[0]] : Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Launcher {}
    WallPicker {}
    ShotWindow {}
    SettingsWindow {}
    NotifPopups {}
    LockScreen {}
    GreeterSync {}
    DisplaysWindow {}
    BindsWindow {}
    CheatSheet {}
    ClipboardWindow {}
    HomePanel {}
    OsdWindow {}
    ErrorsWindow {}
    PolkitWindow {}
    CastWindow {}
    WelcomeWindow {}
}

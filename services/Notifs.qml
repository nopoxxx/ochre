pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Сервер уведомлений: история, всплывающие карточки, «не беспокоить».
//   qs ipc call notify dnd    — переключить «не беспокоить»
//   qs ipc call notify clear  — очистить историю
//   qs ipc call notify hide   — убрать всплывающие с экрана, история остаётся
Singleton {
    id: root

    // запись: { key, time, app, summary, body, urgency, actions: [{ id, text, action }], notif }
    property var history: []
    property var entries: ({})     // key → запись, для карточек
    property int unread: 0
    property bool centerOpen: false   // пока открыта история, карточки не мешают поверх неё
    property int _seq: 0
    // игровой режим глушит уведомления, не трогая сохранённое значение
    readonly property bool dnd: Settings.get("shell.notify.dnd") || Game.on && Settings.get("shell.game.dnd")

    // на экране — только ключи: ListModel не пересоздаёт остальные карточки при добавлении новой
    readonly property alias popups: popupModel

    function level(u) {
        return u === NotificationUrgency.Critical ? "ERROR" : u === NotificationUrgency.Low ? "DEBUG" : "INFO";
    }

    // тело может прийти с разметкой — показываем как простой текст
    function clean(s) {
        return (s ?? "").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
            .replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }

    function push(n) {
        const e = {
            key: ++_seq,
            time: new Date(),
            app: n.appName || "?",
            summary: clean(n.summary),
            body: clean(n.body),
            urgency: n.urgency,
            actions: Array.from(n.actions ?? []).map(a => ({ id: a.identifier, text: a.text, action: a })),
            notif: n
        };
        entries[e.key] = e;
        // transient (мьют, громкость и т.п.) — только попап, без истории
        if (!n.transient) {
            history = [e].concat(history).slice(0, 100);
            unread++;
        }
        n.closed.connect(() => {
            removePopup(e.key);
            e.notif = null;
        });

        if (dnd && n.urgency !== NotificationUrgency.Critical) return;
        const onTop = Settings.get("shell.notify.position").startsWith("top");
        popupModel.insert(onTop ? 0 : popupModel.count, { key: e.key });
        while (popupModel.count > Settings.get("shell.notify.max"))
            popupModel.remove(onTop ? popupModel.count - 1 : 0);
    }

    function removePopup(key) {
        for (let i = 0; i < popupModel.count; i++)
            if (popupModel.get(i).key === key) {
                popupModel.remove(i);
                return;
            }
    }

    // убрать с экрана, но оставить в истории
    function hidePopup(e) { removePopup(e.key); }

    function dismiss(e) {
        removePopup(e.key);
        if (e.notif) e.notif.dismiss();
    }

    // действие по умолчанию, если оно есть; иначе просто закрыть
    function invoke(e, a) {
        const act = a ?? e.actions.find(x => x.id === "default");
        const resident = e.notif?.resident ?? false;
        if (act && e.notif) act.action.invoke();
        if (!resident) dismiss(e);
        else removePopup(e.key);
    }

    function remove(e) {
        history = history.filter(h => h.key !== e.key);
        dismiss(e);
    }

    function removeAll(list) {
        const keys = new Set(list.map(e => e.key));
        history = history.filter(h => !keys.has(h.key));
        for (const e of list) dismiss(e);
    }

    function clear() {
        for (const h of history)
            if (h.notif) h.notif.dismiss();
        history = [];
        popupModel.clear();
        unread = 0;
    }

    function markRead() { unread = 0; }
    function toggleDnd() { Settings.set("shell.notify.dnd", !Settings.get("shell.notify.dnd")); }

    ListModel { id: popupModel }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: false
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            root.push(n);
        }
    }

    IpcHandler {
        target: "notify"
        function dnd(): void { root.toggleDnd(); }
        function clear(): void { root.clear(); }
        function hide(): void { popupModel.clear(); }
    }
}

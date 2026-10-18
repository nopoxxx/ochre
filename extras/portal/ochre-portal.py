#!/usr/bin/env python3
# ochre-portal — бэкенд xdg-desktop-portal для демонстрации экрана (org.freedesktop.impl.portal.ScreenCast).
#
# Discord, браузер, OBS просят демонстрацию у портала, портал — у этого бэкенда. Что показать, выбирает окно
# ochre (CastWindow.qml): демон шлёт запрос shell'у и ждёт ответа, потом через API Mutter, который реализует niri
# (org.gnome.Mutter.ScreenCast), записывает выбранный монитор или окно и отдаёт порталу узел PipeWire.
#
# Демон запускается D-Bus'ом по первому запросу (~/.local/share/dbus-1/services, файлы пишет services/Cast.qml),
# shell подключается к нему через unix-сокет $XDG_RUNTIME_DIR/ochre-portal.sock: `ochre-portal.py --client` —
# мост stdin/stdout ↔ сокет, его держит Process в shell. Строки JSON:
#   демон → shell: {"op": "pick", "id", "app", "types", "multiple"}, {"op": "cancel", "id"}
#   shell → демон: {"op": "answer", "id", "choice": {"type": "monitor", "name"} | {"type": "window", "id"} | null}
# Shell не подключён (упал, выключен shell.cast) — сессия целиком уходит бэкенду gnome: демонстрация работает всегда.

import json
import os
import socket
import sys
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

NAME = "org.freedesktop.impl.portal.desktop.ochre"
PATH = "/org/freedesktop/portal/desktop"
IFACE = "org.freedesktop.impl.portal.ScreenCast"
GNOME = "org.freedesktop.impl.portal.desktop.gnome"
MUTTER = "org.gnome.Mutter.ScreenCast"
SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "ochre-portal.sock")

MONITOR, WINDOW = 1, 2
# курсор: портал — 1 hidden, 2 embedded, 4 metadata; Mutter — 0, 1, 2
CURSOR = {1: 0, 2: 1, 4: 2}
NO_TIMEOUT = GLib.MAXINT32

SCREENCAST_XML = f"""<node><interface name="{IFACE}">
  <method name="CreateSession"><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="s" direction="in"/>
    <arg type="a{{sv}}" direction="in"/><arg type="u" direction="out"/><arg type="a{{sv}}" direction="out"/></method>
  <method name="SelectSources"><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="s" direction="in"/>
    <arg type="a{{sv}}" direction="in"/><arg type="u" direction="out"/><arg type="a{{sv}}" direction="out"/></method>
  <method name="Start"><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="s" direction="in"/>
    <arg type="s" direction="in"/><arg type="a{{sv}}" direction="in"/><arg type="u" direction="out"/><arg type="a{{sv}}" direction="out"/></method>
  <property name="AvailableSourceTypes" type="u" access="read"/>
  <property name="AvailableCursorModes" type="u" access="read"/>
  <property name="version" type="u" access="read"/>
</interface></node>"""
SESSION_XML = """<node><interface name="org.freedesktop.impl.portal.Session">
  <method name="Close"/><signal name="Closed"/><property name="version" type="u" access="read"/>
</interface></node>"""
REQUEST_XML = """<node><interface name="org.freedesktop.impl.portal.Request"><method name="Close"/></interface></node>"""

SC_INFO = Gio.DBusNodeInfo.new_for_xml(SCREENCAST_XML).interfaces[0]
SESSION_INFO = Gio.DBusNodeInfo.new_for_xml(SESSION_XML).interfaces[0]
REQUEST_INFO = Gio.DBusNodeInfo.new_for_xml(REQUEST_XML).interfaces[0]


def log(*a):
    print("ochre-portal:", *a, file=sys.stderr, flush=True)


def reply(inv, code, results=None):
    inv.return_value(GLib.Variant("(ua{sv})", (code, results or {})))


class Session:
    def __init__(self, path, app_id, proxy):
        self.path = path
        self.app_id = app_id
        self.proxy = proxy          # True — сессию ведёт gnome
        self.types = MONITOR
        self.multiple = False
        self.cursor = 1
        self.reg = 0
        self.mutter = None          # путь сессии Mutter
        self.subs = []
        self.closed = False


class Portal:
    def __init__(self, bus):
        self.bus = bus
        self.sessions = {}
        self.pending = {}           # id запроса → (invocation, session, handle, request reg)
        self.next_id = 0
        self.client = None          # сокет shell
        self.buf = b""
        self.started = os.stat(__file__).st_mtime

    # ── shell ──
    def send(self, msg):
        if not self.client:
            return False
        try:
            self.client.sendall((json.dumps(msg, ensure_ascii=False) + "\n").encode())
            return True
        except OSError:
            self.drop_client()
            return False

    def drop_client(self):
        if self.client:
            try:
                self.client.close()
            except OSError:
                pass
        self.client = None
        # ждавшие ответа запросы — отказ: выбирать больше некому
        for rid in list(self.pending):
            self.finish_pick(rid, None)

    def on_accept(self, srv, _cond):
        conn, _ = srv.accept()
        # обновился код (shell обновился) и ничего не идёт — перезапуститься: D-Bus поднимет новый
        if os.stat(__file__).st_mtime != self.started and not self.sessions and not self.pending:
            log("code changed, restarting")
            conn.close()
            os._exit(0)
        if self.client:
            self.drop_client()
        self.client = conn
        self.buf = b""
        GLib.io_add_watch(conn.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.on_client, conn)
        log("shell connected")
        return True

    def on_client(self, _fd, cond, conn):
        if conn is not self.client:
            return False
        data = b""
        if cond & GLib.IO_IN:
            try:
                data = conn.recv(65536)
            except OSError:
                data = b""
        if not data:
            log("shell disconnected")
            self.drop_client()
            return False
        self.buf += data
        while b"\n" in self.buf:
            line, self.buf = self.buf.split(b"\n", 1)
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if msg.get("op") == "answer":
                self.finish_pick(str(msg.get("id")), msg.get("choice"))
        return True

    # ── D-Bus: ScreenCast ──
    def on_call(self, conn, sender, path, iface, method, params, inv):
        args = params.unpack()
        if method == "CreateSession":
            handle, spath, app_id, _opts = args
            if self.client:
                s = Session(spath, app_id, False)
                s.reg = conn.register_object(spath, SESSION_INFO, self.on_session_call, self.on_session_prop, None)
                self.sessions[spath] = s
                reply(inv, 0)
            else:
                self.forward(inv, method, params, handle, spath, app_id)
        elif method == "SelectSources":
            _handle, spath, _app, opts = args
            s = self.sessions.get(spath)
            if s is None:
                reply(inv, 2)
            elif s.proxy:
                self.forward(inv, method, params, _handle)
            else:
                s.types = opts.get("types", MONITOR) or MONITOR
                s.multiple = bool(opts.get("multiple", False))
                s.cursor = opts.get("cursor_mode", 1)
                reply(inv, 0)
        elif method == "Start":
            handle, spath, app_id, _parent, _opts = args
            s = self.sessions.get(spath)
            if s is None:
                reply(inv, 2)
            elif s.proxy:
                self.forward(inv, method, params, handle)
            else:
                self.ask(inv, s, handle)

    def on_prop(self, conn, sender, path, iface, prop):
        return {"AvailableSourceTypes": GLib.Variant("u", MONITOR | WINDOW),
                "AvailableCursorModes": GLib.Variant("u", 1 | 2),
                "version": GLib.Variant("u", 5)}.get(prop)

    # ── gnome вместо нас ──
    def forward(self, inv, method, params, handle, new_session=None, app_id=""):
        # отмена запроса приложением (Request.Close) приходит нам — передать gnome
        req = 0
        try:
            req = self.bus.register_object(handle, REQUEST_INFO, lambda c, snd, p, i, m, prm, iv: (
                self.bus.call(GNOME, handle, "org.freedesktop.impl.portal.Request", "Close", None, None,
                              Gio.DBusCallFlags.NONE, -1, None, None), iv.return_value(None)), None, None)
        except GLib.Error:
            pass

        def done(bus, res):
            if req:
                self.bus.unregister_object(req)
            try:
                out = bus.call_finish(res)
            except GLib.Error as e:
                log("gnome", method, "failed:", e.message)
                reply(inv, 2)
                return
            if new_session:
                s = Session(new_session, app_id, True)
                s.reg = self.bus.register_object(new_session, SESSION_INFO, self.on_session_call, self.on_session_prop, None)
                # gnome закрыл сессию — сообщить порталу от нашего имени
                s.subs.append(self.bus.signal_subscribe(GNOME, "org.freedesktop.impl.portal.Session", "Closed",
                                                        new_session, None, Gio.DBusSignalFlags.NONE,
                                                        lambda *a: self.close_session(s, emit=True), None))
                self.sessions[new_session] = s
            inv.return_value(out)
        log("forward", method, "to gnome (shell not connected)")
        self.bus.call(GNOME, PATH, IFACE, method, params, GLib.VariantType("(ua{sv})"),
                      Gio.DBusCallFlags.NONE, NO_TIMEOUT, None, done)

    # ── выбор в shell ──
    def ask(self, inv, s, handle):
        self.next_id += 1
        rid = str(self.next_id)
        reg = 0
        try:
            reg = self.bus.register_object(handle, REQUEST_INFO,
                                           lambda c, snd, p, i, m, prm, iv: (self.finish_pick(rid, None), iv.return_value(None)),
                                           None, None)
        except GLib.Error:
            pass
        self.pending[rid] = (inv, s, handle, reg)
        if not self.send({"op": "pick", "id": rid, "app": s.app_id, "types": s.types, "multiple": s.multiple}):
            self.finish_pick(rid, None)

    def finish_pick(self, rid, choice):
        p = self.pending.pop(rid, None)
        if not p:
            return
        inv, s, _handle, reg = p
        if reg:
            self.bus.unregister_object(reg)
        if not choice:
            self.send({"op": "cancel", "id": rid})
            reply(inv, 1)
            return
        self.record(inv, s, choice)

    # ── запись через Mutter API niri ──
    def mcall(self, path, iface, method, args, rtype):
        return self.bus.call_sync(MUTTER, path, iface, method, args, GLib.VariantType(rtype) if rtype else None,
                                  Gio.DBusCallFlags.NONE, 5000, None)

    def record(self, inv, s, choice):
        try:
            (mpath,) = self.mcall("/org/gnome/Mutter/ScreenCast", "org.gnome.Mutter.ScreenCast", "CreateSession",
                                  GLib.Variant("(a{sv})", ({},)), "(o)").unpack()
            s.mutter = mpath
            props = {"cursor-mode": GLib.Variant("u", CURSOR.get(s.cursor, 0))}
            if choice.get("type") == "window":
                props["window-id"] = GLib.Variant("t", int(choice["id"]))
                (stream,) = self.mcall(mpath, "org.gnome.Mutter.ScreenCast.Session", "RecordWindow",
                                       GLib.Variant("(a{sv})", (props,)), "(o)").unpack()
                kind = WINDOW
            else:
                (stream,) = self.mcall(mpath, "org.gnome.Mutter.ScreenCast.Session", "RecordMonitor",
                                       GLib.Variant("(sa{sv})", (str(choice["name"]), props)), "(o)").unpack()
                kind = MONITOR
        except (GLib.Error, KeyError, ValueError) as e:
            log("record failed:", getattr(e, "message", e))
            self.stop_mutter(s)
            reply(inv, 2)
            return

        # niri остановил демонстрацию (stop-cast) — закрыть сессию портала
        s.subs.append(self.bus.signal_subscribe(MUTTER, "org.gnome.Mutter.ScreenCast.Session", "Closed", mpath, None,
                                                Gio.DBusSignalFlags.NONE, lambda *a: self.close_session(s, emit=True), None))
        answered = []

        def added(_c, _snd, _p, _i, _sig, params, _data):
            if answered:
                return
            answered.append(1)
            (node,) = params.unpack()
            info = {"source_type": GLib.Variant("u", kind)}
            try:
                (v,) = self.bus.call_sync(MUTTER, stream, "org.freedesktop.DBus.Properties", "Get",
                                          GLib.Variant("(ss)", ("org.gnome.Mutter.ScreenCast.Stream", "Parameters")),
                                          GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 2000, None).unpack()
                if "position" in v:
                    info["position"] = GLib.Variant("(ii)", tuple(v["position"]))
                # у окна niri сначала знает только 1×1 — такой размер не передаём, настоящий придёт в PipeWire
                if "size" in v and min(v["size"]) > 1:
                    info["size"] = GLib.Variant("(ii)", tuple(v["size"]))
            except GLib.Error:
                pass
            log("streaming", choice, "node", node)
            reply(inv, 0, {"streams": GLib.Variant("a(ua{sv})", [(node, info)])})

        s.subs.append(self.bus.signal_subscribe(MUTTER, "org.gnome.Mutter.ScreenCast.Stream", "PipeWireStreamAdded",
                                                stream, None, Gio.DBusSignalFlags.NONE, added, None))

        def timeout():
            if not answered:
                answered.append(1)
                log("no PipeWire stream from niri")
                self.close_session(s, emit=False)
                reply(inv, 2)
            return False
        GLib.timeout_add_seconds(10, timeout)
        try:
            self.mcall(mpath, "org.gnome.Mutter.ScreenCast.Session", "Start", None, None)
        except GLib.Error as e:
            log("start failed:", e.message)
            answered.append(1)
            self.close_session(s, emit=False)
            reply(inv, 2)

    def stop_mutter(self, s):
        if s.mutter:
            try:
                self.mcall(s.mutter, "org.gnome.Mutter.ScreenCast.Session", "Stop", None, None)
            except GLib.Error:
                pass
            s.mutter = None

    # ── сессия портала ──
    def close_session(self, s, emit):
        if s.closed:
            return
        s.closed = True
        for sub in s.subs:
            self.bus.signal_unsubscribe(sub)
        if s.proxy:
            if not emit:   # закрывает портал — передать gnome
                self.bus.call(GNOME, s.path, "org.freedesktop.impl.portal.Session", "Close", None, None,
                              Gio.DBusCallFlags.NONE, -1, None, None)
        else:
            self.stop_mutter(s)
        if emit:
            self.bus.emit_signal(None, s.path, "org.freedesktop.impl.portal.Session", "Closed", None)
        if s.reg:
            self.bus.unregister_object(s.reg)
        self.sessions.pop(s.path, None)

    def on_session_call(self, conn, sender, path, iface, method, params, inv):
        s = self.sessions.get(path)
        if s and method == "Close":
            self.close_session(s, emit=False)
        inv.return_value(None)

    def on_session_prop(self, conn, sender, path, iface, prop):
        return GLib.Variant("u", 1) if prop == "version" else None


def serve():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    portal = Portal(bus)
    bus.register_object(PATH, SC_INFO, portal.on_call, portal.on_prop, None)

    loop = GLib.MainLoop()

    # сокет — только когда имя наше: второй экземпляр не должен удалить сокет первого
    def acquired(*_):
        try:
            os.unlink(SOCK)
        except FileNotFoundError:
            pass
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(SOCK)
        os.chmod(SOCK, 0o600)
        srv.listen(2)
        GLib.io_add_watch(srv.fileno(), GLib.IO_IN, lambda fd, cond: portal.on_accept(srv, cond))
        log("ready")

    Gio.bus_own_name_on_connection(bus, NAME, Gio.BusNameOwnerFlags.NONE, acquired,
                                   lambda *a: (log("name lost"), loop.quit()))
    loop.run()


# мост для shell: поднять демон (D-Bus activation), подключиться к сокету, гонять строки stdin ↔ сокет
def client():
    sock = None
    for attempt in range(40):
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(SOCK)
            break
        except OSError:
            sock.close()
            sock = None
            if attempt == 0:
                try:
                    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
                    bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                                  "StartServiceByName", GLib.Variant("(su)", (NAME, 0)), None,
                                  Gio.DBusCallFlags.NONE, 5000, None)
                except GLib.Error as e:
                    log("cannot start daemon:", e.message)
            time.sleep(0.1)
    if not sock:
        log("daemon socket not available")
        sys.exit(1)
    print(json.dumps({"op": "connected"}), flush=True)
    loop = GLib.MainLoop()

    def from_daemon(fd, cond):
        data = sock.recv(65536) if cond & GLib.IO_IN else b""
        if not data:
            loop.quit()
            return False
        sys.stdout.write(data.decode(errors="replace"))
        sys.stdout.flush()
        return True

    def from_shell(fd, cond):
        line = sys.stdin.readline() if cond & GLib.IO_IN else ""
        if not line:
            loop.quit()
            return False
        sock.sendall(line.encode())
        return True

    GLib.io_add_watch(sock.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, from_daemon)
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, from_shell)
    loop.run()


if __name__ == "__main__":
    client() if "--client" in sys.argv else serve()

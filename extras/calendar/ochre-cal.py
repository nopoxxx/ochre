#!/usr/bin/env python3
# Календари для shell (services/Calendar.qml): читает ~/.config/ochre/calendars.conf, скачивает .ics и CalDAV,
# разворачивает повторы и пишет события окна [сегодня − 7 дней, сегодня + days] в ~/.cache/ochre/calendar.json.
#   ochre-cal.py sync [--days N]   обновить кэш (так зовёт shell)
#   ochre-cal.py init              создать calendars.conf с примерами, если его нет
#   ochre-cal.py login             спросить пароли CalDAV и положить в связку ключей (secret-tool)
# Нужны python-icalendar и python-dateutil. Пароли — только в связке ключей, в конфиге их нет.
import argparse
import base64
import datetime as dt
import getpass
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or HOME + "/.config", "ochre", "calendars.conf")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or HOME + "/.cache", "ochre", "calendar.json")
SECRET = ["service", "ochre-calendar"]
NS = {"d": "DAV:", "c": "urn:ietf:params:xml:ns:caldav"}

TEMPLATE = """# Календари ochre: по строке на календарь — «имя  адрес  [пользователь]». Строки с # — комментарии.
#
# .ics по ссылке (webcal:// тоже) или файл:
#   holidays  https://example.com/holidays.ics
#   local     ~/Documents/plan.ics
#
# Google: Настройки календаря → «Интеграция календаря» → «Секретный адрес в формате iCal»:
#   google    https://calendar.google.com/calendar/ical/…/private-…/basic.ics
#
# Outlook: Параметры → Календарь → Общие календари → «Опубликовать календарь» → ссылка ICS.
#
# CalDAV (Nextcloud, Fastmail, Radicale, Baikal) — адрес календаря или коллекции календарей и пользователь.
# Пароль (лучше пароль приложения): Mod+S → home/ → календарь → пароли CalDAV.
#   cloud     https://cloud.example.com/remote.php/dav/calendars/me/  me
"""


def parse_conf(path):
    out = []
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        return out
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) == 1:
            parts = [os.path.basename(parts[0].rstrip("/")) or parts[0]] + parts
        out.append({"name": parts[0], "url": parts[1], "user": parts[2] if len(parts) > 2 else ""})
    return out


def is_ics(src):
    u = src["url"]
    return not re.match(r"^https?://", u) or u.startswith("webcal") or re.search(r"\.ics(\?|$)", u) is not None


def password(src):
    if not src["user"]:
        return None
    try:
        r = subprocess.run(["secret-tool", "lookup", *SECRET, "user", src["user"], "url", src["url"]],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.rstrip("\n") if r.returncode == 0 and r.stdout else None


def request(url, src, method="GET", body=None, depth=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("User-Agent", "ochre-calendar")
    if body is not None:
        req.add_header("Content-Type", "application/xml; charset=utf-8")
    if depth is not None:
        req.add_header("Depth", depth)
    pw = password(src)
    if pw is not None:
        token = base64.b64encode(f"{src['user']}:{pw}".encode()).decode()
        req.add_header("Authorization", "Basic " + token)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


def fetch_ics(src):
    u = src["url"]
    if not re.match(r"^(https?|webcal)://", u):
        with open(os.path.expanduser(u), encoding="utf-8") as f:
            return [f.read()]
    return [request(re.sub(r"^webcal://", "https://", u), src)]


def caldav_query(url, src, start, end):
    fmt = "%Y%m%dT%H%M%SZ"
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-data/></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">
    <c:time-range start="{start.strftime(fmt)}" end="{end.strftime(fmt)}"/>
  </c:comp-filter></c:comp-filter></c:filter>
</c:calendar-query>"""
    xml = ET.fromstring(request(url, src, "REPORT", body.encode(), "1"))
    return [e.text for e in xml.iterfind(".//c:calendar-data", NS) if e.text]


# адрес календаря — запрос к нему; адрес коллекции — ко всем календарям внутри
def fetch_caldav(src, start, end):
    url = src["url"]
    body = b"""<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>"""
    xml = ET.fromstring(request(url, src, "PROPFIND", body, "1"))
    cals = []
    for r in xml.iterfind("d:response", NS):
        href = r.findtext("d:href", "", NS)
        if r.find(".//d:resourcetype/c:calendar", NS) is not None:
            cals.append(urllib.parse.urljoin(url, href))
    base = urllib.parse.urlparse(url).path.rstrip("/")
    if any(urllib.parse.urlparse(c).path.rstrip("/") == base for c in cals):
        cals = [url]
    out = []
    for c in cals:
        out += caldav_query(c, src, start, end)
    return out


def local(t):
    if isinstance(t, dt.datetime):
        return t.astimezone().replace(tzinfo=None) if t.tzinfo else t
    return dt.datetime(t.year, t.month, t.day)


def link_of(ev):
    url = str(ev.get("URL") or "")
    if url:
        return url
    for k in ("LOCATION", "DESCRIPTION"):
        m = re.search(r"https?://[^\s<>\"]+", str(ev.get(k) or ""))
        if m:
            return m.group(0)
    return ""


def rule_set(ev, start):
    from dateutil import rrule
    rs = rrule.rruleset()
    aware = isinstance(start, dt.datetime) and start.tzinfo is not None
    for r in ev.get("RRULE") if isinstance(ev.get("RRULE"), list) else [ev.get("RRULE")]:
        text = r.to_ical().decode()
        until = re.search(r"UNTIL=([0-9T]+Z?)", text)
        if until:
            u = until.group(1)
            if aware and not u.endswith("Z"):
                u = (u if "T" in u else u + "T235959") + "Z"
            elif not aware:
                u = u.rstrip("Z")
            text = text.replace(until.group(0), "UNTIL=" + u)
        rs.rrule(rrule.rrulestr(text, dtstart=start))
    for key, add in (("RDATE", rs.rdate), ("EXDATE", rs.exdate)):
        vals = ev.get(key)
        for v in vals if isinstance(vals, list) else [vals] if vals is not None else []:
            for d in v.dts:
                t = d.dt
                if not isinstance(t, dt.datetime):
                    t = dt.datetime(t.year, t.month, t.day)
                if aware and t.tzinfo is None:
                    t = t.replace(tzinfo=start.tzinfo)
                elif not aware and t.tzinfo is not None:
                    t = t.replace(tzinfo=None)
                add(t)
    return rs


def expand(text, idx, name, start, end):
    from icalendar import Calendar
    masters, overrides = [], {}
    for ev in Calendar.from_ical(text).walk("VEVENT"):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED" and "RECURRENCE-ID" not in ev:
            continue
        if "DTSTART" not in ev:
            continue
        if "RECURRENCE-ID" in ev:
            overrides[(str(ev.get("UID")), local(ev.decoded("RECURRENCE-ID")))] = ev
        else:
            masters.append(ev)

    out = []

    def emit(ev, s, e):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            return
        all_day = not isinstance(ev.decoded("DTSTART"), dt.datetime)
        ls, le = local(s), local(e)
        if le <= start or ls >= end:
            return
        fmt = "%Y-%m-%d" if all_day else "%Y-%m-%dT%H:%M:%S"
        out.append({
            "id": f"{ev.get('UID', '')}@{ls.isoformat()}",
            "src": idx, "cal": name,
            "title": str(ev.get("SUMMARY") or "").strip(),
            "start": ls.strftime(fmt), "end": le.strftime(fmt), "allDay": all_day,
            "location": str(ev.get("LOCATION") or "").strip(),
            "link": link_of(ev),
        })

    def span(ev):
        s = ev.decoded("DTSTART")
        if "DTEND" in ev:
            return s, ev.decoded("DTEND") - s
        if "DURATION" in ev:
            return s, ev.decoded("DURATION")
        return s, dt.timedelta(days=1) if not isinstance(s, dt.datetime) else dt.timedelta(0)

    for ev in masters:
        s, dur = span(ev)
        uid = str(ev.get("UID"))
        if "RRULE" not in ev:
            emit(ev, s, s + dur)
            continue
        first = s if isinstance(s, dt.datetime) else dt.datetime(s.year, s.month, s.day)
        lo, hi = start - dur - dt.timedelta(days=1), end + dt.timedelta(days=1)
        if first.tzinfo is not None:
            lo, hi = lo.astimezone(), hi.astimezone()
        for t in rule_set(ev, first).between(lo, hi, inc=True):
            occ = t if isinstance(s, dt.datetime) else t.date()
            ov = overrides.pop((uid, local(occ)), None)
            if ov is not None:
                ostart, odur = span(ov)
                emit(ov, ostart, ostart + odur)
            else:
                emit(ev, occ, occ + dur)
    for ov in overrides.values():
        s, dur = span(ov)
        emit(ov, s, s + dur)
    return out


def sync(days):
    sources = parse_conf(CONF)
    result = {"updated": dt.datetime.now().isoformat(timespec="seconds"), "error": "", "sources": [], "events": []}
    if sources:
        try:
            import icalendar  # noqa: F401
            import dateutil  # noqa: F401
        except ImportError:
            result["error"] = "deps"
            sources = []
    today = dt.datetime.combine(dt.date.today(), dt.time())
    start, end = today - dt.timedelta(days=7), today + dt.timedelta(days=days + 1)
    utc = (start.astimezone(dt.timezone.utc), end.astimezone(dt.timezone.utc))
    for i, src in enumerate(sources):
        info = {"name": src["name"], "error": "", "count": 0}
        try:
            texts = fetch_ics(src) if is_ics(src) else fetch_caldav(src, *utc)
            events = []
            for t in texts:
                events += expand(t, i, src["name"], start, end)
            info["count"] = len(events)
            result["events"] += events
        except urllib.error.HTTPError as e:
            info["error"] = f"HTTP {e.code}"
        except urllib.error.URLError as e:
            info["error"] = str(e.reason)
        except Exception as e:
            info["error"] = f"{type(e).__name__}: {e}"
        result["sources"].append(info)
    result["events"].sort(key=lambda e: (e["start"], e["title"]))
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False)
    os.replace(tmp, CACHE)


def init():
    if os.path.exists(CONF):
        return
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    with open(CONF, "w", encoding="utf-8") as f:
        f.write(TEMPLATE)


def login():
    caldav = [s for s in parse_conf(CONF) if s["user"]]
    if not caldav:
        print(f"В {CONF} нет календарей с пользователем (третье слово строки).")
        return
    for s in caldav:
        have = password(s) is not None
        print(f"\n{s['name']}  {s['user']}  {s['url']}" + ("  (пароль уже сохранён)" if have else ""))
        pw = getpass.getpass("пароль (пусто — оставить как есть): ")
        if not pw:
            continue
        r = subprocess.run(["secret-tool", "store", "--label", f"ochre calendar {s['name']}", *SECRET,
                            "user", s["user"], "url", s["url"]], input=pw, text=True)
        print("сохранён" if r.returncode == 0 else "не сохранён: secret-tool завершился с ошибкой")


def main():
    p = argparse.ArgumentParser(prog="ochre-cal")
    p.add_argument("cmd", choices=["sync", "init", "login"])
    p.add_argument("--days", type=int, default=31)
    a = p.parse_args()
    if a.cmd == "sync":
        sync(max(1, a.days))
    elif a.cmd == "init":
        init()
    else:
        login()
        input("\n↵ — закрыть")


if __name__ == "__main__":
    sys.exit(main())

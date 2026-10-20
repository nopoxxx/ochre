pragma Singleton
import Quickshell
import QtQuick
import "glyphs.js" as G

// Погода Open-Meteo (без ключа). Место — shell.weather.city через геокодер Open-Meteo,
// пустой город — по IP (ipinfo.io). Обновление раз в 30 минут и при смене города или единиц.
// Создаётся при первом обращении (секция weather в home, ночной режим по закату).
Singleton {
    id: root

    readonly property string city: Settings.get("shell.weather.city").trim()
    readonly property bool imperial: Settings.get("shell.weather.units") === "imperial"

    property var place: null        // { name, lat, lon }
    property var current: null      // { temp, feels, code, wind, humidity, day }
    property var daily: []          // [{ date, code, max, min }], первый — сегодня
    property var sun: null          // { rise, set } — Date на сегодня
    property string error: ""
    property bool loading: false
    property date updated

    readonly property string tempUnit: imperial ? "°F" : "°C"
    readonly property string windUnit: imperial ? "mph" : I18n.tr("м/с")

    // WMO weather code → значок и подпись
    function describe(code, day) {
        if (code === 0) return { icon: G.g(day ? "sunny" : "night"), text: I18n.tr("ясно") };
        if (code <= 2) return { icon: G.g(day ? "partly" : "partlyNight"), text: code === 1 ? I18n.tr("малооблачно") : I18n.tr("переменная облачность") };
        if (code === 3) return { icon: G.g("cloudy"), text: I18n.tr("пасмурно") };
        if (code <= 48) return { icon: G.g("fog"), text: I18n.tr("туман") };
        if (code <= 57) return { icon: G.g("rain"), text: I18n.tr("морось") };
        if (code <= 65) return { icon: G.g(code >= 65 ? "pouring" : "rain"), text: code >= 65 ? I18n.tr("ливень") : I18n.tr("дождь") };
        if (code <= 67) return { icon: G.g("sleet"), text: I18n.tr("ледяной дождь") };
        if (code <= 77) return { icon: G.g("snow"), text: I18n.tr("снег") };
        if (code <= 82) return { icon: G.g("pouring"), text: I18n.tr("ливень") };
        if (code <= 86) return { icon: G.g("snow"), text: I18n.tr("снегопад") };
        return { icon: G.g(code >= 96 ? "hail" : "storm"), text: code >= 96 ? I18n.tr("гроза с градом") : I18n.tr("гроза") };
    }

    function get(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { cb(null, "HTTP " + (xhr.status || I18n.tr("нет сети"))); return; }
            try { cb(JSON.parse(xhr.responseText), ""); } catch (e) { cb(null, String(e)); }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function fail(msg) {
        error = msg;
        loading = false;
    }

    function refresh() {
        if (loading) return;
        loading = true;
        if (!city) {
            get("https://ipinfo.io/json", (r, err) => {
                const loc = r?.loc?.split(",");
                if (!loc || loc.length !== 2) return fail(I18n.tr("место по IP: %1", err || I18n.tr("нет данных")));
                place = { name: r.city || "?", lat: Number(loc[0]), lon: Number(loc[1]) };
                forecast();
            });
        } else {
            get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=" + I18n.code + "&name=" + encodeURIComponent(city), (r, err) => {
                const g = r?.results?.[0];
                if (!g) return fail(err ? I18n.tr("геокодер: %1", err) : I18n.tr("город не найден: %1", city));
                place = { name: g.name, lat: g.latitude, lon: g.longitude };
                forecast();
            });
        }
    }

    function forecast() {
        const q = [
            "latitude=" + place.lat, "longitude=" + place.lon, "timezone=auto",
            "current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
            "forecast_days=" + Math.max(1, Settings.get("shell.weather.days") + 1),
            "wind_speed_unit=" + (imperial ? "mph" : "ms"),
            "temperature_unit=" + (imperial ? "fahrenheit" : "celsius")
        ];
        get("https://api.open-meteo.com/v1/forecast?" + q.join("&"), (r, err) => {
            if (!r?.current) return fail("Open-Meteo: " + (err || I18n.tr("нет данных")));
            const c = r.current, d = r.daily;
            current = {
                temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature),
                code: c.weather_code, wind: Math.round(c.wind_speed_10m), humidity: c.relative_humidity_2m, day: c.is_day === 1
            };
            daily = d.time.map((t, i) => ({
                date: new Date(t + "T12:00"), code: d.weather_code[i],
                max: Math.round(d.temperature_2m_max[i]), min: Math.round(d.temperature_2m_min[i])
            }));
            // время — местное для места погоды (timezone=auto), в QML читаем как локальное
            sun = { rise: new Date(d.sunrise[0]), set: new Date(d.sunset[0]) };
            error = "";
            updated = new Date();
            loading = false;
        });
    }

    readonly property int days: Settings.get("shell.weather.days")

    onCityChanged: retry.restart()
    onImperialChanged: retry.restart()
    onDaysChanged: retry.restart()

    // несколько настроек подряд (←→ по дням) — один запрос
    Timer { id: retry; interval: 800; onTriggered: { root.loading = false; root.refresh(); } }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}

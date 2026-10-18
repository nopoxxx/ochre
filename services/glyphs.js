.pragma library

// Значки Nerd Font (Material Design) по именам — для home/, OSD и панели.
// Рисовать шрифтом Theme.iconFont: в Mono-версии значки ужаты в клетку и не читаются.
// Новый значок проверять по шрифту (fontTools, имя md-<имя>), см. AGENTS.md §9.

const cp = {
    sunny: 0xF0599, night: 0xF0594, partly: 0xF0595, partlyNight: 0xF0F31, cloudy: 0xF0590, fog: 0xF0591,
    rain: 0xF0597, pouring: 0xF0596, snow: 0xF0598, storm: 0xF0593, sleet: 0xF067F, hail: 0xF0592,
    wind: 0xF059D, humidity: 0xF058E,
    wifi: 0xF05A9, wifiOff: 0xF05AA, wifi1: 0xF091F, wifi2: 0xF0922, wifi3: 0xF0925, wifi4: 0xF0928,
    wifi0: 0xF092F, wifiLock: 0xF16BF,
    bt: 0xF00AF, btOff: 0xF00B2, btOn: 0xF00B1,
    moon: 0xF0F65, bell: 0xF009A, bellOff: 0xF009B, dnd: 0xF00A0,
    mic: 0xF036C, micOff: 0xF036D, vol: 0xF057E, volOff: 0xF0581, bright: 0xF00DF,
    rec: 0xF044A, stop: 0xF0666, cog: 0xF0493, lock: 0xF033E, power: 0xF0425, sleep: 0xF04B2,
    logout: 0xF0343, restart: 0xF0709,
    play: 0xF040A, pause: 0xF03E4, next: 0xF04AD, prev: 0xF04AE, music: 0xF075A,
    battery: 0xF0079, charging: 0xF0084, balanced: 0xF04C5, saver: 0xF032A, performance: 0xF14DE,
    cpu: 0xF0EE0, mem: 0xF035B, disk: 0xF02CA, temp: 0xF050F, calendar: 0xF00ED, clock: 0xF0150,
    headphones: 0xF02CB, mouse: 0xF037D, keyboard: 0xF030C, phone: 0xF011C, speaker: 0xF04C3,
    monitor: 0xF0379, account: 0xF0004, game: 0xF0297
};

function g(name) { return cp[name] ? String.fromCodePoint(cp[name]) : ""; }

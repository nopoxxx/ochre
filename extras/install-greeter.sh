#!/usr/bin/env bash
# Ставит ochre как greeter для greetd.
#   sudo ./extras/install-greeter.sh
# Greeter — тот же shell: у пакета это его файлы в /usr/share/ochre, git-установку копирует в /usr/local/share/ochre
# (не в /usr/share: там файлы пакета). Кладёт конфиг niri для greeter, создаёт каталоги синхронизации
# и переключает [default_session] в greetd.
# [initial_session] (автовход), если он есть, не трогает.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "запустите через sudo" >&2; exit 1; }

src=$(cd "$(dirname "$0")/.." && pwd)
conf=/etc/greetd/config.toml

if [ "$src" = /usr/share/ochre ]; then
    dest=$src
else
    dest=/usr/local/share/ochre
    rm -rf "$dest"
    mkdir -p "$dest"
    # --no-same-owner: файлы — root'у. Иначе tar оставит владельцем пользователя из клона, и он (или любая его
    # программа) сможет подменить код greeter, который на экране входа принимает пароли всех пользователей
    (cd "$src" && tar --exclude=.git --exclude=extras --exclude=docs --exclude=README.md --exclude=AGENTS.md --exclude=CLAUDE.md -cf - .) \
        | tar -xf - --no-same-owner -C "$dest"
    chown -R root:root "$dest"
    chmod -R u=rwX,go=rX "$dest"
    # копия greeter из git-установки, которую ставила прошлая версия этого скрипта, — если это не файлы пакета
    if [ -d /usr/share/ochre ] && ! pacman -Qqo /usr/share/ochre >/dev/null 2>&1; then rm -rf /usr/share/ochre; fi
fi

sed "s#/usr/share/ochre/greeter.qml#$dest/greeter.qml#" "$src/extras/greeter/niri.kdl" > /etc/greetd/.ochre-niri.kdl.tmp
install -Dm644 /etc/greetd/.ochre-niri.kdl.tmp /etc/greetd/ochre-niri.kdl
rm -f /etc/greetd/.ochre-niri.kdl.tmp

# общий каталог: настройки и обои пользователей (пишут их сессии) и состояние greeter
install -d -m755 /var/lib/ochre-greeter
# greeter под старым именем (nopox-shell): копии настроек и последний вход — сюда, старое убираем
if [ -d /var/lib/nopox-greeter ]; then
    cp -an /var/lib/nopox-greeter/. /var/lib/ochre-greeter/
    rm -rf /var/lib/nopox-greeter
fi
rm -rf /usr/share/nopox-shell
rm -f /etc/greetd/nopox-niri.kdl
install -d -m755 -o greeter -g greeter /var/lib/ochre-greeter/.greeter
[ -f /var/lib/ochre-greeter/.greeter/niri.kdl ] || printf 'layout {\n    background-color "#1d2021"\n}\n' > /var/lib/ochre-greeter/.greeter/niri.kdl
chown greeter:greeter /var/lib/ochre-greeter/.greeter/niri.kdl
getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1}' | while read -r u; do
    install -d -m755 -o "$u" -g "$(id -gn "$u")" "/var/lib/ochre-greeter/$u"
done

[ -f "$conf.orig" ] || cp "$conf" "$conf.orig"
sed -i '/^\[default_session\]/,/^\[/ s|^command = .*|command = "niri -c /etc/greetd/ochre-niri.kdl"|' "$conf"

echo "готово: greeter установлен, исходный конфиг greetd — $conf.orig"
grep -A2 '^\[default_session\]' "$conf"

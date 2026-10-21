#!/usr/bin/env bash
# ochre — установщик для Arch Linux и производных (CachyOS, EndeavourOS, …)
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/ochre/main/install.sh)
#
# Флаги (всё, что не задано флагом, установщик спросит; с --yes — возьмёт по умолчанию):
#   --yes                    не задавать вопросов
#   --terminal <t>           kitty | alacritty | ghostty | foot
#   --shell <s>              zsh | fish | bash
#   --browser <b>            helium | firefox | zen | chromium | brave | vivaldi | none
#   --files <f>              thunar | nautilus | dolphin | nemo | yazi | none
#   --apps <a,b,…>           программы (список — в начале установки), none — никаких
#   --discord-mod <m>        none | vencord | betterdiscord | vesktop
#   --no-greeter             не ставить greeter (greetd)
#   --no-steam-notify        не ставить Millennium и плагин nopox-notify (уведомления Steam)
#   --no-chaotic             не подключать chaotic-aur: AUR-программы собирать makepkg (дольше)
#   --keep-niri-config       не заменять config.kdl niri, только дописать include
#   --branch <ветка>         ветка репозитория (по умолчанию main)
#   --system <каталог>       shell уже поставлен пакетом в <каталог> (так зовёт `ochre setup`): без git-клона
#
# Ничего не удаляет: всё, что заменяется, переезжает в *.bak-<дата>.
set -euo pipefail

REPO=https://github.com/nopoxxx/ochre
BRANCH=main
YES=0
GREETER=ask
STEAM_NOTIFY=ask
CHAOTIC=ask
KEEP_NIRI=0
TERMINAL="" SHELL_CHOICE="" BROWSER="" FILES="" APPS="" DISCORD_MOD=""
DEST="$HOME/.config/quickshell"
SYSTEM=""
NIRI_DIR="$HOME/.config/niri"
STAMP=$(date +%Y%m%d-%H%M%S)

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) YES=1 ;;
        --terminal) TERMINAL=${2:?}; shift ;;
        --shell) SHELL_CHOICE=${2:?}; shift ;;
        --browser) BROWSER=${2:?}; shift ;;
        --files) FILES=${2:?}; shift ;;
        --apps) APPS=${2:?}; shift ;;
        --discord-mod) DISCORD_MOD=${2:?}; shift ;;
        --no-greeter) GREETER=no ;;
        --no-steam-notify) STEAM_NOTIFY=no ;;
        --no-chaotic) CHAOTIC=no ;;
        --keep-niri-config) KEEP_NIRI=1 ;;
        --branch) BRANCH=${2:?нужно имя ветки}; shift ;;
        --system) SYSTEM=${2:?нужен каталог}; DEST=$SYSTEM; shift ;;
        -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный флаг: $1" >&2; exit 1 ;;
    esac
    shift
done

# ── вывод в цветах Gruvbox ───────────────────────────────────────────
if [ -t 1 ]; then
    Y=$'\e[33m' G=$'\e[32m' R=$'\e[31m' A=$'\e[36m' D=$'\e[90m' BOLD=$'\e[1m' N=$'\e[0m'
else
    Y="" G="" R="" A="" D="" BOLD="" N=""
fi

step() { printf '\n%s❯%s %s%s%s\n' "$Y" "$N" "$BOLD" "$*" "$N"; }
info() { printf '  %s%s%s\n' "$D" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# ask "вопрос" y|n — default; с --yes сразу ответ по умолчанию
ask() {
    local q=$1 def=${2:-y} ans hint
    if [ "$YES" = 1 ]; then [ "$def" = y ]; return; fi
    hint=$([ "$def" = y ] && echo "Y/n" || echo "y/N")
    printf '  %s?%s %s [%s] ' "$A" "$N" "$q" "$hint"
    read -r ans </dev/tty || ans=""
    ans=${ans:-$def}
    [[ $ans =~ ^[YyДд] ]]
}

backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        mv "$1" "$1.bak-$STAMP"
        info "старое — в $1.bak-$STAMP"
    fi
}

# choose ПЕРЕМЕННАЯ "заголовок" умолчание "id|описание" … — нумерованный выбор одного варианта.
# Если переменная уже задана флагом — только проверяет, что такой вариант есть.
choose() {
    local var=$1 title=$2 def=$3 ans i line id
    shift 3
    local ids=()
    for line in "$@"; do ids+=("${line%%|*}"); done
    if [ -n "${!var}" ]; then
        printf '%s\n' "${ids[@]}" | grep -qx "${!var}" || die "$title: нет варианта «${!var}» (есть: ${ids[*]})"
        ok "$title: ${!var}"
        return
    fi
    if [ "$YES" = 1 ]; then
        printf -v "$var" '%s' "$def"
        ok "$title: $def"
        return
    fi
    printf '\n  %s%s%s\n' "$BOLD" "$title" "$N"
    i=1
    for line in "$@"; do
        id=${line%%|*}
        printf '   %s%2d)%s %-14s %s%s%s%s\n' "$A" "$i" "$N" "$id" "$D" "${line#*|}" "$N" \
            "$([ "$id" = "$def" ] && printf '  %s← по умолчанию%s' "$Y" "$N")"
        i=$((i + 1))
    done
    while true; do
        printf '  %s?%s номер [Enter — %s] ' "$A" "$N" "$def"
        read -r ans </dev/tty || ans=""
        if [ -z "$ans" ]; then printf -v "$var" '%s' "$def"; break; fi
        if [[ $ans =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le ${#ids[@]} ]; then
            printf -v "$var" '%s' "${ids[$((ans - 1))]}"
            break
        fi
        warn "нужен номер от 1 до ${#ids[@]}"
    done
    ok "$title: ${!var}"
}

# set_setting ключ значение — в ~/.config/ochre/settings.json (shell пишет его по ключу на строку)
set_setting() {
    local f="$HOME/.config/ochre/settings.json" k=$1 v=$2
    mkdir -p "${f%/*}"
    if [ ! -s "$f" ] || ! grep -q '"' "$f"; then
        printf '{\n  "%s": "%s"\n}\n' "$k" "$v" > "$f"
    elif grep -q "\"$k\":" "$f"; then
        sed -i "s|\"$k\": *\"[^\"]*\"|\"$k\": \"$v\"|" "$f"
    else
        sed -i "0,/{/s//{\n  \"$k\": \"$v\",/" "$f"
    fi
}

# .desktop-файл пакета — для браузера и файлового менеджера по умолчанию
# desktop_of <пакет> [mime] — .desktop пакета; с mime — тот, что его открывает: у thunar первым по алфавиту
# идёт thunar-bulk-rename.desktop, а папки открывает thunar.desktop (MimeType=inode/directory)
desktop_of() {
    local files f
    files=$(pacman -Qlq "$1" 2>/dev/null | grep '^/usr/share/applications/.*\.desktop$' || true)
    [ -n "$files" ] || return 0
    if [ -n "${2:-}" ]; then
        for f in $files; do
            grep -qE "^MimeType=(.*;)?$2(;|$)" "$f" && { basename "$f"; return 0; }
        done
    fi
    basename "$(head -1 <<<"$files")"
}

# vulkan_drivers — Vulkan-драйверы под видеокарты машины (по PCI vendor из /sys: lspci на минимальном Arch может не быть).
# Steam требует vulkan-driver и lib32-vulkan-driver; с --noconfirm pacman молча взял бы первый вариант — nvidia-utils.
# nvidia-utils — только при проприетарном модуле: пакет отключает nouveau, и без модуля nvidia карта осталась бы без драйвера.
# Программный (lavapipe) — только если известных карт нет вовсе (виртуалка): рядом с настоящим Steam может выбрать его
vulkan_drivers() {
    local dev vendor known=0
    {
        for dev in /sys/class/drm/card*/device; do
            vendor=$(cat "$dev/vendor" 2>/dev/null) || continue
            case "$vendor" in
                0x1002) echo vulkan-radeon lib32-vulkan-radeon; known=1 ;;
                0x8086) echo vulkan-intel lib32-vulkan-intel; known=1 ;;
                0x10de)
                    if [ "$(basename "$(readlink "$dev/driver" 2>/dev/null)")" = nvidia ] || modinfo nvidia >/dev/null 2>&1; then
                        echo nvidia-utils lib32-nvidia-utils
                    else
                        echo vulkan-nouveau lib32-vulkan-nouveau
                    fi
                    known=1 ;;
            esac
        done
        [ "$known" = 1 ] || echo vulkan-swrast lib32-vulkan-swrast
    } | tr ' ' '\n' | sort -u
}

printf '%s' "$Y"
cat <<'EOF'

  ┌─[ ochre ]──────────────────────────────────────┐
  │  terminal-style shell для niri на Quickshell          │
  └───────────────────────────────────────────────────────┘
EOF
printf '%s' "$N"

# ── проверки ─────────────────────────────────────────────────────────
step "Проверка системы"
[ "$(id -u)" -ne 0 ] || die "запускайте от обычного пользователя — sudo спросят там, где нужно"
command -v pacman >/dev/null || die "нужен Arch Linux или производный дистрибутив (pacman)"
command -v sudo >/dev/null || die "нужен sudo"
curl -fsS --max-time 15 -o /dev/null https://github.com || die "нет доступа к github.com"
ok "Arch-подобная система, $(uname -r)"

# ── выбор ────────────────────────────────────────────────────────────
step "Что ставим"

choose TERMINAL "Терминал" kitty \
    "kitty|быстрый, GPU, вкладки и картинки" \
    "alacritty|минималистичный, GPU" \
    "ghostty|новый, GPU, нативный GTK" \
    "foot|лёгкий, только Wayland"

choose SHELL_CHOICE "Оболочка" zsh \
    "zsh|подсказки по истории и подсветка команд" \
    "fish|удобный сразу, без настройки" \
    "bash|стандартный"

choose BROWSER "Браузер" helium \
    "helium|Chromium без телеметрии и лишнего" \
    "firefox|Firefox" \
    "zen|Zen — Firefox с вертикальными вкладками" \
    "chromium|Chromium" \
    "brave|Brave — со встроенным блокировщиком" \
    "vivaldi|Vivaldi — много настроек" \
    "none|не ставить"

choose FILES "Файловый менеджер" thunar \
    "thunar|лёгкий, из Xfce" \
    "nautilus|GNOME Files" \
    "dolphin|KDE, много возможностей" \
    "nemo|из Cinnamon" \
    "yazi|в терминале — в стиле shell" \
    "none|не ставить"

# группа|id|описание|пакеты|по умолчанию
APP_CATALOG=(
    "Медиа|mpv|mpv — видеоплеер|mpv|1"
    "Медиа|obs|OBS Studio — запись и стримы|obs-studio|0"
    "Медиа|spotify|Spotify|spotify-launcher|0"
    "Медиа|qbittorrent|qBittorrent|qbittorrent|0"
    "Медиа|imv|imv — просмотр картинок|imv|0"
    "Общение|discord|Discord (моды — следующий вопрос)|discord|1"
    "Общение|telegram|Telegram|telegram-desktop|1"
    "Графика|photocraft|PhotoCraft — аналог Photoshop на Rust, альфа|photocraft-bin|1"
    "Графика|gimp|GIMP|gimp|0"
    "Графика|krita|Krita — рисование|krita|0"
    "Работа и код|code|Code - OSS (VS Code)|code|0"
    "Работа и код|vscodium|VSCodium|vscodium/vscodium-bin|0"
    "Работа и код|neovim|Neovim|neovim|0"
    "Работа и код|libreoffice|LibreOffice|libreoffice-fresh|0"
    "Работа и код|obsidian|Obsidian — заметки|obsidian|0"
    "Игры|steam|Steam (включит multilib)|steam|0"
    "Игры|lutris|Lutris|lutris|0"
    "Игры|heroic|Heroic — Epic Games и GOG|heroic-games-launcher-bin|0"
    "Игры|gametools|MangoHud + GameMode|mangohud gamemode|0"
    "Утилиты|btop|btop — монитор ресурсов|btop|1"
    "Утилиты|flatpak|Flatpak|flatpak|0"
    "Утилиты|timeshift|Timeshift — снимки системы|timeshift|0"
)
SEL=()
for i in "${!APP_CATALOG[@]}"; do SEL[i]=${APP_CATALOG[i]##*|}; done

app_field() { local IFS='|'; local f=(${APP_CATALOG[$1]}); printf '%s' "${f[$2]}"; }

if [ -n "$APPS" ]; then
    for i in "${!APP_CATALOG[@]}"; do SEL[i]=0; done
    for id in ${APPS//,/ }; do
        [ "$id" = none ] && continue
        found=0
        for i in "${!APP_CATALOG[@]}"; do
            [ "$(app_field "$i" 1)" = "$id" ] && { SEL[i]=1; found=1; }
        done
        [ "$found" = 1 ] || die "--apps: нет программы «$id»"
    done
elif [ "$YES" != 1 ]; then
    while true; do
        printf '\n  %sПрограммы%s %s(номера через пробел — отметить/снять, Enter — готово)%s\n' "$BOLD" "$N" "$D" "$N"
        group=""
        for i in "${!APP_CATALOG[@]}"; do
            g=$(app_field "$i" 0)
            [ "$g" != "$group" ] && { printf '   %s── %s%s\n' "$D" "$g" "$N"; group=$g; }
            mark=$([ "${SEL[i]}" = 1 ] && printf '%s[x]%s' "$G" "$N" || printf '[ ]')
            printf '   %s%2d)%s %s %s\n' "$A" "$((i + 1))" "$N" "$mark" "$(app_field "$i" 2)"
        done
        printf '  %s?%s ' "$A" "$N"
        read -r ans </dev/tty || ans=""
        [ -z "$ans" ] && break
        for x in $ans; do
            if [[ $x =~ ^[0-9]+$ ]] && [ "$x" -ge 1 ] && [ "$x" -le ${#APP_CATALOG[@]} ]; then
                SEL[$((x - 1))]=$((1 - SEL[$((x - 1))]))
            else
                warn "нет пункта $x"
            fi
        done
    done
fi

APP_IDS=() APP_PKGS=()
for i in "${!APP_CATALOG[@]}"; do
    [ "${SEL[i]}" = 1 ] || continue
    APP_IDS+=("$(app_field "$i" 1)")
    read -ra pk <<<"$(app_field "$i" 3)"
    APP_PKGS+=("${pk[@]}")
done
ok "Программы: ${APP_IDS[*]:-никаких}"

if printf '%s\n' "${APP_IDS[@]}" | grep -qx discord; then
    choose DISCORD_MOD "Discord" none \
        "none|как есть" \
        "vencord|Vencord — плагины и темы, патч обычного Discord" \
        "betterdiscord|BetterDiscord — плагины и темы" \
        "vesktop|Vesktop — отдельный клиент со встроенным Vencord, лучше на Wayland"
    # Vesktop заменяет обычный Discord
    if [ "$DISCORD_MOD" = vesktop ]; then
        mapfile -t APP_PKGS < <(printf '%s\n' "${APP_PKGS[@]}" | sed 's#^discord$#vesktop/vesktop-bin#')
    fi
    [ "$DISCORD_MOD" = betterdiscord ] && APP_PKGS+=(betterdiscordctl)
else
    DISCORD_MOD=none
fi

declare -A BROWSER_PKG=([helium]=helium-browser-bin [firefox]=firefox [zen]=zen-browser-bin
    [chromium]=chromium [brave]=brave-bin [vivaldi]=vivaldi [none]="")
declare -A FILES_PKG=([thunar]=thunar [nautilus]=nautilus [dolphin]=dolphin [nemo]=nemo [yazi]=yazi [none]="")
declare -A SHELL_PKGS=([zsh]="zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions" [fish]=fish [bash]=bash-completion)

printf '\n  %sИтого:%s %s · %s · %s · файлы: %s · программы: %s%s\n' "$BOLD" "$N" \
    "$TERMINAL" "$SHELL_CHOICE" "$BROWSER" "$FILES" "${APP_IDS[*]:-нет}" \
    "$([ "$DISCORD_MOD" != none ] && printf ' · discord: %s' "$DISCORD_MOD")"
ask "Начинаем?" y || die "отменено"

sudo -v || die "без sudo не поставить пакеты"
# держим sudo живым, пока идёт установка
while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done &

# с --yes pacman и makepkg тоже не спрашивают; без него их вопросы остаются: видно, что ставится
noconfirm=()
[ "$YES" = 1 ] && noconfirm=(--noconfirm)

# ── пакеты ───────────────────────────────────────────────────────────
step "Пакеты"
PKGS=(
    niri quickshell xwayland-satellite git curl xdg-utils
    networkmanager pipewire pipewire-pulse wireplumber upower pacman-contrib libnotify
    polkit-gnome gnome-keyring xdg-desktop-portal-gnome xdg-desktop-portal-gtk qt6ct adw-gtk-theme
    ttf-terminus-nerd noto-fonts noto-fonts-emoji
    wl-clipboard cliphist brightnessctl playerctl pavucontrol fastfetch base-devel
    gammastep wf-recorder slurp tesseract tesseract-data-eng tesseract-data-rus cava python-gobject songrec
    python-icalendar python-dateutil libsecret
    qt6-multimedia-ffmpeg qt6-shadertools ffmpeg
    "$TERMINAL"
)
read -ra sp <<<"${SHELL_PKGS[$SHELL_CHOICE]}"
PKGS+=("${sp[@]}")
# есть адаптер bluetooth — нужен bluez: без него секция bluetooth в меню home не появится
[ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] && PKGS+=(bluez bluez-utils)

missing=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done

if [ ${#missing[@]} -eq 0 ]; then
    ok "базовые пакеты уже установлены"
else
    info "нужно поставить: ${missing[*]}"
    if ask "Обновить систему вместе с установкой (pacman -Syu)? На Arch так правильнее" y; then
        sudo pacman -Syu --needed "${noconfirm[@]}" "${missing[@]}"
    else
        sudo pacman -S --needed "${noconfirm[@]}" "${missing[@]}"
    fi
    ok "базовые пакеты установлены"
fi

# shell пишет конфиг под свежий niri (горячие углы по одному, pick-window и screenshot-window --path для скриншотов):
# старый niri такой конфиг не примет, а pacman -S --needed уже установленный niri не обновит
NIRI_MIN=25.11
niri_ver=$(niri --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)
if [ -n "$niri_ver" ] && [ "$(printf '%s\n' "$NIRI_MIN" "$niri_ver" | sort -V | head -1)" != "$NIRI_MIN" ]; then
    warn "niri $niri_ver старше $NIRI_MIN — конфиг ochre он не примет"
    if ask "Обновить систему вместе с niri (pacman -Syu)?" y; then
        sudo pacman -Syu --needed "${noconfirm[@]}" niri
        ok "niri: $(niri --version | head -1)"
    else
        die "нужен niri $NIRI_MIN или новее: sudo pacman -Syu niri"
    fi
fi

# build_aur <пакет> — собрать из AUR makepkg'ом и поставить; сборочные зависимости (-r) удаляются после сборки.
# Не makepkg -si: он ставит пакет через «sudo -k» и заново спрашивает пароль (а с --yes зависает)
build_aur() {
    local tmp rc=0
    tmp=$(mktemp -d)
    git clone -q --depth 1 "https://aur.archlinux.org/$1.git" "$tmp/$1" \
        && (cd "$tmp/$1" && makepkg -sr --noconfirm) \
        && sudo pacman -U --noconfirm "$tmp/$1/$1"-[0-9]*.pkg.tar.zst || rc=1
    rm -rf "$tmp"
    return $rc
}

# installed <пакет> — стоит ли он сам или то, что его провайдит (vesktop-bin → vesktop, paru-bin → paru)
installed() { pacman -T "$1" >/dev/null 2>&1; }

# install_pkgs <пакет|a/b> … — что есть в репозиториях (официальные, chaotic-aur, …) — одним pacman,
# остального нет нигде — makepkg из AUR. «a/b» — варианты имени: первый, что есть в репозиториях,
# иначе последний (обычно -bin: собирается без компиляции). Не поставилось — в FAILED.
FAILED=()
install_pkgs() {
    local item alt pick repo=() aur=() p alts
    for item in "$@"; do
        IFS=/ read -ra alts <<<"$item"
        pick=""
        for alt in "${alts[@]}"; do installed "$alt" && { pick=-; break; }; done
        [ "$pick" = - ] && continue
        for alt in "${alts[@]}"; do pacman -Si "$alt" &>/dev/null && { pick=$alt; break; }; done
        if [ -n "$pick" ]; then repo+=("$pick"); else aur+=("${alts[-1]}"); fi
    done
    if [ ${#repo[@]} -gt 0 ]; then
        info "pacman: ${repo[*]}"
        sudo pacman -S --needed "${noconfirm[@]}" "${repo[@]}" || true
    fi
    for p in "${aur[@]}"; do
        info "нет в репозиториях — собираю из AUR: $p"
        build_aur "$p" || true
    done
    for p in "${repo[@]}" "${aur[@]}"; do installed "$p" || FAILED+=("$p"); done
}

# ── chaotic-aur ──────────────────────────────────────────────────────
# AUR-программы — готовыми сборками chaotic-aur через pacman: без компиляции установка в разы быстрее
CHAOTIC_KEY=3056513887B78AEB
CHAOTIC_CDN=https://cdn-mirror.chaotic.cx/chaotic-aur
if grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    ok "chaotic-aur уже подключён"
elif [ "$CHAOTIC" = no ] || ! ask "Подключить chaotic-aur — готовые сборки AUR, программы ставятся без компиляции?" y; then
    info "без chaotic-aur: программы из AUR соберутся makepkg — это дольше"
elif sudo pacman-key --recv-key "$CHAOTIC_KEY" --keyserver keyserver.ubuntu.com \
    && sudo pacman-key --lsign-key "$CHAOTIC_KEY" \
    && sudo pacman -U --needed --noconfirm "$CHAOTIC_CDN/chaotic-keyring.pkg.tar.zst" "$CHAOTIC_CDN/chaotic-mirrorlist.pkg.tar.zst"; then
    sudo cp /etc/pacman.conf "/etc/pacman.conf.bak-$STAMP"
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    sudo pacman -Sy
    ok "chaotic-aur подключён (старый pacman.conf — /etc/pacman.conf.bak-$STAMP)"
else
    warn "chaotic-aur подключить не вышло — программы из AUR соберутся makepkg"
fi

# ── программы ────────────────────────────────────────────────────────
# браузер, файловый менеджер, программы, иконки Gruvbox Plus и Papirus (их shell включает в GTK и Qt по теме), matugen для темы Wallpaper
EXTRA=("${APP_PKGS[@]}" gruvbox-plus-icon-theme papirus-icon-theme matugen/matugen-bin)
[ -n "${BROWSER_PKG[$BROWSER]}" ] && EXTRA+=("${BROWSER_PKG[$BROWSER]}")
[ -n "${FILES_PKG[$FILES]}" ] && EXTRA+=("${FILES_PKG[$FILES]}")

if printf '%s\n' "${EXTRA[@]}" | grep -qx steam && ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    if ask "Steam нужен репозиторий multilib (32-битные библиотеки). Включить?" y; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy
        ok "multilib включён"
    else
        mapfile -t EXTRA < <(printf '%s\n' "${EXTRA[@]}" | grep -vx steam)
        warn "Steam пропущен"
    fi
fi

# Steam: Vulkan-драйвер — явно и в той же транзакции, иначе pacman выберет поставщика сам
if printf '%s\n' "${EXTRA[@]}" | grep -qx steam && ! installed vulkan-driver; then
    mapfile -t vk < <(vulkan_drivers)
    [ ${#vk[@]} -gt 0 ] && { EXTRA=("${vk[@]}" "${EXTRA[@]}"); info "Vulkan для Steam: ${vk[*]}"; }
fi
install_pkgs "${EXTRA[@]}"
if [ ${#FAILED[@]} -eq 0 ]; then
    ok "программы установлены"
else
    warn "не поставились: ${FAILED[*]} — см. вывод выше; повторить: paru -S ${FAILED[*]}"
    FAILED=()
fi

# paru — для shell (обновления AUR на панели, меню packages/); сам установщик им не пользуется.
# Должен не просто стоять, а запускаться: paru-bin собран под конкретную libalpm и после обновления pacman не стартует
paru_ok() { paru --version &>/dev/null; }
if paru_ok; then
    ok "paru уже есть"
else
    # неработающий paru мешает поставить другой (paru и paru-bin конфликтуют)
    if command -v paru >/dev/null; then
        old=$(pacman -Qq | grep -xE 'paru|paru-bin' || true)
        [ -z "$old" ] || sudo pacman -Rdd --noconfirm $old >/dev/null
    fi
    install_pkgs paru/paru-bin
    FAILED=()
    if paru_ok; then ok "paru: $(paru --version | head -1)"
    else warn "paru не запускается — обновления AUR и меню packages/ его не найдут; поставить потом: pacman -S paru"; fi
fi

# ── сам shell ────────────────────────────────────────────────────────
step "ochre → $DEST"
if [ -n "$SYSTEM" ]; then
    ok "поставлен пакетом — обновляется вместе с системой"
elif [ -d "$DEST/.git" ] && git -C "$DEST" remote get-url origin 2>/dev/null | grep -qE "nopoxxx/(ochre|nopox-shell)"; then
    # клон ещё под старым именем репозитория (nopox-shell) — GitHub перенаправляет, но адрес лучше сменить
    git -C "$DEST" remote set-url origin "$REPO"
    git -C "$DEST" fetch --quiet origin "$BRANCH" || die "не удалось скачать ветку $BRANCH"
    # клон мог быть на другой ветке (или его ветку удалили) — тогда переключаем на нужную
    if [ "$(git -C "$DEST" rev-parse --abbrev-ref HEAD)" != "$BRANCH" ] \
        || ! git -C "$DEST" rev-parse --abbrev-ref '@{u}' &>/dev/null; then
        git -C "$DEST" checkout -q -B "$BRANCH" "origin/$BRANCH" || die "в $DEST локальные правки мешают переключиться на $BRANCH"
        git -C "$DEST" branch -q -u "origin/$BRANCH"
    else
        git -C "$DEST" merge -q --ff-only "origin/$BRANCH" || die "в $DEST локальные правки мешают обновиться (git status)"
    fi
    ok "уже установлен — обновлён до $(git -C "$DEST" log --oneline -1)"
else
    backup "$DEST"
    git clone -q --branch "$BRANCH" "$REPO" "$DEST"
    ok "склонирован: $(git -C "$DEST" log --oneline -1)"
fi
info "обновления потом — сам shell: ochre ↑ на панели"

# shell раньше назывался nopox-shell: настройки и состояние — в новые каталоги, пока set_setting не создал пустые.
# Конфиг niri (~/.config/niri/nopox и include в config.kdl) переведёт сам shell при запуске — с проверкой niri validate.
for pair in ".config/nopox:.config/ochre" ".local/state/nopox:.local/state/ochre"; do
    old="$HOME/${pair%%:*}" new="$HOME/${pair#*:}"
    if [ -d "$old" ]; then
        mkdir -p "$new" && cp -an "$old"/. "$new"/ && rm -rf "$old"
        ok "~/${pair%%:*} → ~/${pair#*:} (nopox-shell теперь ochre)"
    fi
done
mkdir -p "$HOME/Pictures/Wallpapers"

# выбор терминала, файлового менеджера и браузера — в настройки shell (Mod+Return, Mod+E, Mod+Shift+B, окна обновлений и т.п.);
# оболочку и браузер shell при запуске всё равно сверит с системой (services/DefaultApps.qml)
set_setting shell.terminal "$TERMINAL"
set_setting shell.files "$FILES"
set_setting shell.sh "$SHELL_CHOICE"
set_setting shell.browser "$BROWSER"

# ── niri ─────────────────────────────────────────────────────────────
step "Конфиг niri"
conf="$NIRI_DIR/config.kdl"
# ~/.config/niri/ochre/ — по файлу на раздел (input, displays, layout, window-rules, …).
# Shell перегенерирует их при запуске; стартовые нужны, чтобы niri загрузил конфиг ещё до shell.
mkdir -p "$NIRI_DIR/ochre"
for f in "$DEST"/extras/niri/ochre/*.kdl; do
    t="$NIRI_DIR/ochre/$(basename "$f")"
    [ -f "$t" ] && continue
    cp "$f" "$t"
    # у пакета shell — не конфиг quickshell по умолчанию: и запуск, и qs ipc — с -p <каталог>
    # (дальше binds.kdl перепишет сам shell, но до его первого запуска niri берёт эту заготовку)
    if [ -n "$SYSTEM" ] && [ "$(basename "$f")" = binds.kdl ]; then
        sed -i -e "s#^spawn-at-startup \"qs\"\$#spawn-at-startup \"qs\" \"-p\" \"$DEST\"#" \
               -e "s#spawn \"qs\" \"ipc\" \"call\"#spawn \"qs\" \"ipc\" \"-p\" \"$DEST\" \"call\"#" "$t"
    fi
done

if [ -f "$conf" ] && grep -q '^include "ochre/main.kdl"' "$conf"; then
    ok "ochre уже подключён к вашему config.kdl"
    # старый эталон держал Mod+Shift+S за встроенным скриншотом niri; config.kdl грузится после ochre/binds.kdl
    # и перекрыл бы скриншот ochre с разметкой
    shot_re='^[[:space:]]*(Mod\+Shift\+S|Print)[[:space:]]*\{[[:space:]]*screenshot;[[:space:]]*\}'
    if grep -qE "$shot_re" "$conf"; then
        if ask "В config.kdl Mod+Shift+S / Print — встроенный скриншот niri; он перекрывает скриншот ochre с разметкой. Закомментировать?" y; then
            cp "$conf" "$conf.bak-$STAMP"
            sed -i -E "s#($shot_re)#// \1  // ochre: скриншот с разметкой — в ochre/binds.kdl#" "$conf"
            ok "встроенный скриншот niri отключён (Ctrl+Print / Alt+Print остались); старое — в $conf.bak-$STAMP"
        fi
    fi
elif [ -f "$conf" ] && grep -qE '^include "nopox(/main|-binds)?\.kdl"' "$conf"; then
    ok "подключён под старым именем nopox — shell сам переведёт его в ~/.config/niri/ochre/ при запуске"
elif [ ! -f "$conf" ] || { [ "$KEEP_NIRI" = 0 ] && ask "Заменить ваш config.kdl конфигом ochre? Старый уйдёт в бэкап" y; }; then
    backup "$conf"
    cp "$DEST/extras/niri/config.kdl" "$conf"
    ok "config.kdl ochre установлен"
else
    # в одном файле может быть только один binds — поэтому всё своё ochre держит во включаемых файлах;
    # они в конце, значит одноимённые клавиши (Mod+D и т.п.) берутся из ochre
    cp "$conf" "$conf.bak-$STAMP"
    info "старое — в $conf.bak-$STAMP"
    {
        echo
        echo "// >>> ochre >>> (добавлено install.sh)"
        echo 'include "ochre/main.kdl"'
        echo 'include "ochre/keys.kdl"'
        echo "// <<< ochre <<<"
    } >> "$conf"
    ok "к вашему config.kdl дописаны include ochre"
    warn "флаги в ваших секциях input / layout (например, tap) окно настроек (Mod+S) выключить не сможет"
fi

# Mod+Shift+V — история буфера ochre; в старом эталоне и в стандартном конфиге niri там фокус плавающих окон,
# а config.kdl, подключённый после ochre/binds.kdl (и старая схема после миграции), перекрыл бы бинд ochre
clip_re='^([[:space:]]*)Mod\+Shift\+V([[:space:]]*\{[[:space:]]*switch-focus-between-floating-and-tiling;[[:space:]]*\})'
if grep -qE "$clip_re" "$conf"; then
    if ask "В config.kdl Mod+Shift+V — фокус плавающих окон; он перекрывает историю буфера ochre. Перенести на Mod+Ctrl+V?" y; then
        [ -f "$conf.bak-$STAMP" ] || cp "$conf" "$conf.bak-$STAMP"
        if grep -qE '^[[:space:]]*Mod\+Ctrl\+V[[:space:]]' "$conf"; then
            # Mod+Ctrl+V уже занят: второй такой бинд в одном блоке niri не примет — просто отключаем
            sed -i -E "s#$clip_re#\1// Mod+Shift+V\2   // ochre: история буфера#" "$conf"
            ok "Mod+Shift+V — история буфера (фокус плавающих окон отключён: Mod+Ctrl+V у вас занят)"
        else
            sed -i -E "s#$clip_re#\1Mod+Ctrl+V\2   // Mod+Shift+V — история буфера ochre#" "$conf"
            ok "фокус плавающих окон — Mod+Ctrl+V, Mod+Shift+V — история буфера"
        fi
    fi
fi

if command -v niri >/dev/null && ! niri validate -c "$conf" >/dev/null 2>&1; then
    warn "niri validate не принял конфиг — возвращаю прежний"
    [ -f "$conf.bak-$STAMP" ] && mv "$conf.bak-$STAMP" "$conf"
    niri validate -c "$conf" 2>&1 | tail -5
    die "исправьте config.kdl и запустите установщик снова"
fi
ok "niri validate: конфиг корректный"

# ── терминал ─────────────────────────────────────────────────────────
step "Терминал: $TERMINAL"
declare -A TERM_CONF=(
    [kitty]="kitty/kitty.conf:$HOME/.config/kitty/kitty.conf"
    [alacritty]="alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
    [ghostty]="ghostty/config:$HOME/.config/ghostty/config"
    [foot]="foot/foot.ini:$HOME/.config/foot/foot.ini"
)
for f in "$DEST"/extras/term/*; do
    [ -f "$HOME/.config/ochre/term/${f##*/}" ] || install -Dm644 "$f" "$HOME/.config/ochre/term/${f##*/}"
done
src="$DEST/extras/${TERM_CONF[$TERMINAL]%%:*}"
dst="${TERM_CONF[$TERMINAL]#*:}"
if [ ! -f "$dst" ]; then
    install -Dm644 "$src" "$dst"
    ok "конфиг ochre: Terminess, цвета из темы"
elif cmp -s "$dst" "$src"; then
    ok "уже стоит конфиг ochre"
elif ask "Заменить ваш конфиг $TERMINAL на конфиг ochre (Terminess, цвета из темы)?" n; then
    backup "$dst"
    install -Dm644 "$src" "$dst"
    ok "конфиг заменён"
else
    info "оставил ваш конфиг"
fi

# fastfetch в стиле панели — только если своего конфига нет; дальше его ведёт shell (Mod+S → вид → стиль fastfetch)
ff="$HOME/.config/fastfetch/config.jsonc"
if [ ! -f "$ff" ]; then
    install -Dm644 "$DEST/extras/fastfetch/config.jsonc" "$ff"
    # логотип — из каталога shell (в конфиге — путь git-установки)
    sed -i "s#~/.config/quickshell/extras/fastfetch/#$DEST/extras/fastfetch/#" "$ff"
    ok "fastfetch: конфиг ochre"
fi

# ── оболочка ─────────────────────────────────────────────────────────
step "Оболочка: $SHELL_CHOICE"
case "$SHELL_CHOICE" in
    zsh)
        if [ ! -f "$HOME/.zshrc" ]; then
            cp "$DEST/extras/shell/zshrc" "$HOME/.zshrc"
            ok "~/.zshrc: приглашение как панель ochre, подсказки, подсветка"
        elif grep -qE "ochre|nopox-shell" "$HOME/.zshrc"; then
            ok "~/.zshrc уже от ochre"
        elif ask "Заменить ваш ~/.zshrc на ochre (приглашение как панель, подсказки, подсветка)?" n; then
            backup "$HOME/.zshrc"
            cp "$DEST/extras/shell/zshrc" "$HOME/.zshrc"
            ok "~/.zshrc заменён"
        else
            info "оставил ваш ~/.zshrc"
        fi
        ;;
    fish)
        fp="$HOME/.config/fish/functions/fish_prompt.fish"
        install -Dm644 "$DEST/extras/shell/ochre.fish" "$HOME/.config/fish/conf.d/ochre.fish"
        rm -f "$HOME/.config/fish/conf.d/nopox.fish"   # то же под старым именем
        if [ ! -f "$fp" ] || grep -qE "ochre|nopox-shell" "$fp"; then
            install -Dm644 "$DEST/extras/shell/fish_prompt.fish" "$fp"
            ok "приглашение fish как панель ochre"
        elif ask "Заменить ваше приглашение fish на ochre?" n; then
            backup "$fp"
            install -Dm644 "$DEST/extras/shell/fish_prompt.fish" "$fp"
            ok "приглашение fish заменено"
        fi
        ;;
    bash)
        if grep -qE ">>> (ochre|nopox-shell) >>>" "$HOME/.bashrc" 2>/dev/null; then
            ok "~/.bashrc уже с приглашением ochre"
        elif ask "Добавить в ~/.bashrc приглашение как панель ochre?" y; then
            { echo; cat "$DEST/extras/shell/bashrc"; } >> "$HOME/.bashrc"
            ok "добавлено в ~/.bashrc"
        fi
        ;;
esac
target=$(command -v "$SHELL_CHOICE")
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$target" ]; then
    ok "$SHELL_CHOICE уже оболочка по умолчанию"
else
    sudo chsh -s "$target" "$USER" && ok "оболочка по умолчанию: $target (с нового входа)"
fi

# ── приложения по умолчанию ──────────────────────────────────────────
step "Приложения по умолчанию"
if [ -n "${BROWSER_PKG[$BROWSER]}" ] && d=$(desktop_of "${BROWSER_PKG[$BROWSER]}" x-scheme-handler/https) && [ -n "$d" ]; then
    xdg-settings set default-web-browser "$d" && ok "браузер: $d"
fi
if [ -n "${FILES_PKG[$FILES]}" ] && [ "$FILES" != yazi ] && d=$(desktop_of "${FILES_PKG[$FILES]}" inode/directory) && [ -n "$d" ]; then
    xdg-mime default "$d" inode/directory && ok "папки открывает: $d"
fi
[ "$FILES" = yazi ] && ok "файлы: yazi в терминале (Mod+E)"

# ── Discord ──────────────────────────────────────────────────────────
case "$DISCORD_MOD" in
    vencord)
        step "Discord: Vencord"
        # пакет discord — только загрузчик: сам Discord докачивает себя в ~/.config/discord при первом запуске,
        # поэтому Vencord ставится от пользователя туда, а не в /opt
        tmp=$(mktemp)
        curl -fsSL -o "$tmp" https://github.com/Vendicated/VencordInstaller/releases/latest/download/VencordInstallerCli-linux \
            || die "не скачался установщик Vencord"
        sudo install -Dm755 "$tmp" /usr/local/bin/VencordInstallerCli
        rm -f "$tmp"
        if compgen -G "$HOME/.config/discord/app-*/resources/app.asar" >/dev/null; then
            if VencordInstallerCli -install -location "$HOME/.config/discord" </dev/null >/dev/null 2>&1; then
                ok "Vencord установлен"
            else
                warn "Vencord не встал — попробуйте: VencordInstallerCli -install -location ~/.config/discord"
            fi
        else
            warn "Discord ещё не запускался — запустите его один раз, закройте и выполните:"
            info "VencordInstallerCli -install -location ~/.config/discord"
        fi
        info "Discord обновляет себя сам; если Vencord пропал: VencordInstallerCli -repair -location ~/.config/discord"
        ;;
    betterdiscord)
        step "Discord: BetterDiscord"
        if [ -d "$HOME/.config/discord" ]; then
            betterdiscordctl install && ok "BetterDiscord установлен"
        else
            warn "Discord ещё ни разу не запускался — запустите его, закройте и выполните: betterdiscordctl install"
        fi
        info "после обновлений Discord: betterdiscordctl reinstall"
        ;;
    vesktop)
        step "Discord: Vesktop"
        ok "Vesktop установлен вместо Discord — Vencord уже внутри"
        ;;
esac

# ── Steam: уведомления ───────────────────────────────────────────────
# Steam рисует свои уведомления отдельным окном, и niri ставит его посреди экрана. Плагин Millennium nopox-notify
# забирает их у Steam и шлёт через notify-send — приходят как обычные уведомления shell.
STEAM_DIR="$HOME/.local/share/Steam"
NOTIFY_DIR="$HOME/.local/share/nopox-notify"
MCFG="$HOME/.config/millennium/config.json"
if [ "$STEAM_NOTIFY" != no ] && pacman -Qq steam &>/dev/null; then
    step "Steam: уведомления"
    if ask "Поставить Millennium и плагин nopox-notify (уведомления Steam — обычными уведомлениями shell)?" y; then
        install_pkgs millennium bun
        if ! pacman -T millennium >/dev/null || ! command -v bun >/dev/null; then
            warn "Millennium или bun не поставились — см. вывод выше; плагин пропущен"
        else
            # пакет millennium подключается к Steam симлинками, но только если Steam уже запускался
            if [ -d "$STEAM_DIR/ubuntu12_32" ] && [ -d "$STEAM_DIR/ubuntu12_64" ]; then
                ln -sf /usr/lib/millennium/libmillennium_bootstrap_x86.so "$STEAM_DIR/ubuntu12_32/libXtst.so.6"
                ln -sf /usr/lib/millennium/libmillennium_bootstrap_hhx64.so "$STEAM_DIR/ubuntu12_64/libXtst.so.6"
                ok "Millennium подключён к Steam"
            else
                warn "Steam ещё не запускался — запустите его один раз, закройте и подключите Millennium:"
                info "ln -sf /usr/lib/millennium/libmillennium_bootstrap_x86.so ~/.local/share/Steam/ubuntu12_32/libXtst.so.6"
                info "ln -sf /usr/lib/millennium/libmillennium_bootstrap_hhx64.so ~/.local/share/Steam/ubuntu12_64/libXtst.so.6"
            fi

            if [ -d "$NOTIFY_DIR/.git" ]; then
                git -C "$NOTIFY_DIR" pull -q --ff-only || warn "не удалось обновить $NOTIFY_DIR"
            else
                backup "$NOTIFY_DIR"
                git clone -q https://github.com/nopoxxx/nopox-notify "$NOTIFY_DIR"
            fi
            mkdir -p "$HOME/.local/share/millennium/plugins"
            if (cd "$NOTIFY_DIR" && bun install --silent && bun run build) >/dev/null 2>&1; then
                ok "nopox-notify собран → ~/.local/share/millennium/plugins/"
                # включить плагин: plugins.enabledPlugins в config.json Millennium; битый JSON не трогаем
                if bun -e '
                    const fs = require("fs"), path = require("path"), file = process.argv[1];
                    let cfg = {};
                    if (fs.existsSync(file) && fs.statSync(file).size > 0) {
                        try { cfg = JSON.parse(fs.readFileSync(file, "utf8")); } catch { process.exit(1); }
                    }
                    cfg.plugins ??= {};
                    const on = new Set(cfg.plugins.enabledPlugins ?? []);
                    on.add("nopox-notify");
                    cfg.plugins.enabledPlugins = [...on];
                    fs.mkdirSync(path.dirname(file), { recursive: true });
                    fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");' "$MCFG"; then
                    ok "плагин включён"
                else
                    warn "$MCFG не разбирается — включите ochre notify вручную: Steam → Millennium → Plugins"
                fi
                pgrep -x steam >/dev/null && warn "Steam запущен — перезапустите его, чтобы подхватить плагин"
            else
                warn "плагин не собрался — повторить: cd $NOTIFY_DIR && bun install && bun run build"
            fi
        fi
    else
        info "пропущено — потом: https://github.com/nopoxxx/nopox-notify"
    fi
fi

# ── greeter ──────────────────────────────────────────────────────────
step "Greeter (экран входа)"
if [ "$GREETER" = no ] || ! ask "Поставить greeter ochre для greetd?" y; then
    info "пропущено — потом можно: sudo $DEST/extras/install-greeter.sh"
else
    sudo pacman -S --needed --noconfirm greetd
    sudo bash "$DEST/extras/install-greeter.sh" | sed 's/^/  /'

    dm=$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)
    if [ "$dm" = "greetd.service" ]; then
        ok "greetd уже включён"
    elif [ -n "$dm" ]; then
        if ask "Сейчас вход через $dm. Заменить его на greetd с greeter ochre?" n; then
            sudo systemctl disable "$dm"
            sudo systemctl enable greetd
            ok "greetd включён вместо $dm — заработает после перезагрузки"
        else
            info "оставил $dm; переключить потом: sudo systemctl disable $dm && sudo systemctl enable greetd"
        fi
    elif ask "Включить greetd (вход в систему через greeter)?" y; then
        sudo systemctl enable greetd
        ok "greetd включён — заработает после перезагрузки"
    fi
fi

# ── итог ─────────────────────────────────────────────────────────────
step "Готово"
systemctl is-active --quiet NetworkManager \
    || warn "NetworkManager не запущен — модуль net покажет offline (sudo systemctl enable --now NetworkManager)"
if pacman -Qq bluez &>/dev/null && ! systemctl is-enabled --quiet bluetooth 2>/dev/null; then
    sudo systemctl enable --now bluetooth && ok "bluetooth включён — устройства в меню home (Mod+A)"
fi

if [ -n "${NIRI_SOCKET:-}" ] && pgrep -x niri >/dev/null; then
    if ask "Вы сейчас в niri — перезапустить shell?" y; then
        QS=(qs); [ -n "$SYSTEM" ] && QS=(qs -p "$DEST")
        # qs kill гасит по одному экземпляру этого конфига, другие конфиги quickshell не трогает
        for _ in 1 2 3 4 5; do qs kill "${QS[@]:1}" &>/dev/null || break; done
        niri msg action spawn -- "${QS[@]}"
        ok "shell перезапущен"
    fi
else
    info "Войдите в сессию niri: через greeter или командой niri-session из консоли."
fi

cat <<EOF

  ${A}Mod+D${N}        меню             ${A}Mod+S${N}         настройки
  ${A}Mod+Return${N}   $TERMINAL$(printf '%*s' $((17 - ${#TERMINAL})) '')${A}Mod+Shift+W${N}   обои
  ${A}Mod+Space${N}    программы        ${A}Super+Alt+L${N}   блокировка$([ "$FILES" != none ] && printf '\n  %sMod+E%s        %s' "$A" "$N" "$FILES")
  ${A}Mod+Tab${N}      обзор            ${A}Mod+Shift+S${N}   скриншот с разметкой (и Print)$([ "$BROWSER" != none ] && printf '\n  %sMod+Shift+B%s  %s' "$A" "$N" "$BROWSER")
  ${A}Mod+A${N}        меню home        ${A}Mod+Shift+V${N}   история буфера
  ${A}Mod+/${N}        все клавиши      ${A}Mod+Alt+R${N}     запись экрана

  ${D}документация: https://nopoxxx.github.io/ochre/${N}
EOF

#!/bin/sh

# Removes Microsoft AutoUpdate (MAU) after Microsoft Office for Mac has been installed.
# Office keeps working; only the updater and its background services are removed.
#
# Usage:  sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_remove_mau.sh)"
#         (asks for the macOS password itself; "sudo sh -c ..." works too)
# No options: the script asks before removing anything.
#
# What is removed:
#   /Library/Application Support/Microsoft/MAU2.0                 (Microsoft AutoUpdate.app, Update Assistant)
#   /Library/LaunchAgents/com.microsoft.update.agent.plist
#   /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist
#   /Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper

SCRIPT_VERSION="2026-10-08 mau"
SCRIPT_URL="https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_remove_mau.sh"
REMOVED=0
FAILED=0

# ---------------------------------------------------------------- colors
ESC="$(printf '\033')"
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    CYAN="${ESC}[36m"; BOLD="${ESC}[1m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"
    RED="${ESC}[31m"; DETAIL=""; MAGENTA="${ESC}[35m"; RESET="${ESC}[0m"
else
    CYAN=""; BOLD=""; GREEN=""; YELLOW=""; RED=""; DETAIL=""; MAGENTA=""; RESET=""
fi

# ---------------------------------------------------------------- language
# Messages are shown in Russian when the macOS language is Russian, else in English.
LANG_UI=en
detect_lang()   # detect_lang [user_home]
{
    first=""
    # Read the user's global preferences directly: under sudo "defaults -g" would read root's.
    if [ -n "$1" ]; then
        first="$(defaults read "$1/Library/Preferences/.GlobalPreferences" AppleLanguages 2>/dev/null | sed -n '2p')"
    fi
    [ -n "$first" ] || first="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2p')"
    [ -n "$first" ] || first="${LC_ALL:-${LANG:-}}"
    case "$first" in
        *ru*|*RU*) LANG_UI=ru ;;
        *) LANG_UI=en ;;
    esac
}
tx() { if [ "$LANG_UI" = "ru" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
detect_lang

# ---------------------------------------------------------------- output helpers
title() { printf '\n%s%s%s%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
info()  { printf '  %s%s%s\n' "$DETAIL" "$1" "$RESET"; }
warn()  { printf '  %s! %s%s\n' "$YELLOW" "$1" "$RESET"; }
fail()  { printf '  %s✗ %s%s\n' "$RED" "$1" "$RESET"; }
ok()    { printf '  %s✓%s %s%s%s\n' "$GREEN" "$RESET" "$DETAIL" "$1" "$RESET"; }

trap 'printf "\n"; exit 130' INT TERM

# ---------------------------------------------------------------- root / user
if [ "$(id -u)" -ne 0 ]; then
    title "$(tx "Administrator rights required" "Требуются права администратора")"
    info "$(tx "Now you will be asked for the local password of your Mac account (the one you use to log in)." "Сейчас потребуется ввести локальный пароль от вашей учётной записи macOS (тот, которым вы входите в систему).")"
    info "$(tx "Characters are not shown while you type, this is normal. Press Enter when done." "Символы при вводе не отображаются, это нормально. После ввода нажмите Enter.")"
    printf '\n'
    SUDO_PROMPT="$(tx "Mac account password: " "Пароль учётной записи Mac: ")"
    if [ -f "$0" ] && [ "$0" != "sh" ]; then
        exec sudo -p "$SUDO_PROMPT" sh "$0"
    fi
    SELF="$(curl -fsSL "$SCRIPT_URL?$(date +%s)")"
    if [ -z "$SELF" ]; then
        printf '%s%s%s\n' "$RED" "$(tx "Cannot download the script." "Не удалось загрузить скрипт.")" "$RESET"
        exit 1
    fi
    exec sudo -p "$SUDO_PROMPT" sh -c "$SELF"
fi

# The real user, whether started via "sudo sh", "sudo su" or "sudo sh -c ..."
# Needed only to stop the update agent that runs in this user's session.
TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER="$(stat -f%Su /dev/console 2>/dev/null)"
fi
USER_HOME=""
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
    USER_HOME="$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
fi
detect_lang "$USER_HOME"

# Questions are read from the terminal, so it also works with "curl | sh".
if ! [ -r /dev/tty ]; then
    printf '%s\n' "$(tx "No terminal available for questions." "Нет терминала для вопросов.")"
    exit 1
fi

# ---------------------------------------------------------------- question helper
# ask "question" default(y|n) ["description"]
ask()
{
    printf '\n%s?%s %s%s%s\n' "$CYAN" "$RESET" "$BOLD" "$1" "$RESET"
    if [ -n "$3" ]; then
        printf '%s\n' "$3" | while IFS= read -r line; do
            printf '  %s%s%s\n' "$DETAIL" "$line" "$RESET"
        done
    fi
    if [ "$LANG_UI" = "ru" ]; then
        if [ "$2" = "y" ]; then hint="[Д/н]"; else hint="[д/Н]"; fi
    else
        if [ "$2" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
    fi
    while :; do
        printf '  %s›%s %s%s%s ' "$YELLOW" "$RESET" "$YELLOW" "$hint" "$RESET"
        read answer < /dev/tty || exit 1
        case "$answer" in
            "") [ "$2" = "y" ]; return ;;
            y|Y|yes|YES|д|Д|да|Да|ДА) return 0 ;;
            n|N|no|NO|н|Н|нет|Нет|НЕТ) return 1 ;;
        esac
    done
}

# ---------------------------------------------------------------- helpers
MAU_PATHS="/Library/Application Support/Microsoft/MAU2.0
/Library/LaunchAgents/com.microsoft.update.agent.plist
/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist
/Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper"

# Unload the background jobs and stop the updater processes, otherwise they keep running
# (and the deleted files stay in use) until the next reboot.
stop_services()
{
    stopped=0
    if launchctl print "system/com.microsoft.autoupdate.helper" >/dev/null 2>&1; then
        launchctl bootout "system/com.microsoft.autoupdate.helper" >/dev/null 2>&1
        stopped=$((stopped + 1))
    fi
    uid=""
    [ -n "$TARGET_USER" ] && uid="$(id -u "$TARGET_USER" 2>/dev/null)"
    if [ -n "$uid" ] && launchctl print "gui/$uid/com.microsoft.update.agent" >/dev/null 2>&1; then
        launchctl bootout "gui/$uid/com.microsoft.update.agent" >/dev/null 2>&1
        stopped=$((stopped + 1))
    fi
    for proc in "Microsoft AutoUpdate" "Microsoft Update Assistant"; do
        pkill -x "$proc" >/dev/null 2>&1 && stopped=$((stopped + 1))
    done
    if [ "$stopped" -gt 0 ]; then
        title "$(tx "Background services" "Фоновые службы")"
        ok "$(tx "Stopped Microsoft AutoUpdate services and processes:" "Остановлены службы и процессы Microsoft AutoUpdate:") $stopped"
    fi
}

remove_path()
{
    [ -e "$1" ] || [ -L "$1" ] || return 0
    rm_err="$(rm -rf "$1" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "$1"
        REMOVED=$((REMOVED + 1))
    else
        fail "$(tx "Cannot remove" "Не удалось удалить") $1"
        printf '%s\n' "$rm_err" | head -3 | while IFS= read -r line; do
            info "  $line"
        done
        FAILED=$((FAILED + 1))
    fi
}

# ---------------------------------------------------------------- main
[ -t 1 ] && clear
title "$(tx "Microsoft AutoUpdate remover" "Удаление Microsoft AutoUpdate")"
info "$(tx "Removes the Office updater (MAU); Office itself is not touched." "Удаляет службу обновления Office (MAU); сам Office не затрагивается.")"
[ -n "$TARGET_USER" ] && info "$(tx "User" "Пользователь"): $TARGET_USER"
info "$(tx "Language" "Язык"): $LANG_UI   $(tx "Script version" "Версия скрипта"): $SCRIPT_VERSION"

# ---- 1. check what exists before asking anything
FOUND=0
while IFS= read -r p; do
    if [ -e "$p" ] || [ -L "$p" ]; then
        FOUND=$((FOUND + 1))
    fi
done <<EOF
$MAU_PATHS
EOF

if [ "$FOUND" -eq 0 ]; then
    printf '\n%s%s%s%s\n\n' "$BOLD" "$GREEN" "$(tx "Microsoft AutoUpdate not found, nothing to remove." "Microsoft AutoUpdate не найден, удалять нечего.")" "$RESET"
    exit 0
fi
info "$(tx "Components found" "Найдено компонентов"): $FOUND"

# ---- 2. question
if ! ask "$(tx "Remove Microsoft AutoUpdate?" "Удалить Microsoft AutoUpdate?")" n \
"$(tx "Found: $FOUND component(s): the updater app, its launch agent, launch daemon and privileged helper.
Afterwards 'Check for Updates' in Office stops working: install Office updates by hand
(download the installer from Microsoft). Reinstalling or updating Office may bring MAU back." "Найдено компонентов: $FOUND: приложение обновления, его агент и демон запуска, привилегированный помощник.
После этого «Проверить обновления» в Office перестанет работать: обновления Office придётся
ставить вручную (скачивать установщик с сайта Microsoft). Переустановка или обновление Office может вернуть MAU.")"; then
    printf '\n'
    info "$(tx "Nothing was removed." "Ничего не удалено.")"
    printf '\n'
    exit 0
fi

# ---- 3. removal
stop_services
title "$(tx "Removal" "Удаление")"
while IFS= read -r p; do
    remove_path "$p"
done <<EOF
$MAU_PATHS
EOF

# ---------------------------------------------------------------- summary
if [ "$FAILED" -gt 0 ]; then
    printf '\n%s%s%s %s%s\n' "$BOLD" "$YELLOW" "$(tx "Done with errors. Items removed:" "Готово с ошибками. Удалено элементов:")" "$REMOVED" "$RESET"
    info "$(tx "Failed to remove: $FAILED. Reasons are shown above." "Не удалось удалить: $FAILED. Причины показаны выше.")"
    printf '\n'
    exit 1
fi
printf '\n%s%s%s %s%s\n' "$BOLD" "$GREEN" "$(tx "Done. Items removed:" "Готово. Удалено элементов:")" "$REMOVED" "$RESET"
printf '\n'

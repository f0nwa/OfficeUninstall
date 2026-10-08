#!/bin/sh

# Restores the Outlook profile saved by office_uninstaller.sh
# (Desktop/OfficeUninstall-backup-*) into a freshly installed Microsoft Office for Mac.
#
# Usage:  sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_restore.sh)"
#         Run it as your normal user, without sudo: no administrator rights are needed.
#         A backup folder can be passed explicitly:  sh -c "$(curl -fsSL ...)" sh /path/to/backup
#
# The backup holds two folders that go back to the places they were copied from:
#   com.microsoft.Outlook  ->  ~/Library/Containers/
#   UBF8T346G9.Office      ->  ~/Library/Group Containers/

SCRIPT_VERSION="2026-10-08 restore"

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
detect_lang()
{
    first="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2p')"
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

# ---------------------------------------------------------------- spinner
SPIN_PID=""
spin_start()
{
    [ -t 1 ] || return 0
    spin_stop
    msg="$1"
    cols="$(tput cols 2>/dev/null || echo 80)"
    max=$((cols - 8))
    [ "$max" -lt 20 ] && max=20
    if [ "${#msg}" -gt "$max" ]; then
        msg="$(printf '%s' "$msg" | cut -c1-$((max - 3)))..."
    fi
    (
        while :; do
            for f in ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; do
                printf '\r%s[2K  %s%s%s %s%s%s' "$ESC" "$CYAN" "$f" "$RESET" "$DETAIL" "$msg" "$RESET"
                sleep 0.1
            done
        done
    ) &
    SPIN_PID=$!
}
spin_stop()
{
    if [ -n "$SPIN_PID" ]; then
        kill -KILL "$SPIN_PID" 2>/dev/null
        wait "$SPIN_PID" 2>/dev/null
        SPIN_PID=""
        printf '\r%s[2K' "$ESC"
    fi
}
trap 'spin_stop' EXIT
trap 'spin_stop; printf "\n"; exit 130' INT TERM

# ---------------------------------------------------------------- user
# No administrator rights are needed: everything lives in the user's own Library.
# Under sudo the files would be created for root, so refuse to run that way.
if [ "$(id -u)" -eq 0 ]; then
    printf '%s%s%s\n' "$RED" "$(tx "Run this script as your normal user, without sudo." "Запустите скрипт от своего обычного пользователя, без sudo.")" "$RESET"
    exit 1
fi
USER_HOME="$HOME"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    printf '%s%s%s\n' "$RED" "$(tx "Home directory not found." "Домашняя папка не найдена.")" "$RESET"
    exit 1
fi

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

# ---------------------------------------------------------------- disk access
# Name of the terminal app for hints (Terminal.app sets TERM_PROGRAM=Apple_Terminal).
terminal_app_name()
{
    case "${TERM_PROGRAM:-}" in
        ""|Apple_Terminal) printf 'Terminal' ;;
        iTerm.app) printf 'iTerm' ;;
        *) printf '%s' "$TERM_PROGRAM" ;;
    esac
}

# Full Disk Access check: the TCC database can only be read with it.
can_read_tcc()
{
    [ -e "/Library/Application Support/com.apple.TCC/TCC.db" ] || return 0
    head -c 1 "/Library/Application Support/com.apple.TCC/TCC.db" >/dev/null 2>&1
}

# macOS does not show a dialog for Full Disk Access and does not let a program grant
# it: open the Full Disk Access pane, wait, check again. Restarting the terminal is
# not required: choose "Later" if macOS offers it.
FDA_GRANTED_NOW=0   # 1 only when the user granted Full Disk Access during this run
ensure_disk_access()
{
    can_read_tcc && return 0
    app="$(terminal_app_name)"
    title "$(tx "Disk access for $app" "Доступ к диску для $app")"
    warn "$(tx "To read the backup and write into Outlook's containers macOS needs Full Disk Access for $app." "Чтобы прочитать копию и записать данные в контейнеры Outlook, macOS требуется «Полный доступ к диску» для $app.")"
    info "$(tx "Without it macOS blocks access to other apps' data and the restore may fail halfway." "Без него macOS блокирует доступ к данным других приложений, и восстановление может оборваться на середине.")"
    if ask "$(tx "Open System Settings and grant access now?" "Открыть Системные настройки и выдать доступ сейчас?")" y; then
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" >/dev/null 2>&1
        info "$(tx "1. In the window that opened, enable the switch next to $app" "1. В открывшемся окне включите переключатель рядом с $app")"
        info "$(tx "   (if it is not listed: '+' > Applications > Utilities > $app)." "   (если его нет в списке: «+» → Программы → Утилиты → $app).")"
        info "$(tx "2. If macOS offers 'Quit & Reopen', choose 'Later'. Restarting $app is NOT needed." "2. Если macOS предложит «Завершить и открыть снова», выберите «Позже». Перезапускать $app НЕ нужно.")"
        info "$(tx "3. Come back here and press Enter." "3. Вернитесь сюда и нажмите Enter.")"
        tries=0
        while [ "$tries" -lt 3 ]; do
            tries=$((tries + 1))
            printf '  %s›%s %s' "$YELLOW" "$RESET" "$(tx "Press Enter when access is granted... " "Нажмите Enter, когда доступ выдан... ")"
            read dummy < /dev/tty || exit 1
            if can_read_tcc; then
                printf '  %s✓ %s%s\n' "$GREEN" "$(tx "Access granted." "Доступ получен.")" "$RESET"
                FDA_GRANTED_NOW=1
                return 0
            fi
            warn "$(tx "Access is not visible to the script yet. Make sure the switch next to $app is on." "Скрипт пока не видит доступ. Убедитесь, что переключатель рядом с $app включён.")"
        done
        info "$(tx "If the switch is on but access is still not active, quit $app (Cmd+Q), open it again and run the script again." "Если переключатель включён, а доступа всё нет, закройте $app (Cmd+Q), откройте снова и запустите скрипт ещё раз.")"
    fi
    if ask "$(tx "Continue without access?" "Продолжить без доступа?")" n \
    "$(tx "macOS will ask for access separately and part of the data may not be restored." "macOS будет спрашивать доступ отдельно, часть данных может не восстановиться.")"; then
        return 0
    fi
    printf '\n'
    info "$(tx "Stopped. Grant Full Disk Access to $app and run the script again." "Остановлено. Выдайте $app «Полный доступ к диску» и запустите скрипт снова.")"
    exit 0
}

# ---------------------------------------------------------------- helpers
OUTLOOK_APP="/Applications/Microsoft Outlook.app"
ITEM_NAMES="com.microsoft.Outlook UBF8T346G9.Office"

dest_for()   # dest_for NAME -> the place the folder lived in before the uninstall
{
    case "$1" in
        com.microsoft.Outlook) printf '%s' "$USER_HOME/Library/Containers/$1" ;;
        *) printf '%s' "$USER_HOME/Library/Group Containers/$1" ;;
    esac
}

# Office apps share the UBF8T346G9.Office container, all of them must be closed.
running_office()
{
    for proc in "Microsoft Word" "Microsoft Excel" "Microsoft PowerPoint" "Microsoft Outlook" "Microsoft OneNote"; do
        pgrep -x "$proc" >/dev/null 2>&1 && printf '%s\n' "$proc"
    done
}

count_files()
{
    find "$1" -type f ! -name '.com.apple.containermanagerd.metadata.plist' 2>/dev/null | wc -l | tr -d ' '
}

# copy_tree SRC DEST: merges SRC into DEST like the backup was made (ditto). The system
# metadata file of a container is protected and never part of a backup, errors about it
# are ignored. The reason of a real failure is left in COPY_ERR.
COPY_ERR=""
copy_tree()
{
    attempt=0
    rc=1
    real_err=""
    while [ "$rc" -ne 0 ] && [ "$attempt" -lt 3 ]; do
        attempt=$((attempt + 1))
        [ "$attempt" -gt 1 ] && sleep 2
        copy_err="$(ditto "$1" "$2" 2>&1)"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            # without extended attributes, ACLs and resource forks
            copy_err="$(ditto --noextattr --noacl --norsrc --noqtn "$1" "$2" 2>&1)"
            rc=$?
        fi
        real_err="$(printf '%s\n' "$copy_err" | grep -v 'containermanagerd.metadata.plist' | grep .)"
        [ -z "$real_err" ] && rc=0
    done
    COPY_ERR="$real_err"
    return "$rc"
}

show_error()
{
    printf '%s\n' "$COPY_ERR" | head -3 | while IFS= read -r line; do
        # keep the end of the line: the reason comes last
        info "  $(printf '%s' "$line" | awk '{ if (length($0) > 100) print "..." substr($0, length($0) - 96); else print }')"
    done
}

# ---------------------------------------------------------------- main
[ -t 1 ] && clear
title "$(tx "Outlook profile restore from the backup" "Восстановление профиля Outlook из резервной копии")"
info "$(tx "Home" "Домашняя папка"): $USER_HOME"
info "$(tx "Language" "Язык"): $LANG_UI   $(tx "Script version" "Версия скрипта"): $SCRIPT_VERSION"

# ---- 1. Full Disk Access first: the backup is on the Desktop and the targets are app containers
ensure_disk_access

# ---- 2. Office must be installed and closed
if [ ! -d "$OUTLOOK_APP" ]; then
    title "$(tx "Microsoft Outlook is not installed" "Microsoft Outlook не установлен")"
    fail "$OUTLOOK_APP"
    info "$(tx "Install Microsoft Office first, then run this script again." "Сначала установите Microsoft Office, затем запустите скрипт снова.")"
    printf '\n'
    exit 1
fi

RUNNING="$(running_office)"
if [ -n "$RUNNING" ]; then
    title "$(tx "Office applications are running" "Запущены приложения Office")"
    printf '%s\n' "$RUNNING" | while IFS= read -r proc; do
        warn "$proc"
    done
    info "$(tx "Quit them (Cmd+Q), save your documents, and run the script again." "Закройте их (Cmd+Q), сохраните документы и запустите скрипт повторно.")"
    printf '\n'
    exit 1
fi

# ---- 3. find the backup
if [ -n "$1" ]; then
    SRC="${1%/}"
    if [ ! -d "$SRC/com.microsoft.Outlook" ] && [ ! -d "$SRC/UBF8T346G9.Office" ]; then
        title "$(tx "This is not an Outlook backup" "Это не резервная копия Outlook")"
        fail "$SRC"
        info "$(tx "The folder must contain com.microsoft.Outlook and/or UBF8T346G9.Office." "В папке должны быть com.microsoft.Outlook и/или UBF8T346G9.Office.")"
        printf '\n'
        exit 1
    fi
else
    BACKUPS=""
    for d in "$USER_HOME/Desktop/OfficeUninstall-backup-"*; do
        [ -d "$d" ] || continue
        if [ -d "$d/com.microsoft.Outlook" ] || [ -d "$d/UBF8T346G9.Office" ]; then
            BACKUPS="$BACKUPS$d
"
        fi
    done
    BACKUPS="$(printf '%s' "$BACKUPS" | grep . | sort -r)"   # newest first
    if [ -z "$BACKUPS" ]; then
        title "$(tx "Backup not found" "Резервная копия не найдена")"
        info "$(tx "Looked for $USER_HOME/Desktop/OfficeUninstall-backup-* with Outlook data inside." "Искали $USER_HOME/Desktop/OfficeUninstall-backup-* с данными Outlook внутри.")"
        info "$(tx "If you moved the backup, pass its folder as an argument:" "Если вы переместили копию, передайте её папку аргументом:")"
        info "  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_restore.sh)\" sh /path/to/backup"
        printf '\n'
        exit 1
    fi
    COUNT="$(printf '%s\n' "$BACKUPS" | grep -c .)"
    if [ "$COUNT" -eq 1 ]; then
        SRC="$BACKUPS"
    else
        title "$(tx "Several backups found" "Найдено несколько копий")"
        n=0
        while IFS= read -r d; do
            n=$((n + 1))
            info "$n. $(basename "$d")$([ "$n" -eq 1 ] && tx "   (newest)" "   (самая свежая)")"
        done <<EOF
$BACKUPS
EOF
        while :; do
            printf '\n  %s›%s %s ' "$YELLOW" "$RESET" "$(tx "Number of the backup to restore [1]:" "Номер копии для восстановления [1]:")"
            read choice < /dev/tty || exit 1
            [ -n "$choice" ] || choice=1
            case "$choice" in
                *[!0-9]*) continue ;;
            esac
            SRC="$(printf '%s\n' "$BACKUPS" | sed -n "${choice}p")"
            [ -n "$SRC" ] && break
        done
    fi
fi

title "$(tx "Backup" "Резервная копия")"
info "$SRC"
ITEMS=""
for name in $ITEM_NAMES; do
    if [ -d "$SRC/$name" ]; then
        info "  $name ($(du -sh "$SRC/$name" 2>/dev/null | awk '{print $1}'))"
        ITEMS="$ITEMS$name
"
    else
        warn "$(tx "Not in the backup" "Нет в копии"): $name"
    fi
done
ITEMS="$(printf '%s' "$ITEMS" | grep .)"

if [ -f "$SRC/backup-errors.log" ]; then
    warn "$(tx "The backup is incomplete: some data could not be copied when it was made." "Копия неполная: при её создании часть данных скопировать не удалось.")"
    head -3 "$SRC/backup-errors.log" | while IFS= read -r line; do
        info "  $(printf '%s' "$line" | awk '{ if (length($0) > 100) print "..." substr($0, length($0) - 96); else print }')"
    done
    ask "$(tx "Restore from the incomplete backup anyway?" "Всё равно восстановить из неполной копии?")" n || { printf '\n'; exit 0; }
fi

# ---- 4. the containers must exist: macOS creates them when Outlook starts for the first time
MISSING=""
for name in $ITEMS; do
    [ -d "$(dest_for "$name")" ] || MISSING="$MISSING$name
"
done
MISSING="$(printf '%s' "$MISSING" | grep .)"
if [ -n "$MISSING" ]; then
    title "$(tx "Outlook has not been started yet" "Outlook ещё не запускался")"
    printf '%s\n' "$MISSING" | while IFS= read -r name; do
        warn "$(tx "No such folder yet" "Такой папки ещё нет"): $(dest_for "$name")"
    done
    info "$(tx "macOS creates these folders with the right permissions when Outlook starts for the first time." "macOS создаёт эти папки с правильными правами при первом запуске Outlook.")"
    if ! ask "$(tx "Start Outlook now to create them?" "Запустить Outlook сейчас, чтобы они создались?")" y; then
        info "$(tx "Start Outlook once, quit it (Cmd+Q) and run this script again." "Запустите Outlook один раз, закройте его (Cmd+Q) и запустите скрипт снова.")"
        printf '\n'
        exit 0
    fi
    open -a "Microsoft Outlook" >/dev/null 2>&1
    spin_start "$(tx "Waiting for Outlook to create its folders..." "Ждём, пока Outlook создаст свои папки...")"
    waited=0
    while [ "$waited" -lt 90 ]; do
        still=""
        for name in $ITEMS; do
            [ -d "$(dest_for "$name")" ] || still=1
        done
        [ -z "$still" ] && break
        sleep 2
        waited=$((waited + 2))
    done
    spin_stop
    if [ -n "$still" ]; then
        fail "$(tx "The folders did not appear." "Папки не появились.")"
        info "$(tx "Finish the first-run screen in Outlook, quit it (Cmd+Q) and run this script again." "Пройдите экран первого запуска в Outlook, закройте его (Cmd+Q) и запустите скрипт снова.")"
        printf '\n'
        exit 1
    fi
    ok "$(tx "Folders created." "Папки созданы.")"
    # The script started Outlook itself a moment ago, there is nothing to save in it: close it here.
    # SIGTERM instead of an Apple event, which would make macOS ask for Automation access.
    sleep 3   # let it finish writing its first files
    spin_start "$(tx "Closing Outlook..." "Закрываем Outlook...")"
    pkill -x "Microsoft Outlook" >/dev/null 2>&1
    waited=0
    while [ -n "$(running_office)" ] && [ "$waited" -lt 20 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    pkill -x "Microsoft Database Daemon" >/dev/null 2>&1
    spin_stop
    [ -z "$(running_office)" ] && ok "$(tx "Outlook closed." "Outlook закрыт.")"
    # Fallback: if it did not quit, ask the user to do it.
    while [ -n "$(running_office)" ]; do
        info "$(tx "Quit Outlook now (Cmd+Q)." "Закройте Outlook (Cmd+Q).")"
        printf '  %s›%s %s' "$YELLOW" "$RESET" "$(tx "Press Enter when Outlook is closed... " "Нажмите Enter, когда Outlook закрыт... ")"
        read dummy < /dev/tty || exit 1
    done
fi

# ---- 5. confirmation
# The question repeats which backup and what goes where: the backup list may be off screen by now.
SRC_NAME="$(basename "$SRC")"
# OfficeUninstall-backup-YYYYMMDD-HHMMSS -> DD.MM.YYYY HH:MM:SS (other folder names: no date)
SRC_DATE="$(printf '%s' "$SRC_NAME" | sed -n 's/.*-\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)$/\3.\2.\1 \4:\5:\6/p')"
PLAN=""
for name in $ITEMS; do
    size="$(du -sh "$SRC/$name" 2>/dev/null | awk '{print $1}')"
    shown_dest="$(dest_for "$name" | sed "s#^$USER_HOME#~#")"
    PLAN="$PLAN  $name ($size)  →  $shown_dest
"
done
if [ -n "$SRC_DATE" ]; then
    ASK_TITLE="$(tx "Restore the Outlook profile from the backup made on $SRC_DATE?" "Восстановить профиль Outlook из копии от $SRC_DATE?")"
else
    ASK_TITLE="$(tx "Restore the Outlook profile from the backup $SRC_NAME?" "Восстановить профиль Outlook из копии $SRC_NAME?")"
fi
if ! ask "$ASK_TITLE" y \
"$(tx "Backup:" "Копия:") $SRC
$(tx "Will be restored:" "Будет восстановлено:")
$PLAN$(tx "Files with the same names in the current Outlook folders will be replaced.
A copy of the current data is saved to the Desktop first." "Файлы с теми же именами в текущих папках Outlook будут заменены.
Перед этим копия текущих данных сохраняется на Рабочий стол.")"; then
    printf '\n'
    exit 0
fi

# ---- 6. restore
# Outlook's background helper keeps the database open.
pkill -x "Microsoft Database Daemon" >/dev/null 2>&1
sleep 1

title "$(tx "Restore" "Восстановление")"
SAFE="$USER_HOME/Desktop/OfficeUninstall-before-restore-$(date +%Y%m%d-%H%M%S)"
SAFE_USED=0
SAFE_FAILED=0
for name in $ITEMS; do
    dest="$(dest_for "$name")"
    if [ -n "$(find "$dest" -mindepth 1 ! -name '.com.apple.containermanagerd.metadata.plist' 2>/dev/null | head -1)" ]; then
        mkdir -p "$SAFE"
        spin_start "$(tx "Saving the current data" "Сохраняем текущие данные") $dest"
        copy_tree "$dest" "$SAFE/$name"
        rc=$?
        spin_stop
        if [ "$rc" -eq 0 ]; then
            SAFE_USED=1
        else
            fail "$(tx "Cannot save the current data of" "Не удалось сохранить текущие данные") $name"
            show_error
            SAFE_FAILED=1
        fi
    fi
done
if [ "$SAFE_FAILED" -eq 1 ]; then
    if ! ask "$(tx "Restore without a copy of the current data?" "Восстанавливать без копии текущих данных?")" n; then
        info "$(tx "Stopped, nothing was changed." "Остановлено, ничего не изменено.")"
        printf '\n'
        exit 1
    fi
fi
[ -d "$SAFE" ] && [ "$SAFE_USED" -eq 0 ] && rmdir "$SAFE" 2>/dev/null

RESTORED=0
BAD=0
for name in $ITEMS; do
    dest="$(dest_for "$name")"
    spin_start "$(tx "Restoring" "Восстановление") $name"
    copy_tree "$SRC/$name" "$dest"
    rc=$?
    spin_stop
    if [ "$rc" -ne 0 ]; then
        fail "$(tx "Cannot restore" "Не удалось восстановить") $name"
        show_error
        BAD=$((BAD + 1))
        continue
    fi
    # The merge only adds to the destination, so it must hold at least as many files as the backup.
    src_n="$(count_files "$SRC/$name")"
    dest_n="$(count_files "$dest")"
    if [ "${dest_n:-0}" -ge "${src_n:-0}" ]; then
        ok "$name ($src_n $(tx "files" "файлов"))"
        RESTORED=$((RESTORED + 1))
    else
        fail "$(tx "Not all files arrived" "Файлы скопированы не полностью"): $name ($dest_n/$src_n)"
        BAD=$((BAD + 1))
    fi
done

# ---------------------------------------------------------------- summary
printf '\n'
if [ "$BAD" -eq 0 ]; then
    printf '%s%s%s%s\n' "$BOLD" "$GREEN" "$(tx "Done. Folders restored:" "Готово. Восстановлено папок:") $RESTORED" "$RESET"
    title "$(tx "What next" "Что дальше")"
    info "$(tx "- Start Outlook: the profile and local data should be back." "- Запустите Outlook: профиль и локальные данные должны вернуться.")"
    info "$(tx "- Mail from IMAP, Exchange and Microsoft 365 is pulled from the server again, you may need to sign in once more." "- Почта IMAP, Exchange и Microsoft 365 подтянется с сервера заново, возможно, придётся ещё раз войти в аккаунт.")"
    info "$(tx "- Keep the backup folder until you are sure everything is in place." "- Не удаляйте папку с копией, пока не убедитесь, что всё на месте.")"
    # Full Disk Access is a broad permission: suggest taking it back, but only if this run asked for it.
    if [ "$FDA_GRANTED_NOW" -eq 1 ]; then
        info "$(tx "- Full Disk Access for $(terminal_app_name) was needed only while the script ran. You can turn it off: System Settings > Privacy & Security > Full Disk Access." "- Доступ к диску для $(terminal_app_name) был нужен только на время работы скрипта. Его можно отключить: Системные настройки > Конфиденциальность и безопасность > Полный доступ к диску.")"
    fi
    [ "$SAFE_USED" -eq 1 ] && info "$(tx "- The data that was in Outlook before the restore is in" "- Данные, которые были в Outlook до восстановления, лежат в") ${MAGENTA}${SAFE}${RESET} $(tx "(can be deleted when you do not need it)." "(можно удалить, когда не понадобится).")"
else
    printf '%s%s%s%s\n' "$BOLD" "$RED" "$(tx "The restore is incomplete. Failed folders:" "Восстановление неполное. Не удалось папок:") $BAD" "$RESET"
    info "$(tx "Check the reasons above (Full Disk Access for the terminal) and run the script again: it is safe to repeat." "Проверьте причины выше (полный доступ к диску для терминала) и запустите скрипт ещё раз: повтор безопасен.")"
    exit 1
fi
printf '\n'

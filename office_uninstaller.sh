#!/bin/sh

# Author : jim ye
# Interactive uninstaller for Microsoft Office for Mac 2011/2016/2019/2021/2024/365
#
# Usage:  sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
#         (asks for the macOS password itself; "sudo sh -c ..." works too)
# No options: the script asks everything interactively.
#
# Reference:
# 1.https://support.microsoft.com/en-us/kb/2398768
# 2.https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

SCRIPT_VERSION="2026-10-08 dock-recent"
SCRIPT_URL="https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh"
REMOVED=0
CLEAN_PROFILE=0

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

MODE=run          # "scan": only count what exists, print and delete nothing
FOUND_SYSTEM=0
FOUND_PROFILE=0
FOUND_PERSONAL=0
KC_COUNT=0
KC_RC=0
DO_SYSTEM=0
FAILED=""
PROTECT_PERSONAL=0
STEP_TITLE=""
step_end() { STEP_TITLE=""; }
# The title is printed lazily, only when something is actually removed in the step.
step() { [ "$MODE" = "scan" ] && return; STEP_TITLE="$1"; }

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
TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER="$(stat -f%Su /dev/console 2>/dev/null)"
fi
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    printf '%s ' "$(tx "Cannot detect the login user. Enter the user name whose Office data should be removed:" "Не удалось определить пользователя. Введите имя пользователя, у которого нужно удалить данные Office:")"
    read TARGET_USER < /dev/tty
fi
USER_HOME="$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] || [ "$USER_HOME" = "/var/root" ]; then
    printf '%s%s%s\n' "$RED" "$(tx "Home directory of user '$TARGET_USER' not found." "Домашняя папка пользователя '$TARGET_USER' не найдена.")" "$RESET"
    exit 1
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

# ---------------------------------------------------------------- delete helpers
# A container left with nothing but the system metadata file (macOS keeps it and
# does not let anyone remove it) holds no data: treat it as already gone.
NO_FDA=0
FDA_GRANTED_NOW=0   # 1 only when the user granted Full Disk Access during this run
is_hollow()
{
    [ -d "$1" ] || return 1
    hollow_out="$(find "$1" -mindepth 1 ! -name '.com.apple.containermanagerd.metadata.plist' 2>/dev/null)"
    [ $? -eq 0 ] && [ -z "$hollow_out" ]
}

is_personal() { printf '%s\n' "$PERSONAL" | grep -Fxq -- "$1"; }

delete()
{
    case "$1" in
        "$USER_HOME/Library/Containers/"*|"$USER_HOME/Library/Group Containers/"*)
            is_hollow "$1" && return ;;
    esac
    if [ "$PROTECT_PERSONAL" -eq 1 ] && is_personal "$1"; then
        return
    fi
    if [ "$MODE" = "scan" ]; then
        if [ -e "$1" ] || [ -L "$1" ]; then
            case "$1" in
                "$USER_HOME"/*) FOUND_PROFILE=$((FOUND_PROFILE + 1)) ;;
                *) FOUND_SYSTEM=$((FOUND_SYSTEM + 1)) ;;
            esac
        fi
        return
    fi
    case "$1" in
        "$USER_HOME"/*) [ "$CLEAN_PROFILE" -eq 1 ] || return ;;
        *) [ "$DO_SYSTEM" -eq 1 ] || return ;;
    esac
    if [ -e "$1" ] || [ -L "$1" ]; then
        if [ -n "$STEP_TITLE" ]; then
            title "$STEP_TITLE"
            STEP_TITLE=""
        fi
        spin_start "$(tx "Removing" "Удаление") $1"
        rm_err="$(rm -rf "$1" 2>&1)"
        rc=$?
        spin_stop
        if [ "$rc" -eq 0 ]; then
            ok "$1"
            REMOVED=$((REMOVED + 1))
        else
            case "$rm_err" in
                *"Operation not permitted"*|*"Permission denied"*)
                    fail "$(tx "Access denied by macOS" "macOS не дала доступ"): $1"
                    FAILED="$FAILED
$1" ;;
                *) fail "$(tx "Cannot remove" "Не удалось удалить") $1" ;;
            esac
        fi
    fi
}

deletefiles()   # deletefiles /path/prefix  -> removes /path/prefix*
{
    for file in "$1"*; do
        delete "$file"
    done
}

# Only Office-related bundle ids (not Edge, VS Code, Teams, Remote Desktop ...)
OFFICE_IDS="com.microsoft.Word com.microsoft.Excel com.microsoft.Powerpoint
com.microsoft.Outlook com.microsoft.onenote com.microsoft.office
com.microsoft.Office com.microsoft.autoupdate com.microsoft.errorreporting
com.microsoft.netlib com.microsoft.RMS com.microsoft.Messenger
com.microsoft.Communicator com.microsoft.openxml
com.microsoft.PowerPoint com.microsoft.outlook com.microsoft.excel com.microsoft.word
com.microsoft.OneNote"
ONEDRIVE_IDS="com.microsoft.OneDrive com.microsoft.onedrive"

deleteids()   # deleteids DIR "ID LIST"
{
    for id in $2; do
        deletefiles "$1/$id"
    done
}

as_user() { sudo -H -u "$TARGET_USER" "$@"; }

PERSONAL="$USER_HOME/Library/Group Containers/UBF8T346G9.Office
$USER_HOME/Library/Containers/com.microsoft.Outlook
$USER_HOME/Documents/Microsoft ~ Data
$USER_HOME/Documents/Microsoft User Data"

# ---------------------------------------------------------------- Dock
PLISTBUDDY=/usr/libexec/PlistBuddy
DOCK_PLIST="$USER_HOME/Library/Preferences/com.apple.dock.plist"
DOCK_REMOVED=0

# Dock arrays with app icons: pinned apps and the "recent applications" section.
DOCK_ARRAYS="persistent-apps recent-apps"

# Prints "array|index|name" for Dock icons of Office apps in array $1, highest index
# first (deleting from the end keeps the lower indexes valid).
dock_office_icons()
{
    arr="$1"
    [ -f "$DOCK_PLIST" ] && [ -x "$PLISTBUDDY" ] || return 0
    n="$(as_user "$PLISTBUDDY" -c "Print :$arr" "$DOCK_PLIST" 2>/dev/null | grep -c '^    Dict {')"
    [ "${n:-0}" -gt 0 ] || return 0
    i=$((n - 1))
    while [ "$i" -ge 0 ]; do
        url="$(as_user "$PLISTBUDDY" -c "Print :$arr:$i:tile-data:file-data:_CFURLString" "$DOCK_PLIST" 2>/dev/null)"
        name=""
        case "$url" in
            *"Microsoft%20Word.app"*) name="Microsoft Word" ;;
            *"Microsoft%20Excel.app"*) name="Microsoft Excel" ;;
            *"Microsoft%20PowerPoint.app"*) name="Microsoft PowerPoint" ;;
            *"Microsoft%20Outlook.app"*) name="Microsoft Outlook" ;;
            *"Microsoft%20OneNote.app"*) name="Microsoft OneNote" ;;
            */OneDrive.app*) name="OneDrive" ;;
        esac
        [ -n "$name" ] && printf '%s|%s|%s\n' "$arr" "$i" "$name"
        i=$((i - 1))
    done
}

remove_dock_icons()
{
    icons=""
    for arr in $DOCK_ARRAYS; do
        found="$(dock_office_icons "$arr")"
        [ -n "$found" ] && icons="$icons$found
"
    done
    icons="$(printf '%s' "$icons" | grep .)"
    [ -n "$icons" ] || return 0
    if [ "$MODE" = "scan" ]; then
        FOUND_SYSTEM=$((FOUND_SYSTEM + $(printf '%s\n' "$icons" | grep -c .)))
        return 0
    fi
    [ "$DO_SYSTEM" -eq 1 ] || return 0
    title "Dock"
    while IFS='|' read -r arr idx name; do
        [ -n "$idx" ] || continue
        case "$arr" in
            recent-apps) where="$(tx "recent" "недавние")" ;;
            *) where="$(tx "pinned" "закреплена")" ;;
        esac
        if as_user "$PLISTBUDDY" -c "Delete :$arr:$idx" "$DOCK_PLIST" >/dev/null 2>&1; then
            ok "$(tx "Removed icon" "Удалена иконка"): $name ($where)"
            REMOVED=$((REMOVED + 1))
            DOCK_REMOVED=$((DOCK_REMOVED + 1))
        else
            fail "$(tx "Cannot remove icon" "Не удалось удалить иконку"): $name ($where)"
        fi
    done <<EOF
$icons
EOF
    if [ "$DOCK_REMOVED" -gt 0 ]; then
        as_user killall cfprefsd >/dev/null 2>&1
        as_user killall Dock >/dev/null 2>&1
    fi
}

# ---------------------------------------------------------------- receipts and services
# Installer receipts of the Office packages (com.microsoft.package.*): the file mask
# alone does not catch them, "pkgutil --forget" removes them from the receipt database.
office_pkgs()
{
    pkgutil --pkgs 2>/dev/null | grep -E '^com\.microsoft\.(package|pkg)\.' | grep -v -i 'teams'
}

forget_receipts()
{
    pkgs="$(office_pkgs)"
    [ -n "$pkgs" ] || return 0
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        if [ "$MODE" = "scan" ]; then
            FOUND_SYSTEM=$((FOUND_SYSTEM + 1))
            continue
        fi
        [ "$DO_SYSTEM" -eq 1 ] || continue
        if [ -n "$STEP_TITLE" ]; then
            title "$STEP_TITLE"
            STEP_TITLE=""
        fi
        if pkgutil --forget "$pkg" >/dev/null 2>&1; then
            ok "pkgutil: $pkg"
            REMOVED=$((REMOVED + 1))
        else
            fail "pkgutil: $pkg"
        fi
    done <<EOF
$pkgs
EOF
}

# Unload background jobs and stop helper processes, otherwise they keep running
# (and may recreate files) until the next reboot.
stop_services()
{
    stopped=0
    for label in com.microsoft.office.licensing.helper com.microsoft.office.licensingV2.helper \
                 com.microsoft.autoupdate.helper com.microsoft.onedriveupdaterdaemon; do
        if launchctl print "system/$label" >/dev/null 2>&1; then
            launchctl bootout "system/$label" >/dev/null 2>&1
            stopped=$((stopped + 1))
        fi
    done
    uid="$(id -u "$TARGET_USER" 2>/dev/null)"
    if [ -n "$uid" ] && launchctl print "gui/$uid/com.microsoft.update.agent" >/dev/null 2>&1; then
        launchctl bootout "gui/$uid/com.microsoft.update.agent" >/dev/null 2>&1
        stopped=$((stopped + 1))
    fi
    for proc in "Microsoft AutoUpdate" "Microsoft Update Assistant" "Microsoft Error Reporting" "OneDrive"; do
        pkill -x "$proc" >/dev/null 2>&1 && stopped=$((stopped + 1))
    done
    if [ "$stopped" -gt 0 ]; then
        title "$(tx "Background services" "Фоновые службы")"
        ok "$(tx "Stopped Microsoft background services and updaters:" "Остановлены фоновые службы и обновлялки Microsoft:") $stopped"
    fi
}

# ---------------------------------------------------------------- backup
do_backup()
{
    title "$(tx "Backup" "Резервная копия")"
    BACKUP="$USER_HOME/Desktop/OfficeUninstall-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    COPIED=0
    COPY_FAILED=0
    # Outlook's background helpers keep its database open and may still be writing to it.
    for helper in "Microsoft Database Daemon" "Microsoft Outlook"; do
        pkill -x "$helper" >/dev/null 2>&1
    done
    sleep 1
    while IFS= read -r p; do
        if [ -e "$p" ]; then
            spin_start "$(tx "Copying" "Копирование") $p"
            dest="$BACKUP/$(basename "$p")"
            attempt=0
            rc=1
            while [ "$rc" -ne 0 ] && [ "$attempt" -lt 3 ]; do
                attempt=$((attempt + 1))
                [ "$attempt" -gt 1 ] && sleep 2
                copy_err="$(ditto "$p" "$dest" 2>&1)"
                rc=$?
                if [ "$rc" -ne 0 ]; then
                    # without extended attributes, ACLs and resource forks
                    copy_err="$(ditto --noextattr --noacl --norsrc --noqtn "$p" "$dest" 2>&1)"
                    rc=$?
                fi
                # The system metadata file of a container is protected and never needed in a backup.
                real_err="$(printf '%s\n' "$copy_err" | grep -v 'containermanagerd.metadata.plist' | grep .)"
                [ -z "$real_err" ] && rc=0
            done
            spin_stop
            if [ "$rc" -eq 0 ]; then
                ok "$p"
                COPIED=$((COPIED + 1))
            else
                fail "$(tx "Cannot copy" "Не удалось скопировать") $p"
                printf '%s\n' "$real_err" >> "$BACKUP/backup-errors.log"
                # keep the end of the line: the reason comes last
                printf '%s\n' "$real_err" | head -3 | while IFS= read -r line; do
                    info "  $(printf '%s' "$line" | awk '{ if (length($0) > 100) print "..." substr($0, length($0) - 96); else print }')"
                done
                COPY_FAILED=$((COPY_FAILED + 1))
            fi
        fi
    done <<EOF
$PERSONAL
EOF
    chown -R "$TARGET_USER" "$BACKUP"
    if [ "$COPIED" -gt 0 ]; then
        info "$(tx "Backup stored in" "Копия сохранена в") ${MAGENTA}${BACKUP}${RESET}"
        [ -f "$BACKUP/backup-errors.log" ] && info "$(tx "Full error log:" "Полный журнал ошибок:") ${MAGENTA}${BACKUP}/backup-errors.log${RESET}"
    else
        rmdir "$BACKUP" 2>/dev/null
        if [ "$COPY_FAILED" -eq 0 ]; then
            info "$(tx "No Outlook data found, backup not needed." "Данные Outlook не найдены, копия не нужна.")"
        fi
    fi
    if [ "$COPY_FAILED" -gt 0 ]; then
        warn "$(tx "Backup is incomplete: some Outlook data could not be copied (reasons above)." "Резервная копия неполная: часть данных Outlook скопировать не удалось (причины выше).")"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------- removal
# Also used in scan mode (MODE=scan) to find out what exists before asking questions.
remove_all()
{
step "$(tx "Applications" "Приложения")"
delete "/Applications/Microsoft Office 2011"
for a in Communicator Messenger Outlook Excel OneNote PowerPoint Word; do
    delete "/Applications/Microsoft $a.app"
done

step "$(tx "Preferences and helpers" "Настройки и вспомогательные службы")"
deleteids "$USER_HOME/Library/Preferences" "$OFFICE_IDS"
deleteids "$USER_HOME/Library/Preferences/ByHost" "$OFFICE_IDS"
deleteids "/Library/Preferences" "$OFFICE_IDS"
delete "$USER_HOME/Library/Preferences/Microsoft/Office 2011"
delete /Library/LaunchDaemons/com.microsoft.office.licensing.helper.plist
delete /Library/LaunchDaemons/com.microsoft.office.licensingV2.helper.plist
delete /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist
delete /Library/PrivilegedHelperTools/com.microsoft.office.licensing.helper
delete /Library/PrivilegedHelperTools/com.microsoft.office.licensingV2.helper
delete /Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper
delete /Library/LaunchAgents/com.microsoft.update.agent.plist
delete /Library/Preferences/com.microsoft.office.licensing.plist
delete /Library/Preferences/com.microsoft.office.licensingV2.plist

step "$(tx "Containers" "Контейнеры")"
for c in errorreporting Excel netlib.shipassertprocess Office.setupassistant \
         Office365ServiceV2 Powerpoint RMS-XPCService Word onenote.mac; do
    delete "$USER_HOME/Library/Containers/com.microsoft.$c"
done
for g in UBF8T346G9.ms UBF8T346G9.OfficeOsfWebHost; do
    delete "$USER_HOME/Library/Group Containers/$g"
done

step "Application Support, $(tx "caches, logs" "кэши, логи")"
delete "/Library/Application Support/Microsoft/MAU2.0"
delete "/Library/Application Support/Microsoft/MERP2.0"
delete "/Library/Application Support/Microsoft/Office"
delete "$USER_HOME/Library/Application Support/Microsoft/Office"
for app in "Microsoft Communicator" "Microsoft Messenger" "Microsoft Outlook" \
           "Microsoft Excel" "Microsoft OneNote" "Microsoft PowerPoint" "Microsoft Word"; do
    deletefiles "$USER_HOME/Library/Application Support/CrashReporter/$app"
    deletefiles "$USER_HOME/Library/Logs/DiagnosticReports/$app"
    deletefiles "/Library/Logs/DiagnosticReports/$app"
done
deleteids "$USER_HOME/Library/Saved Application State" "$OFFICE_IDS"
deleteids "$USER_HOME/Library/Caches" "$OFFICE_IDS"
delete "$USER_HOME/Library/Caches/Microsoft Office"

step "$(tx "Automator, receipts, fonts" "Automator, чеки установки, шрифты")"
while IFS= read -r action; do
    [ -n "$action" ] && delete "/Library/Automator/$action"
done <<'AUTOMATOR'
Add Attachments to Outlook Messages.action
Add Content to Word Documents.action
Add Document Properties Page to Word Documents.action
Add New Sheet to Workbooks.action
Add Table of Contents to Word Documents.action
Add Watermark to Word Documents.action
Apply Animation to PowerPoint Slide Parts.action
Apply Font Format Settings to Word Documents.action
AutoFormat Data in Excel Workbooks.action
Bring Word Documents to Front.action
Close Excel Workbooks.action
Close Outlook Items.action
Close PowerPoint Presentations.action
Close Word Documents.action
Combine Excel Files.action
Combine PowerPoint Presentations.action
Combine Word Documents.action
Compare Word Documents.action
Convert Format of Excel Files.action
Convert Format of PowerPoint Presentations.action
Convert Format of Word Documents.action
Convert PowerPoint Presentations to Movies.action
Convert Word Content Object to Text Object.caction
Copy Excel Workbook Content to the Clipboard.action
Copy PowerPoint Slides to the Clipboard.action
Copy Word Document Content to the Clipboard.action
Create List from Data in Workbook.action
Create New Excel Workbook.action
Create New Outlook Mail Message.action
Create New PowerPoint Presentation.action
Create New Word Document.action
Create PowerPoint Picture Slide Shows.action
Create Table from Data in Workbook.action
Delete Outlook Items.action
Find and Replace Text in Word Documents.action
Flag Word Documents for Follow Up.action
Forward Outlook Mail Messages.action
Get Content from Word Documents.action
Get Images from PowerPoint Slides.action
Get Images from Word Documents.action
Get Parent Presentations of Slides.action
Get Parent Workbooks.action
Get Selected Content from Excel Workbooks.action
Get Selected Content from Word Documents.action
Get Selected Outlook Items.action
Get Selected Text from Outlook Items.action
Get Text From Outlook Mail Messages.action
Get Text from Word Documents.action
Import Text Files to Excel Workbook.action
Insert Captions into Word Documents.action
Insert Content into Outlook Mail Messages.action
Insert Content into Word Documents.action
Insert New PowerPoint Slides.action
Mark Outlook Mail Message as a To Do Item.action
Office.definition
Open Excel Workbooks.action
Open Outlook Items.action
Open PowerPoint Presentations.action
Open Word Documents.action
Paste Clipboard Content into Excel Workbooks.action
Paste Clipboard Content into Outlook Items.action
Paste Clipboard Content into PowerPoint Presentations.action
Paste Clipboard Content into Word Documents.action
Play PowerPoint Slide Shows.action
Print Excel Workbooks.action
Print Outlook Messages.action
Print PowerPoint Presentations.action
Print Word Documents.action
Protect Word Documents.action
Quit Excel.action
Quit Outlook.action
Quit PowerPoint.action
Quit Word.action
Reply to Outlook Mail Messages.action
Save Excel Workbooks.action
Save Outlook Draft Messages.action
Save Outlook Items as Files.action
Save Outlook Messages as Files.action
Save PowerPoint Presentations.action
Save Word Documents.action
Search Outlook Items.action
Select Cells in Excel Workbooks.action
Select PowerPoint Slides.action
Send Outgoing Outlook Mail Messages.action
Set Category of Outlook Items.action
Set Document Settings.action
Set Excel Workbook Properties.action
Set Footer for PowerPoint Slides.action
Set Outlook Contact Properties.action
Set PowerPoint Slide Layout.action
Set PowerPoint Slide Transition Settings.action
Set Security Options for Word Documents.action
Set Text Case in Word Documents.action
Set Word Document Properties.action
Sort Data in Excel Workbooks.action
AUTOMATOR
delete /Library/Automator/Office.definition
deletefiles /Library/Receipts/Office2011_
deletefiles /Library/Receipts/Office2016_
deletefiles /Library/Receipts/Office2019_
deletefiles /private/var/db/receipts/com.microsoft.office
forget_receipts
delete /Library/Fonts/Microsoft
deletefiles "/Library/Internet Plug-Ins/SharePoint"

step "OneDrive"
delete /Applications/OneDrive.app
delete /Library/LaunchDaemons/com.microsoft.onedriveupdaterdaemon.plist
delete "$USER_HOME/Library/Containers/com.microsoft.onedrive.findersync"
for g in UBF8T346G9.OfficeOneDriveSyncIntegration UBF8T346G9.OneDriveStandaloneSuite; do
    delete "$USER_HOME/Library/Group Containers/$g"
done
deleteids "$USER_HOME/Library/Preferences" "$ONEDRIVE_IDS"
deleteids "/Library/Preferences" "$ONEDRIVE_IDS"
deleteids "$USER_HOME/Library/Caches" "$ONEDRIVE_IDS"
deletefiles "$USER_HOME/Library/Application Support/CrashReporter/OneDrive"
deletefiles "$USER_HOME/Library/Logs/DiagnosticReports/OneDrive"
deletefiles "/Library/Logs/DiagnosticReports/OneDrive"
delete "$USER_HOME/Library/Cookies/com.microsoft.onedrive.binarycookies"
delete "$USER_HOME/Library/Cookies/com.microsoft.onedriveupdater.binarycookies"

remove_dock_icons

if [ "$MODE" = "scan" ] || [ "$CLEAN_PROFILE" -eq 1 ]; then
    step "$(tx "Outlook data" "Данные Outlook")"
    while IFS= read -r p; do
        delete "$p"
    done <<EOF
$PERSONAL
EOF
fi
step_end
}

# ---------------------------------------------------------------- keychain
# Runs as the real user (the keychain belongs to the user, not to root).
# Only metadata is listed, passwords are never read.
keychain_scan()
{
    LIST="$(mktemp)"
    RAW="$(mktemp)"
    as_user security dump-keychain >"$RAW" 2>/dev/null
    KC_RC=$?
    awk '
        function val(line, key,   m) {
            if (match(line, "\"" key "\"<[a-z]+>=\"")) {
                m = substr(line, RSTART + RLENGTH)
                sub(/"[^"]*$/, "", m)
                return m
            }
            return ""
        }
        function flush() {
            if (class == "") return
            name = svce svr labl
            low = tolower(name)
            if (low ~ /microsoft|adal|msal|oneauth|office|onedrive/ && low !~ /edge|teams|remote desktop/)
                printf "%s|%s|%s|%s|%s\n", class, svce, acct, svr, labl
            class = svce = acct = svr = labl = ""
        }
        /^keychain:/ { flush() }
        /^class: "genp"/ { class = "genp" }
        /^class: "inet"/ { class = "inet" }
        /"svce"</ { svce = val($0, "svce") }
        /"acct"</ { acct = val($0, "acct") }
        /"srvr"</ { svr = val($0, "srvr") }
        /"labl"</ { labl = val($0, "labl") }
        END { flush() }
    ' "$RAW" | sort -u > "$LIST"
    rm -f "$RAW"
    KC_COUNT="$(wc -l < "$LIST" | tr -d ' ')"
}

keychain_cleanup()
{
    title "$(tx "Keychain" "Связка ключей")"
    info "$(tx "Passwords are not read. macOS may ask you to allow the removal." "Пароли не читаются. macOS может запросить разрешение на удаление.")"
    while IFS="|" read -r class svce acct svr labl; do
        if [ "$class" = "genp" ]; then
            desc="$(tx "password: service" "пароль: служба")='$svce' $(tx "account" "учётная запись")='$acct' $(tx "label" "метка")='$labl'"
        else
            desc="$(tx "internet password: server" "интернет-пароль: сервер")='$svr' $(tx "account" "учётная запись")='$acct' $(tx "label" "метка")='$labl'"
        fi
        if ask "$(tx "Delete this keychain entry?" "Удалить эту запись связки ключей?")" n "$desc"; then
            if [ "$class" = "genp" ]; then
                as_user security delete-generic-password -s "$svce" ${acct:+-a "$acct"} >/dev/null 2>&1
            else
                as_user security delete-internet-password -s "$svr" ${acct:+-a "$acct"} >/dev/null 2>&1
            fi
            if [ $? -eq 0 ]; then
                ok "$(tx "Deleted" "Удалено")"
                REMOVED=$((REMOVED + 1))
            else
                fail "$(tx "Not deleted (cancelled or no access)" "Не удалено (отменено или нет доступа)")"
            fi
        fi
    done < "$LIST"
    rm -f "$LIST"
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
# it: open the Full Disk Access pane, wait, check again. Asked once, before the scan,
# so the separate "access data of other apps" prompts do not appear later.
# Restarting the terminal is not required: choose "Later" if macOS offers it.
ensure_disk_access()
{
    can_read_tcc && return 0
    app="$(terminal_app_name)"
    title "$(tx "Disk access for $app" "Доступ к диску для $app")"
    warn "$(tx "To find all Office leftovers macOS needs Full Disk Access for $app." "Чтобы найти все следы Office, macOS требуется «Полный доступ к диску» для $app.")"
    info "$(tx "Without it macOS hides the contents of app folders, asks for access to each app's data separately and some data cannot be found or removed." "Без него macOS скрывает содержимое папок приложений, отдельно спрашивает доступ к данным каждого приложения, а часть данных не найти и не удалить.")"
    if ask "$(tx "Open System Settings and grant access now?" "Открыть Системные настройки и выдать доступ сейчас?")" y; then
        as_user open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" >/dev/null 2>&1
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
    "$(tx "macOS will ask for access to app data separately, part of the data may not be removed or backed up." "macOS будет отдельно спрашивать доступ к данным приложений, часть данных может не удалиться и не попасть в резервную копию.")"; then
        NO_FDA=1
        return 0
    fi
    printf '\n'
    info "$(tx "Stopped. Grant Full Disk Access to $app and run the script again." "Остановлено. Выдайте $app «Полный доступ к диску» и запустите скрипт снова.")"
    exit 0
}

# ---------------------------------------------------------------- access retry
# macOS protects other apps' data (TCC): Terminal may need the user's permission.
retry_failed()
{
    attempt=0
    while [ -n "$FAILED" ] && [ "$attempt" -lt 3 ]; do
        attempt=$((attempt + 1))
        count="$(printf '%s\n' "$FAILED" | grep -c .)"
        title "$(tx "Access to some items was denied" "Доступ к части элементов не получен")"
        info "$(tx "Items not removed: $count." "Не удалено элементов: $count.")"
        if [ "$attempt" -eq 1 ]; then
            info "$(tx "If macOS showed 'Terminal wants to access data of other apps', click Allow." "Если macOS показала окно «Терминал запрашивает доступ к данным других приложений», нажмите «Разрешить».")"
        else
            info "$(tx "Grant Full Disk Access: System Settings > Privacy & Security > Full Disk Access > enable Terminal." "Выдайте полный доступ к диску: Системные настройки > Конфиденциальность и безопасность > Полный доступ к диску > включите Терминал.")"
            info "$(tx "If macOS offers 'Quit & Reopen', choose 'Later': restarting is not needed." "Если macOS предложит «Завершить и открыть снова», выберите «Позже»: перезапуск не нужен.")"
            if ask "$(tx "Open the Full Disk Access settings now?" "Открыть настройки полного доступа к диску?")" y; then
                as_user open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" >/dev/null 2>&1
            fi
        fi
        ask "$(tx "Try to remove these items again?" "Повторить удаление этих элементов?")" y || return 0
        pending="$FAILED"
        FAILED=""
        while IFS= read -r p; do
            [ -n "$p" ] && delete "$p"
        done <<EOF
$pending
EOF
    done
}

# ---------------------------------------------------------------- main
# Cleanup of temporary files on exit
trap 'spin_stop; [ -n "${LIST:-}" ] && rm -f "$LIST"' EXIT

[ -t 1 ] && clear
title "$(tx "Microsoft Office for Mac uninstaller" "Удаление Microsoft Office для Mac")"
info "$(tx "Versions: 2011 / 2016 / 2019 / 2021 / 2024 / 365" "Версии: 2011 / 2016 / 2019 / 2021 / 2024 / 365")"
info "$(tx "User" "Пользователь"): $TARGET_USER"
info "$(tx "Home" "Домашняя папка"): $USER_HOME"
info "$(tx "Language" "Язык"): $LANG_UI   $(tx "Script version" "Версия скрипта"): $SCRIPT_VERSION"



# ---- 1. check what exists before asking anything
# Running Office apps lock their files and recreate settings on exit: ask to close them first.
RUNNING=""
for proc in "Microsoft Word" "Microsoft Excel" "Microsoft PowerPoint" "Microsoft Outlook" "Microsoft OneNote"; do
    if pgrep -x "$proc" >/dev/null 2>&1; then
        RUNNING="$RUNNING
$proc"
    fi
done
RUNNING="$(printf '%s\n' "$RUNNING" | grep .)"
if [ -n "$RUNNING" ]; then
    title "$(tx "Office applications are running" "Запущены приложения Office")"
    printf '%s\n' "$RUNNING" | while IFS= read -r proc; do
        warn "$proc"
    done
    info "$(tx "Quit them (Cmd+Q), save your documents, and run the script again." "Закройте их (Cmd+Q), сохраните документы и запустите скрипт повторно.")"
    printf '\n'
    exit 1
fi

# Full Disk Access first: without it macOS hides the contents of app containers and the
# scan cannot find all leftovers.
ensure_disk_access
printf '\n'
if [ "$NO_FDA" -eq 1 ]; then
    info "$(tx "macOS may ask: 'Terminal wants to access data of other apps'. Click Allow: nothing is removed at this step." "macOS может спросить: «Терминал запрашивает доступ к данным других приложений». Нажмите «Разрешить»: на этом шаге ничего не удаляется.")"
fi
spin_start "$(tx "Checking what is installed..." "Проверяем, что есть на компьютере...")"
MODE=scan
remove_all
MODE=run
while IFS= read -r p; do
    [ -e "$p" ] && FOUND_PERSONAL=$((FOUND_PERSONAL + 1))
done <<EOF
$PERSONAL
EOF
keychain_scan
spin_stop

title "$(tx "Check result" "Результат проверки")"
info "$(tx "System components found" "Найдено системных компонентов"): $FOUND_SYSTEM"
info "$(tx "Items in the user profile" "Элементов в профиле пользователя"): $FOUND_PROFILE ($(tx "Outlook data" "данные Outlook"): $FOUND_PERSONAL)"
if [ "$KC_RC" -eq 0 ]; then
    info "$(tx "Keychain entries" "Записей в связке ключей"): $KC_COUNT"
else
    info "$(tx "Keychain entries: could not check (locked or no graphical session)" "Записи в связке ключей: проверить не удалось (связка заблокирована или нет графической сессии)")"
fi

if [ "$FOUND_SYSTEM" -eq 0 ] && [ "$FOUND_PROFILE" -eq 0 ] && [ "$KC_COUNT" -eq 0 ] && [ "$KC_RC" -eq 0 ]; then
    printf '\n%s%s%s%s\n\n' "$BOLD" "$GREEN" "$(tx "No traces of Microsoft Office found, nothing to remove." "Следов Microsoft Office не найдено, удалять нечего.")" "$RESET"
    exit 0
fi

# ---- 2. questions, only about what was found
DO_BACKUP=0
if [ "$FOUND_PROFILE" -gt 0 ] && ask "$(tx "Remove the user profile data of Office?" "Удалить данные Office из пользовательского профиля?")" n \
"$(tx "Found: $FOUND_PROFILE item(s) in $USER_HOME/Library (settings, containers, caches, local Outlook data).
Without removing them Office leftovers may stay in your profile." "Найдено: $FOUND_PROFILE элемент(ов) в $USER_HOME/Library (настройки, контейнеры, кэши, локальные данные Outlook).
Если их не удалять, в профиле могут остаться следы Office.")"; then
    CLEAN_PROFILE=1
    if [ "$FOUND_PERSONAL" -gt 0 ] && ask "$(tx "Save a backup copy of Outlook data to the Desktop first?" "Сохранить резервную копию данных Outlook на Рабочий стол?")" y \
    "$(tx "Local mail archives cannot be restored after removal." "Локальные почтовые архивы после удаления не восстановить.")"; then
        DO_BACKUP=1
    fi
fi

if [ "$FOUND_SYSTEM" -gt 0 ] && ask "$(tx "Remove Microsoft Office and all other components?" "Удалить Microsoft Office и все остальные компоненты?")" y \
"$(tx "Found: $FOUND_SYSTEM component(s): applications, settings and licensing helpers, containers,
Application Support, caches and logs, Automator actions, receipts, fonts and OneDrive." "Найдено компонентов: $FOUND_SYSTEM: приложения, настройки и службы лицензирования, контейнеры,
Application Support, кэши и логи, действия Automator, чеки установки, шрифты и OneDrive.")"; then
    DO_SYSTEM=1
fi

# ---- 3. removal
if [ "$CLEAN_PROFILE" -eq 1 ] || [ "$DO_SYSTEM" -eq 1 ]; then
    if [ "$DO_BACKUP" -eq 1 ] && ! do_backup; then
        if ! ask "$(tx "Remove Outlook data without a complete backup?" "Удалить данные Outlook без полной резервной копии?")" n \
        "$(tx "Check the reasons above (Full Disk Access for Terminal, restart Terminal) and run the script again." "Проверьте причины выше (полный доступ к диску для Terminal, перезапуск Terminal) и запустите скрипт снова.")"; then
            PROTECT_PERSONAL=1
            info "$(tx "Outlook data will be kept." "Данные Outlook будут сохранены.")"
        fi
    fi
    if [ "$CLEAN_PROFILE" -eq 1 ] && [ "$NO_FDA" -eq 1 ]; then
        printf '\n'
        warn "$(tx "macOS may show: 'Terminal wants to access data of other apps'. Click Allow, otherwise app containers cannot be removed." "macOS может показать окно «Терминал запрашивает доступ к данным других приложений». Нажмите «Разрешить», иначе контейнеры приложений не удалятся.")"
    fi
    [ "$DO_SYSTEM" -eq 1 ] && stop_services
    remove_all
    retry_failed
fi
if [ "$FOUND_PROFILE" -gt 0 ] && [ "$CLEAN_PROFILE" -eq 0 ]; then
    printf '\n'
    warn "$(tx "User profile was not touched (settings, caches, Outlook data)." "Пользовательский профиль не затронут (настройки, кэши, данные Outlook).")"
fi

# ---- 4. keychain
KEYCHAIN_DONE=0
if [ "$KC_COUNT" -gt 0 ] && ask "$(tx "Delete Microsoft account / Office entries from the keychain?" "Удалить из связки ключей записи аккаунта Microsoft / Office?")" n \
"$(tx "Found: $KC_COUNT entry(ies). They are shown one by one, you confirm each deletion." "Найдено записей: $KC_COUNT. Они показываются по одной, каждое удаление подтверждается отдельно.")"; then
    keychain_cleanup
    KEYCHAIN_DONE=1
fi

# ---------------------------------------------------------------- summary
if [ "$REMOVED" -gt 0 ]; then
    printf '\n%s%s%s %s%s\n' "$BOLD" "$GREEN" "$(tx "Done. Items removed:" "Готово. Удалено элементов:")" "$REMOVED" "$RESET"
else
    printf '\n%s\n' "$(tx "Nothing was removed." "Ничего не удалено.")"
fi

if [ "$REMOVED" -gt 0 ] || [ "$KEYCHAIN_DONE" -eq 0 ]; then
    title "$(tx "Finish the uninstall manually" "Завершите удаление вручную")"
    if [ "$KEYCHAIN_DONE" -eq 0 ] && { [ "$KC_COUNT" -gt 0 ] || [ "$KC_RC" -ne 0 ]; }; then
        info "$(tx "1. Open Keychain Access and remove the entries \"Microsoft Office Identities Cache 2\" and \"Microsoft Office Identities Settings 2\"." "1. Откройте «Связку ключей» и удалите записи «Microsoft Office Identities Cache 2» и «Microsoft Office Identities Settings 2».")"
        info "$(tx "   Search the keychain for \"ADAL\" and remove all matching entries." "   Найдите все записи со словом «ADAL» и удалите их.")"
    fi
    if [ "$REMOVED" -gt 0 ]; then
        if [ "$DOCK_REMOVED" -eq 0 ]; then
            info "$(tx "- Remove Office icons from the Dock (right-click > Options > Remove from Dock)." "- Уберите значки Office из Dock (правый клик > Параметры > Удалить из Dock).")"
        fi
        info "$(tx "- Restarting the computer is recommended, especially before reinstalling Office (not required otherwise)." "- Перезагрузка рекомендуется, особенно перед повторной установкой Office (в остальных случаях необязательна).")"
    fi
fi
# Full Disk Access is a broad permission: suggest taking it back, but only if this run asked for it.
if [ "$FDA_GRANTED_NOW" -eq 1 ]; then
    title "$(tx "Disk access" "Доступ к диску")"
    info "$(tx "Full Disk Access for $(terminal_app_name) was needed only while the script ran." "Доступ к диску для $(terminal_app_name) был нужен только на время работы скрипта.")"
    info "$(tx "You can turn it off: System Settings > Privacy & Security > Full Disk Access > switch off $(terminal_app_name)." "Его можно отключить: Системные настройки > Конфиденциальность и безопасность > Полный доступ к диску > выключите переключатель рядом с $(terminal_app_name).")"
fi
printf '\n'

#!/bin/sh

# Author : jim ye
# Interactive uninstaller for Microsoft Office for Mac 2011/2016/2019/2021/2024/365
#
# Usage:  sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
# No options: the script asks everything interactively.
#
# Reference:
# 1.https://support.microsoft.com/en-us/kb/2398768
# 2.https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

SCRIPT_VERSION="2026-10-07 ui+lang"
REMOVED=0
CLEAN_PROFILE=0

# ---------------------------------------------------------------- colors
ESC="$(printf '\033')"
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    CYAN="${ESC}[36m"; BOLD="${ESC}[1m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"
    RED="${ESC}[31m"; DETAIL="${ESC}[90m"; MAGENTA="${ESC}[35m"; RESET="${ESC}[0m"
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

STEP_OPEN=0
STEP_START=0
step_end()
{
    if [ "$STEP_OPEN" -eq 1 ] && [ "$REMOVED" -eq "$STEP_START" ]; then
        info "$(tx "nothing found" "ничего не найдено")"
    fi
    STEP_OPEN=0
}
step() { step_end; title "$1"; STEP_OPEN=1; STEP_START=$REMOVED; }

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
    printf '%s%s%s\n' "$YELLOW" "$(tx "Run as root, e.g.:" "Запустите от имени администратора, например:")" "$RESET"
    printf '  sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"\n'
    exit 1
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
        printf '  %s›%s %s%s%s ' "$YELLOW" "$RESET" "$DETAIL" "$hint" "$RESET"
        read answer < /dev/tty || exit 1
        case "$answer" in
            "") [ "$2" = "y" ]; return ;;
            y|Y|yes|YES|д|Д|да|Да|ДА) return 0 ;;
            n|N|no|NO|н|Н|нет|Нет|НЕТ) return 1 ;;
        esac
    done
}

# ---------------------------------------------------------------- delete helpers
delete()
{
    if [ "$CLEAN_PROFILE" -eq 0 ]; then
        case "$1" in "$USER_HOME"/*) return ;; esac
    fi
    if [ -e "$1" ] || [ -L "$1" ]; then
        spin_start "$(tx "Removing" "Удаление") $1"
        rm -rf "$1"
        rc=$?
        spin_stop
        if [ "$rc" -eq 0 ]; then
            ok "$1"
            REMOVED=$((REMOVED + 1))
        else
            fail "$(tx "Cannot remove" "Не удалось удалить") $1"
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
com.microsoft.Communicator com.microsoft.openxml"
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

# ---------------------------------------------------------------- start
[ -t 1 ] && clear
title "$(tx "Microsoft Office for Mac uninstaller" "Удаление Microsoft Office для Mac")"
info "$(tx "Versions: 2011 / 2016 / 2019 / 2021 / 2024 / 365" "Версии: 2011 / 2016 / 2019 / 2021 / 2024 / 365")"
info "$(tx "User" "Пользователь"): $TARGET_USER"
info "$(tx "Home" "Домашняя папка"): $USER_HOME"
info "$(tx "Language" "Язык"): $LANG_UI   $(tx "Script version" "Версия скрипта"): $SCRIPT_VERSION"

if pgrep -x -f "Microsoft (Word|Excel|PowerPoint|Outlook|OneNote)" >/dev/null 2>&1; then
    printf '\n'
    warn "$(tx "Office applications are still running. Please quit them first." "Приложения Office ещё запущены. Сначала закройте их.")"
    ask "$(tx "Continue anyway?" "Всё равно продолжить?")" n || exit 1
fi

# ---------------------------------------------------------------- questions
DO_BACKUP=0
if ask "$(tx "Remove the user profile data of Office?" "Удалить данные Office из пользовательского профиля?")" n \
"$(tx "Settings, containers, caches and local Outlook data (mail archives) in $USER_HOME/Library.
Without it Office leftovers may stay in your profile." "Настройки, контейнеры, кэши и локальные данные Outlook (почтовые архивы) в $USER_HOME/Library.
Без этого в профиле могут остаться следы Office.")"; then
    CLEAN_PROFILE=1
    if ask "$(tx "Save a backup copy of Outlook data to the Desktop first?" "Сохранить резервную копию данных Outlook на Рабочий стол?")" y \
    "$(tx "Local mail archives cannot be restored after removal." "Локальные почтовые архивы после удаления не восстановить.")"; then
        DO_BACKUP=1
    fi
fi

if ! ask "$(tx "Remove Microsoft Office and all other components?" "Удалить Microsoft Office и все остальные компоненты?")" y \
"$(tx "Applications, settings and licensing helpers, containers, Application Support,
caches and logs, Automator actions, receipts, fonts and OneDrive." "Приложения, настройки и службы лицензирования, контейнеры, Application Support,
кэши и логи, действия Automator, чеки установки, шрифты и OneDrive.")"; then
    printf '\n'
    info "$(tx "Cancelled, nothing was removed." "Отменено, ничего не удалено.")"
    exit 0
fi

# ---------------------------------------------------------------- backup
if [ "$DO_BACKUP" -eq 1 ]; then
    title "$(tx "Backup" "Резервная копия")"
    BACKUP="$USER_HOME/Desktop/OfficeUninstall-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    COPIED=0
    while IFS= read -r p; do
        if [ -e "$p" ]; then
            spin_start "$(tx "Copying" "Копирование") $p"
            ditto "$p" "$BACKUP/$(basename "$p")" 2>/dev/null
            rc=$?
            spin_stop
            if [ "$rc" -eq 0 ]; then
                ok "$p"
                COPIED=$((COPIED + 1))
            else
                fail "$(tx "Cannot copy" "Не удалось скопировать") $p"
            fi
        fi
    done <<EOF
$PERSONAL
EOF
    chown -R "$TARGET_USER" "$BACKUP"
    if [ "$COPIED" -gt 0 ]; then
        info "$(tx "Backup stored in" "Копия сохранена в") ${MAGENTA}${BACKUP}${RESET}"
    else
        rmdir "$BACKUP" 2>/dev/null
        info "$(tx "No Outlook data found, backup not needed." "Данные Outlook не найдены, копия не нужна.")"
    fi
fi

# ---------------------------------------------------------------- removal
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
deleteids "$USER_HOME/Library/Caches" "$ONEDRIVE_IDS"
deletefiles "$USER_HOME/Library/Application Support/CrashReporter/OneDrive"
deletefiles "$USER_HOME/Library/Logs/DiagnosticReports/OneDrive"
deletefiles "/Library/Logs/DiagnosticReports/OneDrive"
delete "$USER_HOME/Library/Cookies/com.microsoft.onedrive.binarycookies"
delete "$USER_HOME/Library/Cookies/com.microsoft.onedriveupdater.binarycookies"

if [ "$CLEAN_PROFILE" -eq 1 ]; then
    step "$(tx "Outlook data" "Данные Outlook")"
    while IFS= read -r p; do
        delete "$p"
    done <<EOF
$PERSONAL
EOF
fi
step_end

if [ "$CLEAN_PROFILE" -eq 0 ]; then
    printf '\n'
    warn "$(tx "User profile was not touched (settings, caches, Outlook data)." "Пользовательский профиль не затронут (настройки, кэши, данные Outlook).")"
fi

# ---------------------------------------------------------------- keychain
# Runs as the real user (the keychain belongs to the user, not to root).
# Only metadata is listed, passwords are never read.
keychain_cleanup()
{
    title "$(tx "Keychain" "Связка ключей")"
    LIST="$(mktemp)"
    spin_start "$(tx "Searching the keychain..." "Поиск в связке ключей...")"
    as_user security dump-keychain 2>/dev/null | awk '
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
    ' | sort -u > "$LIST"
    spin_stop
    if [ ! -s "$LIST" ]; then
        info "$(tx "No Microsoft/Office entries found." "Записи Microsoft/Office не найдены.")"
        rm -f "$LIST"
        return 0
    fi
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

KEYCHAIN_DONE=0
if ask "$(tx "Search the keychain for Microsoft account / Office entries?" "Поискать в связке ключей записи аккаунта Microsoft / Office?")" n \
"$(tx "Entries are listed one by one, you confirm each deletion." "Записи показываются по одной, каждое удаление подтверждается отдельно.")"; then
    keychain_cleanup
    KEYCHAIN_DONE=1
fi

# ---------------------------------------------------------------- summary
printf '\n%s%s%s %s%s%s\n' "$BOLD" "$GREEN" "$(tx "Done. Items removed:" "Готово. Удалено элементов:")" "$REMOVED" "" "$RESET"

title "$(tx "Finish the uninstall manually" "Завершите удаление вручную")"
if [ "$KEYCHAIN_DONE" -eq 0 ]; then
    info "$(tx "1. Open Keychain Access and remove the entries \"Microsoft Office Identities Cache 2\" and \"Microsoft Office Identities Settings 2\"." "1. Откройте «Связку ключей» и удалите записи «Microsoft Office Identities Cache 2» и «Microsoft Office Identities Settings 2».")"
    info "$(tx "   Search the keychain for \"ADAL\" and remove all matching entries." "   Найдите все записи со словом «ADAL» и удалите их.")"
fi
info "$(tx "- Remove Office icons from the Dock (right-click > Options > Remove from Dock)." "- Уберите значки Office из Dock (правый клик > Параметры > Удалить из Dock).")"
info "$(tx "- Restart the computer." "- Перезагрузите компьютер.")"
printf '\n'

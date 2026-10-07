#!/bin/sh

# Author : jim ye
# Interactive uninstaller for Microsoft Office for Mac 2011/2016/2019/2021/2024/365
#
# Usage:  sudo sh office_uninstaller.sh
# No options: the script asks everything interactively (dry run, profile, each category).
#
# Reference:
# 1.https://support.microsoft.com/en-us/kb/2398768
# 2.https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

DRY_RUN=0
SKIP_PROFILE=0

# ---------------------------------------------------------------- language
# Messages are shown in Russian when the macOS language is Russian, else in English.
LANG_UI=en
detect_lang()   # detect_lang [user]
{
    if [ -n "$1" ] && [ "$(id -u)" -eq 0 ]; then
        first="$(sudo -u "$1" defaults read -g AppleLanguages 2>/dev/null | sed -n '2p')"
    else
        first="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2p')"
    fi
    [ -n "$first" ] || first="${LC_ALL:-${LANG:-}}"
    case "$first" in
        *ru*|*RU*) LANG_UI=ru ;;
        *) LANG_UI=en ;;
    esac
}
tx() { if [ "$LANG_UI" = "ru" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
detect_lang

# ---------------------------------------------------------------- root / user
if [ "$(id -u)" -ne 0 ]; then
    echo "$(tx "Run as root, e.g.:" "Запустите от имени администратора, например:")"
    echo "  sudo sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)\""
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
    echo "$(tx "Home directory of user '$TARGET_USER' not found." "Домашняя папка пользователя '$TARGET_USER' не найдена.")"
    exit 1
fi
detect_lang "$TARGET_USER"

# ---------------------------------------------------------------- helpers
# Questions are read from the terminal, so it also works with "curl | sh".
if ! [ -r /dev/tty ]; then
    echo "$(tx "No terminal available for questions." "Нет терминала для вопросов.")"
    exit 1
fi

ask()   # ask "question" default(y|n)
{
    if [ "$2" = "y" ]; then hint="[Д/н]"; else hint="[д/Н]"; fi
    [ "$LANG_UI" = "ru" ] || { if [ "$2" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi; }
    while :; do
        printf '%s %s ' "$1" "$hint"
        read answer < /dev/tty || exit 1
        case "$answer" in
            "") [ "$2" = "y" ]; return ;;
            y|Y|yes|YES|д|Д|да|Да|ДА) return 0 ;;
            n|N|no|NO|н|Н|нет|Нет|НЕТ) return 1 ;;
        esac
    done
}

REMOVED=0
delete()
{
    if [ "$SKIP_PROFILE" -eq 1 ]; then
        case "$1" in "$USER_HOME"/*) return ;; esac
    fi
    if [ -e "$1" ] || [ -L "$1" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[dry-run] $(tx "would remove" "будет удалено") $1"
        else
            rm -rf "$1" && echo "$(tx "Remove" "Удалено") $1"
        fi
        REMOVED=$((REMOVED + 1))
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

section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------- start
echo "$(tx "This will uninstall Microsoft Office for Mac 2011/2016/2019/2021/2024/365." "Будет удалён Microsoft Office для Mac 2011/2016/2019/2021/2024/365.")"
echo "$(tx "User" "Пользователь"): $TARGET_USER   $(tx "Home" "Домашняя папка"): $USER_HOME"

echo "$(tx "You can first do a dry run: it only shows what would be removed." "Можно сначала сделать пробный запуск: он только покажет, что будет удалено.")"
if ask "$(tx "Dry run (show only, delete nothing)?" "Пробный запуск (только показать, ничего не удалять)?")" n; then
    DRY_RUN=1
    echo "$(tx "DRY RUN: nothing will be deleted." "ПРОБНЫЙ ЗАПУСК: ничего не будет удалено.")"
fi

if pgrep -x -f "Microsoft (Word|Excel|PowerPoint|Outlook|OneNote)" >/dev/null 2>&1; then
    echo "$(tx "Office applications are still running. Please quit them first." "Приложения Office ещё запущены. Сначала закройте их.")"
    ask "$(tx "Continue anyway?" "Всё равно продолжить?")" n || exit 1
fi

if [ "$SKIP_PROFILE" -eq 0 ]; then
    echo "$(tx "Office also stores settings, containers and caches in your profile ($USER_HOME/Library)." "Office также хранит настройки, контейнеры и кэши в вашем профиле ($USER_HOME/Library).")"
    ask "$(tx "Clean the user profile too? (No = only system-wide files)" "Очистить также пользовательский профиль? (Нет = только системные файлы)")" n || SKIP_PROFILE=1
fi
[ "$SKIP_PROFILE" -eq 1 ] && echo "$(tx "User profile will NOT be touched." "Пользовательский профиль НЕ будет затронут.")"

ask "$(tx "Continue?" "Продолжить?")" y || exit 0

# ---------------------------------------------------------------- personal data
section "$(tx "Personal data (Outlook profile, local mail archives)" "Личные данные (профиль Outlook, локальные почтовые архивы)")"
echo "$(tx "Outlook keeps local mail ('On My Computer') in the folders below." "Outlook хранит локальную почту («На моём компьютере») в папках ниже.")"
echo "$(tx "They are NOT removed unless you say yes." "Они НЕ удаляются, если вы явно не согласитесь.")"
PERSONAL="$USER_HOME/Library/Group Containers/UBF8T346G9.Office
$USER_HOME/Library/Containers/com.microsoft.Outlook
$USER_HOME/Documents/Microsoft ~ Data
$USER_HOME/Documents/Microsoft User Data"
REMOVE_PERSONAL=0
if ask "$(tx "Remove personal Outlook data as well?" "Удалить также личные данные Outlook?")" n; then
    REMOVE_PERSONAL=1
    if ask "$(tx "Make a backup copy on the Desktop first?" "Сначала сделать резервную копию на Рабочем столе?")" y && [ "$DRY_RUN" -eq 0 ]; then
        BACKUP="$USER_HOME/Desktop/OfficeUninstall-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP"
        echo "$PERSONAL" | while IFS= read -r p; do
            [ -e "$p" ] && ditto "$p" "$BACKUP/$(basename "$p")" && echo "$(tx "Backup" "Копия") $p"
        done
        chown -R "$TARGET_USER" "$BACKUP"
        echo "$(tx "Backup stored in" "Копия сохранена в") $BACKUP"
    fi
fi
if [ "$REMOVE_PERSONAL" -eq 1 ]; then
    echo "$PERSONAL" | while IFS= read -r p; do delete "$p"; done
fi

# ---------------------------------------------------------------- categories
if ask "$(tx "1. Remove applications (Word, Excel, PowerPoint, Outlook, OneNote, Office 2011)?" "1. Удалить приложения (Word, Excel, PowerPoint, Outlook, OneNote, Office 2011)?")" y; then
    section "$(tx "Applications" "Приложения")"
    delete "/Applications/Microsoft Office 2011"
    for a in Communicator Messenger Outlook Excel OneNote PowerPoint Word; do
        delete "/Applications/Microsoft $a.app"
    done
fi

if ask "$(tx "2. Remove preferences and licensing/updater helpers?" "2. Удалить настройки и вспомогательные службы лицензирования/обновления?")" y; then
    section "$(tx "Preferences" "Настройки")"
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
fi

if ask "$(tx "3. Remove application containers (settings, templates)?" "3. Удалить контейнеры приложений (настройки, шаблоны)?")" y; then
    section "$(tx "Containers" "Контейнеры")"
    for c in errorreporting Excel netlib.shipassertprocess Office.setupassistant \
             Office365ServiceV2 Powerpoint RMS-XPCService Word onenote.mac; do
        delete "$USER_HOME/Library/Containers/com.microsoft.$c"
    done
    for g in UBF8T346G9.ms UBF8T346G9.OfficeOsfWebHost; do
        delete "$USER_HOME/Library/Group Containers/$g"
    done
    # Office group container holds the Outlook profile: only with explicit consent above
    [ "$REMOVE_PERSONAL" -eq 1 ] || echo "$(tx "Kept Outlook data" "Данные Outlook сохранены") (UBF8T346G9.Office, com.microsoft.Outlook)."
fi

if ask "$(tx "4. Remove Application Support, caches, saved state, crash logs?" "4. Удалить Application Support, кэши, сохранённые состояния, отчёты о сбоях?")" y; then
    section "$(tx "Application Support / caches / logs" "Application Support / кэши / логи")"
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
fi

if ask "$(tx "5. Remove Automator actions, receipts, fonts, SharePoint plug-in?" "5. Удалить действия Automator, чеки установки, шрифты, плагин SharePoint?")" y; then
    section "$(tx "Automator / receipts / fonts" "Automator / чеки / шрифты")"
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
fi

if ask "$(tx "6. Remove OneDrive too? (skip if you still use it)" "6. Удалить также OneDrive? (пропустите, если он вам нужен)")" n; then
    section "OneDrive"
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
fi

# ---------------------------------------------------------------- keychain
# Runs as the real user (the keychain belongs to the user, not to root).
# Only metadata is listed, passwords are never read.
as_user() { sudo -u "$TARGET_USER" "$@"; }

keychain_cleanup()
{
    section "$(tx "Keychain (Microsoft accounts and Office entries)" "Связка ключей (аккаунты Microsoft и записи Office)")"
    LIST="$(mktemp)"
    if ! as_user security dump-keychain 2>/dev/null | awk '
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
    ' | sort -u > "$LIST"; then
        echo "$(tx "Could not read the keychain (locked or no graphical session)." "Не удалось прочитать связку ключей (заблокирована или нет графической сессии).")"
        rm -f "$LIST"
        return 1
    fi
    if [ ! -s "$LIST" ]; then
        echo "$(tx "No Microsoft/Office entries found." "Записи Microsoft/Office не найдены.")"
        rm -f "$LIST"
        return 0
    fi
    echo "$(tx "Found entries (passwords are not read). macOS may ask you to allow the removal." "Найдены записи (пароли не читаются). macOS может запросить разрешение на удаление.")"
    while IFS="|" read -r class svce acct svr labl; do
        if [ "$class" = "genp" ]; then
            desc="$(tx "password: service" "пароль: служба")='$svce' $(tx "account" "учётная запись")='$acct' $(tx "label" "метка")='$labl'"
        else
            desc="$(tx "internet password: server" "интернет-пароль: сервер")='$svr' $(tx "account" "учётная запись")='$acct' $(tx "label" "метка")='$labl'"
        fi
        if ask "$(tx "Delete" "Удалить") $desc ?" n; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "[dry-run] $(tx "would delete keychain entry" "запись связки ключей была бы удалена")"
            elif [ "$class" = "genp" ]; then
                as_user security delete-generic-password -s "$svce" ${acct:+-a "$acct"} >/dev/null 2>&1 \
                    && echo "$(tx "Deleted" "Удалено")" || echo "$(tx "Not deleted (cancelled or no access)" "Не удалено (отменено или нет доступа)")"
            else
                as_user security delete-internet-password -s "$svr" ${acct:+-a "$acct"} >/dev/null 2>&1 \
                    && echo "$(tx "Deleted" "Удалено")" || echo "$(tx "Not deleted (cancelled or no access)" "Не удалено (отменено или нет доступа)")"
            fi
        fi
    done < "$LIST"
    rm -f "$LIST"
}

KEYCHAIN_DONE=0
if ask "$(tx "Search the keychain for Microsoft account / Office entries?" "Поискать в связке ключей записи аккаунта Microsoft / Office?")" n; then
    keychain_cleanup && KEYCHAIN_DONE=1
fi

# ---------------------------------------------------------------- summary
if [ "$DRY_RUN" -eq 1 ]; then
    printf '\n%s %s\n' "$(tx "Done. Items that would be removed:" "Готово. Элементов, которые были бы удалены:")" "$REMOVED"
else
    printf '\n%s %s\n' "$(tx "Done. Items removed:" "Готово. Удалено элементов:")" "$REMOVED"
fi

echo
echo "$(tx "Finish the uninstall manually:" "Завершите удаление вручную:")"
if [ "$KEYCHAIN_DONE" -eq 0 ]; then
    if [ "$LANG_UI" = "ru" ]; then
        cat <<'TXT'
1. Откройте «Связку ключей» и удалите записи
     Microsoft Office Identities Cache 2
     Microsoft Office Identities Settings 2
   Найдите все записи со словом "ADAL" и удалите их.
TXT
    else
        cat <<'TXT'
1. Open Keychain Access and remove the entries
     Microsoft Office Identities Cache 2
     Microsoft Office Identities Settings 2
   Search the keychain for "ADAL" and remove all matching entries.
TXT
    fi
fi
if [ "$LANG_UI" = "ru" ]; then
    cat <<'TXT'
- Уберите значки Office из Dock (правый клик > Параметры > Удалить из Dock).
- Перезагрузите компьютер.
TXT
else
    cat <<'TXT'
- Remove Office icons from the Dock (right-click > Options > Remove from Dock).
- Restart the computer.
TXT
fi

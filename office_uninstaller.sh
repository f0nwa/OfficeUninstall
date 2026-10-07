#!/bin/sh

# Author : jim ye
# Interactive uninstaller for Microsoft Office for Mac 2011/2016/2019/2021/2024/365
#
# Usage:  sudo sh office_uninstaller.sh [--dry-run] [--yes]
#   --dry-run  only show what would be removed, delete nothing
#   --yes      do not ask questions, remove every category except personal data
#
# Reference:
# 1.https://support.microsoft.com/en-us/kb/2398768
# 2.https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,8p' "$0" 2>/dev/null; exit 0 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- root / user
if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root:  sudo sh $0"
    exit 1
fi

# The real user, whether started via "sudo sh", "sudo su" or "sudo sh -c ..."
TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER="$(stat -f%Su /dev/console 2>/dev/null)"
fi
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    printf 'Cannot detect the login user. Enter the user name whose Office data should be removed: '
    read TARGET_USER < /dev/tty
fi
USER_HOME="$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ] || [ "$USER_HOME" = "/var/root" ]; then
    echo "Home directory of user '$TARGET_USER' not found."
    exit 1
fi

# ---------------------------------------------------------------- helpers
# Questions are read from the terminal, so it also works with "curl | sh".
if [ "$ASSUME_YES" -eq 0 ] && ! [ -r /dev/tty ]; then
    echo "No terminal available for questions. Use --yes or --dry-run."
    exit 1
fi

ask()   # ask "question" default(y|n)
{
    [ "$ASSUME_YES" -eq 1 ] && { [ "$2" = "y" ]; return; }
    if [ "$2" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
    while :; do
        printf '%s %s ' "$1" "$hint"
        read answer < /dev/tty
        case "$answer" in
            "") [ "$2" = "y" ]; return ;;
            y|Y|yes|YES) return 0 ;;
            n|N|no|NO) return 1 ;;
        esac
    done
}

REMOVED=0
delete()
{
    if [ -e "$1" ] || [ -L "$1" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[dry-run] would remove $1"
        else
            rm -rf "$1" && echo "Remove $1"
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
echo "This will uninstall Microsoft Office for Mac 2011/2016/2019/2021/2024/365."
echo "User: $TARGET_USER   Home: $USER_HOME"
[ "$DRY_RUN" -eq 1 ] && echo "DRY RUN: nothing will be deleted."

if pgrep -x -f "Microsoft (Word|Excel|PowerPoint|Outlook|OneNote)" >/dev/null 2>&1; then
    echo "Office applications are still running. Please quit them first."
    ask "Continue anyway?" n || exit 1
fi

ask "Continue?" y || exit 0

# ---------------------------------------------------------------- personal data
section "Personal data (Outlook profile, local mail archives)"
echo "Outlook keeps local mail ('On My Computer') in the folders below."
echo "They are NOT removed unless you say yes."
PERSONAL="$USER_HOME/Library/Group Containers/UBF8T346G9.Office
$USER_HOME/Library/Containers/com.microsoft.Outlook
$USER_HOME/Documents/Microsoft ~ Data
$USER_HOME/Documents/Microsoft User Data"
REMOVE_PERSONAL=0
if ask "Remove personal Outlook data as well?" n; then
    REMOVE_PERSONAL=1
    if ask "Make a backup copy on the Desktop first?" y && [ "$DRY_RUN" -eq 0 ]; then
        BACKUP="$USER_HOME/Desktop/OfficeUninstall-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP"
        echo "$PERSONAL" | while IFS= read -r p; do
            [ -e "$p" ] && ditto "$p" "$BACKUP/$(basename "$p")" && echo "Backup $p"
        done
        chown -R "$TARGET_USER" "$BACKUP"
        echo "Backup stored in $BACKUP"
    fi
fi
if [ "$REMOVE_PERSONAL" -eq 1 ]; then
    echo "$PERSONAL" | while IFS= read -r p; do delete "$p"; done
fi

# ---------------------------------------------------------------- categories
if ask "1. Remove applications (Word, Excel, PowerPoint, Outlook, OneNote, Office 2011)?" y; then
    section "Applications"
    delete "/Applications/Microsoft Office 2011"
    for a in Communicator Messenger Outlook Excel OneNote PowerPoint Word; do
        delete "/Applications/Microsoft $a.app"
    done
fi

if ask "2. Remove preferences and licensing/updater helpers?" y; then
    section "Preferences"
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

if ask "3. Remove application containers (settings, templates)?" y; then
    section "Containers"
    for c in errorreporting Excel netlib.shipassertprocess Office.setupassistant \
             Office365ServiceV2 Powerpoint RMS-XPCService Word onenote.mac; do
        delete "$USER_HOME/Library/Containers/com.microsoft.$c"
    done
    for g in UBF8T346G9.ms UBF8T346G9.OfficeOsfWebHost; do
        delete "$USER_HOME/Library/Group Containers/$g"
    done
    # Office group container holds the Outlook profile: only with explicit consent above
    [ "$REMOVE_PERSONAL" -eq 1 ] || echo "Kept Outlook data (UBF8T346G9.Office, com.microsoft.Outlook)."
fi

if ask "4. Remove Application Support, caches, saved state, crash logs?" y; then
    section "Application Support / caches / logs"
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

if ask "5. Remove Automator actions, receipts, fonts, SharePoint plug-in?" y; then
    section "Automator / receipts / fonts"
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

if ask "6. Remove OneDrive too? (skip if you still use it)" n; then
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

# ---------------------------------------------------------------- summary
printf '\nDone. %s item(s) %s.\n' "$REMOVED" "$([ "$DRY_RUN" -eq 1 ] && echo 'would be removed' || echo 'removed')"

cat <<'TXT'

Finish the uninstall manually:
1. Open Keychain Access and remove the entries
     Microsoft Office Identities Cache 2
     Microsoft Office Identities Settings 2
2. Search the keychain for "ADAL" and remove all matching entries.
3. Remove Office icons from the Dock (right-click > Options > Remove from Dock).
4. Restart the computer.
TXT

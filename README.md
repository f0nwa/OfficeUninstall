# Microsoft Office For Mac Uninstaller
This is a shell script to deep uninstall Microsoft Office for Mac 2011/2016/2019/365. 

# Usage
 1. Make sure all Office applications are closed.
 2. Download the script and read it:
```
curl -O https://raw.githubusercontent.com/f0nwa/officeuninstall/claude/admiring-tesla-itpkxw/office_uninstaller.sh
```
 3. Preview what would be removed (nothing is deleted):
```
sudo sh office_uninstaller.sh --dry-run
```
 4. Run it. The script asks before every category:
```
sudo sh office_uninstaller.sh
```

- Run it with plain `sudo`; `sudo su` is **not** needed. The script finds the real user via `SUDO_USER`, so your own `~/Library` is cleaned in both cases.
- Outlook local data (`UBF8T346G9.Office`, `com.microsoft.Outlook`) is kept unless you explicitly agree; a backup to the Desktop is offered.
- Only Office bundle ids are removed, other Microsoft apps (Edge, VS Code, Teams ...) and OneDrive (asked separately) are left alone.
- `--yes` answers the questions with defaults (personal data and OneDrive are kept).

# Reference
Microsoft not provide a offical uninstall program, but some documents about how to uninstall can be found in their website.
 1. [How to completely remove Office for Mac 2011][1]
 2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]


  [1]: https://support.microsoft.com/en-us/kb/2398768
  [2]: https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

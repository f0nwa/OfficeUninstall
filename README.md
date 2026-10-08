# Удаление Microsoft Office для Mac
[English version below](#english)

Интерактивный shell-скрипт для полного удаления Microsoft Office для Mac 2011/2016/2019/2021/2024/365.

# Использование
Скрипт запускается сразу по сети, скачивать его и указывать параметры не нужно. Закройте все приложения Office и выполните в Terminal:
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
```
В начале скрипт предупредит, что сейчас потребуется локальный пароль от вашей учётной записи macOS (при вводе символы не отображаются), и сам запросит права администратора. Запуск с `sudo sh -c "…"` тоже работает.

Скрипт сам задаёт вопросы, вам остаётся подтверждать `д` или `н` (Enter выбирает вариант по умолчанию):
 1. удалять ли данные Office из пользовательского профиля (`~/Library` и локальные данные Outlook), по умолчанию «нет»; если «да», дополнительно предлагается копия данных Outlook на Рабочий стол;
 2. общий вопрос: удалить Microsoft Office и все остальные компоненты (приложения, настройки, контейнеры, кэши, Automator, шрифты, OneDrive, а также иконки Office из Dock: закреплённые и в «недавних»);
 3. искать ли записи Microsoft/Office в связке ключей (по умолчанию «нет»): скрипт показывает найденные записи без чтения паролей и спрашивает про каждую.

Интерфейс цветной, при долгих операциях показывается анимация. Цвета отключаются переменной `NO_COLOR=1` или если вывод не в терминал.

Язык сообщений выбирается автоматически по языку macOS: русский, если система на русском, иначе английский. Отвечать можно `y`/`n` или `д`/`н`.

- `sudo su` **не нужен**. Скрипт сам определяет настоящего пользователя, поэтому результат не зависит от того, как вы получили root. Профиль (`~/Library`) по умолчанию не трогается (как раньше при `sudo su`), но вы можете согласиться на его очистку, ответив `y` на вопрос.
- Локальные данные Outlook (`UBF8T346G9.Office`, `com.microsoft.Outlook`) удаляются только вместе с профилем, если вы явно согласились на это в первом вопросе.
- Удаляются только компоненты Office и OneDrive. Другие продукты Microsoft (Edge, VS Code, Teams и др.) не затрагиваются.

# Другие решения

Ниже инструменты, которые я проверил на момент написания (октябрь 2026). Отдельного официального «удалителя» Office для Mac я не нашёл: у Microsoft есть только инструкция по ручному удалению и инструмент удаления лицензий.

| Решение | Что делает | Актуальность | Когда выбрать |
|---|---|---|---|
| [Инструкция Microsoft по полному удалению](https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0) | Ручное удаление приложений, системных файлов и папок в `~/Library` через Finder | Официальная, обновляется Microsoft | Когда нужно сверить, что удаляется, или выполнить шаги вручную |
| [Инструмент удаления лицензий Microsoft](https://support.microsoft.com/en-us/microsoft-365-activation-licensing/how-to-remove-office-license-files-on-a-mac) | Только лицензии (Microsoft 365, Office 2024 и 2021 для Mac), приложения не удаляет | Официальный, актуальный. По опыту автора проекта, на некоторых сборках не снимал лицензию Microsoft 365: тогда помогает выйти из аккаунта в приложениях Office и удалить записи Office в связке ключей перед запуском (этот скрипт умеет искать их) | Проблемы активации или конфликт лицензий без удаления Office |
| [Unlicense](https://github.com/pbowden-msft/Unlicense) | Консольный инструмент снятия лицензии Office 365/2021/2019/2016 для Mac, ключи `--All`, `--O365`, `--Volume`, `--ForceClose`, `--DetectOnly` | Неофициальный (репозиторий частного аккаунта), 43 коммита, дата последнего изменения на странице не видна | Когда лицензионный инструмент Microsoft не помог; проверьте инструмент на тестовой учётной записи |
| [Office-Reset](https://office-reset.com/changelog/) | Сброс и переустановка приложений, сброс OneAuth, чистка связки ключей и остатков OneDrive/Teams | Последняя версия 2.0 Beta 1 от 25.11.2023, заявлена поддержка до Office 16.79 и macOS Sonoma, не обновляется | Если нужен сброс отдельного приложения, а не полное удаление; на новых версиях Office и macOS работа не проверена |
| [qsor27/office-mac-uninstaller](https://github.com/qsor27/office-mac-uninstaller) | Скрипт по инструкции Microsoft: приложения, контейнеры, системные файлы, чеки (`pkgutil`), с подтверждениями; заявлены Microsoft 365, Office 2024, 2021, 2019 | Переписан в 2025 году, небольшой проект (2 коммита) | Альтернатива с английским интерфейсом |
| [snandaworld/MS-Office-Uninstall-Script-For-MacOS](https://github.com/snandaworld/MS-Office-Uninstall-Script-For-MacOS) | Форк исходного скрипта плюс отдельный скрипт резервной копии Outlook | Даты последнего изменения на странице не видны | Если нужен отдельный скрипт копии Outlook |
| [demureiskander/Microsoft-Removal-Tool-for-macOS](https://github.com/demureiskander/Microsoft-Removal-Tool-for-macOS) | Удаляет **все** продукты Microsoft (в том числе Defender, Teams) и записи связки ключей по словам `microsoft`, `office`, `live.com` | Заявлены Ventura, Sonoma, Sequoia; вопросов перед удалением нет | Только если нужно стереть всё от Microsoft |

Коммерческие деинсталляторы (например, CleanMyMac или BuhoCleaner) тоже удаляют Office вместе с остатками, но это платные программы, и их набор путей неизвестен.

## Чем этот скрипт отличается

- Перед вопросами проверяет, что реально осталось: системные файлы, профиль, данные Outlook, чеки установки, связку ключей, иконки Dock.
- Только Office: профили и настройки Edge, VS Code, Teams и других продуктов Microsoft не затрагиваются.
- Просит закрыть запущенные приложения Office и выдать «Полный доступ к диску» до начала работы, при необходимости открывает нужные Системные настройки.
- Делает резервную копию данных Outlook перед удалением и не удаляет их без вашего согласия.
- Удаляет иконки Office из Dock (закреплённые и «недавние»), чеки установки (`pkgutil`), фоновые службы.
- Записи связки ключей удаляются по одной, с подтверждением каждой; пароли не читаются.
- Русский и английский интерфейс по языку macOS.

# Ссылки
Microsoft не предоставляет официальную программу удаления, но инструкции есть на сайте:
 1. [How to completely remove Office for Mac 2011][1]
 2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]


  [1]: https://support.microsoft.com/en-us/kb/2398768
  [2]: https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

---

# English

## Microsoft Office for Mac uninstaller
An interactive shell script for completely removing Microsoft Office for Mac 2011/2016/2019/2021/2024/365.

### Usage
The script runs straight from the network: no download and no options needed. Quit all Office apps and run in Terminal:
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
```
At the start the script warns that you will need the local password of your macOS account (characters are not shown while typing) and requests administrator rights itself. Running it as `sudo sh -c "…"` works too.

The script asks the questions itself, you only confirm with `y` or `n` (Enter picks the default):
 1. whether to remove Office data from the user profile (`~/Library` and local Outlook data), default "no"; if "yes", a backup copy of the Outlook data to the Desktop is offered;
 2. one general question: remove Microsoft Office and all other components (apps, settings, containers, caches, Automator actions, fonts, OneDrive, and Office icons from the Dock: pinned and in "recent");
 3. whether to search the keychain for Microsoft/Office entries (default "no"): the script lists found entries without reading passwords and asks about each one.

The interface is colored and shows an animation during long operations. Colors are turned off with `NO_COLOR=1` or when the output is not a terminal.

The message language follows the macOS language: Russian if the system is Russian, English otherwise. You can answer with `y`/`n` or `д`/`н`.

- `sudo su` is **not** needed. The script detects the real user itself, so the result does not depend on how you got root. The profile (`~/Library`) is not touched by default, but you can agree to clean it by answering `y` to the question.
- Local Outlook data (`UBF8T346G9.Office`, `com.microsoft.Outlook`) is removed only together with the profile, and only if you explicitly agreed in the first question.
- Only Office components and OneDrive are removed. Other Microsoft products (Edge, VS Code, Teams, etc.) are not touched.

### Other solutions

These are the tools I checked at the time of writing (October 2026). I did not find a separate official Office uninstaller for Mac: Microsoft provides only a manual removal guide and a license removal tool.

| Solution | What it does | Status | When to use |
|---|---|---|---|
| [Microsoft complete-removal guide](https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0) | Manual removal of apps, system files and `~/Library` folders in Finder | Official, maintained by Microsoft | When you want to check what is removed or do the steps by hand |
| [Microsoft License Removal Tool](https://support.microsoft.com/en-us/microsoft-365-activation-licensing/how-to-remove-office-license-files-on-a-mac) | Licenses only (Microsoft 365, Office 2024 and 2021 for Mac), does not remove the apps | Official, current. In the project author's experience it did not remove the Microsoft 365 license on some builds: signing out of the account in Office apps and deleting the Office keychain entries before running it helps (this script can find them) | Activation problems or license conflicts without removing Office |
| [Unlicense](https://github.com/pbowden-msft/Unlicense) | Command-line tool that removes the Office 365/2021/2019/2016 for Mac license, options `--All`, `--O365`, `--Volume`, `--ForceClose`, `--DetectOnly` | Unofficial (a personal account repository), 43 commits, last change date not visible on the page | When Microsoft's license tool did not help; try it on a test account first |
| [Office-Reset](https://office-reset.com/changelog/) | Resets and reinstalls apps, resets OneAuth, cleans the keychain and OneDrive/Teams leftovers | Latest version 2.0 Beta 1 from 2023-11-25, claims support up to Office 16.79 and macOS Sonoma, not updated | When you need to reset one app rather than remove everything; not verified on newer Office and macOS versions |
| [qsor27/office-mac-uninstaller](https://github.com/qsor27/office-mac-uninstaller) | Script following Microsoft's guide: apps, containers, system files, receipts (`pkgutil`), with confirmations; Microsoft 365, Office 2024, 2021, 2019 claimed | Rewritten in 2025, small project (2 commits) | An alternative with an English interface |
| [snandaworld/MS-Office-Uninstall-Script-For-MacOS](https://github.com/snandaworld/MS-Office-Uninstall-Script-For-MacOS) | Fork of the original script plus a separate Outlook backup script | Last change date not visible on the page | When you need a separate Outlook backup script |
| [demureiskander/Microsoft-Removal-Tool-for-macOS](https://github.com/demureiskander/Microsoft-Removal-Tool-for-macOS) | Removes **all** Microsoft products (including Defender, Teams) and keychain entries matching `microsoft`, `office`, `live.com` | Ventura, Sonoma, Sequoia claimed; no confirmation before removal | Only if you want to wipe everything from Microsoft |

Commercial uninstallers (for example CleanMyMac or BuhoCleaner) also remove Office with its leftovers, but they are paid programs and the set of paths they remove is not known.

### How this script is different

- Before asking anything it checks what is actually left: system files, profile, Outlook data, installer receipts, keychain, Dock icons.
- Office only: profiles and settings of Edge, VS Code, Teams and other Microsoft products are not touched.
- Asks you to quit running Office apps and to grant "Full Disk Access" before starting, and opens the needed System Settings pane when necessary.
- Makes a backup of Outlook data before removal and does not remove it without your consent.
- Removes Office icons from the Dock (pinned and "recent"), installer receipts (`pkgutil`) and background services.
- Keychain entries are removed one by one, each with a confirmation; passwords are never read.
- Russian and English interface following the macOS language.

### References
Microsoft does not provide an official uninstaller, but there are guides on its website:
 1. [How to completely remove Office for Mac 2011][1]
 2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]

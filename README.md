# Удаление Microsoft Office для Mac

Интерактивный shell-скрипт, который полностью удаляет Microsoft Office для Mac 2011/2016/2019/2021/2024/365. Перед удалением он может сохранить данные Outlook, а второй скрипт вернёт их в новую установку.

**Не знаете, с чего начать? [Пошаговая инструкция: переустановить Office начисто](docs/userguide/reinstall-office.md).**

[Использование](#использование) · [Восстановление Outlook](#восстановление-профиля-outlook) · [Отключение MAU](#отключение-microsoft-autoupdate) · [Где скачать и как активировать](#где-скачать-office-и-как-активировать) · [Другие решения](#другие-решения) · [English](#english)

## Что делает

- Перед вопросами проверяет, что реально осталось: системные файлы, профиль, данные Outlook, чеки установки, связку ключей, иконки Dock.
- Затрагивает только Office, OneDrive и (по отдельному вопросу) Microsoft Defender: профили и настройки Edge, VS Code, Teams и других продуктов Microsoft остаются нетронутыми.
- Делает резервную копию данных Outlook перед удалением и не удаляет их без вашего согласия.
- Удаляет иконки Office из Dock (закреплённые и «недавние»), чеки установки (`pkgutil`) и фоновые службы.
- Записи связки ключей удаляет по одной, с подтверждением каждой; пароли не читает.
- Просит закрыть запущенные приложения Office и выдать «Полный доступ к диску» до начала работы, при необходимости открывает нужные Системные настройки.
- Язык интерфейса выбирается по языку macOS: русский или английский.

## Использование

Скрипт запускается сразу по сети, скачивать его и указывать параметры не нужно. Закройте все приложения Office и выполните в Terminal:

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
```

В начале скрипт предупредит, что сейчас потребуется локальный пароль от вашей учётной записи macOS (при вводе символы не отображаются), и сам запросит права администратора. Запуск с `sudo sh -c "…"` тоже работает, а `sudo su` **не нужен**: скрипт сам определяет настоящего пользователя.

Дальше он задаёт вопросы, вам остаётся отвечать `д` или `н` (можно и `y`/`n`; Enter выбирает вариант по умолчанию):

1. **Удалять ли данные Office из пользовательского профиля** (`~/Library` и локальные данные Outlook). По умолчанию «нет». Если «да», дополнительно предлагается копия данных Outlook на Рабочий стол.
2. **Удалить Microsoft Office и все остальные компоненты**: приложения, настройки, контейнеры, кэши, Automator, шрифты, OneDrive и иконки Office из Dock.
3. **Удалить ли Microsoft Defender**, если он найден. Defender ставится одним пакетом (`com.microsoft.wdav`): скрипт запускает его официальный деинсталлятор, затем убирает остатки (приложение, службы `com.microsoft.fresno`/`com.microsoft.wdav.*`, настройки, логи, чек установки). По умолчанию «нет»: после удаления компьютер остаётся без защиты Defender. Если у Defender включена защита от изменений (Tamper Protection) или он управляется MDM, macOS может не дать удалить часть файлов.
4. **Искать ли записи Microsoft/Office в связке ключей.** По умолчанию «нет». Скрипт показывает найденные записи без чтения паролей и спрашивает про каждую.

Локальные данные Outlook (`UBF8T346G9.Office`, `com.microsoft.Outlook`) удаляются только вместе с профилем и только если вы явно согласились на это в первом вопросе.

После удаления рекомендуется перезагрузить компьютер, особенно перед повторной установкой Office; в остальных случаях это необязательно.

Интерфейс цветной, при долгих операциях показывается анимация. Цвета отключаются переменной `NO_COLOR=1` или если вывод не в терминал.

## Восстановление профиля Outlook

Если вы согласились на копию данных Outlook, она лежит на Рабочем столе в папке `OfficeUninstall-backup-ГГГГММДД-ЧЧММСС`. Установите Office, закройте все приложения Office и выполните в Terminal (пароль не нужен, `sudo` не используйте):

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_restore.sh)"
```

Что делает скрипт:

1. Проверяет «Полный доступ к диску» для Terminal и при необходимости просит его выдать.
2. Проверяет, что Outlook установлен, а приложения Office закрыты.
3. Находит на Рабочем столе папку `OfficeUninstall-backup-*`. Если их несколько, предложит выбрать; свою папку можно передать аргументом. О неполной копии предупредит.
4. Если контейнеры ещё не созданы, сам запустит Outlook, чтобы macOS их создала, и сам его закроет.
5. Сохраняет текущие данные Outlook на Рабочий стол в `OfficeUninstall-before-restore-*`, копирует данные из резервной копии и проверяет число файлов.

После работы скрипт подскажет отключить «Полный доступ к диску», если он выдавался во время запуска.

Что важно знать:

- Почта IMAP, Exchange и Microsoft 365 подтянется с сервера, но после восстановления может понадобиться войти в аккаунт заново.
- Восстанавливайте копию в ту же или более новую версию Outlook: более старая может не открыть базу.
- Не удаляйте папку с копией, пока не убедитесь, что всё на месте.

<details>
<summary>То же самое вручную</summary>

Папки внутри копии повторяют исходные места, поэтому их нужно вернуть обратно:

| Папка в копии | Куда положить |
|---|---|
| `com.microsoft.Outlook` | `~/Library/Containers/` |
| `UBF8T346G9.Office` | `~/Library/Group Containers/` |

1. Установите Office и один раз запустите Outlook, чтобы macOS создала контейнеры с правильными правами. Затем полностью закройте Outlook (Cmd+Q).
2. В Finder нажмите Cmd+Shift+G и откройте `~/Library/Containers`. Перенесите туда `com.microsoft.Outlook` из копии и согласитесь на замену. Так же замените `UBF8T346G9.Office` в `~/Library/Group Containers`.
3. Запустите Outlook: профиль и локальные данные должны вернуться.

Если Finder не даёт заменить папки (контейнеры защищены macOS), используйте Terminal. Подставьте имя своей папки с копией:

```
cd ~/Desktop/OfficeUninstall-backup-ГГГГММДД-ЧЧММСС
osascript -e 'quit app "Microsoft Outlook"'
rsync -a com.microsoft.Outlook/ ~/Library/Containers/com.microsoft.Outlook/
rsync -a UBF8T346G9.Office/ "$HOME/Library/Group Containers/UBF8T346G9.Office/"
```

Terminal может потребовать «Полный доступ к диску» (Системные настройки → Конфиденциальность и безопасность).

</details>

## Отключение Microsoft AutoUpdate

Office обновляется через Microsoft AutoUpdate (MAU): отдельное приложение с фоновыми службами, которое после установки само проверяет обновления. Если оно не нужно, его можно удалить, не трогая сам Office. Основной скрипт удаляет MAU вместе со всем Office, а этот нужен, когда Office уже установлен заново.

Закройте окна MAU, если они открыты, и выполните в Terminal:

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_remove_mau.sh)"
```

Скрипт предупредит про пароль учётной записи macOS и сам запросит права администратора (`sudo su` не нужен). Затем он проверит, что осталось от MAU, и спросит подтверждение (по умолчанию «нет»). Если согласиться, он остановит фоновые службы и удалит:

- `/Library/Application Support/Microsoft/MAU2.0` (приложение Microsoft AutoUpdate и Update Assistant);
- `/Library/LaunchAgents/com.microsoft.update.agent.plist`;
- `/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist`;
- `/Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper`.

Что важно знать:

- После удаления пункт «Проверить обновления» в Office перестанет работать: обновления придётся ставить вручную, скачав установщик с сайта Microsoft.
- Переустановка или обновление Office может вернуть MAU: тогда запустите скрипт ещё раз.
- Если MAU уже нет, скрипт сообщит об этом и ничего не изменит.

## Где скачать Office и как активировать

**Где скачать.** Актуальные установщики Microsoft публикует на странице [Update history for Office for Mac](https://learn.microsoft.com/en-us/officeupdates/update-history-office-for-mac). Там есть пакет установки всего набора Office (с Microsoft Teams и без него) для новой установки и пакеты обновления отдельных приложений (Word, Excel, PowerPoint, Outlook, OneNote). Ссылки на скачивание даны только для последних выпусков, поддерживается только самая новая версия. Отдельных установщиков для каждого приложения на странице нет.

**Как активировать.** Активировать Office нужно до работы с Outlook: без активации почтовым ящиком воспользоваться не получится.

- **Microsoft 365 (подписка).** Запустите любое приложение Office и войдите в учётную запись с активной подпиской.
- **Office LTSC 2024 и 2021 для Mac по корпоративной лицензии.** Активирует Volume License (VL) Serializer: пакет `.pkg`, который запускают на Mac с установленным Office. Скачать его может только администратор корпоративного лицензирования: [Microsoft 365 admin center](https://admin.microsoft.com/) → Billing → Your products → Volume licensing → вкладка Download and keys, поиск «Office LTSC Standard for Mac 2024» или «2021». Подробности в [документации Microsoft](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/volume-license-serializer). Лицензия лежит в `/Library/Preferences/com.microsoft.office.licensingV2.plist` и привязана к серийному номеру загрузочного диска, поэтому перенести её на другой Mac нельзя.

`office_uninstaller.sh` удаляет и этот файл лицензии, так что после переустановки Office LTSC нужно запустить VL Serializer ещё раз. Для подписки Microsoft 365 достаточно снова войти в учётную запись.

## Другие решения

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

## Ссылки

Microsoft не предоставляет официальную программу удаления, но инструкции есть на сайте:

1. [How to completely remove Office for Mac 2011][1]
2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]

## Лицензия

[MIT](LICENSE)

  [1]: https://support.microsoft.com/en-us/kb/2398768
  [2]: https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

---

# English

[Русская версия](#удаление-microsoft-office-для-mac)

## Microsoft Office for Mac uninstaller

An interactive shell script that completely removes Microsoft Office for Mac 2011/2016/2019/2021/2024/365. Before removal it can save your Outlook data, and a second script puts it back into the new installation.

**Not sure where to start? [Step-by-step guide: reinstall Office from scratch](docs/userguide/reinstall-office.md#english).**

[Usage](#usage) · [Restoring Outlook](#restoring-the-outlook-profile) · [Removing MAU](#removing-microsoft-autoupdate) · [Where to download and how to activate](#where-to-download-office-and-how-to-activate) · [Other solutions](#other-solutions)

### What it does

- Before asking anything it checks what is actually left: system files, profile, Outlook data, installer receipts, keychain, Dock icons.
- Touches only Office, OneDrive and (as a separate question) Microsoft Defender: profiles and settings of Edge, VS Code, Teams and other Microsoft products are left alone.
- Makes a backup of Outlook data before removal and does not remove it without your consent.
- Removes Office icons from the Dock (pinned and "recent"), installer receipts (`pkgutil`) and background services.
- Keychain entries are removed one by one, each with a confirmation; passwords are never read.
- Asks you to quit running Office apps and to grant "Full Disk Access" before starting, and opens the needed System Settings pane when necessary.
- The interface language follows macOS: Russian or English.

### Usage

The script runs straight from the network: no download and no options needed. Quit all Office apps and run in Terminal:

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
```

At the start the script warns that you will need the local password of your macOS account (characters are not shown while typing) and requests administrator rights itself. Running it as `sudo sh -c "…"` works too, and `sudo su` is **not** needed: the script detects the real user itself.

Then it asks questions, you only confirm with `y` or `n` (`д`/`н` also work; Enter picks the default):

1. **Whether to remove Office data from the user profile** (`~/Library` and local Outlook data). Default "no". If "yes", a backup copy of the Outlook data to the Desktop is offered.
2. **Remove Microsoft Office and all other components**: apps, settings, containers, caches, Automator actions, fonts, OneDrive, and Office icons from the Dock.
3. **Whether to remove Microsoft Defender**, if found. Defender is installed as a single package (`com.microsoft.wdav`): the script runs its official uninstaller, then removes the leftovers (app, `com.microsoft.fresno`/`com.microsoft.wdav.*` services, settings, logs, installer receipt). Default "no": the computer has no Defender protection afterwards. If Tamper Protection is on or Defender is managed by MDM, macOS may refuse to remove some files.
4. **Whether to search the keychain for Microsoft/Office entries.** Default "no". The script lists found entries without reading passwords and asks about each one.

Local Outlook data (`UBF8T346G9.Office`, `com.microsoft.Outlook`) is removed only together with the profile, and only if you explicitly agreed in the first question.

Restarting the computer afterwards is recommended, especially before reinstalling Office; otherwise it is not required.

The interface is colored and shows an animation during long operations. Colors are turned off with `NO_COLOR=1` or when the output is not a terminal.

### Restoring the Outlook profile

If you agreed to the Outlook data backup, it is on the Desktop in the folder `OfficeUninstall-backup-YYYYMMDD-HHMMSS`. Install Office, quit all Office apps and run in Terminal (no password needed, do not use `sudo`):

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_restore.sh)"
```

What the script does:

1. Checks "Full Disk Access" for Terminal and asks you to grant it if needed.
2. Checks that Outlook is installed and Office apps are closed.
3. Finds the `OfficeUninstall-backup-*` folder on the Desktop. If there are several it lets you choose; you can also pass your own folder as an argument. Warns about an incomplete backup.
4. If the containers do not exist yet, starts Outlook itself so macOS creates them, then closes it again.
5. Saves the current Outlook data to the Desktop as `OfficeUninstall-before-restore-*`, copies the data from the backup and checks the number of files.

When it finishes, the script suggests turning "Full Disk Access" off again if it was granted during the run.

Good to know:

- IMAP, Exchange and Microsoft 365 mail is pulled from the server again, but after restoring you may need to sign in to the account once more.
- Restore the backup into the same or a newer Outlook version: an older one may not open the database.
- Do not delete the backup folder until you are sure everything is in place.

<details>
<summary>The same by hand</summary>

The folders inside the backup mirror the original locations, so put them back:

| Folder in the backup | Where to put it |
|---|---|
| `com.microsoft.Outlook` | `~/Library/Containers/` |
| `UBF8T346G9.Office` | `~/Library/Group Containers/` |

1. Install Office and launch Outlook once so macOS creates the containers with the right permissions. Then quit Outlook completely (Cmd+Q).
2. In Finder press Cmd+Shift+G and open `~/Library/Containers`. Move `com.microsoft.Outlook` from the backup there and confirm the replacement. Do the same for `UBF8T346G9.Office` in `~/Library/Group Containers`.
3. Launch Outlook: the profile and local data should be back.

If Finder refuses to replace the folders (containers are protected by macOS), use Terminal. Substitute the name of your backup folder:

```
cd ~/Desktop/OfficeUninstall-backup-YYYYMMDD-HHMMSS
osascript -e 'quit app "Microsoft Outlook"'
rsync -a com.microsoft.Outlook/ ~/Library/Containers/com.microsoft.Outlook/
rsync -a UBF8T346G9.Office/ "$HOME/Library/Group Containers/UBF8T346G9.Office/"
```

Terminal may need "Full Disk Access" (System Settings → Privacy & Security).

</details>

### Removing Microsoft AutoUpdate

Office is updated through Microsoft AutoUpdate (MAU): a separate app with background services that checks for updates on its own after installation. If you do not need it, it can be removed without touching Office itself. The main script removes MAU together with all of Office, while this one is for when Office is already installed again.

Close the MAU windows if they are open and run in Terminal:

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_remove_mau.sh)"
```

The script warns about the macOS account password and requests administrator rights itself (`sudo su` is not needed). Then it checks what is left of MAU and asks for confirmation (default "no"). If you agree, it stops the background services and removes:

- `/Library/Application Support/Microsoft/MAU2.0` (the Microsoft AutoUpdate app and Update Assistant);
- `/Library/LaunchAgents/com.microsoft.update.agent.plist`;
- `/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist`;
- `/Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper`.

Good to know:

- Afterwards "Check for Updates" in Office stops working: install updates by hand by downloading the installer from Microsoft.
- Reinstalling or updating Office may bring MAU back: just run the script again.
- If MAU is already gone, the script says so and changes nothing.

### Where to download Office and how to activate

**Where to download.** Microsoft publishes current installers on the [Update history for Office for Mac](https://learn.microsoft.com/en-us/officeupdates/update-history-office-for-mac) page. It has the install package for the whole Office suite (with or without Microsoft Teams) for a new installation, and update packages for individual apps (Word, Excel, PowerPoint, Outlook, OneNote). Download links are given only for the latest releases, and only the newest version is supported. The page has no standalone installers for each app.

**How to activate.** Office must be activated before you use Outlook: without activation the mailbox cannot be used.

- **Microsoft 365 (subscription).** Launch any Office app and sign in with an account that has an active subscription.
- **Office LTSC 2024 and 2021 for Mac under a volume license.** Activated by the Volume License (VL) Serializer: a `.pkg` package that you run on a Mac where Office is installed. Only a volume licensing administrator can download it: [Microsoft 365 admin center](https://admin.microsoft.com/) → Billing → Your products → Volume licensing → the Download and keys tab, search for "Office LTSC Standard for Mac 2024" or "2021". Details are in [Microsoft's documentation](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/volume-license-serializer). The license is stored in `/Library/Preferences/com.microsoft.office.licensingV2.plist` and is tied to the serial number of the boot drive, so it cannot be moved to another Mac.

`office_uninstaller.sh` removes this license file too, so after reinstalling Office LTSC run the VL Serializer again. For a Microsoft 365 subscription it is enough to sign in again.

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

### References

Microsoft does not provide an official uninstaller, but there are guides on its website:

1. [How to completely remove Office for Mac 2011][1]
2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]

### License

[MIT](LICENSE)

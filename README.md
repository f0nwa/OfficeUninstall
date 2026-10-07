# Удаление Microsoft Office для Mac
Интерактивный shell-скрипт для полного удаления Microsoft Office для Mac 2011/2016/2019/2021/2024/365.

# Использование
Скрипт запускается сразу по сети, скачивать его и указывать параметры не нужно. Закройте все приложения Office и выполните в Terminal:
```
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
```
Скрипт сам задаёт вопросы, вам остаётся подтверждать `y` или `n` (Enter выбирает вариант по умолчанию):
 1. пробный запуск (только показать, что будет удалено, ничего не удаляя);
 2. чистить ли пользовательский профиль (`~/Library`);
 3. удалять ли личные данные Outlook (и сделать ли копию на Рабочий стол);
 4. каждая категория: приложения, настройки, контейнеры, кэши и логи, Automator/шрифты, OneDrive.

Рекомендуем сначала ответить «да» на пробный запуск, а затем запустить команду ещё раз.

- Запускайте с обычным `sudo`, `sudo su` **не нужен**. Скрипт сам определяет настоящего пользователя, поэтому ваш профиль (`~/Library`) очищается в любом случае. Раньше при `sudo su` профиль молча не затрагивался, теперь это выбор: скрипт спрашивает, чистить ли профиль.
- Локальные данные Outlook (`UBF8T346G9.Office`, `com.microsoft.Outlook`) сохраняются, если вы явно не согласитесь их удалить.
- Удаляются только компоненты Office. Другие продукты Microsoft (Edge, VS Code, Teams и др.) не затрагиваются, а OneDrive удаляется только по отдельному вопросу.

# Ссылки
Microsoft не предоставляет официальную программу удаления, но инструкции есть на сайте:
 1. [How to completely remove Office for Mac 2011][1]
 2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]


  [1]: https://support.microsoft.com/en-us/kb/2398768
  [2]: https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

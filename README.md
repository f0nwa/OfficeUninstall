# Удаление Microsoft Office для Mac
Интерактивный shell-скрипт для полного удаления Microsoft Office для Mac 2011/2016/2019/2021/2024/365.

# Использование
Скрипт запускается сразу по сети, скачивать его не нужно. Закройте все приложения Office и выполните в Terminal.

Сначала посмотрите, что будет удалено (ничего не удаляется):
```
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)" _ --dry-run
```

Затем запустите удаление. Перед каждой категорией скрипт задаёт вопрос:
```
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh)"
```

Параметры добавляются после `_`: `--dry-run`, `--yes`, `--no-profile`.

Привычный вариант тоже работает (вопросы читаются из терминала):
```
sudo sh -c "curl -s https://raw.githubusercontent.com/f0nwa/OfficeUninstall/master/office_uninstaller.sh | sh"
```

- Запускайте с обычным `sudo`, `sudo su` **не нужен**. Скрипт сам определяет настоящего пользователя, поэтому ваш профиль (`~/Library`) очищается в любом случае. Раньше при `sudo su` профиль молча не затрагивался, теперь это выбор: скрипт спрашивает, чистить ли профиль, а флаг `--no-profile` оставляет профиль нетронутым (удаляются только системные файлы).
- Локальные данные Outlook (`UBF8T346G9.Office`, `com.microsoft.Outlook`) сохраняются, если вы явно не согласитесь их удалить. Перед удалением предлагается резервная копия на Рабочий стол.
- Удаляются только компоненты Office. Другие продукты Microsoft (Edge, VS Code, Teams и др.) не затрагиваются, а OneDrive удаляется только по отдельному вопросу.
- `--yes` отвечает на вопросы значениями по умолчанию (данные Outlook и OneDrive остаются).

# Ссылки
Microsoft не предоставляет официальную программу удаления, но инструкции есть на сайте:
 1. [How to completely remove Office for Mac 2011][1]
 2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]


  [1]: https://support.microsoft.com/en-us/kb/2398768
  [2]: https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

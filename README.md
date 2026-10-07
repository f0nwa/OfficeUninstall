# Удаление Microsoft Office для Mac
Интерактивный shell-скрипт для полного удаления Microsoft Office для Mac 2011/2016/2019/2021/2024/365.

# Использование
 1. Закройте все приложения Office.
 2. Скачайте скрипт и прочитайте его:
```
curl -O https://raw.githubusercontent.com/f0nwa/officeuninstall/claude/admiring-tesla-itpkxw/office_uninstaller.sh
```
 3. Посмотрите, что будет удалено (ничего не удаляется):
```
sudo sh office_uninstaller.sh --dry-run
```
 4. Запустите скрипт. Перед каждой категорией он задаёт вопрос:
```
sudo sh office_uninstaller.sh
```

- Запускайте с обычным `sudo`, `sudo su` **не нужен**. Скрипт определяет настоящего пользователя через `SUDO_USER`, поэтому ваша папка `~/Library` очищается в обоих случаях.
- Локальные данные Outlook (`UBF8T346G9.Office`, `com.microsoft.Outlook`) сохраняются, если вы явно не согласитесь их удалить. Перед удалением предлагается резервная копия на Рабочий стол.
- Удаляются только компоненты Office. Другие продукты Microsoft (Edge, VS Code, Teams и др.) не затрагиваются, а OneDrive удаляется только по отдельному вопросу.
- `--yes` отвечает на вопросы значениями по умолчанию (данные Outlook и OneDrive остаются).

# Ссылки
Microsoft не предоставляет официальную программу удаления, но инструкции есть на сайте:
 1. [How to completely remove Office for Mac 2011][1]
 2. [Troubleshoot Office for Mac issues by completely uninstalling before you reinstall][2]


  [1]: https://support.microsoft.com/en-us/kb/2398768
  [2]: https://support.microsoft.com/en-us/office/troubleshoot-office-for-mac-issues-by-completely-uninstalling-before-you-reinstall-ec3aa66e-6a76-451f-9d35-cba2e14e94c0?omkt=en-us&ui=en-us&rs=en-us&ad=us

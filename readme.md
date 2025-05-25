# vsftpd-manager

Утилита управления vsftpd-сервером на systemd-хостах.

## Требования

- Bash ≥ 4  
- systemd  
- sudo  
- inotify-tools (`inotifywait`)  

## Установка

1. Скопировать скрипт:
   ```bash
   sudo cp vsftpd-manager.sh /usr/local/bin/vsftpd-manager
   sudo chmod +x /usr/local/bin/vsftpd-manager
````

2. Убедиться, что зависимости установлены:

   ```bash
   sudo apt install inotify-tools
   ```

## Конфигурация

* Основной конфиг: `/etc/vsftpd.conf`
* Логи:

  * FTP-сервер: `/var/log/vsftpd.log`
  * Действия менеджера: `/var/log/ftp-manager-actions.log`
  * Подключения: `/var/log/ftp-connection-tracker.log`

## Использование

```bash
sudo vsftpd-manager
```

### Меню

1. **Управление службой**
   Запуск, остановка, перезапуск, проверка статуса.

2. **Пользователи**
   Создать/удалить FTP-пользователя.

3. **Логи**
   Просмотр последних записей vsftpd, логов менеджера, трекера подключений.

4. **Конфигурация**
   Открыть в редакторе или проверить на ошибки.

5. **Шаблоны запуска**
   Автозапуск systemd или временный запуск (10 мин, 1 ч, 3 ч).

## Логи и мониторинг

* Трекер подключений автоматически стартует при запуске скрипта.
* Используется `inotifywait` для отслеживания новых CONNECT-записей.

## Лицензия

MIT

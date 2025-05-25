#!/usr/bin/env bash
# vsftpd-manager.sh — утилита управления vsftpd-сервером
# Требования: bash ≥4, systemd, sudo

set -euo pipefail
IFS=$'\n\t'

readonly CONFIG_FILE="/etc/vsftpd.conf"
readonly SERVICE_NAME="vsftpd"
readonly LOG_FTP="/var/log/vsftpd.log"
readonly LOG_ACTION="/var/log/ftp-manager-actions.log"
readonly LOG_CONN="/var/log/ftp-connection-tracker.log"

log_action() {
    local msg=$1
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$ts ▶ $msg" | sudo tee -a "$LOG_ACTION" >/dev/null
}

ensure_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Требуются привилегии root. Перезапустите скрипт через sudo." >&2
        exit 1
    fi
}

check_dependency() {
    command -v "$1" >/dev/null || {
        echo "Не найдено: $1. Установите пакет и повторите." >&2
        exit 2
    }
}

# Общая функция запуска/остановки с логированием
manage_service() {
    local action=$1 icon=$2 msg=$3
    systemctl "$action" "$SERVICE_NAME"
    log_action "$icon $msg"
}

# Фоновый трекер подключений через inotify (более эффективно, чем tail -F)
start_connection_tracker() {
    check_dependency inotifywait
    sudo touch "$LOG_CONN"
    sudo chmod 666 "$LOG_CONN"
    inotifywait -m -e modify "$LOG_FTP" --format '%T %w%f' --timefmt '%Y-%m-%d %H:%M:%S' \
    | while read ts file; do
        grep --line-buffered "CONNECT:" "$file" | while read line; do
            echo "$ts $line" >> "$LOG_CONN"
        done
      done &
}

# Универсальный таймер отключения
schedule_stop() {
    local delay=$1 desc=$2
    manage_service start "▶" "FTP запущен на $desc"
    (
      sleep "$delay"
      manage_service stop "⏹" "FTP автоматически остановлен через $desc"
    ) &
}

# Меню управления службами
menu_service() {
    PS3="Выберите действие: "
    local opts=("Запустить" "Остановить" "Перезапустить" "Статус" "Назад")
    select opt in "${opts[@]}"; do
        case $REPLY in
            1) manage_service start "🔼" "FTP-сервер запущен" ;;
            2) manage_service stop  "🔻" "FTP-сервер остановлен" ;;
            3) manage_service restart "🔁" "FTP-сервер перезапущен" ;;
            4) systemctl status "$SERVICE_NAME" --no-pager ;;
            5) break ;;
            *) echo "Некорректный выбор." ;;
        esac
    done
}

# Меню управления пользователями
menu_users() {
    PS3="Выберите действие: "
    local opts=("Создать" "Удалить" "Назад")
    select opt in "${opts[@]}"; do
        case $REPLY in
            1)
                read -rp "Имя нового пользователя: " u
                adduser --disabled-password --gecos "" "$u"
                log_action "➕ Пользователь '$u' создан"
                ;;
            2)
                read -rp "Имя пользователя для удаления: " u
                deluser --remove-home "$u"
                log_action "➖ Пользователь '$u' удалён"
                ;;
            3) break ;;
            *) echo "Некорректный выбор." ;;
        esac
    done
}

# Меню логов
menu_logs() {
    PS3="Выберите действие: "
    local opts=("Последние 30 строк vsftpd.log" "Просмотреть vsftpd.log" \
                "Лог действий" "Лог подключений" "Назад")
    select opt in "${opts[@]}"; do
        case $REPLY in
            1) tail -n 30 "$LOG_FTP" ;;
            2) less "$LOG_FTP" ;;
            3) less "$LOG_ACTION" ;;
            4)
                if [[ -s "$LOG_CONN" ]]; then
                    less "$LOG_CONN"
                else
                    echo "Нет записей подключения."
                fi
                ;;
            5) break ;;
            *) echo "Некорректный выбор." ;;
        esac
    done
}

# Меню конфигурации
menu_config() {
    PS3="Выберите действие: "
    local opts=("Редактировать конфиг" "Проверить на ошибки" "Назад")
    select opt in "${opts[@]}"; do
        case $REPLY in
            1) ${EDITOR:-nano} "$CONFIG_FILE" ;;
            2)
                if vsftpd "$CONFIG_FILE" &>/dev/null; then
                    echo "✅ Конфигурация корректна."
                else
                    echo "❌ Обнаружены ошибки!"
                fi
                ;;
            3) break ;;
            *) echo "Некорректный выбор." ;;
        esac
    done
}

# Меню шаблонов автозапуска
menu_autostart() {
    PS3="Выберите шаблон автозапуска: "
    local opts=("Включить автозапуск" "На 10 минут" "На 1 час" "На 3 часа" "Назад")
    select opt in "${opts[@]}"; do
        case $REPLY in
            1)
                systemctl enable "$SERVICE_NAME"
                manage_service start "▶" "Постоянный автозапуск включен"
                ;;
            2) schedule_stop 600 "10 минут" ;;
            3) schedule_stop 3600 "1 час" ;;
            4) schedule_stop 10800 "3 часа" ;;
            5) break ;;
            *) echo "Некорректный выбор." ;;
        esac
    done
}

main() {
    ensure_root
    check_dependency systemctl
    check_dependency adduser
    check_dependency deluser

    # Стартуем трекер подключений, если ещё не запущен
    if ! pgrep -f inotifywait >/dev/null; then
        start_connection_tracker
    fi

    PS3="Выберите раздел: "
    local opts=("Управление службой" "Пользователи" "Логи" "Конфигурация" \
                "Шаблоны запуска" "Выход")
    while true; do
        select opt in "${opts[@]}"; do
            case $REPLY in
                1) menu_service ;;
                2) menu_users ;;
                3) menu_logs ;;
                4) menu_config ;;
                5) menu_autostart ;;
                6) exit 0 ;;
                *) echo "Некорректный выбор." ;;
            esac
        done
    done
}

main "$@"

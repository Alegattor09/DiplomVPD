#!/bin/bash

# Логирование ошибок
LOG_FILE="/var/log/zabbix_network_metrics.log"
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

case $1 in
    # Сетевые метрики USE
    "network_util")
        # Утилизация сетевого интерфейса в %
        interface=${2:-eth0}
        stats=$(grep "$interface:" /proc/net/dev 2>/dev/null)
        if [[ -n "$stats" ]]; then
            rx_bytes=$(echo "$stats" | awk '{print $2}')
            tx_bytes=$(echo "$stats" | awk '{print $10}')
            # Предполагаем гигабитный интерфейс (1Gbps = 125000000 bytes/s)
            max_bandwidth=125000000
            # Используем awk для вычислений вместо bc
            utilization=$(echo "$rx_bytes $tx_bytes $max_bandwidth" | awk '{printf "%.2f", ($1 + $2) * 100 / $3}')
            echo "$utilization"
        else
            log_message "ERROR: Interface $interface not found"
            echo 0
        fi
        ;;
    
"network_sat")
    # Насыщение сети - пакеты в очереди
    interface=${2:-eth0}
    if command -v tc &> /dev/null; then
        queue_drops=$(tc -s qdisc show dev "$interface" 2>/dev/null | grep dropped | awk '{print $7}' | head -1 | sed 's/,//g')
        # Если значение пустое, возвращаем 0
        if [[ -z "$queue_drops" ]]; then
            echo 0
        else
            echo "$queue_drops"
        fi
    else
        echo 0
    fi
    ;;
    
    "network_errors")
        # Ошибки сети
        interface=${2:-eth0}
        stats=$(grep "$interface:" /proc/net/dev 2>/dev/null)
        if [[ -n "$stats" ]]; then
            errors=$(echo "$stats" | awk '{print $4+$12}')
            echo "${errors:-0}"
        else
            echo 0
        fi
        ;;
    
    "network_packet_loss")
        # Потеря пакетов (ICMP ping до шлюза)
        gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)
        if [[ -n "$gateway" ]]; then
            loss=$(ping -c 3 -W 2 "$gateway" 2>/dev/null | grep "packet loss" | awk '{print $6}' | sed 's/%//')
            echo "${loss:-100}"
        else
            log_message "WARNING: Default gateway not found"
            echo 100
        fi
        ;;
    
    "network_latency")
        # Задержка до шлюза
        gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)
        if [[ -n "$gateway" ]]; then
            latency=$(ping -c 3 -W 2 "$gateway" 2>/dev/null | grep "avg" | awk -F'/' '{print $5}')
            if [[ -n "$latency" ]]; then
                echo "$latency"
            else
                echo 0
            fi
        else
            echo 0
        fi
        ;;
    
    # HTTP метрики
    "http_response_time")
        # Время ответа HTTP
        url=${2:-http://localhost}
        if command -v curl &> /dev/null; then
            response_time=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo 0)
            echo "$response_time"
        else
            log_message "ERROR: curl not installed"
            echo 0
        fi
        ;;
    
    "http_status_code")
        # HTTP статус код
        url=${2:-http://localhost}
        if command -v curl &> /dev/null; then
            status_code=$(curl -o /dev/null -s -w "%{http_code}\n" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo 0)
            echo "$status_code"
        else
            echo 0
        fi
        ;;
    
    "http_availability")
        # Доступность HTTP (1 - доступно, 0 - недоступно)
        url=${2:-http://localhost}
        if command -v curl &> /dev/null; then
            http_code=$(curl -o /dev/null -s -w "%{http_code}\n" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
            if [[ "$http_code" =~ ^[2-3][0-9][0-9]$ ]]; then
                echo 1
            else
                echo 0
            fi
        else
            echo 0
        fi
        ;;
    
    "http_ssl_expiry")
        # Дней до истечения SSL сертификата
        url=${2:-https://localhost}
        # Убираем протокол для получения домена
        domain=$(echo "$url" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1)
        if command -v openssl &> /dev/null && command -v timeout &> /dev/null; then
            expiry_date=$(timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null < /dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
            if [[ -n "$expiry_date" ]]; then
                expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
                current_epoch=$(date +%s)
                if [[ -n "$expiry_epoch" ]] && [[ -n "$current_epoch" ]]; then
                    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                    echo "$days_left"
                else
                    echo 0
                fi
            else
                echo 0
            fi
        else
            log_message "ERROR: openssl or timeout not installed"
            echo 0
        fi
        ;;
    
    "tcp_port_check")
        # Проверка доступности TCP порта
        host=${2:-localhost}
        port=${3:-80}
        if command -v timeout &> /dev/null; then
            timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null && echo 1 || echo 0
        else
            # Fallback без timeout
            (bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null && echo 1 || echo 0) &
            sleep 5
        fi
        ;;
    
    "dns_response_time")
        # Время ответа DNS
        domain=${2:-google.com}
        if command -v dig &> /dev/null; then
            response_time=$(dig +short +stats "$domain" 2>/dev/null | grep "Query time:" | awk '{print $4}' | head -1)
            echo "${response_time:-0}"
        else
            # Альтернатива с nslookup
            response_time=$(nslookup "$domain" 2>/dev/null | grep -o "time=[0-9]*" | cut -d= -f2 | head -1)
            echo "${response_time:-0}"
        fi
        ;;
    
    "bandwidth_usage")
        # Использование полосы пропускания в Mbps
        interface=${2:-eth0}
        if [[ -f "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
            # Получаем статистику за 1 секунду
            rx1=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null)
            tx1=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null)
            sleep 1
            rx2=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null)
            tx2=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null)
            
            rx_speed=$(( (rx2 - rx1) * 8 / 1000000 )) # Mbps
            tx_speed=$(( (tx2 - tx1) * 8 / 1000000 )) # Mbps
            
            echo "RX:$rx_speed TX:$tx_speed"
        else
            echo "RX:0 TX:0"
        fi
        ;;
    
    *)
        log_message "ERROR: Unknown metric '$1' with params: $2 $3"
        echo 0
        ;;
esac
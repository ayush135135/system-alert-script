#!/bin/bash

SYSLOG_PATH="/var/log/syslog"
ALERT_LOG="/tmp/sys_alert.log"
REPORT_LOG="/var/log/sys_watchdog.log"
ALERT_EMAIL="admin@example.com"
CPU_LIMIT=80
MEM_LIMIT=80

write_log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$REPORT_LOG"
}

check_cpu_usage() {
  local cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
  cpu_load=${cpu_load%.*}
  if [ "$cpu_load" -ge "$CPU_LIMIT" ]; then
    echo "High CPU usage detected: $cpu_load%" >> "$ALERT_LOG"
    write_log "CPU warning at ${cpu_load}%"
    return 1
  fi
  return 0
}

check_memory_usage() {
  local mem_used=$(free | awk '/Mem:/ {printf("%.0f", $3/$2 * 100)}')
  if [ "$mem_used" -ge "$MEM_LIMIT" ]; then
    echo "High Memory usage: $mem_used%" >> "$ALERT_LOG"
    write_log "Memory warning at ${mem_used}%"
    return 1
  fi
  return 0
}

scan_syslog_errors() {
  grep -Ei "panic|error|fail" "$SYSLOG_PATH" > "$ALERT_LOG"
  local error_count=$(wc -l < "$ALERT_LOG")
  if [ "$error_count" -gt 0 ]; then
    write_log "$error_count error(s) found in $SYSLOG_PATH"
    return 1
  fi
  return 0
}

notify_admin() {
  mailx -s "System Alert Report" "$ALERT_EMAIL" < "$ALERT_LOG"
  write_log "Alert mail sent to $ALERT_EMAIL"
}

cleanup() {
  rm -f "$ALERT_LOG"
}

system_watchdog() {
  touch "$REPORT_LOG"
  echo "" > "$ALERT_LOG"

  check_cpu_usage || notify_admin
  check_memory_usage || notify_admin
  scan_syslog_errors || notify_admin

  cleanup
}

system_watchdog

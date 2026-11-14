#!/usr/bin/env bash
# ==============================================================================
# system_health.sh - Production Linux System Health Monitoring & Automation
# Suitable for automated monitoring agents, cron jobs, and systemd timers.
#
# Exit Codes:
#   0 = HEALTHY  (All monitored metrics within normal thresholds)
#   1 = WARNING  (One or more thresholds exceeded)
#   2 = CRITICAL (Severe threshold exceeded e.g. >= 95% or runtime failure)
# ==============================================================================

set -euo pipefail

# Default configuration thresholds and paths
CPU_THRESHOLD=90
MEM_THRESHOLD=85
DISK_THRESHOLD=80
OUTPUT_JSON=false
LOG_FILE="health_log.txt"
MAX_LOG_LINES=2000

# ------------------------------------------------------------------------------
# Help Function
# ------------------------------------------------------------------------------
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Collects Linux server performance metrics, checks configurable warning
thresholds, logs timestamped results with automatic rotation, and returns
monitoring-compatible exit codes.

Options:
  --cpu <percent>       CPU usage warning threshold (default: 90)
  --mem <percent>       Memory usage warning threshold (default: 85)
  --disk <percent>      Disk usage warning threshold across all filesystems (default: 80)
  --log-file <path>     Path to output log file (default: health_log.txt)
  --max-lines <count>   Maximum lines in log before rotation (default: 2000)
  --json                Output results in structured JSON format
  -h, --help            Show this help message and exit

Exit Codes:
  0 = HEALTHY           All metrics within configured thresholds
  1 = WARNING           One or more warning thresholds exceeded
  2 = CRITICAL          Severe condition (Disk or Memory >= 95%) or fatal execution error

Cron Example (every 5 minutes):
  */5 * * * * /opt/scripts/system_health.sh --disk 80 --cpu 90 --mem 85 >> /var/log/cron_health.log 2>&1
EOF
}

# ------------------------------------------------------------------------------
# Parse Command-Line Arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu)
      CPU_THRESHOLD="${2:-}"
      shift 2
      ;;
    --mem)
      MEM_THRESHOLD="${2:-}"
      shift 2
      ;;
    --disk)
      DISK_THRESHOLD="${2:-}"
      shift 2
      ;;
    --log-file)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    --max-lines)
      MAX_LOG_LINES="${2:-}"
      shift 2
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      show_help >&2
      exit 2
      ;;
  esac
done

# Validate threshold inputs are numeric
for val in "$CPU_THRESHOLD" "$MEM_THRESHOLD" "$DISK_THRESHOLD"; do
  if ! [[ "$val" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] Thresholds must be positive integers. Received: $val" >&2
    exit 2
  fi
done

# ------------------------------------------------------------------------------
# Metric Collection
# ------------------------------------------------------------------------------
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 1. CPU Usage Calculation (via /proc/stat or top)
if command -v top >/dev/null 2>&1; then
  # Extract CPU idle percentage from top batch mode
  CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int($1)}')
  CPU_USAGE=$((100 - CPU_IDLE))
else
  CPU_USAGE=0
fi

# 2. Memory Usage Calculation
if command -v free >/dev/null 2>&1; then
  MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
  MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
  MEM_USAGE=$(( (MEM_USED * 100) / MEM_TOTAL ))
else
  MEM_TOTAL=0
  MEM_USED=0
  MEM_USAGE=0
fi

# 3. Load Average (1, 5, 15 min)
if [[ -f /proc/loadavg ]]; then
  LOAD_1=$(awk '{print $1}' /proc/loadavg)
  LOAD_5=$(awk '{print $2}' /proc/loadavg)
  LOAD_15=$(awk '{print $3}' /proc/loadavg)
else
  LOAD_1="0.00"
  LOAD_5="0.00"
  LOAD_15="0.00"
fi

# 4. Disk Usage (All mounted ext/xfs/btrfs/root filesystems, excluding pseudo fs)
MAX_DISK_USAGE=0
DISK_DETAILS=()
while read -r fs size used avail pcent target; do
  pcent_num="${pcent%\%}"
  DISK_DETAILS+=("{\"filesystem\":\"$fs\",\"mount\":\"$target\",\"used_percent\":$pcent_num,\"available\":\"$avail\"}")
  if [[ "$pcent_num" -gt "$MAX_DISK_USAGE" ]]; then
    MAX_DISK_USAGE="$pcent_num"
  fi
done < <(df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2)

# 5. Top 5 Processes by Memory Usage
TOP_PROCESSES=()
while read -r pid user mem cpu comm; do
  TOP_PROCESSES+=("{\"pid\":$pid,\"user\":\"$user\",\"mem_percent\":\"$mem\",\"cpu_percent\":\"$cpu\",\"command\":\"$comm\"}")
done < <(ps -eo pid,user,%mem,%cpu,comm --sort=-%mem 2>/dev/null | head -n 6 | tail -n +2)

# ------------------------------------------------------------------------------
# Threshold Evaluation & Status Code
# ------------------------------------------------------------------------------
EXIT_CODE=0
WARNINGS=()

if [[ "$CPU_USAGE" -ge "$CPU_THRESHOLD" ]]; then
  WARNINGS+=("CPU usage exceeded threshold: ${CPU_USAGE}% >= ${CPU_THRESHOLD}%")
  EXIT_CODE=1
fi

if [[ "$MEM_USAGE" -ge "$MEM_THRESHOLD" ]]; then
  WARNINGS+=("Memory usage exceeded threshold: ${MEM_USAGE}% >= ${MEM_THRESHOLD}%")
  EXIT_CODE=1
fi

if [[ "$MAX_DISK_USAGE" -ge "$DISK_THRESHOLD" ]]; then
  WARNINGS+=("Disk usage exceeded threshold: ${MAX_DISK_USAGE}% >= ${DISK_THRESHOLD}%")
  EXIT_CODE=1
fi

# Upgrade to CRITICAL (exit code 2) if severe exhaustion detected
if [[ "$MAX_DISK_USAGE" -ge 95 ]] || [[ "$MEM_USAGE" -ge 95 ]]; then
  EXIT_CODE=2
fi

HEALTH_STATUS="HEALTHY"
if [[ "$EXIT_CODE" -eq 1 ]]; then
  HEALTH_STATUS="WARNING"
elif [[ "$EXIT_CODE" -eq 2 ]]; then
  HEALTH_STATUS="CRITICAL"
fi

# ------------------------------------------------------------------------------
# Output Formatting (Plain Text or JSON)
# ------------------------------------------------------------------------------
if [[ "$OUTPUT_JSON" == true ]]; then
  # Format JSON output
  IFS=","
  JSON_OUTPUT=$(cat << JSON
{
  "timestamp": "$TIMESTAMP",
  "status": "$HEALTH_STATUS",
  "exit_code": $EXIT_CODE,
  "cpu": {
    "usage_percent": $CPU_USAGE,
    "threshold_percent": $CPU_THRESHOLD
  },
  "memory": {
    "used_mb": $MEM_USED,
    "total_mb": $MEM_TOTAL,
    "usage_percent": $MEM_USAGE,
    "threshold_percent": $MEM_THRESHOLD
  },
  "load_average": {
    "1min": "$LOAD_1",
    "5min": "$LOAD_5",
    "15min": "$LOAD_15"
  },
  "max_disk_usage_percent": $MAX_DISK_USAGE,
  "disks": [${DISK_DETAILS[*]}],
  "top_memory_processes": [${TOP_PROCESSES[*]}],
  "warnings": [$(for w in "${WARNINGS[@]}"; do echo "\"$w\""; done | paste -sd, -)]
}
JSON
)
  echo "$JSON_OUTPUT"
  LOG_ENTRY="$JSON_OUTPUT"
else
  # Format Plain Text Output
  PLAIN_OUTPUT="[$TIMESTAMP] STATUS: $HEALTH_STATUS | CPU: ${CPU_USAGE}% | MEM: ${MEM_USAGE}% (${MEM_USED}MB/${MEM_TOTAL}MB) | LOAD: $LOAD_1, $LOAD_5, $LOAD_15 | MAX DISK: ${MAX_DISK_USAGE}%"
  echo "$PLAIN_OUTPUT"
  for warn in "${WARNINGS[@]}"; do
    echo "[WARNING] $warn"
  done
  LOG_ENTRY="$PLAIN_OUTPUT"
fi

# ------------------------------------------------------------------------------
# Log Rotation & Persistence
# ------------------------------------------------------------------------------
# Rotate log file if lines exceed MAX_LOG_LINES
if [[ -f "$LOG_FILE" ]]; then
  LINE_COUNT=$(wc -l < "$LOG_FILE")
  if [[ "$LINE_COUNT" -ge "$MAX_LOG_LINES" ]]; then
    mv -f "$LOG_FILE" "${LOG_FILE}.1"
    echo "[$TIMESTAMP] Rotated $LOG_FILE ($LINE_COUNT lines reached limit of $MAX_LOG_LINES)" > "$LOG_FILE"
  fi
fi

# Append entry to log file
echo "$LOG_ENTRY" >> "$LOG_FILE"

exit "$EXIT_CODE"

#!/usr/bin/env bash
set -uo pipefail

if [[ $# -ne 1 || ! $1 =~ ^[a-zA-Z0-9_][a-zA-Z0-9_@.:-]*$ ]]; then
    echo "Usage: $0 <service>" >&2
    exit 2
fi

service=$1
syslog_file=${SYSLOG_FILE:-/var/log/syslog}
result=0

for command_name in systemctl journalctl date awk grep mktemp; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing command: $command_name" >&2
        exit 2
    fi
done

load_state=$(systemctl show --property=LoadState --value -- "$service" 2>/dev/null)
if [[ $load_state == not-found || -z $load_state ]]; then
    echo "Service not found or systemd unavailable: $service" >&2
    result=2
elif systemctl is-active --quiet -- "$service"; then
    echo "Service $service: active"
else
    echo "Service $service: inactive"
    journalctl --no-pager -u "$service" -n 10 || result=2
    [[ $result -eq 2 ]] || result=1
fi

if [[ ! -r $syslog_file ]]; then
    echo "Cannot read syslog: $syslog_file" >&2
    exit 2
fi

recent_logs=$(mktemp) || exit 2
trap 'rm -f "$recent_logs"' EXIT

# Syslog supports RFC 3164 local time and RFC 3339 timestamps with offsets.
if ! awk -v now="$(date +%s)" '
function offset_seconds(value, sign) {
    sign = substr(value, 1, 1) == "-" ? -1 : 1
    gsub(/:/, "", value)
    return sign * (substr(value, 2, 2) * 3600 + substr(value, 4, 2) * 60)
}
BEGIN {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
    for (i = 1; i <= 12; i++) months[names[i]] = i
    year = strftime("%Y", now)
}
{
    epoch = -1
    if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) {
        stamp = $1
        zone = substr(stamp, 20)
        sub(/^\.[0-9]+/, "", zone)
        if (zone !~ /^(Z|[+-][0-9][0-9]:[0-9][0-9])$/) next
        date_time = substr(stamp, 1, 19)
        gsub(/[-T:]/, " ", date_time)
        local_epoch = mktime(date_time " -1")
        if (local_epoch < 0) next
        epoch = local_epoch + offset_seconds(strftime("%z", local_epoch))
        if (zone != "Z") epoch -= offset_seconds(zone)
    } else if ($1 in months && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
        time = $3
        gsub(/:/, " ", time)
        epoch = mktime(year " " months[$1] " " $2 " " time " -1")
        if (epoch > now + 300) epoch = mktime((year - 1) " " months[$1] " " $2 " " time " -1")
    }
    if (epoch >= now - 3600 && epoch <= now) print
}' "$syslog_file" > "$recent_logs"; then
    echo "Failed to parse syslog" >&2
    exit 2
fi

error_count=$(grep -Eic '(^|[^[:alnum:]_])(error|err|crit|critical|alert|emerg|emergency|panic|fatal|failed)([^[:alnum:]_]|$)' "$recent_logs")
grep_status=$?
if (( grep_status > 1 )); then
    echo "Failed to count syslog errors" >&2
    exit 2
fi
printf 'Syslog error lines in the last hour: %s\n' "$error_count"
exit "$result"

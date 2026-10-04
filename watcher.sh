#!/bin/sh

SMTP_PORT=${SMTP_PORT:-465}
SUBJECT_PREFIX=${SUBJECT_PREFIX:-"[Alert]"}
CRASH_DELAY_SECONDS=${CRASH_DELAY_SECONDS:-0}

case "$CRASH_DELAY_SECONDS" in
    ''|*[!0-9]*)
        echo "Invalid CRASH_DELAY_SECONDS '$CRASH_DELAY_SECONDS'; using 0."
        CRASH_DELAY_SECONDS=0
        ;;
esac

NOW=$(date '+%d/%m/%Y %H:%M:%S')
echo "[$NOW] Starting docker crash watcher..."

send_email() {
    local container="$1"
    local now
    now=$(date '+%d/%m/%Y %H:%M:%S')

    printf "From: %s <%s>\nTo: %s\nSubject: %s %s stop\n\nContainer: %s\nDate and time: %s\n" \
        "$SMTP_FROM_NAME" "$SMTP_FROM" "$SMTP_TO" "$SUBJECT_PREFIX" "$container" "$container" "$now" | \
        curl -s --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
            --mail-from "$SMTP_FROM" \
            --mail-rcpt "$SMTP_TO" \
            --user "$SMTP_USER:$SMTP_PASS" \
            -T -

    if [ $? -eq 0 ]; then
        echo "[$now] Crash alert sent successfully for '$container'."
    else
        echo "[$now] Email Error sending crash alert for '$container'."
    fi
}

handle_crash() {
    local container="$1"
    local now
    local running

    if [ "$CRASH_DELAY_SECONDS" -gt 0 ]; then
        sleep "$CRASH_DELAY_SECONDS"
    fi

    running=$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null)
    if [ "$running" = "true" ]; then
        now=$(date '+%d/%m/%Y %H:%M:%S')
        echo "[$now] Container '$container' is running again; crash alert skipped."
        return
    fi

    now=$(date '+%d/%m/%Y %H:%M:%S')
    echo "[$now] Container '$container' is still stopped. Sending email..."
    send_email "$container"
}

# Listen events from Docker socket
docker events --filter 'type=container' --filter 'event=die' --filter 'event=oom' --format '{{.Actor.Attributes.name}}' | while read -r container; do
    NOW=$(date '+%d/%m/%Y %H:%M:%S')
    echo "[$NOW] Event detected in '$container'. Checking again in ${CRASH_DELAY_SECONDS}s..."
    handle_crash "$container" &
done
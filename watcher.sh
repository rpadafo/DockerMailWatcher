#!/bin/sh

# 465 port if is empty in environment variables
SMTP_PORT=${SMTP_PORT:-465}
SUBJECT_PREFIX=${SUBJECT_PREFIX:-"[Alert]"}

NOW=$(date '+%d/%m/%Y %H:%M:%S')
echo "[$NOW] Starting docker mail watcher..."
echo "[$NOW] SMTP Server: $SMTP_SERVER:$SMTP_PORT"
echo "[$NOW] Notifications to: $SMTP_TO"

# Listen events from Docker socket
docker events --filter 'type=container' --filter 'event=die' --filter 'event=oom' --format '{{.Actor.Attributes.name}}' | while read -r container; do
  NOW=$(date '+%d/%m/%Y %H:%M:%S')
  echo "[$NOW] Event detected in '$container'. Sending email to $SMTP_TO..."

  printf "From: %s <%s>\nTo: %s\nSubject: %s %s stop\n\nContainer: %s\nDate and time: %s\n" \
    "$SMTP_FROM_NAME" "$SMTP_FROM" "$SMTP_TO" "$SUBJECT_PREFIX" "$container" "$container" "$NOW" | \
    curl -s --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
      --mail-from "$SMTP_FROM" \
      --mail-rcpt "$SMTP_TO" \
      --user "$SMTP_USER:$SMTP_PASS" \
      -T -

  if [ $? -eq 0 ]; then
    echo "[$NOW] Alert sent successfully."
  else
    echo "[$NOW] Email Error."
  fi
done
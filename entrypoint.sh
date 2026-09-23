#!/bin/sh

NOW=$(date '+%d/%m/%Y %H:%M:%S')
echo "[$NOW] Starting Docker Mail Watcher Services..."
echo "[$NOW] SMTP Server: $SMTP_SERVER:$SMTP_PORT"
echo "[$NOW] Notifications to: $SMTP_TO"

# Arrancar la revisión de actualizaciones en segundo plano
/app/update.sh &

# Arrancar el monitor de caídas en primer plano (mantiene el contenedor activo)
/app/watcher.sh
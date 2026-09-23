#!/bin/sh

# Variables para activar/desactivar servicios (por defecto 'true')
ENABLE_CRASH_WATCHER=${ENABLE_CRASH_WATCHER:-true}
ENABLE_UPDATE_WATCHER=${ENABLE_UPDATE_WATCHER:-true}

NOW=$(date '+%d/%m/%Y %H:%M:%S')
echo "[$NOW] Starting Docker Mail Watcher..."
echo "[$NOW] SMTP Server: $SMTP_SERVER:$SMTP_PORT"
echo "[$NOW] Notifications to: $SMTP_TO"

# Lanzar servicio de caídas si está activado
if [ "$ENABLE_CRASH_WATCHER" = "true" ]; then
    echo "[$NOW] Crash watcher: ENABLED"
    /app/watcher.sh &
else
    echo "[$NOW] Crash watcher: DISABLED"
fi

# Lanzar servicio de actualizaciones si está activado
if [ "$ENABLE_UPDATE_WATCHER" = "true" ]; then
    echo "[$NOW] Update watcher: ENABLED"
    /app/update.sh &
else
    echo "[$NOW] Update watcher: DISABLED"
fi

# Si ninguno está activado, avisar y salir
if [ "$ENABLE_CRASH_WATCHER" != "true" ] && [ "$ENABLE_UPDATE_WATCHER" != "true" ]; then
    echo "[$NOW] Error: Both watchers are disabled. Exiting..."
    exit 1
fi

# Mantener el contenedor activo procesando las señales del sistema
exec tail -f /dev/null
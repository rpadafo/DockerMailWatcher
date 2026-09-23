#!/bin/sh

SMTP_PORT=${SMTP_PORT:-465}
SUBJECT_PREFIX=${SUBJECT_PREFIX_UPDATE:-"[Update]"}
CHECK_INTERVAL=${CHECK_INTERVAL:-86400} # Por defecto revisa cada 24 horas

NOW=$(date '+%d/%m/%Y %H:%M:%S')
echo "[$NOW] Starting docker update watcher..."

send_email() {
    local container="$1"
    local image="$2"
    local now
    now=$(date '+%d/%m/%Y %H:%M:%S')

    printf "From: %s <%s>\nTo: %s\nSubject: %s Update available: %s\n\nThere is a new image version available for container '%s' (Image: %s).\nDate and time: %s\n" \
        "$SMTP_FROM_NAME" "$SMTP_FROM" "$SMTP_TO" "$SUBJECT_PREFIX" "$container" "$container" "$image" "$now" | \
        curl -s --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
            --mail-from "$SMTP_FROM" \
            --mail-rcpt "$SMTP_TO" \
            --user "$SMTP_USER:$SMTP_PASS" \
            -T -

    if [ $? -eq 0 ]; then
        echo "[$now] Update alert sent successfully for '$container'."
    else
        echo "[$now] Email Error sending update alert for '$container'."
    fi
}

sleep 10

while true; do
    NOW=$(date '+%d/%m/%Y %H:%M:%S')
    echo "[$NOW] Checking for Docker image updates..."

    containers=$(docker ps --format '{{.Names}}|{{.Image}}')

    echo "$containers" | while IFS='|' read -r name image; do
        [ -z "$image" ] && continue

        # 1. Obtener la ID (sha256) exacta de la imagen que está usando el contenedor en ejecución
        running_image_id=$(docker inspect --format='{{.Image}}' "$name" 2>/dev/null)
        [ -z "$running_image_id" ] && continue

        # 2. Hacer pull de la imagen delegando todo el trabajo al Daemon local.
        # Silenciamos la salida para no ensuciar el log. Si la imagen no ha cambiado, no descarga nada.
        docker pull "$image" > /dev/null 2>&1
        
        if [ $? -ne 0 ]; then
            echo "[$NOW] Warning: Could not pull/check remote image for '$name' ($image)."
            continue
        fi

        # 3. Obtener la ID (sha256) de la imagen de ese tag que está guardada ahora en el disco local
        latest_image_id=$(docker image inspect --format='{{.Id}}' "$image" 2>/dev/null)

        if [ -n "$latest_image_id" ]; then
            # 4. Si las IDs son diferentes, significa que el pull trajo una imagen nueva
            if [ "$running_image_id" != "$latest_image_id" ]; then
                echo "[$NOW] Update available for container '$name' (Image: $image)"
                send_email "$name" "$image" &
            else
                echo "[$NOW] Container '$name' is UP TO DATE."
            fi
        else
            echo "[$NOW] Warning: Could not resolve latest image ID for '$name'."
        fi
    done

    echo "[$NOW] Image check completed. Next check in $CHECK_INTERVAL seconds."
    sleep "$CHECK_INTERVAL"
done
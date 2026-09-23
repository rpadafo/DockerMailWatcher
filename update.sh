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

        # 1. Obtener la ID de la imagen que está corriendo localmente
        local_image_id=$(docker inspect --format='{{.Image}}' "$name" 2>/dev/null)
        [ -z "$local_image_id" ] && continue

        # 2. Obtener el RepoDigest o ID local de la imagen montada
        local_digest=$(docker image inspect "$local_image_id" --format='{{index .RepoDigests 0}}' 2>/dev/null)

        # 3. Obtener el Digest de la imagen remota mediante 'docker buildx imagetools'
        remote_digest=$(docker buildx imagetools inspect "$image" --raw 2>/dev/null | jq -r '.manifests[0].digest // .config.digest // empty' 2>/dev/null)

        # Si no pudimos obtener con buildx, intentamos la consulta directa del manifiesto (fallback)
        if [ -z "$remote_digest" ]; then
            remote_digest=$(docker manifest inspect "$image" 2>/dev/null | jq -r '.config.digest // empty' 2>/dev/null)
        fi

        # 4. Comprobación segura
        if [ -n "$remote_digest" ]; then
            # Comparamos si el digest remoto está contenido en la imagen o RepoDigest local
            is_match=$(docker image inspect "$local_image_id" 2>/dev/null | grep -i "$remote_digest")

            if [ -z "$is_match" ]; then
                echo "[$NOW] Update available for container '$name' (Image: $image)"
                send_email "$name" "$image" &
            else
                echo "[$NOW] Container '$name' is UP TO DATE."
            fi
        else
            echo "[$NOW] Could not fetch remote manifest for '$image'."
        fi
    done

    echo "[$NOW] Image check completed. Next check in $CHECK_INTERVAL seconds."
    sleep "$CHECK_INTERVAL"
done
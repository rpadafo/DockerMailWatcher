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

        # 1. Obtener la lista de hashes (RepoDigests) que el contenedor tiene registrados localmente
        local_repo_digests=$(docker inspect --format='{{json .RepoDigests}}' "$name" 2>/dev/null)
        
        # Si está vacío, intentamos sacarlo de la ID de la imagen base
        if [ "$local_repo_digests" = "[]" ] || [ -z "$local_repo_digests" ] || [ "$local_repo_digests" = "null" ]; then
            image_id=$(docker inspect --format='{{.Image}}' "$name" 2>/dev/null)
            local_repo_digests=$(docker image inspect --format='{{json .RepoDigests}}' "$image_id" 2>/dev/null)
        fi

        # 2. Consultar el Hash remoto de la imagen SIN descargarla usando Skopeo
        # (skopeo solo descarga un texto JSON de unos bytes)
        remote_digest=$(skopeo inspect --format '{{.Digest}}' "docker://$image" 2>/dev/null)

        # 3. Comprobación segura
        if [ -n "$remote_digest" ]; then
            if [ "$local_repo_digests" != "[]" ] && [ -n "$local_repo_digests" ] && [ "$local_repo_digests" != "null" ]; then
                # Si el hash remoto está en la lista de hashes locales, está actualizado
                if echo "$local_repo_digests" | grep -q "$remote_digest"; then
                    echo "[$NOW] Container '$name' is UP TO DATE."
                else
                    echo "[$NOW] Update available for container '$name' (Image: $image)"
                    send_email "$name" "$image" &
                fi
            else
                echo "[$NOW] Warning: No local RepoDigest for '$name'. Cannot compare safely."
            fi
        else
            echo "[$NOW] Warning: Could not fetch remote digest via Skopeo for '$name' ($image)."
        fi
    done

    echo "[$NOW] Image check completed. Next check in $CHECK_INTERVAL seconds."
    sleep "$CHECK_INTERVAL"
done
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

    # Obtener lista de contenedores y sus imágenes
    containers=$(docker ps --format '{{.Names}}|{{.Image}}')

    echo "$containers" | while IFS='|' read -r name image; do
        [ -z "$image" ] && continue

        # Normalizar el nombre de la imagen para Docker Hub si no incluye dominio
        full_image="$image"
        case "$full_image" in
            */*) ;;
            *) full_image="docker.io/library/$full_image" ;;
        esac

        # 1. Obtener el RepoDigest actual del contenedor local (ej. sha256:abc...)
        local_repo_digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$name" 2>/dev/null)

        # Si local_repo_digest está vacío, se busca a través de la ID de la imagen
        if [ -z "$local_repo_digest" ]; then
            image_id=$(docker inspect --format='{{.Image}}' "$name" 2>/dev/null)
            local_repo_digest=$(docker image inspect "$image_id" --format='{{index .RepoDigests 0}}' 2>/dev/null)
        fi

        # Si no tenemos RepoDigest local, saltamos
        if [ -z "$local_repo_digest" ]; then
            echo "[$NOW] Skipping '$name': No local RepoDigest found."
            continue
        fi

        # Extraer solo el hash SHA256 local
        local_hash=$(echo "$local_repo_digest" | sed -n 's/.*sha256:\([a-f0-9]\{64\}\).*/\1/p')

        # 2. Consultar el manifiesto remoto usando 'docker manifest inspect'
        export DOCKER_CLI_EXPERIMENTAL=enabled
        manifest_output=$(docker manifest inspect "$full_image" 2>/dev/null)

        if [ -z "$manifest_output" ]; then
            echo "[$NOW] Warning: Could not fetch remote manifest for '$name' ($image)."
            continue
        fi

        # 3. Comprobar si el hash local existe en la respuesta del manifiesto remoto
        if echo "$manifest_output" | grep -q "$local_hash"; then
            echo "[$NOW] Container '$name' is UP TO DATE."
        else
            echo "[$NOW] Update available for container '$name' (Image: $image)"
            send_email "$name" "$image" &
        fi
    done

    echo "[$NOW] Image check completed. Next check in $CHECK_INTERVAL seconds."
    sleep "$CHECK_INTERVAL"
done
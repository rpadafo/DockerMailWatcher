FROM alpine:latest

# Instalar dependencias necesarias y zona horaria
RUN apk add --no-cache docker-cli curl tzdata jq

WORKDIR /app

# Copiar el script al contenedor
COPY watcher.sh /app/watcher.sh
COPY update.sh /app/update.sh
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]
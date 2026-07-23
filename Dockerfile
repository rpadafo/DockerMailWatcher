FROM alpine:latest

# Instalar dependencias necesarias y zona horaria
RUN apk add --no-cache docker-cli curl tzdata

WORKDIR /app

# Copiar el script al contenedor
COPY watcher.sh /app/watcher.sh
RUN chmod +x /app/watcher.sh

ENTRYPOINT ["/app/watcher.sh"]
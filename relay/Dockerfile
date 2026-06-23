# Relay wss:// di World Order — immagine minimale Node.
FROM node:20-alpine

WORKDIR /app

# Installa solo le dipendenze di produzione (riusa la cache se package*.json non cambia).
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.js ./

# La porta arriva da $PORT (Render/Fly la impostano); default 8080 in locale.
ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]

FROM node:26.13.0-alpine
WORKDIR /app
RUN npm install --omit=dev express@5.3.0 >/dev/null
COPY server.js .
CMD ["node", "server.js"]

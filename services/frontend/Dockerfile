# Stage 1 — Build Angular
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./

# Installer Angular CLI globalement + dépendances du projet
RUN npm install -g @angular/cli@18 && npm ci --silent

COPY . .

RUN ng build --configuration=production

# Stage 2 — Nginx
FROM nginx:1.25-alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist/*/browser /usr/share/nginx/html

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
CMD ["/docker-entrypoint.sh"]

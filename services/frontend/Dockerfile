# ── Stage 1: Build Angular ────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Cache npm dependencies
COPY package.json package-lock.json ./
RUN npm ci --silent

# Copy source and build for production
COPY . .
RUN npm run build -- --configuration=production

# ── Stage 2: Serve with Nginx ─────────────────────────────────────────────────
FROM nginx:1.25-alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Angular app
COPY --from=builder /app/dist/*/browser /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

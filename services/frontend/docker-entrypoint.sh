#!/bin/sh

# Lire les variables d'environnement du conteneur
# et générer un fichier JavaScript que Angular peut lire

cat <<EOF > /usr/share/nginx/html/env.js
window.__ENV__ = {
  API_GATEWAY_URL: "${API_GATEWAY_URL:-http://localhost:30900}",
  KEYCLOAK_URL: "${KEYCLOAK_URL:-http://localhost:30818}"
};
EOF

echo "[ENTRYPOINT] env.js généré :"
cat /usr/share/nginx/html/env.js

# Démarrer Nginx
exec nginx -g "daemon off;"

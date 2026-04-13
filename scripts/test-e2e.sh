#!/bin/bash

# ============================================================
#  NexShop — Test End-to-End
#  Usage: chmod +x test-nexshop.sh && ./test-nexshop.sh
# ============================================================

NODE_IP="192.168.100.113"
GATEWAY="http://$NODE_IP:30900"
KEYCLOAK="http://$NODE_IP:30818"
REALM="spring-microservices-security-realm"
CLIENT_ID="spring-cloud-client"
CLIENT_SECRET="secret"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; }
info() { echo -e "${BLUE}▶ $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
separator() { echo -e "\n${BLUE}══════════════════════════════════════════${NC}"; }

check_http() {
  local label=$1
  local expected=$2
  local actual=$3
  local body=$4
  if [ "$actual" = "$expected" ]; then
    pass "$label → HTTP $actual"
    [ -n "$body" ] && echo "    $body"
  else
    fail "$label → HTTP $actual (attendu $expected)"
    [ -n "$body" ] && echo "    $body"
  fi
}

# ============================================================
separator
info "ÉTAPE 1 — Vérification des pods"
separator

ALL_RUNNING=true
while IFS= read -r line; do
  NAME=$(echo "$line" | awk '{print $1}')
  READY=$(echo "$line" | awk '{print $2}')
  STATUS=$(echo "$line" | awk '{print $3}')
  RESTARTS=$(echo "$line" | awk '{print $4}')
  if [ "$STATUS" = "Running" ] && [ "$READY" = "1/1" ]; then
    pass "$NAME ($RESTARTS restarts)"
  else
    fail "$NAME — STATUS: $STATUS READY: $READY"
    ALL_RUNNING=false
  fi
done < <(kubectl get pods -n nexshop --no-headers 2>/dev/null | grep -v "^$")

if [ "$ALL_RUNNING" = false ]; then
  warn "Certains pods ne sont pas prêts — le test continue quand même"
fi

# ============================================================
separator
info "ÉTAPE 2 — Création du client Keycloak"
separator

ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ]; then
  fail "Impossible d'obtenir le token admin Keycloak"
  exit 1
fi
pass "Token admin Keycloak obtenu"

# Créer l'utilisateur
USERNAME="john.doe.$(date +%s)"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$KEYCLOAK/admin/realms/$REALM/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\":\"$USERNAME\",
    \"enabled\":true,
    \"firstName\":\"John\",
    \"lastName\":\"Doe\",
    \"email\":\"john.doe@nexshop.com\",
    \"emailVerified\":true,
    \"requiredActions\":[],
    \"credentials\":[{\"type\":\"password\",\"value\":\"password123\",\"temporary\":false}]
  }")

if [ "$HTTP" = "201" ]; then
  pass "Utilisateur '$USERNAME' créé (HTTP 201)"
else
  warn "Utilisateur existe peut-être déjà (HTTP $HTTP) — on continue"
fi

# ============================================================
separator
info "ÉTAPE 3 — Login et obtention du token JWT"
separator

RESPONSE=$(curl -s -X POST "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&username=testuser&password=password")

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
  fail "Impossible d'obtenir le token JWT"
  echo "  Réponse: $RESPONSE"
  exit 1
fi
pass "Token JWT obtenu (expire dans $(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_in','?'))")s)"

# ============================================================
separator
info "ÉTAPE 4 — Création d'un produit"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$GATEWAY/api/product" \
  -d '{"name":"MacBook Pro M3","description":"Apple laptop","price":2499.99}')

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
check_http "POST /api/product" "201" "$HTTP" "$BODY"
SKU_CODE="macbook-pro-m3"

# ============================================================
separator
info "ÉTAPE 5 — Liste des produits"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$GATEWAY/api/product")

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
check_http "GET /api/product" "200" "$HTTP" "$COUNT produit(s) en base"

# ============================================================
separator
info "ÉTAPE 6 — Ajout de stock (inventory)"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$GATEWAY/api/inventory" \
  -d "{\"skuCode\":\"$SKU_CODE\",\"quantity\":50}")

HTTP=$(echo "$RESPONSE" | tail -1)
check_http "POST /api/inventory" "201" "$HTTP"

# ============================================================
separator
info "ÉTAPE 7 — Vérification du stock"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$GATEWAY/api/inventory?skuCode=$SKU_CODE&quantity=1")

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
check_http "GET /api/inventory?skuCode=$SKU_CODE&quantity=1" "200" "$HTTP" "En stock: $BODY"

# ============================================================
separator
info "ÉTAPE 8 — Passage d'une commande"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$GATEWAY/api/order" \
  -d "{
    \"skuCode\":\"$SKU_CODE\",
    \"price\":2499.99,
    \"quantity\":1,
    \"userDetails\":{
      \"email\":\"john.doe@nexshop.com\",
      \"firstName\":\"John\",
      \"lastName\":\"Doe\"
    }
  }")

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
check_http "POST /api/order" "201" "$HTTP" "$BODY"

# ============================================================
separator
info "ÉTAPE 9 — Vérification Frontend & Kafka UI"
separator

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:30200/")
check_http "Frontend :30200" "200" "$HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:30886/")
check_http "Kafka UI :30886" "200" "$HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY/actuator/health")
check_http "API Gateway health" "200" "$HTTP"

# ============================================================
separator
echo -e "\n${GREEN}  Test end-to-end terminé !${NC}\n"
separator

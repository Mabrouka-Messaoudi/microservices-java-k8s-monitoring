#!/bin/bash

# ============================================================
#  NexShop — Test End-to-End Backend
#  Usage: chmod +x test-nexshop.sh && ./test-nexshop.sh
# ============================================================

NODE_IP="192.168.100.113"
GATEWAY="http://$NODE_IP:30900"
KEYCLOAK="http://$NODE_IP:30818"
REALM="spring-microservices-security-realm"
CLIENT_ID="angular-client"

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
  local label=$1 expected=$2 actual=$3 body=$4
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

[ "$ALL_RUNNING" = false ] && warn "Certains pods ne sont pas prêts — le test continue quand même"

# ============================================================
separator
info "ÉTAPE 2 — Obtention du token JWT (user: mab)"
separator

RESPONSE=$(curl -s -X POST "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=$CLIENT_ID&username=mab&password=***REMOVED***&scope=openid")

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
  fail "Impossible d'obtenir le token JWT"
  echo "  Réponse: $RESPONSE"
  exit 1
fi

EXPIRES=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_in','?'))" 2>/dev/null)
pass "Token JWT obtenu pour 'mab' (expire dans ${EXPIRES}s)"

# Décoder les infos du token
EMAIL=$(echo "$TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -c "import sys,json; p=json.load(sys.stdin); print(p.get('email','?'))" 2>/dev/null)
FIRSTNAME=$(echo "$TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -c "import sys,json; p=json.load(sys.stdin); print(p.get('given_name','?'))" 2>/dev/null)
LASTNAME=$(echo "$TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -c "import sys,json; p=json.load(sys.stdin); print(p.get('family_name','?'))" 2>/dev/null)
pass "User: $FIRSTNAME $LASTNAME <$EMAIL>"

# ============================================================
separator
info "ÉTAPE 3 — Création d'un produit"
separator

SKU="test-sku-$(date +%s)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$GATEWAY/api/product" \
  -d "{\"name\":\"Test Product\",\"description\":\"Test description\",\"skuCode\":\"$SKU\",\"price\":99.99}")

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
check_http "POST /api/product" "201" "$HTTP" "$BODY"

# ============================================================
separator
info "ÉTAPE 4 — Liste des produits"
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
info "ÉTAPE 5 — Ajout de stock (inventory)"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$GATEWAY/api/inventory" \
  -d "{\"skuCode\":\"$SKU\",\"quantity\":50}")

HTTP=$(echo "$RESPONSE" | tail -1)
check_http "POST /api/inventory" "201" "$HTTP"

# ============================================================
separator
info "ÉTAPE 6 — Vérification du stock"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$GATEWAY/api/inventory?skuCode=$SKU&quantity=1")

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
check_http "GET /api/inventory?skuCode=$SKU&quantity=1" "200" "$HTTP" "En stock: $BODY"

# ============================================================
separator
info "ÉTAPE 7 — Passage d'une commande"
separator

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$GATEWAY/api/order" \
  -d "{
    \"skuCode\":\"$SKU\",
    \"price\":99.99,
    \"quantity\":1,
    \"userDetails\":{
      \"email\":\"$EMAIL\",
      \"firstName\":\"$FIRSTNAME\",
      \"lastName\":\"$LASTNAME\"
    }
  }")

HTTP=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
check_http "POST /api/order" "201" "$HTTP" "$BODY"

# ============================================================
separator
info "ÉTAPE 8 — Vérification des endpoints"
separator

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -k "https://$NODE_IP:30200/health")
check_http "Frontend HTTPS :30200/health" "200" "$HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:30886/")
check_http "Kafka UI :30886" "200" "$HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY/actuator/health")
check_http "API Gateway health" "200" "$HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:30818/realms/$REALM/.well-known/openid-configuration")
check_http "Keycloak OIDC :30818" "200" "$HTTP"

# ============================================================
separator
echo -e "\n${GREEN}  ✅ Test end-to-end NexShop terminé !${NC}\n"
separator

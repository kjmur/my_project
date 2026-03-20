#!/usr/bin/env bash
set -euo pipefail

ROUTER_USER="admin"
ROUTER_HOST="192.168.4.34"

WG_IF="wg0"
WG_PORT="51820"
SERVER_WG_ADDR="10.10.10.1/24"
CLIENT_WG_ADDR="10.10.10.2/24"
CLIENT_ALLOWED_ADDR="10.10.10.2/32"

CLIENT_NAME="client"
CLIENT_PRIV="./${CLIENT_NAME}_private.key"
CLIENT_PUB="./${CLIENT_NAME}_public.key"
CLIENT_CONF="./${CLIENT_NAME}.conf"

echo "[*] Creating WireGuard interface on MikroTik..."
ssh -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_HOST}" \
"/interface wireguard add name=${WG_IF} listen-port=${WG_PORT}"

echo "[*] Adding IP address to WireGuard interface..."
ssh -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_HOST}" \
"/ip address add address=${SERVER_WG_ADDR} interface=${WG_IF}"

echo "[*] Reading MikroTik WireGuard public key..."
SERVER_PUB=$(
  ssh -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_HOST}" \
  "/interface wireguard print detail without-paging where name=${WG_IF}" \
  | sed -n 's/.*public-key=\"\([^\"]*\)\".*/\1/p'
)

echo "[*] MikroTik public key: ${SERVER_PUB}"

echo "[*] Generating client keys..."
wg genkey | tee "${CLIENT_PRIV}" | wg pubkey > "${CLIENT_PUB}"
chmod 600 "${CLIENT_PRIV}" "${CLIENT_PUB}"

CLIENT_PRIVATE_KEY=$(cat "${CLIENT_PRIV}")
CLIENT_PUBLIC_KEY=$(cat "${CLIENT_PUB}")

echo "[*] Adding client peer to MikroTik..."
ssh -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_HOST}" \
"/interface wireguard peers add interface=${WG_IF} public-key=\"${CLIENT_PUBLIC_KEY}\" allowed-address=${CLIENT_ALLOWED_ADDR} persistent-keepalive=25s"

echo "[*] Writing client config..."
cat > "${CLIENT_CONF}" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_WG_ADDR}
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${ROUTER_HOST}:${WG_PORT}
AllowedIPs = 10.10.10.0/24
PersistentKeepalive = 25
EOF

echo "[+] Done."
echo "[+] Client config written to: ${CLIENT_CONF}"

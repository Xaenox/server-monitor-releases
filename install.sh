#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-xaenox/server-monitor-releases}"
VERSION="${VERSION:-latest}"
BASE_URL="https://github.com/${REPO}/releases"

usage() {
    cat <<'EOF'
Usage:
  install.sh dashboard [options]
  install.sh agent [options]

Dashboard options:
  --tailscale-serve        Run "tailscale serve" after dashboard install.
  --tailscale-port PORT    Tailscale Serve HTTPS port. Default: 443, or 8443 if 443 is already in use.
  --http-addr ADDR         Dashboard bind address. Default: first free 127.0.0.1:8080..8089.
  --public-url URL         Public dashboard URL. Default: https://<tailscale-dns-name> when available.
  --username USER          Dashboard username. Default: admin.

Agent options:
  --dashboard-url URL      Dashboard URL. Required unless DASHBOARD_URL is set.
  --interval SECONDS       Collection interval. Default: 30.

Shared options:
  --version VERSION        Release version. Default: latest.
  --repo OWNER/REPO        Release repo. Default: xaenox/server-monitor-releases.
  -h, --help               Show this help.

Examples:
  curl -fsSLo /tmp/server-monitor-install.sh https://github.com/Xaenox/server-monitor-releases/releases/latest/download/install.sh
  sudo bash /tmp/server-monitor-install.sh dashboard --tailscale-serve
  sudo bash /tmp/server-monitor-install.sh agent --dashboard-url https://server-monitor.example.ts.net
EOF
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: run as root, for example: curl ... | sudo bash -s -- ..." >&2
        exit 1
    fi
}

read_tty() {
    local prompt="$1"
    local var_name="$2"
    if [ ! -r /dev/tty ]; then
        echo "ERROR: interactive input requires a TTY. Set ${var_name} in the environment instead." >&2
        exit 1
    fi
    read -rp "$prompt" "$var_name" </dev/tty
}

read_secret_tty() {
    local prompt="$1"
    local var_name="$2"
    if [ ! -r /dev/tty ]; then
        echo "ERROR: secret input requires a TTY. Set ${var_name} in the environment instead." >&2
        exit 1
    fi
    read -rsp "$prompt" "$var_name" </dev/tty
    echo >/dev/tty
}

download_url() {
    local asset="$1"
    if [ "$VERSION" = "latest" ]; then
        echo "${BASE_URL}/latest/download/${asset}"
    else
        echo "${BASE_URL}/download/${VERSION}/${asset}"
    fi
}

port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk '{print $4}' | grep -Eq "(:|\\])${port}$"
    else
        return 1
    fi
}

default_http_addr() {
    local port
    for port in 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089; do
        if ! port_in_use "$port"; then
            printf '127.0.0.1:%s\n' "$port"
            return 0
        fi
    done
    echo "ERROR: no free port found in 8080..8089; pass --http-addr manually." >&2
    exit 1
}

tailscale_dns_url() {
    local https_port="${1:-443}"
    if ! command -v tailscale >/dev/null 2>&1; then
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        tailscale status --json 2>/dev/null | TAILSCALE_HTTPS_PORT="$https_port" python3 -c '
import json, sys
import os
port = os.environ.get("TAILSCALE_HTTPS_PORT", "443")
try:
    dns = json.load(sys.stdin).get("Self", {}).get("DNSName", "")
except Exception:
    dns = ""
dns = dns.rstrip(".")
if dns:
    suffix = "" if port == "443" else ":" + port
    print("https://" + dns + suffix)
'
    fi
}

default_tailscale_port() {
    if port_in_use 443; then
        printf '8443\n'
    else
        printf '443\n'
    fi
}

install_dashboard() {
    local http_addr="" public_url="" username="admin" tailscale_serve=0 tailscale_port=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --tailscale-serve) tailscale_serve=1; shift ;;
            --tailscale-port) tailscale_port="${2:?missing value for --tailscale-port}"; shift 2 ;;
            --http-addr) http_addr="${2:?missing value for --http-addr}"; shift 2 ;;
            --public-url) public_url="${2:?missing value for --public-url}"; shift 2 ;;
            --username) username="${2:?missing value for --username}"; shift 2 ;;
            --version) VERSION="${2:?missing value for --version}"; shift 2 ;;
            --repo) REPO="${2:?missing value for --repo}"; BASE_URL="https://github.com/${REPO}/releases"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "ERROR: unknown dashboard option: $1" >&2; usage; exit 1 ;;
        esac
    done

    http_addr="${http_addr:-$(default_http_addr)}"
    if [ "$tailscale_serve" = "1" ]; then
        tailscale_port="${tailscale_port:-$(default_tailscale_port)}"
    else
        tailscale_port="${tailscale_port:-443}"
    fi
    public_url="${public_url:-$(tailscale_dns_url "$tailscale_port")}"

    echo "Dashboard bind address: ${http_addr}"
    if [ -n "$public_url" ]; then
        echo "Dashboard public URL: ${public_url}"
    else
        echo "Dashboard public URL: unset"
    fi

    if [ -z "${ADMIN_PASSWORD_HASH:-}" ] && [ -z "${ADMIN_PASSWORD:-}" ]; then
        read_secret_tty "Admin password: " ADMIN_PASSWORD
        export ADMIN_PASSWORD
    fi

    REPO="$REPO" \
    VERSION="$VERSION" \
    HTTP_ADDR="$http_addr" \
    PUBLIC_URL="$public_url" \
    USERNAME="$username" \
    bash <(curl -fsSL "$(download_url install-dashboard.sh)")

    unset ADMIN_PASSWORD || true

    if [ "$tailscale_serve" = "1" ]; then
        if ! command -v tailscale >/dev/null 2>&1; then
            echo "ERROR: --tailscale-serve requested, but tailscale is not installed." >&2
            exit 1
        fi
        echo "Configuring Tailscale Serve for http://${http_addr}"
        if [ "$tailscale_port" = "443" ]; then
            tailscale serve --bg --yes "http://${http_addr}"
        else
            tailscale serve --bg --yes --https="$tailscale_port" "http://${http_addr}"
        fi
        tailscale serve status
    fi

    echo
    echo "Dashboard status:"
    systemctl status server-monitor --no-pager || true
    echo
    echo "Health:"
    curl -fsS "http://${http_addr}/health"
    echo
}

install_agent() {
    local dashboard_url="${DASHBOARD_URL:-}" interval="${COLLECT_INTERVAL_SEC:-30}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dashboard-url) dashboard_url="${2:?missing value for --dashboard-url}"; shift 2 ;;
            --interval) interval="${2:?missing value for --interval}"; shift 2 ;;
            --version) VERSION="${2:?missing value for --version}"; shift 2 ;;
            --repo) REPO="${2:?missing value for --repo}"; BASE_URL="https://github.com/${REPO}/releases"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "ERROR: unknown agent option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if [ -z "$dashboard_url" ]; then
        read_tty "Dashboard URL: " dashboard_url
    fi
    if [ -z "${AGENT_TOKEN:-}" ]; then
        read_secret_tty "Agent token: " AGENT_TOKEN
        export AGENT_TOKEN
    fi

    REPO="$REPO" \
    VERSION="$VERSION" \
    DASHBOARD_URL="$dashboard_url" \
    COLLECT_INTERVAL_SEC="$interval" \
    bash <(curl -fsSL "$(download_url install-agent.sh)")

    unset AGENT_TOKEN || true

    echo
    echo "Agent status:"
    systemctl status server-monitor-agent --no-pager || true
}

main() {
    local mode="${1:-}"
    case "$mode" in
        -h|--help|"") usage ;;
        dashboard) require_root; shift; install_dashboard "$@" ;;
        agent) require_root; shift; install_agent "$@" ;;
        *) echo "ERROR: unknown mode: $mode" >&2; usage; exit 1 ;;
    esac
}

main "$@"

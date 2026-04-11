#!/bin/bash
# install.sh - 自动检测系统架构并从中南大学 VPN 门户下载最新客户端
# Auto-detect machine architecture and download the latest CSU VPN client
# Download page: https://vpn.csu.edu.cn/portal/#/down_client_new?moreClient=1

set -e

PORTAL_URL="https://vpn.csu.edu.cn"
DOWNLOAD_PAGE="${PORTAL_URL}/portal/#/down_client_new?moreClient=1"
TMP_DIR=$(mktemp -d /tmp/csu-vpn-XXXXXX)

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Detect the architecture and map to AnyConnect client type
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "linux64"
            ;;
        aarch64|arm64)
            echo "linux-arm64"
            ;;
        armv7*|armhf)
            echo "linux-arm"
            ;;
        i386|i686)
            echo "linux"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Try to get download URL from portal REST API (common patterns for VPN portals)
fetch_url_from_api() {
    local arch_type="$1"
    local endpoints=(
        "/portal/api/v1/download/client?os=linux&arch=${arch_type}"
        "/portal/api/v2/client/download?platform=linux&arch=${arch_type}"
        "/portal/api/download/linux/${arch_type}"
        "/portal/download/${arch_type}"
    )

    for endpoint in "${endpoints[@]}"; do
        local response
        response=$(curl -sf --connect-timeout 10 "${PORTAL_URL}${endpoint}" 2>/dev/null) || continue

        # Extract URL from a JSON "url", "download_url", or "file_url" field (POSIX sed)
        local file_url
        file_url=$(printf '%s' "$response" \
            | sed -n 's/.*"\(url\|download_url\|file_url\)" *: *"\([^"]*\)".*/\2/p' \
            | head -1)
        if [ -n "$file_url" ]; then
            echo "$file_url"
            return 0
        fi
    done

    return 1
}

# Fallback: scrape the portal's frontend JS bundles to find a direct download link
fetch_url_from_portal_js() {
    local arch_type="$1"

    local index_html
    index_html=$(curl -sf --connect-timeout 10 "${PORTAL_URL}/portal/" 2>/dev/null) || return 1

    # Collect every JS bundle referenced in the page
    local js_files
    js_files=$(printf '%s' "$index_html" | grep -oP 'src="\K[^"]+\.js' | head -10)

    for js_file in $js_files; do
        # Handle both absolute and relative paths
        local js_url
        if [[ "$js_file" == http* ]]; then
            js_url="$js_file"
        else
            js_url="${PORTAL_URL}/portal/${js_file}"
        fi

        local js_content
        js_content=$(curl -sf --connect-timeout 10 "$js_url" 2>/dev/null) || continue

        # Look for anyconnect installer URLs embedded in the bundle (.sh / .bin / .run)
        local found_url
        found_url=$(printf '%s' "$js_content" \
            | grep -oE "(https?://[^'\"[:space:]]*anyconnect-${arch_type}[^'\"[:space:]]*\.(sh|bin|run))" \
            | head -1)
        if [ -n "$found_url" ]; then
            echo "$found_url"
            return 0
        fi
    done

    return 1
}

# Attempt to download the installer and run it
download_and_install() {
    local arch_type="$1"
    local dest_file="${TMP_DIR}/vpn_install.sh"

    echo "Detected architecture: $(uname -m) → client type: ${arch_type}"
    echo "Fetching latest client from ${PORTAL_URL} ..."

    local download_url=""

    # 1. Try portal REST API
    download_url=$(fetch_url_from_api "$arch_type" 2>/dev/null) || true

    # 2. Fall back to scraping JS bundles
    if [ -z "$download_url" ]; then
        download_url=$(fetch_url_from_portal_js "$arch_type" 2>/dev/null) || true
    fi

    if [ -z "$download_url" ]; then
        echo ""
        echo "Error: Could not automatically locate the download URL."
        echo "Please visit the download page and install manually:"
        echo "  ${DOWNLOAD_PAGE}"
        echo ""
        echo "Select the package that matches your architecture: ${arch_type}"
        exit 1
    fi

    # Make relative URLs absolute
    if [[ "$download_url" != http* ]]; then
        download_url="${PORTAL_URL}${download_url}"
    fi

    echo "Downloading: ${download_url}"
    if ! curl -L --progress-bar -o "$dest_file" "$download_url"; then
        echo "Error: Download failed."
        exit 1
    fi

    chmod +x "$dest_file"
    echo "Running installer..."
    sh "$dest_file"
    echo "Installation complete."
}

main() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "Error: This script only supports Linux."
        exit 1
    fi

    if [ "$EUID" -ne 0 ]; then
        echo "Error: Please run as root."
        echo "  sudo $0"
        exit 1
    fi

    if ! command -v curl > /dev/null 2>&1; then
        echo "Error: curl is required but not installed."
        echo "  Install it with: sudo apt install curl   (Debian/Ubuntu)"
        echo "                or: sudo yum install curl   (RHEL/CentOS)"
        exit 1
    fi

    local arch_type
    arch_type=$(detect_arch)

    if [ -z "$arch_type" ]; then
        echo "Error: Unsupported architecture: $(uname -m)"
        echo "Please visit ${DOWNLOAD_PAGE} to download the appropriate client manually."
        exit 1
    fi

    download_and_install "$arch_type"
}

main

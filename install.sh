#!/bin/bash
# install.sh - 自动检测系统架构并从中南大学 VPN 门户下载最新 aTrust 客户端
# Auto-detect machine architecture and download the latest CSU VPN aTrust client
# Download page: https://vpn.csu.edu.cn/portal/#/down_client_new?moreClient=1

set -e

PORTAL_URL="https://vpn.csu.edu.cn"
DOWNLOAD_PAGE="${PORTAL_URL}/portal/#/down_client_new?moreClient=1"
TMP_DIR=$(mktemp -d /tmp/csu-vpn-XXXXXX)

# Known stable client name and version (aTrust for Linux, not limited to Ubuntu)
ATRUST_CLIENT="aTrust_ubuntu"
ATRUST_STABLE_VERSION="2.5.16.30"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Detect the CPU architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*|armhf)
            echo "arm"
            ;;
        i386|i686)
            echo "x86"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Detect the Linux distribution family and preferred package format
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID_LIKE $ID" in
            *debian*|*ubuntu*)
                echo "deb"
                return
                ;;
            *rhel*|*centos*|*fedora*|*suse*)
                echo "rpm"
                return
                ;;
        esac
    fi
    # Final fallback: check for package managers directly
    if command -v dpkg > /dev/null 2>&1; then
        echo "deb"
    elif command -v rpm > /dev/null 2>&1; then
        echo "rpm"
    else
        echo "sh"
    fi
}

# Install the downloaded package using the appropriate package manager
install_package() {
    local pkg_file="$1"
    local pkg_fmt="$2"

    case "$pkg_fmt" in
        deb)
            echo "Installing .deb package..."
            dpkg -i "$pkg_file" || apt-get install -f -y
            ;;
        rpm)
            echo "Installing .rpm package..."
            rpm -Uvh "$pkg_file"
            ;;
        *)
            echo "Running installer script..."
            chmod +x "$pkg_file"
            sh "$pkg_file"
            ;;
    esac
}

# Try to get a download URL from portal REST API (Sangfor/aTrust common patterns)
fetch_url_from_api() {
    local client="$1"
    local endpoints=(
        "/portal/api/v1/download/client?name=${client}&os=linux"
        "/portal/api/v2/client/download?name=${client}&platform=linux"
        "/portal/api/download/client?clientType=${client}"
        "/portal/api/client/download?type=${client}"
    )

    for endpoint in "${endpoints[@]}"; do
        local response
        response=$(curl -sf --connect-timeout 10 "${PORTAL_URL}${endpoint}" 2>/dev/null) || continue

        # Extract URL from common JSON fields (POSIX sed)
        local file_url
        file_url=$(printf '%s' "$response" \
            | sed -n 's/.*"\(url\|download_url\|file_url\|downloadUrl\)" *: *"\([^"]*\)".*/\2/p' \
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
    local client="$1"

    local index_html
    index_html=$(curl -sf --connect-timeout 10 "${PORTAL_URL}/portal/" 2>/dev/null) || return 1

    # Collect JS bundle paths referenced in the page
    local js_files
    js_files=$(printf '%s' "$index_html" \
        | grep -oE 'src="[^"]+\.js"' \
        | sed 's/src="//;s/"//' \
        | head -10)

    for js_file in $js_files; do
        local js_url
        if printf '%s' "$js_file" | grep -q '^http'; then
            js_url="$js_file"
        else
            js_url="${PORTAL_URL}/portal/${js_file}"
        fi

        local js_content
        js_content=$(curl -sf --connect-timeout 10 "$js_url" 2>/dev/null) || continue

        # Look for aTrust installer URLs (.deb / .rpm / .sh / .bin / .run)
        local found_url
        found_url=$(printf '%s' "$js_content" \
            | grep -oE "https?://[^'\"[:space:]]*${client}[^'\"[:space:]]*\.(deb|rpm|sh|bin|run)" \
            | head -1)
        if [ -n "$found_url" ]; then
            echo "$found_url"
            return 0
        fi
    done

    return 1
}

# Build candidate download URLs using known Sangfor portal path conventions
candidate_urls() {
    local client="$1"
    local version="$2"
    local pkg_fmt="$3"
    local arch="$4"

    local ver_nodot
    ver_nodot=$(printf '%s' "$version" | tr -d '.')

    # Common Sangfor/aTrust portal download path patterns
    printf '%s\n' \
        "${PORTAL_URL}/portal/download/${client}/${version}/${client}_${version}.${pkg_fmt}" \
        "${PORTAL_URL}/portal/download/${client}/${version}/${client}_${version}_${arch}.${pkg_fmt}" \
        "${PORTAL_URL}/portal/download/${client}/${version}/${client}-${version}.${pkg_fmt}" \
        "${PORTAL_URL}/portal/download/${client}/${version}/${client}-${version}-${arch}.${pkg_fmt}" \
        "${PORTAL_URL}/download/${client}/${version}/${client}_${version}.${pkg_fmt}" \
        "${PORTAL_URL}/download/${client}/${version}/${client}_${version}_${arch}.${pkg_fmt}" \
        "${PORTAL_URL}/portal/api/download?name=${client}&version=${version}" \
        "${PORTAL_URL}/portal/clientdownload?type=${client}&version=${version}"
}

# Try each candidate URL and return the first that responds with a non-error HTTP status
probe_candidate_urls() {
    local client="$1"
    local version="$2"
    local pkg_fmt="$3"
    local arch="$4"

    while IFS= read -r url; do
        local http_code
        http_code=$(curl -sI --connect-timeout 8 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null) || continue
        case "$http_code" in
            200|301|302)
                echo "$url"
                return 0
                ;;
        esac
    done < <(candidate_urls "$client" "$version" "$pkg_fmt" "$arch")

    return 1
}

# Attempt to locate, download, and install the aTrust client
download_and_install() {
    local arch="$1"
    local pkg_fmt="$2"

    echo "Detected architecture : $(uname -m) (${arch})"
    echo "Detected package format: ${pkg_fmt}"
    echo "Target client         : ${ATRUST_CLIENT} v${ATRUST_STABLE_VERSION}"
    echo "Fetching download URL from ${PORTAL_URL} ..."

    local download_url=""
    local ext="$pkg_fmt"

    # 1. Try portal REST API
    download_url=$(fetch_url_from_api "$ATRUST_CLIENT" 2>/dev/null) || true

    # 2. Fall back to scraping JS bundles
    if [ -z "$download_url" ]; then
        download_url=$(fetch_url_from_portal_js "$ATRUST_CLIENT" 2>/dev/null) || true
    fi

    # 3. Fall back to probing known URL patterns
    if [ -z "$download_url" ]; then
        download_url=$(probe_candidate_urls "$ATRUST_CLIENT" "$ATRUST_STABLE_VERSION" "$pkg_fmt" "$arch" 2>/dev/null) || true
    fi

    if [ -z "$download_url" ]; then
        echo ""
        echo "Error: Could not automatically locate the download URL."
        echo "Please visit the download page and install manually:"
        echo "  ${DOWNLOAD_PAGE}"
        echo ""
        echo "Look for '${ATRUST_CLIENT}' under the Linux section."
        exit 1
    fi

    # Make relative URLs absolute
    if ! printf '%s' "$download_url" | grep -q '^http'; then
        download_url="${PORTAL_URL}${download_url}"
    fi

    # Determine file extension from URL if available
    local url_ext
    url_ext=$(printf '%s' "$download_url" | grep -oE '\.(deb|rpm|sh|bin|run)$') || true
    if [ -n "$url_ext" ]; then
        ext="${url_ext#.}"
    fi

    local dest_file="${TMP_DIR}/vpn_install.${ext}"
    echo "Downloading: ${download_url}"
    if ! curl -L --progress-bar -o "$dest_file" "$download_url"; then
        echo "Error: Download failed."
        exit 1
    fi

    install_package "$dest_file" "$ext"
    echo "Installation complete."
}

main() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "Error: This script only supports Linux."
        exit 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: Please run as root."
        echo "  sudo $0"
        exit 1
    fi

    if ! command -v curl > /dev/null 2>&1; then
        echo "Error: curl is required but not installed."
        echo "  Install it with: sudo apt install curl   (Debian/Ubuntu)"
        echo "                or: sudo yum install curl   (RHEL/CentOS/Fedora)"
        exit 1
    fi

    local arch
    arch=$(detect_arch)

    if [ -z "$arch" ]; then
        echo "Error: Unsupported architecture: $(uname -m)"
        echo "Please visit ${DOWNLOAD_PAGE} to download the appropriate client manually."
        exit 1
    fi

    local pkg_fmt
    pkg_fmt=$(detect_distro)

    download_and_install "$arch" "$pkg_fmt"
}

main

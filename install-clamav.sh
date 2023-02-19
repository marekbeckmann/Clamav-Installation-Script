#!/bin/bash

# Clamav install script for version 1.0.1

shopt -s inherit_errexit nullglob
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
WARN="${DGN}⚠${CL}"

CONFIG_FILE="config.ini"
CONFIG_FILE="$(realpath "${CONFIG_FILE}")"
CMAKE_TARGET_VERSION="3.25.2"
CLAMAV_TARGET_VERSION="1.0.1"

function backupConfigs() {
    cp -pr --archive "$1" "$1"-COPY-"$(date +"%m-%d-%Y")" >/dev/null 2>&1
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_warn() {
    local msg="$1"
    echo -e "${BFR} ${WARN} ${DGN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function errorhandler() {
    msg_error "$1"
    exit 1
}

function getIni() {
    startsection="$1"
    endsection="$2"
    output="$(awk "/$startsection/{ f = 1; next } /$endsection/{ f = 0 } f" "${CONFIG_FILE}")" || errorhandler "Failed to get config from ${CONFIG_FILE}"
}

function removeExistingClamav() {
    msg_info "Removing existing Clamav"
    clamav_version="$(clamscan --version 2>/dev/null)"
    apt-get remove --purge clamav -y >/dev/null 2>&1
    apt-get remove --purge clamav-daemon -y >/dev/null 2>&1
    apt-get remove --purge clamav-freshclam -y >/dev/null 2>&1
    apt-get remove --purge clamav* -y >/dev/null 2>&1
    apt-get remove --purge libclamav* -y >/dev/null 2>&1
    rm -rf /usr/local/share/clamav >/dev/null 2>&1
    rm -rf /usr/local/share/doc/clamav >/dev/null 2>&1
    rm -rf /usr/local/clamav >/dev/null 2>&1
    rm -rf /usr/local/etc/clamav >/dev/null 2>&1
    rm -rf /usr/local/etc/freshclam.conf >/dev/null 2>&1
    rm -rf /usr/local/etc/clamd.conf >/dev/null 2>&1
    rm -rf /usr/local/etc/clamd.conf.sample >/dev/null 2>&1
    rm -rf /usr/local/etc/freshclam.conf.sample >/dev/null 2>&1
    rm -rf /usr/local/etc/logrotate.d/clamav >/dev/null 2>&1
    rm -rf /usr/local/src/clamav* >/dev/null 2>&1
    rm -rf /usr/local/src/freshclam* >/dev/null 2>&1
    rm -rf /usr/local/src/libclamav* >/dev/null 2>&1
    rm -rf /usr/local/src/libfreshclam* >/dev/null 2>&1
    clamscan_cmd="$(clamscan --version 2>/dev/null)"
    if [[ "$?" -ne 0 ]]; then
        if [[ -z "${clamav_version}" ]]; then
            msg_ok "ClamaV not installed on system"
        else
            msg_ok "${clamav_version} removed from system"
        fi
    else
        errorhandler "Unable to remove Clamav from system"
    fi
}

function installDependencies() {
    msg_info "Installing basic dependencies (This will take a while)"
    apt-get update >/dev/null 2>&1
    apt-get fu∏ll-upgrade -y >/dev/null 2>&1
    apt-get install -y build-essential libssl-dev libcurl4-openssl-dev libxml2-dev libbz2-dev libpcre3-dev liblzma-dev libyara-dev libtool automake autoconf pkg-config gcc make pkg-config python3 python3-pip python3-pytest valgrind check libbz2-dev libcurl4-openssl-dev libjson-c-dev libmilter-dev \
        libncurses5-dev libpcre2-dev libssl-dev libxml2-dev zlib1g-dev gcc libssl-dev python3-pip >/dev/null 2>&1 || errorhandler "Failed to install dependencies"
    msg_ok "Basic dependencies installed"

    msg_info "Installing CMAKE v${CMAKE_TARGET_VERSION} (This will take a while)"
    cmake_installed_version="$(cmake --version 2>/dev/null | grep version | cut -d " " -f3)"
    if [[ "${cmake_installed_version}" != "${CMAKE_TARGET_VERSION}" ]]; then
        wget https://github.com/Kitware/CMake/releases/download/v"${CMAKE_TARGET_VERSION}"/cmake-"${CMAKE_TARGET_VERSION}".tar.gz -O /tmp/cmake-"${CMAKE_TARGET_VERSION}".tar.gz >/dev/null 2>&1
        tar xvf /tmp/cmake-"${CMAKE_TARGET_VERSION}".tar.gz -C /tmp >/dev/null 2>&1
        cd /tmp/cmake-"${CMAKE_TARGET_VERSION}" || errorhandler "Failed to cd into /tmp/cmake-${CMAKE_TARGET_VERSION}"
        ./bootstrap >/dev/null 2>&1
        gmake -j"$(nproc)" >/dev/null 2>&1
        make install >/dev/null 2>&1
        cmake_installed_version="$(cmake --version 2>/dev/null | grep version | cut -d " " -f3)"
        if [[ "${cmake_installed_version}" == "${CMAKE_TARGET_VERSION}" ]]; then
            msg_ok "CMAKE v${cmake_installed_version} installed"
        else
            errorhandler "Failed to install CMAKE v${CMAKE_TARGET_VERSION}"
        fi
    else
        msg_ok "CMAKE v${CMAKE_TARGET_VERSION} already installed"
    fi
    msg_info "Installing Rust"
    curl https://sh.rustup.rs -sSf | sh -s -- -y >/dev/null 2>&1
    source "$HOME"/.cargo/env >/dev/null 2>&1
    export PATH:"$PATH":/root/.cargo/bin >/dev/null 2>&1
    rust_version="$(rustc --version 2>/dev/null | cut -d " " -f2)"
    msg_ok "Rust v${rust_version} installed"
}

function installClamav() {
    msg_info "Installing Clamav v${CLAMAV_TARGET_VERSION}"
    useradd -r -M -d /var/lib/clamav -s /bin/false -c "Clam Antivirus" clamav >/dev/null 2>&1
    wget https://www.clamav.net/downloads/production/clamav-"$CLAMAV_TARGET_VERSION".linux.x86_64.deb -O /tmp/clamav-"$CLAMAV_TARGET_VERSION".linux.x86_64.deb >/dev/null 2>&1
    apt install /tmp/clamav-"$CLAMAV_TARGET_VERSION".linux.x86_64.deb -y >/dev/null 2>&1
    getIni "START_FRESHCLAMCONF" "END_FRESHCLAMCONF"
    printf "%s" "$output" | tee /usr/local/etc/freshclam.conf >/dev/null 2>&1
    getIni "START_CLAMDCONF" "END_CLAMDCONF"
    printf "%s" "$output" | tee /usr/local/etc/clamd.conf >/dev/null 2>&1
    touch /var/run/clamav/clamd.ctl >/dev/null 2>&1
    chown clamav:clamav /var/run/clamav/clamd.ctl >/dev/null 2>&1
    mkdir -p /var/log/clamav/ /var/lib/clamav /var/run/clamav/ >/dev/null 2>&1
    chown -R clamav: /var/log/clamav/ /var/lib/clamav /var/run/clamav/ >/dev/null 2>&1
    freshclam >/dev/null 2>&1
    sudo -u clamav freshclam >/dev/null 2>&1
    getIni "START_FRESHCLAM_SERVICE" "END_FRESHCLAM_SERVICE"
    printf "%s" "$output" | tee /etc/systemd/system/clamav-freshclam.service >/dev/null 2>&1
    getIni "START_CLAMD_SERVICE" "END_CLAMD_SERVICE"
    printf "%s" "$output" | tee /etc/systemd/system/clamav-daemon.service >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable --now clamav-daemon >/dev/null 2>&1
    systemctl enable --now clamav-freshclam >/dev/null 2>&1
    systemctl restart clamav-daemon >/dev/null 2>&1
    systemctl restart clamav-freshclam >/dev/null 2>&1
    if [[ "$(systemctl is-active clamav-daemon)" == "active" ]]; then
        msg_ok "Clamd is running"
    else
        msg_warn "Clamd is not running"
    fi
    if [[ "$(systemctl is-active clamav-freshclam)" == "active" ]]; then
        msg_ok "Freshclam is running"
    else
        msg_warn "Freshclam is not running"
    fi
    clamav_installed_version="$(clamscan --version 2>/dev/null)"
    msg_ok "${clamav_installed_version} installed"
}

function testingClamav() {
    msg_info "Testing Clamscan with EICAR (This might take a while)"
    sleep 10
    wget https://www.eicar.org/download/eicar.com -O /tmp/eicar.com >/dev/null 2>&1
    clamscan_result="$(clamscan --no-summary --infected /tmp/eicar.com 2>/dev/null | grep FOUND)"
    if [[ -n "$clamscan_result" ]]; then
        msg_ok "Clamscan appears to be working"
    else
        msg_error "Clamscan is not working"
    fi
    clamscand_result="$(clamdscan --no-summary --infected /tmp/eicar.com 2>/dev/null | grep FOUND)"
    if [[ -n "$clamscand_result" ]]; then
        msg_ok "Clamdscan appears to be working"
    else
        msg_error "Clamdscan is not working"
    fi
}

function main() {
    removeExistingClamav
    installDependencies
    installClamav
    testingClamav
}
main "$@"

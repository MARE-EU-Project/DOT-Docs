#!/usr/bin/env bash
# Install the DOT CLI in the current user's local bin directory.
set -euo pipefail

supports_package_install() (
    [[ -r /etc/os-release ]] || return 1
    # shellcheck source=/dev/null
    source /etc/os-release
    [[ "${ID:-}" = ubuntu && "${VERSION_ID:-}" = 26.04 ]]
)

install_prerequisites() {
    local -a packages=() apt_command=(apt-get)
    command -v git >/dev/null 2>&1 || packages+=(git)
    command -v go >/dev/null 2>&1 || packages+=(golang-go)
    if [[ "$(dpkg-query -W -f='${db:Status-Status}' ca-certificates 2>/dev/null || true)" != installed ]]; then
        packages+=(ca-certificates)
    fi
    if (( ${#packages[@]} == 0 )); then
        return 0
    fi

    if ! supports_package_install || ! command -v apt-get >/dev/null 2>&1; then
        printf 'Install these packages before retrying on this system.\n  %s\n' "${packages[*]}" >&2
        printf 'Git installation https://git-scm.com/install/linux\n' >&2
        printf 'Go installation https://go.dev/doc/install\n' >&2
        return 1
    fi
    if (( EUID != 0 )); then
        if ! command -v sudo >/dev/null 2>&1; then
            printf 'Ask an administrator to install these Ubuntu packages.\n  %s\n' "${packages[*]}" >&2
            return 1
        fi
        apt_command=(sudo apt-get)
    fi

    printf 'Installing Ubuntu prerequisites %s\n' "${packages[*]}"
    if ! "${apt_command[@]}" update </dev/null || ! "${apt_command[@]}" install -y -- "${packages[@]}" </dev/null; then
        printf 'Ubuntu prerequisite installation failed. Check apt and sudo, then run the installer again.\n' >&2
        return 1
    fi
}

main() {
    local cli_module='github.com/MARE-EU-Project/DOT-CLI'
    local private_scope='github.com/MARE-EU-Project/*'
    local version="${CLI_VERSION:-latest}"
    local bin_dir executable go_config
    local -a privacy

    if [[ "${HOME:-}" != /* ]]; then
        printf 'Set HOME to the absolute path of your home directory.\n' >&2
        return 1
    fi
    bin_dir="$HOME/.local/bin"
    executable="$bin_dir/dotx"

    install_prerequisites
    if ! command -v git >/dev/null 2>&1 || ! command -v go >/dev/null 2>&1; then
        printf 'Put Git and Go on PATH before retrying. Ubuntu installs them under /usr/bin.\n' >&2
        return 1
    fi

    if ! GIT_TERMINAL_PROMPT=0 git ls-remote "https://$cli_module.git" HEAD </dev/null >/dev/null; then
        printf 'Git needs read access to %s. Configure your GitHub credentials and try again.\n' "$cli_module" >&2
        printf 'https://docs.github.com/en/get-started/git-basics/caching-your-github-credentials-in-git\n' >&2
        return 1
    fi

    go_config="$(GOTOOLCHAIN=local go env GOPRIVATE GONOPROXY GONOSUMDB </dev/null)"
    mapfile -t privacy <<< "$go_config"
    mkdir -p -- "$bin_dir"
    printf 'Installing dotx@%s to %s\n' "$version" "$bin_dir"
    if ! GOBIN="$bin_dir" \
        GOPRIVATE="${privacy[0]:+${privacy[0]},}$private_scope" \
        GONOPROXY="${privacy[1]:+${privacy[1]},}$private_scope" \
        GONOSUMDB="${privacy[2]:+${privacy[2]},}$private_scope" \
        GIT_TERMINAL_PROMPT=0 go install "$cli_module/cmd/dotx@$version" </dev/null; then
        printf 'dotx installation failed. Check the Go toolchain and CLI version above.\n' >&2
        printf 'https://go.dev/doc/install\n' >&2
        return 1
    fi

    if [[ ! -x "$executable" ]]; then
        printf 'Go finished without installing an executable at %s.\n' "$executable" >&2
        return 1
    fi
    "$executable" version </dev/null
    printf 'Installed dotx at %q\n' "$executable"
    printf 'dotx installation complete.\n'
}

main "$@"

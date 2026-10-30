#!/bin/sh
# Uninstall git-push-remotes. Mirrors install.sh and supports the same environments.
set -eu

APP_NAME="git-push-remotes"
ASSUME_YES=0
SYSTEM=0

die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }
say()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF_USAGE'
Usage: sh uninstall.sh [--system] [--yes|-y] [--help|-h]

Remove the git-push-remotes program, its Python virtual environment, and its launcher.

Options:
  --system    Remove the system-wide installation made with "install.sh --system".
  -y, --yes   Skip the confirmation prompt.
  -h, --help  Show this help message.

Custom installation paths can be supplied through the same variables used by install.sh:
  GPR_INSTALL_DIR  Program directory
  GPR_VENV_DIR     Python virtual environment directory
  GPR_BIN_DIR      Directory containing the launcher
EOF_USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --system) SYSTEM=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Error: Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------------------------
# Operating system detection. Keep this block in sync with install.sh.
# ---------------------------------------------------------------------------------------------
UNAME_S=$(uname -s 2>/dev/null || printf unknown)
case "$UNAME_S" in
    Linux)
        if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]; then
            OS=termux
        elif [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ] ||
             grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
            OS=wsl
        else
            OS=linux
        fi
        ;;
    Darwin)     OS=macos ;;
    FreeBSD)    OS=freebsd ;;
    OpenBSD)    OS=openbsd ;;
    NetBSD)     OS=netbsd ;;
    DragonFly)  OS=dragonfly ;;
    SunOS)      OS=sunos ;;
    Haiku)      OS=haiku ;;
    AIX)        OS=aix ;;
    CYGWIN*)    OS=cygwin ;;
    MINGW*|MSYS*) OS=gitbash ;;
    *)
        OS=unknown
        warn "Unrecognised system '$UNAME_S'. Continuing with generic POSIX behaviour."
        ;;
esac

# Keep these defaults in sync with install.sh.
if [ "$SYSTEM" -eq 1 ]; then
    case "$OS" in
        gitbash|cygwin) die "--system is not supported on $OS." ;;
        termux) SYS_PREFIX=${PREFIX:-/data/data/com.termux/files/usr} ;;
        *) SYS_PREFIX=/usr/local ;;
    esac
    : "${GPR_INSTALL_DIR:=$SYS_PREFIX/libexec/$APP_NAME}"
    : "${GPR_VENV_DIR:=$SYS_PREFIX/share/$APP_NAME/venv}"
    : "${GPR_BIN_DIR:=$SYS_PREFIX/bin}"
else
    [ -n "${HOME:-}" ] || die "The HOME variable is not set."
    : "${GPR_INSTALL_DIR:=$HOME/.local/opt/$APP_NAME}"
    : "${GPR_VENV_DIR:=$HOME/.local/share/$APP_NAME/venv}"
    if [ "$OS" = termux ]; then
        : "${GPR_BIN_DIR:=${PREFIX:-/data/data/com.termux/files/usr}/bin}"
    else
        : "${GPR_BIN_DIR:=$HOME/.local/bin}"
    fi
fi

# Remove trailing slashes so path safety checks behave consistently.
trim_trailing_slashes() {
    value=$1
    while [ "$value" != "/" ] && [ "${value%/}" != "$value" ]; do
        value=${value%/}
    done
    printf '%s' "$value"
}
GPR_INSTALL_DIR=$(trim_trailing_slashes "$GPR_INSTALL_DIR")
GPR_VENV_DIR=$(trim_trailing_slashes "$GPR_VENV_DIR")
GPR_BIN_DIR=$(trim_trailing_slashes "$GPR_BIN_DIR")

# Refuse unsafe or ambiguous paths before running rm -rf.
validate_path() {
    label=$1
    path=$2
    recursive=$3
    [ -n "$path" ] || die "$label cannot be empty."
    case "$path" in
        /*) ;;
        *) die "$label must be an absolute path: $path" ;;
    esac
    [ "$path" != "/" ] || die "Refusing to use the filesystem root as $label."
    if [ -n "${HOME:-}" ]; then
        [ "$path" != "$HOME" ] || die "Refusing to use HOME as $label. Check your installation path variables."
        case "$HOME/" in
            "$path/"*) die "Refusing to use a parent directory of HOME as $label: $path" ;;
        esac
    fi
    # Directories that are deleted recursively must never be a well-known system location.
    if [ "$recursive" -eq 1 ]; then
        case "$path" in
            /bin|/boot|/dev|/etc|/home|/lib|/lib32|/lib64|/libexec|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
            /usr/bin|/usr/lib|/usr/lib32|/usr/lib64|/usr/libexec|/usr/sbin|/usr/share|/usr/include|/usr/local|\
            /usr/local/bin|/usr/local/lib|/usr/local/libexec|/usr/local/sbin|/usr/local/share|\
            /Users|/Applications|/Library|/System|/Volumes|/private|\
            /usr/pkg|/usr/pkg/bin|/usr/pkg/lib|/usr/pkg/libexec|/usr/pkg/share|\
            /usr/X11R6|/usr/ports|/data|/data/data|/boot/system|/boot/home)
                die "Refusing to recursively remove the system directory used as $label: $path" ;;
        esac
    fi
}
validate_path "GPR_INSTALL_DIR" "$GPR_INSTALL_DIR" 1
validate_path "GPR_VENV_DIR" "$GPR_VENV_DIR" 1
validate_path "GPR_BIN_DIR" "$GPR_BIN_DIR" 0

# Prevent the program and venv paths from overlapping, which could delete unrelated files.
is_same_or_child_path() {
    candidate=$1
    parent=$2
    [ "$candidate" = "$parent" ] && return 0
    case "$candidate/" in
        "$parent/"*) return 0 ;;
        *) return 1 ;;
    esac
}
if is_same_or_child_path "$GPR_INSTALL_DIR" "$GPR_VENV_DIR" ||
   is_same_or_child_path "$GPR_VENV_DIR" "$GPR_INSTALL_DIR"; then
    die "GPR_INSTALL_DIR and GPR_VENV_DIR overlap. Set them to separate installation directories."
fi

LAUNCHER="$GPR_BIN_DIR/$APP_NAME"

# A directory is only deleted when it really looks like what the installer creates.
is_our_launcher() {
    [ -f "$LAUNCHER" ] || return 1
    grep -qF "Generated by the $APP_NAME installer" "$LAUNCHER" 2>/dev/null && return 0
    grep -qF "$GPR_INSTALL_DIR/$APP_NAME" "$LAUNCHER" 2>/dev/null && return 0
    return 1
}
is_our_install_dir() { [ -f "$GPR_INSTALL_DIR/$APP_NAME" ]; }
is_our_venv()        { [ -f "$GPR_VENV_DIR/pyvenv.cfg" ]; }

say "Target environment: $OS"
say "Program directory: $GPR_INSTALL_DIR"
say "Python environment: $GPR_VENV_DIR"
say "Command launcher: $LAUNCHER"
say ""

FOUND=0
{ [ -e "$LAUNCHER" ] || [ -L "$LAUNCHER" ] || [ -e "$GPR_INSTALL_DIR" ] || [ -e "$GPR_VENV_DIR" ]; } && FOUND=1
if [ "$FOUND" -eq 0 ]; then
    say "Nothing to remove at these locations."
    if [ "$SYSTEM" -eq 0 ] && [ -e "/usr/local/libexec/$APP_NAME" ]; then
        say "A system-wide installation exists. Rerun with: sudo sh uninstall.sh --system"
    fi
    exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    [ -t 0 ] || die "Confirmation is required in a non-interactive shell. Rerun with --yes to proceed."
    printf 'Remove this git-push-remotes installation? [y/N] '
    IFS= read -r answer || answer=""
    case "$answer" in
        y|Y|yes|YES|Yes) ;;
        *) say "Uninstallation cancelled."; exit 0 ;;
    esac
fi

SKIPPED=0

# Launcher.
if [ -e "$LAUNCHER" ] || [ -L "$LAUNCHER" ]; then
    if is_our_launcher; then
        rm -f "$LAUNCHER" || die "Could not remove the command launcher: $LAUNCHER"
    else
        warn "Skipping '$LAUNCHER': it was not created by this installer (or uses another program path)."
        SKIPPED=1
    fi
fi

# Program directory.
if [ -L "$GPR_INSTALL_DIR" ]; then
    rm -f "$GPR_INSTALL_DIR" || die "Could not remove the program link: $GPR_INSTALL_DIR"
elif [ -e "$GPR_INSTALL_DIR" ]; then
    if is_our_install_dir; then
        rm -rf "$GPR_INSTALL_DIR" || die "Could not remove the program directory: $GPR_INSTALL_DIR"
    else
        warn "Skipping '$GPR_INSTALL_DIR': it does not contain '$APP_NAME'."
        SKIPPED=1
    fi
fi

# Python virtual environment.
if [ -e "$GPR_VENV_DIR" ] || [ -L "$GPR_VENV_DIR" ]; then
    if is_our_venv; then
        rm -rf "$GPR_VENV_DIR" || die "Could not remove the Python environment: $GPR_VENV_DIR"
    else
        warn "Skipping '$GPR_VENV_DIR': it is not a Python virtual environment."
        SKIPPED=1
    fi
fi

# Remove the application's own parent directory (default: ~/.local/share/git-push-remotes) when
# it is empty. rmdir never removes a directory that still has content.
for dir in "$GPR_VENV_DIR" "$GPR_INSTALL_DIR"; do
    parent=$(dirname -- "$dir")
    if [ "${parent##*/}" = "$APP_NAME" ]; then
        rmdir "$parent" 2>/dev/null || true
    fi
done

if [ "$SKIPPED" -eq 0 ]; then
    say "Uninstallation completed ($OS)."
    say "The git-push-remotes program, virtual environment, and launcher have been removed."
else
    say "Uninstallation finished with skipped items (see the warnings above)."
fi
say "No shell profile files were modified by this uninstaller."

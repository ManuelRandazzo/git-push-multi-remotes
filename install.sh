#!/bin/sh
# Install git-push-remotes so that `git push-remotes` works.
#
# Git runs any executable called `git-<name>` found in PATH as `git <name>`. This is the same
# mechanism git-filter-repo relies on. The installer therefore only has to put a small launcher
# called `git-push-remotes` in a directory that is in PATH.
#
# Recognised environments: Linux (glibc and musl), WSL, Termux (Android), macOS, FreeBSD,
# OpenBSD, NetBSD, DragonFly BSD, illumos, Haiku, AIX, Cygwin and Git Bash (MSYS2).
# Any other POSIX system is attempted with a warning, because the only real requirements are
# a POSIX shell, Python 3.8+ with the venv module, and network access to PyPI.
set -eu

APP_NAME="git-push-remotes"
SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM=0

die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }
say()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF_USAGE'
Usage: sh install.sh [--system] [--help]

Install git-push-remotes so that "git push-remotes" works.

Options:
  --system    Install for all users (default prefix /usr/local). Requires root, for example
              "sudo sh install.sh --system". Not available on Git Bash and Cygwin.
  -h, --help  Show this help message.

Environment variables (the same ones are read by uninstall.sh):
  GPR_INSTALL_DIR  Program directory
  GPR_VENV_DIR     Python virtual environment directory
  GPR_BIN_DIR      Directory that receives the "git-push-remotes" launcher
  GPR_PYTHON       Python interpreter to use instead of automatic detection
EOF_USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --system) SYSTEM=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Error: Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# Quote a string so that it can be pasted safely into a POSIX shell script.
sh_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# ---------------------------------------------------------------------------------------------
# Operating system detection. Keep this block in sync with uninstall.sh.
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

# Git Bash needs a native Windows Python and Cygwin needs a Cygwin Python, because the two
# kinds of virtual environment are not interchangeable.
case "$OS" in
    gitbash) WANT_PLATFORM=win32 ;;
    cygwin)  WANT_PLATFORM=cygwin ;;
    *)       WANT_PLATFORM="" ;;
esac

# ---------------------------------------------------------------------------------------------
# Installation paths.
# ---------------------------------------------------------------------------------------------
if [ "$SYSTEM" -eq 1 ]; then
    case "$OS" in
        gitbash|cygwin) die "--system is not supported on $OS. Run the installer without it." ;;
        termux) SYS_PREFIX=${PREFIX:-/data/data/com.termux/files/usr} ;;
        *) SYS_PREFIX=/usr/local ;;
    esac
    : "${GPR_INSTALL_DIR:=$SYS_PREFIX/libexec/$APP_NAME}"
    : "${GPR_VENV_DIR:=$SYS_PREFIX/share/$APP_NAME/venv}"
    : "${GPR_BIN_DIR:=$SYS_PREFIX/bin}"
    umask 022
else
    [ -n "${HOME:-}" ] || die "The HOME variable is not set."
    : "${GPR_INSTALL_DIR:=$HOME/.local/opt/$APP_NAME}"
    : "${GPR_VENV_DIR:=$HOME/.local/share/$APP_NAME/venv}"
    if [ "$OS" = termux ]; then
        # Termux has no ~/.local/bin in PATH by default, but $PREFIX/bin is always there.
        : "${GPR_BIN_DIR:=${PREFIX:-/data/data/com.termux/files/usr}/bin}"
    else
        : "${GPR_BIN_DIR:=$HOME/.local/bin}"
    fi
fi

# ---------------------------------------------------------------------------------------------
# Prerequisites.
# ---------------------------------------------------------------------------------------------
python_ok() {
    "$1" -c 'import sys; w = sys.argv[1]; raise SystemExit(0 if sys.version_info >= (3, 8) and (not w or sys.platform == w) else 1)' "$WANT_PLATFORM" >/dev/null 2>&1
}

find_python() {
    if [ -n "${GPR_PYTHON:-}" ]; then
        candidate_path=$(command -v "$GPR_PYTHON" 2>/dev/null || true)
        if [ -n "$candidate_path" ] && python_ok "$candidate_path"; then
            printf '%s' "$candidate_path"
            return 0
        fi
        return 1
    fi
    for candidate in python3 python python3.14 python3.13 python3.12 python3.11 python3.10 python3.9 python3.8; do
        candidate_path=$(command -v "$candidate" 2>/dev/null || true)
        if [ -n "$candidate_path" ] && python_ok "$candidate_path"; then
            printf '%s' "$candidate_path"
            return 0
        fi
    done
    return 1
}

if ! PYTHON=$(find_python); then
    case "$OS" in
        gitbash) die "Git Bash requires native Windows Python 3.8 or newer. Install Python for Windows, enable its PATH option, restart Git Bash, and run this installer again." ;;
        cygwin)  die "Cygwin requires the Cygwin build of Python 3.8 or newer (install the python3 package with the Cygwin setup program)." ;;
        *)       die "Python 3.8 or newer was not found. Install Python 3, or set GPR_PYTHON to the interpreter to use." ;;
    esac
fi

if ! command -v git >/dev/null 2>&1; then
    warn "git was not found in PATH. 'git push-remotes' needs Git at run time, so install Git as well."
fi

[ -f "$SOURCE_DIR/$APP_NAME" ] ||
    die "Cannot find '$SOURCE_DIR/$APP_NAME'. Run install.sh from the extracted project directory."

# Suggest the package that provides the venv module on common distributions.
venv_hint() {
    os_id=""; os_like=""
    if [ -r /etc/os-release ]; then
        os_id=$(. /etc/os-release >/dev/null 2>&1; printf '%s' "${ID:-}")
        os_like=$(. /etc/os-release >/dev/null 2>&1; printf '%s' "${ID_LIKE:-}")
    fi
    case " $os_id $os_like " in
        *" debian "*|*" ubuntu "*) say "Hint: sudo apt install python3-venv" ;;
        *" alpine "*)              say "Hint: apk add python3 py3-pip" ;;
        *" fedora "*|*" rhel "*)   say "Hint: sudo dnf install python3 python3-pip" ;;
        *" arch "*)                say "Hint: sudo pacman -S python" ;;
        *" suse "*|*" opensuse"*)  say "Hint: sudo zypper install python3 python3-pip" ;;
        *)
            case "$OS" in
                freebsd) say "Hint: pkg install python3 (and the matching py3*-pip package)" ;;
                openbsd) say "Hint: pkg_add python3" ;;
                termux)  say "Hint: pkg install python" ;;
                *)       say "Hint: install your system's Python 3 venv/ensurepip support." ;;
            esac
            ;;
    esac
}

# Print the interpreter of a virtual environment; the layout differs between POSIX and Windows.
venv_python_path() {
    for sub in bin/python bin/python3 Scripts/python.exe; do
        if [ -f "$GPR_VENV_DIR/$sub" ]; then
            printf '%s' "$GPR_VENV_DIR/$sub"
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------------------------
# Installation. Program files are staged first so that a failure never leaves a half install.
# ---------------------------------------------------------------------------------------------
mkdir -p "$GPR_BIN_DIR" "$(dirname -- "$GPR_INSTALL_DIR")" "$(dirname -- "$GPR_VENV_DIR")" ||
    die "Could not create the installation directories. For --system, run the installer as root."

PARENT_DIR=$(dirname -- "$GPR_INSTALL_DIR")
STAGE_DIR="$PARENT_DIR/.${APP_NAME}.install.$$"
BACKUP_DIR="$PARENT_DIR/.${APP_NAME}.backup.$$"
LAUNCHER_TMP="$GPR_BIN_DIR/.${APP_NAME}.$$"
VENV_CREATED=0
INSTALL_COMMITTED=0
cleanup() {
    [ ! -d "$STAGE_DIR" ] || rm -rf "$STAGE_DIR"
    [ ! -f "$LAUNCHER_TMP" ] || rm -f "$LAUNCHER_TMP"
    if [ "$VENV_CREATED" -eq 1 ] && [ "$INSTALL_COMMITTED" -eq 0 ]; then
        rm -rf "$GPR_VENV_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$STAGE_DIR"

for file in "$APP_NAME" "$APP_NAME.py" requirements.txt README.md LICENSE; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$STAGE_DIR/$file" || die "Could not copy $file."
    fi
done
chmod 755 "$STAGE_DIR/$APP_NAME"

create_venv() {
    VENV_CREATED=1
    if ! "$PYTHON" -m venv "$@" "$GPR_VENV_DIR"; then
        venv_hint
        die "Could not create the virtual environment."
    fi
}

# The environment lives at its final path because venvs contain absolute paths.
if [ -d "$GPR_VENV_DIR" ]; then
    [ -f "$GPR_VENV_DIR/pyvenv.cfg" ] ||
        die "'$GPR_VENV_DIR' exists but is not a Python virtual environment. Remove it or set GPR_VENV_DIR to another path."
    if ! VENV_PYTHON=$(venv_python_path) || ! "$VENV_PYTHON" -c 'pass' >/dev/null 2>&1; then
        say "The existing virtual environment is broken (the base Python was probably upgraded or removed). Recreating it."
        create_venv --clear
    fi
else
    create_venv
fi
VENV_PYTHON=$(venv_python_path) ||
    die "The virtual environment interpreter was not found in '$GPR_VENV_DIR'. Remove the environment and rerun the installer."

"$VENV_PYTHON" -m pip install --upgrade pip ||
    warn "Could not upgrade pip. Continuing with the version bundled with Python."
if [ -f "$SOURCE_DIR/requirements.txt" ]; then
    "$VENV_PYTHON" -m pip install -r "$SOURCE_DIR/requirements.txt" ||
        die "Could not install the dependencies from requirements.txt. Check your network connection and try again."
else
    "$VENV_PYTHON" -m pip install GitPython ||
        die "Could not install GitPython. Check your network connection and try again."
fi
VENV_CREATED=0

# Replace the program files only after Python and the dependencies are ready.
if [ -e "$GPR_INSTALL_DIR" ] || [ -L "$GPR_INSTALL_DIR" ]; then
    mv "$GPR_INSTALL_DIR" "$BACKUP_DIR" || die "Could not back up the previous program installation."
fi
if ! mv "$STAGE_DIR" "$GPR_INSTALL_DIR"; then
    [ ! -e "$BACKUP_DIR" ] || mv "$BACKUP_DIR" "$GPR_INSTALL_DIR"
    die "Could not activate the new program installation."
fi
[ ! -e "$BACKUP_DIR" ] || rm -rf "$BACKUP_DIR"

# The launcher calls the venv interpreter explicitly, so the program needs no shebang and does not
# depend on whatever "python3" happens to be first in PATH.
if [ -x /bin/sh ]; then SH_PATH=/bin/sh; else SH_PATH=$(command -v sh); fi
{
    printf '#!%s\n' "$SH_PATH"
    printf '# Generated by the %s installer. Do not edit.\n' "$APP_NAME"
    printf 'exec %s %s "$@"\n' "$(sh_quote "$VENV_PYTHON")" "$(sh_quote "$GPR_INSTALL_DIR/$APP_NAME")"
} > "$LAUNCHER_TMP" || die "Could not write the command launcher."
chmod 755 "$LAUNCHER_TMP"
mv "$LAUNCHER_TMP" "$GPR_BIN_DIR/$APP_NAME" || die "Could not install the command launcher."
INSTALL_COMMITTED=1

say ""
say "Installation completed ($OS)."
say "Program:     $GPR_INSTALL_DIR"
say "Python env:  $GPR_VENV_DIR"
say "Launcher:    $GPR_BIN_DIR/$APP_NAME"
say ""

# ---------------------------------------------------------------------------------------------
# PATH diagnostics. Shell profile files are never modified.
# ---------------------------------------------------------------------------------------------
case ":${PATH:-}:" in
    *":$GPR_BIN_DIR:"*)
        found=$(command -v "$APP_NAME" 2>/dev/null || true)
        if [ -n "$found" ] && [ "$found" != "$GPR_BIN_DIR/$APP_NAME" ]; then
            warn "Another '$APP_NAME' at '$found' comes first in PATH and will be used by 'git push-remotes'."
        fi
        ;;
    *)
        warn "$GPR_BIN_DIR is not in the current PATH, so 'git push-remotes' will not be found yet."
        shell_name=${SHELL:-}
        shell_name=${shell_name##*/}
        case "$shell_name" in
            zsh)
                say "Add this line to ~/.zshrc:"
                say "  export PATH=\"$GPR_BIN_DIR:\$PATH\"" ;;
            bash)
                if [ "$OS" = macos ]; then rc="~/.bash_profile"; else rc="~/.bashrc"; fi
                say "Add this line to $rc:"
                say "  export PATH=\"$GPR_BIN_DIR:\$PATH\"" ;;
            fish)
                say "Run this once in fish:"
                say "  fish_add_path \"$GPR_BIN_DIR\"" ;;
            csh|tcsh)
                say "Add this line to ~/.cshrc:"
                say "  setenv PATH \"$GPR_BIN_DIR:\$PATH\"" ;;
            nu)
                say "Add this line to your Nushell config.nu:"
                say "  \$env.PATH = (\$env.PATH | prepend \"$GPR_BIN_DIR\")" ;;
            ksh|mksh|oksh|ash|dash|sh)
                say "Add this line to ~/.profile:"
                say "  export PATH=\"$GPR_BIN_DIR:\$PATH\"" ;;
            *)
                say "Add $GPR_BIN_DIR to your shell PATH." ;;
        esac
        say "Then restart the terminal or reload your shell configuration."
        ;;
esac
say "Usage: git push-remotes"

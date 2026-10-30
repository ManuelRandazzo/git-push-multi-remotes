# Git Push Multiple Remotes

---

![Supported OS:](https://img.shields.io/badge/Supported%20OS-lightgrey) ![Linux](https://img.shields.io/badge/Linux-yellow?logo=linux&logoColor=black) ![Windows, WSL And Git For Windows](https://img.shields.io/badge/Windows,%20WSL%20and%20Git%20For%20Windows-blue?logo=gitforwindows&logoColor=darkblue) ![MacOS](https://img.shields.io/badge/MacOS-lightblue?logo=macos&logoColor=white) ![FreeBSD](https://img.shields.io/badge/FreeBSD-red?logo=freebsd&logoColor=white) ![OpenBSD](https://img.shields.io/badge/OpenBSD-yellow?logo=openbsd&logoColor=white) ![NetBSD](https://img.shields.io/badge/NetBSD-orange?logo=netbsd&logoColor=white) ![DragonFlyBSD](https://img.shields.io/badge/DragonFlyBSD-lightgreen) ![Termux](https://img.shields.io/badge/Termux-black) ![Others](https://img.shields.io/badge/Others-green)

## Table Of Contents

- [Description](#description)
- [Dependencies To Install](#dependencies-to-install)
    - [Windows Dependencies](#windows-dependencies)
    - [Unix-Like Dependencies (Linux, BSD, MacOS, WSL, Git Bash)](#unix-like-dependencies-linux-bsd-macos-wsl-git-bash)
- [Supported Systems](#supported-systems)
- [Installation](#installation)
    - [Windows Installation](#windows-installation)
    - [Unix-Like Installation (Linux, BSD, MacOS, WSL, Git Bash)](#unix-like-installation-linux-bsd-macos-wsl-git-bash)
- [Manual Installation (Linux, MacOS, FreeBSD)](#manual-installation-linux-macos-freebsd)
- [Uninstallation](#uninstallation)
    - [Windows Uninstallation](#windows-uninstallation)
    - [Unix-Like Uninstallation (Linux, BSD, MacOS, WSL, Git Bash)](#unix-like-uninstallation-linux-bsd-macos-wsl-git-bash)
- [Script Usage And Commands](#script-usage-and-commands)
    - [Git Push Options](#git-push-options)
    - [What git push-remotes <branch> Does](#what-git-push-remotes-branch-does)
- [Troubleshooting](#troubleshooting)
- [How To Contribute To This Project](#how-to-contribute-to-this-project)
- [License](#license)

---

## Description
A Git subcommand that pushes a branch to **all** the remotes of a repository
with a single command:

```bash
git push-remotes <branch name>
```

Every option of `git push` can be used too, for example `git push-remotes --force <branch name>`.

---

## Dependencies To Install
Python 3.8 or newer. The installer takes care of the rest (it installs
[GitPython](https://pypi.org/project/GitPython/) in a private virtual
environment (venv), so nothing is added to your system Python).

---

### Windows Dependencies
Open PowerShell and type
```ps1
winget install python
```

---

### Unix-Like Dependencies (Linux, BSD, MacOS, WSL, Git Bash)
Open Terminal and type
```bash
# MacOS
brew install python3

# Ubuntu/Debian based distro (make sure to use your distribution package manager)
sudo apt install python3

# FreeBSD
sudo pkg install python3
```


---

## Supported Systems
Tested on Ubuntu, Fedora, FreeBSD, Windows 11, WSL and Git Bash.

The installer should also recognize MacOS, OpenBSD, NetBSD, DragonFly BSD,
Illumos, Haiku, AIX, Termux and Cygwin, but these have not been tested.

---

## Installation
The installer sets up three things: the `git-push-remotes` program, a private
Python virtual environment (venv) containing the GitPython library, and a small launcher in your `PATH` that lets Git find the command.

---

### Windows Installation
From the project folder double-click:
```bat
install.bat
```
**WARNING**: If you double-click the file, the installation logs may not remain visible after the script finishes.

Alternatively open PowerShell, navigate to the repository folder, and run:
```bat
& ".\install.bat"
```

The installer adds its command folder to your user `PATH`. Open a **new**
terminal afterwards so the change is picked up.

---

### Unix-Like Installation (Linux, BSD, MacOS, WSL, Git Bash)
```bash
# switch to the directory (any in your system) where you want to clone this repo, for example
# cd ~/Downloads

# clone this repo
git clone https://github.com/ManuelRandazzo/git-push-multi-remotes

# switch to repo's clone directory
cd git-push-multi-remotes

# add executable permission to file "install.sh"
# ATTENTION: requires administrative (superuser) privileges with the 'sudo' command
sudo chmod +x install.sh

# run the installation script (interactive)
# ATTENTION: requires administrative (superuser) privileges with the 'sudo' command
sudo sh install.sh

# To install for all users instead:
# sudo sh install.sh --system
```

If the installer reports that its launcher directory is not in your `PATH`,
add the line it prints to your shell profile, then open a new terminal.

> **Git Bash:** use `install.sh`, and make sure the Windows build of Python
> (python.org) is installed, not the MSYS one. `--system` is not available.

---

## Manual Installation (Linux, MacOS, FreeBSD)
From the project folder:

```sh

# Create a Python virtual environment (venv)
python3 -m venv ~/.local/share/git-push-remotes/venv

# Install the GitPython library using pip from the virtual environment
~/.local/share/git-push-remotes/venv/bin/pip install GitPython

# Create the directories for the script and its launcher
mkdir -p ~/.local/opt/git-push-remotes ~/.local/bin

# Copy the Git push remotes script into its installation directory
cp git-push-remotes ~/.local/opt/git-push-remotes/

# Create a launcher script that runs the Python script using the virtual environment
printf '#!/bin/sh\nexec "$HOME/.local/share/git-push-remotes/venv/bin/python" "$HOME/.local/opt/git-push-remotes/git-push-remotes" "$@"\n' > ~/.local/bin/git-push-remotes

# Add executable permission to script file "git-push-remotes"
chmod +x ~/.local/bin/git-push-remotes
```

Make sure `~/.local/bin` is in your `PATH`. To remove a manual installation:

```sh
rm -rf ~/.local/share/git-push-remotes ~/.local/opt/git-push-remotes ~/.local/bin/git-push-remotes
```

---

## Uninstallation
The uninstaller will remove three things: the `git-push-remotes` program, a private
Python virtual environment (venv) containing the GitPython library, and a small launcher in your `PATH` that lets Git find the command.

---

### Windows Uninstallation:
From the project folder double-click:
```bat
uninstall.bat
```
And follow the interactive process.

**WARNING**: If you double-click the file, the uninstallation logs may not remain visible after the script finishes. 

Alternatively open PowerShell, navigate to the repository folder, and run:
```bat
& ".\uninstall.bat"
```
And follow the interactive process.

---

### Unix-Like Uninstallation (Linux, BSD, MacOS, WSL, Git Bash):
```bash
# switch to the directory where you cloned this repo, for example
cd ~/Downloads/git-push-multi-remotes

# add executable permission to file "uninstall.sh"
sudo chmod +x uninstall.sh

# run the uninstallation script (interactive)
sh uninstall.sh

# To uninstall for all users instead (interactive):
# sudo sh uninstall.sh --system
```

The uninstallers only remove what the installers created, and ask for
confirmation first.

---

## Script Usage And Commands
Run the commands inside a Git repository.

| Command | What it does |
|---|---|
| `git push-remotes <branch>` | Pushes `<branch>` to every remote of the repository. **This is the main command.** |
| `git push-remotes [git push options] <branch>` | Same, with any option of `git push` (see [Git Push Options](#git-push-options)). |
| `git push-remotes <branch> -x <remote> [<remote> ...]` | Same, but skips the listed remotes. Unknown remote names are reported as errors, so typos are caught. Put `<branch>` before `-x`, because `-x` accepts several names. |
| `git push-remotes -ls -r` | Lists the names of the remotes. |
| `git push-remotes -ls -L` | Lists the local branches. |
| `git push-remotes -ls -R` | Lists the remote branches. |
| `git push-remotes -ls -a` | Lists local and remote branches. |
| `git push-remotes -ls --push` | Lists the options of `git push` (the output of `git push -h`), all usable with `git push-remotes`. Works outside a repository too. |
| `git push-remotes --set-local-path <path> ...` | Works on the repository at `<path>` instead of the current folder. Goes before the rest of the command, e.g. `git push-remotes --set-local-path ~/work/project --dry-run main`. |
| `git push-remotes -V` | Prints the script version (`--version`). |
| `git push-remotes -h` | Shows the built-in help. |

`-ls` needs at least one of `-r`, `-L`, `-R`, `-a`, `--push` and for this command combinations are supported (e.g. `git push-remotes -ls -a` is equal to `git push-remotes -ls -LR`, and `git push-remotes -ls -r --push` lists the remotes and then the options of `git push`). `-ls` cannot be combined with a branch, `-x` or `git push` options.

---

### Git Push Options
Every option of `git push` can be used. To see them all, run `git push -h` or
`git push-remotes -ls --push`. For example:

```bash
git push-remotes --force <branch>              # force push to every remote
git push-remotes --force-with-lease <branch>   # safer force push
git push-remotes --dry-run <branch>            # show what would happen, push nothing
git push-remotes -u <branch>                   # set the upstream branch
git push-remotes -o ci.skip <branch>           # send a push option to the servers
git push-remotes --tags                        # push all tags (no branch needed)
git push-remotes --all                         # push all branches (no branch needed)
git push-remotes --delete <old-branch>         # delete a branch on every remote
```

Good to know:
- Options can go before or after the branch.
- `-v` is the `git push` one (verbose). The version is `-V`.
- Options with an optional value need the `=` form, as in git: `--force-with-lease=<branch>:<sha>`, `--signed=if-asked`.
- `--repo` is refused: the remotes are chosen by `git push-remotes`.
- `--delete` works even if the branch no longer exists locally.
- `--force` hits **all** the remotes at once. Prefer `--force-with-lease`.
- `-u` is applied to each remote in turn, so the upstream ends up on the last remote pushed (a warning is shown).

---

### What `git push-remotes <branch>` Does
It is equivalent to:

```sh
for r in $(git remote); do git push "$r" <branch>; done
```

but it is much easier to read and type. It runs the real `git push` once per
remote, so every option behaves exactly as in git (with options, the equivalent
is `git push [options] "$r" <branch>`). On top of that, it checks that the
branch exists, asks for confirmation if `HEAD` is detached, lets you exclude
remotes with `-x`, prints the result for each remote, and stops with an error
at the first push that fails, telling you which remotes were not attempted.

---

## Troubleshooting
- **`git: 'push-remotes' is not a git command`**: the launcher folder is not in
  your `PATH`. Add it (the installer prints the exact line) and open a new
  terminal. On Windows, a new terminal is enough.
- **`Python 3.8 or newer was not found`**: install Python 3.8+. On Unix-like
  systems you can point the installer to a specific interpreter with
  `GPR_PYTHON=python3.12 sh install.sh`.
- **The virtual environment cannot be created (Debian/Ubuntu)**: install the
  `python3-venv` package.
- **`git push-remotes --help` shows a "no manual entry" message**: Git
  intercepts `--help` for its subcommands. Use `git push-remotes -h`.
- **`Unknown remote(s): <branch>`**: `-x` accepts several remote names, so it
  takes the branch as one of them. Write the branch before `-x`:
  `git push-remotes <branch> -x <remote>`.
- **`git push-remotes -v` does not print the version**: since version 1.1.0
  `-v` is the `git push` option (verbose). Use `-V` or `--version`.
- **`'./' is an invalid path`**: you are not inside a Git repository. Move into
  one, or use `--set-local-path`.
- **Windows uninstall: "Could not remove ..."**: some file is in use. Close
  terminals and editors using those folders, wait for any antivirus scan to
  finish, then run `uninstall.bat` again.
- **The uninstaller says there is nothing to remove**: you installed with
  custom locations. Set the same `GPR_*` variables before uninstalling.

---

## How To Contribute To This Project
To help me improve this script feel free to [**report bugs**](https://github.com/ManuelRandazzo/git-push-multi-remotes/tree/main/.github/ISSUE_TEMPLATE/bug_report.md) or ask to [**add features**](https://github.com/ManuelRandazzo/git-push-multi-remotes/tree/main/.github/ISSUE_TEMPLATE/feature_request.md) following the proposed templates.

If you have already fixed something feel free to make a **pull request** following the proposed templates for [**bugs pull request**](https://github.com/ManuelRandazzo/git-push-multi-remotes/tree/main/.github/PULL_REQUEST_TEMPLATE/bug_fix_pull_request.md) and [**features pull request**](https://github.com/ManuelRandazzo/git-push-multi-remotes/tree/main/.github/PULL_REQUEST_TEMPLATE/feature_pull_request.md) that I will personally review and eventually merge.

---

## License
Read the [License](https://github.com/ManuelRandazzo/git-push-multi-remotes/blob/main/LICENSE)
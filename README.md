# Ansible Target Bootstrap Script
This repository contains a shell script designed to bootstrap a fresh Linux system (VM, container, or bare metal) to be managed by Ansible.

**What it does:**

1.  Creates a dedicated user (`ansible` by default) for Ansible to connect as.
2.  Configures passwordless `sudo` privileges for this user.
3.  Sets up SSH key-based authentication for the created user using hte publickey fetched from your configured repository.
4.  Attempts to automatically install Python 3 if it's not already present (required by Ansible on managed nodes) using `apt`, `dnf`, or `yum`.

> [!CAUTION]
> Executing scripts directly from the internet using `curl | bash` is convenient but carries **significant security risks**. You are downloading code and running it with **root privileges**.

**Only run this script if:**

1.  You **fully trust** the source repository (ideally, your own fork).
2.  You have **reviewed the script code** to understand exactly what it does.
3.  You understand the implications of granting passwordless `sudo` and SSH access.

Failure to configure this script properly after forking could potentially grant access to the original author if you run it with the default placeholder URLs. **Always configure your fork!**

## Repository Structure & Branching

This repository uses a specific structure for safe and effective use. Using separate branches prevents accidental execution with placeholder values and ensures your specific configuration (SSH key, user) is used:

*   **`main` Branch (You are here):** This branch contains the **template** script (`script.sh`) and a placeholder key file (`key`). It uses **placeholder values** for repository URLs and is **NOT intended to be run directly**. Its purpose is to be forked.
*   **Your Working Branch (e.g., `personal`, `homelab`, `prod`):** You should create your own branch from `main`. On this branch, you will:
    *   Edit `script.sh` to set the correct `REPO_RAW_BASE_URL` pointing to *your fork and branch*.
    *   Populate the `key` file with *your* desired public SSH key.
    *   (Optionally) Customize the `ANSIBLE_USER`.

## Setup

1.  **Fork this Repository:** Click the "Fork" button on GitHub.
2.  **Clone Your Fork:** Clone your newly created fork to your local machine.
    ```bash
    git clone https://github.com/your-username/repo-name.git
    cd YourRepoName
    ```
3.  **Create a Working Branch:** Create and switch to a branch where you will store your configuration (e.g., `personal`).
    ```bash
    git checkout -b personal
    # Or whatever name you prefer (e.g., homelab, prod)
    ```
4.  **Edit `script.sh`:**
    *   Open `script.sh` in a text editor.
    *   Locate the `CONFIGURATION` section near the top.
    *   **Crucially, change the `REPO_RAW_BASE_URL` variable.** Replace the placeholder `https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main` with the correct raw URL pointing to *this working branch* in *your fork*. For example: `https://raw.githubusercontent.com/hellocharli/auserlese/aura/`.
    *   (Optional) Change the `ANSIBLE_USER` variable if you don't want to use `ansible`.
    *   (Optional) Change `PUBLIC_KEY_FILENAME` only if you intend to rename the `key` file.
5.  **Edit `key` file:**
    *   Open the `key` file.
    *   Delete the placeholder content.
    *   Paste **your public SSH key** (e.g., the contents of `~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub` from your Ansible control node) into this file. **Ensure it's the PUBLIC key, not the private key!**
6.  **Commit and Push:** Save your changes, commit them to your working branch, and push the branch to your fork on GitHub.
    ```bash
    git add script.sh key
    git commit -m "Configure bootstrap script for personal use"
    git push -u origin personal # Push your new branch
    ```
7.  **Use:** Now you can use the `curl | bash` command as described in the "How to Use" section, making sure the URL points to `script.sh` on the branch you just pushed (`personal` in this example).

## Prerequisites on Target Machine

*   `curl`: To download the script and key.
*   `sudo`: To execute the script with root privileges.
*   Internet connectivity: To reach GitHub.
*   Supported Linux Distribution: Tested on Debian/Ubuntu using `apt`. The script *should* handle CentOS/Fedora derivatives using `dnf` or `yum` but it has not been tested. Other distributions might require manual Python 3 installation.
*   Standard core utilities (`id`, `useradd`, `chmod`, `chown`, `mkdir`, `touch`, `grep`, `cat`, `mv`, `rm`, `mktemp`, `visudo`, `sed`, `awk`, etc.)

## Usage

1.  **Get the Raw URL:** Navigate to the `script.sh` file **on your configured branch** within **your fork** on GitHub. Click the "Raw" button and copy the URL from your browser's address bar.

2.  **Run on Target Machine:** Log into the target Linux machine (as root or a user with `sudo` privileges) and execute:

    ```bash
    # Replace the URL with the Raw URL of script.sh from YOUR configured branch/fork!
    curl -fsSL https://raw.githubusercontent.com/your-username/repo-name/branch-name/script.sh | sudo bash
    ```

3.  **Verify:** After the script completes, attempt to SSH into the target machine from your Ansible control node using the configured user and the corresponding private SSH key:

    ```bash
    ssh -i /path/to/your/private_key ansible@<TARGET_IP_OR_HOSTNAME>
    # Replace 'ansible' if you changed ANSIBLE_USER
    # Replace /path/to/your/private_key with the path to the key matching the public key in your 'key' file
    ```
## Contributing

While primarily a personal utility, improvements to the template script on the `main` branch (e.g., supporting more distributions, adding robustness) are welcome via Pull Requests against the original repository's `main` branch. Please ensure changes are generic and maintain the template nature of the script.
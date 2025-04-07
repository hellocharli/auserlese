#!/usr/bin/env bash

# =============================================================================
# Ansible Target Bootstrap Script
#
# Purpose: Prepares a Linux system to be managed by Ansible by:
#          1. Creating a dedicated Ansible user.
#          2. Setting up SSH key authentication for that user.
#          3. Granting passwordless sudo privileges to the user.
#          4. Ensuring Python 3 (required by Ansible) is installed.
#
# Usage:   This is a TEMPLATE script for the 'main' branch.
#          DO NOT run this directly using curl | bash without configuration.
#          To use this script, do the following:
#          1. Fork the repository.
#          2. Create a working branch (e.g., 'personal' or 'prod').
#          3. Edit the CONFIGURATION variables below in your branch.
#          4. Populate the 'key' file in your branch with your public SSH key.
#          5. Run the script from YOUR branch/fork using curl | bash.
#             See the README.md for detailed instructions.
#
# Security: Executing scripts downloaded via 'curl | bash' carries inherent
#           security risks. Only run scripts from sources you fully trust.
# =============================================================================

# --- Configuration ---

# The username for the Ansible control user to be created.
ANSIBLE_USER="ansible"

# The BASE URL for the raw content of YOUR repository fork and branch.
# Example: https://raw.githubusercontent.com/YourUsername/YourRepoName/your-branch
# --->>> IMPORTANT: Replace this placeholder with your actual URL! <<<---
REPO_RAW_BASE_URL="https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main"

# The filename of the public key file within this repository.
PUBLIC_KEY_FILENAME="key"

# --- End Configuration ---


# --- Safety & Prerequisites ---
set -o errexit  # Exit immediately if a command exits with a non-zero status.
set -o nounset  # Treat unset variables as an error during substitution.
set -o pipefail # Cause a pipeline to return the exit status of the last command that exited with a non-zero status.

# Print logging
log() {
    echo "[INFO] $1"
}
warn() {
    echo "[WARN] $1" >&2
}
error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
   error "This script must be run as root or with sudo."
fi

# Check: Ensure the placeholder URL has been changed.
if [[ "${REPO_RAW_BASE_URL}" == "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main" ]]; then
   warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   warn "!!! The REPO_RAW_BASE_URL variable is still the placeholder URL.           !!!"
   warn "!!! Please edit this script in your repository fork/branch before running. !!!"
   warn "!!! See the README.md for instructions.                                    !!!"
   warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   exit 1
fi


# --- Main Execution ---

log "Starting Ansible target bootstrap process for user: ${ANSIBLE_USER}"

# --- Dependency Check/Installation (Python 3) ---
log "Checking for Python 3..."
PYTHON_COMMAND="python3"
if command -v $PYTHON_COMMAND &> /dev/null; then
    log "Python 3 found: $(command -v $PYTHON_COMMAND)"
else
    warn "Python 3 not found. Attempting installation..."
    PACKAGE_MANAGER=""
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    else
        error "Could not detect apt, dnf, or yum. Please install Python 3 manually."
    fi

    log "Using package manager: ${PACKAGE_MANAGER}"
    case "${PACKAGE_MANAGER}" in
        apt)
            log "Updating apt cache..."
            apt-get update -y > /dev/null
            log "Installing python3..."
            apt-get install -y python3 > /dev/null
            ;;
        dnf|yum)
            log "Installing python3..."
            "${PACKAGE_MANAGER}" install -y python3 > /dev/null
            ;;
    esac

    if command -v $PYTHON_COMMAND &> /dev/null; then
        log "Python 3 installed successfully: $(command -v $PYTHON_COMMAND)"
    else
        error "Failed to install Python 3 automatically. Please install it manually."
    fi
fi


# --- User Creation ---
log "Checking for user: ${ANSIBLE_USER}..."
if id "${ANSIBLE_USER}" &>/dev/null; then
    log "User ${ANSIBLE_USER} already exists. Skipping creation."
    USER_HOME=$(eval echo ~"${ANSIBLE_USER}")
else
    log "Creating user ${ANSIBLE_USER}..."
    useradd --create-home --shell /bin/bash "${ANSIBLE_USER}"
    USER_HOME=$(eval echo ~"${ANSIBLE_USER}")
    log "User ${ANSIBLE_USER} created with home directory ${USER_HOME}."
    # Explicitly disable password auth. This should be default with a blank password
    passwd --lock "${ANSIBLE_USER}"
    log "Password authentication locked for ${ANSIBLE_USER}."
fi


# --- Sudo Configuration ---
log "Configuring passwordless sudo for ${ANSIBLE_USER}..."
SUDOERS_FILE="/etc/sudoers.d/${ANSIBLE_USER}"
SUDOERS_TEMP_FILE=$(mktemp)

# Create the sudoers entry in a temporary file first
echo "${ANSIBLE_USER} ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_TEMP_FILE}"
chmod 0440 "${SUDOERS_TEMP_FILE}"

# Validate syntax before moving into place
if visudo -c -f "${SUDOERS_TEMP_FILE}"; then
    log "Sudoers syntax check passed."
    # Check if file exists and content differs before overwriting
    if [[ ! -f "${SUDOERS_FILE}" ]] || ! cmp -s "${SUDOERS_TEMP_FILE}" "${SUDOERS_FILE}"; then
        mv "${SUDOERS_TEMP_FILE}" "${SUDOERS_FILE}"
        log "Sudoers file created/updated at ${SUDOERS_FILE}."
    else
        log "Sudoers file ${SUDOERS_FILE} already exists and is up-to-date."
        rm -f "${SUDOERS_TEMP_FILE}"
    fi
else
    warn "Sudoers syntax check failed for generated content:"
    cat "${SUDOERS_TEMP_FILE}" >&2
    rm -f "${SUDOERS_TEMP_FILE}"
    error "Aborting due to invalid sudoers configuration."
fi


# --- SSH Key Setup ---
log "Setting up SSH key authentication..."
SSH_DIR="${USER_HOME}/.ssh"
AUTH_KEYS_FILE="${SSH_DIR}/authorized_keys"
FULL_KEY_URL="${REPO_RAW_BASE_URL}/${PUBLIC_KEY_FILENAME}"

log "Ensuring SSH directory exists: ${SSH_DIR}"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${SSH_DIR}"

log "Ensuring authorized_keys file exists with correct permissions: ${AUTH_KEYS_FILE}"
touch "${AUTH_KEYS_FILE}"
chmod 600 "${AUTH_KEYS_FILE}"
chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${AUTH_KEYS_FILE}"

log "Downloading public key from ${FULL_KEY_URL}..."
TEMP_KEY_FILE=$(mktemp /tmp/ssh_key.XXXXXX)
trap 'rm -f "${TEMP_KEY_FILE}"' EXIT HUP INT QUIT TERM

if curl --fail --silent --show-error --location "${FULL_KEY_URL}" --output "${TEMP_KEY_FILE}"; then
    log "Key downloaded successfully to temporary file: ${TEMP_KEY_FILE}"
    if [[ ! -s "${TEMP_KEY_FILE}" ]]; then
        rm -f "${TEMP_KEY_FILE}"
        trap - EXIT HUP INT QUIT TERM
        error "Downloaded key file is empty. Check URL and file content: ${FULL_KEY_URL}"
    fi

    DOWNLOADED_KEY=$(<"${TEMP_KEY_FILE}")

    if grep -F -x -q -- "${DOWNLOADED_KEY}" "${AUTH_KEYS_FILE}"; then
        log "Public key already present in ${AUTH_KEYS_FILE}."
    else
        log "Public key not found. Preparing to append to ${AUTH_KEYS_FILE}..."

        # --- Start of Newline Check ---
        if [ -s "${AUTH_KEYS_FILE}" ] && [ "$(tail -c 1 "${AUTH_KEYS_FILE}")" != $'\n' ]; then
             log "Existing ${AUTH_KEYS_FILE} has content but does not end with a newline. Adding one."
             echo "" >> "${AUTH_KEYS_FILE}"
        else
             if [ ! -s "${AUTH_KEYS_FILE}" ]; then
                 log "${AUTH_KEYS_FILE} is empty. No preceding newline needed."
             else
                 log "${AUTH_KEYS_FILE} already ends with a newline. No preceding newline needed."
             fi
        fi
        # --- End of Newline Check ---

        log "Appending key from ${TEMP_KEY_FILE}."
        cat "${TEMP_KEY_FILE}" >> "${AUTH_KEYS_FILE}"

        # --- Ensure final newline ---
        if [ "$(tail -c 1 "${AUTH_KEYS_FILE}")" != $'\n' ]; then
            log "Key appended, adding missing trailing newline to ${AUTH_KEYS_FILE}."
            echo "" >> "${AUTH_KEYS_FILE}"
        else
             log "Key appended, file already ends with a newline."
        fi
        # --- End of final newline check ---

        log "Public key added successfully to ${AUTH_KEYS_FILE}."
    fi
else
    STATUS=$?
    error "Failed to download public key (curl exit code ${STATUS}) from: ${FULL_KEY_URL}. Check URL, file existence, and network connectivity."
fi

trap - EXIT HUP INT QUIT TERM
rm -f "${TEMP_KEY_FILE}"
log "SSH key setup process finished."

# Final ownership check (redundant but safe)
chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${SSH_DIR}"

# --- Completion ---
# Attempt to detect the primary IP address
TARGET_CONNECT_ADDR="<TARGET_IP_OR_HOSTNAME>"
DETECTED_IP=""

if command -v ip &> /dev/null; then
    # Try to get the IP used for the default route by querying route to a public IP
    DETECTED_IP=$(ip route get 1.1.1.1 | awk '/ src /{print $7; exit}')

    # Make sure we got something that looks like an IP
    if [[ -n "${DETECTED_IP}" && "${DETECTED_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
         TARGET_CONNECT_ADDR="${DETECTED_IP}"
         log "Detected likely primary IP: ${TARGET_CONNECT_ADDR} (Verify reachability from control node)"
     else
         log "Could not reliably detect primary IP via 'ip route'."
         # Try hostname -I as a fallback
         DETECTED_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
         if [[ -n "${DETECTED_IP}" && "${DETECTED_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            TARGET_CONNECT_ADDR="${DETECTED_IP}"
            log "Detected IP via 'hostname -I': ${TARGET_CONNECT_ADDR} (Might have multiple; verify reachability)"
         fi
     fi
else
    log "Command 'ip' (iproute2 package) not found. Cannot automatically detect IP. Using placeholder."
fi

log "=========================================================="
log ">>> Bootstrap process complete for user '${ANSIBLE_USER}'!"
log ">>> Target system should now be ready for Ansible management."
log ">>> Test SSH access (from your control node):"
log "    ssh -i /path/to/your/private_key ${ANSIBLE_USER}@${TARGET_CONNECT_ADDR}"
log "=========================================================="

exit 0
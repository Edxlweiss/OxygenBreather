#!/system/bin/sh
#
# OxygenBreather Magisk/KernelSU Module
# Copyright (c) 2025, edxlweiss
# All rights reserved.
#
# This file is part of the OxygenBreather module.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# For the full license text, see the LICENSE.txt file in the module's root directory.
#

# Magisk module path (automatically set by Magisk)
MODPATH=${0%/*}

# Path to the checksums file
CHECKSUMS_FILE="$MODPATH/checksums.sha256"

# Function to print messages to Magisk log
log_print() {
    echo "$1" >&2
}

# --- Main Verification Logic ---

log_print "--- Starting module integrity verification ---"

if [ ! -f "$CHECKSUMS_FILE" ]; then
    log_print "Error: Checksums file ($CHECKSUMS_FILE) not found!"
    log_print "Module integrity verification failed. Aborting."
    exit 1
fi

# Use sha256sum -c to verify. It expects a file with "hash  filename" format.
# The --status flag makes it silent, returning 0 for success, non-zero for failure.
# The --ignore-missing flag prevents errors for files that might not exist (e.g., optional files),
# but for core module files, we want them to exist. Let's not use --ignore-missing.

# Temporarily change directory to MODPATH to ensure sha256sum checks relative paths correctly
(
    cd "$MODPATH" || { log_print "Error: Cannot change directory to $MODPATH. Aborting verification."; exit 1; }
    
    log_print "Verifying checksums from $CHECKSUMS_FILE..."
    if sha256sum -c "$CHECKSUMS_FILE"; then
        log_print "--- Module integrity VERIFIED successfully! ---"
        exit 0
    else
        log_print "Error: One or more files failed checksum verification!"
        log_print "--- Module integrity FAILED! Module files may be corrupted or tampered with. ---"
        exit 1
    fi
)

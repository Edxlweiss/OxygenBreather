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

# This script is triggered by Magisk Manager/KernelSU Manager
# to open the OxygenBreather module's Web UI.

MODPATH=${0%/*}          # Path to your module's root directory
WEBUI_DIR="$MODPATH/webui" # Directory where your HTML/CSS/JS files are
PORT="8080"              # The port your web server will listen on (choose one unlikely to conflict, e.g., 8080, 8000, 8888)

LOG_FILE="$MODPATH/webui_action.log" # Log file for debugging
# Redirect stdout/stderr to log file for debugging
exec >> "$LOG_FILE" 2>&1
echo "--- $(date) ---"
echo "Starting OxygenBreather Web UI action..."

# --- Check for Web UI Files ---
if [ ! -d "$WEBUI_DIR" ]; then
    echo "Error: Web UI directory '$WEBUI_DIR' not found."
    echo "Please ensure your HTML, CSS, JS files are placed in '$MODPATH/webui/'."
    # Use 'su -lp 2000 -c' to show a toast/notification to the user
    su -lp 2000 -c "cmd notification post -S bigtext -t 'OxygenBreather Error' Tag 'Web UI files missing! Check module installation.'" >/dev/null 2>&1
    exit 1
fi

# --- Determine Web Server Binary ---
HTTPD_BIN=""
echo "Attempting to find a web server binary..."
if command -v busybox &> /dev/null; then
    # Prioritize busybox if available globally
    HTTPD_BIN="busybox httpd"
    echo "Using busybox httpd."
elif [ -x "$MODPATH/bin/httpd" ]; then
    # Use custom httpd if provided in module and executable
    HTTPD_BIN="$MODPATH/bin/httpd"
    echo "Using custom httpd binary from module."
elif [ -x "/data/adb/magisk/busybox" ]; then # Fallback for Magisk's internal busybox
    HTTPD_BIN="/data/adb/magisk/busybox httpd"
    echo "Using Magisk's internal busybox httpd."
else
    echo "Error: No suitable web server binary (busybox httpd or $MODPATH/bin/httpd) found."
    echo "Cannot start Web UI server."
    su -lp 2000 -c "cmd notification post -S bigtext -t 'OxygenBreather Error' Tag 'Web server binary missing! Cannot open UI.'" >/dev/null 2>&1
    exit 1
fi

# --- Check if Server is Already Running ---
echo "Checking if Web UI server is already running on port $PORT..."
# This is a basic check. A more robust solution would use PID files or process names.
if netstat -tuln | grep -q ":$PORT"; then
    echo "Web UI server already running on port $PORT."
else
    echo "Starting Web UI server from $WEBUI_DIR on port $PORT..."
    # Start httpd in the background.
    # `setsid` ensures it runs in a new session and doesn't get killed when action.sh exits.
    # `&` sends it to the background.
    # -p: port
    # -h: document root
    setsid $HTTPD_BIN -p "$PORT" -h "$WEBUI_DIR" &
    SERVER_PID=$!
    echo "Web UI server started with PID: $SERVER_PID"
    sleep 2 # Give the server a moment to start up
fi

# --- Open Web UI in Browser ---
echo "Opening Web UI in browser..."
WEB_URL="http://localhost:$PORT"
am start -a android.intent.action.VIEW -d "$WEB_URL"

echo "Action completed. Web UI opened: $WEB_URL"

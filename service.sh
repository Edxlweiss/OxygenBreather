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

# Path to the gamelist and state file
GAMELIST="$MODPATH/gamelist.txt"
STATE_FILE="$MODPATH/current_state" # Stores "active", "gaming", or "screen_off"

# --- Common Paths for MTK G99/G100 ---
# Verify these paths on your specific device!
CPU_GOVERNOR_BASE="/sys/devices/system/cpu/cpu"
CPU_FREQ_MIN_BASE="/sys/devices/system/cpu/cpu"
CPU_FREQ_MAX_BASE="/sys/devices/system/cpu/cpu"
LMK_PATH="/sys/module/lowmemorykiller/parameters/minfree"

# Dynamically find GPU governor path
GPU_GOVERNOR_PATH=$(find /sys/class/devfreq/ /sys/devices/platform/ -name "*mali*/governor" 2>/dev/null | head -n 1)

# --- Functions for Applying/Reverting Settings ---

# Applies general battery saver settings (screen ON, not gaming)
apply_general_saver() {
    if [ "$(cat "$STATE_FILE")" != "active" ]; then
        echo "Applying general battery saver (screen ON, not gaming)..." >&2
        # Set CPU governor to schedutil
        for cpu in 0 1 2 3 4 5 6 7; do
            if [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ]; then
                echo "schedutil" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
            fi
            # Restore min/max freqs to allow full range
            if [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ]; then
                echo "0" > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
            fi
            if [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ]; then
                echo "9999999" > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
            fi
        done

        # Set LMK parameters for general use
        if [ -w "$LMK_PATH" ]; then
            echo "16000,32000,64000,128000,144000,180000" > "$LMK_PATH"
        fi

        # Set GPU governor for general use
        if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
            echo "simple_ondemand" > "$GPU_GOVERNOR_PATH"
        fi

        echo "active" > "$STATE_FILE"
    fi
}

# Applies performance settings (gaming mode)
apply_gaming_performance() {
    if [ "$(cat "$STATE_FILE")" != "gaming" ]; then
        echo "Applying performance settings (gaming mode)..." >&2
        # Set CPU governor to performance
        for cpu in 0 1 2 3 4 5 6 7; do
            if [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ]; then
                echo "performance" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
            fi
            # Ensure min/max freqs are at their highest for full performance
            if [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ]; then
                echo "0" > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
            fi
            if [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ]; then
                echo "9999999" > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
            fi
        done

        # Set GPU governor for gaming
        if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
            echo "performance" > "$GPU_GOVERNOR_PATH"
        fi

        echo "gaming" > "$STATE_FILE"
    fi
}

# Applies aggressive screen-off battery saver
apply_screen_off_saver() {
    if [ "$(cat "$STATE_FILE")" != "screen_off" ]; then
        echo "Applying screen OFF battery saver..." >&2
        # Cores 0-5 (Little/Efficiency Cores)
        for cpu in 0 1 2 3 4 5; do
            if [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ]; then
                echo 500000 > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
            fi
            if [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ]; then
                echo 500000 > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
            fi
            if [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ]; then
                echo "powersave" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
            fi
        done
        # Cores 6-7 (Big/Performance Cores)
        for cpu in 6 7; do
            if [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ]; then
                echo 750000 > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
            fi
            if [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ]; then
                echo 750000 > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
            fi
            if [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ]; then
                echo "powersave" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
            fi
        done

        # Set GPU governor for screen off
        if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
            echo "powersave" > "$GPU_GOVERNOR_PATH"
        fi

        echo "screen_off" > "$STATE_FILE"
    fi
}

# Ensure initial state file exists (should be created by customize.sh)
if [ ! -f "$STATE_FILE" ]; then
    echo "active" > "$STATE_FILE" # Fallback, assume general battery saver if file not found
fi

# --- Initial Boot Notification and Setup ---

# Wait for boot to complete
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 5
done

# Post the notification
su -lp 2000 -c "cmd notification post -S bigtext -t 'OxygenBreather' Tag 'Device Oxygenated✨'" >/dev/null &

# --- Main Monitoring Loop ---

while true; do
    # 1. Check screen state first (highest priority)
    IS_SCREEN_ON=$(dumpsys power | grep -iq "mHoldingDisplaySuspendBlocker=true" && echo "true" || echo "false")

    if [ "$IS_SCREEN_ON" == "false" ]; then
        # Screen is OFF: Apply aggressive screen-off saver
        apply_screen_off_saver
    else
        # Screen is ON: Proceed to check for gaming
        FOREGROUND_APP=$(dumpsys activity activities | grep -E 'mResumedActivity|mFocusedWindow' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9\._-]+)\/([a-zA-Z0-9\._-]+) .*/\1/')
        if [ -z "$FOREGROUND_APP" ]; then # Fallback for some devices/versions
            FOREGROUND_APP=$(dumpsys activity activities | grep -E 'topResumedActivity|mFocusedWindow' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9\._-]+)\/([a-zA-Z0-9\._-]+) .*/\1/')
        fi
        if [ -z "$FOREGROUND_APP" ]; then # Last resort for older Android versions
            FOREGROUND_APP=$(dumpsys activity | grep -E 'mCurrentFocus|mFocusedWindow' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9\._-]+)\/([a-zA-Z0-9\._-]+) .*/\1/')
        fi

        IS_GAME_ACTIVE=false
        if [ -f "$GAMELIST" ]; then
            while IFS= read -r game_package; do
                if [ -n "$game_package" ] && [ "$FOREGROUND_APP" == "$game_package" ]; then
                    IS_GAME_ACTIVE=true
                    break
                fi
            done < "$GAMELIST"
        fi

        if "$IS_GAME_ACTIVE"; then
            # Screen ON and a game is active: Apply gaming performance
            apply_gaming_performance
        else
            # Screen ON, but not a game: Apply general battery saver
            apply_general_saver
        fi
    fi

    # Wait for a few seconds before checking again (e.g., 5 seconds)
    sleep 5
done

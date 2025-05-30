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

# OxygenBreather Module Path
MODPATH=${0%/*}

# Configuration files & paths
GAMELIST="$MODPATH/gamelist.txt"
STATE_FILE="$MODPATH/current_state"

CPU_GOVERNOR_BASE="/sys/devices/system/cpu/cpu"
CPU_FREQ_MIN_BASE="/sys/devices/system/cpu/cpu"
CPU_FREQ_MAX_BASE="/sys/devices/system/cpu/cpu"
LMK_PATH="/sys/module/lowmemorykiller/parameters/minfree"
GPU_GOVERNOR_PATH=$(find /sys/class/devfreq/ /sys/devices/platform/ -name "*mali*/governor" 2>/dev/null | head -n 1)

# Apply general performance saver profile
apply_general_saver() {
    [ "$(cat "$STATE_FILE")" = "active" ] && return
    for cpu in 0 1 2 3 4 5 6 7; do
        [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ] && echo "schedutil" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
        [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ] && echo "0" > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
        [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ] && echo "9999999" > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
    done
    [ -w "$LMK_PATH" ] && echo "16000,32000,64000,128000,144000,180000" > "$LMK_PATH"
    if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
        echo "simple_ondemand" > "$GPU_GOVERNOR_PATH"
    fi
    echo "active" > "$STATE_FILE"
}

# Apply gaming performance profile
apply_gaming_performance() {
    [ "$(cat "$STATE_FILE")" = "gaming" ] && return
    for cpu in 0 1 2 3 4 5 6 7; do
        [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ] && echo "performance" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
        [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ] && echo "0" > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
        [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ] && echo "9999999" > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
    done
    if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
        echo "performance" > "$GPU_GOVERNOR_PATH"
    fi
    echo "gaming" > "$STATE_FILE"
}

# Apply screen-off battery saver profile
apply_screen_off_saver() {
    [ "$(cat "$STATE_FILE")" = "screen_off" ] && return
    for cpu in 0 1 2 3 4 5; do
        [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ] && echo 500000 > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
        [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ] && echo 500000 > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
        [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ] && echo "powersave" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
    done
    for cpu in 6 7; do
        [ -w "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq" ] && echo 750000 > "${CPU_FREQ_MIN_BASE}${cpu}/cpufreq/scaling_min_freq"
        [ -w "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq" ] && echo 750000 > "${CPU_FREQ_MAX_BASE}${cpu}/cpufreq/scaling_max_freq"
        [ -w "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor" ] && echo "powersave" > "${CPU_GOVERNOR_BASE}${cpu}/cpufreq/scaling_governor"
    done
    if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
        echo "powersave" > "$GPU_GOVERNOR_PATH"
    fi
    echo "screen_off" > "$STATE_FILE"
}

# Initialize state file if missing
[ ! -f "$STATE_FILE" ] && echo "active" > "$STATE_FILE"

# Wait for system boot completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# Delay notification to avoid instant spam
sleep 25

# Post boot notification
su -lp 2000 -c "cmd notification post -S bigtext -t 'OxygenBreather' Tag 'Device Oxygenated✨'" >/dev/null &

# Main Loop
while true; do
    IS_SCREEN_ON=$(dumpsys power | grep -iq "mHoldingDisplaySuspendBlocker=true" && echo "true" || echo "false")
    
    if [ "$IS_SCREEN_ON" = "false" ]; then
        apply_screen_off_saver
    else
        FOREGROUND_APP=$(dumpsys activity activities | grep -E 'mResumedActivity|mFocusedWindow' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9\._-]+)\/([a-zA-Z0-9\._-]+) .*/\1/')
        if [ -z "$FOREGROUND_APP" ]; then
            FOREGROUND_APP=$(dumpsys activity activities | grep -E 'topResumedActivity|mFocusedWindow' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9\._-]+)\/([a-zA-Z0-9\._-]+) .*/\1/')
        fi
        if [ -z "$FOREGROUND_APP" ]; then
            FOREGROUND_APP=$(dumpsys activity | grep -E 'mCurrentFocus|mFocusedWindow' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9\._-]+)\/([a-zA-Z0-9\._-]+) .*/\1/')
        fi

        IS_GAME_ACTIVE="false"
        game_found_flag="false"

        if [ -n "$FOREGROUND_APP" ] && [ -f "$GAMELIST" ]; then
            while IFS= read -r line_from_gamelist || [ -n "$line_from_gamelist" ]; do
                [ -z "$line_from_gamelist" ] && continue
                OLD_IFS="$IFS"
                IFS='|'
                set -f
                set -- $line_from_gamelist
                set +f
                for game_package_candidate; do
                    [ -n "$game_package_candidate" ] && [ "$FOREGROUND_APP" = "$game_package_candidate" ] && IS_GAME_ACTIVE="true" && game_found_flag="true" && break
                done
                IFS="$OLD_IFS"
                [ "$game_found_flag" = "true" ] && break
            done < "$GAMELIST"
        fi

        if [ "$IS_GAME_ACTIVE" = "true" ]; then
            apply_gaming_performance
        else
            apply_general_saver
        fi
    fi

    sleep 5
done
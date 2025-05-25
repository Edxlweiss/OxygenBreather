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

# Magisk module path
MODPATH=${0%/*}

ui_print "- Uninstalling MyBatterySaver..."

# --- Revert Settings ---

# Revert CPU governors to a common default (schedutil is often a good system default for MTK)
for cpu in 0 1 2 3 4 5 6 7; do
    if [ -w "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor" ]; then
        echo "schedutil" > "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor"
    fi
    # Ensure min/max freqs are reset to kernel defaults
    if [ -w "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_min_freq" ]; then
        echo "0" > "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_min_freq"
    fi
    if [ -w "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq" ]; then
        echo "9999999" > "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq"
    fi
done

# Revert LMK to common system defaults for MTK (adjust if your ROM uses different ones)
if [ -w "/sys/module/lowmemorykiller/parameters/minfree" ]; then
    echo "18432,23040,27648,36864,46080,55296" > /sys/module/lowmemorykiller/parameters/minfree
fi

# Revert GPU governor (assuming Mali GPU on MTK G99/G100)
GPU_GOVERNOR_PATH=$(find /sys/class/devfreq/ /sys/devices/platform/ -name "*mali*/governor" 2>/dev/null | head -n 1)
if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
    echo "simple_ondemand" > "$GPU_GOVERNOR_PATH" # Restore to a common default
    ui_print "  Restored GPU governor to simple_ondemand."
fi

# Remove the state file
rm -f "$MODPATH/current_state"

ui_print "- Uninstallation complete."

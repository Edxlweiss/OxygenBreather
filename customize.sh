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

# Remove the line below that sources util_functions.sh
# . "$MODPATH"/util_functions.sh

# Redefine ui_print for KernelSU compatibility
ui_print() {
  echo "$1" >&2
}

ui_print "- Installing Oxygen Breather for MTK G99/G100..."

# --- Run Verification First ---
# Ensure verify.sh is executable
chmod +x "$MODPATH/verify.sh"

ui_print "Running module integrity check..."
if "$MODPATH/verify.sh"; then
    ui_print "Module files verified successfully!"
else
    ui_print "ERROR: Module files failed integrity check. Aborting installation!"
    # Exit with a non-zero status to signal installation failure
    exit 1
fi

# --- Initial Setup Functions ---

# Applies general battery saver settings (screen ON, not gaming) for initial install
apply_general_saver_initial() {
    ui_print "  Applying initial general battery saver settings..."
    # Set CPU governor to schedutil (balanced performance/efficiency)
    for cpu in 0 1 2 3 4 5 6 7; do
        if [ -w "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor" ]; then
            echo "schedutil" > "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor"
        fi
        # Ensure min/max freqs are reset to allow full range (kernel's defaults)
        if [ -w "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_min_freq" ]; then
            echo "0" > "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_min_freq"
        fi
        if [ -w "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq" ]; then
            echo "9999999" > "/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq"
        fi
    done

    # Set LMK parameters for general use (more aggressive than default)
    if [ -w "/sys/module/lowmemorykiller/parameters/minfree" ]; then
        echo "16000,32000,64000,128000,144000,180000" > /sys/module/lowmemorykiller/parameters/minfree
    fi

    # Initialize GPU governor (assuming Mali GPU on MTK G99/G100)
    GPU_GOVERNOR_PATH=$(find /sys/class/devfreq/ /sys/devices/platform/ -name "*mali*/governor" 2>/dev/null | head -n 1)
    if [ -n "$GPU_GOVERNOR_PATH" ] && [ -w "$GPU_GOVERNOR_PATH" ]; then
        echo "simple_ondemand" > "$GPU_GOVERNOR_PATH"
        ui_print "  Set initial GPU governor to simple_ondemand."
    else
        ui_print "  Warning: Could not find or write to GPU governor path. GPU tweaks may not apply."
    fi

    # Set initial state
    echo "active" > "$MODPATH/current_state"
}

# Apply default battery saver settings on initial install
apply_general_saver_initial

# Ensure service.sh is executable
chmod +x "$MODPATH/service.sh"

ui_print "- Installation complete. Reboot your device to apply changes."

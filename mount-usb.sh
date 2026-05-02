#!/bin/bash
set -euo pipefail

# Find USB block devices by checking if the device's removable flag is set
# or if it's connected via USB in the sysfs tree
usb_devs=()
for dev in /sys/block/sd*; do
    [ -e "$dev" ] || continue
    devname=$(basename "$dev")
    # Check if the device is connected via USB
    if readlink -f "$dev" | grep -q usb; then
        usb_devs+=("/dev/$devname")
    fi
done

if [ ${#usb_devs[@]} -eq 0 ]; then
    echo "No USB storage device found."
    exit 1
fi

if [ ${#usb_devs[@]} -gt 1 ]; then
    echo "Multiple USB devices found:"
    for i in "${!usb_devs[@]}"; do
        size=$(lsblk -dno SIZE "${usb_devs[$i]}" 2>/dev/null || echo "unknown")
        model=$(lsblk -dno MODEL "${usb_devs[$i]}" 2>/dev/null || echo "unknown")
        echo "  [$i] ${usb_devs[$i]}  $size  $model"
    done
    read -rp "Select device [0]: " choice
    choice=${choice:-0}
    dev="${usb_devs[$choice]}"
else
    dev="${usb_devs[0]}"
fi

echo "USB device: $dev"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$dev"

# Pick the first partition, or the whole device if no partitions exist
part=$(lsblk -lnpo NAME "$dev" | grep -v "^${dev}$" | head -1)
if [ -z "$part" ]; then
    part="$dev"
fi

echo "Mounting $part to /mnt/usb ..."
sudo mkdir -p /mnt/usb
sudo mount "$part" /mnt/usb
echo "Mounted successfully."

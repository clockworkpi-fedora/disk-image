#!/bin/bash

SCRIPT_NAME="$(basename "$0")"
if [[ $EUID -ne 0 ]]; then
   echo "$SCRIPT_NAME must be run as root. Please use sudo."
   exit 1
fi

# Globals
RSYNC_URL="rsync://dl.fedoraproject.org/fedora-alt/iot/43/IoT/aarch64/images/"
CONTAINER_IMAGE="localhost/cf-lxqt:latest"
BOOTC_IMAGE="quay.io/fedora/fedora-bootc:43"
WORKING_IMAGE_FILE=working.raw
OUTPUT_NAME="Clockworkpi-Fedora-LXQT-raw-43"
LOOP_DEV=""
SRC_DIR="../deploy"


RAW_IMAGE_FILE=$(rsync --list-only "$RSYNC_URL" | awk '{print $5}' | grep 'Fedora-IoT-raw-.*\.raw\.xz$' | sort -V | tail -n 1)
if [ -z "$RAW_IMAGE_FILE" ]; then
    echo "Error: File not found."
    exit 1
fi

if [ ! -e "$RAW_IMAGE_FILE" ]; then
  echo "Downloading $RAW_IMAGE_FILE"
  rsync -P "$RSYNC_URL/$RAW_IMAGE_FILE" .
else
  echo "Found $RAW_IMAGE_FILE. Not downloading."
fi

cleanup() {
  echo "Cleaning up..."
  if [ -n "$LOOP_DEV" ]; then
    losetup -d "$LOOP_DEV"
    echo "Detatched ($LOOP_DEV)"
  fi
  echo "Done."
}
trap cleanup EXIT

unxz -v --stdout $RAW_IMAGE_FILE > $WORKING_IMAGE_FILE

echo "Setting up Loopback Device..."
LOOP_DEV=$(losetup -fP --show "$WORKING_IMAGE_FILE")
partprobe "$LOOP_DEV" || true
udevadm settle

echo "Attached to $LOOP_DEV"

P_ESP="${LOOP_DEV}p1"
P_BOOT="${LOOP_DEV}p2"
P_ROOT="${LOOP_DEV}p3"

echo "Wiping root and boot partitions (keep ESP/EFI)..."
if [[ "$P_ROOT" != /dev/loop* ]] || [[ "$P_BOOT" != /dev/loop* ]]; then
    echo "CRITICAL ERROR: Target device is not a loop device!"
    echo "Aborting immediately to protect host filesystem."
    exit 1
fi
echo "FORMATTING $P_ROOT. Press Enter to continue."
read
mkfs.ext4 -F "$P_ROOT"

echo "FORMATTING $P_BOOT. Press Enter to continue."
read
mkfs.ext4 -F "$P_BOOT"

SCRIPT="
set -e
set -x
mkdir -p /target
mount "$P_ROOT" "/target"
mkdir -p /target/boot
mount "$P_BOOT" "/target/boot"
mkdir -p /target/boot/efi
mount "$P_ESP" "/target/boot/efi"
bootc install to-filesystem /target \
  --source-imgref "containers-storage:$CONTAINER_IMAGE" \
  --skip-finalize --skip-fetch-check \
"

echo "Temorarily disabling selinux..."
setenforce 0
echo "Installing Clockworkpi Fedora to disk image. This will take a while..."
podman run --rm --privileged --platform=linux/arm64 \
  --security-opt label=disable \
  --device $LOOP_DEV \
  --device $P_ESP \
  --device $P_BOOT \
  --device $P_ROOT \
  -v /var/lib/containers:/var/lib/containers \
  "$BOOTC_IMAGE" \
  /usr/bin/bash -c "$SCRIPT"
echo "Re-enabling selinux..."
setenforce 1

echo "Mounting ESP to apply config.txt and overlays..."
MOUNT_DIR=$(mktemp -d)
mkdir -p $MOUNT_DIR
mount "$P_ESP" "$MOUNT_DIR"

cp "$SRC_DIR/config.txt" "$MOUNT_DIR"
cp -r "$SRC_DIR/overlays" "$MOUNT_DIR/"

echo "Unmounting ESP..."
umount $MOUNT_DIR
rmdir "$MOUNT_DIR"

echo "Compressing final image to xz..."
xz "$WORKING_IMAGE_FILE"
mv $WORKING_IMAGE_FILE.xz $OUTPUT_NAME.raw.xz

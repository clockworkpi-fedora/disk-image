#!/bin/bash
# AXP221 Manual Power-Off
sync
sleep 0.5
echo "0-0034" > /sys/bus/i2c/drivers/axp20x-i2c/unbind 2>/dev/null || true
sleep 0.5
i2cset -y 0 0x34 0x32 0xcb 2>/dev/null || true

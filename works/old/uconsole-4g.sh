#!/bin/bash

GPIOCHIP="gpiochip0"
GPIO_POWER=24
GPIO_ENABLE=15

function enable4g {
    echo "Powering on 4G module..."
    
    # Kill any existing gpioset
    pkill -f "gpioset.*$GPIO_POWER" 2>/dev/null
    pkill -f "gpioset.*$GPIO_ENABLE" 2>/dev/null
    sleep 1
    
    gpioset -c $GPIOCHIP -z $GPIO_POWER=1
    gpioset -c $GPIOCHIP -p 5s -t 0 $GPIO_ENABLE=1
    
    echo "Waiting 25 seconds for modem boot..."
    sleep 25
    
    echo "Restarting ModemManager..."
    systemctl restart ModemManager
    sleep 6
    
    echo "Testing modem..."
    if [ -e /dev/ttyUSB2 ]; then
        echo "/dev/ttyUSB2 exists"
        mmcli -L
    else
        echo "ERROR: /dev/ttyUSB2 not found"
    fi
}

function disable4g {
    echo "Powering off 4G module..."
    
    pkill -f "gpioset.*$GPIO_POWER" 2>/dev/null
    sleep 3
    gpioset -c $GPIOCHIP -t 0 $GPIO_POWER=0

    gpioset -c $GPIOCHIP -p 3s -t 0 $GPIO_POWER=1
    
    gpioset -c $GPIOCHIP -t 0 $GPIO_POWER=0
    
    echo "Waiting 25 seconds for modem poweroff..."
    sleep 25
    
    if [ -e /dev/ttyUSB2 ]; then
        echo "WARNING: /dev/ttyUSB2 still exists (modem may still be on)"
    else
        echo "Modem powered off."
    fi
}

function status4g {
    if pgrep -f "gpioset.*$GPIO_POWER" >/dev/null; then
        echo "Power GPIO is held HIGH"
    else
        echo "Power GPIO is OFF"
    fi
    
    if [ -e /dev/ttyUSB2 ]; then
        echo "/dev/ttyUSB2 exists"
    else
        echo "/dev/ttyUSB2 does not exist"
    fi
    
    mmcli -L 2>/dev/null || echo "No modems in ModemManager"
}

case "${1:-}" in
    enable) enable4g ;;
    disable) disable4g ;;
    status) status4g ;;
    *) echo "Usage: $0 {enable|disable|status}"; exit 1 ;;
esac

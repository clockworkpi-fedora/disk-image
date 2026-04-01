#!/bin/bash

GPIOCHIP="gpiochip0"
GPIO_POWER=24
GPIO_ENABLE=15

function enable {
    echo "Powering on 4G module..."
    
    gpioset -c $GPIOCHIP -p 20s -t 0 -z $GPIO_POWER=1
    gpioset -c $GPIOCHIP -p 5s -t 0 -z $GPIO_ENABLE=1
    
    echo "Waiting 13 seconds for modem boot..."
    sleep 13
    
    echo "Restarting ModemManager..."
    systemctl restart ModemManager
    
    echo "Testing modem..."
    if [ -e /dev/ttyUSB2 ]; then
        echo "/dev/ttyUSB2 exists"
    else
        echo "ERROR: /dev/ttyUSB2 not found"
    fi
}

function disable {
    echo "Powering off 4G module..."    

    gpioset -c $GPIOCHIP -p 10s -t 0 -z $GPIO_ENABLE=0
    gpioset -c $GPIOCHIP -p 1s -t 0 $GPIO_POWER=0
    gpioset -c $GPIOCHIP -p 3s -t 0 $GPIO_POWER=1
    
    echo "Waiting 25 seconds for modem poweroff..."
    sleep 25
    
    if [ -e /dev/ttyUSB2 ]; then
        echo "WARNING: /dev/ttyUSB2 still exists (modem may still be on)"
    else
        echo "Modem powered off."
    fi
}

function status {
    if [ -e /dev/ttyUSB2 ]; then
        echo "/dev/ttyUSB2 exists"
    else
        echo "/dev/ttyUSB2 does not exist"
    fi
    
    mmcli -L 2>/dev/null || echo "No modems in ModemManager"
}

case "${1:-}" in
    enable) enable ;;
    disable) disable ;;
    status) status ;;
    *) echo "Usage: $0 {enable|disable|status}"; exit 1 ;;
esac

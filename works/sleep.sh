#!/bin/bash

STATE_DIR="/var/run/deep-idle"
mkdir -p "$STATE_DIR"

display() {
	if [ "$1" -eq 1 ] ; then
		for bl in /sys/class/backlight/*/brightness; do
			[ -f "$bl" ] || continue
			cat "$bl" > "$STATE_DIR/backlight_$(basename $(dirname $bl))"
			echo o > "$bl"
		done

		for fb in /sys/class/graphics/fb*/blank; do
			[ -f "$fb" ] && echo 1 > "$fb"
		done
	else
		for bl in /sys/class/backlight/*/brightness; do
                        [ -f "$bl" ] || continue
			state="$STATE_DIR/backlight_"
                done
}

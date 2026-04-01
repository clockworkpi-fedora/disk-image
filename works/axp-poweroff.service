[Unit]
Description=AXP20x Hardware Power Off
DefaultDependencies=no
Before=unmount.target final.target
Conflicts=reboot.target kexec.target

[Service]
Type=oneshot
ExecStart=/var/usrlocal/bin/axp-poweroff.sh
StandardOutput=journal+console
StandardError=journal+console
TimeoutStartSec=10

[Install]
WantedBy=poweroff.target halt.target

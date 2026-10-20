#!/usr/bin/env bash
# Tank Squad GCP builder: runs as root on every boot (instance metadata startup-script).
# Starts ZeroTier and installs the idle auto-stop: the VM powers itself off after IDLE_STOP_MIN minutes in which no
# `make` runs for any user, so a forgotten burst never bills overnight. Spot preemption stops it too; `make gcp-start`
# wakes it either way.
set -u
exec >>/var/log/tanksquad_startup.log 2>&1
echo "=== tanksquad startup $(date) ==="

systemctl start zerotier-one 2>/dev/null || true

MIN=$(curl -fsS -H Metadata-Flavor:Google \
	http://metadata.google.internal/computeMetadata/v1/instance/attributes/idle-stop-min 2>/dev/null || echo 20)

cat >/usr/local/bin/tanksquad-idle-stop <<EOF
#!/usr/bin/env bash
# Called every minute by tanksquad-idle-stop.timer. Counts consecutive idle minutes in a state file.
STATE=/run/tanksquad-idle-minutes
if pgrep -x make >/dev/null || [ "\$(cut -d. -f1 /proc/uptime)" -lt 600 ]; then
	echo 0 >"\$STATE"; exit 0
fi
n=\$(( \$(cat "\$STATE" 2>/dev/null || echo 0) + 1 ))
echo "\$n" >"\$STATE"
if [ "\$n" -ge $MIN ]; then
	logger "tanksquad: idle for $MIN min with no make running: powering off"
	shutdown -h now
fi
EOF
chmod +x /usr/local/bin/tanksquad-idle-stop

cat >/etc/systemd/system/tanksquad-idle-stop.service <<'EOF'
[Unit]
Description=Tank Squad builder: power off when idle
[Service]
Type=oneshot
ExecStart=/usr/local/bin/tanksquad-idle-stop
EOF
cat >/etc/systemd/system/tanksquad-idle-stop.timer <<'EOF'
[Unit]
Description=Tank Squad builder: idle check every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now tanksquad-idle-stop.timer
echo "idle auto-stop armed: $MIN min"

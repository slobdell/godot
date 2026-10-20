#!/usr/bin/env bash
# Tank Squad's own GCP Spot build machine (2026-10-19; _agents/gcp_builder.md "Choosing a cheaper machine").
# Creates the VM if it doesn't exist, installs the build toolchain, joins ZeroTier and arms the idle auto-stop.
# It recreates builder2 (balsa-worker-gcp, shared with plane_maker) if it is ever lost; it never modifies a VM that exists.
#
#   make gcp-provision                  # defaults below; override any GCP_* on the make line or in local.mk
#   GCP_MACHINE=e2-highcpu-32 GCP_ZONE=us-west4-a tools/gcp/provision.sh
#
# After the first run: authorize the printed ZeroTier node in my.zerotier.com, give it a static IP, and map that IP
# to builder2 in /etc/hosts (the converted VM kept 10.115.229.9). Then `make gcp-status` answers over ZeroTier.
set -euo pipefail

GCP_PROJECT="${GCP_PROJECT:-leddrones}"
GCP_ZONE="${GCP_ZONE:-us-west4-a}"
GCP_VM="${GCP_VM:-balsa-worker-gcp}"
GCP_MACHINE="${GCP_MACHINE:-e2-highcpu-32}"
GCP_DISK_GB="${GCP_DISK_GB:-40}"
GCP_SSH_USER="${GCP_SSH_USER:-slobdell}"
GCP_SSH_KEY="${GCP_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}"
ZEROTIER_NETWORK_ID="${ZEROTIER_NETWORK_ID:-f3797ba7a8546f34}"
IDLE_STOP_MIN="${IDLE_STOP_MIN:-20}"
HERE="$(cd "$(dirname "$0")" && pwd)"
G=(--project="$GCP_PROJECT" --zone="$GCP_ZONE")

command -v gcloud >/dev/null || { echo "gcloud is not installed"; exit 1; }
[ -f "$GCP_SSH_KEY" ] || { echo "no ssh public key at $GCP_SSH_KEY"; exit 1; }

# C3/C4/M3/H3 families need Hyperdisk; everything else gets the cheaper pd-balanced.
DISK_TYPE=pd-balanced
[[ "$GCP_MACHINE" =~ ^(c3|c4|m3|h3) ]] && DISK_TYPE=hyperdisk-balanced

if gcloud compute instances describe "$GCP_VM" "${G[@]}" >/dev/null 2>&1; then
	echo ">> gcp: $GCP_VM already exists in $GCP_ZONE; skipping creation"
else
	echo ">> gcp: creating $GCP_VM: $GCP_MACHINE SPOT, ${GCP_DISK_GB} GB $DISK_TYPE, $GCP_ZONE"
	KEYS=$(mktemp); trap 'rm -f "$KEYS"' EXIT
	echo "${GCP_SSH_USER}:$(cat "$GCP_SSH_KEY")" > "$KEYS"
	gcloud compute instances create "$GCP_VM" "${G[@]}" \
		--machine-type="$GCP_MACHINE" \
		--provisioning-model=SPOT --instance-termination-action=STOP \
		--image-family=ubuntu-2604-lts-amd64 --image-project=ubuntu-os-cloud \
		--boot-disk-size="${GCP_DISK_GB}GB" --boot-disk-type="$DISK_TYPE" \
		--metadata-from-file="ssh-keys=$KEYS,startup-script=$HERE/startup.sh" \
		--metadata="idle-stop-min=$IDLE_STOP_MIN"
fi

echo ">> gcp: waiting for ssh"
for i in $(seq 1 40); do
	gcloud compute ssh "$GCP_VM" "${G[@]}" --command=true >/dev/null 2>&1 && break
	[ "$i" = 40 ] && { echo ">> gcp: ssh never answered"; exit 1; }
	sleep 5
done

echo ">> gcp: toolchain (the same as builder0: Ubuntu 26.04, glibc 2.43, g++, cmake, python3; Godot and Node come from"
echo "   tools/remote.sh's first-use bootstrap) and ZeroTier"
gcloud compute ssh "$GCP_VM" "${G[@]}" --command="set -e
	sudo DEBIAN_FRONTEND=noninteractive apt-get update -q
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq build-essential cmake python3 python3-yaml rsync git curl unzip
	command -v zerotier-cli >/dev/null || curl -fsSL https://install.zerotier.com | sudo bash
	sudo systemctl enable --now zerotier-one
	sudo zerotier-cli join $ZEROTIER_NETWORK_ID >/dev/null
	sudo bash -c 'curl -fsS -H Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/attributes/startup-script | bash'
	echo ZT_NODE=\$(sudo zerotier-cli info | awk '{print \$3}')
	echo GLIBC=\$(ldd --version | head -1)
	echo THREADS=\$(nproc) MEM=\$(free -g | awk '/Mem/{print \$2}')G"

cat <<EOF
>> gcp: $GCP_VM is up. One-time steps (the lead):
   1. my.zerotier.com, network $ZEROTIER_NETWORK_ID: authorize the ZT_NODE above and give it a static IP.
   2. /etc/hosts on the laptop: "<that IP>  builder2".
   3. make gcp-status   (should answer over ZeroTier), then make gcp-remote T=quick (first use bootstraps Godot).
   It stops itself after ${IDLE_STOP_MIN} min with no make running (tools/gcp/startup.sh); make gcp-start wakes it.
EOF

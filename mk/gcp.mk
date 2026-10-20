# ---- GCP burst builder (round 33, 2026-10-17): _agents/gcp_builder.md ------------------------------------------
# A second remote build machine, powered on only when we want more throughput. The same tools/remote.sh drives it
# (REMOTE_HOST); builder0 stays the default for every target. Override any of these in local.mk (git-ignored).
# 2026-10-19: Tank Squad's own cost-optimized Spot VM (tools/gcp/provision.sh; _agents/gcp_builder.md "Choosing a cheaper
# machine"). plane_maker's balsa-worker-gcp (c4d-standard-32, us-west1-a, builder2) is untouched: reach it with
# GCP_VM=balsa-worker-gcp GCP_ZONE=us-west1-a GCP_HOST=slobdell@builder2.
GCP_PROJECT ?= leddrones
GCP_ZONE ?= us-west4-a
GCP_VM ?= tanksquad-builder
GCP_MACHINE ?= e2-highcpu-32
GCP_HOST ?= slobdell@builder3
GCLOUD ?= gcloud
_GCP = $(GCLOUD) compute instances --project=$(GCP_PROJECT)

.PHONY: gcp-status gcp-start gcp-stop gcp-remote gcp-provision
gcp-provision: ## GCP builder: create Tank Squad's Spot VM if missing (GCP_MACHINE, default e2-highcpu-32 in us-west4-a), toolchain, ZeroTier, idle auto-stop
	GCP_PROJECT=$(GCP_PROJECT) GCP_ZONE=$(GCP_ZONE) GCP_VM=$(GCP_VM) GCP_MACHINE=$(GCP_MACHINE) tools/gcp/provision.sh

gcp-status: ## GCP burst builder: its power state and provisioning model, and whether ssh answers over ZeroTier
	@$(_GCP) describe $(GCP_VM) --zone=$(GCP_ZONE) --format="value(status,scheduling.provisioningModel,machineType.basename())"
	@ssh -o BatchMode=yes -o ConnectTimeout=5 $(GCP_HOST) 'echo "ssh ok: $$(nproc) threads, load $$(cut -d" " -f1-3 /proc/loadavg)"' 2>/dev/null \
		|| echo "ssh: no answer from $(GCP_HOST) (stopped, booting, or ZeroTier not up yet)"

gcp-start: ## GCP burst builder: power it on (billing starts) and wait until ssh answers over ZeroTier
	$(_GCP) start $(GCP_VM) --zone=$(GCP_ZONE)
	@for i in $$(seq 1 30); do ssh -o BatchMode=yes -o ConnectTimeout=5 $(GCP_HOST) true 2>/dev/null && { echo ">> gcp: ssh answers ($(GCP_HOST))"; exit 0; }; sleep 5; done; \
		echo ">> gcp: started, but ssh has not answered in 150 s: check ZeroTier"; exit 1

gcp-stop: ## GCP burst builder: power it off (compute billing stops; its disk still bills; it also stops itself after 20 idle min). Refuses while a make runs there
	@busy=$$(ssh -o BatchMode=yes -o ConnectTimeout=5 $(GCP_HOST) 'pgrep -u $$USER -x make | wc -l' 2>/dev/null || echo 0); \
	if [ "$${busy:-0}" -gt 0 ] && [ "$(FORCE)" != 1 ]; then \
		echo ">> gcp: REFUSED: $$busy make process(es) still running there; FORCE=1 to stop anyway"; exit 1; fi
	$(_GCP) stop $(GCP_VM) --zone=$(GCP_ZONE)

gcp-remote: ## Run a make target on the GCP burst builder instead of builder0: T="check" (same rules as make remote)
	@REMOTE_HOST=$(GCP_HOST) $(MAKE) --no-print-directory remote T="$(T)" LIGHT=$(LIGHT)

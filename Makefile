POCKET_SD ?= $(if $(wildcard pocket),$(abspath pocket),/Volumes/Pocket)
EJECT_AFTER_INSTALL ?= 1
SKELETON := src/apf_amstrad_skeleton
CORE_ID := steve.AmstradCPC
PLATFORM_ID := amstrad
RSYNC_POCKET := rsync -r --inplace --no-perms --no-owner --no-group --omit-dir-times --exclude='._*' --exclude='.DS_Store'
RSYNC_POCKET_DIR := $(RSYNC_POCKET) --delete
POCKET_CORE_DIR := $(POCKET_SD)/Cores/$(CORE_ID)
POCKET_PLATFORM_DIR := $(POCKET_SD)/Platforms
POCKET_ASSET_DIR := $(POCKET_SD)/Assets/$(PLATFORM_ID)/$(CORE_ID)
BOOT_ROM_SOURCE ?= upstreams/Amstrad_MiSTer/releases/boot.rom

.PHONY: check build-skeleton install-pocket

check:
	python3 scripts/check_expected_files.py
	python3 scripts/check_skeleton.py

build-skeleton:
	scripts/build_skeleton_docker.sh

install-pocket: check
	@test -d "$(POCKET_SD)" || (echo "Pocket SD mount not found: $(POCKET_SD)" >&2; exit 1)
	@test -f "$(SKELETON)/Cores/$(CORE_ID)/bitstream.rbf_r" || (echo "Missing packaged bitstream; run make build-skeleton" >&2; exit 1)
	mkdir -p "$(POCKET_SD)/Cores" "$(POCKET_PLATFORM_DIR)" "$(POCKET_SD)/Assets/$(PLATFORM_ID)"
	find "$(POCKET_CORE_DIR)" "$(POCKET_ASSET_DIR)" -name '._*' -delete 2>/dev/null || true
	find "$(POCKET_PLATFORM_DIR)" -maxdepth 1 -name '._$(PLATFORM_ID).json' -delete 2>/dev/null || true
	$(RSYNC_POCKET_DIR) "$(SKELETON)/Cores/$(CORE_ID)/" "$(POCKET_CORE_DIR)/"
	$(RSYNC_POCKET) "$(SKELETON)/Platforms/$(PLATFORM_ID).json" "$(POCKET_PLATFORM_DIR)/"
	# Preserve Pocket-side runtime assets such as boot ROMs and mounted media.
	$(RSYNC_POCKET) "$(SKELETON)/Assets/$(PLATFORM_ID)/$(CORE_ID)/" "$(POCKET_ASSET_DIR)/"
	@if [ -f "$(BOOT_ROM_SOURCE)" ]; then \
		$(RSYNC_POCKET) "$(BOOT_ROM_SOURCE)" "$(POCKET_ASSET_DIR)/"; \
	fi
	@echo "Installed $(CORE_ID) to $(POCKET_SD)"
	@if [ "$(EJECT_AFTER_INSTALL)" = "1" ]; then \
		echo "Flushing writes and ejecting $(POCKET_SD)"; \
		disk_id=$$(diskutil info "$(POCKET_SD)" | awk -F': *' '/Part of Whole/ {print $$2; exit}'); \
		sync; \
		if ! diskutil eject "$(POCKET_SD)"; then \
			if [ -z "$$disk_id" ]; then \
				echo "Unable to determine disk identifier for $(POCKET_SD)" >&2; \
				exit 1; \
			fi; \
			echo "Normal eject failed; forcing unmount of $$disk_id"; \
			diskutil unmountDisk force "$$disk_id"; \
			diskutil eject "$$disk_id"; \
		fi; \
	fi

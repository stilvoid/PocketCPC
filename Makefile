POCKET_SD ?= /Volumes/Pocket
EJECT_AFTER_INSTALL ?= 1
SKELETON := src/apf_amstrad_skeleton
CORE_ID := steve.AmstradCPC
PLATFORM_ID := amstrad
RSYNC_POCKET := rsync -r --inplace --no-perms --no-owner --no-group --omit-dir-times --exclude='._*' --exclude='.DS_Store'

.PHONY: check build-skeleton install-pocket

check:
	python3 scripts/check_expected_files.py
	python3 scripts/check_skeleton.py

build-skeleton:
	scripts/build_skeleton_docker.sh

install-pocket: check
	@test -d "$(POCKET_SD)" || (echo "Pocket SD mount not found: $(POCKET_SD)" >&2; exit 1)
	@test -f "$(SKELETON)/Cores/$(CORE_ID)/bitstream.rbf_r" || (echo "Missing packaged bitstream; run make build-skeleton" >&2; exit 1)
	mkdir -p "$(POCKET_SD)/Cores" "$(POCKET_SD)/Platforms" "$(POCKET_SD)/Assets/$(PLATFORM_ID)"
	$(RSYNC_POCKET) "$(SKELETON)/Cores/$(CORE_ID)/" "$(POCKET_SD)/Cores/$(CORE_ID)/"
	$(RSYNC_POCKET) "$(SKELETON)/Platforms/$(PLATFORM_ID).json" "$(POCKET_SD)/Platforms/"
	$(RSYNC_POCKET) "$(SKELETON)/Assets/$(PLATFORM_ID)/$(CORE_ID)/" "$(POCKET_SD)/Assets/$(PLATFORM_ID)/$(CORE_ID)/"
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

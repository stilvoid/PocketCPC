# User-configurable.
POCKET_SD ?= /Volumes/Pocket
REPORT_STRICT ?= 1

# Internal layout.
CORE_ID := stilvoid.PocketCPC
PACKAGE_DIR := build/package
QUARTUS_DIR := build/quartus
REPORT_SCRIPT := scripts/report_build.py
CORE_JSON_TEMPLATE := src/pocket/Cores/$(CORE_ID)/core.json
STAGED_CORE_DIR := $(PACKAGE_DIR)/Cores/$(CORE_ID)
STAGED_CORE_JSON := $(STAGED_CORE_DIR)/core.json
STAGED_BITSTREAM := $(STAGED_CORE_DIR)/bitstream.rbf_r
STAGED_BUILD_INFO := $(STAGED_CORE_DIR)/build-info.txt
STAGE_STAMP := $(PACKAGE_DIR)/.stage.stamp
QUARTUS_SYNC_STAMP := $(QUARTUS_DIR)/.source-sync.stamp
QUARTUS_BUILD_STAMP := $(QUARTUS_DIR)/.artifacts.stamp
CORE_VERSION_RAW := $(shell git -C . describe --tags --always --match 'v*' 2>/dev/null || git -C . rev-parse --short HEAD 2>/dev/null || echo unknown)
CORE_VERSION := $(patsubst v%,%,$(CORE_VERSION_RAW))
PACKAGE_ZIP := dist/$(CORE_ID)-$(CORE_VERSION).zip
GIT_HEAD_PATH := $(shell git -C . rev-parse --git-path HEAD 2>/dev/null)
GIT_PACKED_REFS_PATH := $(shell git -C . rev-parse --git-path packed-refs 2>/dev/null)
GIT_REFS_HEADS_PATH := $(shell git -C . rev-parse --git-path refs/heads 2>/dev/null)
GIT_REFS_TAGS_PATH := $(shell git -C . rev-parse --git-path refs/tags 2>/dev/null)
GIT_METADATA_INPUTS := $(GIT_HEAD_PATH) $(wildcard $(GIT_PACKED_REFS_PATH)) $(shell find $(GIT_REFS_HEADS_PATH) $(GIT_REFS_TAGS_PATH) -type f 2>/dev/null | sort)

FPGA_BUILD_INPUTS := $(shell find src/fpga \
	\( -path 'src/fpga/db' -o \
	   -path 'src/fpga/incremental_db' -o \
	   -path 'src/fpga/output_files' -o \
	   -path 'src/fpga/simulation' \) -prune -o \
	-type f \( -name '*.sv' -o \
	           -name '*.v' -o \
	           -name '*.vhd' -o \
	           -name '*.vhdl' -o \
	           -name '*.qsf' -o \
	           -name '*.qpf' -o \
	           -name '*.qip' -o \
	           -name '*.sdc' -o \
	           -name '*.tcl' -o \
	           -name '*.mif' \) \
	-print | sort)

PACKAGE_TEMPLATE_INPUTS := $(shell find \
	src/pocket/Assets \
	src/pocket/Platforms \
	src/pocket/Cores/$(CORE_ID) \
	-type f \
	! -name 'bitstream.rbf_r' \
	! -name 'build-info.txt' \
	-print | sort)

.DEFAULT_GOAL := build

.PHONY: build install dist clean report

build: $(STAGE_STAMP) $(STAGED_CORE_JSON) $(STAGED_BITSTREAM) $(STAGED_BUILD_INFO)

report: $(STAGED_CORE_JSON) $(STAGED_BITSTREAM) $(STAGED_BUILD_INFO) $(REPORT_SCRIPT)
	python3 "$(REPORT_SCRIPT)" $(if $(filter 0 false no off,$(REPORT_STRICT)),,--strict)

$(STAGE_STAMP): $(PACKAGE_TEMPLATE_INPUTS)
	mkdir -p "$(PACKAGE_DIR)" "$(STAGED_CORE_DIR)"
	rm -rf "$(PACKAGE_DIR)/Assets" "$(PACKAGE_DIR)/Platforms"
	cp -R "src/pocket/Assets" "$(PACKAGE_DIR)/Assets"
	cp -R "src/pocket/Platforms" "$(PACKAGE_DIR)/Platforms"
	find "$(STAGED_CORE_DIR)" -mindepth 1 -maxdepth 1 -type f ! -name 'bitstream.rbf_r' ! -name 'build-info.txt' -delete
	cp -R "src/pocket/Cores/$(CORE_ID)/." "$(STAGED_CORE_DIR)/"
	rm -f "$(STAGED_CORE_JSON)"
	touch "$@"

$(QUARTUS_SYNC_STAMP): $(FPGA_BUILD_INPUTS)
	mkdir -p "$(QUARTUS_DIR)"
	find "$(QUARTUS_DIR)" -mindepth 1 -maxdepth 1 \
		! -name 'build_monitor' \
		! -name 'db' \
		! -name 'incremental_db' \
		! -name 'output_files' \
		! -name 'simulation' \
		! -name 'c5_pin_model_dump.txt' \
		-exec rm -rf {} +
	cp -R "src/fpga/." "$(QUARTUS_DIR)/"
	touch "$@"

$(STAGED_CORE_JSON): $(STAGE_STAMP) $(CORE_JSON_TEMPLATE) scripts/update_core_metadata.py $(GIT_METADATA_INPUTS)
	cp "$(CORE_JSON_TEMPLATE)" "$@"
	python3 scripts/update_core_metadata.py "$@"

$(QUARTUS_BUILD_STAMP): $(QUARTUS_SYNC_STAMP) scripts/build_core_docker.sh scripts/reverse_rbf_bits.py
	scripts/build_core_docker.sh
	@test -f "$(STAGED_BITSTREAM)"
	@test -f "$(STAGED_BUILD_INFO)"
	touch "$@"

$(STAGED_BITSTREAM): $(QUARTUS_BUILD_STAMP)

$(STAGED_BUILD_INFO): $(QUARTUS_BUILD_STAMP)

install: dist
	@test -d "$(POCKET_SD)" || (echo "Pocket SD mount not found: $(POCKET_SD)" >&2; exit 1)
	unzip -oq "$(PACKAGE_ZIP)" -d "$(POCKET_SD)"
	@echo "Installed $(CORE_ID) to $(POCKET_SD)"

dist: $(PACKAGE_ZIP)

$(PACKAGE_ZIP): report $(STAGE_STAMP) $(STAGED_CORE_JSON) $(STAGED_BITSTREAM) $(STAGED_BUILD_INFO)
	mkdir -p "dist"
	rm -f "$@"
	cd "$(PACKAGE_DIR)" && zip -r -X "../../$@" Assets Cores Platforms

clean:
	rm -rf build dist

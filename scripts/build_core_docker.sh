#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_repo_path() {
    local path="$1"

    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$ROOT" "$path" ;;
    esac
}

BUILD_ROOT="$(resolve_repo_path "${POCKETCPC_BUILD_ROOT:-build}")"
CORE_ID="${POCKETCPC_CORE_ID:-stilvoid.PocketCPC}"
FPGA_DIR="$(resolve_repo_path "${POCKETCPC_FPGA_DIR:-$BUILD_ROOT/quartus}")"
CORE_DIR="$(resolve_repo_path "${POCKETCPC_CORE_DIR:-$BUILD_ROOT/package/Cores/$CORE_ID}")"
OUTPUT_DIR="$FPGA_DIR/output_files"
STATE_DIR="$(resolve_repo_path "${POCKETCPC_STATE_DIR:-$BUILD_ROOT/quartus/build_monitor}")"
IMAGE="${QUARTUS_DOCKER_IMAGE:-raetro/quartus:18.1}"
CONTAINER_NAME="${QUARTUS_DOCKER_CONTAINER:-pocketcpc-quartus-build}"
HEARTBEAT_SECONDS="${BUILD_HEARTBEAT_SECONDS:-60}"
BUILD_LOG_LINES="${BUILD_LOG_LINES:-80}"
LOG_FILE="$STATE_DIR/build.log"
CID_FILE="$STATE_DIR/container.cid"
LAST_EXIT_FILE="$STATE_DIR/last_exit_code"
LAST_START_FILE="$STATE_DIR/last_start_utc.txt"
LAST_END_FILE="$STATE_DIR/last_end_utc.txt"
PACKAGED_BITSTREAM="$(resolve_repo_path "${POCKETCPC_PACKAGED_BITSTREAM:-$CORE_DIR/bitstream.rbf_r}")"
PACKAGED_BITSTREAM_TMP="$PACKAGED_BITSTREAM.tmp"
BUILD_INFO_FILE="$(resolve_repo_path "${POCKETCPC_BUILD_INFO_FILE:-$CORE_DIR/build-info.txt}")"
BUILD_INFO_TMP="$BUILD_INFO_FILE.tmp"
RAW_RBF="$OUTPUT_DIR/ap_core.rbf"
PREBUILD_GIT_STATE="unknown"

usage() {
    cat <<EOF
usage: $(basename "$0") [build|status|log|wait|stop|freshness|assert-fresh]
EOF
}

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

git_describe_version() {
    local describe

    describe="$(git -C "$ROOT" describe --tags --always --match 'v*' 2>/dev/null || \
        git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    printf '%s' "${describe#v}"
}

git_release_date() {
    git -C "$ROOT" log -1 --date=format:%Y-%m-%d --format=%cd HEAD 2>/dev/null || \
        date -u '+%Y-%m-%d'
}

stat_mtime() {
    local path="$1"

    if [ -e "$path" ]; then
        if stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %z' "$path" >/dev/null 2>&1; then
            stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %z' "$path"
        else
            stat -c '%y' "$path" | sed -E 's/\.[0-9]+ / /'
        fi
    else
        printf 'missing'
    fi
}

sha256_file() {
    local path="$1"

    if [ -f "$path" ]; then
        if command -v shasum >/dev/null 2>&1; then
            shasum -a 256 "$path" | awk '{print $1}'
        elif command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$path" | awk '{print $1}'
        else
            python3 -c 'import hashlib, pathlib, sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$path"
        fi
    else
        printf 'missing'
    fi
}

container_exists() {
    docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

container_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)" = "true" ]
}

container_status_line() {
    docker ps --filter "name=$CONTAINER_NAME" --format 'container={{.Names}} status={{.Status}} image={{.Image}}'
}

artifact_summary() {
    cat <<EOF
packaged_bitstream=$(stat_mtime "$PACKAGED_BITSTREAM")
raw_rbf=$(stat_mtime "$RAW_RBF")
fit_summary=$(stat_mtime "$OUTPUT_DIR/ap_core.fit.summary")
sta_summary=$(stat_mtime "$OUTPUT_DIR/ap_core.sta.summary")
asm_report=$(stat_mtime "$OUTPUT_DIR/ap_core.asm.rpt")
build_info=$(stat_mtime "$BUILD_INFO_FILE")
EOF
}

find_stale_sources() {
    if [ ! -f "$PACKAGED_BITSTREAM" ]; then
        return 0
    fi

    find "$FPGA_DIR" \
        \( -path "$FPGA_DIR/output_files" -o \
           -path "$FPGA_DIR/db" -o \
           -path "$FPGA_DIR/incremental_db" -o \
           -path "$FPGA_DIR/simulation" \) -prune -o \
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
        -newer "$PACKAGED_BITSTREAM" -print | sort
}

print_freshness() {
    local stale

    stale="$(find_stale_sources)"
    if [ -z "$stale" ]; then
        echo "freshness=fresh"
        return 0
    fi

    echo "freshness=stale"
    echo "$stale" | sed 's#^#stale_source=#'
    return 1
}

assert_fresh() {
    local stale

    if [ ! -f "$PACKAGED_BITSTREAM" ]; then
        echo "Packaged bitstream not found: $PACKAGED_BITSTREAM" >&2
        exit 1
    fi

    stale="$(find_stale_sources)"
    if [ -n "$stale" ]; then
        echo "Packaged bitstream is older than Quartus input files; run make build first." >&2
        echo "$stale" | sed 's#^#  #'
        exit 1
    fi
}

write_build_info() {
    local git_commit git_describe core_release_date

    git_commit="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    git_describe="$(git_describe_version)"
    core_release_date="$(git_release_date)"

    cat > "$BUILD_INFO_TMP" <<EOF
build_timestamp_utc=$(now_utc)
git_commit=$git_commit
git_describe=$git_describe
git_state=$PREBUILD_GIT_STATE
core_version=$git_describe
core_date_release=$core_release_date
quartus_image=$IMAGE
container_name=$CONTAINER_NAME
raw_rbf_sha256=$(sha256_file "$RAW_RBF")
packaged_rbf_r_sha256=$(sha256_file "$PACKAGED_BITSTREAM")
packaged_bitstream_mtime=$(stat_mtime "$PACKAGED_BITSTREAM")
EOF

    mv "$BUILD_INFO_TMP" "$BUILD_INFO_FILE"
}

heartbeat() {
    while true; do
        sleep "$HEARTBEAT_SECONDS"
        if ! container_running; then
            break
        fi

        {
            echo "[build] still running at $(now_utc)"
            artifact_summary
        } | tee -a "$LOG_FILE"
    done
}

run_build() {
    local build_status docker_status heartbeat_pid

    mkdir -p "$STATE_DIR" "$CORE_DIR"
    if git -C "$ROOT" diff --quiet --ignore-submodules HEAD -- 2>/dev/null; then
        PREBUILD_GIT_STATE="clean"
    else
        PREBUILD_GIT_STATE="dirty"
    fi

    if container_running; then
        echo "A Quartus build is already running in container '$CONTAINER_NAME'." >&2
        exit 1
    fi

    if container_exists; then
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi

    : > "$LOG_FILE"
    rm -f "$CID_FILE" "$LAST_EXIT_FILE" "$LAST_END_FILE" "$PACKAGED_BITSTREAM_TMP" "$BUILD_INFO_TMP"
    now_utc > "$LAST_START_FILE"

    {
        echo "[build] starting at $(cat "$LAST_START_FILE")"
        echo "[build] container=$CONTAINER_NAME image=$IMAGE"
        artifact_summary
    } | tee -a "$LOG_FILE"

    heartbeat &
    heartbeat_pid=$!

    set +e
    docker run --rm --name "$CONTAINER_NAME" --cidfile "$CID_FILE" --platform linux/amd64 \
        --user "$(id -u):$(id -g)" \
        -v "$FPGA_DIR:/work" \
        -w /work \
        "$IMAGE" \
        /opt/intelFPGA/quartus/bin/quartus_sh --flow compile ap_core 2>&1 | tee -a "$LOG_FILE"
    docker_status=${PIPESTATUS[0]}
    set -e

    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true

    rm -f "$CID_FILE"

    if [ "$docker_status" -ne 0 ]; then
        printf '%s\n' "$docker_status" > "$LAST_EXIT_FILE"
        now_utc > "$LAST_END_FILE"
        echo "[build] Quartus exited with status $docker_status at $(cat "$LAST_END_FILE")" | tee -a "$LOG_FILE"
        exit "$docker_status"
    fi

    if [ ! -f "$RAW_RBF" ]; then
        printf '%s\n' "1" > "$LAST_EXIT_FILE"
        now_utc > "$LAST_END_FILE"
        echo "[build] missing Quartus output: $RAW_RBF" | tee -a "$LOG_FILE" >&2
        exit 1
    fi

    set +e
    python3 "$ROOT/scripts/reverse_rbf_bits.py" "$RAW_RBF" "$PACKAGED_BITSTREAM_TMP"
    build_status=$?
    if [ "$build_status" -eq 0 ]; then
        mv "$PACKAGED_BITSTREAM_TMP" "$PACKAGED_BITSTREAM"
        build_status=$?
    fi
    if [ "$build_status" -eq 0 ]; then
        write_build_info
        build_status=$?
    fi
    set -e

    printf '%s\n' "$build_status" > "$LAST_EXIT_FILE"
    now_utc > "$LAST_END_FILE"

    if [ "$build_status" -ne 0 ]; then
        echo "[build] packaging failed with status $build_status at $(cat "$LAST_END_FILE")" | tee -a "$LOG_FILE" >&2
        exit "$build_status"
    fi

    {
        echo "[build] wrote $PACKAGED_BITSTREAM"
        echo "[build] wrote $BUILD_INFO_FILE"
        echo "[build] completed at $(cat "$LAST_END_FILE")"
        artifact_summary
    } | tee -a "$LOG_FILE"
}

show_status() {
    mkdir -p "$STATE_DIR"

    if container_running; then
        echo "build=running"
        container_status_line
    else
        echo "build=idle"
        if [ -f "$LAST_EXIT_FILE" ]; then
            echo "last_exit_code=$(cat "$LAST_EXIT_FILE")"
        fi
        if [ -f "$LAST_START_FILE" ]; then
            echo "last_start_utc=$(cat "$LAST_START_FILE")"
        fi
        if [ -f "$LAST_END_FILE" ]; then
            echo "last_end_utc=$(cat "$LAST_END_FILE")"
        fi
    fi

    artifact_summary
    print_freshness || true
}

show_log() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "No build log at $LOG_FILE" >&2
        exit 1
    fi

    tail -n "$BUILD_LOG_LINES" "$LOG_FILE"
}

wait_for_build() {
    local status

    if ! container_running; then
        echo "No running build container '$CONTAINER_NAME'." >&2
        if [ -f "$LAST_EXIT_FILE" ]; then
            echo "Last build exit code: $(cat "$LAST_EXIT_FILE")" >&2
        fi
        exit 1
    fi

    while container_running; do
        {
            echo "[wait] build still running at $(now_utc)"
            artifact_summary
        }
        sleep "$HEARTBEAT_SECONDS"
    done

    for _ in 1 2 3 4 5; do
        if [ -f "$LAST_EXIT_FILE" ]; then
            break
        fi
        sleep 1
    done

    status="$(cat "$LAST_EXIT_FILE" 2>/dev/null || echo 1)"
    echo "[wait] build finished with exit code $status"
    exit "$status"
}

stop_build() {
    if ! container_running; then
        echo "No running build container '$CONTAINER_NAME'." >&2
        exit 1
    fi

    docker stop "$CONTAINER_NAME"
}

cmd="${1:-build}"

case "$cmd" in
    build)
        run_build
        ;;
    status)
        show_status
        ;;
    log)
        show_log
        ;;
    wait)
        wait_for_build
        ;;
    stop)
        stop_build
        ;;
    freshness)
        print_freshness
        ;;
    assert-fresh)
        assert_fresh
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

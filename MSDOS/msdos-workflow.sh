#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE=""
STAGE="check"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--env path] [stage]

Stages:
  check      Validate host tools, DOS C drive, Borland C++ files, and project paths.
  build      Run the configured DOS build command inside DOSBox-X.
  run        Run the configured DOS command inside DOSBox-X interactively.
  package    Build, copy configured artifacts to dist/test/<package>, and zip them.
  all        Alias for package.

Project environment:
  By default, $SCRIPT_NAME loads ./msdos-project.env from the current directory.
  Use --env to load a different project environment file.

Required variables:
  PROJECT_DIR DOS_C_DRIVE DOS_SOURCE_ROOT BUILD_COMMAND RUN_COMMAND

Optional variables:
  DOSBOX_BIN DOSBOX_HELPER DOS_PROJECT_DIR PACKAGE_NAME PACKAGE_FILES PACKAGE_DIRS
  SIBLING_DEPS TRANSFER_DIR DOSBOX_MACHINE DOSBOX_SCALER DOSBOX_WINDOWRES
  DOSBOX_EXTRA_CONFIG BUILD_DOS_COMMANDS RUN_DOS_COMMANDS
EOF
}

fail() {
    echo "$SCRIPT_NAME: $*" >&2
    exit 1
}

quote_arg() {
    case "$1" in
        *[!A-Za-z0-9_./:=@%+,-]*|'')
            printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
            ;;
        *)
            printf "%s" "$1"
            ;;
    esac
}

show_cmd() {
    printf '+'
    for arg in "$@"; do
        printf ' %s' "$(quote_arg "$arg")"
    done
    printf '\n'
}

run() {
    show_cmd "$@"
    "$@"
}

load_config() {
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE="./msdos-project.env"
    fi

    [ -f "$CONFIG_FILE" ] || fail "project environment not found: $CONFIG_FILE"

    local config_dir config_base config_abs_dir
    config_dir="$(dirname "$CONFIG_FILE")"
    config_base="$(basename "$CONFIG_FILE")"
    config_abs_dir="$(CDPATH= cd -- "$config_dir" && pwd)"
    CONFIG_FILE="$config_abs_dir/$config_base"

    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
    echo "Loaded MS-DOS project environment: $CONFIG_FILE"
}

require_var() {
    local var_name var_value
    var_name="$1"
    eval "var_value=\${$var_name-}"
    [ -n "$var_value" ] || fail "required variable is not set: $var_name"
}

require_file() {
    [ -f "$1" ] || fail "required file not found: $1"
}

require_dir() {
    [ -d "$1" ] || fail "required directory not found: $1"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

resolve_dosbox_bin() {
    if [ -n "${DOSBOX_BIN-}" ]; then
        [ -x "$DOSBOX_BIN" ] || fail "DOSBox-X binary not found or not executable: $DOSBOX_BIN"
        return 0
    fi

    if command -v dosbox-x >/dev/null 2>&1; then
        DOSBOX_BIN="$(command -v dosbox-x)"
        export DOSBOX_BIN
        return 0
    fi

    fail "DOSBOX_BIN is not set and dosbox-x was not found on PATH"
}

set_defaults() {
    DOS_PROJECT_DIR="${DOS_PROJECT_DIR:-$(basename "$PROJECT_DIR")}"
    PACKAGE_NAME="${PACKAGE_NAME:-$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')}"
    DOSBOX_MACHINE="${DOSBOX_MACHINE:-svga_s3}"
    DOSBOX_SCALER="${DOSBOX_SCALER:-normal2x}"
    DOSBOX_WINDOWRES="${DOSBOX_WINDOWRES:-1280x960}"
}

require_common_config() {
    require_var PROJECT_DIR
    require_var DOS_C_DRIVE
    require_var DOS_SOURCE_ROOT
    require_var BUILD_COMMAND
    require_var RUN_COMMAND
    set_defaults
}

check_borland_c() {
    require_file "$DOS_C_DRIVE/BC/BIN/BCC.EXE"
    require_file "$DOS_C_DRIVE/BC/BIN/MAKE.EXE"
    require_file "$DOS_C_DRIVE/BC/BIN/TLINK.EXE"
    require_file "$DOS_C_DRIVE/BC/LIB/C0L.OBJ"
    require_file "$DOS_C_DRIVE/BC/LIB/CL.LIB"
    require_file "$DOS_C_DRIVE/BC/LIB/EMU.LIB"
    require_file "$DOS_C_DRIVE/BC/LIB/MATHL.LIB"
    require_file "$DOS_C_DRIVE/BC/INCLUDE/DOS.H"
}

check_sibling_deps() {
    [ -n "${SIBLING_DEPS-}" ] || return 0

    local dep
    for dep in $SIBLING_DEPS; do
        require_dir "$DOS_SOURCE_ROOT/$dep"
    done
}

stage_check() {
    require_common_config
    resolve_dosbox_bin
    require_dir "$PROJECT_DIR"
    require_dir "$DOS_C_DRIVE"
    require_dir "$DOS_SOURCE_ROOT"
    require_dir "$DOS_SOURCE_ROOT/$DOS_PROJECT_DIR"
    check_borland_c
    check_sibling_deps

    echo "MS-DOS workflow check passed."
    echo "Project: $PROJECT_DIR"
    echo "DOS C drive: $DOS_C_DRIVE"
    echo "DOS source root: $DOS_SOURCE_ROOT"
    echo "DOS project path: D:\\$DOS_PROJECT_DIR"
    echo "DOSBox-X: $DOSBOX_BIN"
}

write_dosbox_config() {
    local mode command extra_commands config_file
    mode="$1"
    command="$2"
    extra_commands="$3"
    config_file="$4"

    {
        cat <<EOF
[sdl]
fullscreen=false
fullresolution=Standard
windowresolution=$DOSBOX_WINDOWRES

[cpu]
cycles=auto

[dosbox]
machine=$DOSBOX_MACHINE

[render]
scaler=$DOSBOX_SCALER
EOF

        if [ -n "${DOSBOX_EXTRA_CONFIG-}" ]; then
            printf '\n%s\n' "$DOSBOX_EXTRA_CONFIG"
        fi

        cat <<EOF

[autoexec]
path=%PATH%;C:\\BC\\BIN
mount c "$DOS_C_DRIVE"
mount d "$DOS_SOURCE_ROOT"
D:
cd \\$DOS_PROJECT_DIR
EOF

        if [ -n "$extra_commands" ]; then
            printf '%s\n' "$extra_commands"
        fi

        printf '%s\n' "$command"

        if [ "$mode" = "build" ]; then
            printf 'exit\n'
        fi
    } > "$config_file"
}

run_dosbox_config() {
    local config_file mode
    config_file="$1"
    mode="$2"

    if [ -n "${DOSBOX_HELPER-}" ] && [ -f "$DOSBOX_HELPER" ]; then
        if [ "$mode" = "build" ]; then
            run python3 "$DOSBOX_HELPER" run --launch-mode binary --silent --fastlaunch --config "$config_file"
        else
            run python3 "$DOSBOX_HELPER" run --launch-mode binary --fastlaunch --config "$config_file"
        fi
        return 0
    fi

    if [ "$mode" = "build" ]; then
        run "$DOSBOX_BIN" -conf "$config_file" -silent -fastlaunch
    else
        run "$DOSBOX_BIN" -conf "$config_file" -fastlaunch
    fi
}

stage_build() {
    stage_check

    local config_file
    config_file="$(mktemp "${TMPDIR:-/tmp}/msdos-build.XXXXXX")"
    write_dosbox_config "build" "$BUILD_COMMAND" "${BUILD_DOS_COMMANDS-}" "$config_file"
    echo "Generated build config: $config_file"
    run_dosbox_config "$config_file" "build"
}

stage_run() {
    stage_check

    local config_file
    config_file="$(mktemp "${TMPDIR:-/tmp}/msdos-run.XXXXXX")"
    write_dosbox_config "run" "$RUN_COMMAND" "${RUN_DOS_COMMANDS-}" "$config_file"
    echo "Generated run config: $config_file"
    run_dosbox_config "$config_file" "run"
}

copy_package_files() {
    local package_dir item
    package_dir="$1"

    [ -n "${PACKAGE_FILES-}" ] || fail "PACKAGE_FILES is not set"

    for item in $PACKAGE_FILES; do
        [ -f "$PROJECT_DIR/$item" ] || fail "package file not found: $PROJECT_DIR/$item"
        run cp "$PROJECT_DIR/$item" "$package_dir/"
    done
}

copy_package_dirs() {
    local package_dir item base
    package_dir="$1"

    [ -n "${PACKAGE_DIRS-}" ] || return 0

    for item in $PACKAGE_DIRS; do
        [ -d "$PROJECT_DIR/$item" ] || fail "package directory not found: $PROJECT_DIR/$item"
        base="$(basename "$item")"
        run mkdir -p "$package_dir/$base"
        run cp -R "$PROJECT_DIR/$item"/. "$package_dir/$base/"
    done
}

stage_package() {
    require_command zip
    stage_build

    local branch_name commit_sha build_date dist_root package_dir zip_path
    branch_name="$(git -C "$PROJECT_DIR" symbolic-ref --short HEAD 2>/dev/null || echo main)"
    commit_sha="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo no-commit)"
    build_date="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    dist_root="$PROJECT_DIR/dist/test"
    package_dir="$dist_root/$PACKAGE_NAME"
    zip_path="$dist_root/$PACKAGE_NAME.zip"

    run rm -rf "$dist_root"
    run mkdir -p "$package_dir"
    copy_package_files "$package_dir"
    copy_package_dirs "$package_dir"

    printf 'Package: %s\r\nBranch: %s\r\nCommit: %s\r\nBuilt: %s\r\nPurpose: Hardware test package, not a formal release.\r\n' \
        "$PACKAGE_NAME" "$branch_name" "$commit_sha" "$build_date" > "$package_dir/BUILDINFO.TXT"

    run rm -f "$zip_path"
    (
        cd "$dist_root"
        show_cmd zip -qr "$PACKAGE_NAME.zip" "$PACKAGE_NAME"
        zip -qr "$PACKAGE_NAME.zip" "$PACKAGE_NAME"
    )

    echo "Created $package_dir"
    echo "Created $zip_path"

    if [ -n "${TRANSFER_DIR-}" ]; then
        if [ -d "$TRANSFER_DIR" ]; then
            run rm -rf "$TRANSFER_DIR/$PACKAGE_NAME"
            run mkdir -p "$TRANSFER_DIR/$PACKAGE_NAME"
            run cp -R "$package_dir"/. "$TRANSFER_DIR/$PACKAGE_NAME/"
            run cp "$zip_path" "$TRANSFER_DIR/$PACKAGE_NAME.zip"
            echo "Updated $TRANSFER_DIR/$PACKAGE_NAME"
            echo "Updated $TRANSFER_DIR/$PACKAGE_NAME.zip"
        else
            echo "Skipped transfer copy; TRANSFER_DIR does not exist: $TRANSFER_DIR"
        fi
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --env)
            [ "$#" -ge 2 ] || fail "--env requires a path"
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        check|build|run|package|all)
            STAGE="$1"
            shift
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

load_config

case "$STAGE" in
    check)
        stage_check
        ;;
    build)
        stage_build
        ;;
    run)
        stage_run
        ;;
    package|all)
        stage_package
        ;;
esac

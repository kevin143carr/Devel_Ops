#!/bin/sh
set -eu

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_FILE=
STAGE=all

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--env path] [stage]

Stages:
  all        Build, test with iix, import into the GS/OS image, then run emulator.
  build      Compile and link with ORCA/C through iix.
  test-iix   Run the local executable through iix interactively.
  run-iix    Build, then run the local executable through iix interactively.
  import     Import the executable and optional extra files into the GS/OS image with appcom.
  transfer   Copy the configured GS/OS image to IMAGE_TRANSFER_DIR.
  emulator   Launch emulator (Clemens or GSPlus), wait RUN_SECONDS, then quit.
  launch     Alias for emulator; launch emulator using the configured project settings.
  gsplus     Launch GSPlus emulator.
  run-gsos   Build, import into the GS/OS image, then run emulator.
  run-both   Build, run with iix, then import and run emulator.
  verify     Show local files and GS/OS image listing.

Project environment:
  By default, $SCRIPT_NAME loads ./appleiigs-project.env from the current
  directory. Use --env to load a different project environment file.

Required variables:
  PROJECT_DIR SOURCE OBJECT PROGRAM IMAGE DEST_NAME FILE_TYPE AUX_TYPE

Optional variables:
  EXTRA_IMPORTS IMAGE_TRANSFER_DIR

Required for emulator stage (Clemens):
  CLEMENS_APP CLEMENS_NAME CLEMENS_CONFIG RUN_SECONDS

Required for emulator stage (GSPlus):
  GSPLUS GSPLUS_CONFIG RUN_SECONDS
EOF
}

fail() {
    echo "$SCRIPT_NAME: $*" >&2
    exit 1
}

show_cmd() {
    printf '+'
    for arg in "$@"; do
        printf ' %s' "$(quote_arg "$arg")"
    done
    printf '\n'
}

quote_arg() {
    case "$1" in
        *[!A-Za-z0-9_./:=@%-]*|'')
            printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
            ;;
        *)
            printf "%s" "$1"
            ;;
    esac
}

run() {
    show_cmd "$@"
    "$@"
}

load_config() {
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE=./appleiigs-project.env
    fi

    [ -f "$CONFIG_FILE" ] || fail "project environment not found: $CONFIG_FILE"

    config_dir=$(dirname "$CONFIG_FILE")
    config_base=$(basename "$CONFIG_FILE")
    config_abs_dir=$(CDPATH= cd -- "$config_dir" && pwd)
    CONFIG_FILE="$config_abs_dir/$config_base"

    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
    echo "Loaded Apple IIgs project environment: $CONFIG_FILE"
}

require_var() {
    var_name=$1
    eval "var_value=\${$var_name-}"
    [ -n "$var_value" ] || fail "required variable is not set: $var_name"
}

require_common_config() {
    require_var PROJECT_DIR
    require_var SOURCE
    require_var OBJECT
    require_var PROGRAM
    require_var IMAGE
    require_var DEST_NAME
    require_var FILE_TYPE
    require_var AUX_TYPE
}

configure_golden_gate() {
    if [ -n "${GOLDEN_GATE-}" ]; then
        [ -d "$GOLDEN_GATE" ] || fail "Golden Gate root not found: $GOLDEN_GATE"
        export GOLDEN_GATE
        echo "Using Golden Gate root: $GOLDEN_GATE"
    fi
}

require_emulator_config() {
    if [ -n "${GSPLUS-}" ]; then
        require_var GSPLUS
        require_var GSPLUS_CONFIG
        require_var RUN_SECONDS
    elif [ -n "${CLEMENS_APP-}" ]; then
        require_var CLEMENS_APP
        require_var CLEMENS_NAME
        require_var CLEMENS_CONFIG
        require_var RUN_SECONDS
    else
        fail "Either GSPLUS or CLEMENS_APP must be set for emulator stages. Please set one of these in your project environment file ($CONFIG_FILE). For GSPlus: GSPLUS, GSPLUS_CONFIG, RUN_SECONDS. For Clemens: CLEMENS_APP, CLEMENS_NAME, CLEMENS_CONFIG, RUN_SECONDS."
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_project_dir() {
    [ -d "$PROJECT_DIR" ] || fail "project directory not found: $PROJECT_DIR"
    cd "$PROJECT_DIR"
}

require_base_tools() {
    require_command iix
    require_command appcom
}

require_emulator_tools() {
    [ -x /usr/bin/open ] || fail "required command not found or not executable: /usr/bin/open"
    [ -x /usr/bin/osascript ] || fail "required command not found or not executable: /usr/bin/osascript"
}

backup_image_if_needed() {
    image_dir=$(dirname "$IMAGE")
    image_base=$(basename "$IMAGE" .hdv)

    existing_backup=$(find "$image_dir" -maxdepth 1 -type f -name "${image_base}-before-*.hdv" -print -quit)
    if [ -n "$existing_backup" ]; then
        echo "Existing backup found: $existing_backup"
        return 0
    fi

    timestamp=$(date '+%Y%m%d-%H%M%S')
    backup="$image_dir/${image_base}-before-workflow-$timestamp.hdv"
    run cp "$IMAGE" "$backup"
    echo "Created backup: $backup"
}

is_clemens_running() {
    if [ -n "${GSPLUS-}" ]; then
        # For GSPlus, we can't easily check if it's running via AppleScript
        # so we'll assume it starts successfully
        return 0
    fi
    
    result=$(/usr/bin/osascript -e "application \"$CLEMENS_NAME\" is running" 2>/dev/null || echo "false")
    [ "$result" = "true" ]
}

wait_for_clemens_running() {
    if [ -n "${GSPLUS-}" ]; then
        # For GSPlus, we'll just wait a bit for it to start
        sleep 3
        return 0
    fi
    
    deadline=20
    elapsed=0

    while [ "$elapsed" -lt "$deadline" ]; do
        if is_clemens_running; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 1
}

wait_for_clemens_shutdown() {
    if [ -n "${GSPLUS-}" ]; then
        # For GSPlus, we'll just wait a bit for it to quit
        sleep 2
        return 0
    fi
    
    deadline=10
    elapsed=0

    while [ "$elapsed" -lt "$deadline" ]; do
        if ! is_clemens_running; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 1
}

stage_build() {
    require_project_dir
    require_base_tools
    [ -f "$SOURCE" ] || fail "source file not found: $PROJECT_DIR/$SOURCE"

    echo "Building ORCA/C program in $PROJECT_DIR"
    run iix compile "$SOURCE" keep="$OBJECT"
    run iix link "$OBJECT" keep="$PROGRAM"
    run ls -la "$SOURCE" "$PROGRAM" "$OBJECT.a" "$OBJECT.root"
}

stage_test_iix() {
    require_project_dir
    require_base_tools
    [ -f "$PROGRAM" ] || fail "executable not found: $PROJECT_DIR/$PROGRAM"

    echo "Running iix test interactively. Supply the key or Return requested by the program."
    run iix "./$PROGRAM"
}

import_file() {
    source_file=$1
    dest_name=$2
    file_type=$3
    aux_type=$4

    [ -f "$source_file" ] || fail "import source file not found: $PROJECT_DIR/$source_file"

    echo "Deleting existing $dest_name if present. A not-found message is acceptable."
    show_cmd appcom -d "$IMAGE" "$dest_name"
    appcom -d "$IMAGE" "$dest_name" || true

    echo "Importing $source_file as $dest_name with type $file_type and auxiliary type $aux_type."
    show_cmd appcom -p "$IMAGE" "$dest_name" "$file_type" "$aux_type" '<' "$source_file"
    appcom -p "$IMAGE" "$dest_name" "$file_type" "$aux_type" < "$source_file"
}

import_extra_files() {
    [ -n "${EXTRA_IMPORTS-}" ] || return 0

    printf '%s\n' "$EXTRA_IMPORTS" | while IFS= read -r import_entry; do
        remainder=
        source_file=
        dest_name=
        file_type=
        aux_type=

        case "$import_entry" in
            ''|'#'*)
                continue
                ;;
        esac

        source_file=${import_entry%%|*}
        remainder=${import_entry#*|}
        [ "$remainder" != "$import_entry" ] || fail "invalid EXTRA_IMPORTS entry: $import_entry"

        dest_name=${remainder%%|*}
        remainder=${remainder#*|}
        [ "$remainder" != "$dest_name" ] || fail "invalid EXTRA_IMPORTS entry: $import_entry"

        file_type=${remainder%%|*}
        aux_type=${remainder#*|}
        [ "$aux_type" != "$remainder" ] || fail "invalid EXTRA_IMPORTS entry: $import_entry"

        case "$aux_type" in
            *'|'*)
                fail "invalid EXTRA_IMPORTS entry: $import_entry"
                ;;
        esac

        [ -n "$source_file" ] || fail "EXTRA_IMPORTS source is empty: $import_entry"
        [ -n "$dest_name" ] || fail "EXTRA_IMPORTS destination is empty: $import_entry"
        [ -n "$file_type" ] || fail "EXTRA_IMPORTS file type is empty: $import_entry"
        [ -n "$aux_type" ] || fail "EXTRA_IMPORTS auxiliary type is empty: $import_entry"

        import_file "$source_file" "$dest_name" "$file_type" "$aux_type"
    done
}

stage_import() {
    require_project_dir
    require_base_tools
    [ -f "$IMAGE" ] || fail "disk image not found: $IMAGE"
    [ -f "$PROGRAM" ] || fail "executable not found: $PROJECT_DIR/$PROGRAM"

    backup_image_if_needed

    run appcom -i "$IMAGE"
    run appcom -ll "$IMAGE"

    import_file "$PROGRAM" "$DEST_NAME" "$FILE_TYPE" "$AUX_TYPE"
    import_extra_files

    listing=$(appcom -ll "$IMAGE")
    printf '%s\n' "$listing"
    printf '%s\n' "$listing" | /usr/bin/grep -E "^[[:space:]]+$DEST_NAME[[:space:]].*[[:space:]]$FILE_TYPE[[:space:]].*[$]0000" >/dev/null \
        || fail "AppleCommander did not list $DEST_NAME as $FILE_TYPE with auxiliary type \$0000"
}

stage_emulator() {
    require_emulator_tools
    
    if [ -n "${GSPLUS-}" ]; then
        [ -f "$GSPLUS" ] || fail "GSPlus app not found: $GSPLUS"
        [ -f "$GSPLUS_CONFIG" ] || fail "GSPlus config not found: $GSPLUS_CONFIG"
        
        echo "Starting GSPlus with config: $GSPLUS_CONFIG"
        run /usr/bin/open -n "$GSPLUS" --args -cfg "$GSPLUS_CONFIG"
    elif [ -n "${CLEMENS_APP-}" ]; then
        [ -f "$IMAGE" ] || fail "disk image not found: $IMAGE"
        [ -d "$CLEMENS_APP" ] || fail "Clemens app bundle not found: $CLEMENS_APP"

        if [ -f "$CLEMENS_CONFIG" ]; then
            run grep -F "gs.smart.1=$IMAGE" "$CLEMENS_CONFIG"
        else
            fail "Clemens config not found: $CLEMENS_CONFIG"
        fi

        if is_clemens_running; then
            echo "$CLEMENS_NAME is already running; quitting it before launch."
            run /usr/bin/osascript -e "tell application \"$CLEMENS_NAME\" to quit"
            wait_for_clemens_shutdown || fail "$CLEMENS_NAME did not quit before launch"
        fi

        run /usr/bin/open "$CLEMENS_APP"
        wait_for_clemens_running || fail "$CLEMENS_NAME did not report as running after launch"

        case "$RUN_SECONDS" in
            -*)
                echo "Clemens is running. RUN_SECONDS=$RUN_SECONDS; leaving emulator running."
                return 0
                ;;
        esac

        echo "Clemens is running. Waiting $RUN_SECONDS seconds before timed shutdown."
        sleep "$RUN_SECONDS"

        run /usr/bin/osascript -e "tell application \"$CLEMENS_NAME\" to quit"
        wait_for_clemens_shutdown || fail "$CLEMENS_NAME did not quit cleanly"
        echo "Clemens timed run completed."
    else
        fail "Neither GSPLUS nor CLEMENS_APP is configured. Please set one of these in your project environment file."
    fi
}

stage_run_iix() {
    stage_build
    stage_test_iix
}

stage_run_gsos() {
    stage_build
    stage_import
    stage_emulator
}

stage_run_both() {
    stage_build
    stage_test_iix
    stage_import
    stage_emulator
}

stage_verify() {
    require_project_dir
    require_base_tools
    run pwd
    run ls -la
    [ -f "$IMAGE" ] || fail "disk image not found: $IMAGE"
    run appcom -i "$IMAGE"
    run appcom -ll "$IMAGE"
}

stage_transfer() {
    require_project_dir
    require_var IMAGE_TRANSFER_DIR
    [ -f "$IMAGE" ] || fail "disk image not found: $IMAGE"
    [ -d "$IMAGE_TRANSFER_DIR" ] || fail "image transfer directory not found: $IMAGE_TRANSFER_DIR"

    image_base=$(basename "$IMAGE")
    transfer_dest="$IMAGE_TRANSFER_DIR/$image_base"
    run cp "$IMAGE" "$transfer_dest"
    echo "Transferred disk image: $transfer_dest"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --env)
            shift
            [ "$#" -gt 0 ] || fail "--env requires a path"
            CONFIG_FILE=$1
            shift
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        all|build|test-iix|run-iix|import|transfer|emulator|launch|run-gsos|run-both|verify)
            STAGE=$1
            shift
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

load_config
require_common_config
configure_golden_gate

case "$STAGE" in
    all)
        require_emulator_config
        stage_build
        stage_test_iix
        stage_import
        stage_emulator
        ;;
    build)
        stage_build
        ;;
    test-iix)
        stage_test_iix
        ;;
    run-iix)
        stage_run_iix
        ;;
    import)
        stage_import
        ;;
    transfer)
        stage_transfer
        ;;
    launch)
        require_emulator_config
        stage_emulator
        ;;
    emulator)
        require_emulator_config
        stage_emulator
        ;;
    gsplus)
        require_emulator_config
        stage_emulator
        ;;
    run-gsos)
        require_emulator_config
        stage_run_gsos
        ;;
    run-both)
        require_emulator_config
        stage_run_both
        ;;
    verify)
        stage_verify
        ;;
    *)
        usage >&2
        fail "unknown stage: $STAGE"
        ;;
esac

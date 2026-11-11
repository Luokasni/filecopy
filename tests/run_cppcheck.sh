
#!/bin/bash

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

SUPPRESSIONS="tests/cppcheck_suppressions.txt"
MISRA_CONFIG="tests/misra.json"

CPP_FILES=(
    src/main.c
    src/copy.c
    src/parallel.c
    src/dir.c
    src/queue.c
    src/utils.c
    src/log.c
    tests/test_mycp.c
)

CPP_TEST_FILES=(
    tests/gtest_mycp.cpp
)

check_cppcheck() {
    if ! command -v cppcheck >/dev/null 2>&1; then
        echo "ERROR: Cppcheck is not installed."
        return 1
    fi

    local common_options=(
        --enable=warning,style,performance,portability
        --inline-suppr
        --error-exitcode=1
        -I include
    )

    local suppression_options=()

    if [[ -f "$SUPPRESSIONS" ]]; then
        suppression_options+=("--suppressions-list=$SUPPRESSIONS")
    fi

    echo "========== C11 Cppcheck =========="

    cppcheck \
        "${common_options[@]}" \
        "${suppression_options[@]}" \
        --language=c \
        --std=c11 \
        "${CPP_FILES[@]}" || return 1

    echo "========== C++14 Cppcheck =========="

    cppcheck \
        "${common_options[@]}" \
        "${suppression_options[@]}" \
        --language=c++ \
        --std=c++14 \
        "${CPP_TEST_FILES[@]}" || return 1

    echo "Cppcheck completed successfully."
}

check_misra() {
    if ! command -v cppcheck >/dev/null 2>&1; then
        echo "ERROR: Cppcheck is not installed."
        return 1
    fi

    if [[ ! -f "$MISRA_CONFIG" ]]; then
        echo "ERROR: MISRA configuration not found: $MISRA_CONFIG"
        return 1
    fi

    echo "========== MISRA C Analysis =========="

    cppcheck \
        --enable=warning,style,performance,portability \
        --inline-suppr \
        --error-exitcode=1 \
        --language=c \
        --std=c11 \
        -I include \
        --addon="$MISRA_CONFIG" \
        "${CPP_FILES[@]}" || return 1

    echo "MISRA analysis completed successfully."
}

case "${1:-all}" in
    cppcheck)
        check_cppcheck
        ;;
    misra)
        check_misra
        ;;
    all)
        check_cppcheck && check_misra
        ;;
    *)
        echo "Usage: $0 {cppcheck|misra|all}"
        exit 2
        ;;
esac

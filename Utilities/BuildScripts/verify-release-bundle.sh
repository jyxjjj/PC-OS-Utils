#!/bin/bash

set -euo pipefail

if [[ "${CONFIGURATION:-}" != "Release" ]]; then
    exit 0
fi

app_bundle="${1:?Missing application bundle path}"

if [[ ! -d "$app_bundle" ]]; then
    echo "error: Release bundle audit could not find the application bundle." >&2
    exit 1
fi

pattern_labels=(
    "a macOS user-home path"
    "a DerivedData path"
    "a SourcePackages path"
    "an Xcode intermediate build path"
    "an Xcode product build path"
)
patterns=(
    "/Users/"
    "DerivedData/"
    "SourcePackages/"
    "/Build/Intermediates.noindex/"
    "/Build/Products/"
)

for variable_name in \
    SRCROOT PROJECT_DIR \
    BUILD_DIR BUILD_ROOT BUILT_PRODUCTS_DIR CONFIGURATION_BUILD_DIR \
    OBJROOT SYMROOT PROJECT_TEMP_DIR TARGET_TEMP_DIR TEMP_DIR \
    DERIVED_FILE_DIR SOURCE_PACKAGES_DIR_PATH
do
    variable_value="${!variable_name:-}"
    if [[ -n "$variable_value" && "$variable_value" != "/" ]]; then
        pattern_labels+=("the ${variable_name} build path")
        patterns+=("$variable_value")
    fi
done

if [[ -n "${HOME:-}" && "$HOME" != "/" ]]; then
    pattern_labels+=("the build account home path")
    patterns+=("$HOME")
fi

leak_count=0

debug_artifact="$(/usr/bin/find "$app_bundle" \( -name "*.dSYM" -o -name "*.bcsymbolmap" \) -print -quit)"
if [[ -n "$debug_artifact" ]]; then
    relative_path="${debug_artifact#"$app_bundle"/}"
    echo "error: Release bundle audit found a packaged debug artifact in '${relative_path}'." >&2
    leak_count=$((leak_count + 1))
fi

while IFS= read -r -d '' link_path; do
    relative_path="${link_path#"$app_bundle"/}"
    link_target="$(/usr/bin/readlink "$link_path")"

    if [[ "$link_target" == /* ]]; then
        echo "error: Release bundle audit found an absolute symbolic link target in '${relative_path}'." >&2
        leak_count=$((leak_count + 1))
        continue
    fi

    for index in "${!patterns[@]}"; do
        if [[ "$link_target" == *"${patterns[$index]}"* ]]; then
            echo "error: Release bundle audit found ${pattern_labels[$index]} in the symbolic link target for '${relative_path}'." >&2
            leak_count=$((leak_count + 1))
        fi
    done
done < <(/usr/bin/find "$app_bundle" -type l -print0)

while IFS= read -r -d '' file_path; do
    relative_path="${file_path#"$app_bundle"/}"

    for index in "${!patterns[@]}"; do
        if LC_ALL=C /usr/bin/grep -a -F -- "${patterns[$index]}" "$file_path" >/dev/null 2>&1; then
            echo "error: Release bundle audit found ${pattern_labels[$index]} in '${relative_path}'." >&2
            leak_count=$((leak_count + 1))
        fi
    done

    file_description="$(/usr/bin/file -b "$file_path")"
    if [[ "$file_description" != *"Mach-O"* ]]; then
        continue
    fi

    if /usr/bin/otool -l "$file_path" 2>/dev/null | /usr/bin/awk '
        $1 == "segname" && $2 == "__DWARF" { found = 1 }
        END { exit !found }
    '; then
        echo "error: Release bundle audit found a __DWARF segment in '${relative_path}'." >&2
        leak_count=$((leak_count + 1))
    fi

    if /usr/bin/nm -a "$file_path" 2>/dev/null | /usr/bin/awk '
        $2 == "-" && !($5 == "OPT" && $6 ~ /^radr:\/\/[[:alnum:]]+$/) { found = 1 }
        END { exit !found }
    '; then
        echo "error: Release bundle audit found debugger symbol table entries in '${relative_path}'." >&2
        leak_count=$((leak_count + 1))
    fi
done < <(/usr/bin/find "$app_bundle" -type f -print0)

if (( leak_count > 0 )); then
    echo "error: Release bundle audit failed with ${leak_count} finding(s)." >&2
    exit 1
fi

echo "Release bundle audit passed: no private build paths, absolute symbolic link targets, or packaged debug data were found."

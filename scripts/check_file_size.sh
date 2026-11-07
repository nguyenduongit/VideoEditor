#!/usr/bin/env bash
set -euo pipefail

echo "==> Running AAS File Size Threshold Check..."

MAX_LINES=300
WARN_LINES=200
VIOLATIONS=0

find Sources/ -name "*.swift" 2>/dev/null | while read -r file; do
    LINES=$(wc -l < "$file" | tr -d ' ')
    if [ "$LINES" -gt "$MAX_LINES" ]; then
        echo "REVIEW: $file has $LINES lines (exceeds $MAX_LINES limit)."
        VIOLATIONS=$((VIOLATIONS + 1))
    elif [ "$LINES" -gt "$WARN_LINES" ]; then
        echo "WARN: $file has $LINES lines (approaching limit)."
    fi
done

echo "Check complete."
exit 0

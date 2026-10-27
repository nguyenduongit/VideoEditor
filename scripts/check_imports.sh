#!/usr/bin/env bash
# Kiểm tra ranh giới import theo AGENTS.md R2.1 / R2.3. Exit 1 nếu có vi phạm.
set -u
cd "$(dirname "$0")/.."
FAIL=0
ALLOWED_FILE="Config/domain-allowed-imports.txt"

report() { echo "❌ $1"; FAIL=1; }

# Domain: chỉ được import framework trong danh sách cho phép
ALLOWED=$(grep -vE '^\s*(#|$)' "$ALLOWED_FILE" | awk '{print $1}' | paste -sd'|' -)
while IFS= read -r line; do
  report "Domain import ngoài danh sách cho phép: $line"
done < <(grep -rnE '^(@[a-zA-Z_]+ )?import ' Sources/Domain | grep -vE "import ($ALLOWED)\s*$")

# DesignSystem: không import module nội bộ
while IFS= read -r line; do
  report "DesignSystem import module nội bộ: $line"
done < <(grep -rnE '^import (Domain|Infrastructure|FeatureShell)\b' Sources/DesignSystem)

# FeatureShell: không import Infrastructure / Supabase
while IFS= read -r line; do
  report "FeatureShell import Infrastructure/Supabase: $line"
done < <(grep -rnE '^import (Infrastructure|Supabase|PostgREST)\b' Sources/FeatureShell)

# Infrastructure: không import Feature / DesignSystem / SwiftUI
while IFS= read -r line; do
  report "Infrastructure import tầng trên/UI: $line"
done < <(grep -rnE '^import (FeatureShell|DesignSystem|SwiftUI)\b' Sources/Infrastructure)

if [ $FAIL -eq 0 ]; then echo "✅ check_imports: không có vi phạm ranh giới"; fi
exit $FAIL

#!/usr/bin/env bash
set -euo pipefail

echo "==> Running AAS Architecture Import Validator..."

ERRORS=0

# 1. Domain must not import UI, Supabase, or Infrastructure frameworks
if grep -rnE "^import (SwiftUI|AppKit|CoreData|SwiftData|GRDB|Infrastructure|DesignSystem|FeatureShell|Supabase)" Sources/Domain/ 2>/dev/null; then
    echo "ERROR: Domain module contains forbidden imports (UI, FeatureShell, Infrastructure, or ORM/Cloud SDK)."
    ERRORS=$((ERRORS + 1))
fi

# 2. FeatureShell must not import Infrastructure or Supabase directly
if grep -rnE "^import (Infrastructure|Supabase)" Sources/FeatureShell/ 2>/dev/null; then
    echo "ERROR: FeatureShell must not import Infrastructure or Supabase directly. Depend on Domain protocols."
    ERRORS=$((ERRORS + 1))
fi

# 3. DesignSystem must not import Domain, FeatureShell, Infrastructure, or Supabase
if grep -rnE "^import (Domain|FeatureShell|Infrastructure|Supabase)" Sources/DesignSystem/ 2>/dev/null; then
    echo "ERROR: DesignSystem (C0/C1) must not import Domain, FeatureShell, or Infrastructure."
    ERRORS=$((ERRORS + 1))
fi

# 4. Infrastructure must not import UI / FeatureShell / DesignSystem
if grep -rnE "^import (SwiftUI|FeatureShell|DesignSystem)" Sources/Infrastructure/ 2>/dev/null; then
    echo "ERROR: Infrastructure must not import SwiftUI, FeatureShell, or DesignSystem."
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS architectural boundary violations found."
    exit 1
else
    echo "PASSED: All architectural import boundaries verified across Domain, DesignSystem, FeatureShell, and Infrastructure."
    exit 0
fi

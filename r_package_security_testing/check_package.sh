#!/bin/bash
# check_package.sh - Run all security checks for an R package
# Combines: Scorecard + Local R checks + Credential scan

PACKAGE=$1
REPO_URL=$2

if [ -z "$PACKAGE" ]; then
cat << 'EOF'
Usage: ./check_package.sh <package_name> [github_repo_url]

Examples:
./check_package.sh aws.s3 https://github.com/cloudyr/aws.s3
./check_package.sh usethis https://github.com/r-lib/usethis
./check_package.sh ggplot2 # Will try to find repo automatically

This script runs:
1. OSSF Scorecard (if repo URL provided)
2. Local R checks (CRAN, dependencies, hooks, licenses)
3. Credential scan (bulk_extractor)

EOF
exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " COMPLETE SECURITY CHECK: $PACKAGE"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Create results directory
mkdir -p local_results

# Try to find repo URL if not provided
if [ -z "$REPO_URL" ]; then
echo "⚙️ Searching for GitHub repository..."
REPO_URL=$(curl -s "https://cran.r-project.org/web/packages/$PACKAGE/index.html" | \
grep -o 'https://github.com/[^"]*' | head -1)
if [ -n "$REPO_URL" ]; then
echo "✓ Found: $REPO_URL"
else
echo "⚠️ Could not find GitHub repository (Scorecard will be skipped)"
fi
echo ""
fi

# ════════════════════════════════════════════════════════════════════
# CHECK 1: OSSF Scorecard
# ════════════════════════════════════════════════════════════════════

if [ -n "$REPO_URL" ] && command -v scorecard &> /dev/null; then
echo "[1/3] Running OSSF Scorecard..."
echo "────────────────────────────────────────────────────────────────────"
SCORECARD_OUT="local_results/${PACKAGE}_scorecard.json"
if scorecard --repo="$REPO_URL" --format=json > "$SCORECARD_OUT" 2>&1; then
# Extract and display score
SCORE=$(jq -r '.score // "N/A"' "$SCORECARD_OUT" 2>/dev/null)
echo ""
echo " Scorecard Score: $SCORE/10"
# Show key checks
if [ "$SCORE" != "N/A" ]; then
echo ""
echo " Key Checks:"
jq -r '.checks[] | select(.name == "Code-Review" or .name == "Maintained" or .name == "Token-Permissions") | " \(.name): \(.score)/10"' "$SCORECARD_OUT" 2>/dev/null
fi
# Determine status
if (( $(echo "$SCORE >= 7.0" | bc -l 2>/dev/null || echo 0) )); then
echo ""
echo " ✅ PASS (score ≥ 7.0)"
elif [ "$SCORE" != "N/A" ]; then
echo ""
echo " ⚠️ REVIEW (score < 7.0)"
fi
else
echo " ⚠️ Scorecard check failed (see $SCORECARD_OUT for details)"
fi
echo ""
elif [ -n "$REPO_URL" ]; then
echo "[1/3] Scorecard not installed (skipping)"
echo "────────────────────────────────────────────────────────────────────"
echo " Install: go install github.com/ossf/scorecard/v5/cmd/scorecard@latest"
echo ""
else
echo "[1/3] Skipping Scorecard (no GitHub repository)"
echo "────────────────────────────────────────────────────────────────────"
echo ""
fi

# ════════════════════════════════════════════════════════════════════
# CHECK 2: Local R Package Checks
# ════════════════════════════════════════════════════════════════════

echo "[2/3] Running Local R Package Checks..."
echo "────────────────────────────────────────────────────────────────────"

if [ -f "local_package_check.R" ]; then
Rscript local_package_check.R "$PACKAGE" 2>&1 | grep -v "^$"
else
echo " ❌ local_package_check.R not found"
echo " Make sure you're running this from the correct directory"
fi

echo ""

# ════════════════════════════════════════════════════════════════════
# CHECK 3: Credential Scan
# ════════════════════════════════════════════════════════════════════

echo "[3/3] Running Credential Scan..."
echo "────────────────────────────────────────────────────────────────────"

if [ -f "scan_credentials.sh" ]; then
bash scan_credentials.sh "$PACKAGE" 2>&1 | grep -v "^$"
else
echo " ❌ scan_credentials.sh not found"
fi

echo ""

# ════════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════════

echo "════════════════════════════════════════════════════════════════════"
echo " RESULTS SUMMARY: $PACKAGE"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Gather all results
SCORECARD_SCORE=$(jq -r '.score // "N/A"' "local_results/${PACKAGE}_scorecard.json" 2>/dev/null)
LOCAL_REC=$(jq -r '.recommendation // "N/A"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
CRED_COUNT=$(wc -l < "local_results/${PACKAGE}_credentials.txt" 2>/dev/null || echo "0")

echo "Results:"
echo " 📊 Scorecard: $SCORECARD_SCORE/10"
echo " 📦 Local Checks: $LOCAL_REC"
echo " 🔑 Credentials: $CRED_COUNT findings"
echo ""

echo "Files created:"
ls -1h local_results/${PACKAGE}* 2>/dev/null | sed 's/^/ /'
echo ""

# Overall recommendation
echo "Next Steps:"
echo " 1. Review: local_results/${PACKAGE}_scorecard.json"
echo " 2. Review: local_results/${PACKAGE}_local_check.json"
echo " 3. Review: local_results/${PACKAGE}_credentials.txt"
echo " 4. Make decision using DECISION_TEMPLATE.md"
echo ""

# Quick decision logic
APPROVE=true

if [ "$SCORECARD_SCORE" != "N/A" ]; then
if (( $(echo "$SCORECARD_SCORE < 7.0" | bc -l 2>/dev/null || echo 0) )); then
APPROVE=false
echo "⚠️ CONCERN: Scorecard score below 7.0"
fi
fi

if [ "$LOCAL_REC" = "REVIEW REQUIRED" ] || [ "$LOCAL_REC" = "MANUAL REVIEW" ]; then
APPROVE=false
echo "⚠️ CONCERN: Local checks require review"
fi

if [ "$CRED_COUNT" -gt 10 ]; then
APPROVE=false
echo "⚠️ CONCERN: Many credential findings (review for false positives)"
fi

echo ""

if [ "$APPROVE" = true ]; then
echo "✅ PRELIMINARY: Looks good (pending manual review)"
else
echo "⚠️ PRELIMINARY: Manual review required"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
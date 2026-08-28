#!/bin/bash
# scan_credentials.sh
# Quick credential scan using bulk_extractor (you already have this installed)

PACKAGE=$1

if [ -z "$PACKAGE" ]; then
echo "Usage: ./scan_credentials.sh <package_name>" 
echo "Example: ./scan_credentials.sh aws.s3"
exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " CREDENTIAL SCAN: $PACKAGE"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Create temp directory
mkdir -p temp local_results

# Download package
echo "[1/4] Downloading package..."
R --quiet --no-save << EOF
download.packages("$PACKAGE", destdir="temp", type="source", repos="https://cran.r-project.org")
EOF

# Find the package file
PKG_FILE=$(ls -t temp/${PACKAGE}_*.tar.gz 2>/dev/null | head -1)

if [ -z "$PKG_FILE" ]; then
echo "❌ Error: Package not found"
exit 1
fi

echo "✓ Downloaded: $PKG_FILE"
echo ""

# Extract
echo "[2/4] Extracting package..."
tar -xzf "$PKG_FILE" -C temp
EXTRACT_DIR=$(find temp -maxdepth 1 -type d -name "${PACKAGE}*" | head -1)
echo "✓ Extracted to: $EXTRACT_DIR"
echo ""

# Run bulk_extractor if available
if command -v bulk_extractor &> /dev/null; then
echo "[3/4] Running bulk_extractor..."
BULK_OUT="local_results/${PACKAGE}_bulk"
rm -rf "$BULK_OUT"
bulk_extractor -o "$BULK_OUT" -S ssn_mode=0 "$EXTRACT_DIR" 2>&1 | grep -v "^#" || true
echo ""
else
echo "[3/4] bulk_extractor not found, using grep patterns..."
BULK_OUT="local_results/${PACKAGE}_grep"
mkdir -p "$BULK_OUT"
fi

# Manual pattern search
echo "[4/4] Searching for credential patterns..."
OUTPUT="local_results/${PACKAGE}_credentials.txt"
> "$OUTPUT"

# Search patterns
echo "Searching for potential secrets..."

# AWS Keys
if grep -r -i -n "AKIA[0-9A-Z]\{16\}" "$EXTRACT_DIR" 2>/dev/null | grep -v "Binary"; then
echo "⚠️ Found AWS key patterns" | tee -a "$OUTPUT"
fi

# API Keys 
if grep -r -i -n "api[_-]key.*=.*['\"][^'\"]\{20,\}" "$EXTRACT_DIR" 2>/dev/null | head -5 | grep -v "Binary"; then
echo "⚠️ Found API key patterns" | tee -a "$OUTPUT"
fi

# Passwords
if grep -r -i -n "password.*=.*['\"][^'\"]\{4,\}" "$EXTRACT_DIR" 2>/dev/null | head -5 | grep -v "Binary"; then
echo "⚠️ Found password patterns" | tee -a "$OUTPUT"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " SCAN COMPLETE"
echo "═══════════════════════════════════════════════════════════"

if [ -s "$OUTPUT" ]; then
LINES=$(wc -l < "$OUTPUT")
echo "⚠️ Found $LINES potential issues"
echo " Review: $OUTPUT"
echo ""
echo "IMPORTANT for packages like aws.s3:"
echo " Variable names like 'AWS_ACCESS_KEY_ID' are EXPECTED"
echo " Only worry about ACTUAL hardcoded values"
else
echo "✅ No obvious credentials found"
fi

echo ""
echo "Results:"
if command -v bulk_extractor &> /dev/null; then
echo " - bulk_extractor: $BULK_OUT/"
fi
echo " - Pattern scan: $OUTPUT"
echo ""
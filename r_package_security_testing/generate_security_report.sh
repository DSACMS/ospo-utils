#!/bin/bash
# generate_security_report.sh
# Generates a markdown report summarizing security checks for an R package
# Combines results from check_package.sh and local_package_check.R
# Automarically extracts data from the JSON outputs

PACKAGE=$1
REPO_URL=$2
REVIEWER_NAME=${3:-"[REVIEWER_NAME]"}

if [ -z "$PACKAGE" ]; then
    cat << 'EOF'
Usage: ./generate_security_report.sh <package_name> [github_repo_url] [reviewer_name]

Examples:
  ./generate_security_report.sh aws.s3 https://github.com/cloudyr/aws.s3
  ./generate_security_report.sh usethis https://github.com/r-lib/usethis "John Doe"

This script:
  1. Runs all security checks (Scorecard, local R checks, credential scan)
  2. Extracts the results from the JSON outputs automatically 
  2. Generates a markdown report summarizing the findings
  3. Saves the report as security_reports/<package_name>_security_report.md

You can then:
    - Copy/paste the markdown into GitHub issues
    - Edit the [TODO] sections manually
    - Add your own comments and recommendations
    - Add screenshots where indicated
EOF
    exit 1
fi

# Create output directory
mkdir -p security_reports
mkdir -p local_results

REPORT_FILE="security_reports/${PACKAGE}_security_report.md"
REVIEW_DATE=$(date +"%Y-%m-%d")

echo "=════════════════════════════════════════════════════════════════════"
echo " GENERATING SECURITY REPORT: $PACKAGE"
echo "════════════════════════════════════════════════════════════════════="
echo ""

# =════════════════════════════════════════════════════════════════════
# RUN ALL CHECKS
# =════════════════════════════════════════════════════════════════════

echo "[1/4] Running all local checks..."
if [ -f "local_package_check.R" ]; then
    Rscript local_package_check.R "$PACKAGE" > /dev/null 2>&1
    echo "✓ Local checks complete"
else
    echo "⚠️ local_package_check.R not found, skipping local checks"
fi

echo "[2/4] Running credential scan..."
if [ -f "scan_credentials.sh" ]; then
    bash scan_credentials.sh "$PACKAGE" > /dev/null 2>&1
    echo "✓ Credential scan complete"
else
    echo "⚠️ scan_credentials.sh not found, skipping credential scan"
fi

echo "[3/4] Running complete package check (Scorecard + all checks)..."
if [ -n "$REPO_URL" ] && command -v scorecard &> /dev/null; then
    bash check_package.sh "$PACKAGE" "$REPO_URL" > /dev/null 2>&1
    scorecard --repo="$REPO_URL" --format=json > "local_results/${PACKAGE}_scorecard.json" 2>&1
    echo "✓ Complete package check complete"
else
    echo "⚠️ check_package.sh or scorecard not found, skipping complete package check"
fi

echo "[4/4] Extracting results..."
echo ""

# =════════════════════════════════════════════════════════════════════
# EXTRACT RESULTS
# =════════════════════════════════════════════════════════════════════

# Initialize variables with default values
CRAN_STATUS="[TODO: Yes/No] (check CRAN page)"
CRAN_VERSION="[TODO: Latest version on CRAN]"
CRAN_STATUS_ICON="[TODO: Add icon based on status]"
CRAN_STATUS_TEXT="[TODO: ✅ PASS / ❌ FAIL]"

TOTAL_DEPS="[TODO: Total number of dependencies]"
DIRECT_DEPS="[TODO: Number of direct dependencies]"
DEP_STATUS="[TODO: ✅ PASS / ⚠️ ACCEPTABLE / ❌ FAIL]"

HOOKS_FOUND="[TODO: Yes/No]"
HOOKS_STATUS="[TODO: ✅ PASS / ❌ FAIL]"
HOOKS_RED_FLAG="No"

LICENSE="[TODO: License name]"
LICENSE_TYPE="[TODO: License type]"
LICENSE_STATUS="[TODO: ✅ GREAT / ⚠️ ACCEPTABLE / ❌ NOT ACCEPTABLE]"

CRED_FINDINGS_COUNT=0
CRED_FINDINGS_TEXT="[TODO: Yes/No]"
CRED_STATUS="[TODO: ✅ PASS / ❌ FAIL]"

SCORECARD_SCORE="[TODO: Fill in from GitHub Actions results]"
OVERALL_RECOMMENDATION="[TODO: ✅ APPROVE / ❌ DISAPPROVE / ⚠️ FLAG FOR SECOND REVIEW]"

# =════════════════════════════════════════════════════════════════════
# EXTRACT RESULTS FROM JSON FILES
# =════════════════════════════════════════════════════════════════════

if [ -f "local_results/${PACKAGE}_local_check.json" ]; then
    echo "Extracting local check results from local_check.json..."

    # Get Cran Info
    CRAN_ON_CRAN=$(jq -r '.local_checks.cran.on_cran // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
    if [ "$CRAN_ON_CRAN" == "true" ]; then
        CRAN_STATUS="Yes"
        CRAN_STATUS_ICON="✅"
    elif [ "$CRAN_ON_CRAN" == "false" ]; then
        CRAN_STATUS="No"
        CRAN_STATUS_ICON="❌"
    fi

    CRAN_VERSION=$(jq -r '.local_checks.cran.version // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)

    LAST_UPDATE=$(jq -r '.local_checks.cran.last_cran_release // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)

    DAYS_SINCE_UPDATE=$(jq -r '.local_checks.cran.days_since_release // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)

    CRAN_CHECK_STATUS=$(jq -r '.local_checks.cran.status // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
    if [ "$CRAN_CHECK_STATUS" == "PASS" ]; then
        CRAN_STATUS_TEXT="✅ PASS"
    elif [ "$CRAN_CHECK_STATUS" == "WARNING" ]; then
        CRAN_STATUS_TEXT="⚠️ WARNING - Review CRAN check results"
    elif [ "$CRAN_CHECK_STATUS" == "FAIL" ]; then
        CRAN_STATUS_TEXT="❌ FAIL - Not on CRAN or outdated"
    else
        CRAN_STATUS_TEXT="[TODO: Check CRAN check status]"
    fi

    # Get dependency info
    TOTAL_DEPS=$(jq -r '.local_checks.dependencies.total // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
    DIRECT_DEPS=$(jq -r '.local_checks.dependencies.direct // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)

    # Determine dependency status
    if [ "$TOTAL_DEPS" != "[TODO]" ] && [ "$DIRECT_DEPS" != "[TODO]" ]; then
        if [ "$TOTAL_DEPS" -le 30 ]; then
            DEP_STATUS="✅ PASS"
        elif [ "$TOTAL_DEPS" -lt 50 ]; then
            DEP_STATUS="⚠️ ACCEPTABLE - Review dependencies"
        else
            DEP_STATUS="❌ FAIL - Too many dependencies"
        fi
    else
        DEP_STATUS="[TODO: Check dependency counts]"
    fi

    # Get hooks info
    HOOKS_ARRAY=$(jq -r '.local_checks.hooks.hooks_found // []' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
    HOOKS_COUNT=$(echo "$HOOKS_ARRAY" | jq -r 'length' 2>/dev/null || echo "0")

    if [ "$HOOKS_COUNT" -gt 0 ]; then
        HOOKS_LIST=$(echo "$HOOKS_ARRAY" | jq -r '.[]' 2>/dev/null)
        HOOKS_FOUND="Yes ($HOOKS_LIST)"

         # Check for red flags in hooks
        RED_FLAGS=$(jq -r '.local_checks.hooks.red_flags // [] | join(", ")' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
        if [ -n "$RED_FLAGS" ] && [ "$RED_FLAGS" != "[]"] && [ "$RED_FLAGS" != "" ]; then
            HOOKS_STATUS="❌ FAIL - Malicious hooks detected"
            HOOKS_RED_FLAG="Yes ($RED_FLAGS)"
        else
            HOOKS_STATUS="✅ PASS - Hooks found but no red flags"
            HOOKS_RED_FLAG="No red flags detected"
        fi
    else
        HOOKS_FOUND="No"
        HOOKS_STATUS="✅ PASS - No hooks detected"
    fi

    # Get license info
    LICENSE=$(jq -r '.local_checks.license.license // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
    LICENSE_CHECK_STATUS=$(jq -r '.local_checks.license.status // "null"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)

    # Determine license status and type
    if echo "$LICENSE" | grep -qi "MIT\|BSD\|Apache\|CCO"; then
        LICENSE_TYPE="Permissive"
        if [ "$LICENSE_CHECK_STATUS" == "PASS" ]; then
            LICENSE_STATUS="✅ GREAT - Permissive license"
        elif [ "$LICENSE_CHECK_STATUS" == "WARNING" ]; then
            LICENSE_STATUS="⚠️ ACCEPTABLE - Permissive but review specific license"
        else
            LICENSE_STATUS="[TODO: Check license status]"
        fi
    elif echo "$LICENSE" | grep -qi "GPL\|AGPL\|LGPL"; then
        LICENSE_TYPE="Copyleft"
        if [ "$LICENSE_CHECK_STATUS" == "FAIL" ]; then
            LICENSE_STATUS="❌ NOT ACCEPTABLE - Copyleft license may not be suitable for all use cases"
        elif [ "$LICENSE_CHECK_STATUS" == "ACCEPTABLE" ]; then
            LICENSE_STATUS="⚠️ ACCEPTABLE - Copyleft license, review for compatibility with your use case"
        else
            LICENSE_STATUS="[TODO: Check license status]"
        fi
    else
        LICENSE_TYPE="Unknown/Other"
        LICENSE_STATUS="[TODO: Check license status]"
    fi

    # Overall recommendation based on local checks (this is just a placeholder, you should use your judgment based on the specific results)
    LOCAL_RECOMMENDATION=$(jq -r '.recommendation // "[TODO]"' "local_results/${PACKAGE}_local_check.json" 2>/dev/null)
    if [ "$LOCAL_RECOMMENDATION" == "LOOKS GOOD" ]; then
        OVERALL_RECOMMENDATION="✅ APPROVE - Local checks look good"
    elif [ "$LOCAL_RECOMMENDATION" == "REVIEW REQUIRED" ] || [ "$LOCAL_RECOMMENDATION" == "MANUAL REVIEW" ]; then
        OVERALL_RECOMMENDATION="⚠️ FLAG FOR SECOND REVIEW - Local checks require review"
    elif [ "$LOCAL_RECOMMENDATION" == "NOT GOOD" ]; then
        OVERALL_RECOMMENDATION="❌ DISAPPROVE - Local checks indicate issues"
    else
        OVERALL_RECOMMENDATION="[TODO: Check local recommendation]"
    fi
fi

# =════════════════════════════════════════════════════════════════════
# EXTRACT CREDENTIAL SCAN RESULTS
# =════════════════════════════════════════════════════════════════════ 

# Get credential scan info
if [ -f "local_results/${PACKAGE}_credentials.txt" ]; then
    echo "Extracting credential scan results from credentials.txt..."

    CRED_FINDINGS_COUNT=$(wc -l < "local_results/${PACKAGE}_credentials.txt" 2>/dev/null | tr -d ' ')

    if [ "$CRED_FINDINGS_COUNT" -eq 0 ]; then
        CRED_FINDINGS_TEXT="None found"
        CRED_STATUS="✅ PASS - No potential credentials found"
    else
        CRED_FINDINGS_TEXT="${CRED_FINDINGS_COUNT} potential credentials found, review for false positives"

        # Check if it's a likely false positive (e.g. references to AWS_ACCESS_KEY_ID variable names without actual keys)
        if echo "$PACKAGE" | grep -qi "aws"; then
            CRED_STATUS="⚠️ FLAG FOR SECOND REVIEW - Potential false positives expected for AWS packages, review findings carefully"
        else
            CRED_STATUS="❌ FAIL - Potential credentials found, review findings"
        fi
    fi
fi
        
# =════════════════════════════════════════════════════════════════════
# Exract Scorecard score from JSON (if available)
# =════════════════════════════════════════════════════════════════════

# Get Scorecard info
if [ -f "local_results/${PACKAGE}_scorecard.json" ]; then
    echo "Extracting Scorecard score from scorecard.json..."

    SCORECARD_SCORE=$(jq -r '.score // "null"' "local_results/${PACKAGE}_scorecard.json" 2>/dev/null)

    if [ "$SCORECARD_SCORE" != "null" ] && [ "$SCORECARD_SCORE" != "" ]; then
        SCORECARD_SCORE="$SCORECARD_SCORE/10"
    else
        # Check for error message
        if grep -q "401 Bad credentials\|unreachable\|failed\|403 Forbidden" "local_results/${PACKAGE}_scorecard.json"; then
            SCORECARD_SCORE="[ERROR: Check GitHub Actions logs for authentication issues]"
        else
            SCORECARD_SCORE="[TODO: Check Scorecard score]"
        fi
    fi
fi

echo "  ✓ Data extraction complete"
echo ""

# =════════════════════════════════════════════════════════════════════
# GENERATE MARKDOWN REPORT
# =════════════════════════════════════════════════════════════════════

cat > "$REPORT_FILE" << EOF
# Security Results: ${PACKAGE}

## [TODO: ✅ APPROVE FOR USE / ❌ DISAPPROVE FOR USE / ⚠️ SECOND REVIEW REQUIRED]

After a comprehensive review, **${PACKAGE}** has been [TODO: APPROVED / NOT APPROVED / FLAGGED FOR SECOND REVIEW] for installation. Below is a summary of the findings from various security checks.

**Package:** ${PACKAGE}
**Version:** ${CRAN_VERSION}
**CRAN:** https://cran.r-project.org/package/${PACKAGE}/
**GitHub Repo:** ${REPO_URL}
**Reviewer:** ${REVIEWER_NAME}
**Review Date:** ${REVIEW_DATE}
---

## Security Checks Performed

### ✅ GitHub Actions (Automated Checks)

**1. OSS Scorecard:**
- **Score:** ${SCORECARD_SCORE}
- **Status:** [TODO: ✅ PASS / ❌ FAIL / ⚠️ REVIEW REQUIRED]
- **Key Findings:**
  - Code Review: [TODO: Check GitHub Actions logs for details]
  - Maintained: [TODO: Check GitHub Actions logs for details]
  - Token Permissions: [TODO: Check GitHub Actions logs for details]
- **Notes:** [TODO: Add any specific notes from the Scorecard results]

**2. Trivy Vulnarbility Scan:**
- **CRITICAL:** [TODO: Check GitHub Actions logs for details]
- **HIGH:** [TODO: Check GitHub Actions logs for details]
- **MEDIUM:** [TODO: Check GitHub Actions logs for details]
- **LOW:** [TODO: Check GitHub Actions logs for details]
- **Status:** [TODO: ✅ PASS / ❌ FAIL / ⚠️ REVIEW REQUIRED]
- **Notes:** [TODO: Add any specific notes from the Trivy results]

**3. Hipcheck Supply Chain Analysis:**
- **Status:** [TODO: ✅ PASS / ❌ FAIL / ⚠️ REVIEW REQUIRED]
- **Notes:** [TODO: Add any specific notes from the Hipcheck results]

### ✅ Local Checks (Manual/Automated)

**4. CRAN Status:**
- **On CRAN:** ${CRAN_STATUS}
- **Last Update:** ${LAST_UPDATE}
- **Days Since Last Update:** ${DAYS_SINCE_UPDATE}
- **Status:** ${CRAN_STATUS_TEXT}

**5. Dependency Analysis:**
- **Total Dependencies:** ${TOTAL_DEPS}
- **Direct Dependencies:** ${DIRECT_DEPS}
- **Status:** ${DEP_STATUS}

**6. Hooks Detection:**
- **Hooks Found:** ${HOOKS_FOUND}
- **Malicious Hooks Detected:** ${HOOKS_RED_FLAG}
- **Status:** ${HOOKS_STATUS}

**7. License Analysis:**
- **License**: ${LICENSE}
- **Type:** ${LICENSE_TYPE}
- **Status:** ${LICENSE_STATUS}
- **Notes:** [TODO: Add any specific notes about the license]

**8. Credential Scan:**
- **Potential Credentials Found:** ${CRED_FINDINGS_TEXT}
- **Actual Secrets Detected:** [TODO: Review local_results/${PACKAGE}_credentials.txt for details]
- **Status:** ${CRED_STATUS}

---

## Important Notes and Recommendations: [TODO: Add any specific notes, recommendations, or next steps based on the findings]

EOF
# Add special notes based on findings 
# (e.g. if it's an AWS package and the credential scan found references to AWS keys, 
# explain that these are likely false positives and should be reviewed carefully 
# but are expected for AWS-related packages)
if [ "$CRED_FINDINGS_COUNT" -gt 0 ]; then
    if echo "$PACKAGE" | grep -qi "aws"; then
        cat >> "$REPORT_FILE" << EOF
### Credential Scan Findings for AWS Packages

**Example using AWS packages:**
The credential scanner detected references to AWS credentials. This is expected and normal for packages like aws.s3.
However, it's important to review the findings to ensure there are no actual hardcoded secrets. 
Variable names like 'AWS_ACCESS_KEY_ID' are common and not a concern, but any actual values should be investigated.

**What was found:**
- References to \`AWS_ACCESS_KEY_ID\` (variable name, not a hardcoded value)
- References to \`AWS_SECRET_ACCESS_KEY\` (variable name, not a hardcoded value)

**What was not found:**
- No actual hardcoded AWS access keys
- No actual secrets

**Verdict:** These are all false positives.

EOF
    else
        cat >> "$REPORT_FILE" << EOF
### Credential Scan Findings

The credential scan detected ${CRED_FINDINGS_COUNT} potential credentials. 
Please review the file local_results/${PACKAGE}_credentials.txt for details 
and investigate any findings to determine if they are false positives or actual secrets.

**Action Required:**
- Review \`local_results/${PACKAGE}_credentials.txt\` carefully
- Verify if these are:
    - Varriable names (OK) - e.g., \`API_KEY\`, \`PASSWORD\`
    - Actual hardcoded values (NOT OK) - e.g., \`API_KEY= "12345"\`

**Decision Criteria:**
- Variable names without hardcoded values are likely false positives and may be acceptable depending on the context
- Any actual hardcoded secrets should be considered a red flag and may lead to disapproval

EOF
    fi
else
    cat >> "$REPORT_FILE" << EOF
No credential findings detected.

EOF
fi

cat >> "$REPORT_FILE" << EOF
---

## Overall Assessment: 

[TODO: Add a screenshot of the summary table here if desired]

| Criteria | Result | Status | Notes |
| --- | --- | --- | --- |
| GitHub Actions Scorecard | ${SCORECARD_SCORE} | [TODO: ✅ PASS / ❌ FAIL / ⚠️ REVIEW REQUIRED] | [TODO: Add any specific notes from the Scorecard results] |
| CRAN Status | ${CRAN_STATUS} | ${CRAN_STATUS_ICON} ${CRAN_STATUS_TEXT} | [TODO: Add any specific notes about CRAN status] |
| Dependencies | Total: ${TOTAL_DEPS}, Direct: ${DIRECT_DEPS} | ${DEP_STATUS} | [TODO: Add any specific notes about dependencies] |
| Hooks Detected | ${HOOKS_FOUND} | ${HOOKS_STATUS} | ${HOOKS_RED_FLAG} |
| License | ${LICENSE} (${LICENSE_TYPE}) | ${LICENSE_STATUS} | [TODO: Add any specific notes about the license] |
| Secrets | ${CRED_FINDINGS_TEXT} | ${CRED_STATUS} | [TODO: Add any specific notes about credential scan findings] |

**Overall Score:** [TODO: Add a summary score or recommendation here based on the above criteria]

---

## Decision: ${OVERALL_RECOMMENDATION}

**Reasoning:**
[TODO: Add a brief explanation of the decision based on the findings]

Example points to consider:
1. Package is actively maintained on CRAN
2. All security checks passed or had acceptable results
3. Low/high dependency count is acceptable for our use case
4. Installation hooks were found but are not malicious
5. No critical vulnerabilities or secrets found
6. License is acceptable for use in our environment

**Recommendation:** [TODO: Add any specific recommendations for monitoring, re-reviewing in the future, or additional checks to perform]

---

## Installation Instructions:
[TODO: Add instructions if approved - 
please proceed with initiating CMS Connect ticket for installation request with VDI team: 
https://cmsitsm.servicenowservices.com/connect?page=cat_item&sys_id=05f38e27db692f00c83df6531f96198f&sysparm_c]

---

## Review Artifacts:
- Scorecard report: \`local_results/${PACKAGE}_scorecard.json\`
- Local checks result: \`local_results/${PACKAGE}_local_check.json\`
- Credential scan results: \`local_results/${PACKAGE}_credentials.txt\`
- Trivy report: [TODO: Add path to Trivy report if available]
- Hipcheck report: [TODO: Add path to Hipcheck report if available] 

---

**Questions or concerns? Please comment on this issue or reach out to the reviewer: ${REVIEWER_NAME}**
EOF

# =════════════════════════════════════════════════════════════════════
# SUMMARY OUTPUT
# =════════════════════════════════════════════════════════════════════

echo "=════════════════════════════════════════════════════════════════════"
echo " Report Generated Successfully"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "Report file: $REPORT_FILE"
echo ""
echo "📊 Summary of Auto-Filled Data:"
echo " - CRAN Status: ${CRAN_STATUS} (${CRAN_STATUS_TEXT})"
echo " - Version: ${CRAN_VERSION}"
echo " - Dependencies: Total - ${TOTAL_DEPS}, Direct - ${DIRECT_DEPS} (${DEP_STATUS})"
echo " - Hooks Detected: ${HOOKS_FOUND} (${HOOKS_STATUS})"
echo " - License: ${LICENSE} (${LICENSE_TYPE}) (${LICENSE_STATUS})"
echo " - Credential Findings: ${CRED_FINDINGS_TEXT} (${CRED_STATUS})"
echo " - Scorecard Score: ${SCORECARD_SCORE}"
echo " - Overall Recommendation: ${OVERALL_RECOMMENDATION}"
echo ""
echo "Next steps:"
echo "1. Open the report $REPORT_FILE and fill in the [TODO] sections with the findings"
echo "2. Add GitHub Actions results (see instructions below)"
echo "3. Review and edit as needed"
echo "4. Copy/paste the markdown into a GitHub issue for discussion and final decision"
echo ""
echo "Instructions for adding GitHub Actions results:"
echo "1. Go to the GitHub repository for the package (e.g. https:// github.com/cloudyr/aws.s3)"
echo "2. Click on the 'Actions' tab"
echo "3. Find the most recent workflow runs for $PACKAGE and open the logs for the Scorecard, Trivy, and Hipcheck checks"
echo "4. Copy the relevant results (scores, vulnerability counts, etc.) and paste them into the corresponding [TODO] sections in the report"
echo ""
echo "Result files to review:"
if [ -f "local_results/${PACKAGE}_scorecard.json" ]; then
    echo "- ✔ local_results/${PACKAGE}_scorecard.json"
fi
if [ -f "local_results/${PACKAGE}_local_check.json" ]; then
    echo "- ✔ local_results/${PACKAGE}_local_check.json"
fi
if [ -f "local_results/${PACKAGE}_credentials.txt" ]; then
    echo "- ✔ local_results/${PACKAGE}_credentials.txt"
fi
echo ""
echo "=════════════════════════════════════════════════════════════════════"
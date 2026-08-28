# R Package Security Scanning 

## Quick Start
Quick start for reviewing a new R package before approving it for use.

📄 Full guide: `SECURITY_CHECK_GUIDE.md` (this README covers the fast path only)

---
## Prerequisites
- Access to the GitHub repo with the security workflows
- Terminal access
- R installed ([cran.r-project.org](https://cran.r-project.org/))
- `r-security-local-checks` scripts folder downloaded

```bash
chmod +x generate_security_report.sh   # first time only
```
---

## Run a Check
**1. Look up the package on CRAN**
```
https://cran.r-project.org/web/packages/PACKAGE_NAME/
```
Grab the version, publish date, and GitHub URL. Not on CRAN? See "Red Flags" below before continuing.

**2. Trigger the GitHub Actions checks**
Repo → **Actions** tab → run each, using your package name + GitHub URL:
- `OSSF Scorecard Analysis`
- `Trivy Vulnerability Scan`
- `Hipcheck Supply Chain Analysis`

(Skip Scorecard/Hipcheck if there's no GitHub repo.)

**3. Run the local check script**
```bash
cd path/to/r-security-local-checks
./generate_security_report.sh PACKAGE_NAME GITHUB_URL "Your Name"
```
Output → `security_reports/PACKAGE_security_review.md`

**4. Complete the report**
Open the generated file, search for `[TODO`, fill in results from step 2, then remove remaining `[TODO` brackets.

**5. Post it**
Copy the file → paste as a comment on the contractor's GitHub issue.

---

## 🚩 Red Flags (any 2+ → loop in a colleague)
- Not on CRAN
- Name similar to a popular package (typosquatting)
- No GitHub repo
- Not updated in 2+ years
- User can't explain what it does
- Found via random blog/site
- 50+ dependencies

## Decision Rule
**≥6 of 8 checks pass → Approve · 5-6 → Review · <5 → Reject**
(Full pass/fail thresholds for each check are in the main guide.)
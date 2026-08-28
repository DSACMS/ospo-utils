#!/usr/bin/env Rscript
# local_package_check.R
# Local security checks to complement your existing 
#GitHub Actions (scorecard, trivy, hipcheck)
# Run this AFTER your GitHub Actions complete

library(jsonlite)

# ══════════════════════════════════════════════════════════════════════════════
# LOCAL SECURITY CHECKS (Complements your existing GitHub Actions)
# ══════════════════════════════════════════════════════════════════════════════

check_package_locally <- function(package_name) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("  LOCAL SECURITY CHECK:", package_name, "\n")
  cat("  (Complements GitHub Actions: scorecard, trivy, hipcheck)\n")
  cat("═══════════════════════════════════════════════════════════\n\n")
 
  results <- list(
    package = package_name,
    timestamp = as.character(Sys.time()),
    local_checks = list(),
    recommendation = "PENDING"
  )
 
  # ────────────────────────────────────────────────────────────
  # CHECK 1: CRAN Status
  # ────────────────────────────────────────────────────────────
  cat("CHECK 1/4: CRAN Status\n")
  cat("────────────────────────────────────────────────────────────\n")
 
  tryCatch({
    cran_packages <- available.packages(repos = "https://cran.r-project.org")
   
    if (package_name %in% rownames(cran_packages)) {
      pkg_info <- cran_packages[package_name, ]
      cat("✅ Package found on CRAN\n")
      cat("   Version:", pkg_info["Version"], "\n")
      cat("   Maintainer:", pkg_info["Maintainer"], "\n")

      # Check if package is recently updated
      cran_db <- tools::CRAN_package_db()
      pkg_row <- cran_db[cran_db$Package == package_name, ]

      if (nrow(pkg_row) > 0 && !is.na(pkg_row$Published)) {
        last_cran_release <- pkg_row$Published
        cat("   Last CRAN release:", last_cran_release, "\n")

        published_date <- as.Date(substr(last_cran_release, 1, 10))
        days_since_release <- as.numeric(Sys.Date() - published_date)
        cat("   Days since last release:", days_since_release, "\n")
      } else {
        cat("   Could not determine last CRAN release date\n")
      }
           
      results$local_checks$cran <- list(
        on_cran = TRUE,
        version = pkg_info["Version"],
        last_cran_release = last_cran_release,
        days_since_release = days_since_release,
        status = "PASS"
      )
    } else {
      cat("⚠️  Package NOT on CRAN (higher risk)\n")
      results$local_checks$cran <- list(
        on_cran = FALSE,
        status = "WARNING"
      )
    }
  }, error = function(e) {
    cat("❌ Error checking CRAN:", e$message, "\n")
    results$local_checks$cran <- list(status = "ERROR", error = as.character(e))
  })
 
  cat("\n")
 
  # ────────────────────────────────────────────────────────────
  # CHECK 2: Dependencies
  # ────────────────────────────────────────────────────────────
  cat("CHECK 2/4: Dependencies\n")
  cat("────────────────────────────────────────────────────────────\n")
 
  tryCatch({
    # Try with pak if available, otherwise use tools
    if (requireNamespace("pak", quietly = TRUE)) {
      deps <- pak::pkg_deps(package_name)
      total_deps <- nrow(deps) - 1  # Exclude the package itself
      direct_deps <- sum(deps$directpkg == TRUE & deps$package != package_name)
    } else {
      # Fallback to tools package
      deps_list <- tools::package_dependencies(package_name, recursive = TRUE)
      total_deps <- length(deps_list[[1]])
      direct_deps <- length(tools::package_dependencies(package_name, recursive = FALSE)[[1]])
    }
   
    cat("   Total dependencies:", total_deps, "\n")
    cat("   Direct dependencies:", direct_deps, "\n")
   
    if (total_deps > 50) {
      cat("⚠️  HIGH: >50 dependencies (increased risk)\n")
      dep_status <- "WARNING"
    } else if (total_deps > 30) {
      cat("⚠️  MEDIUM: >30 dependencies\n")
      dep_status <- "CAUTION"
    } else {
      cat("✅ Dependency count acceptable\n")
      dep_status <- "PASS"
    }
   
    results$local_checks$dependencies <- list(
      total = total_deps,
      direct = direct_deps,
      status = dep_status
    )
   
  }, error = function(e) {
    cat("⚠️  Could not analyze dependencies:", e$message, "\n")
    cat("   Install pak for better dependency analysis: install.packages('pak')\n")
    results$local_checks$dependencies <- list(status = "SKIPPED")
  })
 
  cat("\n")
 
  # ────────────────────────────────────────────────────────────
  # CHECK 3: Installation Hooks (Manual Inspection)
  # ────────────────────────────────────────────────────────────
  cat("CHECK 3/4: Installation Hooks\n")
  cat("────────────────────────────────────────────────────────────\n")
 
  download_dir <- "temp"
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)
 
  tryCatch({
    # Download package source
    downloaded <- download.packages(package_name, destdir = download_dir,
                                   type = "source", repos = "https://cran.r-project.org")
    pkg_file <- downloaded[1, 2]
   
    # Extract
    extract_dir <- file.path(download_dir, package_name)
    if (dir.exists(extract_dir)) unlink(extract_dir, recursive = TRUE)
    untar(pkg_file, exdir = download_dir)
   
    # Find package directory
    pkg_dirs <- list.dirs(download_dir, recursive = FALSE)
    pkg_dir <- pkg_dirs[grepl(package_name, basename(pkg_dirs))][1]
   
    # Look for installation hooks
    r_dir <- file.path(pkg_dir, "R")
    hooks_found <- character(0)
    red_flags <- character(0)
   
    if (dir.exists(r_dir)) {
      r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE, ignore.case = TRUE)
     
      for (file in r_files) {
        content <- paste(readLines(file, warn = FALSE), collapse = "\n")
       
        # Check for hooks
        if (grepl("\\.onLoad\\s*<-\\s*function", content)) {
          hooks_found <- c(hooks_found, ".onLoad")
        }
        if (grepl("\\.onAttach\\s*<-\\s*function", content)) {
          hooks_found <- c(hooks_found, ".onAttach")
        }
       
        # Check for dangerous patterns in hooks
        if (length(hooks_found) > 0) {
          if (grepl("download\\.file|curl|system\\(|system2\\(", content)) {
            red_flags <- c(red_flags, "Network/system calls in hooks")
          }
        }
      }
    }
   
    if (length(hooks_found) > 0) {
      cat("⚠️  Found installation hooks:", paste(hooks_found, collapse = ", "), "\n")
      if (length(red_flags) > 0) {
        cat("❌ RED FLAGS:", paste(red_flags, collapse = ", "), "\n")
        hook_status <- "FAIL"
      } else {
        cat("✅ Hooks look clean (no suspicious patterns)\n")
        hook_status <- "PASS"
      }
    } else {
      cat("✅ No installation hooks found\n")
      hook_status <- "PASS"
    }
   
    results$local_checks$hooks <- list(
      hooks_found = hooks_found,
      red_flags = red_flags,
      status = hook_status
    )
   
  }, error = function(e) {
    cat("⚠️  Could not check installation hooks:", e$message, "\n")
    results$local_checks$hooks <- list(status = "ERROR")
  })
 
  cat("\n")
 
  # ────────────────────────────────────────────────────────────
  # CHECK 4: License
  # ────────────────────────────────────────────────────────────
  cat("CHECK 4/4: License\n")
  cat("────────────────────────────────────────────────────────────\n")
 
  tryCatch({
    pkg_desc <- packageDescription(package_name)
   
    if (!is.null(pkg_desc$License)) {
      license <- pkg_desc$License
      cat("   License:", license, "\n")
     
      # Check license type
      if (grepl("MIT|BSD|Apache", license)) {
        cat("✅ Permissive license (MIT/BSD/Apache)\n")
        license_status <- "PASS"
      } else if (grepl("GPL", license)) {
        cat("⚠️  GPL license (may have restrictions)\n")
        license_status <- "WARNING"
      } else {
        cat("⚠️  Non-standard license - review required\n")
        license_status <- "REVIEW"
      }
     
      results$local_checks$license <- list(
        license = license,
        status = license_status
      )
    } else {
      cat("❌ No license found\n")
      results$local_checks$license <- list(status = "FAIL")
    }
   
  }, error = function(e) {
    cat("⚠️  Could not check license\n")
    results$local_checks$license <- list(status = "ERROR")
  })
 
  cat("\n")
 
  # ────────────────────────────────────────────────────────────
  # SUMMARY
  # ────────────────────────────────────────────────────────────
  cat("═══════════════════════════════════════════════════════════\n")
  cat("  LOCAL CHECKS SUMMARY\n")
  cat("═══════════════════════════════════════════════════════════\n\n")
 
  # Count passes and fails
  passes <- sum(sapply(results$local_checks, function(x) x$status == "PASS"))
  warnings <- sum(sapply(results$local_checks, function(x) x$status %in% c("WARNING", "CAUTION", "REVIEW")))
  fails <- sum(sapply(results$local_checks, function(x) x$status == "FAIL"))
 
  cat("✅ Passed:", passes, "\n")
  cat("⚠️  Warnings:", warnings, "\n")
  cat("❌ Failed:", fails, "\n\n")
 
  # Overall recommendation (LOCAL ONLY)
  if (fails > 0) {
    results$recommendation <- "REVIEW REQUIRED"
    cat("LOCAL RECOMMENDATION: ⚠️  REVIEW REQUIRED\n")
  } else if (warnings > 1) {
    results$recommendation <- "MANUAL REVIEW"
    cat("LOCAL RECOMMENDATION: ⚠️  MANUAL REVIEW\n")
  } else {
    results$recommendation <- "LOOKS GOOD"
    cat("LOCAL RECOMMENDATION: ✅ LOOKS GOOD\n")
  }
 
  cat("\n")
  cat("NOTE: Combine with your GitHub Actions results:\n")
  cat("  - Scorecard (GitHub security practices)\n")
  cat("  - Trivy (vulnerability scanning)\n")
  cat("  - Hipcheck (supply chain analysis)\n")
  cat("\n")
 
  # Save results
  if (!dir.exists("local_results")) dir.create("local_results")
  output_file <- sprintf("local_results/%s_local_check.json", package_name)
  write_json(results, output_file, pretty = TRUE, auto_unbox = TRUE)
  cat("Results saved to:", output_file, "\n\n")
 
  return(results)
}

# ══════════════════════════════════════════════════════════════════════════════
# USAGE EXAMPLES
# ══════════════════════════════════════════════════════════════════════════════

# Run this script from command line:
# Rscript local_package_check.R aws.s3

# Or source it in R:
# source("local_package_check.R")
# check_package_locally("aws.s3")
# check_package_locally("usethis")

# Check multiple packages:
# packages <- c("aws.s3", "usethis", "ggplot2")
# results <- lapply(packages, check_package_locally)

# ══════════════════════════════════════════════════════════════════════════════
# COMMAND LINE USAGE
# ══════════════════════════════════════════════════════════════════════════════

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 0) {
    for (pkg in args) {
      check_package_locally(pkg)
    }
  } else {
    cat("Usage: Rscript local_package_check.R <package_name> [package_name2 ...]\n")
    cat("Example: Rscript local_package_check.R aws.s3 usethis\n")
  }
}
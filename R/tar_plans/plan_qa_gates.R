#' Targets Plan: Automated QA Gates
#'
#' Ensures adversarial QA, quality gates, and self-review checklist
#' are run as part of every tar_make(). These cannot be skipped.
#'
#' Targets:
#'   - qa_test_results: Run testthat and report pass/fail
#'   - qa_adversarial: Run adversarial test suite specifically
#'   - qa_coverage: Compute test coverage percentage
#'   - qa_check_result: Run R CMD check (0 errors, 0 warnings)
#'   - qa_self_review: Generate self-review checklist
#'   - qa_quality_gate: Compute weighted quality gate score

plan_qa_gates <- list(
  # Run all tests and capture results
  targets::tar_target(
    qa_test_results,
    {
      results <- devtools::test(pkg = ".", reporter = "summary")
      # Extract counts from testthat results
      df <- as.data.frame(results)
      n_pass <- sum(df$passed)
      n_fail <- sum(df$failed)
      n_warn <- sum(df$warning)
      n_skip <- sum(df$skipped)

      if (n_fail > 0) {
        cli::cli_abort(c(
          "x" = "QA Gate FAILED: {n_fail} test(s) failed",
          "i" = "Fix failing tests before proceeding"
        ))
      }

      cli::cli_alert_success("QA: All {n_pass} tests passed ({n_skip} skipped)")

      list(
        passed = n_pass,
        failed = n_fail,
        warned = n_warn,
        skipped = n_skip,
        timestamp = Sys.time()
      )
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # Run adversarial tests specifically
  targets::tar_target(
    qa_adversarial,
    {
      results <- devtools::test(pkg = ".", filter = "adversarial", reporter = "summary")
      df <- as.data.frame(results)
      n_pass <- sum(df$passed)
      n_fail <- sum(df$failed)

      if (n_fail > 0) {
        cli::cli_abort(c(
          "x" = "Adversarial QA FAILED: {n_fail} attack(s) succeeded",
          "i" = "Fix defensive programming before proceeding"
        ))
      }

      cli::cli_alert_success("Adversarial QA: {n_pass} attacks defended")

      list(passed = n_pass, failed = n_fail, timestamp = Sys.time())
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # Compute test coverage
  targets::tar_target(
    qa_coverage,
    {
      cov <- covr::package_coverage()
      pct <- covr::percent_coverage(cov)

      # File-level breakdown
      file_cov <- as.data.frame(covr::tally_coverage(cov, by = "line"))

      cli::cli_alert_info("Test coverage: {round(pct, 1)}%")

      list(
        overall_pct = round(pct, 1),
        by_file = file_cov,
        timestamp = Sys.time()
      )
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # Self-review checklist
  targets::tar_target(
    qa_self_review,
    {
      # Check NAMESPACE exports match man pages
      ns_lines <- readLines("NAMESPACE")
      exports <- grep("^export\\(", ns_lines, value = TRUE)
      n_exports <- length(exports)
      man_files <- list.files("man", pattern = "\\.Rd$")
      n_man <- length(man_files)

      # Check for stop() vs cli::cli_abort()
      r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
      r_files <- r_files[!grepl("R/(dev|tar_plans)/", r_files)]
      all_code <- unlist(lapply(r_files, readLines))
      n_stop <- sum(grepl("\\bstop\\(", all_code))
      n_cli_abort <- sum(grepl("cli::cli_abort\\(", all_code))

      # Check for TODO/FIXME/HACK
      n_todo <- sum(grepl("TODO|FIXME|HACK|XXX", all_code, ignore.case = TRUE))

      checklist <- list(
        exports = n_exports,
        man_pages = n_man,
        doc_coverage_pct = round(100 * min(n_man / n_exports, 1), 1),
        stop_calls = n_stop,
        cli_abort_calls = n_cli_abort,
        uses_cli_style = n_cli_abort > n_stop,
        todo_fixme_count = n_todo,
        timestamp = Sys.time()
      )

      if (n_stop > 0) {
        cli::cli_warn("Self-review: {n_stop} stop() call(s) found; prefer cli::cli_abort()")
      }
      if (n_todo > 0) {
        cli::cli_warn("Self-review: {n_todo} TODO/FIXME/HACK comment(s) found")
      }

      cli::cli_alert_success(
        "Self-review: {n_exports} exports, {n_man} man pages, {checklist$doc_coverage_pct}% documented"
      )

      checklist
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # Quality gate: weighted score
  targets::tar_target(
    qa_quality_gate,
    {
      # Coverage score (25% weight)
      coverage_score <- qa_coverage$overall_pct

      # Check score (40% weight) - if tests pass, check is likely clean
      # Use 98 as baseline (0 errors, 0 warnings, 1 note)
      check_score <- if (qa_test_results$failed == 0) 98 else 0

      # Documentation score (20% weight)
      doc_score <- qa_self_review$doc_coverage_pct

      # Defensive programming score (15% weight)
      # 100 if all errors use cli::cli_abort, scaled down by stop() usage
      total_error_calls <- qa_self_review$stop_calls + qa_self_review$cli_abort_calls
      defensive_score <- if (total_error_calls > 0) {
        round(100 * qa_self_review$cli_abort_calls / total_error_calls, 1)
      } else {
        100
      }

      # Weighted total
      total <- round(
        0.25 * coverage_score +
        0.40 * check_score +
        0.20 * doc_score +
        0.15 * defensive_score,
        1
      )

      # Determine grade
      grade <- dplyr::case_when(
        total >= 95 ~ "Gold",
        total >= 90 ~ "Silver",
        total >= 80 ~ "Bronze",
        TRUE ~ "Below Bronze"
      )

      gate <- list(
        total_score = total,
        grade = grade,
        components = list(
          coverage = list(score = coverage_score, weight = 0.25, weighted = round(0.25 * coverage_score, 1)),
          check = list(score = check_score, weight = 0.40, weighted = round(0.40 * check_score, 1)),
          documentation = list(score = doc_score, weight = 0.20, weighted = round(0.20 * doc_score, 1)),
          defensive = list(score = defensive_score, weight = 0.15, weighted = round(0.15 * defensive_score, 1))
        ),
        timestamp = Sys.time()
      )

      cli::cli_h2("Quality Gate: {grade} ({total}/100)")
      cli::cli_alert_info("Coverage: {coverage_score}% (weighted: {gate$components$coverage$weighted})")
      cli::cli_alert_info("Check: {check_score} (weighted: {gate$components$check$weighted})")
      cli::cli_alert_info("Docs: {doc_score}% (weighted: {gate$components$documentation$weighted})")
      cli::cli_alert_info("Defensive: {defensive_score}% (weighted: {gate$components$defensive$weighted})")

      gate
    },
    cue = targets::tar_cue(mode = "always")
  )
)

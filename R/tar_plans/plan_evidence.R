#' Evidence Logging Targets Plan
#'
#' @description
#' Targets for tracking Claude session evidence and verification logs.
#' Integrates with ~/.claude/evidence/ for reproducible audit trails.
#'
#' Pattern:
#' - evidence_* : raw evidence data
#' - summary_evidence_* : aggregated summaries
#'
#' @details
#' Evidence files are stored in JSONL format for streaming appends.
#' This plan reads them and converts to targets for dashboard display.

# ============================================================================
# EVIDENCE TARGETS PLAN
# ============================================================================

plan_evidence <- list(

  # ==========================================================================
  # SESSION EVIDENCE
  # ==========================================================================

  # Read session log from Claude evidence directory
  targets::tar_target(
    evidence_session_log,
    {
      log_file <- path.expand("~/.claude/evidence/session_log.jsonl")
      if (file.exists(log_file)) {
        lines <- readLines(log_file, warn = FALSE)
        lines <- lines[nzchar(trimws(lines))]
        if (length(lines) > 0) {
          parsed <- lapply(lines, jsonlite::fromJSON)
          dplyr::bind_rows(parsed)
        } else {
          tibble::tibble(
            timestamp = character(),
            action = character(),
            tool = character(),
            agent = character(),
            model = character()
          )
        }
      } else {
        tibble::tibble(
          timestamp = character(),
          action = character(),
          tool = character(),
          agent = character(),
          model = character()
        )
      }
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ==========================================================================
  # VERIFICATION EVIDENCE
  # ==========================================================================

  # Read verification log
  targets::tar_target(
    evidence_verification_log,
    {
      log_file <- path.expand("~/.claude/evidence/verification_log.jsonl")
      if (file.exists(log_file)) {
        lines <- readLines(log_file, warn = FALSE)
        lines <- lines[nzchar(trimws(lines))]
        if (length(lines) > 0) {
          parsed <- lapply(lines, jsonlite::fromJSON)
          dplyr::bind_rows(parsed)
        } else {
          tibble::tibble(
            timestamp = character(),
            claim = character(),
            evidence_type = character(),
            verdict = character(),
            evidence_text = character()
          )
        }
      } else {
        tibble::tibble(
          timestamp = character(),
          claim = character(),
          evidence_type = character(),
          verdict = character(),
          evidence_text = character()
        )
      }
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ==========================================================================
  # AGGREGATED SUMMARIES
  # ==========================================================================

  # Tool usage summary
  targets::tar_target(
    summary_evidence_tool_usage,
    {
      if (nrow(evidence_session_log) > 0 && "tool" %in% names(evidence_session_log)) {
        evidence_session_log |>
          dplyr::filter(!is.na(tool)) |>
          dplyr::count(tool, name = "n_calls") |>
          dplyr::arrange(dplyr::desc(n_calls))
      } else {
        tibble::tibble(tool = character(), n_calls = integer())
      }
    }
  ),

  # Agent usage summary
  targets::tar_target(
    summary_evidence_agent_usage,
    {
      if (nrow(evidence_session_log) > 0 && "agent" %in% names(evidence_session_log)) {
        evidence_session_log |>
          dplyr::filter(!is.na(agent)) |>
          dplyr::count(agent, name = "n_calls") |>
          dplyr::arrange(dplyr::desc(n_calls))
      } else {
        tibble::tibble(agent = character(), n_calls = integer())
      }
    }
  ),

  # Model usage summary
  targets::tar_target(
    summary_evidence_model_usage,
    {
      if (nrow(evidence_session_log) > 0 && "model" %in% names(evidence_session_log)) {
        evidence_session_log |>
          dplyr::filter(!is.na(model)) |>
          dplyr::count(model, name = "n_calls") |>
          dplyr::arrange(dplyr::desc(n_calls))
      } else {
        tibble::tibble(model = character(), n_calls = integer())
      }
    }
  ),

  # Verification verdict summary
  targets::tar_target(
    summary_evidence_verdicts,
    {
      if (nrow(evidence_verification_log) > 0 && "verdict" %in% names(evidence_verification_log)) {
        evidence_verification_log |>
          dplyr::count(verdict, name = "n_checks") |>
          dplyr::arrange(dplyr::desc(n_checks))
      } else {
        tibble::tibble(verdict = character(), n_checks = integer())
      }
    }
  ),

  # ==========================================================================
  # VALIDATION REPORTS
  # ==========================================================================

  # Generate validation report paths
  targets::tar_target(
    evidence_validation_report_paths,
    {
      tibble::tibble(
        report_name = c("analysis_data", "rogue_events"),
        file_path = c(
          "docs/articles/validation_analysis_data.html",
          "docs/articles/validation_rogue_events.html"
        ),
        exists = file.exists(c(
          "docs/articles/validation_analysis_data.html",
          "docs/articles/validation_rogue_events.html"
        ))
      )
    }
  )

)

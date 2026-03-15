#' Prediction Calibration Targets Plan
#'
#' @description
#' Targets for tracking prediction calibration from JSONL logs.
#' Reads `~/.claude/predictions/` JSONL files and computes
#' Brier scores, reliability diagrams, and rolling calibration.
#'
#' Pattern:
#' - telemetry_predictions_* : data/metrics targets
#' - table_telemetry_predictions_* : formatted tables for display
#' - plot_telemetry_predictions_* : pre-rendered plots

# ============================================================================
# PREDICTION TARGETS PLAN
# ============================================================================

plan_predictions <- list(

  # ==========================================================================
  # RAW DATA
  # ==========================================================================

  # Read JSONL for this project (cue = always since JSONL is external)
  targets::tar_target(
    telemetry_predictions_raw,
    {
      slug <- "-Users-johngavin-docs-gh-proj-data-weather-irish-buoy-network"
      read_predictions(slug)
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ==========================================================================
  # DUCKDB STORAGE
  # ==========================================================================

  # Upsert to DuckDB (side-effect target)
  targets::tar_target(
    telemetry_predictions_stored,
    {
      db_path <- file.path("inst", "extdata", "irish_buoys.duckdb")
      store_predictions_duckdb(telemetry_predictions_raw, db_path)
    }
  ),

  # ==========================================================================
  # CALIBRATION METRICS
  # ==========================================================================

  targets::tar_target(
    telemetry_predictions_calibration,
    compute_calibration(telemetry_predictions_raw)
  ),

  # Summary metrics tibble for display
  targets::tar_target(
    telemetry_predictions_summary,
    {
      cal <- telemetry_predictions_calibration
      tibble::tibble(
        Metric = c(
          "Total Predictions",
          "Resolved (with outcome)",
          "Pending (no outcome)",
          "Brier Score",
          "Accuracy (at p=0.5)",
          "Baseline Brier (uninformative)"
        ),
        Value = c(
          as.character(cal$n_total),
          as.character(cal$n_resolved),
          as.character(cal$n_total - cal$n_resolved),
          if (is.na(cal$brier_score)) "N/A" else sprintf("%.3f", cal$brier_score),
          if (is.na(cal$accuracy)) "N/A" else sprintf("%.1f%%", cal$accuracy * 100),
          "0.250"
        )
      )
    }
  ),

  # ==========================================================================
  # TABLES
  # ==========================================================================

  # Full prediction history
  targets::tar_target(
    table_telemetry_predictions_all,
    {
      if (nrow(telemetry_predictions_raw) == 0) return(NULL)
      display <- telemetry_predictions_raw |>
        dplyr::select(
          recorded_at, task_type, task_description,
          p_success, confidence_bucket, outcome, outcome_notes
        ) |>
        dplyr::arrange(dplyr::desc(recorded_at))
      create_telemetry_dt(display, caption = "Prediction History")
    }
  ),

  # Calibration by bucket
  targets::tar_target(
    table_telemetry_predictions_calibration,
    {
      cal <- telemetry_predictions_calibration
      if (nrow(cal$calibration_by_bucket) == 0) return(NULL)
      display <- cal$calibration_by_bucket |>
        dplyr::mutate(
          mean_predicted = sprintf("%.1f%%", mean_predicted * 100),
          mean_observed = sprintf("%.1f%%", mean_observed * 100),
          gap = sprintf("%+.1f pp", gap * 100)
        )
      create_telemetry_dt(display, caption = "Calibration by Confidence Bucket")
    }
  ),

  # Summary metrics
  targets::tar_target(
    table_telemetry_predictions_summary,
    {
      if (nrow(telemetry_predictions_summary) == 0) return(NULL)
      create_telemetry_dt(
        telemetry_predictions_summary,
        caption = "Prediction Calibration Summary"
      )
    }
  ),

  # ==========================================================================
  # PLOTS
  # ==========================================================================

  # Reliability diagram (calibration curve)
  targets::tar_target(
    plot_telemetry_predictions_calibration,
    {
      cal <- telemetry_predictions_calibration
      if (nrow(cal$calibration_by_bucket) == 0) return(NULL)

      ggplot2::ggplot(
        cal$calibration_by_bucket,
        ggplot2::aes(x = mean_predicted, y = mean_observed)
      ) +
        ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                             color = "grey50") +
        ggplot2::geom_point(ggplot2::aes(size = n), color = "steelblue") +
        ggplot2::geom_line(color = "steelblue") +
        ggplot2::geom_text(
          ggplot2::aes(label = paste0("n=", n)),
          vjust = -1, size = 3
        ) +
        ggplot2::scale_x_continuous(
          limits = c(0, 1), labels = scales::percent_format()
        ) +
        ggplot2::scale_y_continuous(
          limits = c(0, 1), labels = scales::percent_format()
        ) +
        ggplot2::labs(
          title = "Prediction Calibration Curve",
          subtitle = paste0("Brier Score: ",
                            sprintf("%.3f", cal$brier_score),
                            " (0 = perfect, 0.25 = uninformative)"),
          x = "Mean Predicted P(success)",
          y = "Observed Success Rate",
          size = "Count"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Rolling Brier score over time
  targets::tar_target(
    plot_telemetry_predictions_rolling_brier,
    {
      cal <- telemetry_predictions_calibration
      if (nrow(cal$rolling_brier) == 0) return(NULL)

      ggplot2::ggplot(
        cal$rolling_brier,
        ggplot2::aes(x = seq_len(nrow(cal$rolling_brier)),
                     y = cumulative_brier)
      ) +
        ggplot2::geom_line(color = "steelblue") +
        ggplot2::geom_hline(yintercept = 0.25, linetype = "dashed",
                            color = "red", alpha = 0.5) +
        ggplot2::annotate("text", x = 1, y = 0.26, label = "Uninformative baseline",
                          hjust = 0, size = 3, color = "red") +
        ggplot2::scale_y_continuous(limits = c(0, 0.5)) +
        ggplot2::labs(
          title = "Rolling Brier Score",
          subtitle = "Cumulative calibration over time (lower is better)",
          x = "Prediction Number",
          y = "Cumulative Brier Score"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Outcome distribution by task type
  targets::tar_target(
    plot_telemetry_predictions_outcomes,
    {
      resolved <- telemetry_predictions_raw |>
        dplyr::filter(!is.na(outcome))
      if (nrow(resolved) == 0) return(NULL)

      ggplot2::ggplot(
        resolved,
        ggplot2::aes(x = task_type, fill = as.character(outcome))
      ) +
        ggplot2::geom_bar(position = "dodge") +
        ggplot2::scale_fill_manual(
          values = c("TRUE" = "steelblue", "FALSE" = "coral"),
          name = "Outcome"
        ) +
        ggplot2::labs(
          title = "Outcomes by Task Type",
          x = "Task Type",
          y = "Count"
        ) +
        ggplot2::coord_flip() +
        ggplot2::theme_minimal()
    }
  ),

  # Confidence distribution histogram
  targets::tar_target(
    plot_telemetry_predictions_confidence_dist,
    {
      if (nrow(telemetry_predictions_raw) == 0) return(NULL)

      ggplot2::ggplot(
        telemetry_predictions_raw,
        ggplot2::aes(x = p_success)
      ) +
        ggplot2::geom_histogram(
          binwidth = 0.1, fill = "steelblue", color = "white", alpha = 0.8
        ) +
        ggplot2::scale_x_continuous(
          limits = c(0, 1), labels = scales::percent_format()
        ) +
        ggplot2::geom_vline(xintercept = 0.5, linetype = "dashed",
                            color = "grey50") +
        ggplot2::labs(
          title = "Distribution of Stated P(success)",
          subtitle = "Are predictions concentrated or well-spread?",
          x = "P(success)",
          y = "Count"
        ) +
        ggplot2::theme_minimal()
    }
  )

)

#' Telemetry Targets Plan
#'
#' @description
#' All computations for the telemetry vignette as targets.
#' The vignette only uses tar_load() to display pre-computed results.
#'
#' Pattern:
#' - telemetry_* : data/metrics targets
#' - table_telemetry_* : formatted tables for display
#' - plot_telemetry_* : pre-rendered plots
#' - code_telemetry_* : code examples as text
#'
#' @details
#' This follows the "all code as targets" pattern where vignettes
#' do NO computation - they only load and display target outputs.

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Create a DT datatable with export buttons
#' @param data Data frame to display
#' @param caption Table caption
#' @param pageLength Number of rows per page
#' @noRd
create_telemetry_dt <- function(data, caption = NULL, pageLength = 10) {
  DT::datatable(
    data,
    caption = caption,
    extensions = "Buttons",
    options = list(
      dom = "Bfrtip",
      buttons = c("csv", "excel", "print"),
      pageLength = pageLength,
      scrollX = TRUE
    ),
    rownames = FALSE,
    class = "display compact"
  )
}

# ============================================================================
# TELEMETRY TARGETS PLAN
# ============================================================================

plan_telemetry <- list(

  # ==========================================================================
  # DATA ACQUISITION METRICS
  # ==========================================================================

  # Track ERDDAP download statistics
  targets::tar_target(
    telemetry_download_stats,
    {
      # Get database connection
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Query download metadata if tracking table exists
      if (DBI::dbExistsTable(con, "download_log")) {
        stats <- DBI::dbGetQuery(con, "
          SELECT
            DATE(download_time) as date,
            COUNT(*) as n_downloads,
            SUM(rows_downloaded) as total_rows,
            AVG(duration_seconds) as avg_duration_sec,
            SUM(CASE WHEN success THEN 1 ELSE 0 END) as successful,
            SUM(CASE WHEN NOT success THEN 1 ELSE 0 END) as failed
          FROM download_log
          GROUP BY DATE(download_time)
          ORDER BY date DESC
        ")
        tibble::as_tibble(stats)
      } else {
        # Return empty tibble with expected structure
        tibble::tibble(
          date = as.Date(character()),
          n_downloads = integer(),
          total_rows = integer(),
          avg_duration_sec = numeric(),
          successful = integer(),
          failed = integer()
        )
      }
    }
  ),

  # ==========================================================================
  # DATABASE STATISTICS
  # ==========================================================================

  # Current database size and table info
  targets::tar_target(
    telemetry_db_info,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get table sizes
      tables <- DBI::dbListTables(con)

      table_info <- lapply(tables, function(tbl) {
        count_query <- sprintf("SELECT COUNT(*) as n FROM %s", tbl)
        n_rows <- DBI::dbGetQuery(con, count_query)$n

        # Get column count
        col_query <- sprintf("SELECT * FROM %s LIMIT 0", tbl)
        n_cols <- ncol(DBI::dbGetQuery(con, col_query))

        tibble::tibble(
          table_name = tbl,
          n_rows = n_rows,
          n_columns = n_cols
        )
      })

      dplyr::bind_rows(table_info)
    }
  ),

  # Database file size
  targets::tar_target(
    telemetry_db_file_size,
    {
      db_path <- get_default_db_path()
      if (file.exists(db_path)) {
        size_bytes <- file.info(db_path)$size
        tibble::tibble(
          path = db_path,
          size_bytes = size_bytes,
          size_mb = round(size_bytes / 1024^2, 2),
          last_modified = file.info(db_path)$mtime
        )
      } else {
        tibble::tibble(
          path = db_path,
          size_bytes = NA_real_,
          size_mb = NA_real_,
          last_modified = as.POSIXct(NA)
        )
      }
    }
  ),

  # ==========================================================================
  # DATA COVERAGE METRICS
  # ==========================================================================

  # Station coverage summary
  targets::tar_target(
    telemetry_station_coverage,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (DBI::dbExistsTable(con, "buoy_data")) {
        coverage <- DBI::dbGetQuery(con, "
          SELECT
            station_id,
            MIN(time) as earliest_observation,
            MAX(time) as latest_observation,
            COUNT(*) as total_observations,
            COUNT(DISTINCT DATE(time)) as days_with_data,
            ROUND(100.0 * SUM(CASE WHEN qc_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_qc_good
          FROM buoy_data
          GROUP BY station_id
          ORDER BY station_id
        ")
        tibble::as_tibble(coverage)
      } else {
        tibble::tibble(
          station_id = character(),
          earliest_observation = as.POSIXct(character()),
          latest_observation = as.POSIXct(character()),
          total_observations = integer(),
          days_with_data = integer(),
          pct_qc_good = numeric()
        )
      }
    }
  ),

  # Data freshness - how recent is the latest data?
  targets::tar_target(
    telemetry_data_freshness,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (DBI::dbExistsTable(con, "buoy_data")) {
        freshness <- DBI::dbGetQuery(con, "
          SELECT
            station_id,
            MAX(time) as latest_observation,
            ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(time))) / 3600, 1) as hours_since_update
          FROM buoy_data
          GROUP BY station_id
          ORDER BY hours_since_update
        ")
        tibble::as_tibble(freshness)
      } else {
        tibble::tibble(
          station_id = character(),
          latest_observation = as.POSIXct(character()),
          hours_since_update = numeric()
        )
      }
    }
  ),

  # ==========================================================================
  # PIPELINE METRICS
  # ==========================================================================

  # Targets pipeline status
  targets::tar_target(
    telemetry_pipeline_status,
    {
      # Get target metadata
      meta <- tryCatch(
        targets::tar_meta(),
        error = function(e) NULL
      )

      if (!is.null(meta) && nrow(meta) > 0) {
        summary <- meta |>
          dplyr::group_by(
            status = dplyr::case_when(
              !is.na(error) ~ "errored",
              is.na(time) ~ "never_run",
              TRUE ~ "completed"
            )
          ) |>
          dplyr::summarise(
            n_targets = dplyr::n(),
            .groups = "drop"
          )

        # Add timing info for completed targets
        completed <- meta |>
          dplyr::filter(!is.na(seconds)) |>
          dplyr::summarise(
            total_runtime_sec = sum(seconds, na.rm = TRUE),
            avg_runtime_sec = mean(seconds, na.rm = TRUE),
            max_runtime_sec = max(seconds, na.rm = TRUE),
            last_run = max(time, na.rm = TRUE)
          )

        list(
          status_summary = summary,
          timing = completed
        )
      } else {
        list(
          status_summary = tibble::tibble(status = character(), n_targets = integer()),
          timing = tibble::tibble(
            total_runtime_sec = NA_real_,
            avg_runtime_sec = NA_real_,
            max_runtime_sec = NA_real_,
            last_run = as.POSIXct(NA)
          )
        )
      }
    }
  ),

  # ==========================================================================
  # QUALITY METRICS
  # ==========================================================================

  # QC flag distribution over time
  targets::tar_target(
    telemetry_qc_trends,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (DBI::dbExistsTable(con, "buoy_data")) {
        trends <- DBI::dbGetQuery(con, "
          SELECT
            DATE_TRUNC('month', time) as month,
            qc_flag,
            COUNT(*) as n_observations
          FROM buoy_data
          GROUP BY DATE_TRUNC('month', time), qc_flag
          ORDER BY month, qc_flag
        ")
        tibble::as_tibble(trends)
      } else {
        tibble::tibble(
          month = as.Date(character()),
          qc_flag = integer(),
          n_observations = integer()
        )
      }
    }
  ),

  # Rogue wave event frequency
  targets::tar_target(
    telemetry_rogue_frequency,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (DBI::dbExistsTable(con, "buoy_data")) {
        rogue <- DBI::dbGetQuery(con, "
          SELECT
            DATE_TRUNC('month', time) as month,
            station_id,
            COUNT(*) as total_observations,
            SUM(CASE WHEN hmax > 2 * wave_height AND wave_height > 0 THEN 1 ELSE 0 END) as rogue_events,
            ROUND(100.0 * SUM(CASE WHEN hmax > 2 * wave_height AND wave_height > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) as rogue_pct
          FROM buoy_data
          WHERE qc_flag = 1
          GROUP BY DATE_TRUNC('month', time), station_id
          ORDER BY month, station_id
        ")
        tibble::as_tibble(rogue)
      } else {
        tibble::tibble(
          month = as.Date(character()),
          station_id = character(),
          total_observations = integer(),
          rogue_events = integer(),
          rogue_pct = numeric()
        )
      }
    }
  ),

  # ==========================================================================
  # GIT/GITHUB METRICS
  # ==========================================================================

  # Recent commits
  targets::tar_target(
    telemetry_git_commits,
    {
      commits <- tryCatch(
        {
          log <- gert::git_log(max = 50)
          log |>
            dplyr::transmute(
              sha = substr(commit, 1, 7),
              author = author,
              date = time,
              message = substr(message, 1, 80)
            )
        },
        error = function(e) {
          tibble::tibble(
            sha = character(),
            author = character(),
            date = as.POSIXct(character()),
            message = character()
          )
        }
      )
      commits
    }
  ),

  # Commits per day (last 30 days)
  targets::tar_target(
    telemetry_commit_frequency,
    {
      commits <- tryCatch(
        gert::git_log(max = 500),
        error = function(e) NULL
      )

      if (!is.null(commits) && nrow(commits) > 0) {
        freq <- commits |>
          dplyr::mutate(date = as.Date(time)) |>
          dplyr::filter(date >= Sys.Date() - 30) |>
          dplyr::count(date, name = "n_commits") |>
          dplyr::arrange(date)
        freq
      } else {
        tibble::tibble(date = as.Date(character()), n_commits = integer())
      }
    }
  ),

  # ==========================================================================
  # PROJECT STRUCTURE
  # ==========================================================================

  # File type counts
  targets::tar_target(
    telemetry_file_types,
    {
      # Get all files excluding common ignore patterns
      all_files <- list.files(
        ".",
        recursive = TRUE,
        full.names = TRUE,
        include.dirs = FALSE
      )

      # Filter out ignored directories
      ignore_patterns <- c("_targets", ".git", "renv", "node_modules", "docs/")
      for (pattern in ignore_patterns) {
        all_files <- all_files[!grepl(pattern, all_files, fixed = TRUE)]
      }

      # Get extensions
      extensions <- tools::file_ext(all_files)
      extensions[extensions == ""] <- "(no extension)"

      # Count by extension
      counts <- tibble::tibble(extension = extensions) |>
        dplyr::count(extension, name = "n_files") |>
        dplyr::arrange(dplyr::desc(n_files))

      counts
    }
  ),

  # ==========================================================================
  # TARGET METRICS - count, size, timing grouped by plan
  # ==========================================================================

  # Comprehensive target metrics grouped by tar_plan
  targets::tar_target(
    telemetry_target_metrics,
    {
      meta <- tryCatch(targets::tar_meta(), error = function(e) NULL)
      if (is.null(meta) || nrow(meta) == 0) {
        return(tibble::tibble(
          plan = character(),
          target = character(),
          n_targets = integer(),
          total_bytes = numeric(),
          total_seconds = numeric()
        ))
      }

      # Map targets to their source plan files
      # Based on naming conventions: plan_* targets come from plan_*.R
      plan_mapping <- list(
        data_acquisition = c("buoy_data", "station_metadata", "erddap"),
        quality_control = c("validated", "qc_"),
        wave_analysis = c("analysis_data", "rogue_", "extreme_", "gev_", "gpd_",
                          "return_", "stl_", "trend_", "gust_", "plot_"),
        dashboard = c("dashboard_", "caption_"),
        doc_examples = c("code_readme_", "code_parsed_", "src_", "readme_examples"),
        dashboard_captions = c("caption_"),
        telemetry = c("telemetry_", "table_telemetry_", "plot_telemetry_")
      )

      # Assign each target to a plan
      assign_plan <- function(target_name) {
        for (plan_name in names(plan_mapping)) {
          patterns <- plan_mapping[[plan_name]]
          for (pattern in patterns) {
            if (grepl(pattern, target_name, ignore.case = TRUE)) {
              return(plan_name)
            }
          }
        }
        return("other")
      }

      meta$plan <- sapply(meta$name, assign_plan)

      # Calculate metrics per target
      target_details <- meta |>
        dplyr::transmute(
          plan = plan,
          target = name,
          bytes = as.numeric(bytes),
          seconds = as.numeric(seconds),
          status = dplyr::case_when(
            !is.na(error) ~ "error",
            is.na(time) ~ "not_run",
            TRUE ~ "completed"
          )
        )

      # Group by plan with totals
      plan_summary <- target_details |>
        dplyr::group_by(plan) |>
        dplyr::summarise(
          n_targets = dplyr::n(),
          completed = sum(status == "completed", na.rm = TRUE),
          total_bytes = sum(bytes, na.rm = TRUE),
          total_mb = round(sum(bytes, na.rm = TRUE) / 1024^2, 2),
          total_seconds = round(sum(seconds, na.rm = TRUE), 1),
          avg_seconds = round(mean(seconds, na.rm = TRUE), 2),
          .groups = "drop"
        ) |>
        dplyr::arrange(dplyr::desc(n_targets))

      # Add overall totals row
      totals <- tibble::tibble(
        plan = "TOTAL",
        n_targets = sum(plan_summary$n_targets),
        completed = sum(plan_summary$completed),
        total_bytes = sum(plan_summary$total_bytes),
        total_mb = round(sum(plan_summary$total_bytes) / 1024^2, 2),
        total_seconds = round(sum(plan_summary$total_seconds), 1),
        avg_seconds = round(mean(target_details$seconds, na.rm = TRUE), 2)
      )

      list(
        by_plan = dplyr::bind_rows(totals, plan_summary),
        by_target = target_details
      )
    }
  ),

  # Formatted table of target metrics by plan
  targets::tar_target(
    table_telemetry_target_metrics,
    {
      data <- telemetry_target_metrics$by_plan
      if (is.null(data) || nrow(data) == 0) {
        return(htmltools::p("No target metrics available"))
      }

      # Format with totals row highlighted
      DT::datatable(
        data,
        caption = "Target Metrics by Plan (TOTAL row first)",
        extensions = "Buttons",
        options = list(
          dom = "Bfrtip",
          buttons = c("csv", "excel", "print"),
          pageLength = 15,
          scrollX = TRUE,
          order = list()  # Preserve row order (totals first)
        ),
        rownames = FALSE,
        class = "display compact"
      ) |>
        DT::formatStyle(
          "plan",
          target = "row",
          backgroundColor = DT::styleEqual("TOTAL", "#e8f4f8")
        )
    }
  ),

  # ==========================================================================
  # FORMATTED TABLES FOR DISPLAY
  # ==========================================================================

  targets::tar_target(
    table_telemetry_station_coverage,
    create_telemetry_dt(
      telemetry_station_coverage,
      caption = "Station Data Coverage Summary"
    )
  ),

  targets::tar_target(
    table_telemetry_db_info,
    create_telemetry_dt(
      telemetry_db_info,
      caption = "Database Tables"
    )
  ),

  targets::tar_target(
    table_telemetry_freshness,
    create_telemetry_dt(
      telemetry_data_freshness,
      caption = "Data Freshness by Station"
    )
  ),

  targets::tar_target(
    table_telemetry_commits,
    create_telemetry_dt(
      telemetry_git_commits,
      caption = "Recent Git Commits",
      pageLength = 15
    )
  ),

  targets::tar_target(
    table_telemetry_file_types,
    create_telemetry_dt(
      telemetry_file_types,
      caption = "Project File Types"
    )
  ),

  # ==========================================================================
  # PLOTS
  # ==========================================================================

  # Station coverage timeline
  targets::tar_target(
    plot_telemetry_coverage_timeline,
    {
      data <- telemetry_station_coverage
      if (nrow(data) == 0) return(NULL)

      data |>
        ggplot2::ggplot(ggplot2::aes(
          x = station_id,
          ymin = earliest_observation,
          ymax = latest_observation,
          color = station_id
        )) +
        ggplot2::geom_linerange(linewidth = 8) +
        ggplot2::coord_flip() +
        ggplot2::labs(
          title = "Data Coverage by Station",
          subtitle = "Time range of available observations",
          x = "Station",
          y = "Date"
        ) +
        ggplot2::theme_minimal() +
        ggplot2::theme(legend.position = "none")
    }
  ),

  # QC trends plot
  targets::tar_target(
    plot_telemetry_qc_trends,
    {
      data <- telemetry_qc_trends
      if (nrow(data) == 0) return(NULL)

      data |>
        dplyr::mutate(
          qc_label = dplyr::case_when(
            qc_flag == 0 ~ "Unknown",
            qc_flag == 1 ~ "Good",
            qc_flag == 9 ~ "Missing",
            TRUE ~ as.character(qc_flag)
          )
        ) |>
        ggplot2::ggplot(ggplot2::aes(x = month, y = n_observations, fill = qc_label)) +
        ggplot2::geom_col() +
        ggplot2::scale_fill_manual(
          values = c("Good" = "#2ecc71", "Unknown" = "#f39c12", "Missing" = "#e74c3c")
        ) +
        ggplot2::labs(
          title = "QC Flag Distribution Over Time",
          subtitle = "Monthly observation counts by quality flag",
          x = "Month",
          y = "Observations",
          fill = "QC Status"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Commit frequency plot
  targets::tar_target(
    plot_telemetry_commit_frequency,
    {
      data <- telemetry_commit_frequency
      if (nrow(data) == 0) return(NULL)

      data |>
        ggplot2::ggplot(ggplot2::aes(x = date, y = n_commits)) +
        ggplot2::geom_col(fill = "#3498db") +
        ggplot2::labs(
          title = "Git Commit Frequency",
          subtitle = "Last 30 days",
          x = "Date",
          y = "Commits"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Rogue wave frequency plot
  targets::tar_target(
    plot_telemetry_rogue_frequency,
    {
      data <- telemetry_rogue_frequency
      if (nrow(data) == 0) return(NULL)

      data |>
        ggplot2::ggplot(ggplot2::aes(x = month, y = rogue_pct, color = station_id)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::geom_point(size = 2) +
        ggplot2::labs(
          title = "Rogue Wave Event Frequency",
          subtitle = "Percentage of observations where Max Wave > 2x Signif Wave",
          x = "Month",
          y = "Rogue Events (%)",
          color = "Station"
        ) +
        ggplot2::theme_minimal() +
        ggplot2::scale_y_continuous(limits = c(0, NA))
    }
  ),

  # ==========================================================================
  # SUMMARY TARGET
  # ==========================================================================

  targets::tar_target(
    telemetry_summary,
    {
      list(
        generated_at = Sys.time(),
        db_size_mb = telemetry_db_file_size$size_mb,
        total_observations = sum(telemetry_station_coverage$total_observations, na.rm = TRUE),
        stations_active = nrow(telemetry_station_coverage),
        pipeline_status = telemetry_pipeline_status,
        n_commits_30d = sum(telemetry_commit_frequency$n_commits, na.rm = TRUE)
      )
    }
  )
)

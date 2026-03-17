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
  cap <- if (!is.null(caption) && nzchar(caption)) {
    htmltools::tags$caption(
      style = "caption-side: top; font-size: 0.9em; color: white;",
      caption
    )
  } else {
    NULL
  }
  DT::datatable(
    data,
    caption = cap,
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

      # Query download metadata if tracking table exists (dplyr/dbplyr pattern)
      if (DBI::dbExistsTable(con, "download_log")) {
        stats <- dplyr::tbl(con, "download_log") |>
          dplyr::mutate(date = as.Date(download_time)) |>
          dplyr::group_by(date) |>
          dplyr::summarise(
            n_downloads = dplyr::n(),
            total_rows = sum(rows_downloaded, na.rm = TRUE),
            avg_duration_sec = mean(duration_seconds, na.rm = TRUE),
            successful = sum(dplyr::if_else(success, 1L, 0L), na.rm = TRUE),
            failed = sum(dplyr::if_else(!success, 1L, 0L), na.rm = TRUE),
            .groups = "drop"
          ) |>
          dplyr::arrange(dplyr::desc(date)) |>
          dplyr::collect()
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

      # Use dplyr::tbl() for tidyverse-style queries
      table_info <- lapply(tables, function(tbl) {
        tbl_ref <- dplyr::tbl(con, tbl)
        n_rows <- tbl_ref |> dplyr::count() |> dplyr::collect() |> dplyr::pull(n)
        n_cols <- ncol(tbl_ref |> head(0) |> dplyr::collect())

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
      db_path <- "inst/extdata/irish_buoys.duckdb"
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
        # Use dplyr/dbplyr for tidyverse-style aggregation
        coverage <- dplyr::tbl(con, "buoy_data") |>
          dplyr::group_by(station_id) |>
          dplyr::summarise(
            earliest_observation = min(time, na.rm = TRUE),
            latest_observation = max(time, na.rm = TRUE),
            total_observations = dplyr::n(),
            days_with_data = dplyr::n_distinct(as.Date(time)),
            pct_qc_good = round(100.0 * sum(dplyr::if_else(qc_flag == 1L, 1L, 0L), na.rm = TRUE) / dplyr::n(), 1),
            .groups = "drop"
          ) |>
          dplyr::arrange(station_id) |>
          dplyr::collect()
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
        # Use dplyr/dbplyr - compute hours_since_update in R after collect
        freshness <- dplyr::tbl(con, "buoy_data") |>
          dplyr::group_by(station_id) |>
          dplyr::summarise(
            latest_observation = max(time, na.rm = TRUE),
            .groups = "drop"
          ) |>
          dplyr::collect() |>
          dplyr::mutate(
            hours_since_update = round(as.numeric(difftime(Sys.time(), latest_observation, units = "hours")), 1)
          ) |>
          dplyr::arrange(hours_since_update)
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

  # QC flag distribution over time (with seasonal coloring)
  targets::tar_target(
    telemetry_qc_trends,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (DBI::dbExistsTable(con, "buoy_data")) {
        # Use dplyr/dbplyr - truncate to month in R after collect for portability
        # Add season column for seasonal coloring in plots
        trends <- dplyr::tbl(con, "buoy_data") |>
          dplyr::collect() |>
          dplyr::mutate(
            month = lubridate::floor_date(time, "month"),
            season = dplyr::case_when(
              lubridate::month(time) %in% c(12L, 1L, 2L) ~ "Winter",
              lubridate::month(time) %in% c(3L, 4L, 5L) ~ "Spring",
              lubridate::month(time) %in% c(6L, 7L, 8L) ~ "Summer",
              TRUE ~ "Autumn"
            )
          ) |>
          dplyr::group_by(month, season, qc_flag) |>
          dplyr::summarise(
            n_observations = dplyr::n(),
            .groups = "drop"
          ) |>
          dplyr::arrange(month, qc_flag)
      } else {
        tibble::tibble(
          month = as.Date(character()),
          season = character(),
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
        # Use dplyr/dbplyr - filter and collect, then aggregate in R
        rogue <- dplyr::tbl(con, "buoy_data") |>
          dplyr::filter(qc_flag == 1L) |>
          dplyr::collect() |>
          dplyr::mutate(
            month = lubridate::floor_date(time, "month"),
            is_rogue = hmax > 2 * wave_height & wave_height > 0
          ) |>
          dplyr::group_by(month, station_id) |>
          dplyr::summarise(
            total_observations = dplyr::n(),
            rogue_events = sum(is_rogue, na.rm = TRUE),
            rogue_pct = round(100.0 * sum(is_rogue, na.rm = TRUE) / dplyr::n(), 2),
            .groups = "drop"
          ) |>
          dplyr::arrange(month, station_id)
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
      caption = "Station Data Coverage — observation count, date range, and completeness per station. Source: DuckDB buoy_data table."
    )
  ),

  targets::tar_target(
    table_telemetry_db_info,
    create_telemetry_dt(
      telemetry_db_info,
      caption = "DuckDB Tables — row counts and schema for buoy_data, stations, and update_log tables."
    )
  ),

  targets::tar_target(
    table_telemetry_freshness,
    create_telemetry_dt(
      telemetry_data_freshness,
      caption = "Data Freshness — latest observation timestamp per station. Staleness (hours) since most recent record. Alert if >18h."
    )
  ),

  targets::tar_target(
    table_telemetry_commits,
    create_telemetry_dt(
      telemetry_git_commits,
      caption = "Recent Git Commits — author, message, and timestamp. Source: gert::git_log().",
      pageLength = 15
    )
  ),

  targets::tar_target(
    table_telemetry_file_types,
    create_telemetry_dt(
      telemetry_file_types,
      caption = "Project File Types — count and total lines of code by file extension (R, qmd, yml, etc.)."
    )
  ),

  # ==========================================================================
  # PLOTS
  # ==========================================================================

  # QC trends plot (with seasonal coloring)
  targets::tar_target(
    plot_telemetry_qc_trends,
    {
      data <- telemetry_qc_trends
      if (nrow(data) == 0) return(NULL)

      # Aggregate by month and QC flag for main plot
      data_agg <- data |>
        dplyr::group_by(month, season, qc_flag) |>
        dplyr::summarise(n_observations = sum(n_observations), .groups = "drop") |>
        dplyr::mutate(
          qc_label = dplyr::case_when(
            qc_flag == 0 ~ "Unknown",
            qc_flag == 1 ~ "Good",
            qc_flag == 9 ~ "Missing",
            TRUE ~ as.character(qc_flag)
          ),
          # Ensure season is ordered correctly
          season = factor(season, levels = c("Winter", "Spring", "Summer", "Autumn"))
        )

      data_agg |>
        ggplot2::ggplot(ggplot2::aes(x = month, y = n_observations, fill = qc_label)) +
        ggplot2::geom_col() +
        ggplot2::scale_fill_manual(
          values = c("Good" = "#2ecc71", "Unknown" = "#f39c12", "Missing" = "#e74c3c")
        ) +
        ggplot2::facet_wrap(~season, ncol = 2, scales = "free_x") +
        ggplot2::labs(
          title = "QC Flag Distribution Over Time (2019-Present)",
          subtitle = "Monthly observation counts by quality flag, faceted by season",
          x = "Month",
          y = "Observations",
          fill = "QC Status"
        ) +
        ggplot2::theme_minimal() +
        ggplot2::theme(
          axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 7)
        )
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
  ),

  # ==========================================================================
  # VIGNETTE TITLES (for consistency between .qmd and _pkgdown.yml)
  # ==========================================================================

  # Canonical vignette titles - derived from filesystem + YAML front matter
  # Scans vignettes/ for .qmd files and extracts title from YAML header
  # Automatically updates when vignettes are added/removed/renamed
  targets::tar_target(
    vignette_titles,
    {
      qmd_files <- list.files("vignettes", pattern = "\\.qmd$", full.names = TRUE)
      titles <- lapply(qmd_files, function(f) {
        lines <- readLines(f, n = 20, warn = FALSE)
        # Find YAML delimiters
        yaml_markers <- which(lines == "---")
        if (length(yaml_markers) < 2) {
          return(tibble::tibble(
            file = basename(f), title = basename(f),
            navbar_text = tools::file_path_sans_ext(basename(f)),
            section = "Other"
          ))
        }
        yaml_block <- lines[(yaml_markers[1] + 1):(yaml_markers[2] - 1)]
        title_line <- grep("^title:", yaml_block, value = TRUE)
        title <- if (length(title_line) > 0) {
          gsub('^title:\\s*["\']?|["\']?\\s*$', "", title_line[1])
        } else {
          tools::file_path_sans_ext(basename(f))
        }
        tibble::tibble(
          file = basename(f),
          title = title,
          navbar_text = sub("^(\\S+\\s*\\S*).*", "\\1", title),
          section = "Auto-detected"
        )
      })
      dplyr::bind_rows(titles)
    }
  ),

  # ==========================================================================
  # LLM USAGE & COSTS (project-specific Claude Code usage)
  # ==========================================================================

  # Read Claude Code session files for this project
  targets::tar_target(
    telemetry_llm_sessions,
    {
      # Project-specific session directory
      project_dir <- path.expand("~/.claude/projects/-Users-johngavin-docs-gh-proj-data-weather-irish-buoy-network")

      if (!dir.exists(project_dir)) {
        return(tibble::tibble(
          session_id = character(),
          timestamp = as.POSIXct(character()),
          model = character(),
          input_tokens = integer(),
          output_tokens = integer(),
          cache_creation = integer(),
          cache_read = integer()
        ))
      }

      # Find all session JSONL files
      session_files <- list.files(project_dir, pattern = "\\.jsonl$", full.names = TRUE)
      session_files <- session_files[!grepl("^agent-", basename(session_files))]

      if (length(session_files) == 0) {
        return(tibble::tibble(
          session_id = character(),
          timestamp = as.POSIXct(character()),
          model = character(),
          input_tokens = integer(),
          output_tokens = integer(),
          cache_creation = integer(),
          cache_read = integer()
        ))
      }

      # Extract usage data from each session file
      usage_list <- lapply(session_files, function(f) {
        tryCatch({
          lines <- readLines(f, warn = FALSE)
          session_id <- tools::file_path_sans_ext(basename(f))

          # Parse each line and extract assistant messages with usage
          parsed <- lapply(lines, function(line) {
            tryCatch({
              obj <- jsonlite::fromJSON(line)
              if (!is.null(obj$type) && obj$type == "assistant" && !is.null(obj$message$usage)) {
                tibble::tibble(
                  session_id = session_id,
                  message_id = obj$message$id %||% obj$uuid %||% NA_character_,
                  timestamp = as.POSIXct(obj$timestamp, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"),
                  model = obj$message$model %||% "unknown",
                  input_tokens = as.integer(obj$message$usage$input_tokens %||% 0L),
                  output_tokens = as.integer(obj$message$usage$output_tokens %||% 0L),
                  cache_creation = as.integer(obj$message$usage$cache_creation_input_tokens %||% 0L),
                  cache_read = as.integer(obj$message$usage$cache_read_input_tokens %||% 0L)
                )
              } else {
                NULL
              }
            }, error = function(e) NULL)
          })

          dplyr::bind_rows(parsed) |>
            # Deduplicate by message_id (streaming can create duplicate entries)
            dplyr::distinct(message_id, .keep_all = TRUE)
        }, error = function(e) NULL)
      })

      dplyr::bind_rows(usage_list) |>
        dplyr::filter(!is.na(timestamp)) |>
        # Final deduplication across all sessions by message_id
        dplyr::distinct(message_id, .keep_all = TRUE) |>
        dplyr::arrange(timestamp)
    }
  ),

  # Daily aggregated usage
  targets::tar_target(
    telemetry_llm_daily,
    {
      if (nrow(telemetry_llm_sessions) == 0) {
        return(tibble::tibble(
          date = as.Date(character()),
          model = character(),
          n_requests = integer(),
          total_input = integer(),
          total_output = integer(),
          total_cache_creation = integer(),
          total_cache_read = integer(),
          total_tokens = integer(),
          estimated_cost_usd = numeric()
        ))
      }

      telemetry_llm_sessions |>
        dplyr::mutate(date = as.Date(timestamp)) |>
        dplyr::group_by(date, model) |>
        dplyr::summarise(
          n_requests = dplyr::n(),
          total_input = sum(input_tokens, na.rm = TRUE),
          total_output = sum(output_tokens, na.rm = TRUE),
          total_cache_creation = sum(cache_creation, na.rm = TRUE),
          total_cache_read = sum(cache_read, na.rm = TRUE),
          total_tokens = sum(input_tokens + output_tokens + cache_creation + cache_read, na.rm = TRUE),
          # Estimate cost (approximate rates as of 2025)
          # Opus: ~$15/M input, ~$75/M output, cache creation ~$18.75/M, cache read ~$1.875/M
          # Sonnet: ~$3/M input, ~$15/M output, cache creation ~$3.75/M, cache read ~$0.375/M
          estimated_cost_usd = dplyr::case_when(
            grepl("opus", model, ignore.case = TRUE) ~
              (total_input * 15 + total_output * 75 + total_cache_creation * 18.75 + total_cache_read * 1.875) / 1e6,
            grepl("sonnet", model, ignore.case = TRUE) ~
              (total_input * 3 + total_output * 15 + total_cache_creation * 3.75 + total_cache_read * 0.375) / 1e6,
            TRUE ~ (total_input * 3 + total_output * 15) / 1e6  # Default to sonnet rates
          ),
          .groups = "drop"
        ) |>
        dplyr::arrange(date, model) |>
        dplyr::distinct()  # Remove duplicate rows from summarise
    }
  ),

  # LLM usage summary statistics
  targets::tar_target(
    telemetry_llm_summary,
    {
      if (nrow(telemetry_llm_daily) == 0) {
        return(tibble::tibble(
          metric = character(),
          value = character()
        ))
      }

      total_cost <- sum(telemetry_llm_daily$estimated_cost_usd, na.rm = TRUE)
      total_tokens <- sum(telemetry_llm_daily$total_tokens, na.rm = TRUE)
      total_requests <- sum(telemetry_llm_daily$n_requests, na.rm = TRUE)
      days_active <- dplyr::n_distinct(telemetry_llm_daily$date)
      date_range <- range(telemetry_llm_daily$date, na.rm = TRUE)

      tibble::tibble(
        metric = c("Total Cost (USD)", "Total Tokens", "Total Requests",
                   "Days Active", "Avg Cost/Day", "Avg Tokens/Day", "Date Range"),
        value = c(
          sprintf("$%.2f", total_cost),
          format(total_tokens, big.mark = ","),
          format(total_requests, big.mark = ","),
          as.character(days_active),
          sprintf("$%.2f", total_cost / max(days_active, 1)),
          format(round(total_tokens / max(days_active, 1)), big.mark = ","),
          paste(date_range, collapse = " to ")
        )
      )
    }
  ),

  # Cost by model breakdown
  targets::tar_target(
    telemetry_llm_by_model,
    {
      if (nrow(telemetry_llm_daily) == 0) {
        return(tibble::tibble(
          model = character(),
          total_cost = numeric(),
          total_tokens = integer(),
          n_requests = integer(),
          pct_cost = numeric()
        ))
      }

      total <- sum(telemetry_llm_daily$estimated_cost_usd, na.rm = TRUE)

      telemetry_llm_daily |>
        dplyr::group_by(model) |>
        dplyr::summarise(
          total_cost = sum(estimated_cost_usd, na.rm = TRUE),
          total_tokens = sum(total_tokens, na.rm = TRUE),
          n_requests = sum(n_requests, na.rm = TRUE),
          .groups = "drop"
        ) |>
        dplyr::mutate(
          pct_cost = round(100 * total_cost / total, 1),
          model_clean = gsub("claude-", "", model)
        ) |>
        dplyr::arrange(dplyr::desc(total_cost))
    }
  ),

  # Plot: Daily cost trend
  targets::tar_target(
    plot_telemetry_llm_cost_trend,
    {
      data <- telemetry_llm_daily
      if (nrow(data) == 0) return(NULL)

      data |>
        dplyr::group_by(date) |>
        dplyr::summarise(daily_cost = sum(estimated_cost_usd, na.rm = TRUE), .groups = "drop") |>
        ggplot2::ggplot(ggplot2::aes(x = date, y = daily_cost)) +
        ggplot2::geom_col(fill = "steelblue", alpha = 0.7) +
        ggplot2::geom_smooth(method = "loess", se = FALSE, color = "darkred") +
        ggplot2::scale_y_continuous(labels = scales::dollar_format()) +
        ggplot2::labs(
          title = "Daily LLM Costs (irishbuoys project)",
          subtitle = "Estimated cost based on Claude API pricing",
          x = "Date",
          y = "Cost (USD)"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Plot: Token usage by type
  targets::tar_target(
    plot_telemetry_llm_tokens,
    {
      data <- telemetry_llm_daily
      if (nrow(data) == 0) return(NULL)

      token_data <- data |>
        dplyr::group_by(date) |>
        dplyr::summarise(
          Input = sum(total_input, na.rm = TRUE),
          Output = sum(total_output, na.rm = TRUE),
          `Cache Create` = sum(total_cache_creation, na.rm = TRUE),
          `Cache Read` = sum(total_cache_read, na.rm = TRUE),
          .groups = "drop"
        ) |>
        tidyr::pivot_longer(-date, names_to = "type", values_to = "tokens")

      token_data |>
        ggplot2::ggplot(ggplot2::aes(x = date, y = tokens / 1e6, fill = type)) +
        ggplot2::geom_col() +
        ggplot2::scale_fill_manual(values = c(
          "Input" = "#3498db",
          "Output" = "#e74c3c",
          "Cache Create" = "#f39c12",
          "Cache Read" = "#2ecc71"
        )) +
        ggplot2::labs(
          title = "Token Usage by Type",
          subtitle = "Daily breakdown of input, output, and cache tokens",
          x = "Date",
          y = "Tokens (millions)",
          fill = "Type"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Plot: Cost by model
  targets::tar_target(
    plot_telemetry_llm_by_model,
    {
      data <- telemetry_llm_by_model
      if (nrow(data) == 0) return(NULL)

      data |>
        ggplot2::ggplot(ggplot2::aes(x = reorder(model_clean, total_cost), y = total_cost)) +
        ggplot2::geom_col(fill = "steelblue") +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::dollar_format()) +
        ggplot2::labs(
          title = "Cost by Model",
          subtitle = "Total estimated cost per Claude model",
          x = NULL,
          y = "Cost (USD)"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # Formatted tables
  targets::tar_target(
    table_telemetry_llm_summary,
    create_telemetry_dt(
      telemetry_llm_summary,
      caption = "LLM Usage Summary — total tokens (input/output/cache), estimated cost (USD), and session count. Source: Claude Code JSONL logs."
    )
  ),

  targets::tar_target(
    table_telemetry_llm_daily,
    create_telemetry_dt(
      telemetry_llm_daily |>
        dplyr::mutate(
          estimated_cost_usd = round(estimated_cost_usd, 4),
          model = gsub("claude-", "", model)
        ),
      caption = "Daily LLM Usage — tokens and estimated cost (USD) per day by model. Cache tokens reduce costs via prompt caching."
    )
  ),

  targets::tar_target(
    table_telemetry_llm_by_model,
    create_telemetry_dt(
      telemetry_llm_by_model |>
        dplyr::select(-model) |>
        dplyr::rename(model = model_clean) |>
        dplyr::mutate(total_cost = round(total_cost, 2)),
      caption = "Usage by Claude Model — sessions, total tokens, and cost (USD) per model variant (opus, sonnet, haiku)."
    )
  ),

  # ==========================================================================
  # TEST STATISTICS
  # ==========================================================================

  # Collect test statistics from testthat files
  targets::tar_target(
    telemetry_test_stats,
    {
      test_dir <- "tests/testthat"
      if (!dir.exists(test_dir)) {
        return(tibble::tibble(
          file = character(),
          test_type = character(),
          n_tests = integer(),
          n_expectations = integer()
        ))
      }

      test_files <- list.files(test_dir, pattern = "^test-.*\\.R$", full.names = TRUE)

      # Parse test files to count tests and categorize
      stats <- lapply(test_files, function(f) {
        content <- readLines(f, warn = FALSE)
        file_name <- basename(f)

        # Count test_that() blocks
        n_tests <- sum(grepl("^\\s*test_that\\s*\\(", content))

        # Count expectations
        n_expectations <- sum(grepl("expect_", content))

        # Count snapshot tests
        n_snapshots <- sum(grepl("expect_snapshot", content))

        # Count adversarial/null guard tests
        n_adversarial <- sum(grepl("adversarial|null|NULL|invalid", content, ignore.case = TRUE))

        # Categorize the test file
        test_type <- dplyr::case_when(
          grepl("adversarial", file_name, ignore.case = TRUE) ~ "Adversarial/Edge Cases",
          grepl("snapshot", file_name, ignore.case = TRUE) ~ "Snapshot Tests",
          grepl("integration", file_name, ignore.case = TRUE) ~ "Integration Tests",
          n_snapshots > 0 ~ "Contains Snapshots",
          n_adversarial > n_tests / 2 ~ "Defensive/Null Guards",
          TRUE ~ "Unit Tests"
        )

        tibble::tibble(
          file = file_name,
          test_type = test_type,
          n_tests = n_tests,
          n_expectations = n_expectations,
          n_snapshots = n_snapshots
        )
      })

      dplyr::bind_rows(stats) |>
        dplyr::arrange(test_type, file)
    }
  ),

  # Summary by test type
  targets::tar_target(
    telemetry_test_summary,
    {
      telemetry_test_stats |>
        dplyr::group_by(test_type) |>
        dplyr::summarise(
          n_files = dplyr::n(),
          total_tests = sum(n_tests, na.rm = TRUE),
          total_expectations = sum(n_expectations, na.rm = TRUE),
          total_snapshots = sum(n_snapshots, na.rm = TRUE),
          .groups = "drop"
        ) |>
        dplyr::bind_rows(
          tibble::tibble(
            test_type = "TOTAL",
            n_files = sum(telemetry_test_stats$n_tests > 0, na.rm = TRUE),
            total_tests = sum(telemetry_test_stats$n_tests, na.rm = TRUE),
            total_expectations = sum(telemetry_test_stats$n_expectations, na.rm = TRUE),
            total_snapshots = sum(telemetry_test_stats$n_snapshots, na.rm = TRUE)
          )
        )
    }
  ),

  # Formatted table for display
  targets::tar_target(
    table_telemetry_test_stats,
    create_telemetry_dt(
      telemetry_test_stats,
      caption = "Test Files by Type — file name, category (unit/adversarial/integration), test count, and expectation count per file."
    )
  ),

  targets::tar_target(
    table_telemetry_test_summary,
    {
      data <- telemetry_test_summary
      DT::datatable(
        data,
        caption = htmltools::tags$caption(
          style = "caption-side: top; font-size: 0.9em; color: white;",
          "Test Summary by Category \u2014 files, tests, expectations, and snapshot counts aggregated by test type. TOTAL row highlighted."
        ),
        extensions = "Buttons",
        options = list(
          dom = "Bfrtip",
          buttons = c("csv", "excel", "print"),
          pageLength = 15,
          scrollX = TRUE
        ),
        rownames = FALSE,
        class = "display compact"
      ) |>
        DT::formatStyle(
          "test_type",
          target = "row",
          backgroundColor = DT::styleEqual("TOTAL", "#e8f4f8")
        )
    }
  ),

  # ==========================================================================
  # COMMIT VELOCITY (weekly, full history)
  # ==========================================================================

  targets::tar_target(
    telemetry_commit_velocity,
    {
      commits <- tryCatch(
        gert::git_log(max = 2000),
        error = function(e) NULL
      )
      if (is.null(commits) || nrow(commits) == 0) {
        return(tibble::tibble(
          week = as.Date(character()),
          n_commits = integer()
        ))
      }
      commits |>
        dplyr::mutate(week = lubridate::floor_date(as.Date(time), "week")) |>
        dplyr::count(week, name = "n_commits") |>
        dplyr::arrange(week)
    }
  ),

  targets::tar_target(
    table_telemetry_commit_velocity,
    {
      data <- telemetry_commit_velocity
      if (nrow(data) == 0) return(htmltools::p("No commit data available"))
      data |>
        dplyr::mutate(
          week_label = format(week, "%Y-W%V"),
          cumulative = cumsum(n_commits)
        ) |>
        create_telemetry_dt(
          caption = htmltools::tags$caption(
            style = "caption-side: top; font-size: 0.9em; color: white;",
            "Weekly commit counts. ",
            "Columns: week start date, ISO week label, commit count, cumulative total. ",
            "Key: Shows development velocity over full project history. ",
            "Source: gert::git_log()."
          )
        )
    }
  ),

  # Plot: Commit velocity timeline
  targets::tar_target(
    plot_telemetry_commit_velocity,
    {
      data <- telemetry_commit_velocity
      if (nrow(data) == 0) return(NULL)
      data |>
        ggplot2::ggplot(ggplot2::aes(x = week, y = n_commits)) +
        ggplot2::geom_col(fill = "#3498db", alpha = 0.7) +
        ggplot2::geom_smooth(method = "loess", se = FALSE, color = "#e74c3c",
                             span = 0.3, linewidth = 0.8) +
        ggplot2::labs(
          title = "Weekly Commit Velocity",
          subtitle = "Full project history with LOESS trend",
          caption = paste(
            "Commits per week from gert::git_log(max = 2000).",
            "Red line: LOESS smoother showing development intensity trend.",
            "Source: local git repository."
          ),
          x = "Week", y = "Commits"
        ) +
        ggplot2::theme_minimal()
    }
  ),

  # ==========================================================================
  # GITHUB ACTIVITY (issues, PRs, workflows)
  # ==========================================================================

  targets::tar_target(
    telemetry_github_activity,
    {
      tryCatch({
        owner <- "JohnGavin"
        repo <- "irishbuoys"

        open_issues <- gh::gh(
          "GET /repos/{owner}/{repo}/issues",
          owner = owner, repo = repo,
          state = "open", per_page = 1,
          .accept = "application/vnd.github.v3+json"
        )
        closed_issues <- gh::gh(
          "GET /repos/{owner}/{repo}/issues",
          owner = owner, repo = repo,
          state = "closed", per_page = 1,
          .accept = "application/vnd.github.v3+json"
        )
        open_prs <- gh::gh(
          "GET /repos/{owner}/{repo}/pulls",
          owner = owner, repo = repo,
          state = "open", per_page = 1,
          .accept = "application/vnd.github.v3+json"
        )
        closed_prs <- gh::gh(
          "GET /repos/{owner}/{repo}/pulls",
          owner = owner, repo = repo,
          state = "closed", per_page = 1,
          .accept = "application/vnd.github.v3+json"
        )

        # Get workflow runs (last 5)
        runs <- gh::gh(
          "GET /repos/{owner}/{repo}/actions/runs",
          owner = owner, repo = repo,
          per_page = 5,
          .accept = "application/vnd.github.v3+json"
        )
        workflow_runs <- if (length(runs$workflow_runs) > 0) {
          lapply(runs$workflow_runs, function(r) {
            tibble::tibble(
              name = r$name %||% "unknown",
              status = r$conclusion %||% r$status %||% "unknown",
              created = r$created_at %||% NA_character_
            )
          }) |> dplyr::bind_rows()
        } else {
          tibble::tibble(name = character(), status = character(), created = character())
        }

        list(
          issues_open = length(open_issues),
          issues_closed = length(closed_issues),
          prs_open = length(open_prs),
          prs_closed = length(closed_prs),
          recent_workflows = workflow_runs,
          fetched_at = Sys.time()
        )
      }, error = function(e) {
        list(
          issues_open = NA_integer_,
          issues_closed = NA_integer_,
          prs_open = NA_integer_,
          prs_closed = NA_integer_,
          recent_workflows = tibble::tibble(
            name = character(), status = character(), created = character()
          ),
          fetched_at = Sys.time(),
          error = conditionMessage(e)
        )
      })
    }
  ),

  targets::tar_target(
    table_telemetry_github_activity,
    {
      ga <- telemetry_github_activity
      if (!is.null(ga$error)) {
        return(htmltools::p(paste("GitHub API error:", ga$error)))
      }

      summary_df <- tibble::tibble(
        Metric = c("Open Issues", "Closed Issues", "Open PRs", "Closed PRs"),
        Count = c(ga$issues_open, ga$issues_closed, ga$prs_open, ga$prs_closed)
      )

      create_telemetry_dt(
        summary_df,
        caption = htmltools::tags$caption(
          style = "caption-side: top; font-size: 0.9em; color: white;",
          "GitHub issues and pull requests summary. ",
          "Source: GitHub API via gh::gh(). ",
          "Fetched: ", format(ga$fetched_at, "%Y-%m-%d %H:%M UTC"), "."
        )
      )
    }
  ),

  # ==========================================================================
  # CODEBASE METRICS
  # ==========================================================================

  targets::tar_target(
    telemetry_codebase_metrics,
    {
      r_files <- list.files("R", pattern = "\\.R$", recursive = TRUE)
      r_files_no_dev <- r_files[!grepl("^dev/", r_files)]
      test_files <- list.files("tests/testthat", pattern = "^test-.*\\.R$")

      # Count lines of R code (excluding blank/comment)
      loc <- tryCatch({
        all_r <- list.files("R", pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
        all_r <- all_r[!grepl("R/dev/", all_r)]
        lines <- unlist(lapply(all_r, readLines, warn = FALSE))
        sum(!grepl("^\\s*$|^\\s*#", lines))
      }, error = function(e) NA_integer_)

      # Count exported functions from NAMESPACE
      exports <- tryCatch({
        ns <- readLines("NAMESPACE", warn = FALSE)
        sum(grepl("^export\\(", ns))
      }, error = function(e) NA_integer_)

      # Package version
      version <- tryCatch({
        desc <- read.dcf("DESCRIPTION", fields = "Version")
        as.character(desc[1, 1])
      }, error = function(e) NA_character_)

      tibble::tibble(
        Metric = c("R Source Files", "Test Files", "Lines of Code (R)",
                    "Exported Functions", "Package Version"),
        Value = c(
          as.character(length(r_files_no_dev)),
          as.character(length(test_files)),
          format(loc, big.mark = ","),
          as.character(exports),
          version
        )
      )
    }
  ),

  targets::tar_target(
    table_telemetry_codebase_metrics,
    create_telemetry_dt(
      telemetry_codebase_metrics,
      caption = htmltools::tags$caption(
        style = "caption-side: top; font-size: 0.9em; color: white;",
        "Codebase size and structure metrics. ",
        "LOC excludes blank lines and comments. ",
        "Exports counted from NAMESPACE file. ",
        "Source: local filesystem."
      )
    )
  ),

  # ==========================================================================
  # TOP TARGETS BY SIZE AND TIME
  # ==========================================================================

  targets::tar_target(
    table_telemetry_top_size,
    {
      data <- telemetry_target_metrics$by_target
      if (is.null(data) || nrow(data) == 0) {
        return(htmltools::p("No target metrics available"))
      }
      top <- data |>
        dplyr::filter(!is.na(bytes)) |>
        dplyr::arrange(dplyr::desc(bytes)) |>
        utils::head(5) |>
        dplyr::mutate(
          size_mb = round(bytes / 1024^2, 2),
          size_label = dplyr::case_when(
            bytes >= 1024^2 ~ paste0(round(bytes / 1024^2, 1), " MB"),
            bytes >= 1024 ~ paste0(round(bytes / 1024, 1), " KB"),
            TRUE ~ paste0(bytes, " B")
          )
        ) |>
        dplyr::select(plan, target, size_label, size_mb)

      create_telemetry_dt(
        top,
        caption = htmltools::tags$caption(
          style = "caption-side: top; font-size: 0.9em; color: white;",
          "Top 5 targets by stored object size. ",
          "Columns: plan source, target name, human-readable size, size in MB. ",
          "Key: Largest targets dominate _targets/ storage. ",
          "Source: targets::tar_meta()."
        )
      )
    }
  ),

  targets::tar_target(
    table_telemetry_top_time,
    {
      data <- telemetry_target_metrics$by_target
      if (is.null(data) || nrow(data) == 0) {
        return(htmltools::p("No target metrics available"))
      }
      top <- data |>
        dplyr::filter(!is.na(seconds)) |>
        dplyr::arrange(dplyr::desc(seconds)) |>
        utils::head(5) |>
        dplyr::mutate(
          time_label = dplyr::case_when(
            seconds >= 60 ~ paste0(round(seconds / 60, 1), " min"),
            TRUE ~ paste0(round(seconds, 1), " sec")
          )
        ) |>
        dplyr::select(plan, target, time_label, seconds)

      create_telemetry_dt(
        top,
        caption = htmltools::tags$caption(
          style = "caption-side: top; font-size: 0.9em; color: white;",
          "Top 5 targets by computation time. ",
          "Columns: plan source, target name, human-readable duration, seconds. ",
          "Key: Slowest targets are optimization candidates. ",
          "Source: targets::tar_meta()."
        )
      )
    }
  ),

  # ==========================================================================
  # CI WORKFLOW RUNTIMES
  # ==========================================================================

  targets::tar_target(
    table_telemetry_ci_workflows,
    {
      wf <- telemetry_github_activity$recent_workflows
      if (is.null(wf) || nrow(wf) == 0) {
        return(htmltools::p("No CI workflow data available"))
      }
      create_telemetry_dt(
        wf,
        caption = htmltools::tags$caption(
          style = "caption-side: top; font-size: 0.9em; color: white;",
          "Recent CI workflow runs (last 5). ",
          "Columns: workflow name, conclusion/status, created timestamp. ",
          "Source: GitHub Actions API."
        ),
        pageLength = 5
      )
    }
  )
)

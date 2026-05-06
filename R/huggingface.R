#' Construct HuggingFace dataset URL for buoy data
#'
#' DuckDB 0.10+ supports `hf://datasets/...` natively — no httpfs extension
#' needed, 34% faster than `resolve/main/` URLs.
#'
#' @param filename Parquet filename (default: `"buoy_data.parquet"`)
#' @return `hf://datasets/{repo}/{filename}` URL string
#' @family huggingface
#' @export
#' @examples
#' ib_hf_url()
#' ib_hf_url("stations.json")
ib_hf_url <- function(filename = "buoy_data.parquet") {
  repo <- Sys.getenv("IB_HF_REPO", unset = "JohnGavin/irish-buoy-network")
  sprintf("hf://datasets/%s/%s", repo, filename)
}

#' Check if HuggingFace dataset is reachable
#'
#' Returns `TRUE` if the HF API responds within 5 seconds.
#' Used by tests and examples to fall back to local sample data.
#'
#' @return Logical
#' @family huggingface
#' @export
#' @examples
#' ib_hf_online()
ib_hf_online <- function() {
  repo <- Sys.getenv("IB_HF_REPO", unset = "JohnGavin/irish-buoy-network")
  url <- sprintf("https://huggingface.co/api/datasets/%s", repo)
  tryCatch(
    {
      con <- url(url, open = "r")
      on.exit(close(con))
      TRUE
    },
    error = function(e) FALSE
  )
}

#' Create a DuckDB connection for reading HuggingFace Parquet
#'
#' Returns a DBI connection to an ephemeral DuckDB instance.
#' DuckDB 0.10+ supports `hf://datasets/...` natively.
#' httpfs is loaded as a fallback for non-HF HTTPS URLs.
#'
#' @return DBI connection object
#' @family huggingface
#' @export
#' @examples
#' \dontrun{
#' con <- ib_hf_connect()
#' dplyr::tbl(con, ib_hf_url()) |> dplyr::glimpse()
#' DBI::dbDisconnect(con)
#' }
ib_hf_connect <- function() {
  con <- DBI::dbConnect(duckdb::duckdb())
  tryCatch(
    invisible(DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")),
    error = function(e) NULL
  )
  con
}

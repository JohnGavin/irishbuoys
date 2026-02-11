

# irishbuoys

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

The `irishbuoys` package provides tools to download, process, and
analyze data from the Irish Weather Buoy Network. It includes functions
for accessing real-time and historical data via the Marine Institute’s
ERDDAP server, storing data in DuckDB for efficient querying, and
building predictive models for wave height and weather conditions.

## Installation

### Standard R Installation

You can install the development version of irishbuoys from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("johngavin/irishbuoys")
```

### Nix Environment Installation (Recommended)

For a reproducible development environment using Nix:

``` bash
# Clone the repository
git clone https://github.com/johngavin/irishbuoys.git
cd irishbuoys

# Generate Nix configuration from DESCRIPTION
Rscript default.R

# Enter Nix shell (first time may take a while)
./default.sh

# Subsequent entries are fast (seconds)
./default.sh
```

### Pure Mode Enforcement (Security & Reproducibility)

This project enforces Nix `--pure` mode to guarantee:

- **Reproducibility**: Only Nix-provided tools are available
- **Security**: No accidental use of system tools with different
  versions
- **Consistency**: Same environment locally and in CI

**Entering the environment:**

``` bash
# Recommended: Use default.sh (pure mode enforced automatically)
./default.sh
# Output shows: 🔒 SECURITY: Running in --pure mode

# Or manually with pure flag:
nix-shell --pure default.nix
```

**Verifying pure mode:**

``` bash
# Check IN_NIX_SHELL (should be "pure", not "impure")
echo $IN_NIX_SHELL
# Expected: pure

# Check tools are from Nix store
which R
# Expected: /nix/store/...

which git
# Expected: /nix/store/...

# Verify R version
R --version
```

**Passing additional environment variables:**

``` bash
# If you need to pass secrets/tokens through pure mode:
nix-shell --pure --keep GITHUB_TOKEN --keep MY_API_KEY default.nix
```

### Using with rix

To integrate this package into your own Nix environment:

``` r
library(rix)

rix(
  r_ver = "4.5.0",
  r_pkgs = c("duckdb", "DBI", "httr2", "dplyr"),
  git_pkgs = list(
    list(
      package_name = "irishbuoys",
      repo_url = "https://github.com/johngavin/irishbuoys",
      commit = "main"  # Use specific SHA for reproducibility
    )
  ),
  ide = "other",
  project_path = "."
)
```

### Cachix Binary Cache (Faster Builds)

<div class="panel-tabset">

#### For Other Machines

Use the pre-built R packages from `rstats-on-nix` Cachix cache for much
faster builds:

``` bash
# Install cachix (one-time setup)
nix-shell -p cachix --run "cachix use rstats-on-nix"

# Now nix-shell will download pre-built packages instead of compiling
cd irishbuoys
./default.sh  # Much faster with cache!
```

#### Two-Tier Caching Strategy

This project uses a two-tier Cachix strategy:

| Priority | Cache           | Contains                                    |
|----------|-----------------|---------------------------------------------|
| 1st      | `rstats-on-nix` | All standard R packages (public, pre-built) |
| 2nd      | `johngavin`     | Project-specific custom packages only       |

**Important**: Standard R packages (dplyr, targets, etc.) are ALL
available from `rstats-on-nix`. The `johngavin` cache is only for custom
packages not in rstats-on-nix.

For irishbuoys: - All dependencies come from `rstats-on-nix` - The
irishbuoys package itself is loaded via `pkgload::load_all()`
(development mode) - Nothing needs to be pushed to `johngavin` cache

#### GitHub Actions CI

CI workflows automatically use both caches:

``` yaml
# In .github/workflows/r-cmd-check.yaml
- uses: cachix/cachix-action@v15
  with:
    name: rstats-on-nix  # Public cache FIRST

- uses: cachix/cachix-action@v15
  with:
    name: johngavin      # Project cache SECOND
    authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
    skipPush: true       # Don't push during checks
```

</div>

## Quick Start

### Download Recent Data

``` r
library(irishbuoys)

# Download last 7 days of data
str(data <- download_buoy_data(
  start_date = Sys.Date() - 7,
  end_date = Sys.Date()
))

# Get data for specific station
dim(m3_data <- download_buoy_data(
  stations = "M3",
  start_date = "2024-01-01"
))

# Get earliest available data (buoy network started 2001-02-05)
str(waves <- download_buoy_data(
  start_date = "2001-02-05",
  end_date = "2001-02-06"
))
```

### Initialize and Query Database

``` r
# Initialize database with historical data (chunk_days=365 for faster downloads)
initialize_database(
  start_date = "2024-01-01",  # Default: recent data for quick start
  end_date = Sys.Date(),
  chunk_days = 365  # Download in 1-year chunks for efficiency
)

# Check database statistics immediately after initialization
stats <- get_database_stats()

# Connect to database
con <- connect_duckdb()

# Check QC flag distribution by station FIRST
# qc_flag: 0=unknown, 1=good, 9=missing
qc_tally <- tbl(con, "buoy_data") |>
  group_by(station_id, qc_flag) |>
  summarise(n = n(), .groups = "drop") |>
  collect() |>
  tidyr::pivot_wider(names_from = qc_flag, values_from = n, names_prefix = "qc_")
print(qc_tally)

# Query wave data (qc_filter=FALSE returns all data; TRUE filters for qc_flag==1)
wave_data <- query_buoy_data(
  con,
  stations = c("M3", "M4"),
  variables = c("time", "station_id", "wave_height", "wave_period"),
  start_date = "2024-01-01",
  qc_filter = FALSE  # Set TRUE to filter for qc_flag==1 only
)

# Custom SQL query: Find top 10 most extreme rogue waves
# Ordered by hmax (highest individual wave) because "extreme" = largest waves
extreme_waves <- query_buoy_data(
  con,
  sql_query = "
    SELECT station_id, time, wave_height, hmax
    FROM buoy_data
    WHERE hmax > 2 * wave_height
      AND wave_height > 0
      AND qc_flag = 1
    ORDER BY hmax DESC
    LIMIT 10
  "
)
```

### Tidyverse Alternative (duckplyr)

The same query using `dplyr` verbs with `duckplyr` backend:

``` r
# Tidyverse alternative using duckplyr
# Same query as SQL above, ordered by hmax (highest waves first)
library(dplyr)
library(duckplyr)

extreme_waves_tidy <- tbl(con, "buoy_data") |>
  filter(
    hmax > 2 * wave_height,
    wave_height > 0,
    qc_flag == 1
  ) |>
  select(station_id, time, wave_height, hmax) |>
  arrange(desc(hmax)) |>
  head(10) |>
  collect()
```

**Why duckplyr?** - Familiar tidyverse syntax - Lazy evaluation - query
runs only on `collect()` - Automatic SQL translation for performance -
Works with any DBI connection

``` r
# Don't forget to disconnect
DBI::dbDisconnect(con)
```

### Incremental Updates

``` r
# Perform incremental update (for scheduled jobs)
result <- incremental_update()
print(result$summary)
```

### Data Dictionary

``` r
# Get complete data dictionary (returns tibble)
dict <- get_data_dictionary()
print(dict)

# Get detailed documentation for specific variable
(wave_docs <- get_variable_docs("WaveHeight"))

# Merge dictionary with database column info
# Useful for creating documentation or understanding data
library(dplyr)
db_cols <- tibble(
  variable = c("wave_height", "hmax", "wind_speed", "gust"),
  db_column = c("wave_height", "hmax", "wind_speed", "gust")
)
dict |>
  filter(tolower(variable) %in% db_cols$variable |
         variable %in% c("WaveHeight", "Hmax", "WindSpeed", "Gust")) |>
  select(variable, units, description)
```

## Data Source

Data is sourced from the [Marine Institute’s ERDDAP
server](https://erddap.marine.ie/erddap/tabledap/IWBNetwork.html), which
provides real-time and historical measurements from the Irish Weather
Buoy Network.

### Available Stations

- **M2**: Southwest of Ireland
- **M3**: Southwest of Ireland
- **M4**: Southeast of Ireland
- **M5**: West of Ireland
- **M6**: Northwest of Ireland
- **M1**: Historical data (decommissioned)
- **FS1**: Historical data

### Measured Parameters

- **Meteorological**: Air temperature, pressure, humidity, wind
  speed/direction
- **Oceanographic**: Wave height/period/direction, sea temperature,
  salinity
- **Quality**: QC flags for data validation

## Project Structure

    .
    ├── DESCRIPTION
    ├── LICENSE
    ├── LICENSE.md
    ├── NAMESPACE
    ├── R
    │   ├── data_dictionary.R
    │   ├── database.R
    │   ├── database_parquet.R
    │   ├── dev
    │   │   ├── check_data_gaps.R
    │   │   ├── generate_dashboard_data.R
    │   │   └── issues
    │   ├── email_summary.R
    │   ├── erddap_client.R
    │   ├── extreme_values.R
    │   ├── irishbuoys-package.R
    │   ├── plot_functions.R
    │   ├── plotly_helpers.R
    │   ├── rogue_waves.R
    │   ├── tar_plans
    │   │   ├── plan_dashboard.R
    │   │   ├── plan_dashboard_captions.R
    │   │   ├── plan_data_acquisition.R
    │   │   ├── plan_doc_examples.R
    │   │   ├── plan_quality_control.R
    │   │   └── plan_wave_analysis.R
    │   ├── trend_analysis.R
    │   ├── update.R
    │   ├── wave_model.R
    │   └── wave_science.R
    ├── README.md
    ├── README.qmd
    ├── README.rmarkdown
    ├── _extensions
    │   └── quarto-ext
    │       └── shinylive
    ├── _output
    │   ├── shinylive-sw.js
    │   └── vignettes
    │       ├── dashboard_shinylive.html
    │       ├── dashboard_shinylive_files
    │       └── data
    ├── _pkgdown.yml
    ├── _quarto.yml
    ├── _targets.R
    ├── data-raw
    ├── default.R
    ├── default.nix
    ├── default.sh
    ├── inst
    │   ├── docs
    │   │   └── parquet_storage_guide.md
    │   ├── extdata
    │   │   ├── analysis_questions.md
    │   │   ├── dashboard_buoy_data.rds
    │   │   ├── dashboard_stats.rds
    │   │   ├── dashboard_timeseries.rds
    │   │   ├── return_levels.rds
    │   │   ├── rogue_wave_events.rds
    │   │   ├── seasonal_analysis.rds
    │   │   └── wave_analysis_summary.rds
    │   └── scripts
    │       ├── example_usage.R
    │       └── storage_comparison.R
    ├── man
    │   ├── add_wave_metrics.Rd
    │   ├── analyze_gust_factor.Rd
    │   ├── analyze_parquet_storage.Rd
    │   ├── analyze_rogue_statistics.Rd
    │   ├── buoy_tbl.Rd
    │   ├── calculate_annual_trends.Rd
    │   ├── calculate_hs_from_elevation.Rd
    │   ├── calculate_return_levels.Rd
    │   ├── calculate_rms_wave_height.Rd
    │   ├── calculate_seasonal_means.Rd
    │   ├── calculate_wave_steepness.Rd
    │   ├── compare_rogue_wave_gust.Rd
    │   ├── connect_duckdb.Rd
    │   ├── convert_duckdb_to_parquet.Rd
    │   ├── create_buoy_schema.Rd
    │   ├── create_email_summary.Rd
    │   ├── create_plot_annual_trends.Rd
    │   ├── create_plot_gust_by_category.Rd
    │   ├── create_plot_gusts_vs_waves.Rd
    │   ├── create_plot_monthly_wave.Rd
    │   ├── create_plot_monthly_wind.Rd
    │   ├── create_plot_return_levels.Rd
    │   ├── create_plot_rogue_all.Rd
    │   ├── create_plot_rogue_by_station.Rd
    │   ├── create_plot_rogue_gusts.Rd
    │   ├── create_plot_rogue_gusts_all.Rd
    │   ├── create_plot_rogue_gusts_by_station.Rd
    │   ├── create_plot_stl.Rd
    │   ├── create_plot_time_of_day.Rd
    │   ├── create_plot_week_of_year.Rd
    │   ├── create_plot_wind_beaufort.Rd
    │   ├── create_return_level_plot_data.Rd
    │   ├── decompose_stl.Rd
    │   ├── detect_anomalies.Rd
    │   ├── detect_rogue_waves.Rd
    │   ├── download_buoy_data.Rd
    │   ├── evaluate_wave_model.Rd
    │   ├── explain_hourly_averaging.Rd
    │   ├── explain_hs_formula.Rd
    │   ├── explain_measurement_period.Rd
    │   ├── explain_wave_height_measurement.Rd
    │   ├── extreme_values.Rd
    │   ├── fit_gev_annual_maxima.Rd
    │   ├── fit_gpd_threshold.Rd
    │   ├── generate_and_send_summary.Rd
    │   ├── generate_weekly_summary.Rd
    │   ├── get_data_dictionary.Rd
    │   ├── get_database_stats.Rd
    │   ├── get_latest_timestamp.Rd
    │   ├── get_stations.Rd
    │   ├── get_variable_docs.Rd
    │   ├── hs_from_rms.Rd
    │   ├── incremental_update.Rd
    │   ├── incremental_update_parquet.Rd
    │   ├── init_parquet_storage.Rd
    │   ├── initialize_database.Rd
    │   ├── irishbuoys-package.Rd
    │   ├── irishbuoys_ggplotly.Rd
    │   ├── irishbuoys_layout.Rd
    │   ├── load_to_duckdb.Rd
    │   ├── log_update.Rd
    │   ├── plot_functions.Rd
    │   ├── predict_wave_height.Rd
    │   ├── prepare_wave_features.Rd
    │   ├── query_buoy_data.Rd
    │   ├── query_parquet.Rd
    │   ├── rogue_wave_report.Rd
    │   ├── save_to_parquet.Rd
    │   ├── train_wave_model.Rd
    │   ├── trend_analysis.Rd
    │   ├── trend_summary_report.Rd
    │   ├── update_station_metadata.Rd
    │   ├── wave_glossary.Rd
    │   ├── wave_model.Rd
    │   ├── wave_model_report.Rd
    │   ├── wave_science.Rd
    │   └── wave_science_documentation.Rd
    ├── nix-shell-root
    ├── pkgdown
    │   └── extra.css
    ├── push_to_cachix.sh
    ├── tests
    │   ├── testthat
    │   │   ├── _snaps
    │   │   └── test-data-consistency.R
    │   └── testthat.R
    └── vignettes
        ├── _targets.yaml
        ├── custom.scss
        ├── dashboard_shinylive.qmd
        ├── dashboard_shinylive_files
        │   └── mediabag
        ├── dashboard_static.qmd
        ├── data
        │   ├── buoy_data.json
        │   ├── buoy_data.parquet
        │   ├── buoy_data_raw.csv
        │   └── stations.json
        ├── shinylive-sw.js
        └── wave_analysis.qmd

*Note: `_targets/` (pipeline cache) and `docs/` (generated site)
excluded for clarity.*

## Key Features

1.  **Efficient Data Storage**: Uses DuckDB for fast querying of large
    datasets
2.  **Incremental Updates**: Smart updating to only download new data
3.  **Quality Control**: Built-in filtering for data quality
4.  **Rogue Wave Detection**: Identify extreme wave events (Hmax \> 2 ×
    Hs)
5.  **Comprehensive Documentation**: Full data dictionary with
    scientific definitions

## Use Cases

- Marine safety and operations planning
- Climate and oceanographic research
- Extreme event analysis
- Wave energy resource assessment
- Weather forecast validation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This package is licensed under the MIT License. See LICENSE file for
details.

## Acknowledgments

Data provided by the Marine Institute Ireland in collaboration with Met
Éireann and the UK Met Office.

## Sources

- [Marine Institute ERDDAP
  Server](https://erddap.marine.ie/erddap/tabledap/IWBNetwork.html)
- [Irish Weather Buoy Network on
  data.gov.ie](https://data.gov.ie/dataset/weather-buoy-network)

------------------------------------------------------------------------

    *Last updated: 2026-02-11 12:07 UTC *

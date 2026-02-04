

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
data <- download_buoy_data(
  start_date = Sys.Date() - 7,
  end_date = Sys.Date()
)

# Get data for specific station
m3_data <- download_buoy_data(
  stations = "M3",
  start_date = "2024-01-01"
)

# Get only wave measurements
waves <- download_buoy_data(
  variables = c("time", "station_id", "WaveHeight", "WavePeriod", "Hmax")
)
```

### Initialize and Query Database

``` r
# Initialize database with historical data
initialize_database(
  start_date = "2023-01-01",
  end_date = Sys.Date()
)

# Connect to database
con <- connect_duckdb()

# Query wave data
wave_data <- query_buoy_data(
  con,
  stations = c("M3", "M4"),
  variables = c("time", "station_id", "wave_height", "wave_period"),
  start_date = "2024-01-01",
  qc_filter = TRUE  # Only good quality data
)

# Custom SQL query
extreme_waves <- query_buoy_data(
  con,
  sql_query = "
    SELECT station_id, time, wave_height, hmax
    FROM buoy_data
    WHERE hmax > 2 * wave_height
      AND wave_height > 0
      AND qc_flag = 1
    ORDER BY time DESC
    LIMIT 100
  "
)

# Don't forget to disconnect
DBI::dbDisconnect(con)
```

### Incremental Updates

``` r
# Perform incremental update (for scheduled jobs)
result <- incremental_update()
print(result$summary)

# Check database statistics
stats <- get_database_stats()
```

### Data Dictionary

``` r
# Get complete data dictionary
dict <- get_data_dictionary()
View(dict)

# Get detailed documentation for specific variable
wave_docs <- get_variable_docs("WaveHeight")
print(wave_docs)
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
    │   │   ├── generate_dashboard_data.R
    │   │   └── issues
    │   ├── email_summary.R
    │   ├── erddap_client.R
    │   ├── extreme_values.R
    │   ├── irishbuoys-package.R
    │   ├── rogue_waves.R
    │   ├── tar_plans
    │   │   ├── plan_data_acquisition.R
    │   │   ├── plan_quality_control.R
    │   │   └── plan_wave_analysis.R
    │   ├── trend_analysis.R
    │   ├── update.R
    │   ├── wave_model.R
    │   └── wave_science.R
    ├── README.qmd
    ├── README.rmarkdown
    ├── _extensions
    │   └── quarto-ext
    │       └── shinylive
    │           ├── README.md
    │           ├── _extension.yml
    │           ├── resources
    │           │   └── css
    │           │       └── shinylive-quarto.css
    │           └── shinylive.lua
    ├── _output
    │   ├── shinylive-sw.js
    │   └── vignettes
    │       ├── dashboard_shinylive.html
    │       ├── dashboard_shinylive_files
    │       │   └── libs
    │       │       ├── bootstrap
    │       │       │   ├── bootstrap-d5fa03fb90ac27921a6d47853be462c0.min.css
    │       │       │   ├── bootstrap-icons.css
    │       │       │   ├── bootstrap-icons.woff
    │       │       │   └── bootstrap.min.js
    │       │       ├── clipboard
    │       │       │   └── clipboard.min.js
    │       │       ├── quarto-contrib
    │       │       │   ├── shinylive-0.9.1
    │       │       │   │   ├── shinylive
    │       │       │   │   │   ├── Editor.css
    │       │       │   │   │   ├── Editor.js
    │       │       │   │   │   ├── SourceSansPro-Regular.otf-PVQ5ZP77.woff2
    │       │       │   │   │   ├── browser-OYYBATHK.js
    │       │       │   │   │   ├── browser-YJT5PK6V.js
    │       │       │   │   │   ├── chunk-O5P2LFOG.js
    │       │       │   │   │   ├── chunk-PHWSSKUM.js
    │       │       │   │   │   ├── load-shinylive-sw.js
    │       │       │   │   │   ├── lzstring-worker.js
    │       │       │   │   │   ├── pyodide-worker.js
    │       │       │   │   │   ├── run-python-blocks.js
    │       │       │   │   │   ├── shinylive.css
    │       │       │   │   │   ├── shinylive.js
    │       │       │   │   │   ├── style-resets.css
    │       │       │   │   │   └── webr
    │       │       │   │   │       ├── R.bin.js
    │       │       │   │   │       ├── R.bin.js.bak
    │       │       │   │   │       ├── R.bin.wasm
    │       │       │   │   │       ├── esbuild.d.ts
    │       │       │   │   │       ├── libRblas.so
    │       │       │   │   │       ├── libRlapack.so
    │       │       │   │   │       ├── library.data.gz
    │       │       │   │   │       ├── library.js.metadata
    │       │       │   │   │       ├── packages
    │       │       │   │   │       │   ├── RColorBrewer
    │       │       │   │   │       │   │   └── RColorBrewer_1.1-3.tgz
    │       │       │   │   │       │   ├── S7
    │       │       │   │   │       │   │   └── S7_0.2.0.tgz
    │       │       │   │   │       │   ├── askpass
    │       │       │   │   │       │   │   └── askpass_1.2.1.tgz
    │       │       │   │   │       │   ├── crosstalk
    │       │       │   │   │       │   │   └── crosstalk_1.2.1.tgz
    │       │       │   │   │       │   ├── data.table
    │       │       │   │   │       │   │   └── data.table_1.17.0.tgz
    │       │       │   │   │       │   ├── dplyr
    │       │       │   │   │       │   │   └── dplyr_1.1.4.tgz
    │       │       │   │   │       │   ├── evaluate
    │       │       │   │   │       │   │   └── evaluate_1.0.3.tgz
    │       │       │   │   │       │   ├── farver
    │       │       │   │   │       │   │   └── farver_2.1.2.tgz
    │       │       │   │   │       │   ├── generics
    │       │       │   │   │       │   │   └── generics_0.1.3.tgz
    │       │       │   │   │       │   ├── ggplot2
    │       │       │   │   │       │   │   └── ggplot2_3.5.2.tgz
    │       │       │   │   │       │   ├── gtable
    │       │       │   │   │       │   │   └── gtable_0.3.6.tgz
    │       │       │   │   │       │   ├── highr
    │       │       │   │   │       │   │   └── highr_0.11.tgz
    │       │       │   │   │       │   ├── htmlwidgets
    │       │       │   │   │       │   │   └── htmlwidgets_1.6.4.tgz
    │       │       │   │   │       │   ├── httr
    │       │       │   │   │       │   │   └── httr_1.4.7.tgz
    │       │       │   │   │       │   ├── isoband
    │       │       │   │   │       │   │   └── isoband_0.2.7.tgz
    │       │       │   │   │       │   ├── knitr
    │       │       │   │   │       │   │   └── knitr_1.50.tgz
    │       │       │   │   │       │   ├── labeling
    │       │       │   │   │       │   │   └── labeling_0.4.3.tgz
    │       │       │   │   │       │   ├── lazyeval
    │       │       │   │   │       │   │   └── lazyeval_0.2.2.tgz
    │       │       │   │   │       │   ├── metadata.rds
    │       │       │   │   │       │   ├── openssl
    │       │       │   │   │       │   │   └── openssl_2.3.2.tgz
    │       │       │   │   │       │   ├── pillar
    │       │       │   │   │       │   │   └── pillar_1.10.2.tgz
    │       │       │   │   │       │   ├── pkgconfig
    │       │       │   │   │       │   │   └── pkgconfig_2.0.3.tgz
    │       │       │   │   │       │   ├── plotly
    │       │       │   │   │       │   │   └── plotly_4.10.4.tgz
    │       │       │   │   │       │   ├── purrr
    │       │       │   │   │       │   │   └── purrr_1.0.4.tgz
    │       │       │   │   │       │   ├── rmarkdown
    │       │       │   │   │       │   │   └── rmarkdown_2.29.tgz
    │       │       │   │   │       │   ├── scales
    │       │       │   │   │       │   │   └── scales_1.3.0.tgz
    │       │       │   │   │       │   ├── stringi
    │       │       │   │   │       │   │   └── stringi_1.8.7.tgz
    │       │       │   │   │       │   ├── stringr
    │       │       │   │   │       │   │   └── stringr_1.5.1.tgz
    │       │       │   │   │       │   ├── sys
    │       │       │   │   │       │   │   └── sys_3.4.3.tgz
    │       │       │   │   │       │   ├── tibble
    │       │       │   │   │       │   │   └── tibble_3.2.1.tgz
    │       │       │   │   │       │   ├── tidyr
    │       │       │   │   │       │   │   └── tidyr_1.3.1.tgz
    │       │       │   │   │       │   ├── tidyselect
    │       │       │   │   │       │   │   └── tidyselect_1.2.1.tgz
    │       │       │   │   │       │   ├── tinytex
    │       │       │   │   │       │   │   └── tinytex_0.57.tgz
    │       │       │   │   │       │   ├── utf8
    │       │       │   │   │       │   │   └── utf8_1.2.4.tgz
    │       │       │   │   │       │   ├── vctrs
    │       │       │   │   │       │   │   └── vctrs_0.6.5.tgz
    │       │       │   │   │       │   ├── viridisLite
    │       │       │   │   │       │   │   └── viridisLite_0.4.2.tgz
    │       │       │   │   │       │   ├── xfun
    │       │       │   │   │       │   │   └── xfun_0.52.tgz
    │       │       │   │   │       │   └── yaml
    │       │       │   │   │       │       └── yaml_2.3.10.tgz
    │       │       │   │   │       ├── repl
    │       │       │   │   │       │   ├── App.d.ts
    │       │       │   │   │       │   └── components
    │       │       │   │   │       │       ├── Editor.d.ts
    │       │       │   │   │       │       ├── Files.d.ts
    │       │       │   │   │       │       ├── Plot.d.ts
    │       │       │   │   │       │       ├── Terminal.d.ts
    │       │       │   │   │       │       └── utils.d.ts
    │       │       │   │   │       ├── tests
    │       │       │   │   │       │   ├── packages
    │       │       │   │   │       │   │   └── webr.test.d.ts
    │       │       │   │   │       │   └── webR
    │       │       │   │   │       │       ├── chan
    │       │       │   │   │       │       │   └── channel-postmessage.test.d.ts
    │       │       │   │   │       │       ├── console.test.d.ts
    │       │       │   │   │       │       ├── error.test.d.ts
    │       │       │   │   │       │       ├── mount.test.d.ts
    │       │       │   │   │       │       ├── proxy.test.d.ts
    │       │       │   │   │       │       ├── robj.test.d.ts
    │       │       │   │   │       │       ├── utils.test.d.ts
    │       │       │   │   │       │       ├── webr-main.test.d.ts
    │       │       │   │   │       │       ├── webr-r.test.d.ts
    │       │       │   │   │       │       └── webr-worker.test.d.ts
    │       │       │   │   │       ├── vfs
    │       │       │   │   │       │   ├── etc
    │       │       │   │   │       │   │   └── fonts
    │       │       │   │   │       │   │       └── fonts.conf
    │       │       │   │   │       │   ├── usr
    │       │       │   │   │       │   │   ├── lib
    │       │       │   │   │       │   │   │   └── R
    │       │       │   │   │       │   │   │       ├── doc.data.gz
    │       │       │   │   │       │   │   │       ├── doc.js.metadata
    │       │       │   │   │       │   │   │       ├── library
    │       │       │   │   │       │   │   │       │   ├── base
    │       │       │   │   │       │   │   │       │   │   ├── demo.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── demo.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   └── html.js.metadata
    │       │       │   │   │       │   │   │       │   ├── compiler
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── datasets
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   └── html.js.metadata
    │       │       │   │   │       │   │   │       │   ├── grDevices
    │       │       │   │   │       │   │   │       │   │   ├── afm.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── afm.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── demo.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── demo.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── enc.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── enc.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── fonts.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── fonts.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── libs.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── libs.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── graphics
    │       │       │   │   │       │   │   │       │   │   ├── demo.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── demo.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   └── html.js.metadata
    │       │       │   │   │       │   │   │       │   ├── grid
    │       │       │   │   │       │   │   │       │   │   ├── doc.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── doc.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── methods
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── parallel.data.gz
    │       │       │   │   │       │   │   │       │   ├── parallel.js.metadata
    │       │       │   │   │       │   │   │       │   ├── splines
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── stats
    │       │       │   │   │       │   │   │       │   │   ├── demo.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── demo.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── stats4
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── tcltk.data.gz
    │       │       │   │   │       │   │   │       │   ├── tcltk.js.metadata
    │       │       │   │   │       │   │   │       │   ├── tools
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   ├── translations
    │       │       │   │   │       │   │   │       │   │   └── DESCRIPTION
    │       │       │   │   │       │   │   │       │   ├── translations.data.gz
    │       │       │   │   │       │   │   │       │   ├── translations.js.metadata
    │       │       │   │   │       │   │   │       │   ├── utils
    │       │       │   │   │       │   │   │       │   │   ├── doc.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── doc.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── help.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── help.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── html.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── html.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── misc.data.gz
    │       │       │   │   │       │   │   │       │   │   ├── misc.js.metadata
    │       │       │   │   │       │   │   │       │   │   ├── tests.data.gz
    │       │       │   │   │       │   │   │       │   │   └── tests.js.metadata
    │       │       │   │   │       │   │   │       │   └── webr
    │       │       │   │   │       │   │   │       │       ├── help.data.gz
    │       │       │   │   │       │   │   │       │       ├── help.js.metadata
    │       │       │   │   │       │   │   │       │       ├── html.data.gz
    │       │       │   │   │       │   │   │       │       └── html.js.metadata
    │       │       │   │   │       │   │   │       ├── share.data.gz
    │       │       │   │   │       │   │   │       ├── share.js.metadata
    │       │       │   │   │       │   │   │       ├── tests.data.gz
    │       │       │   │   │       │   │   │       └── tests.js.metadata
    │       │       │   │   │       │   │   └── share
    │       │       │   │   │       │   │       ├── fonts
    │       │       │   │   │       │   │       │   ├── NotoSans-Bold.ttf
    │       │       │   │   │       │   │       │   ├── NotoSans-BoldItalic.ttf
    │       │       │   │   │       │   │       │   ├── NotoSans-Italic.ttf
    │       │       │   │   │       │   │       │   ├── NotoSans-Regular.ttf
    │       │       │   │   │       │   │       │   ├── NotoSansMono-Bold.ttf
    │       │       │   │   │       │   │       │   ├── NotoSansMono-Regular.ttf
    │       │       │   │   │       │   │       │   ├── NotoSerif-Bold.ttf
    │       │       │   │   │       │   │       │   ├── NotoSerif-BoldItalic.ttf
    │       │       │   │   │       │   │       │   ├── NotoSerif-Italic.ttf
    │       │       │   │   │       │   │       │   └── NotoSerif-Regular.ttf
    │       │       │   │   │       │   │       ├── gdal.data.gz
    │       │       │   │   │       │   │       ├── gdal.js.metadata
    │       │       │   │   │       │   │       ├── proj.data.gz
    │       │       │   │   │       │   │       ├── proj.js.metadata
    │       │       │   │   │       │   │       ├── udunits.data.gz
    │       │       │   │   │       │   │       └── udunits.js.metadata
    │       │       │   │   │       │   └── var
    │       │       │   │   │       │       └── cache
    │       │       │   │   │       │           └── fontconfig
    │       │       │   │   │       │               ├── 3830d5c3ddfd5cd38a049b759396e72e-le32d8.cache-7
    │       │       │   │   │       │               └── CACHEDIR.TAG
    │       │       │   │   │       ├── webR
    │       │       │   │   │       │   ├── chan
    │       │       │   │   │       │   │   ├── channel-common.d.ts
    │       │       │   │   │       │   │   ├── channel-postmessage.d.ts
    │       │       │   │   │       │   │   ├── channel-service.d.ts
    │       │       │   │   │       │   │   ├── channel-shared.d.ts
    │       │       │   │   │       │   │   ├── channel.d.ts
    │       │       │   │   │       │   │   ├── message.d.ts
    │       │       │   │   │       │   │   ├── queue.d.ts
    │       │       │   │   │       │   │   ├── serviceworker.d.ts
    │       │       │   │   │       │   │   ├── task-common.d.ts
    │       │       │   │   │       │   │   ├── task-main.d.ts
    │       │       │   │   │       │   │   └── task-worker.d.ts
    │       │       │   │   │       │   ├── compat.d.ts
    │       │       │   │   │       │   ├── config.d.ts
    │       │       │   │   │       │   ├── console.d.ts
    │       │       │   │   │       │   ├── emscripten.d.ts
    │       │       │   │   │       │   ├── error.d.ts
    │       │       │   │   │       │   ├── mount.d.ts
    │       │       │   │   │       │   ├── payload.d.ts
    │       │       │   │   │       │   ├── proxy.d.ts
    │       │       │   │   │       │   ├── robj-main.d.ts
    │       │       │   │   │       │   ├── robj-worker.d.ts
    │       │       │   │   │       │   ├── robj.d.ts
    │       │       │   │   │       │   ├── utils-r.d.ts
    │       │       │   │   │       │   ├── utils.d.ts
    │       │       │   │   │       │   ├── webr-chan.d.ts
    │       │       │   │   │       │   ├── webr-main.d.ts
    │       │       │   │   │       │   └── webr-worker.d.ts
    │       │       │   │   │       ├── webr-serviceworker.js
    │       │       │   │   │       ├── webr-serviceworker.js.map
    │       │       │   │   │       ├── webr-serviceworker.mjs
    │       │       │   │   │       ├── webr-serviceworker.mjs.map
    │       │       │   │   │       ├── webr-worker.js
    │       │       │   │   │       ├── webr-worker.js.map
    │       │       │   │   │       ├── webr.cjs
    │       │       │   │   │       ├── webr.cjs.map
    │       │       │   │   │       ├── webr.mjs
    │       │       │   │   │       └── webr.mjs.map
    │       │       │   │   └── shinylive-sw.js
    │       │       │   └── shinylive-quarto-css
    │       │       │       └── shinylive-quarto.css
    │       │       └── quarto-html
    │       │           ├── anchor.min.js
    │       │           ├── axe
    │       │           │   └── axe-check.js
    │       │           ├── popper.min.js
    │       │           ├── quarto-syntax-highlighting-587c61ba64f3a5504c4d52d930310e48.css
    │       │           ├── quarto.js
    │       │           ├── tabsets
    │       │           │   └── tabsets.js
    │       │           ├── tippy.css
    │       │           └── tippy.umd.min.js
    │       └── data
    │           ├── buoy_data.json
    │           └── stations.json
    ├── _pkgdown.yml
    ├── _quarto.yml
    ├── _targets
    │   ├── meta
    │   │   ├── crew
    │   │   ├── meta
    │   │   ├── process
    │   │   └── progress
    │   ├── objects
    │   │   ├── analysis_data
    │   │   ├── analysis_summary
    │   │   ├── annual_trends_wave
    │   │   ├── annual_trends_wind
    │   │   ├── current_db_stats
    │   │   ├── data_completeness
    │   │   ├── data_update
    │   │   ├── gev_hmax
    │   │   ├── gev_wave_height
    │   │   ├── gev_wind_speed
    │   │   ├── gust_factor_analysis
    │   │   ├── latest_erddap_timestamp
    │   │   ├── outlier_check
    │   │   ├── quality_report
    │   │   ├── recent_data
    │   │   ├── return_level_curves_wave
    │   │   ├── return_level_curves_wind
    │   │   ├── return_levels_hmax
    │   │   ├── return_levels_wave
    │   │   ├── return_levels_wind
    │   │   ├── rogue_comparison
    │   │   ├── rogue_wave_conditions
    │   │   ├── rogue_wave_events
    │   │   ├── rogue_wave_statistics
    │   │   ├── rogue_waves
    │   │   ├── save_vignette_data
    │   │   ├── seasonal_means_wave
    │   │   ├── seasonal_means_wind
    │   │   ├── stations
    │   │   ├── wave_anomalies
    │   │   └── wave_height_seasonal
    │   ├── user
    │   └── workspaces
    │       ├── analysis_data
    │       ├── data_completeness
    │       ├── gev_wind_speed
    │       ├── return_level_curves_wind
    │       ├── seasonal_means_wave
    │       └── stations
    ├── _targets.R
    ├── data-raw
    ├── default.R
    ├── default.nix
    ├── default.sh
    ├── docs
    │   ├── 404.html
    │   ├── LICENSE-text.html
    │   ├── LICENSE.html
    │   ├── articles
    │   │   ├── dashboard_static.html
    │   │   ├── dashboard_static_files
    │   │   │   ├── figure-html
    │   │   │   │   ├── unnamed-chunk-1-1.png
    │   │   │   │   ├── unnamed-chunk-10-1.png
    │   │   │   │   ├── unnamed-chunk-11-1.png
    │   │   │   │   ├── unnamed-chunk-12-1.png
    │   │   │   │   ├── unnamed-chunk-13-1.png
    │   │   │   │   ├── unnamed-chunk-14-1.png
    │   │   │   │   ├── unnamed-chunk-15-1.png
    │   │   │   │   ├── unnamed-chunk-16-1.png
    │   │   │   │   ├── unnamed-chunk-17-1.png
    │   │   │   │   ├── unnamed-chunk-18-1.png
    │   │   │   │   ├── unnamed-chunk-19-1.png
    │   │   │   │   ├── unnamed-chunk-21-1.png
    │   │   │   │   ├── unnamed-chunk-23-1.png
    │   │   │   │   ├── unnamed-chunk-25-1.png
    │   │   │   │   ├── unnamed-chunk-27-1.png
    │   │   │   │   ├── unnamed-chunk-28-1.png
    │   │   │   │   ├── unnamed-chunk-29-1.png
    │   │   │   │   ├── unnamed-chunk-3-1.png
    │   │   │   │   ├── unnamed-chunk-30-1.png
    │   │   │   │   ├── unnamed-chunk-31-1.png
    │   │   │   │   ├── unnamed-chunk-4-1.png
    │   │   │   │   ├── unnamed-chunk-5-1.png
    │   │   │   │   ├── unnamed-chunk-6-1.png
    │   │   │   │   ├── unnamed-chunk-7-1.png
    │   │   │   │   ├── unnamed-chunk-8-1.png
    │   │   │   │   └── unnamed-chunk-9-1.png
    │   │   │   └── libs
    │   │   │       ├── bootstrap
    │   │   │       │   ├── bootstrap-d5fa03fb90ac27921a6d47853be462c0.min.css
    │   │   │       │   ├── bootstrap-icons.css
    │   │   │       │   ├── bootstrap-icons.woff
    │   │   │       │   └── bootstrap.min.js
    │   │   │       ├── clipboard
    │   │   │       │   └── clipboard.min.js
    │   │   │       ├── crosstalk-1.2.2
    │   │   │       │   ├── css
    │   │   │       │   │   └── crosstalk.min.css
    │   │   │       │   ├── js
    │   │   │       │   │   ├── crosstalk.js
    │   │   │       │   │   ├── crosstalk.js.map
    │   │   │       │   │   ├── crosstalk.min.js
    │   │   │       │   │   └── crosstalk.min.js.map
    │   │   │       │   └── scss
    │   │   │       │       └── crosstalk.scss
    │   │   │       ├── datatables-binding-0.34.0
    │   │   │       │   └── datatables.js
    │   │   │       ├── datatables-css-0.0.0
    │   │   │       │   └── datatables-crosstalk.css
    │   │   │       ├── dt-core-1.13.6
    │   │   │       │   ├── css
    │   │   │       │   │   ├── jquery.dataTables.extra.css
    │   │   │       │   │   └── jquery.dataTables.min.css
    │   │   │       │   └── js
    │   │   │       │       └── jquery.dataTables.min.js
    │   │   │       ├── htmltools-fill-0.5.9
    │   │   │       │   └── fill.css
    │   │   │       ├── htmlwidgets-1.6.4
    │   │   │       │   └── htmlwidgets.js
    │   │   │       ├── jquery-3.6.0
    │   │   │       │   ├── jquery-3.6.0.js
    │   │   │       │   ├── jquery-3.6.0.min.js
    │   │   │       │   └── jquery-3.6.0.min.map
    │   │   │       ├── nouislider-7.0.10
    │   │   │       │   ├── jquery.nouislider.min.css
    │   │   │       │   └── jquery.nouislider.min.js
    │   │   │       ├── quarto-html
    │   │   │       │   ├── anchor.min.js
    │   │   │       │   ├── axe
    │   │   │       │   │   └── axe-check.js
    │   │   │       │   ├── popper.min.js
    │   │   │       │   ├── quarto-syntax-highlighting-587c61ba64f3a5504c4d52d930310e48.css
    │   │   │       │   ├── quarto.js
    │   │   │       │   ├── tabsets
    │   │   │       │   │   └── tabsets.js
    │   │   │       │   ├── tippy.css
    │   │   │       │   └── tippy.umd.min.js
    │   │   │       └── selectize-0.12.0
    │   │   │           ├── selectize.bootstrap3.css
    │   │   │           └── selectize.min.js
    │   │   ├── index.html
    │   │   ├── wave_analysis.html
    │   │   └── wave_analysis_files
    │   │       ├── figure-html
    │   │       │   ├── rogue-all-1.png
    │   │       │   ├── rogue-all-plot-1.png
    │   │       │   ├── rogue-m2-1.png
    │   │       │   ├── rogue-m2-plot-1.png
    │   │       │   ├── rogue-m3-1.png
    │   │       │   ├── rogue-m3-plot-1.png
    │   │       │   ├── rogue-m4-1.png
    │   │       │   ├── rogue-m4-plot-1.png
    │   │       │   ├── rogue-m5-1.png
    │   │       │   ├── rogue-m5-plot-1.png
    │   │       │   ├── rogue-m6-1.png
    │   │       │   └── rogue-m6-plot-1.png
    │   │       └── libs
    │   │           ├── bootstrap
    │   │           │   ├── bootstrap-d5fa03fb90ac27921a6d47853be462c0.min.css
    │   │           │   ├── bootstrap-icons.css
    │   │           │   ├── bootstrap-icons.woff
    │   │           │   └── bootstrap.min.js
    │   │           ├── clipboard
    │   │           │   └── clipboard.min.js
    │   │           ├── crosstalk-1.2.2
    │   │           │   ├── css
    │   │           │   │   └── crosstalk.min.css
    │   │           │   ├── js
    │   │           │   │   ├── crosstalk.js
    │   │           │   │   ├── crosstalk.js.map
    │   │           │   │   ├── crosstalk.min.js
    │   │           │   │   └── crosstalk.min.js.map
    │   │           │   └── scss
    │   │           │       └── crosstalk.scss
    │   │           ├── datatables-binding-0.34.0
    │   │           │   └── datatables.js
    │   │           ├── datatables-css-0.0.0
    │   │           │   └── datatables-crosstalk.css
    │   │           ├── dt-core-1.13.6
    │   │           │   ├── css
    │   │           │   │   ├── jquery.dataTables.extra.css
    │   │           │   │   └── jquery.dataTables.min.css
    │   │           │   └── js
    │   │           │       └── jquery.dataTables.min.js
    │   │           ├── htmltools-fill-0.5.9
    │   │           │   └── fill.css
    │   │           ├── htmlwidgets-1.6.4
    │   │           │   └── htmlwidgets.js
    │   │           ├── jquery-3.6.0
    │   │           │   ├── jquery-3.6.0.js
    │   │           │   ├── jquery-3.6.0.min.js
    │   │           │   └── jquery-3.6.0.min.map
    │   │           ├── nouislider-7.0.10
    │   │           │   ├── jquery.nouislider.min.css
    │   │           │   └── jquery.nouislider.min.js
    │   │           ├── quarto-html
    │   │           │   ├── anchor.min.js
    │   │           │   ├── axe
    │   │           │   │   └── axe-check.js
    │   │           │   ├── popper.min.js
    │   │           │   ├── quarto-syntax-highlighting-587c61ba64f3a5504c4d52d930310e48.css
    │   │           │   ├── quarto.js
    │   │           │   ├── tabsets
    │   │           │   │   └── tabsets.js
    │   │           │   ├── tippy.css
    │   │           │   └── tippy.umd.min.js
    │   │           └── selectize-0.12.0
    │   │               ├── selectize.bootstrap3.css
    │   │               └── selectize.min.js
    │   ├── authors.html
    │   ├── deps
    │   │   ├── bootstrap-5.3.1
    │   │   │   ├── bootstrap.bundle.min.js
    │   │   │   ├── bootstrap.bundle.min.js.map
    │   │   │   ├── bootstrap.min.css
    │   │   │   ├── font.css
    │   │   │   └── fonts
    │   │   │       ├── 07d40e985ad7c747025dabb9f22142c4.woff2
    │   │   │       ├── 1Ptug8zYS_SKggPNyC0ITw.woff2
    │   │   │       ├── 1Ptug8zYS_SKggPNyCAIT5lu.woff2
    │   │   │       ├── 1Ptug8zYS_SKggPNyCIIT5lu.woff2
    │   │   │       ├── 1Ptug8zYS_SKggPNyCMIT5lu.woff2
    │   │   │       ├── 1Ptug8zYS_SKggPNyCkIT5lu.woff2
    │   │   │       ├── 1f5e011d6aae0d98fc0518e1a303e99a.woff2
    │   │   │       ├── 4iCs6KVjbNBYlgoKcQ72j00.woff2
    │   │   │       ├── 4iCs6KVjbNBYlgoKcg72j00.woff2
    │   │   │       ├── 4iCs6KVjbNBYlgoKcw72j00.woff2
    │   │   │       ├── 4iCs6KVjbNBYlgoKew72j00.woff2
    │   │   │       ├── 4iCs6KVjbNBYlgoKfA72j00.woff2
    │   │   │       ├── 4iCs6KVjbNBYlgoKfw72.woff2
    │   │   │       ├── 4iCv6KVjbNBYlgoCxCvjs2yNL4U.woff2
    │   │   │       ├── 4iCv6KVjbNBYlgoCxCvjsGyN.woff2
    │   │   │       ├── 4iCv6KVjbNBYlgoCxCvjtGyNL4U.woff2
    │   │   │       ├── 4iCv6KVjbNBYlgoCxCvjvGyNL4U.woff2
    │   │   │       ├── 4iCv6KVjbNBYlgoCxCvjvWyNL4U.woff2
    │   │   │       ├── 4iCv6KVjbNBYlgoCxCvjvmyNL4U.woff2
    │   │   │       ├── 626330658504e338ee86aec8e957426b.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7jsDJT9g.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7ksDJT9g.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7nsDI.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7osDJT9g.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7psDJT9g.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7qsDJT9g.woff2
    │   │   │       ├── 6xK1dSBYKcSV-LCoeQqfX1RYOo3qPZ7rsDJT9g.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qN67lqDY.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qNK7lqDY.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qNa7lqDY.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qNq7lqDY.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qO67lqDY.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qOK7l.woff2
    │   │   │       ├── 6xK3dSBYKcSV-LCoeQqfX1RYOo3qPK7lqDY.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwkxduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwlBduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwlxdu.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwmBduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwmRduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwmhduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3i54rwmxduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwkxduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwlBduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwlxdu.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwmBduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwmRduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwmhduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ig4vwmxduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwkxduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwlBduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwlxdu.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwmBduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwmRduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwmhduz8A.woff2
    │   │   │       ├── 6xKydSBYKcSV-LCoeQqfX1RYOo3ik4zwmxduz8A.woff2
    │   │   │       ├── CSR54z1Qlv-GDxkbKVQ_dFsvWNReuQ.woff2
    │   │   │       ├── CSR54z1Qlv-GDxkbKVQ_dFsvWNpeudwk.woff2
    │   │   │       ├── CSR64z1Qlv-GDxkbKVQ_fO4KTet_.woff2
    │   │   │       ├── CSR64z1Qlv-GDxkbKVQ_fOAKTQ.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvQlMIXxw.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvUlMI.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvXlMIXxw.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvYlMIXxw.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvZlMIXxw.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvalMIXxw.woff2
    │   │   │       ├── HI_QiYsKILxRpg3hIP6sJ7fM7PqlONvblMIXxw.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlM-vWjMY.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlMOvWjMY.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlMevWjMY.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlMuvWjMY.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlOevWjMY.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlPevW.woff2
    │   │   │       ├── HI_SiYsKILxRpg3hIP6sJ7fM7PqlPuvWjMY.woff2
    │   │   │       ├── JTUSjIg1_i6t8kCHKm459W1hyzbi.woff2
    │   │   │       ├── JTUSjIg1_i6t8kCHKm459WRhyzbi.woff2
    │   │   │       ├── JTUSjIg1_i6t8kCHKm459WZhyzbi.woff2
    │   │   │       ├── JTUSjIg1_i6t8kCHKm459Wdhyzbi.woff2
    │   │   │       ├── JTUSjIg1_i6t8kCHKm459Wlhyw.woff2
    │   │   │       ├── QGYpz_kZZAGCONcK2A4bGOj8mNhN.woff2
    │   │   │       ├── S6u8w4BMUTPHjxsAUi-qJCY.woff2
    │   │   │       ├── S6u8w4BMUTPHjxsAXC-q.woff2
    │   │   │       ├── S6u9w4BMUTPHh6UVSwaPGR_p.woff2
    │   │   │       ├── S6u9w4BMUTPHh6UVSwiPGQ.woff2
    │   │   │       ├── S6u9w4BMUTPHh7USSwaPGR_p.woff2
    │   │   │       ├── S6u9w4BMUTPHh7USSwiPGQ.woff2
    │   │   │       ├── S6uyw4BMUTPHjx4wXg.woff2
    │   │   │       ├── S6uyw4BMUTPHjxAwXjeu.woff2
    │   │   │       ├── XRXV3I6Li01BKofIMeaBXso.woff2
    │   │   │       ├── XRXV3I6Li01BKofINeaB.woff2
    │   │   │       ├── XRXV3I6Li01BKofIO-aBXso.woff2
    │   │   │       ├── XRXV3I6Li01BKofIOOaBXso.woff2
    │   │   │       ├── XRXV3I6Li01BKofIOuaBXso.woff2
    │   │   │       ├── c2f002b3a87d3f9bfeebb23d32cfd9f8.woff2
    │   │   │       ├── ee91700cdbf7ce16c054c2bb8946c736.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqW106F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWt06F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWtE6F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWtU6F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWtk6F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWu06F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWuU6F.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWuk6F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWvU6F15M.woff2
    │   │   │       ├── memtYaGs126MiZpBA-UFUIcVXSCEkx2cmqvXlWqWxU6F15M.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTS-muw.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTS2mu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTSCmu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTSGmu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTSKmu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTSOmu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTSumu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTSymu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTUGmu1aB.woff2
    │   │   │       ├── memvYaGs126MiZpBA-UvWbX2vVnXBbObj2OVTVOmu1aB.woff2
    │   │   │       ├── q5uGsou0JOdh94bfuQltOxU.woff2
    │   │   │       └── q5uGsou0JOdh94bfvQlt.woff2
    │   │   ├── bootstrap-toc-1.0.1
    │   │   │   └── bootstrap-toc.min.js
    │   │   ├── clipboard.js-2.0.11
    │   │   │   └── clipboard.min.js
    │   │   ├── data-deps.txt
    │   │   ├── font-awesome-6.5.2
    │   │   │   ├── css
    │   │   │   │   ├── all.css
    │   │   │   │   ├── all.min.css
    │   │   │   │   ├── v4-shims.css
    │   │   │   │   └── v4-shims.min.css
    │   │   │   └── webfonts
    │   │   │       ├── fa-brands-400.ttf
    │   │   │       ├── fa-brands-400.woff2
    │   │   │       ├── fa-regular-400.ttf
    │   │   │       ├── fa-regular-400.woff2
    │   │   │       ├── fa-solid-900.ttf
    │   │   │       ├── fa-solid-900.woff2
    │   │   │       ├── fa-v4compatibility.ttf
    │   │   │       └── fa-v4compatibility.woff2
    │   │   ├── headroom-0.11.0
    │   │   │   ├── headroom.min.js
    │   │   │   └── jQuery.headroom.min.js
    │   │   ├── jquery-3.6.0
    │   │   │   ├── jquery-3.6.0.js
    │   │   │   ├── jquery-3.6.0.min.js
    │   │   │   └── jquery-3.6.0.min.map
    │   │   └── search-1.0.0
    │   │       ├── autocomplete.jquery.min.js
    │   │       ├── fuse.min.js
    │   │       └── mark.min.js
    │   ├── index.html
    │   ├── katex-auto.js
    │   ├── lightswitch.js
    │   ├── link.svg
    │   ├── pkgdown.js
    │   ├── pkgdown.yml
    │   ├── reference
    │   │   ├── add_wave_metrics.html
    │   │   ├── analyze_gust_factor.html
    │   │   ├── analyze_parquet_storage.html
    │   │   ├── analyze_rogue_statistics.html
    │   │   ├── calculate_annual_trends.html
    │   │   ├── calculate_hs_from_elevation.html
    │   │   ├── calculate_return_levels.html
    │   │   ├── calculate_rms_wave_height.html
    │   │   ├── calculate_seasonal_means.html
    │   │   ├── calculate_wave_steepness.html
    │   │   ├── compare_rogue_wave_gust.html
    │   │   ├── connect_duckdb.html
    │   │   ├── convert_duckdb_to_parquet.html
    │   │   ├── create_buoy_schema.html
    │   │   ├── create_email_summary.html
    │   │   ├── create_return_level_plot_data.html
    │   │   ├── decompose_stl.html
    │   │   ├── detect_anomalies.html
    │   │   ├── detect_rogue_waves.html
    │   │   ├── download_buoy_data.html
    │   │   ├── evaluate_wave_model.html
    │   │   ├── explain_hourly_averaging.html
    │   │   ├── explain_hs_formula.html
    │   │   ├── explain_measurement_period.html
    │   │   ├── explain_wave_height_measurement.html
    │   │   ├── extreme_values.html
    │   │   ├── fit_gev_annual_maxima.html
    │   │   ├── fit_gpd_threshold.html
    │   │   ├── generate_and_send_summary.html
    │   │   ├── generate_weekly_summary.html
    │   │   ├── get_data_dictionary.html
    │   │   ├── get_database_stats.html
    │   │   ├── get_latest_timestamp.html
    │   │   ├── get_stations.html
    │   │   ├── get_variable_docs.html
    │   │   ├── hs_from_rms.html
    │   │   ├── incremental_update.html
    │   │   ├── incremental_update_parquet.html
    │   │   ├── index.html
    │   │   ├── init_parquet_storage.html
    │   │   ├── initialize_database.html
    │   │   ├── inst
    │   │   │   └── extdata
    │   │   ├── irishbuoys-package.html
    │   │   ├── load_to_duckdb.html
    │   │   ├── log_update.html
    │   │   ├── predict_wave_height.html
    │   │   ├── prepare_wave_features.html
    │   │   ├── query_buoy_data.html
    │   │   ├── query_parquet.html
    │   │   ├── rogue_wave_report.html
    │   │   ├── save_to_parquet.html
    │   │   ├── train_wave_model.html
    │   │   ├── trend_analysis.html
    │   │   ├── trend_summary_report.html
    │   │   ├── update_station_metadata.html
    │   │   ├── wave_glossary.html
    │   │   ├── wave_model.html
    │   │   ├── wave_model_report.html
    │   │   ├── wave_science.html
    │   │   └── wave_science_documentation.html
    │   └── vignettes
    │       ├── dashboard_static.html
    │       ├── dashboard_static_files
    │       │   ├── figure-html
    │       │   │   ├── unnamed-chunk-1-1.png
    │       │   │   ├── unnamed-chunk-11-1.png
    │       │   │   ├── unnamed-chunk-13-1.png
    │       │   │   ├── unnamed-chunk-15-1.png
    │       │   │   ├── unnamed-chunk-17-1.png
    │       │   │   ├── unnamed-chunk-19-1.png
    │       │   │   ├── unnamed-chunk-21-1.png
    │       │   │   ├── unnamed-chunk-23-1.png
    │       │   │   ├── unnamed-chunk-25-1.png
    │       │   │   ├── unnamed-chunk-27-1.png
    │       │   │   ├── unnamed-chunk-28-1.png
    │       │   │   ├── unnamed-chunk-29-1.png
    │       │   │   ├── unnamed-chunk-3-1.png
    │       │   │   ├── unnamed-chunk-30-1.png
    │       │   │   ├── unnamed-chunk-31-1.png
    │       │   │   ├── unnamed-chunk-5-1.png
    │       │   │   ├── unnamed-chunk-7-1.png
    │       │   │   └── unnamed-chunk-9-1.png
    │       │   └── libs
    │       │       ├── bootstrap
    │       │       │   ├── bootstrap-d5fa03fb90ac27921a6d47853be462c0.min.css
    │       │       │   ├── bootstrap-icons.css
    │       │       │   ├── bootstrap-icons.woff
    │       │       │   └── bootstrap.min.js
    │       │       ├── clipboard
    │       │       │   └── clipboard.min.js
    │       │       ├── crosstalk-1.2.2
    │       │       │   ├── css
    │       │       │   │   └── crosstalk.min.css
    │       │       │   ├── js
    │       │       │   │   ├── crosstalk.js
    │       │       │   │   ├── crosstalk.js.map
    │       │       │   │   ├── crosstalk.min.js
    │       │       │   │   └── crosstalk.min.js.map
    │       │       │   └── scss
    │       │       │       └── crosstalk.scss
    │       │       ├── datatables-binding-0.34.0
    │       │       │   └── datatables.js
    │       │       ├── datatables-css-0.0.0
    │       │       │   └── datatables-crosstalk.css
    │       │       ├── dt-core-1.13.6
    │       │       │   ├── css
    │       │       │   │   ├── jquery.dataTables.extra.css
    │       │       │   │   └── jquery.dataTables.min.css
    │       │       │   └── js
    │       │       │       └── jquery.dataTables.min.js
    │       │       ├── htmltools-fill-0.5.9
    │       │       │   └── fill.css
    │       │       ├── htmlwidgets-1.6.4
    │       │       │   └── htmlwidgets.js
    │       │       ├── jquery-3.6.0
    │       │       │   ├── jquery-3.6.0.js
    │       │       │   ├── jquery-3.6.0.min.js
    │       │       │   └── jquery-3.6.0.min.map
    │       │       ├── nouislider-7.0.10
    │       │       │   ├── jquery.nouislider.min.css
    │       │       │   └── jquery.nouislider.min.js
    │       │       ├── quarto-html
    │       │       │   ├── anchor.min.js
    │       │       │   ├── axe
    │       │       │   │   └── axe-check.js
    │       │       │   ├── popper.min.js
    │       │       │   ├── quarto-syntax-highlighting-587c61ba64f3a5504c4d52d930310e48.css
    │       │       │   ├── quarto.js
    │       │       │   ├── tabsets
    │       │       │   │   └── tabsets.js
    │       │       │   ├── tippy.css
    │       │       │   └── tippy.umd.min.js
    │       │       └── selectize-0.12.0
    │       │           ├── selectize.bootstrap3.css
    │       │           └── selectize.min.js
    │       ├── wave_analysis.html
    │       └── wave_analysis_files
    │           ├── figure-html
    │           │   ├── rogue-all-plot-1.png
    │           │   ├── rogue-m2-plot-1.png
    │           │   ├── rogue-m3-plot-1.png
    │           │   ├── rogue-m4-plot-1.png
    │           │   ├── rogue-m5-plot-1.png
    │           │   └── rogue-m6-plot-1.png
    │           └── libs
    │               ├── bootstrap
    │               │   ├── bootstrap-d5fa03fb90ac27921a6d47853be462c0.min.css
    │               │   ├── bootstrap-icons.css
    │               │   ├── bootstrap-icons.woff
    │               │   └── bootstrap.min.js
    │               ├── clipboard
    │               │   └── clipboard.min.js
    │               ├── crosstalk-1.2.2
    │               │   ├── css
    │               │   │   └── crosstalk.min.css
    │               │   ├── js
    │               │   │   ├── crosstalk.js
    │               │   │   ├── crosstalk.js.map
    │               │   │   ├── crosstalk.min.js
    │               │   │   └── crosstalk.min.js.map
    │               │   └── scss
    │               │       └── crosstalk.scss
    │               ├── datatables-binding-0.34.0
    │               │   └── datatables.js
    │               ├── datatables-css-0.0.0
    │               │   └── datatables-crosstalk.css
    │               ├── dt-core-1.13.6
    │               │   ├── css
    │               │   │   ├── jquery.dataTables.extra.css
    │               │   │   └── jquery.dataTables.min.css
    │               │   └── js
    │               │       └── jquery.dataTables.min.js
    │               ├── htmltools-fill-0.5.9
    │               │   └── fill.css
    │               ├── htmlwidgets-1.6.4
    │               │   └── htmlwidgets.js
    │               ├── jquery-3.6.0
    │               │   ├── jquery-3.6.0.js
    │               │   ├── jquery-3.6.0.min.js
    │               │   └── jquery-3.6.0.min.map
    │               ├── nouislider-7.0.10
    │               │   ├── jquery.nouislider.min.css
    │               │   └── jquery.nouislider.min.js
    │               ├── quarto-html
    │               │   ├── anchor.min.js
    │               │   ├── axe
    │               │   │   └── axe-check.js
    │               │   ├── popper.min.js
    │               │   ├── quarto-syntax-highlighting-587c61ba64f3a5504c4d52d930310e48.css
    │               │   ├── quarto.js
    │               │   ├── tabsets
    │               │   │   └── tabsets.js
    │               │   ├── tippy.css
    │               │   └── tippy.umd.min.js
    │               └── selectize-0.12.0
    │                   ├── selectize.bootstrap3.css
    │                   └── selectize.min.js
    ├── inst
    │   ├── docs
    │   │   └── parquet_storage_guide.md
    │   ├── extdata
    │   │   ├── analysis_questions.md
    │   │   ├── irish_buoys.duckdb
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
    │   ├── load_to_duckdb.Rd
    │   ├── log_update.Rd
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
    ├── push_to_cachix.sh
    ├── tests
    │   ├── testthat
    │   │   └── test-data-consistency.R
    │   └── testthat.R
    └── vignettes
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

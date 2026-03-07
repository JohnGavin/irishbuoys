# Fix #32: Plumber REST API — Phase 2 MVP
#
# Phase 1 (already complete): Static JSON API in docs/api/v1/ with
# 9 endpoints, R/api_static.R generator functions, plan_api.R targets,
# and api-usage.qmd documentation.
#
# Phase 2 MVP (this commit):
#
# 1. inst/plumber/api.R — Minimal plumber API definition
#    4 read-only GET endpoints serving pre-built JSON:
#    - /stations -> docs/api/v1/stations.json
#    - /rogue-waves -> docs/api/v1/rogue-waves.json
#    - /return-levels -> docs/api/v1/return-levels.json
#    - /seasonal -> docs/api/v1/seasonal.json
#    Plus CORS filter and built-in Swagger at /__docs__/
#
# 2. R/api_plumber.R — Exported functions
#    - run_api(port, host): starts the plumber server
#    - create_api_router(): returns router without starting (for testing)
#
# 3. DESCRIPTION: Added plumber to Suggests
#
# 4. tests/testthat/test-api-plumber.R — Basic tests
#    - API file exists
#    - Router can be created
#    - Expected endpoints are registered
#    No live HTTP tests (those are Phase 3)
#
# 5. vignettes/api-usage.qmd — Added "Live API" section
#
# NOT included (future phases):
# - Docker/deployment
# - DuckDB query endpoints
# - Rate limiting
# - Parquet format responses
# - Live HTTP integration tests

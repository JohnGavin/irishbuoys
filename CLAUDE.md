# irishbuoys — Irish marine buoy monitoring

## Project Rules

- ERDDAP data validation, temporal coverage checks, wave model edge cases
- Vignettes: zero inline computation, all via `safe_tar_read()`
- DuckDB: use `duckplyr` not raw SQL

## CRITICAL: Package Context (ctx.yaml)

**Central cache:** `~/docs_gh/proj/data/llm/content/inst/ctx/external/`

**To check ctx coverage, ALWAYS run:**
```r
source("~/docs_gh/llm/R/tar_plans/plan_pkgctx.R")
ctx_audit("DESCRIPTION")
```

**To fix missing ctx:**
```r
source("~/docs_gh/llm/R/tar_plans/plan_pkgctx.R")
ctx_sync("DESCRIPTION")
```

**NEVER** write your own ctx checking code. NEVER look in `.claude/context/` or `inst/ctx/`. ALWAYS use `ctx_audit()` from `plan_pkgctx.R`.


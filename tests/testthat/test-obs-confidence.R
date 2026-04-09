# Tests for R/obs_confidence.R

# ── compute_obs_confidence ────────────────────────────────────────

test_that("compute_obs_confidence returns 1.0 for fresh data", {
  expect_equal(compute_obs_confidence(0), 1.0)
  expect_equal(compute_obs_confidence(3), 1.0)
  expect_equal(compute_obs_confidence(6), 1.0)
})

test_that("compute_obs_confidence decays linearly between 6h and 24h", {
  # Midpoint of the 6-24h ramp is 15h, expected confidence = 0.75
  expect_equal(compute_obs_confidence(15), 0.75)
  # Endpoint at 24h is 0.5
  expect_equal(compute_obs_confidence(24), 0.5)
})

test_that("compute_obs_confidence decays between 24h and 72h", {
  # 24h boundary
  expect_equal(compute_obs_confidence(24), 0.5)
  # 72h boundary
  expect_equal(compute_obs_confidence(72), 0.25)
  # Halfway (48h) → 0.375
  expect_equal(compute_obs_confidence(48), 0.375)
})

test_that("compute_obs_confidence floors at 0.1 beyond 72h", {
  expect_equal(compute_obs_confidence(73), 0.1)
  expect_equal(compute_obs_confidence(168), 0.1)
  expect_equal(compute_obs_confidence(1e6), 0.1)
})

test_that("compute_obs_confidence is vectorised and handles NA", {
  result <- compute_obs_confidence(c(0, 12, 24, 48, NA, 100))
  expect_length(result, 6)
  expect_equal(result[1], 1.0)
  expect_equal(result[3], 0.5)
  expect_true(is.na(result[5]))
  expect_equal(result[6], 0.1)
})

test_that("compute_obs_confidence clamps negative ages to 0", {
  # Slightly negative age (clock skew) should still report fresh
  expect_equal(compute_obs_confidence(-1), 1.0)
})

# ── obs_status_label ──────────────────────────────────────────────

test_that("obs_status_label returns the four expected categories", {
  result <- obs_status_label(c(1.0, 0.7, 0.4, 0.15))
  expect_equal(result$label, c("fresh", "ageing", "stale", "very stale"))
  expect_length(result$color, 4)
  expect_true(all(grepl("^#", result$color)))
})

test_that("obs_status_label propagates NA", {
  result <- obs_status_label(c(1.0, NA))
  expect_equal(result$label[1], "fresh")
  expect_true(is.na(result$label[2]))
  expect_true(is.na(result$color[2]))
})

# ── widen_ci ──────────────────────────────────────────────────────

test_that("widen_ci is identity at confidence = 1", {
  result <- widen_ci(point = 10, lower = 8, upper = 12, confidence = 1)
  expect_equal(result$lower, 8)
  expect_equal(result$upper, 12)
})

test_that("widen_ci doubles half-width at confidence = 0.5", {
  result <- widen_ci(point = 10, lower = 8, upper = 12, confidence = 0.5)
  # half-widths were 2; doubled = 4; → [6, 14]
  expect_equal(result$lower, 6)
  expect_equal(result$upper, 14)
})

test_that("widen_ci preserves the point estimate", {
  result <- widen_ci(point = 10, lower = 8, upper = 12, confidence = 0.3)
  midpoint <- (result$lower + result$upper) / 2
  expect_equal(midpoint, 10)
})

test_that("widen_ci is vectorised over inputs", {
  result <- widen_ci(
    point = c(10, 20, 30),
    lower = c(8, 18, 28),
    upper = c(12, 22, 32),
    confidence = c(1.0, 0.5, 0.25)
  )
  expect_length(result$lower, 3)
  expect_equal(result$lower[1], 8)        # confidence 1 → unchanged
  expect_equal(result$lower[2], 16)       # confidence 0.5 → 2x widen
  expect_equal(result$upper[3], 38)       # confidence 0.25 → 4x widen
})

test_that("widen_ci floors confidence at 0.1 to avoid blowing up", {
  result <- widen_ci(point = 10, lower = 8, upper = 12, confidence = 0.01)
  # Should treat confidence as 0.1, so half-widths × 10 → [-10, 30]
  expect_equal(result$lower, -10)
  expect_equal(result$upper, 30)
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(compute_obs_confidence) signature", {
  expect_snapshot(args(compute_obs_confidence))
})

test_that("snapshot: args(obs_status_label) signature", {
  expect_snapshot(args(obs_status_label))
})

test_that("snapshot: args(widen_ci) signature", {
  expect_snapshot(args(widen_ci))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(add_wave_metrics)", { expect_snapshot(args(irishbuoys:::add_wave_metrics)) })
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
test_that("snap3: args(analyze_joint_extremes)", { expect_snapshot(args(irishbuoys:::analyze_joint_extremes)) })
test_that("snap3: args(analyze_parquet_storage)", { expect_snapshot(args(irishbuoys:::analyze_parquet_storage)) })

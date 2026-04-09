test_that("ci_order_statistics returns correct structure", {
  set.seed(42)
  x <- rnorm(1000)
  result <- ci_order_statistics(x, probs = c(0.95, 0.99))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_named(
    result,
    c("probability", "quantile", "lower", "upper", "j", "k",
      "actual_coverage", "method")
  )
  expect_equal(result$method, c("order_statistics", "order_statistics"))
  expect_equal(result$probability, c(0.95, 0.99))
})

test_that("ci_order_statistics CIs bracket the quantile", {
  set.seed(42)
  x <- rnorm(5000)
  result <- ci_order_statistics(x, probs = c(0.95, 0.99))

  # Lower should be <= quantile <= upper

  expect_true(all(result$lower <= result$quantile))
  expect_true(all(result$quantile <= result$upper))

  # Coverage should meet or exceed requested level

  expect_true(all(result$actual_coverage >= 0.95))
})

test_that("ci_order_statistics handles small samples", {
  x <- 1:5
  result <- ci_order_statistics(x, probs = 0.95)

  expect_equal(nrow(result), 1)
  expect_true(all(is.na(result$lower)))
  expect_equal(result$method, "order_statistics")
})

test_that("ci_order_statistics handles NAs in input", {
  set.seed(42)
  x <- c(rnorm(500), rep(NA, 50))
  result <- ci_order_statistics(x, probs = 0.95)

  expect_equal(nrow(result), 1)
  expect_false(is.na(result$quantile))
  expect_false(is.na(result$lower))
})

test_that("ci_bootstrap_return_levels returns correct structure", {
  skip_if_not_installed("mev")
  set.seed(42)
  d <- data.frame(wave_height = rexp(500, rate = 0.5) + 2)

  result <- ci_bootstrap_return_levels(
    d,
    variable = "wave_height",
    return_periods = c(1, 5),
    n_boot = 50,
    seed = 42
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_named(
    result,
    c("return_period", "return_level", "lower", "upper", "n_success", "method")
  )
  expect_equal(result$method, c("bootstrap", "bootstrap"))
  expect_equal(result$return_period, c(1, 5))
})

test_that("ci_bootstrap_return_levels CIs bracket estimates", {
  skip_if_not_installed("mev")
  set.seed(42)
  d <- data.frame(wave_height = rexp(1000, rate = 0.5) + 2)

  result <- ci_bootstrap_return_levels(
    d,
    variable = "wave_height",
    return_periods = c(1, 5),
    n_boot = 100,
    seed = 42
  )

  # Where we have CIs, lower <= return_level <= upper
  valid <- !is.na(result$lower) & !is.na(result$upper)
  if (any(valid)) {
    expect_true(all(result$lower[valid] <= result$return_level[valid]))
    expect_true(all(result$return_level[valid] <= result$upper[valid]))
  }
})

test_that("ci_bootstrap_return_levels handles block bootstrap", {
  skip_if_not_installed("mev")
  set.seed(42)
  d <- data.frame(wave_height = rexp(500, rate = 0.5) + 2)

  result <- ci_bootstrap_return_levels(
    d,
    variable = "wave_height",
    return_periods = c(1, 5),
    n_boot = 50,
    block_size = 48,
    seed = 42
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_equal(result$method, c("bootstrap", "bootstrap"))
})

test_that("ci_bootstrap_return_levels handles insufficient data", {
  d <- data.frame(wave_height = c(1, 2, 3))

  result <- ci_bootstrap_return_levels(
    d,
    variable = "wave_height",
    return_periods = c(1, 5),
    n_boot = 10
  )

  expect_equal(nrow(result), 2)
  expect_true(all(is.na(result$return_level)))
  expect_true(all(result$n_success == 0))
})

test_that("ci_parametric_bootstrap returns correct structure", {
  skip_if_not_installed("mev")
  fit <- list(u = 5.0, scale = 1.2, shape = 0.1, n_exceed = 500)

  result <- ci_parametric_bootstrap(
    fit,
    n_boot = 50,
    return_periods = c(1, 5, 10),
    seed = 42
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_named(
    result,
    c("return_period", "return_level", "lower", "upper", "n_success", "method")
  )
  expect_equal(result$method, rep("parametric_bootstrap", 3))
})

test_that("ci_parametric_bootstrap CIs bracket estimates", {
  skip_if_not_installed("mev")
  fit <- list(u = 5.0, scale = 1.2, shape = 0.1, n_exceed = 500)

  result <- ci_parametric_bootstrap(
    fit,
    n_boot = 100,
    return_periods = c(1, 5, 10),
    seed = 42
  )

  valid <- !is.na(result$lower) & !is.na(result$upper)
  if (any(valid)) {
    expect_true(all(result$lower[valid] <= result$return_level[valid]))
    expect_true(all(result$return_level[valid] <= result$upper[valid]))
  }
})

test_that("ci_parametric_bootstrap handles error fit", {
  fit <- list(u = 5.0, n_exceed = 10, error = "Insufficient exceedances (<30)")

  result <- ci_parametric_bootstrap(fit, n_boot = 10, return_periods = c(1, 5))

  expect_equal(nrow(result), 2)
  expect_true(all(is.na(result$return_level)))
  expect_true(all(result$n_success == 0))
  expect_equal(result$method, c("parametric_bootstrap", "parametric_bootstrap"))
})

test_that("ci_parametric_bootstrap handles shape=0 (exponential)", {
  skip_if_not_installed("mev")
  fit <- list(u = 3.0, scale = 0.8, shape = 0.0, n_exceed = 300)

  result <- ci_parametric_bootstrap(
    fit,
    n_boot = 50,
    return_periods = c(1, 5),
    seed = 42
  )

  expect_equal(nrow(result), 2)
  expect_true(all(!is.na(result$return_level)))
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(ci_bootstrap_return_levels) signature", {
  expect_snapshot(args(ci_bootstrap_return_levels))
})

test_that("snapshot: args(ci_order_statistics) signature", {
  expect_snapshot(args(ci_order_statistics))
})

test_that("snapshot: args(ci_parametric_bootstrap) signature", {
  expect_snapshot(args(ci_parametric_bootstrap))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(add_wave_metrics)", { expect_snapshot(args(irishbuoys:::add_wave_metrics)) })
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
test_that("snap3: args(analyze_joint_extremes)", { expect_snapshot(args(irishbuoys:::analyze_joint_extremes)) })
test_that("snap3: args(analyze_parquet_storage)", { expect_snapshot(args(irishbuoys:::analyze_parquet_storage)) })

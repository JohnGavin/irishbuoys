# Regression guard: compute_extremal_dependence() inverts Kendall tau with
# kendallknight (O(n log n)) instead of calling copula::fitCopula(method =
# "itau") (O(n^2)). The estimates must stay identical to the copula reference.

ed_times <- function(n) rep(seq.POSIXt(as.POSIXct("2020-01-01", tz = "UTC"), by = "hour", length.out = n), 2)
ed_wave <- function(n, rho, z) round(c(3 + z, 3 + rho * z + rnorm(n, 0, 0.5)), 1)
ed_z <- function(n, seed) { set.seed(seed); rnorm(n) }
ed_fixture <- function(n = 600, rho = 0.8, seed = 7) data.frame(time = ed_times(n), station_id = rep(c("M2", "M3"), each = n), wave_height = ed_wave(n, rho, ed_z(n, seed)), stringsAsFactors = FALSE)
itau_alpha <- function(u) unname(copula::coef(copula::fitCopula(copula::gumbelCopula(dim = 2), u, method = "itau")))
ed_pair <- function(d) list(v1 = d$wave_height[d$station_id == "M2"], v2 = d$wave_height[d$station_id == "M3"])
test_that("point estimates match copula itau on tied data", {
  skip_if_not_installed("copula")
  d <- ed_fixture()
  p <- ed_pair(d)
  expect_gt(mean(duplicated(p$v1)), 0.5)
  res <- compute_extremal_dependence(d, n_bootstrap = 5, boot_subsample = 200)$dependence_table
  ref <- itau_alpha(copula::pobs(cbind(p$v1, p$v2)))
  expect_equal(res$copula_alpha, ref, tolerance = 1e-8)
  expect_equal(res$lambda_upper, 2 - 2^(1 / ref), tolerance = 1e-8)
})

test_that("bootstrap CI matches a copula reference with the same seed", {
  skip_if_not_installed("copula")
  d <- ed_fixture()
  p <- ed_pair(d)
  u <- copula::pobs(cbind(p$v1, p$v2))
  set.seed(99)
  res <- compute_extremal_dependence(d, n_bootstrap = 12, boot_subsample = 200)$dependence_table
  set.seed(99)
  lam <- replicate(12, 2 - 2^(1 / itau_alpha(u[sample(nrow(u), 200, replace = TRUE), ])))
  ci <- unname(stats::quantile(lam, c(0.025, 0.975)))
  expect_equal(c(res$lambda_upper_ci_low, res$lambda_upper_ci_high), ci, tolerance = 1e-8)
})

test_that("gumbel_alpha_from_tau inverts Kendall tau like copula::iTau", {
  skip_if_not_installed("copula")
  for (tau in c(0, 0.1, 0.5, 0.9)) {
    expect_equal(gumbel_alpha_from_tau(tau), copula::iTau(copula::gumbelCopula(), tau))
  }
  # negative tau: copula clamps to independence (alpha = 1)
  expect_equal(gumbel_alpha_from_tau(-0.3), 1)
  expect_error(gumbel_alpha_from_tau(1))
  expect_error(gumbel_alpha_from_tau(NA_real_))
})

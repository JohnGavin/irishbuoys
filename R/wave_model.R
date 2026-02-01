#' Wave Height Prediction Model
#'
#' @description
#' Functions for building and using a Random Forest model to predict
#' significant wave height from meteorological variables.
#'
#' @name wave_model
NULL

#' Prepare Features for Wave Height Prediction
#'
#' @description
#' Creates lagged features and derived variables for wave height prediction.
#'
#' @param data Data frame with buoy observations
#' @param lags Integer vector of lag periods in hours (default: 1:3)
#'
#' @return Data frame with additional lagged and derived features
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, qc_filter = FALSE)
#' features <- prepare_wave_features(data)
#' DBI::dbDisconnect(con)
#' }
prepare_wave_features <- function(data, lags = 1:3) {

 cli::cli_progress_step("Preparing features for wave prediction...")

 # Ensure data is sorted by station and time
 data <- data[order(data$station_id, data$time), ]

 # Create lagged wave height features per station
 for (lag_hours in lags) {
   lag_col <- paste0("wave_height_lag", lag_hours)
   data[[lag_col]] <- NA_real_

   for (station in unique(data$station_id)) {
     idx <- which(data$station_id == station)
     if (length(idx) > lag_hours) {
       data[[lag_col]][idx] <- dplyr::lag(data$wave_height[idx], n = lag_hours)
     }
   }
 }

 # Create lagged wind speed
 data$wind_speed_lag1 <- NA_real_
 for (station in unique(data$station_id)) {
   idx <- which(data$station_id == station)
   if (length(idx) > 1) {
     data$wind_speed_lag1[idx] <- dplyr::lag(data$wind_speed[idx], n = 1)
   }
 }

 # Pressure tendency (change from previous hour)
 data$pressure_change <- NA_real_
 for (station in unique(data$station_id)) {
   idx <- which(data$station_id == station)
   if (length(idx) > 1) {
     data$pressure_change[idx] <- data$atmospheric_pressure[idx] -
       dplyr::lag(data$atmospheric_pressure[idx], n = 1)
   }
 }

 # Temporal features
 data$hour <- as.integer(format(data$time, "%H"))
 data$month <- as.integer(format(data$time, "%m"))

 # Wind direction components (for cyclical nature)
 if ("wind_direction" %in% names(data)) {
   data$wind_dir_sin <- sin(data$wind_direction * pi / 180)
   data$wind_dir_cos <- cos(data$wind_direction * pi / 180)
 }

 # Wave steepness (if wave_period available)
 if ("wave_period" %in% names(data)) {
   wavelength <- 1.56 * data$wave_period^2
   data$wave_steepness <- data$wave_height / wavelength
   data$wave_steepness[!is.finite(data$wave_steepness)] <- NA_real_
 }

 # Gust factor
 if (all(c("gust", "wind_speed") %in% names(data))) {
   data$gust_factor <- data$gust / data$wind_speed
   data$gust_factor[!is.finite(data$gust_factor)] <- NA_real_
 }

 cli::cli_alert_success("Created {length(lags) + 8} derived features")

 return(data)
}

#' Train Wave Height Prediction Model
#'
#' @description
#' Trains a Random Forest model using ranger to predict wave height.
#'
#' @param data Data frame with prepared features (from prepare_wave_features)
#' @param target Target variable name (default: "wave_height")
#' @param predictors Character vector of predictor names (default: NULL uses standard set)
#' @param train_fraction Fraction of data for training (default: 0.7)
#' @param seed Random seed for reproducibility (default: 42)
#' @param ... Additional arguments passed to ranger::ranger
#'
#' @return List with model, train/test indices, and feature importance
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, qc_filter = FALSE)
#' features <- prepare_wave_features(data)
#' model_result <- train_wave_model(features)
#' DBI::dbDisconnect(con)
#' }
train_wave_model <- function(
   data,
   target = "wave_height",
   predictors = NULL,
   train_fraction = 0.7,
   seed = 42,
   ...
) {

 if (!requireNamespace("ranger", quietly = TRUE)) {
   cli::cli_abort("Package 'ranger' is required. Add it to your Nix environment.")
 }

 cli::cli_progress_step("Training wave height prediction model...")

 # Default predictors based on analysis
 if (is.null(predictors)) {
   predictors <- c(
     "wind_speed", "gust", "wind_speed_lag1",
     "wave_height_lag1", "wave_height_lag2", "wave_height_lag3",
     "wave_period", "atmospheric_pressure", "pressure_change",
     "wind_dir_sin", "wind_dir_cos",
     "hour", "month"
   )
 }

 # Filter to available predictors
 available <- predictors[predictors %in% names(data)]
 missing <- setdiff(predictors, available)
 if (length(missing) > 0) {
   cli::cli_alert_warning("Missing predictors: {paste(missing, collapse = ', ')}")
 }

 cli::cli_alert_info("Using {length(available)} predictors")

 # Prepare modeling data
 model_vars <- c(target, available)
 model_data <- data[, model_vars, drop = FALSE]
 model_data <- model_data[complete.cases(model_data), ]

 if (nrow(model_data) < 100) {
   cli::cli_abort("Insufficient complete cases: {nrow(model_data)}. Need at least 100.")
 }

 cli::cli_alert_info("Using {nrow(model_data)} complete observations")

 # Time-based train/test split (forward validation)
 set.seed(seed)
 n <- nrow(model_data)
 train_idx <- 1:floor(n * train_fraction)
 test_idx <- (floor(n * train_fraction) + 1):n

 train_data <- model_data[train_idx, ]
 test_data <- model_data[test_idx, ]

 # Build formula
 formula <- stats::as.formula(paste(target, "~", paste(available, collapse = " + ")))

 # Train ranger model
 model <- ranger::ranger(
   formula = formula,
   data = train_data,
   importance = "impurity",
   num.trees = 500,
   seed = seed,
   ...
 )

 # Get feature importance
 importance <- data.frame(
   variable = names(model$variable.importance),
   importance = as.numeric(model$variable.importance),
   stringsAsFactors = FALSE
 )
 importance <- importance[order(-importance$importance), ]

 cli::cli_alert_success(
   "Model trained: R² = {round(model$r.squared, 3)}, OOB error = {round(sqrt(model$prediction.error), 2)}m"
 )

 return(list(
   model = model,
   formula = formula,
   predictors = available,
   train_idx = train_idx,
   test_idx = test_idx,
   importance = importance,
   train_r_squared = model$r.squared,
   oob_rmse = sqrt(model$prediction.error)
 ))
}

#' Evaluate Wave Height Model
#'
#' @description
#' Evaluates model performance on test data.
#'
#' @param model_result Result from train_wave_model
#' @param data Full prepared data frame
#' @param target Target variable name (default: "wave_height")
#'
#' @return Data frame with performance metrics
#'
#' @export
evaluate_wave_model <- function(model_result, data, target = "wave_height") {

 cli::cli_progress_step("Evaluating model on test data...")

 # Get test data
 model_vars <- c(target, model_result$predictors)
 model_data <- data[, model_vars, drop = FALSE]
 model_data <- model_data[complete.cases(model_data), ]
 test_data <- model_data[model_result$test_idx, ]

 # Make predictions
 predictions <- stats::predict(model_result$model, data = test_data)$predictions
 actual <- test_data[[target]]

 # Calculate metrics
 residuals <- actual - predictions
 rmse <- sqrt(mean(residuals^2))
 mae <- mean(abs(residuals))
 r_squared <- 1 - sum(residuals^2) / sum((actual - mean(actual))^2)
 bias <- mean(residuals)

 # Performance by wave height category
 categories <- cut(actual,
   breaks = c(0, 2, 4, 6, Inf),
   labels = c("Low (0-2m)", "Moderate (2-4m)", "High (4-6m)", "Extreme (>6m)")
 )

 category_metrics <- data.frame(
   category = levels(categories),
   n = as.numeric(table(categories)),
   rmse = tapply(residuals, categories, function(x) sqrt(mean(x^2))),
   mae = tapply(residuals, categories, function(x) mean(abs(x))),
   stringsAsFactors = FALSE
 )

 cli::cli_alert_success("Test RMSE: {round(rmse, 3)}m, R²: {round(r_squared, 3)}")

 return(list(
   overall = data.frame(
     metric = c("RMSE", "MAE", "R_squared", "Bias", "N_test"),
     value = c(rmse, mae, r_squared, bias, length(actual))
   ),
   by_category = category_metrics,
   predictions = data.frame(
     actual = actual,
     predicted = predictions,
     residual = residuals,
     category = categories
   )
 ))
}

#' Predict Wave Height
#'
#' @description
#' Predicts wave height for new observations.
#'
#' @param model_result Result from train_wave_model
#' @param new_data Data frame with predictor values
#'
#' @return Numeric vector of predicted wave heights
#'
#' @export
predict_wave_height <- function(model_result, new_data) {

 # Check for required predictors
 missing <- setdiff(model_result$predictors, names(new_data))
 if (length(missing) > 0) {
   cli::cli_abort("Missing required predictors: {paste(missing, collapse = ', ')}")
 }

 predictions <- stats::predict(model_result$model, data = new_data)$predictions
 return(predictions)
}

#' Generate Wave Model Report
#'
#' @description
#' Creates a formatted summary report of the wave height prediction model.
#'
#' @param model_result Result from train_wave_model
#' @param eval_result Result from evaluate_wave_model
#'
#' @return Character string with formatted report
#'
#' @export
wave_model_report <- function(model_result, eval_result) {

 # Top 5 important features
 top_features <- head(model_result$importance, 5)

 report <- paste0(
   "=== Wave Height Prediction Model Report ===\n\n",
   "MODEL PERFORMANCE\n",
   "----------------\n",
   sprintf("Training R²: %.3f\n", model_result$train_r_squared),
   sprintf("OOB RMSE: %.3f m\n", model_result$oob_rmse),
   sprintf("Test RMSE: %.3f m\n", eval_result$overall$value[1]),
   sprintf("Test MAE: %.3f m\n", eval_result$overall$value[2]),
   sprintf("Test R²: %.3f\n", eval_result$overall$value[3]),
   sprintf("Test samples: %d\n\n", eval_result$overall$value[5]),
   "TOP PREDICTORS\n",
   "--------------\n"
 )

 for (i in 1:nrow(top_features)) {
   report <- paste0(report, sprintf(
     "%d. %s (importance: %.1f)\n",
     i, top_features$variable[i], top_features$importance[i]
   ))
 }

 report <- paste0(report, "\nPERFORMANCE BY WAVE HEIGHT\n")
 report <- paste0(report, "--------------------------\n")

 for (i in 1:nrow(eval_result$by_category)) {
   cat_row <- eval_result$by_category[i, ]
   report <- paste0(report, sprintf(
     "%s: RMSE=%.2fm, MAE=%.2fm (n=%d)\n",
     cat_row$category, cat_row$rmse, cat_row$mae, cat_row$n
   ))
 }

 return(report)
}

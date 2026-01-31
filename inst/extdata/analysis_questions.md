# Irish Weather Buoy Network - Analysis Questions & Answers

## Data Format Questions

### Q1: What is the best data type to download for the initial set of data?
**Answer:** CSV format via ERDDAP API is optimal for initial download because:
- Human-readable and universally supported
- Can be directly imported into DuckDB
- Includes headers with units
- Allows date range and station filtering via URL parameters
- Example: `https://erddap.marine.ie/erddap/tabledap/IWBNetwork.csv?time,station_id,AtmosphericPressure&time>=2024-01-01`

### Q2: What is the best data type to download for subsequent updates?
**Answer:** JSON format is best for incremental updates because:
- Lightweight and fast parsing
- Easy to check for duplicates using timestamps
- Can query only recent data: `&time>=max_existing_timestamp`
- Structured format simplifies error checking
- Alternative: CSV with time constraints for consistency

## Wave Analysis Questions

### Q3: Is wave height to wave period a significant risk metric?
**Answer:** Yes, the ratio is highly significant:
- **Wave Steepness** = WaveHeight / (1.56 * WavePeriod²)
- Steepness > 0.07 indicates breaking waves (dangerous)
- Short period + high waves = steep, dangerous seas
- Long period + high waves = powerful but manageable swells
- Used in marine safety assessments and vessel operations

### Q4: Is Hmax the maximum wave height?
**Answer:** Yes, Hmax is the maximum individual wave height observed during the measurement period (typically 20-30 minutes). It represents the single highest wave from trough to crest.

### Q5: What is the definition of rogue wave? Can we calculate it from this data?
**Answer:** Rogue wave definitions and detection:
- **Standard Definition:** Hmax > 2.0 * WaveHeight (significant wave height)
- **Extreme Definition:** Hmax > 2.2 * WaveHeight
- **Detection Formula:** `rogue_wave = Hmax > 2 * WaveHeight`
- **Yes, calculable** from the data using Hmax and WaveHeight columns
- Typical occurrence: 1 in 3,000 waves statistically

### Q6: What is QC definition? Is it relevant to this analysis?
**Answer:** QC_Flag is the Quality Control indicator:
- 0 = Unknown/unverified data
- 1 = Good data (passed quality checks)
- 9 = Missing value
- **Highly relevant:** Always filter for QC_Flag == 1 for reliable analysis
- Exclude QC_Flag == 9 to avoid missing data issues

## Meteorological Model Questions

### Q7: Are AirTemperature, DewPoint, SeaTemperature, RelativeHumidity related? What models to fit?
**Answer:** Yes, these are thermodynamically related:

**Relationships:**
1. `RelativeHumidity = 100 * (e_actual / e_saturation)`
2. `DewPoint = f(AirTemperature, RelativeHumidity)` via Magnus formula
3. `SeaTemperature` influences `AirTemperature` through heat flux

**Suggested Models:**
```r
# Model 1: Humidity prediction
lm(RelativeHumidity ~ poly(AirTemperature - DewPoint, 2))

# Model 2: Sea-air temperature relationship
gam(AirTemperature ~ s(SeaTemperature) + s(hour) + s(month))

# Model 3: Dew point estimation
lm(DewPoint ~ AirTemperature * RelativeHumidity)
```

### Q8: How are AtmosphericPressure and WindDirection related? What model might we fit?
**Answer:** Indirect relationship through weather systems:

**Physical Relationship:**
- Low pressure → counterclockwise wind circulation (N. Hemisphere)
- Pressure gradient drives wind, not direction directly
- Wind direction indicates frontal passages

**Suggested Models:**
```r
# Circular statistics for wind direction
library(circular)
watson.wheeler.test(WindDirection ~ cut(AtmosphericPressure, 5))

# Pressure tendency model
lm(diff(AtmosphericPressure) ~ WindSpeed + sin(WindDirection*pi/180) + cos(WindDirection*pi/180))
```

### Q9: What is the relationship between wave height and wave period?
**Answer:** Complex non-linear relationship:

**Theory:**
- Fully developed seas: `WaveHeight ∝ WavePeriod^2`
- Fetch-limited: More variable relationship
- Swell vs. wind waves have different relationships

**Stability Testing:**
```r
# Test for regime changes
library(segmented)
model <- lm(log(WaveHeight) ~ log(WavePeriod))
seg.model <- segmented(model, ~log(WavePeriod))

# Non-parametric approach
gam(WaveHeight ~ s(WavePeriod) + s(WindSpeed))
```

### Q10: Are units suitable or do we need conversion?
**Answer:** Mixed units require some conversion:

**Current Units:**
- Wind: knots (nautical miles/hour)
- Waves: meters
- Temperature: Celsius

**Recommendations:**
1. Keep as-is for maritime users (knots are standard)
2. For physics-based models, convert to SI:
   - `wind_ms = WindSpeed * 0.514`
   - Already in meters for waves (good)
3. For wave generation models: knots are fine
   - Empirical formulas often use knots directly

### Q11: Models for wind-wave relationship?
**Suggested Models:**

```r
# 1. JONSWAP empirical model
WaveHeight_predicted = 0.0016 * WindSpeed^2 * sqrt(Fetch/9.8)

# 2. Power law model
lm(log(WaveHeight) ~ log(WindSpeed) + log(Duration))

# 3. Machine learning approach
ranger(WaveHeight ~ WindSpeed + Gust + WindDirection +
       lag(WaveHeight, 1:6) + AtmosphericPressure)
```

### Q12: Best combination of inputs to predict wave height?
**Answer:** Based on physics and empirical studies:

**Primary Predictors:**
1. WindSpeed (most important)
2. Gust (indicates sea state development)
3. Previous WaveHeight (persistence)
4. WavePeriod (sea state maturity)
5. Wind duration (derived from consecutive readings)

**Best Model Structure:**
```r
# Comprehensive model
rf_model <- ranger(
  WaveHeight ~ WindSpeed + Gust + lag(WaveHeight, 1:3) +
    WavePeriod + WindDirection + AtmosphericPressure +
    diff(AtmosphericPressure) + hour(time) + month(time),
  importance = "impurity"
)

# For Hmax prediction
Hmax ~ WaveHeight * (1 + 0.5 * Gust/WindSpeed)
```

## Data Update Strategy

### Incremental Updates
- Query ERDDAP with `time > last_timestamp`
- Append only new records to DuckDB
- Use transaction for atomicity
- Maintain update log with row counts

### Comparison Metrics for Email Summary
1. **Week-over-week:** Current week vs. previous week
2. **Year-over-year:** Current week vs. same week previous years
3. **Climatology:** Current vs. long-term average for this time of year
4. **Extremes:** Flag any records exceeding 95th percentile

## Data Source

Primary data source: [Marine Institute ERDDAP Server](https://erddap.marine.ie/erddap/tabledap/IWBNetwork.html)
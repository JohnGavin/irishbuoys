# ib_hf_url snapshot

    Code
      ib_hf_url()
    Output
      [1] "hf://datasets/dsfefvx/irish-buoy-network/buoy_data.parquet"

---

    Code
      ib_hf_url("stations.json")
    Output
      [1] "hf://datasets/dsfefvx/irish-buoy-network/stations.json"

# local Parquet schema snapshot

    Code
      schema
    Output
      Schema
      time: timestamp[us, tz=UTC]
      station_id: string
      call_sign: string
      longitude: double
      latitude: double
      atmospheric_pressure: double
      air_temperature: double
      dew_point: double
      wind_direction: double
      wind_speed: double
      gust: double
      relative_humidity: double
      sea_temperature: double
      salinity: double
      wave_height: double
      wave_period: double
      mean_wave_direction: double
      hmax: double
      tp: double
      thtp: double
      sprtp: double
      qc_flag: int32


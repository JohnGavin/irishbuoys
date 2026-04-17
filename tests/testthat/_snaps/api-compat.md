# stations.json has all 5 canonical stations

    Code
      station_ids
    Output
      [1] "_meta" "data" 

# Parquet schema is stable

    Code
      col_names
    Output
       [1] "air_temperature"      "atmospheric_pressure" "call_sign"           
       [4] "dew_point"            "gust"                 "hmax"                
       [7] "latitude"             "longitude"            "mean_wave_direction" 
      [10] "qc_flag"              "relative_humidity"    "salinity"            
      [13] "sea_temperature"      "sprtp"                "station_id"          
      [16] "thtp"                 "time"                 "tp"                  
      [19] "wave_height"          "wave_period"          "wind_direction"      
      [22] "wind_speed"          

# get_station_info returns canonical station list

    Code
      sort(info$station_id)
    Output
      [1] "M2" "M3" "M4" "M5" "M6"


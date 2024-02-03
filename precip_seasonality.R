# Precipitation Seasonality
# Examine precipitation seasonality and changes in seasonality
# https://github.com/carlosdobler/Project_mixteca_precip_analysis/blob/master/02_precip_analysis.Rmd

# Seasonal Precipitation 
## Testing original code first
chirps_stars <- precip[,60:70, 60:80,]
# Seasonal precipitation for the whole region
seasonal_map <- map_df(seq_along(st_get_dimension_values(chirps_stars, "lon")), function(c){
  map_df(seq_along(st_get_dimension_values(chirps_stars, "lat")), function(r){
    
    m <- chirps_stars %>% 
      slice("lon", c) %>% 
      slice("lat", r) %>% 
      as_tibble() %>% 
      
      mutate(year = year(time)) %>% 
      group_by(year) %>% 
      mutate(doy = row_number()) %>% 
      ungroup()
    
    n <- m %>%
      group_by(doy) %>%
      summarize(daily_mean = mean(pr)) %>%
      mutate(anomaly = daily_mean - mean(m$pr),
             cum_anomaly = cumsum(anomaly)) %>%
      summarize(onset = which.min(cum_anomaly),
                cessation = which.max(cum_anomaly))

    m %>%
      mutate(seas = case_when(doy >= n$onset & doy < n$cessation ~ "wet",
                              TRUE ~ "dry"),
             year = ifelse(doy >= n$cessation, year+1, year)) %>%
      group_by(seas, year) %>%
      summarize(pr = sum(pr)) %>%
      mutate(lon = st_get_dimension_values(chirps_stars, "lon")[c],
             lat = st_get_dimension_values(chirps_stars, "lat")[r],
             c = c,
             r = r,
             onset = n$onset,
             cessation = n$cessation)

  })
}) %>% suppressMessages()


perc_seasonal <- seasonal_map %>%
  group_by(seas) %>%
  summarize(pr = mean(pr)) %>% 
  mutate(pr = pr/sum(pr)*100)

# Mean onset and cessation --> produces weird output
seasonal_map %>% 
  ungroup() %>% 
  summarize(onset = as_date(mean(onset)),
            cessation = as_date(mean(cessation))) 

####
m <- seasonal_map %>% 
  group_by(lon, lat, c, r, onset, cessation) %>% 
  dplyr::summarize() %>%
  dplyr::ungroup() %>% 
  
  pmap_df(function(onset, cessation, c, r, lon, lat){
    
    chirps_stars %>% 
      slice("lon", c) %>% 
      slice("lat", r) %>%
      
      as_tibble() %>%
      mutate(daily_mean = mean(pr),
             anomaly = pr - daily_mean,
             year = year(time)) %>%
      group_by(year) %>%
      mutate(cum_anomaly = cumsum(anomaly),
             doy = row_number()) %>%

      mutate(cum_anomaly_onset = ifelse(onset - 60 <= doy & onset + 60 >= doy, cum_anomaly, NA),
             cum_anomaly_cessation = ifelse(cessation - 60 <= doy & cessation + 60 >= doy, cum_anomaly, NA)) %>%

      summarise(onset = which.min(cum_anomaly_onset),
                cessation = which.max(cum_anomaly_cessation)) %>%

      dplyr::summarise(mk_onset = trend::mk.test(onset) %>% .$p.value,
                sen_onset = trend::sens.slope(onset) %>% .$estimates %>% as.numeric(),
                mk_cessation = trend::mk.test(cessation) %>% .$p.value,
                sen_cessation = trend::sens.slope(cessation) %>% .$estimates %>% as.numeric()) %>%

      mutate(lon = lon,
             lat = lat)
    
  })

mk <- m %>% 
  select(mk_onset, mk_cessation, lon, lat) %>% 
  gather(1:2, key = seas, val = mk) %>% 
  mutate(mk = ifelse(mk < 0.1, 1, NA),
         seas = str_sub(seas, start = 4),
         seas = factor(seas, levels = c("onset", "cessation"))) %>% 
  filter(!is.na(mk))

m %>% 
  select(sen_onset, sen_cessation, lon, lat) %>% 
  gather(1:2, key = seas, val = sen) %>% 
  mutate(seas = str_sub(seas, start = 5),
         seas = factor(seas, levels = c("onset", "cessation"))) %>% 
  
  ggplot() +
  geom_raster(aes(x = lon, y = lat, fill = sen)) +
  geom_point(data = mk, aes(x = lon, y = lat), shape = 4, alpha = 0.5) +
  scale_fill_distiller(palette = "PuOr",
                       limits = c(-1.1, 1.1),
                       direction = -1,
                       breaks = c(-1, 0, 1),
                       labels = c("-1 (later)", "0 (no change)", "1 (sooner)"),
                       name = "days/year") +
  # geom_point(data = locs, aes(x = lon, y = lat)) +
  # geom_text(data = locs, aes(x = lon, y = lat, label = loc), vjust = 1, nudge_y = -0.02, nudge_x = 0.05, size = 3) +
  facet_grid(~seas) +
  coord_quickmap()
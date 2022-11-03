library(bcdata)

bcdc_search("wildfire weather station")

stn <- bcdc_query_geodata("bc-wildfire-active-weather-stations") %>% 
  collect()

sf::st_write(stn, "data/stn.gpkg")

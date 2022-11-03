

# DOWNLOAD INITIAL DATASET
url <- "https://www.for.gov.bc.ca/ftp/HPR/external/!publish/BCWS_DATA_MART/2022/"
# url <- "ftp://ftp.for.gov.bc.ca/HPR/external/!publish/BCWS_DATA_MART/2022/"

# library(future.apply)
# date_download_end <- as.Date(now())-1
# dates <- seq(as.Date("2022-04-14"),date_download_end,by="1 day")
# plan(multisession)
# df <- do.call(bind_rows, future_lapply(dates, function(d){
#   fread(paste0(url,d,".csv"), header = T) %>% as_tibble() %>%
#     mutate(date = as.Date.character(DATE_TIME, format = "%Y%m%d"),
#            time = substr(DATE_TIME, 9,10),
#            datetime = as_datetime(paste0(date, time, ":00:00")))}))
# file.remove("data/df.rds")
# saveRDS(df, "data/df.rds")

# READ DATASET(LOCAL) 
df <- readRDS("data/df.rds")

# UPDATE DATASET (LOCAL)
# max_date <- max(df$date)
# df <- df %>% filter(date != max_date)
# update_dates <- seq(as.Date(max_date),as.Date(format(now(), format = "%Y-%m-%d")), by = "1 day")
# df_update <- do.call(bind_rows, lapply(update_dates, function(d){
#   f <- tempfile(fileext = ".csv")
#   curl::curl_download(paste0(url,d,".csv"), f)
#   fread(f, header = T) %>% as_tibble() %>%
#   # d <- update_dates[3]
#   # print(d)
#   # fread(paste0(url,d,".csv"), header = T) %>% as_tibble() %>%
#     mutate(date = as.Date.character(DATE_TIME, format = "%Y%m%d"),
#            time = substr(DATE_TIME, 9,10),
#            datetime = as_datetime(paste0(date, time, ":00:00")))}))
# df <- bind_rows(df, df_update)

# VARS

vars <- c("PRECIPITATION",
          "TEMPERATURE",
          "RELATIVE_HUMIDITY",
          "WIND_SPEED",
          "WIND_DIRECTION",
          # "FINE_FUEL_MOISTURE_CODE",
          # "INITIAL_SPREAD_INDEX",
          # "FIRE_WEATHER_INDEX",
          # "DUFF_MOISTURE_CODE",
          # "DROUGHT_CODE",
          # "BUILDUP_INDEX",
          # "DANGER_RATING",
          # "RN_1_PLUVIO1",
          "SNOW_DEPTH"#,
          # "SNOW_DEPTH_QUALITY",
          # "PRECIP_PLUVIO1_STATUS",
          # "PRECIP_PLUVIO1_TOTAL",
          # "RN_1_PLUVIO2",
          # "PRECIP_PLUVIO2_STATUS",
          # "PRECIP_PLUVIO2_TOTAL",
          # "RN_1_RIT",
          # "PRECIP_RIT_STATUS",
          # "PRECIP_RIT_TOTAL",
          # "PRECIP_RGT",
          # "SOLAR_RADIATION_LICOR",
          # "SOLAR_RADIATION_CM3"
)


# JOIN 
stn <- read_sf("data/stn.gpkg") %>% 
  mutate(STATION_ID = paste0(STATION_NAME, " ID:",STATION_CODE))
stn_name <- stn %>% st_drop_geometry() %>% select(STATION_CODE, STATION_NAME)

df <- df %>% full_join(stn_name)


# IDS 
df <- df %>% 
  mutate(STATION_ID = paste0(STATION_NAME, " ID:",STATION_CODE))


# NO DATA STATIONS
# stn_name_no_data <- df %>% filter(is.na(DATE_TIME)) %>% select(STATION_ID) %>% pull()

# NO COORDS STATIONS 
# stn_name_nocoords = full_join(stn %>% st_drop_geometry() %>% select(STATION_ID) %>% mutate(stn = "stn"),
#                               df %>% select(STATION_ID, STATION_CODE) %>% group_by(STATION_ID, STATION_CODE) %>% summarize() %>% mutate(df = "df")) %>% 
#   filter(is.na(stn)) %>% select(STATION_CODE) %>% pull() %>% sort()

# GOOD STATIONS 
df <- df %>% filter(!is.na(DATE_TIME))

ids <- sort(unique(df$STATION_ID))

# NRD

# nrd <- nr_districts() %>%
#   mutate(ORG_UNIT_NAME = gsub(" Natural Resource District", "",ORG_UNIT_NAME)) %>% 
#   st_cast("POLYGON") %>% 
#   mutate(n = row_number()) 
# 
# nrd <- nrd %>% 
#   mutate(ORG_UNIT_NAME = case_when(ORG_UNIT_NAME == "Skeena Stikine" & n == 17 ~ "Skeena Stikine 1",
#                                    ORG_UNIT_NAME == "Skeena Stikine" & n == 18 ~ "Skeena Stikine 2",
#                                    TRUE ~ ORG_UNIT_NAME))
# 
# st_write(nrd, "data/nrd.gpkg")
nrd <- st_read("data/nrd.gpkg")

# COLORS
mycolors <- c("#4E79A7","#A0CBE8","#F28E2B","#FFBE7D","#59A14F","#8CD17D","#B6992D",
              "#F1CE63","#499894","#86BCB6","#E15759","#FF9D9A","#79706E","#BAB0AC",
              "#D37295","#FABFD2","#B07AA1","#D4A6C8","#9D7660","#D7B5A6")

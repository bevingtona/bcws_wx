library(RcppRoll)
library(tmap)
library(data.table)
library(lubridate)
library(sf)
library(dplyr)
library(rbokeh)
library(leaflet)
library(curl)

source("prep.R")

ui <- fluidPage(
  navbarPage(
    theme = "css/bcgov.css",
    title = "BCWS WX DATA (Draft)",
    id = "bcws_wx",
    header = HTML("<h2>BC Wildfire Service Weather Station Data (Draft)</h2>"),
    tabPanel(
      "Realtime Data",
      fluidRow(
        column(3,
               selectInput(
                 "siteID",
                 label="Add/remove station(s):",
                 choices=ids,
                 selected = "SUMMIT ID:11",
                 multiple = TRUE),
               selectInput(
                 "nrdID",
                 label="Select all stations from district (optional):",
                 choices=c("",sort(nrd$ORG_UNIT_NAME)),
                 selected = "",
                 multiple = F),
               selectInput(
                 "variableID",
                 label="Select variable:",
                 choices=vars,
                 selected = vars[1]),
               selectInput(
                 "aggregateID",
                 label="Rolling time window (lower plot):",
                 choices=c("1 hour","12 hours","24 hours","2 days", "1 week"),
                 selected = "24 hours"),
               selectInput(
                 "statisticID",
                 label="Rolling statistic (lower plot):",
                 choices=c("mean","max","min","sum"),
                 selected = "sum"),
               dateRangeInput(
                 "dates",
                 label = "Date range:",
                 start = as.Date(now())-10,
                 end = as.Date(now())),
               leafletOutput("mapStns")),
        column(9,
               rbokehOutput("distPlot"),
               rbokehOutput("rollingPlot"),
               downloadButton("downloadData", paste("Download Hourly CSV")),
               p(),strong("Source:"),em("https://www.for.gov.bc.ca/ftp/HPR/external/!publish/BCWS_DATA_MART/2022/"),
               p("Data comes with no guarantees of quality or reliability. Use at your own risk. Read disclaimer below.")
               )
        )
      ),
    tags$head(tags$script(src="js/bcgov.js")),
    tags$head(tags$link(rel="shortcut icon", href="/images/favicon.ico")),
    footer = HTML('<div id="footer">
                               <img src="images/back-to-top.png" alt="Back to top" title="Back to top" class="back-to-top footer-overlap" style="bottom: 10px; display: inline;">
                               <div id="footerWrapper">
                               <div id="footerAdminSection">
                               <div id="footerAdminLinksContainer" class="container">
                               <div id="footerAdminLinks" class="row">
                               <ul class="inline">
                               <li data-order="0">
                               <a href="//www2.gov.bc.ca/gov/content/home/disclaimer" target="_self">Disclaimer</a>
                               </li>
                               <li data-order="1">
                               <a href="//www2.gov.bc.ca/gov/content/home/privacy" target="_self">Privacy</a>
                               </li>
                               <li data-order="2">
                               <a href="//www2.gov.bc.ca/gov/content/home/accessibility" target="_self">Accessibility</a>
                               </li>
                               <li data-order="3">
                               <a href="//www2.gov.bc.ca/gov/content/home/copyright" target="_self">Copyright</a>
                               </li>
                               </ul>
                               </div>
                               </div>
                               </div>
                               </div>
                               </div>')
    )
)

server <- function(input, output, session) {
  
  output$distPlot <- renderRbokeh({
    
    df_sub <- df %>%
      filter(STATION_ID %in% input$siteID) %>%
      mutate(STATION_ID = as.character(STATION_ID)) %>%
      filter(date >= input$dates[1]) %>%
      filter(date <= input$dates[2]) %>%
      rename(var = input$variableID) %>%
      select(STATION_ID, datetime, var)
    
    df_sub$STATION_ID <- factor(df_sub$STATION_ID, levels = input$siteID)
    
    df_sub$color <- mycolors[match(df_sub$STATION_ID, input$siteID)]
    
    if(nrow(df_sub)>=1){
      figure(title = paste("Hourly Data (most recent:", max(df_sub$datetime),")"), width = 1600, height = 600,
             legend_location = "top_left",
             tools = c("pan", "wheel_zoom", "box_zoom", "reset", "save")) %>%
        ly_lines(datetime, var, data = df_sub, group = STATION_ID) %>%
        ly_points(datetime, var, data = df_sub,
                  hover = list(datetime, STATION_ID, var), 
                  color = STATION_ID) %>%
        set_palette(discrete_color = pal_color(mycolors)) %>% 
        theme_legend(label_text_font_size = "10pt") %>% 
        x_axis(label = "") %>%
        y_axis(paste(input$variableID, "Hourly"))}
  })
  
  output$rollingPlot <- renderRbokeh({
    
    hours <- tibble(id = c("1 hour", "12 hours", "24 hours", "2 days", "1 week"),  
                    hours = c(1,12,24,48,168)) %>% 
      filter(id == input$aggregateID) %>% 
      select(hours) %>% pull()
    
    df_sub <- df %>%
      filter(STATION_ID %in% input$siteID) %>%
      mutate(STATION_ID = as.character(STATION_ID)) %>%
      filter(date >= input$dates[1]) %>%
      filter(date <= input$dates[2]) %>%
      rename(var = input$variableID) %>%
      select(STATION_ID, datetime, var)
    
    df_sub_adj <- df_sub %>%
      arrange(datetime) %>%
      group_by(STATION_ID) %>%
      mutate(
        mean = roll_mean(var, hours, align = "right", fill = NA, na.rm = T),
        min = roll_min(var, hours, align = "right", fill = NA, na.rm = T),
        max = roll_max(var, hours, align = "right", fill = NA, na.rm = T),
        sum = roll_sum(var, hours, align = "right", fill = NA, na.rm = T)) %>%
      rename(myvar = input$statisticID) %>%
      select(STATION_ID, datetime, myvar)
    
    df_sub_adj$STATION_ID <- factor(df_sub_adj$STATION_ID, levels = input$siteID)
    
    df_sub_adj$color <- mycolors[match(df_sub_adj$STATION_ID, input$siteID)]
    
    if(nrow(df_sub_adj)>=1){
      figure(title = paste("Rolling Statistics (most recent:", max(df_sub$datetime),")"), 
             width = 1600, height = 600,
             legend_location = "top_left",
             tools = c("pan", "wheel_zoom", "box_zoom", "reset", "save")) %>%
        ly_lines(datetime, myvar, data = df_sub_adj, group = STATION_ID) %>%
        ly_points(datetime, myvar, data = df_sub_adj,
                  hover = list(datetime, STATION_ID, myvar),
                  color = STATION_ID) %>%
        set_palette(discrete_color = pal_color(mycolors)) %>% 
        theme_legend(label_text_font_size = "10pt") %>% 
        x_axis(label = "") %>%
        y_axis(paste(input$variableID, "Rolling", input$statisticID))}
    
  })
  
  # STN MAP
  output$mapStns <- renderLeaflet({
    stn_map <- stn %>%
      filter(STATION_ID %in% ids) %>% 
      mutate(group = case_when(STATION_ID %in% input$siteID ~ "selected", 
                               TRUE ~ ""))
    stn_map_selected <- select(stn_map, c("STATION_ID","group", "ELEVATION")) %>% 
      filter(group == "selected")
    stn_map_not <- select(stn_map, c("STATION_ID","group", "ELEVATION")) %>% 
      filter(group == "")
    
    stn_map_selected$STATION_ID <- factor(stn_map_selected$STATION_ID, levels = input$siteID)
    
    if(nrow(stn_map_selected)>=1){
      tmap_leaflet(
        tm_shape(nrd, bbox = stn_map_selected %>% st_buffer(50000) %>% st_bbox()) +
          tm_borders() +
          tm_text("ORG_UNIT_NAME", scale=1) +
          tm_shape(stn_map_selected) +
          tm_symbols(col = "STATION_ID", palette = mycolors, size = 1.5, legend.col.show = FALSE, 
                     popup.vars = FALSE) + 
          tm_shape(stn_map_not) + 
          tm_symbols(size = 1.5, popup.vars = FALSE))}else{
            tmap_leaflet(
              tm_shape(stn_map_not) + 
                tm_symbols(size = 1.5, popup.vars = FALSE))
          }
    
  })
  
  output$downloadData <- downloadHandler(
    
    filename = function() {
      gsub("ID:","",gsub("-","",paste("BCWS_WX_DOWNLOAD_", 
                                      input$variableID, "_",
                                      input$dates[1], "_",
                                      input$dates[2],
                                      ".csv", sep = "")))
    },
    content = function(file) {
      write.csv(df %>%
                  filter(STATION_ID %in% input$siteID) %>%
                  mutate(STATION_ID = as.character(STATION_ID)) %>%
                  filter(date >= input$dates[1]) %>%
                  filter(date <= input$dates[2]) %>%
                  select(STATION_ID, datetime, input$variableID) %>% 
                  arrange(datetime),
                file, row.names = FALSE)
    }
  )
  
  
  # CLICK ON MAP TO ADD/REMOVE SITES
  observeEvent(input$mapStns_shape_click, { 
    p <- input$mapStns_shape_click  # typo was on this line
    i = gsub("."," ",gsub("ID.","ID:",p$id), fixed = T)
    print(i)
    
    if(i %in% input$siteID){
      updateSelectizeInput(inputId = "siteID", selected = input$siteID[input$siteID!=i])
    }else{
      updateSelectizeInput(inputId = "siteID", selected = c(input$siteID,i))}
  })
  
  observeEvent(input$nrdID, { 
    
    if(input$nrdID != ""){
      nrd_stn <- stn[stn %>% st_intersects(nrd %>% filter(ORG_UNIT_NAME %in% input$nrdID), sparse = F),]
      
      updateSelectizeInput(inputId = "siteID", selected = nrd_stn$STATION_ID)}
  })
  
  
  
}

shinyApp(ui = ui, server = server)

library(tidyverse)
library(rvest)

## Download and merge every year, selected tables of nhanes data into one R Datafile =====

years <- c(
  "1999-2000", "2001-2002", "2003-2004", "2005-2006", "2007-2008", "2009-2010", "2011-2012", "2013-2014", "2015-2016", "2017-2018"
)
alphabet_codes <-  c("", paste0("_", LETTERS[-1]))

file_names <- c(
  # "DEMO", # Demographic information, including survey weighting - not included because needed to generate unique 
  "HOQ",  # Housing conditions 
  "OCQ",  # Occupational information
  "MCQ",  # Medical conditions
  "AUX"   # Audiology test results
)

every_year <- data.frame()

for (y in 1:length(years)) {
  
  year <- years[y]
  year_code <- alphabet_codes[y]
  
  download.file(paste0("https://wwwn.cdc.gov/nchs/nhanes/",year,"/", "DEMO", year_code,".XPT"), tf <- tempfile(), mode = "wb")
  survey <- foreign::read.xport(tf)
  survey$year <- year
  
  for (f in file_names) {    
    try({
      download.file(paste0("https://wwwn.cdc.gov/nchs/nhanes/",year,"/", f, year_code,".XPT"), tf <- tempfile(), mode = "wb")
      table <- foreign::read.xport(tf)
      survey <- survey %>% left_join(table, by = "SEQN")
    })
  }
  
  every_year <- every_year %>% bind_rows(survey)
  
}

write_rds(every_year, paste0("nhanes/all.rds"))

## Generate documentation list of column names =====
columnn_short_names = names(every_year)

component_names <- c(
  "Demographics",
  "Questionnaire",  
  "Examination"
)

variable_listing <- data.frame()

for (component in component_names) {
  variable_list_page <- read_html(paste0("https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=", component))
  variable_listing <- variable_list_page %>% 
    html_node("#GridView1") %>% 
    html_table() %>% 
    filter(`Variable Name` %in% columnn_short_names && !(`Variable Name` %in% variable_listing$`Variable Name`)) %>%
    bind_rows(variable_listing)
}

variable_listing %>% select(`Variable Name`, `Variable Description`) %>% distinct(across(`Variable Name`), .keep_all = T) %>% write_csv("nhanes/column_info.csv")




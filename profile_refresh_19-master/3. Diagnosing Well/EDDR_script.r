# Download and load packages --------------------------------------------------

#install.packages("easypackages")
#install.packages("tidyverse")
#install.packages("data.table")
#install.packages("PHEindicatormethods")
#install.packages("readxl")
#install.packages("xlsx")
#install.packages("fingertipsR")
#install.packages("odbc")
#install.packages("dataframes2xls")
#install.packages("outliers")
#install.packages("gdata")

library(easypackages)
library(fingertipsR)
library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(dplyr)
library(odbc)
library(dataframes2xls)
library("outliers")
library(htmlTable)
library(gdata)

# Set variables ---------------------------------------------------------------

Year <- 2019

Month <- "february"

Save_path <- "/QA/Katies_Stuff/automated/"

Indicator_num <- 92849

Data_source <- "https://digital.nhs.uk/data-and-information/publications/statistical/recorded-dementia-diagnoses/february-2019"

AgeID <- 27

SexID <- 4

Directory_output <- "Z:/04 Key Projects/Dementia&Neurology/Dementia/Dementia Work/Projects/201819/profile_refresh_19/PHOLIO/To_QA/"

# These variables will generally default to these values but check to see if anything changes

YearRange <- 1

Quarter <- -1

Month <- -1

LowerCI99_8 <- -1

UpperCI99_8 <- -1

Denominator_2 <- -1

ValueNote <- 0

CategoryType <- -1

CategoryId <- -1

# Automatically set variables -------------------------------------------------

Link <- "https://digital.nhs.uk/data-and-information/publications/statistical/recorded-dementia-diagnoses/"

Month_short <- substr(Month,1,3)

File_name <- paste("dem-diag-sum-",Month_short,"-",Year,".xlsx", sep="")

Link_download_file <- paste(Link, Month, "-", Year,"/", File_name, sep="")


# Download data and format-----------------------------------------------------

ds <- fread("QA/Katies_Stuff/automated/92949/dem-diag-sum-Feb-2019.csv", skip = 8, select = c(1:9), header = TRUE)

NA_ds <- ds[!complete.cases(ds), ]

ds <- na.omit(ds)

PHOLIO_template <- read_excel("Z:/04 Key Projects/Dementia&Neurology/Dementia/Dementia Work/Projects/201819/profile_refresh_19/QA/Katies_Stuff/PHOLIO_SHEET.xlsx", sheet = 1)

# Rename ds columns -----------------------------------------------------------

ds <- ds %>%
  rename(AreaCode = `ONS Code`, Count = Recorded, Denominator = Estimated, Value = `Rate (%)`, `LowerCI95` = Lower, `UpperCI95` = Upper)

PHOF <- merge(PHOLIO_template, ds, all = TRUE ) %>%
  distinct()

PHOF$IndicatorID <- Indicator_num

PHOF$Year <- Year

PHOF$SexID <- SexID

PHOF$Month <- Month

PHOF$AgeID <- AgeID

PHOF$YearRange <- YearRange

PHOF$Quarter <- Quarter

PHOF$Month <- Month

PHOF$LowerCI99_8 <- LowerCI99_8

PHOF$UpperCI99_8 <- UpperCI99_8

PHOF$Denominator_2 <- Denominator_2

PHOF$ValueNoteId <- ValueNote

PHOF$CategoryTypeId <- CategoryType

PHOF$CategoryId <- CategoryId

PHOF <- PHOF[,c(1:19)]

PHOF <- PHOF[,c("IndicatorID", 	"Year", 	"YearRange", 	"Quarter", 	"Month", 	"AgeID", 	"SexID", 	"AreaCode", 	"Count", 	"Value", 	"LowerCI95", 	"UpperCI95", 	"LowerCI99_8", "UpperCI99_8", 	"Denominator", 	"Denominator_2", 	"ValueNoteId", 	"CategoryTypeId", 	"CategoryId")] %>%
  
PHOF <- distinct(PHOF)

# Export to CSV in to QA folder -----------------------------------------------

write_excel_csv(PHOF,paste(Directory_output,Indicator_num,"_CCG_LA.xls", sep = ""), na = "NA", append = FALSE, col_names =  TRUE)

# Delete unneeded objects from global envrionment -----------------------------


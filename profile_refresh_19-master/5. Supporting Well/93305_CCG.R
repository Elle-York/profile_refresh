
# Indicator 93305 CCG ---------------------------------------------------------

# Age standardised rate of emergency inpatient hospital admissions of people 
# (aged 65+) with a mention of dementia per 100,000 population
# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Read in SQL output (saved as CSV file)------------------------------------

df <- fread("SQLoutput/93305_CCG.csv") # change for each indicator

names(df) # Check column headings of SQL output, differs every time!
glimpse(df)

df <- df %>% arrange(areacode)


# 3. Convert to PHOLIO --------------------------------------------------------


df <- df %>%
  transmute(IndicatorID = 93305, # Your Indicator no. here
            Year = period, # The year in the SQL output
            YearRange = 1, # 1 = Annual
            Quarter = -1,
            Month = -1, 
            AgeID = 27, # Check age group
            SexID = 4, # 4 = ALL
            AreaCode = areacode,
            Count = count,
            Value = dsr, # Change
            LowerCI95 = lowerci,
            UpperCI95 = upperci,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = denominator,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 4. Save to PHOLIO csv -------------------------------------------------------


write.xlsx(df,file = "93305_CCG.xlsx", sheetName = "PHOLIO")

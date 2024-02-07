
# Indicator 91887 CCG ---------------------------------------------------------

# Deaths in Usual Place of Residence: Percentage of deaths of people 
# with a recorded mention of dementia (aged 65+)
# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Read in SQL output (saved as CSV file)------------------------------------

df <- fread("SQLoutput/91887_CCG.csv") # change for each indicator

names(df) # Check column headings of SQL output, differs every time!
glimpse(df)

# 3. Convert to PHOLIO --------------------------------------------------------


df <- df %>%
  transmute(IndicatorID = 91887, # Your Indicator no. here
            Year = year, # The year in the SQL output
            YearRange = 1, # 1 = Annual
            Quarter = -1,
            Month = -1, 
            AgeID = 27, # Check age group
            SexID = 4, # 4 = ALL
            AreaCode = areacode,
            Count = count,
            Value = value, # Change
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


write.xlsx(df,file = "91887_CCG.xlsx", sheetName = "PHOLIO")

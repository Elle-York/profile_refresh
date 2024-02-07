
# Indicator 93306 CCG ---------------------------------------------------------

# Percentage of emergency inpatient admissions for people (aged 65+) 
# with dementia that are short stays (1 night or less)
# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Read in SQL output (saved as CSV file)------------------------------------

df <- fread("SQLoutput/93306_CCG.csv") # change for each indicator

names(df) # Check column headings of SQL output, differs every time!
glimpse(df)

df <- df %>% arrange(areacode)


# 3. Convert to PHOLIO --------------------------------------------------------


df <- df %>%
  transmute(IndicatorID = 93306, # Your Indicator no. here
            Year = fyear, # The year in the SQL output
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


write.xlsx(df,file = "93306_CCG.xlsx", sheetName = "PHOLIO")

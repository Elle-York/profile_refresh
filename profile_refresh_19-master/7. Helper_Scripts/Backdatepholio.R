# Any indicator ---------------------------------------------------------------


# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Read in SQL output (saved as CSV file)------------------------------------

df <- read_xlsx("SQLoutput/93307to93309.xlsx",
                sheet = 3) # change for each indicator

names(df) # Check column headings of SQL output, differs every time!
glimpse(df)

df <- df %>% arrange(Period, AreaCode) # Only do as necessary



# 3. Convert to PHOLIO --------------------------------------------------------


df <- df %>%
  transmute(IndicatorID = 93309, # Your Indicator no. here
            Year = Period, # The year in the SQL output
            YearRange = 1, # 1 = Annual
            Quarter = -1,
            Month = -1, 
            AgeID = 27, # Check age group
            SexID = 4, # 4 = ALL
            AreaCode = AreaCode,
            Count = Count,
            Value = DSR, # Change
            LowerCI95 = LowerCI,
            UpperCI95 = UpperCI,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = Denominator,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 4. Save to PHOLIO csv -------------------------------------------------------


write.xlsx(df,file = "93309_CCGbackdate.xlsx", sheetName = "PHOLIO") # Change every time

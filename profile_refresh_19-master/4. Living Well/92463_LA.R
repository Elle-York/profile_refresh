
# Indicator 92463 LA ----------------------------------------------------------

# Carer-reported quality of life score for people caring for someone with dementia
# Score is out of 12
# Run each section one at a time and double check correct data files imported!

# 1. Load packages ------------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(xlsx)
library(lubridate)


# 2. Import data --------------------------------------------------------------

df <- read_xlsx("Data/SACE_QoL_annex_2016-17.xlsx", # PSS SACE data
                sheet = 2, 
                skip = 4)
                
# 3. Select columns -----------------------------------------------------------

df <- df %>% select(2:3, 7:9) # select five columns (check this is right!)

names(df) <- c("LA_Code", "LA_Name", "Score", "Marg_of_Error", "Respondents") # Rename columns

glimpse(df) # check data type correct


# 4. Clean the data -----------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values

df <- na.omit(df) #  Remove na values

df <- df[order(df$LA_Code), ] 


# 5. Confidence Intervals -----------------------------------------------------


df$LCI <- (df$Score - df$Marg_of_Error) # LCI
df$UCI <- (df$Score + df$Marg_of_Error) # UCI

glimpse(df) # check column data types and names are fine

# 6. Create PHOLIO sheet ------------------------------------------------------

# Change outputs below as necessary...

df <- df %>%
  transmute(IndicatorID = 92463,
            Year = 2018,
            YearRange = 1,
            Quarter = -1,
            Month = -1,  
            AgeID = 168,
            SexID = 4,
            AreaCode = LA_Code,
            Count = -1,
            Value = Score,
            LowerCI95 = LCI,
            UpperCI95 = UCI,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = -1,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 7. Save to PHOLIO sheet -----------------------------------------------------

write.xlsx(df,file = "92463_LA.xlsx", sheetName = "PHOLIO")


























# Indicator 93043 CCG ---------------------------------------------------------

# Dementia: Percentage of residential care and nursing home beds 
# suitable for a person with dementia, aged 65+
# which have received a rating from the Care Quality Commission.
# Run each section one at a time and double check correct data files imported!

# Libraries -------------------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(xlsx)
library(lubridate)
library(readxl)

# 1. Import data as of Dec 31st -----------------------------------------------

df <- read_xlsx("Data/HSCA Active Locations January 2019.xlsx",
                sheet = 2) # CQC data

LUP <- fread("LUPS/CCGLUP18.csv") # CCG look-up


# 2. Select Columns -----------------------------------------------------------

df <- df %>% 
  select ('Location ID',
          'Care home?',
          'Care homes beds',
          'Location Type/Sector',
          'Location Inspection Directorate',
          'Location Primary Inspection Category',
          'Location Latest Overall Rating',
          'Location ONSPD CCG Code',
          'Location ONSPD CCG',
          'Service user band - Dementia',
          'Service user band - Older People') 


# 3. Filter rows --------------------------------------------------------------

df <- df %>% 
  filter(`Care home?`== "Y") %>% # 
  filter(`Location Type/Sector` == 'Social Care Org') %>% 
  filter(`Location Inspection Directorate` == 'Adult social care') %>% 
  filter(`Location Primary Inspection Category` == 'Residential social care') %>% 
  filter(`Service user band - Dementia` == "Y") %>%
  filter(`Service user band - Older People` == "Y") 


# 4. Inspect column contents --------------------------------------------------

unique(length(df$`Location ID`)) # 7018
sum(df$`Care homes beds`) # 305,592 beds

# 5. Amend Latest Overall Rating Column ---------------------------------------

df$`Location Latest Overall Rating`[is.na(df$`Location Latest Overall Rating`)] <- "Not Assessed"

table(df$`Location Latest Overall Rating`) 

4805 + 137 + 411 + 190 +1475 # 7018 homes

# 6. Amend CCG Code and Name Column -------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 6 homes

# Needs doing every year!
# Check for CCG codes which are missing for the care homes
# Find the CCG code and then enter the details below
# Code in CCG look-ups section


df <- df %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-3998163914", "E38000009", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5400435927", "E38000132", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5407980962", "E38000118", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5563089061", "E38000198", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5779176410", "E38000019", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5865334746", "E38000050", `Location ONSPD CCG Code`)) 


# 7. Drop Columns -------------------------------------------------------------

names(df)
df <- df %>% 
  select(`Location ID`,
         `Care homes beds`,
         `Location Latest Overall Rating`,
         `Location ONSPD CCG Code`)


# 8. Check for NA values ------------------------------------------------------

df[!complete.cases(df), ] # No NA values - Yipee!!


# 9. Spread ratings column ----------------------------------------------------

df <- df %>% spread(`Location Latest Overall Rating`, `Care homes beds`)

df[is.na(df)] <- 0 # Fill NA cells with 0

# 10. Add England column ------------------------------------------------------

df["Eng_Code"] <- "E92000001"

# 11. Join data with CCG look-up  ---------------------------------------------


df <- left_join(df, LUP, by = c("Location ONSPD CCG Code" = "CCG18CD"))

# 12. Select cols and tidy up dataset -----------------------------------------

df <- df %>%
  select(Code = `Location ONSPD CCG Code`,
         STP18CD,
         Eng_Code,
         Good,
         Inadequate,
         `Not Assessed`,
         Outstanding,
         `Requires improvement`)

# 13. Aggregate by Area -------------------------------------------------------

CCG <- df %>%
  group_by(Code) %>%
  summarise(Good = sum(Good), 
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code,
         Good,
         Inadequate,
         `Not Assessed`,
         Outstanding,
         `Requires improvement`)


STP <- df %>%
  group_by(STP18CD) %>%
  summarise(Good = sum(Good), 
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`))%>% 
  select(Code = STP18CD,
         Good,
         Inadequate,
         `Not Assessed`,
         Outstanding,
         `Requires improvement`)
 

Eng <- df %>%
  group_by(Eng_Code) %>%
  summarise(Good = sum(Good), 
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`))%>% 
  select(Code = Eng_Code,
         Good,
         Inadequate,
         `Not Assessed`,
         Outstanding,
         `Requires improvement`)



df <- CCG %>%
  bind_rows(STP) %>%
  bind_rows(Eng) 
  
# 14. Create value columns ----------------------------------------------------

df <- df %>%
  mutate(Assess_Count = Good + Inadequate + Outstanding + `Requires improvement`) %>% 
  mutate(Total_Beds = Good + Inadequate + Outstanding + `Requires improvement` +`Not Assessed`) %>% 
  mutate(Assessed = Assess_Count/Total_Beds * 100)

# 15. Create confidence intervals ---------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Assess_Count, Total_Beds)) %>%
  mutate(Lower = Lower1 * 100) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Assess_Count, Total_Beds)) %>%
  mutate(Upper = Upper1 * 100) %>%
  mutate(Upper1 = NULL)

# 16. Create PHOLIO sheet -----------------------------------------------------

df <- df %>%
transmute(IndicatorID = 93043,
          Year = 2018,
          YearRange = 1,
          Quarter = -1,
          Month = -1, 
          AgeID = 27,
          SexID = 4,
          AreaCode = Code,
          Count = Assess_Count,
          Value = Assessed,
          LowerCI95 = Lower,
          UpperCI95 = Upper,
          LowerCI99_8 = -1,
          UpperCI99_8 = -1,
          Denominator = Total_Beds,
          Denominator_2 = -1,
          ValueNoteId = 0,
          CategoryTypeId = -1,
          CategoryId = -1)

# 17. Save to PHOLIO csv ------------------------------------------------------

write.xlsx(df,file = "93043_CCG.xlsx", sheetName = "PHOLIO")




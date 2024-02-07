
# Indicator 93040 CCG ---------------------------------------------------------

# Dementia: Percentage of residential care and nursing home beds 
# Suitable for a person with dementia, aged 65+
# Which received an overall rating of ‘good’ or ‘outstanding’ 
# From the Care Quality Commission.
# Run each section one at a time and double check correct data files imported!

# Libraries -------------------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(xlsx)
library(lubridate)
library(readxl)

# 1. Import December data -----------------------------------------------------

df <- read_xlsx("Data/HSCA Active Locations January 2019.xlsx",
                sheet = 2) # CQC Filters file as of 31st Dec, 2018

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

glimpse(df) # Check column data types correct
unique(length(df$`Location ID`)) # 7018
sum(df$`Care homes beds`) # 305592 beds

# 5. Fill blank cells in Overall Rating Column --------------------------------

df$`Location Latest Overall Rating`[is.na(df$`Location Latest Overall Rating`)] <- "Not Assessed"


table(df$`Location Latest Overall Rating`) 

# Good = 4805 homes
# Inadequate = 137
# Outstanding = 190
# Req Improvement = 1475
# Not Assessed = 411

4805 + 137 + 190 + 1475 + 411

# 6. Amend CCG Code and Name Column -------------------------------------------

# Needs doing every year!
# Check for CCG codes which are missing for the care homes
# Find the CCG code and then enter the details below
# Code in CCG look-ups section

# df$`Location ONSPD CCG Code`[which(df$`Location ONSPD CCG Code` == "")] <- NA # if there are any missing codes, fill with NA

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 6 homes with no CCG code

# replace dataset with missing information

df <- df %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-3998163914", "E38000009", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5400435927", "E38000132", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5407980962", "E38000118", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5563089061", "E38000198", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5779176410", "E38000019", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5865334746", "E38000050", `Location ONSPD CCG Code`)) 

CCG_names <- as.tibble(unique(df$`Location ONSPD CCG Code`)) # Check you've got the correct amount of CCGs


# 7. Drop Columns -------------------------------------------------------------

df <- df %>% 
  select(Loc_ID = `Location ID`,
         Beds = `Care homes beds`,
         CCG_Code = `Location ONSPD CCG Code`,
         Rating = `Location Latest Overall Rating`)


# 8. Spread contents of rating column -----------------------------------------

df <- df %>% 
  spread(Rating, Beds)


df[is.na(df)] <- 0 # Fill all empty fields with 0



# 9. Merge with CCG look up ---------------------------------------------------


df <- left_join(df, LUP, by = c("CCG_Code" = "CCG18CD"))


# 10. Create England column ---------------------------------------------------


df <- df %>% mutate(England = 'E92000001')


# 11. Aggregate Areas ---------------------------------------------------------

CCG <- df %>%
  group_by(CCG_Code) %>% 
  summarise(Good = sum(Good),
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = CCG_Code,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)



STP <- df %>%
  group_by(STP18CD) %>%
  summarise(Good = sum(Good),
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = STP18CD,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)



England <- df %>%
  group_by(England) %>%
  summarise(Good = sum(Good),
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = England,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)

# 12. Bring them all together

df <- CCG %>%
  bind_rows(STP) %>%
  bind_rows(England) 


# 13. Create value columns ----------------------------------------------------

df <- df %>%
  mutate(Quality = Outstanding + Good) %>% 
  mutate(Beds = Outstanding + Good + `Requires improvement` + Inadequate + `Not Assessed`) %>% 
  mutate(Value = Quality/Beds * 100)

# 14. Create confidence intervals ---------------------------------------------


df <- df %>%
  mutate(Lower1 = wilson_lower(Quality, Beds)) %>%
  mutate(Lower = Lower1 * 100) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Quality, Beds)) %>%
  mutate(Upper = Upper1 * 100) %>%
  mutate(Upper1 = NULL)

# 15. Create PHOLIO sheet -----------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 93040,
            Year = 2018,
            YearRange = 1,
            Quarter = -1,
            Month = -1,
            AgeID = 27,
            SexID = 4,
            AreaCode = Code,
            Count = Quality,
            Value = Value,
            LowerCI95 = Lower,
            UpperCI95 = Upper,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = Beds,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 16. Save to PHOLIO csv ------------------------------------------------------


write.xlsx(df,file = "93040_CCG.xlsx", sheetName = "PHOLIO")






























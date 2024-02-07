
# Indicator 93041 CCG ---------------------------------------------------------

# The number of residential care home and nursing home beds, 
# per 100 persons registered with dementia (aged 65+). 
# Run each section one at a time and double check correct data files imported!

# Libraries -------------------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(xlsx)
library(lubridate)
library(readxl)

# 1. Import data - as of Dec 31st snapshot ------------------------------------

num <- read_xlsx("Data/HSCA Active Locations January 2019.xlsx", # CQC data
                sheet = 2)

dem <- fread("Data/rec-dem-diag-Dec-2018-csv.csv") # NHSD dem 65+ data

LUP <- fread("LUPS/CCGLUP18.csv") # CCG look-up


# 2. Select numerator columns -------------------------------------------------

num <- num %>% 
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


# 3. Filter numerator rows ----------------------------------------------------

num <- num %>% 
  filter(`Care home?`== "Y") %>% # 
  filter(`Location Type/Sector` == 'Social Care Org') %>% 
  filter(`Location Inspection Directorate` == 'Adult social care') %>% 
  filter(`Location Primary Inspection Category` == 'Residential social care') %>% 
  filter(`Service user band - Dementia` == "Y") %>%
  filter(`Service user band - Older People` == "Y") %>%
  select(`Location ID`,
         `Location ONSPD CCG Code`,
         `Care homes beds`)

# 4. Inspect column contents --------------------------------------------------

glimpse(num) # Check column data types correct
unique(length(num$`Location ID`)) # 7018 homes
sum(num$`Care homes beds`) # 305,592 beds
unique(num$`Location ONSPD CCG Code`) # Deal with NA value later

# 5. Amend CCG Code and Name Column -------------------------------------------


num_na <- num %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 6 homes

# This section needs doing every year!
# Check for CCG codes which are missing for the care homes
# Then find the location ID for each missing CCG code
# Find the CCG code from the location ID postcode using SQL (see confluence for look-up)

num <- num %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-3998163914", "E38000009", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5400435927", "E38000132", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5407980962", "E38000118", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5563089061", "E38000198", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5779176410", "E38000019", `Location ONSPD CCG Code`)) %>% 
  mutate(`Location ONSPD CCG Code` = ifelse(`Location ID`== "1-5865334746", "E38000050", `Location ONSPD CCG Code`)) 


num[!complete.cases(num), ] # None - Yipee!!

# 6. Aggregate numerator ------------------------------------------------------

num <- num %>%
  group_by(`Location ONSPD CCG Code`) %>%
  summarise(`Care homes beds` = sum(`Care homes beds`)) %>%
  select(Code = `Location ONSPD CCG Code`,
         Beds = `Care homes beds`)

sum(num$Beds) # 305592 + 195 CCGs


# 7. Denominator - NHSD Monthly Dem 65+ figure Dec ----------------------------

# Filter for latest date (Dec) and re-order by prac code

dem <- dem %>% # Finds latest date in dataset
  mutate(ACH_DATE = dmy(ACH_DATE)) %>%
  filter(ACH_DATE == max(ACH_DATE)) %>%
  arrange(PRACTICE_CODE)

unique(dem$ACH_DATE) # Date is now only "2018-12-31"

# 8. Filter the data ----------------------------------------------------------

dem <- dem %>% filter(Measure == "DEMENTIA_REGISTER_65_PLUS"| Measure == "PAT_LIST_65_PLUS")


# 9. Reshape the data ---------------------------------------------------------

dem <- dem %>% spread(Measure, Value)

sum(dem$DEMENTIA_REGISTER_65_PLUS) # Register = 448348 

dem_na <- dem %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 7 practices

dem <- na.omit(dem) #  6924 pracs - 7 pracs = 6917

sum(dem$DEMENTIA_REGISTER_65_PLUS) # 448121 after NA values removed

# 10. Aggregate denominator ---------------------------------------------------

dem <- dem %>%
  group_by(GEOGRAPHY_CODE) %>%
  summarise(DEMENTIA_REGISTER_65_PLUS = sum(DEMENTIA_REGISTER_65_PLUS)) %>%
  select(Code = GEOGRAPHY_CODE,
         Denom = DEMENTIA_REGISTER_65_PLUS)

sum(dem$Denom) # Recheck total = 448121

# 11. Merge numerator and denominator -----------------------------------------

Final <- full_join(num, dem) # merge all of both datasets

dem_num_na <- Final %>% filter_all(any_vars(is.na(.))) # Check no missing values

sum(Final$Beds) # Still 305592 - good stuff!
sum(Final$Denom) # Still 448121


# 12. Join LookUp to data -----------------------------------------------------

Final <- left_join(Final, LUP, by = c("Code" = "CCG18CD"))


# 13. Add England Column ------------------------------------------------------

Final["Eng_Code"] <- "E92000001"

# 14. Aggregate by area + Bind Final Data -------------------------------------

CCG <- Final %>%
  group_by(Code) %>%
  summarise(Beds = sum(Beds), Denom = sum(Denom)) %>%
  select(Code,
         Beds,
         Denom)


STP <- Final %>%
  group_by(STP18CD) %>%
  summarise(Beds = sum(Beds), Denom = sum(Denom)) %>%
  select(Code = STP18CD,
         Beds,
         Denom)

Eng <- Final %>%
  group_by(Eng_Code) %>%
  summarise(Beds = sum(Beds), Denom = sum(Denom)) %>%
  select(Code = Eng_Code,
         Beds,
         Denom)


Final <- CCG %>%
  bind_rows(STP) %>%
  bind_rows(Eng) %>% 
  select(Code,
         Beds,
         Denom)

# Check England value is correct for amount of beds and dem list 65+


# 15. Create value columns ----------------------------------------------------

Final <- Final %>%
  mutate(Value = Beds/Denom * 100) 


# 16. Create Byars confidence intervals ---------------------------------------

Final <- phe_rate(Final, Beds, Denom, multiplier = 100)

          
# 17. Create PHOLIO sheet -----------------------------------------------------

Final <- Final %>%
  transmute(IndicatorID = 93041,
            Year = 2018,
            YearRange = 1,
            Quarter = -1,
            Month = -1,
            AgeID = 27,
            SexID = 4,
            AreaCode = Code,
            Count = Beds,
            Value = Value,
            LowerCI95 = lowercl,
            UpperCI95 = uppercl,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = Denom,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 18. Save to PHOLIO csv ------------------------------------------------------


write.xlsx(Final,file = "93041_CCG.xlsx", sheetName = "PHOLIO")


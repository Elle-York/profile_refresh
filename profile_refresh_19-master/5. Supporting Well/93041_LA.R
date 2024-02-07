# Indicator 93041 LA ----------------------------------------------------------

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

LUP <- fread("LUPS/CQC_LUP.csv") # Postcode data created when doing 93040 LA

LA_LUP <- fread("LUPS/UTLA_LUP.csv") # Local authority look-up


# 2. Select numerator columns -------------------------------------------------

num <- num %>% 
  select ('Location ID',
          'Care home?',
          'Care homes beds',
          'Location Type/Sector',
          'Location Inspection Directorate',
          'Location Primary Inspection Category',
          'Location Latest Overall Rating',
          'Service user band - Dementia',
          'Service user band - Older People',
          `Location Postal Code`) 


# 3. Filter numerator rows ----------------------------------------------------

num <- num %>% 
  filter(`Care home?`== "Y") %>% # 
  filter(`Location Type/Sector` == 'Social Care Org') %>% 
  filter(`Location Inspection Directorate` == 'Adult social care') %>% 
  filter(`Location Primary Inspection Category` == 'Residential social care') %>% 
  filter(`Service user band - Dementia` == "Y") %>%
  filter(`Service user band - Older People` == "Y") %>%
  select(`Location ID`,
         `Location Postal Code`,
         `Care homes beds`)

# 4. Inspect column contents --------------------------------------------------

glimpse(num) # Check column data types correct
unique(length(num$`Location ID`)) # 7018 homes
sum(num$`Care homes beds`) # 305,592 beds


# 5. Take out string space in both numerator and postcode look-up -------------


LUP$pcd <- gsub(" ", "", LUP$pcd, fixed = TRUE) # strip white space


num$`Location Postal Code` <- gsub(" ", "", num$`Location Postal Code`, fixed = TRUE) # strip white space


# 6. Join numerator to postcode look-up ---------------------------------------

num <- left_join(num, LUP, by = c("Location Postal Code" = "pcd")) 

na_data <- num %>% filter_all(any_vars(is.na(.))) # Check no NA values 


# 7. Aggregate numerator ------------------------------------------------------

num <- num %>%
  group_by(utla) %>%
  summarise(`Care homes beds` = sum(`Care homes beds`)) %>%
  select(Code = utla,
         Beds = `Care homes beds`)

sum(num$Beds) # 305592 + 195 CCGs


# Denominator - NHSD Monthly Dem 65+ figure Dec -------------------------------

# 8. Filter for latest date (Dec) and re-order by prac code

dem <- dem %>% # Finds latest date in dataset
  mutate(ACH_DATE = dmy(ACH_DATE)) %>%
  filter(ACH_DATE == max(ACH_DATE)) %>%
  arrange(PRACTICE_CODE)

unique(dem$ACH_DATE) # Date is now only "2018-12-31"

# 9. Filter the data ----------------------------------------------------------

dem <- dem %>% filter(Measure == "DEMENTIA_REGISTER_65_PLUS"| Measure == "PAT_LIST_65_PLUS")


# 10. Reshape the data --------------------------------------------------------

dem <- dem %>% spread(Measure, Value)

sum(dem$DEMENTIA_REGISTER_65_PLUS) # Register = 448348 

dem_na <- dem %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 7 practices

dem <- na.omit(dem) #  6924 pracs - 7 pracs = 6917

sum(dem$DEMENTIA_REGISTER_65_PLUS) # 448121 after NA values removed


# 11. Select columns for denominator ------------------------------------------

dem <- dem %>% 
  select(Prac = PRACTICE_CODE,
         Denom = DEMENTIA_REGISTER_65_PLUS)

# 12. Import GP to LA look-up for denominator ---------------------------------

# If you've done the code in 'domain' order, 
# then you already have a csv sheet with the details 
# If not go back and do code in order 


GP_LUP <- fread("LUPS/GP_LA_LUP.csv") # Import GP to LA look-up

dem <- left_join(dem, GP_LUP, by = c("Prac" = "GP_Code")) # join denominator and GP look-up

na_data <- dem %>% filter_all(any_vars(is.na(.))) # Check for any missing values

# 13. Aggregate denominator ---------------------------------------------------


dem <- dem %>%
  group_by(UTLA) %>%
  summarise(Denom = sum(Denom)) %>%
  select(Code = UTLA,
         Denom)

sum(dem$Denom) # 448121


# 14. Join num and dem --------------------------------------------------------

df <- full_join(num, dem, by = "Code") 

# 15. Check for any missing LAs -----------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # 1 LA data missing

# Check CQC sheet as no data for one LA which is right

df[is.na(df)] <- 0 # Fill missing LA cells with 0

df <- df %>% arrange(Code) # Put LA code back in order

sum(df$Beds) # 305592
sum(df$Denom) # 448121


# 16. Join merged dataset (num and dem) LA LookUp to data ---------------------


df <- full_join(df, LA_LUP, by = c('Code' = 'UTLA13CD')) # Join on LA

na_data <- df %>% filter_all(any_vars(is.na(.))) # Check no missing values



# 17. Aggregate final data by area and then bind together ---------------------

LA <- df %>% 
  select(Code,
         Beds, 
         Denom)


Region <- df %>%
  group_by(RGN09CD) %>%
  summarise(Beds = sum(Beds),
            Denom = sum(Denom)) %>% 
  select(Code = RGN09CD ,
         Beds, 
         Denom)


England <- df %>%
  group_by(CTRY09CD) %>%
  summarise(Beds = sum(Beds),
            Denom = sum(Denom)) %>% 
  select(Code = CTRY09CD,
         Beds, 
         Denom)

# Bring them all together

df <- LA %>%
  bind_rows(Region) %>%
  bind_rows(England) 


# Check England value is correct for amount of beds and dem list 65+

# 18. Change small values -----------------------------------------------------

names(df)

df[ which(df$Code == 'E06000052'),] # Cornwall
df[ which(df$Code == 'E06000053'),] # Isles of Scilly
df[ which(df$Code == 'E09000001'),] # City of London
df[ which(df$Code == 'E09000012'),] # Hackney


df[df$Code == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Code == 'E06000053',] 
14 + 3252 # Count = 3266
8 + 4532 # Denom = 4540

df[51, 2] = 3266 # fill missing values on row 51, 2nd col
df[52, 2] = 3266 # fill missing values on row 52, 2nd col

df[51, 3] = 4540 # fill missing values on row 51, 3rd col
df[52, 3] = 4540 # fill missing values on row 52, 3rd col

df[df$Code == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Code == 'E09000012',]
142 + 0 # Count = 142
916 + 269 # Register = 1185

df[93, 2] = 142 # fill missing values
df[104, 2] = 142

df[93, 3] = 1185 # fill missing values
df[104, 3] = 1185


# 18. Create value columns ----------------------------------------------------

df <- df %>%
  mutate(Value = Beds/Denom * 100) # Total beds divided by dem register 65+


# 19. Create Byars confidence intervals ---------------------------------------

df <- phe_rate(df, Beds, Denom, multiplier = 100)


# 20. Create PHOLIO sheet -----------------------------------------------------

df <- df %>%
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

# 21. Save to PHOLIO csv ------------------------------------------------------


write.xlsx(df,file = "93041_LA.xlsx", sheetName = "PHOLIO")

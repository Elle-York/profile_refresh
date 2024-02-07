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

LUP <- fread("LUPS/CQC_LUP.csv") # Postcode data created when doing 93040 LA

LA_LUP <- fread("LUPS/UTLA_LUP.csv") # Local authority look-up


# 2. Select Columns -----------------------------------------------------------

df <- df %>% 
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



# 6. Drop Columns -------------------------------------------------------------

names(df)
df <- df %>% 
  select(`Location ID`,
         `Care homes beds`,
         `Location Latest Overall Rating`,
         `Location Postal Code`)


# 7. Spread ratings column ----------------------------------------------------

df <- df %>% spread(`Location Latest Overall Rating`, `Care homes beds`)

df[is.na(df)] <- 0 # Fill NA cells with 0


# 8. Take out string space in dataset postcode column -------------------------


LUP$pcd <- gsub(" ", "", LUP$pcd, fixed = TRUE) # strip white space


df$`Location Postal Code` <- gsub(" ", "", df$`Location Postal Code`, fixed = TRUE) # strip white space

df <- left_join(df, LUP, by = c("Location Postal Code" = "pcd")) 

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 6 homes


# 9. Aggregate by LA ----------------------------------------------------------

df <- df %>%
  group_by(utla) %>%
  summarise(Good = sum(Good), 
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = utla,
         Good,
         Inadequate,
         `Not Assessed`,
         Outstanding,
         `Requires improvement`)

# 10. Join to LA look-up ------------------------------------------------------


df <- full_join(x = df,y = LA_LUP, by = c('Code' = 'UTLA13CD'))

na_data <- df %>% filter_all(any_vars(is.na(.))) # 1 LA data missing, checked and this right

df[is.na(df)] <- 0 # Fill missing LA cells with 0

df <- df %>% arrange(Code)

# 11. Aggregate by each area --------------------------------------------------

LA <- df %>% 
  select(Code,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)


Region <- df %>%
  group_by(RGN09CD) %>%
  summarise(Good = sum(Good),
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = RGN09CD,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)


England <- df %>%
  group_by(CTRY09CD) %>%
  summarise(Good = sum(Good),
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = CTRY09CD,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)

# Bring them all together

df <- LA %>%
  bind_rows(Region) %>%
  bind_rows(England) 

# 12. Create value columns ----------------------------------------------------

df <- df %>%
  mutate(Assess_Count = Good + Inadequate + Outstanding + `Requires improvement`) %>% 
  mutate(Total_Beds = Good + Inadequate + Outstanding + `Requires improvement` +`Not Assessed`) 
  
df <- df %>% 
  select(Code, 
         Assess_Count,
         Total_Beds)

# 12. Deal with small values --------------------------------------------------

names(df)

df[ which(df$Code == 'E06000052'),] # Cornwall
df[ which(df$Code == 'E06000053'),] # Isles of Scilly
df[ which(df$Code == 'E09000001'),] # City of London
df[ which(df$Code == 'E09000012'),] # Hackney


df[df$Code == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Code == 'E06000053',] 
14 + 3129 # Count = 3143
14 + 3252 # Denom = 3266

df[51, 2] = 3143 # fill missing values on row 51, 2nd col
df[52, 2] = 3143 # fill missing values on row 52, 2nd col

df[51, 3] = 3266 # fill missing values on row 51, 3rd col
df[52, 3] = 3266 # fill missing values on row 52, 3rd col

df[df$Code == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Code == 'E09000012',]
142 + 0 # Count = 142
142 + 0 # Register = 142

df[93, 2] = 142 # fill missing values
df[104, 2] = 142

df[93, 3] = 142 # fill missing values
df[104, 3] = 142


# 13. Create Value column -----------------------------------------------------

df <- df %>% mutate(Assessed = Assess_Count/Total_Beds * 100)

# 13. Create confidence intervals ---------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Assess_Count, Total_Beds)) %>%
  mutate(Lower = Lower1 * 100) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Assess_Count, Total_Beds)) %>%
  mutate(Upper = Upper1 * 100) %>%
  mutate(Upper1 = NULL)

# 14. Create PHOLIO sheet -----------------------------------------------------

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

# 15. Save to PHOLIO csv ------------------------------------------------------

write.xlsx(df,file = "93043_LA.xlsx", sheetName = "PHOLIO")




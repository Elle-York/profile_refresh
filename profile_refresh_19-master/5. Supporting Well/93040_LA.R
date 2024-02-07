
# Indicator 93040 LA ---------------------------------------------------------

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

# 1. Import data as of 31st Dec -----------------------------------------------

df <- read_xlsx("Data/HSCA Active Locations January 2019.xlsx",
                sheet = 2)


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

glimpse(df) # Check column data types correct
unique(length(df$`Location ID`)) # 7018
sum(df$`Care homes beds`) # 305,592 beds


# 5. Amend Latest Overall Rating Column ---------------------------------------


df$`Location Latest Overall Rating`[is.na(df$`Location Latest Overall Rating`)] <- "Not Assessed"


table(df$`Location Latest Overall Rating`) 


4805 + 137 + 411 + 190 + 1475 # 7018 homes


# 6. Find Local authorities for dataset ---------------------------------------

# Needs doing every year!
# Find the LA code 
# Code in LA look-ups section


LA_list <- df %>% 
  select('Location Postal Code') # Create postcode file

names(LA_list)[1] <- "Postcode" # Rename column

LA_list$Postcode <- paste0("'", LA_list$Postcode, "',") # Add quotes and comma for SQL work

LA_list <- LA_list %>% 
  arrange(Postcode)

fwrite(LA_list, file = "LA_List.csv") # Save to file 

# Put list into SQL using postcode look-up (confluence) then match laua up to UTLA13 and then to region


# 7. Import postcode look-up --------------------------------------------------

LUP <- fread("LUPS/CQC_LUP.csv")
 

# 8. Take out string space in dataset postcode column -------------------------


LUP$pcd <- gsub(" ", "", LUP$pcd, fixed = TRUE) # strip white space


df$`Location Postal Code` <- gsub(" ", "", df$`Location Postal Code`, fixed = TRUE) # strip white space


# 9. Join dataset to postcode look-up -----------------------------------------

df <- left_join(df, LUP, by = c("Location Postal Code" = "pcd")) 

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 6 homes

# There will be some postcodes missing so you'll have to manually find those.
# Compare other similar postcodes in the look-up
# https://www.gov.uk/find-local-council 
# https://www.royalmail.com/find-a-postcode
# https://www.carehome.co.uk (gives you the council if its on their list)
# Manually add them to the CQC look-up then re-run 'import post code look-up' section again

# 10. Drop columns ------------------------------------------------------------

df <- df %>% 
  select('Location ID',
         Beds = `Care homes beds`,
         LA = utla,
         Rating = `Location Latest Overall Rating`)


# 11. Spread contents of rating column ----------------------------------------

df <- df %>% 
  spread(Rating, Beds)


df[is.na(df)] <- 0 # Fill all empty fields with 0

# Checked why only 151 LAs instead of 152
# City of London LA - no care homes recorded for dementia in origianl data

# 12. Aggregate at LA level ---------------------------------------------------


df <- df %>%
  group_by(LA) %>% 
  summarise(Good = sum(Good),
            Inadequate = sum(Inadequate),
            `Not Assessed` = sum(`Not Assessed`),
            Outstanding = sum(Outstanding),
            `Requires improvement` = sum(`Requires improvement`)) %>% 
  select(Code = LA,
         Outstanding,
         Good,
         `Requires improvement`,
         Inadequate,
         `Not Assessed`)


# 13. Join to LA look-up ------------------------------------------------------


LA_LUP <- fread("LUPS/UTLA_LUP.csv")

df <- full_join(x = df,y = LA_LUP, by = c('Code' = 'UTLA13CD'))

# 14. Check missing LAs -------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # 1 LA data missing, checked and this right

df[is.na(df)] <- 0 # Fill missing LA cells with 0

df <- df %>% arrange(Code)

# 15. Aggregate by area -------------------------------------------------------

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


# 16. Create value columns ----------------------------------------------------

df <- df %>%
  mutate(Quality = Outstanding + Good) %>% 
  mutate(Beds = Outstanding + Good + `Requires improvement` + Inadequate + `Not Assessed`)%>% 
  select(Code,
         Quality,
         Beds)

# 16. Change small numbers ----------------------------------------------------

names(df)

df[ which(df$Code == 'E06000052'),] # Cornwall
df[ which(df$Code == 'E06000053'),] # Isles of Scilly
df[ which(df$Code == 'E09000001'),] # City of London
df[ which(df$Code == 'E09000012'),] # Hackney


df[df$Code == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Code == 'E06000053',] 
14 + 2538 # Count = 2552
14 + 3252 # Denom = 3266

df[51, 2] = 2552 # fill missing values on row 51, 2nd col
df[52, 2] = 2552 # fill missing values on row 52, 2nd col

df[51, 3] = 3266 # fill missing values on row 51, 3rd col
df[52, 3] = 3266 # fill missing values on row 52, 3rd col

df[df$Code == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Code == 'E09000012',]
44 + 0 # Count = 44
142 + 0 # Register = 142

df[93, 2] = 44 # fill missing values
df[104, 2] = 44

df[93, 3] = 142 # fill missing values
df[104, 3] = 142

# 16. Create Value column -----------------------------------------------------

df <-  df %>% 
  mutate(Value = Quality/Beds * 100) 

# 17. Create confidence intervals ---------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Quality, Beds)) %>%
  mutate(Lower = Lower1 * 100) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Quality, Beds)) %>%
  mutate(Upper = Upper1 * 100) %>%
  mutate(Upper1 = NULL)

# 18. Create PHOLIO sheet -----------------------------------------------------

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

# 19. Save to PHOLIO csv ------------------------------------------------------


write.xlsx(df,file = "93040_LA.xlsx", sheetName = "PHOLIO")









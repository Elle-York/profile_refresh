
# Indicator 93026 LA  ---------------------------------------------------------

# 93026 Dem under 64 years per 10,000
# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Import Data --------------------------------------------------------------

df <- fread("Data/rec-dem-diag-Dec-2018-csv.csv")

# 3. Adjust date column and re-order by prac code -----------------------------

df <- df %>%
  mutate(ACH_DATE = dmy(ACH_DATE)) %>%
  filter(ACH_DATE == max(ACH_DATE)) %>%
  arrange(PRACTICE_CODE)

unique(df$ACH_DATE) # Date is now only "2018-12-31"

# 4. Filter the data ----------------------------------------------------------

df <- df %>% filter(Measure == "DEMENTIA_REGISTER_0_64"| Measure == "PAT_LIST_0_64") 

glimpse(df)

# 5. Reshape the data ---------------------------------------------------------

df <- df %>% spread(Measure, Value) # 6924 practices

# 6. NA Values ----------------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 7 practices

df <- na.omit(df) #  6924 pracs - 7 pracs = 6917
df <- df %>% select(2, 6:7)# Keep practice code, dem 64 and pat list 64


# 7. Join LookUp to data ------------------------------------------------------

LUP <- fread("LUPS/GP_LA_LUP.csv")
glimpse(df)
glimpse(LUP)
length(unique(LUP$UTLA)) # 152 UTLAs
length(unique(LUP$Region)) # 9 regions

df <- left_join(df, LUP, by = c("PRACTICE_CODE" = "GP_Code"))

na_data <- df %>% filter_all(any_vars(is.na(.))) # check for NA values

# If you find NA values, go back to the GP look-up and add the missing practices
# Then using the postcodes, find the local authority
# Using the datalake, find the region
# Have a look on Confluence/Dementia Refresh/Look-ups for further info

# 8. Get rid of unwanted columns and put in order -----------------------------


glimpse(df)
df <- df %>%
  select(LA = UTLA,
         Region = Region,
         England = CTRY09CD,
         Dem64 = DEMENTIA_REGISTER_0_64,
         Pat64 = PAT_LIST_0_64)


# 9. Aggregate + Bind Data ----------------------------------------------------

La_df <- df %>%
  group_by(LA) %>%
  summarise(Dem64 = sum(Dem64), Pat64 = sum(Pat64)) %>%
  select(Area = LA,
         Dem64,
         Pat64)


Region_df <- df %>%
  group_by(Region) %>%
  summarise(Dem64 = sum(Dem64), Pat64 = sum(Pat64))%>%
  select(Area = Region,
         Dem64,
         Pat64)

England_df <- df %>%
  group_by(England) %>%
  summarise(Dem64 = sum(Dem64), Pat64 = sum(Pat64))%>%
  select(Area = England,
         Dem64,
         Pat64)


df <- La_df %>%
  bind_rows(Region_df) %>%
  bind_rows(England_df) 

# 10. Sort out small values ---------------------------------------------------

names(df)

df[ which(df$Dem64 <= 25), ]  # Find small numbers under 25 
df[ which(df$Area == 'E06000052'),] # Cornwall
df[ which(df$Area == 'E06000053'),] # Isles of Scilly
df[ which(df$Area == 'E09000001'),] # City of London
df[ which(df$Area == 'E09000012'),] # Hackney


df[df$Area == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Area == 'E06000053',] 
0 + 126 # Count = 126
1807 + 436603 # Denom = 438410

df[51, 2] = 126 # fill missing values on row 51, 2nd col
df[52, 2] = 126 # fill missing values on row 52, 2nd col

df[51, 3] = 438410 # fill missing values on row 51, 3rd col
df[52, 3] = 438410 # fill missing values on row 52, 3rd col

df[df$Area == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Area == 'E09000012',]
45 + 2 # Count = 47
290037 + 8114 # Register = 298151

df[93, 2] = 47 # fill missing values
df[104, 2] = 47

df[93, 3] = 298151 # fill missing values
df[104, 3] = 298151


# 10. Numerator/Denominator and Value -----------------------------------------

df <- df %>%
  rename(Num = Dem64) %>%
  ungroup(df) %>%
  rename(Denom = Pat64) %>% # changed this from mutate to rename
  mutate(Val  = Num/Denom) %>%
  mutate(Val = Val * 10000) %>%
  select(Area, Num, Denom, Val)


# 11. Confidence Intervals ----------------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Num, Denom)) %>%
  mutate(Lower = Lower1 * 10000) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Num, Denom)) %>%
  mutate(Upper = Upper1 * 10000) %>%
  mutate(Upper1 = NULL)

# 12. PHOLIO ------------------------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 93026,
            Year = 2018,
            YearRange = 1,
            Quarter = -1,
            Month = -1, 
            AgeID = 279,
            SexID = 4,
            AreaCode = Area,
            Count = Num,
            Value = Val,
            LowerCI95 = Lower,
            UpperCI95 = Upper,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = Denom,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)


# 13.Save to PHOLIO -----------------------------------------------------------

write.xlsx(df,file = "93026_LA.xlsx", sheetName = "PHOLIO")

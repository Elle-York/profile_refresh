
# Indicator 91891 LA  ---------------------------------------------------------

# Dementia Prevalence aged 65+ 
# Run each section one at a time and double check correct data files imported!
# Last year, Michael wanted the 0 denominators removed but then at the end,
# He wanted the original Engaldn value adding back in
# We revised this at the end in Excel. 
# Best get consensus on this before you do the analysis...


# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Import Data --------------------------------------------------------------

df <- fread("Data/rec-dem-diag-Dec-2018-csv.csv") # Dementia 65+ NHSD
LUP <- fread("LUPS/GP_LA_LUP.csv") # GP postcode to LA look-up


# 3. Adjust date column and re-order by prac code -----------------------------

df <- df %>%
  mutate(ACH_DATE = dmy(ACH_DATE)) %>%
  filter(ACH_DATE == max(ACH_DATE)) %>%
  arrange(PRACTICE_CODE)

unique(df$ACH_DATE) # Date is now only "2018-12-31"

# 4. Filter the data ----------------------------------------------------------

df <- df %>% filter(Measure == "DEMENTIA_REGISTER_65_PLUS"| Measure == "PAT_LIST_65_PLUS") 

# 5. Reshape the data ---------------------------------------------------------

df <- df %>% spread(Measure, Value) # 6924 GP practices


# 6. NA Values ----------------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 7 practices
df <- na.omit(df) #  6924 pracs - 7 pracs = 6917
glimpse(df) # Check columns
df <- df %>% select(2, 6:7)# Keep practice code, dem 65 and pat list 65

# 7. Join LookUp to data ------------------------------------------------------

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
         Dem65 = DEMENTIA_REGISTER_65_PLUS,
         Pat65 = PAT_LIST_65_PLUS)


# 9. Aggregate + Bind Data ----------------------------------------------------

La_df <- df %>%
  group_by(LA) %>%
  summarise(Dem65 = sum(Dem65), Pat65 = sum(Pat65)) %>%
  select(Area = LA,
         Dem65,
         Pat65)


Region_df <- df %>%
  group_by(Region) %>%
  summarise(Dem65 = sum(Dem65), Pat65 = sum(Pat65))%>%
  select(Area = Region,
         Dem65,
         Pat65)

England_df <- df %>%
  group_by(England) %>%
  summarise(Dem65 = sum(Dem65), Pat65 = sum(Pat65))%>%
  select(Area = England,
         Dem65,
         Pat65)


df <- La_df %>%
  bind_rows(Region_df) %>%
  bind_rows(England_df) 

# 10. Check and sort out small numbers ----------------------------------------

names(df)

df[ which(df$Dem65 <= 25), ]  # Find small numbers under 25 
df[ which(df$Area == 'E06000052'),] # Cornwall
df[ which(df$Area == 'E06000053'),] # Isles of Scilly
df[ which(df$Area == 'E09000001'),] # City of London
df[ which(df$Area == 'E09000012'),] # Hackney


df[df$Area == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Area == 'E06000053',] 
8 + 4532 # Count = 4540
557 + 140146 # Denom = 140703

df[51, 2] = 4540 # fill missing values on row 51, 2nd col
df[52, 2] = 4540 # fill missing values on row 52, 2nd col

df[51, 3] = 140703 # fill missing values on row 51, 3rd col
df[52, 3] = 140703 # fill missing values on row 52, 3rd col

df[df$Area == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Area == 'E09000012',]
269 + 916 # Count = 1185
1648 + 21607 # Register = 23255

df[93, 2] = 1185 # fill missing values
df[104, 2] = 1185

df[93, 3] = 23255 # fill missing values
df[104, 3] = 23255 



# 10. Numerator/Denominator and Value -----------------------------------------

df <- df %>%
  rename(Num = Dem65) %>%
  ungroup(df) %>%
  rename(Denom = Pat65) %>% # changed this from mutate to rename
  mutate(Val  = Num/Denom) %>%
  mutate(Val = Val * 100) %>%
  select(Area, Num, Denom, Val)


# 11. Confidence Intervals ----------------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Num, Denom)) %>%
  mutate(Lower = Lower1 * 100) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Num, Denom)) %>%
  mutate(Upper = Upper1 * 100) %>%
  mutate(Upper1 = NULL)

# 12. PHOLIO ------------------------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 91891,
            Year = 2018,
            YearRange = 1,
            Quarter = -1,
            Month = 9, 
            AgeID = 27,
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

write.xlsx(df,file = "91891_LA.xlsx", sheetName = "PHOLIO")



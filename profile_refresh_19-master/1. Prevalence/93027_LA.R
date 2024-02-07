# Indicator 93027 CCG ---------------------------------------------------------

# Dementia (aged under 65 years) as a Proportion of Total Dementia
# (all ages) per 100 
# 16726 YOD/464847 Total Dem
# England value = 3.60

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


# 4. Reshape the data ---------------------------------------------------------

df <- df %>% filter(Measure == "DEMENTIA_REGISTER_65_PLUS"|
                      Measure == "PAT_LIST_65_PLUS" |
                      Measure == "DEMENTIA_REGISTER_0_64"|
                      Measure == "PAT_LIST_0_64") %>%
  spread(Measure, Value)



# 5. NA Values ----------------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # 6924 pracs

df <- na.omit(df) #  Remove 7 NA value rows, leaves  6917 practices
df <- df %>% select(2, 6:9) # Select GP practice, dem registers and pat lists


# 5. Join LookUp to data ------------------------------------------------------

LUP <- fread("LUPS/GP_LA_LUP.csv")

glimpse(LUP)
glimpse(df)
length(unique(LUP$UTLA)) # 152 UTLAs
length(unique(LUP$Region)) # 9 regions

df <- left_join(df, LUP, by = c("PRACTICE_CODE" = "GP_Code"))

na_data <- df %>% filter_all(any_vars(is.na(.))) # check for NA values

# If you find NA values, go back to the GP look-up and add the missing practices
# Then using the postcodes, find the local authority
# Using the datalake, find the region
# Have a look on Confluence/Dementia Refresh/Look-ups for further info

# 6. Get rid of unwanted columns and put in order -----------------------------


glimpse(df)
df <- df %>%
  select(LA = UTLA,
         Region = Region,
         England = CTRY09CD,
         Dem64 = DEMENTIA_REGISTER_0_64,
         Dem65plus = DEMENTIA_REGISTER_65_PLUS)


# 7. Aggregate + Bind Data ----------------------------------------------------

La_df <- df %>%
  group_by(LA) %>%
  summarise(Dem64 = sum(Dem64), Dem65plus = sum(Dem65plus)) %>%
  select(Area = LA,
         Dem64,
         Dem65plus)


Region_df <- df %>%
  group_by(Region) %>%
  summarise(Dem64 = sum(Dem64), Dem65plus = sum(Dem65plus))%>%
  select(Area = Region,
         Dem64,
         Dem65plus)


England_df <- df %>%
  group_by(England) %>%
  summarise(Dem64 = sum(Dem64), Dem65plus = sum(Dem65plus))%>%
  select(Area = England,
         Dem64,
         Dem65plus)


df <- La_df %>%
  bind_rows(Region_df) %>%
  bind_rows(England_df) 

# 10. Sort out small numbers --------------------------------------------------

names(df)

df[ which(df$Dem64 <= 25), ]  # Find small numbers under 25 
df[ which(df$Area == 'E06000052'),] # Cornwall
df[ which(df$Area == 'E06000053'),] # Isles of Scilly
df[ which(df$Area == 'E09000001'),] # City of London
df[ which(df$Area == 'E09000012'),] # Hackney


df[df$Area == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Area == 'E06000053',] 
0 + 126 # Count = 126
8 + 4532 # Denom = 4540

df[51, 2] = 126 # fill missing values on row 51, 2nd col
df[52, 2] = 126 # fill missing values on row 52, 2nd col

df[51, 3] = 4540 # fill missing values on row 51, 3rd col
df[52, 3] = 4540 # fill missing values on row 52, 3rd col

df[df$Area == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Area == 'E09000012',]
45 + 2 # Count = 47
916 + 269 # Register = 1185

df[93, 2] = 47 # fill missing values
df[104, 2] = 47

df[93, 3] = 1185 # fill missing values
df[104, 3] = 1185

# 11. Numerator/Denominator and Value ------------------------------------------

df <- df %>%
  rename(Num = Dem64) %>%
  ungroup(df) %>%
  mutate(Denom = Num + Dem65plus) %>%
  mutate(Val  = Num/Denom) %>%
  mutate(Val = Val * 100) %>%
  select(Area, Num, Denom, Val)


# 12. Confidence Intervals ----------------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Num, Denom)) %>%
  mutate(Lower = Lower1 * 100) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Num, Denom)) %>%
  mutate(Upper = Upper1 * 100) %>%
  mutate(Upper1 = NULL)

# 13. PHOLIO ------------------------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 93027,
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

# 14. Save to file ------------------------------------------------------------

write.xlsx(df,file = "93027_LA.xlsx", sheetName = "PHOLIO")



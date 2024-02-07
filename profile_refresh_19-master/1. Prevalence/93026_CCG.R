
# Indicator 93026 CCG  --------------------------------------------------------

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


# 5. Reshape the data ---------------------------------------------------------

df <- df %>% spread(Measure, Value)


# 6. NA Values ----------------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 7 practices

df <- na.omit(df) #  6924 pracs - 7 pracs = 6917


# 7. Join LookUp to data ------------------------------------------------------

LUP <- fread("LUPS/CCGLUP18.csv")
glimpse(df)
glimpse(LUP)
length(unique(df$GEOGRAPHY_CODE)) # 195 CCGs

df <- left_join(df, LUP, by = c("GEOGRAPHY_CODE" = "CCG18CD"))

# 8. Get rid of unwanted columns and put in order -----------------------------


glimpse(df)
df <- df %>%
  select(CCG_Code = GEOGRAPHY_CODE,
         CCG_Name = CCG18NM,
         STP_Code = STP18CD,
         STP_Name = STP18NM,
         Dem64 = DEMENTIA_REGISTER_0_64,
         Pat64 = PAT_LIST_0_64)

# 9. Add England Column -------------------------------------------------------

df["Eng_Name"] <- "England"
df["Eng_Code"] <- "E92000001"

# 10. Aggregate + Bind Data ---------------------------------------------------

CCG_df <- df %>%
  group_by(CCG_Code, CCG_Name) %>%
  summarise(Dem64 = sum(Dem64), Pat64 = sum(Pat64)) %>%
  select(Code = CCG_Code,
         Area = CCG_Name,
         Dem64,
         Pat64)


STP_df <- df %>%
  group_by(STP_Code, STP_Name) %>%
  summarise(Dem64 = sum(Dem64), Pat64 = sum(Pat64))%>%
  select(Code = STP_Code,
         Area = STP_Name,
         Dem64,
         Pat64)

Eng_df <- df %>%
  group_by(Eng_Code, Eng_Name) %>%
  summarise(Dem64 = sum(Dem64), Pat64 = sum(Pat64))%>%
  select(Code = Eng_Code,
         Area = Eng_Name,
         Dem64,
         Pat64)


df <- CCG_df %>%
  bind_rows(STP_df) %>%
  bind_rows(Eng_df) %>% 
  select(Code,
         Area,
         Dem64,
         Pat64)

# 11. Numerator/Denominator and Value -----------------------------------------

df <- df %>%
  rename(Num = Dem64) %>%
  ungroup(df) %>%
  rename(Denom = Pat64) %>% # changed this from mutate to rename
  mutate(Val  = Num/Denom) %>%
  mutate(Val = Val * 10000) %>%
  select(Code, Area, Num, Denom, Val)


# 12. Confidence Intervals ----------------------------------------------------

df <- df %>%
  mutate(Lower1 = wilson_lower(Num, Denom)) %>%
  mutate(Lower = Lower1 * 10000) %>%
  mutate(Lower1 = NULL)%>%
  mutate(Upper1 = wilson_upper(Num, Denom)) %>%
  mutate(Upper = Upper1 * 10000) %>%
  mutate(Upper1 = NULL)

# 13. PHOLIO ------------------------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 93026,
            Year = 2018,
            YearRange = 1,
            Quarter = -1,
            Month = -1, 
            AgeID = 279,
            SexID = 4,
            AreaCode = Code,
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


# 14.Save to PHOLIO -----------------------------------------------------------

write.xlsx(df,file = "93026_CCG.xlsx", sheetName = "PHOLIO")


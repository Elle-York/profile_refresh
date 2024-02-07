
# Indicator 93027 CCG ---------------------------------------------------------

# Dementia (aged under 65 years) as a Proportion of Total Dementia
# (all ages) per 100 
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


# 4. Reshape the data ---------------------------------------------------------

df <- df %>% filter(Measure == "DEMENTIA_REGISTER_65_PLUS"|
                      Measure == "PAT_LIST_65_PLUS" |
                      Measure == "DEMENTIA_REGISTER_0_64"|
                      Measure == "PAT_LIST_0_64") %>%
  spread(Measure, Value)



# 5. NA Values ----------------------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # 6924 pracs

df <- na.omit(df) #  Remove 7 NA value rows, leaves  6917 practices


# 6. Join LookUp to data ------------------------------------------------------

LUP <- fread("LUPS/CCGLUP18.csv")

df <- left_join(df, LUP, by = c("GEOGRAPHY_CODE" = "CCG18CD"))


# 7. Get rid of unwanted columns and put in order -----------------------------


df <- df %>%
  select(CCG_Code = GEOGRAPHY_CODE,
         CCG_Name = CCG18NM,
         STP_Code = STP18CD,
         STP_Name = STP18NM,
         Dem64 = DEMENTIA_REGISTER_0_64,
         Dem65plus = DEMENTIA_REGISTER_65_PLUS)

# 8. Add England Column -------------------------------------------------------

df["Eng_Name"] <- "England"
df["Eng_Code"] <- "E92000001"


# 9. Aggregate + Bind Data ----------------------------------------------------

CCG_df <- df %>%
  group_by(CCG_Code, CCG_Name) %>%
  summarise(Dem64 = sum(Dem64), Dem65plus = sum(Dem65plus)) %>%
  select(Code = CCG_Code,
         Area = CCG_Name,
         Dem64,
         Dem65plus)


STP_df <- df %>%
  group_by(STP_Code, STP_Name) %>%
  summarise(Dem64 = sum(Dem64), Dem65plus = sum(Dem65plus))%>%
  select(Code = STP_Code,
         Area = STP_Name,
         Dem64,
         Dem65plus)


England_df <- df %>%
  group_by(Eng_Code, Eng_Name) %>%
  summarise(Dem64 = sum(Dem64), Dem65plus = sum(Dem65plus))%>%
  select(Code = Eng_Code,
         Area = Eng_Name,
         Dem64,
         Dem65plus)


df <- CCG_df %>%
  bind_rows(STP_df) %>%
  bind_rows(England_df) %>%
  select(Code,
         Area,
         Dem64,
         Dem65plus)


# 10. Numerator/Denominator and Value -----------------------------------------

df <- df %>%
  rename(Num = Dem64) %>%
  ungroup(df) %>%
  mutate(Denom = Num + Dem65plus) %>%
  mutate(Val  = Num/Denom) %>%
  mutate(Val = Val * 100) %>%
  select(Code, Area, Num, Denom, Val)


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
  transmute(IndicatorID = 93027,
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

# 13. Save to file ------------------------------------------------------------

write.xlsx(df,file = "93027_CCG.xlsx", sheetName = "PHOLIO")


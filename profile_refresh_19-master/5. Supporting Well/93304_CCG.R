
# Indicator 93304 CCG
# People with dementia using inpatient hospital services 
# as a percentage of recorded diagnosis of dementia (all ages)
# First run the SQL code for 93304 and then save output to csv
# import into R and finish indicator
# Run each section one at a time and double check correct data files imported!

# Packages/Libraries ----------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)



# 1. Import Numerator (SQL output of HES data) --------------------------------

num <- fread("SQLoutput/93304_CCG.csv")

num <- num %>%
  select(Code = areacode,
         Count = count) %>%
  filter(str_detect(Code, 'E38')) # Select CCGs only

na_data <- num %>% filter_all(any_vars(is.na(.))) # check for NA values

num[190, 2] = 0 # Remove value for Buckinghamshire as not in denominator


# 2. Import CCG look-up -------------------------------------------------------

CCGLUP <- fread("LUPS/CCGLUP18.csv")

# 3. Join CCG LUP to numerator ------------------------------------------------

num <- merge(num, CCGLUP, by.x = c("Code"), by.y = c("CCG18CD"), all.x = TRUE)

# 4. Select numerator columns -------------------------------------------------

num <- num %>%
  select(Code,
         Count,
         STP = STP18CD) %>% 
  mutate("England" = "E92000001")

# 5. Aggregate numerator ------------------------------------------------------

CCGNum <- num %>%
  group_by(Code) %>%
  summarise(Count = sum(Count)) %>%
  select(Code,
         Count)

STPNum <- num %>%
  group_by(STP) %>%
  summarise(Count = sum(Count)) %>%
  select(Code = STP,
         Count)

EnglandNum <- num %>%
  group_by(England) %>%
  summarise(Count = sum(Count)) %>%
  select(Code = England,
         Count)


num <- CCGNum %>%
  bind_rows(STPNum) %>%
  bind_rows(EnglandNum) %>% 
  select(Code,
         Count)



# 6. Import Denominator -------------------------------------------------------

dem <- fread("Data/qof-1718-prev-ach-exc-neu-prac.csv",
             skip = 8,
             select = c(9, 18)) # CCG Code 3 digit code/Dem Register


na_data <- dem %>% filter_all(any_vars(is.na(.))) # check for NA values

dem <- na.omit(dem) # 7100 GP practices



# 7. Join CCG LUP to denominator ----------------------------------------------

dem <- merge(dem, CCGLUP, by.x = "CCG code", by.y = "CCG18CDH", all.x = TRUE)


na_data <- dem %>% filter_all(any_vars(is.na(.))) # check for NA values

dem <- na.omit(dem) # 7100 GP practices


dem <- dem %>% 
  mutate("England" = "E92000001") # Create England column

dem[190, 2] = 0

# 8. Aggregate denominator ----------------------------------------------------


CCGdem <- dem %>%
  group_by(CCG18CD) %>%
  summarise(Register = sum(Register)) %>%
  select(Code = CCG18CD,
         Register)

STPdem <- dem %>%
  group_by(STP18CD) %>%
  summarise(Register = sum(Register)) %>%
  select(Code = STP18CD,
         Register)

Englanddem <- dem %>%
  group_by(England) %>%
  summarise(Register = sum(Register)) %>%
  select(Code = England,
         Register)


dem <- CCGdem %>%
  bind_rows(STPdem) %>%
  bind_rows(Englanddem) %>% 
  select(Code,
         Register)

# 9. Merge the numerator with denominator -------------------------------------

df <- full_join(num, dem, by = "Code" )

names(num)
names(dem)

# 10.Deal with missing values -------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - extra lines in excel sheet

df[190, 2:3] = 0 # fill missing values for E38000223 Buckinghamshire Num but no denominator


# 11. Check for small numbers -------------------------------------------------

df[ which(df$Count <= 25), ]  # Find small numbers under 25 (none except Bucks as above) 


# 12. Create value columns ----------------------------------------------------

df <- df %>%
  mutate(Value = Count/Register * 100) 

# 13. Create Byars confidence intervals ---------------------------------------

# Remember the earlier value we set to 0 
# The phe_rate function doesnt work for NA or 0!
# So reset this line to 12 (choose any number!) or CI function wont work...

df[190, 2:4] = 12 # This will need changing every run, I know it's pants...


df <- phe_rate(df, Count, Register, multiplier = 100) 

df[190, 2:7] = 0 # reset back to 0, I've asked Seb to upgrade this function with a NA argument!

# 14. Create PHOLIO sheet -----------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 93304,
            Year = 2017,
            YearRange = 1,
            Quarter = -1,
            Month = -1, 
            AgeID = 1,
            SexID = 4,
            AreaCode = Code,
            Count,
            Value = value,
            LowerCI95 = lowercl,
            UpperCI95 = uppercl,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = Register,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 15. Save to PHOLIO csv ------------------------------------------------------


write.xlsx(df, file = "93304_CCG.xlsx", sheetName = "PHOLIO")







           
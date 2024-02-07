# Indicator 92826 CCG  --------------------------------------------------------

# Rate of newly diagnosed dementia registrations (Experimental)
# Dementia aged 65+ 
# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Import Numerator Data ----------------------------------------------------

# The numerator is the 'Denominator + Exceptions' column in the Dem005 section


numerator <- fread("Data/qof-1718-prev-ach-exc-neu-prac.csv",
                   skip = 8, # remove first eight rows of csv
                   select = c(12, 10, 7, 49), # Choose these columns
                   header = TRUE) # treat first row as header

glimpse(numerator) # check columns
# Should have - prac code, ccg code, stp code + 'denom + exclusions' col

numerator <- numerator %>% select(Prac = `Practice code`, 
                                  NewDiag = `Denominator plus Exceptions`,
                                  CCG_Code = `CCG geography code`, 
                                  STP_Code = `STP code`)

# 3. Remove unwanted rows -----------------------------------------------------

numerator <- numerator %>% arrange(Prac) # put rubbish rows to top

na_data <- numerator %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - 486 rows

numerator <- na.omit(numerator) #  7586 - 486 rows = 7100

length(unique(numerator$Prac)) # We now have 7100 pracs


# 4. Import Denominator data --------------------------------------------------

# Use GP practice data for April

denom <- fread("Data/gp-reg-pat-prac-quin-age.csv") # Import these columns

# 5. Filter denominator data by GP, Sex and Age -------------------------------

denom <- denom %>% 
  filter(ORG_TYPE == 'GP') %>% 
  filter(SEX == 'FEMALE' | SEX == 'MALE') %>% 
  filter(AGE_GROUP_5 %in% c("65_69", "70_74", "75_79", "80_84", "85_89", "90_94", "95+"))
  
           
# 6. Aggregate GP practices ---------------------------------------------------

denom <- denom %>% 
  select(ORG_CODE, NUMBER_OF_PATIENTS) %>% 
  group_by(ORG_CODE) %>% 
  summarise(NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS))

# 7. Remove unwanted rows -----------------------------------------------------

denom <- denom %>% arrange(ORG_CODE) # put rubbish rows to top

na_data <- denom %>% filter_all(any_vars(is.na(.))) # 0

length(unique(denom$ORG_CODE)) # We now have 7241 pracs


# 8. Join numerator to denominator --------------------------------------------

# Only keep the numerator GP pracs...

df <- left_join(numerator, denom, by = c("Prac" = "ORG_CODE")) # 7100

na_data <- df %>% filter_all(any_vars(is.na(.))) # 14 GP pracs with missing info

df <- na.omit(df) #  7100 - 14 = 7086 rows

df <- df %>% 
  select(Prac,
         NewDiag,
         CCG_Code,
         NUMBER_OF_PATIENTS)

# 8. STPs are wrong (44) should be 42 -----------------------------------------

STP_LUP <- fread("LUPS/CCGLUP18.csv")

STP_LUP <-  STP_LUP %>% 
  select(CCG18CD,
         STP18CD)

df <- left_join(df, STP_LUP, by = c("CCG_Code" = "CCG18CD"))


# 9. Create England value -----------------------------------------------------

df["Eng_Code"] <- "E92000001" # Create England column



# 10. Aggregate data ----------------------------------------------------------

CCG <- df %>% 
  group_by(CCG_Code) %>% 
  summarise(NewDiag = sum(NewDiag),NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS)) %>% 
  select(Code = CCG_Code,
         NewDiag,
         Patlist = NUMBER_OF_PATIENTS)


STP <- df %>% 
  group_by(STP18CD) %>% 
  summarise(NewDiag = sum(NewDiag),NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS)) %>% 
  select(Code = STP18CD,
         NewDiag,
         Patlist = NUMBER_OF_PATIENTS)

England <- df %>% 
  group_by(Eng_Code) %>% 
  summarise(NewDiag = sum(NewDiag),NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS)) %>% 
  select(Code = Eng_Code,
         NewDiag,
         Patlist = NUMBER_OF_PATIENTS)


df <- CCG %>%
  bind_rows(STP) %>%
  bind_rows(England)



# 11. Sort out data issues ----------------------------------------------------

# Don't do this section before checking you have some missing/problematic values

# There are only 194 CCGs - should be 195 
# but E38000223 (Buckinghamshire) has opted out of QOF
# Buckinhamshire has no numerator but has denominator

add_Bucks <- tibble(
  Code = c("E38000223"),
  NewDiag = c(0),
  Patlist = c(0))


df <- df %>% 
  bind_rows(add_Bucks) %>% 
  arrange(Code)

# 12. Create value and confidence intervals -----------------------------------

df <- df %>% 
  mutate(crude_rate = 1000*NewDiag/Patlist,
         LCI = 1000*wilson_lower(NewDiag, Patlist),
         UCI = 1000*wilson_upper(NewDiag, Patlist))

# 13. Create PHOLIO sheet -----------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 92826,
            Year = 2017,
            YearRange = 1,
            Quarter = -1,
            Month = -1, 
            AgeID = 27,
            SexID = 4,
            AreaCode = Code,
            Count = NewDiag,
            Value = crude_rate,
            LowerCI95 = LCI,
            UpperCI95 = UCI,
            LowerCI99_8 = -1,
            UpperCI99_8 = -1,
            Denominator = Patlist,
            Denominator_2 = -1,
            ValueNoteId = 0,
            CategoryTypeId = -1,
            CategoryId = -1)

# 14. Save to file ------------------------------------------------------------

write.xlsx(df,file = "92826_CCG.xlsx", sheetName = "PHOLIO")


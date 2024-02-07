# Indicator 92826 LA  ---------------------------------------------------------

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
                   select = c(12,49),
                   header = TRUE) # 7586 pracs

glimpse(numerator) # check columns
# Should have - prac code, ccg code, stp code + 'denom + exclusions' col

numerator <- numerator %>% select(Prac = `Practice code`,
                                  NewDiag = `Denominator plus Exceptions`)



# 3. Import Denominator data --------------------------------------------------

# Use GP practice data for April

denom <- fread("Data/gp-reg-pat-prac-quin-age.csv") # Import these columns

# 4. Filter denominator data by GP, Sex and Age -------------------------------

denom <- denom %>% 
  filter(ORG_TYPE == 'GP') %>% 
  filter(SEX == 'FEMALE' | SEX == 'MALE') %>% 
  filter(AGE_GROUP_5 %in% c("65_69", "70_74", "75_79", "80_84", "85_89", "90_94", "95+"))


# 5. Aggregate GP practices ---------------------------------------------------

denom <- denom %>% 
  select(ORG_CODE, NUMBER_OF_PATIENTS) %>% 
  group_by(ORG_CODE) %>% 
  summarise(NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS))


# 6. Join numerator to denominator --------------------------------------------

# Only keep full fields with no NAs

df <- full_join(numerator, denom, by = c("Prac" = "ORG_CODE")) # 7100

na_data <- df %>% filter_all(any_vars(is.na(.))) # find all GP pracs with missing info

df <- na.omit(df) #  Delete incomplete rows - 7086 pracs

df <- df %>% arrange(Prac) # Put back in order


# 7. Join GP pracs to look up -------------------------------------------------

LUP <- fread("LUPS/GP_LA_LUP.csv")


df <- left_join(df, LUP, by = c("Prac" = "GP_Code"))


na_data <- denom %>% filter_all(any_vars(is.na(.))) 


# 8. Aggregate by Area --------------------------------------------------------


LA <- df %>% 
  group_by(UTLA) %>% # group by local authority
  summarise(NewDiag = sum(NewDiag),NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS)) %>% # sum the value columns
  select(Code = UTLA, # then select LA and value columns
         NewDiag,
         Patlist = NUMBER_OF_PATIENTS)


Region <- df %>% 
  group_by(Region) %>% 
  summarise(NewDiag = sum(NewDiag),NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS)) %>% 
  select(Code = Region,
         NewDiag,
         Patlist = NUMBER_OF_PATIENTS)

England <- df %>% 
  group_by(CTRY09CD) %>% 
  summarise(NewDiag = sum(NewDiag),NUMBER_OF_PATIENTS = sum(NUMBER_OF_PATIENTS)) %>% 
  select(Code = CTRY09CD,
         NewDiag,
         Patlist = NUMBER_OF_PATIENTS)


df <- LA %>% # put each of above datasets on top of each other
  bind_rows(Region) %>%
  bind_rows(England)


# 9. Sort out data issues -----------------------------------------------------


# Don't do this section before checking you have some missing/problematic values!
# Check correct amount of LAs (152), regions (9) and England value
# This year Buckinghamshire E10000002 was missing

add_Bucks <- tibble( # create a row
  Code = c("E10000002"), # first column with LA code
  NewDiag = c(0), # Missing value in brackets
  Patlist = c(0)) # Missing value in brackets


df <- df %>% # Add the new row to your dataset
  bind_rows(add_Bucks) %>% # name of row vector in brackets
  arrange(Code) # re order the rows


# If you find any missing data, check the GP practices which have no values
# then re-do the GP look-up. Re-load the GP look-up and do it again


# 10. Sort out small values ---------------------------------------------------

names(df)

df[ which(df$NewDiag <= 25), ]  # Find small numbers under 25 
df[ which(df$Code == 'E06000052'),] # Cornwall
df[ which(df$Code == 'E06000053'),] # Isles of Scilly
df[ which(df$Code == 'E09000001'),] # City of London
df[ which(df$Code == 'E09000012'),] # Hackney


df[df$Code == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Code == 'E06000053',] 
1 + 1007 # Count = 1008
546 + 137918 # Denom = 138464

df[51, 2] = 1008 # fill missing values on row 51, 2nd col
df[52, 2] = 1008 # fill missing values on row 52, 2nd col

df[51, 3] = 138464 # fill missing values on row 51, 3rd col
df[52, 3] = 138464 # fill missing values on row 52, 3rd col

df[df$Code == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Code == 'E09000012',]
9 + 186 # Count = 195
1271 + 20978 # Register = 22249

df[93, 2] = 195 # fill missing values
df[104, 2] = 195

df[93, 3] = 22249 # fill missing values
df[104, 3] = 22249



# 10. Create value and confidence intervals -----------------------------------

df <- df %>% 
  mutate(crude_rate = 1000*NewDiag/Patlist,
         LCI = 1000*wilson_lower(NewDiag, Patlist),
         UCI = 1000*wilson_upper(NewDiag, Patlist))

# 11. Create PHOLIO sheet -----------------------------------------------------

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

# 12. Save to file ------------------------------------------------------------

write.xlsx(df,file = "92826_LA.xlsx", sheetName = "PHOLIO")





# Indicator 91300 LA ----------------------------------------------------------

# First run the SQL code for 91300 and then save output to csv
# import into R and finish indicator
# Run each section one at a time and double check correct data files imported!

# 1. Packages/Libraries -------------------------------------------------------

library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(xlsx)
library(lubridate)

# 2. Import Numerator (SQL output of HES data) --------------------------------

num <- fread("SQLoutput/91300_LA.csv")

# 3. Join to LA look-up -------------------------------------------------------

LA_LUP <- fread("LUPS/UTLA_LUP.csv") # import look-up


num <- merge(x = num, y = LA_LUP, by.x = "areacode", by.y = "UTLA13CD", all = TRUE) # join everything in both tables 

num <- num %>% 
  select(Code = "areacode",
         Count = count,
         Region = RGN09CD,
         England = CTRY09CD)

na_data <- num %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - extra lines in excel sheet

num <- na.omit(num) #  Remove blank lines, 

# 4. Import Denominator (QOF Annual Dem Prev all ages, April 1st) -------------

dem <- fread("Data/qof-1718-prev-ach-exc-neu-prac.csv",
             skip = 8,
             select = c(12, 18), # Cols 'Register' and 'Practice Code'
             header = TRUE)

# 5. Import GP Prac look-up ---------------------------------------------------


LUP <- fread("LUPS/GP_LA_LUP.csv")

# 6. Join denominator with GP Prac look-up ------------------------------------


dem <- merge(x = dem, y = LUP, by.x = "Practice code", by.y = "GP_Code", all.x = TRUE) 

# 6. Deal with NA values ------------------------------------------------------

na_data <- dem %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - extra lines in excel sheet

dem <- na.omit(dem) #  Remove blank lines, now have 7100 GP pracs


# 7. Aggregate denominator areas ----------------------------------------------

dem <- dem %>%
  group_by(UTLA, Region, CTRY09CD) %>%
  summarise(Register = sum(Register)) %>%
  select(Code = UTLA,
         Region,
         England = CTRY09CD,
         Register)


# 8. Join numerator with denominator ------------------------------------------

df <- merge(x = num, y = dem, by = "Code", all = TRUE) # join everything in both tables 


df <- df %>% # clean up table and select columns
  select(Code,
         Count,
         Register,
         Region = 'Region.x',
         England = 'England.x')

# 9. Deal with missing values -------------------------------------------------

na_data <- df %>% filter_all(any_vars(is.na(.))) # Save a snapshot of NA values - extra lines in excel sheet

df[126, 2:3] = 0 # fill missing values

# 10. Aggregate final data ----------------------------------------------------

LA <- df %>% 
  select(Code,
         Count,
         Register)

Region <- df %>%
  group_by(Region) %>%
  summarise(Count = sum(Count), Register = sum(Register)) %>%
  select(Code = Region,
         Count,
         Register)

England <- df %>%
  group_by(England) %>%
  summarise(Count = sum(Count), Register = sum(Register)) %>%
  select(Code = England,
         Count,
         Register)

df <- LA %>%
  bind_rows(Region) %>%
  bind_rows(England) %>% 
  select(Code,
         Count,
         Register)
  
# 11. Check for small numbers -------------------------------------------------

df[ which(df$Count <= 25), ]  # Find small numbers under 25  

# 1: E06000053     8       12 # This needs summing with E06000052
# 2: E09000001    13       36 # This needs summing with E09000012
# 3: E10000002     0        0 # This is fine, we dealt with this earlier

df[df$Code == 'E06000052',] # You'll need to sum E06000052 + E06000053 
df[df$Code == 'E06000053',] 
8 + 2805 # Count = 2813
12 + 4643 # Register = 4655

df[51, 2] = 2813 # fill missing values on row 51, 2nd col
df[52, 2] = 2813 # fill missing values on row 52, 2nd col

df[51, 3] = 4655 # fill missing values on row 51, 3rd col
df[52, 3] = 4655 # fill missing values on row 52, 3rd col

df[df$Code == 'E09000001',] # You'll need to sum E09000001 + E09000012
df[df$Code == 'E09000012',]
13 + 591 # Count = 604
36 + 952 # Register = 988

df[93, 2] = 604 # fill missing values
df[104, 2] = 604

df[93, 3] = 988 # fill missing values
df[104, 3] = 988 


  
# 12. Create value columns ----------------------------------------------------
  
df <- df %>%
    mutate(Value = Count/Register * 100) 
  
  
# 13. Create Byars confidence intervals ---------------------------------------


# Remember the earlier value we set to 0 (E10000002)
# The phe_rate function doesnt work for NA or 0!
# So reset this line to 12 (choose any number!) or CI function wont work...

df[126, 2:4] = 12 # E10000002 - This will need changing every run, I know it's pants...

  
df <- phe_rate(df, Count, Register, multiplier = 100) 

df[126, 2:7] = 0 # reset back to 0, I've asked Seb to upgrade this function with a NA argument!

# 14. Create PHOLIO sheet -----------------------------------------------------

df <- df %>%
  transmute(IndicatorID = 91300,
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


write.xlsx(df, file = "91300_LA.xlsx", sheetName = "PHOLIO")


  
  
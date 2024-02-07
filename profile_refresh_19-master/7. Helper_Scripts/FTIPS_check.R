
# Check any indicator with indicator number...
# Just replace any number used!
# the script checks all geographies for any indicator in any year

# 1. Load packages ------------------------------------------------------------

library(fingertipsR)
library(tidyverse)
library(data.table)

# 2. Check STP values ---------------------------------------------------------

STP <- fingertips_data(93307, AreaTypeID = 120) %>% # filter this indicator, 120 = STPs
  filter(AreaType == "STP") %>% # filter STPs only (Removes additional England value)
  filter(Timeperiod == max(Timeperiod)) %>% # latest upload date
  select(AreaCode, Sex, Age, Value, LowerCI95.0limit, UpperCI95.0limit, Count, Denominator, Valuenote) # Choose columns

sum(STP$Count, na.rm = TRUE) # Sum of Count without NAs = 240492
unique(STP$Valuenote) # Check value notes



# 3. Check CCG values ---------------------------------------------------------

CCG <- fingertips_data(93307, AreaTypeID = 152) %>% 
  filter(str_detect(AreaType, "CCG")) %>% 
  filter(Timeperiod == '2014/15' |
           Timeperiod == '2015/16'|
           Timeperiod == '2016/17'|
           Timeperiod == '2017/18') %>% 
  select(AreaCode, Sex, Age, Value, LowerCI95.0limit, UpperCI95.0limit, Count, Denominator, Valuenote) 

sum(CCG$Count, na.rm = TRUE) 
unique(CCG$Valuenote) 


# 4. Check LA values ----------------------------------------------------------

LA <- fingertips_data(91281, AreaTypeID = 102) %>% 
  filter(AreaType == "County & UA") %>% 
  filter(Timeperiod == max(Timeperiod)) %>% 
  select(AreaCode, Sex, Age, Value, LowerCI95.0limit, UpperCI95.0limit, Count, Denominator, Valuenote) 

sum(LA$Count, na.rm = TRUE) 
unique(LA$Valuenote) 


# 5. Check Regions ------------------------------------------------------------

Region <- fingertips_data(91283) %>% 
  filter(AreaType == "Region") %>% 
  filter(Timeperiod == max(Timeperiod)) %>% 
  select(AreaCode, Sex, Age, Value, LowerCI95.0limit, UpperCI95.0limit, Count, Denominator, Valuenote) 

sum(Region$Count, na.rm = TRUE) 
unique(Region$Valuenote) 



# 6. Check England value ------------------------------------------------------

England <- fingertips_data(93307) %>% 
  filter(AreaCode == 'E92000001') %>% # England code
  filter(Timeperiod == '2014' |
           Timeperiod == '2015'|
           Timeperiod == '2016'|
           Timeperiod == '2017')

sum(England$Count, na.rm = TRUE) 
unique(England$Valuenote) # Check value notes

# 7. Save any outputs to file -------------------------------------------------

fwrite(England, file = "Your_no_here.csv") # first bit is the dataset, 2nd bit is the name of the file



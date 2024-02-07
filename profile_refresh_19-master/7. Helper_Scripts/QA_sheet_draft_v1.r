# Indicator Dummy Run CCG ---------------------------------------------------------

# Dementia (aged under 65 years) as a Proportion of Total Dementia 
# (all ages) per 100 (2018)

#STAGE A - This compares the data against fingertips data from last year-------

#all links for part 2 will need to be updated to reflect the appropriate 

# 1a. Packages/Libraries -------------------------------------------------------

#install.packages("easypackages")
#install.packages("tidyverse")
#install.packages("data.table")
#install.packages("PHEindicatormethods")
#install.packages("readxl")
#install.packages("xlsx")
#install.packages("fingertipsR")
#install.packages("odbc")
#install.packages("dataframes2xls")
#install.packages("outliers")

## @knitr part1

library(easypackages)
library(fingertipsR)
library(tidyverse)
library(data.table)
library(PHEindicatormethods)
library(readxl)
library(dplyr)
library(odbc)
library(dataframes2xls)
library("outliers")
library(htmlTable)


#2a. Please update this data --------------------------------------------------

Indicator = 92849 # Update the indicator value the rest should run by itself if the naming convention is maintained
Directory_geo = "QA/Katies_stuff/automated/" # Update this to the folder for the indicator specific data such as the folder for geography lookups and indicators
Directory_pholio = "PHOLIO/ToQA/" # Update this to the folder where you can locate the pholio sheets for qa
Directory_general = "QA/Katies_Stuff/" # Update this to match the folder for the age and area type tables
Directory_output = "QA/QA_Reports/" # Update this to the folder where you want the qa report to be saved to
Year = 2018 #Enter either the year for the geography data
#ccg_data_source <- "http://geoportal.statistics.gov.uk/datasets/7e72ce9cd4204d588c6f8dd1cac77e98_0" # Enter the hyperlink for the ccg dataset used if the datalake was used then please enter where this could be found
#ltla_data_source <- "https://data.gov.uk/dataset/c4db4c00-d45c-426a-aab6-5b8db480356f/lower-tier-local-authority-to-upper-tier-local-authority-december-2018-lookup-in-england-and-wales and data lake" # Enter the hyperlink for the ltla dataset used if the datalake was used then please enter where this could be found
#stp_data_source <- "http://geoportal.statistics.gov.uk/datasets/7e72ce9cd4204d588c6f8dd1cac77e98_0" # Enter the hyperlink for the stp dataset used if the datalake was used then please enter where this could be found
#utla_data_source <- "https://data.gov.uk/dataset/c4db4c00-d45c-426a-aab6-5b8db480356f/lower-tier-local-authority-to-upper-tier-local-authority-december-2018-lookup-in-england-and-wales" # Enter the hyperlink for the utla dataset used if the datalake was used then please enter where this could be found
#rgn_data_source <- "http://geoportal.statistics.gov.uk/datasets/0c3a9643cc7c4015bb80751aad1d2594_0" # Enter the hyperlink for the rgn dataset used if the datalake was used then please enter where this could be found
#gp_data_source <- "https://digital.nhs.uk/services/organisation-data-service/data-downloads/gp-and-gp-practice-related-data" # Enter the hyperlink for the gp dataset used if the datalake was used then please enter where this could be found
count_link <- "https://www.cqc.org.uk/about-us/transparency/using-cqc-data - December" # Enter the hyperlink for the count dataset used if the datalake was used then please enter where this could be found
denominator_link <- "https://digital.nhs.uk/data-and-information/publications/statistical/recorded-dementia-diagnoses - December"# Enter the hyperlink for the denominator dataset used if the datalake was used then please enter where this could be found

#2a. Get data ------------------------------------------------------------------

fingertips_data_UTLA <- fingertips_data(IndicatorID = Indicator , AreaTypeID = 102)
fingertips_data_LTLA <- fingertips_data(IndicatorID = Indicator, AreaTypeID = 101)
fingertips_data_STP <- fingertips_data(IndicatorID = Indicator, AreaTypeID = 120)
fingertips_data_ccg <- fingertips_data(IndicatorID = Indicator, AreaTypeID = 152)
fingertips_data <- bind_rows(fingertips_data_UTLA,fingertips_data_LTLA, fingertips_data_STP, fingertips_data_ccg) %>%
  distinct()
if(file.exists(paste(Directory_pholio, "CCG/" , Indicator,"_CCG.xlsx", sep = "")))
  pholio_ccg <- read_excel(paste(Directory_pholio, "CCG/", Indicator,"_CCG.xlsx", sep = ""))#pholio document for qa this will be touched in last section
if(file.exists(paste(Directory_pholio, "LA/",Indicator, "_LA.xlsx", sep ="")))
  pholio_la <- read_excel(paste(Directory_pholio, "LA/", Indicator, "_LA.xlsx", sep ="")) #pholio document for qa this will be touched in last section
age_lup <- read_excel(paste(Directory_general,"age_lup.xlsx", sep ="")) #pholio document for qa this will be touched in last section
area_type_lup <- read_excel(paste(Directory_general, "area_type_lup.xlsx", sep = "")) #pholio document for qa this will be touched in last section
Month_desc <- c("Is this updated yearly?","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
Month <- c(0,1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
month_lup <- data.table(Month, Month_desc)

#3a. remove unnessesary objects --------------------------------------------------

rm(Month_desc, Month, fingertips_data_UTLA,fingertips_data_LTLA, fingertips_data_STP, fingertips_data_ccg)

#4a. Join pholio geography sheets ----------------------------------------------

if(exists("pholio_ccg") && exists("pholio_la")) {
  pholio <- data.frame(union(pholio_ccg, pholio_la)) %>%
    distinct()
} else if(exists("pholio_ccg")) {
  pholio <- data.frame(pholio_ccg) %>%
    distinct()
} else if (exists("pholio_la")) {
  pholio <- data.frame(pholio_la) %>%
    distinct()
} else {
  print("Why is there no pholio data?")
}
?exists
#5a. Format FPM and pholio sheet -------------------------------------------------

area_type_lup <- area_type_lup %>% select(1:2)
fingertips_data$Year <- as.integer(str_sub(fingertips_data$TimeperiodSortable, 1,4))
fingertips_data$Month <- ifelse(as.integer(substr(fingertips_data$TimeperiodSortable, 7, 7)) == 0, as.integer(substr(fingertips_data$TimeperiodSortable, 8, 8)), as.integer(substr(fingertips_data$TimeperiodSortable, 7, 8)))
fingertips_data$SexID <- ifelse(fingertips_data$Sex == "Persons", 4, ifelse( fingertips_data$sex == "Male", 1, ifelse(fingertips_data$sex == "Female", 2, -1)))
fingertips_data <- left_join(fingertips_data, age_lup, by = c("Age" = "Age"))
fingertips_data <- left_join(fingertips_data, area_type_lup, by = c("AreaType" = "Short_name"))
fingertips_data <- left_join(fingertips_data, month_lup, by = c("Month" = "Month"))
fingertips_data <- fingertips_data %>%
  filter(TimeperiodSortable==max(TimeperiodSortable))
colnames(fingertips_data) <- paste("old", colnames(fingertips_data), sep = "_")
print(as.integer(substr(fingertips_data$old_TimeperiodSortable, 7, 7)))


#6a. Join FPM and pholio sheet -------------------------------------------------

fpm_pholio <- full_join(pholio, fingertips_data, by = c("AreaCode" = "old_AreaCode")) %>%
  distinct()

fpm_pholio <- within(fpm_pholio, geography_change <- if_else(is.na(Count), "Has this geography been removed?",if_else (is.na(old_Count), "Is this a new geography?", if_else(Value == -1, "why is this value missing?", if_else(fpm_pholio$Count > Denominator, "Why is the count greater than the denominator?", "")))))

geographies_to_review <- fpm_pholio %>%
  filter(is.na(Count) | is.na(old_Count) | Value == -1 | fpm_pholio$Count > Denominator)

fpm_pholio <- fpm_pholio %>%
  filter(!is.na(Count)) %>%
  filter(!is.na(old_Count)) %>%
  filter( Value != -1) %>%
  filter(Count <= Denominator)

fpm_pholio$Value <- as.numeric(fpm_pholio$Value)

#fpm_pholio <- fpm_pholio[order(fpm_pholio$AreaCode, decreasing = TRUE),]


#7a. compare colums ------------------------------------------------------------



for (i in 1:nrow(fpm_pholio)) {
  fpm_pholio$significance_test[i] <- t.test(fpm_pholio$Value, mu = fpm_pholio$Value[i])$p.value
}

fpm_pholio <- within(fpm_pholio, month_compare <- if_else( Month == old_Month, "", "Month does not match the value for last year,"))
fpm_pholio <- within(fpm_pholio, year_compare <- if_else( (old_Year + 1) == Year, "", "Year is not one greater than the value for last year,"))
fpm_pholio <- within(fpm_pholio, sex_compare <- if_else( SexID == old_SexID, "", "Sex ID does not match the value for last year,"))
fpm_pholio <- within(fpm_pholio, age_compare <- if_else( AgeID == old_AGEID, "", "Age ID does not match the value for last year,"))
fpm_pholio <- within(fpm_pholio, value_compare <- if_else( (round((((Value - old_Value)/old_Value)*100),2)^2) >= (8^2), "", "Value has increased/decreased more than 8% compared to last year,"))
fpm_pholio <- within(fpm_pholio, count_compare <- if_else( (round((((Count - old_Count)/old_Count)*100),2)^2) >= (8^2), "Count has increased/decreased more than 8% compared to last year,", ""))
fpm_pholio <- within(fpm_pholio, denom_compare <- if_else( (round((((Denominator - old_Denominator)/old_Denominator)*100),2)^2) >= (8^2), "Denominator has increased/decreased more than 8% compared to last year,", ""))
fpm_pholio <- within(fpm_pholio, upper_compare <- if_else( (round((((LowerCI95 - old_LowerCI95.0limit)/old_LowerCI95.0limit)*100),2)^2) >= (8^2), "Upper confidence interval has increased/decreased more than 8% compared to last year,", ""))
fpm_pholio <- within(fpm_pholio, lower_compare <- if_else( (round((((UpperCI95 - old_UpperCI95.0limit)/old_UpperCI95.0limit)*100),2)^2) >= (8^2), "Lower confidence interval has increased/decreased more than 8% compared to last year,", ""))
fpm_pholio <- within(fpm_pholio, CI_new_compare <- if_else( (Value <= UpperCI95 & Value >= LowerCI95), "", "Value does not lie within the limits of the confidence intervals of this year,"))
fpm_pholio <- within(fpm_pholio, CI_old_compare <- if_else( (Value <= old_UpperCI95.0limit & Value >= old_LowerCI95.0limit), "", "Value does not lie within the limits of the confidence intervals of last year,"))
fpm_pholio <- within(fpm_pholio, Value_calc_compare <- if_else(round(((Count/Denominator)*100),8) == round(Value,8),"", "The recalculated values using the count and denominator figures from the pholio sheet do not match those in the pholio sheet,"))
fpm_pholio <- within(fpm_pholio, LowerCI95_calc_compare <- if_else(round((wilson_lower(Count, Denominator, confidence = 0.95)*100),8) == round(LowerCI95,8),"", "The recalculated lower confidence intervals using the count and denominator figures from the pholio sheet do not match those in the pholio sheet,"))
fpm_pholio <- within(fpm_pholio, UpperCI95_calc_compare <- if_else((wilson_upper(Count, Denominator, confidence = 0.95) * 100 )== UpperCI95, "", "The recalculated upper confidence intervals using the count and denominator figures from the pholio sheet do not match those in the pholio sheet"))
fpm_pholio <- within(fpm_pholio, significance_test_compare <- if_else(fpm_pholio$significance_test>= 0.05, "This result is statistically significant,", "" ))
fpm_pholio <- within(fpm_pholio, Identified_potential_issues <- paste(`month_compare`, 
                                                                      `year_compare`, 
                                                                      `sex_compare`, 
                                                                      `age_compare`, 
                                                                      `value_compare`, 
                                                                      `count_compare`, 
                                                                      `denom_compare`,
                                                                      `upper_compare`,
                                                                      `lower_compare`,
                                                                      `CI_new_compare`,
                                                                      `CI_old_compare`,
                                                                      `Value_calc_compare`,
                                                                      `LowerCI95_calc_compare`,
                                                                      `UpperCI95_calc_compare`,
                                                                      `significance_test_compare`,
                                                                      sep = ""))
#8a. QA overview report --------------------------------------------------------

qa_overview_report <- data.frame()

test <- c("geography_not_in_fingertips" , 
          "geography_not_in_pholio" , 
          "change_in_month_count" , 
          "change_in_year_count",
          "change_in_sex_count",
          "change_in_age_count" , 
          "value_perc_change_over_8" , 
          "count_perc_change_over_8" ,                               
          "denominator_perc_change_over_8" ,
          "lower_ci_perc_change_over_8" , 
          "upper_ci_perc_change_over_8", 
          "ci_logic_test" , 
          "old_ci_test" ,
          "statistical_significance",
          "change_value_calc_count" , 
          "change_lower_calc_count" , 
          "change_upper_calc_count" ,
          "IndicatorID_unq",
          "year_unq",
          "yearrange_unq" ,
          "quarter_unq" ,
          "month_unq" ,
          "ageID_unq" ,
          "sexID_unq" ,
          "areaCode_number_pholio" ,
          "ccg_number_pholio" ,
          "la_number_pholio" ,
          "lowerCI99_8_unq" ,
          "upperCI99_8_unq" ,
          "denominator_2_unq" ,
          "valueNoteID_unq" ,
          "categoryTypeID_unq" ,
          "categoryid_unq" ,
          "England_count_total" ,
          "ccg_count_total" ,
          "stp_count_total" ,
          "rgn_count_total" ,
          "ltla_count_total" ,
          "England_denominator_total",
          "ccg_denominator_total" ,
          "stp_denominator_total" ,
          "rgn_denominator_total",
          "ltla_denominator_total",
          "min_value" ,
          "max_value",
          "range_value_difference_new" ,
          "range_value_difference_old" ,
          "min_value_this_year_vs_last_year_difference" ,
          "max_value_this_year_vs_last_year_difference" )



test_results <- c(sum(is.na(geographies_to_review$old_AreaType)), 
                  sum(is.na(geographies_to_review$IndicatorID)), 
                  print(nrow(subset(fpm_pholio, fpm_pholio$month_compare == "Month does not match the value for last year,"))),#sum(fpm_pholio$month_compare, na.rm=TRUE), 
                  nrow(subset(fpm_pholio, fpm_pholio$year_compare == "Year is not one greater than the value for last year,")), 
                  nrow(subset(fpm_pholio,fpm_pholio$sex_compare == "Sex ID does not match the value for last year,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$age_compare == "Age ID does not match the value for last year,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$value_compare == "Value has increased/decreased more than 8% compared to last year,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$count_compare == "Count has increased/decreased more than 8% compared to last year,")),                               
                  nrow(subset(fpm_pholio, fpm_pholio$denom_compare == "Count has increased/decreased more than 8% compared to last year,")),
                  nrow(subset(fpm_pholio, fpm_pholio$lower_compare == "Lower confidence interval has increased/decreased more than 8% compared to last year,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$upper_compare == "Upper confidence interval has increased/decreased more than 8% compared to last year,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$CI_new_compare == "Value does not lie within the limits of the confidence intervals of this year,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$CI_old_compare == "Value does not lie within the limits of the confidence intervals of last year,")),
                  nrow(subset(fpm_pholio, fpm_pholio$significance_test_compare == "This result is statistically significant,")),
                  nrow(subset(fpm_pholio, fpm_pholio$Value_calc_compare == "The recalculated values using the count and denominator figures from the pholio sheet do not match those in the pholio sheet,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$LowerCI95_calc_compare == "The recalculated lower confidence intervals using the count and denominator figures from the pholio sheet do not match those in the pholio sheet,")), 
                  nrow(subset(fpm_pholio, fpm_pholio$UpperCI95_calc_compare == "The recalculated upper confidence intervals using the count and denominator figures from the pholio sheet do not match those in the pholio sheet")), 
                  ifelse(length(unique(fpm_pholio[["IndicatorID"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["Year"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["YearRange"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["Quarter"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["Month"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["AgeID"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["sexID"]]))> 1, "Investigate","Good"),
                  nrow(unique(pholio)),
                  if(exists("pholio_ccg")) {
                    nrow(unique(pholio_ccg))
                  } else {
                    0
                  },
                  if(exists("pholio_la")){
                    nrow(unique(pholio_la))
                  } else {
                    0
                  },
                  ifelse(length(unique(fpm_pholio[["LowerCI99_8"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["UpperCI99_8"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["Denominator_2"]]))> 1, "Investigate","Good"),
                  length(unique(fpm_pholio[["ValueNoteid"]])),
                  ifelse(length(unique(fpm_pholio[["CategoryTypeid"]]))> 1, "Investigate","Good"),
                  ifelse(length(unique(fpm_pholio[["Categoryid"]]))> 1, "Investigate","Good"),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E92", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E92", select = `Count`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E38", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E38", select = `Count`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E54", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E54", select = `Count`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E12", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E12", select = `Count`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) %in% c("E06", "E07", "E08", "E09", "E10"), select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) %in% c("E06", "E07", "E08", "E09", "E10"), select = `Count`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E92", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E92", select = `Denominator`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E38", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E38", select = `Denominator`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E54", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E54", select = `Denominator`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E12", select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) == "E12", select = `Denominator`)),0)),
                  print(ifelse(nrow(subset(pholio, str_sub(pholio$AreaCode, 1,3) %in% c("E06", "E07", "E08", "E09", "E10"), select = `Count`)) > 0, sum(subset(pholio, str_sub(pholio$AreaCode, 1,3) %in% c("E06", "E07", "E08", "E09", "E10"), select = `Denominator`)),0)),
                  min(fpm_pholio$Value),
                  max(fpm_pholio$Value),
                  max(fpm_pholio$Value) - min(fpm_pholio$Value),
                  max(fpm_pholio$old_Value) - min(fpm_pholio$old_Value),
                  min(fpm_pholio$Value) - min(fpm_pholio$old_Value),
                  max(fpm_pholio$Value) - max(fpm_pholio$old_Value))


Other_info <- c(toString(unique(geographies_to_review$AreaCode)), 
                toString(unique(geographies_to_review$old_AreaName)),
                toString(unique(fpm_pholio$Month), unique(fpm_pholio$old_Month)),
                toString(unique(fpm_pholio$Year, fpm_pholio$old_Year)),
                toString(unique(fpm_pholio$SexID)),
                toString(unique(fpm_pholio$AgeID, fpm_pholio$old_AgeID)),
                "See qa overview data for relevant geographies", 
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                "See qa overview data for relevant geographies",
                toString(unique(fpm_pholio$IndicatorID)),
                toString(unique(fpm_pholio$Year, fpm_pholio$old_Year)),
                toString(unique(fpm_pholio$YearRange, fpm_pholio$old_YearRange)),
                toString(unique(fpm_pholio$Quarter, fpm_pholio$old_Quarter)),
                toString(unique(fpm_pholio$Month)),
                toString(unique(fpm_pholio$AgeID, fpm_pholio$old_AgeID)),
                toString(unique(fpm_pholio$SexID)),
                "Check against expected values",
                "Check against expected values",
                "Check against expected values",
                toString(unique(fpm_pholio$LowerCI99_8, fpm_pholio$old_LowerCI99.8limit)),
                toString(unique(fpm_pholio$UpperCI99_8, fpm_pholio$old_UpperCI99.8limit)),
                toString(unique(fpm_pholio$Denominator_2, fpm_pholio$old_Denominator_2)),
                toString(unique(fpm_pholio$ValueNoteId)),
                toString(unique(fpm_pholio$CategoryTypeId, fpm_pholio$old_CategoryType)),
                toString(unique(fpm_pholio$CategoryId, fpm_pholio$old_Category)),
                "Compare against other geography values",
                "Compare against England value as it should be equal",
                "Compare against England value as it should be equal",
                "Compare against England value as it should be equal",
                "Compare against England value as it should be equal",
                "Compare against other geography values",
                "Compare against England value as it should be equal",
                "Compare against England value as it should be equal",
                "Compare against England value as it should be equal",
                "Compare against England value as it should be equal",
                "Does this seem abnormally low?",
                "Does this seem abnormally high?",
                "How does this compare to 'range_value_difference_old'?",
                "How does this compare to 'range_value_difference_new'?",
                "Is there a big difference between last years minimum value and this years minimum value?",
                "Is there a big difference between last years maximum value and this years maximum value?")

definitions <- c("Identifies the number of geographies which are new to the pholio data set. These have been identified for further investigation.",
                 "Identifies the number of geographies which are missing from the pholio data set. These have been identified for further investigation.",
                 "Identifies the number of geographies which have a month value which is different to the previous year in the pholio dataset",
                 "Identifies the number of geographies which have a year value which is different to the previous year in the pholio dataset",
                 "Identifies the number of geographies which have a sex value which is different to the previous year in the pholio dataset",
                 "Identifies the number of geographies which have a age value which is different to the previous year in the pholio dataset",
                 "Identifies the number of geographies which has a value percentage change of => 8 compared to the previous year",
                 "Identifies the number of geographies which has a count percentage change of => 8 compared to the previous year",
                 "Identifies the number of geographies which has a denominator percentage change of => 8 compared to the previous year",
                 "Identifies the number of geographies which has a lower CI percentage change of => 8 compared to the previous year",
                 "Identifies the number of geographies which has a upper CI percentage change of => 8 compared to the previous year",
                 "Identifies the number of geographies which have a value which is outside of the limits of the confidence interval in the pholio sheet",
                 "Identifies the number of geographies which have a value which is outside of the limits of the old confidence interval in the pholio sheet",
                 "Identifies the number of geographies which have are statistically significant",
                 "Identifies the number of geographies which have a different calculated value using the count and denominator from the pholio sheet",
                 "Identifies the number of geographies which have a different calculated lower CI using the count and denominator from the pholio sheet",
                 "Identifies the number of geographies which have a different calculated upper CI using the count and denominator from the pholio sheet",
                 "Checks to make sure that only one value has been entered for the indicator id column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the year column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the year range column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the quarter column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the month column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the age id column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the sex id column. This value/values has been identified.",
                 "Identifies the number of unique geographies in the pholio sheet",
                 "Identifies the number of unique geographies in the CCG pholio sheet",
                 "Identifies the number of unique geographies in the LA pholio sheet",
                 "Checks to make sure that only one value has been entered for the lowerCI99_8 column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the upperCI99_8 column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the denominator 2 column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the value note id column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the category type id column. This value/values has been identified.",
                 "Checks to make sure that only one value has been entered for the category id column. This value/values has been identified.",
                 "Sums of the count for England in the pholio datasheet",
                 "Sum of the count for all CCG's in the pholio datasheet",
                 "Sum of the count for all STP's in the pholio datasheet",
                 "Sum of the count for all regions in the pholio datasheet",
                 "Sum of the count for all lower tier local authorities in the pholio datasheet",
                 "Sum of the denominator for England in the pholio datasheet",
                 "Sum of the denominator for all CCG's in the pholio datasheet",
                 "Sum of the denominator for all STP's in the pholio datasheet",
                 "Sum of the denominator for all regions in the pholio datasheet",
                 "Sum of the denominator for all lower tier local authorities in the pholio datasheet",
                 "Provides the minimum value in this years pholio sheet",
                 "Provides the maximum value in this years pholio sheet",
                 "Provides the difference between the minimum and maximum values in this years pholio sheet",
                 "Provides the difference between the minimum and maximum values in last years pholio sheet",
                 "Provides the minimum value in this years pholio sheet to the minimum in last years pholio sheet",
                 "Provides the maximum value in this years pholio sheet to the maximum in last years pholio sheet")

qa_overview_report <- cbind(test,test_results, Other_info, definitions) # %>%

qa_overview_report <- data.frame(qa_overview_report)

rm(test,test_results,definitions, Other_info)

#9a Data to look into ----------------------------------------------------------

qa_overview_data <- fpm_pholio %>%
  #filter(is.na(old_IndicatorID)| is.na(IndicatorID) | month_compare != "" | year_compare != "" | sex_compare != "" | age_compare != "" | value_compare != "" | count_compare != "" | denom_compare != "" | upper_compare != "" | lower_compare != "" | CI_new_compare != "" | CI_old_compare != "" | Value_calc_compare != "" | LowerCI95_calc_compare != "" | UpperCI95_calc_compare != "" | ValueNoteId != "") %>%
  select(1:19, ncol(fpm_pholio)) 

geographies_to_review <- geographies_to_review %>%
  select(1:19, ncol(geographies_to_review))

#10a export data --------------------------------------------------------------
if(!file.exists(paste(Directory_output, Indicator, sep="")))
  dir.create(paste(Directory_output, Indicator, sep=""))

write_excel_csv(qa_overview_report, paste(Directory_output, Indicator, "/", Indicator, "_QA_report.xls", sep=""), append = FALSE, col_names = TRUE)
write_excel_csv(qa_overview_data, paste(Directory_output, Indicator, "/", Indicator, "_QA_data.xls", sep=""), append = FALSE, col_names = TRUE)
write_excel_csv(qa_overview_data, paste(Directory_output, Indicator, "/", Indicator, "_QA_geo_data.xls", sep=""), append = FALSE, col_names = TRUE)

max(fpm_pholio$Value)

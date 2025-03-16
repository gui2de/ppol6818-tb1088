global data_path "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088/week_05/03_assignment/01_data"
*Q1: Tanzania Student Data 
*This builds on the bonus from the previous Stata assignment. We downloaded the PSLE data of students from 138 schools in Arusha District in Tanzania (previously we only had data of just 1 school) You can build on your code from the previous assignment to create a student level dataset for these 138 schools.
use "$data_path/q1_psle_student_raw.dta", clear
describe
gen html_text = s

// extracting school-level information
gen school_name = regexs(1) if regexm(html_text, "([A-Z ]+ PRIMARY SCHOOL)")
gen school_code = regexs(1) if regexm(html_text, "(PS[0-9]+)")
gen num_students = real(regexs(1)) if regexm(html_text, "WALIOFANYA MTIHANI : ([0-9]+)")
gen school_avg = real(regexs(1)) if regexm(html_text, "WASTANI WA SHULE   : ([0-9]+\.[0-9]+)")
gen student_group = "Under 40" if regexm(html_text, "KUNDI LA SHULE : Wanafunzi chini ya 40")
replace student_group = ">=40" if student_group == ""

gen rank_council = regexs(1) + " out of " + regexs(2) if regexm(html_text, "NAFASI YA SHULE KWENYE KUNDI LAKE KIHALMASHAURI: ([0-9]+) kati ya ([0-9]+)")
gen rank_region = regexs(1) + " out of " + regexs(2) if regexm(html_text, "NAFASI YA SHULE KWENYE KUNDI LAKE KIMKOA  : ([0-9]+) kati ya ([0-9]+)")
gen rank_national = regexs(1) + " out of " + regexs(2) if regexm(html_text, "NAFASI YA SHULE KWENY E KUNDI LAKE KITAIFA : ([0-9]+) kati ya ([0-9]+)")

expand num_students

// extracting student data
gen cand_id = regexs(1) if regexm(html_text, "(PS[0-9]+-[0-9]+)")
gen prem_number = regexs(1) if regexm(html_text, "([0-9]{11})")
gen gender = regexs(1) if regexm(html_text, ">(M|F)<")

// student names
gen name = regexs(1) if regexm(html_text, "([A-Za-z ]+)</FONT></TD>\s*<TD[^>]+>")


// extracting grades
gen kiswahili = regexs(1) if regexm(html_text, "Kiswahili - ([A-E])")
gen english = regexs(1) if regexm(html_text, "English - ([A-E])")
gen maarifa = regexs(1) if regexm(html_text, "Maarifa - ([A-E])")
gen hisabati = regexs(1) if regexm(html_text, "Hisabati - ([A-E])")
gen science = regexs(1) if regexm(html_text, "Science - ([A-E])")
gen uraia = regexs(1) if regexm(html_text, "Uraia - ([A-E])")
gen average = regexs(1) if regexm(html_text, "Average Grade - ([A-E])")

keep school_name school_code cand_id prem_number gender name kiswahili english maarifa hisabati science uraia average




*Q2: Côte d'Ivoire Population Density
*We have household survey data and population density data of Côte d'Ivoire. Merge departmente-level density data from the excel sheet (CIV_populationdensity.xlsx) into the household data (CIV_Section_O.dta) i.e. add population density column to the CIV_Section_0 dataset.
import excel "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088/week_05/03_assignment/01_data/q2_CIV_populationdensity.xlsx", firstrow clear

* Step 2: Check structure and verify department variable
describe
list in 1/5  

* Step 3: Rename department variable for merging
gen locality_clean = lower(trim(NOMCIRCONSCRIPTION))

* Remove administrative descriptors (district, department)
replace locality_clean = subinstr(locality_clean, "district autonome d'", "", .)
replace locality_clean = subinstr(locality_clean, "departement d'", "", .)
replace locality_clean = trim(locality_clean)  // Trim extra spaces

rename NOMCIRCONSCRIPTION b10_nomvillag   // Rename to match household data
collapse (sum) POPULATION SUPERFICIEKM2 DENSITEAUKM, by(locality_clean)
* Step 4: Save cleaned population density data
save "$data_path/q2_CIV_populationdensity_cleaned.dta", replace

* Step 5: Load the household survey data
use "$data_path/q2_CIV_Section_0.dta", clear

* Step 6: Check structure and verify department variable
describe
list in 1/5  
gen locality_clean = lower(trim(b10_nomvillag))
save Section_0_clean.dta, replace
save "$data_path/q2_CIV_Section_0_cleaned.dta", replace
* Step 7: Merge population density data into household data using department name
use Section_0_clean.dta, clear
merge m:1 locality_clean using q2_CIV_populationdensity_cleaned.dta

drop _merge
drop if missing(POPULATION) | missing(SUPERFICIEKM2) | missing(DENSITEAUKM)
save merged_dataset.dta, replace


*Q3:Enumerator Assignment based on GPS
*We have the GPS coordinates for 111 households from a particular village. You are a field manager and your job is to assign these households to 19 enumerators (~6 surveys per enumerator per day) in such a way that each enumerator is assigned 6 households that are close to each other (this would reduce the amount of time they spend walking from one house to another.) Manually assigning them for each village will take you a lot of time. Your job is to write an algorithm that would auto assign each household (i.e. add a column and assign it a value 1-19 which can be used as enumerator ID). Note: Your code should still work if I run it on data from another village.
use "$data_path/q3_GPS Data.dta", clear
destring latitude longitude, replace force

* Calculate min and max for latitude and longitude
egen min_lat = min(latitude)
egen max_lat = max(latitude)
egen min_lon = min(longitude)
egen max_lon = max(longitude)

* Standardize latitude and longitude for clustering
gen lat_scaled = (latitude - min_lat) / (max_lat - min_lat)
gen lon_scaled = (longitude - min_lon) / (max_lon - min_lon)

* Perform hierarchical clustering using Ward's method
cluster wardslinkage lat_scaled lon_scaled, name(household_clusters)

* Cut the dendrogram into 19 groups (for 19 enumerators)
cluster generate enumerator_id = group(19)


* Save the dataset with assignments
save "$data_path/q3_GPS Data_assigned.dta", replace

*Q4: 2010 Tanzania Election Data cleaning
*2010 election data (Tz_election_2010_raw.xlsx) from Tanzania is not usable in its current format. You have to create a dataset in the wide form, where each row is a unique ward, and votes received by each party are given in separate columns. You can check the following dta file as a template for your output: Tz_elec_template. Your objective is to clean the dataset in such a way that it resembles the format of the template dataset.
 use "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088/week_05/03_assignment/01_data/q4_Tz_election_template.dta", clear

import excel "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088/week_05/03_assignment/01_data/q4_Tz_election_2010_raw.xls", firstrow cellrange(A5) clear

* Drop unnecessary columns
capture drop K  // Drop column K
capture drop G  // Drop column G (since SEX already represents gender)

* Drop the first row if it's an extra header
capture drop in 1

* Fill down missing values in REGION, DISTRICT, COSTITUENCY, and WARD
foreach var in REGION DISTRICT COSTITUENCY WARD {
    replace `var' = `var'[_n-1] if missing(`var')
}

* Fill missing SEX values as "F" (Female)
replace SEX = "F" if missing(SEX)

* Fill missing ELECTEDCANDIDATE values as "Not Selected"
replace ELECTEDCANDIDATE = "Not Selected" if missing(ELECTEDCANDIDATE)

* Destring numeric columns (like TTLVOTES) by removing extra text
replace TTLVOTES = subinstr(TTLVOTES, " votes", "", .)  
destring TTLVOTES, replace force  

* Save the cleaned dataset
save "Tz_election_2010_cleaned.dta", replace

*Q5: Tanzania PSLE data
*PSLE dataset contains data of 17,329 schools. We have the region and district of each school but for our analysis we need the ward information. There is another dataset (q5_school_location) that has the ward information of 19,733 schools. Your job is to identify ward information for 17,329 schools on the PSLE dataset using the q5_school_location.dta. Note: Final dataset should be the PSLE dataset + ward column (i.e. N = 17,329). Hint: You might have to try different methods to get the best results, even then you might have some schools where we can't find ward information. 


* CLEAN SCHOOL NAMES IN PSLE 
use "$data_path/q5_psle_2020_data.dta", clear

* Convert school names to lowercase and trim spaces
gen school_clean = lower(schoolname)
replace school_clean = trim(school_clean)

* Remove common variations (punctuation, abbreviations)
replace school_clean = subinstr(school_clean, ".", "", .)
replace school_clean = subinstr(school_clean, ",", "", .)
replace school_clean = subinstr(school_clean, " primary school", "", .) 
replace school_clean = subinstr(school_clean, " p.s", "", .) 
replace school_clean = subinstr(school_clean, " sec school", " secondary", .)

* Save cleaned PSLE dataset
save "$data_path/q5_psle_2020_data_clean.dta", replace

use "$data_path/q5_psle_2020_data_clean.dta", clear

* Extract school name before the hyphen (if ID exists)
gen school_clean_short = regexs(1) if regexm(school_clean, "(.+?) - ps[0-9]+")
replace school_clean_short = school_clean if school_clean_short == ""

* Trim spaces to ensure consistency
replace school_clean_short = trim(school_clean_short)

* Verify the extraction
list school_clean school_clean_short if _n <= 20

* Save the dataset with the new variable
save "$data_path/q5_psle_2020_data_clean_short.dta", replace


*CLEAN AND DEDUPLICATE SCHOOL LOCATION DATASET 
use "$data_path/q5_school_location.dta", clear

* Convert school names to lowercase and trim spaces
gen school_clean = lower(School)
replace school_clean = trim(school_clean)

* Remove common variations (punctuation, abbreviations)
replace school_clean = subinstr(school_clean, ".", "", .)
replace school_clean = subinstr(school_clean, ",", "", .)
replace school_clean = subinstr(school_clean, " primary school", "", .) 
replace school_clean = subinstr(school_clean, " p.s", "", .) 
replace school_clean = subinstr(school_clean, " sec school", " secondary", .)

* Keep only necessary columns
keep school_clean Ward

* Check for duplicates
duplicates report school_clean

* If duplicates exist, list a few duplicate cases
duplicates list school_clean if _N > 1

* Deduplicate: Keep the most common ward per school
bysort school_clean Ward: gen ward_count = _N
bysort school_clean (ward_count): replace Ward = Ward[_N]
duplicates drop school_clean, force
drop ward_count


save "$data_path/q5_school_location_clean_unique.dta", replace


*MERGE CLEANED DATASETS ON SCHOOL NAME 
use "$data_path/q5_psle_2020_data_clean_short.dta", clear
merge m:1 school_clean using "$data_path/q5_school_location_clean_unique.dta"
tab _merge
drop _merge
save "$data_path/q5_psle_merged_exact.dta", replace









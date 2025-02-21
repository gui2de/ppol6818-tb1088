* Set the global working directory
global wd "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088/Week_03"

* Load the datasets using the global path
use "$wd/04_assignment/01_data/q1_data/school.dta", clear
use "$wd/04_assignment/01_data/q1_data/student.dta", clear
use "$wd/04_assignment/01_data/q1_data/subject.dta", clear
use "$wd/04_assignment/01_data/q1_data/teacher.dta", clear

**# Bookmark #1
*Q1:As part of a larger examination of how various factors contribute to student achievement, you have been asked to find a couple of pieces of information about a school district. Unfortunately, the relevant data is spread across four different files (student.dta, teacher.dta, school.dta, and subject.dta all in the following subfolder: q1_data. See the readme file for more details regarding each dataset.

*(a) What is the mean attendance of students at southern schools?
* Merge with teacher dataset using correct variable names
use "$wd/04_assignment/01_data/q1_data/student.dta", clear

* Rename primary_teacher to match teacher before merging
rename primary_teacher teacher

* Merge with teacher dataset
merge m:1 teacher using "$wd/04_assignment/01_data/q1_data/teacher.dta"
drop if _merge == 2  // Remove unmatched teacher records
drop _merge

* Merge with school dataset to get location
merge m:1 school using "$wd/04_assignment/01_data/q1_data/school.dta"
drop if _merge == 2  // Remove unmatched school records
drop _merge

* Filter for southern schools
keep if loc == "South"

* Calculate mean attendance for southern schools
summarize attendance

*(b) Of all students in high school, what proportion of them have a primary teacher who teaches a tested subject?
use "$wd/04_assignment/01_data/q1_data/teacher.dta", clear

* Merge teachers with subjects to get tested subjects
merge m:1 subject using "$wd/04_assignment/01_data/q1_data/subject.dta"
drop if _merge == 2  // Remove subjects without matching teachers
drop _merge

* Save the updated teacher dataset with tested subjects
save "$wd/04_assignment/01_data/q1_data/teacher_with_subject.dta", replace

* Step 2: Load student dataset and merge with teacher data
use "$wd/04_assignment/01_data/q1_data/student.dta", clear
rename primary_teacher teacher

* Merge student data with teacher data (which now contains tested subjects)
merge m:1 teacher using "$wd/04_assignment/01_data/q1_data/teacher_with_subject.dta"
drop if _merge == 2  // Remove students without matching teachers
drop _merge

* Step 3: Merge with school data to get the school level
merge m:1 school using "$wd/04_assignment/01_data/q1_data/school.dta"
drop if _merge == 2  // Remove unmatched school records
drop _merge

* Step 4: Keep only high school students
keep if level == "High"

* Step 5: Create an indicator for students whose teacher teaches a tested subject
gen tested_subject = (tested == 1)

* Step 6: Calculate the proportion of high school students with a tested subject teacher
summarize tested_subject


*(c) What is the mean gpa of all students in the district?
use "$wd/04_assignment/01_data/q1_data/student.dta", clear

* Rename primary_teacher to match teacher before merging
rename primary_teacher teacher

* Merge with teacher dataset
merge m:1 teacher using "$wd/04_assignment/01_data/q1_data/teacher.dta"
drop if _merge == 2  // Remove unmatched teacher records
drop _merge

* Merge with school dataset to get location
merge m:1 school using "$wd/04_assignment/01_data/q1_data/school.dta"
drop if _merge == 2  // Remove unmatched school records
drop _merge
* Calculate the mean GPA for all students
summarize gpa

*(d) What is the mean attendance of each middle school? 
keep if level == "Middle"

* Compute mean attendance for each middle school
collapse (mean) attendance, by(school)

* Display the results
list school attendance

*Q2: You are working on a crop insurance project in Kenya. For each household, we have the following information: village name, pixel and payout status.
*a)	Payout variable should be consistent within a pixel, confirm if that is the case. Create a new dummy variable (pixel_consistent), this variable =0 if payout variable isn't consistent within that pixel (i.e. =1 when all the payouts are exactly the same, =0 if there is even a single different payout in the pixel) 
use "$wd/04_assignment/01_data/q2_village_pixel.dta", clear
// checking if pixels are repeated by payout
bys pixel: tab payout // looks like payouts are uniform within pixels

// generating max and min payouts
bys pixel: egen max_payout = max(payout)
bys pixel: egen min_payout = min(payout)

// checking for pixel consistency in payout
bys pixel: gen pixel_consistent = (max_payout == min_payout)
codebook pixel_consistent 

*b)	Usually the households in a particular village are within the same pixel but it is possible that some villages are in multiple pixels (boundary cases). Create a new dummy variable (pixel_village), =0 for the entire village when all the households from the village are within a particular pixel, =1 if households from a particular village are in more than 1 pixel. Hint: This variable is at village level.
// tagging first obs of each pixel for village
bys village pixel: gen tag = _n == 1
bys village: gen n_pixels = sum(tag)

// 1: village in more than one pixel    0: in one pixel
gen pixel_village = (n_pixels > 1)
codebook pixel_village

tab vill if pixel_village == 1

*c)	For this experiment, it is only an issue if villages are in different pixels AND have different payout status. For this purpose, divide the households in the following three categories:
**i.	Villages that are entirely in a particular pixel. (==1)
**ii.	Villages that are in different pixels AND have same payout status (Create a list of all hhids in such villages) (==2)
***iii.	Villages that are in different pixels AND have different payout status (==3)
*Hint: These 3 categories are mutually exclusive AND exhaustive i.e. every single observation should fall in one of the 3 categories. Note also that the categories may or may not line up with what you created in (a) and (b) so read the instructions closely.
gen hh_status = .

// hh if village entirely in pixel
replace hh_status = 1 if pixel_village == 0

// hh if village is in > 1 pixel & same payout
bys village payout: gen pay_tag = _n == 1
bys village: egen n_payout = sum(pay_tag)
gen payout_consistent = (n_payout == 1) // 1: 1 payout    0: > 1 payout
replace hh_status = 2 if pixel_village == 1 & payout_consistent == 1

// hh if village > 1 pixel & different payout
replace hh_status = 3 if pixel_village == 1 & payout_consistent == 0
codebook hh_


*Q3: Faculty members submitted 128 proposals for funding opportunities. Unfortunately, we only have enough funding for 50 grants. Each proposal was assigned randomly to three selected reviewers who each gave a score between 1 (lowest) and 5 (highest). Each person reviewed 24 proposals and assigned a score. We think it will be better if we normalize the score wrt each reviewer (using unique ids) before calculating the average score. Add the following columns 1) stand_r1_score 2) stand_r2_score 3) stand_r3_score 4) average_stand_score 5) rank (Note: highest score =>1, lowest => 128)
*Hint: We can normalize scores using the following formula: (score – mean)/sd, where mean = mean score of that particular reviewer (based on the netid), sd = standard deviation of scores of that particular reviewer (based on that netid). (Hint: we are not standardizing the score wrt reviewer 1, 2 or 3. But by the netID.)
use "$wd/04_assignment/01_data/q3_proposal_review.dta", clear

* Fix reviewer names (correct typo if necessary)
rename Rewiewer1 Reviewer1
rename Review1Score Reviewer1Score

* Rename reviewer scores for reshaping
rename Reviewer1Score ReviewerScore1
rename Reviewer2Score ReviewerScore2
rename Reviewer3Score ReviewerScore3

* Create an ID variable for reshaping
gen id = _n  

* Reshape the dataset to long format
reshape long ReviewerScore, i(id) j(reviewer_num)

* Assign correct reviewer net ID
gen reviewer_id = ""
replace reviewer_id = Reviewer1 if reviewer_num == 1
replace reviewer_id = Reviewer2 if reviewer_num == 2
replace reviewer_id = Reviewer3 if reviewer_num == 3

* Compute mean and standard deviation for each reviewer
bysort reviewer_id: egen mean_score = mean(ReviewerScore)
bysort reviewer_id: egen sd_score = sd(ReviewerScore)

* Standardize the scores
gen stand_score = (ReviewerScore - mean_score) / sd_score

* **Drop variables that prevent reshaping**
drop ReviewerScore reviewer_id mean_score sd_score

* Reshape back to wide format (Only keeping standardized scores)
reshape wide stand_score, i(id) j(reviewer_num)

* Rename standardized score columns
rename stand_score1 stand_r1_score
rename stand_score2 stand_r2_score
rename stand_score3 stand_r3_score

* Compute the average standardized score
gen average_stand_score = (stand_r1_score + stand_r2_score + stand_r3_score) / 3

* Rank proposals (higher score gets rank 1)
egen rank = rank(-average_stand_score)

* Save the updated dataset
save "q3_proposal_review_standardized.dta", replace

* Display results for first 10 rows
list proposal_id stand_r1_score stand_r2_score stand_r3_score average_stand_score rank if _n <= 10


*Q4: We have the information of adults that have computerized national ID card in the following pdf: Pakistan_district_table21.pdf. This pdf has 135 tables (one for each district). We extracted data through an OCR software but unfortunately it wasn't very accurate. We need to extract column 2-13 from the first row ("18 and above") from each table. Create a dataset where each row contains information for a particular district. The hint do file contains the code to loop through each sheet, you need to find a way to align the columns correctly.
*Hint: While the formatting is mostly regular, there are a couple of (pretty minor) anomalies so be sure to look at what your code produces.

// Load the dataset for this question
global excel_t21 "$wd/04_assignment/01_data/q4_Pakistan_district_table21.xlsx"

clear

// Set up an empty tempfile
tempfile table21
save `table21', replace emptyok

// Import all 135 Excel sheets and create separate tempfile for each
forvalues i = 1/135 {
    import excel "$excel_t21", sheet("Table `i'") firstrow clear allstring // Import
    display as error "`i'" // Display the loop number
    
    keep if regexm(TABLE21PAKISTANICITIZEN, "18 AND") == 1 // Keep only those rows that have "18 AND"
    keep in 1 // There are 3 of them, but we want the first one
    rename TABLE21PAKISTANICITIZEN District
    
     // Rename category column to District
    
    ds
    local sheet_cols `r(varlist)'
    
    // Update master list with column names
    global master_cols : list master_cols | sheet_cols
    
    tempfile temp`i'
    save `temp`i'', replace
}

// Set up an empty temp dataset to merge the 135 tempfiles together
tempfile final_data
save `final_data', replace emptyok

forvalues i = 1/135 {
    use `temp`i'', clear
    
    // Identify missing columns and iteratively shift values left
    ds
    foreach var of varlist `r(varlist)' {
        if missing(`var'[1]) {
            drop `var' // Drop the missing column
        }
    }
    
    // Rename columns based on their position, excluding table21 and "District"
    ds District, not
    local colnames total_population cnic_obtained cnic_not_obtained male_population male_cnic_obtained ///
                  male_cnic_not_obtained female_population female_cnic_obtained female_cnic_not_obtained ///
                  transgender_population transgender_cnic_obtained transgender_cnic_not_obtained
    
    local j = 1
    foreach var of varlist `r(varlist)' {
        if "`var'" != "18 AND ABOVE" & "`var'" != "District" {  // Ensure District and "18 AND ABOVE" are not renamed
            local newname : word `j' of `colnames' 
            rename `var' `newname' 
            local j = `j' + 1
            if `j' > 12 { 
                continue, break  // Stop renaming after 12 variables
            }
        }
    }
    
    // Append to the final dataset
    append using `final_data'
    save `final_data', replace
}

// Load the dataset to do final check and edit
use `final_data', clear

br

// Check for duplicates
bysort District: gen order = _n // Generate a new variable of occurrence for each "District" value
drop if order == 1 // Keep only the second occurrence if "District" == 135
drop order

// Drop columns B to Y
drop B-Y

// Edit the inconsistencies in "18 AND ABOVE"


// Reorder the columns so that it's easy to eyeball which District each row is from
order District, first

// Fix column width issue so that it's easy to eyeball the data
format %40s District total_population cnic_obtained cnic_not_obtained ///
       male_population male_cnic_obtained male_cnic_not_obtained ///
       female_population female_cnic_obtained female_cnic_not_obtained ///
       transgender_population transgender_cnic_obtained transgender_cnic_not_obtained

br


*Q5: This task involves string cleaning and data wrangling. We scraped data for a school from a Tanzanian government website. Unfortunately, the formatting of the data is a mess. Your task is to extract the following school level variables: 

*1) number of students that took the test, 
*2) school average 
*3) student group (binary, either under 40 or >=40  
*4) school ranking in council (22 out of 46) 
*5) school ranking in the region (74 out of 290)
*6) school ranking at the national level (545 out of 5664) level dataset with the following variables. 

*In addition to these variables, also capture the school name and school code in two different columns. Note: This is a school level dataset, and should only contain one row with all the variables. All the school level information is given at the top of this webpage. The page is in Swahili but it should be fairly straightforward to find the relevant information. You can use google translate if you have trouble finding the relevant parts of the webpage. 
* Load the dataset
use "$wd/04_assignment/01_data/q5_Tz_student_roster_html.dta", clear

* Extract relevant text from the HTML column
gen html_text = s

* Extract School Name
gen school_name = regexs(1) if regexm(html_text, "([A-Z ]+ PRIMARY SCHOOL)")

* Extract School Code
gen school_code = regexs(1) if regexm(html_text, "(PS[0-9]+)")

* Extract Number of Students
gen num_students = real(regexs(1)) if regexm(html_text, "WALIOFANYA MTIHANI : ([0-9]+)")

* Extract School Average
gen school_avg = real(regexs(1)) if regexm(html_text, "WASTANI WA SHULE   : ([0-9]+\.[0-9]+)")

* Extract Student Group
gen student_group = "Under 40" if regexm(html_text, "KUNDI LA SHULE : Wanafunzi chini ya 40")
replace student_group = ">=40" if student_group == ""

* Extract School Ranking in Council
gen ranking_council = regexs(1) + " out of " + regexs(2) if regexm(html_text, "NAFASI YA SHULE KWENYE KUNDI LAKE KIHALMASHAURI: ([0-9]+) kati ya ([0-9]+)")

* Extract School Ranking in Region
gen ranking_region = regexs(1) + " out of " + regexs(2) if regexm(html_text, "NAFASI YA SHULE KWENYE KUNDI LAKE KIMKOA  : ([0-9]+) kati ya ([0-9]+)")

* Extract School Ranking Nationally
gen ranking_national = regexs(1) + " out of " + regexs(2) if regexm(html_text, "NAFASI YA SHULE KWENYE KUNDI LAKE KITAIFA : ([0-9]+) kati ya ([0-9]+)")

* Keep only one row for school-level dataset
keep school_name school_code num_students school_avg student_group ranking_council ranking_region ranking_national

* Save the cleaned data
save "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088/Week_03/04_assignment/01_data/q5_Tz_cleaned.dta", replace


Bonus Question: This task involves string cleaning and data wrangling. We scrapped student data for a school from a Tanzanian government website. Unfortunately, the formatting of the data is a mess. Your task is to create a student level dataset with the following variables: schoolcode, cand_id, gender, prem_number, name, grade variables for: Kiswahili, English, maarifa, hisabati, science, uraia, average. Note: This is a school level dataset, and should have 16 rows (same as the number of students in that school).
Hint: you can get a better view of the string if you go to the website and view its source (which can be done by right clicking or hitting ctrl/command+U).




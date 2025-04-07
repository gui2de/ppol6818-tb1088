*part one:
clear all
set obs 10000  // large number to simulate population

* Generate outcome variable Y ~ N(0,1)
gen Y = rnormal(0,1)
* Generate treatment assignment: 50% treated
gen treat = (runiform() < 0.5)

* Treatment effect uniformly between 0.0 and 0.2
gen te = runiform(0.0, 0.2)

* Apply treatment effect only to treated
replace Y = Y + 0.1 if treat == 1
* Use power command for continuous outcomes
power twomeans 0 0.1, sd(1) power(0.8)
scalar initial_n = 788
scalar adjusted_n = initial_n / (1 - 0.15)
di "Adjusted sample size: " adjusted_n
* More expensive treatment, fewer treated
* Optimal power occurs at 50/50 split, so this will reduce power
* Must adjust sample size accordingly:
power twomeans 0 0.1, sd(1) power(0.8) nratio(0.3/0.7)



*part two
*Step 1–3: DGP for Math Scores with ICC ≈ 0.3
clear all
set more off

* Parameters
local cluster_size = 15      // changeable
local n_clusters = 200       // changeable
local rho = 0.3              // intraclass correlation
local effect = 0.2

* School-level random effect
set obs `n_clusters'
gen school_id = _n
gen u_school = rnormal(0, sqrt(`rho'))  // school-level random effect

* Expand to students
expand `cluster_size'
bysort school_id: gen student_id = _n

* Individual-level noise
gen e = rnormal(0, sqrt(1 - `rho'))
gen Y = u_school + e
* Step 4: Assign Treatment at School Level and Apply Effect
preserve
bysort school_id (student_id): keep if _n == 1
gen treat = (runiform() < 0.5)
gen te = runiform(0.15, 0.25) if treat == 1
replace te = 0 if missing(te)
keep school_id treat te
tempfile treatinfo
save `treatinfo'
restore

merge m:1 school_id using `treatinfo', nogen
replace Y = Y + te
*Step 5:Power vs Cluster Size (First 10 powers of 2)
clear all
set more off

local effect = 0.2
local rho = 0.3
local sims = 500
local n_clusters = 200
tempname results
postfile `results' m power using cluster_power.dta, replace

foreach m in 2 4 8 16 32 64 128 256 512 1024 {
    local rejections = 0
    forvalues s = 1/`sims' {
        clear
        set obs `n_clusters'
        gen school_id = _n
        gen u_school = rnormal(0, sqrt(`rho'))
        expand `m'
        bysort school_id: gen student_id = _n
        gen e = rnormal(0, sqrt(1 - `rho'))
        gen Y = u_school + e

        preserve
        bysort school_id (student_id): keep if _n == 1
        gen treat = (runiform() < 0.5)
        tempfile tr
        save `tr'
        restore
        merge m:1 school_id using `tr', nogen

        gen te = runiform(0.15, 0.25) if treat
        replace te = 0 if missing(te)
        replace Y = Y + te

        regress Y treat, cluster(school_id)
        if (abs(_b[treat]/_se[treat]) > invttail(e(df_r), 0.025)) {
            local rejections = `rejections' + 1
        }
    }
    local pwr = `rejections'/`sims'
    post `results' (`m') (`pwr')
}

postclose `results'
use cluster_power.dta, clear

* Plot
twoway line power m, ///
    title("Power vs Cluster Size (200 Clusters)") ///
    xtitle("Cluster Size (Students/School)") ///
    yline(0.8, lpattern(dash) lcolor(red)) ///
    ytitle("Power")
*Step 6: Fixed Cluster Size = 15 → Find Needed Number of Clusters
clear all
set more off

local effect = 0.2
local rho = 0.3
local sims = 500
local cluster_size = 15
tempname results
postfile `results' k power using needed_clusters.dta, replace

forvalues k = 40(10)200 {
    local rejections = 0
    forvalues s = 1/`sims' {
        clear
        set obs `k'
        gen school_id = _n
        gen u_school = rnormal(0, sqrt(`rho'))
        expand `cluster_size'
        bysort school_id: gen student_id = _n
        gen e = rnormal(0, sqrt(1 - `rho'))
        gen Y = u_school + e

        preserve
        bysort school_id (student_id): keep if _n == 1
        gen treat = (runiform() < 0.5)
        tempfile tr
        save `tr'
        restore
        merge m:1 school_id using `tr', nogen

        gen te = runiform(0.15, 0.25) if treat
        replace te = 0 if missing(te)
        replace Y = Y + te

        regress Y treat, cluster(school_id)
        if (abs(_b[treat]/_se[treat]) > invttail(e(df_r), 0.025)) {
            local rejections = `rejections' + 1
        }
    }
    local pwr = `rejections'/`sims'
    post `results' (`k') (`pwr')
}

postclose `results'
use needed_clusters.dta, clear

* Plot
twoway line power k, ///
    title("Power vs # of Clusters (15 Students/School)") ///
    xtitle("Number of Clusters") ///
    yline(0.8, lpattern(dash) lcolor(red)) ///
    ytitle("Power")
sum power, detail
*Step 7: 70% of Schools Actually Adopt Treatment
clear all
set more off

* PARAMETERS
local effect = 0.2          // true effect size
local compliance = 0.7      // 70% of treated schools adopt
local rho = 0.3             // ICC
local sims = 500            // number of simulations per K
local cluster_size = 15     // fixed students per school

tempname results
postfile `results' k power using power_compliance.dta, replace

* LOOP OVER NUMBER OF CLUSTERS
forvalues k = 40(10)300 {
    di "Simulating for number of clusters: `k'"
    local rejections = 0

    forvalues s = 1/`sims' {
        clear
        set obs `k'
        gen school_id = _n
        gen u_school = rnormal(0, sqrt(`rho'))

        expand `cluster_size'
        bysort school_id: gen student_id = _n
        gen e = rnormal(0, sqrt(1 - `rho'))
        gen Y = u_school + e

        * Randomly assign 50% of schools to treatment
        preserve
        bysort school_id (student_id): keep if _n == 1
        gen treat = (runiform() < 0.5)
        tempfile tr
        save `tr'
        restore
        merge m:1 school_id using `tr', nogen

        * Generate adoption: only 70% of treated schools implement
        gen adopted = treat & (runiform() < `compliance')

        * Apply effect only to those who adopted treatment
        gen te = runiform(0.15, 0.25) if adopted
        replace te = 0 if missing(te)
        replace Y = Y + te

        * REGRESSION on treatment assignment (intent-to-treat)
        regress Y treat, cluster(school_id)
        if (abs(_b[treat]/_se[treat]) > invttail(e(df_r), 0.025)) {
            local rejections = `rejections' + 1
        }
    }

    local pwr = `rejections'/`sims'
    post `results' (`k') (`pwr')
}

postclose `results'
use power_compliance.dta, clear

* PLOT POWER CURVE
twoway line power k, ///
    title("Power vs # of Clusters (70% Compliance)") ///
    yline(0.8, lcolor(red) lpattern(dash)) ///
    xtitle("Number of Clusters") ///
    ytitle("Power")
sum power, detail

	*Part 3
clear all
set more off

* Simulation parameters
local sims = 500
tempname results
postfile `results' N str20 model beta using betasim.dta, replace

* Loop over increasing sample sizes
foreach N in 100 200 500 1000 2000 {
    forvalues s = 1/`sims' {
        clear
        set obs `N'

        * ---- STEP 1: STRATA GROUPS (5 strata)
        gen strata = ceil(runiform()*5)

        * ---- STEP 2: CONTINUOUS COVARIATES
        gen x1 = rnormal()  // confounder (affects both Y and treat)
        gen x2 = rnormal()  // affects Y only
        gen x3 = rnormal()  // affects treat only
        gen noise = rnormal()

        * ---- STEP 3: TREATMENT ASSIGNMENT
        gen pscore = invlogit(0.5*x1 + 0.5*x3)
        gen treat = (runiform() < pscore)

        * ---- STEP 4: OUTCOME VARIABLE
        gen Y = 1*treat + 0.5*x1 + 0.3*x2 + 0.2*strata + noise

        * ---- STEP 5: REGRESSION MODELS ----
        * Model A: No controls
        regress Y treat
        post `results' (`N') ("A_none") (_b[treat])

        * Model B: Add confounder only (x1)
        regress Y treat x1
        post `results' (`N') ("B_confounder") (_b[treat])

        * Model C: Add x1 + x2
        regress Y treat x1 x2
        post `results' (`N') ("C_confounder_outcomeonly") (_b[treat])

        * Model D: Add all covariates (x1, x2, x3)
        regress Y treat x1 x2 x3
        post `results' (`N') ("D_allcovs") (_b[treat])

        * Model E: Add fixed effects for strata
        regress Y treat i.strata
        post `results' (`N') ("E_stratafe") (_b[treat])
    }
}

postclose `results'
use betasim.dta, clear
collapse (mean) beta_mean=beta (sd) beta_sd=beta, by(N model)

* Plot mean beta vs. sample size
twoway (line beta_mean N if model=="A_none", lpattern(dash)) ///
       (line beta_mean N if model=="B_confounder") ///
       (line beta_mean N if model=="C_confounder_outcomeonly") ///
       (line beta_mean N if model=="D_allcovs") ///
       (line beta_mean N if model=="E_stratafe"), ///
       title("Mean of β_treat by Model") ///
       yline(1, lcolor(red) lpattern(dot)) ///
       legend(order(1 "None" 2 "Confounder only" 3 "x1+x2" 4 "All covs" 5 "Strata FE"))

* Plot standard deviation (variance) of beta
twoway (line beta_sd N if model=="A_none", lpattern(dash)) ///
       (line beta_sd N if model=="B_confounder") ///
       (line beta_sd N if model=="C_confounder_outcomeonly") ///
       (line beta_sd N if model=="D_allcovs") ///
       (line beta_sd N if model=="E_stratafe"), ///
       title("SD of β_treat by Model") ///
       ytitle("Standard Deviation") ///
       legend(order(1 "None" 2 "Confounder only" 3 "x1+x2" 4 "All covs" 5 "Strata FE"))


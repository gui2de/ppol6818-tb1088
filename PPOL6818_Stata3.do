cd "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088"
*Q1
clear all
set more off
set seed 12345
set obs 10000

* Step 1: Generate fixed population
gen x = rnormal()
gen e = rnormal(0,1)
gen y = 2*x + e

* Save population
save "population.dta", replace


* Step 2: Define sampling and regression program
program define sample_regression, rclass
    syntax , n(integer)

    use "population.dta", clear
    sample `n', count

    regress y x

    return scalar beta = _b[x]
    return scalar sem  = _se[x]
    return scalar p    = ttail(e(df_r), abs(_b[x]/_se[x]))*2
    return scalar lb   = _b[x] - 1.96 * _se[x]
    return scalar ub   = _b[x] + 1.96 * _se[x]
    return scalar N    = e(N)
end




* Step 3: Run simulations for N = 10, 100, 1000, 10000
simulate N=r(N) beta=r(beta) sem=r(sem) p=r(p) lb=r(lb) ub=r(ub), reps(500): ///
    sample_regression, n(10)
save "results_n10.dta", replace

simulate N=r(N) beta=r(beta) sem=r(sem) p=r(p) lb=r(lb) ub=r(ub), reps(500): ///
    sample_regression, n(100)
save "results_n100.dta", replace

simulate N=r(N) beta=r(beta) sem=r(sem) p=r(p) lb=r(lb) ub=r(ub), reps(500): ///
    sample_regression, n(1000)
save "results_n1000.dta", replace

simulate N=r(N) beta=r(beta) sem=r(sem) p=r(p) lb=r(lb) ub=r(ub), reps(500): ///
    sample_regression, n(10000)
save "results_n10000.dta", replace


* Step 4: Combine all results into one dataset
use results_n10.dta, clear
gen sample = 10

append using results_n100.dta
replace sample = 100 if missing(sample)

append using results_n1000.dta
replace sample = 1000 if missing(sample)

append using results_n10000.dta
replace sample = 10000 if missing(sample)

save results_all.dta, replace


* Step 5: Create summary statistics
collapse (mean) sem beta (sd) beta_sd=beta, by(sample)

* Step 6: Plot SEM vs Sample Size
twoway line sem sample, ///
    title("Mean SEM vs Sample Size") ///
    xtitle("Sample Size") ///
    ytitle("Mean SEM")

* Step 7: Plot Standard Deviation of Beta vs Sample Size
twoway line beta_sd sample, ///
    title("Standard Deviation of β̂ vs Sample Size") ///
    xtitle("Sample Size") ///
    ytitle("SD of Beta")

	
	*Q2
cd "/Users/tianyubai/Documents/GitHub/ppol6818-tb1088"
clear all
set more off
set seed 12345

* Q2: Infinite superpopulation simulation

* Step 1: Define data generating process program
program define dgp_regression, rclass
    syntax , n(integer)
    
    clear
    set obs `n'
    
    * Generate X and error term (infinite superpopulation)
    gen x = rnormal()
    gen e = rnormal(0,1)
    
    * True relationship: Y = 2*X + e
    gen y = 2*x + e
    
    * Run regression
    regress y x
    
    * Return statistics
    return scalar beta = _b[x]
    return scalar sem  = _se[x]
    return scalar p    = 2*ttail(e(df_r), abs(_b[x]/_se[x]))
    return scalar lb   = _b[x] - 1.96 * _se[x]
    return scalar ub   = _b[x] + 1.96 * _se[x]
    return scalar N    = e(N)
end

* Step 2: Create list of sample sizes (first 20 powers of 2 + powers of 10)
local sample_sizes 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 10 100 1000 10000 100000 1000000

* Step 3: Create empty dataset to store results
clear
set obs 0
gen N = .
gen beta = .
gen sem = .
gen p = .
gen lb = .
gen ub = .
save "results_infinite_part2.dta", replace

* Step 4: Run simulations for each sample size
foreach n in `sample_sizes' {
    simulate N=r(N) beta=r(beta) sem=r(sem) p=r(p) lb=r(lb) ub=r(ub), ///
             reps(500) seed(12345): dgp_regression, n(`n')
    
    append using "results_infinite_part2.dta"
    save "results_infinite_part2.dta", replace
}

* Step 5: Create summary statistics and visualizations
use "results_infinite_part2.dta", clear

* Create logN variable for better visualization
gen logN = log(N)

* Figure 1: Distribution of beta estimates by sample size
twoway (scatter beta N, jitter(3) msymbol(oh) mcolor(%30)) ///
       (lpolyci beta N, degree(1)), ///
       xscale(log) xtitle("Sample Size (log scale)") ///
       ytitle("Beta Estimate") title("Distribution of Beta Estimates (Infinite Superpopulation)") ///
       legend(off) yline(2, lpattern(dash))
graph export "beta_infinite.png", replace

* Figure 2: SEM by sample size
twoway (scatter sem N, jitter(3) msymbol(oh) mcolor(%30)) ///
       (lpolyci sem N, degree(1)), ///
       xscale(log) yscale(log) xtitle("Sample Size (log scale)") ///
       ytitle("Standard Error (log scale)") title("Standard Error by Sample Size (Infinite Superpopulation)") ///
       legend(off)
graph export "sem_infinite.png", replace

* Table: Summary statistics by sample size
collapse (mean) beta sem (sd) beta_sd=beta (mean) p, by(N)
list N beta beta_sd sem p, sep(0)

* Load Part 1 results
* Load and prepare Part 1 results (finite population)
use "results_all.dta", clear
collapse (mean) beta sem (sd) beta_sd=beta, by(sample)
rename beta beta_part1
rename sem sem_part1
rename sample N
save "part1_summary.dta", replace

* Load and prepare Part 2 results (infinite superpopulation)
use "results_infinite_part2.dta", clear
collapse (mean) beta sem (sd) beta_sd=beta, by(N)
rename beta beta_part2
rename sem sem_part2
save "part2_summary.dta", replace

* Merge results for comparison
use "part1_summary.dta", clear
merge 1:1 N using "part2_summary.dta", keep(match) nogen

* Display comparison table with header
display _n "Comparison of Finite vs Infinite Population Results"
list N beta_part1 sem_part1 beta_part2 sem_part2, ///
    clean noobs sep(0) ab(32)

* Create comparison graph
twoway (connected sem_part1 N, msymbol(Oh)) ///
       (connected sem_part2 N, msymbol(Th)), ///
       xscale(log) yscale(log) ///
       xtitle("Sample Size (log scale)") ///
       ytitle("Standard Error (log scale)") ///
       title("Standard Error Comparison") ///
       legend(label(1 "Finite Population") label(2 "Infinite Superpopulation")) ///
       note("Comparison at common sample sizes")
graph export "sem_comparison.png", replace

use data_cleaned.dta, replace
gen control = (narrative == 0 & followup == 0)


********************************************************************************
* TABLE 2
********************************************************************************
preserve

drop if round == 0

keep id treatment uninformative abs_diff_from_weak_bayes belief b_lag

* Indicator for whether the subject changed belief
gen update = abs(belief - b_lag) > 0

* Treatment labels and order
gen tr = .
replace tr = 1 if treatment == "Control"
replace tr = 2 if treatment == "Narratives"
replace tr = 3 if treatment == "Followup"

gen str20 Treatment = ""
replace Treatment = "Urn"           if tr == 1
replace Treatment = "Story"         if tr == 2
replace Treatment = "Story No Info" if tr == 3

* Variables for subject-level averages
gen dev_all = abs_diff_from_weak_bayes
gen dev_d   = abs_diff_from_weak_bayes if uninformative == 0
gen dev_nd  = abs_diff_from_weak_bayes if uninformative == 1

gen upd_d   = update if uninformative == 0
gen upd_nd  = update if uninformative == 1

* Subject-level means
collapse ///
    (mean) dev_all dev_d dev_nd upd_d upd_nd, ///
    by(id tr Treatment)

* Treatment-level means and SDs across subjects
collapse ///
    (mean) mean_dev_all = dev_all ///
           mean_dev_d   = dev_d ///
           mean_dev_nd  = dev_nd ///
           mean_upd_d   = upd_d ///
           mean_upd_nd  = upd_nd ///
    (sd)   sd_dev_all   = dev_all ///
           sd_dev_d     = dev_d ///
           sd_dev_nd    = dev_nd ///
           sd_upd_d     = upd_d ///
           sd_upd_nd    = upd_nd ///
    (count) Subjects    = dev_all, ///
    by(tr Treatment)

sort tr


bysort tr: sum mean* sd* Subjects
restore

*************************************************************************************
*  TESTS FOR DIFFERENCES IN ABSOLUTE DEVIATIONS
preserve
drop if round == 0              // exclude prior
collapse (mean) individual_abs_weak_diff = abs_diff_from_weak_bayes, by(id treatment)
kwallis individual_abs_weak_diff, by(treatment)
ranksum individual_abs_weak_diff if treatment != "Followup", by(treatment) exact
ranksum individual_abs_weak_diff if treatment != "Narratives", by(treatment) exact
ranksum individual_abs_weak_diff if treatment != "Control", by(treatment) exact
restore
preserve
drop if round == 0              // exclude prior
keep if uninformative == 0      // diagnostic signals only
collapse (mean) individual_abs_weak_diff = abs_diff_from_weak_bayes, by(id treatment)
kwallis individual_abs_weak_diff, by(treatment)
ranksum individual_abs_weak_diff if treatment != "Followup", by(treatment) exact
ranksum individual_abs_weak_diff if treatment != "Narratives", by(treatment) exact
ranksum individual_abs_weak_diff if treatment != "Control", by(treatment) exact
restore
preserve
drop if round == 0              // exclude prior
keep if uninformative == 1      // non-diagnostic signals only
collapse (mean) individual_abs_weak_diff = abs_diff_from_weak_bayes, by(id treatment)
kwallis individual_abs_weak_diff, by(treatment)
ranksum individual_abs_weak_diff if treatment != "Followup", by(treatment) exact 
ranksum individual_abs_weak_diff if treatment != "Narratives", by(treatment) exact
ranksum individual_abs_weak_diff if treatment != "Control", by(treatment) exact
restore

********************************************************************************
* TESTS FOR DIFFERENCES IN UPDATE FREQUENCIES
preserve
drop if round == 0
gen update = abs(belief - b_lag) > 0
tempfile base
save `base', replace
*------------------------------------------------------------
* Diagnostic signals
*------------------------------------------------------------
use `base', clear
keep if uninformative == 0
collapse (mean) update_freq = update (count) n_rounds = update, by(id treatment)
di " "
di "UPDATE FREQUENCY AFTER DIAGNOSTIC SIGNALS"
kwallis update_freq, by(treatment)
ranksum update_freq if treatment != "Followup", by(treatment) exact
ranksum update_freq if treatment != "Narratives", by(treatment) exact
ranksum update_freq if treatment != "Control", by(treatment) exact
*------------------------------------------------------------
* Non-diagnostic signals
*------------------------------------------------------------
use `base', clear
keep if uninformative == 1
collapse (mean) update_freq = update (count) n_rounds = update, by(id treatment)
di " "
di "UPDATE FREQUENCY AFTER NON-DIAGNOSTIC SIGNALS"
kwallis update_freq, by(treatment)
ranksum update_freq if treatment != "Followup", by(treatment) exact
ranksum update_freq if treatment != "Narratives", by(treatment) exact
ranksum update_freq if treatment != "Control", by(treatment) exact
restore
********************************************************************************




********************************************************************************
*   FIGURE 2  
********************************************************************************
preserve
drop if round == 0
* 2) OPTIONAL: bin beliefs so frequencies aggregate nicely (adjust step if needed)
local step = 0.01   // try 0.05 if you prefer coarser bins
gen b_t    = round(b_lag, `step')
gen b_tp1  = round(belief, `step')

* 3) Count frequencies for each (b_t, b_tp1, signal)
contract treatment sign b_t b_tp1
rename _freq freq

* Urn
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Control" & sign == 0, ///
    msymbol(o) mcolor(blue%30) msize(*1.2) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Urn") name(heatmap_contr_nond, replace)

* Story
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Narratives" & sign == 0, ///
    msymbol(o) mcolor(red%30) msize(*1.2) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story") name(heatmap_narr_nond, replace)

* Story No Info
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Followup" & sign == 0, ///
    msymbol(o) mcolor(purple%30) msize(*1.2) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story No Info") name(heatmap_foll_nond, replace)
restore
graph combine heatmap_contr_nond heatmap_narr_nond heatmap_foll_nond, rows(1) cols(3) l1title("{it:Belief}{sub:t+1}") b1title("{it:Belief}{sub:t}")  name(bubbleplots_nd, replace) imargin(zero) ycommon xsize(6) ysize(2.5)
********************************************************************************





********************************************************************************
*   FIGURE 3
********************************************************************************
preserve
drop if round == 0
keep if uninformative == 1
gen midpoint = (belief == 0.5)
gen byte tr = .
replace tr = 0 if control == 1
replace tr = 1 if narrative == 1
replace tr = 2 if followup == 1
label define tr 0 "Urn" 1 "Story" 2 "Story No Info", replace
label values tr tr
* Absolute distance of prior belief from 0.5
gen d_lag = abs(b_lag - 0.5)
* Bin distance in intervals of width 0.1
gen double d_bin = .
replace d_bin = 0.0 if d_lag >= 0.00 & d_lag <= 0.05
replace d_bin = 0.1 if d_lag >  0.05 & d_lag <= 0.15
replace d_bin = 0.2 if d_lag >  0.15 & d_lag <= 0.25
replace d_bin = 0.3 if d_lag >  0.25 & d_lag <= 0.35
replace d_bin = 0.4 if d_lag >  0.35 & d_lag <= 0.45
replace d_bin = 0.5 if d_lag >  0.45 & d_lag <= 0.50
collapse (mean) p_mid = midpoint, by(tr d_bin)
* Put treatment bars next to each other
gen x_urn      = d_bin - 0.025 if tr == 0
gen x_story    = d_bin          if tr == 1
gen x_followup = d_bin + 0.025 if tr == 2
twoway ///
 (bar p_mid x_urn if tr == 0, barw(0.025) fcolor(blue%20) lcolor(blue)) ///
 (bar p_mid x_story if tr == 1, barw(0.025) fcolor(red%20) lcolor(red)) ///
 (bar p_mid x_followup if tr == 2, barw(0.025) fcolor(purple%20) lcolor(purple)), ///
 legend(order(1 "Urn" 2 "Story" 3 "Story No Info") pos(2) ring(0) rows(3)) ///
 ylab(0(0.1)1) yscale(range(0 1)) ///
 xlab(0(0.1)0.5) xscale(range(-0.05 0.55)) ///
 ytitle("Share reporting 0.5") ///
 xtitle("|{it:Belief}{sub:t-1} − 0.5|") ///
 name(actual_prob_midpoint_dlag, replace)
restore
********************************************************************************




********************************************************************************
*   FIGURE 4 AND TABLE C.2
********************************************************************************
preserve
egen subject = group(id)
drop if round == 0
xtset subject round
gen midpoint = (belief == 0.5)
gen double d_lag = abs(b_lag - 0.5)
gen abssum_of_signals = abs(sum_of_signals)
// to avoid dropping observation in regression, put on the same bin those that have seen at least 5 signals (in narrative none have 6)
replace abssum_of_signals = 5 if abssum_of_signals >= 5

* Create treatment variable
gen byte tr = .
replace tr = 0 if treatment == "Control"
replace tr = 1 if treatment == "Narratives"
replace tr = 2 if treatment == "Followup"
label define tr 0 "Urn" 1 "Story" 2 "Story No Info", replace
label values tr tr

mixed midpoint ib1.tr##c.d_lag i.abssum_of_signals i.round if uninformative == 1 & d_lag > 0 || subject:
estadd scalar Observations = e(N)
eststo lpm_midpoint

meprobit midpoint ib1.tr##c.d_lag i.abssum_of_signals i.round if uninformative == 1 & d_lag > 0 || subject:
estimates store M
estadd scalar Observations = e(N)
eststo probit_midpoint

* predicted probabilities
margins tr, at(d_lag=(0.05(0.05)0.5))
marginsplot, yti("") xti("")  ti("Probability of reporting 0.5") ///
    legend(order(1 "Urn" 2 "Story" 3 "Story No Info") pos(2) ring(0) rows(3)) ///
    plot1opts(msymbol(o) mcolor(blue%30) lcolor(blue%60)) ///
    plot2opts(msymbol(o) mcolor(red%30) lcolor(red%60)) ///
    plot3opts(msymbol(o) mcolor(purple%30) lcolor(purple%60)) ///
    yscale(range(0 .8)) ylab(0(0.1).8) noci name(midpoint_all, replace)

estimates restore M
quietly margins tr, at(d_lag=(0.05(0.05)0.5)) post
matrix b = e(b)
matrix V = e(V)
clear
set obs 20
gen double d_lag = .
gen str30 contrast = ""
gen double effect = .
gen double se = .
local row = 1
forvalues j = 1/10 {
    local x = `j'*0.05
    * Order is: Urn, Story, Story No Info at each value of d_lag
    local urn     = 3*(`j' - 1) + 1
    local story   = 3*(`j' - 1) + 2
    local noinfo  = 3*(`j' - 1) + 3
    * Story - Urn
    scalar diff_su = b[1,`story'] - b[1,`urn']
    scalar se_su = sqrt(V[`story',`story'] + V[`urn',`urn'] ///
                    - 2*V[`story',`urn'])
    replace d_lag = `x' in `row'
    replace contrast = "Story - Urn" in `row'
    replace effect = diff_su in `row'
    replace se = se_su in `row'
    local ++row
    * Story - Story No Info
    scalar diff_sn = b[1,`story'] - b[1,`noinfo']
    scalar se_sn = sqrt(V[`story',`story'] + V[`noinfo',`noinfo'] ///
                    - 2*V[`story',`noinfo'])
    replace d_lag = `x' in `row'
    replace contrast = "Story - Story No Info" in `row'
    replace effect = diff_sn in `row'
    replace se = se_sn in `row'
    local ++row
}
gen lb = effect - invnormal(0.975)*se
gen ub = effect + invnormal(0.975)*se	

twoway ///
    (rcap ub lb d_lag if contrast == "Story - Urn", lcolor(black%70)) ///
    (line effect d_lag if contrast == "Story - Urn", lcolor(black%70) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Urn", mcolor(black%70) msymbol(o)) ///
    (rcap ub lb d_lag if contrast == "Story - Story No Info", lcolor(black%30)) ///
    (line effect d_lag if contrast == "Story - Story No Info", lcolor(black%30) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Story No Info", mcolor(black%30) msymbol(o)), ///
    yline(0, lcolor(black%40) lp(solid)) yti("") xti("") ///
	ti("Treatment effect") legend(order(2 "Story - Urn" 5 "Story - Story No Info") pos(5) ring(0) rows(2)) ///
	xscale(range(0.05 0.5)) xlab(0.05(0.05)0.5) ///
	yscale(range(-0.5 0.5)) ylab(-0.5(0.1)0.5) name(midpoint_treat_eff_all, replace)

graph combine midpoint_all midpoint_treat_eff_all, cols(2) b1title("|{it:Belief}{sub:t-1} − 0.5|") l1title("Predicted probability") name(uncertainty, replace)
restore
********************************************************************************







********************************************************************************
*   FIGURE 5
********************************************************************************
local minimum_move_pp 5
local bootstrap_reps  10000
local bootstrap_seed  123456789

* Anchor the episode on nondiagnostic row t and construct t+1 within string id.
sort id round
by id (round): gen byte has_next = _n < _N & round[_n+1] == round + 1
by id (round): gen double belief_tp1 = belief[_n+1] if has_next
by id (round): gen byte sign_tp1 = sign[_n+1] if has_next

keep if round > 0 & has_next & sign == 0 & inlist(sign_tp1, -1, 1) & inlist(treatment, "Control", "Narratives", "Followup")

* Integer percentage-point versions avoid floating-point threshold problems.
gen int belief_pp = round(100*belief)
gen int b_lag_pp  = round(100*b_lag)

gen byte exact_reset = belief_pp == 50 & b_lag_pp != 50

gen byte meaningful_move = abs(belief_pp - 50) < abs(b_lag_pp - 50) & abs(belief_pp - b_lag_pp) >= `minimum_move_pp'

keep if exact_reset | meaningful_move

* Likelihood of the realized diagnostic signal in state 1 and state 0.
gen double likelihood_state1 = cond(sign_tp1 == 1, .45, .30)
gen double likelihood_state0 = cond(sign_tp1 == 1, .30, .45)

* Persistence: apply Bayes' rule to the belief actually reported at t.
gen double pred_persist =                                       ///
    (likelihood_state1*belief) /                                 ///
    (likelihood_state1*belief + likelihood_state0*(1-belief))

* Return: apply Bayes' rule after reinstating the pre-reset belief b_(t-1).
gen double pred_return = (likelihood_state1*b_lag) / (likelihood_state1*b_lag + likelihood_state0*(1-b_lag))

* Percentage-point prediction advantage of persistence over return.
gen double Delta = 100*(abs(belief_tp1 - pred_return) - abs(belief_tp1 - pred_persist))

gen byte trt = .
replace trt = 1 if treatment == "Control"
replace trt = 2 if treatment == "Narratives"
replace trt = 3 if treatment == "Followup"

tempfile episodes estimates bootstrap_draws
save `episodes', replace

* Estimate treatment means after first giving every participant one observation.
* Percentile confidence intervals resample participants, not episodes.
tempname results
postfile `results' byte sample trt double estimate ci_low ci_high int N_participants N_episodes using `estimates', replace

forvalues sample = 1/2 {

    use `episodes', clear

    if `sample' == 1 keep if exact_reset
    if `sample' == 2 keep if meaningful_move

    forvalues trt = 1/3 {

        preserve
        keep if trt == `trt'

        quietly count
        local N_episodes = r(N)

        collapse (mean) Delta, by(id)

        quietly count
        local N_participants = r(N)

        quietly summarize Delta, meanonly
        local estimate = r(mean)

        local this_seed = `bootstrap_seed' + 100*`sample' + `trt'
        quietly bootstrap r(mean), reps(`bootstrap_reps')        ///
            seed(`this_seed') saving(`bootstrap_draws', replace) ///
            nodots: summarize Delta

        use `bootstrap_draws', clear
        quietly _pctile _bs_1, p(2.5 97.5)
        local ci_low  = r(r1)
        local ci_high = r(r2)

        post `results' (`sample') (`trt') (`estimate')           ///
            (`ci_low') (`ci_high')                               ///
            (`N_participants') (`N_episodes')

        restore
    }
}

postclose `results'
use `estimates', clear

format estimate ci_low ci_high %5.1f

* Participant counts for the panel labels.
quietly summarize N_participants if sample == 1 & trt == 1, meanonly
local N_exact_urn = r(mean)
quietly summarize N_participants if sample == 1 & trt == 2, meanonly
local N_exact_story = r(mean)
quietly summarize N_participants if sample == 1 & trt == 3, meanonly
local N_exact_noinfo = r(mean)

quietly summarize N_participants if sample == 2 & trt == 1, meanonly
local N_move_urn = r(mean)
quietly summarize N_participants if sample == 2 & trt == 2, meanonly
local N_move_story = r(mean)
quietly summarize N_participants if sample == 2 & trt == 3, meanonly
local N_move_noinfo = r(mean)

twoway                                                          ///
    (rcap ci_low ci_high trt if sample == 1, horizontal          ///
        lcolor(black) lwidth(medthin))                           ///
    (scatter trt estimate if sample == 1,                       ///
        msymbol(O) mcolor(black) msize(medlarge)                 ///
        mlabel(estimate) mlabformat(%4.1f) mlabposition(12)      ///
        mlabcolor(black) mlabsize(small)),                       ///
    xline(0, lcolor(gs8) lpattern(dash) lwidth(medthin))         ///
    ylabel(1 "Urn (N=`N_exact_urn')"                            ///
            2 "Story (N=`N_exact_story')"                      ///
            3 "Story No Info (N=`N_exact_noinfo')",            ///
            angle(horizontal))                   ///
    yscale(reverse range(.5 3.5))                               ///
    xlabel(, format(%4.1f) labsize(small))                       ///
    xtitle("{&Delta}{sub:i}") ytitle("")                                      ///
    title("Midpoint reset")                 ///
	subtitle("Transitory       Persistent") ///                                     
    legend(off) graphregion(color(white) margin(zero))           ///
    bgcolor(white) name(exact_reset_panel, replace)
********************************************************************************


	




********************************************************************************
****************************** APPENDIX ****************************************
********************************************************************************
use data_cleaned.dta, replace
gen control = (narrative == 0 & followup == 0)


********************************************************************************
*   Figure C.1
********************************************************************************
preserve
drop if round != 0
replace belief = 1 - belief  if order_reversed == 1 // restore priors (before the recoding 0 = innocent, 1 = guilty)

hist belief if control == 1, frac d width(0.01) color(blue%30) xlab(0(0.1)1) yti("") xti("") ylab(0(.10)1) ti("Urn") name(priors_control, replace)
hist belief if narrative == 1, frac d width(0.01) color(red%30) xlab(0(0.1)1) yti("") xti("") ylab(0(.10)1) ti("Story") name(priors_narrative, replace)
hist belief if followup == 1, frac d width(0.01) color(purple%30) xlab(0(0.1)1) yti("") xti("") ylab(0(.10)1) ti("Story no Info") name(priors_followup, replace)
graph combine priors_control priors_narrative priors_followup, cols(3) ycommon name(priors_distribution, replace) ///
	  b1title("Prior") l1title("Fraction")

restore



********************************************************************************
*   Figure C.2
********************************************************************************
preserve
drop if round == 0
* 2) OPTIONAL: bin beliefs so frequencies aggregate nicely (adjust step if needed)
local step = 0.01   // try 0.05 if you prefer coarser bins
gen b_t    = round(b_lag, `step')
gen b_tp1  = round(belief, `step')

* 3) Count frequencies for each (b_t, b_tp1, signal)
contract treatment sign b_t b_tp1
rename _freq freq

* Control
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Control" & sign == -1, ///
    msymbol(o) mcolor(blue%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Urn | s = -1") name(heatmap_contr_neg, replace)
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Control" & sign == 0, ///
    msymbol(o) mcolor(blue%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Urn | s = 0") name(heatmap_contr_nond, replace)
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Control" & sign == 1, ///
    msymbol(o) mcolor(blue%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Urn | s = +1") name(heatmap_contr_pos, replace)

* Narrative
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Narratives" & sign == -1, ///
    msymbol(o) mcolor(red%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story | s = -1") name(heatmap_narr_neg, replace)
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Narratives" & sign == 0, ///
    msymbol(o) mcolor(red%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story | s = 0") name(heatmap_narr_nond, replace)
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Narratives" & sign == 1, ///
    msymbol(o) mcolor(red%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story | s = +1") name(heatmap_narr_pos, replace)
	
* Followup
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Followup" & sign == -1, ///
    msymbol(o) mcolor(purple%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story No Info | s = -1") name(heatmap_foll_neg, replace)
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Followup" & sign == 0, ///
    msymbol(o) mcolor(purple%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story No Info | s = 0") name(heatmap_foll_nond, replace)
twoway scatter b_tp1 b_t [fw=freq] if treatment == "Followup" & sign == 1, ///
    msymbol(o) mcolor(purple%30) msize(*0.5) ///
    xtitle("") ytitle("") ///
    xlabel(0(0.1)1) ylabel(0(0.1)1) ///
    aspect(1) legend(off) graphregion(margin(zero)) ///
    title("Story No Info | s = +1") name(heatmap_foll_pos, replace)
restore
graph combine heatmap_contr_pos heatmap_narr_pos heatmap_foll_pos heatmap_contr_nond heatmap_narr_nond heatmap_foll_nond heatmap_contr_neg heatmap_narr_neg heatmap_foll_neg, rows(3) cols(3) name(bubbleplots, replace) l1title("{it:Belief}{sub:t+1}") b1title("{it:Belief}{sub:t}") imargin(tiny) ycommon xcommon graphregion(margin(zero)) xsize(7) ysize(6)






********************************************************************************
***********   FIGURE C.3 (PROBABILITY OF REPORTING 0.5 +- 0.05)  ****************
********************************************************************************
preserve
egen subject = group(id)
drop if round == 0
xtset subject round
gen midpoint = ((belief <= 0.55) & (belief >= 0.45))
gen double d_lag = abs(b_lag - 0.5)
gen abssum_of_signals = abs(sum_of_signals)
// to avoid dropping observation in regression, put on the same bin those that have seen at least 5 signals (in narrative none have 6)
replace abssum_of_signals = 5 if abssum_of_signals >= 5

* Create treatment variable
gen byte tr = .
replace tr = 0 if treatment == "Control"
replace tr = 1 if treatment == "Narratives"
replace tr = 2 if treatment == "Followup"
label define tr 0 "Urn" 1 "Story" 2 "Story No Info", replace
label values tr tr

*quietly mixed midpoint ib1.tr##c.d_lag i.abssum_of_signals i.round if uninformative == 1 & d_lag > 0.05 || subject:
*estadd scalar Observations = e(N)
*eststo lpm_midpoint

quietly meprobit midpoint ib1.tr##c.d_lag i.abssum_of_signals i.round if uninformative == 1 & d_lag > 0.05 || subject:
estimates store M
estadd scalar Observations = e(N)
eststo probit_midpoint

* predicted probabilities
margins tr, at(d_lag=(0.05(0.05)0.5))
marginsplot, yti("") xti("")  ti("Probability of reporting around 0.5") ///
    legend(order(1 "Urn" 2 "Story" 3 "Story No Info") pos(2) ring(0) rows(3)) ///
    plot1opts(msymbol(o) mcolor(blue%30) lcolor(blue%60)) ///
    plot2opts(msymbol(o) mcolor(red%30) lcolor(red%60)) ///
    plot3opts(msymbol(o) mcolor(purple%30) lcolor(purple%60)) ///
    yscale(range(0 .8)) ylab(0(0.1).8) noci name(midpoint_all, replace)

estimates restore M
quietly margins tr, at(d_lag=(0.05(0.05)0.5)) post
matrix b = e(b)
matrix V = e(V)
clear
set obs 20
gen double d_lag = .
gen str30 contrast = ""
gen double effect = .
gen double se = .
local row = 1
forvalues j = 1/10 {
    local x = `j'*0.05
    * Order is: Urn, Story, Story No Info at each value of d_lag
    local urn     = 3*(`j' - 1) + 1
    local story   = 3*(`j' - 1) + 2
    local noinfo  = 3*(`j' - 1) + 3
    * Story - Urn
    scalar diff_su = b[1,`story'] - b[1,`urn']
    scalar se_su = sqrt(V[`story',`story'] + V[`urn',`urn'] ///
                    - 2*V[`story',`urn'])
    replace d_lag = `x' in `row'
    replace contrast = "Story - Urn" in `row'
    replace effect = diff_su in `row'
    replace se = se_su in `row'
    local ++row
    * Story - Story No Info
    scalar diff_sn = b[1,`story'] - b[1,`noinfo']
    scalar se_sn = sqrt(V[`story',`story'] + V[`noinfo',`noinfo'] ///
                    - 2*V[`story',`noinfo'])
    replace d_lag = `x' in `row'
    replace contrast = "Story - Story No Info" in `row'
    replace effect = diff_sn in `row'
    replace se = se_sn in `row'
    local ++row
}
gen lb = effect - invnormal(0.975)*se
gen ub = effect + invnormal(0.975)*se	

twoway ///
    (rcap ub lb d_lag if contrast == "Story - Urn", lcolor(black%70)) ///
    (line effect d_lag if contrast == "Story - Urn", lcolor(black%70) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Urn", mcolor(black%70) msymbol(o)) ///
    (rcap ub lb d_lag if contrast == "Story - Story No Info", lcolor(black%30)) ///
    (line effect d_lag if contrast == "Story - Story No Info", lcolor(black%30) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Story No Info", mcolor(black%30) msymbol(o)), ///
    yline(0, lcolor(black%40) lp(solid)) yti("") xti("") ///
	ti("Treatment effect") legend(order(2 "Story - Urn" 5 "Story - Story No Info") pos(5) ring(0) rows(2)) ///
	xscale(range(0.05 0.5)) xlab(0.05(0.05)0.5) ///
	yscale(range(-0.5 0.5)) ylab(-0.5(0.1)0.5) name(midpoint_treat_eff_all, replace)

graph combine midpoint_all midpoint_treat_eff_all, cols(2) b1title("|{it:Belief}{sub:t-1} − 0.5|") l1title("Predicted probability") name(uncertainty, replace)
restore
********************************************************************************





********************************************************************************
* FIGURE C.4 AND TABLE C.2 (MOVEMENT TOWARD UNCERTAINTY) 
********************************************************************************
preserve
egen subject = group(id)
drop if round == 0
xtset subject round
gen double toward_middle = abs(b_lag - 0.5) - abs(belief - 0.5)
gen double d_lag = abs(b_lag - 0.5)
gen abssum_of_signals = abs(sum_of_signals)
// to avoid dropping observation in regression, put on the same bin those that have seen at least 5 signals (in narrative none have 6)
replace abssum_of_signals = 5 if abssum_of_signals >= 5

* Create treatment variable
gen byte tr = .
replace tr = 0 if treatment == "Control"
replace tr = 1 if treatment == "Narratives"
replace tr = 2 if treatment == "Followup"
label define tr 0 "Urn" 1 "Story" 2 "Story No Info", replace
label values tr tr

* positive coefficient means moving toward 0.5
mixed toward_middle ib1.tr##c.d_lag i.abssum_of_signals i.round if uninformative == 1 & d_lag > 0 || subject:
estimates store M
estadd scalar Observations = e(N)
eststo toward_midpoint

* predicted movement
margins tr, at(d_lag=(0.05(0.05)0.5))
marginsplot, yti("") xti("")  ti("Move toward 0.5") ///
    legend(order(1 "Urn" 2 "Story" 3 "Story No Info") pos(5) ring(0) rows(3)) ///
	yline(0, lcolor(black%40) lp(dash)) ///
    plot1opts(msymbol(o) mcolor(blue%30) lcolor(blue%60)) ///
    plot2opts(msymbol(o) mcolor(red%30) lcolor(red%60)) ///
    plot3opts(msymbol(o) mcolor(purple%30) lcolor(purple%60)) ///
    yscale(range(-0.2 0.2)) ylab(-0.2(0.05)0.2) noci name(move_toward_all, replace)

estimates restore M
quietly margins tr, at(d_lag=(0.05(0.05)0.5)) post
matrix b = e(b)
matrix V = e(V)
clear
set obs 20
gen double d_lag = .
gen str30 contrast = ""
gen double effect = .
gen double se = .
local row = 1
forvalues j = 1/10 {
    local x = `j'*0.05
    * Order is: Urn, Story, Story No Info at each value of d_lag
    local urn     = 3*(`j' - 1) + 1
    local story   = 3*(`j' - 1) + 2
    local noinfo  = 3*(`j' - 1) + 3
    * Story - Urn
    scalar diff_su = b[1,`story'] - b[1,`urn']
    scalar se_su = sqrt(V[`story',`story'] + V[`urn',`urn'] ///
                    - 2*V[`story',`urn'])
    replace d_lag = `x' in `row'
    replace contrast = "Story - Urn" in `row'
    replace effect = diff_su in `row'
    replace se = se_su in `row'
    local ++row
    * Story - Story No Info
    scalar diff_sn = b[1,`story'] - b[1,`noinfo']
    scalar se_sn = sqrt(V[`story',`story'] + V[`noinfo',`noinfo'] ///
                    - 2*V[`story',`noinfo'])
    replace d_lag = `x' in `row'
    replace contrast = "Story - Story No Info" in `row'
    replace effect = diff_sn in `row'
    replace se = se_sn in `row'
    local ++row
}
gen lb = effect - invnormal(0.975)*se
gen ub = effect + invnormal(0.975)*se	

twoway ///
    (rcap ub lb d_lag if contrast == "Story - Urn", lcolor(black%70)) ///
    (line effect d_lag if contrast == "Story - Urn", lcolor(black%70) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Urn", mcolor(black%70) msymbol(o)) ///
    (rcap ub lb d_lag if contrast == "Story - Story No Info", lcolor(black%30)) ///
    (line effect d_lag if contrast == "Story - Story No Info", lcolor(black%30) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Story No Info", mcolor(black%30) msymbol(o)), ///
    yline(0, lcolor(black%40) lp(solid)) yti("") xti("") ///
	ti("Treatment effect") legend(order(2 "Story - Urn" 5 "Story - Story No Info") pos(5) ring(0) rows(2)) ///
	xscale(range(0.05 0.5)) xlab(0.05(0.05)0.5) ///
	yscale(range(-0.2 0.2)) ylab(-0.2(0.05)0.2) name(toward_treat_eff_all, replace)

graph combine move_toward_all toward_treat_eff_all, cols(2) b1title("|{it:Belief}{sub:t-1} − 0.5|") l1title("Predicted movement") name(toward_uncertainty, replace)
restore
********************************************************************************





********************************************************************************
*********** FIGURE C.5 (REPORTING 0.5 QUADRATIC) ******************
********************************************************************************
preserve
egen subject = group(id)
drop if round == 0
xtset subject round

gen byte midpoint = (belief == 0.5)
gen double d_lag = abs(b_lag - 0.5)
gen abssum_of_signals = abs(sum_of_signals)

* To avoid dropping observations in the regression, put in the same bin
* those who have seen at least 5 signals
replace abssum_of_signals = 5 if abssum_of_signals >= 5


* Create treatment variable
gen byte tr = .
replace tr = 0 if treatment == "Control"
replace tr = 1 if treatment == "Narratives"
replace tr = 2 if treatment == "Followup"

label define tr ///
    0 "Urn" ///
    1 "Story" ///
    2 "Story No Info", replace

label values tr tr

* Mixed-effects probit model
quietly meprobit midpoint ///
    ib1.tr##c.d_lag##c.d_lag ///
    i.abssum_of_signals i.round ///
    if uninformative == 1 & d_lag > 0 ///
    || subject:

estadd scalar Observations = e(N)
estimates store M_midpoint_quad
eststo probit_midpoint_quad

* PREDICTED PROBABILITIES
margins tr, at(d_lag=(0.05(0.05)0.5))

marginsplot, ///
    yti("") ///
    xti("") ///
    ti("Probability of reporting 0.5") ///
    legend( ///
        order(1 "Urn" 2 "Story" 3 "Story No Info") ///
        pos(2) ring(0) rows(3) ///
    ) ///
    plot1opts( ///
        msymbol(o) ///
        mcolor(blue%30) ///
        lcolor(blue%60) ///
    ) ///
    plot2opts( ///
        msymbol(o) ///
        mcolor(red%30) ///
        lcolor(red%60) ///
    ) ///
    plot3opts( ///
        msymbol(o) ///
        mcolor(purple%30) ///
        lcolor(purple%60) ///
    ) ///
    yscale(range(0 .8)) ///
    ylab(0(0.1).8) ///
    noci ///
    name(midpoint_all_quad, replace)

* TREATMENT CONTRASTS ON THE PROBABILITY SCALE
estimates restore M_midpoint_quad

quietly margins tr, at(d_lag=(0.05(0.05)0.5)) post

matrix b = e(b)
matrix V = e(V)

clear
set obs 20

gen double d_lag = .
gen str30 contrast = ""
gen double effect = .
gen double se = .

local row = 1

forvalues j = 1/10 {

    local x = `j' * 0.05

    /*
    Within each value of d_lag, the margins are ordered as:

        1. Urn
        2. Story
        3. Story No Info
    */

    local urn    = 3 * (`j' - 1) + 1
    local story  = 3 * (`j' - 1) + 2
    local noinfo = 3 * (`j' - 1) + 3


    * Story - Urn
    scalar diff_su = ///
        b[1, `story'] - b[1, `urn']

    scalar se_su = sqrt( ///
        V[`story', `story'] + ///
        V[`urn', `urn'] - ///
        2 * V[`story', `urn'] ///
    )

    replace d_lag = `x' in `row'
    replace contrast = "Story - Urn" in `row'
    replace effect = diff_su in `row'
    replace se = se_su in `row'

    local ++row


    * Story - Story No Info
    scalar diff_sn = ///
        b[1, `story'] - b[1, `noinfo']

    scalar se_sn = sqrt( ///
        V[`story', `story'] + ///
        V[`noinfo', `noinfo'] - ///
        2 * V[`story', `noinfo'] ///
    )

    replace d_lag = `x' in `row'
    replace contrast = "Story - Story No Info" in `row'
    replace effect = diff_sn in `row'
    replace se = se_sn in `row'

    local ++row
}


* Confidence intervals
gen double lb = effect - invnormal(0.975) * se
gen double ub = effect + invnormal(0.975) * se

sort contrast d_lag


* PLOT TREATMENT EFFECTS
twoway ///
    (rcap ub lb d_lag if contrast == "Story - Urn", ///
        lcolor(black%70)) ///
    (line effect d_lag if contrast == "Story - Urn", ///
        lcolor(black%70) ///
        lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Urn", ///
        mcolor(black%70) ///
        msymbol(o)) ///
    (rcap ub lb d_lag if contrast == "Story - Story No Info", ///
        lcolor(black%30)) ///
    (line effect d_lag if contrast == "Story - Story No Info", ///
        lcolor(black%30) ///
        lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Story No Info", ///
        mcolor(black%30) ///
        msymbol(o)), ///
    yline(0, lcolor(black%40) lp(solid)) ///
    yti("") ///
    xti("") ///
    ti("Treatment effect") ///
    legend( ///
        order(2 "Story - Urn" ///
              5 "Story - Story No Info") ///
        pos(5) ring(0) rows(2) ///
    ) ///
    xscale(range(0.05 0.5)) ///
    xlab(0.05(0.05)0.5) ///
    yscale(range(-0.5 0.5)) ///
    ylab(-0.5(0.1)0.5) ///
    name(midpoint_treat_eff_all_quad, replace)

* COMBINE AND EXPORT
graph combine ///
    midpoint_all_quad ///
    midpoint_treat_eff_all_quad, ///
    cols(2) ///
    b1title("|{it:Belief}{sub:t-1} − 0.5|") ///
    l1title("Predicted probability") ///
    name(uncertainty_quad, replace)
restore





********************************************************************************
********************   FIGURE C.6 (TOWARD UNCERTAINTY QUADRATIC)  **************
********************************************************************************
preserve
egen subject = group(id)
drop if round == 0
xtset subject round
gen double toward_middle = abs(b_lag - 0.5) - abs(belief - 0.5)
gen double d_lag = abs(b_lag - 0.5)
gen abssum_of_signals = abs(sum_of_signals)
// to avoid dropping observation in regression, put on the same bin those that have seen at least 5 signals (in narrative none have 6)
replace abssum_of_signals = 5 if abssum_of_signals >= 5

* Create treatment variable
gen byte tr = .
replace tr = 0 if treatment == "Control"
replace tr = 1 if treatment == "Narratives"
replace tr = 2 if treatment == "Followup"
label define tr 0 "Urn" 1 "Story" 2 "Story No Info", replace
label values tr tr

* Positive values mean movement toward 0.5
* Quadratic relationship in d_lag, fully interacted with treatment
quietly mixed toward_middle ///
    ib1.tr##c.d_lag##c.d_lag ///
    i.abssum_of_signals i.round ///
    if uninformative == 1 & d_lag > 0 ///
    || subject:

estimates store M_quad
estadd scalar Observations = e(N)
eststo toward_midpoint_quad

* Predicted movement toward 0.5
margins tr, at(d_lag=(0.05(0.05)0.5))

marginsplot, ///
    yti("") xti("") ///
    ti("Move toward 0.5") ///
    legend(order(1 "Urn" 2 "Story" 3 "Story No Info") ///
        pos(5) ring(0) rows(3)) ///
    yline(0, lcolor(black%40) lp(dash)) ///
    plot1opts(msymbol(o) mcolor(blue%30) lcolor(blue%60)) ///
    plot2opts(msymbol(o) mcolor(red%30) lcolor(red%60)) ///
    plot3opts(msymbol(o) mcolor(purple%30) lcolor(purple%60)) ///
    yscale(range(-0.2 0.2)) ///
    ylab(-0.2(0.05)0.2) ///
    noci ///
    name(move_toward_all_quad, replace)

* Treatment contrasts
estimates restore M_quad

quietly margins tr, at(d_lag=(0.05(0.05)0.5)) post

matrix b = e(b)
matrix V = e(V)
clear
set obs 20
gen double d_lag = .
gen str30 contrast = ""
gen double effect = .
gen double se = .

local row = 1
forvalues j = 1/10 {
    local x = `j' * 0.05
    /*
    Within each value of d_lag, margins are ordered as:
    1. Urn
    2. Story
    3. Story No Info
    */
    local urn    = 3 * (`j' - 1) + 1
    local story  = 3 * (`j' - 1) + 2
    local noinfo = 3 * (`j' - 1) + 3
    * Story - Urn
    scalar diff_su = b[1, `story'] - b[1, `urn']

    scalar se_su = sqrt( ///
        V[`story', `story'] + ///
        V[`urn', `urn'] - ///
        2 * V[`story', `urn'] ///
    )
    replace d_lag = `x' in `row'
    replace contrast = "Story - Urn" in `row'
    replace effect = diff_su in `row'
    replace se = se_su in `row'

    local ++row

    * Story - Story No Info
    scalar diff_sn = b[1, `story'] - b[1, `noinfo']

    scalar se_sn = sqrt( ///
        V[`story', `story'] + ///
        V[`noinfo', `noinfo'] - ///
        2 * V[`story', `noinfo'] ///
    )

    replace d_lag = `x' in `row'
    replace contrast = "Story - Story No Info" in `row'
    replace effect = diff_sn in `row'
    replace se = se_sn in `row'

    local ++row
}

gen double lb = effect - invnormal(0.975) * se
gen double ub = effect + invnormal(0.975) * se

twoway ///
    (rcap ub lb d_lag if contrast == "Story - Urn", ///
        lcolor(black%70)) ///
    (line effect d_lag if contrast == "Story - Urn", ///
        lcolor(black%70) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Urn", ///
        mcolor(black%70) msymbol(o)) ///
    (rcap ub lb d_lag if contrast == "Story - Story No Info", ///
        lcolor(black%30)) ///
    (line effect d_lag if contrast == "Story - Story No Info", ///
        lcolor(black%30) lwidth(medthick)) ///
    (scatter effect d_lag if contrast == "Story - Story No Info", ///
        mcolor(black%30) msymbol(o)), ///
    yline(0, lcolor(black%40) lp(solid)) ///
    yti("") xti("") ///
    ti("Treatment effect") ///
    legend(order(2 "Story - Urn" ///
                 5 "Story - Story No Info") ///
        pos(5) ring(0) rows(2)) ///
    xscale(range(0.05 0.5)) ///
    xlab(0.05(0.05)0.5) ///
    yscale(range(-0.2 0.2)) ///
    ylab(-0.2(0.05)0.2) ///
    name(toward_treat_eff_all_quad, replace)

* Combine and export
graph combine ///
    move_toward_all_quad ///
    toward_treat_eff_all_quad, ///
    cols(2) ///
    b1title("|{it:Belief}{sub:t-1} − 0.5|") ///
    l1title("Predicted movement") ///
    name(toward_uncertainty_quad, replace)
restore
********************************************************************************











********************************************************************************
*   FIGURE C.7 (PERSISTENCE OF NEAR-MIDPOINT REPORTS)
********************************************************************************
local reset_low_pp   45
local reset_high_pp  55
local bootstrap_reps 10000
local bootstrap_seed 123456789

* Save original data.
tempfile original_data episodes estimates bootstrap_draws
quietly save `original_data', replace

* Allow the code to be rerun.
foreach v in has_next belief_tp1 sign_tp1 belief_pp b_lag_pp    ///
             reset_report likelihood_state1 likelihood_state0   ///
             pred_persist pred_return Delta trt {
    capture drop `v'
}

*   CONSTRUCT EPISODES
* Construct t+1 within the same participant.
sort id round

by id (round): gen byte has_next =                             ///
    _n < _N & round[_n+1] == round + 1

by id (round): gen double belief_tp1 = belief[_n+1] if has_next
by id (round): gen byte sign_tp1 = sign[_n+1] if has_next

* Retain nondiagnostic signals immediately followed by a diagnostic signal.
keep if round > 0                                              ///
    & has_next                                                 ///
    & sign == 0                                                ///
    & inlist(sign_tp1, -1, 1)                                 ///
    & inlist(treatment, "Control", "Narratives", "Followup")

* Convert beliefs to integer percentage points.
gen int belief_pp = round(100*belief)
gen int b_lag_pp  = round(100*b_lag)

*   DEFINE NEAR-MIDPOINT REPORTS

* The belief reported after the nondiagnostic signal is between
* 0.45 and 0.55, inclusive, while the previous belief is outside this band.
gen byte reset_report =                                       ///
    inrange(belief_pp, `reset_low_pp', `reset_high_pp')       ///
    & !missing(b_lag_pp)                                      ///
    & !inrange(b_lag_pp, `reset_low_pp', `reset_high_pp')

keep if reset_report

*   CONSTRUCT PERSISTENCE AND REVERSION PREDICTIONS


* Likelihood of the realized diagnostic signal in each state.
gen double likelihood_state1 = cond(sign_tp1 == 1, .45, .30)
gen double likelihood_state0 = cond(sign_tp1 == 1, .30, .45)

* Persistence: update from the belief reported after the nondiagnostic signal.
gen double pred_persist =                                     ///
    (likelihood_state1*belief) /                              ///
    (likelihood_state1*belief + likelihood_state0*(1-belief))

* Reversion: update after reinstating the previous belief.
gen double pred_return =                                      ///
    (likelihood_state1*b_lag) /                               ///
    (likelihood_state1*b_lag + likelihood_state0*(1-b_lag))

* Positive Delta means that persistence predicts b_(t+1) better.
gen double Delta = 100*(                                      ///
    abs(belief_tp1 - pred_return)                             ///
    - abs(belief_tp1 - pred_persist))

gen byte trt = .
replace trt = 1 if treatment == "Control"
replace trt = 2 if treatment == "Narratives"
replace trt = 3 if treatment == "Followup"

save `episodes', replace


*   PARTICIPANT MEANS AND BOOTSTRAP CONFIDENCE INTERVALS
tempname results

postfile `results'                                            ///
    byte trt                                                  ///
    double estimate ci_low ci_high                            ///
    int N_participants N_episodes                             ///
    using `estimates', replace

forvalues trt = 1/3 {

    use `episodes', clear
    keep if trt == `trt'

    quietly count
    local N_episodes = r(N)

    * Give every participant equal weight.
    collapse (mean) Delta, by(id)

    quietly count
    local N_participants = r(N)

    quietly summarize Delta, meanonly
    local estimate = r(mean)

    * Bootstrap participants within the current treatment.
    local this_seed = `bootstrap_seed' + `trt'

    quietly bootstrap r(mean),                               ///
        reps(`bootstrap_reps')                               ///
        seed(`this_seed')                                    ///
        saving(`bootstrap_draws', replace)                   ///
        nodots: summarize Delta

    use `bootstrap_draws', clear

    quietly _pctile _bs_1, p(2.5 97.5)
    local ci_low  = r(r1)
    local ci_high = r(r2)

    post `results'                                           ///
        (`trt')                                              ///
        (`estimate')                                         ///
        (`ci_low')                                           ///
        (`ci_high')                                          ///
        (`N_participants')                                   ///
        (`N_episodes')
}

postclose `results'
use `estimates', clear

format estimate ci_low ci_high %5.1f


*   PARTICIPANT COUNTS
quietly summarize N_participants if trt == 1, meanonly
local N_urn = r(mean)

quietly summarize N_participants if trt == 2, meanonly
local N_story = r(mean)

quietly summarize N_participants if trt == 3, meanonly
local N_noinfo = r(mean)


*   FIGURE
twoway                                                        ///
    (rcap ci_low ci_high trt, horizontal                       ///
        lcolor(black) lwidth(medthin))                         ///
    (scatter trt estimate,                                    ///
        msymbol(O) mcolor(black) msize(medlarge)               ///
        mlabel(estimate) mlabformat(%4.1f) mlabposition(12)    ///
        mlabcolor(black) mlabsize(small)),                     ///
    xline(0, lcolor(gs8) lpattern(dash) lwidth(medthin))       ///
    ylabel(1 "Urn (N=`N_urn')"                                 ///
            2 "Story (N=`N_story')"                           ///
            3 "Story No Info (N=`N_noinfo')",                 ///
            angle(horizontal) labsize(small))                  ///
    yscale(reverse range(.5 3.5))                             ///
    xlabel(, format(%4.1f) labsize(small))                     ///
     xtitle("{&Delta}{sub:i}") ytitle("")                                               ///
    title("Midpoint reset") ///
	subtitle("Transitory       Persistent") /// 
    legend(off)                                               ///
    graphregion(color(white))                                 ///
    bgcolor(white)                                           ///
    name(post_reset_near_midpoint, replace)
* Restore original data.
use `original_data', clear








********************************************************************************
*   FIGURE C.8   (PERSISTENCE OF MOVEMENT TOWARD 0.5)
********************************************************************************
local minimum_move_pp 5
local bootstrap_reps  10000
local bootstrap_seed  123456789

* Anchor the episode on nondiagnostic row t and construct t+1 within string id.
sort id round
by id (round): gen byte has_next = _n < _N & round[_n+1] == round + 1
by id (round): gen double belief_tp1 = belief[_n+1] if has_next
by id (round): gen byte sign_tp1 = sign[_n+1] if has_next

keep if round > 0 & has_next & sign == 0 & inlist(sign_tp1, -1, 1) & inlist(treatment, "Control", "Narratives", "Followup")

* Integer percentage-point versions avoid floating-point threshold problems.
gen int belief_pp = round(100*belief)
gen int b_lag_pp  = round(100*b_lag)

gen byte exact_reset = belief_pp == 50 & b_lag_pp != 50

gen byte meaningful_move = abs(belief_pp - 50) < abs(b_lag_pp - 50) & abs(belief_pp - b_lag_pp) >= `minimum_move_pp'

keep if exact_reset | meaningful_move

* Likelihood of the realized diagnostic signal in state 1 and state 0.
gen double likelihood_state1 = cond(sign_tp1 == 1, .45, .30)
gen double likelihood_state0 = cond(sign_tp1 == 1, .30, .45)

* Persistence: apply Bayes' rule to the belief actually reported at t.
gen double pred_persist =                                       ///
    (likelihood_state1*belief) /                                 ///
    (likelihood_state1*belief + likelihood_state0*(1-belief))

* Return: apply Bayes' rule after reinstating the pre-reset belief b_(t-1).
gen double pred_return = (likelihood_state1*b_lag) / (likelihood_state1*b_lag + likelihood_state0*(1-b_lag))

* Percentage-point prediction advantage of persistence over return.
gen double Delta = 100*(abs(belief_tp1 - pred_return) - abs(belief_tp1 - pred_persist))

gen byte trt = .
replace trt = 1 if treatment == "Control"
replace trt = 2 if treatment == "Narratives"
replace trt = 3 if treatment == "Followup"

tempfile episodes estimates bootstrap_draws
save `episodes', replace

* Estimate treatment means after first giving every participant one observation.
* Percentile confidence intervals resample participants, not episodes.
tempname results
postfile `results' byte sample trt double estimate ci_low ci_high int N_participants N_episodes using `estimates', replace

forvalues sample = 1/2 {

    use `episodes', clear

    if `sample' == 1 keep if exact_reset
    if `sample' == 2 keep if meaningful_move

    forvalues trt = 1/3 {

        preserve
        keep if trt == `trt'

        quietly count
        local N_episodes = r(N)

        collapse (mean) Delta, by(id)

        quietly count
        local N_participants = r(N)

        quietly summarize Delta, meanonly
        local estimate = r(mean)

        local this_seed = `bootstrap_seed' + 100*`sample' + `trt'
        quietly bootstrap r(mean), reps(`bootstrap_reps')        ///
            seed(`this_seed') saving(`bootstrap_draws', replace) ///
            nodots: summarize Delta

        use `bootstrap_draws', clear
        quietly _pctile _bs_1, p(2.5 97.5)
        local ci_low  = r(r1)
        local ci_high = r(r2)

        post `results' (`sample') (`trt') (`estimate')           ///
            (`ci_low') (`ci_high')                               ///
            (`N_participants') (`N_episodes')

        restore
    }
}

postclose `results'
use `estimates', clear

format estimate ci_low ci_high %5.1f

* Participant counts for the panel labels.
quietly summarize N_participants if sample == 1 & trt == 1, meanonly
local N_exact_urn = r(mean)
quietly summarize N_participants if sample == 1 & trt == 2, meanonly
local N_exact_story = r(mean)
quietly summarize N_participants if sample == 1 & trt == 3, meanonly
local N_exact_noinfo = r(mean)

quietly summarize N_participants if sample == 2 & trt == 1, meanonly
local N_move_urn = r(mean)
quietly summarize N_participants if sample == 2 & trt == 2, meanonly
local N_move_story = r(mean)
quietly summarize N_participants if sample == 2 & trt == 3, meanonly
local N_move_noinfo = r(mean)

* all nondiagnostic movements of at least 5 pp toward the midpoint.
twoway                                                          ///
    (rcap ci_low ci_high trt if sample == 2, horizontal          ///
        lcolor(black) lwidth(medthin))                           ///
    (scatter trt estimate if sample == 2,                       ///
        msymbol(O) mcolor(black) msize(medlarge)                 ///
        mlabel(estimate) mlabformat(%4.1f) mlabposition(12)      ///
        mlabcolor(black) mlabsize(small)),                       ///
    xline(0, lcolor(gs8) lpattern(dash) lwidth(medthin))         ///
    ylabel(1 "Urn (N=`N_move_urn')"                             ///
            2 "Story (N=`N_move_story')"                       ///
            3 "Story No Info (N=`N_move_noinfo')",             ///
            angle(horizontal))                   ///
    yscale(reverse range(.5 3.5))                               ///
    xlabel(, format(%4.1f) labsize(small))                       ///
     xtitle("{&Delta}{sub:i}") ytitle("")                                      ///
    title("Movement toward 0.5")    ///
	subtitle("Transitory       Persistent")      ///                                     
    legend(off) graphregion(color(white) margin(zero))           ///
    bgcolor(white) name(midpoint_move_panel, replace)
********************************************************************************








use data_cleaned.dta, replace
gen control = (narrative == 0 & followup == 0)

********************************************************************************
**  TABLE C.3
********************************************************************************
// truncate beliefs within [0.01, 0.99] to have the ln() defined for all observations
preserve
replace belief = 0.01 if belief == 0
replace belief = 0.99 if belief == 1
gen p = ln(belief/(1-belief))  // ln()
by id (round): gen lag_p = p[_n-1]
by id (round): gen delta_z = sum_of_signals - sum_of_signals[_n-1]
gen favour_guilty = (lag_p > 0 & sign == 1 & !missing(lag_p))
gen favour_innocent = (lag_p < 0 & sign == -1 & !missing(lag_p))
gen use_null_guilty = (lag_p > 0 & sign == 0 & !missing(lag_p))
gen use_null_innocent = (lag_p < 0 & sign == 0 & !missing(lag_p))
gen use_null_neutral = (lag_p == 0 & sign == 0 & !missing(lag_p))

reg p lag_p delta_z favour_guilty favour_innocent use_null_neutral use_null_guilty use_null_innocent if treatment == "Control", noconstant vce(cluster id)
test lag_p = 1
test delta_z = 0.4055

reg p lag_p delta_z favour_guilty favour_innocent use_null_neutral use_null_guilty use_null_innocent if treatment == "Narratives", noconstant vce(cluster id)
test lag_p = 1
test delta_z = 0.4055

reg p lag_p delta_z favour_guilty favour_innocent use_null_neutral use_null_guilty use_null_innocent if treatment == "Followup", noconstant vce(cluster id)
test lag_p = 1
test delta_z = 0.4055

restore




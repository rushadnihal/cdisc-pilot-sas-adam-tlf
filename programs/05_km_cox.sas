/*******************************************************************************
Program : 05_km_cox.sas
Purpose : Time to first dermatologic adverse event (ADTTE, PARAMCD = TTDE):
            Figure 1  Kaplan-Meier curves by treatment arm, with number at risk
            Table 7   Kaplan-Meier summary and log-rank test (PROC LIFETEST)
            Table 8   Cox proportional hazards model, treatment only (PROC PHREG)
            Table 9   Cox model adjusted for age and sex (PROC PHREG)
            Check     Proportional hazards assessment (PROC PHREG ASSESS PH)
Inputs  : ADAM.ADTTE (03_adtte.sas)
Outputs : &root/output/05_km_cox.rtf (tables and figure)
          &root/output/05_km_dermatologic.png (Kaplan-Meier figure)
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Event = CNSR 0 (first treatment-emergent dermatologic AE), censored =
          CNSR 1. Time is in days from first dose, day 1 = date of first dose.
          Analysis population: safety population (all 254 subjects).
          Cox model: Efron method for tied event times, Placebo is the reference.
          Expected results (prototyped outside SAS before this program was written):
            events 29 / 62 / 61 (Placebo / Low / High), censored 57 / 22 / 23
            median days Placebo not reached, Low 33, High 36
            log-rank chi-square about 60.3 on 2 df, p < 0.0001
            Cox HR vs Placebo: Low about 4.15, High about 5.03
*******************************************************************************/

%let root = /home/u64094222/cdisc_pilot;
libname adam "&root/data/adam" access=readonly;

options nodate nonumber;

proc format;
  value trtf 0  = 'Placebo'
             54 = 'Xanomeline Low Dose'
             81 = 'Xanomeline High Dose';
run;

/* ---- 1. Analysis dataset ---------------------------------------------------- */
data work.tte;
  set adam.adtte;
  where saffl = 'Y' and paramcd = 'TTDE';
  event = 1 - cnsr;
  format trtan trtf.;
  label aval = 'Days from first dose to first dermatologic AE or censoring';
run;

title1 "Check: analysis dataset by treatment arm";
proc sql;
  select trtan format=trtf. label='Treatment',
         count(*)           as n_subjects label='Subjects',
         sum(event)         as n_events   label='Events',
         sum(1 - event)     as n_censored label='Censored',
         min(aval)          as min_days   label='Minimum days',
         max(aval)          as max_days   label='Maximum days'
  from work.tte
  group by trtan;
quit;
title;

/* ---- 2. Output files ------------------------------------------------------------- */
ods noproctitle;
ods listing gpath="&root/output" image_dpi=200;
ods graphics on / width=8in height=5.5in imagename="05_km_dermatologic" imagefmt=png;
ods rtf file="&root/output/05_km_cox.rtf" style=journal startpage=yes;

/* ---- 3. Figure 1 and Table 7: Kaplan-Meier and log-rank --------------------------------- */
title1 "Figure 1 and Table 7";
title2 "Time to First Dermatologic Adverse Event - Safety Population";
footnote1 "Kaplan-Meier estimate. Tick marks are censored subjects. The number at risk is shown below the plot.";
footnote2 "The p-value is from the log-rank test across the three treatment arms. Source: 05_km_cox.sas";

ods select SurvivalPlot Quartiles CensoredSummary HomTests;
proc lifetest data=work.tte method=km plots=survival(atrisk=0 to 210 by 30 test);
  time aval * event(0);
  strata trtan / test=logrank;
run;

/* ---- 4. Table 8: Cox model, treatment only ---------------------------------------------- */
title1 "Table 8";
title2 "Cox Proportional Hazards Model for Time to First Dermatologic Adverse Event - Treatment Only";
footnote1 "Hazard ratios compare each pair of arms. A ratio above 1 means a higher rate of dermatologic events in the first-named arm.";
footnote2 "Efron method for tied event times. Source: 05_km_cox.sas";

ods select ModelInfo FitStatistics GlobalTests ParameterEstimates HazardRatios;
proc phreg data=work.tte;
  class trtan(ref='Placebo') / param=ref;
  model aval * event(0) = trtan / ties=efron risklimits;
  hazardratio 'Treatment arm' trtan / diff=all;
run;

/* ---- 5. Table 9: Cox model adjusted for age and sex --------------------------------------- */
title1 "Table 9";
title2 "Cox Proportional Hazards Model for Time to First Dermatologic Adverse Event - Adjusted for Age and Sex";
footnote1 "Age is in years. Females are compared with males. Placebo is the reference treatment arm.";
footnote2 "Efron method for tied event times. Source: 05_km_cox.sas";

ods select ModelInfo GlobalTests ParameterEstimates;
proc phreg data=work.tte;
  class trtan(ref='Placebo') sex(ref='M') / param=ref;
  model aval * event(0) = trtan age sex / ties=efron risklimits;
run;

/* ---- 6. Proportional hazards assessment ------------------------------------------------------ */
title1 "Check: Proportional Hazards Assessment";
title2 "Cumulative martingale residual test of the treatment effect (model with treatment only)";
footnote1 "A small p-value would suggest that the hazard ratio changes over time. Source: 05_km_cox.sas";

proc phreg data=work.tte;
  class trtan(ref='Placebo') / param=ref;
  model aval * event(0) = trtan / ties=efron;
  assess ph / resample seed=20261115;
run;

ods rtf close;
ods graphics off;
ods listing close;
ods proctitle;
title;
footnote;

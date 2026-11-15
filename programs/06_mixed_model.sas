/*******************************************************************************
Program : 06_mixed_model.sas
Purpose : Change from baseline in ADAS-Cog(11) total score (PARAMCD = ACTOT), efficacy
          population, with PROC MIXED:
            Table 10  ANCOVA at Week 24 with last observation carried forward (LOCF)
            Table 11  Dose response test at Week 24 (LOCF)
            Table 12  Repeated measures model (MMRM) at Weeks 8, 16 and 24, observed data
            Figure 2  Least squares means by visit from the repeated measures model
Inputs  : &root/data/adam_ref/adqsadas.xpt (PHUSE reference ADQSADAS)
Outputs : &root/output/06_mixed_model.rtf (tables and figure)
          &root/output/06_adascog_lsmeans.png (figure)
Author  : rushadnihal
Date    : 2026-11-15
Notes   : ADQSADAS is not derived in this project. The published PHUSE reference
          dataset is the input, so this program checks the modelling code and not
          the ADAS-Cog derivation (visit windows, LOCF, baseline). ADQSADAS holds
          one record per subject, visit and ADAS-Cog item or total. Only the total
          score (ACTOT) is used.
          Records used: EFFFL = Y, ANL01FL = Y, visits Week 8, 16 and 24, change
          from baseline not missing. The LOCF analysis keeps the LOCF records
          (DTYPE = LOCF). The repeated measures model drops them and uses observed
          scores only. Treatment (TRTPN) is 0 Placebo, 54 Low Dose, 81 High Dose.
          The stored value for 0 is 5.4E-79, so numeric codes are rounded.
          No adjustment is made for multiple comparisons.
          Expected results (prototyped outside SAS before this program was written):
            ANCOVA Week 24 LOCF: n 79 / 81 / 74 (Placebo / Low / High)
              LS mean change 2.47 / 2.01 / 1.47
              Low vs Placebo -0.47 (p 0.57), High vs Placebo -1.01 (p 0.23),
              High vs Low -0.54 (p 0.52), treatment F test p about 0.49,
              dose response p about 0.24
            MMRM: 539 records from 234 subjects
              Week 24 LS mean change about 2.33 / 1.74 / 1.50
              Week 24 Low vs Placebo about -0.59, High vs Placebo about -0.83
              (the SAS standard errors will differ a little because SAS uses the
              Kenward-Roger degrees of freedom and adjustment)
*******************************************************************************/

%let root = /home/YOUR_USER_ID/cdisc_pilot;
libname refx xport "&root/data/adam_ref/adqsadas.xpt" access=readonly;

options nodate nonumber;

proc format;
  value trtf 0  = 'Placebo'
             54 = 'Xanomeline 54 mg (Low Dose)'
             81 = 'Xanomeline 81 mg (High Dose)';
  value visf 8  = 'Week 8'
             16 = 'Week 16'
             24 = 'Week 24';
run;

/* ---- 1. Analysis datasets ------------------------------------------------------ */
data work.adas;
  set refx.adqsadas;
  where paramcd = 'ACTOT' and efffl = 'Y' and anl01fl = 'Y'
        and not missing(chg) and not missing(base);
  trtn = round(trtpn);
  visn = round(avisitn);
  if visn in (8, 16, 24);
  format trtn trtf. visn visf.;
  label trtn  = 'Treatment arm'
        visn  = 'Visit'
        chg   = 'Change from baseline in ADAS-Cog(11)'
        base  = 'Baseline ADAS-Cog(11)';
run;

/* Week 24 LOCF: one record per subject */
data work.locf24;
  set work.adas;
  where visn = 24;
run;

/* Observed scores only, for the repeated measures model */
data work.obs;
  set work.adas;
  where dtype ne 'LOCF';
run;

title1 "Check: records in the analysis datasets";
proc sql;
  select 'Week 24 LOCF' as dataset length=20,
         trtn format=trtf. label='Treatment',
         count(*) as n_records label='Records',
         count(distinct usubjid) as n_subjects label='Subjects'
  from work.locf24
  group by trtn;
  select 'Observed' as dataset length=20,
         visn format=visf. label='Visit',
         trtn format=trtf. label='Treatment',
         count(*) as n_records label='Records',
         count(distinct usubjid) as n_subjects label='Subjects'
  from work.obs
  group by visn, trtn;
  select 'Observed total' as dataset length=20,
         count(*) as n_records label='Records',
         count(distinct usubjid) as n_subjects label='Subjects'
  from work.obs;
quit;
title;

/* ---- 2. Output files ------------------------------------------------------------- */
ods noproctitle;
ods listing gpath="&root/output" image_dpi=200;
ods graphics on / reset=index width=8in height=5.5in imagename="06_adascog_lsmeans" imagefmt=png;
ods rtf file="&root/output/06_mixed_model.rtf" style=journal startpage=yes;

/* ---- 3. Table 10: ANCOVA at Week 24 with LOCF --------------------------------------- */
title1 "Table 10";
title2 "ADAS-Cog(11) Change from Baseline to Week 24 (LOCF) - Efficacy Population";
title3 "Analysis of covariance: treatment, site group and baseline score";
footnote1 "Least squares means are adjusted to the mean baseline score and equal weights for site groups. No adjustment for multiple comparisons.";
footnote2 "A higher ADAS-Cog score is worse, so a negative difference means the first-named arm had the lower (better) score. Source: 06_mixed_model.sas";

ods select ModelInfo Tests3;
ods output LSMeans=work.an_lsm Diffs=work.an_diff;
proc mixed data=work.locf24;
  class trtn sitegr1;
  model chg = base trtn sitegr1 / ddfm=residual;
  lsmeans trtn / diff cl alpha=0.05;
run;

data work.an_diff2;
  set work.an_diff;
  length comparison $60;
  comparison = strip(put(_trtn, trtf.)) || ' vs ' || strip(put(trtn, trtf.));
  difference = -estimate;
  dlower     = -upper;
  dupper     = -lower;
  label comparison = 'Comparison'
        difference = 'Difference in LS mean change'
        dlower     = 'Lower 95% limit'
        dupper     = 'Upper 95% limit'
        stderr     = 'Standard error'
        probt      = 'p-value';
run;

title2 "ADAS-Cog(11) Week 24 (LOCF) - Least Squares Mean Change from Baseline";
proc print data=work.an_lsm noobs label;
  var trtn estimate stderr lower upper;
  format estimate stderr lower upper 8.2;
  label estimate = 'LS mean change' stderr = 'Standard error'
        lower = 'Lower 95% limit' upper = 'Upper 95% limit';
run;

title2 "ADAS-Cog(11) Week 24 (LOCF) - Pairwise Differences";
proc print data=work.an_diff2 noobs label;
  var comparison difference stderr dlower dupper probt;
  format difference stderr dlower dupper 8.2 probt pvalue6.4;
run;

/* ---- 4. Table 11: dose response at Week 24 ----------------------------------------------- */
data work.locf24d;
  set work.locf24;
  dose = trtn / 81;
  label dose = 'Dose (fraction of the high dose)';
run;

title1 "Table 11";
title2 "ADAS-Cog(11) Change from Baseline to Week 24 (LOCF) - Dose Response Test";
title3 "Treatment entered as a linear dose term, with site group and baseline score";
footnote1 "The dose term is the dose divided by 81 mg, so its estimate is the change in score from placebo to the high dose.";
footnote2 "Source: 06_mixed_model.sas";

ods select Tests3 SolutionF;
proc mixed data=work.locf24d;
  class sitegr1;
  model chg = base dose sitegr1 / solution ddfm=residual;
run;

/* ---- 5. Table 12 and Figure 2: repeated measures model ------------------------------------- */
title1 "Table 12";
title2 "ADAS-Cog(11) Change from Baseline - Repeated Measures Model, Observed Scores - Efficacy Population";
title3 "Fixed effects: baseline, treatment, visit, treatment by visit, site group and baseline by visit";
footnote1 "Unstructured covariance between visits within a subject. Kenward-Roger degrees of freedom. No adjustment for multiple comparisons.";
footnote2 "Subjects with at least one observed post-baseline score are included. Source: 06_mixed_model.sas";

ods select ModelInfo ConvergenceStatus CovParms Tests3;
ods output LSMeans=work.mm_lsm Diffs=work.mm_diff;
proc mixed data=work.obs method=reml order=internal;
  class usubjid trtn visn sitegr1;
  model chg = base trtn visn trtn*visn sitegr1 base*visn / ddfm=kr;
  repeated visn / subject=usubjid type=un;
  lsmeans trtn*visn / diff cl alpha=0.05;
run;

data work.mm_diff2;
  set work.mm_diff;
  where visn = _visn;
  length comparison $60;
  comparison = strip(put(_trtn, trtf.)) || ' vs ' || strip(put(trtn, trtf.));
  difference = -estimate;
  dlower     = -upper;
  dupper     = -lower;
  label comparison = 'Comparison'
        difference = 'Difference in LS mean change'
        dlower     = 'Lower 95% limit'
        dupper     = 'Upper 95% limit'
        stderr     = 'Standard error'
        probt      = 'p-value';
run;

proc sort data=work.mm_diff2;
  by visn comparison;
run;

proc sort data=work.mm_lsm;
  by trtn visn;
run;

title2 "ADAS-Cog(11) - Least Squares Mean Change from Baseline by Visit";
title3;
proc print data=work.mm_lsm noobs label;
  var visn trtn estimate stderr lower upper;
  format estimate stderr lower upper 8.2;
  label estimate = 'LS mean change' stderr = 'Standard error'
        lower = 'Lower 95% limit' upper = 'Upper 95% limit';
run;

title2 "ADAS-Cog(11) - Pairwise Differences by Visit";
proc print data=work.mm_diff2 noobs label;
  var visn comparison difference stderr dlower dupper probt;
  format difference stderr dlower dupper 8.2 probt pvalue6.4;
run;

data work.mm_plot;
  set work.mm_lsm;
  xpos = visn + (trtn = 81) * 0.7 - (trtn = 0) * 0.7;
run;

title1 "Figure 2";
title2 "ADAS-Cog(11) Least Squares Mean Change from Baseline by Visit - Efficacy Population";
title3;
footnote1 "Repeated measures model, observed scores. Bars are 95% confidence intervals. A higher ADAS-Cog score is worse.";
footnote2 "Source: 06_mixed_model.sas";

proc sgplot data=work.mm_plot;
  highlow x=xpos low=lower high=upper / group=trtn lowcap=serif highcap=serif;
  series x=xpos y=estimate / group=trtn markers markerattrs=(symbol=circlefilled size=8)
         name='lsm';
  refline 0 / axis=y lineattrs=(pattern=dash);
  xaxis values=(6 8 16 24 26) valuesdisplay=(' ' 'Week 8' 'Week 16' 'Week 24' ' ')
        label='Visit';
  yaxis label='LS mean change from baseline (95% CI)';
  keylegend 'lsm' / title='Treatment arm';
run;

ods rtf close;
ods graphics off;
ods listing close;
ods proctitle;
title;
footnote;
libname refx clear;

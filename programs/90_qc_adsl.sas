/*******************************************************************************
Program : 90_qc_adsl.sas
Purpose : QC of ADAM.ADSL against the published PHUSE reference ADSL using
          PROC COMPARE.
Inputs  : ADAM.ADSL (from 01_adsl.sas); &root/data/adam_ref/adsl.xpt
Outputs : PROC COMPARE report in the Results tab (no permanent datasets)
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Expected differences are listed in docs/adsl_spec.md (BMIBLGR1 for
          subject 01-702-1082; variable lengths and labels). Numeric values are
          compared with an absolute criterion of 1E-6, so the placebo dose codes
          (reference stores 0 as 5.4E-79) compare as equal.
*******************************************************************************/

%let root = /home/YOUR_USER_ID/cdisc_pilot;
libname adam "&root/data/adam" access=readonly;
libname refx xport "&root/data/adam_ref/adsl.xpt" access=readonly;

options nodate nonumber;

data work.adsl_ref;
  set refx.adsl;
run;

proc sort data=work.adsl_ref;
  by usubjid;
run;

proc sort data=adam.adsl out=work.adsl_new;
  by usubjid;
run;

title "ADSL QC: derived ADAM.ADSL (compare) vs PHUSE reference ADSL (base)";
proc compare base=work.adsl_ref compare=work.adsl_new
             method=absolute criterion=1e-6
             listall maxprint=(200, 32767);
  id usubjid;
run;

title;
libname refx clear;

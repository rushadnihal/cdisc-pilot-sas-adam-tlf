/*******************************************************************************
Program : 91_qc_adae.sas
Purpose : QC of ADAM.ADAE against the published PHUSE reference ADAE using
          PROC COMPARE.
Inputs  : ADAM.ADAE (from 02_adae.sas); &root/data/adam_ref/adae.xpt
Outputs : PROC COMPARE report in the Results tab (no permanent datasets)
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Records are matched on USUBJID and AESEQ. Numeric values are compared
          with an absolute criterion of 1E-6. Differences in variable lengths
          are expected (see docs/adae_spec.md).
*******************************************************************************/

%let root = /home/u64094222/cdisc_pilot;
libname adam "&root/data/adam" access=readonly;
libname refx xport "&root/data/adam_ref/adae.xpt" access=readonly;

options nodate nonumber;

data work.adae_ref;
  set refx.adae;
run;

proc sort data=work.adae_ref;
  by usubjid aeseq;
run;

proc sort data=adam.adae out=work.adae_new;
  by usubjid aeseq;
run;

title "ADAE QC: derived ADAM.ADAE (compare) vs PHUSE reference ADAE (base)";
proc compare base=work.adae_ref compare=work.adae_new
             method=absolute criterion=1e-6
             listall maxprint=(200, 32767);
  id usubjid aeseq;
run;

title;
libname refx clear;

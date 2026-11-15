/*******************************************************************************
Program : 92_qc_adtte.sas
Purpose : QC of ADAM.ADTTE against the published PHUSE reference ADTTE using
          PROC COMPARE.
Inputs  : ADAM.ADTTE (from 03_adtte.sas); &root/data/adam_ref/adtte.xpt
Outputs : PROC COMPARE report in the Results tab (no permanent datasets)
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Expected: EVNTDESC differs for the 152 event records because the
          reference text contains typos ("Dematologic Event Occured") that are
          corrected here. Numeric values use an absolute criterion of 1E-6, so the
          reference's 5.4E-79 stored as zero for CNSR compares as equal.
*******************************************************************************/

%let root = /home/YOUR_USER_ID/cdisc_pilot;
libname adam "&root/data/adam" access=readonly;
libname refx xport "&root/data/adam_ref/adtte.xpt" access=readonly;

options nodate nonumber;

data work.adtte_ref;
  set refx.adtte;
run;

proc sort data=work.adtte_ref;
  by usubjid;
run;

proc sort data=adam.adtte out=work.adtte_new;
  by usubjid;
run;

title "ADTTE QC: derived ADAM.ADTTE (compare) vs PHUSE reference ADTTE (base)";
proc compare base=work.adtte_ref compare=work.adtte_new
             method=absolute criterion=1e-6
             listall maxprint=(200, 32767);
  id usubjid;
run;

title;
libname refx clear;

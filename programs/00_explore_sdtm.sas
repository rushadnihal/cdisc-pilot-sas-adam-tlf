/*******************************************************************************
Program : 00_explore_sdtm.sas
Purpose : Explore the SDTM datasets before writing ADaM specifications: arms,
          supplemental qualifiers, dispositions, exposure, AE coding, QS tests,
          visits, and date completeness. Read-only; creates no datasets.
Inputs  : SDTM library (created by 00_setup.sas)
Outputs : Listings and frequency tables in the Results tab
Author  : rushadnihal
Date    : 2026-11-15
*******************************************************************************/

%let root = /home/u64094222/cdisc_pilot;
libname sdtm "&root/data/sdtm" access=readonly;

options nodate nonumber;

/* ---- DM ------------------------------------------------------------------ */
title "DM: rows vs distinct subjects";
proc sql;
  select count(*) as n_rows, count(distinct usubjid) as n_subjects from sdtm.dm;
quit;

title "DM: planned vs actual arm";
proc freq data=sdtm.dm;
  tables arm*actarm armcd*actarmcd / list missing;
run;

title "DM: sex, race, ethnicity, country";
proc freq data=sdtm.dm;
  tables sex race ethnic country / missing;
run;

title "DM: age";
proc means data=sdtm.dm n nmiss mean std min max;
  var age;
run;

/* ---- SUPPDM -------------------------------------------------------------- */
title "SUPPDM: qualifier names and labels";
proc freq data=sdtm.suppdm;
  tables rdomain*qnam*qlabel / list missing;
run;

title "SUPPDM: values for each qualifier";
proc freq data=sdtm.suppdm;
  tables qnam*qval / list missing;
run;

/* ---- DS ------------------------------------------------------------------ */
title "DS: category and standardized disposition term";
proc freq data=sdtm.ds;
  tables dscat*dsdecod / list missing;
run;

title "SUPPDS: qualifiers";
proc freq data=sdtm.suppds;
  tables qnam*qlabel*qval / list missing;
run;

/* ---- EX ------------------------------------------------------------------ */
title "EX: treatment, dose, frequency, route";
proc freq data=sdtm.ex;
  tables extrt*exdose*exdosu*exdosfrq*exroute / list missing;
run;

title "EX: records per subject";
proc sql;
  select count(distinct usubjid) as n_subjects_with_ex, count(*) as n_records from sdtm.ex;
quit;

/* ---- AE ------------------------------------------------------------------ */
title "AE: subjects with at least one AE";
proc sql;
  select count(distinct usubjid) as n_subjects_with_ae, count(*) as n_events from sdtm.ae;
quit;

title "AE: body system";
proc freq data=sdtm.ae order=freq;
  tables aebodsys / missing;
run;

title "AE: severity, seriousness, relationship, outcome, action taken";
proc freq data=sdtm.ae;
  tables aesev aeser aerel aeout aeacn / missing;
run;

title "SUPPAE: qualifiers";
proc freq data=sdtm.suppae;
  tables qnam*qlabel / list missing;
run;

title "SUPPAE: values for each qualifier";
proc freq data=sdtm.suppae;
  tables qnam*qval / list missing;
run;

/* ---- QS ------------------------------------------------------------------ */
title "QS: category and subcategory";
proc freq data=sdtm.qs;
  tables qscat*qsscat / list missing;
run;

title "QS: ADAS-Cog tests (categories containing ADAS)";
proc freq data=sdtm.qs;
  where upcase(qscat) contains 'ADAS';
  tables qstestcd*qstest / list missing;
run;

title "QS: ADAS-Cog visits and baseline flag";
proc freq data=sdtm.qs;
  where upcase(qscat) contains 'ADAS';
  tables visitnum*visit*qsblfl / list missing;
run;

/* ---- SV, trial design ---------------------------------------------------- */
title "SV: visits";
proc freq data=sdtm.sv;
  tables visitnum*visit / list missing;
run;

title "TA: trial arms";
proc print data=sdtm.ta noobs; run;

title "TE: trial elements";
proc print data=sdtm.te noobs; run;

title "TS: trial summary";
proc print data=sdtm.ts noobs; run;

/* ---- Date completeness (ISO 8601 character dates) ------------------------ */
title "Date completeness: missing, partial (<10 chars), with time (>10 chars)";
proc sql;
  select "DM.RFSTDTC" as variable length=14,
         sum(missing(rfstdtc)) as n_missing,
         sum(not missing(rfstdtc) and length(strip(rfstdtc)) < 10) as n_partial,
         sum(length(strip(rfstdtc)) > 10) as n_with_time from sdtm.dm
  union all
  select "DM.RFXSTDTC", sum(missing(rfxstdtc)),
         sum(not missing(rfxstdtc) and length(strip(rfxstdtc)) < 10),
         sum(length(strip(rfxstdtc)) > 10) from sdtm.dm
  union all
  select "DM.RFXENDTC", sum(missing(rfxendtc)),
         sum(not missing(rfxendtc) and length(strip(rfxendtc)) < 10),
         sum(length(strip(rfxendtc)) > 10) from sdtm.dm
  union all
  select "DM.RFENDTC", sum(missing(rfendtc)),
         sum(not missing(rfendtc) and length(strip(rfendtc)) < 10),
         sum(length(strip(rfendtc)) > 10) from sdtm.dm
  union all
  select "AE.AESTDTC", sum(missing(aestdtc)),
         sum(not missing(aestdtc) and length(strip(aestdtc)) < 10),
         sum(length(strip(aestdtc)) > 10) from sdtm.ae
  union all
  select "AE.AEENDTC", sum(missing(aeendtc)),
         sum(not missing(aeendtc) and length(strip(aeendtc)) < 10),
         sum(length(strip(aeendtc)) > 10) from sdtm.ae
  union all
  select "DS.DSSTDTC", sum(missing(dsstdtc)),
         sum(not missing(dsstdtc) and length(strip(dsstdtc)) < 10),
         sum(length(strip(dsstdtc)) > 10) from sdtm.ds
  union all
  select "EX.EXSTDTC", sum(missing(exstdtc)),
         sum(not missing(exstdtc) and length(strip(exstdtc)) < 10),
         sum(length(strip(exstdtc)) > 10) from sdtm.ex
  union all
  select "EX.EXENDTC", sum(missing(exendtc)),
         sum(not missing(exendtc) and length(strip(exendtc)) < 10),
         sum(length(strip(exendtc)) > 10) from sdtm.ex;
quit;

title;

/*******************************************************************************
Program : 03_adtte.sas
Purpose : Derive ADTTE (time-to-event dataset): time to first dermatologic event
          (PARAMCD=TTDE), following docs/adtte_spec.md. One record per subject.
Inputs  : ADAM.ADSL (01_adsl.sas), ADAM.ADAE (02_adae.sas)
Outputs : ADAM.ADTTE (permanent), checks in the Results tab
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Event = first treatment-emergent dermatologic adverse event (ADAE
          AOCC01FL='Y'). Subjects without an event are censored at the date of
          discontinuation/completion (ADSL.RFENDT).
*******************************************************************************/

%let root = /home/YOUR_USER_ID/cdisc_pilot;
libname adam "&root/data/adam";

options nodate nonumber;

/* ---- 1. Subject-level variables from ADSL ------------------------------------ */
proc sort data=adam.adsl
          out=work.adsl_sub(keep=studyid siteid usubjid age agegr1 agegr1n race
                                 racen sex trtsdt trtedt trtdur trt01p trt01a
                                 trt01an saffl rfendt
                            rename=(trt01p=trtp trt01a=trta trt01an=trtan));
  by usubjid;
run;

/* ---- 2. First treatment-emergent dermatologic event per subject --------------- */
data work.first_derm;
  set adam.adae;
  where aocc01fl = 'Y';
  ev_dt  = astdt;
  ev_seq = aeseq;
  keep usubjid ev_dt ev_seq;
run;

proc sort data=work.first_derm;
  by usubjid;
run;

/* ---- 3. Derive ADTTE ------------------------------------------------------------ */
data work.adtte;
  length param $40 paramcd $8 evntdesc $40 srcdom $4 srcvar $6;

  merge work.adsl_sub(in=in_adsl)
        work.first_derm(in=in_event);
  by usubjid;
  if in_adsl;

  param    = 'Time to First Dermatologic Event';
  paramcd  = 'TTDE';
  startdt  = trtsdt;

  if in_event then do;
    adt      = ev_dt;
    cnsr     = 0;
    evntdesc = 'Dermatologic Event Occurred';
    srcdom   = 'ADAE';
    srcvar   = 'ASTDT';
    srcseq   = ev_seq;
  end;
  else do;
    adt      = rfendt;
    cnsr     = 1;
    evntdesc = 'Study Completion Date';
    srcdom   = 'ADSL';
    srcvar   = 'RFENDT';
  end;

  if not missing(adt) and not missing(startdt) then aval = adt - startdt + 1;

  format startdt adt date9.;
  label param    = 'Parameter Description'
        paramcd  = 'Parameter Code'
        aval     = 'Analysis Value'
        startdt  = 'Time to Event Origin Date for Subject'
        adt      = 'Analysis Date'
        cnsr     = 'Censor'
        evntdesc = 'Event or Censoring Description'
        srcdom   = 'Source Domain'
        srcvar   = 'Source Variable'
        srcseq   = 'Source Sequence Number'
        trtp     = 'Planned Treatment'
        trta     = 'Actual Treatment'
        trtan    = 'Actual Treatment (N)';
run;

proc sql;
  create table adam.adtte as
  select studyid, siteid, usubjid, age, agegr1, agegr1n, race, racen, sex,
         trtsdt, trtedt, trtdur, trtp, trta, trtan, param, paramcd, aval,
         startdt, adt, cnsr, evntdesc, srcdom, srcvar, srcseq, saffl
  from work.adtte
  order by usubjid;
quit;

/* ---- 4. Checks ------------------------------------------------------------------ */
title "ADTTE check 1: one record per subject (expect 254 rows, 254 subjects)";
proc sql;
  select count(*) as n_rows, count(distinct usubjid) as n_subjects from adam.adtte;
quit;

title "ADTTE check 2: events and censoring by arm (expect 152 events, 102 censored)";
proc freq data=adam.adtte;
  tables trta*cnsr*evntdesc / list missing;
run;

title "ADTTE check 3: event source (expect 152 ADAE/ASTDT, 102 ADSL/RFENDT)";
proc freq data=adam.adtte;
  tables srcdom*srcvar / list missing;
run;

title "ADTTE check 4: every ADAE first dermatologic event is in ADTTE (expect 152 = 152)";
proc sql;
  select count(*) as n_adtte_events,
         (select count(*) from adam.adae where aocc01fl = 'Y') as n_adae_first_derm,
         (select count(distinct usubjid) from adam.adae where aocc01fl = 'Y') as n_adae_subjects
  from adam.adtte
  where cnsr = 0;
quit;

title "ADTTE check 5: analysis value (days from first dose); minimum should be at least 1";
proc means data=adam.adtte n nmiss min median max maxdec=1;
  var aval;
  class cnsr;
run;

title "ADTTE check 6: missing values in key variables (expect none)";
proc sql;
  select sum(missing(aval)) as miss_aval,
         sum(missing(adt)) as miss_adt,
         sum(missing(startdt)) as miss_startdt,
         sum(missing(cnsr)) as miss_cnsr
  from adam.adtte;
quit;

title "ADTTE check 7: dataset structure";
proc contents data=adam.adtte varnum;
run;

title;

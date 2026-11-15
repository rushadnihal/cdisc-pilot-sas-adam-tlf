/*******************************************************************************
Program : 01_adsl.sas
Purpose : Derive ADSL (subject-level analysis dataset) from SDTM, following
          docs/adsl_spec.md. One record per randomized subject.
Inputs  : SDTM library (created by 00_setup.sas): DM, SV, EX, DS, VS, MH, SC, QS
Outputs : ADAM.ADSL (permanent), checks in the Results tab
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Population = randomized subjects (ARMCD ne 'Scrnfail'); screen
          failures are not in ADSL. Treatment variables follow ARM for every
          subject (TRT01A = TRT01P), as in the PHUSE reference ADSL.
*******************************************************************************/

%let root = /home/u64094222/cdisc_pilot;
libname sdtm "&root/data/sdtm" access=readonly;
libname adam "&root/data/adam";

options nodate nonumber;

/* ---- 1. Base population from DM, with site pooling -------------------------
   A site is pooled into SITEGR1='900' when any of the three arms has fewer than
   3 subjects at that site (counts include subjects randomized at the site).  */
proc sql;
  create table work.sitecnt as
  select siteid,
         sum(arm = 'Placebo')              as n_pbo,
         sum(arm = 'Xanomeline Low Dose')  as n_low,
         sum(arm = 'Xanomeline High Dose') as n_high
  from sdtm.dm
  where armcd ne 'Scrnfail'
  group by siteid;

  create table work.dm_base as
  select a.*,
         (min(b.n_pbo, b.n_low, b.n_high) < 3) as pool_site
  from sdtm.dm as a
       left join work.sitecnt as b
       on a.siteid = b.siteid
  where a.armcd ne 'Scrnfail'
  order by a.usubjid;
quit;

/* ---- 2. Visit dates from SV (visits 1, 3, 4, 8, 10, 12) ---------------------
   PROC TRANSPOSE stops with an error if a subject has two records for the same
   visit, so it doubles as a uniqueness check.                                 */
data work.sv_sel;
  set sdtm.sv;
  where visitnum in (1, 3, 4, 8, 10, 12);
  svdt = input(svstdtc, yymmdd10.);
  keep usubjid visitnum svdt;
run;

proc sort data=work.sv_sel;
  by usubjid visitnum;
run;

proc transpose data=work.sv_sel out=work.sv_wide(drop=_name_) prefix=v;
  by usubjid;
  id visitnum;
  var svdt;
run;

/* ---- 3. Last exposure record from EX ---------------------------------------- */
proc sort data=sdtm.ex out=work.ex_sorted;
  by usubjid exseq;
run;

data work.ex_last;
  set work.ex_sorted;
  by usubjid;
  if last.usubjid;
  ex_enddt = input(exendtc, yymmdd10.);
  keep usubjid ex_enddt;
run;

/* ---- 4. Disposition event from DS ------------------------------------------- */
data work.ds_disp;
  set sdtm.ds;
  where dscat = 'DISPOSITION EVENT';
  ds_visitnum = visitnum;
  keep usubjid dsdecod dsterm ds_visitnum;
run;

proc sort data=work.ds_disp;
  by usubjid;
run;

/* ---- 5. Baseline height and weight (VS), education (SC), disease onset (MH) -- */
data work.vs_height;
  set sdtm.vs;
  where vstestcd = 'HEIGHT' and visitnum = 1;
  heightbl = round(vsstresn, 0.1);
  keep usubjid heightbl;
run;

data work.vs_weight;
  set sdtm.vs;
  where vstestcd = 'WEIGHT' and visitnum = 3;
  weightbl = round(vsstresn, 0.1);
  keep usubjid weightbl;
run;

data work.sc_educ;
  set sdtm.sc;
  where sctestcd = 'EDLEVEL';
  educlvl = scstresn;
  keep usubjid educlvl;
run;

data work.mh_prim;
  set sdtm.mh;
  where mhcat = 'PRIMARY DIAGNOSIS';
  disonsdt = input(mhstdtc, yymmdd10.);
  keep usubjid disonsdt;
run;

proc sort data=work.vs_height; by usubjid; run;
proc sort data=work.vs_weight; by usubjid; run;
proc sort data=work.sc_educ;   by usubjid; run;
proc sort data=work.mh_prim;   by usubjid; run;

/* ---- 6. QS: MMSE total, and subjects with post-baseline ADAS-Cog / CIBIC+ ---- */
proc sql;
  create table work.qs_mmse as
  select usubjid, sum(qsstresn) as mmsetot
  from sdtm.qs
  where qscat = 'MINI-MENTAL STATE'
  group by usubjid
  order by usubjid;

  create table work.qs_adas as
  select distinct usubjid
  from sdtm.qs
  where visitnum > 3 and index(upcase(qscat), 'ALZHEIMER') > 0
  order by usubjid;

  create table work.qs_cibic as
  select distinct usubjid
  from sdtm.qs
  where visitnum > 3 and index(upcase(qscat), 'CIBIC') > 0
  order by usubjid;
quit;

/* ---- 7. Merge sources and derive ADSL variables ------------------------------ */
data work.adsl;
  attrib
    studyid  length=$12 label='Study Identifier'
    usubjid  length=$11 label='Unique Subject Identifier'
    subjid   length=$4  label='Subject Identifier for the Study'
    siteid   length=$3  label='Study Site Identifier'
    sitegr1  length=$3  label='Pooled Site Group 1'
    arm      length=$20 label='Description of Planned Arm'
    trt01p   length=$20 label='Planned Treatment for Period 01'
    trt01pn  length=8   label='Planned Treatment for Period 01 (N)'
    trt01a   length=$20 label='Actual Treatment for Period 01'
    trt01an  length=8   label='Actual Treatment for Period 01 (N)'
    trtsdt   length=8   label='Date of First Exposure to Treatment' format=date9.
    trtedt   length=8   label='Date of Last Exposure to Treatment'  format=date9.
    trtdur   length=8   label='Duration of Treatment (days)'
    avgdd    length=8   label='Avg Daily Dose (as planned)'
    cumdose  length=8   label='Cumulative Dose (as planned)'
    age      length=8   label='Age'
    agegr1   length=$5  label='Pooled Age Group 1'
    agegr1n  length=8   label='Pooled Age Group 1 (N)'
    ageu     length=$6  label='Age Units'
    race     length=$78 label='Race'
    racen    length=8   label='Race (N)'
    sex      length=$1  label='Sex'
    ethnic   length=$25 label='Ethnicity'
    saffl    length=$1  label='Safety Population Flag'
    ittfl    length=$1  label='Intent-To-Treat Population Flag'
    efffl    length=$1  label='Efficacy Population Flag'
    comp8fl  length=$1  label='Completers of Week 8 Population Flag'
    comp16fl length=$1  label='Completers of Week 16 Population Flag'
    comp24fl length=$1  label='Completers of Week 24 Population Flag'
    disconfl length=$1  label='Did the Subject Discontinue the Study?'
    dsraefl  length=$1  label='Discontinued due to AE?'
    dthfl    length=$1  label='Subject Died?'
    bmibl    length=8   label='Baseline BMI (kg/m^2)'
    bmiblgr1 length=$6  label='Pooled Baseline BMI Group 1'
    heightbl length=8   label='Baseline Height (cm)'
    weightbl length=8   label='Baseline Weight (kg)'
    educlvl  length=8   label='Years of Education'
    disonsdt length=8   label='Date of Onset of Disease' format=date9.
    durdis   length=8   label='Duration of Disease (Months)'
    durdsgr1 length=$4  label='Pooled Disease Duration Group 1'
    visit1dt length=8   label='Date of Visit 1' format=date9.
    rfstdtc  length=$10 label='Subject Reference Start Date/Time'
    rfendtc  length=$10 label='Subject Reference End Date/Time'
    visnumen length=8   label='End of Trt Visit (Vis 12 or Early Term.)'
    rfendt   length=8   label='Date of Discontinuation/Completion' format=date9.
    dcdecod  length=$27 label='Standardized Disposition Term'
    dcreascd length=$18 label='Reason for Discontinuation'
    mmsetot  length=8   label='MMSE Total'
  ;

  merge work.dm_base(in=in_dm)
        work.sv_wide
        work.ex_last
        work.ds_disp
        work.vs_height
        work.vs_weight
        work.sc_educ
        work.mh_prim
        work.qs_mmse
        work.qs_adas(in=in_adas)
        work.qs_cibic(in=in_cibic);
  by usubjid;
  if in_dm;

  /* Site group */
  if pool_site then sitegr1 = '900';
  else sitegr1 = siteid;

  /* Treatment: actual = planned for every subject (matches PHUSE ADSL) */
  trt01p = arm;
  select (arm);
    when ('Placebo')              trt01pn = 0;
    when ('Xanomeline Low Dose')  trt01pn = 54;
    when ('Xanomeline High Dose') trt01pn = 81;
    otherwise                     trt01pn = .;
  end;
  trt01a  = trt01p;
  trt01an = trt01pn;

  /* Dates and duration */
  visit1dt = v1;
  trtsdt   = v3;
  rfendt   = input(rfendtc, yymmdd10.);
  /* Last dose date from EX; if missing, date of discontinuation/completion */
  if not missing(ex_enddt) then trtedt = ex_enddt;
  else trtedt = rfendt;
  if not missing(trtsdt) and not missing(trtedt) then trtdur = trtedt - trtsdt + 1;

  /* Cumulative dose as planned. High dose: 54 mg/day until visit 4, 81 mg/day
     from visit 4 to visit 12, 54 mg/day after visit 12.                       */
  if not missing(trtdur) then do;
    if trt01pn in (0, 54) then cumdose = trt01pn * trtdur;
    else if trt01pn = 81 then do;
      if missing(v4) or trtedt < v4 then do;
        d1 = trtedt - trtsdt + 1;
        d2 = 0;
        d3 = 0;
      end;
      else do;
        d1 = v4 - trtsdt + 1;
        if missing(v12) or trtedt < v12 then do;
          d2 = trtedt - v4;
          d3 = 0;
        end;
        else do;
          d2 = v12 - v4;
          d3 = trtedt - v12;
        end;
      end;
      cumdose = 54 * d1 + 81 * d2 + 54 * d3;
    end;
    avgdd = round(cumdose / trtdur, 0.1);
  end;

  /* Age and race groupings */
  if not missing(age) then do;
    if age < 65 then agegr1n = 1;
    else if age <= 80 then agegr1n = 2;
    else agegr1n = 3;
  end;
  select (agegr1n);
    when (1) agegr1 = '<65';
    when (2) agegr1 = '65-80';
    when (3) agegr1 = '>80';
    otherwise agegr1 = ' ';
  end;
  select (race);
    when ('WHITE')                             racen = 1;
    when ('BLACK OR AFRICAN AMERICAN')         racen = 2;
    when ('ASIAN')                             racen = 3;
    when ('AMERICAN INDIAN OR ALASKA NATIVE')  racen = 6;
    otherwise                                  racen = .;
  end;

  /* Population flags */
  if armcd ne ' ' then ittfl = 'Y'; else ittfl = 'N';
  if ittfl = 'Y' and not missing(trtsdt) then saffl = 'Y'; else saffl = 'N';
  if saffl = 'Y' and in_adas and in_cibic then efffl = 'Y'; else efffl = 'N';
  if not missing(v8)  and rfendt >= v8  then comp8fl  = 'Y'; else comp8fl  = 'N';
  if not missing(v10) and rfendt >= v10 then comp16fl = 'Y'; else comp16fl = 'N';
  if not missing(v12) and rfendt >= v12 then comp24fl = 'Y'; else comp24fl = 'N';

  /* Disposition */
  select (dsdecod);
    when ('ADVERSE EVENT')               dcreascd = 'Adverse Event';
    when ('COMPLETED')                   dcreascd = 'Completed';
    when ('DEATH')                       dcreascd = 'Death';
    when ('LACK OF EFFICACY')            dcreascd = 'Lack of Efficacy';
    when ('LOST TO FOLLOW-UP')           dcreascd = 'Lost to Follow-up';
    when ('PHYSICIAN DECISION')          dcreascd = 'Physician Decision';
    when ('STUDY TERMINATED BY SPONSOR') dcreascd = 'Sponsor Decision';
    when ('WITHDRAWAL BY SUBJECT')       dcreascd = 'Withdrew Consent';
    when ('PROTOCOL VIOLATION') do;
      if dsterm = 'PROTOCOL ENTRY CRITERIA NOT MET' then dcreascd = 'I/E Not Met';
      else dcreascd = 'Protocol Violation';
    end;
    otherwise dcreascd = ' ';
  end;
  dcdecod = dsdecod;
  if dcreascd ne 'Completed' and not missing(dcreascd) then disconfl = 'Y';
  if dcreascd = 'Adverse Event' then dsraefl = 'Y';
  if ds_visitnum = 13 then visnumen = 12;
  else visnumen = ds_visitnum;

  /* Baseline body measures (height and weight rounded to 1 decimal in VS step) */
  if not missing(heightbl) and not missing(weightbl) then
    bmibl = round(weightbl / ((heightbl / 100) ** 2), 0.1);
  if not missing(bmibl) then do;
    if bmibl < 25 then bmiblgr1 = '<25';
    else if bmibl < 30 then bmiblgr1 = '25-<30';
    else bmiblgr1 = '>=30';
  end;

  /* Disease duration in months (visit 1 date minus onset date, plus 1 day) */
  if not missing(visit1dt) and not missing(disonsdt) then do;
    durdis = round((visit1dt - disonsdt + 1) / 30.4375, 0.1);
    if durdis < 12 then durdsgr1 = '<12'; else durdsgr1 = '>=12';
  end;

  keep studyid usubjid subjid siteid sitegr1 arm trt01p trt01pn trt01a trt01an
       trtsdt trtedt trtdur avgdd cumdose age agegr1 agegr1n ageu race racen sex
       ethnic saffl ittfl efffl comp8fl comp16fl comp24fl disconfl dsraefl dthfl
       bmibl bmiblgr1 heightbl weightbl educlvl disonsdt durdis durdsgr1
       visit1dt rfstdtc rfendtc visnumen rfendt dcdecod dcreascd mmsetot;
run;

proc sort data=work.adsl out=adam.adsl;
  by usubjid;
run;

/* ---- 8. Checks ---------------------------------------------------------------- */
title "ADSL check 1: one record per subject (expect 254 rows, 254 subjects)";
proc sql;
  select count(*) as n_rows, count(distinct usubjid) as n_subjects from adam.adsl;
quit;

title "ADSL check 2: treatment arms (expect 86 / 84 / 84)";
proc freq data=adam.adsl;
  tables arm*trt01p*trt01a*trt01pn / list missing;
run;

title "ADSL check 3: population and completer flags";
proc freq data=adam.adsl;
  tables saffl ittfl efffl comp8fl comp16fl comp24fl disconfl dsraefl dthfl / missing;
run;

title "ADSL check 4: disposition and visit of end of treatment";
proc freq data=adam.adsl;
  tables dcdecod*dcreascd visnumen / list missing;
run;

title "ADSL check 5: groupings and site pooling";
proc freq data=adam.adsl;
  tables sitegr1 agegr1*agegr1n race*racen bmiblgr1 durdsgr1 / list missing;
run;

title "ADSL check 6: numeric variables";
proc means data=adam.adsl n nmiss min mean max maxdec=2;
  var age trtdur avgdd cumdose bmibl heightbl weightbl educlvl durdis mmsetot;
  class trt01p;
run;

title "ADSL check 7: missing key dates (expect none for TRTSDT, TRTEDT, RFENDT)";
proc sql;
  select sum(missing(trtsdt)) as miss_trtsdt,
         sum(missing(trtedt)) as miss_trtedt,
         sum(missing(rfendt)) as miss_rfendt,
         sum(missing(visit1dt)) as miss_visit1dt,
         sum(missing(disonsdt)) as miss_disonsdt,
         sum(missing(weightbl)) as miss_weightbl,
         sum(missing(bmibl)) as miss_bmibl
  from adam.adsl;
quit;

title "ADSL check 8: dataset structure";
proc contents data=adam.adsl varnum;
run;

title;

/*******************************************************************************
Program : 02_adae.sas
Purpose : Derive ADAE (adverse event analysis dataset) from SDTM AE and ADAM.ADSL,
          following docs/adae_spec.md. One record per adverse event.
Inputs  : SDTM.AE, ADAM.ADSL (from 01_adsl.sas)
Outputs : ADAM.ADAE (permanent), checks in the Results tab
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Partial start dates of the form YYYY-MM are imputed to the first of the
          month (ASTDTF='D'). Year-only start dates are left missing, which
          makes the event not treatment emergent. Duration is not derived when
          the start day was imputed.
*******************************************************************************/

%let root = /home/YOUR_USER_ID/cdisc_pilot;
libname sdtm "&root/data/sdtm" access=readonly;
libname adam "&root/data/adam";

options nodate nonumber;

/* ---- 1. Subject-level variables carried into ADAE ---------------------------- */
proc sort data=adam.adsl
          out=work.adsl_sub(keep=usubjid siteid trt01a trt01an age agegr1 agegr1n
                                 race racen sex saffl trtsdt trtedt
                            rename=(trt01a=trta trt01an=trtan));
  by usubjid;
run;

proc sort data=sdtm.ae out=work.ae_sorted;
  by usubjid aeseq;
run;

/* ---- 2. Merge AE with ADSL and derive record-level variables ----------------- */
data work.adae0;
  length astdtf $1 aduru $3 trtemfl $1 cq01nam $19;

  merge work.ae_sorted(in=in_ae)
        work.adsl_sub(in=in_adsl);
  by usubjid;
  if in_ae;
  if not in_adsl then putlog "WARNING: [02_adae] AE record without ADSL subject: " usubjid= aeseq=;

  /* Analysis start date: complete dates as-is; YYYY-MM imputed to day 01 */
  if lengthn(aestdtc) = 10 then astdt = input(aestdtc, yymmdd10.);
  else if lengthn(aestdtc) = 7 then do;
    astdt  = input(strip(aestdtc) || '-01', yymmdd10.);
    astdtf = 'D';
  end;

  /* Analysis end date: complete dates only (no partial end dates in this study) */
  if lengthn(aeendtc) = 10 then aendt = input(aeendtc, yymmdd10.);

  /* Relative days (no day 0) */
  if not missing(astdt) and not missing(trtsdt) then do;
    if astdt >= trtsdt then astdy = astdt - trtsdt + 1;
    else astdy = astdt - trtsdt;
  end;
  if not missing(aendt) and not missing(trtsdt) then do;
    if aendt >= trtsdt then aendy = aendt - trtsdt + 1;
    else aendy = aendt - trtsdt;
  end;

  /* Duration in days, only when the start day was not imputed */
  if astdtf = ' ' and not missing(astdt) and not missing(aendt) then do;
    adurn = aendt - astdt + 1;
    aduru = 'DAY';
  end;

  /* Treatment-emergent: start date on or after first dose */
  if not missing(astdt) and not missing(trtsdt) and astdt >= trtsdt then trtemfl = 'Y';
  else trtemfl = 'N';

  /* Customized query 01: dermatologic events */
  if index(upcase(aedecod), 'APPLICATION') > 0
     or index(upcase(aedecod), 'DERMATITIS') > 0
     or index(upcase(aedecod), 'ERYTHEMA') > 0
     or index(upcase(aedecod), 'BLISTER') > 0
     or (aebodsys = 'SKIN AND SUBCUTANEOUS TISSUE DISORDERS'
         and upcase(aedecod) not in ('COLD SWEAT', 'HYPERHIDROSIS', 'ALOPECIA'))
  then cq01nam = 'DERMATOLOGIC EVENTS';

  format astdt aendt date9.;
  label astdt   = 'Analysis Start Date'
        astdtf  = 'Analysis Start Date Imputation Flag'
        astdy   = 'Analysis Start Relative Day'
        aendt   = 'Analysis End Date'
        aendy   = 'Analysis End Relative Day'
        adurn   = 'AE Duration (N)'
        aduru   = 'AE Duration Units'
        trta    = 'Actual Treatment'
        trtan   = 'Actual Treatment (N)'
        trtemfl = 'Treatment Emergent Analysis Flag'
        cq01nam = 'Customized Query 01 Name';
run;

/* ---- 3. First-occurrence flags ------------------------------------------------
   Each flag marks the first record, ordered by start date then AESEQ, within the
   group named in &grp, among the records selected by &cond.                     */
%macro occ(flag=, cond=, grp=, lastvar=usubjid, label=);
  proc sort data=work.adae0(where=(&cond) keep=usubjid aeseq aebodsys aedecod astdt
                                                trtemfl aeser cq01nam)
            out=work.occ_tmp;
    by usubjid &grp astdt aeseq;
  run;

  data work.occ_&flag(keep=usubjid aeseq &flag);
    length &flag $1;
    set work.occ_tmp;
    by usubjid &grp;
    if first.&lastvar then do;
      &flag = 'Y';
      output;
    end;
    label &flag = "&label";
  run;

  proc sort data=work.occ_&flag;
    by usubjid aeseq;
  run;
%mend occ;

%occ(flag=aoccfl,   cond=%str(trtemfl='Y'),
     grp=,                      lastvar=usubjid,
     label=1st Occurrence of Any AE Flag);
%occ(flag=aoccsfl,  cond=%str(trtemfl='Y'),
     grp=aebodsys,              lastvar=aebodsys,
     label=1st Occurrence of SOC Flag);
%occ(flag=aoccpfl,  cond=%str(trtemfl='Y'),
     grp=aebodsys aedecod,      lastvar=aedecod,
     label=1st Occurrence of Preferred Term Flag);
%occ(flag=aocc02fl, cond=%str(trtemfl='Y' and aeser='Y'),
     grp=,                      lastvar=usubjid,
     label=1st Occurrence 02 Flag for Serious);
%occ(flag=aocc03fl, cond=%str(trtemfl='Y' and aeser='Y'),
     grp=aebodsys,              lastvar=aebodsys,
     label=1st Occurrence 03 Flag for Serious SOC);
%occ(flag=aocc04fl, cond=%str(trtemfl='Y' and aeser='Y'),
     grp=aebodsys aedecod,      lastvar=aedecod,
     label=1st Occurrence 04 Flag for Serious PT);
%occ(flag=aocc01fl, cond=%str(trtemfl='Y' and cq01nam ne ' '),
     grp=,                      lastvar=usubjid,
     label=1st Occurrence 01 Flag for CQ01);

/* ---- 4. Attach flags and put variables in final order ------------------------ */
data work.adae1;
  merge work.adae0
        work.occ_aoccfl
        work.occ_aoccsfl
        work.occ_aoccpfl
        work.occ_aocc02fl
        work.occ_aocc03fl
        work.occ_aocc04fl
        work.occ_aocc01fl;
  by usubjid aeseq;
run;

proc sql;
  create table adam.adae as
  select studyid, siteid, usubjid, trta, trtan, age, agegr1, agegr1n, race, racen,
         sex, saffl, trtsdt, trtedt, astdt, astdtf, astdy, aendt, aendy, adurn,
         aduru, aeterm, aellt, aelltcd, aedecod, aeptcd, aehlt, aehltcd, aehlgt,
         aehlgtcd, aebodsys, aesoc, aesoccd, aesev, aeser, aescan, aescong,
         aesdisab, aesdth, aeshosp, aeslife, aesod, aerel, aeacn, aeout, aeseq,
         trtemfl, aoccfl, aoccsfl, aoccpfl, aocc02fl, aocc03fl, aocc04fl,
         cq01nam, aocc01fl
  from work.adae1
  order by usubjid, aeseq;
quit;

/* ---- 5. Checks ----------------------------------------------------------------- */
title "ADAE check 1: records and subjects (expect 1191 records, 225 subjects)";
proc sql;
  select count(*) as n_records,
         count(distinct usubjid) as n_subjects,
         count(distinct catx('-', usubjid, put(aeseq, 8.))) as n_unique_keys
  from adam.adae;
quit;

title "ADAE check 2: treatment-emergent flag (expect Y 1126, N 65)";
proc freq data=adam.adae;
  tables trtemfl*trta / missing;
run;

title "ADAE check 3: start date imputation and missing dates (expect D 15; 11 missing ASTDT)";
proc sql;
  select sum(astdtf = 'D') as n_day_imputed,
         sum(missing(astdt)) as n_astdt_missing,
         sum(missing(aendt)) as n_aendt_missing,
         sum(not missing(adurn)) as n_with_duration
  from adam.adae;
quit;

title "ADAE check 4: dermatologic events (expect 493 records) by treatment-emergent flag";
proc freq data=adam.adae;
  tables cq01nam*trtemfl / missing;
run;

title "ADAE check 5: first-occurrence flags (expect AOCC01FL=Y 152)";
proc freq data=adam.adae;
  tables aoccfl aoccsfl aoccpfl aocc02fl aocc03fl aocc04fl aocc01fl / missing;
run;

title "ADAE check 6: subjects with a treatment-emergent AE and with a dermatologic TEAE, by arm";
proc sql;
  select trta,
         count(distinct case when aoccfl = 'Y' then usubjid end)  as n_subj_teae,
         count(distinct case when aocc01fl = 'Y' then usubjid end) as n_subj_derm_teae
  from adam.adae
  group by trta;
quit;

title "ADAE check 7: relative days and duration";
proc means data=adam.adae n nmiss min median max;
  var astdy aendy adurn;
run;

title "ADAE check 8: dataset structure";
proc contents data=adam.adae varnum;
run;

title;

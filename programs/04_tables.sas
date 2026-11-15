/*******************************************************************************
Program : 04_tables.sas
Purpose : Summary tables from ADSL and ADAE, written to one RTF file:
            Table 1  Analysis populations
            Table 2  Baseline demographics and characteristics
            Table 3  Subject disposition
            Table 4  Treatment exposure
            Table 5  Overview of treatment-emergent adverse events
            Table 6  Treatment-emergent adverse events by body system and term
Inputs  : ADAM.ADSL (01_adsl.sas), ADAM.ADAE (02_adae.sas), ADAM.ADTTE (check only)
Outputs : &root/output/04_tables.rtf, plus the same tables in the Results tab
Author  : rushadnihal
Date    : 2026-11-15
Notes   : Columns are the planned treatment arms plus a total. Percentages use the
          number of subjects in each column as the denominator. No hypothesis tests
          are shown for baseline characteristics (arms are randomized, so baseline
          p-values are not informative). ITT, safety and the total column all
          contain the same 254 randomized subjects in this study.
*******************************************************************************/

%let root = /home/u64094222/cdisc_pilot;
libname adam "&root/data/adam" access=readonly;

options nodate nonumber orientation=landscape;

/* ---- 1. Analysis population with display variables ---------------------------- */
data work.pop;
  length agegr1_c $8 sex_c $8 race_c $40 ethnic_c $30 bmigr_c $12 durgr_c $14;
  set adam.adsl;
  where ittfl = 'Y';

  /* Treatment column: 1 Placebo, 2 Low Dose, 3 High Dose */
  select (trt01pn);
    when (0)  trtn = 1;
    when (54) trtn = 2;
    when (81) trtn = 3;
    otherwise trtn = .;
  end;

  agegr1_c = agegr1;
  agegr1_o = agegr1n;

  select (sex);
    when ('F') do; sex_c = 'Female'; sex_o = 1; end;
    when ('M') do; sex_c = 'Male';   sex_o = 2; end;
    otherwise  do; sex_c = 'Unknown'; sex_o = 9; end;
  end;

  race_o = coalesce(racen, 99);
  select (racen);
    when (1)  race_c = 'White';
    when (2)  race_c = 'Black or African American';
    when (3)  race_c = 'Asian';
    when (6)  race_c = 'American Indian or Alaska Native';
    otherwise race_c = 'Other or unknown';
  end;

  select (upcase(ethnic));
    when ('HISPANIC OR LATINO')     do; ethnic_c = 'Hispanic or Latino';     ethnic_o = 1; end;
    when ('NOT HISPANIC OR LATINO') do; ethnic_c = 'Not Hispanic or Latino'; ethnic_o = 2; end;
    otherwise                       do; ethnic_c = 'Other or unknown';       ethnic_o = 9; end;
  end;

  select (bmiblgr1);
    when ('<25')    do; bmigr_c = '<25';    bmigr_o = 1; end;
    when ('25-<30') do; bmigr_c = '25 to <30'; bmigr_o = 2; end;
    when ('>=30')   do; bmigr_c = '>=30';   bmigr_o = 3; end;
    otherwise       do; bmigr_c = 'Missing'; bmigr_o = 4; end;
  end;

  select (durdsgr1);
    when ('<12')  do; durgr_c = '<12 months';  durgr_o = 1; end;
    when ('>=12') do; durgr_c = '>=12 months'; durgr_o = 2; end;
    otherwise     do; durgr_c = 'Missing';     durgr_o = 3; end;
  end;

  select (dcreascd);
    when ('Adverse Event')       dcord = 1;
    when ('Death')               dcord = 2;
    when ('I/E Not Met')         dcord = 3;
    when ('Lack of Efficacy')    dcord = 4;
    when ('Lost to Follow-up')   dcord = 5;
    when ('Physician Decision')  dcord = 6;
    when ('Protocol Violation')  dcord = 7;
    when ('Sponsor Decision')    dcord = 8;
    when ('Withdrew Consent')    dcord = 9;
    otherwise                    dcord = 99;
  end;
run;

/* Same subjects again as column 4 (Total) */
data work.popall;
  set work.pop
      work.pop(in=in_total);
  if in_total then trtn = 4;
run;

/* Column denominators: &n1 Placebo, &n2 Low Dose, &n3 High Dose, &n4 Total */
proc sql noprint;
  select count(*) into :n1 trimmed from work.popall where trtn = 1;
  select count(*) into :n2 trimmed from work.popall where trtn = 2;
  select count(*) into :n3 trimmed from work.popall where trtn = 3;
  select count(*) into :n4 trimmed from work.popall where trtn = 4;
quit;
%put NOTE: [04_tables] Column Ns: Placebo &n1, Low Dose &n2, High Dose &n3, Total &n4;

/* ---- 2. Row-building macros ------------------------------------------------------
   Every row is stored as (roword, lbl, trtn, cell) in a "long" dataset, then
   transposed to one column per treatment.                                        */

%macro init(sect);
  data work.long_&sect;
    length roword 8 lbl $120 trtn 8 cell $30;
    stop;
  run;
%mend init;

/* Section heading row (blank cells) */
%macro hdr(sect=, ord=, text=);
  data work.hd;
    length lbl $120 cell $30;
    roword = &ord;
    lbl    = "&text";
    cell   = ' ';
    do trtn = 1 to 4;
      output;
    end;
  run;
  proc append base=work.long_&sect data=work.hd force;
  run;
%mend hdr;

/* One row of n (%) counting subjects with a flag condition */
%macro flagrow(sect=, ds=, cond=, text=, ord=);
  proc sql;
    create table work.fr as
    select &ord as roword, "&text" as lbl length=120, trtn, sum(&cond) as n
    from &ds
    group by trtn;
  quit;
  data work.frl(keep=roword lbl trtn cell);
    set work.fr;
    length cell $30;
    bign = input(symget('n' || strip(put(trtn, 1.))), best12.);
    cell = strip(put(n, 4.)) || ' (' || strip(put(100 * n / bign, 5.1)) || '%)';
  run;
  proc append base=work.long_&sect data=work.frl force;
  run;
%mend flagrow;

/* Rows of n (%) for each level of a categorical variable; &ord is a numeric
   order variable, rows are placed after &ordbase. Zero counts are kept.       */
%macro catrows(sect=, ds=, var=, ord=, ordbase=);
  proc sql;
    create table work.cf as
    select l.&ord as ordv, l.&var as lv, t.trtn, count(d.usubjid) as count
    from (select distinct &ord, &var from &ds) as l
         cross join
         (select distinct trtn from work.popall) as t
         left join &ds as d
         on d.&ord = l.&ord and d.&var = l.&var and d.trtn = t.trtn
    group by l.&ord, l.&var, t.trtn;
  quit;
  data work.cl(keep=roword lbl trtn cell);
    set work.cf;
    length lbl $120 cell $30;
    roword = &ordbase + ordv / 100;
    lbl    = '    ' || strip(lv);
    bign   = input(symget('n' || strip(put(trtn, 1.))), best12.);
    cell   = strip(put(count, 4.)) || ' (' || strip(put(100 * count / bign, 5.1)) || '%)';
  run;
  proc append base=work.long_&sect data=work.cl force;
  run;
%mend catrows;

/* Continuous variable: n, mean (SD), median, min and max */
%macro controws(sect=, ds=, var=, text=, dec=1, ord=);
  proc means data=&ds noprint nway;
    class trtn;
    var &var;
    output out=work.mo n=n mean=mean std=std median=median min=min max=max;
  run;
  data work.mol(keep=roword lbl trtn cell);
    set work.mo;
    length lbl $120 cell $30;
    roword = &ord + 0.1; lbl = "&text";        cell = ' ';  output;
    roword = &ord + 0.2; lbl = '    n';        cell = strip(put(n, 5.));  output;
    roword = &ord + 0.3; lbl = '    Mean (SD)';
      cell = strip(put(mean, 8.&dec)) || ' (' || strip(put(std, 8.%eval(&dec + 1))) || ')';
      output;
    roword = &ord + 0.4; lbl = '    Median';   cell = strip(put(median, 8.&dec));  output;
    roword = &ord + 0.5; lbl = '    Min, Max';
      cell = strip(put(min, 8.&dec)) || ', ' || strip(put(max, 8.&dec));
      output;
  run;
  proc append base=work.long_&sect data=work.mol force;
  run;
%mend controws;

/* Subjects with at least one treatment-emergent AE meeting a condition */
%macro subjrow(sect=, cond=, text=, ord=);
  proc sql;
    create table work.sr as
    select &ord as roword, "&text" as lbl length=120, p.trtn,
           sum(a.usubjid ne ' ') as n
    from work.popall as p
         left join
         (select distinct usubjid from adam.adae
          where trtemfl = 'Y' and (&cond)) as a
         on p.usubjid = a.usubjid
    where p.saffl = 'Y'
    group by p.trtn;
  quit;
  data work.srl(keep=roword lbl trtn cell);
    set work.sr;
    length cell $30;
    bign = input(symget('n' || strip(put(trtn, 1.))), best12.);
    cell = strip(put(n, 4.)) || ' (' || strip(put(100 * n / bign, 5.1)) || '%)';
  run;
  proc append base=work.long_&sect data=work.srl force;
  run;
%mend subjrow;

/* Transpose a long dataset to one column per treatment: COL1-COL4 */
%macro widen(sect);
  proc sort data=work.long_&sect;
    by roword lbl trtn;
  run;
  proc transpose data=work.long_&sect out=work.w_&sect(drop=_name_) prefix=col;
    by roword lbl;
    id trtn;
    var cell;
  run;
%mend widen;

/* Print a wide table */
%macro rpt(ds=, t1=, t2=, foot=);
  title1 "&t1";
  title2 "&t2";
  footnote1 "&foot";
  footnote2 "Source: 04_tables.sas";
  proc report data=&ds nowd split='|';
    columns roword lbl col1 col2 col3 col4;
    define roword / order noprint;
    define lbl  / display ' ' style(column)={asis=on just=left cellwidth=3.6in};
    define col1 / display "Placebo|(N=&n1)"
                  style(column)={just=center cellwidth=1.2in} style(header)={just=center};
    define col2 / display "Xanomeline|Low Dose|(N=&n2)"
                  style(column)={just=center cellwidth=1.2in} style(header)={just=center};
    define col3 / display "Xanomeline|High Dose|(N=&n3)"
                  style(column)={just=center cellwidth=1.2in} style(header)={just=center};
    define col4 / display "Total|(N=&n4)"
                  style(column)={just=center cellwidth=1.2in} style(header)={just=center};
  run;
  title;
  footnote;
%mend rpt;

/* ---- 3. Table 1: analysis populations ---------------------------------------------- */
%init(t1);
%flagrow(sect=t1, ds=work.popall, cond=%str(ittfl='Y'),     text=Intent-to-treat population,           ord=1);
%flagrow(sect=t1, ds=work.popall, cond=%str(saffl='Y'),     text=Safety population,                    ord=2);
%flagrow(sect=t1, ds=work.popall, cond=%str(efffl='Y'),     text=Efficacy population,                  ord=3);
%flagrow(sect=t1, ds=work.popall, cond=%str(comp8fl='Y'),   text=Completers of Week 8,                 ord=4);
%flagrow(sect=t1, ds=work.popall, cond=%str(comp16fl='Y'),  text=Completers of Week 16,                ord=5);
%flagrow(sect=t1, ds=work.popall, cond=%str(comp24fl='Y'),  text=Completers of Week 24,                ord=6);
%widen(t1);

/* ---- 4. Table 2: baseline demographics and characteristics --------------------------- */
%init(t2);
%controws(sect=t2, ds=work.popall, var=age,      text=Age (years),                 dec=1, ord=10);
%hdr(sect=t2, ord=20, text=Age group);
%catrows(sect=t2, ds=work.popall, var=agegr1_c, ord=agegr1_o, ordbase=20);
%hdr(sect=t2, ord=30, text=Sex);
%catrows(sect=t2, ds=work.popall, var=sex_c,    ord=sex_o,    ordbase=30);
%hdr(sect=t2, ord=40, text=Race);
%catrows(sect=t2, ds=work.popall, var=race_c,   ord=race_o,   ordbase=40);
%hdr(sect=t2, ord=50, text=Ethnicity);
%catrows(sect=t2, ds=work.popall, var=ethnic_c, ord=ethnic_o, ordbase=50);
%controws(sect=t2, ds=work.popall, var=heightbl, text=Baseline height (cm),        dec=1, ord=60);
%controws(sect=t2, ds=work.popall, var=weightbl, text=Baseline weight (kg),        dec=1, ord=70);
%controws(sect=t2, ds=work.popall, var=bmibl,    text=Baseline BMI (kg/m^2),       dec=1, ord=80);
%hdr(sect=t2, ord=90, text=Baseline BMI group (kg/m^2));
%catrows(sect=t2, ds=work.popall, var=bmigr_c,  ord=bmigr_o,  ordbase=90);
%controws(sect=t2, ds=work.popall, var=educlvl,  text=Years of education,          dec=1, ord=100);
%controws(sect=t2, ds=work.popall, var=durdis,   text=Duration of disease (months), dec=1, ord=110);
%hdr(sect=t2, ord=120, text=Duration of disease group);
%catrows(sect=t2, ds=work.popall, var=durgr_c,  ord=durgr_o,  ordbase=120);
%controws(sect=t2, ds=work.popall, var=mmsetot,  text=MMSE total score,            dec=1, ord=130);
%widen(t2);

/* ---- 5. Table 3: disposition ----------------------------------------------------------- */
%init(t3);
%flagrow(sect=t3, ds=work.popall, cond=%str(dcreascd='Completed'), text=Completed the study,       ord=1);
%flagrow(sect=t3, ds=work.popall, cond=%str(disconfl='Y'),         text=Discontinued early,        ord=2);
%hdr(sect=t3, ord=3, text=Reason for early discontinuation);
%catrows(sect=t3, ds=work.popall(where=(disconfl='Y')), var=dcreascd, ord=dcord, ordbase=3);
%widen(t3);

/* ---- 6. Table 4: exposure --------------------------------------------------------------- */
%init(t4);
%controws(sect=t4, ds=work.popall, var=trtdur,  text=Duration of treatment (days),             dec=1, ord=10);
%controws(sect=t4, ds=work.popall, var=cumdose, text=Cumulative dose as planned (mg),          dec=0, ord=20);
%controws(sect=t4, ds=work.popall, var=avgdd,   text=Average daily dose as planned (mg/day),   dec=1, ord=30);
%widen(t4);

/* ---- 7. Table 5: overview of treatment-emergent adverse events ---------------------------- */
%init(t5);
%subjrow(sect=t5, cond=%str(1=1),                                   text=Any treatment-emergent AE,             ord=1);
%subjrow(sect=t5, cond=%str(aerel='POSSIBLE' or aerel='PROBABLE'),  text=Any AE possibly or probably related,   ord=2);
%subjrow(sect=t5, cond=%str(aesev='SEVERE'),                        text=Any severe AE,                         ord=3);
%subjrow(sect=t5, cond=%str(aeser='Y'),                             text=Any serious AE,                        ord=4);
%subjrow(sect=t5, cond=%str(aesdth='Y'),                            text=Any AE with fatal outcome,             ord=5);
%subjrow(sect=t5, cond=%str(cq01nam ne ' '),                        text=Any dermatologic AE,                   ord=6);
%flagrow(sect=t5, ds=work.popall, cond=%str(dsraefl='Y'),           text=Discontinued the study due to an AE,   ord=7);
%widen(t5);

/* ---- 8. Table 6: TEAEs by body system and preferred term ------------------------------------ */
proc sql;
  create table work.soc_n as
  select a.aebodsys as soc length=100,
         sum(p.trtn = 1) as c1, sum(p.trtn = 2) as c2, sum(p.trtn = 3) as c3,
         count(*) as ctot
  from adam.adae as a
       inner join work.pop as p
       on a.usubjid = p.usubjid
  where a.aoccsfl = 'Y' and p.saffl = 'Y'
  group by a.aebodsys;

  create table work.pt_n as
  select a.aebodsys as soc length=100, a.aedecod as pt length=100,
         sum(p.trtn = 1) as c1, sum(p.trtn = 2) as c2, sum(p.trtn = 3) as c3,
         count(*) as ctot
  from adam.adae as a
       inner join work.pop as p
       on a.usubjid = p.usubjid
  where a.aoccpfl = 'Y' and p.saffl = 'Y'
  group by a.aebodsys, a.aedecod;
quit;

/* Rank body systems by total subjects, most frequent first */
proc sort data=work.soc_n;
  by descending ctot soc;
run;

data work.soc_r;
  set work.soc_n;
  socrank = _n_;
run;

proc sort data=work.soc_r(keep=soc socrank) out=work.soc_key;
  by soc;
run;

proc sort data=work.pt_n;
  by soc;
run;

data work.pt_r;
  merge work.pt_n(in=in_pt)
        work.soc_key;
  by soc;
  if in_pt;
run;

data work.t6_all;
  length lbl $120 col4 $20;
  array c{3} c1-c3;
  array col{3} $20 col1-col3;
  set work.soc_r(in=in_soc)
      work.pt_r;

  if in_soc then do;
    level = 1;
    lbl   = soc;
  end;
  else do;
    level = 2;
    lbl   = '    ' || pt;
  end;

  do i = 1 to 3;
    col{i} = strip(put(c{i}, 4.)) || ' (' ||
             strip(put(100 * c{i} / symgetn('n' || strip(put(i, 1.))), 5.1)) || '%)';
  end;
  col4 = strip(put(ctot, 4.)) || ' (' || strip(put(100 * ctot / &n4, 5.1)) || '%)';
run;

proc sort data=work.t6_all;
  by socrank level descending ctot pt;
run;

data work.w_t6;
  set work.t6_all(keep=lbl col1-col4);
  roword = _n_;
run;

/* ---- 9. Write all tables to RTF and the Results tab ------------------------------------------ */
ods noproctitle;
ods rtf file="&root/output/04_tables.rtf" style=journal startpage=yes;

%rpt(ds=work.w_t1,
     t1=Table 1,
     t2=Analysis Populations,
     foot=N is the number of randomized subjects in the column. Completers are subjects who reached the Week 8 or 16 or 24 visit.);

%rpt(ds=work.w_t2,
     t1=Table 2,
     t2=Baseline Demographics and Characteristics - Intent-to-Treat Population,
     foot=Categorical rows show n and percent of the column N. BMI is body mass index. MMSE is the Mini-Mental State Examination.);

%rpt(ds=work.w_t3,
     t1=Table 3,
     t2=Subject Disposition - Intent-to-Treat Population,
     foot=Rows show n and percent of the column N.);

%rpt(ds=work.w_t4,
     t1=Table 4,
     t2=Treatment Exposure - Intent-to-Treat Population,
     foot=Duration is last dose date minus first dose date plus 1. Dose is as planned for the assigned treatment arm.);

%rpt(ds=work.w_t5,
     t1=Table 5,
     t2=Overview of Treatment-Emergent Adverse Events - Safety Population,
     foot=Subjects are counted once per row. Treatment-emergent means the event started on or after the first dose.);

%rpt(ds=work.w_t6,
     t1=Table 6,
     t2=Treatment-Emergent Adverse Events by Body System and Preferred Term - Safety Population,
     foot=Number and percent of subjects with at least one event in the body system or term. Sorted by total frequency.);

ods rtf close;
ods proctitle;

/* ---- 10. Cross-checks ---------------------------------------------------------------------------- */
title "Cross-check: events in ADTTE by arm (should equal 'Any dermatologic AE' in Table 5: 29 / 62 / 61)";
proc sql;
  select trtp, sum(cnsr = 0) as n_events
  from adam.adtte
  group by trtp;
quit;

title "Cross-check: subjects with any treatment-emergent AE by arm (Table 5: 65 / 77 / 76)";
proc sql;
  select trta, count(distinct usubjid) as n_subjects
  from adam.adae
  where trtemfl = 'Y'
  group by trta;
quit;

title;
footnote;

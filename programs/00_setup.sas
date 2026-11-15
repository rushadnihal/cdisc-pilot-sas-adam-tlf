/*******************************************************************************
Program : 00_setup.sas
Purpose : Set the project root path, assign libnames, read the SDTM SAS transport
          (.xpt) files into the SDTM library, and run basic checks.
Inputs  : &root/data/sdtm/*.xpt  (CDISCPilot01 SDTM, phuse-org/phuse-scripts)
Outputs : SDTM library (.sas7bdat copies in &root/data/sdtm), ADAM library (empty)
Author  : rushadnihal
Date    : 2026-11-15 (updated 2026-11-15: added MH and VS for ADSL baseline variables)
Notes   : The only hard-coded path in the project is the &root macro variable below.
*******************************************************************************/

%let root = /home/YOUR_USER_ID/cdisc_pilot;

libname sdtm "&root/data/sdtm";
libname adam "&root/data/adam";

/* Read each transport file and copy its dataset into the SDTM library */
%macro read_xpt(name);
  %if %sysfunc(fileexist(&root/data/sdtm/&name..xpt)) %then %do;
    libname xpt xport "&root/data/sdtm/&name..xpt" access=readonly;
    proc copy inlib=xpt outlib=sdtm memtype=data;
    run;
    libname xpt clear;
  %end;
  %else %put ERROR: [00_setup] Missing file &root/data/sdtm/&name..xpt;
%mend read_xpt;

%macro read_all;
  %local list i n name;
  %let list = dm ds ex ae sv se sc qs mh vs relrec ta te ti ts tv suppdm suppae suppds;
  %let n = %sysfunc(countw(&list));
  %do i = 1 %to &n;
    %let name = %scan(&list, &i);
    %read_xpt(&name);
  %end;
%mend read_all;

%read_all;

/* Check 1: datasets present, observation and variable counts */
title "SDTM library contents (expect 19 datasets)";
proc sql;
  select memname label="Dataset", nobs label="Observations", nvar label="Variables"
  from dictionary.tables
  where libname = "SDTM"
  order by memname;
quit;

/* Check 2: variable-level contents of every dataset */
title "PROC CONTENTS for all SDTM datasets";
proc contents data=sdtm._all_ varnum;
run;

title;

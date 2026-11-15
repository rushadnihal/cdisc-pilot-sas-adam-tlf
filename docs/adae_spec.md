# ADAE specification

Dataset: `ADAM.ADAE` | Program: `programs/02_adae.sas` | Structure: one record per adverse event | Key: `USUBJID`, `AESEQ`

Derived from SDTM `AE` and `ADAM.ADSL`. The rules come from the PHUSE `define.xml` for ADAE and were prototyped outside SAS and checked against the reference `adae.xpt`: all 55 variables matched for all 1,191 records, with the one rule difference noted below.

## Population

All AE records for subjects in ADSL: 1,191 records, 225 subjects (254 subjects in ADSL, 29 with no AE). Every AE subject is in ADSL.

## Variables

| Variable | Source / derivation |
|---|---|
| STUDYID, USUBJID | AE |
| SITEID, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX, SAFFL, TRTSDT, TRTEDT | ADSL, unchanged |
| TRTA, TRTAN | ADSL.TRT01A, ADSL.TRT01AN |
| ASTDT | AESTDTC as a SAS date. `YYYY-MM` is imputed to day 01. A year-only date (`YYYY`) is left missing |
| ASTDTF | `D` when the start day was imputed |
| ASTDY | If ASTDT >= TRTSDT, ASTDT - TRTSDT + 1; if ASTDT < TRTSDT, ASTDT - TRTSDT (no day 0) |
| AENDT | AEENDTC as a SAS date (all non-blank end dates are complete) |
| AENDY | Same rule as ASTDY, using AENDT |
| ADURN, ADURU | AENDT - ASTDT + 1 days, `DAY`; only when both dates are present and the start day was not imputed |
| AETERM, AELLT, AELLTCD, AEDECOD, AEPTCD, AEHLT, AEHLTCD, AEHLGT, AEHLGTCD, AEBODSYS, AESOC, AESOCCD, AESEV, AESER, AESCAN, AESCONG, AESDISAB, AESDTH, AESHOSP, AESLIFE, AESOD, AEREL, AEACN, AEOUT, AESEQ | AE, unchanged |
| TRTEMFL | `Y` if ASTDT is not missing and ASTDT >= TRTSDT; otherwise `N` |
| AOCCFL | Among TRTEMFL=`Y`, first record per subject by ASTDT then AESEQ |
| AOCCSFL | Among TRTEMFL=`Y`, first record per subject and AEBODSYS |
| AOCCPFL | Among TRTEMFL=`Y`, first record per subject, AEBODSYS and AEDECOD |
| AOCC02FL, AOCC03FL, AOCC04FL | Same as AOCCFL, AOCCSFL, AOCCPFL, among TRTEMFL=`Y` and AESER=`Y` |
| CQ01NAM | `DERMATOLOGIC EVENTS` if AEDECOD contains APPLICATION, DERMATITIS, ERYTHEMA or BLISTER, or AEBODSYS is SKIN AND SUBCUTANEOUS TISSUE DISORDERS and AEDECOD is not COLD SWEAT, HYPERHIDROSIS or ALOPECIA; otherwise blank |
| AOCC01FL | Among TRTEMFL=`Y` and CQ01NAM = `DERMATOLOGIC EVENTS`, first record per subject by ASTDT then AESEQ (this is the event used for time to first dermatologic event) |

## Decisions and differences from the define file

1. **Define typos.** The define text for AOCC01FL says "CQ01NAM=''" and the CQ01NAM text has the body system split as "SUBC UTANEOUS". Both are typos; the reference data follow the intended rules above.
2. **Duration with imputed start.** The define text says ADURN = AENDT - ASTDT + 1, but the reference leaves ADURN missing for the 4 events whose start day was imputed and that have an end date. This program does the same, so duration is never based on an imputed day.
3. **Year-only start dates.** 11 events have a year-only start date. ASTDT is missing, so they are not treatment emergent, matching the SDTM treatment-emergent flag (1,126 Y, 65 N).
4. **AEBDSYCD, AEDTC, AESPID, AESTDY, AEENDY, DOMAIN** are SDTM-only and not carried into ADAE.

## Expected results

- 1,191 records, 225 subjects, one record per USUBJID and AESEQ.
- TRTEMFL: Y 1,126, N 65. ASTDTF = D for 15; ASTDT missing for 11; ADURN present for 714 records.
- CQ01NAM = DERMATOLOGIC EVENTS for 493 records; AOCC01FL = Y for 152 records (152 subjects).
- Subjects with a treatment-emergent AE: Placebo 65, Low Dose 77, High Dose 76. Subjects with a dermatologic TEAE: Placebo 29, Low Dose 62, High Dose 61.
- PROC COMPARE against `data/adam_ref/adae.xpt` (`programs/91_qc_adae.sas`).

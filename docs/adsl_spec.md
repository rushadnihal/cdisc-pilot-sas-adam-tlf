# ADSL specification

Dataset: `ADAM.ADSL` | Program: `programs/01_adsl.sas` | Structure: one record per randomized subject | Key: `USUBJID`

Derivations were written from the SDTM data and the PHUSE `define.xml` for ADSL, then prototyped outside SAS and checked against the PHUSE reference `adsl.xpt` before the SAS program was written. Where the define file text and the reference data disagree, the reference data decide and the difference is listed under "Decisions".

## Population

Subjects with `DM.ARMCD ne 'Scrnfail'`: 254 subjects (Placebo 86, Xanomeline Low Dose 84, Xanomeline High Dose 84). The 52 screen failures are not in ADSL.

## Sources

| SDTM | Used for |
|---|---|
| DM | demographics, arm, reference dates, death flag |
| SV | visit dates (visits 1, 3, 4, 8, 10, 12) |
| EX | last dosing record |
| DS | disposition event (`DSCAT='DISPOSITION EVENT'`) |
| VS | baseline height (visit 1) and weight (visit 3) |
| MH | disease onset date (`MHCAT='PRIMARY DIAGNOSIS'`) |
| SC | years of education (`SCTESTCD='EDLEVEL'`) |
| QS | MMSE total; post-baseline ADAS-Cog and CIBIC+ records |

## Variables

| Variable | Label | Type | Derivation |
|---|---|---|---|
| STUDYID, USUBJID, SUBJID, SITEID | identifiers | Char | DM, unchanged |
| SITEGR1 | Pooled Site Group 1 | Char | `'900'` when any arm has fewer than 3 randomized subjects at the site; otherwise `SITEID` |
| ARM | Description of Planned Arm | Char | DM.ARM |
| TRT01P | Planned Treatment for Period 01 | Char | DM.ARM |
| TRT01PN | Planned Treatment (N) | Num | Placebo 0, Low Dose 54, High Dose 81 |
| TRT01A, TRT01AN | Actual Treatment (and N) | Char, Num | Equal to TRT01P, TRT01PN (see Decisions) |
| TRTSDT | Date of First Exposure | Num date | SV.SVSTDTC at VISITNUM 3 |
| TRTEDT | Date of Last Exposure | Num date | EXENDTC of the subject's last EX record (by EXSEQ); if missing, RFENDT |
| TRTDUR | Duration of Treatment (days) | Num | TRTEDT - TRTSDT + 1 |
| CUMDOSE | Cumulative Dose (as planned) | Num | Placebo and Low Dose: TRT01PN x TRTDUR. High Dose: 54 mg x days to visit 4 (inclusive), 81 mg x days from visit 4 to visit 12, 54 mg x days after visit 12; a subject who stopped earlier only accrues the intervals they reached |
| AVGDD | Avg Daily Dose (as planned) | Num | CUMDOSE / TRTDUR, rounded to 1 decimal |
| AGE, AGEU | Age, units | Num, Char | DM |
| AGEGR1, AGEGR1N | Pooled Age Group | Char, Num | <65 (1), 65-80 (2), >80 (3) |
| RACE | Race | Char | DM.RACE |
| RACEN | Race (N) | Num | White 1, Black or African American 2, Asian 3, American Indian or Alaska Native 6 |
| SEX, ETHNIC | | Char | DM |
| ITTFL | Intent-To-Treat Flag | Char | `Y` if ARMCD is not blank, otherwise `N` (all `Y` after the population restriction) |
| SAFFL | Safety Flag | Char | `Y` if ITTFL = `Y` and TRTSDT is not missing |
| EFFFL | Efficacy Flag | Char | `Y` if SAFFL = `Y` and the subject has at least one ADAS-Cog record and at least one CIBIC+ record with VISITNUM > 3 |
| COMP8FL, COMP16FL, COMP24FL | Completer flags | Char | `Y` if the subject has an SV record for visit 8 / 10 / 12 and RFENDT is on or after that visit date, otherwise `N` |
| DCDECOD | Standardized Disposition Term | Char | DS.DSDECOD |
| DCREASCD | Reason for Discontinuation | Char | Grouping of DSDECOD: Completed, Adverse Event, Death, Lack of Efficacy, Lost to Follow-up, Physician Decision, Sponsor Decision, Withdrew Consent; PROTOCOL VIOLATION splits into I/E Not Met (DSTERM = PROTOCOL ENTRY CRITERIA NOT MET) and Protocol Violation |
| DISCONFL | Discontinued Study | Char | `Y` if DCREASCD is not Completed, else blank |
| DSRAEFL | Discontinued due to AE | Char | `Y` if DCREASCD = Adverse Event, else blank |
| DTHFL | Subject Died | Char | DM.DTHFL |
| VISNUMEN | End of Treatment Visit | Num | DS VISITNUM of the disposition event; 13 becomes 12 |
| RFSTDTC, RFENDTC | reference dates | Char | DM, unchanged |
| RFENDT | Date of Discontinuation/Completion | Num date | RFENDTC as a SAS date |
| VISIT1DT | Date of Visit 1 | Num date | SV.SVSTDTC at VISITNUM 1 |
| HEIGHTBL | Baseline Height (cm) | Num | VS.VSSTRESN where VSTESTCD = HEIGHT, VISITNUM 1, rounded to 1 decimal |
| WEIGHTBL | Baseline Weight (kg) | Num | VS.VSSTRESN where VSTESTCD = WEIGHT, VISITNUM 3, rounded to 1 decimal |
| BMIBL | Baseline BMI (kg/m^2) | Num | WEIGHTBL / (HEIGHTBL/100)^2, rounded to 1 decimal |
| BMIBLGR1 | Pooled Baseline BMI Group | Char | <25, 25-<30, >=30; blank if BMIBL is missing |
| EDUCLVL | Years of Education | Num | SC.SCSTRESN where SCTESTCD = EDLEVEL |
| DISONSDT | Date of Onset of Disease | Num date | MH.MHSTDTC where MHCAT = PRIMARY DIAGNOSIS |
| DURDIS | Duration of Disease (months) | Num | (VISIT1DT - DISONSDT + 1) / 30.4375, rounded to 1 decimal |
| DURDSGR1 | Pooled Disease Duration Group | Char | <12, >=12 |
| MMSETOT | MMSE Total | Num | Sum of QS.QSSTRESN over the six MMSE items (category MINI-MENTAL STATE) |

## Decisions and known differences from the PHUSE reference

1. **Treatment for the 12 subjects.** DM has 12 subjects with ARM = Xanomeline High Dose but ACTARM = Xanomeline Low Dose, and their only EX record is 54 mg. As in the reference, TRT01A = TRT01P = ARM, so they are analysed as High Dose. This is documented in the README.
2. **One subject has no baseline weight.** `01-702-1082` has no weight at visit 3, so WEIGHTBL and BMIBL are missing. The reference leaves BMIBL missing but sets BMIBLGR1 to `<25`; here BMIBLGR1 is left blank. Expect one difference in BMIBLGR1 in PROC COMPARE.
3. **Define file text vs reference data.** The define comment for BMIBL writes the height conversion as `HEIGHTBL*100`, which is a typo (centimetres to metres is `/100`); the reference values are reproduced by the formula above. The comment for DURDIS says "number of months"; the reference values need the +1 day and 30.4375 days per month.
4. **Rounding.** SAS `ROUND(x, 0.1)` is used for height, weight, BMI, duration and average dose, as the reference appears to do.
5. **Numeric treatment code for placebo.** The reference stores 0 as a tiny floating-point value (5.4E-79); this program stores a true 0, so PROC COMPARE may flag TRT01PN and TRT01AN for placebo unless a tolerance is set.

## Checks to run

- 254 records, 254 distinct USUBJID, arms 86 / 84 / 84.
- SAFFL and ITTFL = Y for 254; EFFFL = Y for 234; COMP8FL / COMP16FL / COMP24FL = Y for 190 / 147 / 118; DISCONFL = Y for 144; DSRAEFL = Y for 92; DTHFL = Y for 3.
- No missing TRTSDT, TRTEDT, RFENDT, VISIT1DT or DISONSDT.
- PROC COMPARE against `data/adam_ref/adsl.xpt` (separate QC program, after ADSL is clean).

# ADTTE specification

Dataset: `ADAM.ADTTE` | Program: `programs/03_adtte.sas` | Structure: one record per subject (one parameter) | Key: `USUBJID`, `PARAMCD`

Derived from `ADAM.ADSL` and `ADAM.ADAE`. Prototyped outside SAS and checked against the PHUSE reference `adtte.xpt`: all variables matched for all 254 subjects.

## Parameter

`TTDE`: Time to First Dermatologic Event, measured in days from first dose.

## Variables

| Variable | Derivation |
|---|---|
| STUDYID, SITEID, USUBJID, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX, TRTSDT, TRTEDT, TRTDUR, SAFFL | ADSL, unchanged |
| TRTP, TRTA, TRTAN | ADSL.TRT01P, TRT01A, TRT01AN |
| PARAM, PARAMCD | `Time to First Dermatologic Event`, `TTDE` |
| STARTDT | Origin date = ADSL.TRTSDT (equal to the date in DM.RFSTDTC for all 254 subjects) |
| ADT | If the subject has an ADAE record with AOCC01FL = `Y`, that record's ASTDT; otherwise ADSL.RFENDT |
| CNSR | 0 if the subject has such an event, otherwise 1 |
| AVAL | ADT - STARTDT + 1 |
| EVNTDESC | `Dermatologic Event Occurred` if CNSR = 0, otherwise `Study Completion Date` |
| SRCDOM, SRCVAR, SRCSEQ | `ADAE`, `ASTDT`, AESEQ of the event record; or `ADSL`, `RFENDT`, missing for censored subjects |

## Decisions and differences from the reference

1. **Event.** The first treatment-emergent dermatologic adverse event (CQ01NAM = DERMATOLOGIC EVENTS, TRTEMFL = Y) per subject, as flagged by ADAE.AOCC01FL.
2. **Censoring.** Subjects with no such event are censored at the date of discontinuation or completion (RFENDT), the same as the reference. Subjects who stopped for another reason are therefore censored at their last date, not at last dose.
3. **EVNTDESC text.** The reference reads "Dematologic Event Occured" (two typos). This dataset uses the corrected text, so PROC COMPARE shows differences in EVNTDESC for the 152 event records and nothing else.
4. **Same-day events.** AVAL counts the first day as day 1, so an event on the first dose date has AVAL = 1. Minimum AVAL is 1 for events and for censored subjects.

## Expected results

- 254 records, 254 subjects.
- 152 events (CNSR = 0, source ADAE/ASTDT) and 102 censored (CNSR = 1, source ADSL/RFENDT).
- Events by arm: Placebo 29, Low Dose 62, High Dose 61.
- No missing AVAL, ADT or STARTDT.
- PROC COMPARE (`programs/92_qc_adtte.sas`): only EVNTDESC differs, for 152 records.

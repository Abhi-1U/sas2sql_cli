/* Choose the external input dataset or a source library such as sales._all_. */
proc contents data=work.orders
  out=work._s2s_contents(keep=libname memname name type length varnum format informat)
  noprint;
run;

proc sort data=work._s2s_contents;
  by libname memname varnum;
run;

/* FMTINFO is available in SAS 9.4M3 and later. */
data work._s2s_schema;
  length type $9 _category $16;
  set work._s2s_contents(rename=(type=_storage_type));
  if _storage_type = 2 then type = 'character';
  else do;
    type = 'numeric';
    if not missing(format) then _category = lowcase(fmtinfo(strip(format), 'cat'));
    if _category not in ('date', 'datetime', 'time') and not missing(informat) then
      _category = lowcase(fmtinfo(strip(informat), 'cat'));
    if _category in ('date', 'datetime', 'time') then type = _category;
  end;
  drop _storage_type _category;
run;

/* Change this path to the destination visible to your SAS session. */
filename s2scsv 'schema.csv' encoding='utf-8';
proc export data=work._s2s_schema outfile=s2scsv dbms=csv replace;
  putnames=yes;
run;
filename s2scsv clear;

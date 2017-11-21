/*Austin Griffith
/*11/7/2017
/*Hazard Modeling*/

/*web address of annoticks sample code*/
/*http://support.sas.com/kb/42/513.html*/

OPTIONS ls = 70 nodate nocenter;
OPTIONS missing = '';

/*file paths need to be updated according to current computer*/
%let Ppath = P:\SAS Hazard;
%let Cpath = Q:\Data-ReadOnly\COMP;
%let Dpath = Q:\Data-ReadOnly\CRSP;
%let Bpath = Q:\Data-ReadOnly\SurvivalAnalysis;

libname comp "&Cpath";
libname crsp "&Dpath";

/*--------------------------Funda--------------------------*/
/*variables for hazard model*/
%let f_var = QUICK WCAP ROTA
DEBT_TA O_SCORE SALES;
%let f_calc = CHE RECT LCT
ACT LCT
NI AT
LT AT
SALE AT
EBIT AT
AT LT ACT LCT NI PI DP;

/*data is on a yearly basis*/
/*pulls data from funda file*/
data funda;
set comp.funda (keep = indfmt datafmt popsrc fic consol datadate
GVKEY CUSIP DLC DLTT &f_calc);
where indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D' and fic = 'USA'
and consol = 'C';
CUSIP = substr(CUSIP,1,8);
YEAR = year(datadate);
if YEAR >= 1961 and YEAR <= 2016;
YEAR = YEAR + 1;

/*face value of firm debt*/
DLC = DLC*1000000;
DLTT = DLTT*1000000;
F = DLC + 0.5*DLTT;
if F = 0 then delete;
if nmiss(of F) then delete;
if nmiss(of AT) then delete;
if nmiss(of LCT) then delete;

/*values for comparison in hazard model*/
QUICK = (CHE + RECT)/LCT; /*quick ratio*/
WCAP = ACT/LCT; /*working capital ratio*/
ROTA = EBIT/AT; /*return on total assets*/
DEBT_TA = F/(AT*1000000); /*debt as a percentage of total assets*/
SALES = SALE/AT; /*sales/total assets*/

/*o-score variables and calculations*/
A2 = log(AT);
B2 = LT/AT;
C2 = (ACT - LCT)/AT;
D2 = LCT/ACT;
E2 = NI/AT;
F2 = (PI + DP)/LT;
if LT > AT then G2 = 1;
else G2 = 0;
/*H variable*/
if first.gvkey = 0 then do;
	if NI<0 then do;
	H2 = 1;
		end;
	else do;
	H2 = 0;
		end;
end;
else if first.gvkey = 1 then do;
	if (NI+lag(NI))<0 then do;
	H2 = 1;
		end;
	else do;
	H2 = 0;
		end;
end;
else do;
	H2 = 0;
end;
/*I variable*/
if first.gvkey = 0 then I2 = (NI - lag(NI))/(abs(NI) + abs(lag(NI)));
else I2 = 0;
O2 = -1.32 - 0.407*A2 + 6.03*B2 - 1.43*C2 + 0.0757*D2 - 2.37*E2 - 1.83*F2 - 1.72*G2 + 0.285*H2 - 0.521*I2;
O_SCORE = exp(O2)/(1 + exp(O2)); /*probability of default metric*/

/*removes obs for all division by zero and missing values*/
if nmiss(of &f_var) then delete;
keep GVKEY CUSIP YEAR F &f_var;
run;

/*--------------------------DSF--------------------------*/
/*data is initially on a daily basis*/
/*pulls data from dsf file*/
data dsf;
set crsp.dsf (keep = PERMNO CUSIP DATE PRC SHROUT RET);
SHROUT = SHROUT*1000;
YEAR = year(DATE);
format DATE mmddyy10.;
if YEAR >= 1961 and YEAR <= 2016;
E = ABS(PRC)*SHROUT; /*equity value*/
if nmiss(of E) then delete;
if E = 0 then delete;
drop SHROUT PRC;
run;

/*computes cumulative annual return and std deviation for each firm*/
/*assume 250 business days a year*/
proc sql NOPRINT;
create table dsf_sql as
select CUSIP, PERMNO, DATE, mean(E) as E, /*avg E gets average equity per firm per year*/
exp(sum(log(1+RET)))-1 as ANNRET,
std(RET)*sqrt(250) as SIGMAE,
YEAR + 1 as YEAR
from dsf
group by CUSIP, YEAR;
quit;

/*removes dsf file to save temporary work space*/
proc delete data = dsf;
run;

/*--------------------------Merge Funda and DSF--------------------------*/
/*sorts dsf for merging data sets*/
/*gets first value per year, removes duplicate years*/
/*collapses daily -----> annual*/
proc sort data = dsf_sql nodupkey;
by CUSIP YEAR;
run;

/*sorts funda for merging*/
proc sort data = funda;
by CUSIP YEAR;
run;

/*merges funda and dsf data by cusip and year*/
data funda_dsf;
merge funda(in = a) dsf_sql(in = b);
by CUSIP YEAR;
if a & b;
run;

/*--------------------------DD and PD Naive Method--------------------------*/
/*gets DD and PD values*/
/*uses naive method due to lower processor load with good accuracy*/
data funda_dsf;
set funda_dsf;
/*method 1, naive calculations*/
/*since T = 1, it doesn't show up in these equations*/
SIGMAD = 0.05 + 0.25*SIGMAE;
SIGMAV = (E*SIGMAE)/(E+F) + (F*SIGMAD)/(E+F);
DD = (log((E+F)/F) + (ANNRET - (SIGMAV*SIGMAV*0.5)))/SIGMAV;
PD = CDF("normal",-DD);
run;

/*--------------------------Bankruptcy--------------------------*/
/*imports bankruptcy csv data*/
proc import out = bank datafile = "&Bpath\BR1964_2014.csv"
dbms = csv
replace;
run;

/*gets year value for each date of bankruptcy*/
data bank;
set bank;
DATE = BANKRUPTCY_DT;
BK_YEAR = year(DATE);
drop BANKRUPTCY_DT DATE;
run;

/*--------------------------Merge Bankruptcy--------------------------*/
/*sorts funda_dsf and bankruptcy data for merge*/
proc sort data = funda_dsf;
by PERMNO;
run;

proc sort data = bank;
by PERMNO;
run;

/*merges data, matches bankruptcy with permno of firm*/
data main_data;
merge funda_dsf bank;
by PERMNO;
run;

/*matches bankruptcy year with proper year of firm*/
/*marks date of firm bankruptcy*/
/*removes obs where permno didn't match up*/
data main_data;
set main_data;
/*if nmiss(of E) then delete;*/
/*if nmiss(of F) then delete;*/
if YEAR = BK_YEAR then death = 1;
else death = 0;
if nmiss(of &f_var) then delete;
if nmiss(of DD) then delete;
drop RF;
run;

/*--------------------------In Sample--------------------------*/
/*opens up pdf file for output*/
ods pdf file = "&Ppath\Hazard_model_data.pdf";

/*sets up logistic variables for easy drop*/
%let log_var = &f_var DD PD;

/*gets data set for in-sampling*/
data main_in;
set main_data;
run;

/*sorts data by firm, year*/
proc sort data = main_in;
by permno year;
run;

/*logistic process for bankruptcy values*/
/*gets beta values for each variable*/
proc logistic data = main_in descending
outest = in_results;
title1 "In-Sample Logistics";
model death(event = '1') = &log_var;
run;

/*renames beta values, Bi, for each variable*/
/*will allow for merge while avoiding overlap in names*/
data in_results;
set in_results;
beta_quick = QUICK;
beta_wcap = WCAP;
beta_rota = ROTA;
beta_debt_ta = DEBT_TA;
beta_o_score = O_SCORE;
beta_sales = SALES;
beta_dd = DD;
beta_pd = PD;
drop &log_var;
run;

/*merges the beta values with variables*/
/*multiplies beta and variables for Bi*xi in hazard equation*/
/*finds hazard estimate using Bi*xi*/
data in_hazard;
if _n_ = 1 then set in_results;
set main_in;
sum_Bx = beta_quick*QUICK
+ beta_wcap*WCAP + beta_rota*ROTA
+ beta_debt_ta*DEBT_TA
+ beta_o_score*O_SCORE
+ beta_dd*DD + beta_pd*PD
+ beta_sales*SALES;

H_estimate = exp(sum_Bx)/(1 + exp(sum_Bx));
run;

/*ranks data into decile by estimated hazard*/
proc rank data = in_hazard
out = in_hazard_rank
groups = 10 descending;
var H_estimate;
ranks hazard; /*names rank variable*/
run;

/*gets bankruptcy values in each decile*/
data in_check;
set in_hazard_rank;
if death = 1;
run;

/*--------------------------In Sample Check Graph--------------------------*/
/*orders by rank for counting*/
proc sort data = in_check;
by hazard;
run;

/*gets check data for each year in check library*/
/*used to check how many bankruptcies per decile*/
proc means data = in_check N NOPRINT;
var death;
by hazard;
output out = in_check (drop = _TYPE_ _FREQ_) N=;
run;

/*normalizes bankruptcy data per decile*/
proc sql NOPRINT;
create table in_check as
select hazard, death/sum(death) as death
from in_check
quit;

/*annotations for bar graph of deciles*/
data annoticks;
length function color $ 8;
retain color 'black' when 'a' xsys '2';
set in_check;
by hazard;

if first.death then do;
function = 'move';
ysys = '1';
midpoint = hazard;
y = 0;
output;

function = 'draw';
ysys = 'a'; /* relative coordinate system */
midpoint = hazard;
y = -.75;
line = 1;
size = 1;
output;
end;
run;

/*generate the graph of bankruptcies in deciles*/
proc gchart data = in_check;
vbar hazard / sumvar = death discrete
width = 10 annotate = annoticks
maxis = axis1 raxis = axis2;
axis1 label = ('Hazard Decile');
axis2 label = (angle=90 'Bankruptcy');
title2 'Bankrupcties per Decile in In-sample, 1962 to 2014';
run;
quit;


/*--------------------------Out Sample--------------------------*/
/*sets title for out sample*/
title1 "Out-Sample Logistics";

/*gets data set for 62 to 90 for logistic data*/
data out_left;
set main_data;
if YEAR <= 1990;
run;

/*gets data set for 91 to 14 for out sample estimation*/
data out_right;
set main_data;
if YEAR >= 1991;
run;

/*sorts data by firm, year*/
proc sort data = out_left;
by permno year;
run;

proc sort data = out_right;
by permno year;
run;

/*logistic process for bankruptcy values*/
/*gets beta values for each variable*/
proc logistic data = out_left descending
outest = out_results;
title2 "Standard Out-Sample Logistics for 1962-1990";
model death(event = '1') = &log_var;
run;

/*renames beta values, Bi, for each variable*/
/*will allow for merge while avoiding overlap in names*/
data out_results;
set out_results;
beta_quick = QUICK;
beta_wcap = WCAP;
beta_rota = ROTA;
beta_debt_ta = DEBT_TA;
beta_o_score = O_SCORE;
beta_sales = SALES;
beta_dd = DD;
beta_pd = PD;
drop &log_var;
run;

/*merges the beta values with variables*/
/*multiplies beta and variables for Bi*xi in hazard equation*/
/*finds hazard estimate using Bi*xi*/
data out_hazard;
if _n_ = 1 then set out_results;
set out_right;
sum_Bx = beta_quick*QUICK
+ beta_wcap*WCAP + beta_rota*ROTA
+ beta_debt_ta*DEBT_TA
+ beta_o_score*O_SCORE
+ beta_dd*DD + beta_pd*PD
+ beta_sales*SALES;

H_estimate = exp(sum_Bx)/(1 + exp(sum_Bx));
run;

/*ranks data into decile by estimated hazard*/
proc rank data = out_hazard
out = out_hazard_rank
groups = 10 descending;
var H_estimate;
ranks hazard; /*names rank variable*/
run;

/*gets bankruptcy values in each decile*/
data out_check;
set out_hazard_rank;
if death = 1;
run;

/*orders by rank for counting*/
proc sort data = out_check;
by hazard;
run;

/*gets check data for each year in check library*/
/*used to check how many bankruptcies per decile*/
proc means data = out_check N NOPRINT;
var death;
by hazard;
output out = out_check (drop = _TYPE_ _FREQ_) N=;
run;


/*--------------------------Rolling--------------------------*/
/*macro that performs a rolling out sample*/
%macro out_rolling;
%do i = 0 %to 23;
/*gets range dates for rolling calculations*/
%let begin = %eval(1990 + &i);
%let end = %eval(1991 + &i);

/*gets rolling values of desired range of years*/
data rolling;
set main_data;
if YEAR <= &begin;
run;

/*gets year right after range*/
data estimate;
set main_data;
if YEAR = &end;
run;

/*logistic data of year range*/
proc logistic data = rolling descending
outest = roll_results NOPRINT;
model death(event = '1') = &log_var;
run;

/*renames beta values, Bi, for each variable*/
/*will allow for merge while avoiding overlap in names*/
data roll_results;
set roll_results;
beta_quick = QUICK;
beta_wcap = WCAP;
beta_rota = ROTA;
beta_debt_ta = DEBT_TA;
beta_o_score = O_SCORE;
beta_sales = SALES;
beta_dd = DD;
beta_pd = PD;
YEAR = &end;
drop &log_var;
run;

/*combines all the logistics results*/
data roll_results_final;
merge roll_results_final roll_results;
by YEAR;
run;

/*sorts by year for future merges*/
proc sort data = roll_results_final;
by YEAR;
run;

/*drops year variable*/
data roll_results;
set roll_results;
drop YEAR;
run;

/*merges the beta values with variables*/
/*multiplies beta and variables for Bi*xi in hazard equation*/
/*finds hazard estimate using Bi*xi*/
data roll_hazard;
if _n_ = 1 then set roll_results;
set estimate;
sum_Bx = beta_quick*QUICK
+ beta_wcap*WCAP + beta_rota*ROTA
+ beta_debt_ta*DEBT_TA
+ beta_o_score*O_SCORE
+ beta_dd*DD + beta_pd*PD
+ beta_sales*SALES;

H_estimate = exp(sum_Bx)/(1 + exp(sum_Bx));
run;

/*ranks data into decile by estimated hazard*/
proc rank data = roll_hazard
out = roll_hazard_rank
groups = 10 descending;
var H_estimate;
ranks hazard; /*names rank variable*/
run;

/*gets bankruptcy values in each decile*/
data roll_check;
set roll_hazard_rank;
if death = 1;
run;

/*orders by rank for counting*/
proc sort data = roll_check;
by hazard;
run;

/*gets check data for each year in check library*/
/*used to check how many bankruptcies per decile*/
proc means data = roll_check N NOPRINT;
var death;
by hazard;
output out = roll_check (drop = _TYPE_ _FREQ_) N=;
run;

/*adds year values for the decile check*/
data roll_check;
set roll_check;
YEAR = &end;
run;

/*merges check with total checks data set*/
data roll_check_final;
merge roll_check_final roll_check;
by YEAR;
run;

/*sorts total checks by year for future merges*/
proc sort data = roll_check_final;
by YEAR;
run;

/*adds year value for each variation of betas*/
/*used for merge*/
data roll_results;
set roll_results;
YEAR = &end;
run;

/*adds all beta results into a complete set*/
data roll_results_final;
merge roll_results_final roll_results;
by YEAR;
run;
%end;
%mend;


/*--------------------------Fixed Window--------------------------*/

%macro out_window;
%do i = 0 %to 23;
/*gets range dates for fixed window calculations*/
%let left = %eval(1962 + &i);
%let right = %eval(1990 + &i);
%let end = %eval(1991 + &i);

/*gets window values of desired range of years*/
data window;
set main_data;
if YEAR >= &left and YEAR <= &right;
run;

/*gets year right after range*/
data estimate;
set main_data;
if year = &end;
run;

/*logistic data of year range*/
proc logistic data = window descending
outest = win_results NOPRINT;
model death(event = '1') = &log_var;
run;

/*renames beta values, Bi, for each variable*/
/*will allow for merge while avoiding overlap in names*/
data win_results;
set win_results;
beta_quick = QUICK;
beta_wcap = WCAP;
beta_rota = ROTA;
beta_debt_ta = DEBT_TA;
beta_o_score = O_SCORE;
beta_sales = SALES;
beta_dd = DD;
beta_pd = PD;
YEAR = &end;
drop &log_var;
run;

/*combines all the logistics results*/
data win_results_final;
merge win_results_final win_results;
by YEAR;
run;

/*sorts by year for future merges*/
proc sort data = win_results_final;
by YEAR;
run;

/*drops year variable*/
data win_results;
set win_results;
drop YEAR;
run;

/*merges the beta values with variables*/
/*multiplies beta and variables for Bi*xi in hazard equation*/
/*finds hazard estimate using Bi*xi*/
data win_hazard;
if _n_ = 1 then set win_results;
set estimate;
sum_Bx = beta_quick*QUICK
+ beta_wcap*WCAP + beta_rota*ROTA
+ beta_debt_ta*DEBT_TA
+ beta_o_score*O_SCORE
+ beta_dd*DD + beta_pd*PD
+ beta_sales*SALES;

H_estimate = exp(sum_Bx)/(1 + exp(sum_Bx));
run;

/*ranks data into decile by estimated hazard*/
proc rank data = win_hazard
out = win_hazard_rank
groups = 10 descending;
var H_estimate;
ranks hazard; /*names rank variable*/
run;

/*gets bankruptcy values in each decile*/
data win_check;
set win_hazard_rank;
if death = 1;
run;

/*orders by rank for counting*/
proc sort data = win_check;
by hazard;
run;

/*gets check data for each year in check library*/
/*used to check how many bankruptcies per decile*/
proc means data = win_check N NOPRINT;
var death;
by hazard;
output out = win_check (drop = _TYPE_ _FREQ_) N=;
run;

/*adds year values for the decile check*/
data win_check;
set win_check;
YEAR = &end;
run;

/*merges check with total checks data set*/
data win_check_final;
merge win_check_final win_check;
by YEAR;
run;

/*sorts total checks by year for future merges*/
proc sort data = win_check_final;
by YEAR;
run;

/*adds year value for each variation of betas*/
/*used for merge*/
data win_results;
set win_results;
YEAR = &end;
run;

/*adds all beta results into a complete set*/
data win_results_final;
merge win_results_final win_results;
by YEAR;
run;
%end;
%mend;

/*--------------------------Out Beta--------------------------*/
/*gets the desired beta variables*/
%let beta_var = beta_quick
beta_wcap
beta_rota
beta_debt_ta
beta_o_score
beta_sales
beta_dd
beta_pd;

%let mdata_1 = win_results_final;
%let mdata_2 = roll_results_final;
%let mdata_3 = out_results;

/*macro gets mean values for each set of betas*/
%macro beta;
%do i = 1 %to 3;
proc means data = &&mdata_&i mean;
title2 "&&gname_&i Logistic Beta Values";
var &beta_var;
output out = &&mdata_&i mean=;
run;
%end;
%mend;

/*--------------------------Graph Checks--------------------------*/
/*gets variables for macros*/
%let gvar_1 = roll_check_final;
%let gvar_2 = win_check_final;
%let gvar_3 = out_check;

%let gname_1 = Rolling;
%let gname_2 = Fixed Window;
%let gname_3 = Standard;

/*macro to graph the 3 check values*/
%macro graph_check;

%do j = 1 %to 3;
/*normalizes bankruptcy data per decile*/
proc sql NOPRINT;
create table &&gvar_&j as
select hazard, death/sum(death) as death
from &&gvar_&j
quit;

/*sorts total check data for mean calculcations*/
proc sort data = &&gvar_&j;
by hazard YEAR;
run;

/*annotations for bar graph of deciles*/
data annoticks;
length function color $ 8;
retain color 'black' when 'a' xsys '2';
set &&gvar_&j;
by hazard;

if first.death then do;
function = 'move';
ysys = '1';
midpoint = hazard;
y = 0;
output;

function = 'draw';
ysys = 'a'; /* relative coordinate system */
midpoint = hazard;
y = -.75;
line = 1;
size = 1;
output;
end;
run;

/*generate the graph of bankruptcies in deciles*/
proc gchart data = &&gvar_&j;
vbar hazard / sumvar = death discrete
width = 10 annotate = annoticks
maxis = axis1 raxis = axis2;
axis1 label = ('Hazard Decile');
axis2 label = (angle=90 'Bankruptcy');
title2 "Bankruptcies per Decile in &&gname_&j Out-sample, 1991 to 2014";
run;
quit;
%end;
%mend;


/*runs macros*/
%out_rolling;
%out_window;
%beta;
%graph_check;

ods pdf close; /*closes roll sample pdf*/

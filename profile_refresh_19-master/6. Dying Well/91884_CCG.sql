/*  CCG and STP
    91884: Directly Age Standardised Rate of Mortality: People with Dementia Aged 65+
	Amend lines 69/88/231
*/

--- 1a. CCG Populations

/* Construct #populations legacy

if object_id('tempdb..#popgroup') is not null
    drop table #popgroup

select [period]
     ,c.stp as parentcode
     ,c.stp_name as parentnm
     ,a.[officialcode] as areacode
     ,a.[geoname] as areanm
      --,a.quinaryageband as age_band
	  ,[p6569] as '6569', [p7074] as '7074', [p7579] as '7579', [p8084] as '8084' , [p8589] as '8589' , [p90plus] as '90+'
  --    ,a.[population] as ni
into #popgroup
from populations..[vRes_CCG17_FiveYear] a 
inner join (select [ccg17cd],
                   [ccg17nm],
                   [ccg17cdh],
                   [stp17cd] as stp,
                   [stp17nm] as stp_name 
            from lookupsshared..vlkp_ccg17) c
    on a.[officialcode] = c.[ccg17cd]
where period in ('2011', '2012', '2013', '2014', '2015', '2016')

if object_id('tempdb..#population') is not null
    drop table #population

select * 
into #population
from (select * from #popgroup) a 
unpivot 
(
    ni 
    for age_band in ([6569],[7074],[7579],[8084],[8589],[90+])
) as b

drop table #popgroup

*/

--- 1a. CCG Populations

if object_id('tempdb..#population') is not null
    drop table #population

select period, 
    c.stp as parentcode, 
    c.stp_name as parentnm,
    a.officialcode as areacode, 
    a.geoname as areanm,
    replace(a.quinaryageband, '-', '') as age_band, 
    population as ni
into #population
from populations..[vRes_CCGapr18_FiveYear] a 
inner join (select [ccgapr18cd],
                   [ccgapr18nm],
                   [ccgapr18cdh],
                   [stpapr18cd] as stp,
                   [stpapr18nm] as stp_name 
            from lookupsshared..vlkp_ccgapr18) c
    on a.[officialcode] = c.[ccgapr18cd]
where period = '2017'
    and [Sex] = 4
    and replace(a.quinaryageband, '-', '') in ('6569', '7074', '7579', '8084', '8589', '90+')

--- 1b. CCG Deaths Data

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select year(xreg_date) as [year]
       ,b.ccgapr18cd as areacode
       ,[quinary90_dv] as age_band
       ,count(*) as oi
into #numerator
from birthsdeaths..[vDeathsALL_NSPL_2018-05] a
left join [lookupsshared]..[vlkp_lsoa11] b 
    on a.lsoa11_pc = b.lsoa11cd
left join hes_analysis_pseudo..din_zage_bands c 
    on a.xage_year = c.startage
where  year(xreg_date) = '2017'
  and xage_year >= '65'
  and left(lsoa11_pc,1) = 'e'
  and  (left (ucod, 3) in ('f00','f01','f02','f03','f04','g30','g31')
       or left (cod_1, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_2, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_3, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_4, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_5, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_6, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_7, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_8, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_9, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_10, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_11, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_12, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_13, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_14, 3) in ('f00','f01','f02','f03','f04','g30','g31')
	   or left (cod_15, 3) in ('f00','f01','f02','f03','f04','g30','g31'))
group by year(xreg_date), b.ccgapr18cd, quinary90_dv

--- Final Output (formatting)

if object_id('tempdb..#dsr_staging_2') is not null
    drop table #dsr_staging_2

create table #dsr_staging_2 (
    period varchar(4) , 
    areanm varchar(100), 
    areacode varchar(10), 
    o bigint, 
    n bigint, 
    dsr float, 
    [var(dsr)] float
)

--- 3. Calculate CCG-level DSR

if object_id('tempdb..#dsr_staging_1_ccg') is not null
    drop table #dsr_staging_1_ccg

select a.period, 
    a.areacode,
    a.areanm,
    a.age_band, 
    oi, 
    ni, 
    c.[population] as [wi], 
    ((cast(c.[population] as float)*cast(oi as float))/(cast(ni as float))) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*cast(oi as float))/(cast(ni as float)*cast(ni as float)) as [wiwioi/nini]
into #dsr_staging_1_ccg
from #population a
left join #numerator b 
    on a.period = b.[year] 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join [lookupsshared]..[vref_esp2013] c
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min

insert into #dsr_staging_2
select period,
    areanm,
    areacode,
    sum(oi) as o, 
    sum(ni) as n,
    100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr,
    sum([wiwioi/nini])/(sum(cast(wi as float))*sum(cast(wi as float))) as [var(dsr)]
from #dsr_staging_1_ccg
group by period, areanm, areacode

drop table #dsr_staging_1_ccg

--- 4. Calculate STP DSR

if object_id('tempdb..#dsr_staging_1_stp') is not null
    drop table #dsr_staging_1_stp

select a.period,
    parentnm as areanm, 
    parentcode as areacode, 
    a.age_band, 
    sum(oi) as oi, 
    sum(ni) as ni, 
    c.[population] as [wi], 
    ((cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float)))) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float))*sum(cast(ni as float))) as [wiwioi/nini]
into #dsr_staging_1_stp
from #population a
left join #numerator b 
    on a.period = b.[year] 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join [lookupsshared]..[vref_esp2013] c
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min
group by a.period, parentnm, parentcode, a.age_band, c.[population]

insert into #dsr_staging_2
select period,
    areanm, 
    areacode, 
    sum(oi) as o, 
    sum(ni) as n, 
    100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr, 
    sum([wiwioi/nini])/(sum(cast(wi as float))*sum(cast(wi as float))) as [var(dsr)]
from #dsr_staging_1_stp
group by period, areanm, areacode

drop table #dsr_staging_1_stp
--drop table #population
--drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p61_ccg_refresh') is not null
    drop table hes_analysis_pseudo..din_p61_ccg_refresh

select period as period 
    ,areanm
	,areacode
	,a.o as [count]
	,dsr
    ,lowerci = ((cast (dsr as float) /100000) + (sqrt(cast([var(dsr)]/o as float)) *
        ((case when o = '0' then '0'
                when o < '389' then cast(b.chiinvlower as float) 
	            else (cast(o as float) * power((1-1/(9*cast(o as float))-(1.95996398454005/3/sqrt(cast(o as float)))),3)) end) - cast(o as float))))*100000
    ,upperci = ((cast (dsr as float) /100000) + (sqrt(cast([var(dsr)] as float)/cast(o as float)) *
        ((case when o = '0' then '0'
                when o < '389' then cast(c.chiinvupper as float) 
                else ((cast(o as float)+1) * power((1-1/(9*(cast(o as float)+1))+(1.95996398454005/3/sqrt((cast(o as float)+1)))),3)) end) - cast(o as float))))*100000
    ,a.n as [denominator]
into hes_analysis_pseudo..din_p61_ccg_refresh
from #dsr_staging_2 a
left join [HES_Analysis_Pseudo].[dbo].[din_ChiInv] b
    on a.o * 2 = b.n
left join [HES_Analysis_Pseudo].[dbo].[din_ChiInv] c
    on (a.o * 2) + 2 = c.n
group by period, areanm, areacode, o, a.n, dsr, [var(dsr)], b.chiinvlower, c.chiinvupper
order by 1, 3

drop table #dsr_staging_2

select period, /*areanm, */ areacode, dsr, lowerci, upperci, count, denominator
from hes_analysis_pseudo..din_p61_ccg_refresh
where period = '2017'
order by areacode

--- Uncomment the section below and run with the above section to include England aggregates

--union all
--select 2017 period, 'England from CCGs' areanm, 'E92000001' areacode, NULL value, NULL lowerci, NULL upperci, sum(count) count_ccg, sum(denominator) denominator_ccg
--from hes_analysis_pseudo..din_p61_ccg_refresh
--where left(areacode, 3) = 'E38'
--    and period = 2017
--union all
--select 2017 period, 'England from STPs' areanm, 'E92000001' areacode, NULL value, NULL lowerci, NULL upperci, sum(count) count_stp, sum(denominator) denominator_stp
--from hes_analysis_pseudo..din_p61_ccg_refresh
--where left(areacode, 3) = 'E54'
--    and period = 2017
--order by areanm

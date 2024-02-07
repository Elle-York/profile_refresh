/*
    LA
    
    91884: Directly Age Standardised Rate of Mortality: People with dementia aged 65+
    See note on population by age tables used to provide output for 2016 onwards 
	Amend lines 37/59/290

*/


--- 1a. UTLA Populations

if object_id('tempdb..#population') is not null
    drop table #population

select [period]
    ,c.ctry09cd as england
    ,c.ctry09nm as englandnm
    ,c.rgn09cd as parentcode
    ,c.rgn09nm as parentnm
    ,a.[officialcode] as areacode
    ,c.utla13nm as areanm
    ,replace(quinaryageband, '-', '') as age_band
    ,sum(a.[population]) as ni
into #population
--from [phe_populations_v2].[dbo].[vutla11_2016_5yearagebandslist_90plus] a --- use single year tables after 2015
--from [phe_populations_v2].[dbo].[vutla11_2001-2015_5yearagebandslist_90plus] a  --- if pre 2016 use this
from [Populations]..[vRes_UTLA13_FiveYear] a
left join (select distinct ctry09cd, 
                           ctry09nm, 
                           utla13cd, 
                           utla13nm, 
                           rgn09cd, 
                           rgn09nm 
           from [lookupsshared].[dbo].[vlkp_lsoa11]) c 
    on a.officialcode = c.utla13cd
where  period in ('2017') -- toggle: amend date -- note: this approach does not work across pre-/post-2015 as 5 
                                                        --       year vs single year age bands used respectively
   and sex = '4' 
   and left(officialcode,1) = 'e'
   and convert (int, left(quinaryageband,2)) >= '65'
group by period, c.ctry09cd, c.ctry09nm, c.rgn09cd, c.rgn09nm, officialcode, utla13nm, quinaryageband

--- 1b. UTLA Deaths Data

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select year(xreg_date) as [year]
       ,b.utla13cd as areacode
       ,quinary90_dv as age_band
       ,count(*) as oi
into #numerator
from BirthsDeaths..[vDeathsALL_NSPL_2018-05] a
left join [lookupsshared].[dbo].[vlkp_lsoa11] b 
    on a.lsoa11_pc = b.lsoa11cd
left join hes_analysis_pseudo..din_zage_bands c 
on a.xage_year = c.startage
where  year(xreg_date) in ('2017') -- toggle: amend date
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
group by year(xreg_date), b.utla13cd, quinary90_dv

--- Final Output (formatting)

if object_id('tempdb..#dsr_staging_2') is not null
    drop table #dsr_staging_2

create table #dsr_staging_2 (
    period varchar(4),
    areanm varchar(100),
    areacode varchar(10),
    o bigint,
    n bigint,
    dsr float,
    [var(dsr)] float
)

--- 1c. Calculate LA DSR excluding Cornwall, Isles of Scilly, City of London and Hackney

if object_id('tempdb..#dsr_staging_1_la') is not null
    drop table #dsr_staging_1_la

select a.period
    ,a.areacode
    ,a.areanm
    ,a.age_band 
    ,oi
    ,ni 
    ,c.[population] as [wi] 
    ,((cast(c.[population] as float)*cast(oi as float))/(cast(ni as float))) as [wioi/ni]
    ,(cast(c.[population] as float)*cast(c.[population] as float)*cast(oi as float))/(cast(ni as float)*cast(ni as float)) as [wiwioi/nini]
into #dsr_staging_1_la
from #population a
left join #numerator b 
    on a.period = b.[year] 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join Lookupsshared..[vRef_ESP2013] c 
    on cast(substring(a.age_band,1,2) as float) = c.age_band_min
where a.areacode not in ('e06000052','e06000053','e09000001','e09000012') --this excludes cornwall, isles of scilly, city of london and hackney

insert into #dsr_staging_2
select period 
      ,areanm
      ,areacode 
      ,sum(oi) as o 
      ,sum(ni) as n 
      ,100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr 
      ,sum([wiwioi/nini])/(sum(cast(wi as float))*sum(cast(wi as float))) as [var(dsr)]
from #dsr_staging_1_la
group by period, areanm, areacode

drop table #dsr_staging_1_la

--- 1d. Calculate LA DSR for combined Cornwall and Isles of Scilly, City of London and Hackney

create table #combined_la_groups
    (utla13cd varchar(9) 
    ,utla13nm varchar(50)
    ,[group] varchar(1))

insert into #combined_la_groups
    values 
        ('e06000052','cornwall', '1'), 
        ('e06000053','isles of scilly', '1'), 
        ('e09000001','city of london', '2'), 
        ('e09000012','hackney', '2')

select a.period, 
    [group] as areacode, 
    a.age_band, 
    sum(oi) as oi, 
    sum(ni) as ni, 
    c.[population] as [wi], 
    ((cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float)))) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float))*sum(cast(ni as float))) as [wiwioi/nini]
into #dsr_staging_1_la_combined
from #population a
left join #numerator b 
    on a.period = b.[year] 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join Lookupsshared..[vRef_ESP2013] c 
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min
left join #combined_la_groups d 
    on a.areacode = d.utla13cd
where a.areacode in ('e06000052','e06000053','e09000001','e09000012') --this limits the data to cornwall, isles of scilly, city of london and hackney
group by a.period, [group], a.age_band, c.[population]

insert into #dsr_staging_2
select period, 
    b.utla13nm as areanm,
    b.utla13cd as areacode, 
    sum(oi) as o, 
    sum(ni) as n, 
    100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr, 
    sum([wiwioi/nini])/(sum(cast(wi as float))*sum(cast(wi as float))) as [var(dsr)]
from #dsr_staging_1_la_combined a
inner join #combined_la_groups b 
    on a.areacode = b.[group]
group by period, b.utla13nm, b.utla13cd

drop table #combined_la_groups
drop table #dsr_staging_1_la_combined

--- 1e. Calculate Region DSR

if object_id('tempdb..#dsr_staging_1_region') is not null
    drop table #dsr_staging_1_region

select a.period,
    parentnm as areanm, 
    parentcode as areacode, 
    a.age_band, 
    sum(oi) as oi, 
    sum(ni) as ni, 
    c.[population] as [wi], 
    ((cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float)))) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float))*sum(cast(ni as float))) as [wiwioi/nini]
into #dsr_staging_1_region
from #population a
left join #numerator b 
    on a.period = b.[year] 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join [LookupsShared].[dbo].[vRef_ESP2013] c 
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
from #dsr_staging_1_region
group by period, areanm, areacode

drop table #dsr_staging_1_region

--- 1f. Calculate England DSR

select a.period,
    englandnm as areanm,
    england as areacode, 
    a.age_band, 
    sum(oi) as oi, 
    sum(ni) as ni, 
    c.[population] as [wi], 
    ((cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float)))) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float))*sum(cast(ni as float))) as [wiwioi/nini]
into #dsr_staging_1_england
from #population a
left join  #numerator b 
    on a.period = b.[year] 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join [LookupsShared].[dbo].[vRef_ESP2013] c 
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min
group by period, englandnm, england, a.age_band, c.[population]

insert into #dsr_staging_2
select period,
    areanm, 
    areacode, 
    sum(oi) as o, 
    sum(ni) as n, 
    100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr, 
    sum([wiwioi/nini])/(sum(cast(wi as float))*sum(cast(wi as float))) as [var(dsr)]
from #dsr_staging_1_england
group by period, areanm, areacode

drop table #dsr_staging_1_england
--drop table #population
--drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p61_la_refresh') is not null
    drop table hes_analysis_pseudo..din_p61_la_refresh

select period, 
    areanm,
    areacode,
    a.o as [count],
    dsr,
    lowerci = ((cast (dsr as float) /100000) + (sqrt(cast([var(dsr)]/o as float)) *
    ((case when o = '0' then '0'
         when o < '389' then cast(b.chiinvlower as float) 
	     else (cast(o as float) * power((1-1/(9*cast(o as float))-(1.95996398454005/3/sqrt(cast(o as float)))),3)) end) - cast(o as float))
    ))*100000,
    upperci = ((cast (dsr as float) /100000) + (sqrt(cast([var(dsr)] as float)/cast(o as float)) *
    ((case when o = '0' then '0'
         when o < '389' then cast(c.chiinvupper as float) 
	     else ((cast(o as float)+1) * power((1-1/(9*(cast(o as float)+1))+(1.95996398454005/3/sqrt((cast(o as float)+1)))),3)) end) - cast(o as float))
    ))*100000,
     a.n as [denominator]
into hes_analysis_pseudo..din_p61_la_refresh
from #dsr_staging_2 a
left join hes_analysis_pseudo..din_chiinv b 
    on a.o * 2 = b.n
left join hes_analysis_pseudo..din_chiinv c 
    on (a.o * 2) + 2 = c.n
group by period, areanm, areacode, o, a.n, dsr, [var(dsr)], b.chiinvlower, c.chiinvupper
order by 1, 3

drop table #dsr_staging_2

select *
from hes_analysis_pseudo..din_p61_la_refresh
where period = '2017'
--union all
--select 2017 period, 'England from LA' areanm, 'E92000001' areacode, sum(count) count_la, NULL dsr, NULL lowerci, NULL upperci, sum(denominator) denominator_la
--from hes_analysis_pseudo..din_p61_la_refresh
--where left(areacode, 3) in ('E06', 'E07', 'E08', 'E09', 'E10')
--    and period = 2017
--union all
--select 2017 period, 'England from Region' areanm, 'E92000001' areacode, sum(count) count_region, NULL dsr, NULL lowerci, NULL upperci, sum(denominator) denominator_region
--from hes_analysis_pseudo..din_p61_la_refresh
--where left(areacode, 3) = 'E12'
--    and period = 2017
order by period, areacode

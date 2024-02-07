/* 
    Local authority
    91300: Ratio of Inpatient Service Use to Recorded Diagnoses

*/

DROP TABLE #staging
if object_id('tempdb..#la') is not null
    drop table #la

select fyear,
    utla13cd,
    [utla13nm], 
    [rgn09cd], 
    [rgn09nm],
    [ctry09cd], 
    [ctry09nm],
    count(distinct pseudo_hesid) as count
into #staging
from (  select a.fyear, 
            a.pseudo_hesid, 
            a.epikey, 
            c.utla13cd, 
            c.[utla13nm], 
            c.[rgn09cd], 
            c.[rgn09nm],
            c.[ctry09cd], 
            c.[ctry09nm],
            a.admidate_dv,
            row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
        from (  hes_apc..vhes_apc_sav a
                inner join (select distinct fyear, 
                                            epikey
                            from [hes_apc].[dbo].[vthes_apc_diag]
                            where fyear in ('1718') 
                                and left(diagcode4, 3) in ('f00','f01','f02','f03','f04','g30','g31')) b 
                    on a.epikey = b.epikey and a.fyear = b.fyear
                left join [lookupsshared].[dbo].[vlkp_lsoa11] c 
                    on a.lsoa11 = c.lsoa11cd
                left join lookupsshared..vref_agebands d 
                   on cast(a.startage as varchar(30)) = d.age)
		
                where a.fae = '1'
                    and a.classpat = '1'
                    and left(a.lsoa11,1) = 'e') a
where rownumber = '1'
group by fyear, utla13cd, [utla13nm], [rgn09cd], [rgn09nm], [ctry09cd], [ctry09nm]
order by fyear, utla13cd, [utla13nm], [rgn09cd], [rgn09nm], [ctry09cd], [ctry09nm]

--- Region Values

if object_id('tempdb..#region') is not null
    drop table #region

select fyear, [RGN09CD], [RGN09NM], sum([count]) [count]
into #region
from #staging
group by fyear, [RGN09CD], [RGN09NM]
order by 1, 2

--- England Value

if object_id('tempdb..#england') is not null
    drop table #england

select fyear, [CTRY09CD], [CTRY09NM], sum([count]) [count]
into #england
from #staging
group by fyear, [CTRY09CD], [CTRY09NM]
order by 1, 2

--- Results

if object_id('hes_analysis_pseudo..din_p51_la') is not null
    drop table hes_analysis_pseudo..din_p51_la

select fyear, utla13cd areacode, utla13nm areaname, [count]
into hes_analysis_pseudo..din_p51_la
from #staging
union all
select fyear, [RGN09CD] areacode, [RGN09NM] areaname, [count]
from #region
union all
select fyear, [CTRY09CD] areacode, [CTRY09NM] areaname, [count]
from #england
order by 1, 2

--- Display Results

select *
from hes_analysis_pseudo..din_p51_la
order by 1, 2

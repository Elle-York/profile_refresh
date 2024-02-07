/*
    Local Authority Level 
 91283: Alzheimer's Disease: DSR of Inpatient Admissions (Aged 65+)- Amend lines
 91284: Vascular Dementia: DSR of Inpatient Admissions (Aged 65+)
 91748: Unspecified Dementia: DSR of Inpatient Admissions (Aged 65+)
 Each year amend lines 41, 72 107, and 141
*/

--- 1a. UTLA Populations

if object_id('tempdb..#population') is not null
    drop table #population

select indicator,
    period,
    c.ctry09cd as england,
    c.ctry09nm as englandnm, 
    c.rgn09cd as parentcode,
    c.rgn09nm as parentnm,
    a.officialcode as areacode,
    c.utla13nm as areanm,
    replace(a.quinaryageband, '-', '') as age_band,
    sum(a.[population]) as ni
into #population
from populations..vres_utla13_fiveyear a
-- Previously used and alternative tables:
--[phe_populations_v2].[dbo].[vutla11_2016_5yearagebandslist_90plus] a -- toggle: amend date
--[dbo].[vUTLA11_2001-2015_5YearAgeBandsList_90plus] a -- specified as an alternative in legacy code
left join (
        select distinct ctry09cd, 
                        ctry09nm, 
                        utla13cd, 
                        utla13nm, 
                        rgn09cd, 
                        rgn09nm 
        from [lookupsshared].[dbo].[vlkp_lsoa11]) c 
    on a.officialcode = c.utla13cd,
(select '91283' as indicator 
 union select '91284' as indicator 
 union select '91748' as indicator) d
where  period in ('2017') -- toggle: amend date
   and sex = '4' 
   and left(officialcode, 1) = 'e'
   and convert(int, left(quinaryageband, 2)) >= 65
group by d.indicator, period, c.ctry09cd, c.ctry09nm, 
    c.rgn09cd, c.rgn09nm, officialcode, utla13nm, a.quinaryageband

--- 1b. UTLA Admissions

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select '91283' as indicator,
    fyear,
    utla13cd as areacode,
    quinary90_dv as age_band,
    count(distinct pseudo_hesid) as oi
into #numerator
from (
    select
        a.fyear, 
        a.pseudo_hesid, 
        a.epikey, 
        c.utla13cd, 
        a.admidate_dv,
        d.[quinary90_dv],
        row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
    from ([hes_apc].[dbo].[vhes_apc_sav] a
        inner join (select distinct fyear, 
                                    epikey
                    from [hes_apc].[dbo].[vthes_apc_diag]
                    where fyear in ('1718') 
                        and left(diagcode4, 3) in ('f00', 'g30')) b 
            on a.epikey = b.epikey -- toggle: amend date
        left join [lookupsshared].[dbo].[vlkp_lsoa11] c 
            on a.lsoa11 = c.lsoa11cd
        left join hes_analysis_pseudo..din_zage_bands d
        --left join [lookups].[dbo].[zage_bands] d 
            on a.startage = d.startage)
    where a.fae = '1'
        and a.classpat = '1'
        and (a.startage >= '65' and a.startage <= '120')
        and left(a.lsoa11,1) = 'e') a
where rownumber = '1'
group by fyear, utla13cd, quinary90_dv

union all

select '91284' as indicator,
    fyear,
    utla13cd as areacode,
    [quinary90_dv] as age_band,
    count(distinct pseudo_hesid) as oi
from (
    select
        a.fyear, 
        a.pseudo_hesid, 
        a.epikey, 
        c.utla13cd, 
        a.admidate_dv,
        d.[quinary90_dv],
        row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
    from ([hes_apc].[dbo].[vhes_apc_sav] a
        inner join (select distinct fyear, 
                                    epikey
                    from [hes_apc].[dbo].[vthes_apc_diag]
                    where fyear in ('1718') 
                        and left(diagcode4, 3) = 'f01') b 
            on a.epikey = b.epikey -- toggle: amend date
        left join [lookupsshared].[dbo].[vlkp_lsoa11] c 
            on a.lsoa11 = c.lsoa11cd
        left join hes_analysis_pseudo..din_zage_bands d
        --left join [lookups].[dbo].[zage_bands] d 
            on a.startage = d.startage)
    where a.fae = '1'
        and a.classpat = '1'
        and (a.startage >= '65' and a.startage <= '120')
        and left(a.lsoa11,1) = 'e') a
where rownumber = '1'
group by fyear, utla13cd, [quinary90_dv]

union all

select '91748' as indicator,
    fyear,
    utla13cd as areacode,
    quinary90_dv as age_band,
    count(distinct pseudo_hesid) as oi
from (
    select a.fyear, 
        a.pseudo_hesid, 
        a.epikey, 
        c.utla13cd, 
        a.admidate_dv,
        d.quinary90_dv,
        row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
    from ([hes_apc].[dbo].[vhes_apc_sav] a
    inner join (select distinct fyear, 
                                epikey
                from [hes_apc].[dbo].[vthes_apc_diag]
                where fyear in ('1718') 
                    and left(diagcode4, 3) = 'f03') b 
        on a.epikey = b.epikey -- toggle: amend date
    left join [lookupsshared].[dbo].[vlkp_lsoa11] c 
        on a.lsoa11 = c.lsoa11cd
    left join hes_analysis_pseudo..din_zage_bands d
    --left join [lookups].[dbo].[zage_bands] d 
        on a.startage = d.startage)
    where a.fae = '1'
        and a.classpat = '1'
        and (a.startage >= '65' and a.startage <= '120')
        and left(a.lsoa11,1) = 'e') a
where rownumber = '1'
group by fyear, utla13cd, quinary90_dv

--- Final Output (Important for formatting purposes)

if object_id('tempdb..#dsr_staging_2') is not null
    drop table #dsr_staging_2

create table #dsr_staging_2
(
    indicator int,
    period varchar(4),
    areanm varchar(100),
    areacode varchar(10),
    o bigint,
    n bigint,
    dsr float,
    [var(dsr)] float
)

--- 1c. Calculate LA DSR excluding Cornwall, Isles of Scilly, City of London and Hackney

if object_id('tempdb..#DSR_Staging_1_LA') is not null
    drop table #DSR_Staging_1_LA

select a.indicator,
    a.period, 
    a.areacode,
    a.areanm,
    a.age_band, 
    oi, 
    ni, 
    c.[population] as [wi], 
    (cast(c.population as float)*cast(oi as float)) / (cast(ni as float)) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*cast(oi as float)) / (cast(ni as float)*cast(ni as float)) as [wiwioi/nini]
into #DSR_Staging_1_LA
From #Population a
left join #Numerator b 
    on SUBSTRING(a.PERIOD, 3, 2) = SUBSTRING(b.FYEAR, 1, 2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode 
        and a.indicator = b.indicator
left join lookupsshared..vRef_ESP2013 c 
    on cast(substring(a.Age_Band, 1, 2) as float) = c.Age_Band_Min
where a.AreaCode not in ('E06000052','E06000053','E09000001','E09000012') --This excludes Cornwall, Isles of Scilly, City of London and Hackney

insert into #DSR_Staging_2
Select Indicator,
    Period, 
    AreaNM,
    AreaCode, 
    sum(Oi) as O, 
    sum(Ni) as N, 
    100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
    sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_LA
group by Indicator, Period, AreaNM, AreaCode

drop table #dsr_staging_1_la

--- 1d. Calculate LA DSR for combined Cornwall and Isles of Scilly, City of London and Hackney

create table #combined_la_groups
(
    utla13cd varchar(9), 
    utla13nm varchar(50),
    [group] varchar(1)
)

INSERT INTO #Combined_LA_Groups 
    Values 
        ('E06000052','Cornwall', '1'),
        ('E06000053','Isles of Scilly', '1'),
        ('E09000001','City of London', '2'),
        ('E09000012','Hackney', '2')

Select a.Indicator,
    a.period, 
    [group] as areacode, 
    a.age_band, 
    sum(oi) as oi, 
    sum(ni) as ni, 
    c.[population] as [wi], 
    ((cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float)))) as [wioi/ni],
    (cast(c.[population] as float)*cast(c.[population] as float)*sum(cast(oi as float)))/(sum(cast(ni as float))*sum(cast(ni as float))) as [wiwioi/nini]
into #DSR_Staging_1_LA_Combined
From #Population a
left join #Numerator b 
    on SUBSTRING(a.PERIOD, 3, 2) = SUBSTRING(b.FYEAR, 1, 2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode 
        and a.Indicator = b.Indicator
left join lookupsshared..vRef_ESP2013 c 
    on cast(substring(a.Age_Band, 1, 2) as float) = c.Age_Band_Min
left join #Combined_LA_Groups d 
    on a.AreaCode = d.UTLA13CD
where a.AreaCode in ('E06000052','E06000053','E09000001','E09000012') --This limits the data to Cornwall, Isles of Scilly, City of London and Hackney
group by a.Indicator, a.Period, [Group], a.age_band, c.[Population]

insert into #DSR_Staging_2
Select a.Indicator,
    Period, 
    b.UTLA13NM as AreaNM,
    b.UTLA13CD as AreaCode, 
    sum(Oi) as O, 
    sum(Ni) as N, 
    100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
    sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_LA_Combined a
inner join #Combined_LA_Groups b 
    on a.AreaCode = b.[Group]
group by a.Indicator, Period, b.UTLA13NM, b.UTLA13CD

drop table #combined_la_groups, #dsr_staging_1_la_combined

--- 1e. Calculate Region DSR

Select
    a.Indicator,
    a.Period,
    ParentNM as AreaNM, 
    ParentCode as AreaCode, 
    a.age_band, 
    sum(Oi) as Oi, 
    sum(Ni) as Ni, 
    c.[Population] as [Wi], 
    (cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float))) as [WiOi/Ni],
    (cast(c.[Population] as float)*cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float))*sum(cast(Ni as float))) as [WiWiOi/NiNi]
into #DSR_Staging_1_REGION
From #Population a
left join #Numerator b 
    on SUBSTRING(a.PERIOD, 3, 2) = SUBSTRING(b.FYEAR, 1, 2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode 
        and a.Indicator = b.Indicator
left join lookupsshared..vRef_ESP2013 c 
    on cast(substring(a.Age_Band, 1, 2) as float) = c.Age_Band_Min
group by a.Indicator, a.Period, ParentNM, ParentCode, a.age_band, c.[Population]

insert into #dsr_staging_2
select 
    indicator,
    period,
    areanm, 
    areacode, 
    sum(oi) as o, 
    sum(ni) as n, 
    100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr, 
    sum([wiwioi/nini])/(sum(cast(wi as float))*sum(cast(wi as float))) as [var(dsr)]
from #dsr_staging_1_region
group by indicator, period, areanm, areacode

drop table #dsr_staging_1_region

--- 1f. Calculate England DSR 

Select a.Indicator,
    a.Period,
    EnglandNM as AreaNM,
    England as AreaCode, 
    a.age_band, 
    sum(Oi) as Oi, 
    sum(Ni) as 
    Ni, 
    c.[Population] as [Wi], 
    ((cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float)))) as [WiOi/Ni],
    (cast(c.[Population] as float)*cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float))*sum(cast(Ni as float))) as [WiWiOi/NiNi]
into #DSR_Staging_1_ENGLAND
From #Population a
left join  #Numerator b 
    on SUBSTRING(a.PERIOD, 3, 2) = SUBSTRING(b.FYEAR, 1, 2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode 
        and a.Indicator = b.Indicator
left join lookupsshared..vRef_ESP2013 c 
    on cast(substring(a.Age_Band, 1, 2) as float) = c.Age_Band_Min
group by a.Indicator, Period, EnglandNM, England, a.age_band, c.[Population]

insert into #DSR_Staging_2
Select Indicator,
    Period,
    AreaNM, 
    AreaCode, 
    sum(Oi) as O, 
    sum(Ni) as N, 
    100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
    sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_ENGLAND
group by Indicator,Period, AreaNM, AreaCode

drop table #DSR_Staging_1_ENGLAND
--drop table #Population
--drop table #Numerator

--- Results

if object_id('hes_analysis_pseudo..din_p54_la') is not null
    drop table hes_analysis_pseudo..din_p54_la

Select Indicator,
    Period, 
    AreaNM,
    AreaCode,
    a.O as [Count],
    DSR,
    LowerCI = ((cast(DSR as float) /100000) + (SQRT(cast([Var(DSR)]/O as float)) * ((case 
                                                                                when O = '0' then '0'
                                                                                when O < '389' then cast(b.CHIINVLOWER as float)
                                                                                else (cast(O as float) * POWER((1-1/(9*cast(O as float))-(1.95996398454005/3/SQRT(cast(O as float)))),3)) 
                                                                            end) - cast(O as float))))*100000,
    UpperCI = ((cast(DSR as float)/100000) + (SQRT(cast([Var(DSR)] as float)/cast(O as float)) * ((case 
                                                                                                        when O = '0' then '0'
                                                                                                        when O < '389' then cast(c.CHIINVUPPER as float)
                                                                                                        else ((cast(O as float)+1) * POWER((1-1/(9*(cast(O as float)+1))+(1.95996398454005/3/SQRT((cast(O as float)+1)))),3)) 
                                                                                                    end) - cast(O as float))))*100000,
    a.N as [Denominator]
into hes_analysis_pseudo..din_p54_la
FROM #DSR_Staging_2 a
left join hes_analysis_pseudo..din_chiinv b -- missing chi inverse probability lookup table
    on a.O * 2 = b.n
left join hes_analysis_pseudo..din_chiinv c -- missing chi inverse probability lookup table
    on (a.O * 2) + 2 = c.n
group by Indicator, Period, AreaNM, AreaCode, O, a.N, DSR, [Var(DSR)], b.CHIINVLOWER, c.CHIINVUPPER
order by 1,3

drop table #DSR_Staging_2

select *
from hes_analysis_pseudo..din_p54_la
order by period, areacode, indicator

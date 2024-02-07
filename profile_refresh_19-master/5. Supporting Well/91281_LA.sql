/* LA Level 91281: DSR of Emergency Admissions (with mention of dementia) */
-- Change date in Lines 30, 50 and 58
--drop table #DSR_Staging_1_ENGLAND -- If this is an issue just remove two dashes at beginning and re-run code.

--- 1a. Prepare a table of all the UTLA populations


if object_id('tempdb..#population') is not null
    drop table #population

SELECT [Period],
    c.CTRY09CD as England,
    c.CTRY09NM as EnglandNM, 
    c.RGN09CD as ParentCode,
    c.RGN09NM as ParentNM,
    a.[OfficialCode] as AreaCode,
    c.UTLA13NM as AreaNM,
    replace(a.QuinaryAgeBand, '-', '') as Age_Band,
    sum(a.[Population]) as Ni
into #Population
FROM populations..vRes_UTLA13_FiveYear a
left join (SELECT distinct CTRY09CD, 
                           CTRY09NM, 
                           UTLA13CD, 
                           UTLA13NM, 
                           RGN09CD, 
                           RGN09NM 
           FROM [LookupsShared].[dbo].[vLKP_LSOA11]) c 
    on a.OfficialCode = c.UTLA13CD
where Period in ('2017') -- toggle: amend date
   and sex = '4' 
   and left(OfficialCode,1) = 'e'
   and convert (int, left(QuinaryAgeBand,2)) >= '65'
group by [Period], c.CTRY09CD, c.CTRY09NM, c.RGN09CD, c.RGN09NM, [OfficialCode], UTLA13NM, a.QuinaryAgeBand

--- 1b. Prepare a table of all the UTLA admissions data

if object_id('tempdb..#numerator') is not null
    drop table #numerator

SELECT a.FYEAR,
    c.UTLA13CD as AreaCode,
    d.Quinary90 as Age_Band,
    count(a.epikey) as Oi
into #Numerator
FROM [HES_APC].[dbo].[vHES_APC_SAV] a
inner join (Select distinct FYEAR, 
                            epikey 
            from [HES_APC].[dbo].[vtHES_APC_DIAG] 
            where FYEAR in ('1718') -- toggle: amend date
                and left(DiagCode4,3) in ('F00','F01','F02','F03','F04','G30','G31')) b 
    on a.FYEAR = b.FYEAR 
        and a.epikey = b.epikey
left join [LookupsShared].[dbo].[vLKP_LSOA11] c 
    on a.LSOA11 = c.LSOA11CD
left join [LookupsShared].[dbo].[vRef_AgeBands] d 
    on cast(a.STARTAGE as varchar(30)) = d.age
where a.FYEAR in ('1718') -- toggle: amend date
    and left(lsoa11,1) = 'e'
    and fae = '1' 
    and classpat = '1' 
    and admimeth like '2_'
    and a.startage >= 65 
    and a.startage <= 120
group by a.FYEAR, c.UTLA13CD, d.[Quinary90]

--- 1c. Calculate LA DSR excluding Cornwall, Isles of Scilly, City of London and Hackney

if object_id('tempdb..#dsr_staging_1_la') is not null
    drop table #dsr_staging_1_la

Select a.Period, 
    a.AreaCode,
    a.AreaNM,
    a.age_band, 
    Oi, 
    Ni, 
    c.[Population] as [Wi], 
    ((cast(c.[Population] as float)*cast(Oi as float))/(cast(Ni as float))) as [WiOi/Ni],
    (cast(c.[Population] as float)*cast(c.[Population] as float)*cast(Oi as float))/(cast(Ni as float)*cast(Ni as float)) as [WiWiOi/NiNi]
into #DSR_Staging_1_LA
From #Population a
left join #Numerator b 
    on SUBSTRING(a.PERIOD,3,2) = SUBSTRING(b.FYEAR,1,2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode
left join [LookupsShared].[dbo].[vRef_ESP2013] c 
    on cast(substring(a.Age_Band,1,2) as float) = c.Age_band_min
where a.AreaCode not in ('E06000052','E06000053','E09000001','E09000012') -- This excludes Cornwall, Isles of Scilly, City of London and Hackney

if object_id('tempdb..#DSR_Staging_2') is not null
    drop table #DSR_Staging_2

Select Period, 
AreaNM,
AreaCode, 
sum(Oi) as O, 
sum(Ni) as N, 
100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
into #DSR_Staging_2
from #DSR_Staging_1_LA
group by Period, AreaNM, AreaCode

Drop table #DSR_Staging_1_LA

--- 1d. Calculate LA DSR for combined Cornwall and Isles of Scilly, City of London and Hackney

Create Table #Combined_LA_Groups (
    UTLA13CD Varchar(9), 
    UTLA13NM varchar(50),
    [Group] varchar(1)
)

INSERT INTO #Combined_LA_Groups
Values ('E06000052','Cornwall', '1'),
    ('E06000053','Isles of Scilly', '1'),
    ('E09000001','City of London', '2'),
    ('E09000012','Hackney', '2')

Select a.Period, 
[Group] as AreaCode, 
a.age_band, 
sum(Oi) as Oi, 
sum(Ni) as Ni, 
c.[Population] as [Wi], 
((cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float)))) as [WiOi/Ni],
(cast(c.[Population] as float)*cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float))*sum(cast(Ni as float))) as [WiWiOi/NiNi]
into #DSR_Staging_1_LA_Combined
From #Population a
left join #Numerator b 
    on SUBSTRING(a.PERIOD,3,2) = SUBSTRING(b.FYEAR,1,2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode
left join [LookupsShared]..[vRef_ESP2013] c 
    on cast(substring(a.Age_Band,1,2) as float) = c.Age_band_min
left join #Combined_LA_Groups d 
    on a.AreaCode = d.UTLA13CD
where a.AreaCode in ('E06000052','E06000053','E09000001','E09000012') --This limits the data to Cornwall, Isles of Scilly, City of London and Hackney
group by a.Period, [Group], a.age_band, c.[Population]

insert into #DSR_Staging_2
Select Period, 
b.UTLA13NM as AreaNM,
b.UTLA13CD as AreaCode, 
sum(Oi) as O, 
sum(Ni) as N, 
100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_LA_Combined a
inner join #Combined_LA_Groups b on a.AreaCode = b.[Group]
group by Period, b.UTLA13NM, b.UTLA13CD

Drop table #Combined_LA_Groups
Drop table #DSR_Staging_1_LA_Combined

--- 1e. Calculate REGION DSR

Select a.Period,
ParentNM as AreaNM, 
ParentCode as AreaCode, 
a.age_band, 
sum(Oi) as Oi, 
sum(Ni) as Ni, 
c.[Population] as [Wi], 
((cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float)))) as [WiOi/Ni],
(cast(c.[Population] as float)*cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float))*sum(cast(Ni as float))) as [WiWiOi/NiNi]
into #DSR_Staging_1_REGION
From #Population a
left join #Numerator b 
    on SUBSTRING(a.PERIOD,3,2) = SUBSTRING(b.FYEAR,1,2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode
left join [LookupsShared].[dbo].[vRef_ESP2013] c 
    on cast(substring(a.Age_Band,1,2) as float) = c.Age_band_min
group by a.Period, ParentNM, ParentCode, a.age_band, c.[Population]

insert into #DSR_Staging_2
Select Period,
AreaNM, 
AreaCode, 
sum(Oi) as O, 
sum(Ni) as N, 
100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_REGION
group by Period, AreaNM,
 AreaCode

Drop table #DSR_Staging_1_REGION

--- 1f. Calculate ENGLAND DSR

Select a.Period,
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
    on SUBSTRING(a.PERIOD,3,2) = SUBSTRING(b.FYEAR,1,2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode
left join [LookupsShared].[dbo].[vRef_ESP2013] c 
    on cast(substring(a.Age_Band,1,2) as float) = c.Age_band_min
group by Period, EnglandNM, England, a.age_band, c.[Population]

insert into #DSR_Staging_2
Select Period,
AreaNM, 
AreaCode, 
sum(Oi) as O, 
sum(Ni) as N, 
100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_ENGLAND
group by Period, AreaNM, AreaCode

--drop table #DSR_Staging_1_ENGLAND
--drop table #Population
--drop table #Numerator

--- Print results

if object_id('hes_analysis_pseudo..din_p52_la') is not null
    drop table hes_analysis_pseudo..din_p52_la

Select Period, 
       AreaNM,
	   AreaCode,
	   a.O as [Count],
	   DSR,
((cast(DSR as float)/100000) + (SQRT(cast([Var(DSR)]/O as float)) *
((case when O = '0' then '0'
     when O < '389' then cast(b.CHIINVLOWER as float) 
	 else (cast(O as float) * POWER((1-1/(9*cast(O as float))-(1.95996398454005/3/SQRT(cast(O as float)))),3)) end) - cast(O as float))
))*100000 as LowerCI,
((cast (DSR as float) /100000) + (SQRT(cast([Var(DSR)] as float)/cast(O as float)) *
((case when O = '0' then '0'
     when O < '389' then cast(c.CHIINVUPPER as float) 
	 else ((cast(O as float)+1) * POWER((1-1/(9*(cast(O as float)+1))+(1.95996398454005/3/SQRT((cast(O as float)+1)))),3)) end) - cast(O as float))
))*100000 as UpperCI,
a.N as [Denominator]
into hes_analysis_pseudo..din_p52_la
FROM #DSR_Staging_2 a
left join hes_analysis_pseudo.dbo.din_ChiInv b 
    on a.O * 2 = b.n
left join hes_analysis_pseudo.dbo.din_ChiInv c 
    on (a.O * 2) + 2 = c.n
group by Period, AreaNM, AreaCode, O, a.N, DSR, [Var(DSR)], b.CHIINVLOWER, c.CHIINVUPPER
order by 1, 3

--drop table #DSR_Staging_2 

select *
from hes_analysis_pseudo..din_p52_la
order by AreaCode

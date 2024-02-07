/*
    CCG and STP
    91283 (93307): Alzheimer's Disease: DSR of Inpatient Admissions (Aged 65+) 
    91284 (93308): Vascular Dementia: DSR of Inpatient Admissions (Aged 65+)
    91748 (93309): Unspecified Dementia: DSR of Inpatient Admissions (Aged 65+)
*/

--- 1. CCG Populations

if object_id('tempdb..#ccg_lkp') is not null
    drop table #ccg_lkp

select distinct [ccgapr18cd] ccg_geog_code, 
                [ccgapr18nm] ccg_name, 
                [ccgapr18cdh] as ccg_code, 
                [stpapr18cd] as stp, 
                [stpapr18nm] as stp_name 
into #ccg_lkp
from [lookupsshared].[dbo].[vlkp_ccgapr18]

if object_id('tempdb..#population') is not null
    drop table #population

SELECT Indicator  
    ,b.Period
    ,c.STP as ParentCode
    ,c.STP_Name as ParentNM
    ,c.ccg_geog_code as AreaCode
    ,c.ccg_name as AreaNM
    ,b.quinary90 as Age_band
    ,sum(convert(int, b.[Population])) as Ni
into #Population
FROM hes_analysis_pseudo..din_ccg_reg_popns b
inner join #ccg_lkp c 
    --on  b.ccg_code = c.ccg_code
    on (case 
            when b.officialcodeold in ('00F','00G','00H') then '13T' 
            when b.officialcodeold in ('00W','01M','01N') then '14L' 
            when b.officialcodeold in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
            when b.officialcodeold in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
            when b.officialcodeold in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
            when b.officialcodeold in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
            when b.officialcodeold in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
            when b.officialcodeold in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
            else b.officialcodeold
        end) = c.CCG_CODE,
(   Select '91283' as Indicator 
    UNION 
    Select '91284' as Indicator 
    UNION
    Select '91748' as Indicator) d
where convert(int, left(b.quinary90, 2)) >= 65		
    and b.period in ('2017') -- toggle: amend date
group by Indicator, period, c.STP, c.STP_Name, c.ccg_geog_code, c.ccg_name, b.quinary90

--- 2. CCG Admissions

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select '91283' as indicator 
    ,fyear
    ,ccg_geog_code as areacode
    ,[quinary90_dv] as age_band
    ,count(distinct pseudo_hesid) as oi
into #numerator
from (select a.fyear,
    a.pseudo_hesid, 
    a.epikey, 
    c.ccg_geog_code, 
    a.admidate_dv,
    d.[quinary90_dv],
    row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
from ([hes_apc].[dbo].[vhes_apc_sav] a
    inner join (select distinct fyear, 
                                epikey
                from [hes_apc].[dbo].[vthes_apc_diag]
                where fyear in ('1718') -- toggle: amend date
                    and left(diagcode4, 3) in ('f00', 'g30')) b 
        on a.epikey = b.epikey
    inner join #ccg_lkp c 
        --on  ccg_responsibility = c.ccg_code
        on (case 
                when ccg_responsibility in ('00f', '00g', '00h') then '13t' 
                when ccg_responsibility in ('00w', '01m', '01n') then '14l' 
                when ccg_responsibility in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
                when ccg_responsibility in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
                when ccg_responsibility in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
                when ccg_responsibility in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
                when ccg_responsibility in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
                when ccg_responsibility in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
                else ccg_responsibility 
            end) = c.ccg_code
    left join hes_analysis_pseudo..din_zage_bands d 
        on a.startage = d.startage)
    where a.fae = '1'
        and a.classpat = '1'
        and a.startage >= 65 and a.startage <= 120
        and left(a.lsoa11 , 1) = 'E') a
where rownumber = '1'
group by fyear, ccg_geog_code, quinary90_dv

union all

select '91284' as indicator 
      ,fyear
      ,ccg_geog_code as areacode
      ,[quinary90_dv] as age_band
      ,count(distinct pseudo_hesid) as oi
from (select a.fyear,
    a.pseudo_hesid, 
    a.epikey, 
    c.ccg_geog_code, 
    a.admidate_dv,
    d.[quinary90_dv],
    row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
    from ([hes_apc].[dbo].[vhes_apc_sav] a
    inner join (select distinct fyear, 
                                epikey 
                from [hes_apc].[dbo].[vthes_apc_diag]
                where fyear in ('1718') -- toggle: amend date
                    and left(diagcode4, 3) in ('f01')) b 
        on a.epikey = b.epikey
    inner join #ccg_lkp c 
    --on  ccg_responsibility = c.ccg_code
        on (case 
                when ccg_responsibility in ('00f', '00g', '00h') then '13t' 
                when ccg_responsibility in ('00w', '01m', '01n') then '14l' 
                when ccg_responsibility in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
                when ccg_responsibility in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
                when ccg_responsibility in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
                when ccg_responsibility in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
                when ccg_responsibility in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
                when ccg_responsibility in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
                else ccg_responsibility 
            end) = c.ccg_code
    left join hes_analysis_pseudo..din_zage_bands d 
        on a.startage = d.startage)
    where a.fae = '1'
        and a.classpat = '1'
        and a.startage >= 65 
        and a.startage <= 120
        and left(lsoa11, 1) = 'E') a
where rownumber = '1'
group by fyear, ccg_geog_code, quinary90_dv

union all

select '91748' as indicator 
      ,fyear
      ,ccg_geog_code as areacode
      ,[quinary90_dv] as age_band
      ,count(distinct pseudo_hesid) as oi
from (select a.fyear,
    a.pseudo_hesid, 
    a.epikey, 
    c.ccg_geog_code, 
    a.admidate_dv,
    d.[quinary90_dv],
    row_number() over (partition by a.fyear, a.pseudo_hesid order by admidate_dv desc, a.epikey) as rownumber
from ([hes_apc].[dbo].[vhes_apc_sav] a
    inner join (select distinct fyear, 
                                epikey
                from [hes_apc].[dbo].[vthes_apc_diag]
                where fyear in ('1718') -- toggle: amend date
                    and left(diagcode4, 3) in ('f03')) b 
        on a.epikey = b.epikey
    inner join #ccg_lkp c
        --on  ccg_responsibility = c.ccg_code
        on (case 
                when ccg_responsibility in ('00f', '00g', '00h') then '13t' 
                when ccg_responsibility in ('00w', '01m', '01n') then '14l' 
                when ccg_responsibility in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
                when ccg_responsibility in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
                when ccg_responsibility in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
                when ccg_responsibility in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
                when ccg_responsibility in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
                when ccg_responsibility in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
                else ccg_responsibility 
            end) = c.ccg_code
    left join hes_analysis_pseudo..din_zage_bands d 
        on a.startage = d.startage)
    where a.fae = '1'
    and a.classpat = '1'
    and a.startage >= 65
    and a.startage <= 120
    and left(lsoa11, 1) = 'E') a
where rownumber = '1'
group by fyear, ccg_geog_code, quinary90_dv

--- Final Output (formatting)

if object_id('tempdb..#dsr_staging_2') is not null
    drop table #dsr_staging_2 

create table #dsr_staging_2 (
    indicator int,
    period varchar(4),
    areanm varchar(100),
    areacode varchar(10),
    o bigint,
    n bigint,
    dsr float,
    [var(dsr)] float
)

--- 3. Calculate CCG-level DSR

if object_id('tempdb..#DSR_Staging_1_CCG') is not null
    drop table #DSR_Staging_1_CCG

Select a.Indicator,
    a.Period, 
    a.AreaCode,
    a.AreaNM,
    a.age_band, 
    Oi, 
    Ni, 
    c.[Population] as [Wi], 
    ((cast(c.[Population] as float)*cast(Oi as float))/(cast(Ni as float))) as [WiOi/Ni],
    (cast(c.[Population] as float)*cast(c.[Population] as float)*cast(Oi as float))/(cast(Ni as float)*cast(Ni as float)) as [WiWiOi/NiNi]
into #DSR_Staging_1_CCG
From #Population a
left join #Numerator b 
    on SUBSTRING(convert(varchar(4), a.PERIOD), 3, 2) = SUBSTRING(b.FYEAR, 1, 2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode 
        and a.Indicator = b.Indicator
left join lookupsshared..vRef_ESP2013 c 
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min

insert into #DSR_Staging_2
Select Indicator,
    Period, 
    AreaNM,
    AreaCode, 
    sum(Oi) as O, 
    sum(Ni) as N, 
    100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
    sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_CCG
group by Indicator, Period, AreaNM, AreaCode

drop table #dsr_staging_1_ccg

--- 4. Calculate STP DSR

if object_id('tempdb..#DSR_Staging_1_STP') is not null
    drop table #DSR_Staging_1_STP

Select a.Indicator,
    a.Period,
    ParentNM as AreaNM, 
    ParentCode as AreaCode, 
    a.age_band, 
    sum(Oi) as Oi, 
    sum(Ni) as Ni, 
    c.[Population] as [Wi], 
    ((cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float)))) as [WiOi/Ni],
    (cast(c.[Population] as float)*cast(c.[Population] as float)*sum(cast(Oi as float)))/(sum(cast(Ni as float))*sum(cast(Ni as float))) as [WiWiOi/NiNi]
into #DSR_Staging_1_STP
From #Population a
left join #Numerator b 
    on SUBSTRING(convert(varchar(4), a.PERIOD), 3, 2) = SUBSTRING(b.FYEAR, 1, 2) 
        and a.Age_Band = b.Age_Band 
        and a.AreaCode = b.AreaCode 
        and a.Indicator = b.Indicator
left join lookupsshared..vRef_ESP2013 c
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min
group by a.Indicator, a.Period, ParentNM, ParentCode, a.age_band, c.[Population]

insert into #DSR_Staging_2
Select Indicator,
    Period,
    AreaNM, 
    AreaCode, 
    sum(Oi) as O, 
    sum(Ni) as N, 
    100000*(sum([WiOi/Ni])/sum(cast(Wi as float))) as DSR, 
    sum([WiWiOi/NiNi])/(sum(cast(Wi as float))*sum(cast(Wi as float))) as [Var(DSR)]
from #DSR_Staging_1_STP
group by Indicator, Period, AreaNM, AreaCode

drop table #dsr_staging_1_stp
--drop table #population
--drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p54_ccg_refresh') is not null
    drop table hes_analysis_pseudo..din_p54_ccg_refresh

Select Indicator,
    Period,
    AreaNM,
    AreaCode,
    a.O as [Count],
    DSR,
    LowerCI = ((cast (DSR as float) /100000) + (SQRT(cast([Var(DSR)]/O as float)) *
        ((case when O = '0' then '0'
                when O < '389' then cast(b.CHIINVLOWER as float) 
                else (cast(O as float) * POWER((1-1/(9*cast(O as float))-(1.95996398454005/3/SQRT(cast(O as float)))),3)) end) - cast(O as float))))*100000,
    UpperCI = ((cast (DSR as float) /100000) + (SQRT(cast([Var(DSR)] as float)/cast(O as float)) *
        ((case when O = '0' then '0'
                when O < '389' then cast(c.CHIINVUPPER as float) 
	            else ((cast(O as float)+1) * POWER((1-1/(9*(cast(O as float)+1))+(1.95996398454005/3/SQRT((cast(O as float)+1)))),3)) end) - cast(O as float))))*100000,
    a.N as [Denominator]
into hes_analysis_pseudo..din_p54_ccg_refresh
FROM #DSR_Staging_2 a
left join hes_analysis_pseudo..din_chiinv b 
    on a.O * 2 = b.n
left join hes_analysis_pseudo..din_chiinv c 
    on (a.O * 2) + 2 = c.n
group by Indicator, Period, AreaNM, AreaCode, O, a.N, DSR, [Var(DSR)], b.CHIINVLOWER, c.CHIINVUPPER
order by 1, 3

drop table #DSR_Staging_2

select *
from hes_analysis_pseudo..din_p54_ccg_refresh

--select *
--from (
--    select indicator, period, areanm, areacode, count, dsr, lowerci, upperci, denominator
--    from hes_analysis_pseudo..din_p54_ccg_refresh
--    union all
--    select indicator, period, 'England from CCG' areanm, 'E92000001' AreaCode, sum(count) count, NULL dsr, NULL lowerci, NULL upperci, sum(denominator)
--    from hes_analysis_pseudo..din_p54_ccg_refresh
--    where left(areacode, 3) = 'E38'
--    group by indicator, period
--    union all
--    select indicator, period, 'England from STP' areanm, 'E92000001' AreaCode, sum(count) count, NULL dsr, NULL lowerci, NULL upperci, sum(denominator)
--    from hes_analysis_pseudo..din_p54_ccg_refresh
--    where left(areacode, 3) = 'E54'
--    group by indicator, period) _
--where period = 2017
--order by indicator, areacode

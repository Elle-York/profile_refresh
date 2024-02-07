/*
    Domain:               Supporting Well
    Geography:            CCG and STP
    Indicator ID:         93305
    Indicator Definition: DSR of Emergency Admissions (Aged 65+; with mention of dementia)
*/

--- 1. CCG Populations

if object_id('tempdb..#ccg_lkp') is not null
    drop table #ccg_lkp

select distinct [ccgApr18cd], 
                [ccgApr18nm] as ccg_name, 
                [ccgApr18cdh] as ccg_code, 
                [stpApr18cd] as stp, 
                [stpApr18nm] as stp_name 
into #ccg_lkp
from [lookupsshared].[dbo].[vlkp_ccgApr18]

if object_id('tempdb..#population') is not null
    drop table #population

select b.period
      ,c.stp as parentcode
      ,c.stp_name as parentnm
      ,c.ccg_code as areacode
      ,c.ccg_name as areanm
	  ,b.quinary90 as age_band
	  ,sum(b.population) as ni
into #population
from hes_analysis_pseudo..din_ccg_reg_popns b 
inner join #ccg_lkp c
    --on  b.ccg_code = c.ccg_code
    on (case -- combine historic ccgs into 
            when b.officialcodeold in ('00F','00G','00H') then '13T' 
            when b.officialcodeold in ('00W','01M','01N') then '14L' 
            when officialcodeold in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
            when officialcodeold in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
            when officialcodeold in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
            when officialcodeold in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
            when officialcodeold in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
            when officialcodeold in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
            else b.officialcodeold
        end) = c.ccg_code
where b.QuinaryAgeBandMin >= 65
    and b.period = '2017' -- toggle: amend date
group by period, c.stp, c.stp_name, c.ccg_code, c.ccg_name, b.quinary90
order by 1, 2, 4, 6

--- 2. Numerator

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select a.fyear
      ,ccg_code as areacode
      ,quinary90_dv as age_band
      ,count(distinct a.epikey) as oi
into #numerator
from [hes_apc].[dbo].[vhes_apc_sav] a
inner join (select distinct fyear, 
                            epikey 
            from [hes_apc].[dbo].[vthes_apc_diag]
            where fyear in ('1718') -- toggle: amend date
                and left(diagcode4, 3) in ('F00', 'F01', 'F02', 'F03', 'F04', 'G30', 'G31')) b 
    on a.fyear = b.fyear 
        and a.epikey = b.epikey
inner join #ccg_lkp c 
    --on  ccg_responsibility = c.ccg_code
    on (case 
            when ccg_responsibility in ('00F','00G','00H') then '13T' 
            when ccg_responsibility  in ('00W','01M','01N') then '14L' 
            when ccg_responsibility in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
            when ccg_responsibility in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
            when ccg_responsibility in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
            when ccg_responsibility in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
            when ccg_responsibility in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
            when ccg_responsibility in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
            else ccg_responsibility 
        end)= c.ccg_code
left join hes_analysis_pseudo..din_zage_bands d 
    on a.startage = d.startage
where a.fyear in ('1718') -- toggle: amend date
    and left(lsoa11, 1) = 'E'
    and fae = 1
    and classpat = '1' 
    and admimeth like '2_'
    and a.startage >= 65
    and a.startage <= 120
group by a.fyear, ccg_code, d.quinary90_dv

--- 3. Calculate CCG-level DSR

if object_id('tempdb..#dsr_staging_1_ccg') is not null
    drop table #dsr_staging_1_ccg

select a.period, 
    --a.areacode,
    lkp.ccgapr18cd areacode,
    a.areanm,
    a.age_band, 
    oi, 
    ni, 
    c.population as [wi], 
    (c.population*oi)/ni as [wioi/ni],
    (power(c.population, 2)*oi)/(power(cast(ni as float), 2)) as [wiwioi/nini]
into #dsr_staging_1_ccg
from #population a
left join #numerator b 
    on substring(convert(varchar(4), a.period), 3, 2) = substring(b.fyear, 1, 2) 
        and a.age_band = b.age_band
        and a.areacode = b.areacode
left join lookupsshared..vref_esp2013 c 
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min
left join #ccg_lkp lkp
    on a.areacode = lkp.ccg_code

if object_id('tempdb..#dsr_staging_2') is not null
    drop table #dsr_staging_2

select period, 
    areanm,
    areacode, 
    sum(oi) as o, 
    sum(ni) as n, 
    100000*(sum([wioi/ni])/sum(cast(wi as float))) as dsr, 
    sum([wiwioi/nini])/(sum(wi)*sum(wi)) as [var(dsr)]
into #dsr_staging_2
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
    (c.population*sum(oi))/sum(ni) as [wioi/ni],
    (power(c.population, 2)*sum(oi))/power(sum(cast(ni as float)), 2) as [wiwioi/nini]
into #dsr_staging_1_stp
from #population a
left join #numerator b 
    on substring(convert(varchar(4), a.period), 3, 2) = substring(b.fyear, 1, 2) 
        and a.age_band = b.age_band 
        and a.areacode = b.areacode
left join lookupsshared..vref_esp2013 c 
    on cast(substring(a.age_band, 1, 2) as float) = c.age_band_min
group by a.period, parentnm, parentcode, a.age_band, c.population

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

if object_id('hes_analysis_pseudo..din_p52_ccg_refresh') is not null
    drop table hes_analysis_pseudo..din_p52_ccg_refresh

select period, 
    areanm,
	areacode,
	a.o as [count],
	dsr,
    lowerci = ((cast (dsr as float) /100000) + (sqrt(cast([var(dsr)]/o as float)) *
        ((case when o = '0' then '0'
                when o < '389' then cast(b.chiinvlower as float) 
	            else (cast(o as float) * power((1-1/(9*cast(o as float))-(1.95996398454005/3/sqrt(cast(o as float)))),3)) end) - cast(o as float))))*100000,
    upperci = ((cast (dsr as float) /100000) + (sqrt(cast([var(dsr)] as float)/cast(o as float)) *
        ((case when o = '0' then '0'
                when o < '389' then cast(c.chiinvupper as float) 
                else ((cast(o as float)+1) * power((1-1/(9*(cast(o as float)+1))+(1.95996398454005/3/sqrt((cast(o as float)+1)))),3)) end) - cast(o as float))))*100000,
    a.n as [denominator]
into hes_analysis_pseudo..din_p52_ccg_refresh
from #dsr_staging_2 a
left join hes_analysis_pseudo..din_chiinv b 
    on a.o * 2 = b.n
left join hes_analysis_pseudo..din_chiinv c 
    on (a.o * 2) + 2 = c.n
group by period, areanm, areacode, o, a.n, dsr, [var(dsr)], b.chiinvlower, c.chiinvupper
order by 1, 3

drop table #dsr_staging_2

select period, areacode, [count], dsr, lowerci, upperci, denominator
from hes_analysis_pseudo..din_p52_ccg_refresh

/*
    
    Set @fyear as desired

*/

declare @fyear varchar(10) = '1718'

--- Prepare CCG Admissions Data

if object_id('tempdb..#numerator') is not null  
    drop table #numerator

select a.fyear,
    c.stp as parentcode,
    c.stp_name as parentnm,
    c.ccgapr18cd as areacode,
    c.ccgapr18nm as areanm,
    sum(case when speldur in ('0', '1') then '1' else 0 end) as o,
    count(a.epikey) as n
into #numerator
from [hes_apc].[dbo].[vhes_apc_flat] a
inner join (select distinct fyear, epikey
            from [hes_apc].[dbo].[vthes_apc_diag]
            where fyear = @fyear
                and left(diagcode4, 3) in ('F00', 'F01', 'F02', 'F03', 'F04', 'G30', 'G31')) b 
    on a.fyear = b.fyear 
        and a.epikey = b.epikey
inner join (select distinct ccgapr18cd,
                            ccgapr18nm, 
                            ccgapr18cdh as ccg_code, 
                            stpapr18cd as stp, 
                            stpapr18nm as stp_name 
            from lookupsshared..vlkp_ccgapr18) c 
    --on  ccg_responsibility = c.ccg_code
    on (case 
            when ccg_responsibility in ('00F', '00G', '00H') then '13T' 
            when ccg_responsibility in ('00W','01M','01N') then '14L' 
            when ccg_responsibility in ('10M', '10N', '10W', '11D') then '15A' --- NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs  to form NHS Berkshire West CCG
            when ccg_responsibility in ('13P', '04X', '05P') then '15E' --- NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs  to form NHS Birmingham and Solihull CCG
            when ccg_responsibility in ('11H', '11T', '12A') then '15C' --- NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs  to form NHS Bristol, North Somerset and South Gloucestershire CCG
            when ccg_responsibility in ('10Y', '10H') then '14Y' --- NHS Aylesbury Vale and NHS Chiltern CCGs to form NHS Buckinghamshire CCG
            when ccg_responsibility in ('10G', '10T', '11C') then '15D' --- NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs  to form NHS East Berkshire CCG
            when ccg_responsibility in ('02V', '03G', '03C') then '15F' --- NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs  to form NHS Leeds CCG
            else ccg_responsibility 
        end) = c.ccg_code
where a.fyear = @fyear
    and left(lsoa11, 1) = 'E'
    and fde = '1' 
    and classpat = '1' 
    and admimeth like '2_'
    and a.startage >= '65' 
    and a.startage <= '120'
group by a.fyear, stp, stp_name, ccgapr18cd, ccgapr18nm

--- Calculate CCG Values

if object_id('tempdb..#final_output') is not null
    drop table #final_output

select fyear, 
    areanm,
    areacode,
    o, 
    n, 
    100*(cast(o as float)/n) as value
into #final_output
from #numerator

-- Calculate STP values

insert into #final_output
select fyear, 
    parentnm as areanm,
    parentcode as areacode,
    sum(o) as o, 
    sum(n) as n, 
    100*(cast(sum(o) as float)/sum(n)) as value
from #numerator
group by fyear, parentnm, parentcode

drop table #numerator

--- Final Results (including confidence intervals)

if object_id('hes_analysis_pseudo..din_p53_ccg_refresh') is not null
    drop table hes_analysis_pseudo..din_p53_ccg_refresh

Select fyear, 
       areanm,
	   areacode,
	   o as [count],
	   value,
	   (((2*cast(o as float)) +
	   power(1.95996398454005,2) -
	   1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
	   /
	   (2*(cast(n as float)+power(1.95996398454005,2))))
	   *
	   100 as lowerci,
	    (((2*cast(o as float)) +
	   power(1.95996398454005,2) +
	   1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
	   /
	   (2*(cast(n as float)+power(1.95996398454005,2))))
	   *
	   100 as upperci,
	   n as [denominator]
into hes_analysis_pseudo..din_p53_ccg_refresh
from #final_output
order by 1, 3

select fyear, areacode, value, lowerci, upperci, count, denominator
from hes_analysis_pseudo..din_p53_ccg_refresh

--- Uncomment the following section to add aggregated England totals (summed from CCG and/or STP figures)

--union all
--select 1617 fyear, 'E92000001' areacode, NULL value, NULL lowerci, NULL upperci, sum(count) count_ccg, sum(denominator) denominator_ccg
--from hes_analysis_pseudo..din_p53_ccg_refresh
--where left(areacode, 3) = 'E38'
--union all
--select 1617 fyear, 'E92000001' areacode, NULL value, NULL lowerci, NULL upperci, sum(count) count_stp, sum(denominator) denominator_stp
--from hes_analysis_pseudo..din_p53_ccg_refresh
--where left(areacode, 3) = 'E54'

--drop table #final_output

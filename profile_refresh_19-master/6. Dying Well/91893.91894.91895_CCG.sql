
/*
    CCG and STP
	91893: Place of death - care home: People with dementia aged 65+
    91894: Place of death - hospital: People with dementia aged 65+
	91895: Place of death - home: People with dementia aged 65+
	Amend lines
*/

--- 1a. UTLA Admission

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select year(xreg_date) as [year]
    ,stpapr18cd as parentcode
    ,stpapr18nm as parentnm
    ,ccgapr18cd as areacode
    ,ccgapr18nm as areanm
    ,sum(case when commest = 'h' then 1 else 0 end) as o_home
    ,sum(case when (nhs_ind ='1' and est_type in ('02','04','07','10','21')) or (nhs_ind ='2' and est_type in ('03','04','07','10','14','20','22','32','33','99')) then 1 else 0 end) as o_care
    ,sum(case when (nhs_ind ='1' and est_type in ('01','03','18','99')) or (nhs_ind='2' and est_type in ('01','18','19')) then 1 else 0 end) as o_hosp
    ,count(*) as n
into #numerator
from birthsdeaths..[vDeathsALL_NSPL_2018-05] a
left join (select lsoa11cd, 
                  ccgapr18cd, 
                  ccgapr18nm, 
                  ccgapr18cdh, 
                  stpapr18cd, 
                  stpapr18nm 
           from [lookupsshared].[dbo].[vlkp_lsoa11]) b
    on a.lsoa11_pc = b.lsoa11cd
--    left join [hes_analysis_pseudo].[dbo].[ccg_stp_lookup_fingertips_din] b on a.ccgapr16cd = b.[childlevelgeographycode]) b on a.lsoa11_pc = b.lsoa11cd
where year(xreg_date) in ('2017') -- toggle: amend date
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
group by year(xreg_date), stpapr18cd, stpapr18nm, ccgapr18cd, ccgapr18nm

--- Final Output (formatting)

if object_id('tempdb..#final_output') is not null
    drop table #final_output

create table #final_output (
    [year] varchar(4) ,
    areanm varchar(100),
    areacode varchar(10),
    n bigint,
    o_home bigint,
    value_home float,
    o_care bigint,
    value_care float,
    o_hosp bigint,
    value_hosp float
)

--- 1b. Calculate CCG Values

insert into #final_output
select [year] 
,areanm
,areacode
,n
,o_home  
,100*(cast(o_home as float)/n) as value_home
,o_care  
,100*(cast(o_care as float)/n) as value_care
,o_hosp  
,100*(cast(o_hosp as float)/n) as value_hosp
from #numerator

--- 1c. Calculate STP Values

insert into #final_output
select [year]
    ,parentnm as areanm
    ,parentcode as areacode
    ,sum(n) as n
    ,sum(o_home) as o_home 
    ,100*(cast(sum(o_home) as float)/sum(n)) as value_home
    ,sum(o_care) as o_care 
    ,100*(cast(sum(o_care) as float)/sum(n)) as value_care
    ,sum(o_hosp) as o_hosp 
    ,100*(cast(sum(o_hosp) as float)/sum(n)) as value_hosp
from #numerator
group by [year], parentnm, parentcode

drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p63_ccg_refresh') is not null
    drop table hes_analysis_pseudo..din_p63_ccg_refresh

select indicator
    ,ind_desc
    ,[year] 
    ,areanm
    ,areacode
    ,sum(o) as [count]
    ,sum(value) as value
    ,lowerci = sum(((2*cast(o as float)) +
        power(1.95996398454005,2) -
        1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
        /
        (2*(cast(n as float)+power(1.95996398454005,2))))
        *
        100
    ,upperci = sum(((2*cast(o as float)) +
        power(1.95996398454005,2) +
        1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
        /
        (2*(cast(n as float)+power(1.95996398454005,2))))
        *
        100
    ,sum(n) as [denominator]
into hes_analysis_pseudo..din_p63_ccg_refresh
from (select '91895' as indicator
        ,'home' as ind_desc
        ,[year]
        ,areanm
        ,areacode
        ,o_home as o
        ,n
        ,value_home as value
	 from #final_output

	 union all

	 select '91893' as indicator
        ,'care' as ind_desc
        ,[year]
        ,areanm
        ,areacode
        ,o_care as o
        ,n
        ,value_care as value
	from #final_output

	union all

	select '91894' as indicator
        ,'hosp' as ind_desc
        ,[year]
        ,areanm
        ,areacode
        ,o_hosp as o
        ,n
        ,value_hosp as value
    from #final_output) a
group by indicator, ind_desc, [year], areanm, areacode
order by 1, 3, 5

drop table #final_output

select *
from hes_analysis_pseudo..din_p63_ccg_refresh
where year = '2017'
order by indicator, year, areacode

--select *
--from (
--    select *
--    from hes_analysis_pseudo..din_p63_ccg_refresh

--    union all
--    select max(indicator) indicator, max(ind_desc) ind_desc, max(year) year, 'England from CCG' areanm, 'E92000001' areacode, sum(count) count, NULL value, NULL lowerci, NULL upperci, sum(denominator) denominator
--    from hes_analysis_pseudo..din_p63_ccg_refresh
--    where left(areacode, 3) = 'E38'
--    group by indicator, ind_desc, year
--    union all
--    select max(indicator) indicator, max(ind_desc) ind_desc, max(year) year, 'England from STP' areanm, 'E92000001' areacode, sum(count) count, NULL value, NULL lowerci, NULL upperci, sum(denominator) denominator
--    from hes_analysis_pseudo..din_p63_ccg_refresh
--    where left(areacode, 3) = 'E54'
--    group by indicator, ind_desc, year) _
--where left(areacode, 3) = 'E92'
--    and year = 2017
--order by indicator, year, areacode

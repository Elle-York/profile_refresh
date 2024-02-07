
/*  
    LA
	91893: Place of death - care home: People with dementia aged 65+
    91894: Place of death - hospital: People with dementia aged 65+
    91895: Place of death - home: People with dementia aged 65+
	Amend line 
*/

--- 1a. UTLA Admissions

if object_id('tempdb..#numerator') is not null
    drop table #numerator

select year(xreg_date) as [year]
    ,b.ctry09cd as england
    ,b.ctry09nm as englandnm
    ,b.rgn09cd as parentcode
    ,b.rgn09nm as parentnm
    ,b.utla13cd as areacode
    ,b.utla13nm as areanm
    ,sum(case when commest = 'h' then 1 else 0 end) as o_home
    ,sum(case when (nhs_ind ='1' and est_type in ('02','04','07','10','21')) 
                    or (nhs_ind ='2' and est_type in ('03','04','07','10','14','20','22','32','33','99')) then 1 
              else 0 
         end) as o_care
    ,sum(case when (nhs_ind ='1' and est_type in ('01','03','18','99')) 
                    or (nhs_ind = '2' and est_type in ('01','18','19')) then 1 
              else 0 end) as o_hosp
    ,count(*) as n
into #numerator
from birthsdeaths..[vDeathsALL_NSPL_2018-05] a
left join [lookupsshared].[dbo].[vlkp_lsoa11] b 
    on a.lsoa11_pc = b.lsoa11cd
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
group by year(xreg_date), b.ctry09cd, b.ctry09nm, b.rgn09cd, b.rgn09nm, b.utla13cd, b.utla13nm

--- 1b. Calculate LA values excluding Cornwall, Isles of Scilly, City of London and Hackney

if object_id('tempdb..#final_output') is not null
    drop table #final_output

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
into #final_output
from #numerator
where areacode not in ('e06000052','e06000053','e09000001','e09000012') -- Excludes Cornwall, Isles of Scilly, City of London and Hackney

--- 1c. Calculate LA values for combined Cornwall and Isles of Scilly, City of London and Hackney

if object_id('tempdb..#combined_la_groups') is not null
    drop table #combined_la_groups

create table #combined_la_groups (
    utla13cd varchar(9), 
    utla13nm varchar(50),
    [group] varchar(1)
)

insert into #combined_la_groups
    values ('E06000052','Cornwall', '1'),
        ('E06000053','Isles of Scilly', '1'),
        ('E09000001','City of London', '2'),
        ('E09000012','Hackney', '2')

if object_id('tempdb..#staging_1_la_combined') is not null
    drop table #staging_1_la_combined

select a.[year]
    ,[group] as areacode
    ,sum(n) as n
    ,sum(o_home) as o_home 
    ,100*(cast(sum(o_home) as float)/sum(n)) as value_home
    ,sum(o_care) as o_care 
    ,100*(cast(sum(o_care) as float)/sum(n)) as value_care
    ,sum(o_hosp) as o_hosp 
    ,100*(cast(sum(o_hosp) as float)/sum(n)) as value_hosp
into #staging_1_la_combined
from #numerator a
left join #combined_la_groups b 
    on a.areacode = b.utla13cd
where a.areacode in ('E06000052','E06000053','E09000001','E09000012') --this limits the data to cornwall, isles of scilly, city of london and hackney
group by a.[year], [group]

insert into #final_output
select [year] 
    ,b.utla13nm as areanm
    ,b.utla13cd as areacode 
    ,n
    ,o_home
    ,value_home
    ,o_care
    ,value_care
    ,o_hosp
    ,value_hosp
from #staging_1_la_combined a
inner join #combined_la_groups b 
    on a.areacode = b.[group]

drop table #combined_la_groups
drop table #staging_1_la_combined

--- 1e. Calculate REGION Values

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

--- 1f. Calculate England Values

insert into #final_output
select [year]
    ,englandnm as areanm 
    ,england as areacode
    ,sum(n) as n
    ,sum(o_home) as o_home 
    ,100*(cast(sum(o_home) as float)/sum(n)) as value_home
    ,sum(o_care) as o_care 
    ,100*(cast(sum(o_care) as float)/sum(n)) as value_care
    ,sum(o_hosp) as o_hosp 
    ,100*(cast(sum(o_hosp) as float)/sum(n)) as value_hosp
from #numerator
group by [year], englandnm, england

drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p63_la_refresh') is not null
    drop table hes_analysis_pseudo..din_p63_la_refresh

select indicator
      ,ind_desc
      ,[year] 
      ,areanm
	  ,areacode
	  ,o as [count]
	  ,value
	  ,lowerci = (((2*cast(o as float)) +
	       power(1.95996398454005,2) -
	       1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
	       /
	       (2*(cast(n as float)+power(1.95996398454005,2))))
	       *
	       100
	   ,upperci = (((2*cast(o as float)) +
	       power(1.95996398454005,2) +
	       1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
	       /
	       (2*(cast(n as float)+power(1.95996398454005,2))))
	       *
	       100
       ,n as [denominator]
into hes_analysis_pseudo..din_p63_la_refresh
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
order by 1, 3, 5

drop table #final_output

select *
from hes_analysis_pseudo..din_p63_la_refresh
order by indicator, year, areacode, areanm

--select *
--from (
--    select *
--    from hes_analysis_pseudo..din_p63_la_refresh
--    union all
--    select max(indicator), max(ind_desc), max(year) year, 'England from LA' areanm, 'E92000001' areacode, sum(count) count_la, NULL dsr, NULL lowerci, NULL upperci, sum(denominator) denominator_la
--    from hes_analysis_pseudo..din_p63_la_refresh
--    where left(areacode, 3) in ('E06', 'E07', 'E08', 'E09', 'E10')
--    group by indicator, year
--    union all
--    select max(indicator), max(ind_desc), max(year) year, 'England from Region' areanm, 'E92000001' areacode, sum(count) count_region, NULL dsr, NULL lowerci, NULL upperci, sum(denominator) denominator_region
--    from hes_analysis_pseudo..din_p63_la_refresh
--    where left(areacode, 3) = 'E12'
--    group by indicator, year) _
--where year = 2016
--    and left(areacode, 3) = 'E92'
--order by indicator, year, areacode, areanm

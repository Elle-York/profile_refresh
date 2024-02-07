/*
    LA
	91887: Deaths in Usual Place of Residence: People with dementia aged 65+
	Amend line 32
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
    ,sum(case when (commest = 'h'
                        or (a.nhs_ind ='1' and a.est_type in ('02','04','07','10','21'))
                        or (a.nhs_ind ='2' and a.est_type in ('03','04','07','10','14','20','22','32','33','99'))
                        or (a.nhs_ind ='2' and a.est_type in ('52','64'))) then 1
              else 0 
         end) as o
    ,count(*) as n
into #numerator
from [BirthsDeaths]..[vDeathsALL_NSPL_2018-05] a 
left join [lookupsshared].[dbo].[vlkp_lsoa11] b 
    on a.lsoa11_pc = b.lsoa11cd 
left join [BirthsDeaths].[dbo].[vComEst] c 
    on a.commest = c.entity
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
  and left(ucod,1) not in ('v','w','x','y') 
  and left(ucod,4) not in ('u509')
group by year(xreg_date), b.ctry09cd, b.ctry09nm, b.rgn09cd, b.rgn09nm, b.utla13cd, b.utla13nm

--- 1b. Calculate LA values excluding Cornwall, Isles of Scilly, City of London and Hackney

if object_id('tempdb..#final_output') is not null
    drop table #final_output

select [year], 
    areanm,
    areacode,
    o, 
    n, 
    100*(cast(o as float)/n) as value
into #final_output
from #numerator
where areacode not in ('e06000052','e06000053','e09000001','e09000012') --This excludes Cornwall, Isles of Scilly, City of London and Hackney

--- 1c. Calculate LA values for combined Cornwall and Isles of Scilly, City of London and Hackney

if object_id('tempdb..#combined_la_groups') is not null
    drop table #combined_la_groups

create table #combined_la_groups (
    utla13cd varchar(9), 
    utla13nm varchar(50),
    [group] varchar(1)
)

insert into #combined_la_groups
    values ('e06000052','Cornwall', '1'),
        ('e06000053','Isles of Scilly', '1'),
        ('e09000001','City of London', '2'),
        ('e09000012','Hackney', '2')

if object_id('tempdb..#staging_1_la_combined') is not null
    drop table #staging_1_la_combined

select a.[year], 
    [group] as areacode, 
    sum(o) as o, 
    sum(n) as n,
    100*(cast(sum(o) as float)/sum(n)) as value
into #staging_1_la_combined
from #numerator a
left join #combined_la_groups b 
    on a.areacode = b.utla13cd
where a.areacode in ('e06000052','e06000053','e09000001','e09000012') --This limits the data to Cornwall, Isles of Scilly, City of London and Hackney
group by a.[Year], [Group]

insert into #Final_Output
Select [Year], 
    b.UTLA13NM as AreaNM,
    b.UTLA13CD as AreaCode, 
    O, 
    N, 
    Value
from #Staging_1_LA_Combined a
inner join #Combined_LA_Groups b 
    on a.AreaCode = b.[Group]

--Drop table #Combined_LA_Groups
--Drop table #Staging_1_LA_Combined

--- 1e. Calculate Region Values

insert into #final_output
select [year],
    parentnm as areanm, 
    parentcode as areacode, 
    sum(o) as o, 
    sum(n) as n, 
    100*(cast(sum(o) as float)/sum(n)) as value
from #numerator
group by [year], parentnm, parentcode

--- 1f. Calculate England Values

insert into #final_output
select [year],
    englandnm as areanm, 
    england as areacode, 
    sum(o) as o, 
    sum(n) as n, 
    100*(cast(sum(o) as float)/sum(n)) as value
from #numerator
group by [year], englandnm, england
drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p62_la_refresh') is not null
    drop table hes_analysis_pseudo..din_p62_la_refresh

select [year], 
    areanm,
    areacode,
    o as [count],
    value,
    lowerci = (((2*cast(o as float)) +
        power(1.95996398454005,2) -
        1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
        /
        (2*(cast(n as float)+power(1.95996398454005,2))))
        *
        100,
    upperci = (((2*cast(o as float)) +
        power(1.95996398454005,2) +
        1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
        /
        (2*(cast(n as float)+power(1.95996398454005,2))))
        *
        100,
    n as [denominator]
into hes_analysis_pseudo..din_p62_la_refresh
from #final_output
order by 1, 3

--drop table #final_output

select *
from hes_analysis_pseudo..din_p62_la_refresh

union all
select 2017 year, 'England from LA' areanm, 'E92000001' areacode, sum(count) count_la, NULL dsr, NULL lowerci, NULL upperci, sum(denominator) denominator_la
from hes_analysis_pseudo..din_p62_la_refresh
where left(areacode, 3) in ('E06', 'E07', 'E08', 'E09', 'E10')
group by year
union all
select 2017 year, 'England from Region' areanm, 'E92000001' areacode, sum(count) count_region, NULL dsr, NULL lowerci, NULL upperci, sum(denominator) denominator_region
from hes_analysis_pseudo..din_p62_la_refresh
where left(areacode, 3) = 'E12'
group by year

order by year, areacode

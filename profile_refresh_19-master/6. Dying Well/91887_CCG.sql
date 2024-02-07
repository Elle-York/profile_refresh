/*
    CCG and STP
    91887: Deaths in Usual Place of Residence: People with dementia aged 65+
	Amend lines 
*/

--declare @year varchar(10) = '2016'

--- 1a. UTLA Admissions

if object_id('tempdb..#numerator') is not null
    drop table #numerator

SELECT YEAR(xReg_Date) as [YEAR]
       ,STPapr18CD as ParentCode
       ,STPapr18NM as ParentNM
       ,CCGapr18CD as AreaCode
	   ,CCGapr18NM as AreaNM
	   ,sum(case when (commest = 'H'
       or (nhs_ind ='1' and est_type in ('02','04','07','10','21'))
       or (nhs_ind ='2' and est_type in ('03','04','07','10','14','20','22','32','33','99'))
	   or (nhs_ind ='2' and est_type in ('52','64'))
       ) then 1 else 0 end) as O
       ,count(*) as N
into #numerator
FROM [BirthsDeaths]..[vDeathsALL_NSPL_2018-05] a
left join (select LSOA11CD, 
                  CCGapr18CD, 
                  CCGapr18NM, 
                  CCGapr18CDH, 
                  stpapr18cd, 
                  stpapr18nm
           from [LookupsShared].[dbo].[vLKP_LSOA11]) b
    on a.LSOA11_PC = b.LSOA11CD
--            left join [HES_Analysis_Pseudo].[dbo].[CCG_STP_Lookup_Fingertips_DIN] b on a.CCGAPR16CD = b.[ChildLevelGeographyCode]) b on a.LSOA11_PC = b.LSOA11CD
where YEAR(xReg_Date) in ('2017') -- toggle: amend date
    and xAGE_YEAR >= '65'
    and left(LSOA11_PC,1) = 'E'
    and  (LEFT (UCOD, 3) in ('F00','F01','F02','F03','F04','G30','G31')
       OR LEFT (COD_1, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_2, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_3, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_4, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_5, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_6, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_7, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_8, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_9, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_10, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_11, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_12, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_13, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_14, 3) in ('F00','F01','F02','F03','F04','G30','G31')
	   OR LEFT (COD_15, 3) in ('F00','F01','F02','F03','F04','G30','G31'))
    and left(UCOD,1) not in ('V','W','X','Y') 
    and left(UCOD,4) not in ('U509')
GROUP BY YEAR(xReg_Date), STPApr18CD, STPAPR18NM, CCGAPR18CD, CCGapr18NM

--- Final Output (formatting)

if object_id('tempdb..#final_output') is not null
    drop table #final_output

Create Table #final_output (
    [YEAR] Varchar(4),
    AreaNM varchar(100), 
    AreaCode varchar(10), 
    O BIGINT, 
    N BIGINT, 
    Value Float
)

--- 1b. Calculate CCG Values

insert into #Final_Output
Select [Year], 
    AreaNM,
    AreaCode,
    O, 
    N, 
    100*(cast(O as float)/N) as Value
From #Numerator

-- 1c. Calculate STP Values

insert into #final_output
select [year],
    parentnm as areanm, 
    parentcode as areacode, 
    sum(o) as o, 
    sum(n) as n, 
    100*(cast(sum(o) as float)/sum(n)) as value
from #numerator
group by [year], parentnm, parentcode

drop table #numerator

--- Results

if object_id('hes_analysis_pseudo..din_p62_ccg_refresh') is not null
    drop table hes_analysis_pseudo..din_p62_ccg_refresh

select [year], 
    areanm,
	areacode,
	sum(o) as [count],
	sum(value) value,
	lowerci = sum(((2*cast(o as float)) +
	   power(1.95996398454005,2) -
	   1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
	   /
	   (2*(cast(n as float)+power(1.95996398454005,2))))
	   *
	   100,
	upperci = sum(((2*cast(o as float)) +
	   power(1.95996398454005,2) +
	   1.95996398454005 * sqrt(power(1.95996398454005,2)+(4 * cast(o as float)*(1-(cast(o as float)/cast(n as float))))))
	   /
	   (2*(cast(n as float)+power(1.95996398454005,2))))
	   *
	   100,
    sum(n) as [denominator]
into hes_analysis_pseudo..din_p62_ccg_refresh
from #final_output
group by [year], areanm, areacode
order by 1, 3

drop table #final_output

select *
from (
    select *
    from hes_analysis_pseudo..din_p62_ccg_refresh
    union all
    select max(year) year, 'England from CCG' areanm, 'E92000001' areacode, sum(count) count, NULL value, NULL lowerci, NULL upperci, sum(denominator) denominator
    from hes_analysis_pseudo..din_p62_ccg_refresh
    where left(areacode, 3) = 'E38'
    group by year
    union all
    select max(year) year, 'England from STP' areanm, 'E92000001' areacode, sum(count) count, NULL value, NULL lowerci, NULL upperci, sum(denominator) denominator
    from hes_analysis_pseudo..din_p62_ccg_refresh
    where left(areacode, 3) = 'E54'
    group by year) _
where year = '2017'
    --and left(areacode, 3) = 'E92'
order by year, areanm

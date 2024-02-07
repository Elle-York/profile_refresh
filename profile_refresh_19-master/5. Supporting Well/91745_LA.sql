/* LA Level
   91745: Short Stay Emergency Admissions (Aged 65+)
   Amend lines 
*/

declare @fyear varchar(30) = '1718'

--- 1a. UTLA Admissions

if object_id('tempdb..#numerator') is not null
    drop table #numerator

SELECT
    a.FYEAR,
    c.CTRY09CD as England,
    c.CTRY09NM as EnglandNM, 
    c.RGN09CD as ParentCode,
    c.RGN09NM as ParentNM,
    c.UTLA13CD as AreaCode,
    c.UTLA13NM as AreaNM,
    sum(case when SPELDUR in ('0','1') then '1' else 0 end) as O,
    count(a.epikey) as N
into #Numerator
FROM [HES_APC].[dbo].[vHES_APC_FLAT] a
inner join (
        Select distinct FYEAR, 
                        epikey 
        from [HES_APC].[dbo].[vtHES_APC_DIAG] 
        where FYEAR = @fyear
            and left(DiagCode4, 3) in ('F00','F01','F02','F03','F04','G30','G31')) b 
    on a.FYEAR = b.FYEAR 
        and a.epikey = b.epikey
left join [LookupsShared].[dbo].[vLKP_LSOA11] c 
    on a.LSOA11 = c.LSOA11CD
where a.FYEAR = @fyear
    and left(LSOA11,1) = 'e'
    and FDE = '1' 
    and classpat = '1' 
    and admimeth like '2_'
    AND ((a.startage >= '65' AND a.startage <= '120'))
group by a.FYEAR, c.CTRY09CD, c.CTRY09NM, c.RGN09CD, c.RGN09NM, c.UTLA13CD, c.UTLA13NM
order by 1, 6

--- 1b. Calculate LA values excluding Cornwall, Isles of Scilly, City of London and Hackney

Select FYEAR, 
    AreaNM,
    AreaCode,
    O, 
    N, 
    100*(cast(O as float)/N) as Value
into #Final_Output
From #Numerator
where AreaCode not in ('E06000052','E06000053','E09000001','E09000012') -- Excludes Cornwall, Isles of Scilly, City of London and Hackney

--- 1c. Calculate LA values for combined Cornwall and Isles of Scilly, City of London and Hackney

Create Table #Combined_LA_Groups (
    UTLA13CD Varchar(9), 
    UTLA13NM varchar(50),
    [Group] varchar(1)
)

INSERT INTO #Combined_LA_Groups
    Values 
        ('E06000052','Cornwall', '1'),
        ('E06000053','Isles of Scilly', '1'),
        ('E09000001','City of London', '2'),
        ('E09000012','Hackney', '2')

Select a.FYEAR, 
    [Group] as AreaCode, 
    sum(O) as O, 
    sum(N) as N,
    100*(cast(sum(O) as float)/sum(N)) as Value
into #Staging_1_LA_Combined
From #Numerator a
left join #Combined_LA_Groups b 
    on a.AreaCode = b.UTLA13CD
where a.AreaCode in ('E06000052','E06000053','E09000001','E09000012') -- Limits data to Cornwall, Isles of Scilly, City of London and Hackney
group by a.FYEAR, [Group]

insert into #Final_Output
Select FYEAR, 
    b.UTLA13NM as AreaNM,
    b.UTLA13CD as AreaCode, 
    O, 
    N, 
    Value
from #Staging_1_LA_Combined a
inner join #Combined_LA_Groups b 
    on a.AreaCode = b.[Group]

Drop table #Combined_LA_Groups, #Staging_1_LA_Combined

--- 1e. Calculate REGION Values

insert into #Final_Output
Select FYEAR,
    ParentNM as AreaNM, 
    ParentCode as AreaCode, 
    sum(O) as O, 
    sum(N) as N, 
    100*(cast(sum(O) as float)/sum(N)) as Value
From #Numerator
group by FYEAR, ParentNM, ParentCode

--- 1f. Calculate England Values

insert into #Final_Output
Select FYEAR,
    EnglandNM as AreaNM, 
    England as AreaCode, 
    sum(O) as O, 
    sum(N) as N, 
    100*(cast(sum(O) as float)/sum(N)) as Value
From #Numerator
group by FYEAR, EnglandNM, England

--Drop table #Numerator

/*Print results*/

if object_id('hes_analysis_pseudo..din_p53_la') is not null
    drop table hes_analysis_pseudo..din_p53_la

Select FYEAR, 
    AreaNM,
    AreaCode,
    O as [Count],
    Value,
    (((2*cast(O as float)) +
    Power(1.95996398454005,2) -
    1.95996398454005 * SQRT(Power(1.95996398454005,2)+(4 * cast(O as float)*(1-(cast(O as float)/cast(N as float))))))
    /
    (2*(cast(N as float)+Power(1.95996398454005,2))))
    *
    100 as LowerCI,
    (((2*cast(O as float)) +
    Power(1.95996398454005,2) +
    1.95996398454005 * SQRT(Power(1.95996398454005,2)+(4 * cast(O as float)*(1-(cast(O as float)/cast(N as float))))))
    /
    (2*(cast(N as float)+Power(1.95996398454005,2))))
    *
    100 as UpperCI,
    N as [Denominator]
into hes_analysis_pseudo..din_p53_la 
FROM #Final_Output
--group by Period, AreaNM, AreaCode, O, a.N, DSR, [Var(DSR)], b.CHIINVLOWER, c.CHIINVUPPER
order by 1, 3

drop table #Final_Output 

select *
from hes_analysis_pseudo..din_p53_la

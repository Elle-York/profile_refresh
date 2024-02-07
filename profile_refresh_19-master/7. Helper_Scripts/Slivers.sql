
 /*  SLIVERS.sql
   
   Identifies small populations (geographical slivers)
   created when two geographical entities are overlaid 
   or combined.  */

-- UTLA multiple CCG Query

with cte as(
SELECT UTLA13CD, UTLA13NM, CCGApr18CD, CCGApr18NM, SUM(Pop) Pop2015, COUNT(LSOA11CD) NumLSOAs
FROM  [LookupsShared].[dbo].[vLKP_LSOA11] l
LEFT JOIN (	SELECT OfficialCode, SUM(Population) Pop
			FROM [Populations].[dbo].[vRes_LSOA11_SingleYear]
			WHERE SexDesc='Persons'
			--And age >= 65	
			and period = 2017
			and versionnumber= 2
			GROUP BY OfficialCode) p
on l.LSOA11CD=p.OfficialCode
GROUP BY UTLA13CD, UTLA13NM, CCGApr18CD, CCGApr18NM
--ORDER BY LTLA13CD, CCGApr18CD
)

select * from cte
join (select cte.UTLA13CD , count (*) as ctCCG
from cte
group by cte.UTLA13CD
having count (*) >1) sub
on cte.UTLA13CD=sub.UTLA13CD

order by cte.UTLA13CD, cte.CCGApr18CD;

-- CCG multiple UTLA Query

with cte as(
SELECT  CCGApr18CD, CCGApr18NM,UTLA13CD, UTLA13NM, SUM(Pop) Pop2015, COUNT(LSOA11CD) NumLSOAs
FROM  [LookupsShared].[dbo].[vLKP_LSOA11] l
LEFT JOIN (	SELECT OfficialCode, SUM(Population) Pop
			FROM [Populations].[dbo].[vRes_LSOA11_SingleYear]
			WHERE SexDesc='Persons'
			--And age >= 65
			and period = 2017 and versionnumber = 2
			GROUP BY OfficialCode) p
on l.LSOA11CD=p.OfficialCode
GROUP BY UTLA13CD, UTLA13NM, CCGApr18CD, CCGApr18NM
--ORDER BY LTLA13CD, CCGApr18CD
)

select * from cte
join (select cte.CCGApr18CD , count (*) as ctLAs
from cte
group by cte.CCGApr18CD
having count (*) >1) sub
on cte.CCGApr18CD=sub.CCGApr18CD

order by cte.CCGApr18CD, cte.UTLA13CD;


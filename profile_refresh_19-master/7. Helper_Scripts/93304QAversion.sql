/* 93304  People with dementia using inpatient hospital services 
as a percentage of recorded diagnosis of dementia (all ages)*/
-------------------------------------------------------------------------------

/* Run section 1 General Query */

DROP TABLE [HES_Analysis_Pseudo].dbo.DIN93304a;
DROP TABLE [HES_Analysis_Pseudo].dbo.DIN93304
DROP TABLE [HES_Analysis_Pseudo].dbo.DIN93304b

select fyear, epikey
into [HES_Analysis_Pseudo].dbo.DIN93304
from [hes_apc].[dbo].[vthes_apc_diag]
where fyear in ('1718')
and left(diagcode4, 3) in ('f00','f01','f02','f03','f04','g30','g31')
group by fyear, epikey

-------------------------------------------------------------------------------

select a.CCG_RESPONSIBILITY, Count(Distinct a.PSEUDO_HESID) AS Patients, a.fyear, a.admidate_dv, a.epikey,
row_number() over(partition by a.fyear, a.PSEUDO_HESID order by admidate_dv desc, a.epikey) as rownumber
into [HES_Analysis_Pseudo].dbo.DIN93304a
from [HES_APC].[dbo].[vHES_APC_SAV] AS a
Right Join [HES_Analysis_Pseudo].dbo.DIN93304 As b
ON a.fyear = b.fyear
AND a.epikey = b.epikey
WHERE a.FAE = '1'
and a.classpat = '1'
and left(a.lsoa11,1) = 'e'
group by a.fyear, a.CCG_RESPONSIBILITY,a.PSEUDO_HESID, admidate_dv, a.epikey  
order by a.CCG_RESPONSIBILITY;

-------------------------------------------------------------------------------
select *
into [HES_Analysis_Pseudo].dbo.DIN93304b
from [HES_Analysis_Pseudo].dbo.DIN93304a
Where rownumber = 1


-------------------------------------------------------------------------------

/* Run Section 2 - Update old CCG codes for New CCGs 2018 */
 
-- ADD A REAL_CCG Column:
ALTER TABLE [HES_Analysis_Pseudo].dbo.DIN93304b
ADD [REAL_CCG] varchar(5) 
go	

--SETS DEFAULT VALUE AS THE CCG of Responsibility:
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = [CCG_RESPONSIBILITY]
FROM [HES_Analysis_Pseudo].dbo.DIN93304
go
				
-- update the unmerged newcastle gateshead values to 13t
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '13T'
WHERE [CCG_RESPONSIBILITY] in ('00F','00G','00H')
go
					
-- update the unmerged manchester values to 14L
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '14L'
WHERE [CCG_RESPONSIBILITY] in ('00W','01M','01N')
go

-- buckinghamshire
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '14Y'
WHERE [CCG_RESPONSIBILITY] in ('10H','10Y')
go			

--NHS Berkshire West CCG: 15A (this includes the merged NHS Newbury and District, NHS North and West Reading, NHS South Reading and NHS Wokingham CCGs) 
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '15A'
WHERE [CCG_RESPONSIBILITY] in ('10M', '10N', '10W', '11D')
go		

--NHS Bristol, North Somerset and South Gloucestershire CCG: code 15C (this includes the merged NHS Bristol, NHS North Somerset, and NHS South Gloucestershire CCGs)
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '15C'
WHERE [CCG_RESPONSIBILITY] in ('11H', '11T', '12A')
go	

-- NHS East Berkshire CCG: 15D (this includes the merged NHS Bracknell and Ascot, NHS Slough and NHS Windsor, Ascot and Maidenhead CCGs)
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '15D'
WHERE [CCG_RESPONSIBILITY] in ('10G', '10T', '11C')
go	

-- NHS Birmingham and Solihull CCG: 15E (this includes the merged NHS Birmingham South Central, NHS Birmingham CrossCity and NHS Solihull CCGs)
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '15E'
WHERE [CCG_RESPONSIBILITY] in ('04X', '05P', '13P')
go	

-- NHS Leeds CCG: 15F (this includes the merged NHS Leeds North, NHS Leeds South and East and NHS Leeds West CCGs)
UPDATE [HES_Analysis_Pseudo].dbo.DIN93304b
SET REAL_CCG = '15f'
WHERE [CCG_RESPONSIBILITY] in ('02v', '03c', '03g')
go	

-------------------------------------------------------------------------------

/* Run Section 3 - Output is matched to CCG code look-up */

select b.CCGApr18CD, Sum(a.Patients) 
from [HES_Analysis_Pseudo].dbo.DIN93304b AS a
left join [LookupsShared].[dbo].[vLKP_CCGApr18] AS b
ON a.REAL_CCG = b.[CCGApr18CDH]
group by b.CCGApr18CD with rollup


-- Notes: One person can have visited the hospital under two CCGs at different
-- time points in the year. These are all valid counts and are not duplicates
-- They may have moved home or GP practice.
-- Not all CCG responsibility codes map against CCG area codes as
-- some codes are for prison, special hubs etc. 
-- However in previous years, this hasn't happened and only the first row has been 
-- selected per patient so we have kept it consistent and done the same on orders
-- of the boss :)
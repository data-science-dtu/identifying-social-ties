/******  Create Lat Lon Column  ******/
SELECT top 200    Right(left(lat_lon,  CHARINDEX(',',lat_lon)-1),CHARINDEX(',',lat_lon)-2),
				left(Right(lat_lon,  len(lat_lon)- CHARINDEX(',',lat_lon)),  len(lat_lon)- CHARINDEX(',',lat_lon)-1),
				Right(left(lat_lon,len(lat_lon)-1),len(lat_lon)-2)
  FROM [Roskilde].[dbo].[tracker];

--alter table [Roskilde].[dbo].[tracker] drop column lat, lon;
--alter table [Roskilde].[dbo].[tracker] add lat float, lon float;
update tracker SET 
	lat = Right(left(lat_lon,  CHARINDEX(',',lat_lon)-1),CHARINDEX(',',lat_lon)-2),
	lon = left(Right(lat_lon,  len(lat_lon)- CHARINDEX(',',lat_lon)),  len(lat_lon)- CHARINDEX(',',lat_lon)-1)
	from tracker


/****** Grid Index ******/
alter table [Roskilde].[dbo].[tracker] add grid_id int;

update tracker SET 
	grid_id = concat(cast((lat-55.609975)/0.000100 as int) ,cast((lon-12.058901)/0.000100 as int))
	from tracker

--create index grid_id on tracker (grid_id)


/******* create time id ********/
alter table [Roskilde].[dbo].[tracker] add time_id varchar(10);

UPDATE tracker SET
 time_id = concat(datepart(day,c_time),'-', datepart(hour,c_time),'-',(DATEPART(MINUTE, [c_time]) / 10))
 from tracker

 create index time_id on tracker(time_id)



 /******* Find Friends ********/
 drop table dbo.friend_list;
WITH TOPTEN AS (
    SELECT *, ROW_NUMBER() 
    over (
        PARTITION BY T.user_a
        order by T.nr_of_occurences DESC
    ) AS RowNo 
     FROM (SELECT a.user_id as user_a,
				 b.user_id as user_b,
				COUNT(*) as nr_of_occurences
			  FROM [Roskilde].[dbo].[tracker] a JOIN
		  Roskilde.dbo.tracker b on a.user_id <> b.user_id 
								and a.grid_id = b.grid_id
								and a.time_id = b.time_id
			GROUP by a.user_id,b.user_id) as T
)
SELECT * 
into dbo.friend_list
FROM TOPTEN WHERE RowNo <= 10

---------- does not count same spot more than once

drop table dbo.friend_list_distinct_grid;
WITH TOPTEN AS (
    SELECT *, ROW_NUMBER() 
    over (
        PARTITION BY T.user_a
        order by T.nr_of_occurences DESC
    ) AS RowNo 
     FROM (SELECT user_a,
				  user_b,
				  
				COUNT(DISTINCT K.grid_id) as nr_of_occurences
			  FROM(select	a.user_id as user_a,
							b.user_id as user_b,
							a.grid_id from
							 
							Roskilde.[dbo].[tracker] a JOIN
							Roskilde.dbo.tracker b on a.user_id <> b.user_id 
								and a.grid_id = b.grid_id
								and a.time_id = b.time_id
			GROUP by a.user_id,b.user_id,a.grid_id,a.time_id) as K
			GROUP BY K.user_a, K.user_b
			) as T
)
SELECT * 
into dbo.friend_list_distinct_grid
FROM TOPTEN WHERE RowNo <= 10

--Does not take into account distinct grid_id
drop table dbo.friend_list;
WITH TOPTEN AS (
    SELECT *, ROW_NUMBER() 
    over (
        PARTITION BY T.user_a
        order by T.nr_of_occurences DESC
    ) AS RowNo 
     FROM (SELECT user_a,
				  user_b,
				  K.grid_id,
				  K.time_id,
				COUNT(*) as nr_of_occurences
			  FROM(select	a.user_id as user_a,
							b.user_id as user_b,
							a.grid_id,
							a.time_id from
							 
							Roskilde.[dbo].[tracker] a JOIN
							Roskilde.dbo.tracker b on a.user_id <> b.user_id 
								and a.grid_id = b.grid_id
								and a.time_id = b.time_id
			GROUP by a.user_id,b.user_id,a.grid_id,a.time_id) as K
			GROUP BY K.user_a, K.user_b
			) as T
)
SELECT * 
into dbo.friend_list
FROM TOPTEN WHERE RowNo <= 10






/**  Time at hours where people meet    **//
/****** Script for SelectTopNRows command from SSMS  
select * from (
select top 100 h.user_a,h.user_b,h.day_time, h.hour_time,count(*) as count_meets from(
select b.user_id as user_a,datepart(day,b.c_time) as day_time,datepart(hour,b.c_time) as hour_time, b.grid_id as grid_id_a,b.time_id as time_id_a,
c.user_id as user_b, c.grid_id as grid_id_c,c.time_id as time_id_b, count(*) as temp from 
(SELECT [accuracy]
      ,[c_time]
      ,[lat_lon]
      ,[user_id]
      ,[grid_index]
      ,[ID]
      ,[lat]
      ,[lon]
      ,[grid_id]
      ,[time_id]
  FROM [Roskilde].[dbo].[tracker]
  ) b inner join
  (	SELECT [accuracy]
      ,[c_time]
      ,[lat_lon]
      ,[user_id]
      ,[grid_index]
      ,[ID]
      ,[lat]
      ,[lon]
      ,[grid_id]
      ,[time_id]
  FROM [Roskilde].[dbo].[tracker]
  ) c on 
		b.user_id <> c.user_id AND
		b.grid_id = c.grid_id AND
		b.time_id = c.time_id 
group by b.user_id ,datepart(day,b.c_time),datepart(hour,b.c_time), b.grid_id,b.time_id,c.user_id , c.grid_id,c.time_id) h
GROUP by h.user_a,h.user_b,h.day_time,h.hour_time) l
pivot
(	
	sum(l.count_meets)
	for l.hour_time IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23])	
	  
) piv
ORDER by piv.user_a,piv.user_b 
******/
drop TABLE meeting_times
select * 
into meeting_times
from (
select h.user_a,h.user_b, h.hour_time,count(*) as count_meets from(
select b.user_id as user_a,datepart(hour,b.c_time) as hour_time, b.grid_id as grid_id_a,b.time_id as time_id_a,
c.user_id as user_b, c.grid_id as grid_id_c,c.time_id as time_id_b, count(*) as temp from 
(SELECT [accuracy]
      ,[c_time]
      ,[lat_lon]
      ,[user_id]
      ,[grid_index]
      ,[ID]
      ,[lat]
      ,[lon]
      ,[grid_id]
      ,[time_id]
  FROM [Roskilde].[dbo].[tracker]
  ) b inner join
  (	SELECT [accuracy]
      ,[c_time]
      ,[lat_lon]
      ,[user_id]
      ,[grid_index]
      ,[ID]
      ,[lat]
      ,[lon]
      ,[grid_id]
      ,[time_id]
  FROM [Roskilde].[dbo].[tracker]
  ) c on 
		b.user_id <> c.user_id AND
		b.grid_id = c.grid_id AND
		b.time_id = c.time_id AND
		Concat(b.user_id, c.user_id) IN (select CONCAT(user_a,user_b) from dbo.friend_list) 

group by b.user_id,datepart(hour,b.c_time), b.grid_id,b.time_id,c.user_id , c.grid_id,c.time_id) h
GROUP by h.user_a,h.user_b,h.hour_time) l
pivot
(	
	sum(l.count_meets)
	for l.hour_time IN ([0],[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23])	
	  
) piv
ORDER by piv.user_a,piv.user_b 
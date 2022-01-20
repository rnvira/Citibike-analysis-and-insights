
create DATABASE citibikes

use citibikes
GO

--DOWN
if exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_bills_ride_id')
    alter table bills drop constraint fk_bills_ride_id
if exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_bikes_bike_warehouse')
    alter table bikes drop constraint fk_bikes_bike_warehouse
if exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_rides_ride_user_id')
    alter table rides drop constraint fk_rides_ride_user_id
if exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_rides_ride_bike_used')
    alter table rides drop constraint fk_rides_ride_bike_used
if exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_rides_ride_end_station_id')
    alter table rides drop constraint fk_rides_ride_end_station_id
if exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_rides_ride_start_station_id')
    alter table rides drop constraint fk_rides_ride_start_station_id
drop table if exists warehouses
drop table if exists bills
drop table if exists bikes
drop table if exists stations
drop table if exists rides
drop table if exists users
GO

--UP
create table users
(
	user_id int identity not null,
	user_firstname varchar(50) not null,
	user_county varchar(50) not null,
	user_type varchar(50) not null,
	user_gender varchar(5) null,
	user_dob date not null,
    user_email varchar(50) not null,
	constraint pk_users_user_id primary key(user_id),
    constraint u_users_user_email unique (user_email)
)

CREATE TABLE rides
(
    ride_id varchar(30) not null,
	ride_started_at DATETIME2(7) not null,
	ride_ended_at DATETIME2(7) not null,
	ride_start_station_id varchar(20) not null,
	ride_end_station_id varchar(20) not null,
    ride_duration TIME(7) not null,
	ride_bike_used int not null,
    ride_user_id int not null,
	constraint pk_rides_ride_id primary key(ride_id)
)

create table stations
(
    station_id varchar(20) not null,
    station_latitude FLOAT not null,
    station_longitude FLOAT not null,
    station_name varchar(50) not null,
    station_max_docks int not null,
    constraint pk_stations_station_id primary key(station_id)
)

create table bikes
(
    bike_id int identity not null,
    bike_type varchar(20) not null,
    bike_make varchar(20) not null,
    bike_model int not null,
    bike_status varchar(20) not null,
    bike_warehouse int not null,
    constraint pk_bikes_bike_id primary key(bike_id)
)

create table bills
(
    bill_id int identity not null,
    bill_ride_id varchar(30) not null,
    bill_rate_per_minute float not null,
    bill_surge_multiplier int not null,
    bill_type_of_payment varchar(50) not null,
    constraint bills_bill_id primary key(bill_id)
)

create table warehouses
(
    warehouse_id int identity not null,
    warehouse_location varchar(50) not null,
    warehouse_name varchar(50) not null,
    warehouse_capacity int not null,
    constraint warehouses_warehouse_id
        primary key(warehouse_id)
)

alter table rides
    add constraint fk_rides_ride_start_station_id foreign key (ride_start_station_id)
        references stations(station_id)
alter table rides
    add constraint fk_rides_ride_end_station_id foreign key (ride_end_station_id)
        references stations(station_id)
alter table rides
    add constraint fk_rides_ride_bike_used foreign key (ride_bike_used)
        references bikes(bike_id)
alter table rides
    add constraint fk_rides_ride_user_id foreign key (ride_user_id)
        references users(user_id)

alter table bikes
    add constraint fk_bikes_bike_warehouse foreign key (bike_warehouse)
        references warehouses(warehouse_id)

alter table bills
    add constraint fk_bills_bill_ride_id foreign key (bill_ride_id)
        references rides(ride_id)
/* QUESTION 1 */
/* WHAT IS THE AVERAGE DURATION OF EACH RIDE AND THE AVERAGE RIDER AGE? */
--SLIDE 7
select 
  cast(cast(avg(cast(cast(ride_duration as datetime) as float)) as datetime) as time) AvgDuration
from rides;

select AVG(DATEDIFF(hour,user_dob,GETDATE())/8766) as AverageRiderAge
from users
GO


/* QUESTION 2 */
/* CREATE PIVOT OF BIKES STATUS BY THE MANUFACTURER NAME TO ASSESS WHICH ONES HAVE BETTER DURABILITY? */
--SLIDE 8
with bikes_by_make as (
    select bike_id, bike_make, bike_status
    from bikes
)
select *
from bikes_by_make pivot(
    count(bike_id)
        for bike_status in (functional, non_functional)
) pivot_query
GO 

with bikes_by_make_model as (
    select bike_id, bike_make, bike_model, bike_status
    from bikes
)
select *
from bikes_by_make_model pivot(
    count(bike_id)
        for bike_status in (functional, non_functional)
) pivot_query
go
/* QUESTION 3 */
--Most popular bike_makes used for rides
--SLIDE 9
select b.bike_make, 
       count(r.ride_id) as ride_count
    from rides as r
        join bikes as b on b.bike_id=r.ride_bike_used
    where datepart(mi,(cast(r.ride_duration as datetime)))>15
    group by b.bike_make
    order by count(r.ride_id) desc

select b.bike_make, 
       count(r.ride_id) as ride_count
    from rides as r
        join bikes as b on b.bike_id=r.ride_bike_used
    where datepart(mi,(cast(r.ride_duration as datetime)))<15
    group by b.bike_make
    order by count(r.ride_id) desc

go

--question 4
--total contribution made by a person towards citibike based on usertype
--customer lifetime value (LTV) for citibike
--SLIDE 10
select distinct top 10 u.user_id, 
        u.user_firstname, 
        u.user_type,
        count(r.ride_user_id) over (partition by u.user_id) as total_rides,
        sum(datepart(mi,(cast(r.ride_duration as datetime)))) over (partition by u.user_id) as total_minutes,
        CASE
            WHEN u.user_type='Subscriber' 
            THEN sum(cast(sum(datepart(mi,(cast(r.ride_duration as datetime)))*b.bill_rate_per_minute*b.bill_surge_multiplier) as decimal(6,2))/1.5) 
                OVER (PARTITION BY u.user_id) 
            WHEN u.user_type='Customer' 
            THEN sum(cast(sum(datepart(mi,(cast(r.ride_duration as datetime)))*b.bill_rate_per_minute*b.bill_surge_multiplier) as decimal(6,2))) 
                OVER (PARTITION BY u.user_id)
        END AS [Life_Time_Value ($)]
        from bills as b
join rides as r on b.bill_ride_id=r.ride_id
join users as u on u.user_id = r.ride_user_id
group by u.user_id,
         u.user_id,
         u.user_type, 
         u.user_firstname,
         r.ride_duration, 
         b.bill_rate_per_minute, 
         b.bill_surge_multiplier,
         r.ride_user_id
order by [Life_Time_Value ($)] desc

--question 5
--which station has the most frequent type of payment
--count of type of payment paid at each station
--SLIDE 11
with paymentType as (
    select s.station_name,
    b.type_of_payment from
    bills as b 
    join rides as r on b.bill_ride_id=r.ride_id
    join stations as s on s.station_id=r.ride_start_station_id
)
select *
from paymentType pivot(
    count(type_of_payment)
        for type_of_payment in ([cash], [Debit/Credit Card],[Digital Wallet/ApplePay])
) pivot_query
GO

--SLIDE 12
/* VIEW */
drop view if exists stations_visited
drop view if exists station_footfall_data
GO

create view stations_visited as(
    select ride_id, ride_start_station_id as ride_station_id
        from rides as strt
    UNION
    select ride_id, ride_end_station_id from rides as dest
)
GO

create view station_footfall_data as (
    select station_id, station_latitude, station_longitude, count(*) as ride_count
    from stations_visited
        join stations as s on station_id=ride_station_id
    group by station_id, station_latitude, station_longitude
)
GO

select * from station_footfall_data
GO

-- COMP3311 19T3 Assignment 2
-- Written by Jonathan Williams z5162987 October 2019

-- Q1 Which movies are more than 6 hours long? 

create or replace view Q1(title) as 
select main_title 
from Titles 
where runtime > 360 and format='movie';


-- Q2 What different formats are there in Titles, and how many of each?

create or replace view Q2(format, ntitles)
as
select t.format, count(t) 
from Titles t 
group by t.format;


-- Q3 What are the top 10 movies that received more than 1000 votes?

create or replace view Q3(title, rating, nvotes)
as
select t.main_title, t.rating, t.nvotes 
from Titles t 
where t.format='movie' and t.nvotes > 1000 
order by t.rating desc, t.main_title 
limit 10;


-- Q4 What are the top-rating TV series and how many episodes did each have?

create or replace view Q4(title, nepisodes)
as
select t.main_title, count(e) as nepisodes 
from Titles t 
inner join Episodes e on (t.id = e.parent_id) 
where t.rating > 0 
group by t.id 
order by t.rating desc, t.main_title 
limit 4;


-- Q5 Which movie was released in the most languages?
--get the max number of languages for any movie (gives one tuple)
create or replace view MaxLang(nlanguages)
as
select count(distinct a.language) as nlanguages
from Titles t
inner join Aliases a on (t.id = a.title_id)
where a.language is not null and t.format='movie'
group by t.main_title
order by count(distinct a.language) desc
limit 1;
--view for title and number of distinct languages
create or replace view TitleNumLanguages(title, nlanguages)
as
select t.main_title, count(distinct a.language) as nlanguages
from Titles t 
inner join Aliases a on (t.id = a.title_id) 
where a.language is not null and t.format='movie'
group by t.main_title;
--get all titles that have the max number of discrete languages
create or replace view Q5(title, nlanguages)
as
select tnl.title, tnl.nlanguages 
from TitleNumLanguages tnl 
where tnl.nlanguages = (select * from MaxLang);


-- Q6 Which actor has the highest average rating in movies that they're known for?

--creates a view of actor names and the title_id they are known for
create or replace view ActorsKnownFor(actor_id, name, title_id)
as
select n.id, n.name, k.title_id 
from Names n 
inner join Known_for k on (n.id = k.name_id)
where k.name_id in (select a.name_id 
                    from Worked_as a 
                    where a.work_role = 'actor')
      and
      k.title_id in (select m.id 
                     from Titles m 
                     where m.format='movie' and m.rating is not null);

--creates a view containing an actor's id and number of movies they are known for
create or replace view NumKnownFor(actor_id, nknownfor)
as
select actor_id, count(title_id)
from ActorsKnownFor
group by actor_id;

create or replace view Q6(name)
as
select akf.name 
from ActorsKnownFor akf
inner join Titles t on (akf.title_id = t.id)
where (select nknownfor from NumKnownFor where actor_id=akf.actor_id) >= 2
group by akf.name
order by avg(t.rating) desc
limit 1;


-- Q7 For each movie with more than 3 genres, show the movie title and a comma-separated list of the genres

create or replace view MovieTitleAndGenre(movie_title, movie_id, genre)
as
select t.main_title, t.id, g.genre
from Titles t 
inner join Title_genres g on (t.id = g.title_id)
where t.format = 'movie';

create or replace view MovieTitleNumGenres(movie_id, ngenres)
as
select movie_id, count(genre)
from MovieTitleAndGenre
group by movie_id;

create or replace view Q7(title,genres)
as
select tg.movie_title, string_agg(tg.genre, ',')
from MovieTitleAndGenre tg
where (select ngenres from MovieTitleNumGenres ng where ng.movie_id=tg.movie_id) > 3 
group by tg.movie_title, tg.movie_id;

-- Q8 Get the names of all people who had both actor and crew roles on the same movie

--get the id of all people who are both actors and crew members on the same movie
create or replace view ActorAndCrew(name_id, title_id)
as
select ar.name_id,ar.title_id 
from Actor_roles ar 
inner join Crew_roles cr on (ar.name_id = cr.name_id 
                         and ar.title_id = cr.title_id) 
group by ar.name_id, ar.title_id;

--get the names of these people
create or replace view Q8(name)
as
select n.name
from ActorAndCrew aac
inner join Titles t on (t.id = aac.title_id and t.format = 'movie')
inner join Names n on (n.id = aac.name_id)
group by n.name;

-- Q9 Who was the youngest person to have an acting role in a movie, and how old were they when the movie started?

--get tuples for all actors birth year and the start year for the movies they've been in
--format will be later used to group by
create or replace view ActorNameTitle(format, start_year, birth_year, name)
as
select t.format, t.start_year, n.birth_year, n.name
from Actor_roles ar 
inner join Titles t on (t.id = ar.title_id and t.format = 'movie') 
inner join Names n on (n.id = ar.name_id);

--gets the youngest age for acting in a movie, gets a single value
create or replace view MinActingAge(age)
as
select min(start_year-birth_year) as age
from ActorNameTitle
group by format;

--get the names of anyone who acted in a movie at this youngest age
create or replace view Q9(name,age)
as
select ant.name, min(ant.start_year-ant.birth_year) as age
from ActorNameTitle ant
where (ant.start_year-ant.birth_year) = (select * from MinActingAge)
group by ant.name;

-- Q10 Write a PLpgSQL function that, given part of a title, shows the full title and the total size of the cast and crew

create or replace function
	Q10(partial_title text) returns setof text
as $$
declare
   r record;
   n integer := 0;
   unique_title text;
begin
   --view which has each title_id in the db and a name_id of someone who worked on the title
   --each title_id, name_id pair is distinct
   execute '
   create or replace view TitleCastAndCrew(title_id, name_id)
   as
   select t.id as title_id, ar.name_id as name_id
   from Titles t
   join Actor_roles ar on (t.id = ar.title_id and t.main_title ilike ''%'' || '''||partial_title||''' || ''%'')
   union
   select t.id as title_id, cr.name_id as name_id
   from Titles t
   join Crew_roles cr on (t.id = cr.title_id and t.main_title ilike ''%''|| '''||partial_title||''' || ''%'')
   union
   select t.id as title_id, p.name_id as name_id
   from Titles t
   join Principals p on (t.id = p.title_id and t.main_title ilike ''%'' || '''||partial_title||''' || ''%'')';
   
   --count the number for entries for each distinct title_id in TitleCastAndCrew view
   for r in 
      select tcc.title_id, count(tcc.name_id) as tcc_count
      from TitleCastAndCrew tcc
      group by tcc.title_id
   loop
      --find the associated main_title for a tite_id
      unique_title:= (select t.main_title from Titles t where t.id = r.title_id);
      n:= n+1;
      return next unique_title||' has '||r.tcc_count||' cast and crew';
   end loop;
   --if no matches found
   if(n<1) then
      return next 'No matching titles';
   end if;
end;
$$ language plpgsql;


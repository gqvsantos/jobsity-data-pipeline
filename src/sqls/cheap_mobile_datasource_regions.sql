SELECT region
FROM public.hist_trip_data
WHERE datasource = 'cheap_mobile'
GROUP BY region; --using group by instead of distinct.
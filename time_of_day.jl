using SQLite, DataFrames, PyPlot

const MINS_IN_HOUR = 60
const HOURS_IN_DAY = 24

nullable_to_array(nullable_ar) = map(dat -> dat.value, nullable_ar).values

## Parse, combine and return date_string and time_string
## to return them as a single timestamp.
function combine_date_time(date_string, time_string)
    month_str, day, year = split(replace(date_string, ",", " "))
    hourmin, ampm = split(time_string)
    hour, min = map(n -> parse(Int, n), split(hourmin, ":"))
    hour = (hour + if lowercase(ampm) == "pm" 12 else 0 end) % HOURS_IN_DAY
    timestamp = DateTime(parse(Int, year),
                         Dates.MONTHTOVALUE["english"][month_str],
                         parse(Int, day),
                         hour,
                         min)
end    

emailsdb = SQLite.DB("../output/database.sqlite")
q = readall(open("pull_emails.sql"))
emails = SQLite.query(emailsdb, q)

for n in names(emails)
    emails[n] = nullable_to_array(emails[n])
end

###### Convert date and time information into DateTimes. ######
month_names = collect(keys(Dates.MONTHTOVALUE["english"]))
date_regex = Regex("(" * join(month_names, "|") * ") \\d{1,2}[, ]*\\d{4}")
time_regex = r"[012]?\d:\d\d [AP]M"

# missing 49 dates and 0 times with current regexes
dates = map(s -> match(date_regex, lowercase(s)), emails[:timesent])
times = map(s -> match(time_regex, s), emails[:timesent])

good_date_ind = convert(Array{Bool,1}, map(d -> d != nothing, dates))
good_time_ind = convert(Array{Bool,1}, map(d -> d != nothing, times))
both_good_ind = map(&, good_date_ind, good_time_ind)

dates = map(regex_match -> regex_match.match, dates[both_good_ind])
times = map(regex_match -> regex_match.match, times[both_good_ind])
emails = emails[both_good_ind, :]

emails[:timestamp] = map(i -> combine_date_time(dates[i], times[i]),
                         1:size(dates)[1])
emails[:decimal_time_sent] = map(t -> Dates.hour(t) + (Dates.minute(t) / MINS_IN_HOUR), emails[:timestamp])
######

## https://groups.google.com/forum/#!topic/julia-users/6sADBFLsOcA

minute_counts = countmap(emails[:decimal_time_sent]) |>
                hsh -> convert(DataFrame, hcat(collect(keys(hsh)),
                                               collect(values(hsh)))) |>
                d -> sort(d, cols = :x1)                                  

#### plot clock
jake   = emails[emails[:name_from] .== "Jake Sullivan", :]
cheryl = emails[emails[:name_from] .== "Cheryl Mills", :]

ax = plt[:subplot](111, polar = "true")
plt[:setp](ax[:get_yticklabels](), visible = false)
ax[:set_xticks](linspace(0, 2π, HOURS_IN_DAY + 1))
ax[:set_xticklabels](0 : HOURS_IN_DAY+1)
ax[:set_theta_direction](-1)
ax[:set_theta_offset](π / 2)

people = unique(emails[:name_from])[1:5, :]
graphical_step_size = 1.0 / length(people)
graphical_step_iter = countfrom(0, graphical_step_size)

people_colors = palette("RdYlBu", 11)
#curr_el = start(graphical_step_iter)

for (person, color, loc) in zip(people, people_colors, graphical_step_iter)
    #curr_el = next(graphical_step_iter, curr_el)[2]    
    person_times = emails[emails[:name_from] .== person, :]
    ax[:bar](left = person_times[:decimal_time_sent],
             height = fill(graphical_step_size, size(person_times)[1]),
             width = 1 / (MINS_IN_HOUR * HOURS_IN_DAY),
             bottom = loc, #curr_el
             edgecolor = "#C46536")
end
plt[:ylim](0,1)
plt[:show]() 


## Next let's do a sort of overlaid bar chart with the to's and the from's.




###### Collect and plot various summary information

hourcounts = countmap(map(Dates.hour, emails[:timestamp])) |>
             hsh -> convert(DataFrame, hcat(collect(keys(hsh)),
                                            collect(values(hsh)))) |>
             d -> sort(d, cols = :x1)                                   

function plotbar(df, idcol, countcol, rot)
    PyPlot.bar(df[idcol], df[countcol], color = "#0f87bf", align = "center", alpha = 0.4)
    xticks(1:size(df[idcol])[1], rotation = rot)
end

function bar_counts(df, col, rot)
    counts = sort(by(df, col, nrow), cols = :x1)
    plotbar(counts, col, :x1, rot)
end

bar_counts(emails, :name_from, "vertical")

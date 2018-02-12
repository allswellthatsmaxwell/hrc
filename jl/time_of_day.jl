using SQLite, DataFrames, PyPlot, Plots

const MINS_IN_HOUR = 60
const HOURS_IN_DAY = 24
const MONTH_INDICES = 1:12

## Returns a hashmap mapping lowercase name of month to month index
## (e.g. february => 2)
function get_month_names()
    Dict(lowercase(Dates.monthname(i)) => i for i in MONTH_INDICES)
end

## Parse, combine and return date_string and time_string
## to return them as a single timestamp.
function combine_date_time(date_string, time_string)
    month_str, day, year = split(replace(date_string, ",", " "))
    hourmin, ampm = split(time_string)
    hour, min = map(n -> parse(Int, n), split(hourmin, ":"))
    hour = (hour + if lowercase(ampm) == "pm" 12 else 0 end) % HOURS_IN_DAY
    timestamp = DateTime(parse(Int, year),
                         get_month_names()[month_str],
                         parse(Int, day),
                         hour,
                         min)
end

## Returns a regex to try and match the most dates
## possible in the dataset.
function make_date_regex(month_names)
    Regex("(" * join(month_names, "|") * ") \\d{1,2}[, ]*\\d{4}")    
end

## Returns a regex to try and match the most times
## possible in the dataset.
function make_time_regex() r"[012]?\d:\d\d [AP]M" end

## Returns a boolean array where element i is true if both
##  dates[i] and times[i] were not nothing
function get_rowinds_with_matchable_datetime(dates, times)
    good_date_ind = convert(Array{Bool,1}, map(d -> d != nothing, dates))
    good_time_ind = convert(Array{Bool,1}, map(d -> d != nothing, times))
    both_good_ind = map(&, good_date_ind, good_time_ind)
    both_good_ind
end

## Maps timestamp to a numeric of the form h.p..., where
## h the number of hours since midnight and p is the percentage
## of the hour that had passed (e.g. 30 minutes is 0.5 hours).
## So e.g. 6:45PM April 3rd 2018 becomes 18.75.
function timestamp_to_decimal(timestamp)
    Dates.hour(timestamp) + (Dates.minute(timestamp) / MINS_IN_HOUR)
end

## Returns a dataframe with one row per time of day that occurred,
## and a count of how many times it occurred.
function time_of_day_counts(decimal_times)
    counts = StatsBase.countmap(decimal_times)
    counts_frame = convert(DataFrame, hcat(collect(keys(counts)),
                                           collect(values(counts))))
    names!(counts_frame, [:time, :count])
    sort(counts_frame, cols = :time)
end

## Attempts to parse :timesent in each row of emails_frame
## into a datetime, puts it in the (new) column :timestamp,
## and returns the dataframe. Rows where :timesent cannot
## be parsed are dropped.
function get_rows_with_coherent_datetime(emails_frame)
    date_regex = make_date_regex(keys(get_month_names()))
    time_regex = make_time_regex()

    # still missing some dates and times with current regexes
    date_matches = map(s -> match(date_regex, lowercase(s)),
                       emails_frame[:timesent])
    time_matches = map(s -> match(time_regex, s),
                       emails_frame[:timesent])

    both_good_ind = get_rowinds_with_matchable_datetime(date_matches,
                                                        time_matches)

    dates = map(regex_match -> regex_match.match, date_matches[both_good_ind])
    times = map(regex_match -> regex_match.match, time_matches[both_good_ind])
    
    timestampable_emails = emails_frame[both_good_ind, :]
    timestampable_emails[:timestamp] = map(combine_date_time, dates, times)
    timestampable_emails
end

## Draws a plot that looks like a clock (without hands; hours 0 - 23).
function get_clock_base_plot()    
    ax = plt[:subplot](111, polar = "true")
    plt[:setp](ax[:get_yticklabels](), visible = false)
    ax[:set_xticks](linspace(0, 2π, HOURS_IN_DAY + 1))
    ax[:set_xticklabels](0:(HOURS_IN_DAY - 1))
    ax[:set_theta_direction](-1)
    ax[:set_theta_offset](π / 2)
    ax 
end

function plot_email_times(ax, decimal_times)
    ax[:bar](left = decimal_times,
             height = fill(1, length(decimal_times)),##fill(graphical_step_size, size(person_times)[1]),
             width = 1 / (MINS_IN_HOUR * HOURS_IN_DAY),
             bottom = 0,##loc, #curr_el
             edgecolor = "#C46536")
end

function plot_email_times(decimal_times)
    plot_email_times(get_clock_base_plot(), decimal_times)
end
    
emailsdb = SQLite.DB("../data/database.sqlite")
q = readstring(open("../sql/pull_emails.sql"))
all_emails = SQLite.query(emailsdb, q)

emails = get_rows_with_coherent_datetime(all_emails)

emails[:decimal_time_sent] = map(timestamp_to_decimal, emails[:timestamp])

time_counts = time_of_day_counts(emails[:decimal_time_sent])

jake = emails[emails[:name_from] .== "Jake Sullivan", :]
cheryl = emails[emails[:name_from] .== "Cheryl Mills", :]

plot_email_times(jake[:decimal_time_sent])
plot_email_times(cheryl[:decimal_time_sent])

## Still a mess beyond here! ###################################################

people = unique(emails[:name_from])[1:5, :]
graphical_step_size = 1.0 / length(people)
graphical_step_iter = countfrom(0, graphical_step_size)

people_colors = Colors.distinguishable_colors(length(people) + 1)[2:end]
test_colors = ["#2a2dff","#ff81fa","#00e399","#3c3c3c","#ff1f1f"]
people_colors = test_colors
#curr_el = start(graphical_step_iter)

ax = get_clock_base_plot()
for (person, color, loc) in zip(people, people_colors, graphical_step_iter)
    #curr_el = next(graphical_step_iter, curr_el)[2]
    person_times = emails[emails[:name_from] .== person, :]
    ax[:bar](left = person_times[:decimal_time_sent],
             height = fill(graphical_step_size, size(person_times)[1]),
             width = 1 / (MINS_IN_HOUR * HOURS_IN_DAY),
             bottom = loc, #curr_el
             edgecolor = color)
end
plt[:ylim](0,1)
plt[:show]()


## Next let's do a sort of overlaid bar chart with the to's and the from's.




###### Collect and plot various summary information

hourcounts = StatsBase.countmap(map(Dates.hour, emails[:timestamp])) |>
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

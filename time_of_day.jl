using SQLite, DataFrames

nullable_to_array(nullable_ar) = map(dat -> dat.value, nullable_ar).values

## Parse, combine and return date_string and time_string
## to return them as a single timestamp.
function combine_date_time(date_string, time_string)
    month_str, day, year = split(replace(date_string, ",", " "))
    hourmin, ampm = split(time_string)
    hour, min = map(n -> parse(Int, n), split(hourmin, ":"))
    hour = hour + if (lowercase(ampm) == "pm" && hour != 12) 12 else 0 end
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
######


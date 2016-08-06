using SQLite

f(x::Int) = x + 1
nullable_to_array(ar) = map(dat -> dat.value, ar).values
colapply(fn, df) = convert(DataFrame, colwise(fn, df))

emailsdb = SQLite.DB("../output/database.sqlite")
senttimes = SQLite.query(emailsdb, 
                         "select ExtractedFrom, ExtractedDateSent from emails;")
names!(senttimes, [:sender, :timesent])
senttimes[:sender]     = nullable_to_array(senttimes[:sender])
senttimes[:timesent] = nullable_to_array(senttimes[:timesent])

rows_with_names = map(s -> length(s) > 0, senttimes[:sender])
rows_with_times = map(timestamp -> ismatch(r"\d:\d\d [AP]M", timestamp), senttimes[:timesent])

senttimes = senttimes[map(&, rows_with_names, rows_with_times), :]

times = map(s -> match(r"[012]?\d:\d\d [AP]M", s), senttimes[:timesent])


# Great! Only B6 missed. Now need to normalize names. Start by replacing periods with ", ".
unique_names = senttimes[convert(DataArray{Bool, 1},
                                 map(s -> s == nothing ? true : false,
                                     map(s -> match(r"[A-z]+[.,]? ?[A-z]+|^H", s),
                                         senttimes[:sender]))),
                         :]

# still have 359 misses with the regex below: sum(map(s -> s == nothing ? 1 : 0, map(s -> match(r"[A-z]+,? [A-z]+|^H", s), senttimes[1])))
#unique_names = unique(map(r -> r == nothing ? nothing : r.match,
#                          map(s -> match(r"[A-z]+,? [A-z]+|^H", s),
#                              senttimes[1]))) # incomplete

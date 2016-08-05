using SQLite

f(x::Int) = x + 1
nullable_to_array(ar) = map(dat -> dat.value, ar).values

senttimes = begin
    emailsdb = SQLite.DB("../output/database.sqlite")
    senttimes, colnames = SQLite.query(emailsdb, 
                                       "select extractedfrom, ExtractedDateSent from emails;") |>
                          dt -> (dt.data, map(symbol, dt.schema.header))
    senttimes = hcat(nullable_to_array(senttimes[1]),
                     nullable_to_array(senttimes[2]))
    rows_with_names = map(s -> length(s) > 0,
                          senttimes[:, 1])
    rows_with_times = map(timestamp -> ismatch(r"\d:\d\d [AP]M", timestamp),
                          senttimes[:, 2])
    senttimes = convert(DataFrame,
                        senttimes[map(&, rows_with_names, rows_with_times), :])
    names!(senttimes, colnames)
end

times = map(s -> match(r"[012]?\d:\d\d [AP]M", s), senttimes[:ExtractedDateSent])


# Great! Only B6 missed. Now need to normalize names. Start by replacing periods with ", ".
unique_names = senttimes[convert(DataArray{Bool, 1},
                                 map(s -> s == nothing ? true : false,
                                     map(s -> match(r"[A-z]+[.,]? ?[A-z]+|^H", s),
                                         senttimes[1]))),
                         :]

# still have 359 misses with the regex below: sum(map(s -> s == nothing ? 1 : 0, map(s -> match(r"[A-z]+,? [A-z]+|^H", s), senttimes[1])))
#unique_names = unique(map(r -> r == nothing ? nothing : r.match,
#                          map(s -> match(r"[A-z]+,? [A-z]+|^H", s),
#                              senttimes[1]))) # incomplete

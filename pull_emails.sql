
select distinct 
       sender_persons.name      as name_from,
       receiver_persons.name    as name_to,
       emails.ExtractedDateSent as timesent,
       case when sender_persons.name     = 'Hillary Clinton' then 1 else 0 end as from_hrc,
       case when receiver_persons.name   = 'Hillary Clinton' then 1 else 0 end as to_hrc
from emails
join emailReceivers           on emailReceivers.emailID  = emails.id
join persons receiver_persons on emailReceivers.personID = receiver_persons.id
join persons sender_persons   on emails.senderPersonID   = sender_persons.id
where name_from = 'Hillary Clinton' or name_to = 'Hillary Clinton'

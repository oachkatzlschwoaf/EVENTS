#!/bin/sh

# 1. Grab events
./grabbers/grab_kassir.pl;
./grabbers/grab_concert.pl;
./grabbers/grab_ponominalu.pl;
./grabbers/grab_parter.pl;
./grabbers/grab_ticketland.pl;
./grabbers/grab_redkassa.pl;
./grabbers/grab_biletmarket.pl;
./grabbers/grab_afisha.pl;

# 1.1. August fix (TODO: remove in august)
./util/august_fix.pl;

# 2. Grab tickets 
./other/get_tickets.pl;

# 3. Check provider events health
./other/check_events_health.pl;

# 4. Total stat 
./other/global_stat.pl;

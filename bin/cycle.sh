#!/bin/sh

# 1. Grab events
./grabbers/grab_kassir.pl
./grabbers/grab_concert.pl;

# 2. Glue 
./glue/glue_places.pl;
./glue/glue_internal.pl;

# 3. Make index
./other/make_internal_index.pl;

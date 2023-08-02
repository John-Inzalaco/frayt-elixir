#!/bin/bash
pg_restore -c -O -Ft -U $DB_USER -d $DATABASE -h $DB_HOST $DB_FILE
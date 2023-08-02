#!/bin/bash
pg_dump -Ft -h $DB_HOST -d $DATABASE -U $DB_USER -f $DB_FILE
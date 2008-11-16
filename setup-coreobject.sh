#!/bin/sh 
#
# Add a PostgreSQL role for the current user with the right to create new 
# databases
#

sudo -u postgres createuser --no-superuser --no-createrole --createdb $USER
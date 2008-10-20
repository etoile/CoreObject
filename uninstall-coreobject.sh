#!/bin/sh 
#
# Delete CoreObject related databases bound to PostgreSQL role for the current 
# user
#

dropdb --echo coreobject_$USER
dropdb --echo coreobjecttest
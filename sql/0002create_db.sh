#!/bin/sh


if !(test "$USER" = "postgres"); then
	echo "ERROR. You should run this using the postgres user ID."
	echo "   sudo -u postgres $0"
fi
createdb shardsvrdb

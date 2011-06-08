#!/bin/sh
# aStor2 -- storage area network configurable via Web-interface
# Copyright (C) 2009-2011 ETegro Technologies, PLC
#                         Sergey Matveev <stargrave@stargrave.org>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

iqns_stop_all
run_clearing
run_lua single_lvm
iqns_start_all

jobfile=`mktemp`
cat jobfile.fio > $jobfile
dev=`devs_get`
echo "filename=$dev" >> $jobfile
$FIO $jobfile | log_save fio_result
rm -f $jobfile

iqns_stop_all

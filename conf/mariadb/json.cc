# Copyright (C) 2017 MariaDB Corporation.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

# Rough imitation of OLTP-read-write test (sysbench-like)


# ,OrderBy (MDEV-12363)

$combinations = [
	[
	'
		--no-mask
		--seed=time
		--duration=600
		--queries=100M
		--reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock
		--validators=TransformerNoComparator
		--transformers=ConvertLiteralsToDyncols,ConvertLiteralsToSubqueries,ConvertLiteralsToVariables,ConvertTablesToDerived,ConvertTablesToViews,Count,Distinct,ExecuteAsCTE,ExecuteAsDeleteReturning,ExecuteAsDerived,ExecuteAsExecuteImmediate,ExecuteAsFunctionTwice,ExecuteAsInsertSelect,ExecuteAsPreparedTwice,ExecuteAsSelectItem,ExecuteAsSPTwice,ExecuteAsTrigger,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsWhereSubquery,Having
		--mysqld=--log_bin=mysql-bin
		--mysqld=--log_output=FILE
		--grammar=conf/mariadb/json.yy
		--skip-gendata
	'],
	[
		'',
		'--rpl_mode=row --mysqld=--binlog_format=row',
		'--rpl_mode=statement --mysqld=--binlog_format=statement',
		'--rpl_mode=mixed --mysqld=--binlog_format=mixed'
	],
	[
		'--mysqld=--character-set-server=latin1',
		'--mysqld=--character-set-server=utf8',
		'--mysqld=--character-set-server=utf8mb4'
	],
	[
		'--threads=1',
		'--threads=2',
		'--threads=4',
		'--threads=8'
	]
];


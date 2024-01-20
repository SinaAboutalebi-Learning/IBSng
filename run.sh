#!/bin/bash

systemctl start postgresql
/usr/local/IBSng/ibs.py
systemctl start httpd

chown  -R apache:apache /var/www/html
chown  -R postgres:postgres /var/lib/pgsql

exec tail -f /var/log/httpd/error_log_ibs

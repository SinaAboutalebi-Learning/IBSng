FROM centos:systemd

SHELL ["/bin/bash", "-c"]
EXPOSE 80
RUN yum install -y httpd postgresql postgresql-server postgresql-python php perl nano wget sed tar bzip2 python\
    && yum clean all

RUN wget https://netcologne.dl.sourceforge.net/project/ibsng/IBSng-A1.24.tar.bz2 --no-check-certificate \
    && tar -xvjf IBSng-A1.24.tar.bz2 -C /usr/local \
    && rm IBSng-A1.24.tar.bz2

ENV docker_systemctl_replacement="https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/v1.4.4147/files/docker/systemctl.py"
RUN wget "${docker_systemctl_replacement}" --output-document=/usr/bin/systemctl

ADD ibs.web.conf /etc/httpd/conf.d/ibs.web.conf

USER root
RUN /usr/local/IBSng/core/defs_lib/defs2sql.py -i /usr/local/IBSng/core/defs_lib/defs_defaults.py /usr/local/IBSng/db/defs.sql 1>/dev/null 2>/dev/null
RUN mkdir /var/log/IBSng && chmod 770 /var/log/IBSng
RUN cp -f /usr/local/IBSng/addons/apache/ibs.conf /etc/httpd/conf.d && chown root:apache /var/log/IBSng
RUN chown apache /usr/local/IBSng/interface/smarty/templates_c
RUN cp -f /usr/local/IBSng/addons/logrotate/IBSng /etc/logrotate.d
RUN cp -f /usr/local/IBSng/init.d/IBSng.init.redhat /etc/init.d/IBSng
RUN cp -rf /usr/local/IBSng/interface/* /var/www/html
RUN /sbin/chkconfig IBSng on

RUN sed -i 's|#ServerName www.example.com:80|ServerName 127.0.0.1|g' /etc/httpd/conf/httpd.conf \
    && sed -i '1i#coding:utf-8' /usr/local/IBSng/core/lib/IPy.py \
    && sed -i '1i#coding:utf-8' /usr/local/IBSng/core/lib/mschap/des_c.py


USER postgres
ENV PGDATA="/var/lib/pgsql/data"

RUN initdb
RUN echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf
RUN echo 'host	all	all	127.0.0.1/0	trust' >> /var/lib/pgsql/data/pg_hba.conf


RUN pg_ctl -D ${PGDATA} start && \
    sleep 25 && \
    createdb IBSng && \
    createuser ibs && \
    psql -d IBSng < /usr/local/IBSng/db/tables.sql && \
    psql -d IBSng < /usr/local/IBSng/db/functions.sql && \
    psql -d IBSng < /usr/local/IBSng/db/initial.sql && \
    psql -d IBSng < /usr/local/IBSng/db/defs.sql && \
    psql -d IBSng -c "GRANT SELECT ON TABLE defs TO ibs;"| \
    psql -d IBSng -c "GRANT SELECT ON TABLE admins TO ibs;" | \
    psql -d IBSng -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO ibs;" | \
    psql -d IBSng -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ibs;" | \
    #psql -d IBSng -c "GRANT CREATE ON SCHEMA public TO ibs;" | \
    #psql -d IBSng -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ibs;" | \
    #psql -d IBSng -c "GRANT USAGE, SELECT, UPDATE ON SEQUENCE ras_id_seq TO ibs;" | \
    #psql -d IBSng -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ibs;" | \
    #psql -c "GRANT ALL PRIVILEGES ON DATABASE IBSng TO ibs;" | \
    psql -d IBSng -c "ALTER USER ibs WITH PASSWORD 'N53qTn1bc3';" | \
    psql -d IBSng -c "SELECT lanname FROM pg_language WHERE lanname = 'plpgsql'" | \
    grep -q "plpgsql" || createlang plpgsql IBSng 


USER root 
RUN systemctl start postgresql \
    && systemctl start httpd \
    && /usr/local/IBSng/ibs.py

RUN sed -i '1idate.timezone ="Asia/Tehran"' /etc/php.ini 
RUN systemctl restart httpd

ADD run.sh /run.sh
RUN chmod +x /run.sh 

CMD ["/run.sh"]
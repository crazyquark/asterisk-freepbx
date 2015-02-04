#asterisk docker file for unraid 6
FROM phusion/baseimage:0.9.15
MAINTAINER marc brown <marc@22walker.co.uk>

# Set correct environment variables.
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV ASTERISKUSER asterisk
ENV ASTERISKVER 13.1
ENV FREEPBXVER 12.0.3
ENV ASTERISK_DB_PW pass123
ENV AUTOBUILD_UNIXTIME 1418234402
# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

#Install packets that are needed
RUN apt-get update && apt-get install -y build-essential curl libgtk2.0-dev linux-headers-`uname -r` openssh-server apache2 mysql-server mysql-client bison flex php5 php5-curl php5-cli php5-mysql php-pear php-db php5-gd curl sox libncurses5-dev libssl-dev libmysqlclient-dev mpg123 libxml2-dev libnewt-dev sqlite3 libsqlite3-dev pkg-config automake libtool autoconf git subversion unixodbc-dev uuid uuid-dev libasound2-dev libogg-dev libvorbis-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev libspandsp-dev wget sox mpg123 libwww-perl php5 php5-json libiksemel-dev lamp-server^

#Add user
# grab gosu for easy step-down from root
RUN groupadd -r $ASTERISKUSER && useradd -r -g $ASTERISKUSER $ASTERISKUSER \
  && mkdir /var/lib/asterisk && chown $ASTERISKUSER:$ASTERISKUSER /var/lib/asterisk \
  && usermod --home /var/lib/asterisk $ASTERISKUSER \
  && rm -rf /var/lib/apt/lists/* \
  && curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.1/gosu' \
  && chmod +x /usr/local/bin/gosu \
  && apt-get purge -y

#Install Pear DB
RUN pear uninstall db && pear install db-1.7.14

#build pj project
#build jansson
WORKDIR /temp/src/
RUN git clone https://github.com/asterisk/pjproject.git \
  && git clone https://github.com/akheron/jansson.git \
  && cd /temp/src/pjproject \
  && ./configure --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr \
  && make dep \
  && make \
  && make install \
  && cd /temp/src/jansson \
  && autoreconf -i \
  && ./configure \
  && make \
  && make install
  
# Download asterisk.
# Currently Certified Asterisk 13.1.
RUN curl -sf -o /tmp/asterisk.tar.gz -L http://downloads.asterisk.org/pub/telephony/certified-asterisk/certified-asterisk-13.1-current.tar.gz

# gunzip asterisk
RUN mkdir /tmp/asterisk
RUN tar -xzf /tmp/asterisk.tar.gz -C /tmp/asterisk --strip-components=1
WORKDIR /tmp/asterisk

# make asterisk.
ENV rebuild_date 2015-01-29
# Configure
RUN ./configure 1> /dev/null
# Remove the native build option
RUN make menuselect.makeopts
RUN sed -i "s/BUILD_NATIVE//" menuselect.makeopts
# Continue with a standard make.
RUN make 1> /dev/null
RUN make install 1> /dev/null
RUN make config
RUN ldconfig  

 RUN cd /var/lib/asterisk/sounds \
  && wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz \
  && tar xfz asterisk-extra-sounds-en-wav-current.tar.gz \
  && rm -f asterisk-extra-sounds-en-wav-current.tar.gz \
  && wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz \
  && tar xfz asterisk-extra-sounds-en-g722-current.tar.gz \
  && rm -f asterisk-extra-sounds-en-g722-current.tar.gz \
  && chown $ASRERISKUSER. /var/run/asterisk \
  && chown -R $ASTERISKUSER. /etc/asterisk \
  && chown -R $ASTERISKUSER. /var/lib/asterisk \
  && chown -R $ASTERISKUSER. /var/log/asterisk \
  && chown -R $ASTERISKUSER. /var/spool/asterisk \
# && chown -R $ASTERISKUSER. /usr/lib/asterisk \
  && rm -rf /var/www/html

#mod to apache
#Setup mysql
RUN sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php5/apache2/php.ini \
  && cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
  && sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
  && service apache2 restart \
  && /etc/init.d/mysql start \
  && mysqladmin -u root create asterisk \
  && mysqladmin -u root create asteriskcdrdb \
  && mysql -u root -e "GRANT ALL PRIVILEGES ON asterisk.* TO asterisk@localhost IDENTIFIED BY 'pass123';" \
  && mysql -u root -e "GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO asterisk@localhost IDENTIFIED BY 'pass123';" \
  && mysql -u root -e "flush privileges;"

WORKDIR /tmp
RUN wget http://mirror.freepbx.org/freepbx-$FREEPBXVER.tgz \
  && tar vxfz freepbx-$FREEPBXVER.tgz \
  && cd /tmp/freepbx \
  && /etc/init.d/mysql start \
  && /usr/sbin/asterisk \
  &&  ./install_amp --installdb --username=asterisk --password=pass123 \
 # && amportal chown \
 # && amportal reload \
  && amportal a ma installall \
  && amportal a restart \
  && amportal a ma refreshsignatures \
  && amportal chown \
  && ln -s /var/lib/asterisk/moh /var/lib/asterisk/mohmp3 \
  && amportal restart

EXPOSE 5060

CMD asterisk -f

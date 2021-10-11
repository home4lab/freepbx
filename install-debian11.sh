
echo ""
echo " === Install all the necessary packages === "
echo ""

apt install -y apache2 mariadb-server mariadb-client php php-curl php-cli php-pdo php-mysql php-pear php-gd php-mbstring php-intl php-bcmath curl sox mpg123 lame ffmpeg sqlite3 git unixodbc sudo dirmngr postfix asterisk odbc-mariadb php-ldap nodejs npm pkg-config libicu-dev


echo ""
echo " === Prepare Asterisk === "
echo ""

systemctl stop asterisk
systemctl disable asterisk
cd /etc/asterisk
mkdir DIST
mv * DIST
cp DIST/asterisk.conf .
sed -i 's/(!)//' asterisk.conf
touch modules.conf
touch cdr.conf


echo ""
echo " === Configure Apache web server === "
echo ""

sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini
sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
a2enmod rewrite
systemctl restart apache2
rm /var/www/html/index.html

echo ""
echo " === Configure ODBC === "
echo ""

cat <<EOF > /etc/odbcinst.ini
[MySQL]
Description = ODBC for MySQL (MariaDB)
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
FileUsage = 1
EOF

cat <<EOF > /etc/odbc.ini
[MySQL-asteriskcdrdb]
Description = MySQL connection to 'asteriskcdrdb' database
Driver = MySQL
Server = localhost
Database = asteriskcdrdb
Port = 3306
Socket = /var/run/mysqld/mysqld.sock
Option = 3
EOF

echo ""
echo " === Install FreePBX === "
echo ""

cd /usr/local/src
wget http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
tar zxvf freepbx-16.0-latest.tgz
cd /usr/local/src/freepbx/
./start_asterisk start
./install -n

echo ""
echo " === Get the rest of the modules === "
echo ""

fwconsole ma installall

echo ""
echo " === Apply the current configuration === "
echo ""

fwconsole reload

echo ""
echo " === Set symlinks to the correct sound files === "
echo ""

cd /usr/share/asterisk
mv sounds sounds-DIST
ln -s /var/lib/asterisk/sounds sounds

echo ""
echo " === Perform a restart to load all Asterisk modules that had not yet been configured === "
echo ""

fwconsole restart

echo ""
echo " === Set up systemd (startup script) === "
echo ""

cat <<EOF > /etc/systemd/system/freepbx.service
[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable freepbx

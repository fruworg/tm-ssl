# Скачиваем софт по ссылкам ниже
# https://slproweb.com/download/Win64OpenSSL-3_0_1.exe
# https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.76-installer.msi
# https://winscp.net/download/WinSCP-5.19.5-Setup.exe

# Разрешаем запуск скриптов
# Set-ExecutionPolicy Unrestricted -force

# Делаем тестовое подключение
# plink root@192.168.10.10 -pw xxXX1234

# Запускаем скрипт
# .\tm-ssl.ps1

# Если Астра, то $puser = "$luser"
$luser = "iwtm"
$puser = "root"

# Указываем пути
$path = "C:\Program Files\OpenSSL-Win64\bin"
$hpath = "C:\ts-out"
$wpath = "C:\Program Files (x86)\WinSCP"
$lpath = "$hpath\linux"
$cpath = "$hpath\certs"

# Названия сертификатов
$root = "root"
$server = "iwtm"
$client = "arm"

# Данные
$cnf = "iw"
$ip = "192.168.10.10"
$dns = "iwtm"
$password = "xxXX1234"

# Данные для скрипта
$country = "RU"
$state = "MO"
$city = "Moscow"
$corp = "InfoWatch"
$unit = "IB"
$domain = "demo.lab"

# Конфиг опенссл
$config = "
[ ca ]
default_ca = CA_default
[ CA_default ]
certs = ./
serial = serial
database = index
new_certs_dir = ./
certificate = $root.crt
private_key = $root.key
default_days = 36500
default_md  = sha256
preserve = no
email_in_dn  = no
nameopt = default_ca
certopt = default_ca
policy = policy_match
[ policy_match ]
commonName = supplied
countryName = optional
stateOrProvinceName = optional
organizationName = optional
organizationalUnitName = optional
emailAddress = optional
[ req ]
input_password = $password
prompt = no
distinguished_name  = default
default_bits = 2048
default_keyfile = priv.pem
default_md = sha256
req_extensions = v3_req
encyrpt_key = no
x509_extensions = v3_ca
[ default ]
commonName = default
[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true
[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName = @alt_names
[ v3_req ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = $dns.$domain
IP.1 = $ip"

# Скрипт для линукса
$linux = "#!/bin/bash
cd /home/$luser
sudo openssl pkcs12 -in ./$server.p12 -nokeys -out /opt/iw/tm5/etc/certification/$server.crt -password pass:$password
sudo openssl pkcs12 -in ./$server.p12 -nocerts -nodes -out /opt/iw/tm5/etc/certification/$server.key -password pass:$password
cd /etc/nginx/conf.d
sudo sed -i '9s/web-server.pem/$server.crt/' iwtm.conf
sudo sed -i '10s/web-server.key/$server.key/' iwtm.conf
systemctl restart nginx.service"

# Создаём файл с номером и индексом скрипта, конфиг опенссл и скрипт для линукса
cd $path
out-file -append -encoding utf8 "index"
write-output "01" | out-file -append -encoding ASCII "serial"
write-output $config | out-file -append -encoding utf8 "$cnf.cnf"
write-output $linux | out-file -append -encoding utf8 "$cnf.sh"

# Преобразуем скрипт для линукса в *nix формат
((Get-Content "$cnf.sh") -join "`n") + "`n" | Set-Content -NoNewline "$cnf.sh"

# Имя сертификата
$name = $root
# Создаём корневой ключ
.\openssl genrsa -out "$root.key"
# Создаём корневой самоподписанный сертификат
.\openssl req -x509 -new -nodes -key "$root.key" -sha256 -days 1024 -out "$root.crt" -config "$cnf.cnf" -subj "/C=$country/ST=$state/L=$city/O=$corp/OU=$unit/CN=$name/emailAddress=$name@$domain"

# Имя сертификата
$name = $server
# Создаёи промежуточный ключ
.\openssl genrsa -out "$server.key"
# Создаём запрос на подпись
.\openssl req -new -sha256 -config "$cnf.cnf" -key "$server.key" -out "$server.csr" 
# Подписываем сертификат корневым
.\openssl ca -config "$cnf.cnf" -extensions v3_intermediate_ca -days 2650 -batch -in "$server.csr" -out "$server.crt" -subj "/C=$country/ST=$state/L=$city/O=$corp/OU=$unit/CN=$name/emailAddress=$name@$domain"

# Экспортируем промежуточный сертификат и ключ
.\openssl pkcs12 -export -in "$server.crt" -inkey "$server.key" -out "$server.p12" -password pass:"$password"

# Имя сертификата
$name = $client
# Создаём ключ клиента
.\openssl genrsa -out "$client.key"
# Создаём запрос на подпись
.\openssl req -new -key "$client.key" -out "$client.csr" -config "$cnf.cnf"
# Подписываем сертификат промежуточным
.\openssl x509 -req -in "$client.csr" -CA "$server.crt" -CAkey "$server.key" -CAcreateserial -out "$client.crt" -extensions v3_req -extfile "$cnf.cnf" -subj "/C=$country/ST=$state/L=$city/O=$corp/OU=$unit/CN=$name/emailAddress=$name@$domain"

# Экспортируем всё
.\openssl pkcs12 -export -in "$server.crt" -inkey "$server.key" -in "$client.crt" -inkey "$client.key"-in "$root.crt" -inkey "$root.key" -out out.p12 -password pass:"$password"

# Создаём директории для сертификатов и линупса
new-item -path "$cpath" -ItemType Directory -force
new-item -path "$lpath" -ItemType Directory -force

# Перемещаем скрипт для линукса, серверный ключ и сертификат
move-item -path ".\$server.p12" -destination "$lpath\$server.p12" -force
move-item -path ".\$cnf.sh" -destination "$lpath\$cnf.sh" -force

# Перемещаем остальные сертификаты
move-item -path ".\$root.key" -destination "$cpath\$root.key" -force
move-item -path ".\$root.crt" -destination "$cpath\$root.crt" -force
move-item -path ".\$server.key" -destination "$cpath\$server.key" -force
move-item -path ".\$server.csr" -destination "$cpath\$server.csr" -force
move-item -path ".\$server.crt" -destination "$cpath\$server.crt" -force
move-item -path ".\$client.key" -destination "$cpath\$client.key" -force
move-item -path ".\$client.csr" -destination "$cpath\$client.csr" -force
move-item -path ".\$client.crt" -destination "$cpath\$client.crt" -force
move-item -path ".\out.p12" -destination "$cpath\out.p12" -force

# Подчищаем за собой
remove-item "$cnf.cnf"
remove-item "serial"
remove-item "index"
remove-item "01.pem"
remove-item "serial.old"
remove-item "index.old"
remove-item "index.attr"

# Устанавливаем сертификаты в шиндоус
Import-Certificate -FilePath "$cpath\$root.crt" -CertStoreLocation Cert:\LocalMachine\Root
Import-Certificate -FilePath "$cpath\$server.crt" -CertStoreLocation Cert:\LocalMachine\CA
Import-Certificate -FilePath "$cpath\$client.crt" -CertStoreLocation Cert:\LocalMachine\My

# Перемещаем скрипт и сертификаты в линупс
cd $wpath
.\WinSCP.exe sftp://${luser}:${password}@${ip}/home/$luser/ /upload $lpath\$server.p12 $lpath\$cnf.sh /defaults
Start-Sleep -Seconds 1.5

# Запускаем скрипт удалённо
plink -batch $puser@$ip -pw $password "sudo bash /home/$luser/$cnf.sh"

# Чистим за собой
plink -batch $puser@$ip -pw $password "sudo rm /home/$luser/$cnf.sh"
plink -batch $puser@$ip -pw $password "sudo rm /home/$luser/$server.p12"

# Возвращаемся в домашнюю директорию
cd $hpath

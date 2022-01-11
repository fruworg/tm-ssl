#https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.76-installer.msi
#https://winscp.net/download/WinSCP-5.19.5-Setup.exe
#Set-ExecutionPolicy Unrestricted -force
#.\tm-ssl\tm-ssl.ps1

$path = "C:\OpenSSL\bin"
$hpath = "C:\certs"
$wpath = "C:\WinSCP"
$lpath = "$hpath\linux"
$spath = "$hpath\sertificates"
$cnf = "iw"
$ip = "192.168.10.10"
$dns = "iwtm"
$root = "root"
$server = "iwtm"
$client = "arm"
$password = "xxXX1234"

$country = "RU"
$state = "MO"
$city = "Moscow"
$corp = "InfoWatch"
$unit = "IB"
$domain = "demo.lab"

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
input_password = xxXX1234
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
DNS.1 = $dns
IP.1 = $ip"

$linux = "#!/bin/bash
openssl pkcs12 -in ./iwtm.p12 -nokeys -out /opt/iw/tm5/etc/certification/iwtm.crt -password pass:xxXX1234
openssl pkcs12 -in ./iwtm.p12 -nocerts -nodes -out /opt/iw/tm5/etc/certification/iwtm.key -password pass:xxXX1234
cd /etc/nginx/conf.d
sed -i '9s/web-server.pem/iwtm.crt/' iwtm.conf
sed -i '10s/web-server.key/iwtm.key/' iwtm.conf
systemctl restart nginx.service"

#make script.sh + config
cd $path
write-output "01" | out-file -append -encoding ASCII "serial"
write-output $config | out-file -append -encoding utf8 "$cnf.cnf"
write-output $linux | out-file -append -encoding utf8 "$cnf.sh"
out-file -append -encoding utf8 "index"

#root
$name = $root
.\openssl genrsa -out "$root.key"
.\openssl req -x509 -new -nodes -key "$root.key" -sha256 -days 1024 -out "$root.crt" -config "$cnf.cnf" -subj "/C=$country/ST=$state/L=$city/O=$corp/OU=$unit/CN=$name/emailAddress=$name@$domain"

#server
$name = $server
.\openssl genrsa -out "$server.key"
.\openssl req -new -sha256 -config "$cnf.cnf" -key "$server.key" -out "$server.csr" 
.\openssl ca -config "$cnf.cnf" -extensions v3_intermediate_ca -days 2650 -batch -in "$server.csr" -out "$server.crt" -subj "/C=$country/ST=$state/L=$city/O=$corp/OU=$unit/CN=$name/emailAddress=$name@$domain"

#export server
.\openssl pkcs12 -export -in "$server.crt" -inkey "$server.key" -out "$server.p12" -password pass:"$password"

#client
$name = $client
.\openssl genrsa -out "$client.key"
.\openssl req -new -key "$client.key" -out "$client.csr" -config "$cnf.cnf"
.\openssl x509 -req -in "$client.csr" -CA "$server.crt" -CAkey "$server.key" -CAcreateserial -out "$client.crt" -extensions v3_req -extfile "$cnf.cnf" -subj "/C=$country/ST=$state/L=$city/O=$corp/OU=$unit/CN=$name/emailAddress=$name@$domain"

#export final
.\openssl pkcs12 -export -in "$server.crt" -inkey "$server.key" -in "$client.crt" -inkey "$client.key"-in "$root.crt" -inkey "$root.key" -out out.p12 -password pass:"$password"

#certs + linux path
new-item -path "$spath" -ItemType Directory -force
new-item -path "$lpath" -ItemType Directory -force

#linux
move-item -path ".\$server.p12" -destination "$lpath\$server.p12" -force
move-item -path ".\$cnf.sh" -destination "$lpath\$cnf.sh" -force

#certs
move-item -path ".\$root.key" -destination "$spath\$root.key" -force
move-item -path ".\$root.crt" -destination "$spath\$root.crt" -force
move-item -path ".\$server.key" -destination "$spath\$server.key" -force
move-item -path ".\$server.csr" -destination "$spath\$server.csr" -force
move-item -path ".\$server.crt" -destination "$spath\$server.crt" -force
move-item -path ".\$client.key" -destination "$spath\$client.key" -force
move-item -path ".\$client.csr" -destination "$spath\$client.csr" -force
move-item -path ".\$client.crt" -destination "$spath\$client.crt" -force
move-item -path ".\out.p12" -destination "$spath\out.p12" -force

remove-item "$cnf.cnf"
remove-item "serial"
remove-item "index"
remove-item "01.pem"
remove-item "serial.old"
remove-item "index.old"
remove-item "index.attr"

cd $wpath
.\WinSCP.exe sftp://root:xxXX1234@$ip/root/ /upload $lpath\iwtm.p12 $lpath\$cnf.sh /defaults

Import-Certificate -FilePath "$spath\$root.crt" -CertStoreLocation Cert:\LocalMachine\Root
Import-Certificate -FilePath "$spath\$server.crt" -CertStoreLocation Cert:\LocalMachine\CA
Import-Certificate -FilePath "$spath\$client.crt" -CertStoreLocation Cert:\LocalMachine\My

plink -batch root@192.168.10.10 -pw xxXX1234 "yum install dos2unix -y"
plink -batch root@192.168.10.10 -pw xxXX1234 dos2unix "$cnf.sh"
plink -batch root@192.168.10.10 -pw xxXX1234 "bash $cnf.sh"
plink -batch root@192.168.10.10 -pw xxXX1234 "rm $cnf.sh"
plink -batch root@192.168.10.10 -pw xxXX1234 "rm $server.p12"

cd $hpath

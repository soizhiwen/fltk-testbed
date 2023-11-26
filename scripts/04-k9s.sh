su -
cd ~
wget https://github.com/derailed/k9s/releases/download/v0.28.2/k9s_Linux_amd64.tar.gz
tar -xf k9s_Linux_amd64.tar.gz
mv k9s /usr/local/bin/
rm -rf k9s_Linux_amd64.tar.gz README.md LICENSE

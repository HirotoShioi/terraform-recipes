# keyディレクリを作成し、そこにssh鍵を作成する
#!/bin/bash

# keyディレクリを作成
rm -rf key
mkdir -p key

ssh-keygen -t rsa -b 4096 -f key/id_rsa -N "" -C "example@example.com"
chmod 0400 key/id_rsa
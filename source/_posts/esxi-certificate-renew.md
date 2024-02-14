---
title: 【隨手筆記】ESXi憑證過期更新
categories:
  - 隨手筆記
tags:
  - 隨手筆記
  - ESXi
  - TLS
  - 憑證更新
hidden: false
date: 2022-02-16 18:57:51
---
# 前言
我的實驗環境有使用到ESXi，並且有配域名指向此機器，最近使用的憑證過期所以需要更新。

我會需要掛有效憑證的原因主要是
1. 自簽憑證看了心情不好，沒有特別加入信任會跳出警告
2. 我的域名強制HSTS，沒有掛的話連進都進不去

這篇就來記錄一下如何更新ESXi的憑證。

<!-- more -->
# 正文
接下來就實際紀錄更新步驟

1. 準備好有效的憑證
這裡使用letsencrypt免費服務來簽發，效期為三個月。
可以使用certbot來申請，我的DNS託管商為Linode，這裡將使用基於Linode API配合DNS-01 Challenge的certbot插件來完成申請。
    
    以下是Linode DNS插件的使用方法，提供參考
    1. 安裝certbot以及python3-certbot-dns-linode套件
    ```bash
    sudo apt install certbot python3-certbot-dns-linode -y
    ```
    2. 創建~/.secrets/certbot/linode.ini檔案，並在裡面填入Linode API的Token，切記權限要控制好
    ```
    # Linode API credentials used by Certbot
    dns_linode_key = <你的Token>
    ```
    3. 執行以下指令獲得憑證
    ```bash
    sudo certbot certonly \
    --dns-linode \
    --dns-linode-credentials ~/.secrets/certbot/linode.ini \
    --dns-linode-propagation-seconds 120 \
    -d <申請憑證對應的域名>
    ```

完成後就會得到簽發的憑證檔案，等等會用到以下幾個
![](/esxi-certificate-renew/certbot-cert.png)

2. 修改憑證檔案命名
對剛剛產生的憑證做以下檔名修改
    - 將剛剛產生的cert.pem改名為root.cer
    - 將剛剛產生的fullchain.pem改名為rui.crt
    - 將剛剛產生的privkey.pem改名為rui.key


3. 開啟ESXi上的SSH服務，並使用SSH連線到ESXi
![](/esxi-certificate-renew/esxi-open-ssh.png)

4. 進入/etc/vmware/ssl目錄，並備份castore.pem檔案
```bash
cd /etc/vmware/ssl
cp castore.pem castore.pem.bak
```

5. 上傳root.cer到此目錄，並附加到castore.pem檔案內
```bash
cat root.cer >> castore.pem
rm root.cer
```

6. 刪除ESXi上ssl目錄裡原有的rui.crt以及rui.key，並上傳剛剛改名新的有效憑證
```bash
rm rui.crt
rm rui.key
```

7. 執行/sbin/auto-backup.sh
```bash
/sbin/auto-backup.sh
```

8. 重新啟動ESXi即完成
```bash
reboot
```
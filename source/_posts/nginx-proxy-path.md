---
title: 【隨手筆記】Nginx Reverse Proxy 路徑問題
categories:
  - 隨手筆記
tags:
  - 隨手筆記
  - Linux
  - Nginx
  - Reverse Proxy
date: 2022-05-11 15:00:23
---
好久沒有更新了(汗)...

最近在練習架設Gitlab以及建立CI/CD Pipeline。由於我的伺服器上還有其他服務，所以我就沒有用Gitlab-Omnibus內建的Nginx代理，改用自己設定Nginx代理的方式來運作。結果在CI Jobs裡面使用到Gitlab內建的Registry服務時，發生404 Not Found的情況。最後查出來是因為Nginx代理設定中，proxy_pass代理網址的最後我有加了斜線，導致docker打得路徑導向位置不對，造成此問題。

以下是在網路上找到人家整理過的相應設定方式會得到的結果，筆記一下。

| 序號 |         訪問URL         | location配置 |   proxy_pass配置   |  後端接收的請求 |
|:----:|:-----------------------:|:------------:|:------------------:|:---------------:|
|   1  | test.com/user/test.html |    /user/    |    http://test1/   |    /test.html   |
|   2  | test.com/user/test.html |    /user/    |    http://test1    | /user/test.html |
|   3  | test.com/user/test.html |     /user    |    http://test1    | /user/test.html |
|   4  | test.com/user/test.html |     /user    |    http://test1/   |   //test.html   |
|   5  | test.com/user/test.html |    /user/    | http://test1/haha/ | /haha/test.html |
|   6  | test.com/user/test.html |    /user/    |  http://test1/haha |  /hahatest.html |

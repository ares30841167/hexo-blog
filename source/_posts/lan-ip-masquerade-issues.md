---
title: 【踩坑記】正確設定內網IP NAT Masquerade
date: 2024-03-02 22:40:25
categories:
  - 踩坑記
tags:
  - 學習筆記
  - 踩坑
  - RouterOS
  - 網路設定
  - NAT
---

# 前言
這篇的誕生是因為某一天用SSH從宿舍連回實驗室的機器的時候，發現實驗室的機器所記錄的IP是Router上Site to Site VPN的IP地址，而不是我宿舍電腦的IP。很明顯就是NAT Masquerade設定錯誤導致的，故以此篇採坑記記錄一下我又犯了甚麼蠢。
<!-- more -->

# 問題
某一天用SSH從宿舍連回實驗室的機器的時候，發現實驗室的機器所記錄的IP是Router上Site to Site VPN的IP地址，而不是我宿舍電腦的IP。

![](/lan-ip-masquerade-issues/wrong-ip-record.png)
> 上圖是解決前實驗室機器所記錄的IP

會發生這種事呢，主要是因為我在設定內網Masquerade的時候偷懶，使用下圖的設定方法。

![](/lan-ip-masquerade-issues/nat-origin-settings.png)
> 上圖是解決前內網NAT Masquerade的設定

就是因為這種設定方法，導致不管是訪問網際網路的流量，還是訪問內網的流量，一律一視同仁都經過了Masquerade的Src NAT處理，導致連內網的不同網段互相連線時，都會重寫IP的Src。

# 解決
解決方式也是相當的簡單，就是將規則的範圍縮小，只對從WAN口出去的封包做Masquerade的處理即可，這樣一來理應內網的封包其Src與Dst將不會被任何規則改寫，直接送到另一端的路由器做路由，實驗室的機器應該也就會記錄正確的訪問來源IP了。

![](/lan-ip-masquerade-issues/nat-modify-settings.png)
> 上圖是解決後內網NAT Masquerade的設定

但是，沒錯這邊有個但是...

我在這樣子設定完後，並沒有馬上就通，一切順利平安收工。原因是出在防火牆的規則設定上面。

原先我對Site to Site VPN的Forward規則，是使用下圖的設定方法。

![](/lan-ip-masquerade-issues/firewall-origin-forward-settings.png)
> 上圖是解決前的Firewall Site to Site VPN Forward規則設定

如上圖所示，我原本有指定這條規則只能適用於Site to Site VPN所屬的IP，導致從Site to Site VPN所使用的WireGuard介面，只能允許Site to Site VPN所屬的IP被轉發。

就是因為這樣，所以從其他路由器來的封包，在原先使用Masquerade設定的情況下，是可以順利被轉發的，因為Src已經被改寫成Site to Site VPN所屬的IP。但在修改設定後，我們使封包的Src保持原樣，所以這時候就會因為這條規則的關係，沒辦法正常的被轉發。

我們只要將這個Src. Address List的限制拿掉，就可以恢復路由器之間的正常連線了。

![](/lan-ip-masquerade-issues/firewall-modify-forward-settings.png)
> 上圖是解決後的Firewall Site to Site VPN Forward規則設定

回到實驗室的機器看看紀錄的IP，也可以發現IP的紀錄如下圖所示，恢復成連線發起的來源內網IP位置了。

![](/lan-ip-masquerade-issues/correct-ip-record.png)
> 上圖是解決後實驗室機器所記錄的IP
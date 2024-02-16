---
title: 【經驗分享】使用RouterOS架設自己的私人網路
date: 2024-02-16 22:21:33
categories:
  - 經驗分享
tags:
  - 經驗分享
  - WireGuard
  - RouterOS
  - 網路設定
  - VPN
---

# 前言
最近我買了兩台MikroTik RB760iGS hEX S打算在家中跟宿舍各放一台，並讓這兩台Router跟我在研究所實驗室自己架設用來負責個人相關設備網路的Cloud Hosted Router (CHR)組成私人網路。

這篇主要就是分享如何在RouterOS中用WireGuard搭配OSPF來設定私人網路，讓三個地方的設備都可以互相連線。

<!-- more -->

# 架構
![](/build-own-private-network/network-architecture.png)
> 上圖是整體的網路架構圖

先來講大致講一下整體網路架構

## 設備
設備的部分除了實驗室是使用軟體的CHR外，其他皆使用硬體。

- 實驗室
  - Cloud Hosted Router (CHR) - RouterOS v7.13.4
- 家中
  - MikroTik RB760iGS hEX S - RouterOS v7.13.4
- 宿舍
  - MikroTik RB760iGS hEX S - RouterOS v7.13.4

順便介紹一下，MikroTik RB760iGS hEX S這款路由器大概可以路由400Mbps左右的流量，應對目前家中的100Mbps/40Mbps以及宿舍的25Mbps/10Mbps上下載頻寬已經綽綽有餘了。而實驗室的CHR是架在實驗室的Dell PowerEdge R730伺服器上，伺服器上搭載VMWare ESXi，由E5-2623 v3驅動。

## 網段
網段的部分屬於我自用的網段總共有三個，讓路由器使用WireGuard互連的網段三個，實驗室內原有的區域網路網段一個，和提供其他網路外的裝置能通過WireGuard VPN接入的網段一個，共八個。各路由器的網段路由透過OSPF協議交換，並且各路由器之間使用WireGuard透過網際網路互相連接。

- 家中自用網段
  - 10.20.9.0/24
- 宿舍自用網段
  - 10.21.2.0/24
- 實驗室自用網段
  - 172.16.52.0/24
- 實驗室原有區域網路網段
  - 10.52.52.0/24
- 實驗室提供WireGuard VPN服務網段
  - 172.26.52.0/24
- 路由器互連WireGuard網段
  - 10.87.63.0/30
  - 10.87.63.4/30
  - 10.87.63.8/30

# 設定
基礎的設定就不細講了，這邊主要來分享OSPF以及WireGuard的設定和需要注意的地方。

## WireGuard
WireGuard的連線部分其實就是照著一般的方式進行設定，也就是兩個要互連的裝置互相交換Public Key，以及設定對應的Endpoint IP與Allowed IPs。

![](/build-own-private-network/wireguard-peer.png)
> 上圖是WireGuard Peer設定示範

但需要注意的地方在於此情境因為是做Site-to-Site VPN，需要使WireGuard允許所有流量通過，故Allowed IPs就必須互相都設定為0.0.0.0/0。

![](/build-own-private-network/wireguard-allowed-ips.png)
> 上圖是WireGuard Allowed IPs設定示範

基於上面的原因，就會發現一個WireGuard介面只能建立兩個端點的連線(原因是因為流量會跑進第一個符合Allowed IPs網段的Peer，剩餘的Peer就不會收到流量了，設定為0.0.0.0/0後所有流量就只會走最先碰到的Peer，可以參考我的這篇[採坑記](/wireguard-allowedIPs-issues))，故任一對路由器間的連線就只能由單一個WireGuard介面來負責。所以在此次網路架構內，一個路由器就分別用了兩個WireGuard介面來與其他兩個路由器進行連線。

![](/build-own-private-network/wireguard-interfaces.png)
> 上圖是家中路由器的WireGuard介面示範

所以總結要注意的地方就是兩個路由器之間都要由一個獨立的WireGuard介面負責，並且兩端的Allowed IPs都要設定為0.0.0.0/0允許所有流量通過。

## OSPF
建立完WireGuard連線後，各路由器便可通過WireGuard進行溝通，這時候就必須來處理路由的問題。

這裡當然可以通過靜態路由的方式，對所有的路由器手動添加路由路徑，也可以使用RIP來交換路由表(甚至更適合小網路)。而本次分享所使用的是OSPF這個IGP來交換指定介面上的網段路由資訊。

至於OSPF是什麼，以及OSPF與RIP的詳細比較，以後有機會的話再來嘗試寫寫看介紹的文章。這邊先介紹一篇非常優質的文章供大家學習參考: [Jan Ho 的網絡世界 - Open Shortest Path First (OSPF) 開放最短路由優先協定](https://www.jannet.hk/open-shortest-path-first-ospf-zh-hant/)，此篇主要是針對Cisco做示範與介紹。

在RouterOS中首先要先給各個Router一個Router ID。這個ID主要是提供路由器一個「名子」，只不過這個ID通常都使用IP來表示。

要設定Router ID，先選取RouterOS內Routing->Router ID選項，並點選視窗左上角的+號進行新增。並填入自訂名稱以及Router ID兩個資訊。三個路由器都各自重複此步驟進行設定，此次分享的Router ID名稱設定都位於上方[架構圖](#架構)中。

![](/build-own-private-network/router-id.png)
> 上圖是Router ID設定示範

設定完ID後，這邊要把上面設定的「名子」，透過Bridge介面設定為Router的Loopback IP。這邊大家可能就會很納悶了，不是說好只是名子的，怎麼又設定成Router的IP了呢?

要解答這個問題，大家可以參考上面所提到的OSPF文章以及這篇[CSDN文章](https://blog.csdn.net/HiLoveS/article/details/5402252)所說的原因。文章內描述的情況大概只有在較大的網路上會有影響，但養成好習慣並不是壞事，並且也不是一定需要設定此步驟，不設定也不會造成OSPF不能使用。

這邊要設定Bridge介面，先選取RouterOS內Interface選項，並點選視窗左上角的+號進行新增。只需填入名子即可，其他保持預設。

![](/build-own-private-network/ospf-lo.png)
> 上圖是Bridge設定示範

再來要為這個Bridge介面設定IP，先選取RouterOS內IP->Address選項，並點選視窗左上角的+號進行新增。選取相對應的Bridge介面，並給予Router ID所表示的IP位置。三個路由器都各自重複此步驟進行設定。

![](/build-own-private-network/ospf-lo-address.png)
> 上圖是Bridge IP Address設定示範

到這裡就可以開始設定OSPF的部分了。首先選取RouterOS內Routing->OSPF選項進入到OSPF的設定視窗內。

一開始進入到Instances頁籤內並點選視窗左上角的+號進行新增OSPF Instance。輸入自訂的名稱並選取稍早前創建的Router ID完成設定，版本使用2版，VRF選擇main則保持預設。三個路由器都各自重複此步驟進行設定。

![](/build-own-private-network/ospf-instance.png)
> 上圖是OSPF Instance設定示範

再來進入到Area頁籤內並點選視窗左上角的+號進行新增OSPF Area。因為是小型網路，這邊主要都會將路由器分配到Backbone Area內，也就是0.0.0.0這個ID的Area，分Area主要是防止動盪，以免路由更新時影響到整個網路。這邊只需要輸入自訂區域名稱並選取對應的OSPF Instance，其他選項保持預設即可，預設應該就是使用0.0.0.0這個Area ID。三個路由器都各自重複此步驟進行設定。

![](/build-own-private-network/ospf-area.png)
> 上圖是OSPF Area設定示範

最後進入到Interface Templates頁籤內並點選視窗左上角的+號進行新增Interface Template。這邊主要是讓管理員選擇想要參與OSPF交換網段路由的介面，被選中的介面上存在的網段就會動態的透過OSPF進行交換。這邊需要選擇想要交換的介面、路由所屬的OSPF Area ID以及Network Type。這邊要特別注意，Network Type使用broadcast或ptp都可以，唯所有路由器上的此設定皆需一致，也就是要不所有的路由器都使用broadcast這個Network Type，要不就所有路由器都使用ptp。三個路由器都各自重複此步驟進行設定。

![](/build-own-private-network/ospf-interface-template.png)
> 上圖是OSPF Interface Template設定示範

## 結果
到這邊應該就可以看到Neighbors頁籤內出現其他路由器的Router ID，並且狀態為Full表示交換完路由。(圖中只有一個Neighbor是因為宿舍那邊的沒開機)

![](/build-own-private-network/ospf-neighbor.png)
> 上圖是設定完成後OSPF Neighbor的結果

並且也可以看到Route List內也多出了其他路由器上的網段以及對應的Gateway資訊。

![](/build-own-private-network/route-list.png)
> 上圖是設定完成後Route List的結果

看到以上結果的話恭喜大家也成功建置出屬於你自己的私人網路啦，各個區域網段便可以開始愉快的互相連線了。

最後，關於有關過程中遇到的兩個小坑，分別是NAT Loopback以及實驗室原有區域網路的路由問題，就等到下兩篇採坑記補齊囉。

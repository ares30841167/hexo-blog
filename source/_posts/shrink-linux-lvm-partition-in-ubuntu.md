---
title: 【隨手筆記】如何在Ubuntu底下縮小LVM分區大小
categories:
  - 隨手筆記
tags:
  - 隨手筆記
  - 伺服器管理
  - Linux
  - Ubuntu
  - Linux-LVM
  - Resize Partition
hidden: false
date: 2022-02-18 23:14:20
---
# 前言
這篇筆記主要是因為最近有遇到虛擬機搬遷的情況，並且考慮到磁碟空間設定的問題，所以記錄一下過程。

我最近從ESXi上將我的實驗環境完整搬遷了一份下來到我的本地電腦上，總共有8台Ubuntu Server，當初這些在ESXi上的虛擬機系統根目錄的分區大小都設定為40G，但我的本地端預計只想給一顆256G的M.2硬碟給這些虛擬機使用。搬下來後雖然因為虛擬磁碟裡面檔案存的不多，vmdk檔案的大小都還很小，大概只有5G，只要小心一點用不要用超過應該不會有甚麼問題。但考慮到我就是龜毛，所以想要將每一台虛擬機的根目錄分區大小限縮在25G，這樣8台就算裝滿也不會超過256G。

於是就有了這篇隨手筆記誕生，說來說去最主要就是我自己在搞事。

藉著這次順便學習一下如何在Ubuntu底下重新調整LVM分區的大小，因為之前比較少調整。

<!-- more -->

# Linux LVM
[LVM](https://zh.wikipedia.org/wiki/%E9%82%8F%E8%BC%AF%E6%8D%B2%E8%BB%B8%E7%AE%A1%E7%90%86%E5%93%A1) (Logical Volume Manager)，LVM會在硬碟的硬碟分割區之上建立了抽象的邏輯卷軸，並將檔案建立在這個邏輯卷軸上。當這個邏輯卷軸空間不夠用的時候，只需要再將更多的硬碟分割區餵給這個邏輯卷軸使用，就可以擴大這個邏輯卷的可用儲存空間。當然也可以反過來將硬碟分割區從邏輯卷軸占用中釋放，方便彈性調整善用磁碟空間。

![](/shrink-linux-lvm-partition-in-ubuntu/LVM.png)

LVM中有以下幾個部分

- PV (Physical Volume)
  PV其實就是電腦中儲存裝置，創建PV後，LVM會在其裝置中寫入Header用於管理，可以是實體的磁碟裝置，也可以是任何在系統中被視為磁碟的裝置(例如ubuntu底下的mapper或是RAID)
- PE (Physical Extent)
  PE就像是其他系統裡的Block大小，也是LVM管理磁碟空間的最小單位，直接影響了最終的磁碟空間可以有多大。要特別注意的是，PE的大小需要是2的倍數，8k到16G都是可以設定的範圍
- VG (Volume Group)
  LVM會將多個PV結合成一個VG，其角色就像一個虛擬的大硬碟，多個PV的可用空間將會被融合再一起，每個VG最多僅能包含65534個PE。以LVM預設參數而言，預設為4M，故一個VG最大就是256G
- LV (Logical Volume)
  其角色等同於物理硬碟上的分區，但彈性更大，LV通常為使用者與應用程式最直接的互動的一層
- LE (Logical Extent)
  用來組成LV的最小單位，基本上就是與PE的對應，也就是這個LV多大就需要有對應數量的PE分配到LV來組成

你可能會發現組成的PE可以來自不同硬碟，那是不是硬碟壞了我的資料就完了呢?

簡單來說，是。但當然也有相對應的解決方法，例如使用LVM中的Mirror Logic Volume或者使用已經有冗餘能力的RAID來組成VG，都可以有效避免這個問題，這個之後有詳細研究LVM再來分享。

# 實際調整過程
接下來將實際在Ubuntu Server 20.04.3 LTS上操作並記錄如何縮小LVM分區大小。LVM在調整大小時需要先卸載後才能調整，這次因為是要直接動到根目錄掛載磁碟的大小，所以我們需要先借助Live Boot的方式來對根目錄的LV進行操作。

【提醒】此範例為系統安裝在/dev/sda3，/dev/sda3的所有空間被創建為PV，VG只含有這一個PV，並且VG內有唯一LV占滿全部空間的情況，其他情境需視當下情況來操作。此篇主要目的還是對我的狀況做筆記，讀者操作自有資料時請務必謹慎。

1. 先放入Ubuntu Server的安裝光碟並進入到安裝畫面
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-installer.png)

2. 按下Ctrl+Alt+F2~F6其中一個組合鍵進入可操作的TTY
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-tty.png)

3. 先輸入以下命令來縮減LV的大小
    ```bash
    sudo lvresize --resizefs --size <欲調整的大小> <LV路徑>
    ```
    > e.g sudo lvresize --resizefs --size 25G /dev/mapper/ubuntu--vg-ubuntu--lv
    size部分也可以使用加減號來從現在磁碟大小為基準做調整，例如+20G

    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-lvresize.png)

4. 完成LV的縮減後，VG內原本占用的PE就會被釋放為Free的狀態，這時候接著輸入以下指令將PV的大小縮減
    ```bash
    sudo pvresize --setphysicalvolumesize <重新調整的大小> <PV路徑>
    ```
    > e.g sudo pvresize --setphysicalvolumesize 25G /dev/sda3

    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-pvresize.png)

    這裡當時在操作的時候遇到一個小問題，在執行pvresize時出現以下狀況
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-pvresize-fail.png)

    上圖提示Resize的大小小於現在已經占用的PV總大小，可以看到25G被識別成6399個PV，但以占用的PV為6400個。
    所以重新調整的大小就必須多加一個PV的空間，預設值就是4M。
    故這裡改用M的單位再加4M即可解決。
  
5. (選用)使用下列命令來釋放縮小後多於未使用的空間
    最後可以使用fdisk工具將磁碟上多於的空間給釋放出來，變成未配置的狀態。
    ```bash
    sudo fdisk <硬碟路徑>
    ```
    > e.g sudo fdisk /dev/sda

    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk.png)
    > 上圖為fdisk執行的畫面

    接著，先在Command輸入區的地方輸入p，可以看到目前的分區狀態，雖然PV縮小到了25G，但分區依然還有38.5G。
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk-p.png)

    在Command輸入區的地方輸入d，並將現在的分區先刪除
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk-d.png)
    > 在這裡是/dev/sda3，故這裡指定3號分區

    在Command輸入區的地方輸入n，新建一個分區
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk-n.png)
    > 這裡一樣指定3號分區。起始磁區(First Sector)直接留空按Enter使用預設值，也就是可用磁區的最開始的地方。結束磁區(Last Sector)使用加號往後移動你調整的大小，這裡我的情況是+25604M。最後fdisk會發現這個分區上有舊有的LVM2的簽名，選擇N保留，不要移除。

    在Command輸入區的地方輸入t，修改分區類型
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk-t.png)
    > 這裡一樣指定3號分區，並輸入31來將分區指定成Linux LVM類型

    最後在Command輸入區的地方輸入w，保存修改後的分區資料
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk-w.png)

6. 重開機並回到正常開機狀態，搞定!
    重開機後使用fdisk -l檢查，就可以看到空間順利地被縮小了。
    ![](/shrink-linux-lvm-partition-in-ubuntu/ubuntu-fdisk-list-after.png)
---
title: 【踩坑記】使用 Intel AMT IDER 功能掛載虛擬映像安裝 Ubuntu
date: 2024-03-02 22:40:25
categories:
  - 踩坑記
tags:
  - 學習筆記
  - 踩坑
  - vPro
  - Intel AMT
---

# 前言
這篇的誕生是因為我偶然在實驗室的某些實驗用主機上發現貼有 Intel vPro 的貼紙。想到我們實驗室有一組在做容錯技術，常常可能需要重灌電腦，剛好可以用 Intel AMT 來達到類似伺服器 IPMI 的功能，讓他們可以透過 Intel AMT 配合 MeshCommander 遠端連線並掛載虛擬映像進行重灌，不用再跑進小機房內。

但是不出意外馬上就要出意外了，透過 IDER (IDE Redirection) 掛映像後進入 Ubuntu 安裝程序準備開開心心開始重灌時，陷入了一個坑內，Ubuntu 一直不斷重複 `usb x-xx: reset high-speed USB device number x using xhci_hcd` 的提示，無法順利進入安裝程式...
<!-- more -->

# 問題
透過 IDER (IDE Redirection) 掛映像後進入 Ubuntu 安裝程序準備開開心心開始重灌時，Ubuntu 一直不斷重複 `usb x-xx: reset high-speed USB device number x using xhci_hcd` 的提示，如下圖示意圖中所示，無法順利進入安裝程式。

![](/intel-amt-ider-issues/usb-reset-loop.png)
> 上圖是遇到不斷重複提示的示意圖，圖源來自此篇 [GitHub Issues](https://github.com/Ylianst/MeshCommander/issues/51)

會發生這種事呢，主要是起自一個非常神奇的原因，先看看下圖。

![](/intel-amt-ider-issues/intel-amt-ider.png)
> 上圖是 MeshCommander 中 IDE Redirection 設定的選項視窗

通常直覺來說，上圖 IDE Redirection 設定有兩個映像插入的選項，因為現代根本不會用到 Floppy 映像 (安裝系統時也根本用不到...)，所以自然而然此欄位就留空不插映像了。

但坑就在這裡，不知道是 MeshCommander 設計的關係還是 Intel AMT，若該選項沒有插入任何東西，該功能一樣會重導向該映像選項，造成 Ubuntu 行為異常。

# 解決
解決方式也是相當的簡單，大家可以到 [archive.org](https://archive.org/details/blank-floppy) 上下載空白的虛擬 Floppy 檔案並插入 Floppy 欄位，就可以正常進入 Ubuntu 安裝程序了。

![](/intel-amt-ider-issues/intel-amt-ider-correct-insert.png)
> 上圖是 MeshCommander 中正確的 IDE Redirection 設定
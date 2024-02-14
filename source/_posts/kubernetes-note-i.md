---
title: Kubernetes學習筆記(一) - 起點
date: 2022-02-01 19:33:14
categories:
  - Kubernetes基礎學習筆記系列
tags:
  - 學習筆記
  - Kubernetes
  - Containerized
  - High Availability
  - Nginx
---

# 前言
這個系列會記錄我學習到的Kubernetes知識，主要是一系列的學習筆記，從架設到實際部屬簡單的容器APP，並嘗試管理以及操作Kubernetes集群。

2021年的8月其實我有買了一本Gigi Sayfan寫的[Kubernetes 微服務實戰](https://www.tenlong.com.tw/products/9787111655763)，但只看了前面兩三章，還沒有完全看完(汗)。這個系列並沒有包含這本書的學習筆記，之後再開另一個系列筆記來紀錄。
<!-- more -->

# 規劃
此次目標會從Kubernetes的架設開始，並嘗試將Kubernetes群集設定為高可用的狀態，避免SPOF(單點故障)的發生，再到熟悉使用Kubernetes的kubectl對群集進行各種操作與設定，之後嘗試部屬簡易的容器APP並暴露服務，最終希望配合Nginx來做群集服務的Ingress以及Load Balance。

雖然目標是這樣定，但我相信過程中應該還會發現有許多東西沒有涵蓋到，所以就隨時調整並納入筆記囉。

## 預定練習大綱
所以再條列一次目前的學習大方向為:
- Kubernetes架設/高可用性建置
- 熟悉Kubernetes群集的各種操作與設定
- 部屬簡易的容器APP/暴露服務
- Nginx Ingress/Load Balance

## 預計實作的集群架構一覽

### 架構圖
![](/kubernetes-note-i/k8s-practice-architecture.png)

### 集群機器IP表
|     主機名稱    |      IP      |
|:---------------:|:------------:|
|     Gateway     | 10.0.254.254 |
| VRRP Virtual IP | 10.0.254.253 |
|     k8s-lb-1    | 10.0.254.252 |
|     k8s-lb-2    | 10.0.254.251 |
|   k8s-master-1  | 10.0.254.250 |
|   k8s-master-2  | 10.0.254.249 |
|   k8s-master-3  | 10.0.254.248 |
|   k8s-worker-1  | 10.0.254.247 |
|   k8s-worker-2  | 10.0.254.246 |
|   k8s-worker-3  | 10.0.254.245 |

以上機器皆搭載 Ubuntu 20.04.3 LTS 版本作業系統

# 結尾
先前因為就有到處了解一些Kubernetes可以做到的事情以及基本概念，所以這次的規劃就以目前有的知識為主，並著重在嘗試親自動手試驗一遍加深印象與觀念。希望透過邊學習邊紀錄的方式可以先了解並熟悉Kubernetes的基本操作以及基本知識，之後再來學習更進階的技巧與應用，例如持續部屬、進階CNI(容器網路)管理、效能管理、Sidecar Proxy等等更高階的議題。
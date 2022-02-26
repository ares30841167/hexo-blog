---
title: Kubernetes學習筆記(三) - 建立Kubernetes高可用集群
categories:
  - Kubernetes基礎學習筆記系列
tags:
  - 學習筆記
  - Kubernetes
  - High Availability
  - Kubeadm
  - CRI
  - CRI-O
  - CNI
  - Flannel
hidden: false
date: 2022-02-25 21:16:08
---
# 開場
在上一篇筆記文章裡，我們成功部屬了一套高可用的Load Balancer，可用來將控制流量分配到集群內的多個Master Node上。這篇筆記我們就要來將Kubernetes高可用集群實際建立起來，並且跟建立好的集群互動看看，確定有建立成功。

<!-- more -->
# 實作
【提醒】架構圖、機器IP列表以及作業系統資訊請參考[Kubernetes學習筆記(一) - 起點](/kubernetes-note-i/#預計實作的集群架構一覽)，本系列一律使用Ubuntu來實作練習

此次示範的Kubernetes版本為
- Kubernetes v1.23
- kubeadm v1.23
- kubectl v1.23
- cri-o v1.23
- rancher/mirrored-flannelcni-flannel-cni-plugin:v1.0.1
- rancher/mirrored-flannelcni-flannel:v0.16.3

主要使用kubeadm工具來建立高可用集群

順便附上[官方教程](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)

## 安裝建立Kubernetes集群所需的套件並進行前置設定
以下腳本參考[官方網站安裝步驟](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)將需要做的步驟腳本化，讀者可以直接進行適當修改後執行，便可快速安裝建立集群所需要的套件並完成大部分的前置設定。

腳本內實際安裝或設定了什麼，請見腳本內註解的說明。

```bash=
#!/bin/sh

# 安裝Repo使用HTTPS的相依套件
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# /etc/modules-load.d/資料夾內的設定檔目的為系統啓動時自動加載內核模組，此處新增設定檔於開機時自動載入內核模組使橋接的流量也會進入netfilter中處理
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

# /etc/sysctl.d/資料夾內的設定檔目的為系統啓動時自動設定內核參數，此處新增設定檔於開機時自動設定參數讓橋接的流量可被iptables的FORWARD規則過濾
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# 重新載入 /etc/sysctl.conf 的設定
sudo sysctl --system

# 設定OS版本以及要安裝的Kubernetes版本變數
export OS=xUbuntu_20.04
export VERSION=1.23

# 新增對應版本的CRI-O Repo
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF

cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /
EOF

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers-cri-o.gpg add -

# 安裝CRI-O
sudo apt-get update
sudo apt-get install -y cri-o cri-o-runc

# 由於Linux使用systemd作為init system，為了避免系統中使用兩種cgroup driver(cgroupfs)，指定cri-o使用systemd來作為cgroup manager
cat <<EOF | sudo tee /etc/crio/crio.conf.d/02-cgroup-manager.conf
[crio.runtime]
cgroup_manager = "systemd"
EOF

# 作用同上，此處新增設定檔於開機時自動載入使橋接的流量也會進入netfilter中處理的內核模組以及overlayfs存儲驅動內核模組
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

# 手動立即載入overlay以及br_netfilter內核模組
sudo modprobe overlay
sudo modprobe br_netfilter

# 作用同上，此處新增設定檔於開機時自動設定參數讓橋接的流量可被iptables的FORWARD規則過濾，必且允許IPv4的路由轉發
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# 重新載入 /etc/sysctl.conf 的設定
sudo sysctl --system

# 使CRI-O開機時自動啟動，並且指定--now參數使CRI-O服務於此刻立即啟動
sudo systemctl daemon-reload
sudo systemctl enable crio --now

# 新增對應版本的Kubernetes相關套件Repo
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 安裝kubelet、kubeadm以及kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# 固定套件版本
sudo apt-mark hold kubelet kubeadm kubectl

# 關閉Swap
sudo swapoff -a
sudo sed -i 's/.*swap.*/#&/' /etc/fstab
sudo rm /swap.img
```

使用以下指令在所有預計成為Master Node以及Worker Node的主機上執行此腳本，完成安裝
```bash
cd <腳本所在目錄>
sudo chmod +x <腳本檔名>; sudo ./<腳本檔名>
```
> e.g sudo chmod +x kube_install_v2.sh; sudo ./kube_install_v2.sh

![](/kubernetes-note-iii/k8s-install-finish.png)
> 安裝成功範例

## 使用kubeadm初始化預計成為Master Node的第一台主機
這步將在預計成為Master Node的第一台主機，在本範例也就是k8s-master-1，執行節點初始化，使得這些主機初始化為Master的角色。

其他Master節點則使用加入的方式加入到集群中。

在預計成為Master Node的第一台主機執行以下指令來初始化
```bash
sudo kubeadm init --control-plane-endpoint LOAD_BALANCER_DNS/IP:LOAD_BALANCER_PORT --pod-network-cidr 10.244.0.0/16 --upload-certs
```
> --control-plane-endpoint參數將指定管理平面的進入點，這裡就要替換為上一篇筆記中所架設好的高可用Load Balaner當初設定的單一入口IP或Domain Name
--pod-network-cidr參數是用來指定pod網路可使用的總網段，10.244.0.0為flannel這個CNI所預設使用的總網段
【提醒】CNI並不只flannel一種，讀者應該視情況更改
--upload-certs參數用來將所有控制平面節點應該要共用的憑證上傳到集群內供其他節點取得。若未指定此參數，則需手動複製憑證到各個節點
e.g sudo kubeadm init --control-plane-endpoint 10.0.254.253:6443 --pod-network-cidr 10.244.0.0/16 --upload-certs

帶上述指令跑完後若集群建立成功，則會看到以下幾則訊息
![](/kubernetes-note-iii/k8s-init-success.png)
> 此圖最開始的地方提示已成功初始化
中間的部分告知若使用者要使用kubectl與集群進行互動，需要複製admin.conf設定檔到使用者的家目錄底下，來讓kubectl可以通過鑑權得到root權限
最後的部分則提醒要為集群部屬Pod網路

![](/kubernetes-note-iii/k8s-init-control-join-command.png)
> 此圖前面的部分是用來將其他Master節點加入集群中的指令，只需要在其他兩台預計成為Master Node的主機上執行即可加入
後面的部分則是告知因為我們有使用--upload-certs選項，所以會有certificate-key的產生。這組金鑰可以存取集群的敏感資料，所以請小心謹慎。uploaded-certs會在兩個小時後自動刪除以策安全

![](/kubernetes-note-iii/k8s-init-worker-join-command.png)
> 此圖中是用來將其他Worker節點加入集群中的指令，只需要在所有預計成為Worker Node的主機上執行即可加入

## 使用kubeadm將其餘預計成為Master Node的主機加入集群
這步將在其餘兩台預計成為Master Node的主機，在本範例也就是k8s-master-2、k8s-master-3，執行稍早獲得的Master節點加入指令，使其加入集群內形成高可用的狀態。

【提醒】執行稍早獲得的Master節點加入指令須注意，需要以管理員身分執行。

順利加入則會出現以下訊息
![](/kubernetes-note-iii/k8s-master-join-success.png)
> 說明已經成功加入集群

## 使用kubeadm將所有預計成為Worker Node的主機加入集群
這步將在所有預計成為Worker Node的主機，在本範例也就是k8s-worker-1、k8s-worker-2、k8s-worker-3，執行稍早獲得的Master節點加入指令，使主機加入集群中擔任Worker的角色。

【提醒】執行稍早獲得的Worker節點加入指令須注意，需要以管理員身分執行。

順利加入則會出現以下訊息
![](/kubernetes-note-iii/k8s-worker-join-success.png)
> 說明已經成功加入集群

## 複製管理配置文件供kubectl使用
在集群建立成功時有提示若使用者要使用kubectl與集群進行互動，需要複製admin.conf設定檔到使用者的家目錄底下，這步就實際來設定kubectl。

kubectl預設使用~/.kube/config檔案來作為管理設定檔，也可以使用KUBECONFIG環境變數或設置--kubeconfig來更改使用的設定檔位置。

所以我們需要把Master節點主機上的/etc/kuberentes/admin.conf檔案，複製到要用kubectl來管理集群的主機上，並且將這個檔案複製到~/.kube/中更名為config。

此筆記我將會使用與集群同一個網段下的Windows系統來使用kubectl對集群進行操作，所以需要先到[官方下載頁面](https://kubernetes.io/releases/download/)下載kubectl工具，照著官方的步驟即可完成安裝。
【備註】集群連線位置定義在admin.conf之中，請視情況修改

安裝完後，再到集群內下載admin.conf檔案到本機。得到admin.conf後，到使用者目錄底下創建.kube資料夾，將admin.conf檔案複製進來，並更名為config，如下圖範例所視
![](/kubernetes-note-iii/kubectl-config.png)
> 【提醒】admin.conf為敏感文件，再複製或傳輸時請小心警慎，若被竊取則可能使他人完全控制你的集群

上述步驟都完成後，就可以順利的使用kubectl跟集群進行互動了。

## 部屬Flannel CNI
Flannel主要功能就是建構Overlay網路，使不同主機上的Pod之間可以溝通。

這步將要在集群內部屬Flannel，其方法非常簡單，使用下列命令透過kubectl套用Flannel的YAML設定檔即可完成部屬。
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

![](/kubernetes-note-iii/flannel-deploy-success.png)

# 驗證
透過kubectl我們可以使用以下指令查詢節點狀態
```bash
kubectl get nodes
```
![](/kubernetes-note-iii/kubectl-get-nodes.png)
> 可以看到所有節點均為Ready，集群運作正常

並且若多執行幾次上述指令，並觀察HAProxy的Log，可以發現控制流量確實有分布在三台Master Node上，確實達到高可用備援的目的。
![](/kubernetes-note-iii/haproxy-log.png)

# 總結
到此我們就成功的將高可用的Kubernetes集群建立起來了，下一篇筆記我們預計將紀錄如何與Kubernetes集群做更多的互動，並且嘗試對Kubernetes集群進行設定。
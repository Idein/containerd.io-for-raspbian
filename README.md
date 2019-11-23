# Raspbianでarmv6,v7共に動作するcontainerd.ioのパッケージング

## 概要

raspbian buster armv6(pi0など)環境上で動作する `containerd.io` のパッケージング

2019/6/30時点では，raspbian buster armv6(pi0など)環境上で動作する `containerd.io` のパッケージが提供されていなかったため，
元々，本リポジトリはでは動作パッケージを作成する方法を示していたが，現在は提供されている．
そのため本リポジトリは自家パッケージングの手順になっている．

クロスコンパイルもできるかもしれないのだが，qemuユーザーモードエミュレーションには面倒そうな箇所がある上，
途中までx86\_64上で実施してみても`GOARCH`等を付けるとdockerdのビルド時にSEGVしたりしていた．
ただの"Hello,World!"をビルドするgo buildでも確率的にSEGVしていたので，
これはアカンとクロスコンパイルは見切っている．

## 前準備

パッケージングスクリプトはdockerイメージを利用するため，パッケージング環境にはdockerが入っていなければならない．
[raspbian buster](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip)を焼いてpi0起動する．
パッケージングにはdockerイメージを複数使う．また，goプログラムのリンカが利用するメモリもpi3までの容量では不足する．
swap領域も必要になるためパッケージングには予め容量の大きなSDカードを使う．8GBだと不足だった．

headlessでsshまでできるようにしておき，以下ssh後

### メモリが不足するので，swapを拡張しておく

```bash
sudo nano -w /etc/dphys-swapfile
```

```
-CONF_SWAPSIZE=100
+CONF_SWAPSIZE=2048
```

### upgrade

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo reboot
```

## Docker環境構築

### raspbian docker リポジトリの設定

```bash
sudo nano -w /etc/apt/sources.list.d/docker.list
```

```
deb [arch=armhf] https://download.docker.com/linux/raspbian buster stable
```

### `docker-ce` のインストール

```bash
sudo nano -w /etc/apt/preferences.d/docker.pref
```

```
Package: aufs-tools
Pin: version *
Pin-Priority: -1
```

```bash
wget -O- https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
sudo apt update
sudo apt install -y docker-ce
sudo usermod -aG docker pi
```

この後，再ログインしてsudoナシでdocker叩けるか確認

```bash
docker images
```

## パッケージング

### golangイメージのベースイメージ作成

raspbian向けgolangイメージを作るためのベースイメージをraspbianで作る

```console
git clone https://github.com/docker-library/buildpack-deps
cd buildpack-deps
git rev-parse HEAD
2583ce5f75af115a0a9eaf948e19d99bcb17f4dc
cd buster/curl
nano -w Dockerfile
-FROM debian:buster
+FROM idein/actcast-rpi-app-base:buster # 大本のベースイメージをraspbian buster のdebootstrap最小構成に
docker build . -t idein/buildpack-deps:buster-curl
cd ../scm
nano -w Dockerfile
-FROM buildpack-deps:buster-curl
+FROM idein/buildpack-deps:buster-curl
cd
```

### raspbian向けのgolangイメージ作成

```console
git clone https://github.com/docker-library/golang
cd golang
git rev-parse HEAD
4cd30a13eca195db17474df090d84d2901ddf3d6
cd 1.13/buster/
nano -w Dockerfile
-FROM buildpack-deps:stretch-scm
+FROM idein/buildpack-deps:buster-scm
docker build . -t idein/golang:1.13-buster
cd
```

### `containerd.io` パッケージング

```console
git clone https://github.com/Idein/containerd.io-for-raspbian
cd containerd.io-for-raspbian
docker build -t containerd-pkg-builder:1.2.10 .
docker run -v $(pwd):/root/deb containerd-pkg-builder:1.2.10
```

取り出しておく

```console
$ scp pi@pi0.local:containerd.io-for-raspbian/containerd.io_1.2.10-1_armhf.deb .
```

## 動作確認

[raspbian buster](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip)を焼いて起動．以下，パッケージング時と同様にsshできたとこから

おやくそく

```console
$ sudo apt-get update
$ sudo apt-get upgrade -y
$ sudo reboot
```

作ったパッケージを送り込んでおく．

```console
$ scp containerd.io_1.2.10-1_armhf.deb pi@testpi.local:
```

インストール

```console
$ sudo apt install ./containerd.io_1.2.10-1_armhf.deb
```

[docker-ceを拾ってきて](https://github.com/Idein/docker-ce-for-raspbian-buster/releases)インストール

```console
$ sudo apt install ./deb/docker-ce-cli_19.03.5~3-0~raspbian-buster_armhf.deb --no-install-recommends
$ sudo apt install ./deb/docker-ce_19.03.5~3-0~raspbian-buster_armhf.deb --no-install-recommends
```

実行

```console
$ sudo docker images
$ sudo docker run --rm idein/actcast-rpi-app-base:buster echo hello
$ hello
```

pi3環境でも同様に動作確認


## 注意事項

現時点のcontainerd(というか，go 1.13のARM runtime)にはcontainerd-shimがタイミングでSEGVする[バグ](https://go-review.googlesource.com/c/go/+/192937#message-71fa1ed3267bdd59342bed49b86859a779721dfb)がある．

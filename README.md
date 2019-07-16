# Raspbianでarmv6,v7共に動作するcontainerd.ioのパッケージング

## 概要

2019/6/30現在，raspbian buster armv6(pi0など)環境上で動作する `containerd.io` のパッケージが提供されていない．
stretchではかろうじて最新ひとつ手前のバージョンがraspi共通で動作させることのできるものであったが，
それもcontainerdの古さによりbuster上では動作しなくなってしまったことが確認された．
そのため，本ドキュメントではraspi共通で動作させることのできる `containerd.io` パッケージを作成する手順を示し，
その成果物を同梱しておく．

クロスコンパイルもできるかもしれないのだが，qemuユーザーモードエミュレーションには面倒そうな箇所がある上，
途中までx86_64上で実施してみても`GOARCH`等を付けるとdockerdのビルド時にSEGVしたりしていた．
ただの"Hello,World!"をビルドするgo buildでも確率的にSEGVしていたので，
これはアカンとクロスコンパイルは見切った．

## 前準備

パッケージングスクリプトはdockerイメージを利用するため，パッケージング環境にはdockerが入っていなければならない．
[raspbian stretch](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/2019-04-08-raspbian-stretch-lite.zip) (でなら armv6,v7 両方で動く `docker-ce` packageがあるので)を焼いてpi0起動する．
パッケージングにはdockerイメージを複数使う．また，goプログラムのリンカが利用するメモリも不足する可能性がある．
swap領域も必要になるためパッケージングには予め容量の大きなSDカードを使う．8GBだと不足だった．

headlessでsshまでできるようにしておき，以下ssh後

### 念のためswapを拡張しておく

```bash
sudo nano -w /etc/dphys-swapfile
-CONF_SWAPSIZE=100
+CONF_SWAPSIZE=2048
```

### upgrade

```console
$ sudo apt-get update
$ sudo apt-get upgrade -y
$ sudo reboot
```

## Docker環境構築

### raspbian docker リポジトリの設定

```console
$ sudo nano -w /etc/apt/sources.list.d/docker.list
```

```
deb [arch=armhf] https://download.docker.com/linux/raspbian stretch stable
```

### `docker-ce` のインストール

`18.06.1~ce~3-0~raspbian` は raspbian stretch armv6,v7 で動くのでとりあえずビルド環境用にpinningして使う．

```console
$ sudo nano -w /etc/apt/preferences.d/docker.pref
```

```
Package: docker-ce
Pin: version 18.06.1~ce~3-0~raspbian
Pin-Priority: 990

Package: aufs-tools
Pin: version *
Pin-Priority: -1
```

```console
$ wget -O- https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
$ sudo apt-get update
$ sudo apt-get install -y docker-ce
$ sudo usermod -aG docker pi
```

この後，再ログインしてsudoナシでdocker叩けるか確認

```console
$ docker images
```

## パッケージング

### golangイメージのベースイメージ作成

raspbian向けgolangイメージを作るためのベースイメージをraspbianで作る

```console
$ git clone git@github.com:docker-library/buildpack-deps.git
$ cd buildpack-deps
$ git rev-parse HEAD
fa587a0d10fd627c1890345db640d1a55cfab3fc
$ cd buster/curl
$ nano -w Dockerfile
-FROM debian:buster
+FROM idein/actcast-rpi-app-base:buster # 大本のベースイメージをraspbian buster のdebootstrap最小構成に
$ docker build . -t idein/buildpack-deps:buster-curl
$ cd ../scm
$ nano -w Dockerfile
-FROM buildpack-deps:buster-curl
+FROM idein/buildpack-deps:buster-curl
$ docker build . -t idein/buildpack-deps:buster-scm
$ cd
```

### raspbian向けのgolangイメージ作成

```console
$ git clone git@github.com:docker-library/golang.git
$ cd golang
$ git rev-parse HEAD
103d42338bd9c3f661ade41f39dbc88fe9dc83a3
$ cd 1.13-rc/buster
$ nano -w Dockerfile
-FROM buildpack-deps:stretch-scm
+FROM idein/buildpack-deps:buster-scm
$ docker build . -t idein/golang:1.13-rc-buster
$ cd
```

### `containerd.io` パッケージング

```console
$ git clone https://github.com/Idein/containerd.io-for-raspbian
$ cd containerd.io-for-raspbian
$ docker build -t containerd-pkg-builder:1.2.7 .
$ docker run -v $(pwd):/root/deb containerd-pkg-builder:1.2.7
```

取り出しておく

```console
$ scp pi@pi0.local:containerd.io-for-raspbian/containerd.io_1.2.7-1_armhf.deb .
```

## 動作確認

[raspbian buster](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-07-12/2019-07-10-raspbian-buster-lite.zip)を焼いて起動．以下，パッケージング時と同様にsshできたとこから

おやくそく

```console
$ sudo apt-get update
$ sudo apt-get upgrade -y
$ sudo reboot
```

作ったパッケージを送り込んでおく．

```console
$ scp containerd.io_1.2.7-1_armhf.deb pi@testpi.local:
```

インストール

```console
$ sudo apt install ./containerd.io_1.2.7-1_armhf.deb
```

[docker-ceを拾ってきて](https://github.com/Idein/docker-ce-for-raspbian-buster/releases)インストール

```console
$ sudo apt install ./deb/docker-ce-cli_18.09.6~3-0~raspbian-buster_armhf.deb --no-install-recommends
$ sudo apt install ./deb/docker-ce_18.09.6~3-0~raspbian-buster_armhf.deb --no-install-recommends
```

実行

```console
$ sudo docker images
$ sudo docker run --rm idein/actcast-rpi-app-base:buster echo hello
$ hello
```

pi3環境でも同様に動作確認

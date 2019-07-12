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

```console
$ git clone https://github.com/Idein/containerd.io-for-raspbian
$ cd containerd.io-for-raspbian
$ docker build -t containerd-pkg-builder .
$ docker run -v $(pwd):/root/deb containerd-pkg-builder
```

取り出しておく

```console
$ scp pi@pi0.local:containerd.io-for-raspbian/containerd.io_1.2.7-1_armhf.deb .
```

## 動作確認


[raspbian buster](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-06-24/2019-06-20-raspbian-buster-lite.zip)を焼いて起動．以下，パッケージング時と同様にsshできたとこから

おやくそく

```console
$ sudo apt-get update --allow-releaseinfo-change # https://www.raspberrypi.org/forums/viewtopic.php?t=245073
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

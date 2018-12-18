
# Ubuntu设置代理

###设置Shell代理###

Ubuntu下`apt-get`的网络代理设置（终端命令行的网络代理设置）

**方法一**

如果只是想临时使用http代理，可以在使用`apt-get`之前于终端下输入：

```
export http_proxy="http://用户名:密码@代理IP:代理端口"
```

**方法二**

如果希望`apt-get`与其它应用程序都可以一直使用http代理，可以这样：

在终端下编辑~/.bashrc文件：

```
vim ~/.bashrc
```

在文件末尾添加如下两句：
```
export http_proxy=http://用户名:密码@代理地址:代理端口
export https_proxy=http://用户名:密码@代理地址:代理端口
export no_proxy="127.0.0.1, localhost, *.cnn.com, 192.168.1.10, domain.com:8080"
```

然后执行下面命令，使环境变量生效

```
source ~/.bashrc
```

**方法三**

如果只是希望apt-get使用代理，在终端下编辑/etc/apt/apt.conf加入下面这行:
```
Acquire::http::Proxy “http://yourproxyaddress:proxyport”;
```

保存退出apt.conf。

###设置curl代理###

```
curl -x 10.0.0.172:80 www.wo.com.cn
```

此命令使用`10.0.0.172:80`这个代理服务器IP和端口访问站点`www.wo.com.cn`。参数说明，`-x`为设置代理，格式为`host[:port]`，其中`port`的缺省值为`1080`。

###设置wget代理###

```
wget -Y on -e "http_proxy=http://10.0.0.172:9201" "www.wo.com.cn"
```

此命令使用`10.0.0.172:9201`这个代理服务器IP和端口访问站点`www.wo.com.cn`。

参数说明，`-Y`是否使用代理，`-e`执行命令。

By Andy@2018-12-18 14:37:23
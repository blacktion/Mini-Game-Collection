# 五子棋游戏服务器部署指南

## 服务器端 (Python)

### 环境要求
- Python 3.8+
- Linux 服务器

### 部署步骤

1. **上传文件到服务器**
   ```bash
   scp -r server user@your-server:/path/to/gobang/
   ```

2. **安装依赖**
   ```bash
   cd /path/to/gobang/server
   pip3 install -r requirements.txt
   ```

3. **配置防火墙**
   ```bash
   # 开放5000端口
   sudo ufw allow 5000/tcp
   sudo ufw reload
   ```

4. **启动服务器**
   ```bash
   python3 app.py
   ```

5. **使用 systemd 守护进程（推荐）**
   
   创建服务文件 `/etc/systemd/system/gobang.service`:
   ```ini
   [Unit]
   Description=Gobang Game Server
   After=network.target

   [Service]
   User=your_username
   WorkingDirectory=/path/to/gobang/server
   ExecStart=/usr/bin/python3 /path/to/gobang/server/app.py
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```
   
   启动服务：
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable gobang
   sudo systemctl start gobang
   sudo systemctl status gobang
   ```

---

## 客户端端 (Flutter)

### 修改服务器地址

在 `app/lib/main.dart` 第 169 行，修改 `serverUrl`：
```dart
const String serverUrl = 'http://YOUR_SERVER_IP:5000';
```
将 `YOUR_SERVER_IP` 替换为你的服务器 IP 地址。

### 运行应用

```bash
cd app
flutter pub get
flutter run
```

### 打包发布

**Android:**
```bash
flutter build apk --release
# 或
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

---

## 游戏流程

1. 玩家A 创建房间，获得房间号
2. 玩家B 输入房间号加入房间
3. 双方选择 先手/后手
   - 如果选择相同，随机决定
   - 如果选择不同，先到先得
4. 开始对弈
5. 游戏结束显示结果
6. 点击"再来一局"重新选择先后手

---

## 技术架构

- **后端**: Flask + Flask-SocketIO (WebSocket 实时通信)
- **前端**: Flutter + socket_io_client
- **通信协议**: WebSocket + JSON

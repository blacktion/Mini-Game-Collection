#!/usr/bin/env python3
"""
使用 Gunicorn + Eventlet 运行生产环境服务器
推荐用于生产部署
"""

import eventlet
eventlet.monkey_patch()

from app import app, socketio

if __name__ == '__main__':
    print("Gobang Server starting with Gunicorn + Eventlet...")
    print("Production mode: Enabled")
    print("Server will listen on all interfaces")

#!/bin/bash

# 五子棋游戏服务器启停脚本

# 配置
APP_NAME="Mini_Game_Collection"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SCRIPT="$APP_DIR/app.py"
GUNICORN_SCRIPT="$APP_DIR/gunicorn_start.py"
LOG_FILE="$APP_DIR/game.log"
PID_FILE="$APP_DIR/game.pid"
VENV_DIR="$APP_DIR/venv"

# 运行模式: dev (开发) 或 prod (生产)
RUN_MODE="${RUN_MODE:-dev}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取PID
get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    else
        echo ""
    fi
}

# 激活虚拟环境
activate_venv() {
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate"
        print_info "已激活虚拟环境: $VENV_DIR"
        return 0
    else
        print_warn "虚拟环境不存在: $VENV_DIR"
        print_warn "将使用系统Python运行"
        return 1
    fi
}

# 检查进程是否运行
is_running() {
    local pid=$(get_pid)
    if [ -n "$pid" ]; then
        ps -p "$pid" > /dev/null 2>&1
        return $?
    fi
    return 1
}

# 启动服务
start() {
    if is_running; then
        print_warn "服务已在运行中 (PID: $(get_pid))"
        return 1
    fi

    # 激活虚拟环境
    activate_venv

    # 检查Python和依赖
    if ! command -v python3 &> /dev/null; then
        print_error "未找到 python3，请先安装 Python 3"
        return 1
    fi

    # 检查应用文件
    if [ ! -f "$APP_SCRIPT" ]; then
        print_error "未找到应用文件: $APP_SCRIPT"
        return 1
    fi

    print_info "正在启动五子棋游戏服务器..."
    print_info "运行模式: $RUN_MODE"
    print_info "使用 eventlet 异步模式以提高稳定性"

    # 获取Python解释器路径（优先使用虚拟环境）
    if [ -d "$VENV_DIR" ]; then
        PYTHON_CMD="$VENV_DIR/bin/python"
        GUNICORN_CMD="$VENV_DIR/bin/gunicorn"
    else
        PYTHON_CMD="python3"
        GUNICORN_CMD="gunicorn"
    fi

    # 后台启动应用
    cd "$APP_DIR" || exit 1

    if [ "$RUN_MODE" = "prod" ]; then
        # 生产模式: 使用 Gunicorn + Eventlet
        print_info "使用 Gunicorn + Eventlet 启动生产服务器"
        nohup "$GUNICORN_CMD" --worker-class eventlet -w 1 --bind 0.0.0.0:5000 "gunicorn_start:socketio" > "$LOG_FILE" 2>&1 &
    else
        # 开发模式: 直接运行 (内置eventlet支持)
        print_info "使用 Flask + Eventlet 启动开发服务器"
        nohup "$PYTHON_CMD" -u "$APP_SCRIPT" > "$LOG_FILE" 2>&1 &
    fi

    local pid=$!

    # 保存PID
    echo "$pid" > "$PID_FILE"

    # 等待进程启动
    sleep 2

    if is_running; then
        print_info "服务启动成功!"
        print_info "进程名: $APP_NAME"
        print_info "PID: $pid"
        print_info "Python: $PYTHON_CMD"
        print_info "异步模式: eventlet"
        print_info "日志文件: $LOG_FILE"
        print_info ""
        print_info "提示: 使用 '$0 logs' 查看实时日志"
        return 0
    else
        print_error "服务启动失败，请查看日志: $LOG_FILE"
        print_error "常见问题:"
        print_error "  1. 检查是否已安装 eventlet: pip install eventlet"
        print_error "  2. 检查端口 5000 是否被占用: netstat -tuln | grep 5000"
        print_error "  3. 查看详细日志: tail -f $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 停止服务
stop() {
    if ! is_running; then
        print_warn "服务未运行"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid=$(get_pid)
    print_info "正在停止服务 (PID: $pid)..."

    # 优雅停止
    kill "$pid" 2>/dev/null

    # 等待进程结束
    local count=0
    while is_running && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done

    # 如果还没停止，强制杀死
    if is_running; then
        print_warn "服务未响应，强制停止..."
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi

    if is_running; then
        print_error "服务停止失败"
        return 1
    else
        print_info "服务已停止"
        rm -f "$PID_FILE"
        return 0
    fi
}

# 查看状态
status() {
    if is_running; then
        local pid=$(get_pid)
        local memory=$(ps -p "$pid" -o rss= | awk '{printf "%.2f MB", $1/1024}')
        local cpu=$(ps -p "$pid" -o %cpu= | awk '{printf "%.1f%%", $1}')
        local uptime=$(ps -p "$pid" -o etime= | xargs)
        
        echo ""
        echo "========================================="
        echo "  五子棋游戏服务器状态"
        echo "========================================="
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo "  进程名: $APP_NAME"
        echo "  PID: $pid"
        echo "  异步模式: eventlet"
        echo "  CPU使用率: $cpu"
        echo "  内存占用: $memory"
        echo "  运行时间: $uptime"
        echo "  日志文件: $LOG_FILE"
        echo "========================================="
        echo ""
        
        # 检查端口5000是否监听
        if command -v netstat &> /dev/null; then
            if netstat -tuln | grep -q ":5000 "; then
                print_info "端口 5000 正在监听"
            else
                print_warn "端口 5000 未监听"
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":5000 "; then
                print_info "端口 5000 正在监听"
            else
                print_warn "端口 5000 未监听"
            fi
        fi
        
        return 0
    else
        echo ""
        echo "========================================="
        echo "  五子棋游戏服务器状态"
        echo "========================================="
        echo -e "  状态: ${RED}已停止${NC}"
        echo "  进程名: $APP_NAME"
        echo "  提示: 使用 '$0 start' 启动服务"
        echo "========================================="
        echo ""
        return 1
    fi
}

# 查看日志
logs() {
    if [ ! -f "$LOG_FILE" ]; then
        print_error "日志文件不存在: $LOG_FILE"
        return 1
    fi
    
    local lines=${1:-50}
    print_info "显示最后 $lines 行日志:"
    echo "----------------------------------------"
    tail -n "$lines" "$LOG_FILE"
    echo "----------------------------------------"
    print_info "实时查看日志: tail -f $LOG_FILE"
}

# 检查依赖
check_deps() {
    print_info "检查依赖环境..."
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        print_error "未找到 python3"
        return 1
    fi
    
    local python_version=$(python3 --version 2>&1)
    print_info "Python版本: $python_version"
    
    # 激活虚拟环境
    activate_venv
    
    # 检查关键依赖
    print_info "检查关键依赖包..."
    
    local missing_deps=()
    
    if ! python3 -c "import flask" 2>/dev/null; then
        missing_deps+=("flask")
    fi
    
    if ! python3 -c "import flask_socketio" 2>/dev/null; then
        missing_deps+=("flask-socketio")
    fi
    
    if ! python3 -c "import eventlet" 2>/dev/null; then
        missing_deps+=("eventlet")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_info "所有依赖已安装 ✓"
        print_info "  - flask ✓"
        print_info "  - flask-socketio ✓"
        print_info "  - eventlet ✓"
        return 0
    else
        print_error "缺少以下依赖:"
        for dep in "${missing_deps[@]}"; do
            print_error "  - $dep"
        done
        print_info "请运行: pip install -r requirements.txt"
        return 1
    fi
}

# 重启服务
restart() {
    print_info "正在重启服务..."
    stop
    sleep 2
    start
}

# 主函数
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    logs)
        logs "$2"
        ;;
    check)
        check_deps
        ;;
    *)
        echo "用法: $0 {start|stop|status|restart|logs [行数]|check}"
        echo ""
        echo "命令说明:"
        echo "  start    - 启动服务"
        echo "  stop     - 停止服务"
        echo "  status   - 查看服务状态"
        echo "  restart  - 重启服务"
        echo "  logs     - 查看日志（可选指定行数，默认50行）"
        echo "  check    - 检查依赖环境"
        echo ""
        echo "运行模式:"
        echo "  开发模式 (默认): RUN_MODE=dev $0 start"
        echo "  生产模式: RUN_MODE=prod $0 start"
        echo ""
        echo "示例:"
        echo "  $0 start              # 开发模式启动 (使用eventlet)"
        echo "  RUN_MODE=prod $0 start # 生产模式启动 (使用Gunicorn+eventlet)"
        echo "  $0 status             # 查看服务状态"
        echo "  $0 logs 100           # 查看最后100行日志"
        echo "  $0 check              # 检查依赖环境"
        echo "  $0 restart            # 重启服务"
        exit 1
        ;;
esac

exit $?

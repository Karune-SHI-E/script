#!/data/data/com.termux/files/usr/bin/bash

# 定义颜色常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # 恢复默认颜色

# 配置文件参数
CONFIG_FILE="$HOME/.am_downloader.conf"
# 仓库克隆
REPO_DIR="apple-music-alac-atmos-downloader"
# 下载目录
DEFAULT_ALAC_PATH="/storage/emulated/0/Music/AM/AM-DL"
# 杜比下载目录
DEFAULT_ATMOS_PATH="/storage/emulated/0/Music/AM/AM-DL-Atmos"
# 首次安装检测
INSTALL_FLAG="$HOME/.install_done"
# 日志文件路径
LOG_FILE="$HOME/install.log"

# 日志级别常量
LOG_INFO="INFO"
LOG_WARNING="WARNING"
LOG_ERROR="ERROR"

# 播放音频文件或URL的函数
play_audio() {
    local audio_source="$1"
    if command -v mpv >/dev/null 2>&1; then
        # 使用mpv播放音频，静默模式
        mpv --quiet "$audio_source" > /dev/null 2>&1 &
        disown  # 确保mpv在后台继续运行
    elif command -v vlc >/dev/null 2>&1; then
        # 使用vlc播放音频，静默模式
        vlc "$audio_source" --play-and-exit --quiet &
        disown  # 确保vlc在后台继续运行
    else
        echo "未安装音频播放器（mpv 或 vlc），无法播放音频。"
    fi
}

# 播放启动音频
STARTUP_AUDIO_SOURCE="$HOME/你干嘛.wav"
play_audio "$STARTUP_AUDIO_SOURCE"

# 退出时播放音频
EXIT_AUDIO_SOURCE="$HOME/嘛你干.wav"

# 创建日志文件函数
create_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        # 创建日志文件并检查权限
        touch "$LOG_FILE"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[INFO] 日志文件已创建${NC}" >> "$LOG_FILE"
        else
            echo -e "${RED}[ERROR] 无法创建日志文件！${NC}" >&2
            exit 1
        fi
    fi
}

# 日志输出函数
log_message() {
    local level="$1"
    local message="$2"
    
    # 获取当前时间
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # 构建日志消息
    local log_entry="[$timestamp] [$level] $message"

    # 输出到终端并高亮不同级别的日志
    case $level in
        "INFO")
            echo -e "${GREEN}$log_entry${NC}"  # INFO以绿色显示
            ;;
        "WARNING")
            echo -e "${YELLOW}$log_entry${NC}"  # WARNING以黄色显示
            ;;
        "ERROR")
            echo -e "${RED}$log_entry${NC}"  # ERROR以红色显示
            ;;
        *)
            echo -e "$log_entry"
            ;;
    esac

    # 输出到日志文件
    echo "$log_entry" >> "$LOG_FILE"
}

# 用于输出信息日志
log_info() {
    log_message "$LOG_INFO" "$1"
}

# 用于输出警告日志
log_warning() {
    log_message "$LOG_WARNING" "$1"
}

# 用于输出错误日志
log_error() {
    log_message "$LOG_ERROR" "$1"
}

# 初始化日志文件
create_log_file
log_info "脚本启动，开始执行安装过程..."

# 检查是否已经安装过
if [ -f "$INSTALL_FLAG" ]; then
    log_info "已经安装过，无需重新运行安装步骤。"
else
    # 首次运行时更新软件包
    log_info "更新软件源并升级系统..."
    pkg update -y && pkg upgrade -y
    touch "$INSTALL_FLAG"  # 标记已安装

    # 下载并解压 Bento4 工具
    BENTO4_ZIP="bento4.zip"
    BENTO4_URL="https://github.com/Karune-SHI-E/script/releases/download/tgs/bento4_tools_android.zip"
    INSTALL_DIR="$PREFIX/bin"

    log_info "开始下载 Bento4 工具..."
    wget -O "$BENTO4_ZIP" -q "$BENTO4_URL"

    log_info "开始解压 Bento4 工具..."
    unzip -qo "$BENTO4_ZIP" -d "$INSTALL_DIR"

    log_info "清理临时文件..."
    rm -f "$BENTO4_ZIP"

    log_info "Bento4 工具下载和解压完成！"
fi

# 需要安装的软件包
REQUIRED_PKGS=(git golang gpac ffmpeg yq unzip wget vim mpv)
declare -A PKG_DESC=(
    [git]="版本控制工具"
    [golang]="Go语言环境"
    [gpac]="MP4多媒体处理"
    [ffmpeg]="音视频转码工具"
    [yq]="YAML配置处理器"
    [unzip]="解压缩工具"
    [wget]="文件下载工具"
    [vim]="文本编辑器"
    [mpv]="mpv音频"
)

# 依赖安装检查
install_dependencies() {
    log_info "检查系统依赖..."
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            log_info "正在安装 ${PKG_DESC[$pkg]} ($pkg)..."
            pkg install -y "$pkg" || {
                log_error "$pkg 安装失败! 请手动执行："
                log_error "pkg install $pkg"
                exit 1
            }
        else
            log_info "$pkg 已安装，跳过..."
        fi
    done

    log_info "所有依赖包检查完成！"
}

# 初始化配置
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" <<EOF
# Apple Music 下载配置
ALAC_SAVE_FOLDER="$DEFAULT_ALAC_PATH"
ATMOS_SAVE_FOLDER="$DEFAULT_ATMOS_PATH"
EOF
    fi
    source "$CONFIG_FILE"
    log_info "配置文件加载完成：$CONFIG_FILE"
}

# 增强存储权限检查
check_storage() {
    while [ ! -d "/storage/emulated/0/" ]; do
        clear
        log_warning "必须授予存储权限才能继续！"
        log_info "请按以下步骤操作："
        log_info "1. 在Termux中执行以下命令："
        log_info "   termux-setup-storage"
        log_info "2. 在系统弹窗中点击 [允许]"
        log_info "3. 按回车键继续..."
        read -p ""
        
        termux-setup-storage
        sleep 3
        
        if [ ! -d "/storage/emulated/0/" ]; then
            log_error "授权未完成，请检查："
            log_error "1. 已正确执行 termux-setup-storage"
            log_error "2. Termux已获得存储权限"
            log_error "3. 重新启动Termux后重试"
            read -p "按回车键重试..."
        fi
    done
}

# 仓库管理
manage_repo() {
    REPO_URL="https://github.com/zhaarey/apple-music-alac-atmos-downloader.git"
    
    # 如果仓库目录不存在，克隆仓库
    if [ ! -d "$REPO_DIR" ]; then
        log_info "仓库目录不存在，开始克隆仓库..."
        git clone --depth=1 "$REPO_URL" "$REPO_DIR" || {
            log_error "仓库克隆失败! 请检查网络或 Git 配置"
            exit 1
        }
        log_info "仓库克隆成功，开始编译项目..."
        pushd "$REPO_DIR" > /dev/null
        go run .
        popd > /dev/null
    else
        # 仓库目录已存在，检查是否有更新
        log_info "仓库已存在，检查更新..."
        pushd "$REPO_DIR" > /dev/null

        # 获取本地和远程仓库的当前 commit ID
        LOCAL_COMMIT=$(git rev-parse HEAD)
        REMOTE_COMMIT=$(git ls-remote origin -h refs/heads/$(git rev-parse --abbrev-ref HEAD) | awk '{print $1}')

        # 判断本地和远程仓库是否一致
        if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
            log_info "发现新版本，正在拉取更新..."
            git fetch origin
            git merge origin/$(git rev-parse --abbrev-ref HEAD) || {
                log_warning "合并过程中出现冲突，请手动解决冲突"
                popd > /dev/null
                exit 1
            }
            log_info "仓库更新完成，当前版本：$(git rev-parse HEAD)"
        else
            log_info "当前已是最新版本"
            sleep 3
            echo "已停留3秒"
        fi

        popd > /dev/null
    fi
}

# 路径有效性验证
validate_path() {
    if ! mkdir -p "$1" 2>/dev/null; then
        log_error "无法创建目录：$1"
        return 1
    fi
    
    if ! touch "$1/.testwrite" 2>/dev/null; then
        log_error "目录不可写：$1"
        return 1
    fi
    
    rm -f "$1/.testwrite"
    return 0
}

# URL有效性验证
validate_url() {
    local url="$1"
    if [[ "$url" != *"music.apple.com"* ]]; then
        log_error "链接格式错误，请输入有效的Apple Music链接"
        return 1
    fi
    return 0
}

# 配置菜单
config_menu() {
    while :; do
        clear
        echo -e "${GREEN}==== 系统配置 ====${NC}"
        echo "1. 路径配置"
        echo "0. 返回主菜单"
        read -p "请选择: " choice

        case $choice in
        1)
            path_config_menu
            ;;
        0)
            break
            ;;
        *)
            echo -e "${RED}无效选项!${NC}"
            sleep 1
            ;;
        esac
    done
}

# 路径配置菜单
path_config_menu() {
    while :; do
        clear
        echo -e "${GREEN}==== 下载路径配置 ====${NC}"
        echo "1. 修改普通音频路径 (当前: $ALAC_SAVE_FOLDER)"
        echo "2. 修改杜比全景声路径 (当前: $ATMOS_SAVE_FOLDER)"
        echo "3. 测试当前路径有效性"
        echo "4. 恢复默认配置"
        echo "0. 返回上级菜单"
        read -p "请选择: " choice

        case $choice in
        1)
            read -p "请输入新路径: " new_path
            if validate_path "$new_path"; then
                ALAC_SAVE_FOLDER="$new_path"
                sed -i "s|ALAC_SAVE_FOLDER=.*|ALAC_SAVE_FOLDER=\"$new_path\"|" "$CONFIG_FILE"
                echo -e "${GREEN}路径更新成功！${NC}"
            else
                log_error "路径设置失败，请检查termux权限！"
            fi
            sleep 2
            ;;
        2)
            read -p "请输入新路径: " new_path
            if validate_path "$new_path"; then
                ATMOS_SAVE_FOLDER="$new_path"
                sed -i "s|ATMOS_SAVE_FOLDER=.*|ATMOS_SAVE_FOLDER=\"$new_path\"|" "$CONFIG_FILE"
                echo -e "${GREEN}路径更新成功！${NC}"
            else
                log_error "路径设置失败，请检查termux权限！"
            fi
            sleep 2
            ;;
        3)
            echo -e "\n${CYAN}路径有效性测试：${NC}"
            validate_path "$ALAC_SAVE_FOLDER" && \
            echo -e "普通音频路径: ${GREEN}有效${NC}" || \
            echo -e "普通音频路径: ${RED}无效${NC}"
            
            validate_path "$ATMOS_SAVE_FOLDER" && \
            echo -e "杜比全景声路径: ${GREEN}有效${NC}" || \
            echo -e "杜比全景声路径: ${RED}无效${NC}"
            read -p "按回车键继续..."
            ;;
        4)
            ALAC_SAVE_FOLDER="$DEFAULT_ALAC_PATH"
            ATMOS_SAVE_FOLDER="$DEFAULT_ATMOS_PATH"
            sed -i "s|ALAC_SAVE_FOLDER=.*|ALAC_SAVE_FOLDER=\"$DEFAULT_ALAC_PATH\"|" "$CONFIG_FILE"
            sed -i "s|ATMOS_SAVE_FOLDER=.*|ATMOS_SAVE_FOLDER=\"$DEFAULT_ATMOS_PATH\"|" "$CONFIG_FILE"
            echo -e "${GREEN}已恢复默认路径配置！${NC}"
            sleep 1
            ;;
        0)
            break
            ;;
        *)
            echo -e "${RED}无效选项!${NC}"
            sleep 1
            ;;
        esac
    done
}

# 使用帮助信息
show_help() {
    clear
    echo -e "${GREEN}==== 使用说明 ====${NC}"
    echo -e "\n${GREEN}★ 链接格式示例${NC}"
    echo -e "  - 专辑: https://music.apple.com/us/album/whenever-you-need-somebody-2022-remaster/1624945511"
    echo -e "  - 歌单: https://music.apple.com/us/playlist/taylor-swift-essentials/pl.3950454ced8c45a3b0cc693c2a7db97b9"
    echo -e "  - 杜比: https://music.apple.com/us/album/1989-taylors-version-deluxe/1713845538 (需带杜比标记)"
    
    echo -e "\n${GREEN}★ m3u8端口模式说明${NC}"
    echo -e "  - true: 满血端口"
    echo -e "  - false: 残血端口"

    echo -e "\n${RED}⚠ 常见问题${NC}"
    echo -e "  - 解密错误 127.0.0.1:10020 → 重启客户端"
    echo -e "  - 下载24 192出现 EOF错误 → 把get-m3u8-from-device: true（把true改成false）"
    echo -e "  - 下载完成后→ 改成true，不然后续下载是残血"
    echo -e "  - nano /data/data/com.termux/files/home/apple-music-alac-atmos-downloader/config.yaml"
    echo -e "\n${YELLOW}按任意键返回主菜单...${NC}"
    read -n1 -s
}

# 下载功能
run_download() {  
    local choice=$1
    cd "$REPO_DIR" || { echo -e "${RED}无法进入项目目录！${NC}"; return 1; }

    # 更新配置文件
    yq eval ".alac-save-folder = \"$ALAC_SAVE_FOLDER\"" -i config.yaml  
    yq eval ".atmos-save-folder = \"$ATMOS_SAVE_FOLDER\"" -i config.yaml

    while true; do
        # 获取有效链接
        while :; do
            read -p "请输入有效链接（或输入 0 返回主菜单）: " url
            if [[ "$url" == "0" ]]; then
                cd ..
                return
            fi
            if validate_url "$url"; then
                break
            fi
        done

        case $choice in  
        1)  
            echo -e "${CYAN}开始下载指定曲目...${NC}"  
            go run main.go --select "$url"
            ;;  
        2)  
            echo -e "${CYAN}开始下载专辑内容...${NC}"  
            go run main.go "$url"  
            ;;  
        3)  
            echo -e "${CYAN}开始下载杜比全景声...${NC}"  
            go run main.go --atmos "$url"  
            ;;  
        esac  

        # 显示保存路径  
        echo -e "\n${GREEN}文件保存位置："  
        [ $choice -ne 3 ] && echo -e "普通音频: ${CYAN}$ALAC_SAVE_FOLDER${NC}"  
        [ $choice -eq 3 ] && echo -e "杜比全景声: ${CYAN}$ATMOS_SAVE_FOLDER${NC}"  
    done

    cd ..
}

# 查看专辑质量
chakan_zhuanji() {  
    cd "$REPO_DIR" || { echo -e "${RED}无法进入项目目录！${NC}"; return 1; }

    while true; do
        # 获取有效链接
        while :; do
            read -p "请输入有效链接（或输入 0 返回主菜单）: " url
            if [[ "$url" == "0" ]]; then
                cd ..
                return
            fi
            if validate_url "$url"; then
                break
            fi
        done

        echo -e "${CYAN}正在获取专辑质量信息...${NC}"
        go run main.go --debug "$url"
    done
}

# 主程序流程
init_config
check_storage
install_dependencies
manage_repo

# 主菜单循环
while :; do
    clear
    echo -e "${GREEN}==== Apple Music 下载器 ====${NC}"
    echo "1. 下载指定曲目"
    echo "2. 下载专辑/歌单"
    echo "3. 下载杜比全景声"
    echo "4. 查看专辑质量"
    echo "5. 系统配置"
    echo "6. 使用说明"
    echo "0. 退出程序"
    read -p "请输入选项 [1-0]: " choice

    case $choice in
    1|2|3)  run_download $choice ;;
    4)      chakan_zhuanji ;;
    5)      config_menu ;;
    6)      show_help ;;
    0)      echo -e "${GREEN}感谢使用，再见！${NC}"; 
            play_audio "$EXIT_AUDIO_SOURCE"
            sleep 3  # 等待音频播放完成
            exit 0 ;;
    *)      echo -e "${RED}无效选项，请重新输入！${NC}"; sleep 1 ;;
    esac
done
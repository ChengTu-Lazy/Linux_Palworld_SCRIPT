#!/bin/bash
#History:
# 2024年1月31日 诚徒开始编辑
# 2024年2月2日 完成主要功能，实现一键开服关服，崩服自动重启，自动更新游戏，备份游戏存档功能
# 2024年2月4日 新增配置文件修改功能

#脚本版本
SCRIPT_VERSION="1.0.1"
# 脚本当前名称
SCRIPT_NAME=$(basename "$0")
# 脚本当前所在目录
SCRIPT_PATH=$(pwd)
# git加速链接
ACCELERATION_URL="https://ghp.quickso.cn/https://github.com/ChengTu-Lazy//Linux_Palworld_SCRIPT"
# 当前系统版本
OS=$(awk -F = '/^NAME/{print $2}' /etc/os-release | sed 's/"//g' | sed 's/ //g' | sed 's/Linux//g' | sed 's/linux//g')
#默认安装路径
PALWORLD_DEFAULT_PATH="$HOME/.Palworld"
#默认配置文件所在位置
DEFAULTPALWORLDSETTINGS_PATH="$PALWORLD_DEFAULT_PATH/DefaultPalWorldSettings.ini"
#默认存档所在位置
PALWORLD_SAVES_PATH="$HOME/.Palworld/Pal/Saved"

# 获取最新版脚本
get_latest_script() {
	if [ -d "$HOME/clone_tamp" ]; then
		rm -rf "$HOME/clone_tamp"
		mkdir "$HOME/clone_tamp"
	else
		mkdir "$HOME/clone_tamp"
	fi
	clear
	echo "下载时间超过10s,就是网络问题,请CTRL+C强制退出,再次尝试,实在不行手动下载最新的。"
	cd "$HOME/clone_tamp" || exit
	echo "是否使用git加速链接下载?"
	echo "请输入 Y/y 同意 或者 N/n 拒绝并使用官方链接,推荐使用加速链接,失效了再用原版链接,默认回车直接使用加速链接"
	read -r use_acceleration
	if [ "${use_acceleration}" == "Y" ] || [ "${use_acceleration}" == "y" ] || [ "${use_acceleration}" == "" ]; then
		git clone "${ACCELERATION_URL}"
	elif [ "${use_acceleration}" == "N" ] || [ "${use_acceleration}" == "n" ]; then
		git clone "https://github.com/ChengTu-Lazy/Linux_Palworld_SCRIPT.git"
	else
		echo "输入有误,请重新输入"
		get_latest_script
	fi
	cp "$HOME/clone_tamp/Linux_Palworld_SCRIPT/Palworld_SCRIPT.sh" "$SCRIPT_PATH/$SCRIPT_NAME"
	cd "$SCRIPT_PATH" || exit
	rm -rf "$HOME/clone_tamp"
	clear
	bash "$SCRIPT_PATH"/"$SCRIPT_NAME"
}

#前期准备
prepare() {
	if [ ! -d "$HOME/Steam" ] ; then
		pre_library
	fi
	# 下载游戏本体
	if [ ! -f "$PALWORLD_DEFAULT_PATH/PalServer.sh" ] || [ ! -f "$HOME"/.steam/sdk64/steamclient.so ]; then
		echo "正在下载幻兽帕鲁游戏64位依赖!!!"
		steamcmd +login anonymous +app_update 1007 +quit
		echo "幻兽帕鲁游戏64位依赖下载完成!!!"
		mkdir -p "$HOME"/.steam/sdk64/
		cp "$HOME"/Steam/steamapps/common/Steamworks\ SDK\ Redist/linux64/steamclient.so "$HOME"/.steam/sdk64/
		echo "正在下载幻兽帕鲁游戏本体！！！"
		steamcmd +force_install_dir "$PALWORLD_DEFAULT_PATH" +login anonymous +app_update 2394010 validate +quit
		echo "幻兽帕鲁游戏本体下载完成！！！"
	fi
}

pre_library(){
	if [ "$OS" == "Ubuntu" ]; then
		echo ""
		echo "##########################"
		echo "# 加载 Ubuntu Linux 环境 #"
		echo "##########################"
		echo ""
				
		if [ "$(uname -m)" = "x86_64" ]; then
			sudo add-apt-repository multiverse
			sudo dpkg --add-architecture i386
			sudo apt update
			sudo apt install lib32gcc1 steamcmd 
		fi

		if [ "$(which steamcmd)" != "/usr/games/steamcmd" ]; then
			sudo apt install steamcmd
		fi

		#一些必备工具
		sudo apt-get -y install screen
		sudo apt-get -y install htop
		sudo apt-get -y install gawk
		sudo apt-get -y install zip unzip
		sudo apt-get -y install git
	fi
}

#检查是否成功开启
start_server_check() {
	start_time=$(date +%s)
	if [[ "$(screen -ls | grep --text -c "\<PalServer\>")" -gt 0 ]];then
		flag=true
		while $flag 
		do
			echo -en "\r服务器开启中,预计等待12s,请稍后.                              "
			sleep 1
			echo -en "\r服务器开启中,预计等待12s,请稍后..                             "
			sleep 1
			echo -en "\r服务器开启中,预计等待12s,请稍后...                            "
			if [ "$(grep --text "Loaded '$HOME/.steam/sdk64/steamclient.so' OK" -c "$PALWORLD_DEFAULT_PATH/PalServer.log")" -gt 0 ]
			then
				echo -e "\n\r\e[92m服务器启动完成!!!                            \e[0m"
				flag=false
			fi
			sleep 1
		done
		
		end_time=$(date +%s)
		cost_time=$((end_time - start_time))
		cost_minutes=$((cost_time / 60))
		cost_seconds=$((cost_time % 60))
		cost_echo="$cost_minutes分$cost_seconds秒"
		echo -e "\r\e[92m本次开服花费时间: $cost_echo\e[0m"
		sleep 1
	fi

}

#查看游戏更新情况
checkupdate() {
	# 保存buildid的位置
	DST_now=$(date +%Y年%m月%d日%H:%M)
	# 判断一下对应开启的版本
	# 获取最新buildid
	echo "正在获取最新buildid。。。"
	latest_buildid=$(steamcmd +login anonymous +app_info_update 1 +app_info_print 2394010 +quit | sed -e '/"branches"/,/^}/!d' | sed -n "/\"public\"/,/}/p" | grep --text -m 1 buildid | sed 's/[^0-9]//g') 	
	#查看buildid是否一致
	if [[ $latest_buildid -gt $(grep --text -m 1 buildid "$PALWORLD_DEFAULT_PATH"/steamapps/appmanifest_2394010.acf | sed 's/[^0-9]//g') ]]; then
		echo " "
		echo -e "\e[31m${DST_now}:游戏服务端有更新! \e[0m"
		echo " "
		# 更新游戏本体
		echo -e "\e[33m${DST_now}:更新游戏中。。。 \e[0m"
		update_game
	else
		echo -e "\e[92m${DST_now}:游戏服务端没有更新!\e[0m"
	fi
}

auto_update(){
	# 配置auto_update.sh
	printf "%s" "#!/bin/bash
	# 当前脚本所在位置及名称
	script_path_name=\"$SCRIPT_PATH/$SCRIPT_NAME\"
	# 使用脚本的方法
	script(){
		bash \$script_path_name \"\$1\" \"-AUTO\"
	}
	backup()
	{
		# 自动备份
		if [ \"\$timecheck\" == 0 ];then
			if [  -d \"$PALWORLD_SAVES_PATH\" ];then
				cd \"$PALWORLD_SAVES_PATH\" || exit
				if [ ! -d \"$PALWORLD_SAVES_PATH/saves_bak\" ];then
					mkdir saves_bak
				fi
				cd \"$PALWORLD_SAVES_PATH/saves_bak\" || exit
				master_saves_bak=\$(find . -maxdepth 1 -name '*.zip' | wc -l)
				if [ \"\$master_saves_bak\" -gt 101 ];then
					find . -maxdepth 1 -mtime +30 -name '*.zip'  | awk '{if(NR -gt 10){print \$1}}' |xargs rm -f {};
				fi
				cd \"$PALWORLD_SAVES_PATH\"|| exit
				time=\$(date "+%Y%m%d%H%M%S")
				zip -r saves_bak/\"backup_\$time\".zip SaveGames/ >> /dev/null 2>&1
			fi
		fi
	}
	timecheck=0
	# 保持运行
	while :
			do
				script -checkprocess
				timecheck=\$(( timecheck%750 ))
				backup
				((timecheck++))
				script -checkupdate
				sleep 10
			done
	" >"$PALWORLD_DEFAULT_PATH"/auto_update.sh
	chmod 777 "$PALWORLD_DEFAULT_PATH"/auto_update.sh
	screen -dmS "PalServer_AutoUpdate" /bin/sh -c "$PALWORLD_DEFAULT_PATH/auto_update.sh"
	echo -e "\e[92m自动更新进程 PalServer_AutoUpdate 已启动\e[0m"
	sleep 1
}

start_server(){
	if [[ "$(screen -ls | grep --text -c "\<PalServer\>")" -gt 0 ]];then
		echo 服务器已经启动了,请勿重复启动！
	else
		rm -rf "$PALWORLD_DEFAULT_PATH"/PalServer.log
		chmod 777 "$PALWORLD_DEFAULT_PATH"/PalServer.sh
		screen -dmS  "PalServer" bash "$PALWORLD_DEFAULT_PATH"/PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS  
		screen -S  "PalServer" -X logfile "$PALWORLD_DEFAULT_PATH"/PalServer.log
		screen -S PalServer -X log on
		start_server_check
		
	fi
	if [[ "$(screen -ls | grep --text -c "\<PalServer_AutoUpdate\>")" -le 0 ]];then
		auto_update
	fi
}

# 关闭服务器
close_server() {
	# 进程名称符合就删除
	while :; do
		if [[ $(screen -ls | grep --text -c "\<PalServer\>") -gt 0 ]]; then
			for i in $(screen -ls | grep --text -w "\<PalServer\>" | awk '/[0-9]{1,}\./ {print strtonum($1)}'); do
				kill "$i"
				echo -e "\r\e[92m服务器已关闭!!!                   \e[0m "
				sleep 0.2
			done
		else
			break
		fi

		if [[ $(screen -ls | grep --text -c "\<PalServer_AutoUpdate\>") -gt 0 ]]; then
			for i in $(screen -ls | grep --text -w "\<PalServer_AutoUpdate\>" | awk '/[0-9]{1,}\./ {print strtonum($1)}'); do
				kill "$i"
				echo -e "\r\e[92m服务器自动更新进程已关闭!!!                   \e[0m "
				sleep 0.2
			done
		else
			break
		fi
	done
}

# 更新游戏
update_game() {
	echo "正在更新游戏,请稍后。。。更新之后重启服务器生效哦。。。"
	echo "同步最新正式版游戏本体内容中。。。"
	steamcmd +force_install_dir "$PALWORLD_DEFAULT_PATH" +login anonymous +app_update 2394010 validate +quit
	echo 更新完成
}

#重启游戏
restart_server(){
	close_server
	start_server
}

init(){
	# 初始化环境
	rm -rf "$HOME"/Steam
	rm -rf "$PALWORLD_DEFAULT_PATH/PalServer.sh"
	pre_library
	prepare
}

#查看进程执行情况
checkprocess() {
	if [[ $(screen -ls | grep --text -c "\<PalServer\>") -eq 1 ]]; then
		echo "服务器运行正常"
	else
		echo "服务器已经关闭,自动开启中。。。"
		start_server -auto
	fi
}

update_config_option() {
    # 从参数中获取配置文件路径、选项名称和新的选项值
    local config_file="$DEFAULTPALWORLDSETTINGS_PATH"
    local option_name="$1"
    local new_value="$2"

    # 使用awk命令获取选项的当前值
    get_current_config_value "$option_name"
	
    # 使用sed命令替换选项的当前值为新的选项值
    sed -i "s/$option_name=$current_config_value/$option_name=$new_value/" "$config_file"
}


get_current_config_value(){
	local config_file="$DEFAULTPALWORLDSETTINGS_PATH"
    local option_name="$1"
	current_config_value=$(grep -Po "(?<=$option_name=)[^,]+" "$config_file")
}


update_config(){
	local config_option=$1
	local prompt_message=$2
	
	echo_current_config_value "$config_option"

	echo -e "\e[92m$prompt_message\e[0m"
	read -r read_val
	
	update_config_option "$config_option" "$read_val"
	echo "设置完成！"
}

update_config_with_num() {
	local config_option=$1
	local prompt_message=$2
	
	echo_current_config_value "$config_option"

	echo -e "\e[92m$prompt_message\e[0m"
	read -r read_val
	
	# 判断变量是否为数字
	if [[ $read_val =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		update_config_option "$config_option" "$read_val"
		echo -e "\e[92m设置完成！\e[0m"
	else
		echo -e "\e[31m输入的并不是数字，请重新设置\e[0m"
		change_config
	fi
}

update_config_with_str(){
	local config_option=$1
	local prompt_message=$2
	
	echo_current_config_value "$config_option"

	echo -e "\e[92m$prompt_message\e[0m"
	read -r read_val
	
	update_config_option "$config_option" "\"$read_val\""
	echo "设置完成！"
}

update_config_with_bool(){
	local config_option=$1
	local prompt_message=$2
	
	echo_current_config_value "$config_option"

	echo -e "\e[92m$prompt_message\e[0m"
	read -r is_open_pvp
	if [[ $is_open_pvp = "Y" ]] || [[ $is_open_pvp = "y" ]]
	then
		update_config_option "bEnablePlayerToPlayerDamage" "True"
		echo PVP已开启!
	else
		update_config_option "bEnablePlayerToPlayerDamage" "False"
		echo PVP关闭!
	fi
}

echo_current_config_value(){
	local config_option=$1
	get_current_config_value "$config_option"
	echo -e "\e[92m当前值为：$current_config_value\e[0m"
}

# 更改配置
change_config() {
	while :; do
		echo "===========================!!!请输入需要进行的操作序号!!!==========================="
		echo "                                                                                  "
		echo "	[1]设置服务器名          [2]设置服务器描述        [3]设置服务器密码			"
		echo "                                                                                  "
		echo "	[4]设置服务器人数        [5]设置管理员密码        [6]设置服务器端口"
		echo "                                                                                  "
		echo "	[7]设置RCON端口号        [8]修改PVP设置(默认关)   [9]设置营地最大数"
		echo "                                                                                  "
		echo "	[10]设置营地精灵最大数   [11]设置掉落物最大数量   [12]设置精灵生成倍率"
		echo "                                                                                  "
		echo "	[13]设置经验倍率         [14]设置捕捉倍率         [15]设置孵蛋时间"
		echo "                                                                                  "
		echo "	[16]设置死亡掉落         "
		echo "                                                                                  "
		echo "===========================!!!输入其他值直接返回主菜单!!!==========================="
		echo "                                                                                  "
		echo -e "\e[92m请输入命令代号:\e[0m"
		read -r consoleinfo
		(case $consoleinfo in
			1) 
				update_config_with_str ServerName 请输入服务器名
				;;
			2)
				update_config_with_str ServerDescription 请输入服务器描述
				;;
			3)
				update_config_with_str ServerPassword 请输入服务器密码
				;;
			4)
				update_config_with_num ServerPlayerMaxNum 请输入服务器人数（上限为32）
				;;
			5)
				update_config_with_str AdminPassword 请输入管理员密码
				;;
			6)
				update_config_with_num PublicPort 请输入服务器端口，默认8211
				;;
			7)
				update_config_with_num RCONPort 请输入RCON端口，默认25575
				;;
			8)
				update_config_with_bool "bEnablePlayerToPlayerDamage" 输入Y/y开启PVP回车等其他为关闭PVP，默认关闭
				;;
			9)
				update_config_with_num BaseCampMaxNum 请输入营地最大数0-5000，默认128
				;;
			10)
				update_config_with_num BaseCampWorkerMaxNum 请输入营地中最多精灵数1-20，默认15
				;;
			11)
				update_config_with_num DropItemMaxNum 请输入世界掉落物上限0-5000，默认3000
				;;
			12)
				update_config_with_num PalSpawnNumRate 请输入精灵生成倍率0.5-3.0，默认1
				;;
			13)
				update_config_with_num ExpRate 请输入玩家经验倍率0.1-20.0，默认1
				;;	
			14)
				update_config_with_num PalCaptureRate 请输入捕捉倍率0.5-2.0，默认1
				;;	
			15)
				update_config_with_num PalEggDefaultHatchingTime 请输入巨大蛋孵蛋时间0-240H，默认72H
				;;	
			16)
				echo_current_config_value "DeathPenalty"
				echo -e "对应情况为\n1.None=不掉落任何物品\n2.Item=掉落装备以外的道具\n3.ItemAndEquipment=掉落所有物品\n4.All=掉落所有物品及队内帕鲁"
				echo -e "\e[92m请输入对应序号：\n1.不掉落任何物品\n2.掉落装备以外的道具\n3.掉落所有物品\n4.掉落所有物品及队内帕鲁\e[0m"
				read -r read_val
				if [ "$read_val" = "1" ] 
				then
					update_config_option "DeathPenalty" "None"
				elif [ "$read_val" = "2" ] 
				then
					update_config_option "DeathPenalty" "Item"
				elif [ "$read_val" = "3" ] 
				then
					update_config_option "DeathPenalty" "ItemAndEquipment"
				elif [ "$read_val" = "4" ] 
				then
					update_config_option "DeathPenalty" "All"
				else
					echo "请输入正确序号"
					change_config
				fi
				echo "设置完成！"
				;;	
			*)
				main
				;;
			esac)
	done
}

#主菜单
main() {
	while :; do
		tput setaf 2
		if [[ $(screen -ls | grep --text -c "\<PalServer\>") -gt 0 ]]; then
			server_staut="✅"
		else
			server_staut="❌"
		fi

		if [[ $(screen -ls | grep --text -c "\<PalServer_AutoUpdate\>") -gt 0 ]]; then
			autoUpdateServer_staut="✅"
		else
			autoUpdateServer_staut="❌"
		fi

		echo "============================================================"
		printf "%s\n" "                         脚本版本:${SCRIPT_VERSION}  "
		printf "%s\n" "          服务器当前状态: $server_staut  自动更新进程状态: $autoUpdateServer_staut  "
		echo "============================================================"
		echo "                                          	                 "
		echo "  [1]启动服务器      [2]关闭服务器       [3]更改配置文件     "
		echo "                                          	                 "
		echo "  [4]重启服务器      [5]重新安装环境     [6]手动更新服务器   "
		echo "                                          	                 "
		echo "  [7]获取最新脚本     "
		echo "                                          	                 "
		echo "============================================================"
		echo "                                                                                  "
		echo -e "\e[92m请输入命令代号:\e[0m"
		read -r selectedNum
		(case $selectedNum in
			1)
				start_server
				;;
			2)
				close_server
				;;
			3)
				change_config
				;;
			4)
				restart_server
				;;
			5)
				init
				;;
			6)
				update_game
				;;
			7)
				get_latest_script
				;;
			esac)
	done
}

# API
if [ "$1" == "-checkprocess" ]; then
	checkprocess "$2"
elif [ "$1" == "-checkupdate" ]; then
	checkupdate "$2"
elif [ "$1" == "" ] && [ "$2" == "" ]; then
	prepare
	main
fi
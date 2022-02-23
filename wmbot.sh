#!/bin/bash
bot_token="<bot_token>"
admin_id="your_chat_id"
dir="/path/to/dir"

# 后台进程数，超过这个进程数就不在开新进程了
processlmt=5

# 来肝个机器人使用数据统计函数
function botinfo(){
	if [ ! -f "$dir/.site.json" ]; then
		cat>"$dir/.site.json"<<-END
		{
			"totaluser":"0",
			"usrwithwm":"0",
			"totalvids":"0",
			"lastjoin":"null",
			"processes":"0",
			"apicrush":"0"
		}
		END
	else
		totaluser=$(cat "$dir/.site.json" | jq -r ".totaluser")
		usrwithwm=$(cat "$dir/.site.json" | jq -r ".usrwithwm")
		totalvids=$(cat "$dir/.site.json" | jq -r ".totalvids")
		lastjoin=$(cat "$dir/.site.json" | jq -r ".lastjoin")
		processes=$(cat "$dir/.site.json" | jq -r ".processes")
		apicrush=$(cat "$dir/.site.json" | jq -r ".apicrush")
	fi
}

# 向用户发送消息，代码内替换发送内容请搜索函数名
function sendtext(){
	curl -s \
    https://api.telegram.org/bot$bot_token/sendMessage \
    -d text="$stext" \
    -d chat_id="$chat_id"
}

# 向系统管理员发送消息，代码内替换发送内容请搜索函数名 2022/2/19 更新，如果时admin自己在操作发个什么提醒发
function sendadmin(){
	if [ "$admin_id" -ne "$chat_id" ]; then
		curl -s \
		https://api.telegram.org/bot$bot_token/sendMessage \
		-d text="$stext" \
		-d chat_id="$admin_id"
	fi
}

# log 记录，代码内替换发送内容请搜索函数名
function sendlog(){
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $stext" >> $dir/wmbot.log
}

# 设置水印文件
function setpng(){

    # 搞个30秒循环等待用户发送图片进来
    i=0
    local nmsg="$newmsg_id"
	
	# 当前用户的 chat_id 暂时保存下来以免与其他发新消息的用户混淆
	local current_id="$chat_id"
	
	# 生成一个 .lock 文件，如果检测到该用户的目录内有这个文件，他就进不去 getfile 函数内
	touch "$dir/$current_id/set.lock"
	
    while [ $i -le 30 ]
    do 
        local updt=$(curl -s https://api.telegram.org/bot$bot_token/getupdates)
        local newmsg_id=$(echo "$updt" | jq -r ".|.result|.[-1]|.message|.message_id")
		local chat_id=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.chat|.id") 

        # 这里做个判断如果新消息来了newmsg_id变得大于nmsg的时候进行下面判断
        if [ "$newmsg_id" -gt "$nmsg" ]; then
			# 比较当前用户的 chat_id 是否和当前用户的 chat_id 相符
			if [ "$current_id" -eq "$chat_id" ]; then			
				local mime=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|.document|.mime_type")
				if [[ $mime =~ image/png ]]; then
					local doc_id=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|.document|.file_id")
					local docinfo=$(curl -s https://api.telegram.org/bot$bot_token/getFile?file_id=$doc_id)
					local doc_url=$(echo $docinfo | jq -r ".|.result|.file_path")

					# 用户加水印的操作计入 site.json 内
					local usrwithwm=$((usrwithwm+1))
					sed -i "s/\"usrwithwm\":[^,}]*/\"usrwithwm\":\"$usrwithwm\"/g" "$dir/.site.json"

					wget "https://api.telegram.org/file/bot$bot_token/$doc_url" -O "$dir/$chat_id/config/watermark.png"

					stext="水印文件已经给你设置好了"
					sendtext
					stext="$first_name 设置了水印文件"
					sendlog

					# 管理员偷窥用户动态
					stext="$first_name 设置了个水印哦😬"
					sendadmin
					
					# 删除 .lock 文件，然后又能愉快的设置水印文件了
					rm -rf "$dir/$current_id/set.lock"
					break
				else
					stext="你发的好像不是 png 文件啊，发送的时候一定要记得取消勾选压缩哦"
					sendtext
					
					# 删除 .lock 文件
					rm -rf "$dir/$current_id/set.lock"
					break
				fi
			fi
        fi
    sleep 1s
    i=$((i + 1))
    done 

    # 当用户超时的时候嘲讽他
    if [ "$i" -ge 30 ]; then 
		local chat_id="$current_id"

		# 删除 .lock 文件
		rm -rf "$dir/$chat_id/set.lock"

        stext="你是猪啊，发个破图片半天发不过来"
        sendtext
		stext="$first_name 设置水印时超时,并被机器人无情的嘲讽了"
        sendlog

        # 管理员偷窥用户动态
        stext="$first_name 刚刚被我骂了，哈哈哈😂😂"
        sendadmin
    fi
}

# 加水印压缩
function compress(){

	# 临时存储函数范围内有效的变量，后台运行时避免与函数外的chat_id搞混，才学到
	local chat_id="$chat_id"
    if [ ! -d "$dir/$chat_id/watermarked" ]; then
        mkdir -p -- "$dir/$chat_id/watermarked/"
		sleep 1s
	fi

    # 判断用户配置目录是否存在
	if [ ! -d "$dir/$chat_id/config" ]; then
		mkdir -p -- "$dir/$chat_id/config"
		sleep 1s
	fi

    # 判断用户配置文件是否存在，没有就给写个默认的文件
	if [ ! -f "$dir/$chat_id/config/.config.json" ]; then
		cat>"$dir/$chat_id/config/.config.json"<<-END
		{
			"position": "lt",
			"count": "0",
			"jointime":"null"
		}
		END
		stext="$first_name 创建了自己的配置文件"
        sendlog

        # 管理员偷窥用户动态
        stext="$first_name 刚刚创建了自己的配置文件哦🤪"
        sendadmin

		# 最后一个注册用户，将其 first_name 计入 site.json 内
		local lastjoin="$first_name"
		sed -i "s/\"lastjoin\":[^,}]*/\"lastjoin\":\"$lastjoin\"/g" "$dir/.site.json"

		sleep 1s
	fi
	
	# 读取用户配置文件
	local configfile="$dir/$chat_id/config/.config.json"
	
	# position=$(cat "$configfile" | jq -r ".position") 暂时还没用
	local count=$(cat "$configfile" | jq -r ".count")
	local jointime=$(cat "$configfile" | jq -r ".jointime")

    # 判断用户是否设置了水印
    local wmark="$dir/$chat_id/config/watermark.png"
    if [ ! -f "$wmark" ]; then
        stext="你没设置水印文件哦，我只能给你打默认水印啦。回头自己设置一个水印文件吧。亲亲"
        sendtext
        cp -- "$dir/watermark.png" "$wmark"

        #在判断一下主目录内有没有默认水印文件
        if [ ! -f "$dir/watermark.png" ]; then
            touch "$dir/watermark.png"
        fi
    fi

	# 压缩主命令
    ffmpeg -i "$dir/$chat_id/$filename" \
    -i $wmark \
	-filter_complex "[1][0]scale2ref=w='if(gte(iw,ih),iw*20/100,iw*35/100)':h='ow/mdar'[vid][wm]; \
	[wm][vid]overlay=w/4:w/4:format=auto,format=yuv420p" \
	-c:a copy \
	-crf 28 \
    "$dir/$chat_id/watermarked/$filename"
    echo "转换完毕，现在要发回去了"

    # 获取视频的各种参数
    local media="$dir/$chat_id/watermarked/$filename"
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$media")
	local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$media")

    # 生成缩略图，上传完毕后需要删除掉这个缩略图文件
	local video_thumb="$media.jpeg"

	# 缩略图竖向和横向视频最长边设置为 400 像素
	if [ "$height" != null ]; then
		if [ "$height" -ge "$width" ]; then
			ffmpeg -i "$media" -ss 00:00:02.000 -vframes 1 -filter:v scale="-1:320" "$video_thumb" -y > /dev/null 2>&1
		elif [ "$width" -gt "$height" ]; then
			ffmpeg -i "$media" -ss 00:00:02.000 -vframes 1 -filter:v scale="320:-1" "$video_thumb" -y > /dev/null 2>&1
		fi
	fi

    stext="终于转换完了，我亲爱的大爷！累死个我了🥵 视频马上发给你，请稍等哦……"
    sendtext

	# 发送视频主命令
	curl -F thumb=@"$video_thumb" \
    -F video=@"$media" \
    -F width="$width" \
    -F height="$height" \
	-F -sendChatAction="videos" \
    https://api.telegram.org/bot$bot_token/sendVideo?chat_id=$chat_id > /dev/null 2>&1

    # 删除掉那个水印文件
    rm -rf -- "$video_thumb"
    sleep 5s
	local count=$((count + 1))

	# 将count写入用户配置文件
	sed -i "s/\"count\":[^,}]*/\"count\":\"$count\"/g" "$configfile"

	# 新增用户加入时间，以第一次加水印开始算起，一次性写入 2022/2/19更新
	if [[ $jointime =~ null ]]; then
		jointime=$(date "+%Y-%m-%d %H:%M:%S")
		sed -i "s/\"jointime\":[^}]*/\"jointime\":\"$jointime\"/g" "$configfile"
	fi

	# 转码视频计入 site.json 内
	local totalvids=$((totalvids+1))
	sed -i "s/\"totalvids\":[^,}]*/\"totalvids\":\"$totalvids\"/g" "$dir/.site.json"

    # 一系列俏皮话
    if [ $count -gt 200 ]; then
        stext="挖槽！ $first_name！！！你差不多得了这都是你第 $count 个加水印的视频了🧐 悠着点吧，你要累趴我啊"
    elif [ $count -gt 100 ]; then
        stext="哇！$first_name 大爷！你都压了 $count 个视频了呢，你不打算给我点工钱吗？🥺"
    elif [ $count -gt 50 ]; then
        stext="我勒个去，没想到啊 $first_name！不知不觉你给 $count 个视频加水印了呢，你是干啥的啊？"
    elif [ $count -gt 25 ]; then
        stext="$first_name先森！你在我这里已经加了 $count 个水印了，你怎么这么能加水印啊？"
    elif [ $count -gt 20 ]; then
        stext="哈哈 $first_name 大爷！好了好了，不逗你了，你在这里加了 $count 个视频水印了😆"
    elif [ $count -gt 10 ]; then
        stext="呵！$first_name 大哥，你都不爱我……我以后不给你报数了🙄"
    elif [ $count -gt 5 ]; then
        stext="亲爱的 $first_name ……我是你的报数机器人😊 到目前为止你在我这里加过水印视频数为：$count 个"
    elif [ $count -gt 2 ]; then
        stext="😅你还真的再来一个啊？这是你第 $count 个加水印的视频哦"
    else
        stext="怎么样啊？$first_name 大爷！要不要再来一个？这是你第 $count 个加水印的视频哦"
    fi
    sendtext
	stext="$first_name 压缩了一个文件(第$count次)：$filename"
	sendlog

	# 压缩完毕后线程数减1,并删掉.lock文件
	rm -rf "$dir/$chat_id/$newmsg_id.lock"
	processes=$(cat "$dir/.site.json" | jq -r ".processes")
	processes=$((processes-1))
	sed -i "s/\"processes\":[^,}]*/\"processes\":\"$processes\"/g" "$dir/.site.json"
}

function getfile(){
    local file_id=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|select(.video != null)|.video|.file_id")
    local filename=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|select(.video != null)|.video|.file_name")
    local vinfo=$(curl -s https://api.telegram.org/bot$bot_token/getFile?file_id=$file_id)
    local video_url=$(echo $vinfo | jq -r ".|.result|.file_path")
	local chat_id="$chat_id"

    if [ ! -d "$dir/$chat_id" ]; then
        mkdir -p -- "$dir/$chat_id"
	fi

    if [[ $filename =~ null ]] || [ -f "$dir/$chat_id/$filename" ]; then

        # video_2022-02-15_22-08-42.mp4 假如获取不到文件名，或者与已下载文件重名
        local filename="video_$(date "+%Y-%m-%d_%H-%M-%S").mp4"
    fi
    if [ ! -n "$file_id" ]; then
        stext="你倒是给我发个视频呀，大爷！"
        sendtext
		stext="$first_name 发了个非视频消息"
		sendlog
    else
        # 再加个 video_url 判断，因为 Telegram api 的限制如果文件超过20M 这个值是 null 会导致出错
        if [[ $video_url =~ null ]] || [ ! -n "$video_url" ];then 
			stext="$first_name 发来的的文件体积超限了"
			sendlog
            stext="哎呀妈呀，你这个视频好特么大啊，超过20M的文件不是我不想帮你加水印，Telegram 拦着不给我呀"
            sendtext
        else
            if [ ! -f "$dir/$chat_id/$newmsg_id.lock" ]; then

				# 生成一个当前 message_id 的.lock文件，以防止同一条消息的文件多次顺利通过这个判断
				touch "$dir/$chat_id/$newmsg_id.lock"
                echo "要开始下载了"

                wget "https://api.telegram.org/file/bot$bot_token/$video_url" -O "$dir/$chat_id/$filename"
                echo "下载完了"
                stext="收到你的视频了，我真是谢谢你哦……稍后加好水印我发回给你"
                sendtext
				if [ "$processes" -le "$processlmt" ]; then
					processes=$(cat "$dir/.site.json" | jq -r ".processes")
					processes=$((processes+1))
					sed -i "s/\"processes\":[^,}]*/\"processes\":\"$processes\"/g" "$dir/.site.json"

					# 加"&"表示后台运行,视频压缩运行完毕后在compress函数内processes在减1
					compress &
				else
					processes=$(cat "$dir/.site.json" | jq -r ".processes")
					inline=$((processes-processlmt+1))
					echo "压缩视频超过线程数了,$inline排队中……"
					stext="压缩任务太重了啦，目前有$inline个任务正在排队中……待会儿重新给我发吧"
					sendtext
				fi
            fi
        fi
    fi
}

# 程序运行的真正开始处

ifnew=0
while true
do
    updt=$(curl -s https://api.telegram.org/bot$bot_token/getupdates)
	
	# 判断api是否连通
	isok=$(echo "$updt" | jq -r ".ok")
	if [[ $isok =~ true ]]; then

		# getupdates 信息满了之后，保留10个最近的信息，其他全部丢弃
		lastid=$(echo "$updt" | jq -r ".|.result|.[-1]|.update_id")
		firstid=$(echo "$updt" | jq -r ".|.result|.[0]|.update_id")
		totalmsg=$((lastid - firstid))
		offset=$((lastid - 10))
		if [ "$totalmsg" -ge 99 ]; then
			curl -s https://api.telegram.org/bot$bot_token/getupdates?offset=$offset
			stext="已清空轮询获取的聊天信息"
			sendlog

			# 向机器人管理员发送通知
			stext="聊天信息即将突破上限，现已清空！"
			sendadmin
			curl "https://api.telegram.org/bot$bot_token/sendMessage?chat_id=$chat_id&text=$stext"
		fi

		# 机器人使用统计在这开始吧
		botinfo

		# 轮询获取最后一个信息的 message_id
		newmsg_id=$(echo "$updt" | jq -r ".|.result|.[-1]|.message|.message_id")

		# ifnew 的值小于 newmsg_id 说明有新信息进入，然后新信息处理完毕后将 new_msg 的值赋予ifnew
		if [ "$ifnew" -lt "$newmsg_id" ] && [ $ifnew -ne 0 ]; then

			# 通过 chat_id 区分正在交互的用户，并获取用户信息
			chat_id=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.chat|.id") 
			first_name=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.chat|.first_name")
			
			# 获取发送的内容
			text=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.text")
			if [ ! -n "$text" ]; then
				echo "无F**K可说"
			elif [[ $text =~ "null" ]] && [ ! -f "$dir/$chat_id/set.lock" ]; then
				# 上面第二个 if 判断该用户目录下有无 set.lock ，如有说明其正在设置水印
				getfile
			else
				if [[ "$text" == "/help" ]]; then
					stext="嗨！你来啦？🤩 $first_name 🥳 我是一个小小的水印机器人，你只要给我发视频过来，我就会给你把视频加好水印发回给你。如果想设置自己的专属水印点击 /setpng 哦 🤪"
					sendtext
					stext="$first_name 阅读了帮助文档"
					sendlog
				elif [[ "$text" == "/setpng" ]]; then 
					stext="好吧，那就把你的水印文件发过来吧。水印文件一定要 png 格式哦，发送的时候一定记得取消勾选压缩。png 格式支持透明通道，效果会好很多，最佳分辨率是 500x180px"
					sendtext
					stext="$first_name 开始设置水印文件"
					sendlog

					# 开始设置水印文件也放入了后台，没想到后台运行仅仅是加个"&"号就可以了，另一个getfile函数我也做了进程数管理
					setpng &
				elif [[ "$text" == "/start" ]]; then
					stext="我是一个给视频加水印的机器人%0A到目前为止我已经处理了 $totalvids 个视频呢%0A %0A就请直接把视频发给我吧，我会给你的视频加水印发回给你哦。我目前只支持处理 20M 以内的视频，呵呵哒。最好记得设置一下你的水印哦"
					sendtext

					if [ ! -f "$dir/$chat_id" ];then
						# 用户算是正式加入，计入 site.json 内
						totaluser=$((totaluser+1))
						sed -i "s/\"totaluser\":[^,}]*/\"totaluser\":\"$totaluser\"/g" "$dir/.site.json"
					fi

					stext="$first_name 点了/start命令"
					sendlog
				elif [[ "$text" == "/setposition" ]]; then 
					stext="该功能还没上线呐，现在默认水印位置是左上角呢"
					sendtext
					stext="$first_name 想要设置水印位置"
					sendlog
				elif [[ "$text" == "/myinfo" ]]; then
					configfile="$dir/$chat_id/config/.config.json"
					count=$(cat "$configfile" | jq -r ".count")
					jointime=$(cat "$configfile" | jq -r ".jointime")
					stext="总共加水印：$count 次%0Achat_id：$chat_id%0A加入时间：$jointime"
					sendtext
					stext="$first_name 查看了自己的信息"
					sendlog
				elif [[ "$text" == "/information" ]]; then
					stext="总用户数为：$totaluser%0A设水印次数：$usrwithwm%0A此次轮询数：$totalmsg%0A总处理视频：$totalvids%0A总消息数为：$newmsg_id%0A最后注册者：$lastjoin%0A正在转码数：$processes%0A轮询故障数：$apicrush"
					sendtext
					stext="$first_name 查看了机器人的数据"
					sendlog

					# 管理员偷窥用户动态
					stext="$first_name 偷偷查看了机器人的数据哦"
					sendadmin
				else
					echo "$first_name 说：$text"
					echo "[$(date "+%Y-%m-%d %H:%M:%S")] [用户] $first_name 说：$text" >> $dir/wmbot.log
				fi
			fi
		fi
		sleep 1s
		ifnew="$newmsg_id"
	else
		stext="Telegram bot api 发生故障，请检查"
		sendlog
		echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] Telegram bot api 发生故障，请检查"
		apicrush=$((apicrush+1))
		sed -i "s/\"apicrush\":[^,}]*/\"apicrush\":\"$apicrush\"/g" "$dir/.site.json"
		sleep 5s
		stext="Telegram bot api 刚才发生了故障！"
		sendadmin
	fi
done

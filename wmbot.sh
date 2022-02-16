#!/bin/bash
bot_token="<bot_token>"
admin_id="<your_chat_id>"
dir="/your/path/to/dir"

# 向用户发送消息
function sendtext(){
    curl "https://api.telegram.org/bot$bot_token/sendMessage?chat_id=$chat_id&text=$stext"
}

# 向系统管理员发送消息
function sendadmin(){
    curl "https://api.telegram.org/bot$bot_token/sendMessage?chat_id=$admin_id&text=$stext"
}

# 设置水印文件
function setpng(){

    # 搞个60秒循环等待用户发送图片进来
    i=0
    nmsg=$newmsg_id
    while [ $i -le 60 ]
    do 
        updt=$(curl -s https://api.telegram.org/bot$bot_token/getupdates)
        newmsg_id=$(echo "$updt" | jq -r ".|.result|.[-1]|.message|.message_id")

        # 这里做个判断如果新消息来了newmsg_id变得大于nmsg的时候进行下面判断
        if [ "$newmsg_id" -gt "$nmsg" ]; then
            mime=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|.document|.mime_type")
            if [[ $mime =~ image/png ]]; then
                doc_id=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|.document|.file_id")
                docinfo=$(curl -s https://api.telegram.org/bot$bot_token/getFile?file_id=$doc_id)
                doc_url=$(echo $docinfo | jq -r ".|.result|.file_path")
                wget "https://api.telegram.org/file/bot$bot_token/$doc_url" -O "$dir/$chat_id/config/watermark.png"

                stext="水印文件已经给你设置好了"
                sendtext
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 设置了水印文件" >> $dir/wmbot.log

                # 管理员偷窥用户动态
                stext="$first_name 设置了个水印哦😬"
                sendadmin
                break
            else
                stext="你发的好像不是 png 文件啊，发送的时候一定要记得取消勾选压缩哦"
                sendtext
                break
            fi
        fi
    sleep 1s
    i=$((i + 1))
    done 

    # 当用户超时的时候嘲讽他
    if [ $i -gt 60 ]; then 
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 设置水印时超时,并被机器人无情的嘲讽了" >> $dir/wmbot.log
        stext="你是猪啊，发个破图片半天发不过来"
        sendtext

        # 管理员偷窥用户动态
        stext="$first_name 刚刚被机器人骂了，哈哈哈😂😂"
        sendadmin
    fi
}

# 加水印压缩
function compress(){
    if [ ! -d "$dir/$chat_id/watermarked" ]; then
        mkdir -p -- "$dir/$chat_id/watermarked/"
		sleep 1s
	fi

    # 判定用户配置目录是否存在
	if [ ! -d "$dir/$chat_id/config" ]; then
		mkdir -p -- "$dir/$chat_id/config"
		sleep 1s
	fi

    # 判定用户配置文件是否存在，没有就给写个默认的文件
	if [ ! -f "$dir/$chat_id/config/.config.json" ]; then
		cat>"$dir/$chat_id/config/.config.json"<<-END
		{
		  "position": "lt",
		  "count": "0"
		}
		END
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 创建了自己的配置文件" >> $dir/wmbot.log

        # 管理员偷窥用户动态
        stext="$first_name 刚刚创建了自己的配置文件哦🤪"
        sendadmin
		sleep 1s
	fi
	
	# 读取用户配置文件
	configfile=$(cat "$dir/$chat_id/config/.config.json")
	# position=$(echo "$configfile" | jq -r ".position") 暂时还没用
	count=$(echo "$configfile" | jq -r ".count")

    # 判定用户是否设置了水印
    wmark="$dir/$chat_id/config/watermark.png"
    if [ ! -f "$wmark" ]; then
        stext="你没设置水印文件啊，我只能给你打默认水印啦。回头设置一个水印文件吧。亲亲"
        sendtext
        wmark="$dir/watermark.png"

        #在判定一下主目录内有没有默认水印文件
        if [ ! -f "$wmark" ]; then
            touch "$wmark"
        fi
    fi

	# 压缩主命令
    ffmpeg -i "$dir/$chat_id/$filename" \
    -i $wmark \
    -filter_complex "[1][0]scale2ref=w='iw*30/100':h='ow/mdar'[vid][wm]; \
    [wm][vid]overlay=W/11:H/12:format=auto,format=yuv420p" \
    -c:a copy \
    "$dir/$chat_id/watermarked/$filename"
    echo "转换完毕，现在要发回去了"

    # 获取视频的各种参数
    media="$dir/$chat_id/watermarked/$filename"
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$media")
	height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$media")

    # 生成缩略图，上传完毕后需要删除掉这个缩略图文件
	video_thumb="$media.png"

	# 缩略图竖向和横向视频最长边设置为 400 像素
	if [ "$height" != null ]; then
		if [ "$height" -ge "$width" ]; then
			ffmpeg -i "$media" -ss 00:00:02.000 -vframes 1 -filter:v scale="-1:400" "$video_thumb" -y > /dev/null 2>&1
		elif [ "$width" -gt "$height" ]; then
			ffmpeg -i "$media" -ss 00:00:02.000 -vframes 1 -filter:v scale="400:-1" "$video_thumb" -y > /dev/null 2>&1
		fi
	fi

    stext="终于转换完了，我亲爱的大爷！累死个我了🥵 视频马上发给你，请稍等哦……"
    sendtext

	# 发送视频主命令
	curl -F thumb=@"$video_thumb" \
    -F video=@"$media" \
    -F width="$width" \
    -F height="$height" \
    https://api.telegram.org/bot$bot_token/sendVideo?chat_id=$chat_id > /dev/null 2>&1

    # 删除掉那个水印文件
    rm -rf -- "$video_thumb"
    sleep 5s
	count=$((count + 1))

	# 将count写入用户配置文件
	sed -i "s/\"count\":[^,}]*/\"count\":\"$count\"/g" "$dir/$chat_id/config/.config.json"

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
	echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 压缩了一个文件(第 $count 次)：$filename" >> $dir/wmbot.log
}

function getfile(){
    file_id=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|select(.video != null)|.video|.file_id")
    filename=$(echo $updt | jq -r ".|.result|.[]|.message|select(.message_id == $newmsg_id)|select(.video != null)|.video|.file_name")
    vinfo=$(curl -s https://api.telegram.org/bot$bot_token/getFile?file_id=$file_id)
    video_url=$(echo $vinfo | jq -r ".|.result|.file_path")

    if [ ! -d "$dir/$chat_id" ]; then
        mkdir -p -- "$dir/$chat_id"
    elif [[ $filename =~ null ]]; then

        # video_2022-02-15_22-08-42.mp4 假如获取不到文件名
        filename="video_$(date "+%Y-%m-%d_%H-%M-%S").mp4"
    fi
    if [ ! -n "$file_id" ]; then
        stext="你倒是给我发个视频呀，大爷！"
        sendtext
		echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统]$first_name 发了个非视频消息" >> $dir/wmbot.log
    else
        # 再加个 video_url 判定，因为 Telegram api 的限制如果文件超过20M 这个值是 null 会导致出错
        if [[ "$video_url" =~ null ]] || [ ! -n "$video_url" ];then 
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 发来的的文件体积超限了" >> $dir/wmbot.log
            stext="哎呀妈呀，你这个视频好特么大啊，超过20M的文件不是我不想帮你加水印，Telegram 拦着不给我呀"
            sendtext
        else
            if [ ! -f "$dir/$chat_id/$filename" ]; then
                echo "要开始下载了"
                wget "https://api.telegram.org/file/bot$bot_token/$video_url" -O "$dir/$chat_id/$filename"
                echo "下载完了"
                stext="收到你的视频了，我真是谢谢你哦……稍后加好水印我发回给你"
                sendtext
                compress
            fi
        fi
    fi
}

# 程序运行的真正开始处
ifnew=0
while true
do
    updt=$(curl -s https://api.telegram.org/bot$bot_token/getupdates)

    # getupdates 信息满了之后，保留10个最近的信息，其他全部丢弃
    lastid=$(echo "$updt" | jq -r ".|.result|.[-1]|.update_id")
    firstid=$(echo "$updt" | jq -r ".|.result|.[0]|.update_id")
    totalmsg=$((lastid - firstid))
    offset=$((lastid - 10))
    if [ "$totalmsg" -gt 99 ]; then
        curl -s https://api.telegram.org/bot$bot_token/getupdates?offset=$offset
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] 已清空获取的聊天信息" >> $dir/wmbot.log

        # 向机器人管理员发送通知
        stext="聊天信息即将突破上线，现已清空！"
        sendadmin
        curl "https://api.telegram.org/bot$bot_token/sendMessage?chat_id=$chat_id&text=$stext"
    fi

    # 通过 message_id 最后一个值获取最新消息
    newmsg_id=$(echo "$updt" | jq -r ".|.result|.[-1]|.message|.message_id")

    # ifnew 的值小于 new_msg 说明有新信息进入，然后新信息处理完毕后将 new_msg 的值赋予ifnew
    if [ "$ifnew" -lt "$newmsg_id" ]; then

        # 通过 chat_id 区分正在交互的用户
        chat_id=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.chat|.id") 
        first_name=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.chat|.first_name")
        
        # 获取发送的内容
        text=$(echo "$updt" | jq -r ".|.result|.[]|.message|select(.message_id == "$newmsg_id")|.text")
        if [ ! -n "$text" ]; then
            echo "无F**K可说"
        elif [[ $text =~ "null" ]]; then
            getfile
        else
			if [[ "$text" == "/help" ]]; then
				stext="嗨！你来啦？🤩 $first_name 🥳 我是一个小小的水印机器人，你只要给我发视频过来，我就会给你把视频加好水印发回给你。如果想设置自己的专属水印点击 /setpng 哦 🤪"
				sendtext
				echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 阅读了帮助文档" >> $dir/wmbot.log
			elif [[ "$text" == "/setpng" ]]; then 
				stext="好吧，那就把你的水印文件发过来吧。水印文件一定要 png 格式哦，发送的时候一定记得取消勾选压缩哦。png 格式支持透明通道，效果会好很多哦"
				sendtext
				echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 开始设置水印文件" >> $dir/wmbot.log
                setpng
			elif [[ "$text" == "/start" ]]; then
				stext="我是一个给视频加水印的机器人，请直接把视频发给我吧，我会给你的视频加水印发回给你哦。我目前只支持处理 20M 以内的视频，呵呵哒。最好记得设置一下你的水印哦"
				sendtext
				echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统]  $first_name 点了start命令" >> $dir/wmbot.log
			elif [[ "$text" == "/setposition" ]]; then 
				stext="该功能还没上线呐，现在默认水印位置是左上角呢"
				sendtext
				echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 想要设置水印位置" >> $dir/wmbot.log
            elif [[ "$text" == "/totalmsg" ]]; then 
				stext="目前获取的聊天信息总数为：$totalmsg 条"
				sendtext
				echo "[$(date "+%Y-%m-%d %H:%M:%S")] [系统] $first_name 查看了目前的聊天信息总数" >> $dir/wmbot.log
			else
				echo "$first_name 说：$text"
				echo "[$(date "+%Y-%m-%d %H:%M:%S")] $first_name 说：$text" >> $dir/wmbot.log
			fi
        fi
    fi
    sleep 1s
    ifnew=$newmsg_id
done

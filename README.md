## 这是个啥？有啥功能？
- Telegram 水印机器人，给视频打水印的
- 不同用户可以设置自己的水印文件
- 单文件 Shell 脚本
- 开频道偷视频一绝

## 怎么使用？
- 依赖：需要有 jq ，没有安装一个 `apt isntall jq`
- 依赖：需要有 ffmpeg ，没有安装一个 `apt install ffmpeg`
- @botfather 处申请一个 bot
- 将 bot token 填到文件内 `<bot_token>` 处
- 把机器人运行的主目录设置到文件内 `/your/path/to/dir` 处
- 主目录内准备个 watermark.png 的水印文件（用户不设置水印就会用这个）
- `sh ./wmbot.sh`
- @botfather 处增加如下命令
`/start` `/myinfo` `/setpng` `help`

## 这机器人好用不
- Telegram bot api 只支持 20M 以内文件的传输
- （已修复）~~Telegram bot api 轮询机制没整明白，机器人运行一段时间会没反应~~
- 待填坑：水印位置的选项还没写（-filter_comlex太复杂了，不想研究了）
- （决定放弃）：~~每次处理的是最后一个消息，会忽略当前消息到最新消息之间的消息~~
- 以上除了 20M 限制以外的毛病，等我整明白了第一时间修复
- 除此外，非常好用，加个水印还是挺快的

## 新更新
- 增加了 admin 用户权限，运行中必要动态将发送给 admin 的账号上。设置请在文件头部 `admin_id=` 处填写自己的 chat_id
- 丰富了一些 log 记录的细节
- 丰富了一些互动相关内容
- ~~给机器人发送 `/totalmsg` 可以查看目前轮询消息总数~~
- 新增了机器人使用情况统计信息，给机器人发 `/information` 可接收信息
- 规整了修复了很多处
- 增加了进程管理（没想到挺简单的，本来要放弃了）
- 用户配置文件增加了加入日期
- 机器人使用情况增加了最后加入用户
- 给用户查询自己信息的命令

## 预览
- https://t.me/lightrekt_wmbot

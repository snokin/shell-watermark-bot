# shell-watermark-bot
## 这是个啥？有啥功能？
- Telegram 水印机器人，给视频打水印的
- 不同用户可以设置自己的水印文件
- 单文件 Shell 脚本

## 怎么使用？
- 需要有 jq ，没有安装一个 `apt isntall jq`
- @botfather 处申请一个 bot
- 将 bot token 填到文件内 `<bot_token>` 处
- 把机器人运行的主目录设置到 `/your/path/to/dir` 处
- `sh ./wmbot.sh`

## 这机器人好用不
- Telegram bot api 只支持 20M 以内文件的传输
- Telegram bot api 的 getupdates 还没整明白，所以机器人运行一段时间没反应了得手动 getupdates 一下
- 水印位置的选项还没来得及写
- 以上除了 20M 限制以外的毛病，等我整明白了第一时间修复

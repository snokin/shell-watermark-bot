## 这是个啥？有啥功能？
- Telegram 水印机器人，给视频打水印的
- 不同用户可以设置自己的水印文件
- 单文件 Shell 脚本

## 怎么使用？
- 需要有 jq ，没有安装一个 `apt isntall jq`
- @botfather 处申请一个 bot
- 将 bot token 填到文件内 `<bot_token>` 处
- 把机器人运行的主目录设置到文件内 `/your/path/to/dir` 处
- `sh ./wmbot.sh`

## 这机器人好用不
- Telegram bot api 只支持 20M 以内文件的传输
- （已修复）Telegram bot api 的轮询机制还没整明白，所以机器人运行一段时间没反应了得手动 getupdates 一下
- 水印位置的选项还没来得及写
- 单线程，多个用户使用时只能排队一个一个来
- 以上除了 20M 限制以外的毛病，等我整明白了第一时间修复
- 除此外，非常好用，加个水印还是挺快的

## 新更新
- 增加了 admin 权限，必要动态将发送给 admin 的账号上。设置请在文件头部 `admin_id=` 处填写自己的 chat_id
- 丰富了一些 log 记录的细节
- 丰富了一些互动相关内容

## 预览
- https://t.me/lightrekt_wmbot

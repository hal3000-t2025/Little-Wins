# 功劳簿

一个面向个人使用的 macOS GTD / 功劳簿应用。

## 功能

- Inbox 快速记录当天事项
- 四象限权重分配
- 日历视图查看每日事项
- 完成事项进入功劳簿
- 统计今日、本周、本月、本年完成数量
- DeepSeek 可选 AI 分类，未配置 key 时保持本地功能
- 单向导入今日紧急重要任务到系统日历
- 本地 JSON 存储和每日备份

## 数据

任务数据保存在本机：

```text
~/Library/Application Support/GongLaoBu/tasks.json
```

备份保存在：

```text
~/Library/Application Support/GongLaoBu/Backups/
```

## 开发运行

```bash
./script/build_and_run.sh --verify
```

## 打包 release

```bash
./script/package_release.sh
```

产物会输出到：

```text
dist/release/
```

当前没有 Developer ID 证书时，release 会使用 ad-hoc 签名。要让陌生用户下载后无拦截打开，需要 Developer ID 签名和 Apple notarization。

## 作者

hal3000

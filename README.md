# macOS CRT Screen Filter

全局屏幕 CRT 效果滤镜，使用 Metal 着色器实现，Racket 作为控制接口。

## 依赖

- macOS 12.3+
- Xcode Command Line Tools
- Racket 8.0+

## 构建

```bash
make -C native
cp native/libcrt-native.dylib .
```

## 使用

```bash
# 启动 CRT 效果（5秒）
racket -e '(require "racket/crt-api.rkt") (start) (sleep 5) (stop)'

# 切换开关
racket -e '(require "racket/crt-api.rkt") (toggle)'
```

## API

| 函数 | 说明 |
|------|------|
| `(start)` | 启动 CRT 效果 |
| `(stop)` | 停止 CRT 效果 |
| `(toggle)` | 切换开关 |
| `(status)` | 查看状态 |

## 效果参数

默认使用 `generated/crt-subtle.metal`：
- 240 线扫描线
- 轻微暗角
- 暖色调

## 权限

首次运行需授予「屏幕录制」权限：
系统设置 → 隐私与安全性 → 屏幕录制 → 添加 Racket

## 许可

MIT

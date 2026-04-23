# simple-cpu-profiling

基于 Linux `perf` 的 7x24 小时 CPU 性能剖析系统。以固定时间切片（默认 10 秒）采集调用链采样数据，并可为任意时间切片生成可视化火焰图。设计为以 systemd 服务方式长期运行。

## 简介

一个轻量级、持续运行的 CPU 性能剖析工具，特性包括：

- 以 99 Hz 频率采集系统级 CPU 采样，包含完整调用栈（`perf record -a -g`）
- 数据按固定时间切片存储（默认 10 秒一片，每片约 1.4 MB）
- 自动清理 24 小时前的数据
- 为任意已记录的时间切片生成火焰图 SVG
- 以 systemd 服务方式运行，支持崩溃自动重启

## 环境要求

- Linux 系统，已安装 `perf`（`linux-tools-generic` / `kernel-tools`）
- [FlameGraph 工具集](https://github.com/brendangregg/FlameGraph) 安装到 `/opt/FlameGraph`
- `bash 4+`
- root 权限，或 `perf_event_paranoid` 内核参数设置小于 2

## 快速开始

### 1. 安装依赖

```bash
# 安装 perf
sudo apt install linux-tools-generic  # Debian/Ubuntu
# 或
sudo yum install kernel-tools         # RHEL/CentOS

# 安装 FlameGraph 工具集
git clone https://github.com/brendangregg/FlameGraph.git /opt/FlameGraph
```

### 2. 配置参数

编辑 `config/profiler.conf` 调整参数：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `SAMPLE_FREQ` | `99` | 采样频率（Hz） |
| `SLICE_INTERVAL` | `10` | 每个采样切片持续时间（秒） |
| `OUTPUT_DIR` | `log/profiler` | perf 数据和火焰图的存储目录 |
| `RETENTION_MINUTES` | `1440` | 数据保留时间，超过此值自动删除（分钟） |
| `CLEANUP_INTERVAL` | `600` | 清理检查间隔（每 N 个切片执行一次） |
| `PID_FILE` | `run/profiler.pid` | 守护进程 PID 文件 |
| `LOG_FILE` | `log/profiler/profiler.log` | 守护进程日志文件 |

### 3. 启动守护进程

```bash
# 通过 systemd 启动（推荐）
sudo cp config/profiler.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start profiler
sudo systemctl enable profiler

# 或直接运行
./scripts/profiler_daemon.sh start
./scripts/profiler_daemon.sh stop
./scripts/profiler_daemon.sh status
```

### 4. 生成火焰图

```bash
# 为最新的已完成切片生成
./scripts/generate_flamegraph.sh

# 为指定时刻生成（HH:MM 或 HH:MM:SS，匹配当天数据）
./scripts/generate_flamegraph.sh 14:30
./scripts/generate_flamegraph.sh 14:30:25
```

生成的 SVG 文件保存为 `flamegraph_HH-MM.svg` 或 `flamegraph_HH-MM-SS.svg`，存放在 `log/profiler/` 目录中。

## 文件结构

```
simple-cpu-profiling/
├── config/
│   ├── profiler.conf          # 共享配置文件
│   └── profiler.service       # systemd 单元文件
├── scripts/
│   ├── profiler_daemon.sh     # 剖析守护进程（start/stop/status）
│   └── generate_flamegraph.sh # 火焰图生成器
├── log/
│   └── profiler/
│       ├── perf_*.data        # perf 原始数据切片
│       ├── flamegraph_*.svg   # 生成的火焰图
│       └── profiler.log       # 守护进程运行日志
├── run/
│   └── profiler.pid           # 守护进程 PID 文件
└── README.md
```

## 架构设计

```
profiler_daemon.sh (systemd service)
  │
  ├── 每 10 秒循环执行:
  │     perf record -a -g -F 99 -o perf_YYYYMMDD_HHMMSS.data -- sleep 10
  │
  └── 每 100 秒执行清理:
        find log/profiler -name "perf_*.data" -mmin +1440 -delete

generate_flamegraph.sh [HH:MM | HH:MM:SS]
  │
  ├── 无参数 → 选取最新已完成的 .data 切片文件
  ├── 带参数 → 查找距离目标时间最近的 .data 切片文件
  │
  └── 处理流水线:
        perf script -i <data>
      │ stackcollapse-perf.pl
      │ flamegraph.pl
      > flamegraph_HH-MM[-SS].svg
```

### 设计说明

- **固定切片 vs 单文件**：每次采样均为独立的 `perf record` 进程，便于按时间窗口隔离和分析，避免管理庞大的单一数据文件。
- **99 Hz 采样频率**：选用质数频率，避免与常见周期任务（如 100 Hz 定时器中断）产生共振混叠。
- **`--no-buildid`**：跳过 build-id 采集以降低每片开销，关注点在于相对热点路径的定位，而非跨二进制版本的符号解析。
- **24 小时数据保留**：每个 perf 数据文件约 1.4 MB，每分钟约 6 片，全天约 120 GB。24 小时自动清理控制磁盘占用。
- **systemd 集成**：守护进程在前台运行（阻塞于 `perf record`），systemd 可直接追踪主进程 PID。`Restart=always` 确保崩溃或重启后的自愈能力。

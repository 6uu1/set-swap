# VPS Swap 自动配置脚本

一个用于在Linux VPS上自动创建和配置swap文件的Bash脚本。支持自定义swap大小、swappiness参数和完全自动化配置。

## 功能特性

- ✅ **交互式菜单** - 友好的图形化菜单界面
- ✅ **智能默认配置** - 自动计算推荐swap大小（内存的1倍）
- ✅ 自动检测现有swap配置
- ✅ 支持自定义swap大小（GB/MB/KB）
- ✅ 智能选择快速创建方法（fallocate或dd）
- ✅ 自动配置开机挂载（/etc/fstab）
- ✅ 优化swap性能参数（swappiness和cache pressure）
- ✅ 磁盘空间检查，防止空间不足
- ✅ 彩色日志输出，易于查看
- ✅ 支持删除现有swap配置
- ✅ Root权限检查和安全设置

## 系统要求

- Linux系统（支持Ubuntu、Debian、CentOS等主流发行版）
- Root权限
- Bash 4.0+

## 快速开始

### 1. 下载脚本

```bash
# 直接覆盖保存（推荐）
wget -O setup-swap.sh https://raw.githubusercontent.com/6uu1/set-swap/main/setup-swap.sh

# 或使用curl
curl -o setup-swap.sh https://raw.githubusercontent.com/6uu1/set-swap/main/setup-swap.sh

# 如果只是想“有新版本才更新”
wget -N https://raw.githubusercontent.com/6uu1/set-swap/main/setup-swap.sh
```

### 2. 添加执行权限

```bash
chmod +x setup-swap.sh
```

### 3. 运行脚本

```bash
# 交互式菜单模式（推荐新手使用）
sudo ./setup-swap.sh -i

# 使用默认配置（swap为内存的1倍）
sudo ./setup-swap.sh

# 或者指定swap大小
sudo ./setup-swap.sh -s 4G
```

## 使用说明

### 基本用法

```bash
sudo ./setup-swap.sh [选项]
```

### 选项说明
i` | `--interactive` | 启用交互式菜单模式 | - |
| `-s` | `--size SIZE` | Swap文件大小（如2G, 4G, 512M） | 自动（内存的1倍）
| 选项 | 长选项 | 说明 | 默认值 |
|------|--------|------|--------|
| `-s` | `--size SIZE` | Swap文件大小（如2G, 4G, 512M） | 2G |
| `-w` | `--swappiness VALUE` | Swappiness值（0-100） | 10 |
| `-c` | `--cache VALUE` | Cache pressure值（0-100） | 50 |
| `-f` | `--file PATH` | Swap文件路径 | /swapfile |
| `-r` | `--remove` | 删除现有swap | - |
| `-h` | 交互式菜单模式（推荐）
```bash
sudo ./setup-swap.sh -i
```
进入友好的图形化菜单，提供：
- 使用推荐配置（一键配置）
- 自定义swap大小
- 完全自定义配置
- 删除swap
- 查看当前状态

#### 示例2：使用默认配置（swap为内存的1倍）
```bash
sudo ./setup-swap.sh
```

#### 示例3：创建4G swap
```bash
sudo ./setup-swap.sh -s 4G
```

#### 示例4：创建2G swap并设置swappiness为20
```bash
sudo ./setup-swap.sh -s 2G -w 20
```

#### 示例5：创建512MB swap（小内存VPS）
```bash
sudo ./setup-swap.sh -s 512M
```

#### 示例6：删除现有swap
```bash
sudo ./setup-swap.sh -r
```

#### 示例7
sudo ./setup-swap.sh -r
```

#### 示例6：完全自定义配置
```bash
sudo ./setup-swap.sh -s 8G -w 30 -c 60 -f /swap/myswapfile
```

## 参数说明

### Swappiness

Swappiness控制系统使用swap的倾向性（范围：0-100）：

- **0-10**: 尽可能使用物理内存，适合服务器环境（推荐）
- **10-30**: 较少使用swap，适合一般服务器
- **60**: 系统默认值，适合桌面环境
- **80-100**: 积极使用swap，不推荐

**推荐设置**：
- 数据库服务器：5-10
**自动计算（默认）**：
- 脚本会自动读取系统内存大小
- 默认创建 **内存的1倍** 作为swap大小
- 例如：2GB内存 → 2GB swap，4GB内存 → 4GB swap

**手动指定参考**：

| 物理内存 | 推荐Swap大小 | 命令示例 |
|---------|-------------|----------|
| 512MB   | 1-2GB       | `sudo ./setup-swap.sh -s 2G` |
| 1GB     | 1-2GB       | `sudo ./setup-swap.sh -s 1G` |
| 2GB     | 2GB         | `sudo ./setup-swap.sh` (使用默认) |
| 4GB     | 2-4GB       | `sudo ./setup-swap.sh` (使用默认) |
| 8GB+    | 2-4GB       | `sudo ./setup-swap.sh -s 4
- **<50**: 更倾向于保留目录和inode缓存
- **>50**: 更倾向于回收缓存

**推荐设置**：50（默认值通常是最佳选择）

### Swap大小推荐

根据VPS内存大小选择swap：

| 物理内存 | 推荐Swap大小 | 命令示例 |
|---------|-------------|----------|
| < 2GB   | 2-4GB       | `sudo ./setup-swap.sh -s 4G` |
| 2-4GB   | 2GB         | `sudo ./setup-swap.sh -s 2G` |
| 4-8GB   | 2-4GB       | `sudo ./setup-swap.sh -s 2G` |
| > 8GB   | 2GB或按需   | `sudo ./setup-swap.sh -s 2G` |

## 检查Swap状态

### 查看swap使用情况
```bash
free -h
```

### 查看swap详细信息
```bash
swapon --show
```

### 查看swap参数
```bash
sysctl vm.swappiness
sysctl vm.vfs_cache_pressure
```

### 实时监控内存和swap
```bash
watch -n 1 free -h
```

## 手动管理Swap

### 临时关闭swap
```bash
sudo swapoff -a
```

### 临时启用swap
```bash
sudo swapon -a
```

### 修改swappiness（临时）
```bash
sudo sysctl vm.swappiness=10
```

### 修改swappiness（永久）
编辑 `/etc/sysctl.conf`，添加或修改：
```
vm.swappiness=10
```

## 故障排查

### 问题1：权限被拒绝
**错误信息**: `Permission denied`

**解决方法**: 使用sudo运行脚本
```bash
sudo ./setup-swap.sh
```

### 问题2：磁盘空间不足
**错误信息**: `磁盘空间不足`

**解决方法**: 
1. 清理不需要的文件
2. 使用更小的swap大小
```bash
sudo ./setup-swap.sh -s 1G
```

### 问题3：Swap创建失败
**可能原因**: fallocate在某些文件系统上不支持

**解决方法**: 脚本会自动回退到dd命令，耐心等待完成

### 问题4：查看错误日志
如果脚本执行失败，可以查看系统日志：
```bash
dmesg | tail -n 50
journalctl -xe
```

## 安全注意事项

1. **文件权限**: 脚本自动设置swap文件权限为600（仅root可读写）
2. **Root权限**: 脚本需要root权限运行，请确保从可信来源下载
3. **备份**: 脚本会自动备份fstab和sysctl.conf（.bak后缀）

## 卸载

删除swap配置：
```bash
sudo ./setup-swap.sh -r
```

这将：
- 关闭所有swap设备
- 删除swa如何使用交互式菜单？
A: 运行 `sudo ./setup-swap.sh -i` 即可进入友好的图形化菜单界面，适合新手使用。

### Q: 默认swap大小是多少？
A: 脚本会自动检测系统内存，默认创建 **内存的1倍** 作为swap。例如2GB内存会创建2GB swap。

### Q: 我应该使用多大的swap？
A: 推荐使用默认配置（内存的1倍）。如果运行内存密集型应用，可以考虑1.5-2倍内存。

### Q: p文件
- 从/etc/fstab中移除swap条目
- 从/etc/sysctl.conf中移除swap配置

## 技术细节

### 创建方法
- 优先使用 `fallocate`（速度更快）
- 不可用时回退到 `dd`（兼容性更好）

### 文件系统支持
- ext4, ext3, xfs: 完全支持
- btrfs: 需要使用dd命令
- zfs: 不推荐使用文件作为swap

### 持久化
- `/etc/fstab`: 开机自动挂载swap
- `/etc/sysctl.conf`: 保存swap参数配置

## 常见问题 (FAQ)

### Q: swap是否会影响SSD寿命？
A: 合理使用swap（swappiness=10）对SSD寿命影响很小。现代SSD的写入寿命足够应对正常使用。
1.0 (2026-01-21)
- ✨ 新增交互式菜单模式（`-i`参数）
- ✨ 智能默认配置：自动计算swap大小为内存的1倍
- ✨ 添加预设选项：快速选择常见配置
- 🎨 改进用户体验和提示信息
- 📝 更新文档说明

### v1.
### Q: 我的VPS已经有swap了，可以运行此脚本吗？
A: 可以。脚本会检测现有swap并提示，会先关闭旧swap再创建新的。

### Q: 为什么推荐swappiness=10？
A: 服务器通常需要快速响应，低swappiness值可以确保尽可能使用物理内存，减少swap带来的性能损失。

### Q: 可以创建多个swap文件吗？
A: 可以使用 `-f` 参数指定不同路径多次运行脚本，但通常一个swap文件就足够了。

### Q: swap会自动清理吗？
A: 系统会根据需要管理swap，但如果要手动清理：`sudo swapoff -a && sudo swapon -a`

## 性能建议

1. **监控swap使用**: 如果swap使用率持续很高，考虑增加物理内存
2. **数据库服务器**: 使用最低的swappiness值（5-10）
3. **避免swap抖动**: 确保swap大小合理，避免频繁换入换出
4. **SSD优先**: 如果可能，将swap文件放在SSD上

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！

## 更新日志

### v1.0.0 (2026-01-21)
- 初始版本发布
- 支持自动创建和配置swap
- 支持自定义参数
- 添加完整的错误处理和日志
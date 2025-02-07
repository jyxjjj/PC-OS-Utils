# zshrc_Apple_Terminal Remover

每次开机都删除 `/etc/zshrc_Apple_Terminal` 防止系统更新恢复此文件

1. 我们每次都遇到 `.zsh_sessions` 文件夹的出现
2. 根据 `StackOverflow` 和 `SuperUser` 的说法，我们需要将变量添加到 `.zprofile`
3. `Apple官方注释`中，让我们把变量放进 `.zshenv`
4. 这三个情况都会导致 `$HOME` 目录 `~` 中多出一个项目，占用 `Finder` 列表的屏幕视觉空间
5. 强迫症专用，慎用！！！
6. 请执行 `run.sh` 。
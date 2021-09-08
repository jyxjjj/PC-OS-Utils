@echo off
echo 此程序可以执行资源管理器导航栏中的系统文件夹的隐藏和删除操作
echo 您可以按提示选择某个步骤是否继续或取消操作
echo 请按任意键开始
pause >nul
cls

choice /M 是否隐藏资源管理器-此电脑-图片
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-此电脑-图片"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo 隐藏"资源管理器-此电脑-图片"完毕
) ELSE (
    echo 您取消了"隐藏资源管理器-此电脑-图片"的操作
)

echo.
choice /M 是否隐藏资源管理器-此电脑-视频
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-此电脑-视频"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo 隐藏"资源管理器-此电脑-视频"完毕
) ELSE (
    echo 您取消了隐藏"资源管理器-此电脑-视频"的操作
)

echo.
choice /M 是否隐藏资源管理器-此电脑-音乐
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-此电脑-音乐"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo 隐藏"资源管理器-此电脑-音乐"完毕
) ELSE (
    echo 您取消了隐藏"资源管理器-此电脑-音乐"的操作
)

echo.
choice /M 是否隐藏资源管理器-此电脑-下载
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-此电脑-下载"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo 隐藏"资源管理器-此电脑-下载"完毕
) ELSE (
    echo 您取消了隐藏"资源管理器-此电脑-下载"的操作
)

echo.
choice /M 是否隐藏资源管理器-此电脑-桌面
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-此电脑-桌面"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo 隐藏"资源管理器-此电脑-桌面"完毕
) ELSE (
    echo 您取消了隐藏"资源管理器-此电脑-桌面"的操作
)

echo.
choice /M 是否隐藏资源管理器-此电脑-文档
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-此电脑-文档"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo 隐藏"资源管理器-此电脑-文档"完毕
) ELSE (
    echo 您取消了隐藏"资源管理器-此电脑-文档"的操作
)

echo.
choice /M "是否彻底删除资源管理器-此电脑-3D Objects"
IF %ERRORLEVEL% EQU 1 (
    echo 彻底删除"资源管理器-此电脑-3D Objects"中...
    REG DELETE HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A} /f
    REG DELETE HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A} /f
    echo 彻底删除"资源管理器-此电脑-3D Objects"完毕
) ELSE (
    echo 您取消了彻底删除"资源管理器-此电脑-3D Objects"的操作
)

echo.
choice /M 是否隐藏资源管理器-OneDrive
IF %ERRORLEVEL% EQU 1 (
    echo 隐藏"资源管理器-OneDrive"中...
    REG ADD HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4035969101 /f
    REG ADD HKCR\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4035969101 /f
    echo 隐藏"资源管理器-OneDrive"完毕
) ELSE (
    echo 您取消了隐藏"资源管理器-OneDrive"的操作
)

echo.
pause
cls
echo 即将重启资源管理器
pause
taskkill /f /im explorer.exe
start explorer.exe
echo 隐藏和删除操作全部执行完毕
echo 可以继续执行恢复操作
echo 您可以关闭窗口以退出，或按任意键继续
pause >nul
cls

choice /M 是否恢复资源管理器-此电脑-图片
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-此电脑-图片"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo 恢复"资源管理器-此电脑-图片"完毕
) ELSE (
    echo 您取消了"恢复资源管理器-此电脑-图片"的操作
)

echo.
choice /M 是否恢复资源管理器-此电脑-视频
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-此电脑-视频"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo 恢复"资源管理器-此电脑-视频"完毕
) ELSE (
    echo 您取消了恢复"资源管理器-此电脑-视频"的操作
)

echo.
choice /M 是否恢复资源管理器-此电脑-音乐
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-此电脑-音乐"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo 恢复"资源管理器-此电脑-音乐"完毕
) ELSE (
    echo 您取消了恢复"资源管理器-此电脑-音乐"的操作
)

echo.
choice /M 是否恢复资源管理器-此电脑-下载
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-此电脑-下载"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo 恢复"资源管理器-此电脑-下载"完毕
) ELSE (
    echo 您取消了恢复"资源管理器-此电脑-下载"的操作
)

echo.
choice /M 是否恢复资源管理器-此电脑-桌面
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-此电脑-桌面"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo 恢复"资源管理器-此电脑-桌面"完毕
) ELSE (
    echo 您取消了恢复"资源管理器-此电脑-桌面"的操作
)

echo.
choice /M 是否恢复资源管理器-此电脑-文档
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-此电脑-文档"中...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo 恢复"资源管理器-此电脑-文档"完毕
) ELSE (
    echo 您取消了恢复"资源管理器-此电脑-文档"的操作
)

echo.
choice /M 是否恢复资源管理器-OneDrive
IF %ERRORLEVEL% EQU 1 (
    echo 恢复"资源管理器-OneDrive"中...
    REG ADD HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4034920525 /f
    REG ADD HKCR\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4034920525 /f
    echo 恢复"资源管理器-OneDrive"完毕
) ELSE (
    echo 您取消了恢复"资源管理器-OneDrive"的操作
)

echo.
pause
cls
echo 即将重启资源管理器
pause
taskkill /f /im explorer.exe
start explorer.exe
echo 重启完毕，即将退出
pause

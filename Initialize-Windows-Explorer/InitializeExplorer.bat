@echo off
echo �˳������ִ����Դ�������������е�ϵͳ�ļ��е����غ�ɾ������
echo �����԰���ʾѡ��ĳ�������Ƿ������ȡ������
echo �밴�������ʼ
pause >nul
cls

choice /M �Ƿ�������Դ������-�˵���-ͼƬ
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-�˵���-ͼƬ"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo ����"��Դ������-�˵���-ͼƬ"���
) ELSE (
    echo ��ȡ����"������Դ������-�˵���-ͼƬ"�Ĳ���
)

echo.
choice /M �Ƿ�������Դ������-�˵���-��Ƶ
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-�˵���-��Ƶ"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo ����"��Դ������-�˵���-��Ƶ"���
) ELSE (
    echo ��ȡ��������"��Դ������-�˵���-��Ƶ"�Ĳ���
)

echo.
choice /M �Ƿ�������Դ������-�˵���-����
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-�˵���-����"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo ����"��Դ������-�˵���-����"���
) ELSE (
    echo ��ȡ��������"��Դ������-�˵���-����"�Ĳ���
)

echo.
choice /M �Ƿ�������Դ������-�˵���-����
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-�˵���-����"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo ����"��Դ������-�˵���-����"���
) ELSE (
    echo ��ȡ��������"��Դ������-�˵���-����"�Ĳ���
)

echo.
choice /M �Ƿ�������Դ������-�˵���-����
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-�˵���-����"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo ����"��Դ������-�˵���-����"���
) ELSE (
    echo ��ȡ��������"��Դ������-�˵���-����"�Ĳ���
)

echo.
choice /M �Ƿ�������Դ������-�˵���-�ĵ�
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-�˵���-�ĵ�"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Hide /f
    echo ����"��Դ������-�˵���-�ĵ�"���
) ELSE (
    echo ��ȡ��������"��Դ������-�˵���-�ĵ�"�Ĳ���
)

echo.
choice /M "�Ƿ񳹵�ɾ����Դ������-�˵���-3D Objects"
IF %ERRORLEVEL% EQU 1 (
    echo ����ɾ��"��Դ������-�˵���-3D Objects"��...
    REG DELETE HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A} /f
    REG DELETE HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A} /f
    echo ����ɾ��"��Դ������-�˵���-3D Objects"���
) ELSE (
    echo ��ȡ���˳���ɾ��"��Դ������-�˵���-3D Objects"�Ĳ���
)

echo.
choice /M �Ƿ�������Դ������-OneDrive
IF %ERRORLEVEL% EQU 1 (
    echo ����"��Դ������-OneDrive"��...
    REG ADD HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4035969101 /f
    REG ADD HKCR\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4035969101 /f
    echo ����"��Դ������-OneDrive"���
) ELSE (
    echo ��ȡ��������"��Դ������-OneDrive"�Ĳ���
)

echo.
pause
cls
echo ����������Դ������
pause
taskkill /f /im explorer.exe
start explorer.exe
echo ���غ�ɾ������ȫ��ִ�����
echo ���Լ���ִ�лָ�����
echo �����Թرմ������˳��������������
pause >nul
cls

choice /M �Ƿ�ָ���Դ������-�˵���-ͼƬ
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-�˵���-ͼƬ"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo �ָ�"��Դ������-�˵���-ͼƬ"���
) ELSE (
    echo ��ȡ����"�ָ���Դ������-�˵���-ͼƬ"�Ĳ���
)

echo.
choice /M �Ƿ�ָ���Դ������-�˵���-��Ƶ
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-�˵���-��Ƶ"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo �ָ�"��Դ������-�˵���-��Ƶ"���
) ELSE (
    echo ��ȡ���˻ָ�"��Դ������-�˵���-��Ƶ"�Ĳ���
)

echo.
choice /M �Ƿ�ָ���Դ������-�˵���-����
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-�˵���-����"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo �ָ�"��Դ������-�˵���-����"���
) ELSE (
    echo ��ȡ���˻ָ�"��Դ������-�˵���-����"�Ĳ���
)

echo.
choice /M �Ƿ�ָ���Դ������-�˵���-����
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-�˵���-����"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo �ָ�"��Դ������-�˵���-����"���
) ELSE (
    echo ��ȡ���˻ָ�"��Դ������-�˵���-����"�Ĳ���
)

echo.
choice /M �Ƿ�ָ���Դ������-�˵���-����
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-�˵���-����"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo �ָ�"��Դ������-�˵���-����"���
) ELSE (
    echo ��ȡ���˻ָ�"��Դ������-�˵���-����"�Ĳ���
)

echo.
choice /M �Ƿ�ָ���Դ������-�˵���-�ĵ�
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-�˵���-�ĵ�"��...
    REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    REG ADD HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag /v ThisPCPolicy /t REG_SZ /d Show /f
    echo �ָ�"��Դ������-�˵���-�ĵ�"���
) ELSE (
    echo ��ȡ���˻ָ�"��Դ������-�˵���-�ĵ�"�Ĳ���
)

echo.
choice /M �Ƿ�ָ���Դ������-OneDrive
IF %ERRORLEVEL% EQU 1 (
    echo �ָ�"��Դ������-OneDrive"��...
    REG ADD HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4034920525 /f
    REG ADD HKCR\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder /v Attributes /t REG_DWORD /d 4034920525 /f
    echo �ָ�"��Դ������-OneDrive"���
) ELSE (
    echo ��ȡ���˻ָ�"��Դ������-OneDrive"�Ĳ���
)

echo.
pause
cls
echo ����������Դ������
pause
taskkill /f /im explorer.exe
start explorer.exe
echo ������ϣ������˳�
pause

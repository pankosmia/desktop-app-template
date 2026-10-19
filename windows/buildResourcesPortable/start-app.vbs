Option Explicit

Dim shell, fso, root, exePath, appPath

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(WScript.ScriptFullName)
exePath = root & "\%%APP_NAME%%\electron\electron.exe"
appPath = root & "\%%APP_NAME%%\electron"

shell.Run """" & exePath & """ """ & appPath & """", 0, False

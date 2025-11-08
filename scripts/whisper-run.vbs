' This VBScript launches whisper-run silently in the background
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Get the directory where this script is located
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
projectRoot = fso.GetParentFolderName(scriptDir)
whisperExe = projectRoot & "\.venv\Scripts\whisper-run.exe"

' Run whisper-run hidden (0 = hidden window)
WshShell.Run Chr(34) & whisperExe & Chr(34), 0, False

Set WshShell = Nothing
Set fso = Nothing

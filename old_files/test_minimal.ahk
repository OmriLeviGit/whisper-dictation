#Requires AutoHotkey v2.0
#SingleInstance Force

; MINIMAL TEST - Just check if audioDevice variable works

global audioDevice := "Microphone (Razer USB Sound Card)"

MsgBox("Step 1: Variable set`n`naudioDevice = " . audioDevice)

if audioDevice = "" {
    MsgBox("ERROR: audioDevice is empty!", "Error", "Icon!")
    ExitApp()
}

MsgBox("Step 2: Variable is NOT empty`n`naudioDevice = " . audioDevice . "`n`nLength: " . StrLen(audioDevice))

; Test if we can use it in a string
testString := 'ffmpeg -f dshow -i audio="' . audioDevice . '"'
MsgBox("Step 3: Test command built`n`n" . testString)

MsgBox("SUCCESS! The audioDevice variable works fine.`n`nThis means the problem is elsewhere in the script.")

#Requires AutoHotkey v2.0
#SingleInstance Force

; Test microphone detection
MsgBox("Testing microphone detection...`n`nPress OK to start.")

; Method 1: Try to run FFmpeg and capture output
try {
    ; Run FFmpeg command and save to temp file
    tempFile := A_Temp "\ffmpeg_test.txt"

    ; Delete old file if exists
    if FileExist(tempFile) {
        FileDelete(tempFile)
    }

    ; Run FFmpeg and redirect output to file
    RunWait('cmd.exe /c ffmpeg -list_devices true -f dshow -i dummy > "' . tempFile . '" 2>&1', , "Hide")

    ; Read the output
    output := ""
    if FileExist(tempFile) {
        output := FileRead(tempFile)
    } else {
        MsgBox("Temp file was not created!")
        ExitApp()
    }

    ; Extract audio devices
    audioDevice := ""
    Loop Parse, output, "`n", "`r"
    {
        if InStr(A_LoopField, "(audio)") {
            ; Extract device name between quotes
            if RegExMatch(A_LoopField, '"([^"]+)"', &match) {
                audioDevice := match[1]
                break
            }
        }
    }

    ; Show results
    if audioDevice != "" {
        MsgBox("SUCCESS!`n`nDetected microphone:`n" . audioDevice, "Microphone Found", "Icon!")
    } else {
        MsgBox("FAILED!`n`nNo audio device found in output.`n`nFull output saved to:`n" . tempFile, "No Microphone", "Icon!")
    }

} catch as err {
    MsgBox("ERROR!`n`n" . err.Message, "Error", "Icon!")
}

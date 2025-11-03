#Requires AutoHotkey v2.0
#SingleInstance Force

; Test transcription of existing recording
AUDIO_FILE := A_Temp "\whisper_dictation\recording.wav"
API_URL := "http://localhost:58231/transcribe/simple"

MsgBox("Testing transcription...`n`nAudio file: " . AUDIO_FILE . "`n`nPress OK to transcribe.")

; Check if file exists
if !FileExist(AUDIO_FILE) {
    MsgBox("Recording file not found!`n`n" . AUDIO_FILE, "Error", "Icon!")
    ExitApp()
}

; Show file size
fileSize := FileGetSize(AUDIO_FILE)
MsgBox("File found!`nSize: " . Round(fileSize / 1024 / 1024, 2) . " MB`n`nSending to transcription service...")

; Run curl command
curlCmd := 'curl -X POST "' . API_URL . '" -F "audio=@' . AUDIO_FILE . '" -s'

try {
    ; Create temp file for output
    tempFile := A_Temp "\curl_output.txt"

    ; Run command and redirect output to file
    RunWait(A_ComSpec " /C " . curlCmd . ' > "' . tempFile . '" 2>&1', , "Hide")

    ; Read the output
    output := ""
    if FileExist(tempFile) {
        output := FileRead(tempFile)
    }

    if output = "" {
        MsgBox("Empty response from service!", "Error", "Icon!")
        ExitApp()
    }

    ; Show result
    MsgBox("Response received!`n`nLength: " . StrLen(output) . " chars`n`nFirst 500 chars:`n" . SubStr(output, 1, 500), "Result", "Icon?")

} catch as err {
    MsgBox("Error: " . err.Message, "Error", "Icon!")
}

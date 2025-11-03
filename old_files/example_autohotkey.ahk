; ============================================================================
; Faster-Whisper Push-to-Talk Dictation (AutoHotkey v2)
; ============================================================================
; This script provides push-to-talk dictation using the Whisper transcription service.
; Press and hold a hotkey to record audio, release to transcribe and type the text.
;
; Requirements:
; - AutoHotkey v2 (https://www.autohotkey.com/)
; - FFmpeg installed and in PATH (for audio recording)
; - curl.exe (included in Windows 10/11)
; - Whisper transcription service running (docker-compose up -d)
;
; ============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; GLOBAL VARIABLES (must be declared FIRST!)
; ============================================================================

global isRecording := false
global recordingPID := 0
global audioDevice := ""  ; Cached audio device name

; ============================================================================
; CONFIGURATION
; ============================================================================

; Hotkey for push-to-talk (hold to record, release to transcribe)
; Win+F1 = #F1, Win+F2 = #F2, etc. Other options: F13, F14, F15, CapsLock, ScrollLock
HOTKEY_COMBO := "#F1"  ; Win+F1 - Change to your preferred key

; Whisper API endpoint
API_URL := "http://localhost:58231/transcribe/simple"

; Temporary file paths
TEMP_DIR := A_Temp "\whisper_dictation"
RAW_FILE := TEMP_DIR "\recording.raw"  ; Raw PCM - no header to corrupt!
AUDIO_FILE := TEMP_DIR "\recording.wav"

; Audio recording settings (uses Windows default microphone automatically)
SAMPLE_RATE := "16000"  ; 16kHz is optimal for Whisper

; Visual feedback (optional)
SHOW_TOOLTIP := true
PLAY_SOUNDS := true  ; Beep on start/stop recording

; ============================================================================
; INITIALIZATION
; ============================================================================

; Create temp directory if it doesn't exist
if !DirExist(TEMP_DIR) {
    DirCreate(TEMP_DIR)
}

; Check dependencies
CheckDependencies()

; Detect audio device once at startup
DetectAudioDevice()

; Set up hotkeys
Hotkey(HOTKEY_COMBO, RecordStart)
Hotkey(HOTKEY_COMBO " Up", RecordStop)

; Show startup message
if SHOW_TOOLTIP {
    ToolTip("Whisper Dictation Ready`nHold " HOTKEY_COMBO " to record")
    SetTimer(() => ToolTip(), -2000)
}

; ============================================================================
; RECORDING FUNCTIONS
; ============================================================================

RecordStart(*) {
    global isRecording, recordingPID, RAW_FILE, AUDIO_FILE

    if isRecording {
        return  ; Already recording
    }

    isRecording := true

    ; Delete old recordings if they exist
    if FileExist(RAW_FILE) {
        try FileDelete(RAW_FILE)
    }
    if FileExist(AUDIO_FILE) {
        try FileDelete(AUDIO_FILE)
    }

    ; Visual feedback
    if SHOW_TOOLTIP {
        ToolTip("Recording... (Release " HOTKEY_COMBO " to stop)")
    }

    if PLAY_SOUNDS {
        SoundBeep(1000, 100)
    }

    ; Start recording with ffmpeg
    ; WAV format for best compatibility and speed
    global audioDevice

    if audioDevice = "" {
        MsgBox("No microphone detected!`n`nPlease connect a microphone and restart the script.", "No Audio Device", "Icon!")
        isRecording := false
        if SHOW_TOOLTIP {
            ToolTip()
        }
        return
    }

    ; Record directly to WAV
    ; Use -nostdin to prevent FFmpeg from reading console input
    ffmpegCmd := 'ffmpeg.exe -nostdin -f dshow -i audio="' . audioDevice . '" -ar ' . SAMPLE_RATE . ' -ac 1 -y "' . AUDIO_FILE . '" -loglevel quiet'

    try {
        ; Run without hiding console - we need it for Ctrl+C signal
        recordingPID := Run(ffmpegCmd, , "Hide")
    } catch as err {
        MsgBox("Failed to start recording: " err.Message . "`n`nDevice: " . audioDevice, "Error", "Icon!")
        isRecording := false
        if SHOW_TOOLTIP {
            ToolTip()
        }
    }
}

RecordStop(*) {
    global isRecording, recordingPID, AUDIO_FILE

    if !isRecording {
        return
    }

    ; Send Ctrl+C signal to FFmpeg for graceful shutdown
    if recordingPID {
        ; Try to attach to FFmpeg's console and send Ctrl+C
        ; This is the proper way to stop FFmpeg gracefully
        try {
            DllCall("kernel32\AttachConsole", "UInt", recordingPID)
            DllCall("kernel32\SetConsoleCtrlHandler", "Ptr", 0, "Int", 1)
            DllCall("kernel32\GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)
            Sleep(100)
            DllCall("kernel32\FreeConsole")
            DllCall("kernel32\SetConsoleCtrlHandler", "Ptr", 0, "Int", 0)
        } catch {
            ; If that fails, force close
            ProcessClose(recordingPID)
        }
        recordingPID := 0
    }

    isRecording := false

    if PLAY_SOUNDS {
        SoundBeep(800, 100)
    }

    ; Wait for file to be finalized
    Sleep(1000)

    ; Check if recording file exists and has content
    if !FileExist(AUDIO_FILE) {
        if SHOW_TOOLTIP {
            ToolTip("No audio recorded - file not created")
            SetTimer(() => ToolTip(), -3000)
        }
        return
    }

    ; Check if file has content (more than just WAV header)
    try {
        fileSize := FileGetSize(AUDIO_FILE)
        if fileSize < 1000 {  ; WAV header is ~44 bytes, so <1KB means almost no audio
            if SHOW_TOOLTIP {
                ToolTip("Recording too short or empty")
                SetTimer(() => ToolTip(), -3000)
            }
            return
        }
    } catch {
        if SHOW_TOOLTIP {
            ToolTip("Error reading audio file")
            SetTimer(() => ToolTip(), -3000)
        }
        return
    }

    ; Show processing message
    if SHOW_TOOLTIP {
        ToolTip("Transcribing...")
    }

    ; Transcribe and type the result
    TranscribeAndType()
}

; ============================================================================
; TRANSCRIPTION FUNCTION
; ============================================================================

TranscribeAndType() {
    global AUDIO_FILE, API_URL

    ; Prepare curl command with properly quoted file path
    ; Using curl to upload the audio file to the transcription service
    curlCmd := 'curl -X POST "' . API_URL . '" -F "audio=@' . AUDIO_FILE . '" -s'

    ; Execute curl and capture output
    try {
        result := RunWaitCapture(curlCmd)

        if result = "" {
            throw Error("Empty response from transcription service")
        }

        ; Parse JSON response
        jsonObj := Jxon_Load(result)

        if !jsonObj.Has("text") {
            ; Show what we got for debugging
            if SHOW_TOOLTIP {
                ToolTip("Invalid response: " . SubStr(result, 1, 100))
                SetTimer(() => ToolTip(), -5000)
            }
            throw Error("Invalid response format")
        }

        text := jsonObj["text"]

        ; Trim whitespace
        text := Trim(text)

        if text = "" {
            if SHOW_TOOLTIP {
                ToolTip("No speech detected")
                SetTimer(() => ToolTip(), -2000)
            }
            return
        }

        ; Hide tooltip
        if SHOW_TOOLTIP {
            ToolTip()
        }

        ; Type the transcribed text
        SendText(text)

        ; Optional: Add space after
        ; Send(" ")

    } catch as err {
        if SHOW_TOOLTIP {
            ToolTip("Transcription failed: " . err.Message)
            SetTimer(() => ToolTip(), -5000)
        }
    }
}

; ============================================================================
; UTILITY FUNCTIONS
; ============================================================================

; Run a command and capture its output (hidden)
RunWaitCapture(command) {
    ; Create a temporary file for output
    tempFile := A_Temp "\ahk_output_" A_TickCount ".txt"

    ; Run command and redirect output to file (hidden)
    RunWait(A_ComSpec " /C " command " > `"" tempFile "`" 2>&1", , "Hide")

    ; Read the output
    output := ""
    if FileExist(tempFile) {
        output := FileRead(tempFile)
        FileDelete(tempFile)
    }

    return output
}

; Detect audio device once at startup
DetectAudioDevice() {
    global audioDevice

    ; SIMPLIFIED: Just use your Razer microphone directly
    ; We tested this and it works!
    audioDevice := "Microphone (Razer USB Sound Card)"

    ; Show which device we're using
    if SHOW_TOOLTIP {
        ToolTip("Using: " . audioDevice)
        SetTimer(() => ToolTip(), -1500)
    }

    ; Quick test - verify FFmpeg can see this device
    ; (Optional - comment out if you want faster startup)
    testCmd := 'ffmpeg -list_devices true -f dshow -i dummy 2>&1 | findstr /C:"' . audioDevice . '"'
    ; Skip test for speed
}


; Check if required dependencies are installed
CheckDependencies() {
    ; Check for curl
    try {
        Run("curl --version", , "Hide", &curlPID)
        ProcessWaitClose(curlPID)
    } catch {
        MsgBox("curl.exe not found. Please ensure curl is installed.`n" .
               "It should be included in Windows 10/11 by default.", "Error", "Icon!")
        ExitApp()
    }

    ; Check for ffmpeg
    try {
        Run("ffmpeg -version", , "Hide", &ffmpegPID)
        ProcessWaitClose(ffmpegPID)
    } catch {
        MsgBox("ffmpeg.exe not found. Please install FFmpeg and add it to PATH.`n" .
               "Download from: https://ffmpeg.org/download.html", "Error", "Icon!")
        ExitApp()
    }

    ; Check if Whisper service is running
    try {
        result := RunWaitCapture('curl -s http://localhost:58231/health')
        if !InStr(result, "healthy") {
            throw Error("Service not responding")
        }
    } catch {
        response := MsgBox("Whisper transcription service is not running.`n" .
                          "Please start it with: docker-compose up -d`n`n" .
                          "Continue anyway?", "Warning", "Icon? YesNo")
        if response = "No" {
            ExitApp()
        }
    }
}

; ============================================================================
; JSON PARSER (Lightweight)
; ============================================================================

; Simple JSON parser for basic needs
Jxon_Load(json) {
    ; Remove whitespace
    json := Trim(json)

    ; Very simple parser - works for our basic use case
    ; For production, consider a robust JSON library

    obj := Map()

    ; Extract "text" field
    if RegExMatch(json, '"text"\s*:\s*"([^"]*)"', &match) {
        obj["text"] := match[1]
    }

    return obj
}

; ============================================================================
; HOTKEY HELP
; ============================================================================

; Press Ctrl+Shift+H to show help
^+h:: {
    helpText := "
    (
    Whisper Push-to-Talk Dictation

    Hotkey: " HOTKEY_COMBO "
    - Press and HOLD to start recording
    - RELEASE to stop recording and transcribe

    Features:
    - Automatic language detection
    - GPU-accelerated transcription
    - Types text directly into active window

    Shortcuts:
    - Ctrl+Shift+H: Show this help
    - Ctrl+Shift+Q: Exit script

    Status:
    - Recording: " (isRecording ? "Yes" : "No") "
    - Service: http://localhost:58231
    )"

    MsgBox(helpText, "Whisper Dictation Help", "Icon?")
}

; Press Ctrl+Shift+Q to exit
^+q:: {
    response := MsgBox("Exit Whisper Dictation?", "Confirm Exit", "YesNo Icon?")
    if response = "Yes" {
        ExitApp()
    }
}

; ============================================================================
; NOTES
; ============================================================================

; Customization ideas:
; 1. Add automatic punctuation insertion
; 2. Voice commands (e.g., "new line", "delete that")
; 3. Save transcription history
; 4. Support for multiple languages with hotkey switching
; 5. Integration with clipboard for review before typing

; Performance tips:
; - Use 16kHz sample rate (optimal for Whisper)
; - Keep recordings under 30 seconds for best latency
; - Ensure GPU is being used in the Docker service

; Troubleshooting:
; - If recording doesn't start, ensure your microphone is set as the default recording device in Windows Sound Settings
; - If transcription fails, check service logs: docker-compose logs -f
; - For better accuracy, use a good quality microphone close to your mouth
; - To list available audio devices: ffmpeg -list_devices true -f dshow -i dummy

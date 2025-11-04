#Requires AutoHotkey v2.0
#SingleInstance Force

; ==================== CONFIGURATION ====================
; Configuration is now loaded from config/client.env
; This section contains derived/computed values
; =======================================================

; Global variables
global isRecording := false
global recordingProcess := 0
global outputFile := ""
global stopFlagFile := ""
global tempDir := A_Temp "\whisper_dictation"
global scriptDir := A_ScriptDir
global projectRoot := scriptDir "\..\"  ; Project root is parent of scripts/
global srcDir := projectRoot "src"
global configDir := projectRoot "config"
global clientConfigFile := configDir "\client.env"

; Configuration variables (loaded from config file)
global PYTHON_CMD := "uv run python"
global AUDIO_DEVICE := ""
global HOTKEY_CONFIG := "Win+F1"  ; Default fallback
global HOTKEY_BASE_KEY := "F1"     ; Base key for KeyWait (extracted from hotkey)

; Create temp directory if it doesn't exist
if !DirExist(tempDir) {
    DirCreate(tempDir)
}

; Debug logging function
LogDebug(message) {
    global tempDir
    logFile := tempDir "\ahk_debug.log"
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend("[" timestamp "] " message "`n", logFile)
}

; Read configuration from client.env file
LoadConfig() {
    global clientConfigFile, AUDIO_DEVICE, HOTKEY_CONFIG

    LogDebug("Loading config from: " clientConfigFile)

    if !FileExist(clientConfigFile) {
        LogDebug("WARNING: Config file not found, using defaults")
        return
    }

    try {
        configContent := FileRead(clientConfigFile)

        ; Parse each line
        Loop Parse, configContent, "`n", "`r" {
            line := Trim(A_LoopField)

            ; Skip empty lines and comments
            if (line = "" || SubStr(line, 1, 1) = "#") {
                continue
            }

            ; Parse KEY=VALUE
            if InStr(line, "=") {
                parts := StrSplit(line, "=", , 2)
                key := Trim(parts[1])
                value := Trim(parts[2])

                ; Strip inline comments (everything after #)
                if InStr(value, "#") {
                    commentPos := InStr(value, "#")
                    value := SubStr(value, 1, commentPos - 1)
                    value := Trim(value)
                }

                ; Load relevant config values
                if (key = "AUDIO_DEVICE") {
                    AUDIO_DEVICE := value
                    LogDebug("Loaded AUDIO_DEVICE: " value)
                } else if (key = "HOTKEY") {
                    HOTKEY_CONFIG := value
                    LogDebug("Loaded HOTKEY: " value)
                }
            }
        }
    } catch Error as err {
        LogDebug("ERROR loading config: " err.Message)
    }
}

; Convert user-friendly hotkey format to AHK format
; Examples: "Win+F1" -> {ahkFormat: "#F1", baseKey: "F1"}
ConvertHotkeyFormat(userFormat) {
    LogDebug("Converting hotkey: " userFormat)

    ahkFormat := ""
    baseKey := ""
    parts := StrSplit(userFormat, "+")

    ; Process each part
    for index, part in parts {
        part := Trim(part)

        ; Convert modifiers
        if (part = "Win") {
            ahkFormat .= "#"
        } else if (part = "Ctrl") {
            ahkFormat .= "^"
        } else if (part = "Alt") {
            ahkFormat .= "!"
        } else if (part = "Shift") {
            ahkFormat .= "+"
        } else {
            ; This is the actual key (last part)
            ahkFormat .= part
            baseKey := part
        }
    }

    LogDebug("Converted to: " ahkFormat " (base key: " baseKey ")")
    return {ahkFormat: ahkFormat, baseKey: baseKey}
}

; Log startup
LogDebug("Script started!")
LogDebug("Temp dir: " tempDir)
LogDebug("Script dir: " scriptDir)
LogDebug("Python CMD: " PYTHON_CMD)

; Load configuration
LoadConfig()

; Clean up any stale stop flag files from previous sessions
CleanupStaleFlags() {
    global tempDir
    LogDebug("Cleaning up stale stop flag files...")
    try {
        Loop Files, tempDir "\*.stop" {
            FileDelete(A_LoopFileFullPath)
            LogDebug("Deleted stale flag: " A_LoopFileName)
        }
    } catch Error as err {
        LogDebug("Error cleaning up flags: " err.Message)
    }
}

; Run cleanup on startup
CleanupStaleFlags()

; Handler for hold-to-record hotkey
HandleRecordingHotkey() {
    global isRecording, recordingProcess, outputFile, stopFlagFile, tempDir, scriptDir, PYTHON_CMD, AUDIO_DEVICE

    if (!isRecording) {
        LogDebug("Recording hotkey pressed - starting recording")
        isRecording := true

        ; Generate unique filename with timestamp
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        outputFile := tempDir "\recording_" timestamp ".wav"
        stopFlagFile := tempDir "\recording_" timestamp ".stop"
        LogDebug("Output file: " outputFile)
        LogDebug("Stop flag file: " stopFlagFile)

        ; Show tooltip
        ToolTip("Recording... (Hold hotkey)")
        SoundBeep(600, 100)  ; Beep to indicate start

        ; Build Python command
        recorderScript := srcDir "\recorder.py"
        pythonCmd := PYTHON_CMD ' "' recorderScript '" "' outputFile '"'

        ; Add device parameter if specified
        if (AUDIO_DEVICE != "") {
            pythonCmd .= " " AUDIO_DEVICE
        }

        LogDebug("Python command: " pythonCmd)

        ; Start recording
        try {
            recordingProcess := Run(pythonCmd, , "Hide")
            LogDebug("Process started with PID: " recordingProcess)
        } catch Error as err {
            LogDebug("ERROR: " err.Message)
            ToolTip("Error starting recording:`n" err.Message)
            SetTimer () => ToolTip(), -3000
            isRecording := false
            return
        }

        ; Wait for key release
        KeyWait(HOTKEY_BASE_KEY)

        ; Stop recording
        StopRecording()
    }
}

StopRecording() {
    global isRecording, recordingProcess, outputFile, stopFlagFile, scriptDir, PYTHON_CMD

    if (isRecording) {
        LogDebug("Stopping recording, PID: " recordingProcess)

        ; Create stop flag file to signal Python to stop gracefully
        try {
            FileAppend("", stopFlagFile)
            LogDebug("Stop flag file created: " stopFlagFile)
        } catch Error as err {
            LogDebug("Error creating stop flag: " err.Message)
            ; Fall back to process killing if flag creation fails
            if (recordingProcess != 0) {
                ProcessClose(recordingProcess)
                LogDebug("Fallback: killed process with ProcessClose")
            }
            isRecording := false
            return
        }

        ; Give Python time to detect the flag (it checks every 200ms)
        ; Python will clean up the flag file itself
        LogDebug("Waiting for Python to detect stop flag...")
        Sleep(500)  ; Wait 500ms for Python to see the flag

        isRecording := false
        LogDebug("Recording stopped, file should be at: " outputFile)

        ; Play a sound to indicate recording stopped
        SoundBeep(800, 100)

        ; Wait for file to be written (check for existence with timeout)
        maxWaitMs := 3000
        waitedMs := 0
        while (!FileExist(outputFile) && waitedMs < maxWaitMs) {
            Sleep(100)
            waitedMs += 100
        }

        if (!FileExist(outputFile)) {
            LogDebug("ERROR: Recording file was not created")
            ToolTip("Error: Recording file not created", , , 1)
            SetTimer () => ToolTip("", , , 1), -3000
            return
        }

        LogDebug("Recording file exists, starting transcription...")

        ; Show transcription progress tooltip
        ToolTip("Transcribing...", , , 1)

        ; Build command to transcribe and type
        transcribeScript := srcDir "\transcribe_and_type.py"
        transcribeCmd := PYTHON_CMD ' "' transcribeScript '" "' outputFile '"'
        LogDebug("Transcribe command: " transcribeCmd)

        ; Run transcription (synchronously, wait for completion)
        try {
            RunWait(transcribeCmd, , "Hide")
            LogDebug("Transcription completed")
            ToolTip("", , , 1)  ; Hide tooltip
        } catch Error as err {
            LogDebug("ERROR during transcription: " err.Message)
            ToolTip("Transcription error - check logs", , , 1)
            SetTimer () => ToolTip("", , , 1), -3000
        }
    }
}

; Register the hotkey dynamically
hotkeyInfo := ConvertHotkeyFormat(HOTKEY_CONFIG)
HOTKEY_BASE_KEY := hotkeyInfo.baseKey
ahkHotkey := hotkeyInfo.ahkFormat

LogDebug("Registering hotkey: " ahkHotkey " (base key: " HOTKEY_BASE_KEY ")")

try {
    Hotkey(ahkHotkey, (*) => HandleRecordingHotkey(), "On")
    LogDebug("Hotkey registered successfully!")
} catch Error as err {
    LogDebug("ERROR: Failed to register hotkey: " err.Message)
    MsgBox("Failed to register hotkey: " HOTKEY_CONFIG "`n`nError: " err.Message "`n`nPlease check your config/client.env file.")
    ExitApp()
}

; Show startup message
TrayTip("Hold-to-Record Ready", "Press and hold " HOTKEY_CONFIG " to record audio")

Scriptname SNSGlobalAIController extends SKI_QuestBase

;===========================================
; SkyrimNet Global AI Controller
; On hotkey press: burst polls the config for up to ~3 seconds to catch the
; C++ state write, then tells both widgets to update visibility.
; In polling mode: continuously polls the config at the widget's poll interval.
;===========================================

; Widget references
SNSGMWidget Property GMWidget Auto
SNSWhisperWidget Property WhisperWidget Auto

; Hotkey
Int globalAIHotkey = -1

; State tracking
Bool lastKnownState = True

; Burst polling - 30 polls at 0.1s = ~3s of coverage after a key press
Int burstPollCount = 0
Int maxBurstPolls = 30
Bool isBurstActive = False  ; True while burst is running; read by GMWidget to suppress its own re-registration

Bool Function IsBursting()
    Return isBurstActive
EndFunction

Event OnInit()
    Parent.OnInit()
    RegisterForModEvent("SNSMCM_HotkeyUpdate", "OnHotkeyUpdate")
    LoadHotkey()

    ; Sync initial state to both widgets
    lastKnownState = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    Debug.Trace("[SNSGlobalAIController] OnInit - initial globalAI state: " + lastKnownState)
    If GMWidget
        GMWidget.SetGlobalAIVisibility(lastKnownState)
    EndIf
    If WhisperWidget
        WhisperWidget.SetGlobalAIVisibility(lastKnownState)
    EndIf

    ; Start polling only if any widget is in polling mode
    Float interval = GetPollInterval()
    If interval > 0
        Debug.Trace("[SNSGlobalAIController] Polling mode - starting with interval: " + interval + "s")
        RegisterForSingleUpdate(interval)
    Else
        Debug.Trace("[SNSGlobalAIController] Hotkey mode - waiting for keypress")
    EndIf
EndEvent

; Re-sync after every save load - SKI_QuestBase fires this after the game is ready
Event OnGameReload()
    Debug.Trace("[SNSGlobalAIController] OnGameReload - reloading hotkey and syncing state")
    Parent.OnGameReload()
    LoadHotkey()
    lastKnownState = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If GMWidget
        GMWidget.SetGlobalAIVisibility(lastKnownState)
    EndIf
    If WhisperWidget
        WhisperWidget.SetGlobalAIVisibility(lastKnownState)
    EndIf
EndEvent

; Load and register for globalAI hotkey
Function LoadHotkey()
    Int vkCode = SkyrimNetApi.GetConfigInt("hotkey", "toggleGlobalAI", -1)
    Int hotkeyValue = ConvertVKToSkyrim(vkCode)

    UnregisterForAllKeys()

    If hotkeyValue > 0
        globalAIHotkey = hotkeyValue
        RegisterForKey(globalAIHotkey)
        Debug.Trace("[SNSGlobalAIController] Registered globalAI hotkey: " + globalAIHotkey + " (VK " + vkCode + ")")
    Else
        globalAIHotkey = -1
        Debug.Trace("[SNSGlobalAIController] GlobalAI hotkey disabled (VK code: " + vkCode + ")")
    EndIf
EndFunction

Event OnHotkeyUpdate(string eventName, string strArg, float numArg, Form sender)
    Debug.Trace("[SNSGlobalAIController] Hotkey update received - reloading")
    LoadHotkey()
EndEvent

; Key pressed - start burst polling to catch the C++ config state change
Event OnKeyDown(Int keyCode)
    If keyCode == globalAIHotkey && !Utility.IsInMenuMode()
        Debug.Trace("[SNSGlobalAIController] GlobalAI hotkey pressed - starting burst polling")
        burstPollCount = 0
        isBurstActive = True
        UnregisterForUpdate()
        ; Fire the first poll on the very next VM tick so we catch a fast C++ write,
        ; then continue at 0.1s intervals for up to ~3 seconds total coverage.
        ; NOTE: GMWidget shares this VMHandle. isBurstActive suppresses GMWidget's
        ; 3s temp-poll re-registration so our 0.1s timer is not overwritten.
        RegisterForSingleUpdate(0.0)
    EndIf
EndEvent

; Burst poll or continuous poll - check state and update widgets
Event OnUpdate()
    Bool currentState = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)

    If currentState != lastKnownState
        Debug.Trace("[SNSGlobalAIController] State changed: " + lastKnownState + " -> " + currentState)
        lastKnownState = currentState
        If GMWidget
            GMWidget.SetGlobalAIVisibility(lastKnownState)
        EndIf
        If WhisperWidget
            WhisperWidget.SetGlobalAIVisibility(lastKnownState)
        EndIf
    EndIf

    ; Continue burst polling if active
    If burstPollCount < maxBurstPolls
        burstPollCount += 1
        Debug.Trace("[SNSGlobalAIController] Burst poll " + burstPollCount + "/" + maxBurstPolls)
        RegisterForSingleUpdate(0.1)
        Return
    EndIf

    ; Transition: burst just finished (isBurstActive still True) vs recovery/normal tick
    If isBurstActive
        ; First time past the burst threshold - burst is truly done.
        isBurstActive = False
        Float interval = GetPollInterval()
        If interval > 0
            RegisterForSingleUpdate(interval)
        Else
            Debug.Trace("[SNSGlobalAIController] Burst complete - hotkey mode, no background polling")
            ; Fire one final shared tick so co-located scripts (e.g. GMWidget) see
            ; isBurstActive=False and can re-register their own timers.
            ; isBurstActive is now False, so the recovery tick will NOT loop back here.
            RegisterForSingleUpdate(0.0)
        EndIf
    Else
        ; Recovery tick (or normal continuous poll) - re-register if polling mode.
        Float interval = GetPollInterval()
        If interval > 0
            RegisterForSingleUpdate(interval)
        EndIf
        ; Hotkey mode: nothing to do, wait for the next keypress.
    EndIf
EndEvent

; Returns polling interval if any widget is in polling mode, -1 if both in hotkey mode
Float Function GetPollInterval()
    Bool gmUseHotkey = True
    Float gmInterval = 0.5
    If GMWidget
        gmUseHotkey = GMWidget.UseHotkeyMode
        gmInterval = GMWidget.PollInterval
    EndIf

    Bool whisperUseHotkey = True
    Float whisperInterval = 0.5
    If WhisperWidget
        whisperUseHotkey = WhisperWidget.UseHotkeyMode
        whisperInterval = WhisperWidget.PollInterval
    EndIf

    If !gmUseHotkey || !whisperUseHotkey
        Float fastest = gmInterval
        If !whisperUseHotkey && whisperInterval < fastest
            fastest = whisperInterval
        EndIf
        Return fastest
    EndIf

    Return -1.0  ; Both in hotkey mode - no background polling
EndFunction

; Converts Windows Virtual Key codes to Skyrim DirectInput scan codes
Int Function ConvertVKToSkyrim(Int vkCode)
    If vkCode == 48
        Return 11  ; 0
    ElseIf vkCode >= 49 && vkCode <= 57
        Return vkCode - 47  ; 1-9
    ElseIf vkCode == 65
        Return 30  ; A
    ElseIf vkCode == 66
        Return 48  ; B
    ElseIf vkCode == 67
        Return 46  ; C
    ElseIf vkCode == 68
        Return 32  ; D
    ElseIf vkCode == 69
        Return 18  ; E
    ElseIf vkCode == 70
        Return 33  ; F
    ElseIf vkCode == 71
        Return 34  ; G
    ElseIf vkCode == 72
        Return 35  ; H
    ElseIf vkCode == 73
        Return 23  ; I
    ElseIf vkCode == 74
        Return 36  ; J
    ElseIf vkCode == 75
        Return 37  ; K
    ElseIf vkCode == 76
        Return 38  ; L
    ElseIf vkCode == 77
        Return 50  ; M
    ElseIf vkCode == 78
        Return 49  ; N
    ElseIf vkCode == 79
        Return 24  ; O
    ElseIf vkCode == 80
        Return 25  ; P
    ElseIf vkCode == 81
        Return 16  ; Q
    ElseIf vkCode == 82
        Return 19  ; R
    ElseIf vkCode == 83
        Return 31  ; S
    ElseIf vkCode == 84
        Return 20  ; T
    ElseIf vkCode == 85
        Return 22  ; U
    ElseIf vkCode == 86
        Return 47  ; V
    ElseIf vkCode == 87
        Return 17  ; W
    ElseIf vkCode == 88
        Return 45  ; X
    ElseIf vkCode == 89
        Return 21  ; Y
    ElseIf vkCode == 90
        Return 44  ; Z
    ElseIf vkCode >= 112 && vkCode <= 123
        Return vkCode - 53  ; F1-F12 -> 59-70
    ElseIf vkCode == 27
        Return 1   ; ESC
    ElseIf vkCode == 32
        Return 57  ; Space
    ElseIf vkCode == 13
        Return 28  ; Enter
    ElseIf vkCode == 9
        Return 15  ; Tab
    ElseIf vkCode == 8
        Return 14  ; Backspace
    ElseIf vkCode == 16
        Return 42  ; Shift
    ElseIf vkCode == 17
        Return 29  ; Ctrl
    ElseIf vkCode == 18
        Return 56  ; Alt
    ElseIf vkCode == 189
        Return 12  ; -
    ElseIf vkCode == 187
        Return 13  ; =
    ElseIf vkCode == 219
        Return 26  ; [
    ElseIf vkCode == 221
        Return 27  ; ]
    ElseIf vkCode == 186
        Return 39  ; ;
    ElseIf vkCode == 222
        Return 40  ; '
    ElseIf vkCode == 192
        Return 41  ; `
    ElseIf vkCode == 220
        Return 43  ; \
    ElseIf vkCode == 188
        Return 51  ; ,
    ElseIf vkCode == 190
        Return 52  ; .
    ElseIf vkCode == 191
        Return 53  ; /
    ElseIf vkCode == 37
        Return 203  ; Left
    ElseIf vkCode == 38
        Return 200  ; Up
    ElseIf vkCode == 39
        Return 205  ; Right
    ElseIf vkCode == 40
        Return 208  ; Down
    ElseIf vkCode == 45
        Return 210  ; Insert
    ElseIf vkCode == 46
        Return 211  ; Delete
    ElseIf vkCode == 36
        Return 199  ; Home
    ElseIf vkCode == 35
        Return 207  ; End
    ElseIf vkCode == 33
        Return 201  ; Page Up
    ElseIf vkCode == 34
        Return 209  ; Page Down
    ElseIf vkCode == 96
        Return 82  ; Num 0
    ElseIf vkCode == 97
        Return 79  ; Num 1
    ElseIf vkCode == 98
        Return 80  ; Num 2
    ElseIf vkCode == 99
        Return 81  ; Num 3
    ElseIf vkCode == 100
        Return 75  ; Num 4
    ElseIf vkCode == 101
        Return 76  ; Num 5
    ElseIf vkCode == 102
        Return 77  ; Num 6
    ElseIf vkCode == 103
        Return 71  ; Num 7
    ElseIf vkCode == 104
        Return 72  ; Num 8
    ElseIf vkCode == 105
        Return 73  ; Num 9
    EndIf
    ; Unsupported or invalid
    Return -1
EndFunction
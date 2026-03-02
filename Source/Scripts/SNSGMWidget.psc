Scriptname SNSGMWidget extends SKI_WidgetBase

;===========================================
; SkyrimNet Game Master & Continuous Mode Widget
; Displays GM agent on/off state and continuous mode indicator
;===========================================

;===========================================
; PROPERTIES
;===========================================

; Quest containing skynet_Library script for Papyrus hotkey support
Quest Property SkyrimNetLibraryQuest Auto

;===========================================
; STATE TRACKING
;===========================================

; Previous state values to prevent redundant UI updates
Bool lastGMState = False           ; Last known GM agent enabled state
Bool lastContinuousState = False   ; Last known continuous mode state
Bool lastGlobalAIState = True      ; Last known global AI state

; Hotkey management
Int gmHotkey = -1                  ; Toggle GM mode hotkey
Int continuousHotkey = -1          ; Toggle continuous mode hotkey
Int globalAIHotkey = -1            ; Toggle global AI hotkey (registered here so burst polling catches visibility change)
Bool usePapyrusHotkeys = False     ; True = Papyrus hotkeys, False = C++ hotkeys

; GlobalAI state (managed by SNSGlobalAIController)
Bool currentGlobalAIState = True   ; Current globalAI enabled state (set by controller)

; Reference to the controller - used to suppress temp-poll re-registration
; during a globalAI burst so the controller's 0.1s timer is not overwritten
; by this widget's 3s temp-poll interval (both scripts share a VMHandle).
SNSGlobalAIController Property GlobalAIController Auto

; Burst polling when hotkey pressed
Int burstPollCount = 0             ; Counter for burst polls after key press
Int maxBurstPolls = 4              ; Poll 4 times at 0.1s intervals (covers 0.4s window)

; Temporary polling after reset
Int tempPollCount = 0               ; Counter for temporary polls after reset
Int maxTempPolls = 6                ; Poll 6 times (18 seconds at 3s interval) after reset
Int maxTimeoutPolls = 20            ; Maximum 20 polls (60 seconds at 3s) before timeout
Bool tempPollingTimedOut = False    ; Flag if temp polling exceeded timeout
Float fTempPollInterval = 3.0       ; Temp polling interval (3 seconds to reduce init load)

;===========================================
; SETTINGS (configurable via MCM)
;===========================================

Bool widgetVisible = True          ; Master visibility toggle
Int widgetSize = 100               ; Scale percentage (50-200, default 100)
Int widgetOpacity = 100            ; Opacity percentage (0-100, default 100)
Bool bShowContinuousIndicator = True  ; Enable continuous mode indicator
Bool bHideWhenInactive = False     ; Auto-hide when GM OFF and continuous OFF
Bool bOnlyShowWhenContinuous = False  ; Only show widget when continuous mode is ON (requires GM)
Bool bUseHotkeyMode = True         ; Update mode: False = polling, True = hotkey only (DEFAULT)
Float fPollInterval = 0.5          ; Polling interval (seconds)

; Master visibility toggle property
Bool Property Visible
    Bool Function Get()
        Return widgetVisible
    EndFunction
    
    Function Set(Bool a_val)
        widgetVisible = a_val
        If (Ready)
            ; Force full status update to ensure proper visibility state
            UpdateStatus(true)
        EndIf
    EndFunction
EndProperty

; Widget scale property (percentage: 50-200)
Int Property Size
    Int Function Get()
        Return widgetSize
    EndFunction
    
    Function Set(Int a_val)
        widgetSize = a_val
        If (Ready)
            UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", widgetSize as Float)
            UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", widgetSize as Float)
        EndIf
    EndFunction
EndProperty

; Widget opacity property
Int Property Opacity
    Int Function Get()
        Return widgetOpacity
    EndFunction
    
    Function Set(Int a_val)
        widgetOpacity = a_val
        If (Ready)
            UI.SetInt(HUD_MENU, WidgetRoot + "._alpha", widgetOpacity)
        EndIf
    EndFunction
EndProperty

; Continuous mode indicator toggle
Bool Property ShowContinuousIndicator
    Bool Function Get()
        Return bShowContinuousIndicator
    EndFunction
    
    Function Set(Bool a_val)
        bShowContinuousIndicator = a_val
        If (Ready)
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Auto-hide when inactive toggle
Bool Property HideWhenInactive
    Bool Function Get()
        Return bHideWhenInactive
    EndFunction
    
    Function Set(Bool a_val)
        bHideWhenInactive = a_val
        If (Ready)
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Only show when continuous mode enabled toggle
Bool Property OnlyShowWhenContinuous
    Bool Function Get()
        Return bOnlyShowWhenContinuous
    EndFunction
    
    Function Set(Bool a_val)
        bOnlyShowWhenContinuous = a_val
        If (Ready)
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Update mode toggle (polling vs hotkey-only)
Bool Property UseHotkeyMode
    Bool Function Get()
        Return bUseHotkeyMode
    EndFunction
    
    Function Set(Bool a_val)
        bUseHotkeyMode = a_val
        If (Ready)
            UnregisterForUpdate()
            If !bUseHotkeyMode
                ; Switching to polling mode - start polling
                RegisterForSingleUpdate(fPollInterval)
            ; Else: hotkey mode - no background polling, OnKeyDown drives updates
            EndIf
        EndIf
    EndFunction
EndProperty

; Polling interval property
Float Property PollInterval
    Float Function Get()
        Return fPollInterval
    EndFunction
    
    Function Set(Float a_val)
        fPollInterval = a_val
        If (Ready && !bUseHotkeyMode)
            UnregisterForUpdate()
            RegisterForSingleUpdate(fPollInterval)
        EndIf
    EndFunction
EndProperty

;===========================================
; INITIALIZATION EVENTS
;===========================================

Event OnInit()
    Debug.Trace("[SNSGMWidget] OnInit() called")
    
    ; Set default position BEFORE calling Parent.OnInit()
    ; This ensures correct position on first load (Bottom Right, above whisper widget)
    X = 1272.0          ; Horizontal position
    Y = 686.0           ; Vertical position (30px above whisper widget's default Y=716)
    HAnchor = "right"   ; Anchor to right edge
    VAnchor = "bottom"  ; Anchor to bottom edge
    
    Debug.Trace("[SNSGMWidget] Calling Parent.OnInit()")
    Parent.OnInit()
    Debug.Trace("[SNSGMWidget] OnInit() complete, Ready=" + Ready)
EndEvent

; Called when player loads a save game
Event OnGameReload()
    Debug.Trace("[SNSGMWidget] OnGameReload() called, Ready=" + Ready)
    
    Parent.OnGameReload()
    
    Debug.Trace("[SNSGMWidget] OnGameReload() complete, Ready=" + Ready)
    
    ; Detect and register GM mode hotkeys
    LoadHotkeysFromConfig()
EndEvent

; Override to set custom modes before parent calls UpdateWidgetModes()
Event OnWidgetLoad()
    Debug.Trace("[SNSGMWidget] OnWidgetLoad() called, Ready=" + Ready)
    
    ; Set modes to include DialogueMode BEFORE parent sets them
    string[] modesArray = new string[7]
    modesArray[0] = "All"
    modesArray[1] = "StealthMode"
    modesArray[2] = "Favor"
    modesArray[3] = "Swimming"
    modesArray[4] = "HorseMode"
    modesArray[5] = "WarHorseMode"
    modesArray[6] = "DialogueMode"
    Modes = modesArray
        
    ; Now let parent handle the rest
    Parent.OnWidgetLoad()
    Debug.Trace("[SNSGMWidget] OnWidgetLoad() complete, Ready=" + Ready)
EndEvent

; Called when widget is reset (UI reload, etc.)
Event OnWidgetReset()
    Debug.Trace("[SNSGMWidget] OnWidgetReset() called, Ready=" + Ready)
    
    ; Reset temp polling counter (but NOT burstPollCount - that's only for hotkeys)
    tempPollCount = 0
    
    Parent.OnWidgetReset()
    
    ; Load hotkeys AFTER parent reset - Parent.OnWidgetReset() calls UnregisterForAllKeys()
    ; internally, so any keys registered before the parent call get wiped.
    ; Calling LoadHotkeysFromConfig() here ensures keys survive the parent reset.
    LoadHotkeysFromConfig()
        
    ; Apply saved settings to the Flash widget
    If (Ready)
        Debug.Trace("[SNSGMWidget] Applying widget settings")
        ; Apply visual settings
        UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", widgetSize as Float)
        UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", widgetSize as Float)
        UI.SetInt(HUD_MENU, WidgetRoot + "._alpha", widgetOpacity)
        
        ; Restore last known icon states to prevent flash of default OFF state
        ; Cached states are usually correct (persisted from before reload)
        ; Forced updates will correct them within 1-2 seconds if SkyrimNet state changed
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", lastGMState)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", lastContinuousState)
        Debug.Trace("[SNSGMWidget] Restored cached states - GM:" + lastGMState + " Continuous:" + lastContinuousState)
        
        ; Set visibility based on current globalAI state (set by controller) + auto-hide rules
        ; Controller has already synced currentGlobalAIState in its OnInit
        UpdateVisibilityFromState()
    Else
        Debug.Trace("[SNSGMWidget] WARNING: Ready=False in OnWidgetReset!")
    EndIf
    
    ; Register for menus so OnMenuClose can force-sync state after any game interaction.
    ; This mirrors the whisper widget's backstop and is the primary mechanism for
    ; catching globalAI state changes that happened while no menus were open.
    RegisterForMenu("LoadingMenu")
    RegisterForMenu("Dialogue Menu")
    RegisterForMenu("ContainerMenu")
    RegisterForMenu("InventoryMenu")
    RegisterForMenu("MagicMenu")
    RegisterForMenu("BarterMenu")
    RegisterForMenu("GiftMenu")
    RegisterForMenu("JournalMenu")
    RegisterForMenu("MapMenu")
    RegisterForMenu("FavoritesMenu")
    RegisterForMenu("Console")
    RegisterForMenu("CustomMenu")
    
    ; Always start initial polling after reset to establish state
    ; In hotkey mode, this will poll a few times then stop
    ; In polling mode, this will poll continuously
    If bUseHotkeyMode
        tempPollCount = 0  ; Reset temp poll counter
    EndIf
    RegisterForSingleUpdate(fTempPollInterval)
EndEvent

; Called when a registered menu closes.
; Force-syncs widget state to catch any globalAI or GM state changes that
; occurred since the last update (burst polling may have missed them if C++
; committed after the 0.4s burst window). Matches whisper widget behaviour.
Event OnMenuClose(String menuName)
    If Ready
        UpdateStatus(true)
    EndIf
EndEvent

;===========================================
; WIDGET SOURCE
;===========================================

; Returns the path to the widget SWF file
String Function GetWidgetSource()
    Return "SNSGMWidget.swf"
EndFunction

; Returns the widget type identifier
String Function GetWidgetType()
    Return "pnx.widgets.GMWidget"
EndFunction

;===========================================
; EVENT HANDLERS
;===========================================

; Handles hotkey presses for GM, continuous mode, and globalAI toggles
Event OnKeyDown(Int keyCode)
    If !Utility.IsInMenuMode()
        If keyCode == gmHotkey || keyCode == continuousHotkey || keyCode == globalAIHotkey
            ; Start burst polling to catch the config state change
            burstPollCount = 0
            RegisterForSingleUpdate(0.1)
        EndIf
    EndIf
EndEvent

; Periodic update event - polls GM and continuous mode state
Event OnUpdate()
    Debug.Trace("[SNSGMWidget] OnUpdate() called - burstPollCount=" + burstPollCount + ", tempPollCount=" + tempPollCount + ", bUseHotkeyMode=" + bUseHotkeyMode)
    ; Priority 1: Burst polling after hotkey press
    If burstPollCount < maxBurstPolls
        UpdateStatus()  ; Check all states — non-force path detects globalAI change
        burstPollCount += 1
        If burstPollCount < maxBurstPolls
            RegisterForSingleUpdate(0.1)  ; Quick 0.1s interval for burst
            Return  ; More burst polls pending
        EndIf
        ; Last burst poll - fall through to temp polling below.
    EndIf
    
    ; Reset burst counter so it doesn't interfere with other polling modes
    If burstPollCount >= maxBurstPolls
        burstPollCount = maxBurstPolls  ; Keep at max to prevent overflow
    EndIf
    
    If !bUseHotkeyMode
        ; Polling mode: continuous updates
        ; Force update on first few polls after reset to handle SkyrimNet initialization delay
        Bool forceFirst = (tempPollCount < 3)
        UpdateStatus(forceFirst)
        If tempPollCount < 10
            tempPollCount += 1
        EndIf
        RegisterForSingleUpdate(fPollInterval)
    Else
        ; Hotkey mode: temporary post-reset polling
        If (tempPollCount < maxTempPolls || !Ready) && tempPollCount < maxTimeoutPolls
            ; Normal post-reset temp polling (count-based).
            Debug.Trace("[SNSGMWidget] Temp poll #" + tempPollCount + ", Ready=" + Ready)
            UpdateStatus()
            tempPollCount += 1
            ; Only re-register if the controller is NOT running a burst.
            ; Controller shares our VMHandle - if we register 3s while it wants 0.1s,
            ; our call would win (last write wins) and slow the burst to 3s intervals.
            If !GlobalAIController || !GlobalAIController.IsBursting()
                RegisterForSingleUpdate(fTempPollInterval)
            EndIf
            
            If tempPollCount >= maxTempPolls && !Ready
                Debug.Trace("[SNSGMWidget] Extending temp polling, Ready=False (poll " + tempPollCount + ")")
            EndIf
        Else
            ; Temp polling complete - hotkey mode has no background polling.
            ; GM/continuous changes are detected via hotkey burst polls.
            ; OnMenuClose provides a backstop for any missed changes.
            Debug.Trace("[SNSGMWidget] Temp polling complete - hotkey mode, no further background polling")
        EndIf
    EndIf
EndEvent

;===========================================
; STATE UPDATE FUNCTIONS
;===========================================

; Checks GM mode, continuous mode, AND globalAI state - updates icons and visibility
Function UpdateStatus(Bool forceUpdate = false)
    ; Check globalAI directly - don't rely solely on controller calling SetGlobalAIVisibility
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    Bool globalAIChanged = (isGlobalAIEnabled != currentGlobalAIState)
    If globalAIChanged
        Debug.Trace("[SNSGMWidget] UpdateStatus detected globalAI change: " + currentGlobalAIState + " -> " + isGlobalAIEnabled)
        currentGlobalAIState = isGlobalAIEnabled
    EndIf

    ; Query current GM/continuous states from SkyrimNet
    Bool isGMEnabled = IsGMAgentEnabled()
    Bool isContinuous = False
    If (bShowContinuousIndicator || forceUpdate) && isGMEnabled
        isContinuous = IsContinuousModeEnabled()
    EndIf

    Bool gmChanged = (isGMEnabled != lastGMState)
    Bool continuousChanged = (isContinuous != lastContinuousState)

    If (forceUpdate || gmChanged || continuousChanged) && Ready
        Debug.Trace("[SNSGMWidget] Icon update - GM:" + isGMEnabled + " Continuous:" + isContinuous)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", isGMEnabled)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
        lastGMState = isGMEnabled
        lastContinuousState = isContinuous
    EndIf

    ; Update visibility whenever globalAI changed, or when GM/continuous changed with auto-hide
    If (forceUpdate || globalAIChanged || gmChanged || continuousChanged) && Ready
        UpdateVisibilityFromState()
    EndIf
EndFunction

; Called by SNSGlobalAIController when globalAI state changes
; Immediately updates visibility based on new globalAI state
Function SetGlobalAIVisibility(Bool isGlobalAIEnabled)
    currentGlobalAIState = isGlobalAIEnabled
    Debug.Trace("[SNSGMWidget] SetGlobalAIVisibility(" + isGlobalAIEnabled + ") - Ready: " + Ready + ", widgetVisible: " + widgetVisible)
    
    If !Ready
        Debug.Trace("[SNSGMWidget] SetGlobalAIVisibility - widget not Ready yet, returning")
        Return
    EndIf
    
    ; Fast path: no auto-hide rules, just set visibility directly
    If !bHideWhenInactive && !bOnlyShowWhenContinuous
        Bool shouldBeVisible = widgetVisible && currentGlobalAIState
        Debug.Trace("[SNSGMWidget] Fast path - setting visibility to " + shouldBeVisible)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        Return
    EndIf
    
    ; Slow path: need to query GM/continuous state for auto-hide rules
    Debug.Trace("[SNSGMWidget] Slow path - calling UpdateVisibilityFromState()")
    UpdateVisibilityFromState()
EndFunction

; Recalculates and updates visibility based on current states
; Called by: SetGlobalAIVisibility (globalAI change) and UpdateStatus (GM/continuous change with auto-hide)
Function UpdateVisibilityFromState()
    If !Ready
        Debug.Trace("[SNSGMWidget] UpdateVisibilityFromState - widget not Ready yet")
        Return
    EndIf
    
    Bool isGMEnabled = IsGMAgentEnabled()
    Bool isContinuous = False
    If bShowContinuousIndicator && isGMEnabled
        isContinuous = IsContinuousModeEnabled()
    EndIf
    
    Bool shouldBeVisible = widgetVisible && currentGlobalAIState
    If shouldBeVisible && bOnlyShowWhenContinuous
        If !isGMEnabled || !isContinuous
            shouldBeVisible = false
        EndIf
    ElseIf shouldBeVisible && bHideWhenInactive
        If !isGMEnabled
            shouldBeVisible = false
        EndIf
    EndIf
    
    Debug.Trace("[SNSGMWidget] UpdateVisibilityFromState - widgetVisible:" + widgetVisible + " globalAI:" + currentGlobalAIState + " GM:" + isGMEnabled + " continuous:" + isContinuous + " => shouldBeVisible:" + shouldBeVisible)
    UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
EndFunction

; Fast update for GM hotkey press - only checks GM mode
; Skips continuous mode check for instant response
Function UpdateGMMode()
    ; Early exit if global AI is disabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If !isGlobalAIEnabled
        Return
    EndIf
    
    Bool isGMEnabled = IsGMAgentEnabled()
    
    ; Update only if GM state changed
    If isGMEnabled != lastGMState
        lastGMState = isGMEnabled
        
        ; Check continuous mode since it depends on GM state
        Bool isContinuous = False
        If isGMEnabled && bShowContinuousIndicator
            isContinuous = IsContinuousModeEnabled()
            lastContinuousState = isContinuous
        Else
            ; GM disabled means continuous indicator should be off
            lastContinuousState = False
        EndIf
        
        If (Ready)
            ; Update both GM and continuous indicators together
            Debug.Trace("[SNSGMWidget] UpdateGMMode - Setting GM icon to: " + isGMEnabled)
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", isGMEnabled)
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
            
            ; Apply auto-hide logic if enabled
            Bool shouldBeVisible = widgetVisible
            If bOnlyShowWhenContinuous
                ; Only show when both GM and continuous are enabled
                If !isGMEnabled || !isContinuous
                    shouldBeVisible = false
                EndIf
            ElseIf bHideWhenInactive && !isGMEnabled
                shouldBeVisible = false
            EndIf
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        EndIf
    EndIf
EndFunction

; Fast update for continuous mode hotkey press - checks continuous mode
; Also verifies GM is enabled since continuous requires GM
Function UpdateContinuousMode()
    ; Early exit if feature disabled
    If !bShowContinuousIndicator
        Return
    EndIf
    
    ; Early exit if global AI is disabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If !isGlobalAIEnabled
        Return
    EndIf
    
    ; Check GM state - continuous only makes sense when GM is enabled
    Bool isGMEnabled = IsGMAgentEnabled()
    Bool isContinuous = False
    If isGMEnabled
        isContinuous = IsContinuousModeEnabled()
    EndIf
    
    ; Update only if continuous state changed
    If isContinuous != lastContinuousState
        lastContinuousState = isContinuous
        
        If (Ready)
            ; Update continuous indicator
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
            
            ; Apply auto-hide logic if enabled
            Bool shouldBeVisible = widgetVisible
            If bOnlyShowWhenContinuous
                ; Only show when both GM and continuous are enabled
                If !isGMEnabled || !isContinuous
                    shouldBeVisible = false
                EndIf
            ElseIf bHideWhenInactive && !isGMEnabled
                shouldBeVisible = false
            EndIf
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        EndIf
    EndIf
EndFunction

;===========================================
; STATE DETECTION
;===========================================

; Checks if Game Master agent is currently enabled
; Returns true if GM mode is active
Bool Function IsGMAgentEnabled()
    ; Check config value for GM agent enabled state
    ; Config: SkyrimNet.yaml - gamemaster.agentEnabled (boolean)
    Bool gmEnabled = SkyrimNetApi.GetConfigBool("game", "gamemaster.agentEnabled", False)
    Return gmEnabled
EndFunction

; Checks if Continuous mode is currently enabled
; Returns true if continuous mode is active
; Checks if continuous scene mode is currently enabled
Bool Function IsContinuousModeEnabled()
    Return SkyrimNetApi.IsContinuousModeEnabled()
EndFunction

;===========================================
; HOTKEY MANAGEMENT
;===========================================

; Loads hotkeys from SkyrimNet config and registers them
Function LoadHotkeysFromConfig()
    ; Determine which hotkey system SkyrimNet is using
    usePapyrusHotkeys = !SkyrimNetApi.IsCppHotkeysEnabled()
    
    ; Arrays to store new hotkeys
    Int newGMHotkey = -1
    Int newContinuousHotkey = -1
    Int newGlobalAIHotkey = -1
    
    If usePapyrusHotkeys
        ; Papyrus system: Read hotkeys directly from quest properties
        ; Note: Global AI toggle hotkey doesn't exist in Papyrus, so we skip it
        If SkyrimNetLibraryQuest
            skynet_Library libraryScript = SkyrimNetLibraryQuest as skynet_Library
            If libraryScript
                newGMHotkey = libraryScript.hotkeyToggleGameMaster
                newContinuousHotkey = libraryScript.hotkeyToggleContinuousMode
            EndIf
        EndIf
    Else
        ; C++ system: Read VK codes from config and convert
        newGMHotkey = ConvertVKToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleGameMaster", -1))
        newContinuousHotkey = ConvertVKToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleContinuousMode", -1))
        newGlobalAIHotkey = ConvertVKToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleGlobalAI", -1))
    EndIf
    
    ; Unregister old hotkeys
    If gmHotkey != -1
        UnregisterForKey(gmHotkey)
    EndIf
    If continuousHotkey != -1
        UnregisterForKey(continuousHotkey)
    EndIf
    If globalAIHotkey != -1
        UnregisterForKey(globalAIHotkey)
    EndIf
    
    ; Register new hotkeys
    gmHotkey = newGMHotkey
    continuousHotkey = newContinuousHotkey
    globalAIHotkey = newGlobalAIHotkey
    
    If gmHotkey != -1
        RegisterForKey(gmHotkey)
    EndIf
    If continuousHotkey != -1
        RegisterForKey(continuousHotkey)
    EndIf
    If globalAIHotkey != -1
        RegisterForKey(globalAIHotkey)
    EndIf
    
    Debug.Trace("[SNSGMWidget] LoadHotkeysFromConfig complete - usePapyrus:" + usePapyrusHotkeys + " gmHotkey:" + gmHotkey + " continuousHotkey:" + continuousHotkey + " globalAIHotkey:" + globalAIHotkey)
EndFunction

; Converts Windows Virtual Key codes to Skyrim DirectInput scan codes
; Uses full per-letter lookup table (letters are non-sequential in DirectInput)
; Returns: Skyrim key code, or -1 if unsupported
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
    ElseIf vkCode == 188
        Return 51  ; ,
    ElseIf vkCode == 190
        Return 52  ; .
    ElseIf vkCode == 191
        Return 53  ; /
    ElseIf vkCode == 220
        Return 43  ; \
    ElseIf vkCode == 192
        Return 41  ; `
    ElseIf vkCode == 38
        Return 200  ; Up
    ElseIf vkCode == 37
        Return 203  ; Left
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
        Return 82   ; Num 0
    ElseIf vkCode == 97
        Return 79   ; Num 1
    ElseIf vkCode == 98
        Return 80   ; Num 2
    ElseIf vkCode == 99
        Return 81   ; Num 3
    ElseIf vkCode == 100
        Return 75   ; Num 4
    ElseIf vkCode == 101
        Return 76   ; Num 5
    ElseIf vkCode == 102
        Return 77   ; Num 6
    ElseIf vkCode == 103
        Return 71   ; Num 7
    ElseIf vkCode == 104
        Return 72   ; Num 8
    ElseIf vkCode == 105
        Return 73   ; Num 9
    EndIf
    
    ; Unsupported or invalid
    Return -1
EndFunction

Scriptname SNSWidgetMCM extends SKI_ConfigBase

;===========================================
; PROPERTIES
;===========================================

; Reference to the widget script for reading/writing settings
SNSWhisperWidget Property WidgetScript Auto

;===========================================
; MCM OPTION IDs
;===========================================

Int widgetVisibleOpt          ; Show/hide widget toggle
Int widgetPosXOpt             ; X position slider
Int widgetPosYOpt             ; Y position slider
Int widgetScaleOpt            ; Size/scale slider
Int widgetOpacityOpt          ; Opacity/alpha slider
Int widgetAnchorHOpt          ; Horizontal anchor menu
Int widgetAnchorVOpt          ; Vertical anchor menu
Int widgetPositionPresetOpt   ; Position preset menu
Int showRecordingOpt          ; Recording indicator toggle
Int hideWhenInactiveOpt       ; Auto-hide feature toggle
Int useHotkeyModeOpt          ; Update mode toggle
Int pollIntervalOpt           ; Polling interval slider

;===========================================
; PRESET AND ANCHOR STRINGS
;===========================================

; Position preset display names
String[] positionPresetStrings

; Horizontal anchor display names (Left/Middle/Right)
String[] hAnchorStrings

; Vertical anchor display names (Top/Middle/Bottom)
String[] vAnchorStrings

;===========================================
; INITIALIZATION
;===========================================

; Sets up mod name, pages, and string arrays for dropdowns
Event OnConfigInit()
    ModName = "SkyrimNet Status Widget"
    Pages = new String[1]
    Pages[0] = "Settings"
    
    ; Initialize position preset dropdown options
    ; Index 0 = User Defined (custom position)
    ; Index 1-8 = Nine preset positions (corners, edges, centers)
    positionPresetStrings = new String[9]
    positionPresetStrings[0] = "User Defined"
    positionPresetStrings[1] = "Top Left"
    positionPresetStrings[2] = "Top center"
    positionPresetStrings[3] = "Top Right"
    positionPresetStrings[4] = "Center Left"
    positionPresetStrings[5] = "Center Right"
    positionPresetStrings[6] = "Bottom Left"
    positionPresetStrings[7] = "Bottom center"
    positionPresetStrings[8] = "Bottom Right"
    
    ; Initialize horizontal anchor dropdown
    hAnchorStrings = new String[3]
    hAnchorStrings[0] = "Left"      ; Anchor to left edge
    hAnchorStrings[1] = "Middle"    ; Anchor to center
    hAnchorStrings[2] = "Right"     ; Anchor to right edge
    
    ; Initialize vertical anchor dropdown
    vAnchorStrings = new String[3]
    vAnchorStrings[0] = "Top"       ; Anchor to top edge
    vAnchorStrings[1] = "Middle"    ; Anchor to center
    vAnchorStrings[2] = "Bottom"    ; Anchor to bottom edge
EndEvent

;===========================================
; MCM PAGE BUILDING
;===========================================

; Creates all the UI elements (toggles, sliders, menus)
Event OnPageReset(String page)
    If (page == "Settings")
        ; Two-column layout: fill top to bottom
        SetCursorFillMode(TOP_TO_BOTTOM)
        
        ;=== LEFT COLUMN ===
        SetCursorPosition(0)
        
        ; Display settings section
        AddHeaderOption("Widget Display")
        widgetVisibleOpt = AddToggleOption("Show Widget", WidgetScript.Visible)
        widgetScaleOpt = AddSliderOption("Size Slider", WidgetScript.Size, "{0}%")
        widgetOpacityOpt = AddSliderOption("Opacity Slider", WidgetScript.Opacity, "{0}%")
        showRecordingOpt = AddToggleOption("Show Recording Indicator", WidgetScript.ShowRecordingIndicator)
        hideWhenInactiveOpt = AddToggleOption("Hide When Inactive", WidgetScript.HideWhenInactive)
        useHotkeyModeOpt = AddToggleOption("Use Hotkey Mode", WidgetScript.UseHotkeyMode)
        
        ; Poll interval slider - disabled when hotkey mode is active
        Int pollFlags = OPTION_FLAG_NONE
        If WidgetScript.UseHotkeyMode
            pollFlags = OPTION_FLAG_DISABLED
        EndIf
        pollIntervalOpt = AddSliderOption("Poll Interval", WidgetScript.PollInterval, "{1} sec", pollFlags)
        
        AddEmptyOption()
        
        ; Position settings section
        AddHeaderOption("Location")
        widgetPositionPresetOpt = AddMenuOption("Position Preset", GetCurrentPresetName())
        widgetPosXOpt = AddSliderOption("X Position", WidgetScript.X, "{0}")
        widgetPosYOpt = AddSliderOption("Y Position", WidgetScript.Y, "{0}")
        
        ;=== RIGHT COLUMN ===
        SetCursorPosition(1)
        
        ; Anchor settings section
        AddHeaderOption("Anchors")
        widgetAnchorHOpt = AddMenuOption("Horizontal Anchor", GetDisplayAnchor(WidgetScript.HAnchor, true))
        widgetAnchorVOpt = AddMenuOption("Vertical Anchor", GetDisplayAnchor(WidgetScript.VAnchor, false))
        
        AddEmptyOption()
        
        ; Status display section (read-only)
        AddHeaderOption("Info")
        AddTextOption("Whisper Mode", GetWhisperStatus(), OPTION_FLAG_DISABLED)
    EndIf
EndEvent

;===========================================
; TOGGLE OPTION HANDLERS
;===========================================

; Toggles the boolean value and updates UI
Event OnOptionSelect(Int option)
    If (option == widgetVisibleOpt)
        ; Toggle master visibility
        WidgetScript.Visible = !WidgetScript.Visible
        SetToggleOptionValue(widgetVisibleOpt, WidgetScript.Visible)
        
    ElseIf (option == showRecordingOpt)
        ; Toggle recording indicator feature
        WidgetScript.ShowRecordingIndicator = !WidgetScript.ShowRecordingIndicator
        SetToggleOptionValue(showRecordingOpt, WidgetScript.ShowRecordingIndicator)
        
    ElseIf (option == hideWhenInactiveOpt)
        ; Toggle auto-hide feature
        WidgetScript.HideWhenInactive = !WidgetScript.HideWhenInactive
        SetToggleOptionValue(hideWhenInactiveOpt, WidgetScript.HideWhenInactive)
        
    ElseIf (option == useHotkeyModeOpt)
        ; Toggle update mode
        WidgetScript.UseHotkeyMode = !WidgetScript.UseHotkeyMode
        SetToggleOptionValue(useHotkeyModeOpt, WidgetScript.UseHotkeyMode)
        
        ; Enable/disable poll interval slider based on new mode
        If WidgetScript.UseHotkeyMode
            SetOptionFlags(pollIntervalOpt, OPTION_FLAG_DISABLED)
        Else
            SetOptionFlags(pollIntervalOpt, OPTION_FLAG_NONE)
        EndIf
    EndIf
EndEvent

;===========================================
; SLIDER OPTION HANDLERS
;===========================================

; Sets up the slider's range, default, and starting value
Event OnOptionSliderOpen(Int option)
    If (option == widgetScaleOpt)
        ; Size slider: 50% to 200% in 5% increments
        SetSliderDialogStartValue(WidgetScript.Size)
        SetSliderDialogDefaultValue(100)
        SetSliderDialogRange(50, 200)
        SetSliderDialogInterval(5)
        
    ElseIf (option == widgetOpacityOpt)
        ; Opacity slider: 0% to 100% in 5% increments
        SetSliderDialogStartValue(WidgetScript.Opacity)
        SetSliderDialogDefaultValue(100)
        SetSliderDialogRange(0, 100)
        SetSliderDialogInterval(5)
        
    ElseIf (option == widgetPosXOpt)
        ; X position: 0 to 1280 (screen width at 720p)
        SetSliderDialogStartValue(WidgetScript.X)
        SetSliderDialogDefaultValue(1272.0)
        SetSliderDialogRange(0.0, 1280.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == widgetPosYOpt)
        ; Y position: 0 to 720 (screen height at 720p)
        SetSliderDialogStartValue(WidgetScript.Y)
        SetSliderDialogDefaultValue(716.0)
        SetSliderDialogRange(0.0, 720.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == pollIntervalOpt)
        ; Poll interval: 0.1 to 1.0 seconds
        SetSliderDialogStartValue(WidgetScript.PollInterval)
        SetSliderDialogDefaultValue(0.5)
        SetSliderDialogRange(0.1, 1.0)
        SetSliderDialogInterval(0.1)
    EndIf
EndEvent

; Updates the widget property and MCM display
Event OnOptionSliderAccept(Int option, Float value)
    If (option == widgetScaleOpt)
        ; Update widget size
        WidgetScript.Size = value as Int
        SetSliderOptionValue(widgetScaleOpt, value, "{0}%")
        
    ElseIf (option == widgetOpacityOpt)
        ; Update widget opacity
        WidgetScript.Opacity = value as Int
        SetSliderOptionValue(widgetOpacityOpt, value, "{0}%")
        
    ElseIf (option == widgetPosXOpt)
        ; Update X position
        WidgetScript.X = value
        SetSliderOptionValue(widgetPosXOpt, value, "{0}")
        
    ElseIf (option == widgetPosYOpt)
        ; Update Y position
        WidgetScript.Y = value
        SetSliderOptionValue(widgetPosYOpt, value, "{0}")
        
    ElseIf (option == pollIntervalOpt)
        ; Update poll interval
        WidgetScript.PollInterval = value
        SetSliderOptionValue(pollIntervalOpt, value, "{1} sec")
    EndIf
EndEvent

;===========================================
; MENU OPTION HANDLERS
;===========================================

; Sets up the menu's available options and starting selection
Event OnOptionMenuOpen(Int option)
    If (option == widgetPositionPresetOpt)
        ; Position preset menu
        SetMenuDialogStartIndex(0)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(positionPresetStrings)
        
    ElseIf (option == widgetAnchorHOpt)
        ; Horizontal anchor menu (Left/Middle/Right)
        Int currentIndex = GetHAnchorIndex(WidgetScript.HAnchor)
        SetMenuDialogStartIndex(currentIndex)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(hAnchorStrings)
        
    ElseIf (option == widgetAnchorVOpt)
        ; Vertical anchor menu (Top/Middle/Bottom)
        Int currentIndex = GetVAnchorIndex(WidgetScript.VAnchor)
        SetMenuDialogStartIndex(currentIndex)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(vAnchorStrings)
    EndIf
EndEvent

; Updates the widget properties based on selection
Event OnOptionMenuAccept(Int option, Int index)
    If (option == widgetPositionPresetOpt)
        ; Apply selected position preset
        ApplyPositionPreset(index)
        SetMenuOptionValue(widgetPositionPresetOpt, positionPresetStrings[index])
        
        ; Update position sliders to show new values
        SetSliderOptionValue(widgetPosXOpt, WidgetScript.X, "{0}")
        SetSliderOptionValue(widgetPosYOpt, WidgetScript.Y, "{0}")
        
    ElseIf (option == widgetAnchorHOpt)
        ; Set horizontal anchor (convert display string to internal value)
        If index == 0
            WidgetScript.HAnchor = "left"
        ElseIf index == 1
            WidgetScript.HAnchor = "center"
        Else
            WidgetScript.HAnchor = "right"
        EndIf
        SetMenuOptionValue(widgetAnchorHOpt, hAnchorStrings[index])
        
    ElseIf (option == widgetAnchorVOpt)
        ; Set vertical anchor (convert display string to internal value)
        If index == 0
            WidgetScript.VAnchor = "top"
        ElseIf index == 1
            WidgetScript.VAnchor = "center"
        Else
            WidgetScript.VAnchor = "bottom"
        EndIf
        SetMenuOptionValue(widgetAnchorVOpt, vAnchorStrings[index])
    EndIf
EndEvent

;===========================================
; HELP TEXT
;===========================================

; Shows descriptive text at bottom of MCM
Event OnOptionHighlight(Int option)
    If (option == widgetVisibleOpt)
        SetInfoText("Toggle the widget visibility on/off. Default: Enabled")
        
    ElseIf (option == widgetScaleOpt)
        SetInfoText("Adjust the size of the widget (50-200%). Default: 100")
        
    ElseIf (option == widgetOpacityOpt)
        SetInfoText("Adjust the opacity/transparency of the widget (0-100%). Default: 100")
        
    ElseIf (option == showRecordingOpt)
        SetInfoText("Show a visual indicator when recording input. Default: Enabled")
        
    ElseIf (option == hideWhenInactiveOpt)
        SetInfoText("Hide the widget when in default state (no whisper mode, no recording). Shows only when active. Default: Disabled")
        
    ElseIf (option == useHotkeyModeOpt)
        SetInfoText("Updates on keypress, disables polling. Reload is required after changing SkyrimNet keybinds. Default: Disabled")
        
    ElseIf (option == pollIntervalOpt)
        SetInfoText("How often to check for state changes in polling mode (0.1-1.0 seconds). Default: 0.5")
        
    ElseIf (option == widgetPositionPresetOpt)
        SetInfoText("Select a position preset or use User Defined for manual positioning")
        
    ElseIf (option == widgetPosXOpt)
        SetInfoText("Horizontal position (0-1280)")
        
    ElseIf (option == widgetPosYOpt)
        SetInfoText("Vertical position (0-720)")
        
    ElseIf (option == widgetAnchorHOpt)
        SetInfoText("Horizontal anchor point for the widget")
        
    ElseIf (option == widgetAnchorVOpt)
        SetInfoText("Vertical anchor point for the widget")
    EndIf
EndEvent

;===========================================
; HELPER FUNCTIONS
;===========================================

; Detects which preset (if any) matches the current widget position
; Checks coordinates against known preset values with tolerance
; Returns: Preset name or "Custom Preset" if no match
String Function GetCurrentPresetName()
    Float x = WidgetScript.X
    Float y = WidgetScript.Y
    
    ; Check each preset position (with 5-unit tolerance for floating point)
    If (IsNear(x, 5.0) && IsNear(y, 5.0))
        Return "Top left"
    ElseIf (IsNear(x, 640.0) && IsNear(y, 5.0))
        Return "Top middle"
    ElseIf (IsNear(x, 1275.0) && IsNear(y, 5.0))
        Return "Top right"
    ElseIf (IsNear(x, 5.0) && IsNear(y, 360.0))
        Return "Middle left"
    ElseIf (IsNear(x, 1275.0) && IsNear(y, 360.0))
        Return "Middle right"
    ElseIf (IsNear(x, 5.0) && IsNear(y, 715.0))
        Return "Bottom left"
    ElseIf (IsNear(x, 640.0) && IsNear(y, 715.0))
        Return "Bottom middle"
    ElseIf (IsNear(x, 1272.0) && IsNear(y, 716.0))
        Return "Bottom right"
    Else
        Return "Custom Preset"
    EndIf
EndFunction

; Checks if two float values are within tolerance of each other
; Used for floating point comparison to avoid precision issues
Bool Function IsNear(Float value1, Float value2, Float tolerance = 5.0)
    Return Math.abs(value1 - value2) <= tolerance
EndFunction

; Applies a position preset to the widget
; Sets X, Y coordinates and anchors based on preset index
; Index 0 = Custom (no change), Indices 1-8 = Nine preset positions
Function ApplyPositionPreset(Int index)
    If (index == 1) ; Top Left
        WidgetScript.X = 5.0
        WidgetScript.Y = 5.0
        WidgetScript.HAnchor = "left"
        WidgetScript.VAnchor = "top"
        
    ElseIf (index == 2) ; Top Center
        WidgetScript.X = 640.0
        WidgetScript.Y = 5.0
        WidgetScript.HAnchor = "center"
        WidgetScript.VAnchor = "top"
        
    ElseIf (index == 3) ; Top Right
        WidgetScript.X = 1275.0
        WidgetScript.Y = 5.0
        WidgetScript.HAnchor = "right"
        WidgetScript.VAnchor = "top"
        
    ElseIf (index == 4) ; Middle Left
        WidgetScript.X = 5.0
        WidgetScript.Y = 360.0
        WidgetScript.HAnchor = "left"
        WidgetScript.VAnchor = "center"
        
    ElseIf (index == 5) ; Middle Right
        WidgetScript.X = 1275.0
        WidgetScript.Y = 360.0
        WidgetScript.HAnchor = "right"
        WidgetScript.VAnchor = "center"
        
    ElseIf (index == 6) ; Bottom Left
        WidgetScript.X = 5.0
        WidgetScript.Y = 715.0
        WidgetScript.HAnchor = "left"
        WidgetScript.VAnchor = "bottom"
        
    ElseIf (index == 7) ; Bottom Center
        WidgetScript.X = 640.0
        WidgetScript.Y = 715.0
        WidgetScript.HAnchor = "center"
        WidgetScript.VAnchor = "bottom"
        
    ElseIf (index == 8) ; Bottom Right
        WidgetScript.X = 1275.0
        WidgetScript.Y = 715.0
        WidgetScript.HAnchor = "right"
        WidgetScript.VAnchor = "bottom"
    EndIf
    ; index == 0 is "Custom", no action needed
EndFunction

; Converts internal horizontal anchor string to array index
; "left" -> 0, "center" -> 1, "right" -> 2
Int Function GetHAnchorIndex(String anchor)
    If (anchor == "left")
        Return 0
    ElseIf (anchor == "center")
        Return 1
    ElseIf (anchor == "right")
        Return 2
    Else
        Return 0  ; Default to left
    EndIf
EndFunction

; Converts internal vertical anchor string to array index
; "top" -> 0, "center" -> 1, "bottom" -> 2
Int Function GetVAnchorIndex(String anchor)
    If (anchor == "top")
        Return 0
    ElseIf (anchor == "center")
        Return 1
    ElseIf (anchor == "bottom")
        Return 2
    Else
        Return 0  ; Default to top
    EndIf
EndFunction

; Gets current whisper mode status for display
; Returns: "ON" if whisper mode active, "OFF" otherwise
String Function GetWhisperStatus()
    If (WidgetScript.IsWhisperModeEnabled())
        Return "ON"
    Else
        Return "OFF"
    EndIf
EndFunction

; Converts internal anchor string to display string for MCM
; Internal: "left"/"center"/"right" or "top"/"center"/"bottom"
; Display: "Left"/"Middle"/"Right" or "Top"/"Middle"/"Bottom"
String Function GetDisplayAnchor(String anchor, Bool isHorizontal)
    If isHorizontal
        Return hAnchorStrings[GetHAnchorIndex(anchor)]
    Else
        Return vAnchorStrings[GetVAnchorIndex(anchor)]
    EndIf
EndFunction

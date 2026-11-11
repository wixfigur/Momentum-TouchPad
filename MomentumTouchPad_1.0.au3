#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Pad.ico
#AutoIt3Wrapper_Outfile=MomentumTouchPad.exe
#AutoIt3Wrapper_Outfile_x64=MomentumTouchPad.exe
#AutoIt3Wrapper_Res_Description=MomentumTouchPad
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=MomentumTouchPad
#AutoIt3Wrapper_Res_ProductVersion=1.0
#AutoIt3Wrapper_Res_CompanyName=Wixfigur
#AutoIt3Wrapper_Run_AU3Check=n
#AutoIt3Wrapper_Tidy_Stop_OnError=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#NoTrayIcon

#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <SliderConstants.au3>
#include <WindowsStylesConstants.au3>
#include <WinAPILocale.au3>
#include <Misc.au3>

Global $BackColor                      ="0x202020"
Global $FontColor                      ="0xffffff"
Global $ButtonColorNormal              ="0x424242"
Global $ButtonColorHover               ="0x656565"

Global $SlowDownExpPreset			   = 330
Global $SlowDownLinPreset			   = 49
Global $ExpLinPreset				   = 2
Global $AccelleratePreset			   = 89

Global Const $g_iSamplingInterval      = 4       ; Sampling interval in ms
Global Const $g_iSpeedWindow           = 100     ; Speed measurement window in ms
Global Const $g_iDirectionWindow       = 20      ; Direction measurement window in ms
Global Const $g_iReleaseTimeout        = 21      ; Finger release detection in ms
Global Const $g_iMinimumDistance       = 15      ; Minimum movement in pixels
Global Const $g_iStillnessRadius       = 10      ; Stillness tolerance in pixels
Global Const $g_iStillnessDuration     = 10      ; Stillness duration in ms
Global Const $g_iStillnessReleaseDelay = 50      ; Waiting period after stillness detection
Global Const $g_fMinimumSpeed      	   = 3       ; Speed at which momentum starts
Global Const $g_iIntermediatePositions = 2       ; Intermediate positions
Global Const $g_iSlowDownStyle         = 3       ; 1 = exponentiell, 2 = linear, 3 = kombiniert

Global Const $g_iMaxSamples 		   = 500

Global Const $g_sWindowTitle 		   = "MomentumPad"
Global Const $g_sMessageName		   = "Momentum_OpenSettings_Message"
Global $IniPath  					   = @ScriptDir & "\settings.ini"
Global $Shortcut  					   = @programsdir&"\Accessories\"&StringTrimRight(@ScriptName,4)&".lnk"

Global $g_bTouching = False, $g_bMomentum = False, $ValueChanged = False
Global $ValueChangedTimer = TimerInit(), $g_hTimer = TimerInit(), $g_hSampleTimer = TimerInit(), $g_hStillstandTimer = TimerInit()
Global $g_fVelX = 0, $g_fVelY = 0, $g_fLetzteVelX = 0, $g_fLetzteVelY = 0, $g_fStartVelX = 0, $g_fStartVelY = 0
Global $g_fMomentumScale = 1, $g_fMomentumProgress = 0, $g_fMomentumMaxProgress = 0
Global $g_iStartX = 0, $g_iStartY = 0, $g_iStillstandX = 0, $g_iStillstandY = 0
Global $g_iMomentumStartX = 0, $g_iMomentumStartY = 0, $g_iTargetX = 0, $g_iTargetY = 0
Global $g_bStillstandGemeldet = False, $g_bStillstandWartet = False, $g_hStillstandReleaseTimer = TimerInit()
Global $g_iSampleCount = 0, $g_iSamplePos = 0, $g_aSamples[$g_iMaxSamples][3]
Global $button_Reset_color = $ButtonColorNormal, $button_Back_color = $ButtonColorNormal, $button_Exit_color = $ButtonColorNormal
Global $SlowDownExpValue, $SlowDownLinValue, $ExpLinValue, $AccellerateValue


_Initial ()


WHILE 1
	_Momentum ()
	$Msg = GUIGetMsg()
	SWITCH $Msg		
		CASE $button_Reset
			_Reset ()
		CASE $button_Back
			_HideMenu ()
		CASE $GUI_EVENT_CLOSE
			_HideMenu ()
		CASE $button_Exit
			_Exit ()
		CASE $GUI_EVENT_MOUSEMOVE
			Global $aCursor = GUIGetCursorInfo()
			_ButtonHover($button_Reset, $aCursor, $button_Reset_color)
			_ButtonHover($button_Back , $aCursor, $button_Back_color)
			_ButtonHover($button_Exit , $aCursor, $button_Exit_color)
	ENDSWITCH
WEND


Func _Initial ()
	Global $SliderSlowDownExpValue = IniRead($IniPath, "Settings", "SlowDownExp", $SlowDownExpPreset)
	Global $SliderSlowDownLinValue = IniRead($IniPath, "Settings", "SlowDownLin", $SlowDownLinPreset)
	Global $SliderExpLinValue      = IniRead($IniPath, "Settings", "ExpLin", $ExpLinPreset)
	Global $SliderAccellerateValue = IniRead($IniPath, "Settings", "Accellerate", $AccelleratePreset)
	Global $OpenMenuValue		   = IniRead($IniPath, "Settings", "Openmenu", 0)
	Global $OnOffValue			   = IniRead($IniPath, "Settings", "OnOff", 1)
	Global $AutostartValue         = IniRead($IniPath, "Settings", "Autostart", 1)
	
	if not fileexists ($Shortcut) then FileCreateShortcut (@ScriptFullPath, $Shortcut)
	if fileexists ($Shortcut) then
		Local $getShortcut = FileGetShortcut ($Shortcut)
		If not $getShortcut[0] = @ScriptFullPath then
			FileDelete ($Shortcut)
			FileCreateShortcut (@ScriptFullPath, $Shortcut)
		Endif
	Endif	
		
	Local $aMsg          = DllCall("user32.dll", "uint","RegisterWindowMessageW", "wstr", $g_sMessageName)
	Local $iOpenMessage  = $aMsg[0] ; Windows-Nachricht registrieren	
	Local $aProcesses    = ProcessList(@ScriptName) ; Zweite Instanz?
	If $aProcesses[0][0] > 1 Then
		Opt("WinDetectHiddenWindows", 1)
		Local $MenuGUI   = WinGetHandle($g_sWindowTitle)
		If $MenuGUI     <> 0 Then DllCall("user32.dll", "lresult", "SendMessageW","hwnd", $MenuGUI, "uint", $iOpenMessage,"wparam", 0, "lparam", 0)
		Exit
	EndIf
	GUIRegisterMsg($iOpenMessage, "_ShowMenu")	
	_Locale   ()	
	_MenuGui  ()
	_Calc     ()
	_IniWrite ()
	_AutostartReg ()
	Global $tRID = DllStructCreate("ushort UsagePage;ushort Usage;dword Flags;hwnd hWnd")
	DllStructSetData($tRID, "UsagePage", 0x0D)
	DllStructSetData($tRID, "Usage", 0x05)
	DllStructSetData($tRID, "Flags", 0x00000100)
	DllStructSetData($tRID, "hWnd", $MenuGui)
	Global $aReg = DllCall("user32.dll", "bool","RegisterRawInputDevices", "struct*", $tRID,"uint", 1, "uint", DllStructGetSize($tRID))
	GUIRegisterMsg(0x00FF, "_PadTouch")
Endfunc

Func _Locale ()
	Local $Locale =  _WinAPI_GetLocaleInfo($LOCALE_CUSTOM_DEFAULT, $LOCALE_SLANGUAGE)
	if StringRegExp (StringLower ($Locale), "deutsch") then
		Global $TxtManual      = "Menü mit der Verknüpfung im "&@CRLF&"Startmenü > Zubehör öffnen."
		Global $TxtSlowDownExp = "Abbremsung exponentiell"
		Global $TxtSlowDownLin = "Abbremsung linear"
		Global $TxtAcceller    = "Beschleunigung"
		Global $TxtExpLin      = "<--Exponentiell--Linear-->"
		Global $TxtOnOff       = "Momentum An/Aus"
		Global $TxtExit        = "Beenden"
		Global $TxtBack        = "Zurück"
	Else
		Global $TxtManual      = "Open menu with the shortcut"&@CRLF&"in start menu > accessories."
		Global $TxtSlowDownExp = "Slow Down exponential"
		Global $TxtSlowDownLin = "Slow Down linear"
		Global $TxtExpLin      = "<--Exponential--Linear-->"
		Global $TxtAcceller    = "Accellerate"
		Global $TxtOnOff       = "Momentum On/Off"
		Global $TxtExit        = "Exit"
		Global $TxtBack        = "Back"
	Endif
Endfunc

FUNC _MenuGui()
	Global $MenuGui=GUICreate($g_sWindowTitle,325,340,-1,-1, BitOR($WS_CAPTION, $WS_SYSMENU))
		GUISetBkColor($BackColor)
		Local $Label_SlowDownExp  = GUICtrlCreateLabel ($TxtSlowDownExp, 30, 10, 140, 15)
			GUICtrlSetFont($Label_SlowDownExp, 9, 400, "Tahoma")
			GUICtrlSetColor($Label_SlowDownExp,$FontColor)
			GUICtrlSetBkColor($Label_SlowDownExp,$BackColor)		
		Global $SliderSlowDownExp = GUICtrlCreateSlider(20, 30, 285, 30)
			GUICtrlSetBkColor($SliderSlowDownExp, $BackColor)
			GUICtrlSetLimit($SliderSlowDownExp, 380,280)
			GUICtrlSetData ($SliderSlowDownExp, $SliderSlowDownExpValue)
		Local $Label_SlowDownLin  = GUICtrlCreateLabel ($TxtSlowDownLin, 30, 70, 140, 15)
			GUICtrlSetFont($Label_SlowDownLin, 9, 400, "Tahoma")
			GUICtrlSetColor($Label_SlowDownLin,$FontColor)
			GUICtrlSetBkColor($Label_SlowDownLin,$BackColor)
		Global $SliderSlowDownLin = GUICtrlCreateSlider(20, 90, 285, 30)
			GUICtrlSetBkColor($SliderSlowDownLin, $BackColor)
			GUICtrlSetLimit($SliderSlowDownLin, 119, 19)	
			GUICtrlSetData ($SliderSlowDownLin, $SliderSlowDownLinValue)
		Local $Label_ExpLin       = GUICtrlCreateLabel ($TxtExpLin, 30, 130, 140, 15)
			GUICtrlSetFont($Label_ExpLin, 9, 400, "Tahoma")
			GUICtrlSetColor($Label_ExpLin,$FontColor)
			GUICtrlSetBkColor($Label_ExpLin,$BackColor)
		Global $SliderExpLin      = GUICtrlCreateSlider(20, 150, 285, 30)
			GUICtrlSetBkColor($SliderExpLin, $BackColor)
			GUICtrlSetLimit($SliderExpLin, 101, 1)	
			GUICtrlSetData ($SliderExpLin, $SliderExpLinValue)
		Local $Label_Accellerate  = GUICtrlCreateLabel ($TxtAcceller, 30, 190, 140, 15)
			GUICtrlSetFont($Label_Accellerate, 9, 400, "Tahoma")
			GUICtrlSetColor($Label_Accellerate,$FontColor)
			GUICtrlSetBkColor($Label_Accellerate,$BackColor)
		Global $SliderAccellerate = GUICtrlCreateSlider(20, 210, 285, 30)
			GUICtrlSetBkColor($SliderAccellerate, $BackColor)
			GUICtrlSetLimit($SliderAccellerate, 139, 39)	
			GUICtrlSetData ($SliderAccellerate, $SliderAccellerateValue)
			
		Global $CheckboxAutostart = GUICtrlCreateCheckbox("", 30, 255, 20, 20)
			GUICtrlSetState($CheckboxAutostart, $AutostartValue)
			Local $Label_CheckboxAutostart = GUICtrlCreateLabel ("Autostart", 60, 258, 85, 15)
			GUICtrlSetColor($Label_CheckboxAutostart,$FontColor)	
		Global $CheckboxOnOff     = GUICtrlCreateCheckbox("", 162, 255, 20, 20)
			GUICtrlSetState($CheckboxOnOff, $OnOffValue)
			Local $Label_CheckboxOnOff = GUICtrlCreateLabel ($TxtOnOff, 192, 258, 100, 15)
			GUICtrlSetColor($Label_CheckboxOnOff,$FontColor)
		
		Global $button_Back       = GUICtrlCreateLabel ($TxtBack, 20, 300, 85, 25, $SS_CENTER + $SS_CENTERIMAGE)
			GUICtrlSetFont($button_Back, 9, 400, "Tahoma")
			GUICtrlSetColor($button_Back,$FontColor)
			GUICtrlSetBkColor($button_Back,$ButtonColorNormal)
		Global $button_Reset      = GUICtrlCreateLabel ("Reset", 120, 300, 85, 25, $SS_CENTER + $SS_CENTERIMAGE)
			GUICtrlSetFont($button_Reset, 9, 400, "Tahoma")
			GUICtrlSetColor($button_Reset,$FontColor)
			GUICtrlSetBkColor($button_Reset,$ButtonColorNormal)
		Global $button_Exit       = GUICtrlCreateLabel ($TxtExit, 220, 300, 85, 25, $SS_CENTER + $SS_CENTERIMAGE)
			GUICtrlSetFont($button_Exit, 9, 400, "Tahoma")
			GUICtrlSetColor($button_Exit,$FontColor)
			GUICtrlSetBkColor($button_Exit,$ButtonColorNormal)
	GUISetState(@SW_HIDE, $MenuGui)
	if not fileexists ($IniPath) then
		_ShowMenu(0, 0, 0, 0)
		msgbox(64,"", $TxtManual)
	Endif
	if $OpenMenuValue = 1 then _ShowMenu(0, 0, 0, 0)
ENDFUNC

Func _ShowMenu($hWnd, $iMsg, $wParam, $lParam)
	If BitAND(WinGetState($MenuGui), 2) Then Return
    GUISetState(@SW_SHOW, $MenuGui)
	AdlibRegister("_CheckElements", 50)
    WinActivate($MenuGui)
EndFunc

Func _HideMenu ()
	AdlibUnRegister("_CheckElements")
	GUISetState(@SW_HIDE, $MenuGui)
Endfunc

Func _CheckElements ()
	$SliderSlowDownExpValue = GUICtrlRead($SliderSlowDownExp)
	$SliderSlowDownLinValue = GUICtrlRead($SliderSlowDownLin)
	$SliderExpLinValue      = GUICtrlRead($SliderExpLin)
	$SliderAccellerateValue = GUICtrlRead($SliderAccellerate)
	$AutostartValue   	    = GUICtrlRead($CheckboxAutostart)
	$OnOffValue 			= GUICtrlRead($CheckboxOnOff)

	If _HasChanged ("Elements",$SliderSlowDownExpValue+$SliderSlowDownLinValue+$SliderExpLinValue+$SliderAccellerateValue+$AutostartValue+$OnOffValue) then
		_Calc ()
		$ValueChanged 	    = True
		$ValueChangedTimer  = TimerInit()
    EndIf
	If $ValueChanged And TimerDiff($ValueChangedTimer) > 999 Then
		_IniWrite     ()
		_AutostartReg ()
		$ValueChanged = False
	EndIf
Endfunc

Func _Reset ()
	GUICtrlSetData ($SliderSlowDownExp, $SlowDownExpPreset)
	GUICtrlSetData ($SliderSlowDownLin, $SlowDownLinPreset)
	GUICtrlSetData ($SliderExpLin, $ExpLinPreset)
	GUICtrlSetData ($SliderAccellerate, $AccelleratePreset)
Endfunc

Func _Momentum ()
	if $OnOffValue = 4 then 
		Sleep(100)
		return
	Endif
	
    ; Während des Momentums übernimmt die Teilbewegung die Wartezeit.
    If Not ($g_bMomentum And Not $g_bTouching) Then
        Sleep($g_iSamplingInterval)
    EndIf

    Local $aPos = MouseGetPos()

    ; ===== KONTAKT UND STILLSTAND =====
    If $g_bTouching Then
        Local $iAbstandX = $aPos[0] - $g_iStillstandX
        Local $iAbstandY = $aPos[1] - $g_iStillstandY

        Local $fAbstand  = Sqrt($iAbstandX * $iAbstandX + $iAbstandY * $iAbstandY)

        If $fAbstand > $g_iStillnessRadius Then
            $g_iStillstandX        = $aPos[0]
            $g_iStillstandY        = $aPos[1]
            $g_hStillstandTimer    = TimerInit()
            $g_bStillstandGemeldet = False
            $g_bStillstandWartet   = False

        ElseIf Not $g_bStillstandGemeldet And Not $g_bStillstandWartet And TimerDiff($g_hStillstandTimer) >= $g_iStillnessDuration Then
            ; Stillstand erkannt: erst kurz auf ein Release warten.
            ; Die letzte Geschwindigkeit bleibt in dieser Zeit erhalten.
            $g_bStillstandWartet       = True
            $g_hStillstandReleaseTimer = TimerInit()
        EndIf

        _AddSample($aPos[0], $aPos[1])

        ; Letzte gültige Geschwindigkeit während des Kontakts sichern.
        _CalcDirectionVelocity()

        If Sqrt($g_fVelX * $g_fVelX + $g_fVelY * $g_fVelY) > 0 Then
            $g_fLetzteVelX = $g_fVelX
            $g_fLetzteVelY = $g_fVelY
        EndIf

        ; Finger vermutlich abgehoben
        If TimerDiff($g_hTimer)  > $g_iReleaseTimeout Then
            ; Gespeicherte Geschwindigkeit an das Momentum übergeben.
            $g_fVelX             = $g_fLetzteVelX
            $g_fVelY             = $g_fLetzteVelY
            $g_bTouching         = False
            ; Ein Release im Wartefenster beendet das Warten ohne Reset.
            $g_bStillstandWartet = False

            Local $iStreckeX = $aPos[0] - $g_iStartX
            Local $iStreckeY = $aPos[1] - $g_iStartY

            Local $fStrecke  = Sqrt($iStreckeX * $iStreckeX + $iStreckeY * $iStreckeY)

            Local $fGeschwindigkeit = Sqrt($g_fVelX * $g_fVelX + $g_fVelY * $g_fVelY)

            If Not $g_bStillstandGemeldet And $fStrecke >= $g_iMinimumDistance And $fGeschwindigkeit >= $g_fMinimumSpeed Then
                $g_fStartVelX        = $g_fVelX
                $g_fStartVelY        = $g_fVelY

                $g_iMomentumStartX   = $aPos[0]
                $g_iMomentumStartY   = $aPos[1]

                _PrepareMomentumTarget()

                $g_fMomentumScale    = 1
                $g_fMomentumProgress = 0
                $g_bMomentum         = ($g_fMomentumMaxProgress > 0)
            Else
                $g_bMomentum         = False
            EndIf
        EndIf
    EndIf

    ; Wenn innerhalb des Wartefensters kein Release erkannt wurde, gilt es als echter Stillstand: erst jetzt Bewegungsdaten zurücksetzen.
    If $g_bTouching And $g_bStillstandWartet And TimerDiff($g_hStillstandReleaseTimer) >= $g_iStillnessReleaseDelay Then
        _PadRelease()
        $g_bStillstandWartet = False
    EndIf

    ; ===== MOMENTUM MIT ZWISCHENPOSITIONEN =====
    If Not $g_bTouching And $g_bMomentum Then
        Local $iAltX = $aPos[0]
        Local $iAltY = $aPos[1]

        ; Nächsten Fortschritt berechnen
        $g_fMomentumProgress    += $g_fMomentumScale

        If $g_fMomentumProgress >= $g_fMomentumMaxProgress Then
            $g_fMomentumProgress = $g_fMomentumMaxProgress
        EndIf

        Local $iNeuX = Round($g_iMomentumStartX + $g_fStartVelX * $g_fMomentumProgress)
        Local $iNeuY = Round($g_iMomentumStartY + $g_fStartVelY * $g_fMomentumProgress)

        ; Anzahl der Teilbewegungen absichern
        Local $iTeile = $g_iIntermediatePositions
        If $iTeile    < 1 Then $iTeile = 1

        Local $iPause = Int($g_iSamplingInterval / $iTeile)
        If $iPause    < 1 Then $iPause = 1

        ; Zwischenpositionen anfahren
        For $i = 1 To $iTeile
            Local $iX = Round($iAltX + ($iNeuX - $iAltX) * $i / $iTeile)
            Local $iY = Round($iAltY + ($iNeuY - $iAltY) * $i / $iTeile)
            MouseMove($iX, $iY, 0)
            Sleep($iPause)
        Next

        ; Abbremsung fortsetzen
        If $g_fMomentumProgress >= $g_fMomentumMaxProgress Then
            $g_bMomentum        = False
        Else
            $g_fMomentumScale   = _NextMomentumScale($g_fMomentumScale, $g_iSlowDownStyle)

            If $g_fMomentumScale <= 0 Then
                $g_bMomentum     = False
            EndIf
        EndIf
    EndIf
Endfunc

Func _PadTouch ($hWnd, $iMsg, $wParam, $lParam)
    If Not $g_bTouching Then
        $g_bMomentum           = False
        $g_bStillstandGemeldet = False
        $g_bStillstandWartet   = False
        ; Alte Geschwindigkeitswerte verwerfen
        $g_fVelX 		   	   = 0
        $g_fVelY 		       = 0
        $g_fLetzteVelX 		   = 0
        $g_fLetzteVelY 		   = 0

        $g_iSampleCount 	   = 0
        $g_iSamplePos 		   = 0

        $g_hSampleTimer 	   = TimerInit()
        $g_hStillstandTimer    = TimerInit()

        Local $aPos            = MouseGetPos()

        $g_iStartX 			   = $aPos[0]
        $g_iStartY 			   = $aPos[1]

        $g_iStillstandX		   = $aPos[0]
        $g_iStillstandY 	   = $aPos[1]

        _AddSample($aPos[0], $aPos[1])
    EndIf
    $g_hTimer 				   = TimerInit()
    $g_bTouching 			   = True
    Return 0
EndFunc

Func _PadRelease ()
    $g_fVelX 		 	   = 0
    $g_fVelY 		       = 0
    $g_fStartVelX     	   = 0
    $g_fStartVelY     	   = 0
    $g_fMomentumScale 	   = 1
    $g_bMomentum           = False
    $g_bStillstandGemeldet = True
EndFunc

Func _AddSample ($iX, $iY)
    $g_aSamples[$g_iSamplePos][0] = TimerDiff($g_hSampleTimer)
    $g_aSamples[$g_iSamplePos][1] = $iX
    $g_aSamples[$g_iSamplePos][2] = $iY

    $g_iSamplePos 			      = Mod($g_iSamplePos + 1, $g_iMaxSamples)

    If $g_iSampleCount			  < $g_iMaxSamples Then
        $g_iSampleCount		      += 1
    EndIf
EndFunc

Func _GetDisplacement ($iFenster, ByRef $fDX, ByRef $fDY, ByRef $fZeit) ; ===== BEWEGUNG ÜBER ZEITFENSTER ERMITTELN =====
    $fDX   = 0
    $fDY   = 0
    $fZeit = 0

    If $g_iSampleCount < 2 Then Return

    Local $iNeu     = Mod($g_iSamplePos - 1 + $g_iMaxSamples, $g_iMaxSamples)
    Local $iAlt     = $iNeu
    Local $fNeuZeit = $g_aSamples[$iNeu][0]

    For $i = 1 To $g_iSampleCount - 1
        Local $iIdx = Mod($iNeu - $i + $g_iMaxSamples, $g_iMaxSamples)
        $iAlt       = $iIdx
        If $fNeuZeit - $g_aSamples[$iIdx][0] >= $iFenster Then ExitLoop
    Next

    $fZeit     = $fNeuZeit - $g_aSamples[$iAlt][0]
    If $fZeit <= 0 Then Return

    $fDX = $g_aSamples[$iNeu][1] - $g_aSamples[$iAlt][1]
    $fDY = $g_aSamples[$iNeu][2] - $g_aSamples[$iAlt][2]
EndFunc

Func _CalcDirectionVelocity ()
    Local $fDX, $fDY, $fZeit
    Local $fDirX, $fDirY, $fDirZeit

    _GetDisplacement($g_iSpeedWindow, $fDX, $fDY, $fZeit)

    If $fZeit <= 0 Or ($fDX = 0 And $fDY = 0) Then
        _GetDisplacement(999999, $fDX, $fDY, $fZeit)
    EndIf

    If $fZeit   <= 0 Then
        $g_fVelX = 0
        $g_fVelY = 0
        Return
    EndIf

    Local $fSpeed = Sqrt($fDX * $fDX + $fDY * $fDY) * $g_iSamplingInterval / $fZeit

    _GetDisplacement($g_iDirectionWindow, $fDirX, $fDirY, $fDirZeit)

    Local $fDirLength = Sqrt($fDirX * $fDirX + $fDirY * $fDirY)

    If $fDirLength <= 0 Then
        $fDirX      = $fDX
        $fDirY      = $fDY
        $fDirLength = Sqrt($fDirX * $fDirX + $fDirY * $fDirY)
    EndIf

    If $fDirLength <= 0 Then
        $g_fVelX    = 0
        $g_fVelY    = 0
        Return
    EndIf
    $g_fVelX = $fSpeed * $fDirX / $fDirLength * $AccellerateValue
    $g_fVelY = $fSpeed * $fDirY / $fDirLength * $AccellerateValue
EndFunc

Func _NextMomentumScale ($fScale, $iArt) ; ===== ABREMSUNG JE SCHRITT =====
    Switch $iArt
        Case 1 ; Exponentiell
            Return $fScale * $SlowDownExpValue
        Case 2 ; Linear
            Return $fScale - $SlowDownLinValue
        Case 3 ; Kombiniert
            If $fScale > $ExpLinValue Then
                Return $fScale * $SlowDownExpValue
            Else
                Return $fScale - $SlowDownLinValue
            EndIf
    EndSwitch
    Return $fScale * $SlowDownExpValue
EndFunc

Func _PrepareMomentumTarget ()
    Local $fScale    = 1
    Local $fGesamt   = 0
    Local $iSchritte = 0

    While $fScale  > 0 And $iSchritte < 10000
        $fGesamt   += $fScale
        $fScale     = _NextMomentumScale($fScale, $g_iSlowDownStyle)
        $iSchritte += 1
    WEnd

    Local $fMaxProgress = $fGesamt
    Local $iMaxX        = @DesktopWidth - 1
    Local $iMaxY        = @DesktopHeight - 1

    If $g_fStartVelX > 0 Then
        $fMaxProgress = _Min($fMaxProgress, ($iMaxX - $g_iMomentumStartX) / $g_fStartVelX)
    ElseIf $g_fStartVelX < 0 Then
        $fMaxProgress = _Min($fMaxProgress, (0 - $g_iMomentumStartX) / $g_fStartVelX)
    EndIf

    If $g_fStartVelY > 0 Then
        $fMaxProgress = _Min($fMaxProgress, ($iMaxY - $g_iMomentumStartY) / $g_fStartVelY)
    ElseIf $g_fStartVelY < 0 Then
        $fMaxProgress = _Min($fMaxProgress, (0 - $g_iMomentumStartY) / $g_fStartVelY)
    EndIf

    If $fMaxProgress < 0 Then $fMaxProgress = 0

    $g_fMomentumMaxProgress = $fMaxProgress
    $g_iTargetX 		    = Round($g_iMomentumStartX + $g_fStartVelX * $fMaxProgress)
    $g_iTargetY 		    = Round($g_iMomentumStartY + $g_fStartVelY * $fMaxProgress)
EndFunc

Func _Min ($a, $b) 
    If $a < $b Then Return $a
    Return $b
EndFunc

Func _Calc ()
	$SlowDownExpValue		  = Round ((660 - $SliderSlowDownExpValue) / 400, 5)
	$SlowDownLinValue 		  = Round ($SliderSlowDownLinValue / 600, 5)
	$ExpLinValue 	  		  = Round ($SliderExpLinValue / 700, 5)
	$AccellerateValue 		  = Round ($SliderAccellerateValue / 5.555, 5)
Endfunc

Func _ButtonHover ($iCtrl, ByRef $aCursor, ByRef $color)
    If $aCursor[4] = $iCtrl And $color <> $ButtonColorHover Then
        GUICtrlSetBkColor($iCtrl, $ButtonColorHover)
        $color = $ButtonColorHover
        Sleep(50)
    ElseIf $aCursor[4] <> $iCtrl And $color <> $ButtonColorNormal Then
        GUICtrlSetBkColor($iCtrl, $ButtonColorNormal)
        $color = $ButtonColorNormal
        Sleep(50)
    EndIf
EndFunc

Func _HasChanged ($name, $value)
    Static $state
    If Not IsObj($state) Then
        $state = ObjCreate("Scripting.Dictionary")
    EndIf
    If $state.Exists($name) And $state.Item($name) = $value Then Return False
    $state.Item($name) = $value
    Return True
EndFunc

Func _IniWrite ()
	IniWrite($IniPath, "Settings", "SlowDownExp", $SliderSlowDownExpValue)
	IniWrite($IniPath, "Settings", "SlowDownLin", $SliderSlowDownLinValue)
	IniWrite($IniPath, "Settings", "ExpLin", $SliderExpLinValue)
	IniWrite($IniPath, "Settings", "Accellerate", $SliderAccellerateValue)
	IniWrite($IniPath, "Settings", "Autostart", $AutostartValue)
	IniWrite($IniPath, "Settings", "OnOff", $OnOffValue)
	IniWrite($IniPath, "Settings", "OpenMenu", $OpenMenuValue)
Endfunc

Func _AutostartReg ()
	if  $AutostartValue = 1 then
		RegWrite('HKCU\Software\Microsoft\Windows\CurrentVersion\Run', 'Momentum 4 Precision Touchpad','REG_SZ','"'&@scriptfullpath&'"')
	Else
		Regdelete('HKCU\Software\Microsoft\Windows\CurrentVersion\Run', 'Momentum 4 Precision Touchpad')
	endif
Endfunc

Func _Exit ()
	AdlibUnRegister("_CheckElements")
	_IniWrite ()
	GUIDelete ($MenuGui)
	EXIT
Endfunc

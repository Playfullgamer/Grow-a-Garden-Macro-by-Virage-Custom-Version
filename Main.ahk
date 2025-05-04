; Virage Grow a Garden Macro v1.5.5
#SingleInstance, Force
#NoEnv
SetWorkingDir %A_ScriptDir%
#WinActivateForce
SetMouseDelay, -1 
SetWinDelay, -1
SetControlDelay, -1
SetBatchLines, -1   

settingsFile := A_ScriptDir "\settings.ini"
global userName
IniRead, userName, %settingsFile%, Main, RobloxUser, UnknownPlayer
if (userName = "" or userName = "UnknownPlayer") {
    InputBox, userInput, Set Your Display Name, Enter your name for Discord webhook messages:
    if (userInput != "") {
        userName := userInput
        IniWrite, %userName%, %settingsFile%, Main, RobloxUser
    } else {
        userName := "UnknownPlayer"
    }
}

IniRead, userName, %settingsFile%, Main, RobloxUser, UnknownPlayer

if (userName = "" or userName = "UnknownPlayer") {
    InputBox, userInput, Set Your Display Name, Enter your name for Discord webhook messages:
    if (userInput != "") {
        userName := userInput
        IniWrite, %userName%, %settingsFile%, Main, RobloxUser
    } else {
        userName := "UnknownPlayer"
    }
}

global webhookURL := "https://discord.com/api/webhooks/1368345029151817788/RQ2hgGukA9bNwleWJrE__yX1fnkiLWkxcv3cd-1pF33fo1GiCsAahnAfn66BZrSi7a9y"

SendWebhook(msg) {
    global webhookURL
    FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
    json := "{""content"":""[" timestamp "] " msg """}"

    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", webhookURL, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(json)
    } catch e {
        MsgBox, Webhook failed:`n%e%
    }
}

SendWebhook("Macro launched by " userName)

ScaleX(refX) {
    return Round(refX * A_ScreenWidth / 1920)
}

ScaleY(refY) {
    return Round(refY * A_ScreenHeight / 1080)
}

ScaleRegion(refX, refY, refW, refH) {
    x := ScaleX(refX)
    y := ScaleY(refY)
    w := Round(refW * A_ScreenWidth  / 1920)
    h := Round(refH * A_ScreenHeight / 1080)
    return [ x, y, w, h ]
}


global lastNotificationTime := { backpack: 0
                              , gear:      0
                              , egg:       0}
global debounceMs := 200000


; === task queue for sell / buy routines ===
global actionQueue := []

; ======== Debugging Setup ========
global debugMode := false       ; Set to true to enable debug logging
global currentSection := ""    ; Tracks current section for error context

LogDebug(msg) {
    global debugMode
    if (!debugMode)
        return
    FormatTime, timestamp, %A_Now%, yyyy-MM-dd HH:mm:ss
    FileAppend, %timestamp% - %msg%`n, *MacroDebugLog.txt
}

LogDebug("Script launched")

; ======== Global Data & Defaults ========
seedItems   := ["Carrot Seed", "Strawberry Seed", "Blueberry Seed", "Orange Tulip"
               , "Tomato Seed", "Corn Seed", "Daffodil Seed", "Watermelon Seed"
               , "Pumpkin Seed", "Apple Seed", "Bamboo Seed", "Coconut Seed"
               , "Cactus Seed", "Dragon Fruit Seed", "Mango Seed", "Grape Seed"          ,"Mushroom Seed", "Pepper Seed"]

gearItems   := ["Watering Can", "Trowel", "Basic Sprinkler", "Advanced Sprinkler"
               , "Godly Sprinkler", "Lightning Rod", "Master Sprinkler"]

slotChoice             := 1

; ======== Script State Flags ========
started    := false
IniRead, userName, %settingsFile%, Main, RobloxUser
if (userName = "" or userName = "UnknownPlayer") {
    InputBox, userInput, Set Your Display Name, Enter your name for Discord webhook messages:
    if (userInput != "")
    {
        userName := userInput
        IniWrite, %userName%, %settingsFile%, Main, RobloxUser
    }
}

Gosub, ShowGui

ShowGui:
    Gui, Destroy

    ; Load settings
    IniRead, userName, %settingsFile%, Main, RobloxUser, UnknownPlayer
    IniRead, slotChoice, %settingsFile%, Main, SlotChoice, 1
    IniRead, col, %settingsFile%, Main, Collecting, 1
    IniRead, bgColor, %settingsFile%, Main, ThemeBackgroundColor, 1A1A1A

    Gui, +Resize +MinimizeBox +SysMenu +AlwaysOnTop
    Gui, Margin, 10, 10
    Gui, Color, %bgColor%
    Gui, Font, s10 cWhite, Segoe UI

    Gui, Add, Tab2, x10 y10 w600 h690 vActiveTab cWhite Background%bgColor%, Garden|Shopping|Settings

    ; === Garden Tab ===
    Gui, Tab, Garden
    Gui, Font, s9 cWhite, Segoe UI
    Gui, Add, GroupBox, x20 y40 w560 h90 cWhite, Garden Slot Selection
    Loop, 6 {
        if (A_Index <= 3) {
            x := (A_Index-1)*100 + 40
            y := 70
        } else {
            x := (A_Index-4)*100 + 40
            y := 100
        }
        opts := "x" x " y" y " vSlot" A_Index " cWhite"
        if (A_Index = 1)
            opts .= " Group"
        if (slotChoice = A_Index)
            opts .= " Checked"
        Gui, Add, Radio, %opts%, Slot %A_Index%
    }

    Gui, Add, GroupBox, x20 y150 w560 h60 cWhite, Auto Collect Crops
    opts := "x40 y175 vCollectingEnable cWhite"
    if (col = 1)
        opts .= " Checked"
    Gui, Add, Radio, %opts%, Enable
    opts := "x140 y175 vCollectingDisable cWhite"
    if (col = 0)
        opts .= " Checked"
    Gui, Add, Radio, %opts%, Disable

    ; === Shopping Tab ===
    Gui, Tab, Shopping
    Gui, Font, s9 cWhite, Segoe UI
    Gui, Add, GroupBox, x20 y50 w260 h260 cWhite, Gear Shop Items
    Loop, % gearItems.Length() {
        IniRead, gVal, %settingsFile%, Gear, Item%A_Index%, 0
        y := 70 + (A_Index - 1) * 25
        Gui, Add, Checkbox, % "x40 y" y " vGearItem" A_Index " cWhite " . (gVal ? "Checked" : ""), % gearItems[A_Index]
    }

    Gui, Add, GroupBox, x300 y50 w260 h260 cWhite, Egg Shop
    IniRead, EggBuyAll, %settingsFile%, Egg, BuyAll, 0
    Gui, Add, Checkbox, % "x320 y70 vEggBuyAll cWhite " . (EggBuyAll ? "Checked" : ""), Buy All Eggs

    Gui, Add, GroupBox, x20 y330 w560 h300 cWhite, Seed Shop Items
    Loop, % seedItems.Length() {
        IniRead, sVal, %settingsFile%, Seed, Item%A_Index%, 0
        col := (A_Index > 9 ? 300 : 40)
        idx := (A_Index > 9 ? A_Index-9 : A_Index)
        y := 350 + (idx - 1) * 25
        Gui, Add, Checkbox, % "x" col " y" y " vSeedItem" A_Index " cWhite " . (sVal ? "Checked" : ""), % seedItems[A_Index]
    }

    ; === Settings Tab ===
    Gui, Tab, Settings
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, Text, x30 y60 cWhite, Display Name for Discord:
    Gui, Add, Edit, x30 y90 w300 vUserNameField cBlack BackgroundWhite, %userName%

    Gui, Add, Text, x30 y140 cWhite, Background Color (Hex):
    Gui, Add, Edit, x30 y170 w100 vThemeBackgroundField cBlack BackgroundWhite, %bgColor%

    ; === Final Buttons ===
    Gui, Tab
    Gui, Font, s10 cWhite Bold, Segoe UI
    Gui, Add, Button, x50 y645 w200 h40 gStartScan Background202020, Start Macro (F5)
    Gui, Add, Button, x350 y645 w200 h40 gQuit Background202020, Exit Macro (F7)

    Gui, Show, w620 h740, Virage Grow a Garden Macro v1.5.5
Return

; ========== ITEM SELECTION ==========
UpdateSelectedItems:
    Gui, Submit, NoHide
    selectedSeedItems := []
    Loop, % seedItems.Length() {
        if (SeedItem%A_Index%)
            selectedSeedItems.Push(seedItems[A_Index])
    }
    selectedGearItems := []
    Loop, % gearItems.Length() {
        if (GearItem%A_Index%)
            selectedGearItems.Push(gearItems[A_Index])
    }
Return


GetSelectedItems() {
    result := ""
    if (selectedSeedItems.Length()) {
        result .= "Seed Items:`n"
        for _, name in selectedSeedItems
            result .= "  - " name "`n"
    }
    if (selectedGearItems.Length()) {
        result .= "Gear Items:`n"
        for _, name in selectedGearItems
            result .= "  - " name "`n"
    }
    return result
}


; ========== MAIN ENTRY ==========
StartScan:
    currentSection := "StartScan"

if WinExist("Roblox")
    {
        WinActivate   ; activates the last found window (Roblox)
        WinWaitActive, , , 2  ; wait up to 2s for it to become active
    }
    Gui, Submit, NoHide
    if (UserNameField != "")
    userName := UserNameField
    SendWebhook("Macro stopped by " userName)


    Loop, 6 {
        if (Slot%A_Index%)
            slotChoice := A_Index
    }
    ; Get the collecting status from the correct radio button
    Collecting := CollectingEnable ? 1 : 0
    
    LogDebug("StartScan: slotChoice=" slotChoice)
    Gosub, UpdateSelectedItems
    itemsText := GetSelectedItems()
    LogDebug("Items → " itemsText)

    ToolTip, % "Starting macro on Slot #" slotChoice "`n`n" itemsText

    Sleep, 500
    Gosub, alignment
    ToolTip

    if (!started) {
        started    := true


        ; ← start background OCR every 300ms
        SetTimer, ScanForNotifications, 300


        LogDebug("Macro started")
        Gosub, collecting
        LogDebug("Returned to StartScan from collecting")
    } 
Return

; ========== MORE ==========

alignment:
    Sleep, 200
    Send, {i down}
    Sleep, 800
    Send, {i up}
    Sleep, 200
    Send, {o down}
    Sleep, 180
    Send, {o up}
    Sleep, 200
Return

; ========== SELL ROUTINE ==========
sell:
    currentSection := "sell"
    LogDebug("sell routine started")
    SendWebhook("Inventory full — selling crops by " userName)
    Sleep, 1000
    SafeClick(986, 546)
    Sleep, 1000
    SafeClick(966, 534)
    Sleep, 2000
    SafeClick(1252, 143)
    Sleep, 1000
    SafeClick(1250, 141)
    Sleep, 2000
    Send {e}
    Sleep, 2700
    SafeClick(1100, 450)
    Sleep, 500
    SafeClick(1100, 500)
    Sleep, 500
    SafeClick(1050, 510)
    Sleep, 2500
    SafeClick(951, 152)
    Sleep, 500
    SafeClick(945, 151)
    Sleep, 2000
    LogDebug("sell routine complete")
Return

; ========== BUY ROUTINES ==========

buyGearSeed:
    currentSection := "buyGearSeed"
    LogDebug("buyGearSeed entered")
    SendWebhook("Entering gear/seed shop by " userName)
    ; — suspend OCR so it can't interrupt our clicks —
    SetTimer, ScanForNotifications, Off

    if (selectedSeedItems.Length())
        Gosub, seedShopPath
    if (selectedGearItems.Length())
        Gosub, % "slot" slotChoice "GearShopPath"

    ; — restore OCR timer when done —
    SetTimer, ScanForNotifications, On

    LogDebug("buyGearSeed complete")
Return

buyEggShop:
    currentSection := "buyEggShop"
    LogDebug("buyEggShop entered")
    SendWebhook("Entering egg shop by " userName)
    ; — suspend OCR so it can't interrupt our clicks —
    SetTimer, ScanForNotifications, Off

if (EggBuyAll) {
    Gosub, % "slot" slotChoice "EggShopPath"
} 

        
    ; — restore OCR timer when done —
    SetTimer, ScanForNotifications, On

    LogDebug("buyEggShop complete")
Return


; ========== COLLECTING LOOP ==========
collecting:
    currentSection := "collecting"
    LogDebug("collecting loop entered")

    while ( started ) {
    if ( Collecting == 1 ) {
        Gosub, Pattern1

    }
    while ( actionQueue.Length() ) {
        next := actionQueue.RemoveAt(1)
        LogDebug("Dequeued action → " next)
        Gosub, % next
        Sleep, 500
    }



        Sleep, 200
    }

    LogDebug("Exiting collecting loop")
Return


Pattern1:
    currentSection := "Pattern1"
    LogDebug("Starting Pattern1")

    Sleep, 500
    Send, {e Down}
    Sleep, 100

    Random, sDuration, 500, 3000
    Send, {s Down}
    Sleep, %sDuration%
    Send, {s Up}

    Sleep, 50
    Send, {Space Down}
    Sleep, 50

    Random, adChoice, 0, 1
    Random, adDuration, 1500, 2000
    key := adChoice ? "a" : "d"
    Send, {%key% Down}
    Sleep, %adDuration%
    Send, {%key% Up}

    Sleep, 50
    Send, {Space Up}
    Sleep, 50
    Send, {e Up}

    Sleep, 200
    Gosub, DoubleClick

    LogDebug("Finished Pattern1")
Return



DoubleClick:
    LogDebug("DoubleClick executed")
    Sleep, 300
    SafeClick(960,130)
    Sleep, 300
    SafeClick(950,140)
    Sleep, 300
Return

ScanForNotifications:
    currentSection := "ScanForNotifications"
    LogDebug("ScanForNotifications start")

    if (!IsFunc("OCR"))
        Return

    region := ScaleRegion(802, 240, 126, 42)
    raw := OCR(region, "eng")
    StringReplace, raw, raw, `r`n, %A_Space%, All
    StringReplace, raw, raw, `n, %A_Space%, All
    cleaned := RegExReplace(raw, "[^A-Za-z]", "")
    StringLower, cleaned, cleaned
    LogDebug("Clean OCR: '" cleaned "'")

    now := A_TickCount

    ; — backpack debounce —
    if InStr(cleaned, "back") {
        if (now - lastNotificationTime.backpack > debounceMs) {
            actionQueue.Push("sell")
            lastNotificationTime.backpack := now
            LogDebug("→ Enqueued sell (backpack)")
        }
    }
    ; — gear/seed debounce —
    if InStr(cleaned, "shop") || InStr(cleaned, "seed") {
        if (now - lastNotificationTime.gear > debounceMs) {
            actionQueue.Push("buyGearSeed")
            lastNotificationTime.gear := now
            LogDebug("→ Enqueued buyGearSeed")
        }
    }
    ; — egg shop debounce —
    if InStr(cleaned, "egg") {
        if (now - lastNotificationTime.egg > debounceMs) {
            actionQueue.Push("buyEggShop")
            lastNotificationTime.egg := now
            LogDebug("→ Enqueued buyEggShop")
        }
    }
Return


SafeClick(xRef, yRef){
    ;— get actual screen size —
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    ;— scale reference coords to real coords —
    x := Round(xRef * screenW / 1920)
    y := Round(yRef * screenH / 1080)

    ;— click at the scaled location —
    CoordMode, Mouse, Screen
    MouseMove, x, y, 20
    MouseClick, Left, x, y
}


; ========== SHOP‑PATH LABELS ==========

slot1EggShopPath:
slot3EggShopPath:
slot5EggShopPath:
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Sleep, 500
    SafeClick(1250, 141)
    Sleep, 500
    Send, {d down}
    Sleep, 18000
    Send, {d up}
    Sleep, 500
    Send, {i down}
    Sleep, 100
    Send, {i up}
    Sleep, 500
    Send, {e}
    Sleep, 200
    SafeClick(900,680)
    Sleep, 300
    SafeClick(1305,365)
    Sleep, 200
    Send, {s down}
    Sleep, 220
    Send, {s up}
    Sleep, 500
    Send, {e}
    Sleep, 200
    SafeClick(900,680)
    Sleep, 300
    SafeClick(1305,365)
    Sleep, 200
    Send, {w down}
    Sleep, 450
    Send, {w up}
    Sleep, 500
    Send, {e}
    Sleep, 200
    SafeClick(900,680)
    Sleep, 300
    SafeClick(1305,365)
    Sleep, 200
    SafeClick(1000,150)
    Sleep, 500
    Gosub, alignment
    Sleep, 200
Return

slot2EggShopPath:
slot4EggShopPath:
slot6EggShopPath:
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Sleep, 500
    SafeClick(1250, 141)
    Sleep, 500
    Send, {a down}
    Sleep, 18000
    Send, {a up}
    Sleep, 500
    Send, {i down}
    Sleep, 100
    Send, {i up}
    Sleep, 500
    Send, {e}
    Sleep, 200
    SafeClick(900,680)
    Sleep, 300
    SafeClick(1305,365)
    Sleep, 200
    Send, {w down}
    Sleep, 220
    Send, {w up}
    Sleep, 500
    Send, {e}
    Sleep, 200
    SafeClick(900,680)
    Sleep, 300
    SafeClick(1305,365)
    Sleep, 200
    Send, {s down}
    Sleep, 450
    Send, {s up}
    Sleep, 500
    Send, {e}
    Sleep, 200
    SafeClick(900,680)
    Sleep, 300
    SafeClick(1305,365)
    Sleep, 200
    SafeClick(1000,150)
    Sleep, 500
    Gosub, alignment
    Sleep, 200
Return


seedShopPath:
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Sleep, 500
    SafeClick(675, 130)
    Sleep, 500
    Send {e}
    Sleep, 2000
    SafeClick(1305, 351)
    Sleep, 300
    Send, {WheelUp 40}
    Sleep, 300
    for index, item in selectedSeedItems {
        label := StrReplace(item, " ", "")
        Gosub, %label%
        Sleep, 300
    }
    Sleep, 500
    SafeClick(1290,260)
    Sleep, 500
    SafeClick(1000,150)
    Sleep, 500
Return

slot1GearShopPath:
slot3GearShopPath:
slot5GearShopPath:
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Sleep, 500
    SafeClick(675, 130)
    Sleep, 500
    Send, {d down}
    Sleep, 16400
    Send, {d up}
    Sleep, 300
    Send {e}
    Sleep, 1500
    SafeClick(1100, 450)
    Sleep, 200
    SafeClick(1100, 500)
    Sleep, 200
    SafeClick(1050, 510)
    Sleep, 2000
    SafeClick(1305, 351)
    Sleep, 300
    Send, {WheelUp 40}
    Sleep, 300
    for index, item in selectedGearItems {
        label := StrReplace(item, " ", "")
        Gosub, %label%
        Sleep, 300
    }
    Sleep, 500
    SafeClick(1290,260)
    Sleep, 500
    SafeClick(1000,150)
    Sleep, 500
Return

slot2GearShopPath:
slot4GearShopPath:
slot6GearShopPath:
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Sleep, 500
    SafeClick(675, 130)
    Sleep, 500
    Send, {a down}
    Sleep, 16400
    Send, {a up}
    Sleep, 300
    Send {e}
    Sleep, 1500
    SafeClick(1100, 450)
    Sleep, 200
    SafeClick(1100, 500)
    Sleep, 200
    SafeClick(1050, 510)
    Sleep, 2000
    SafeClick(1305, 351)
    Sleep, 300
    Send, {WheelUp 40}
    Sleep, 300
    for index, item in selectedGearItems {
        label := StrReplace(item, " ", "")
        Gosub, %label%
        Sleep, 300
    }
    Sleep, 500
    SafeClick(1290,260)
    Sleep, 500
    SafeClick(1000,150)
    Sleep, 500
Return


; ========== ITEM CALLBACKS ==========

CarrotSeed:
    Sleep, 500
    SafeClick(750, 450)
    Sleep, 500
    Loop, 25 {
        SafeClick(750, 630)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 450)
    Sleep, 300
Return
StrawberrySeed:
    Sleep, 500
    SafeClick(750, 750)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 640)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 450)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 300
return
BlueberrySeed:
    Sleep, 500
    Send, {WheelDown 3}
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 650)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
OrangeTulip:
    Sleep, 500
    Send, {WheelDown 3}
    Sleep, 500
    SafeClick(750, 800)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 650)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
TomatoSeed:
    Sleep, 500
    Send, {WheelDown 4}
    Sleep, 500
    SafeClick(750, 850)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 680)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
CornSeed:
    Sleep, 500
    Send, {WheelDown 5}
    Sleep, 500
    SafeClick(750, 850)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 690)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
DaffodilSeed:
    Sleep, 500
    Send, {WheelDown 7}
    Sleep, 500
    SafeClick(750, 840)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 700)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
WatermelonSeed:
    Sleep, 500
    Send, {WheelDown 9}
    Sleep, 500
    SafeClick(750, 830)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 700)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
PumpkinSeed:
    Sleep, 500
    Send, {WheelDown 12}
    Sleep, 500
    SafeClick(750, 670)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 720)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
AppleSeed:
    Sleep, 500
    Send, {WheelDown 15}
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 730)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
BambooSeed:
    Sleep, 500
    Send, {WheelDown 15}
    Sleep, 500
    SafeClick(750, 700)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 730)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
CoconutSeed:
    Sleep, 500
    Send, {WheelDown 16}
    Sleep, 500
    SafeClick(750, 800)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 750)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 550)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
CactusSeed:
    Sleep, 500
    Send, {WheelDown 18}
    Sleep, 500
    SafeClick(750, 800)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 750)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 550)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
DragonFruitSeed:
    Sleep, 500
    Send, {WheelDown 21}
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 770)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 550)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
MangoSeed:
    Sleep, 500
    Send, {WheelDown 21}
    Sleep, 500
    SafeClick(750, 800)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 780)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
GrapeSeed:
    Sleep, 500
    Send, {WheelDown 24}
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Loop, 25
    {
        SafeClick(750, 800)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
MushroomSeed:
    Sleep, 500
    Send, {WheelDown 24}
    Sleep, 500
    SafeClick(750, 820)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 820)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
PepperSeed:
    Sleep, 500
    Send, {WheelDown 27}
    Sleep, 500
    SafeClick(750, 820)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 820)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return


WateringCan: 
    Sleep, 500
    SafeClick(750, 450)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 630)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 450)
    Sleep, 500
return
Trowel:
    Sleep, 500
    SafeClick(750, 750)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 640)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 450)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
BasicSprinkler:
    Sleep, 500
    Send, {WheelDown 3}
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 650)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
AdvancedSprinkler:
    Sleep, 500
    Send, {WheelDown 3}
    Sleep, 500
    SafeClick(750, 800)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 650)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
GodlySprinkler:
    Sleep, 500
    Send, {WheelDown 4}
    Sleep, 500
    SafeClick(750, 850)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 680)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
LightningRod:
    Sleep, 500
    Send, {WheelDown 5}
    Sleep, 500
    SafeClick(750, 850)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 690)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 500)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return
MasterSprinkler:
    Sleep, 500
    Send, {WheelDown 7}
    Sleep, 500
    SafeClick(750, 840)
    Sleep, 500
    Loop, 10
    {
        SafeClick(750, 800)
        Sleep, 15
    }
    Sleep, 500
    SafeClick(750, 600)
    Sleep, 500
    Send, {WheelUp 40}
    Sleep, 500
return


; ========== HOTKEYS & INCLUDE ==========

SaveSettings:
    Gui, Submit, NoHide
    userName := UserNameField
    IniWrite, %userName%, %settingsFile%, Main, RobloxUser
    IniWrite, %ThemeBackgroundField%, %settingsFile%, Main, ThemeBackgroundColor
userName := UserNameField
IniWrite, %userName%, %settingsFile%, Main, RobloxUser

    ; — update our variables from the GUI —
    Loop, 6 {
        if (Slot%A_Index%)
            slotChoice := A_Index
    }
    Collecting := CollectingEnable ? 1 : 0

    ; — now write them out —
    IniWrite, %slotChoice%,   %settingsFile%, Main, SlotChoice
    IniWrite, %Collecting%,   %settingsFile%, Main, Collecting
    IniWrite, % (EggBuyAll ? 1 : 0), %settingsFile%, Egg, BuyAll


    Loop, % gearItems.Length()
        IniWrite, % (GearItem%A_Index% ? 1 : 0), %settingsFile%, Gear, Item%A_Index%

    Loop, % seedItems.Length()
        IniWrite, % (SeedItem%A_Index% ? 1 : 0), %settingsFile%, Seed, Item%A_Index%
Return

; ─── temp 
/*
F4::
    actionQueue.Push("seedShopPath")
    actionQueue.Push("slot" slotChoice "GearShopPath")
Return

F3::
    ; actionQueue.Push("sell")
    actionQueue.Push("slot" slotChoice "EggShopPath")
Return
*/

; ─── common STOP/RELOAD routine ───────────────────────────────────────────────
StopMacro(terminate := 1) {
    global userName
    Gui, Submit, NoHide
    if (UserNameField != "")
        userName := UserNameField
    SendWebhook("Macro stopped by " userName)
    Sleep, 50
    started := false
    Gosub, SaveSettings
    Gui, Destroy
    if (terminate)
        ExitApp
}


; ─── hook window close [×] and Esc key ────────────────────────────────────────
GuiClose:
GuiEscape:
    StopMacro(1)
    return

; ─── your GUI “Exit Macro (F7)” button ──────────────────────────────────────
Quit:
    StopMacro(1)
    return

; ─── F7 hotkey now cleanly reloads ───────────────────────────────────────────
F7::
    StopMacro(1)  ; prepare for reload, but don’t ExitApp
    Reload        ; AutoHotkey’s built‑in single‑step restart
    return

; ─── F5 still starts your scan ───────────────────────────────────────────────
F5::Gosub, StartScan

; ─── ensure you still include Vis2 and other directives ─────────────────────
#MaxThreadsPerHotkey, 2
#Include %A_ScriptDir%\lib\Vis2.ahk
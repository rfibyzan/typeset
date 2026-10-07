#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent(true)
SetWorkingDir(A_ScriptDir)
#Include WebView2.ahk

global webGui := ""
global wvc := ""
global activeWv := ""



; ==========================================================
; FUNGSI UTILITAS: Sudut Rounded via DWM (Windows 11)
; ==========================================================
SetRoundedCorners(hwnd) {
    preference := Buffer(4, 0)
    NumPut("Int", 2, preference)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 33, "Ptr", preference, "Int", 4)
}

; ==========================================================
; FUNGSI UTILITAS: Konversi Hex Color (#RRGGBB) ke Word COLORREF (BGR)
; ==========================================================
HexToWordColor(hexStr) {
    hexStr := Trim(StrReplace(StrReplace(hexStr, "#", ""), '"', ""))
    if (StrLen(hexStr) != 6)
        return 0 ; Default: Hitam (wdColorBlack = 0)
    try {
        r := Integer("0x" . SubStr(hexStr, 1, 2))
        g := Integer("0x" . SubStr(hexStr, 3, 2))
        b := Integer("0x" . SubStr(hexStr, 5, 2))
        return r | (g << 8) | (b << 16)
    } catch {
        return 0
    }
}

; ==========================================================
; FUNGSI UTILITAS: Dialog Pemilihan Warna Native Windows (ChooseColor)
; ==========================================================
ChooseColorDlg(initHex := "#000000", ownerHwnd := 0) {
    initHex := StrReplace(initHex, "#", "")
    r := 0, g := 0, b := 0
    if (StrLen(initHex) == 6) {
        try {
            r := Integer("0x" . SubStr(initHex, 1, 2))
            g := Integer("0x" . SubStr(initHex, 3, 2))
            b := Integer("0x" . SubStr(initHex, 5, 2))
        }
    }
    initColor := r | (g << 8) | (b << 16)
    
    static customColors := Buffer(64, 0)
    ccSize := (A_PtrSize == 8) ? 72 : 36
    cc := Buffer(ccSize, 0)
    NumPut("UInt", ccSize, cc, 0)
    NumPut("Ptr", ownerHwnd, cc, A_PtrSize)
    NumPut("UInt", initColor, cc, A_PtrSize * 3)
    NumPut("Ptr", customColors.Ptr, cc, A_PtrSize * 4)
    NumPut("UInt", 0x1 | 0x2, cc, A_PtrSize * 5) ; CC_RGBINIT | CC_FULLOPEN
    
    if DllCall("comdlg32\ChooseColorW", "Ptr", cc) {
        resColor := NumGet(cc, A_PtrSize * 3, "UInt")
        resR := resColor & 0xFF
        resG := (resColor >> 8) & 0xFF
        resB := (resColor >> 16) & 0xFF
        return Format("#{1:02X}{2:02X}{3:02X}", resR, resG, resB)
    }
    return ""
}

; ==========================================================
; FUNGSI NOTIFIKASI TOAST MODERN (HUD / OSD)
; ==========================================================
ShowToast(msg, duration := 1200) {
    static toastGui := ""
    if IsObject(toastGui) {
        try toastGui.Destroy()
        toastGui := ""
    }

    toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner")
    toastGui.BackColor := "0x141416"
    toastGui.MarginX := 0
    toastGui.MarginY := 0

    toastGui.SetFont("s10 c10B981", "Segoe UI")
    toastGui.Add("Text", "x14 y9", "●")
    toastGui.SetFont("s9 cFFFFFF", "Segoe UI")
    toastGui.Add("Text", "x32 y10", msg)

    toastGui.Show("AutoSize NoActivate Hide")
    SetRoundedCorners(toastGui.Hwnd)
    toastGui.GetPos(&x, &y, &w, &h)
    posX := A_ScreenWidth - w - 20
    posY := A_ScreenHeight - h - 60
    toastGui.Show("x" . posX . " y" . posY . " NoActivate")

    SetTimer(DismissToast, -duration)

    DismissToast() {
        if IsObject(toastGui) {
            try toastGui.Destroy()
            toastGui := ""
        }
    }
}

; Toast native hanya tampil bila window utama tertutup atau diminimize.
; Bila window terbuka, notifikasi web di dalam window yang tampil.
Notify(msg) {
    global webGui
    try {
        if IsObject(webGui) {
            if WinExist("ahk_id " . webGui.Hwnd) {
                try {
                    if (WinGetMinMax("ahk_id " . webGui.Hwnd) != -1)
                        return
                } catch {
                }
            }
        }
    } catch {
    }
    ShowToast(msg)
}

; ==========================================================
; KONFIGURASI INI
; ==========================================================
iniFile := A_ScriptDir . "\typeset.ini"

; Migrasi sekali jalan dari nama config lama. Bila config baru belum ada
; dan file lama ada, pindahkan (pengaturan user utuh). Bila keduanya ada,
; pakai yang baru dan buang yang lama agar tidak membingungkan.
oldIniFile := A_ScriptDir . "\doc_formatter.ini"
if (!FileExist(iniFile) && FileExist(oldIniFile)) {
    try FileMove(oldIniFile, iniFile)
}
if (FileExist(iniFile) && FileExist(oldIniFile)) {
    try FileDelete(oldIniFile)
}

; ==========================================================
; AUTO-UPDATE (GitHub releases)
; ==========================================================
APP_VERSION := "1.0.5"
UPDATE_URL := "https://raw.githubusercontent.com/rfibyzan/typeset/main/update.json"
updateBusy := false
updateUrl := ""
updateVer := ""
updateFile := ""
updateTotal := 0
updateInstalling := false
updateName := ""
updateLastSize := 0
updateStall := 0

UpdateOnExitCall(*) {
    global updateInstalling
    if (!updateInstalling) {
        try {
            tmpDir := A_Temp . "\Typeset_update"
            if DirExist(tmpDir) {
                try DirDelete(tmpDir, true)
            }
        }
    }
}
try OnExit(UpdateOnExitCall, 1)

if !FileExist(iniFile) {
    IniWrite("Praktikum", iniFile, "Settings", "ActivePreset")
    IniWrite("dark", iniFile, "Settings", "Theme")
    IniWrite(1, iniFile, "Settings", "AlwaysOnTop")
    IniWrite("Times New Roman|12|1.5|0|0|#000000|Justify|11111111|none", iniFile, "Presets", "Praktikum")
    IniWrite("Courier New|10|1.0|0|0|#000000|Left|11111111|none", iniFile, "Presets", "Kode")
    IniWrite("Courier New|10|1.0|0|0|#000000|Left|11010000|none", iniFile, "Presets", "Kode Sisipan")
    IniWrite("Times New Roman", iniFile, "CaptionTabel", "Font")
    IniWrite("10", iniFile, "CaptionTabel", "Size")
    IniWrite("Left", iniFile, "CaptionTabel", "Alignment")
    IniWrite("6", iniFile, "CaptionTabel", "SpaceBefore")
    IniWrite("6", iniFile, "CaptionTabel", "SpaceAfter")
    IniWrite("#000000", iniFile, "CaptionTabel", "Color")
    IniWrite("Times New Roman", iniFile, "CaptionGambar", "Font")
    IniWrite("10", iniFile, "CaptionGambar", "Size")
    IniWrite("Center", iniFile, "CaptionGambar", "Alignment")
    IniWrite("6", iniFile, "CaptionGambar", "SpaceBefore")
    IniWrite("6", iniFile, "CaptionGambar", "SpaceAfter")
    IniWrite("#000000", iniFile, "CaptionGambar", "Color")
    WriteDefaultShortcuts()
} else {
    try IniRead(iniFile, "CaptionTabel", "Color")
    catch
        IniWrite("#000000", iniFile, "CaptionTabel", "Color")
    try IniRead(iniFile, "CaptionGambar", "Color")
    catch
        IniWrite("#000000", iniFile, "CaptionGambar", "Color")
    try IniRead(iniFile, "CaptionTabel", "Font")
    catch {
        IniWrite("Times New Roman", iniFile, "CaptionTabel", "Font")
        IniWrite("10", iniFile, "CaptionTabel", "Size")
        IniWrite("Left", iniFile, "CaptionTabel", "Alignment")
        IniWrite("6", iniFile, "CaptionTabel", "SpaceBefore")
        IniWrite("6", iniFile, "CaptionTabel", "SpaceAfter")
        IniWrite("#000000", iniFile, "CaptionTabel", "Color")
    }
    try IniRead(iniFile, "CaptionGambar", "Font")
    catch {
        IniWrite("Times New Roman", iniFile, "CaptionGambar", "Font")
        IniWrite("10", iniFile, "CaptionGambar", "Size")
        IniWrite("Center", iniFile, "CaptionGambar", "Alignment")
        IniWrite("6", iniFile, "CaptionGambar", "SpaceBefore")
        IniWrite("6", iniFile, "CaptionGambar", "SpaceAfter")
        IniWrite("#000000", iniFile, "CaptionGambar", "Color")
    }
    try {
        if (IniRead(iniFile, "Presets", "Kode", "") == "")
            IniWrite("Courier New|10|1.0|0|0|#000000|Left|11111111|none", iniFile, "Presets", "Kode")
    } catch {
        IniWrite("Courier New|10|1.0|0|0|#000000|Left|11111111|none", iniFile, "Presets", "Kode")
    }
    try {
        if (IniRead(iniFile, "Presets", "Kode Sisipan", "") == "")
            IniWrite("Courier New|10|1.0|0|0|#000000|Left|11010000|none", iniFile, "Presets", "Kode Sisipan")
    } catch {
        IniWrite("Courier New|10|1.0|0|0|#000000|Left|11010000|none", iniFile, "Presets", "Kode Sisipan")
    }
    try {
        if (IniRead(iniFile, "Settings", "Theme", "") == "")
            IniWrite("dark", iniFile, "Settings", "Theme")
    } catch {
        try IniWrite("dark", iniFile, "Settings", "Theme")
    }
    try {
        if (IniRead(iniFile, "Settings", "AlwaysOnTop", "") == "")
            IniWrite(1, iniFile, "Settings", "AlwaysOnTop")
    } catch {
        try IniWrite(1, iniFile, "Settings", "AlwaysOnTop")
    }
    WriteDefaultShortcuts()
}

; Tulis default shortcut (format tampil, mis. "Ctrl+Shift+F") hanya bila belum ada.
; Tidak menimpa kustomisasi pengguna.
WriteDefaultShortcuts() {
    defs := Map("Format", "Ctrl+Shift+F", "Switcher", "Win+Shift+F", "CapTable", "Ctrl+Shift+T", "CapFig", "Ctrl+Shift+G", "Heading", "Ctrl+Alt", "Menu", "Win+Shift+C")
    for id, def in defs {
        try {
            if (IniRead(iniFile, "Shortcuts", id, "") == "")
                IniWrite(def, iniFile, "Shortcuts", id)
        } catch {
            try IniWrite(def, iniFile, "Shortcuts", id)
        }
    }
}

ExportConfigToJs()

; ==========================================================
; MENU TRAY (TASKBAR SYSTEM TRAY)
; ==========================================================
A_TrayMenu.Delete()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_IconTip := "Typeset"
OnMessage(0x404, TrayIconClick)

; Klik kiri pada tray icon langsung membuka window Typeset.
; Klik kanan menampilkan menu bawaan (Exit).
TrayIconClick(wParam, lParam, *) {
    if (lParam == 0x202) {
        try ShowModernConfigUI()
    }
}

BindShortcuts()

; Buka window otomatis saat script pertama dijalankan (close window = kembali ke tray)
ShowModernConfigUI()

; ==========================================================
; HELPER PARSER KONFIGURASI (BACKWARD COMPATIBILITY)
; ==========================================================
ParsePresetConfig(rawConfig) {
    if (rawConfig == "")
        return ""
    data := StrSplit(rawConfig, "|")
    if (data.Length < 7)
        return ""

    cfg := { font: "Times New Roman", size: "12", spacing: "1.5", before: "0", after: "0", color: "#000000", align: "Left", style: "none",
        use: Map("font", true, "size", true, "style", true, "color", true, "spacing", true, "align", true, "before", true, "after", true) }

    ; Format v2: font|size|spacing|before|after|color|align|flags8|style (>= 9 kolom).
    ; flags8 = 8 digit 0/1 untuk font,size,style,color,spacing,align,before,after.
    ; style = none|b|i|bi.
    if (data.Length >= 9) {
        cfg.font    := Trim(data[1])
        cfg.size    := Trim(data[2])
        cfg.spacing := Trim(data[3])
        cfg.before  := Trim(data[4])
        cfg.after   := Trim(data[5])
        cfg.color   := (Trim(data[6]) != "") ? Trim(data[6]) : "#000000"
        cfg.align   := (Trim(data[7]) != "") ? Trim(data[7]) : "Left"
        fl := Trim(data[8])
        keys := ["font", "size", "style", "color", "spacing", "align", "before", "after"]
        Loop 8 {
            if (StrLen(fl) >= A_Index)
                cfg.use[keys[A_Index]] := (SubStr(fl, A_Index, 1) == "1")
        }
        st := StrLower(Trim(data[9]))
        cfg.style := (st == "b" || st == "i" || st == "bi") ? st : "none"
        return cfg
    }

    ; Format lama dengan bold & italic: font|size|bold|italic|spacing|before|after[|color|align] (>= 8 kolom)
    if (data.Length >= 8) {
        cfg.font    := Trim(data[1])
        cfg.size    := Trim(data[2])
        cfg.spacing := Trim(data[5])
        cfg.before  := Trim(data[6])
        cfg.after   := Trim(data[7])
        cfg.color   := (Trim(data[8]) != "") ? Trim(data[8]) : "#000000"
        cfg.align   := (data.Length >= 9 && Trim(data[9]) != "") ? Trim(data[9]) : "Left"
        return cfg
    }

    ; Format 7 kolom: bisa format baru (font|size|spacing|before|after|color|align)
    ; atau format kuno tanpa color/align (font|size|bold|italic|spacing|before|after)
    if (data.Length == 7) {
        if (SubStr(Trim(data[6]), 1, 1) == "#" || data[7] ~= "i)^(Left|Center|Right|Justify)$") {
            cfg.font    := Trim(data[1])
            cfg.size    := Trim(data[2])
            cfg.spacing := Trim(data[3])
            cfg.before  := Trim(data[4])
            cfg.after   := Trim(data[5])
            cfg.color   := (Trim(data[6]) != "") ? Trim(data[6]) : "#000000"
            cfg.align   := (Trim(data[7]) != "") ? Trim(data[7]) : "Left"
        } else {
            cfg.font    := Trim(data[1])
            cfg.size    := Trim(data[2])
            cfg.spacing := Trim(data[5])
            cfg.before  := Trim(data[6])
            cfg.after   := Trim(data[7])
            cfg.color   := "#000000"
            cfg.align   := "Left"
        }
        return cfg
    }

    return ""
}

ParseCaptionConfig(rawCap, defaultAlign := "Left") {
    cfg := { font: "Times New Roman", size: "10", align: defaultAlign, before: "0", after: "0", color: "#000000",
        use: Map("font", true, "size", true, "color", true, "align", true, "before", true, "after", true) }
    if (rawCap == "")
        return cfg
    d := StrSplit(rawCap, "|")

    ; Format v2 caption: font|size|align|before|after|color|flags6 (kolom 7 = 6 digit 0/1).
    if (d.Length >= 7 && RegExMatch(Trim(d[7]), "^[01]{6}$")) {
        cfg.font   := Trim(d[1])
        cfg.size   := Trim(d[2])
        cfg.align  := Trim(d[3])
        cfg.before := Trim(d[4])
        cfg.after  := Trim(d[5])
        if (Trim(d[6]) != "")
            cfg.color := Trim(d[6])
        fl := Trim(d[7])
        keys := ["font", "size", "color", "align", "before", "after"]
        Loop 6 {
            cfg.use[keys[A_Index]] := (SubStr(fl, A_Index, 1) == "1")
        }
        return cfg
    }

    ; Format lama dengan bold & italic: font|size|bold|italic|align|before|after[|color] (>= 7 kolom)
    if (d.Length >= 7) {
        cfg.font   := Trim(d[1])
        cfg.size   := Trim(d[2])
        cfg.align  := Trim(d[5])
        cfg.before := Trim(d[6])
        cfg.after  := Trim(d[7])
        if (d.Length >= 8 && Trim(d[8]) != "")
            cfg.color := Trim(d[8])
        return cfg
    }

    ; Format baru tanpa bold & italic: font|size|align|before|after|color (6 kolom)
    if (d.Length >= 6) {
        cfg.font   := Trim(d[1])
        cfg.size   := Trim(d[2])
        cfg.align  := Trim(d[3])
        cfg.before := Trim(d[4])
        cfg.after  := Trim(d[5])
        if (Trim(d[6]) != "")
            cfg.color := Trim(d[6])
        return cfg
    }

    return cfg
}

; ==========================================================
; LOGIKA EKSEKUSI FORMATTING KE MICROSOFT WORD
; ==========================================================

; ==========================================================
; UNDO WORD: gabungkan semua perubahan format menjadi 1 entri undo (1x Ctrl+Z).
; BeginWordUndo mengembalikan true bila custom record dimulai oleh kita;
; nilai itu WAJIB diteruskan ke EndWordUndo (via try/finally) agar stack
; undo Word tidak macet dalam status merekam.
; ==========================================================
BeginWordUndo(wordApp, label) {
    try {
        ur := wordApp.UndoRecord
        if !ur.IsRecordingCustomRecord {
            ur.StartCustomRecord(label)
            return true
        }
    } catch {
    }
    return false
}

EndWordUndo(wordApp, started) {
    if !started
        return
    try {
        wordApp.UndoRecord.EndCustomRecord()
    } catch {
    }
}

; ==========================================================
ApplyPresetToWord(presetName := "") {
    if (presetName == "")
        presetName := IniRead(iniFile, "Settings", "ActivePreset", "")
    if (presetName == "") {
        ShowToast("No active preset selected!")
        return false
    }

    rawConfig := IniRead(iniFile, "Presets", presetName, "")
    if (rawConfig == "") {
        ShowToast("Preset '" . presetName . "' not found!")
        return false
    }

    cfg := ParsePresetConfig(rawConfig)
    if !IsObject(cfg) {
        ShowToast("Incomplete preset configuration!")
        return false
    }

    try {
        wordApp := ComObjActive("Word.Application")
        undoStarted := BeginWordUndo(wordApp, "Typeset: " . presetName)
        try {
            sel := wordApp.Selection
            if (cfg.use["font"])
                sel.Font.Name := cfg.font
            if (cfg.use["size"])
                sel.Font.Size := Float(cfg.size)
            if (cfg.use["style"]) {
                sel.Font.Bold := InStr(cfg.style, "b") ? true : false
                sel.Font.Italic := InStr(cfg.style, "i") ? true : false
            }
            if (cfg.use["color"])
                sel.Font.Color := HexToWordColor(cfg.color)
            if (cfg.use["align"]) {
                switch cfg.align {
                    case "Left":    sel.ParagraphFormat.Alignment := 0
                    case "Center":  sel.ParagraphFormat.Alignment := 1
                    case "Right":   sel.ParagraphFormat.Alignment := 2
                    case "Justify": sel.ParagraphFormat.Alignment := 3
                    default:        sel.ParagraphFormat.Alignment := 0
                }
            }
            if (cfg.use["before"])
                sel.ParagraphFormat.SpaceBefore := Float(cfg.before)
            if (cfg.use["after"])
                sel.ParagraphFormat.SpaceAfter := Float(cfg.after)
            if (cfg.use["spacing"]) {
                switch cfg.spacing {
                    case "1.0": sel.ParagraphFormat.LineSpacingRule := 0
                    case "1.5": sel.ParagraphFormat.LineSpacingRule := 1
                    case "2.0": sel.ParagraphFormat.LineSpacingRule := 2
                    case "1.15":
                        sel.ParagraphFormat.LineSpacingRule := 5
                        sel.ParagraphFormat.LineSpacing := 13.8
                    default:
                        try sel.ParagraphFormat.LineSpacing := Float(cfg.spacing) * 12
                }
            }
            ShowToast("Format applied: " . presetName)
            return true
        } finally {
            EndWordUndo(wordApp, undoStarted)
        }
    } catch {
        ShowToast("Word not detected or no text selected.")
        return false
    }
}

; ==========================================================
; LOGIKA CAPTION FORMATTER (TABEL & GAMBAR)
; ==========================================================
ApplyCaptionFormat(captionType) {
    activePreset := IniRead(iniFile, "Settings", "ActivePreset", "")
    keyName := (captionType == "tabel") ? "Tabel" : "Gambar"
    legacySec := (captionType == "tabel") ? "CaptionTabel" : "CaptionGambar"
    defaultAlign := (captionType == "tabel") ? "Left" : "Center"

    rawPresetCap := ""
    if (activePreset != "") {
        try rawPresetCap := IniRead(iniFile, "Captions_" . activePreset, keyName, "")
    }

    if (rawPresetCap != "") {
        capCfg := ParseCaptionConfig(rawPresetCap, defaultAlign)
    } else {
        fontName  := IniRead(iniFile, legacySec, "Font", "Times New Roman")
        fontSize  := IniRead(iniFile, legacySec, "Size", "10")
        fontColor := IniRead(iniFile, legacySec, "Color", "#000000")
        alignment := IniRead(iniFile, legacySec, "Alignment", defaultAlign)
        spBefore  := IniRead(iniFile, legacySec, "SpaceBefore", "0")
        spAfter   := IniRead(iniFile, legacySec, "SpaceAfter", "0")
        capCfg := { font: fontName, size: fontSize, align: alignment, before: spBefore, after: spAfter, color: fontColor }
    }

    try {
        wordApp := ComObjActive("Word.Application")
        undoStarted := BeginWordUndo(wordApp, "Typeset: Caption " . captionType)
        try {
            sel := wordApp.Selection
            if (capCfg.use["font"])
                sel.Font.Name  := capCfg.font
            if (capCfg.use["size"])
                sel.Font.Size  := Float(capCfg.size)
            if (capCfg.use["color"])
                sel.Font.Color := HexToWordColor(capCfg.color)
            if (capCfg.use["align"]) {
                switch capCfg.align {
                    case "Left":    sel.ParagraphFormat.Alignment := 0
                    case "Center":  sel.ParagraphFormat.Alignment := 1
                    case "Right":   sel.ParagraphFormat.Alignment := 2
                    case "Justify": sel.ParagraphFormat.Alignment := 3
                    default:        sel.ParagraphFormat.Alignment := (captionType == "tabel" ? 0 : 1)
                }
            }
            if (capCfg.use["before"])
                sel.ParagraphFormat.SpaceBefore := Float(capCfg.before)
            if (capCfg.use["after"])
                sel.ParagraphFormat.SpaceAfter  := Float(capCfg.after)
            sel.ParagraphFormat.LineSpacingRule := 0
            label := (captionType == "tabel") ? "Table Caption" : "Figure Caption"
            presetSuffix := (activePreset != "") ? " (" . activePreset . ")" : ""
            ShowToast(label . presetSuffix . " applied")
        } finally {
            EndWordUndo(wordApp, undoStarted)
        }
    } catch {
        ShowToast("Word not detected or no text selected.")
    }
}

; ==========================================================
; SHORTCUT DINAMIS: semua hotkey dibaca dari INI [Shortcuts] (format tampil,
; mis. "Ctrl+Shift+F") dan dapat diubah dari tab Pengaturan. Tidak ada hotkey
; statis lagi di file ini.
; ==========================================================
CurCombos := Map()
global swGui := ""
global swWvc := ""
global swWv := ""

; Ubah "Ctrl+Shift+F" -> "^+f". "" bila tidak valid.
ShortcutToCombo(display) {
    parts := StrSplit(display, "+")
    if (parts.Length < 2)
        return ""
    mods := ""
    key := Trim(parts[parts.Length])
    Loop parts.Length - 1 {
        m := Trim(parts[A_Index])
        if (m == "Ctrl")
            mods .= "^"
        else if (m == "Shift")
            mods .= "+"
        else if (m == "Alt")
            mods .= "!"
        else if (m == "Win")
            mods .= "#"
        else
            return ""
    }
    if (StrLen(key) == 1)
        return mods . StrLower(key)
    if RegExMatch(key, "^F([1-9]|1[0-9]|2[0-4])$")
        return mods . StrUpper(key)
    static named := Map("Space", "Space", "Delete", "Delete", "Insert", "Insert",
        "Home", "Home", "End", "End", "PgUp", "PgUp", "PgDn", "PgDn",
        "Right", "Right", "Left", "Left", "Up", "Up", "Down", "Down")
    if (named.Has(key))
        return mods . named[key]
    return ""
}

; Ubah "Ctrl+Alt" -> "^!". "" bila tidak valid.
HeadingModsToCombo(disp) {
    parts := StrSplit(disp, "+")
    mods := ""
    for m in parts {
        m := Trim(m)
        if (m == "Ctrl")
            mods .= "^"
        else if (m == "Shift")
            mods .= "+"
        else if (m == "Alt")
            mods .= "!"
        else if (m == "Win")
            mods .= "#"
        else if (m != "")
            return ""
    }
    return mods
}

ShortcutActionFn(id) {
    switch id {
        case "Format": return (*) => ApplyPresetToWord()
        case "Switcher": return (*) => ShowPresetSwitcher()
        case "CapTable": return (*) => ApplyCaptionFormat("tabel")
        case "CapFig": return (*) => ApplyCaptionFormat("gambar")
        case "Menu": return (*) => ShowModernConfigUI()
        default: return ""
    }
}

TryBindCombo(combo, fn) {
    try {
        Hotkey(combo, fn, "On")
        return true
    } catch {
        return false
    }
}

BindShortcuts() {
    global CurCombos
    CurCombos := Map()
    for id in ["Format", "Switcher", "CapTable", "CapFig", "Menu"] {
        disp := ""
        try {
            disp := IniRead(iniFile, "Shortcuts", id, "")
        } catch {
            disp := ""
        }
        if (disp == "")
            continue
        combo := ShortcutToCombo(disp)
        if (combo == "")
            continue
        if (TryBindCombo(combo, ShortcutActionFn(id)))
            CurCombos[id] := combo
    }
    hmods := ""
    try {
        hmods := IniRead(iniFile, "Shortcuts", "Heading", "")
    } catch {
        hmods := ""
    }
    if (hmods != "") {
        parts := StrSplit(hmods, "+")
        mods := ""
        ok := true
        for m in parts {
            m := Trim(m)
            if (m == "Ctrl")
                mods .= "^"
            else if (m == "Shift")
                mods .= "+"
            else if (m == "Alt")
                mods .= "!"
            else if (m == "Win")
                mods .= "#"
            else if (m != "")
                ok := false
        }
        if (ok && mods != "") {
            if (TryBindCombo(mods . "Right", (*) => CycleHeading(1)))
                CurCombos["HeadingNext"] := mods . "Right"
            if (TryBindCombo(mods . "Left", (*) => CycleHeading(-1)))
                CurCombos["HeadingPrev"] := mods . "Left"
        }
    }
}

; Ganti binding satu aksi. Mengembalikan true bila binding baru berhasil dipasang.
; Binding lama hanya dimatikan bila yang baru sukses.
RebindShortcut(id, display) {
    global CurCombos
    if (id == "Heading") {
        parts := StrSplit(display, "+")
        mods := ""
        for m in parts {
            m := Trim(m)
            if (m == "Ctrl")
                mods .= "^"
            else if (m == "Shift")
                mods .= "+"
            else if (m == "Alt")
                mods .= "!"
            else if (m == "Win")
                mods .= "#"
            else if (m != "")
                return false
        }
        if (mods == "")
            return false
        fnNext := (*) => CycleHeading(1)
        fnPrev := (*) => CycleHeading(-1)
        okNext := TryBindCombo(mods . "Right", fnNext)
        okPrev := TryBindCombo(mods . "Left", fnPrev)
        if (okNext && okPrev) {
            if (CurCombos.Has("HeadingNext")) {
                try {
                    Hotkey(CurCombos["HeadingNext"], "Off")
                } catch {
                }
            }
            if (CurCombos.Has("HeadingPrev")) {
                try {
                    Hotkey(CurCombos["HeadingPrev"], "Off")
                } catch {
                }
            }
            CurCombos["HeadingNext"] := mods . "Right"
            CurCombos["HeadingPrev"] := mods . "Left"
            return true
        }
        if (okNext) {
            try {
                Hotkey(mods . "Right", "Off")
            } catch {
            }
        }
        if (okPrev) {
            try {
                Hotkey(mods . "Left", "Off")
            } catch {
            }
        }
        return false
    }
    combo := ShortcutToCombo(display)
    if (combo == "")
        return false
    if (!TryBindCombo(combo, ShortcutActionFn(id)))
        return false
    if (CurCombos.Has(id)) {
        try {
            Hotkey(CurCombos[id], "Off")
        } catch {
        }
    }
    CurCombos[id] := combo
    return true
}

; Switcher preset: window mandiri berisi ui/switcher.html (piksel mockup).
; Window utama Typeset tidak disentuh sama sekali.
ShowPresetSwitcher() {
    global swGui, swWvc, swWv, swOpenTick
    if IsObject(swGui) {
        try {
            WinActivate(swGui.Hwnd)
            return
        } catch {
            swGui := "", swWvc := "", swWv := ""
        }
    }
    try {
        ExportConfigToJs()
    } catch {
    }
    swGui := Gui("+AlwaysOnTop +ToolWindow -Caption", "Select Preset")
    swGui.MarginX := 0, swGui.MarginY := 0
    swGui.BackColor := "0x0B0B0D"
    try {
        swGui.Show("w400 h470 Center")
        try WinActivate(swGui.Hwnd)
        FocusSwWebView()
        SetRoundedCorners(swGui.Hwnd)
        swWvc := WebView2.create(swGui.Hwnd)
        swWv := swWvc.CoreWebView2
        try {
            settings := swWv.Settings
            settings.AreDefaultContextMenusEnabled := false
            settings.IsStatusBarEnabled := false
        }
        swWv.Navigate("file:///" . StrReplace(A_ScriptDir . "\ui\switcher.html", "\", "/"))
        swWvc.Fill()
        try FileDelete(A_Temp . "\opencode\swfocus.log")
        FocusSwDeep()
        swGui.OnEvent("Size", (*) => SwTryFill())
        swGui.OnEvent("Close", (*) => CloseSwitcherGui("gui-close"))
        swGui.OnEvent("Escape", (*) => CloseSwitcherGui("gui-escape"))
        SetTimer(ListenSwitcherMessages, 80)
        swOpenTick := A_TickCount
        SetTimer(WatchSwitcherFocus, 200)
    } catch as err {
        try CloseSwitcherGui("open-catch")
        ShowToast("Failed to open switcher")
    }

    SwTryFill() {
        global swWvc
        if IsObject(swWvc) {
            try swWvc.Fill()
        }
    }
}


; Satu tembakan fokus keyboard ke child WebView pertama yang terverifikasi.
; Tanpa loop fallback, tanpa timer ulang (keduanya terbukti memindahkan fokus
; ke child yang salah setelah input sempat jalan).
FocusSwWebView() {
    global swGui
    if !IsObject(swGui)
        return false
    try {
        ctlList := WinGetControls(swGui.Hwnd)
        for ctl in ctlList {
            if (InStr(ctl, "Chrome_WidgetWin") == 1) {
                try ControlFocus(ctl, "ahk_id " . swGui.Hwnd)
                try {
                    if (ControlGetFocus("ahk_id " . swGui.Hwnd) == ctl)
                        return true
                } catch {
                }
            }
        }
    } catch {
    }
    return false
}

; Fokus keyboard ke descendant konten WebView terdalam + catat hasil ke log
; (%Temp%\opencode\swfocus.log) agar terverifikasi headless tanpa tebakan.
; Versi paksa: AttachThreadInput + SetForegroundWindow + SetFocus HWND langsung.
FocusSwDeep() {
    global swGui
    if !IsObject(swGui)
        return ""
    log := A_Temp . "\opencode\swfocus.log"
    try {
        fgBefore := DllCall("GetForegroundWindow", "Ptr")
        curThread := DllCall("GetCurrentThreadId", "UInt")
        fgThread := DllCall("GetWindowThreadProcessId", "Ptr", fgBefore, "Ptr", 0, "UInt")
        DllCall("AttachThreadInput", "UInt", curThread, "UInt", fgThread, "Int", true)
        DllCall("SetForegroundWindow", "Ptr", swGui.Hwnd)
        DllCall("BringWindowToTop", "Ptr", swGui.Hwnd)
        DllCall("AttachThreadInput", "UInt", curThread, "UInt", fgThread, "Int", false)
    } catch {
    }
    kids := []
    try {
        tops := WinGetControls(swGui.Hwnd)
        for ctl in tops {
            if (InStr(ctl, "Chrome_WidgetWin") == 1) {
                try {
                    kh := ControlGetHwnd(ctl, "ahk_id " . swGui.Hwnd)
                    if (kh != "")
                        kids.Push(kh)
                } catch {
                }
            }
            try {
                ch := ControlGetHwnd(ctl, "ahk_id " . swGui.Hwnd)
                if (ch != "") {
                    subs := WinGetControls("ahk_id " . ch)
                    for s in subs {
                        if (InStr(s, "Chrome_WidgetWin") == 1) {
                            try {
                                sh := ControlGetHwnd(s, "ahk_id " . ch)
                                if (sh != "")
                                    kids.Push(sh)
                            } catch {
                            }
                        }
                    }
                }
            } catch {
            }
        }
    } catch {
    }
    got := ""
    i := kids.Length
    while (i >= 1) {
        try {
            DllCall("SetFocus", "Ptr", kids[i])
            try {
                if (DllCall("GetFocus", "Ptr") == kids[i]) {
                    got := kids[i]
                    break
                }
            } catch {
            }
        } catch {
        }
        i--
    }
    try {
        fgAfter := DllCall("GetForegroundWindow", "Ptr")
        FileAppend("kids=" . kids.Length . " got=" . got . " fg=" . fgAfter . "`n", log)
    } catch {
    }
    return got
}

; Tutup switcher otomatis saat interaksi pindah ke window lain.
; Hanya jalan saat popup terbuka; masa tenggang 1 detik setelah dibuka.
WatchSwitcherFocus() {
    global swGui, swOpenTick
    if !IsObject(swGui) {
        SetTimer(WatchSwitcherFocus, 0)
        return
    }
    try {
        if (A_TickCount - swOpenTick < 1000)
            return
        fg := DllCall("GetForegroundWindow", "Ptr")
        if (fg != "" && fg != swGui.Hwnd)
            CloseSwitcherGui("focus-lost")
    } catch {
    }
}

CloseSwitcherGui(from := "unknown") {
    global swGui, swWvc, swWv
    try {
        FileAppend("close from=" . from . "`n", A_Temp . "\opencode\swfocus.log")
    } catch {
    }
    SetTimer(ListenSwitcherMessages, 0)
    SetTimer(WatchSwitcherFocus, 0)
    tempW := swWvc
    swWvc := "", swWv := ""
    if IsObject(tempW) {
        try tempW.Close()
    }
    if IsObject(swGui) {
        try swGui.Destroy()
    }
    swGui := ""
}

ListenSwitcherMessages() {
    static lastMsg := ""
    global swWv, swGui

    if !IsObject(swGui) {
        SetTimer(ListenSwitcherMessages, 0)
        return
    }

    try {
        curTitle := ""
        if IsObject(swWv) {
            try curTitle := swWv.DocumentTitle
        }
        if InStr(curTitle, "AHK_MSG:") {
            msgPart := SubStr(curTitle, InStr(curTitle, "AHK_MSG:") + 8)
            if (msgPart != lastMsg) {
                lastMsg := msgPart
                firstBrace := InStr(msgPart, "{")
                lastBrace := InStr(msgPart, "}", , -1)
                if (firstBrace && lastBrace && lastBrace >= firstBrace) {
                    dataChunk := SubStr(msgPart, firstBrace, lastBrace - firstBrace + 1)
                    ProcessWebCommand(dataChunk)
                }
            }
        }
    } catch {
    }
}

; ==========================================================
; SHORTCUT 2: Heading Cycler (dinamis, binding via INI [Shortcuts])
; ==========================================================

CycleHeading(direction) {
    try {
        maxLevel := 9
        if (maxLevel < 1)
            maxLevel := 1
        if (maxLevel > 9)
            maxLevel := 9
        wordApp := ComObjActive("Word.Application")
        sel := wordApp.Selection
        ol := 10
        try ol := sel.ParagraphFormat.OutlineLevel
        curLevel := (ol >= 1 && ol <= 9) ? ol : 0
        nextLevel := curLevel + direction
        if (nextLevel > maxLevel)
            nextLevel := maxLevel
        if (nextLevel < 0)
            nextLevel := 0
        undoStarted := BeginWordUndo(wordApp, "Typeset: Heading")
        try {
            if (nextLevel >= 1 && nextLevel <= 9)
                sel.Style := -(nextLevel + 1)
            else
                sel.Style := -1
        } finally {
            EndWordUndo(wordApp, undoStarted)
        }
        label := (nextLevel == 0) ? "Normal" : "Heading " . nextLevel
        ShowToast("Style: " . label)
    } catch as err {
        ShowToast("Failed: " . err.Message)
    }
}

; ==========================================================
; SHORTCUT 3 & 4: Caption (binding via INI [Shortcuts])
; ==========================================================

; ==========================================================
; SHORTCUT 5: Buka Modern Webview UI (binding via INI [Shortcuts])
; ==========================================================

ShowModernConfigUI() {
    global webGui, wvc, activeWv

    ; If window already exists, bring it to front
    if IsObject(webGui) {
        try {
            WinActivate(webGui.Hwnd)
            return
        } catch {
            webGui := "", wvc := "", activeWv := ""
        }
    }

    uiPath := A_ScriptDir . "\ui\index.html"
    if !FileExist(uiPath) {
        ShowToast("UI file not found: ui\index.html")
        return
    }

    ExportConfigToJs()

    ; Buat Window Native Win32 tanpa browser chrome (Fixed size, non-resizable)
    aotTop := Integer(IniRead(iniFile, "Settings", "AlwaysOnTop", "1"))
    topFlag := aotTop ? "+AlwaysOnTop " : ""
    webGui := Gui(topFlag . "-Resize -MaximizeBox", "Typeset")
    webGui.MarginX := 0, webGui.MarginY := 0
    webGui.BackColor := "0xFFFFFF"
    SetRoundedCorners(webGui.Hwnd)

    try {
        initW := 860
        initH := 640
        webGui.Show("w" . initW . " h" . initH . " Center")
        
        wvc := WebView2.create(webGui.Hwnd)
        activeWv := wvc.CoreWebView2
        
        ; Disable context menu & default accelerator keys for pure desktop app feel
        try {
            settings := activeWv.Settings
            settings.AreDefaultContextMenusEnabled := false
            settings.IsStatusBarEnabled := false
        }

        activeWv.Navigate("file:///" . StrReplace(uiPath, "\", "/"))
        wvc.Fill()

        webGui.OnEvent("Size", (g, minmax, w, h) => (minmax != -1 && IsObject(wvc)) ? TryFillWvc() : "")
        webGui.OnEvent("Close", CloseWebGui)

        SetTimer(ListenWebUiMessages, 80)
    } catch as err {
        if IsObject(wvc) {
            try wvc.Close()
        }
        try webGui.Destroy()
        webGui := "", wvc := "", activeWv := ""
        ShowToast("Failed to open Modern UI: " . err.Message)
    }

    TryFillWvc() {
        if IsObject(wvc) {
            try wvc.Fill()
        }
    }

    CloseWebGui(*) {
        global webGui, wvc, activeWv
        SetTimer(ListenWebUiMessages, 0)
        if IsObject(webGui) {
            try webGui.OnEvent("Size", (*) => "")
            try webGui.OnEvent("Close", (*) => "")
            try webGui.OnEvent("Escape", (*) => "")
        }
        tempWvc := wvc
        wvc := "", activeWv := ""
        if IsObject(tempWvc) {
            try tempWvc.Close()
        }
        if IsObject(webGui) {
            try webGui.Destroy()
        }
        webGui := ""
    }
}


JsBool(b) {
    return b ? "true" : "false"
}

UseFlagsJs(u) {
    s := "{ font: " . JsBool(u["font"])
    s .= ", size: " . JsBool(u["size"])
    s .= ", style: " . JsBool(u["style"])
    s .= ", color: " . JsBool(u["color"])
    s .= ", spacing: " . JsBool(u["spacing"])
    s .= ", align: " . JsBool(u["align"])
    s .= ", before: " . JsBool(u["before"])
    s .= ", after: " . JsBool(u["after"]) . " }"
    return s
}

CapUseJs(u) {
    s := "{ font: " . JsBool(u["font"])
    s .= ", size: " . JsBool(u["size"])
    s .= ", color: " . JsBool(u["color"])
    s .= ", align: " . JsBool(u["align"])
    s .= ", before: " . JsBool(u["before"])
    s .= ", after: " . JsBool(u["after"]) . " }"
    return s
}

ExportConfigToJs() {
    uiDir := A_ScriptDir . "\ui"
    if !DirExist(uiDir)
        DirCreate(uiDir)

    act := IniRead(iniFile, "Settings", "ActivePreset", "Laprak")
    theme := IniRead(iniFile, "Settings", "Theme", "dark")
    if (theme != "light" && theme != "dark")
        theme := "dark"
    aotJs := Integer(IniRead(iniFile, "Settings", "AlwaysOnTop", "1")) ? "true" : "false"

    js := "// Auto-generated configuration data from typeset.ini`n"
    js .= "window.initialData = {`n"
    js .= "  activePreset: `"" . act . "`",`n"
    js .= "  theme: `"" . theme . "`",`n"
    js .= "  appVersion: `"" . APP_VERSION . "`",`n"

    js .= "  shortcuts: {`n"
    scIds := ["Format", "Switcher", "CapTable", "CapFig", "Heading", "Menu"]
    scDefs := Map("Format", "Ctrl+Shift+F", "Switcher", "Win+Shift+F", "CapTable", "Ctrl+Shift+T", "CapFig", "Ctrl+Shift+G", "Heading", "Ctrl+Alt", "Menu", "Win+Shift+C")
    for id in scIds {
        v := IniRead(iniFile, "Shortcuts", id, "")
        if (v == "")
            v := scDefs[id]
        js .= "    " . id . ": `"" . v . "`",`n"
    }
    js .= "  },`n"
    js .= "  alwaysOnTop: " . aotJs . ",`n"

    js .= "  lastUsed: {`n"
    firstLU := true
    rawLU := IniRead(iniFile, "LastUsed", , "")
    Loop Parse, rawLU, "`n", "`r" {
        if (A_LoopField == "")
            continue
        lu := StrSplit(A_LoopField, "=")
        if (lu.Length >= 2) {
            if !firstLU
                js .= ",`n"
            js .= "    `"" . lu[1] . "`": `"" . lu[2] . "`""
            firstLU := false
        }
    }
    js .= "`n  },`n"

    tFont := IniRead(iniFile, "CaptionTabel", "Font", "Times New Roman")
    tSize := IniRead(iniFile, "CaptionTabel", "Size", "10")
    tAlign := IniRead(iniFile, "CaptionTabel", "Alignment", "Left")
    tBefore := IniRead(iniFile, "CaptionTabel", "SpaceBefore", "0")
    tAfter := IniRead(iniFile, "CaptionTabel", "SpaceAfter", "0")
    tColor := IniRead(iniFile, "CaptionTabel", "Color", "#000000")

    gFont := IniRead(iniFile, "CaptionGambar", "Font", "Times New Roman")
    gSize := IniRead(iniFile, "CaptionGambar", "Size", "10")
    gAlign := IniRead(iniFile, "CaptionGambar", "Alignment", "Center")
    gBefore := IniRead(iniFile, "CaptionGambar", "SpaceBefore", "0")
    gAfter := IniRead(iniFile, "CaptionGambar", "SpaceAfter", "0")
    gColor := IniRead(iniFile, "CaptionGambar", "Color", "#000000")

    js .= "  presets: {`n"

    rawPresets := IniRead(iniFile, "Presets", , "")
    Loop Parse, rawPresets, "`n", "`r" {
        if (A_LoopField == "")
            continue
        p := StrSplit(A_LoopField, "=")
        if (p.Length >= 2) {
            name := p[1]
            cfg := ParsePresetConfig(p[2])
            if IsObject(cfg) {
                rawCapT := IniRead(iniFile, "Captions_" . name, "Tabel", "")
                capT := (rawCapT != "") ? ParseCaptionConfig(rawCapT, tAlign) : { font: tFont, size: tSize, align: tAlign, before: tBefore, after: tAfter, color: tColor, use: Map("font", true, "size", true, "color", true, "align", true, "before", true, "after", true) }

                rawCapG := IniRead(iniFile, "Captions_" . name, "Gambar", "")
                capG := (rawCapG != "") ? ParseCaptionConfig(rawCapG, gAlign) : { font: gFont, size: gSize, align: gAlign, before: gBefore, after: gAfter, color: gColor, use: Map("font", true, "size", true, "color", true, "align", true, "before", true, "after", true) }

                js .= "    `"" . name . "`": {`n"
                js .= "      font: `"" . cfg.font . "`", size: `"" . cfg.size . "`", spacing: `"" . cfg.spacing . "`", before: `"" . cfg.before . "`", after: `"" . cfg.after . "`", color: `"" . cfg.color . "`", align: `"" . cfg.align . "`", style: `"" . cfg.style . "`",`n"
                js .= "      use: " . UseFlagsJs(cfg.use) . ",`n"
                js .= "      captions: {`n"
                js .= "        `"tabel`": { font: `"" . capT.font . "`", size: `"" . capT.size . "`", align: `"" . capT.align . "`", before: `"" . capT.before . "`", after: `"" . capT.after . "`", color: `"" . capT.color . "`", use: " . CapUseJs(capT.use) . " },`n"
                js .= "        `"gambar`": { font: `"" . capG.font . "`", size: `"" . capG.size . "`", align: `"" . capG.align . "`", before: `"" . capG.before . "`", after: `"" . capG.after . "`", color: `"" . capG.color . "`", use: " . CapUseJs(capG.use) . " }`n"
                js .= "      }`n"
                js .= "    },`n"
            }
        }
    }
    js .= "  },`n"

    js .= "  captions: {`n"
    js .= "    `"tabel`": { font: `"" . tFont . "`", size: `"" . tSize . "`", align: `"" . tAlign . "`", before: `"" . tBefore . "`", after: `"" . tAfter . "`", color: `"" . tColor . "`" },`n"
    js .= "    `"gambar`": { font: `"" . gFont . "`", size: `"" . gSize . "`", align: `"" . gAlign . "`", before: `"" . gBefore . "`", after: `"" . gAfter . "`", color: `"" . gColor . "`" }`n"
    js .= "  }`n};`n"

    try {
        f := FileOpen(uiDir . "\data.js", "w", "UTF-8")
        f.Write(js)
        f.Close()
    }
}

ListenWebUiMessages() {
    static lastMsg := ""
    global activeWv, webGui

    if !IsObject(webGui) {
        SetTimer(ListenWebUiMessages, 0)
        return
    }

    try {
        curTitle := ""
        if IsObject(activeWv) {
            try curTitle := activeWv.DocumentTitle
        }
        if (curTitle == "") {
            targetHwnd := WinExist("Typeset")
            if !targetHwnd {
                SetTimer(ListenWebUiMessages, 0)
                return
            }
            curTitle := WinGetTitle(targetHwnd)
        }

        if InStr(curTitle, "AHK_MSG:") {
            msgPart := SubStr(curTitle, InStr(curTitle, "AHK_MSG:") + 8)
            if (msgPart != lastMsg) {
                lastMsg := msgPart
                firstBrace := InStr(msgPart, "{")
                lastBrace := InStr(msgPart, "}", , -1)
                if (firstBrace && lastBrace && lastBrace >= firstBrace) {
                    dataChunk := SubStr(msgPart, firstBrace, lastBrace - firstBrace + 1)
                    ProcessWebCommand(dataChunk)
                }
            }
        }
    } catch {
        ; Abaikan error transisi saat dialog ditutup
    }
}

ProcessWebCommand(rawJson) {
    global webGui, wvc, CurCombos
    if RegExMatch(rawJson, '`"action`":\s*`"([^`"]+)`"', &mAct) {
        action := mAct[1]
        switch action {
            case "setActivePreset":
                if RegExMatch(rawJson, '`"name`":\s*`"([^`"]+)`"', &mName) {
                    IniWrite(mName[1], iniFile, "Settings", "ActivePreset")
                    IniWrite(A_Now, iniFile, "LastUsed", mName[1])
                    CloseSwitcherGui("setActive")
                    Notify("Active preset: " . mName[1])
                    PushPresetEvent(mName[1])
                }
            case "closeSwitcher":
                CloseSwitcherGui("ipc")
            case "savePreset":
                if RegExMatch(rawJson, '`"name`":\s*`"([^`"]+)`"', &mName) {
                    name := mName[1]
                    font := RegExMatch(rawJson, '`"font`":\s*`"([^`"]+)`"', &mF) ? mF[1] : "Times New Roman"
                    size := RegExMatch(rawJson, '`"size`":\s*`"([^`"]+)`"', &mS) ? mS[1] : "12"
                    spacing := RegExMatch(rawJson, '`"spacing`":\s*`"([^`"]+)`"', &mSp) ? mSp[1] : "1.5"
                    before := RegExMatch(rawJson, '`"before`":\s*`"([^`"]+)`"', &mBf) ? mBf[1] : "0"
                    after := RegExMatch(rawJson, '`"after`":\s*`"([^`"]+)`"', &mAf) ? mAf[1] : "0"
                    color := RegExMatch(rawJson, '`"color`":\s*`"([^`"]+)`"', &mClr) ? mClr[1] : "#000000"
                    align := RegExMatch(rawJson, '`"align`":\s*`"([^`"]+)`"', &mAl) ? mAl[1] : "Left"
                    flags := RegExMatch(rawJson, '`"flags`":\s*`"([01]{8})`"', &mFl) ? mFl[1] : "11111111"
                    style := RegExMatch(rawJson, '`"style`":\s*`"(none|b|i|bi)`"', &mSt) ? mSt[1] : "none"

                    packVal := font . "|" . size . "|" . spacing . "|" . before . "|" . after . "|" . color . "|" . align . "|" . flags . "|" . style
                    IniWrite(packVal, iniFile, "Presets", name)

                    ; If captions object is included in payload, save them
                    if InStr(rawJson, '`"captions`"') {
                        tflags := RegExMatch(rawJson, '`"tflags`":\s*`"([01]{6})`"', &mTf) ? mTf[1] : "111111"
                        gflags := RegExMatch(rawJson, '`"gflags`":\s*`"([01]{6})`"', &mGf) ? mGf[1] : "111111"
                        if RegExMatch(rawJson, '`"tabel`":\s*\{([^}]+)\}', &mTab) {
                            tChunk := mTab[1]
                            tF := RegExMatch(tChunk, '`"font`":\s*`"([^`"]+)`"', &m) ? m[1] : "Times New Roman"
                            tS := RegExMatch(tChunk, '`"size`":\s*`"([^`"]+)`"', &m) ? m[1] : "10"
                            tA := RegExMatch(tChunk, '`"align`":\s*`"([^`"]+)`"', &m) ? m[1] : "Left"
                            tBf := RegExMatch(tChunk, '`"before`":\s*`"([^`"]+)`"', &m) ? m[1] : "0"
                            tAf := RegExMatch(tChunk, '`"after`":\s*`"([^`"]+)`"', &m) ? m[1] : "0"
                            tC := RegExMatch(tChunk, '`"color`":\s*`"([^`"]+)`"', &m) ? m[1] : "#000000"
                            packT := tF . "|" . tS . "|" . tA . "|" . tBf . "|" . tAf . "|" . tC . "|" . tflags
                            IniWrite(packT, iniFile, "Captions_" . name, "Tabel")
                            if (IniRead(iniFile, "Settings", "ActivePreset", "") == name) {
                                IniWrite(tF, iniFile, "CaptionTabel", "Font")
                                IniWrite(tS, iniFile, "CaptionTabel", "Size")
                                IniWrite(tA, iniFile, "CaptionTabel", "Alignment")
                                IniWrite(tBf, iniFile, "CaptionTabel", "SpaceBefore")
                                IniWrite(tAf, iniFile, "CaptionTabel", "SpaceAfter")
                                IniWrite(tC, iniFile, "CaptionTabel", "Color")
                            }
                        }
                        if RegExMatch(rawJson, '`"gambar`":\s*\{([^}]+)\}', &mGam) {
                            gChunk := mGam[1]
                            gF := RegExMatch(gChunk, '`"font`":\s*`"([^`"]+)`"', &m) ? m[1] : "Times New Roman"
                            gS := RegExMatch(gChunk, '`"size`":\s*`"([^`"]+)`"', &m) ? m[1] : "10"
                            gA := RegExMatch(gChunk, '`"align`":\s*`"([^`"]+)`"', &m) ? m[1] : "Center"
                            gBf := RegExMatch(gChunk, '`"before`":\s*`"([^`"]+)`"', &m) ? m[1] : "0"
                            gAf := RegExMatch(gChunk, '`"after`":\s*`"([^`"]+)`"', &m) ? m[1] : "0"
                            gC := RegExMatch(gChunk, '`"color`":\s*`"([^`"]+)`"', &m) ? m[1] : "#000000"
                            packG := gF . "|" . gS . "|" . gA . "|" . gBf . "|" . gAf . "|" . gC . "|" . gflags
                            IniWrite(packG, iniFile, "Captions_" . name, "Gambar")
                            if (IniRead(iniFile, "Settings", "ActivePreset", "") == name) {
                                IniWrite(gF, iniFile, "CaptionGambar", "Font")
                                IniWrite(gS, iniFile, "CaptionGambar", "Size")
                                IniWrite(gA, iniFile, "CaptionGambar", "Alignment")
                                IniWrite(gBf, iniFile, "CaptionGambar", "SpaceBefore")
                                IniWrite(gAf, iniFile, "CaptionGambar", "SpaceAfter")
                                IniWrite(gC, iniFile, "CaptionGambar", "Color")
                            }
                        }
                    } else if (IniRead(iniFile, "Captions_" . name, "Tabel", "") == "") {
                        actPreset := IniRead(iniFile, "Settings", "ActivePreset", "Laprak")
                        curT := IniRead(iniFile, "Captions_" . actPreset, "Tabel", "")
                        curG := IniRead(iniFile, "Captions_" . actPreset, "Gambar", "")
                        if (curT != "")
                            IniWrite(curT, iniFile, "Captions_" . name, "Tabel")
                        if (curG != "")
                            IniWrite(curG, iniFile, "Captions_" . name, "Gambar")
                    }
                    ExportConfigToJs()
                }
            case "setTheme":
                th := RegExMatch(rawJson, '`"theme`":\s*`"([^`"]+)`"', &mT) ? mT[1] : ""
                if (th == "light" || th == "dark")
                    IniWrite(th, iniFile, "Settings", "Theme")
            case "setAlwaysOnTop":
                aot := InStr(rawJson, '`"value`":true') ? 1 : 0
                IniWrite(aot, iniFile, "Settings", "AlwaysOnTop")
                if IsObject(webGui) {
                    try WinSetAlwaysOnTop(aot, webGui.Hwnd)
                }
            case "resetConfig":
                try {
                    FileDelete(iniFile)
                } catch {
                }
                Reload()
            case "setShortcut":
                sid := RegExMatch(rawJson, '`"id`":\s*`"([^`"]+)`"', &mId) ? mId[1] : ""
                disp := RegExMatch(rawJson, '`"display`":\s*`"([^`"]+)`"', &mD) ? mD[1] : ""
                if (sid == "Heading") {
                    mods := HeadingModsToCombo(disp)
                    if (mods == "") {
                        Notify("Invalid heading shortcut")
                    } else {
                        dupH := false
                        for k, v in CurCombos {
                            if (k != "HeadingNext" && k != "HeadingPrev" && (v == mods . "Right" || v == mods . "Left"))
                                dupH := true
                        }
                        if (dupH) {
                            Notify("Shortcut already in use")
                        } else if (RebindShortcut("Heading", disp)) {
                            IniWrite(disp, iniFile, "Shortcuts", "Heading")
                        } else {
                            Notify("Failed to bind shortcut")
                        }
                    }
                } else if (sid == "Format" || sid == "Switcher" || sid == "CapTable" || sid == "CapFig" || sid == "Menu") {
                    if (disp == "") {
                        Notify("Empty shortcut")
                    } else {
                        combo := ShortcutToCombo(disp)
                        dup := false
                        if (combo != "") {
                            for k, v in CurCombos {
                                if (k != sid && v == combo)
                                    dup := true
                            }
                        }
                        if (combo == "" || dup) {
                            Notify("Invalid shortcut / already in use")
                        } else if (RebindShortcut(sid, disp)) {
                            IniWrite(disp, iniFile, "Shortcuts", sid)
                        } else {
                            Notify("Failed to bind shortcut")
                        }
                    }
                }
            case "deletePreset":
                if RegExMatch(rawJson, '`"name`":\s*`"([^`"]+)`"', &mName) {
                    IniDelete(iniFile, "Presets", mName[1])
                    IniDelete(iniFile, "Captions_" . mName[1])
                    IniDelete(iniFile, "LastUsed", mName[1])
                }
            case "renamePreset":
                if RegExMatch(rawJson, '`"old`":\s*`"([^`"]+)`"', &mOld) && RegExMatch(rawJson, '`"new`":\s*`"([^`"]+)`"', &mNew) {
                    oldName := mOld[1]
                    newName := mNew[1]
                    if (oldName == "" || newName == "") {
                        Notify("Invalid preset name")
                    } else if (oldName == newName) {
                        ; Exact no-op
                    } else {
                        oldVal := IniRead(iniFile, "Presets", oldName, "")
                        if (oldVal == "") {
                            Notify("Preset not found: " . oldName)
                        } else if (StrLower(newName) != StrLower(oldName) && IniRead(iniFile, "Presets", newName, "") != "") {
                            Notify("Preset name already exists: " . newName)
                        } else {
                            IniDelete(iniFile, "Presets", oldName)
                            IniWrite(oldVal, iniFile, "Presets", newName)
                            oldSec := "Captions_" . oldName
                            newSec := "Captions_" . newName
                            for key in ["Tabel", "Gambar"] {
                                capVal := IniRead(iniFile, oldSec, key, "")
                                if (capVal != "")
                                    IniWrite(capVal, iniFile, newSec, key)
                            }
                            if (StrLower(newSec) != StrLower(oldSec))
                                IniDelete(iniFile, oldSec)
                            if (IniRead(iniFile, "Settings", "ActivePreset", "") = oldName)
                                IniWrite(newName, iniFile, "Settings", "ActivePreset")
                            luVal := IniRead(iniFile, "LastUsed", oldName, "")
                            if (luVal != "") {
                                if (StrLower(newName) != StrLower(oldName))
                                    IniDelete(iniFile, "LastUsed", oldName)
                                IniWrite(luVal, iniFile, "LastUsed", newName)
                            }
                        }
                    }
                }
            case "startUpdate":
                updUrl := RegExMatch(rawJson, '`"url`":\s*`"([^`"]+)`"', &mU) ? mU[1] : ""
                updVer := RegExMatch(rawJson, '`"version`":\s*`"([^`"]+)`"', &mV) ? mV[1] : ""
                updSize := RegExMatch(rawJson, '`"size`":\s*`"?(\d+)`"?', &mS) ? Integer(mS[1]) : 0
                if (updUrl != "" && updVer != "")
                    StartUpdateDownload(updUrl, updVer, updSize)
            case "cancelUpdate":
                CancelUpdateDownload()
            case "openChangelog":
                clUrl := RegExMatch(rawJson, '`"url`":\s*`"([^`"]+)`"', &mCl) ? mCl[1] : ""
                if (clUrl == "" || !(InStr(clUrl, "https://github.com/rfibyzan/typeset") == 1))
                    Notify("Invalid changelog link")
                else {
                    try {
                        Run('"' . clUrl . '"')
                    } catch {
                        Notify("Could not open browser")
                    }
                }
        }
    }
}

JsEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "")
    return s
}

PushPresetEvent(name) {
    global activeWv
    if !IsObject(activeWv)
        return
    try {
        activeWv.ExecuteScriptAsync("window.onExternalPreset(`"" . JsEscape(name) . "`")")
    }
}

PushUpdateEvent(jsonBody) {
    global activeWv
    if !IsObject(activeWv)
        return
    try {
        activeWv.ExecuteScriptAsync("window.onUpdateEvent(" . jsonBody . ")")
    }
}

StartUpdateDownload(url, ver, total := 0) {
    global updateBusy, updateUrl, updateVer, updateFile, updateTotal, updateInstalling, updateName, updateLastSize, updateStall
    if (updateBusy)
        return
    if (url == "" || ver == "")
        return
    if (!InStr(url, "https://"))
        return
    updateBusy := true
    updateInstalling := false
    updateUrl := url
    updateVer := ver
    updateTotal := total
    updateLastSize := 0
    updateStall := 0
    tmpDir := A_Temp . "\Typeset_update"
    try DirCreate(tmpDir)
    updateName := "Typeset-" . ver . ".zip"
    updateFile := tmpDir . "\" . updateName
    try {
        if FileExist(updateFile)
            FileDelete(updateFile)
    }
    cmd := 'curl.exe -L --fail --silent --show-error -o "' . updateFile . '" "' . url . '"'
    try {
        Run(cmd, , "Hide")
    } catch {
        updateBusy := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    SetTimer(PollUpdateProgress, 400)
}

PollUpdateProgress() {
    global updateBusy, updateFile, updateTotal, updateInstalling, updateLastSize, updateStall
    if (!updateBusy || updateInstalling)
        return
    got := 0
    try {
        if FileExist(updateFile)
            got := FileGetSize(updateFile)
    } catch {
        got := 0
    }
    if (got == updateLastSize)
        updateStall += 1
    else {
        updateStall := 0
        updateLastSize := got
    }
    done := false
    if (updateTotal > 0 && got >= updateTotal)
        done := true
    else if (updateStall >= 12 && got > 0)
        done := true
    if (done) {
        SetTimer(PollUpdateProgress, 0)
        PushUpdateEvent('{"phase":"installing"}')
        FinishDownloadAndInstall()
        return
    }
    if (updateStall >= 150) {
        SetTimer(PollUpdateProgress, 0)
        updateBusy := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    if (updateTotal > 0 && got > 0) {
        pct := Round(got * 100 / updateTotal)
        if (pct > 99)
            pct := 99
        PushUpdateEvent('{"phase":"progress","pct":' . pct . '}')
    } else {
        PushUpdateEvent('{"phase":"progress","pct":-1}')
    }
}

CancelUpdateDownload() {
    global updateBusy, updateFile, updateTotal, updateInstalling, updateName
    if (!updateBusy || updateInstalling)
        return
    try {
        wmi := ComObjGet("winmgmts:")
        q := wmi.ExecQuery("SELECT ProcessId,CommandLine FROM Win32_Process WHERE Name='curl.exe'")
        for p in q {
            try {
                cl := p.CommandLine
                if (cl != "" && updateName != "" && InStr(cl, updateName))
                    ProcessClose(p.ProcessId)
            } catch {
            }
        }
    } catch {
    }
    SetTimer(PollUpdateProgress, 0)
    try {
        if (updateFile != "" && FileExist(updateFile))
            FileDelete(updateFile)
    } catch {
    }
    updateBusy := false
    updateFile := ""
    updateTotal := 0
    PushUpdateEvent('{"phase":"cancelled"}')
}

FinishDownloadAndInstall() {
    global updateBusy, updateFile, updateVer, updateInstalling
    updateInstalling := true
    tmpDir := A_Temp . "\Typeset_update"
    stageDir := tmpDir . "\stage-" . updateVer
    try {
        if DirExist(stageDir)
            DirDelete(stageDir, true)
        DirCreate(stageDir)
    } catch {
        updateBusy := false
        updateInstalling := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    psCmd := "powershell -NoProfile -NonInteractive -Command `"Expand-Archive -Force '" . updateFile . "' '" . stageDir . "'`""
    try {
        RunWait(psCmd, , "Hide")
    } catch {
        updateBusy := false
        updateInstalling := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    srcDir := stageDir
    try {
        Loop Files, stageDir . "\*", "D" {
            inner := A_LoopFileFullPath
            if (FileExist(inner . "\doc-formatter.ahk") || FileExist(inner . "\Typeset.exe") || DirExist(inner . "\ui")) {
                srcDir := inner
                break
            }
        }
    } catch {
    }
    if (!FileExist(srcDir . "\doc-formatter.ahk") && !FileExist(srcDir . "\Typeset.exe") && !DirExist(srcDir . "\ui")) {
        updateBusy := false
        updateInstalling := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    installDir := A_ScriptDir
    if (A_IsCompiled) {
        runExe := A_ScriptFullPath
        runArg := ""
    } else {
        runExe := A_AhkPath
        runArg := A_ScriptFullPath
    }
    batFile := tmpDir . "\update_apply.bat"
    bat := "@echo off`r`n"
    bat .= "setlocal`r`n"
    bat .= 'set "WATCH_PID=' . ProcessExist() . '"`r`n'
    bat .= 'set "SRC=' . srcDir . '"`r`n'
    bat .= 'set "DST=' . installDir . '"`r`n'
    bat .= 'set "RUNEXE=' . runExe . '"`r`n'
    bat .= 'set "RUNARG=' . runArg . '"`r`n'
    bat .= ":waitloop`r`n"
    bat .= 'tasklist /FI "PID eq %WATCH_PID%" 2>nul | find "%WATCH_PID%" >nul`r`n'
    bat .= "if not errorlevel 1 (timeout /t 1 /nobreak >nul & goto waitloop)`r`n"
    bat .= 'robocopy "%SRC%" "%DST%" /E /XF *.ini /NFL /NDL /NJH /NJS >nul 2>&1`r`n'
    bat .= 'if "%RUNARG%"=="" (start "" "%RUNEXE%") else (start "" "%RUNEXE%" "%RUNARG%")`r`n'
    bat .= '(goto) 2>nul & del "%~f0"`r`n'
    try {
        f := FileOpen(batFile, "w", "CP0")
        f.Write(bat)
        f.Close()
    } catch {
        updateBusy := false
        updateInstalling := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    try {
        Run('"' . batFile . '"', , "Hide")
    } catch {
        updateBusy := false
        updateInstalling := false
        PushUpdateEvent('{"phase":"failed"}')
        return
    }
    Sleep(600)
    ExitApp()
}

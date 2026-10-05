#Requires AutoHotkey v2.0
#Warn Unreachable, Off
#Warn VarUnset, Off
myGui:=Gui("","Cycle Counter") ; makes a GUI
myGui.Add("Edit","r20 w200 vQuery","") ; Creates our left-most input box
	myGui["Query"].OnEvent("Change",updateAnswer) ; auto-processes it as we paste in there
myGui.Add("Checkbox","Checked vAuto","&Auto-Submit") ; a way to disable auto-processing
	myGui["Auto"].OnEvent("Click",updateAuto) ; take action as we toggle the checkbox
myGui.Add("Button","vSub x+44 WP HP+3","&Submit") ; manual submit button to use when auto-processing is disabled
	myGui["Sub"].OnEvent("Click",updateAnswer2) ; take action as we click the button
myGui.Add("Text","ys r2 w200 Section vCycles","Cycles") ; a text label which we'll put our cycle information in
myGui.Add("Text","w200 vBytes","Bytes") ; a text label which we'll put our bytes information in
;myGui.SetFont("q5","Courier") ; prior to learning about tabstops on the next control, this was set to be a mono-width font to allow manipulating said tabs to make nice columns
mygui.Add("Edit","r15 w640 y+12 t24 t60 t82 t104 t130 t142 t154 t166 t178 t190 vWork","") ; this is where our results go that shows our work in identifying opcodes for bytes/cycles. The tN all represent tab stops which give us our nice columns.
;myGui.SetFont("q5","Verdana") ; prior to learning about tabstops on the previous control, this was to restore a default font that's nicer to read
myGui.Add("Checkbox","vflags","&Flags In Result?") ; the option to show flags in our results. Most people wouldn't need this, but it might come in handy if you are debugging and not getting the results you expect for conditional routines. However, because this script does not dig into the function as requested by CALL, etc. if the flags get updated inside that function, we would not know about it.
myGui.Add("Text","ys w200 Section","Ignored:") ; A label to let the human know what the box below is for
;myGui.SetFont("q5","Courier") ; again the idea about mono-width font was here, wanted some symmetry even if this wouldn't use tab stops
myGui.Add("Edit","r16 w280 vIgn y+39","") ; shows our ignored text in the right most box
;myGui.Add("Edit","r16 w140 vRomCheck ys+54","") ; debugging purposes, a fourth box was added that would show the bytes as expected in rom allowing one to use grep against a text file representation of the rom to make sure the code as intepreted actually existed in the rom. A sanity check against what the assembler made.
myGui.OnEvent("Close", myGui_Close) ; for the EXE, we wanted it so if a user closes the window, it closes the script
myGui.Show() ; show the GUI
myGui_Close(thisGui) { ; closes the executable if this window gets closed; same in the script itself actually.
	ExitApp
}

;this is a regex pattern for notepad++ copypasting out of source https://gbdev.io/gb-opcodes/optables/ to format it in these arrays
;input"		^(.+?) (\d)  ((\d|/)+?) (.) (.) (.) (.) ?$ but manually adjust high and low cycles
;replace:		bytes["$1"]:=[$2,$3,$3,"$5","$6","$7","$8"]
;you'll notice $3 is used twice, which repeats the min/max of t-states. For opcodes that do have differences due to conditions, they would format through as e.g. `12/8,12/8` and I just manually regexed "/.*?/" (maybe the / needed \/ escaping) to replace with a comma, resulting in `12,8`

; bytes["mnemonic"]:=["bytes","t-states max","t-states min","z flag","n flag","h flag","c flag","opcode"]

global rememberfolder:="" ; AHK will open a system default folder to start with, however, we'll update it based on the last opened folder during this session; no config file to cache this between sessions

bytes:=Map() ; the key to this map/array is the opcode on the left hand side of the :=. On the right is our properties as values we'd be interested in.
bytes["nop"]:=[1,4,4,"-","-","-","-","00"]
bytes["ld bc, n16"]:=[3,12,12,"-","-","-","-","01"]
bytes["ld [bc], a"]:=[1,8,8,"-","-","-","-","02"]
bytes["inc bc"]:=[1,8,8,"-","-","-","-","03"]
bytes["inc b"]:=[1,4,4,"Z","0","H","-","04"]
bytes["dec b"]:=[1,4,4,"Z","1","H","-","05"]
bytes["ld b, n8"]:=[2,8,8,"-","-","-","-","06"]
bytes["rlca"]:=[1,4,4,"0","0","0","C","07"]
bytes["ld [a16], sp"]:=[3,20,20,"-","-","-","-","08"]
bytes["add hl, bc"]:=[1,8,8,"-","0","H","C","09"]
bytes["ld a, [bc]"]:=[1,8,8,"-","-","-","-","0a"]
bytes["dec bc"]:=[1,8,8,"-","-","-","-","0b"]
bytes["inc c"]:=[1,4,4,"Z","0","H","-","0c"]
bytes["dec c"]:=[1,4,4,"Z","1","H","-","0d"]
bytes["ld c, n8"]:=[2,8,8,"-","-","-","-","0e"]
bytes["rrca"]:=[1,4,4,"0","0","0","C","0f"]

bytes["stop n8"]:=[2,4,4,"-","-","-","-","10"]
bytes["ld de, n16"]:=[3,12,12,"-","-","-","-","11"]
bytes["ld [de], a"]:=[1,8,8,"-","-","-","-","12"]
bytes["inc de"]:=[1,8,8,"-","-","-","-","13"]
bytes["inc d"]:=[1,4,4,"Z","0","H","-","14"]
bytes["dec d"]:=[1,4,4,"Z","1","H","-","15"]
bytes["ld d, n8"]:=[2,8,8,"-","-","-","-","16"]
bytes["rla"]:=[1,4,4,"0","0","0","C","17"]
bytes["jr e8"]:=[2,12,12,"-","-","-","-","18"]
bytes["add hl, de"]:=[1,8,8,"-","0","H","C","19"]
bytes["ld a, [de]"]:=[1,8,8,"-","-","-","-","1a"]
bytes["dec de"]:=[1,8,8,"-","-","-","-","1b"]
bytes["inc e"]:=[1,4,4,"Z","0","H","-","1c"]
bytes["dec e"]:=[1,4,4,"Z","1","H","-","1d"]
bytes["ld e, n8"]:=[2,8,8,"-","-","-","-","1e"]
bytes["rra"]:=[1,4,4,"0","0","0","C","1f"]

bytes["jr nz, e8"]:=[2,12,8,"-","-","-","-","20"]
bytes["ld hl, n16"]:=[3,12,12,"-","-","-","-","21"]
bytes["ld [hl+], a"]:=[1,8,8,"-","-","-","-","22"]
bytes["inc hl"]:=[1,8,8,"-","-","-","-","23"]
bytes["inc h"]:=[1,4,4,"Z","0","H","-","24"]
bytes["dec h"]:=[1,4,4,"Z","1","H","-","25"]
bytes["ld h, n8"]:=[2,8,8,"-","-","-","-","26"]
bytes["daa"]:=[1,4,4,"Z","-","0","C","27"]
bytes["jr z, e8"]:=[2,12,8,"-","-","-","-","28"]
bytes["add hl, hl"]:=[1,8,8,"-","0","H","C","29"]
bytes["ld a, [hl+]"]:=[1,8,8,"-","-","-","-","2a"]
bytes["dec hl"]:=[1,8,8,"-","-","-","-","2b"]
bytes["inc l"]:=[1,4,4,"Z","0","H","-","2c"]
bytes["dec l"]:=[1,4,4,"Z","1","H","-","2d"]
bytes["ld l, n8"]:=[2,8,8,"-","-","-","-","2e"]
bytes["cpl"]:=[1,4,4,"-","1","1","-","2f"]

bytes["jr nc, e8"]:=[2,12,8,"-","-","-","-","30"]
bytes["ld sp, n16"]:=[3,12,12,"-","-","-","-","31"]
bytes["ld [hl-], a"]:=[1,8,8,"-","-","-","-","32"]
bytes["inc sp"]:=[1,8,8,"-","-","-","-","33"]
bytes["inc [hl]"]:=[1,12,12,"Z","0","H","-","34"]
bytes["dec [hl]"]:=[1,12,12,"Z","1","H","-","35"]
bytes["ld [hl], n8"]:=[2,12,12,"-","-","-","-","36"]
bytes["scf"]:=[1,4,4,"-","0","0","1","37"]
bytes["jr c, e8"]:=[2,12,8,"-","-","-","-","38"]
bytes["add hl, sp"]:=[1,8,8,"-","0","H","C","39"]
bytes["ld a, [hl-]"]:=[1,8,8,"-","-","-","-","3a"]
bytes["dec sp"]:=[1,8,8,"-","-","-","-","3b"]
bytes["inc a"]:=[1,4,4,"Z","0","H","-","3c"]
bytes["dec a"]:=[1,4,4,"Z","1","H","-","3d"]
bytes["ld a, n8"]:=[2,8,8,"-","-","-","-","3e"]
bytes["ccf"]:=[1,4,4,"-","0","0","C","3f"]

bytes["ld b, b"]:=[1,4,4,"-","-","-","-","40"]
bytes["ld b, c"]:=[1,4,4,"-","-","-","-","41"]
bytes["ld b, d"]:=[1,4,4,"-","-","-","-","42"]
bytes["ld b, e"]:=[1,4,4,"-","-","-","-","43"]
bytes["ld b, h"]:=[1,4,4,"-","-","-","-","44"]
bytes["ld b, l"]:=[1,4,4,"-","-","-","-","45"]
bytes["ld b, [hl]"]:=[1,8,8,"-","-","-","-","46"]
bytes["ld b, a"]:=[1,4,4,"-","-","-","-","47"]
bytes["ld c, b"]:=[1,4,4,"-","-","-","-","48"]
bytes["ld c, c"]:=[1,4,4,"-","-","-","-","49"]
bytes["ld c, d"]:=[1,4,4,"-","-","-","-","4a"]
bytes["ld c, e"]:=[1,4,4,"-","-","-","-","4b"]
bytes["ld c, h"]:=[1,4,4,"-","-","-","-","4c"]
bytes["ld c, l"]:=[1,4,4,"-","-","-","-","4d"]
bytes["ld c, [hl]"]:=[1,8,8,"-","-","-","-","4e"]
bytes["ld c, a"]:=[1,4,4,"-","-","-","-","4f"]

bytes["ld d, b"]:=[1,4,4,"-","-","-","-","50"]
bytes["ld d, c"]:=[1,4,4,"-","-","-","-","51"]
bytes["ld d, d"]:=[1,4,4,"-","-","-","-","52"]
bytes["ld d, e"]:=[1,4,4,"-","-","-","-","53"]
bytes["ld d, h"]:=[1,4,4,"-","-","-","-","54"]
bytes["ld d, l"]:=[1,4,4,"-","-","-","-","55"]
bytes["ld d, [hl]"]:=[1,8,8,"-","-","-","-","56"]
bytes["ld d, a"]:=[1,4,4,"-","-","-","-","57"]
bytes["ld e, b"]:=[1,4,4,"-","-","-","-","58"]
bytes["ld e, c"]:=[1,4,4,"-","-","-","-","59"]
bytes["ld e, d"]:=[1,4,4,"-","-","-","-","5a"]
bytes["ld e, e"]:=[1,4,4,"-","-","-","-","5b"]
bytes["ld e, h"]:=[1,4,4,"-","-","-","-","5c"]
bytes["ld e, l"]:=[1,4,4,"-","-","-","-","5d"]
bytes["ld e, [hl]"]:=[1,8,8,"-","-","-","-","5e"]
bytes["ld e, a"]:=[1,4,4,"-","-","-","-","5f"]

bytes["ld h, b"]:=[1,4,4,"-","-","-","-","60"]
bytes["ld h, c"]:=[1,4,4,"-","-","-","-","61"]
bytes["ld h, d"]:=[1,4,4,"-","-","-","-","62"]
bytes["ld h, e"]:=[1,4,4,"-","-","-","-","63"]
bytes["ld h, h"]:=[1,4,4,"-","-","-","-","64"]
bytes["ld h, l"]:=[1,4,4,"-","-","-","-","65"]
bytes["ld h, [hl]"]:=[1,8,8,"-","-","-","-","66"]
bytes["ld h, a"]:=[1,4,4,"-","-","-","-","67"]
bytes["ld l, b"]:=[1,4,4,"-","-","-","-","68"]
bytes["ld l, c"]:=[1,4,4,"-","-","-","-","69"]
bytes["ld l, d"]:=[1,4,4,"-","-","-","-","6a"]
bytes["ld l, e"]:=[1,4,4,"-","-","-","-","6b"]
bytes["ld l, h"]:=[1,4,4,"-","-","-","-","6c"]
bytes["ld l, l"]:=[1,4,4,"-","-","-","-","6d"]
bytes["ld l, [hl]"]:=[1,8,8,"-","-","-","-","6e"]
bytes["ld l, a"]:=[1,4,4,"-","-","-","-","6f"]

bytes["ld [hl], b"]:=[1,8,8,"-","-","-","-","70"]
bytes["ld [hl], c"]:=[1,8,8,"-","-","-","-","71"]
bytes["ld [hl], d"]:=[1,8,8,"-","-","-","-","72"]
bytes["ld [hl], e"]:=[1,8,8,"-","-","-","-","73"]
bytes["ld [hl], h"]:=[1,8,8,"-","-","-","-","74"]
bytes["ld [hl], l"]:=[1,8,8,"-","-","-","-","75"]
bytes["halt"]:=[1,4,4,"-","-","-","-","76"]
bytes["ld [hl], a"]:=[1,8,8,"-","-","-","-","77"]
bytes["ld a, b"]:=[1,4,4,"-","-","-","-","78"]
bytes["ld a, c"]:=[1,4,4,"-","-","-","-","79"]
bytes["ld a, d"]:=[1,4,4,"-","-","-","-","7a"]
bytes["ld a, e"]:=[1,4,4,"-","-","-","-","7b"]
bytes["ld a, h"]:=[1,4,4,"-","-","-","-","7c"]
bytes["ld a, l"]:=[1,4,4,"-","-","-","-","7d"]
bytes["ld a, [hl]"]:=[1,8,8,"-","-","-","-","7e"]
bytes["ld a, a"]:=[1,4,4,"-","-","-","-","7f"]

bytes["add a, b"]:=[1,4,4,"Z","0","H","C","80"]
bytes["add a, c"]:=[1,4,4,"Z","0","H","C","81"]
bytes["add a, d"]:=[1,4,4,"Z","0","H","C","82"]
bytes["add a, e"]:=[1,4,4,"Z","0","H","C","83"]
bytes["add a, h"]:=[1,4,4,"Z","0","H","C","84"]
bytes["add a, l"]:=[1,4,4,"Z","0","H","C","85"]
bytes["add a, [hl]"]:=[1,8,8,"Z","0","H","C","86"]
bytes["add a, a"]:=[1,4,4,"Z","0","H","C","87"]
bytes["adc a, b"]:=[1,4,4,"Z","0","H","C","88"]
bytes["adc a, c"]:=[1,4,4,"Z","0","H","C","89"]
bytes["adc a, d"]:=[1,4,4,"Z","0","H","C","8a"]
bytes["adc a, e"]:=[1,4,4,"Z","0","H","C","8b"]
bytes["adc a, h"]:=[1,4,4,"Z","0","H","C","8c"]
bytes["adc a, l"]:=[1,4,4,"Z","0","H","C","8d"]
bytes["adc a, [hl]"]:=[1,8,8,"Z","0","H","C","8e"]
bytes["adc a, a"]:=[1,4,4,"Z","0","H","C","8f"]

bytes["sub a, b"]:=[1,4,4,"Z","1","H","C","90"]
bytes["sub a, c"]:=[1,4,4,"Z","1","H","C","91"]
bytes["sub a, d"]:=[1,4,4,"Z","1","H","C","92"]
bytes["sub a, e"]:=[1,4,4,"Z","1","H","C","93"]
bytes["sub a, h"]:=[1,4,4,"Z","1","H","C","94"]
bytes["sub a, l"]:=[1,4,4,"Z","1","H","C","95"]
bytes["sub a, [hl]"]:=[1,8,8,"Z","1","H","C","96"]
bytes["sub a, a"]:=[1,4,4,"1","1","0","0","97"]
bytes["sbc a, b"]:=[1,4,4,"Z","1","H","C","98"]
bytes["sbc a, c"]:=[1,4,4,"Z","1","H","C","99"]
bytes["sbc a, d"]:=[1,4,4,"Z","1","H","C","9a"]
bytes["sbc a, e"]:=[1,4,4,"Z","1","H","C","9b"]
bytes["sbc a, h"]:=[1,4,4,"Z","1","H","C","9c"]
bytes["sbc a, l"]:=[1,4,4,"Z","1","H","C","9d"]
bytes["sbc a, [hl]"]:=[1,8,8,"Z","1","H","C","9e"]
bytes["sbc a, a"]:=[1,4,4,"Z","1","H","-","9f"]

bytes["and a, b"]:=[1,4,4,"Z","0","1","0","a0"]
bytes["and a, c"]:=[1,4,4,"Z","0","1","0","a1"]
bytes["and a, d"]:=[1,4,4,"Z","0","1","0","a2"]
bytes["and a, e"]:=[1,4,4,"Z","0","1","0","a3"]
bytes["and a, h"]:=[1,4,4,"Z","0","1","0","a4"]
bytes["and a, l"]:=[1,4,4,"Z","0","1","0","a5"]
bytes["and a, [hl]"]:=[1,8,8,"Z","0","1","0","a6"]
bytes["and a, a"]:=[1,4,4,"Z","0","1","0","a7"]
bytes["xor a, b"]:=[1,4,4,"Z","0","0","0","a8"]
bytes["xor a, c"]:=[1,4,4,"Z","0","0","0","a9"]
bytes["xor a, d"]:=[1,4,4,"Z","0","0","0","aa"]
bytes["xor a, e"]:=[1,4,4,"Z","0","0","0","ab"]
bytes["xor a, h"]:=[1,4,4,"Z","0","0","0","ac"]
bytes["xor a, l"]:=[1,4,4,"Z","0","0","0","ad"]
bytes["xor a, [hl]"]:=[1,8,8,"Z","0","0","0","ae"]
bytes["xor a, a"]:=[1,4,4,"1","0","0","0","af"]

bytes["or a, b"]:=[1,4,4,"Z","0","0","0","b0"]
bytes["or a, c"]:=[1,4,4,"Z","0","0","0","b1"]
bytes["or a, d"]:=[1,4,4,"Z","0","0","0","b2"]
bytes["or a, e"]:=[1,4,4,"Z","0","0","0","b3"]
bytes["or a, h"]:=[1,4,4,"Z","0","0","0","b4"]
bytes["or a, l"]:=[1,4,4,"Z","0","0","0","b5"]
bytes["or a, [hl]"]:=[1,8,8,"Z","0","0","0","b6"]
bytes["or a, a"]:=[1,4,4,"Z","0","0","0","b7"]
bytes["cp a, b"]:=[1,4,4,"Z","1","H","C","b8"]
bytes["cp a, c"]:=[1,4,4,"Z","1","H","C","b9"]
bytes["cp a, d"]:=[1,4,4,"Z","1","H","C","ba"]
bytes["cp a, e"]:=[1,4,4,"Z","1","H","C","bb"]
bytes["cp a, h"]:=[1,4,4,"Z","1","H","C","bc"]
bytes["cp a, l"]:=[1,4,4,"Z","1","H","C","bd"]
bytes["cp a, [hl]"]:=[1,8,8,"Z","1","H","C","be"]
bytes["cp a, a"]:=[1,4,4,"1","1","0","0","bf"]

bytes["ret nz"]:=[1,20,8,"-","-","-","-","c0"]
bytes["pop bc"]:=[1,12,12,"-","-","-","-","c1"]
bytes["jp nz, a16"]:=[3,16,12,"-","-","-","-","c2"]
bytes["jp a16"]:=[3,16,16,"-","-","-","-","c3"]
bytes["call nz, a16"]:=[3,24,12,"-","-","-","-","c4"]
bytes["push bc"]:=[1,16,16,"-","-","-","-","c5"]
bytes["add a, n8"]:=[2,8,8,"Z","0","H","C","c6"]
bytes["rst $00"]:=[1,16,16,"-","-","-","-","c7"]
bytes["ret z"]:=[1,20,8,"-","-","-","-","c8"]
bytes["ret"]:=[1,16,16,"-","-","-","-","c9"]
bytes["jp z, a16"]:=[3,16,12,"-","-","-","-","ca"]
bytes["prefix"]:=[1,4,4,"-","-","-","-","cb"]
bytes["call z, a16"]:=[3,24,12,"-","-","-","-","cc"]
bytes["call a16"]:=[3,24,24,"-","-","-","-","cd"]
bytes["adc a, n8"]:=[2,8,8,"Z","0","H","C","ce"]
bytes["rst $08"]:=[1,16,16,"-","-","-","-","cf"]

bytes["ret nc"]:=[1,20,8,"-","-","-","-","d0"]
bytes["pop de"]:=[1,12,12,"-","-","-","-","d1"]
bytes["jp nc, a16"]:=[3,16,12,"-","-","-","-","d2"]
;—,"d3" 
bytes["call nc, a16"]:=[3,24,12,"-","-","-","-","d4"]
bytes["push de"]:=[1,16,16,"-","-","-","-","d5"]
bytes["sub a, n8"]:=[2,8,8,"Z","1","H","C","d6"]
bytes["rst $10"]:=[1,16,16,"-","-","-","-","d7"]
bytes["ret c"]:=[1,20,8,"-","-","-","-","d8"]
bytes["reti"]:=[1,16,16,"-","-","-","-","d9"]
bytes["jp c, a16"]:=[3,16,12,"-","-","-","-","da"]
;—,"db" 
bytes["call c, a16"]:=[3,24,12,"-","-","-","-","dc"]
;—,"dd" 
bytes["sbc a, n8"]:=[2,8,8,"Z","1","H","C","de"]
bytes["rst $18"]:=[1,16,16,"-","-","-","-","df"]

bytes["ldh [a8], a"]:=[2,12,12,"-","-","-","-","e0"]
bytes["pop hl"]:=[1,12,12,"-","-","-","-","e1"]
bytes["ldh [c], a"]:=[1,8,8,"-","-","-","-","e2"]
;—,"e3" 
;—,"e4" 
bytes["push hl"]:=[1,16,16,"-","-","-","-","e5"]
bytes["and a, n8"]:=[2,8,8,"Z","0","1","0","e6"]
bytes["rst $20"]:=[1,16,16,"-","-","-","-","e7"]
bytes["add sp, e8"]:=[2,16,16,"0","0","H","C","e8"]
bytes["jp hl"]:=[1,4,4,"-","-","-","-","e9"]
bytes["ld [a16], a"]:=[3,16,16,"-","-","-","-","ea"]
;—,"eb" 
;—,"ec" 
;—,"ed" 
bytes["xor a, n8"]:=[2,8,8,"Z","0","0","0","ee"]
bytes["rst $28"]:=[1,16,16,"-","-","-","-","ef"]

bytes["ldh a, [a8]"]:=[2,12,12,"-","-","-","-","f0"]
bytes["pop af"]:=[1,12,12,"Z","N","H","C","f1"]
bytes["ldh a, [c]"]:=[1,8,8,"-","-","-","-","f2"]
bytes["di"]:=[1,4,4,"-","-","-","-","f3"]
;—,"f4" 
bytes["push af"]:=[1,16,16,"-","-","-","-","f5"]
bytes["or a, n8"]:=[2,8,8,"Z","0","0","0","f6"]
bytes["rst $30"]:=[1,16,16,"-","-","-","-","f7"]
bytes["ld hl, sp + e8"]:=[2,12,12,"0","0","H","C","f8"]
bytes["ld sp, hl"]:=[1,8,8,"-","-","-","-","f9"]
bytes["ld a, [a16]"]:=[3,16,16,"-","-","-","-","fa"]
bytes["ei"]:=[1,4,4,"-","-","-","-","fb"]
;—,"fc" 
;—,"fd" 
bytes["cp a, n8"]:=[2,8,8,"Z","1","H","C","fe"]
bytes["rst $38"]:=[1,16,16,"-","-","-","-","ff"]

bytes["rlc b"]:=[2,8,8,"Z","0","0","C","cb.00"]
bytes["rlc c"]:=[2,8,8,"Z","0","0","C","cb.01"]
bytes["rlc d"]:=[2,8,8,"Z","0","0","C","cb.02"]
bytes["rlc e"]:=[2,8,8,"Z","0","0","C","cb.03"]
bytes["rlc h"]:=[2,8,8,"Z","0","0","C","cb.04"]
bytes["rlc l"]:=[2,8,8,"Z","0","0","C","cb.05"]
bytes["rlc [hl]"]:=[2,16,16,"Z","0","0","C","cb.06"]
bytes["rlc a"]:=[2,8,8,"Z","0","0","C","cb.07"]
bytes["rrc b"]:=[2,8,8,"Z","0","0","C","cb.08"]
bytes["rrc c"]:=[2,8,8,"Z","0","0","C","cb.09"]
bytes["rrc d"]:=[2,8,8,"Z","0","0","C","cb.0a"]
bytes["rrc e"]:=[2,8,8,"Z","0","0","C","cb.0b"]
bytes["rrc h"]:=[2,8,8,"Z","0","0","C","cb.0c"]
bytes["rrc l"]:=[2,8,8,"Z","0","0","C","cb.0d"]
bytes["rrc [hl]"]:=[2,16,16,"Z","0","0","C","cb.0e"]
bytes["rrc a"]:=[2,8,8,"Z","0","0","C","cb.0f"]

bytes["rl b"]:=[2,8,8,"Z","0","0","C","cb.10"]
bytes["rl c"]:=[2,8,8,"Z","0","0","C","cb.11"]
bytes["rl d"]:=[2,8,8,"Z","0","0","C","cb.12"]
bytes["rl e"]:=[2,8,8,"Z","0","0","C","cb.13"]
bytes["rl h"]:=[2,8,8,"Z","0","0","C","cb.14"]
bytes["rl l"]:=[2,8,8,"Z","0","0","C","cb.15"]
bytes["rl [hl]"]:=[2,16,16,"Z","0","0","C","cb.16"]
bytes["rl a"]:=[2,8,8,"Z","0","0","C","cb.17"]
bytes["rr b"]:=[2,8,8,"Z","0","0","C","cb.18"]
bytes["rr c"]:=[2,8,8,"Z","0","0","C","cb.19"]
bytes["rr d"]:=[2,8,8,"Z","0","0","C","cb.1a"]
bytes["rr e"]:=[2,8,8,"Z","0","0","C","cb.1b"]
bytes["rr h"]:=[2,8,8,"Z","0","0","C","cb.1c"]
bytes["rr l"]:=[2,8,8,"Z","0","0","C","cb.1d"]
bytes["rr [hl]"]:=[2,16,16,"Z","0","0","C","cb.1e"]
bytes["rr a"]:=[2,8,8,"Z","0","0","C","cb.1f"]

bytes["sla b"]:=[2,8,8,"Z","0","0","C","cb.20"]
bytes["sla c"]:=[2,8,8,"Z","0","0","C","cb.21"]
bytes["sla d"]:=[2,8,8,"Z","0","0","C","cb.22"]
bytes["sla e"]:=[2,8,8,"Z","0","0","C","cb.23"]
bytes["sla h"]:=[2,8,8,"Z","0","0","C","cb.24"]
bytes["sla l"]:=[2,8,8,"Z","0","0","C","cb.25"]
bytes["sla [hl]"]:=[2,16,16,"Z","0","0","C","cb.26"]
bytes["sla a"]:=[2,8,8,"Z","0","0","C","cb.27"]
bytes["sra b"]:=[2,8,8,"Z","0","0","C","cb.28"]
bytes["sra c"]:=[2,8,8,"Z","0","0","C","cb.29"]
bytes["sra d"]:=[2,8,8,"Z","0","0","C","cb.2a"]
bytes["sra e"]:=[2,8,8,"Z","0","0","C","cb.2b"]
bytes["sra h"]:=[2,8,8,"Z","0","0","C","cb.2c"]
bytes["sra l"]:=[2,8,8,"Z","0","0","C","cb.2d"]
bytes["sra [hl]"]:=[2,16,16,"Z","0","0","C","cb.2e"]
bytes["sra a"]:=[2,8,8,"Z","0","0","C","cb.2f"]

bytes["swap b"]:=[2,8,8,"Z","0","0","0","cb.30"]
bytes["swap c"]:=[2,8,8,"Z","0","0","0","cb.31"]
bytes["swap d"]:=[2,8,8,"Z","0","0","0","cb.32"]
bytes["swap e"]:=[2,8,8,"Z","0","0","0","cb.33"]
bytes["swap h"]:=[2,8,8,"Z","0","0","0","cb.34"]
bytes["swap l"]:=[2,8,8,"Z","0","0","0","cb.35"]
bytes["swap [hl]"]:=[2,16,16,"Z","0","0","0","cb.36"]
bytes["swap a"]:=[2,8,8,"Z","0","0","0","cb.37"]
bytes["srl b"]:=[2,8,8,"Z","0","0","C","cb.38"]
bytes["srl c"]:=[2,8,8,"Z","0","0","C","cb.39"]
bytes["srl d"]:=[2,8,8,"Z","0","0","C","cb.3a"]
bytes["srl e"]:=[2,8,8,"Z","0","0","C","cb.3b"]
bytes["srl h"]:=[2,8,8,"Z","0","0","C","cb.3c"]
bytes["srl l"]:=[2,8,8,"Z","0","0","C","cb.3d"]
bytes["srl [hl]"]:=[2,16,16,"Z","0","0","C","cb.3e"]
bytes["srl a"]:=[2,8,8,"Z","0","0","C","cb.3f"]

bytes["bit 0, b"]:=[2,8,8,"Z","0","1","-","cb.40"]
bytes["bit 0, c"]:=[2,8,8,"Z","0","1","-","cb.41"]
bytes["bit 0, d"]:=[2,8,8,"Z","0","1","-","cb.42"]
bytes["bit 0, e"]:=[2,8,8,"Z","0","1","-","cb.43"]
bytes["bit 0, h"]:=[2,8,8,"Z","0","1","-","cb.44"]
bytes["bit 0, l"]:=[2,8,8,"Z","0","1","-","cb.45"]
bytes["bit 0, [hl]"]:=[2,12,12,"Z","0","1","-","cb.46"]
bytes["bit 0, a"]:=[2,8,8,"Z","0","1","-","cb.47"]
bytes["bit 1, b"]:=[2,8,8,"Z","0","1","-","cb.48"]
bytes["bit 1, c"]:=[2,8,8,"Z","0","1","-","cb.49"]
bytes["bit 1, d"]:=[2,8,8,"Z","0","1","-","cb.4a"]
bytes["bit 1, e"]:=[2,8,8,"Z","0","1","-","cb.4b"]
bytes["bit 1, h"]:=[2,8,8,"Z","0","1","-","cb.4c"]
bytes["bit 1, l"]:=[2,8,8,"Z","0","1","-","cb.4d"]
bytes["bit 1, [hl]"]:=[2,12,12,"Z","0","1","-","cb.4e"]
bytes["bit 1, a"]:=[2,8,8,"Z","0","1","-","cb.4f"]

bytes["bit 2, b"]:=[2,8,8,"Z","0","1","-","cb.50"]
bytes["bit 2, c"]:=[2,8,8,"Z","0","1","-","cb.51"]
bytes["bit 2, d"]:=[2,8,8,"Z","0","1","-","cb.52"]
bytes["bit 2, e"]:=[2,8,8,"Z","0","1","-","cb.53"]
bytes["bit 2, h"]:=[2,8,8,"Z","0","1","-","cb.54"]
bytes["bit 2, l"]:=[2,8,8,"Z","0","1","-","cb.55"]
bytes["bit 2, [hl]"]:=[2,12,12,"Z","0","1","-","cb.56"]
bytes["bit 2, a"]:=[2,8,8,"Z","0","1","-","cb.57"]
bytes["bit 3, b"]:=[2,8,8,"Z","0","1","-","cb.58"]
bytes["bit 3, c"]:=[2,8,8,"Z","0","1","-","cb.59"]
bytes["bit 3, d"]:=[2,8,8,"Z","0","1","-","cb.5a"]
bytes["bit 3, e"]:=[2,8,8,"Z","0","1","-","cb.5b"]
bytes["bit 3, h"]:=[2,8,8,"Z","0","1","-","cb.5c"]
bytes["bit 3, l"]:=[2,8,8,"Z","0","1","-","cb.5d"]
bytes["bit 3, [hl]"]:=[2,12,12,"Z","0","1","-","cb.5e"]
bytes["bit 3, a"]:=[2,8,8,"Z","0","1","-","cb.5f"]

bytes["bit 4, b"]:=[2,8,8,"Z","0","1","-","cb.60"]
bytes["bit 4, c"]:=[2,8,8,"Z","0","1","-","cb.61"]
bytes["bit 4, d"]:=[2,8,8,"Z","0","1","-","cb.62"]
bytes["bit 4, e"]:=[2,8,8,"Z","0","1","-","cb.63"]
bytes["bit 4, h"]:=[2,8,8,"Z","0","1","-","cb.64"]
bytes["bit 4, l"]:=[2,8,8,"Z","0","1","-","cb.65"]
bytes["bit 4, [hl]"]:=[2,12,12,"Z","0","1","-","cb.66"]
bytes["bit 4, a"]:=[2,8,8,"Z","0","1","-","cb.67"]
bytes["bit 5, b"]:=[2,8,8,"Z","0","1","-","cb.68"]
bytes["bit 5, c"]:=[2,8,8,"Z","0","1","-","cb.69"]
bytes["bit 5, d"]:=[2,8,8,"Z","0","1","-","cb.6a"]
bytes["bit 5, e"]:=[2,8,8,"Z","0","1","-","cb.6b"]
bytes["bit 5, h"]:=[2,8,8,"Z","0","1","-","cb.6c"]
bytes["bit 5, l"]:=[2,8,8,"Z","0","1","-","cb.6d"]
bytes["bit 5, [hl]"]:=[2,12,12,"Z","0","1","-","cb.6e"]
bytes["bit 5, a"]:=[2,8,8,"Z","0","1","-","cb.6f"]

bytes["bit 6, b"]:=[2,8,8,"Z","0","1","-","cb.70"]
bytes["bit 6, c"]:=[2,8,8,"Z","0","1","-","cb.71"]
bytes["bit 6, d"]:=[2,8,8,"Z","0","1","-","cb.72"]
bytes["bit 6, e"]:=[2,8,8,"Z","0","1","-","cb.73"]
bytes["bit 6, h"]:=[2,8,8,"Z","0","1","-","cb.74"]
bytes["bit 6, l"]:=[2,8,8,"Z","0","1","-","cb.75"]
bytes["bit 6, [hl]"]:=[2,12,12,"Z","0","1","-","cb.76"]
bytes["bit 6, a"]:=[2,8,8,"Z","0","1","-","cb.77"]
bytes["bit 7, b"]:=[2,8,8,"Z","0","1","-","cb.78"]
bytes["bit 7, c"]:=[2,8,8,"Z","0","1","-","cb.79"]
bytes["bit 7, d"]:=[2,8,8,"Z","0","1","-","cb.7a"]
bytes["bit 7, e"]:=[2,8,8,"Z","0","1","-","cb.7b"]
bytes["bit 7, h"]:=[2,8,8,"Z","0","1","-","cb.7c"]
bytes["bit 7, l"]:=[2,8,8,"Z","0","1","-","cb.7d"]
bytes["bit 7, [hl]"]:=[2,12,12,"Z","0","1","-","cb.7e"]
bytes["bit 7, a"]:=[2,8,8,"Z","0","1","-","cb.7f"]

bytes["res 0, b"]:=[2,8,8,"-","-","-","-","cb.80"]
bytes["res 0, c"]:=[2,8,8,"-","-","-","-","cb.81"]
bytes["res 0, d"]:=[2,8,8,"-","-","-","-","cb.82"]
bytes["res 0, e"]:=[2,8,8,"-","-","-","-","cb.83"]
bytes["res 0, h"]:=[2,8,8,"-","-","-","-","cb.84"]
bytes["res 0, l"]:=[2,8,8,"-","-","-","-","cb.85"]
bytes["res 0, [hl]"]:=[2,16,16,"-","-","-","-","cb.86"]
bytes["res 0, a"]:=[2,8,8,"-","-","-","-","cb.87"]
bytes["res 1, b"]:=[2,8,8,"-","-","-","-","cb.88"]
bytes["res 1, c"]:=[2,8,8,"-","-","-","-","cb.89"]
bytes["res 1, d"]:=[2,8,8,"-","-","-","-","cb.8a"]
bytes["res 1, e"]:=[2,8,8,"-","-","-","-","cb.8b"]
bytes["res 1, h"]:=[2,8,8,"-","-","-","-","cb.8c"]
bytes["res 1, l"]:=[2,8,8,"-","-","-","-","cb.8d"]
bytes["res 1, [hl]"]:=[2,16,16,"-","-","-","-","cb.8e"]
bytes["res 1, a"]:=[2,8,8,"-","-","-","-","cb.8f"]

bytes["res 2, b"]:=[2,8,8,"-","-","-","-","cb.90"]
bytes["res 2, c"]:=[2,8,8,"-","-","-","-","cb.91"]
bytes["res 2, d"]:=[2,8,8,"-","-","-","-","cb.92"]
bytes["res 2, e"]:=[2,8,8,"-","-","-","-","cb.93"]
bytes["res 2, h"]:=[2,8,8,"-","-","-","-","cb.94"]
bytes["res 2, l"]:=[2,8,8,"-","-","-","-","cb.95"]
bytes["res 2, [hl]"]:=[2,16,16,"-","-","-","-","cb.96"]
bytes["res 2, a"]:=[2,8,8,"-","-","-","-","cb.97"]
bytes["res 3, b"]:=[2,8,8,"-","-","-","-","cb.98"]
bytes["res 3, c"]:=[2,8,8,"-","-","-","-","cb.99"]
bytes["res 3, d"]:=[2,8,8,"-","-","-","-","cb.9a"]
bytes["res 3, e"]:=[2,8,8,"-","-","-","-","cb.9b"]
bytes["res 3, h"]:=[2,8,8,"-","-","-","-","cb.9c"]
bytes["res 3, l"]:=[2,8,8,"-","-","-","-","cb.9d"]
bytes["res 3, [hl]"]:=[2,16,16,"-","-","-","-","cb.9e"]
bytes["res 3, a"]:=[2,8,8,"-","-","-","-","cb.9f"]

bytes["res 4, b"]:=[2,8,8,"-","-","-","-","cb.a0"]
bytes["res 4, c"]:=[2,8,8,"-","-","-","-","cb.a1"]
bytes["res 4, d"]:=[2,8,8,"-","-","-","-","cb.a2"]
bytes["res 4, e"]:=[2,8,8,"-","-","-","-","cb.a3"]
bytes["res 4, h"]:=[2,8,8,"-","-","-","-","cb.a4"]
bytes["res 4, l"]:=[2,8,8,"-","-","-","-","cb.a5"]
bytes["res 4, [hl]"]:=[2,16,16,"-","-","-","-","cb.a6"]
bytes["res 4, a"]:=[2,8,8,"-","-","-","-","cb.a7"]
bytes["res 5, b"]:=[2,8,8,"-","-","-","-","cb.a8"]
bytes["res 5, c"]:=[2,8,8,"-","-","-","-","cb.a9"]
bytes["res 5, d"]:=[2,8,8,"-","-","-","-","cb.aa"]
bytes["res 5, e"]:=[2,8,8,"-","-","-","-","cb.ab"]
bytes["res 5, h"]:=[2,8,8,"-","-","-","-","cb.ac"]
bytes["res 5, l"]:=[2,8,8,"-","-","-","-","cb.ad"]
bytes["res 5, [hl]"]:=[2,16,16,"-","-","-","-","cb.ae"]
bytes["res 5, a"]:=[2,8,8,"-","-","-","-","cb.af"]

bytes["res 6, b"]:=[2,8,8,"-","-","-","-","cb.b0"]
bytes["res 6, c"]:=[2,8,8,"-","-","-","-","cb.b1"]
bytes["res 6, d"]:=[2,8,8,"-","-","-","-","cb.b2"]
bytes["res 6, e"]:=[2,8,8,"-","-","-","-","cb.b3"]
bytes["res 6, h"]:=[2,8,8,"-","-","-","-","cb.b4"]
bytes["res 6, l"]:=[2,8,8,"-","-","-","-","cb.b5"]
bytes["res 6, [hl]"]:=[2,16,16,"-","-","-","-","cb.b6"]
bytes["res 6, a"]:=[2,8,8,"-","-","-","-","cb.b7"]
bytes["res 7, b"]:=[2,8,8,"-","-","-","-","cb.b8"]
bytes["res 7, c"]:=[2,8,8,"-","-","-","-","cb.b9"]
bytes["res 7, d"]:=[2,8,8,"-","-","-","-","cb.ba"]
bytes["res 7, e"]:=[2,8,8,"-","-","-","-","cb.bb"]
bytes["res 7, h"]:=[2,8,8,"-","-","-","-","cb.bc"]
bytes["res 7, l"]:=[2,8,8,"-","-","-","-","cb.bd"]
bytes["res 7, [hl]"]:=[2,16,16,"-","-","-","-","cb.be"]
bytes["res 7, a"]:=[2,8,8,"-","-","-","-","cb.bf"]

bytes["set 0, b"]:=[2,8,8,"-","-","-","-","cb.c0"]
bytes["set 0, c"]:=[2,8,8,"-","-","-","-","cb.c1"]
bytes["set 0, d"]:=[2,8,8,"-","-","-","-","cb.c2"]
bytes["set 0, e"]:=[2,8,8,"-","-","-","-","cb.c3"]
bytes["set 0, h"]:=[2,8,8,"-","-","-","-","cb.c4"]
bytes["set 0, l"]:=[2,8,8,"-","-","-","-","cb.c5"]
bytes["set 0, [hl]"]:=[2,16,16,"-","-","-","-","cb.c6"]
bytes["set 0, a"]:=[2,8,8,"-","-","-","-","cb.c7"]
bytes["set 1, b"]:=[2,8,8,"-","-","-","-","cb.c8"]
bytes["set 1, c"]:=[2,8,8,"-","-","-","-","cb.c9"]
bytes["set 1, d"]:=[2,8,8,"-","-","-","-","cb.ca"]
bytes["set 1, e"]:=[2,8,8,"-","-","-","-","cb.cb"]
bytes["set 1, h"]:=[2,8,8,"-","-","-","-","cb.cc"]
bytes["set 1, l"]:=[2,8,8,"-","-","-","-","cb.cd"]
bytes["set 1, [hl]"]:=[2,16,16,"-","-","-","-","cb.ce"]
bytes["set 1, a"]:=[2,8,8,"-","-","-","-","cb.cf"]

bytes["set 2, b"]:=[2,8,8,"-","-","-","-","cb.d0"]
bytes["set 2, c"]:=[2,8,8,"-","-","-","-","cb.d1"]
bytes["set 2, d"]:=[2,8,8,"-","-","-","-","cb.d2"]
bytes["set 2, e"]:=[2,8,8,"-","-","-","-","cb.d3"]
bytes["set 2, h"]:=[2,8,8,"-","-","-","-","cb.d4"]
bytes["set 2, l"]:=[2,8,8,"-","-","-","-","cb.d5"]
bytes["set 2, [hl]"]:=[2,16,16,"-","-","-","-","cb.d6"]
bytes["set 2, a"]:=[2,8,8,"-","-","-","-","cb.d7"]
bytes["set 3, b"]:=[2,8,8,"-","-","-","-","cb.d8"]
bytes["set 3, c"]:=[2,8,8,"-","-","-","-","cb.d9"]
bytes["set 3, d"]:=[2,8,8,"-","-","-","-","cb.da"]
bytes["set 3, e"]:=[2,8,8,"-","-","-","-","cb.db"]
bytes["set 3, h"]:=[2,8,8,"-","-","-","-","cb.dc"]
bytes["set 3, l"]:=[2,8,8,"-","-","-","-","cb.dd"]
bytes["set 3, [hl]"]:=[2,16,16,"-","-","-","-","cb.de"]
bytes["set 3, a"]:=[2,8,8,"-","-","-","-","cb.df"]

bytes["set 4, b"]:=[2,8,8,"-","-","-","-","cb.e0"]
bytes["set 4, c"]:=[2,8,8,"-","-","-","-","cb.e1"]
bytes["set 4, d"]:=[2,8,8,"-","-","-","-","cb.e2"]
bytes["set 4, e"]:=[2,8,8,"-","-","-","-","cb.e3"]
bytes["set 4, h"]:=[2,8,8,"-","-","-","-","cb.e4"]
bytes["set 4, l"]:=[2,8,8,"-","-","-","-","cb.e5"]
bytes["set 4, [hl]"]:=[2,16,16,"-","-","-","-","cb.e6"]
bytes["set 4, a"]:=[2,8,8,"-","-","-","-","cb.e7"]
bytes["set 5, b"]:=[2,8,8,"-","-","-","-","cb.e8"]
bytes["set 5, c"]:=[2,8,8,"-","-","-","-","cb.e9"]
bytes["set 5, d"]:=[2,8,8,"-","-","-","-","cb.ea"]
bytes["set 5, e"]:=[2,8,8,"-","-","-","-","cb.eb"]
bytes["set 5, h"]:=[2,8,8,"-","-","-","-","cb.ec"]
bytes["set 5, l"]:=[2,8,8,"-","-","-","-","cb.ed"]
bytes["set 5, [hl]"]:=[2,16,16,"-","-","-","-","cb.ee"]
bytes["set 5, a"]:=[2,8,8,"-","-","-","-","cb.ef"]

bytes["set 6, b"]:=[2,8,8,"-","-","-","-","cb.f0"]
bytes["set 6, c"]:=[2,8,8,"-","-","-","-","cb.f1"]
bytes["set 6, d"]:=[2,8,8,"-","-","-","-","cb.f2"]
bytes["set 6, e"]:=[2,8,8,"-","-","-","-","cb.f3"]
bytes["set 6, h"]:=[2,8,8,"-","-","-","-","cb.f4"]
bytes["set 6, l"]:=[2,8,8,"-","-","-","-","cb.f5"]
bytes["set 6, [hl]"]:=[2,16,16,"-","-","-","-","cb.f6"]
bytes["set 6, a"]:=[2,8,8,"-","-","-","-","cb.f7"]
bytes["set 7, b"]:=[2,8,8,"-","-","-","-","cb.f8"]
bytes["set 7, c"]:=[2,8,8,"-","-","-","-","cb.f9"]
bytes["set 7, d"]:=[2,8,8,"-","-","-","-","cb.fa"]
bytes["set 7, e"]:=[2,8,8,"-","-","-","-","cb.fb"]
bytes["set 7, h"]:=[2,8,8,"-","-","-","-","cb.fc"]
bytes["set 7, l"]:=[2,8,8,"-","-","-","-","cb.fd"]
bytes["set 7, [hl]"]:=[2,16,16,"-","-","-","-","cb.fe"]
bytes["set 7, a"]:=[2,8,8,"-","-","-","-","cb.ff"]

; the following are pseudo opcodes. Without using a sym or map file, a command such as `set THISBIT, b` where THISBIT is a constant could be any of `set 0, b`, `set 1, b`, etc. Using `set n, b` gives the opportunity to at least get the bytes and machine cycles, even if the opcode will not be known.

bytes["set n, b"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, c"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, d"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, e"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, h"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, l"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, [hl]"]:=[2,16,16,"-","-","-","-","cb.??"]
bytes["set n, a"]:=[2,8,8,"-","-","-","-","cb.??"]

bytes["res n, b"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, c"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, d"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, e"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, h"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, l"]:=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, [hl]"]:=[2,16,16,"-","-","-","-","cb.??"]
bytes["res n, a"]:=[2,8,8,"-","-","-","-","cb.??"]

bytes["bit n, b"]:=[2,8,8,"?","?","?","?","cb.??"]
bytes["bit n, c"]:=[2,8,8,"?","?","?","?","cb.??"]
bytes["bit n, d"]:=[2,8,8,"?","?","?","?","cb.??"]
bytes["bit n, e"]:=[2,8,8,"?","?","?","?","cb.??"]
bytes["bit n, h"]:=[2,8,8,"?","?","?","?","cb.??"]
bytes["bit n, l"]:=[2,8,8,"?","?","?","?","cb.??"]
bytes["bit n, [hl]"]:=[2,12,12,"?","?","?","?","cb.??"]
bytes["bit n, a"]:=[2,8,8,"?","?","?","?","cb.??"]

;bytes["jpfar label"]:=[32,200,200,"?","?","?","?"] ; inspiration to how someone may extend this feature to include macros. By measuring a jpfar through this utility, it could become recognized as its own "opcode".

symbolExpectations:="[\w\(\)\\]" ; AHK treats \w as equivalent to [a-zA-Z0-9_]
;symbolExpectationsPlusDollar:="[\w\(\)\\\$]" ; I thought this would be necessary thanks to allowing recognition of $xx numbers, however, it then adapted to numbervalue as seen on the next line
numbervalue:="-?((\$|%)?\d+|\$[a-fA-F0-9]+)(?!.*,)"

updateAuto(GuiCtrlObj,Info) { ; used		; if we want the pasted contents to be evaluated automatically. If you intend to actually edit the code in the GUI, the script will automatically process with every new keystroke that changes the input, so we want to be able to turn it off.
	if GuiCtrlObj.Value
		myGui["Query"].OnEvent("Change",updateAnswer)
	else
		myGui["Query"].OnEvent("Change",updateAnswer,0)
}

updateAnswer2(GuiCtrlObj,Info) { ; used in the stupidest of ways  ; I couldn't figure out how to make the gui just pass the below command directly, so I made a parent-child function as a workaround
	updateAnswer(myGui["Query"],"")
}

updateAnswer(GuiCtrlObj,Info) { ; used
	GuiCtrlObj.Value:=FixSpacing(GuiCtrlObj.Value) ; FixSpacing will look to trim out tabs, etc. We will then leave that visually displayed in the GUI input box.
	workingwith:=RemoveComments(GuiCtrlObj.Value) ; we will then create a working copy of the code stripped of comments
	workingwith:=FixSpacing2(workingwith) ; reading up on https://rgbds.gbdev.io/docs/v1.0.1/rgbasm.5 there is a syntax tolerance for \ to "merge" the lines that I want to account for
	global bytesInt:=0 ; we'll get these variables ready to start tallying as we identify opcodes
	global t_cycle_max:=0
	global t_cycle_min:=0
	myGui["Work"].text:="Processing" ; placeholder text to show the GUI is working
	myGui["Ign"].text:="" ; clears the previous ignored text; without this, the ignored lines would just append to the previous reported ignored lines getting confusing
	global acceptedresults:="" ; these variables will hold our final answers, added to via concatenation
	global ignoredresults:=""
	; global bytebuilding:="" ; this is not necessary in the final application, this was a debug tool. 
	global zflag:="-" ; I'm not sure this is actually in use with any purpose. There was a feature that was removed that tried to track when the flags would change and keep a current state of them. The decision to remove it was because of macros or calls would have un-evaluated code that in itself could change the flags. These lines set their starting value of "neutral" so the script to evaluate when a change took place would work.
	global nflag:="-"
	global hflag:="-"
	global cflag:="-"
	inputarray:=StrSplit(workingwith,"`n","`r") ; in AHK, we actually did a lot of formatting on trimming spaces, etc. on the entire text in one go. Now we are breaking it down line by line to try to identify if it is a label, recognized opcode, or other.
	Loop inputarray.Length {
		myGui["Work"].text:="Processing" . SubStr("...",Mod(Floor(A_Index/80),3)+1) ; every 80 lines processed we will change the number of periods after the word Processing. Large files of thousands of lines may take several seconds to process and this indicates to the user that the GUI is functioning.
		Classification(inputarray[A_Index],A_Index) ; The Classification() function will take the line of text followed by the line number to put a line into accepted results or ignored results with the appropriate details necessary
	}
	myGui["Work"].text:="Line#`tAssembly`tT-Cycle`tM-Cycle`tBytes`t" . (myGui["flags"].Value?"Z`tN`tH`tC`t":"") . "Original Code`r`n" . acceptedresults ; this creates a header for columns and then the actual results
	myGui["Ign"].text:=ignoredresults ; put the ignored lines here for debugging purposes, often going to be macros, etc.
	myGui["Bytes"].text:="Bytes:" bytesInt ; showing the total number of bytes here
	myGui["Cycles"].text:=(t_cycle_max = t_cycle_min ? "T-Cycle " . t_cycle_max . "\nM-Cycle " . Format("{:d}",t_cycle_max/4) : "T-Cycles " . t_cycle_min . "-" . t_cycle_max . "`nM-Cycles " . Format("{:d}",t_cycle_min/4) . "-" . Format("{:d}",t_cycle_max/4)) ; shows our cycles
	;myGui["RomCheck"].text:=bytebuilding ; this was a debug purpose of concatenating the bytes along with .. as regex wildcards based on the total length of the opcode in bytes to allow matching with the existing rom; hypothetically if this produced a string that could not be found in searching the hexcode of the rom, that would indicate an opcode was misinterpreted by this program. i.e. jp hl being recognized as jp e8 because of incorrectly identifying hl as a constant
	return
}

FixSpacing2(field) { ; used
	output:=RegExReplace(field,"\\\R","") ; \\ is to get a plain \ as would be used per https://rgbds.gbdev.io/docs/v1.0.1/rgbasm.5 and in AHK \R matches `r, `n, and `r`n, so this essentially merges our lines up.
	return output
}

Classification(field,linenumber) { ; used
	; is it a label?
	pos:=0
	pos:=RegExMatch(field,":$")
	pos+=RegExMatch(field,"^\..") ; notice the += syntax; we are adding onto it whatever this RegExMatch() result is, not overwriting it.
	if pos > 0 { ; pos is a positive integer if it finds a match
		global acceptedresults.=Format("{:03d}",linenumber) . "|`t`t`t`t`t" . (myGui["flags"].Value?"`t`t`t`t":"") . field . "`r`n" ; pad it with the necessary tabs; this is not an opcode, but it's displayed in the accepted results to help guide the user to where in the code they are looking
		return
	}
	translation:=ParseRegisters(field) ; this is where we do a lot of work to try to identify an opcode by changing what could be constants/variables into recognized numbers like an e8 or a16
	CategorizeAndScore(translation,linenumber,field) ; now that we have an opcode (or an unrecognized one), we'll pass it along to give us tallies. the field parameter contains our original code so we can reference it and help troubleshoot if it is being miscategorized
}

CategorizeAndScore(field,linenumber,og:="") { ; used
	if StrLen(field) = 0 ; this gets confusing because we moved where "field" is relative to what calls it, but the first parameter is going to be our hopefully-recognized opcode. If this is a null string with no length, we just do nothing. Ignore it.
		return
	try ; this will yield a match value if the bytes Map() has a key we want.
		{
			match:=bytes[field] ; we'll get an array back with the bytes, cycles, flags, opcode.
		}
		catch Any ; if it fails to find this key, we make the match variable the string "failure"
		{
			match:="failure"
		}
	if (match = "failure") {
		;MsgBox(field . "`n" . og) ; debugging message
		global ignoredresults.=Format("{:03d}",linenumber) . "|`t" . og . "`r`n" ; we didn't recognize this, so we are going to include it in ignored results with a line number prefix to help diagnose why it wasn't recognized if we believe it should have been
		;if RegExMatch(field,"INCLUDE") ; debugging feature, if the assembly used an INCLUDE "file" syntax, we just added a couple empty lines between opcodes because the actual bytes this would write would be unknown to us
		;	bytebuilding.="`r`n`r`n" ; this was accidentally left uncommented when building the EXE as of 1/25/26. An earlier line that clears this variable to null was left in tact, so not really harmful.
		;else
		;	bytebuilding.=".*?" ; it's a macro or predef or something I hope. So I'm just going to let it be as aggressive as it wants to match the opcodes.
		}
	else {
		global zflag ; just makes this local function recognize these global variables should be used
		global nflag
		global hflag
		global cflag
		global bytesInt+=match[1] ; notice the += for incrementing by the values found in the match array
		global t_cycle_max+=match[2]
		global t_cycle_min+=match[3]
		;global acceptedresults.=(true ? match[8] : Format("{:03d}",linenumber)) . "|`t" . field . "`t" . ( match[2] != match[3] ? (match[2] "/" match[3] . "`t" . Format("{:d}",match[2]/4) "/" Format("{:d}",match[3]/4)) : match[2] . "`t" . Format("{:d}",match[2]/4) ) . "`t" . match[1] . (myGui["flags"].Value ? "`t" . (match[4] = "-" ? zflag : (zflag:=match[4]) . "*") . "`t" . (match[5] = "-" ? nflag : (nflag:=match[5]) . "*") . "`t" . (match[6] = "-" ? hflag : (hflag:=match[6]) . "*") . "`t" . (match[7] = "-" ? cflag : (cflag:=match[7]) . "*") : "") . "`t" og "`r`n" ; this was a diagnostic syntax where instead of a line number, an opcode prefix would be used in the first column
		global acceptedresults.=Format("{:03d}",linenumber) . "|`t" . field . "`t" . ( match[2] != match[3] ? (match[2] "/" match[3] . "`t" . Format("{:d}",match[2]/4) "/" Format("{:d}",match[3]/4)) : match[2] . "`t" . Format("{:d}",match[2]/4) ) . "`t+" . match[1] . "=" . bytesInt . "`t" . (myGui["flags"].Value ? match[4] . "`t" . match[5] . "`t" . match[6] . "`t" . match[7] . "`t" : "") . og "`r`n"
		; global bytebuilding.=RegExReplace(RegExReplace(match[8],"cb\.","cb",&yesitwasacb),"\?\?","..") . SubStr(".............",1,(match[1]-(yesitwasacb?2:1))*2) ; probably unnecessary in length, I think the largest value is 3 bytes... ; this was accidentally left uncommented when building the EXE as of 1/25/26. This was a debug tool to construct the byte sequence as found in ROM so using a find feature on the hexcode of the ROM could give us confidence our utility is interpreting the code correctly.
		}
}

FixSpacing(field) { ; used ; this trims spacing 
	output:=RegExReplace(field,"`r`n","`n") ; not sure if this is really needed, but the point was because the edit field is weird, we simplify the line breaks to just be newlines instead of carriage return+new lines.
	output:=RegExReplace(output,"m)^[\t ]+","") ; gets rid of any lead whitespace produced by tabs or space characters on each line of our code
	output:=RegExReplace(output,"m)[\t ]+$","") ; gets rid of any trailing whitespace produced by tabs or space characters on each line of our code
	return output ; rather than using \s to capture whitespace, just tabs and spaces were used because I did not want to merge empty lines otherwise it throws off the linecount for debugging purposes when cross-referencing your code in your text editor
}

ExplicitImpliedA(field) { ; used
	output:=RegExReplace(field,"m)^[\t ]*(ld\s|add\s|adc\s|sub\s|sbc\s|and\s|xor\s|or\s|cp\s|ldh\s)(?!.*?,)","$1a, ") ; hypothetically the [\t ]* part shouldn't be necessary as it should've been trimmed by fixspacing above, but no harm in it being there
	return output	; this identifies any code that does not have a comma further down the line. while `ld b` is valid, `ld a b` is not, it must be `ld a, b`. So if we can't find a comma, then we assume an implicit a was used, so we put that in to help match in our Bytes Map()
}

RemoveComments(field) { ; used
	output:=RegExReplace(field,"m)[\t ]*;.*","") ; simply find the ; character and delete any tabs or spaces preceeding it and all text after it ; it is possible for multiple comments to be on a line for human readability via multiple semicolons so we don't limit ourselves to matching the end of the line
	return output
}

ParseRegisters(field) { ; used
	output:=RegExReplace(field,"'.+?'","string") ; note that this comes before the ExplicitImpliedA function *because* it is possible for a string to have a comma in it, e.g. "Hello, World". We need to get rid of those commas that aren't part of the opcode syntax
	output:=RegExReplace(output,'".+?"',"string") ; strings could be double quoted or single quoted
	output:=ExplicitImpliedA(output) ; now that we have simplified the strings, we can put in the implied register a to be explicit to allow syntax recognition matching
	output:=RegExReplace(output,"\[hli\]","[hl+]") ; the mnemonic hli may be used in place of hl+; we change it to be consistently hl+ for sake of the Bytes Map()
	output:=RegExReplace(output,"\[hld\]","[hl-]") ; same as above, just hld = hl-
	output:=RegExReplace(output,"i)" . numbervalue,"000") ; my attempt at parsing through that anything recognized as a number just be treated as the integer 000 which will identify within symbolsMathed; symbolsMathed requries 3 or more characters to differentiate it from registers like a, b, c, hl, etc. Persons who use a 1 or 2 character custom symbol will confuse this script :(
	Loop 6 ; this is an attempt to do math on symbols and consolidate them to one word, because it is possible for multiple operations to exist, I arbitrarily chose 6 iterations
		output:=RegExReplace(output,"i)\(*" . symbolExpectations . "{3,} ?[\+\-\*/\|\<>&\^~%!]+ ?" . symbolExpectations . "+\)*","symbolsMathed") ; trying to account for adding numbers onto a constant, won't catch it if it's like 1 + CONSTANT but should catch CONSTANT + 1 or CONSTANT + $A ? I think the above using numbervalue -> 000 helps me account for this
	output:=RegExReplace(output,"i)[\+\-~!]+" . symbolExpectations,"symbolsMathed") ; the negation operators, and maybe urnary operators, could prefix on here. E.g. !value is boolean not to invert the value of something; if it was non-zero it becomes zero and if it was zero becomes one.
	output:=RegExReplace(output,"i)^\s*ldh\s(?!\[c\])\[.*?\],\sa\s*$","ldh [a8], a") ; watch out for LDH [C], A. There is a special opcode that is ldh [c], a that we don't watch to match against, otherwise we can assume this is going to be like ldh [wRamAddress], a. where wRamAddress will be an a8 number
	output:=RegExReplace(output,"i)^\s*ldh\sa,\s(?!\[c\])\[.*?\]\s*$","ldh a, [a8]") ; watch out for LDH A, [C] ; same as above just reverse order; we have already used ExplicitImpliedA to make sure an a, will be there.
	output:=RegExReplace(output,"i)^\s*ld \[.*?\], sp\s*$","ld [a16], sp") ; specific opcode for an ld [a16], sp.
	output:=RegExReplace(output,"i)^\s*ld \[" . symbolExpectations . "{3,}?\], a\s*$","ld [a16], a") ; these bug out on the registers like ld a, [hl] or ld a, [hli] or ld a, [de] if we don't require Symbols to be minimum 3 characters.
	output:=RegExReplace(output,"i)^\s*ld a, \[" . symbolExpectations . "{3,}?\]\s*$","ld a, [a16]") ; reverse order as above
	output:=RegExReplace(output,"i)^\s*((jp|call)( n?(z|c),)?.(?!hl$)).*$","$1a16") ; watch out for JP HL -- that's the purpose of our negative lookahead; but otherwise there are conditional jp and call functions like jp c or call nz, and unconditional, to identify. They will have an "a16" companion value
	output:=RegExReplace(output,"i)^\s*(jr,? (n?(z|c),)? ?).*$","$1e8") ; if we see a jr, it'll have an e8 value, we just need to identify if it's conditional or not for the Bytes Map()
	output:=RegExReplace(output,"i)^\s*add sp, .*$","add sp, e8") ; specific opcode
	output:=RegExReplace(output,"i)^\s*ld hl, sp \+ .*$","ld hl, sp + e8") ; really odd, specific opcode.
	output:=RegExReplace(output,"i)^\s*(ld (bc|de|hl|sp), )(?!sp \+ e8$).*$","$1n16") ; a few opcodes that assuming isn't the specific one above we load in an n16 value as a companion value
	output:=RegExReplace(output,"i)^\s*stop\b.*$","stop n8") ; specific opcode
	output:=RegExReplace(output,"i)^\s*(ld\s(b|d|h|\[hl\]|c|e|l|a),)\s*(?=[$0-9]).*$","$1 n8") ; this needs to be careful about ld b, a etc. Tried to match on a $xx hex or any digit on a lookahead. Is that actually making a capture group when I option it out?
	output:=RegExReplace(output,"i)^\s*(ld\s(b|d|h|\[hl\]|c|e|l|a),)\s*" . symbolExpectations . "{3,}\s*$","$1 n8") ; this is me trying to capture symbol names. BIG ASSUMPTION that symbols are minimum 3 characters...
	output:=RegExReplace(output,"i)^\s*(add|sub|and|or|adc|sbc|xor|cp)\s*a,\s*(?=[$0-9]).*$","$1 a, n8") ; some of the most common opcodes, do something to the a register with a number n8. This is an older iteration on my regex code; it could be improved, but it seems to work as is. Earlier we took advantage of an AHK variable numbervalue in the regex and this should have replaced everything with 000 that's recognized as a number. So no $ hax prefix, etc. And this lacks consideration for just % binary input too, but numbervalue gets that.
	output:=RegExReplace(output,"i)^\s*(add|sub|and|or|adc|sbc|xor|cp)\s*a,\s*" . symbolExpectations . "{3,}\s*$","$1 a, n8") ; this is trying to capture symbols and not just numbers, repeating the above. Probably could be consolidated with an [ | ] block in the regex.
	output:=RegExReplace(output,"i)^\s*(bit|res|set)\s+" . symbolExpectations . "{3,},\s*","$1 n, ") ; for when we use a symbol in place of integers 0-7, we have pseudo-opcodes like `res n, b`
	;output:=RegExReplace(output,"m)^\s*jpfar.*","jpfar label") ; hypothetically if someone wanted to create custom opcodes named after macros, they could.
	output:=StrLower(output) ; in case someone inputs like `CALL ThisFunction` or `LD H, B`, we are lowercasing stuff so it comes out as call a16 rather than CALL a16 to allow for it to match in the Bytes Map.
	return output
}
#HotIf WinActive("Cycle Counter ahk_class AutoHotkeyGUI") ; I hope this actually works in the EXE. Seems to.
^o:: { ; a "hidden" hotkey to just open up a file instead
global rememberfolder ; we tell AHK this function may access this variable globally
fi:=FileSelect(3,rememberfolder,,"*.asm") ; select a file! It must exist.
if !fi ; if someone exited out of the file selection with doing nothing
	return
SplitPath fi, , &rememberfolder ; update rememberfolder with the folder we were just in; fi continues to hold the full path and name
myGui["Query"].text := FileRead(fi) ; open this into the left most box
if myGui["Auto"].value = 1 ; and if we have autosubmit on
	updateAnswer(myGui["Query"],"") ; submit it for us
return
}
/* ; debug purposes
^k:: { ; the hotkey Ctrl+K opened up a file selection dialog and I could select multiple files to process through debugging to make sure the bytes we intepreted form each opcode matches what's actually in the rom
fi:=FileSelect("M","C:\cygwin64\home\Doctor\pokered",,"*.asm")
for asm in fi { ; for each file selected in the dialog
	myGui["Query"].text := FileRead(asm) ; load that into the input box of the GUI
	Sleep 100 ; wait a moment for it to process, arbitrarily 0.1 seconds
	updateAnswer2("filler","filler") ; call updateAnswer2 as if I had clicked the submit button. Normally this wouldn't process automatically I don't believe. Or at least at debugging time it didn't. It might now.
	Sleep 100 ; this then generates our accepted results, ignored results, and debug byte sequence
	ctrll("^l") ; this calls the hotkey ^l (Ctrl+L) to evaluate if the debug byte seequence could be found in the vanilla rom reprsented as hex in a text file
}
return
}

^l:: 
ctrll(hk){ ; ctrll(hk) is AHK v2's way of letting you call a hotkey through this "Secondary" label
inspect:=myGui["RomCheck"].text ; grab the byte sequence from debugging
literalsinglequote:="'" ; ahk weirdness in regex and passing functions to commandline in RunWaitOne()
literaldoublequote:='"' ; " ; this extra comment and quotation mark is just for syntax highlighting in NotePad++ if one has the AHK syntax highlighting found somewhere on autohotkey.com or its forums
Loop Parse inspect, "`r", "`n" ; read each line of our bytes
	if StrLen(A_LoopField) > 20 ; if it is <=20, don't bother. These are easy matches, probably. Just cumbersome to query such a short string that probably repeats a lot, like a series of 5 calls or what not. But it must be > 0, as if it's 0, there's no instruction at all and it breaks everything in this compareable.
		if !(StrLen(rer:=RegExReplace(r:=RunWaitOne(v:="C:\cygwin64\bin\bash --login -c " . literalsinglequote . "cd ../../cygdrive/c/Users/docto/PokeStream; grep -oiE " . literaldoublequote . A_LoopField . literaldoublequote . " prline.txt" . literalsinglequote),"`a)\s+",""))) ; greps a file known to have the hex values of the ROM laid out as text for our byte query
			MsgBox("__" . A_LoopField . "__`n`n" . r) ; *IF* our input string to match does not have the same length as what was found via the terminal, then this box is shown to tell us what went wrong. A_LoopField is the current queried item of the parsing from Loop Parse in AHK. "r" is the variable holding the output of the terminal window. The most likely expected result is nothing matches, so a length of 0 differs from a length of >0 (or in this case, >20 now). Previously, when short sequences were used, I was getting multiple grep matches -- or I had to configure the plaintext hex file differently, now I don't remember -- and I had a step for checking if it was multiple. E.g. if you grep checked for ABCDEF in the code, and it found 3 matches, returning ABCDEF`nABCDEF`nABCDEF I had a manipulation to make that work that has since been lost. Hence the weird approach of checking string length instead of actual content.
	;MsgBox(v) ; debugging that was just checking out what actually gets passed to the RunWaitOne command.
return
}
; there was a closing block comment here, but it should really enclose the code below as that's part of the debugging. The functions below are included in the EXE as of 1/25/26.
hexRead(file){ ; actually not sure this is ever used in debugging ,just copied it from a previous project that would parse a binary file into its hex values
    literalquote:=
    commandstring:="xxd -ps -u " . literalquote . file . literalquote
    result:=RunWaitOne(commandstring)
    return RegExReplace(result,"\s","")
}

RunWaitOne(command) { ; this will execute via command line. Whether this is terminal or cmd depends on the OS configuration. In System Settings -> Advanced, there is a dropdown to determine this. Section "Terminal" which for me on Windows 11 can be Windows Console Host, Windows Terminal, or "Let Windows Decide"
    shell := ComObject("WScript.Shell") ; opens up a terminal as the OS determines
    exec := shell.Exec(command) ; runs our command
    ;MsgBox(exec.StdOut.ReadAll())
    return exec.StdOut.ReadAll() ; returns our output from stdout for AHK to read
}
*/

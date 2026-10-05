import argparse
import re
# dependency retrieve via `pip install pyperclip`
parser = argparse.ArgumentParser()
parser.add_argument('--verbose','-v', action='store_true', help='This shows the logic of the parser so you can double check its work')
parser.add_argument('--flags','-f',action='store_true',help='Outputs flags so you can follow flag values through the steps, however note that explicit steps not included like unrolling a loop or when something returns from a call may not be accurate. Forces verbose output.')
parser.add_argument('--clip','-c', action='store_true', help='We will read from the clipboard rather than open a file.')
parser.add_argument('strings')
args = parser.parse_args()

if args.clip: # if the user is using the -c or --clip flag, we'll let this take precdence and read the clipboard. For those who don't have pyperclip, at least reading from a file on drive is possible.
    import pyperclip
    workingwith = pyperclip.paste()
else:
    try:
        pre_workingwith = open(str(args.strings)) # try to open the file given
    except: # if it fails, we print this error and close the script.
        print("This file wasn't recognized to be read. If you did not specify a file and meant to use the clipboard, use -c flag")
        exit()
    workingwith = pre_workingwith.read() # we only get here if the file opened, and at this point we copy it info a new variable for its text content
    pre_workingwith.close() # close the file nicely
items = workingwith.splitlines() # break this down into each of its lines
verbosetabbing = '{:<6}{:<20}{:<10}{:<10}{:<8}{:<3}{:<3}{:<3}{:<3}{:<3}' # this sets up nice columns in the console
        #line# Assembly T-Cycle M-Cycle Bytes Z N H C Original # this is the syntax the above would follow for column headers
noflagtabbing = '{:<6}{:<20}{:<10}{:<10}{:<8}{:<3}' # this sets up nice columns in the console if we are not going toshow the flags
linecount = 0
bytesInt = 0
t_cycle_max = 0
t_cycle_min = 0
acceptedresults = ""
ignoredresults = ""
zflag = "-" # remnants of a removed feature that tracked the current status of the flags line by line and marked if they had changed.
nflag = "-" # this feature was removed because it could not be 100% accurate as this script lacks the ability to dig into loops and macros and the functions asked by CALL
hflag = "-" # and any of those could have changed the flags on us
cflag = "-" # so instead we just show if the flag is updated by that very specific command
zsuffix = ""
nsuffix = ""
hsuffix = ""
csuffix = ""
dummycounts = 0
symbolExpectations = "[\w\(\)\\\\]"
numbervalue="-?((\$|%)?\d+|\$[a-fA-F0-9]+)(?!.*,)"

bytes={} # this is a map or array that was created from https://gbdev.io/gb-opcodes/optables/
bytes["nop"]=[1,4,4,"-","-","-","-","00"]
bytes["ld bc, n16"]=[3,12,12,"-","-","-","-","01"]
bytes["ld [bc], a"]=[1,8,8,"-","-","-","-","02"]
bytes["inc bc"]=[1,8,8,"-","-","-","-","03"]
bytes["inc b"]=[1,4,4,"Z","0","H","-","04"]
bytes["dec b"]=[1,4,4,"Z","1","H","-","05"]
bytes["ld b, n8"]=[2,8,8,"-","-","-","-","06"]
bytes["rlca"]=[1,4,4,"0","0","0","C","07"]
bytes["ld [a16], sp"]=[3,20,20,"-","-","-","-","08"]
bytes["add hl, bc"]=[1,8,8,"-","0","H","C","09"]
bytes["ld a, [bc]"]=[1,8,8,"-","-","-","-","0a"]
bytes["dec bc"]=[1,8,8,"-","-","-","-","0b"]
bytes["inc c"]=[1,4,4,"Z","0","H","-","0c"]
bytes["dec c"]=[1,4,4,"Z","1","H","-","0d"]
bytes["ld c, n8"]=[2,8,8,"-","-","-","-","0e"]
bytes["rrca"]=[1,4,4,"0","0","0","C","0f"]

bytes["stop n8"]=[2,4,4,"-","-","-","-","10"]
bytes["ld de, n16"]=[3,12,12,"-","-","-","-","11"]
bytes["ld [de], a"]=[1,8,8,"-","-","-","-","12"]
bytes["inc de"]=[1,8,8,"-","-","-","-","13"]
bytes["inc d"]=[1,4,4,"Z","0","H","-","14"]
bytes["dec d"]=[1,4,4,"Z","1","H","-","15"]
bytes["ld d, n8"]=[2,8,8,"-","-","-","-","16"]
bytes["rla"]=[1,4,4,"0","0","0","C","17"]
bytes["jr e8"]=[2,12,12,"-","-","-","-","18"]
bytes["add hl, de"]=[1,8,8,"-","0","H","C","19"]
bytes["ld a, [de]"]=[1,8,8,"-","-","-","-","1a"]
bytes["dec de"]=[1,8,8,"-","-","-","-","1b"]
bytes["inc e"]=[1,4,4,"Z","0","H","-","1c"]
bytes["dec e"]=[1,4,4,"Z","1","H","-","1d"]
bytes["ld e, n8"]=[2,8,8,"-","-","-","-","1e"]
bytes["rra"]=[1,4,4,"0","0","0","C","1f"]

bytes["jr nz, e8"]=[2,12,8,"-","-","-","-","20"]
bytes["ld hl, n16"]=[3,12,12,"-","-","-","-","21"]
bytes["ld [hl+], a"]=[1,8,8,"-","-","-","-","22"]
bytes["inc hl"]=[1,8,8,"-","-","-","-","23"]
bytes["inc h"]=[1,4,4,"Z","0","H","-","24"]
bytes["dec h"]=[1,4,4,"Z","1","H","-","25"]
bytes["ld h, n8"]=[2,8,8,"-","-","-","-","26"]
bytes["daa"]=[1,4,4,"Z","-","0","C","27"]
bytes["jr z, e8"]=[2,12,8,"-","-","-","-","28"]
bytes["add hl, hl"]=[1,8,8,"-","0","H","C","29"]
bytes["ld a, [hl+]"]=[1,8,8,"-","-","-","-","2a"]
bytes["dec hl"]=[1,8,8,"-","-","-","-","2b"]
bytes["inc l"]=[1,4,4,"Z","0","H","-","2c"]
bytes["dec l"]=[1,4,4,"Z","1","H","-","2d"]
bytes["ld l, n8"]=[2,8,8,"-","-","-","-","2e"]
bytes["cpl"]=[1,4,4,"-","1","1","-","2f"]

bytes["jr nc, e8"]=[2,12,8,"-","-","-","-","30"]
bytes["ld sp, n16"]=[3,12,12,"-","-","-","-","31"]
bytes["ld [hl-], a"]=[1,8,8,"-","-","-","-","32"]
bytes["inc sp"]=[1,8,8,"-","-","-","-","33"]
bytes["inc [hl]"]=[1,12,12,"Z","0","H","-","34"]
bytes["dec [hl]"]=[1,12,12,"Z","1","H","-","35"]
bytes["ld [hl], n8"]=[2,12,12,"-","-","-","-","36"]
bytes["scf"]=[1,4,4,"-","0","0","1","37"]
bytes["jr c, e8"]=[2,12,8,"-","-","-","-","38"]
bytes["add hl, sp"]=[1,8,8,"-","0","H","C","39"]
bytes["ld a, [hl-]"]=[1,8,8,"-","-","-","-","3a"]
bytes["dec sp"]=[1,8,8,"-","-","-","-","3b"]
bytes["inc a"]=[1,4,4,"Z","0","H","-","3c"]
bytes["dec a"]=[1,4,4,"Z","1","H","-","3d"]
bytes["ld a, n8"]=[2,8,8,"-","-","-","-","3e"]
bytes["ccf"]=[1,4,4,"-","0","0","C","3f"]

bytes["ld b, b"]=[1,4,4,"-","-","-","-","40"]
bytes["ld b, c"]=[1,4,4,"-","-","-","-","41"]
bytes["ld b, d"]=[1,4,4,"-","-","-","-","42"]
bytes["ld b, e"]=[1,4,4,"-","-","-","-","43"]
bytes["ld b, h"]=[1,4,4,"-","-","-","-","44"]
bytes["ld b, l"]=[1,4,4,"-","-","-","-","45"]
bytes["ld b, [hl]"]=[1,8,8,"-","-","-","-","46"]
bytes["ld b, a"]=[1,4,4,"-","-","-","-","47"]
bytes["ld c, b"]=[1,4,4,"-","-","-","-","48"]
bytes["ld c, c"]=[1,4,4,"-","-","-","-","49"]
bytes["ld c, d"]=[1,4,4,"-","-","-","-","4a"]
bytes["ld c, e"]=[1,4,4,"-","-","-","-","4b"]
bytes["ld c, h"]=[1,4,4,"-","-","-","-","4c"]
bytes["ld c, l"]=[1,4,4,"-","-","-","-","4d"]
bytes["ld c, [hl]"]=[1,8,8,"-","-","-","-","4e"]
bytes["ld c, a"]=[1,4,4,"-","-","-","-","4f"]

bytes["ld d, b"]=[1,4,4,"-","-","-","-","50"]
bytes["ld d, c"]=[1,4,4,"-","-","-","-","51"]
bytes["ld d, d"]=[1,4,4,"-","-","-","-","52"]
bytes["ld d, e"]=[1,4,4,"-","-","-","-","53"]
bytes["ld d, h"]=[1,4,4,"-","-","-","-","54"]
bytes["ld d, l"]=[1,4,4,"-","-","-","-","55"]
bytes["ld d, [hl]"]=[1,8,8,"-","-","-","-","56"]
bytes["ld d, a"]=[1,4,4,"-","-","-","-","57"]
bytes["ld e, b"]=[1,4,4,"-","-","-","-","58"]
bytes["ld e, c"]=[1,4,4,"-","-","-","-","59"]
bytes["ld e, d"]=[1,4,4,"-","-","-","-","5a"]
bytes["ld e, e"]=[1,4,4,"-","-","-","-","5b"]
bytes["ld e, h"]=[1,4,4,"-","-","-","-","5c"]
bytes["ld e, l"]=[1,4,4,"-","-","-","-","5d"]
bytes["ld e, [hl]"]=[1,8,8,"-","-","-","-","5e"]
bytes["ld e, a"]=[1,4,4,"-","-","-","-","5f"]

bytes["ld h, b"]=[1,4,4,"-","-","-","-","60"]
bytes["ld h, c"]=[1,4,4,"-","-","-","-","61"]
bytes["ld h, d"]=[1,4,4,"-","-","-","-","62"]
bytes["ld h, e"]=[1,4,4,"-","-","-","-","63"]
bytes["ld h, h"]=[1,4,4,"-","-","-","-","64"]
bytes["ld h, l"]=[1,4,4,"-","-","-","-","65"]
bytes["ld h, [hl]"]=[1,8,8,"-","-","-","-","66"]
bytes["ld h, a"]=[1,4,4,"-","-","-","-","67"]
bytes["ld l, b"]=[1,4,4,"-","-","-","-","68"]
bytes["ld l, c"]=[1,4,4,"-","-","-","-","69"]
bytes["ld l, d"]=[1,4,4,"-","-","-","-","6a"]
bytes["ld l, e"]=[1,4,4,"-","-","-","-","6b"]
bytes["ld l, h"]=[1,4,4,"-","-","-","-","6c"]
bytes["ld l, l"]=[1,4,4,"-","-","-","-","6d"]
bytes["ld l, [hl]"]=[1,8,8,"-","-","-","-","6e"]
bytes["ld l, a"]=[1,4,4,"-","-","-","-","6f"]

bytes["ld [hl], b"]=[1,8,8,"-","-","-","-","70"]
bytes["ld [hl], c"]=[1,8,8,"-","-","-","-","71"]
bytes["ld [hl], d"]=[1,8,8,"-","-","-","-","72"]
bytes["ld [hl], e"]=[1,8,8,"-","-","-","-","73"]
bytes["ld [hl], h"]=[1,8,8,"-","-","-","-","74"]
bytes["ld [hl], l"]=[1,8,8,"-","-","-","-","75"]
bytes["halt"]=[1,4,4,"-","-","-","-","76"]
bytes["ld [hl], a"]=[1,8,8,"-","-","-","-","77"]
bytes["ld a, b"]=[1,4,4,"-","-","-","-","78"]
bytes["ld a, c"]=[1,4,4,"-","-","-","-","79"]
bytes["ld a, d"]=[1,4,4,"-","-","-","-","7a"]
bytes["ld a, e"]=[1,4,4,"-","-","-","-","7b"]
bytes["ld a, h"]=[1,4,4,"-","-","-","-","7c"]
bytes["ld a, l"]=[1,4,4,"-","-","-","-","7d"]
bytes["ld a, [hl]"]=[1,8,8,"-","-","-","-","7e"]
bytes["ld a, a"]=[1,4,4,"-","-","-","-","7f"]

bytes["add a, b"]=[1,4,4,"Z","0","H","C","80"]
bytes["add a, c"]=[1,4,4,"Z","0","H","C","81"]
bytes["add a, d"]=[1,4,4,"Z","0","H","C","82"]
bytes["add a, e"]=[1,4,4,"Z","0","H","C","83"]
bytes["add a, h"]=[1,4,4,"Z","0","H","C","84"]
bytes["add a, l"]=[1,4,4,"Z","0","H","C","85"]
bytes["add a, [hl]"]=[1,8,8,"Z","0","H","C","86"]
bytes["add a, a"]=[1,4,4,"Z","0","H","C","87"]
bytes["adc a, b"]=[1,4,4,"Z","0","H","C","88"]
bytes["adc a, c"]=[1,4,4,"Z","0","H","C","89"]
bytes["adc a, d"]=[1,4,4,"Z","0","H","C","8a"]
bytes["adc a, e"]=[1,4,4,"Z","0","H","C","8b"]
bytes["adc a, h"]=[1,4,4,"Z","0","H","C","8c"]
bytes["adc a, l"]=[1,4,4,"Z","0","H","C","8d"]
bytes["adc a, [hl]"]=[1,8,8,"Z","0","H","C","8e"]
bytes["adc a, a"]=[1,4,4,"Z","0","H","C","8f"]

bytes["sub a, b"]=[1,4,4,"Z","1","H","C","90"]
bytes["sub a, c"]=[1,4,4,"Z","1","H","C","91"]
bytes["sub a, d"]=[1,4,4,"Z","1","H","C","92"]
bytes["sub a, e"]=[1,4,4,"Z","1","H","C","93"]
bytes["sub a, h"]=[1,4,4,"Z","1","H","C","94"]
bytes["sub a, l"]=[1,4,4,"Z","1","H","C","95"]
bytes["sub a, [hl]"]=[1,8,8,"Z","1","H","C","96"]
bytes["sub a, a"]=[1,4,4,"1","1","0","0","97"]
bytes["sbc a, b"]=[1,4,4,"Z","1","H","C","98"]
bytes["sbc a, c"]=[1,4,4,"Z","1","H","C","99"]
bytes["sbc a, d"]=[1,4,4,"Z","1","H","C","9a"]
bytes["sbc a, e"]=[1,4,4,"Z","1","H","C","9b"]
bytes["sbc a, h"]=[1,4,4,"Z","1","H","C","9c"]
bytes["sbc a, l"]=[1,4,4,"Z","1","H","C","9d"]
bytes["sbc a, [hl]"]=[1,8,8,"Z","1","H","C","9e"]
bytes["sbc a, a"]=[1,4,4,"Z","1","H","-","9f"]

bytes["and a, b"]=[1,4,4,"Z","0","1","0","a0"]
bytes["and a, c"]=[1,4,4,"Z","0","1","0","a1"]
bytes["and a, d"]=[1,4,4,"Z","0","1","0","a2"]
bytes["and a, e"]=[1,4,4,"Z","0","1","0","a3"]
bytes["and a, h"]=[1,4,4,"Z","0","1","0","a4"]
bytes["and a, l"]=[1,4,4,"Z","0","1","0","a5"]
bytes["and a, [hl]"]=[1,8,8,"Z","0","1","0","a6"]
bytes["and a, a"]=[1,4,4,"Z","0","1","0","a7"]
bytes["xor a, b"]=[1,4,4,"Z","0","0","0","a8"]
bytes["xor a, c"]=[1,4,4,"Z","0","0","0","a9"]
bytes["xor a, d"]=[1,4,4,"Z","0","0","0","aa"]
bytes["xor a, e"]=[1,4,4,"Z","0","0","0","ab"]
bytes["xor a, h"]=[1,4,4,"Z","0","0","0","ac"]
bytes["xor a, l"]=[1,4,4,"Z","0","0","0","ad"]
bytes["xor a, [hl]"]=[1,8,8,"Z","0","0","0","ae"]
bytes["xor a, a"]=[1,4,4,"1","0","0","0","af"]

bytes["or a, b"]=[1,4,4,"Z","0","0","0","b0"]
bytes["or a, c"]=[1,4,4,"Z","0","0","0","b1"]
bytes["or a, d"]=[1,4,4,"Z","0","0","0","b2"]
bytes["or a, e"]=[1,4,4,"Z","0","0","0","b3"]
bytes["or a, h"]=[1,4,4,"Z","0","0","0","b4"]
bytes["or a, l"]=[1,4,4,"Z","0","0","0","b5"]
bytes["or a, [hl]"]=[1,8,8,"Z","0","0","0","b6"]
bytes["or a, a"]=[1,4,4,"Z","0","0","0","b7"]
bytes["cp a, b"]=[1,4,4,"Z","1","H","C","b8"]
bytes["cp a, c"]=[1,4,4,"Z","1","H","C","b9"]
bytes["cp a, d"]=[1,4,4,"Z","1","H","C","ba"]
bytes["cp a, e"]=[1,4,4,"Z","1","H","C","bb"]
bytes["cp a, h"]=[1,4,4,"Z","1","H","C","bc"]
bytes["cp a, l"]=[1,4,4,"Z","1","H","C","bd"]
bytes["cp a, [hl]"]=[1,8,8,"Z","1","H","C","be"]
bytes["cp a, a"]=[1,4,4,"1","1","0","0","bf"]

bytes["ret nz"]=[1,20,8,"-","-","-","-","c0"]
bytes["pop bc"]=[1,12,12,"-","-","-","-","c1"]
bytes["jp nz, a16"]=[3,16,12,"-","-","-","-","c2"]
bytes["jp a16"]=[3,16,16,"-","-","-","-","c3"]
bytes["call nz, a16"]=[3,24,12,"-","-","-","-","c4"]
bytes["push bc"]=[1,16,16,"-","-","-","-","c5"]
bytes["add a, n8"]=[2,8,8,"Z","0","H","C","c6"]
bytes["rst $00"]=[1,16,16,"-","-","-","-","c7"]
bytes["ret z"]=[1,20,8,"-","-","-","-","c8"]
bytes["ret"]=[1,16,16,"-","-","-","-","c9"]
bytes["jp z, a16"]=[3,16,12,"-","-","-","-","ca"]
bytes["prefix"]=[1,4,4,"-","-","-","-","cb"]
bytes["call z, a16"]=[3,24,12,"-","-","-","-","cc"]
bytes["call a16"]=[3,24,24,"-","-","-","-","cd"]
bytes["adc a, n8"]=[2,8,8,"Z","0","H","C","ce"]
bytes["rst $08"]=[1,16,16,"-","-","-","-","cf"]

bytes["ret nc"]=[1,20,8,"-","-","-","-","d0"]
bytes["pop de"]=[1,12,12,"-","-","-","-","d1"]
bytes["jp nc, a16"]=[3,16,12,"-","-","-","-","d2"]
#—,"d3" 
bytes["call nc, a16"]=[3,24,12,"-","-","-","-","d4"]
bytes["push de"]=[1,16,16,"-","-","-","-","d5"]
bytes["sub a, n8"]=[2,8,8,"Z","1","H","C","d6"]
bytes["rst $10"]=[1,16,16,"-","-","-","-","d7"]
bytes["ret c"]=[1,20,8,"-","-","-","-","d8"]
bytes["reti"]=[1,16,16,"-","-","-","-","d9"]
bytes["jp c, a16"]=[3,16,12,"-","-","-","-","da"]
#—,"db" 
bytes["call c, a16"]=[3,24,12,"-","-","-","-","dc"]
#—,"dd" 
bytes["sbc a, n8"]=[2,8,8,"Z","1","H","C","de"]
bytes["rst $18"]=[1,16,16,"-","-","-","-","df"]

bytes["ldh [a8], a"]=[2,12,12,"-","-","-","-","e0"]
bytes["pop hl"]=[1,12,12,"-","-","-","-","e1"]
bytes["ldh [c], a"]=[1,8,8,"-","-","-","-","e2"]
#—,"e3" 
#—,"e4" 
bytes["push hl"]=[1,16,16,"-","-","-","-","e5"]
bytes["and a, n8"]=[2,8,8,"Z","0","1","0","e6"]
bytes["rst $20"]=[1,16,16,"-","-","-","-","e7"]
bytes["add sp, e8"]=[2,16,16,"0","0","H","C","e8"]
bytes["jp hl"]=[1,4,4,"-","-","-","-","e9"]
bytes["ld [a16], a"]=[3,16,16,"-","-","-","-","ea"]
#—,"eb" 
#—,"ec" 
#—,"ed" 
bytes["xor a, n8"]=[2,8,8,"Z","0","0","0","ee"]
bytes["rst $28"]=[1,16,16,"-","-","-","-","ef"]

bytes["ldh a, [a8]"]=[2,12,12,"-","-","-","-","f0"]
bytes["pop af"]=[1,12,12,"Z","N","H","C","f1"]
bytes["ldh a, [c]"]=[1,8,8,"-","-","-","-","f2"]
bytes["di"]=[1,4,4,"-","-","-","-","f3"]
#—,"f4" 
bytes["push af"]=[1,16,16,"-","-","-","-","f5"]
bytes["or a, n8"]=[2,8,8,"Z","0","0","0","f6"]
bytes["rst $30"]=[1,16,16,"-","-","-","-","f7"]
bytes["ld hl, sp + e8"]=[2,12,12,"0","0","H","C","f8"]
bytes["ld sp, hl"]=[1,8,8,"-","-","-","-","f9"]
bytes["ld a, [a16]"]=[3,16,16,"-","-","-","-","fa"]
bytes["ei"]=[1,4,4,"-","-","-","-","fb"]
#—,"fc" 
#—,"fd" 
bytes["cp a, n8"]=[2,8,8,"Z","1","H","C","fe"]
bytes["rst $38"]=[1,16,16,"-","-","-","-","ff"]

bytes["rlc b"]=[2,8,8,"Z","0","0","C","cb.00"]
bytes["rlc c"]=[2,8,8,"Z","0","0","C","cb.01"]
bytes["rlc d"]=[2,8,8,"Z","0","0","C","cb.02"]
bytes["rlc e"]=[2,8,8,"Z","0","0","C","cb.03"]
bytes["rlc h"]=[2,8,8,"Z","0","0","C","cb.04"]
bytes["rlc l"]=[2,8,8,"Z","0","0","C","cb.05"]
bytes["rlc [hl]"]=[2,16,16,"Z","0","0","C","cb.06"]
bytes["rlc a"]=[2,8,8,"Z","0","0","C","cb.07"]
bytes["rrc b"]=[2,8,8,"Z","0","0","C","cb.08"]
bytes["rrc c"]=[2,8,8,"Z","0","0","C","cb.09"]
bytes["rrc d"]=[2,8,8,"Z","0","0","C","cb.0a"]
bytes["rrc e"]=[2,8,8,"Z","0","0","C","cb.0b"]
bytes["rrc h"]=[2,8,8,"Z","0","0","C","cb.0c"]
bytes["rrc l"]=[2,8,8,"Z","0","0","C","cb.0d"]
bytes["rrc [hl]"]=[2,16,16,"Z","0","0","C","cb.0e"]
bytes["rrc a"]=[2,8,8,"Z","0","0","C","cb.0f"]

bytes["rl b"]=[2,8,8,"Z","0","0","C","cb.10"]
bytes["rl c"]=[2,8,8,"Z","0","0","C","cb.11"]
bytes["rl d"]=[2,8,8,"Z","0","0","C","cb.12"]
bytes["rl e"]=[2,8,8,"Z","0","0","C","cb.13"]
bytes["rl h"]=[2,8,8,"Z","0","0","C","cb.14"]
bytes["rl l"]=[2,8,8,"Z","0","0","C","cb.15"]
bytes["rl [hl]"]=[2,16,16,"Z","0","0","C","cb.16"]
bytes["rl a"]=[2,8,8,"Z","0","0","C","cb.17"]
bytes["rr b"]=[2,8,8,"Z","0","0","C","cb.18"]
bytes["rr c"]=[2,8,8,"Z","0","0","C","cb.19"]
bytes["rr d"]=[2,8,8,"Z","0","0","C","cb.1a"]
bytes["rr e"]=[2,8,8,"Z","0","0","C","cb.1b"]
bytes["rr h"]=[2,8,8,"Z","0","0","C","cb.1c"]
bytes["rr l"]=[2,8,8,"Z","0","0","C","cb.1d"]
bytes["rr [hl]"]=[2,16,16,"Z","0","0","C","cb.1e"]
bytes["rr a"]=[2,8,8,"Z","0","0","C","cb.1f"]

bytes["sla b"]=[2,8,8,"Z","0","0","C","cb.20"]
bytes["sla c"]=[2,8,8,"Z","0","0","C","cb.21"]
bytes["sla d"]=[2,8,8,"Z","0","0","C","cb.22"]
bytes["sla e"]=[2,8,8,"Z","0","0","C","cb.23"]
bytes["sla h"]=[2,8,8,"Z","0","0","C","cb.24"]
bytes["sla l"]=[2,8,8,"Z","0","0","C","cb.25"]
bytes["sla [hl]"]=[2,16,16,"Z","0","0","C","cb.26"]
bytes["sla a"]=[2,8,8,"Z","0","0","C","cb.27"]
bytes["sra b"]=[2,8,8,"Z","0","0","C","cb.28"]
bytes["sra c"]=[2,8,8,"Z","0","0","C","cb.29"]
bytes["sra d"]=[2,8,8,"Z","0","0","C","cb.2a"]
bytes["sra e"]=[2,8,8,"Z","0","0","C","cb.2b"]
bytes["sra h"]=[2,8,8,"Z","0","0","C","cb.2c"]
bytes["sra l"]=[2,8,8,"Z","0","0","C","cb.2d"]
bytes["sra [hl]"]=[2,16,16,"Z","0","0","C","cb.2e"]
bytes["sra a"]=[2,8,8,"Z","0","0","C","cb.2f"]

bytes["swap b"]=[2,8,8,"Z","0","0","0","cb.30"]
bytes["swap c"]=[2,8,8,"Z","0","0","0","cb.31"]
bytes["swap d"]=[2,8,8,"Z","0","0","0","cb.32"]
bytes["swap e"]=[2,8,8,"Z","0","0","0","cb.33"]
bytes["swap h"]=[2,8,8,"Z","0","0","0","cb.34"]
bytes["swap l"]=[2,8,8,"Z","0","0","0","cb.35"]
bytes["swap [hl]"]=[2,16,16,"Z","0","0","0","cb.36"]
bytes["swap a"]=[2,8,8,"Z","0","0","0","cb.37"]
bytes["srl b"]=[2,8,8,"Z","0","0","C","cb.38"]
bytes["srl c"]=[2,8,8,"Z","0","0","C","cb.39"]
bytes["srl d"]=[2,8,8,"Z","0","0","C","cb.3a"]
bytes["srl e"]=[2,8,8,"Z","0","0","C","cb.3b"]
bytes["srl h"]=[2,8,8,"Z","0","0","C","cb.3c"]
bytes["srl l"]=[2,8,8,"Z","0","0","C","cb.3d"]
bytes["srl [hl]"]=[2,16,16,"Z","0","0","C","cb.3e"]
bytes["srl a"]=[2,8,8,"Z","0","0","C","cb.3f"]

bytes["bit 0, b"]=[2,8,8,"Z","0","1","-","cb.40"]
bytes["bit 0, c"]=[2,8,8,"Z","0","1","-","cb.41"]
bytes["bit 0, d"]=[2,8,8,"Z","0","1","-","cb.42"]
bytes["bit 0, e"]=[2,8,8,"Z","0","1","-","cb.43"]
bytes["bit 0, h"]=[2,8,8,"Z","0","1","-","cb.44"]
bytes["bit 0, l"]=[2,8,8,"Z","0","1","-","cb.45"]
bytes["bit 0, [hl]"]=[2,12,12,"Z","0","1","-","cb.46"]
bytes["bit 0, a"]=[2,8,8,"Z","0","1","-","cb.47"]
bytes["bit 1, b"]=[2,8,8,"Z","0","1","-","cb.48"]
bytes["bit 1, c"]=[2,8,8,"Z","0","1","-","cb.49"]
bytes["bit 1, d"]=[2,8,8,"Z","0","1","-","cb.4a"]
bytes["bit 1, e"]=[2,8,8,"Z","0","1","-","cb.4b"]
bytes["bit 1, h"]=[2,8,8,"Z","0","1","-","cb.4c"]
bytes["bit 1, l"]=[2,8,8,"Z","0","1","-","cb.4d"]
bytes["bit 1, [hl]"]=[2,12,12,"Z","0","1","-","cb.4e"]
bytes["bit 1, a"]=[2,8,8,"Z","0","1","-","cb.4f"]

bytes["bit 2, b"]=[2,8,8,"Z","0","1","-","cb.50"]
bytes["bit 2, c"]=[2,8,8,"Z","0","1","-","cb.51"]
bytes["bit 2, d"]=[2,8,8,"Z","0","1","-","cb.52"]
bytes["bit 2, e"]=[2,8,8,"Z","0","1","-","cb.53"]
bytes["bit 2, h"]=[2,8,8,"Z","0","1","-","cb.54"]
bytes["bit 2, l"]=[2,8,8,"Z","0","1","-","cb.55"]
bytes["bit 2, [hl]"]=[2,12,12,"Z","0","1","-","cb.56"]
bytes["bit 2, a"]=[2,8,8,"Z","0","1","-","cb.57"]
bytes["bit 3, b"]=[2,8,8,"Z","0","1","-","cb.58"]
bytes["bit 3, c"]=[2,8,8,"Z","0","1","-","cb.59"]
bytes["bit 3, d"]=[2,8,8,"Z","0","1","-","cb.5a"]
bytes["bit 3, e"]=[2,8,8,"Z","0","1","-","cb.5b"]
bytes["bit 3, h"]=[2,8,8,"Z","0","1","-","cb.5c"]
bytes["bit 3, l"]=[2,8,8,"Z","0","1","-","cb.5d"]
bytes["bit 3, [hl]"]=[2,12,12,"Z","0","1","-","cb.5e"]
bytes["bit 3, a"]=[2,8,8,"Z","0","1","-","cb.5f"]

bytes["bit 4, b"]=[2,8,8,"Z","0","1","-","cb.60"]
bytes["bit 4, c"]=[2,8,8,"Z","0","1","-","cb.61"]
bytes["bit 4, d"]=[2,8,8,"Z","0","1","-","cb.62"]
bytes["bit 4, e"]=[2,8,8,"Z","0","1","-","cb.63"]
bytes["bit 4, h"]=[2,8,8,"Z","0","1","-","cb.64"]
bytes["bit 4, l"]=[2,8,8,"Z","0","1","-","cb.65"]
bytes["bit 4, [hl]"]=[2,12,12,"Z","0","1","-","cb.66"]
bytes["bit 4, a"]=[2,8,8,"Z","0","1","-","cb.67"]
bytes["bit 5, b"]=[2,8,8,"Z","0","1","-","cb.68"]
bytes["bit 5, c"]=[2,8,8,"Z","0","1","-","cb.69"]
bytes["bit 5, d"]=[2,8,8,"Z","0","1","-","cb.6a"]
bytes["bit 5, e"]=[2,8,8,"Z","0","1","-","cb.6b"]
bytes["bit 5, h"]=[2,8,8,"Z","0","1","-","cb.6c"]
bytes["bit 5, l"]=[2,8,8,"Z","0","1","-","cb.6d"]
bytes["bit 5, [hl]"]=[2,12,12,"Z","0","1","-","cb.6e"]
bytes["bit 5, a"]=[2,8,8,"Z","0","1","-","cb.6f"]

bytes["bit 6, b"]=[2,8,8,"Z","0","1","-","cb.70"]
bytes["bit 6, c"]=[2,8,8,"Z","0","1","-","cb.71"]
bytes["bit 6, d"]=[2,8,8,"Z","0","1","-","cb.72"]
bytes["bit 6, e"]=[2,8,8,"Z","0","1","-","cb.73"]
bytes["bit 6, h"]=[2,8,8,"Z","0","1","-","cb.74"]
bytes["bit 6, l"]=[2,8,8,"Z","0","1","-","cb.75"]
bytes["bit 6, [hl]"]=[2,12,12,"Z","0","1","-","cb.76"]
bytes["bit 6, a"]=[2,8,8,"Z","0","1","-","cb.77"]
bytes["bit 7, b"]=[2,8,8,"Z","0","1","-","cb.78"]
bytes["bit 7, c"]=[2,8,8,"Z","0","1","-","cb.79"]
bytes["bit 7, d"]=[2,8,8,"Z","0","1","-","cb.7a"]
bytes["bit 7, e"]=[2,8,8,"Z","0","1","-","cb.7b"]
bytes["bit 7, h"]=[2,8,8,"Z","0","1","-","cb.7c"]
bytes["bit 7, l"]=[2,8,8,"Z","0","1","-","cb.7d"]
bytes["bit 7, [hl]"]=[2,12,12,"Z","0","1","-","cb.7e"]
bytes["bit 7, a"]=[2,8,8,"Z","0","1","-","cb.7f"]

bytes["res 0, b"]=[2,8,8,"-","-","-","-","cb.80"]
bytes["res 0, c"]=[2,8,8,"-","-","-","-","cb.81"]
bytes["res 0, d"]=[2,8,8,"-","-","-","-","cb.82"]
bytes["res 0, e"]=[2,8,8,"-","-","-","-","cb.83"]
bytes["res 0, h"]=[2,8,8,"-","-","-","-","cb.84"]
bytes["res 0, l"]=[2,8,8,"-","-","-","-","cb.85"]
bytes["res 0, [hl]"]=[2,16,16,"-","-","-","-","cb.86"]
bytes["res 0, a"]=[2,8,8,"-","-","-","-","cb.87"]
bytes["res 1, b"]=[2,8,8,"-","-","-","-","cb.88"]
bytes["res 1, c"]=[2,8,8,"-","-","-","-","cb.89"]
bytes["res 1, d"]=[2,8,8,"-","-","-","-","cb.8a"]
bytes["res 1, e"]=[2,8,8,"-","-","-","-","cb.8b"]
bytes["res 1, h"]=[2,8,8,"-","-","-","-","cb.8c"]
bytes["res 1, l"]=[2,8,8,"-","-","-","-","cb.8d"]
bytes["res 1, [hl]"]=[2,16,16,"-","-","-","-","cb.8e"]
bytes["res 1, a"]=[2,8,8,"-","-","-","-","cb.8f"]

bytes["res 2, b"]=[2,8,8,"-","-","-","-","cb.90"]
bytes["res 2, c"]=[2,8,8,"-","-","-","-","cb.91"]
bytes["res 2, d"]=[2,8,8,"-","-","-","-","cb.92"]
bytes["res 2, e"]=[2,8,8,"-","-","-","-","cb.93"]
bytes["res 2, h"]=[2,8,8,"-","-","-","-","cb.94"]
bytes["res 2, l"]=[2,8,8,"-","-","-","-","cb.95"]
bytes["res 2, [hl]"]=[2,16,16,"-","-","-","-","cb.96"]
bytes["res 2, a"]=[2,8,8,"-","-","-","-","cb.97"]
bytes["res 3, b"]=[2,8,8,"-","-","-","-","cb.98"]
bytes["res 3, c"]=[2,8,8,"-","-","-","-","cb.99"]
bytes["res 3, d"]=[2,8,8,"-","-","-","-","cb.9a"]
bytes["res 3, e"]=[2,8,8,"-","-","-","-","cb.9b"]
bytes["res 3, h"]=[2,8,8,"-","-","-","-","cb.9c"]
bytes["res 3, l"]=[2,8,8,"-","-","-","-","cb.9d"]
bytes["res 3, [hl]"]=[2,16,16,"-","-","-","-","cb.9e"]
bytes["res 3, a"]=[2,8,8,"-","-","-","-","cb.9f"]

bytes["res 4, b"]=[2,8,8,"-","-","-","-","cb.a0"]
bytes["res 4, c"]=[2,8,8,"-","-","-","-","cb.a1"]
bytes["res 4, d"]=[2,8,8,"-","-","-","-","cb.a2"]
bytes["res 4, e"]=[2,8,8,"-","-","-","-","cb.a3"]
bytes["res 4, h"]=[2,8,8,"-","-","-","-","cb.a4"]
bytes["res 4, l"]=[2,8,8,"-","-","-","-","cb.a5"]
bytes["res 4, [hl]"]=[2,16,16,"-","-","-","-","cb.a6"]
bytes["res 4, a"]=[2,8,8,"-","-","-","-","cb.a7"]
bytes["res 5, b"]=[2,8,8,"-","-","-","-","cb.a8"]
bytes["res 5, c"]=[2,8,8,"-","-","-","-","cb.a9"]
bytes["res 5, d"]=[2,8,8,"-","-","-","-","cb.aa"]
bytes["res 5, e"]=[2,8,8,"-","-","-","-","cb.ab"]
bytes["res 5, h"]=[2,8,8,"-","-","-","-","cb.ac"]
bytes["res 5, l"]=[2,8,8,"-","-","-","-","cb.ad"]
bytes["res 5, [hl]"]=[2,16,16,"-","-","-","-","cb.ae"]
bytes["res 5, a"]=[2,8,8,"-","-","-","-","cb.af"]

bytes["res 6, b"]=[2,8,8,"-","-","-","-","cb.b0"]
bytes["res 6, c"]=[2,8,8,"-","-","-","-","cb.b1"]
bytes["res 6, d"]=[2,8,8,"-","-","-","-","cb.b2"]
bytes["res 6, e"]=[2,8,8,"-","-","-","-","cb.b3"]
bytes["res 6, h"]=[2,8,8,"-","-","-","-","cb.b4"]
bytes["res 6, l"]=[2,8,8,"-","-","-","-","cb.b5"]
bytes["res 6, [hl]"]=[2,16,16,"-","-","-","-","cb.b6"]
bytes["res 6, a"]=[2,8,8,"-","-","-","-","cb.b7"]
bytes["res 7, b"]=[2,8,8,"-","-","-","-","cb.b8"]
bytes["res 7, c"]=[2,8,8,"-","-","-","-","cb.b9"]
bytes["res 7, d"]=[2,8,8,"-","-","-","-","cb.ba"]
bytes["res 7, e"]=[2,8,8,"-","-","-","-","cb.bb"]
bytes["res 7, h"]=[2,8,8,"-","-","-","-","cb.bc"]
bytes["res 7, l"]=[2,8,8,"-","-","-","-","cb.bd"]
bytes["res 7, [hl]"]=[2,16,16,"-","-","-","-","cb.be"]
bytes["res 7, a"]=[2,8,8,"-","-","-","-","cb.bf"]

bytes["set 0, b"]=[2,8,8,"-","-","-","-","cb.c0"]
bytes["set 0, c"]=[2,8,8,"-","-","-","-","cb.c1"]
bytes["set 0, d"]=[2,8,8,"-","-","-","-","cb.c2"]
bytes["set 0, e"]=[2,8,8,"-","-","-","-","cb.c3"]
bytes["set 0, h"]=[2,8,8,"-","-","-","-","cb.c4"]
bytes["set 0, l"]=[2,8,8,"-","-","-","-","cb.c5"]
bytes["set 0, [hl]"]=[2,16,16,"-","-","-","-","cb.c6"]
bytes["set 0, a"]=[2,8,8,"-","-","-","-","cb.c7"]
bytes["set 1, b"]=[2,8,8,"-","-","-","-","cb.c8"]
bytes["set 1, c"]=[2,8,8,"-","-","-","-","cb.c9"]
bytes["set 1, d"]=[2,8,8,"-","-","-","-","cb.ca"]
bytes["set 1, e"]=[2,8,8,"-","-","-","-","cb.cb"]
bytes["set 1, h"]=[2,8,8,"-","-","-","-","cb.cc"]
bytes["set 1, l"]=[2,8,8,"-","-","-","-","cb.cd"]
bytes["set 1, [hl]"]=[2,16,16,"-","-","-","-","cb.ce"]
bytes["set 1, a"]=[2,8,8,"-","-","-","-","cb.cf"]

bytes["set 2, b"]=[2,8,8,"-","-","-","-","cb.d0"]
bytes["set 2, c"]=[2,8,8,"-","-","-","-","cb.d1"]
bytes["set 2, d"]=[2,8,8,"-","-","-","-","cb.d2"]
bytes["set 2, e"]=[2,8,8,"-","-","-","-","cb.d3"]
bytes["set 2, h"]=[2,8,8,"-","-","-","-","cb.d4"]
bytes["set 2, l"]=[2,8,8,"-","-","-","-","cb.d5"]
bytes["set 2, [hl]"]=[2,16,16,"-","-","-","-","cb.d6"]
bytes["set 2, a"]=[2,8,8,"-","-","-","-","cb.d7"]
bytes["set 3, b"]=[2,8,8,"-","-","-","-","cb.d8"]
bytes["set 3, c"]=[2,8,8,"-","-","-","-","cb.d9"]
bytes["set 3, d"]=[2,8,8,"-","-","-","-","cb.da"]
bytes["set 3, e"]=[2,8,8,"-","-","-","-","cb.db"]
bytes["set 3, h"]=[2,8,8,"-","-","-","-","cb.dc"]
bytes["set 3, l"]=[2,8,8,"-","-","-","-","cb.dd"]
bytes["set 3, [hl]"]=[2,16,16,"-","-","-","-","cb.de"]
bytes["set 3, a"]=[2,8,8,"-","-","-","-","cb.df"]

bytes["set 4, b"]=[2,8,8,"-","-","-","-","cb.e0"]
bytes["set 4, c"]=[2,8,8,"-","-","-","-","cb.e1"]
bytes["set 4, d"]=[2,8,8,"-","-","-","-","cb.e2"]
bytes["set 4, e"]=[2,8,8,"-","-","-","-","cb.e3"]
bytes["set 4, h"]=[2,8,8,"-","-","-","-","cb.e4"]
bytes["set 4, l"]=[2,8,8,"-","-","-","-","cb.e5"]
bytes["set 4, [hl]"]=[2,16,16,"-","-","-","-","cb.e6"]
bytes["set 4, a"]=[2,8,8,"-","-","-","-","cb.e7"]
bytes["set 5, b"]=[2,8,8,"-","-","-","-","cb.e8"]
bytes["set 5, c"]=[2,8,8,"-","-","-","-","cb.e9"]
bytes["set 5, d"]=[2,8,8,"-","-","-","-","cb.ea"]
bytes["set 5, e"]=[2,8,8,"-","-","-","-","cb.eb"]
bytes["set 5, h"]=[2,8,8,"-","-","-","-","cb.ec"]
bytes["set 5, l"]=[2,8,8,"-","-","-","-","cb.ed"]
bytes["set 5, [hl]"]=[2,16,16,"-","-","-","-","cb.ee"]
bytes["set 5, a"]=[2,8,8,"-","-","-","-","cb.ef"]

bytes["set 6, b"]=[2,8,8,"-","-","-","-","cb.f0"]
bytes["set 6, c"]=[2,8,8,"-","-","-","-","cb.f1"]
bytes["set 6, d"]=[2,8,8,"-","-","-","-","cb.f2"]
bytes["set 6, e"]=[2,8,8,"-","-","-","-","cb.f3"]
bytes["set 6, h"]=[2,8,8,"-","-","-","-","cb.f4"]
bytes["set 6, l"]=[2,8,8,"-","-","-","-","cb.f5"]
bytes["set 6, [hl]"]=[2,16,16,"-","-","-","-","cb.f6"]
bytes["set 6, a"]=[2,8,8,"-","-","-","-","cb.f7"]
bytes["set 7, b"]=[2,8,8,"-","-","-","-","cb.f8"]
bytes["set 7, c"]=[2,8,8,"-","-","-","-","cb.f9"]
bytes["set 7, d"]=[2,8,8,"-","-","-","-","cb.fa"]
bytes["set 7, e"]=[2,8,8,"-","-","-","-","cb.fb"]
bytes["set 7, h"]=[2,8,8,"-","-","-","-","cb.fc"]
bytes["set 7, l"]=[2,8,8,"-","-","-","-","cb.fd"]
bytes["set 7, [hl]"]=[2,16,16,"-","-","-","-","cb.fe"]
bytes["set 7, a"]=[2,8,8,"-","-","-","-","cb.ff"]

# below are psuedo opcodes where using a constant name obfuscates what the digit 0-7 should have been for the first "operand". Because a debug tool wanted to get the exact bytes, it would have been erronenous to assume any specific number as the byte opcode is specific to which bit this works on.

bytes["set n, b"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, c"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, d"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, e"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, h"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, l"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["set n, [hl]"]=[2,16,16,"-","-","-","-","cb.??"]
bytes["set n, a"]=[2,8,8,"-","-","-","-","cb.??"]

bytes["res n, b"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, c"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, d"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, e"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, h"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, l"]=[2,8,8,"-","-","-","-","cb.??"]
bytes["res n, [hl]"]=[2,16,16,"-","-","-","-","cb.??"]
bytes["res n, a"]=[2,8,8,"-","-","-","-","cb.??"]

bytes["bit n, b"]=[2,8,8,"Z","0","1","-","cb.??"]
bytes["bit n, c"]=[2,8,8,"Z","0","1","-","cb.??"]
bytes["bit n, d"]=[2,8,8,"Z","0","1","-","cb.??"]
bytes["bit n, e"]=[2,8,8,"Z","0","1","-","cb.??"]
bytes["bit n, h"]=[2,8,8,"Z","0","1","-","cb.??"]
bytes["bit n, l"]=[2,8,8,"Z","0","1","-","cb.??"]
bytes["bit n, [hl]"]=[2,12,12,"Z","0","1","-","cb.??"]
bytes["bit n, a"]=[2,8,8,"Z","0","1","-","cb.??"]

dummyarray=[' ',' ',' ',' ',' ',' ',' ',' '] # need something here of length of greater for our tabbing sequence

prefix = str("") # set up prefixes to be empty for the sake of line 629 that says `t = prefix + str(t)` where we need two same types of string to concatenate

if args.flags:
    print(verbosetabbing.format('line#','Assembly','T-Cycle','M-Cycle','Bytes','Z','N','H','C','Original'))
elif args.verbose: # flags takes precedence. 
    print(noflagtabbing.format('line#','Assembly','T-Cycle','M-Cycle','Bytes','Original'))
#you'll notice there's no formatting for things that aren't verbose
for t in items: # for everything in our items array which was a breakdown of line by line of our clipboard or read file
    linecount += 1 # we'll tick up the linecount; because of line merging this won't be totally accurate, it'll show the line number of the last merged line. Line merging is done by ending a line with \ per the rgbds docs.
    t = prefix + str(t) # prefix is used for line merging as supported by rgbds docs; not something I have seen in practice, but it's supported
    z = t.strip() # strip spacing from the ends of lines
    y = re.sub("\s*;.*","",z) # strip comments by finding a semicolon and removing any whitespace preceding it and any characters after it, and the semicolon itself of course
    if y == '':
        continue # apparently the whole line was a comment or otherwise blank, we don't want to do anything more with this line, let's get the next t in items
    concatquery = re.search("\\\$",y) # this signifies we need to concat t 
    if concatquery:
        prefix = re.sub("\\\$","",y) # this line ends in a \, so it serves as a prefix to the next one. (Any previous prefixes were alrady concatenated to the front of this item t)
        #print('we found a prefix') #debugging comment
        continue # go back to the top where prefix will get prepended to the next line
    else:
        prefix = str("") # no prefix # this sets us up for success on the next iteration which will not need a prefix, but the code demands a value for it
    r1 = re.search(":$",y,re.I) # identifies a label based on a terminating colon
    r2 = re.search("^\.",y,re.I) # identifies a sublabel based on an opening period
    if r1 or r2: # if either were found
        if args.flags:
            print(verbosetabbing.format(linecount,'','','','','','','','',z)) # just print the line number, no values, and the space-trimmed line item in respective columns
        elif args.verbose:
            print(noflagtabbing.format(linecount,'','','','',z)) # same as couple lines above, just skipping the flag columns
        continue
    x = re.sub('".+?"',"string",y,0,re.I) # strings in assembly could be wrapped in " "
    x = re.sub("'.+?'","string",x,0,re.I) # strings in assembly could be wrapped in ' '
    #this has replaced quotes that we find to tell us they are strings, done prior to the below step because a string could contain a comma and we don't want that. e.g. `cp "Hello, World"` or really just `cp ","` would confuse this interpreter on the next line, so instead we've converted it to be `cp string`
    w = re.sub("^\s*(ld\s|add\s|adc\s|sub\s|sbc\s|and\s|xor\s|or\s|cp\s|ldh\s)(?!.*?,)",r"\1a, ",x,re.I) 
    #now we have restored the implied a. Where as syntax like `ld b` is valid, we want it recognized as `ld a, b`. The syntax `ld a b` is not valid, hence us looking ahead for any comma; if we find a comma, then we can assume a register was explicitly stated whether it was a or not, and in which case there was no implied a so we don't do anything when the comma is found
    #next we need to parse the registers
    w = re.sub("\[hli\]","[hl+]",w,0,re.I) # mnemonics hl+ = hli, but our opcodes Bytes {} is looking for hl+
    w = re.sub("\[hld\]","[hl-]",w,0,re.I) # mnemonics hl- = hld, but our opcodes Bytes {} is looking for hl-
    w = re.sub(numbervalue,"000",w,0,re.I) # my attempt at parsing through that anything recognized as a number at the end of an instruction (i.e. meant to be n8 or n16) just be treated as the integer 000 ; the three digits allows further code like symbolExpectations to match it. I assume symbols are minimum 3 characters otherwise it is complicated to differentiate from registers like a, b, c, hl, etc.
    for i in range(6): # finds any math operations and tries to simplify the algorithm down to just a single "symbolsMathed" term, arbitrarily capped at 6 searches
        w = re.sub("\(*" + symbolExpectations + "{3,} ?[\+\-\*/\|\<>&\^~%!]+ ?" + symbolExpectations + "+\)*","symbolsMathed",w,0,re.I)
    w = re.sub("[\+\-~!]+" + symbolExpectations,"symbolsMathed",w,0,re.I) # you could have something where a numeric value is from the expression !constant; and maybe these other operators could be there as unary + or -. So we just simplify those. Otherwise might have !symbolsMathed.
    w = re.sub("^\s*ldh\s(?!\[c\])\[.*?\],\sa\s*$","ldh [a8], a",w,0,re.I) # there is a special case of ldh [c], a that we don't want to misidentify as the more generic ldh [a8], a
    w = re.sub("^\s*ldh\sa,\s(?!\[c\])\[.*?\]\s*$","ldh a, [a8]",w,0,re.I) # there is a special case of ldh a, [c] that we don't want to misidentify as the more generic ldh a, [a8]
    w = re.sub("^\s*ld \[.*?\], sp\s*$","ld [a16], sp",w,0,re.I) # specific opcode for ld [a16], sp
    w = re.sub("^\s*ld \[" + symbolExpectations + "{3,}?\], a\s*$","ld [a16], a",w,0,re.I) # tries to identify the generic ld [a16], a
    w = re.sub("^\s*ld a, \[" + symbolExpectations + "{3,}?\]\s*$","ld a, [a16]",w,0,re.I) # tries to identify the generic ld a, [a16]
    #w = re.sub("^\s*((jp|call) (?!hl$)n?(z|c)?\b,?)( )?.*$",r"\1\4a16",w,0,re.I) #watch out for jp hl <-- failed attempt
    w = re.sub("^\s*((jp|call)( n?[z|c],)?.(?!hl$)).*$",r"\1a16",w,0,re.I) # should be successful attempt. Avoids misidentify jp hl as a jp a16, but keeps conditional recognition on e.g. jp c, a16 and call nz, a16.
    w = re.sub("^\s*(jr,? (n?(z|c),)? ?).*$",r"\1e8",w,0,re.I) # jr can be conditional or not but always is an e8 offset
    w = re.sub("^\s*add sp, .*$","add sp, e8",w,0,re.I) # specific opcode
    w = re.sub("^\s*ld hl, sp \+ .*$","ld hl, sp + e8",w,0,re.I) # very specific opcode
    w = re.sub("^\s*(ld (bc|de|hl|sp), )(?!sp \+ e8$).*$",r"\1n16",w,0,re.I) # if it's not the above, it is ld *double-register*, n16
    w = re.sub("^\s*stop,? .*$","stop n8",w,0,re.I) # specific opcode
    w = re.sub("^\s*(ld\s(b|d|h|\[hl\]|c|e|l|a),)\s*(?=[$0-9]).*$",r"\1 n8",w,0,re.I) # this is maybe a relic; this predates adding in the step regarding numbervalue substitution to 000 and I think would otherwise fail on % binary prefixed numbers, but thanks to numbervalue substitution above, not a problem
    w = re.sub("^\s*(ld\s(b|d|h|\[hl\]|c|e|l|a),)\s*" + symbolExpectations + "{3,}\s*$",r"\1 n8",w,0,re.I) # tries to identify symbols that would be constants instead of actual numerals
    w = re.sub("^\s*(add|sub|and|or|adc|sbc|xor|cp)\s*a,\s*(?=[$0-9]).*$",r"\1 a, n8",w,0,re.I) # like the above two lines, but different operations
    w = re.sub("^\s*(add|sub|and|or|adc|sbc|xor|cp)\s*a,\s*" + symbolExpectations + "{3,}\s*$",r"\1 a, n8",w,0,re.I) # like the line two above it, trying to find symbols as constants instead of actual numerals
    w = re.sub("^\s*(bit|res|set)\s+" + symbolExpectations + "{3,},\s*",r"\1 n, ",w,0,re.I) # this is for when a constant is used and we match it to a pseudo-opcode of bit|res|set n, _
    #now I need this to match against the known arguments
    w = w.lower() # if we used any capitals in the assembly code, we shift to lowercase so it can match against bytes list
    breakdown = bytes.get(w,dummyarray).copy() # so .copy() means we don't affect the original bytes if we do any manipulation, as seen in the below "else" statement. The .get(key,default) means if it can find w in the bytes array, a copy of it goes into breakdown. If it cannot find it, then whatever code we have is unmatched/unrecognized, and we load dummyarray instead.
    if breakdown[1] == ' ': # this tests if we loaded dummyarray, as only dummyarray has parameter [1] as a string of a single space character
           dummycounts += 1 # increments the number of misses we have
           w = '__macro?__' # changes w into being a "placeholder" string that we will print
           tpart = '' # no value
           mpart = '' # no value
    else: 
        if breakdown[1] == breakdown[2]: # are the tmax and tmin the same?
            tpart = breakdown[1] # keep it simple, store just a single number
            mpart = int(breakdown[1])//4 # keep it simple, store just a single number that is 1/4th the value of tpart
        else:
            tpart = str(breakdown[1]) + "/" + str(breakdown[2]) # this is either or situation, and using the syntax on the https://gbdev.io/gb-opcodes/optables/ they use a Max/Min formatting
            mpart = str(int(breakdown[1])//4) + "/" + str(int(breakdown[2])//4) # mpart being 1/4th the size of tpart
    #reassemble = [ linecount, w, tpart, mpart, breakdown[0], zflag + zsuffix, nflag + nsuffix, hflag + hsuffix, cflag + csuffix, z ] # just a reference for how to break down each item as we print strings
    if args.verbose or args.flags: # we print something on each step if either is asked for
        if args.flags: # more columns for the flags
            reassemble = [ linecount, w, tpart, mpart, breakdown[0], breakdown[3], breakdown[4], breakdown[5], breakdown[6], z ]
            print(verbosetabbing.format(*reassemble, sep='\t')) # this is where the tabbing gets used. format(*variable, seperator="character") to print each item in our array separated by tabs; the exact spacing as determined by the verbosetabbing.
        else: # essentially "if args.verbose"
            reassemble = [ linecount, w, tpart, mpart, breakdown[0], z ] # same as 3 lines above, just without the flags
            print(noflagtabbing.format(*reassemble, sep='\t'))
    if breakdown[1] != ' ': # a logic reflow would place this above in the else block on line 686
        bytesInt = bytesInt + int(breakdown[0])
        t_cycle_max = t_cycle_max + int(breakdown[1])
        t_cycle_min = t_cycle_min + int(breakdown[2])
m_cycle_max = t_cycle_max//4 # we are finally out of the loop that looked at every line
m_cycle_min = t_cycle_min//4 # so now we are ready to math out our answers
if t_cycle_max == t_cycle_min:
    t_part = t_cycle_max # wonky that we have variables t_part and tpart to track... I suppose could have overwritten tpart anyway, as it shouldn't be used later on
    m_part = m_cycle_max
else:
    t_part = str(t_cycle_min) + "-" + str(t_cycle_max) # create a range display. This goes against the https://gbdev.io/gb-opcodes/optables/ syntax of Max/Min and instead uses Min-Max. Eh, personal preference... 
    m_part = str(m_cycle_min) + "-" + str(m_cycle_max)
if args.verbose or args.flags:
    print(noflagtabbing.format('Total:','',t_part,m_part,bytesInt,'')) # this won't match all the columns of flags, but there is no original code to paste either, so we keep it simple with just filling in a few of the columns.
else: # we didn't show our work and print each step, so we just have a super simple output
    print('Total T-Cycles from ' + str(t_cycle_min) + ' to ' + str(t_cycle_max))
    print('Total M-Cycles from ' + str(m_cycle_min) + ' to ' + str(m_cycle_max))
    print('Total bytes are ' + str(bytesInt))
if dummycounts > 0: # let the user know there were N number of unrecognized lines
    print('Skipped a total of ' + str(dummycounts) + ' lines not recognized as known opcodes. This may include macros, predefs, etc.')

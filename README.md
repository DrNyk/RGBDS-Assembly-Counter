Asked for by users in the discord at github.com/pret/pokered to quick check code for optimization on the basis of ROM data savings or CPU cycle savings.

This may or may not be bug free. Submit PR or find <a href="https://discordapp.com/users/1010987010003054654">DrNyk on Discord</a> for any issues.

I initially developed this app in the language AutoHotkey v2; script available for those with AHK installed. If you do not have Autohotkey available at <a href="www.autohotkey.com">autohotkey.com</a>, a Windows x32 EXE is available.
Operation of the script in AHK is to just paste your code into the left-most box. Toggle the options as you see fit regarding auto-processing or showing the Z/N/H/C flags that each opcode affects.
Hidden is the ability to also use Ctrl+O to open a file to achieve the same result as copy-pasting into the leftmost box.

Because AHK is Windows only, a python command-line utility was also made.

There are two ways to use the python script. You may call asmcounter.py and pass it a file (directory)/name it will read that file, or you may specify the -c or --clip option to have it read from clipboard. If you provide both, the clipboard option takes precedence.

Dependencies it asks for are `re` for regular expressions, `argparse` to read your arguments, and if you opt for the clipboard reading, `pyperclip`. Each should be available via pip if you do not yet have.

```
options:
  -h, --help     show this help message and exit
  --verbose, -v  This shows the logic of the parser so you can double check its work
  --flags, -f    Outputs flags so you can follow flag values through the steps, however note that explicit steps not included like unrolling a loop or when something returns from a call may
                 not be accurate. Forces verbose output.
  --clip, -c     We will read from the clipboard rather than open a file.
```

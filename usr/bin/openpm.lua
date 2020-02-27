-- openpm: package management utility inspired by Pacman --

local args, options = shell.parse(...)

local pkg = require("openpkg") -- This does most of the heavy lifting

if #args < 1 then
  if options.h or options.help then
    print("usage: openpm <operation> [...]")
    print("operations:")
    print("  openpm {-h --help}")
    print("  openpm {-V --version}")
    print("  openpm {-F --files}    <package(s)>")
    print("  openpm {-Q --query}    <package(s)>")
    print("  openpm {-S --sync}     [package(s)]")
    print("  openpm {-R --remove}   <package(s)>")
    print("  openpm {-U --upgrade}  <file(s)>")
  else
    print("error: no operation specified (use -h for help)")
  end
  return
end

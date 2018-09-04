# Modification by Me
1. Fix download speed and time estimation
2. Add fancy progress bar and text coloring
3. Longer waiting time, sometimes bot got busy, to avoid timed out

## Screenshot
![screenshot](https://github.com/chocolateshirt/xget/blob/master/xget.jpg)

## Requirement
You need to install ruby `filesize` gem using this command:

```
gem install filesize
```

==============================================================================================================================================================

# xget

xget is a simple IRC client/bot that downloads files from XDCC servers, xget also supports DCC RESUME, so if the connection is cut off, you can continue easily.

Pass the XDCC server, channel, bot and pack as a sort of link and xget does the rest.

Links can be passed either through the arguments, or in a file, which is read line by line. Also, if you have mutiple packages from the same bot in a row, use a range, like `x..y` or `x..y|interval` if you would like to specify a step interval for the range. You can add multiple ranges, with steps: `x..y|interval&x..y&x&x..y|interval`. For more info, run with `--help`

## Screenshot

![screenshot](https://github.com/takeiteasy/xget/raw/master/screen.png)

## Install

Firstly, xget requires the latest version of Ruby, 2.0.0p0, and also [Slop](https://github.com/leejarvis/slop) for the argument parsing.

If you're on Windows, use [ansicon](https://github.com/adoxa/ansicon) for coloured terminal escapes.

You may also benefit from making a config file, see .xget.conf for a simple example config. You can alternativly pass them in arguments, see --help. By default, config files are read from "~/.xget.conf"

```
gem install xget slop
```

## Usage
```
xget #news@irc.rizon.net/ginpachi-sensei/1
xget #news@irc.rizon.net/ginpachi-sensei/41..46
xget #news@irc.rizon.net/ginpachi-sensei/41..46|2
xget #news@irc.rizon.net/ginpachi-sensei/41..46&49..52|2&30
```

## License

```
Copyright (c) 2013, Rusty Shackleford
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL RUSTY SHACKLEFORD BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

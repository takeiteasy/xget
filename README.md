# xget

xget is a simple IRC client/bot that downloads files from XDCC servers, xget also supports DCC RESUME, so if the connection is cut off, you can continue easily.

Pass the XDCC server, channel, bot and pack as a sort of link and xget does the rest. See `.xget.conf` for an example config file.

Links can be passed either through the arguments, or in a file, which is read line by line. Also, if you have mutiple packages from the same bot in a row, use a range, like `x..y` or `x..y|interval` if you would like to specify a step interval for the range. You can add multiple ranges, with steps: `x..y|interval&x..y&x&x..y|interval`. For more info, run with `--help`

## Screenshot

![screenshot](https://raw.githubusercontent.com/chocolateshirt/xget/master/xget-ss.jpg)

## Usage
```
xget #news@irc.rizon.net/ginpachi-sensei/1
xget #news@irc.rizon.net/ginpachi-sensei/41..46
xget #news@irc.rizon.net/ginpachi-sensei/41..46|2
xget #news@irc.rizon.net/ginpachi-sensei/41..46&49..52|2&30
```

## License

```
Copyright (c) 2013, George Watson
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

# xget

_xget_ is a simple IRC bot that can easily automate downloading files over XDCC.

You can download can either download the `xget.rb` file from here and chmod it, or download the gem `gem install xget`.

![screenshot](https://raw.githubusercontent.com/chocolateshirt/xget/master/xget-ss.jpg)

## Usage

To get started, here is a basic example:

```
xget #news@irc.rizon.net/ginpachi-sensei/1
```

If you are familiar with IRC and XDCC bots this shouldn't be too hard to work out. If you're not, you might want to familiarise yourself with some basic concepts first. This command will instruct xget to connect to the `news` channel on the `irc.rizon.net` server and request XDCC package `1` from the bot `ginpanchi-sensei`.

```
xget #[channel]@[server]/[bot]/[packages]
```

To download multiple different packages at the same time, you can add a range, for example ```x..y```. This will queue downloads for all packages from x to y. You can also add a step to the range, ```x..y-n```. This will download all packages from x to y taking n steps through the range. For example, `10..20-2` would queue ```10, 12, 14, 16, 18 & 20```.

Multiple ranges or packages can be chained together with ```&```.

```
xget #news@irc.rizon.net/ginpachi-sensei/1
xget #news@irc.rizon.net/ginpachi-sensei/41..46
xget #news@irc.rizon.net/ginpachi-sensei/41..46-2
xget #news@irc.rizon.net/ginpachi-sensei/41..46&49..52-2&30
```
xget also supports `DCC RESUME`. So if the connection is cut off, you can continue the download where it left off.

See `.xget.conf` for an example configuration file. Different aliases and accounts can be setup per-server. xget will look for a .xget.conf file in the directory it's located or in your home directory.

## License

```
Copyright (c) 2013 George Watson, All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list
of conditions and the following disclaimer. Redistributions in binary form must
reproduce the above copyright notice, this list of conditions and the following
disclaimer in the documentation and/or other materials provided with the distribution.
Neither the name of the copyright holder nor the names of its contributors may be used
to endorse or promote products derived from this software without specific prior written
permission. 
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

# xget

xget is a simple IRC client/bot that downloads fils from XDCC servers,<br/>
xget also supports DCC RESUME, so if the connection is cut off, you can continue easily.</br>
Pass the XDCC server, channel, bot and pack as a sort of link and xget does the rest.<br/>
Links can be passed either through the arguments, or in a file, which is read line by line.<br/>
Also, if you have mutiple packages from the same bot in a row, use a range, like x..y<br/>

## Instructions

Firstly, xget requires the latest version of Ruby, 2.0.0p0, and also Slop for<br/>
the argument parsing.

<pre>
gem install Slop
</pre>

Then either chmod +x it, or run it through ruby

<pre>
xget irc.rizon.net/#news/ginpachi-sensei/1
xget irc.rizon.net/#news/ginpachi-sensei/41..46
</pre>

You may also benefit from making a config file, see .xget.conf for a simple<br/>
example config. You can alternativly pass them in arguments, see --help.
By default, config files are read from "~/.xget.conf"

## License

<pre>
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
</pre>


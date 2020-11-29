<p align="center">
  <img width="30%" src="logo_transparent.png">
</p>
A command line tool for managing and generating LLDB scripts.
<h2>Features</h2>
<p>Recursively fetch all LLDB scripts from a repo</p>
<pre><code>$ lowmad install git@github.com:bangerang/lldb_commands.git</code></pre>
<br>
<p>Or just a subset of scripts</p>
<pre><code>$ lowmad install git@github.com:bangerang/lldb_commands.git --subset label instruction</code></pre>
<br>
<p>Generate a new script</p>
<pre><code>$ lowmad generate my_script</code></pre>
<br>
<p>That's it! You´re new scripts are ready to use! Restart your LLDB debugging session or just reload the current one</p>
<pre>
<code>(lldb) command source ~/.lldbinit</code>
<code>(lldb) my_script</code>
</pre>
<br>
<p><b>lowmad</b> creates and maintains a manifest file for you containing all your installed scripts. This is very convenient if you want to share your scripts with others or setting up a new machine. <b>lowmad</b> also supports installation from a manifest file</p>
<pre><code>$ lowmad install --manifest my/path/to/manifest.json</code></pre>
<h2>Installation</h2>
<h3><a href="https://github.com/yonaskolb/mint">Mint</a></h3>
<pre>
<code>$ mint install bangerang/lowmad</code>
<code>$ lowmad init</code>
</pre>
<h3>Manual</h3>
<pre>
<code>$ cd lowmad</code>
<code>$ swift build -c release</code>
<code>$ ln -s ${PWD}/.build/release/lowmad /usr/local/bin/lowmad</code>
<code>$ lowmad init</code>
</pre>
<h2>Available commands</h2>
<pre><code>$ lowmad --help       
<br>
Usage: lowmad <command> [options]
<br>
A command line tool for managing and generating LLDB scripts.
<br>
Commands:
  init            Initialize lowmad.
  install         Install scripts from a repo or manifest file.
  list            List all available LLDB commands.
  uninstall       Uninstall scripts.
  generate        Generates a new LLDB script.
  dump            Dumps path and content of manifest file.
  help            Prints help information
  version         Prints the current version of this app
  </code></pre>
  
<pre><code>$ lowmad install --help                                                                                             

Usage: lowmad install [<gitURL>] [<subset>] ... [options]

Install scripts from a repo or manifest file.

Options:
  -c, --commit              Install from a specific commit.
  -h, --help                Show help information
  -m, --manifest            Install scripts from manifest file, path or URL to file.
  -o, --own                 Install commands to your own commands folder.

</code></pre>

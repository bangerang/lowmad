<p align="center">
  <img width="30%" src="logo_transparent.png">
</p>
A command line tool for managing and generating LLDB scripts
<h2>Features</h2>
<p>Recursively fetch all LLDB scripts from a repo</p>
<pre><code>$ lowmad install git@github.com:DerekSelander/LLDB.git</code></pre>
<br>
<p>Or just a subset of scripts</p>
<pre><code>$ lowmad install git@github.com:DerekSelander/LLDB.git --subset msl,dclass</code></pre>
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
<pre>
<code>$ brew install lowmad</code>
<code>$ lowmad init</code>
</pre>
<h2>Available commands</h2>
<table>
  <tr>
    <th>Command</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td>install</td>
    <td>Install scripts from a repo or manifest file.</td> 
  </tr>
  <tr>
    <td>uninstall</td>
    <td>Unistall scripts.</td> 
  </tr>
    <tr>
    <td>list</td>
    <td>List all available LLDB commands.</td> 
  </tr>
      <tr>
    <td>generate</td>
    <td>Generates a new script.</td> 
  </tr>
        <tr>
    <td>manifest</td>
    <td>Print path to manifest file.</td> 
  </tr>
</table>

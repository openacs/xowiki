<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="focus">note.title</property>

<!-- we should load extra style files optional -->
<style type="text/css" media="all">
<!--    @import "/resources/calendar/calendar.css"; -->
</style> 

<script type="text/javascript" language="javascript">

function getHttpObject() {
     var http_request = false;
     if (window.XMLHttpRequest) { // Mozilla, Safari,...
         http_request = new XMLHttpRequest();
         if (http_request.overrideMimeType) {
              http_request.overrideMimeType('text/xml');
         }
     } else if (window.ActiveXObject) { // IE
         try {
             http_request = new ActiveXObject("Msxml2.XMLHTTP");
         } catch (e) {
             try {
                 http_request = new ActiveXObject("Microsoft.XMLHTTP");
             } catch (e) {}
         }
     }

     if (!http_request) {
         alert('Cannot create and instance of XMLHTTP');
     }
   return http_request;
}

if (typeof DOMParser == "undefined") {
   DOMParser = function () {}
	
   DOMParser.prototype.parseFromString = function (str, contentType) {
      if (typeof ActiveXObject != "undefined") {
         var d = new ActiveXObject("MSXML.DomDocument");
         d.loadXML(str);
         return d;
        }
   }
}

var http = getHttpObject();
</script>

<style type='text/css'>
#wikicmds {position: relative;top: -50px;  right: 0px; height: 0px;
	  text-align: right;  font-family: sans-serif; font-size: 85%;color: #7A7A78;}
#wikicmds a, #wikicmds a:visited { color: #7A7A78; text-decoration: none;}
#wikicmds a:hover {text-decoration: underline;}
#wikicmds a:active {color: rgb(255,153,51);}
#cmdbar {
	background: transparent repeat-x url(/resources/xowiki/aqua.png);
	border-bottom: solid 1px rgb(221,221,221);
	font-family: sans-serif;  font-size: 85%;
	padding: 0.25em 0.5em 0.25em 0 .5em;
	color: #7A7A78;
	margin-bottom: 2px;
}
a.external {
	color: #002bb8;
	background: url(/resources/xowiki/external.png) right center no-repeat;
	padding-right: 12px;
}
h1 {
	border-bottom: solid silver 1px; color: #222222; 
	margin-top: 0.5em;	margin-bottom: 0.5em;
	text-align: left; font-weight: normal;
}

h2 {
	border-bottom: 1px solid silver; color: #222222;
	margin-top: 1em; margin-bottom: 0.25em;
	text-align: left; font-weight: normal;
}

h3 {
	text-indent: 0em; margin-top: 0.75em; margin-bottom: 0.0em;
	letter-spacing: 0px;  color: #222222;
	text-align: left; font-weight: bold;
}

hr {
   height: 1px; border: none; 
   color: silver; background-color: silver;
} 
#page-body {background: #fff; font: 10pt Arial, Helvetica, sans-serif;}
table, td       {font: 10px 'Lucida Grande', Geneva, Verdana, Arial, sans-serif; color: #000;}
#main div.column {text-align: left; margin-bottom: 1em;}
#content      {float: left; width: 68%}
#page-body h1 {font-size: 24px; margin: 0 0 .5em 0;}
#page-body h2 {font-size: 16px}
#page-body h3 {font-size: 12px}
#page-body h4 {font-size: 10px; margin: 0;}
#page-body .box {border: 1px solid #a1a5a9; padding: 0 5px 5px 5px; margin: 0 0 1.25em 0;}
#content .box h2 {border-bottom: 1px solid #a1a5a9; padding: 5px; background: #f2f2f2; margin: 0 -5px 5px -5px; font-size: 12px;}
#sidebar {float: right; width: 31%; font: 10px 'Lucida Grande', Geneva, Verdana, Arial, sans-serif;}
#sidebar h2 {font-size: 12px; margin: 0;}
#sidebar h3 {font-size: 11px; margin: 0;}
#sidebar h4 {font-size: 10px; margin: 0;}
#sidebar .sidebox li {font-size: 10px; margin: 0;}
img.found {border: 0; height: 12px}
img.undefined {border: 10; color: yellow; height: 12px}
#left-col   {float: left;    width: 40%; top: 0px;}
#right-col {float: right; width: 59%;  top: 0px;}
#left-col30   {float: left;    width: 30%; top: 0px; margin-right: 10px;}
#left-col25   {float: left;    width: 25%; top: 0px; margin-right: 10px;}
#right-col70 {float: right; width: 69%; top: 0px;}
#right-col25 {float: right; width: 25%; top: 0px;}
#messages .timestamp {font-size: 80%; color: grey}
#messages .user {font-size: 80%; font-weight: bold; color: grey}
#messages .message {vertical-align: top}
</style>

<div id='wikicmds'>
    <a href='@edit_link@' accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot;
    <a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot;
<!--  <a href="changes?object_type=CrWikiPage&item_id=@item_id@" accesskey='c'>
   Änderungen</a> &middot; -->
   <a href="@new_link@" accesskey='n'>#xowiki.new#</a> &middot;
   <a href="@index_link@" accesskey='i'>#xowiki.index#</a> 
</div>

@content;noquote@
<div style="clear: both; text-align: left; font-size: 85%;">
<p/>&nbsp;<hr>
#xowiki.references_label# @references;noquote@
@lang_links;noquote@</div><br>
@gc_comments;noquote@
<if @gc_comments@ not nil>
   <p>#file-storage.lt_Comments_on_this_file#
   <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
   <p>@gc_link;noquote@</p>
</if>

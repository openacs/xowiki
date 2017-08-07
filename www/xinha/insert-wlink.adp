<master src="/www/blank-master">
  <property name="doc(title)">#acs-templating.HTMLArea_InsertWikiLink#</property>

  <link rel="stylesheet" href="/resources/acs-templating/lists.css" type="text/css" media="all">
<script type="text/javascript" src="/resources/richtext-xinha/xinha-nightly/popups/popup.js"></script>

<style type="text/css">
  .list-table td.list {
    padding: 4px 4px;
  }

  html, body {
    background: ButtonFace;
    color: ButtonText;
    font: 11px Tahoma,Verdana,sans-serif;
    margin: 0px;
    padding: 0px;
}
body { padding: 5px; }
table {
    font: 11px Tahoma,Verdana,sans-serif;
}
.title { background: #ddf; color: #000; font-weight: bold; font-size: 120%; padding: 3px 10px; margin-bottom: 10px;
    border-bottom: 1px solid black; letter-spacing: 2px;
}
	</style>
	
<script type="text/javascript" <if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
  window.resizeTo(400, 230);

HTMLArea = window.opener.HTMLArea;

function Init() {
  __dlg_translate('Xinha');
  __dlg_init();
}

function onOK(caller) {
    // Note, that this code assumes, that onOK() was clicked on a A
    // included in a TD, which contains the "name" of the page...
    var caller = caller.parentNode;
    var anchor = caller.firstChild;
    var name = anchor.firstChild.nodeValue;
    var label = document.getElementById('label').value;
    if (label == '') {
       var labelField = caller.nextSibling.firstChild;
       //alert(labelField.nodeName + "   " + labelField.nodeValue);
       label = labelField.nodeValue;
    }

    __dlg_close({name: name, label: label});
    return false;
}
</script>

<body id="body">
  <div class="title">#acs-templating.HTMLArea_InsertWikiLink#</div>
  <div style="padding-left:10px;padding-right:10px;">
    <p>#xowiki.select_link_target#</p>
    <if @back_link@><a href="@back_link@">previous</a></if>
    @t1;noquote@
    <if @next_link@><a href="@next_link@">next</a></if>
    </br>
    Label: <input id="label" type="text"/>
  </div>
  

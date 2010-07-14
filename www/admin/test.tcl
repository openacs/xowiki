# regression test for xowiki
# $Id$
Object test
test set passed 0
test set failed 0
test proc case msg {ad_return_top_of_page "<title>$msg</title><h2>$msg</h2>"} 
test proc section msg    {my reset; ns_write "<hr><h3>$msg</h3>"} 
test proc subsection msg {ns_write "<h4>$msg</h4>"} 
test proc subsubsection msg {ns_write "<h5>$msg</h5>"} 
test proc errmsg msg     {my code "ERROR: [string map [list < {&lt;} > {&gt;}] $msg]<BR/>";test incr failed}
test proc okmsg msg      {ns_write "OK: $msg<BR/>"; test incr passed}
test proc code msg       {ns_write "<pre>$msg</pre>"}
test proc hint msg       {ns_write "$msg<BR/>"}
test proc reset {} {
  array unset ::xotcl_cleanup
  global af_parts  af_key_name
  array unset af_parts
  array unset af_key_name
}
test proc without_ns_form {cmd} {
  rename ::ns_queryget ::ns_queryget.orig
  rename ::ns_querygetall ::ns_querygetall.orig
  rename ::ad_returnredirect ::ad_returnredirect.orig
  proc ::ns_queryget key {
    #ns_log notice "queryget $key => [::xo::cc form_parameter $key {}]"; 
    ::xo::cc form_parameter $key ""
  }
  proc ::ns_querygetall key {
    #ns_log notice "querygetall $key => [list [::xo::cc form_parameter $key {}]]"
    list [::xo::cc form_parameter $key {}] 
  }
  proc ::ad_returnredirect url {::xo::cc returnredirect $url}
  if {[catch {set r [uplevel $cmd]} errmsg]} {
    if {$errmsg ne ""} {test code "error in command: $errmsg [info exists r]"}
    set r ""
  }
  rename ::ns_queryget ""
  rename ::ns_queryget.orig ::ns_queryget
  rename ::ns_querygetall ""
  rename ::ns_querygetall.orig ::ns_querygetall
  rename ::ad_returnredirect ""
  rename ::ad_returnredirect.orig ::ad_returnredirect
  return $r
}


proc ? {cmd expected {msg ""}} {
   set r [uplevel $cmd]
   if {$msg eq ""} {set msg $cmd}
   if {$r ne $expected} {
     test errmsg "$msg returned \n&nbsp;&nbsp;&nbsp;'$r' ne \n&nbsp;&nbsp;&nbsp;'$expected'"
   } else {
     test okmsg "$msg - passed ([t1 diff] ms)"
   }
}

set instance_name XOWIKI-TEST
set index_vuh_parms {
  {-m view}
  {-folder_id:integer 0}
}
::xo::Timestamp t1

test case "XoWiki Test Cases"

test section "Basic Setup"

test hint "Using XOTcl $::xotcl::version$::xotcl::patchlevel"
? {expr {$::xotcl::version < 1.5}} 0 "XOTcl Version $::xotcl::version >= 1.5"

set ns_cache_version_old [catch {ns_cache names xowiki_cache xxx}]
if {$ns_cache_version_old} {
  ? {set x old} new "upgrade ns_cache: cvs -z3 -d:pserver:anonymous@aolserver.cvs.sourceforge.net:/cvsroot/aolserver co nscache"
} else {
  ? {set x new} new "ns_cache version seems up to date"
}

set tdom_version [package require tdom]
if {$tdom_version < "0.8.0"} {
  ? {set x old} new "xowiki requires at least tdom 0.8.0 (released Aug 2004), \
	the installed tdom version is to old ($tdom_version).<br>&nbsp;&nbsp;&nbsp;\
	Please Upgrade tdom from: <code>cvs -z3 -d:pserver:anonymous@cvs.tdom.org:/usr/local/pubcvs co tdom</code><br>"
} else {
  ? {set x new} new "tdom version $tdom_version is ok"
}
########################################################################
test section "Create New Package Instance of XoWiki"
#
# create a fresh instance for testing
#
if {[site_node::exists_p -url /$instance_name]} {
  test hint "we have an existing instance named  /$instance_name, we delete it..."
  # we have already an instance, get rid of it
  array set info [site_node::get_from_url -url /$instance_name -exact]
  # is the instance mounted?
  if {$info(package_id) ne ""} {
    site_node::unmount -node_id $info(node_id)
  }
  site_node::delete -node_id $info(node_id)
  # remove the package instance
  apm_package_instance_delete $info(object_id)
  
  #test code [array get info]
}

? {site_node::exists_p -url /$instance_name} 0 \
    "the test instance does not exist"

#set root_id [site_node::get_root_node_id]
set root_id [db_string "" {select node_id from site_nodes where parent_id is null}]

if {[db_0or1row check_broken_site_nodes {
     select node_id, name from site_nodes where name = :instance_name and parent_id = :root_id
}]} {
  test hint "... site nodes seem broken, since we have an entry, but site_node::exists_p returns false"
  test hint "... try to fix anyhow"
  db_dml fix_broken_entry {
    delete from site_nodes where name = :instance_name and parent_id = :root_id
  }
}

# create a fresh instance
array set node [site_node::get -url /]
#test code [array get node]

site_node::instantiate_and_mount \
    -parent_node_id $node(node_id) \
    -node_name $instance_name \
    -package_name $instance_name \
    -package_key xowiki

? {site_node::exists_p -url /$instance_name} 1 \
    "created test instance /$instance_name"
array set info [site_node::get_from_url -url /$instance_name -exact]
#test code [array get info]

? {expr {$info(package_id) ne ""}} 1 "package is mounted, package_id provided"


test subsection "Basic Setup: Package, url= /$instance_name/"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/ \
    -actual_query "" \
    -user_id 0

? {info exists package_id} 1 "package_id is exported"
? {set package_id} $info(package_id) "package_id right value"
? {::xotcl::Object isobject ::$package_id} 1 "we have a package_id object"
? {$package_id package_url} /$instance_name/ "package_url"
? {$package_id url} /$instance_name/
? {$package_id id} $package_id "the id of the package object = package_id"

test code [$package_id serialize]

test subsection "Basic Setup: Folder Object"
? {$package_id exists folder_id} 1 "folder_id is set"
set folder_id [::$package_id folder_id]
? {::xotcl::Object isobject ::$folder_id} 1 "we have a folder object"
? {::$folder_id name} "xowiki: $package_id" "name of folder object is 'xowiki: $package_id'"
? {::$folder_id parent_id} -100  "parent_id of folder object is -100"
? {expr {[::$folder_id item_id]>0}} 1 "item_id given"
? {expr {[::$folder_id revision_id]>0}} 1 "revision_id given"
? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 0 \
    "folder contains no objects"

test subsection "Create and Render Index Page"
? {$package_id set object} "" "object name parsed"
? {set m} view "method passed from package initialize"
set object [$package_id set object]
set page_item_id [$package_id resolve_page $object $m]
? {expr {$page_item_id ne ""}} 1 "index page resolved"
? {::xotcl::Object isobject ::$page_item_id} 1 "we have a page object"
? {expr {[::$page_item_id item_id]>0}} 1 "item_id given"
? {expr {[::$page_item_id revision_id]>0}} 1 "revision_id given"
? {::$page_item_id parent_id} $folder_id "parent_id of page object is folder_id"
? {::$page_item_id package_id} $package_id "package_id of page object"
? {::$page_item_id name} en:index "name of resolved index page"
? {::$page_item_id istype ::xowiki::Page} 1 "type or subtype of ::xowiki::Page"

set content [$package_id call $page_item_id $m ""]
set content_length [string length $content]
? {expr {$content_length > 1000}} 1 \
    "page rendered, content-length $content_length > 1000"
? {string first Error $content} -1 "page contains no error"
? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 1 \
    "folder contains the index page"
#test code [$page_item_id serialize]

test subsection "Check Permissions based on default policy"
? {::xo::cc user_id} 0 "user_id is guest"
? {::$package_id make_link ::$page_item_id delete return_url} "" \
    "the public cannot delete this page"
? {::$package_id make_link -privilege admin -link admin/ $package_id {} {}} "" \
    "the public cannot admin this package"

########################################################################
#
# run a new query, use en/index explicitely
#
test section "New Query: /$instance_name/en/index"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/index \
    -actual_query "" \
    -user_id 0

? {info exists package_id} 1 "package_id is exported"
? {set package_id} $info(package_id) "package_id right value"
? {::xotcl::Object isobject ::$package_id} 1 "we have a package_id object"
? {$package_id package_url} /$instance_name/ "package_url"
? {$package_id url} /$instance_name/en/index "url"
? {$package_id id} $package_id "the id of the package object = package_id"
set object [::$package_id set object]
set page_item_id [::$package_id resolve_page $object $m]
set folder_id [::$package_id folder_id]
? {::$page_item_id parent_id} $folder_id "parent_id of page object is folder_id"
? {::$page_item_id package_id} $package_id "package_id of page object"
? {::$page_item_id name} en:index "name of resolved index page"

########################################################################
#
# run a new query
#
test section "New Query: /$instance_name/"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/ \
    -actual_query "" \
    -user_id 0

? {info exists package_id} 1 "package_id is exported"
? {set package_id} $info(package_id) "package_id right value"
? {::xotcl::Object isobject ::$package_id} 1 "we have a package_id object"
? {$package_id package_url} /$instance_name/ "package_url"
? {$package_id url} /$instance_name/ "url"
? {$package_id id} $package_id "the id of the package object = package_id"

test subsection "Basic Setup: Folder Object (2nd)"
? {$package_id exists folder_id} 1 "folder_id is set"
set folder_id [::$package_id folder_id]
? {::xotcl::Object isobject ::$folder_id} 1 "we have a folder object"
? {::$folder_id name} "xowiki: $package_id" "name of folder object is 'xowiki: $package_id'"
? {::$folder_id parent_id} -100  "parent_id of folder object is -100"
? {expr {[::$folder_id item_id]>0}} 1 "item_id given"
? {expr {[::$folder_id revision_id]>0}} 1 "revision_id given"
? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 1 \
    "folder contains the index"

test subsection "Render Index Page (2nd)"
? {$package_id set object} "" "object name parsed"
? {set m} view "method passed from package initialize"
set object [$package_id set object]
set page_item_id [$package_id resolve_page $object $m]
? {expr {$page_item_id ne ""}} 1 "index page resolved"
? {::xotcl::Object isobject ::$page_item_id} 1 "we have a page object"
? {expr {[::$page_item_id item_id]>0}} 1 "item_id given"
? {expr {[::$page_item_id revision_id]>0}} 1 "revision_id given"
? {::$page_item_id parent_id} $folder_id "parent_id of page object is folder_id"
? {::$page_item_id package_id} $package_id "package_id of page object"
? {::$page_item_id name} en:index "name of resolved index page"
? {::$page_item_id istype ::xowiki::Page} 1 "type or subtype of ::xowiki::Page"

set content [$package_id call $page_item_id $m ""]
set content_length [string length $content]
? {expr {$content_length > 1000}} 1 \
    "page rendered, content-length $content_length > 1000"
? {string first Error $content} -1 "page contains no error"
#test code [$page_item_id serialize]

########################################################################
#
# run a new query
#
test section "New Query: /$instance_name/weblog"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/weblog \
    -actual_query "" \
    -user_id 0

? {$package_id package_url} /$instance_name/ "package_url"
? {$package_id url} /$instance_name/weblog "url"
? {$package_id id} $package_id "the id of the package object = package_id"
set folder_id [::$package_id folder_id]

test subsection "Create and Render Weblog"
set content [::$package_id invoke -method $m]
set content_length [string length $content]
? {expr {$content_length > 1000}} 1 \
    "page rendered, content-length $content_length > 1000"
? {string first Error $content} -1 "page contains no error"
#test hint $content

? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 3 \
    "folder contains: index and weblog page (+1 includelet)"

::xo::at_cleanup


########################################################################
test section "New Query: /$instance_name/en/weblog"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/weblog \
    -actual_query "" \
    -user_id 0

set content [::$package_id invoke -method $m]
set content_length [string length $content]
? {expr {$content_length > 1000}} 1 \
    "page rendered, content-length $content_length > 1000"
? {string first Error $content} -1 "page contains no error"
? {string first file:image $content} -1 "page contains no error"
? {expr {[string first "Index Page" $content] == -1}} 0 \
    "weblog contains Index Page"

set full_weblog_content_length $content_length

::xo::at_cleanup

########################################################################
test section "New Query: /$instance_name/en/weblog with summary=1"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/weblog \
    -actual_query "summary=1" \
    -user_id 0

set content [::$package_id invoke -method $m]
set content_length [string length $content]
? {expr {$content_length > 1000}} 1 \
    "page rendered, content-length $content_length > 1000"
? {string first Error $content} -1 "page contains no error"
? {expr {$full_weblog_content_length > $content_length}} 1 \
    "summary ($content_length) is shorter than full weblog $full_weblog_content_length"

#test hint $content
::xo::at_cleanup
#return

########################################################################
test section "Testing as SWA: query /$instance_name/"

set swas [db_list get_swa "select grantee_id from acs_permissions \
	where object_id = -4 and privilege = 'admin'"]

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/ \
    -actual_query "" \
    -user_id [lindex $swas 0]

set content [::$package_id invoke -method $m]
? {string first Error $content} -1 "page contains no error"

test subsection "Check Permissions based on default policy"
? {expr {[::xo::cc user_id] != 0}} 1 "user_id [lindex $swas 0] is not guest"
? {expr {[::$package_id make_link ::$page_item_id delete return_url] ne ""}} 1 \
    "SWA sees the delete link"
? {expr {[::$package_id make_link -privilege admin -link admin/ $package_id {} {}] ne ""}} 1 \
    "SWA sees admin link"
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 3 \
    "folder contains: index and weblog page (+1 includelet)"
::xo::at_cleanup

########################################################################
test section "Delete weblog-portlet via weblink"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/weblog-portlet \
    -actual_query "m=delete" \
    -user_id [lindex $swas 0]

set content [::$package_id invoke -method $m]
? {string first Error $content} -1 "page contains no error"
? {::xo::cc exists __continuation} 1 "continuation exists"
? {::xo::cc set  __continuation} "ad_returnredirect /$instance_name/" \
    "redirect to main instance"
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 2 \
    "folder contains: index and weblog page (+0 includelet)"

test subsection "Create a test page named hello with package_id $package_id"

set page [::xowiki::Page new \
              -title "Hello World" \
              -name en:hello \
              -package_id $package_id \
              -parent_id [$package_id folder_id] \
              -destroy_on_cleanup \
              -text {
                Hello [[Wiki]] World.
              }]
$page set_content [string trim [$page text] " \n"]
$page initialize_loaded_object
$page save_new
? {$page set package_id} $package_id "package_id $package_id not modified"
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 3 \
    "folder contains: index and weblog, hello page (+0 includelet)"
? {expr {[$page revision_id]>0}} 1 "revision_id given"
? {expr {[$page item_id]>0}} 1 "item_id given"
set revision_id1 [$page revision_id]
set item_id1 [$page item_id]

$page append title "- V.2"
$page save
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 3 \
    "still 3 pages"
? {expr {[$page revision_id]>$revision_id1}} 1 "revision_id > old revision_id"
? {expr {[$page item_id] == $item_id1}} 1 "item id the same"

::xo::at_cleanup



########################################################################
test section "Recreate weblog-portlet"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/weblog \
    -actual_query "summary=1" \
    -user_id 0

set content [::$package_id invoke -method $m]
set content_length [string length $content]
? {expr {$content_length > 1000}} 1 \
    "page rendered, content-length $content_length > 1000"
? {string first Error $content} -1 "page contains no error"
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 4 \
    "again, 4 pages"

::xo::at_cleanup

########################################################################
test section "Query revisions for hello page via weblink"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/hello \
    -actual_query "m=revisions" \
    -user_id [lindex $swas 0]

set content [::$package_id invoke -method $m]
? {string first Error $content} -1 "page contains no error"
? {expr {[string first 2: $content]>-1}} 1 "page contains two revisions"

::xo::at_cleanup


########################################################################
test section "Edit hello page via weblink"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/hello \
    -actual_query "m=edit" \
    -user_id [lindex $swas 0]

set content [::$package_id invoke -method $m]
? {string first Error $content} -1 "page contains no error"
? {expr {[string first "- V.2" $content]>-1}} 1 \
    "form page contains the modified title"

regexp {name="item_id" value="([^\"]+)"} $content _ returned_item_id
? {info exists returned_item_id} 1 "item_id contained in form"
? {expr {$returned_item_id > 0}} 1 "item_id $returned_item_id > 0"
? {$package_id isobject $returned_item_id} 1 "item is instantiated"

regexp {name="folder_id" value="([^\"]+)"} $content _ returned_folder_id
? {info exists returned_folder_id} 1 "folder_id contained in form"
? {expr {$returned_folder_id > 0}} 1 "returned folder id $returned_folder_id >0"

regexp {name="__key_signature" value="([^\"]+)"} $content _ signature
? {info exists signature} 1 "signature contained in form"
? {expr {$signature ne ""}} 1 "signature not empty"

set title [$returned_item_id title]
set text [lindex [$returned_item_id text] 0]

? {set title} {Hello World- V.2}
? {set text}  {Hello [[Wiki]] World.}

::xo::at_cleanup

########################################################################
test section "Submit edited hello page via weblink"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/hello \
    -actual_query "m=edit" \
    -user_id [lindex $swas 0] \
    -form_parameter [subst {
      form:id f1 
      form:mode edit 
      formbutton:ok {       OK       } 
      __refreshing_p 0 
      __confirmed_p 0
      __new_p 0
      __key_signature {$signature} 
      __object_name en:hello
      name en:hello 
      object_type ::xowiki::Page 
      text.format text/html 
      creator {{Gustaf Neumann}} 
      description {{this is the description}}
      text {{$text ... just testing ..<br />}} 
      nls_language en_US 
      folder_id $returned_folder_id 
      title {{$title - saved}}
      item_id $returned_item_id }]

set content [test without_ns_form {::$package_id invoke -method $m}]
? {string first Error $content} -1 "page contains no error"
? {::xo::cc exists __continuation} 1 "continuation exists"
? {::xo::cc set  __continuation} "ad_returnredirect /$instance_name/hello" \
    "redirect to hello page"

::xo::at_cleanup

########################################################################
test section "Query revisions for hello page via weblink"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/hello \
    -actual_query "m=revisions" \
    -user_id [lindex $swas 0]

set content [::$package_id invoke -method $m]

set p [::xowiki::Page info instances]
? {llength $p} 1 "expect only one page instance"

if {[llength $p] == 1} {
  ? {$p set title} {Hello World- V.2 - saved} "saved title is ok"
  ? {lindex [$p set text] 0} {Hello [[Wiki]] World. ... just testing ..<br />} "saved text is ok"
} else {
  test code [::xowiki::Page info instances]
  foreach p [::xowiki::Page info instances] {test code "$p [$p serialize]"}
}

? {string first Error $content} -1 "page contains no error"
? {expr {[string first 3: $content]>-1}} 1 "page contains three revisions"

# keep the page for the following test
#::xo::at_cleanup

########################################################################
test section "Small tests"

test subsection "Link resolver"
set p [::xowiki::Page info instances]
? {llength $p} 1 "expect only one page instance"

proc xowiki-test-links {p tests} {
  foreach {link result external} $tests {
    set l [$p create_link $link]
    switch [$l info class] {
      ::xowiki::Link         { ? {expr {[$l resolve] > 0}} $result "Can resolve link $link" }
      ::xowiki::ExternalLink { ? {expr {$external == 1}} $result "found external link" }
    }
    $l destroy
  }
}
test subsubsection "Testing links on English page"
xowiki-test-links $p {
    hello 1 0
    en:hello 1 0
    de:hello 0 0
    xxx 0 0
    //XOWIKI-TEST/hello 1 0
    //XOWIKI-TEST/en:hello 1 0
    //XOWIKI-TEST/de:hello 0 0
    //XOWIKI-TEST/en/hello 0 0
    //forums 1 1
    //XOWIKI-TEST/weblog?m=create-new&p.exercise_form=en:l1 1 0
    //XOWIKI-TEST/en:weblog?m=create-new&p.exercise_form=en:l1 1 0
}

# make page a german page
$p nls_language de_DE
test subsubsection "Testing links on German page"
xowiki-test-links $p {
    hello 1 0
    en:hello 1 0
    de:hello 0 0
    xxx 0 0
    //XOWIKI-TEST/hello 1 0
    //XOWIKI-TEST/en:hello 1 0
    //XOWIKI-TEST/de:hello 0 0
    //XOWIKI-TEST/en/hello 0 0
    //forums 1 1
    //XOWIKI-TEST/weblog?m=create-new&p.exercise_form=en:l1 1 0
    //XOWIKI-TEST/en:weblog?m=create-new&p.exercise_form=en:l1 1 0
}



########################################################################
test subsection "Filter expressions"

? {::xowiki::FormPage filter_expression \
    "_state=created|accepted|approved|tested|developed|deployed&&_assignee=123" &&} \
    {tcl {[lsearch -exact {created accepted approved tested developed deployed} [my property _state]] > -1&&[my property _assignee] eq {123}} h {} vars {} sql {{state in ('created','accepted','approved','tested','developed','deployed')} {assignee = '123'}}} filter_expr_where_1

? {::xowiki::FormPage filter_expression \
    "_assignee<=123 && y>=123" &&} \
    {tcl {[my property _assignee] <= {123}&&$__ia(y) >= {123}} h {} vars {y {}} sql {{assignee <= '123'}}} \
    filter_expr_where_2

? {::xowiki::FormPage filter_expression \
    "betreuer contains en:person1" &&} \
    {tcl {[lsearch $__ia(betreuer) {en:person1}] > -1} h {} vars {betreuer {}} sql {{instance_attributes like '%en:person1%'}}} \
    filter_expr_where_3

? {::xowiki::FormPage filter_expression \
    "_state=closed" ||} \
    {tcl {[my property _state] eq {closed}} h {} vars {} sql {{state = 'closed'}}} \
    filter_expr_unless_1

? {::xowiki::FormPage filter_expression \
    "_state= closed|accepted || x = 1" ||} \
    {tcl {[lsearch -exact {closed accepted} [my property _state]] > -1||$__ia(x) eq {1}} h x=>1 vars {x {}} sql {{state in ('closed','accepted')}}} \
    filter_expr_unless_1



########################################################################
test section "Item refs"
#
# Testing item refs and wiki links (between [[ .... ]])
#
# Still missing:
#    - test reverse mappings from urls generated from item-refs back to item_ids
#    - syntax Person:de:p1 (if de:p1 does not exist, create an instance of Person name de:p1)
#    - typed links (glossary app)... important?
#    - interaction between PackagePath and folders (would be nice to inherit from folders, not packages)
#
# Save this file in openacs-4/www/item-ref-test.tcl and run it via 
# http://..../item-ref-test
#
#

  # "require_folder" and "require_page" are here just for testing
  proc require_folder {name parent_id package_id} {
    set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
    
    if {$item_id == 0} {
      set form_id [::xowiki::Weblog instantiate_forms -forms en:folder.form -package_id $package_id]
      set f [$form_id create_form_page_instance \
		 -name $name \
		 -nls_language en_US \
		 -default_variables [list title "Folder $name" parent_id $parent_id package_id $package_id]]
      $f save_new
      set item_id [$f item_id]
    }
    test hint "  $name => $item_id\n"
    return $item_id
  }

  proc require_link {name parent_id package_id target_id} {
    set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
    
    if {$item_id == 0} {
      set form_id [::xowiki::Weblog instantiate_forms -forms en:link.form -package_id $package_id]
      set target [::xo::db::CrClass get_instance_from_db -item_id $target_id]
      set item_ref [[$target package_id] external_name -parent_id [$target parent_id] [$target name]]

      set f [$form_id create_form_page_instance \
		 -name $name \
		 -nls_language en_US \
		 -instance_attributes [list link $item_ref] \
		 -default_variables [list title "Link $name" parent_id $parent_id package_id $package_id]]
      $f save_new
      set item_id [$f item_id]
    }
    test hint "  $name => $item_id\n"
    return $item_id
  }

  proc require_page {name parent_id package_id {file_content ""}} {
    set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
    if {$item_id == 0} {
      if {$file_content eq ""} {      
        set f [::xowiki::Page new -name $name -description "" \
                   -parent_id $parent_id -package_id $package_id -text [list "Content of $name" text/html]]
      } else {
        set mime_type [::xowiki::guesstype $name]
        set f [::xowiki::File new -name $name -description "" \
                   -parent_id $parent_id -package_id $package_id -mime_type $mime_type]
        set import_file [ns_tmpnam]
        ::xowiki::write_file $import_file [::base64::decode $file_content]
        $f set import_file $import_file
      }
      $f save_new
      set item_id [$f item_id]
      $f destroy_on_cleanup
    }
    ns_log notice "Page  $name => $item_id"
    test hint "  $name => $item_id\n"
    return $item_id
  }
  proc label {intro case ref} {return "$intro '$ref' -- $case"}

  #some test cases
  ::xowiki::Package initialize -url /$instance_name/
  ::xowiki::Page create p -package_id $package_id -nls_language de_DE -parent_id [$package_id folder_id]
  p set unresolved_references 0

  test subsection "Ingredients:"
  set folder_id [$package_id folder_id]
  test hint "folder_id => $folder_id"

  set folder_id [$package_id folder_id]

  # make sure, we have folder "f1" with subfolder "f3" with subfolder "subf3"
  set f1_id          [require_folder "f1"          $folder_id $package_id]
  set f3_id          [require_folder "f3"          $f1_id $package_id]
  set subf3_id       [require_folder "subf3"       $f3_id $package_id]

  # make sure, we have the test pages
  set parentpage_id  [require_page   de:parentpage $folder_id $package_id]
  set enpage_id      [require_page   en:page       $folder_id $package_id]
  set testpage_id    [require_page   de:testpage   $f1_id $package_id]
  set f3page_id      [require_page   en:page       $f3_id $package_id]

  set childfolder_id [require_folder "childfolder" $parentpage_id $package_id]
  set childpage_id   [require_page "de:childpage"  $parentpage_id $package_id]

  set base64 "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAAXNSR0IArs4c6QAAAAxJREFUCNdj\n+P//PwAF/gL+3MxZ5wAAAABJRU5ErkJggg=="
  set image_id       [require_page file:image.png  $folder_id $package_id $base64]
  set subimage_id    [require_page file:image2.png $f1_id $package_id $base64]
  set childimage_id  [require_page file:image3.png $parentpage_id $package_id $base64]

  set pagelink_id      [require_link link1      $folder_id $package_id $parentpage_id]
  set folderlink_id    [require_link link2      $folder_id $package_id $f1_id]
  set subpagelink_id   [require_link link3      $folder_id $package_id $testpage_id]
  set subfolderlink_id [require_link link4      $folder_id $package_id $f3_id]
  set subimagelink_id  [require_link link5      $folder_id $package_id $subimage_id]
  ################################


  test subsection "Toplevel Tests:"

  set l "folder:f1"
  set test [label "item_ref" "existing topfolder" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f1"
	   && $(form) eq "en:folder.form"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "de:parentpage"
  set test [label "item_ref" "existing page in root_folder" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == $parentpage_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/"
  set test [label "item_ref" "existing topfolder short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f1"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1";# this works, since "f1" exists
  set test [label "item_ref" "existing topfolder short + lookup" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f1"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "page1";#  last item per default page
  set test [label "item_ref" "not existing page short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "page1"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "parentpage"
  set test [label "item_ref" "existing page short (without language prefix)" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == $parentpage_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "image:img1"
  set test [label "item_ref" "not existing image" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "image" && $(prefix) eq "file" && $(stripped_name) eq "img1"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "image:image.png"
  set test [label "item_ref" "existing image" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "image" && $(prefix) eq "file" && $(stripped_name) eq "image.png"
           && $(parent_id) eq $folder_id && $(item_id) == $image_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "file:file1"
  set test [label "item_ref" "not existing file" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "file" && $(prefix) eq "file" && $(stripped_name) eq "file1"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "file:image.png"
  set test [label "item_ref" "existing file" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "file" && $(prefix) eq "file" && $(stripped_name) eq "image.png"
           && $(parent_id) eq $folder_id && $(item_id) == $image_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "image.png"
  set test [label "item_ref" "existing image short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "image" && $(prefix) eq "file" && $(stripped_name) eq "image.png"
           && $(parent_id) eq $folder_id && $(item_id) == $image_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "image1.png"
  set test [label "item_ref" "not existing image short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "image" && $(prefix) eq "file" && $(stripped_name) eq "image1.png"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "flashfile.swf"
  set test [label "item_ref" "not existing flash file short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "swf" && $(prefix) eq "file" && $(stripped_name) eq "flashfile.swf"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  ################################
  test subsection "Relative to current folder:"

  set l "./parentpage"
  set test [label "item_ref" "existing page short (without prefixuage prefix), relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == $parentpage_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./de:parentpage"
  set test [label "item_ref" "existing page in root_folder, relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == $parentpage_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./f1/"
  set test [label "item_ref" "existing topfolder short, relative" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f1"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./f1";# this works, since "f1" exists
  set test [label "item_ref" "existing topfolder short + lookup, relative" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f1"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./page1";#  last item per default page
  set test [label "item_ref" "not existing page short, relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "page1"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "./parentpage/"
  set test [label "item_ref" "not existing folder (with same name of existing page) in root_folder, relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "./" ;# stripped name will be the name of the root folder
  set test [label "item_ref" "dot with slash, relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" 
           && $(parent_id) == -100 && $(item_id) == $folder_id}} 1 "\n$test:\n  [array get {}]\n "

  ################################
  test subsection "Ending with dot:"

  set l "." ;# stripped name will be the name of the root folder, omit from test
  set test [label "item_ref" "dot with slash, relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" 
           && $(parent_id) eq -100 && $(item_id) == $folder_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./f1/."
  set test [label "item_ref" "existing topfolder short, relative" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" && $(stripped_name) eq "f1"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./parentpage/."
  set test [label "item_ref" "existing page short (without language prefix), relative" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == $parentpage_id}} 1 "\n$test:\n  [array get {}]\n "

  ################################
  test subsection "Under folder:"

  set l "folder:f1/folder:f3"
  set test [label "item_ref" "existing subfolder" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "folder:f1/f3/"
  set test [label "item_ref" "existing subfolder short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "./folder:f1/folder:f3/"
  set test [label "item_ref" "existing subfolder with prefix and trailing slash" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/"
  set test [label "item_ref" "existing subfolder short short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "folder:f11/folder:f3"
  set test [label "item_ref" "not existing folder with subfolder" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f11"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "f11/folder/"
  set test [label "item_ref" "not existing folder with subfolder short short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f11"
           && $(parent_id) eq $folder_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/folder1/"
  set test [label "item_ref" "existing folder with not existing subfolder short short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "folder1"
           && $(parent_id) eq $f1_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/page1"
  set test [label "item_ref" "existing folder with not existing page short short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "page1"
           && $(parent_id) eq $f1_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "folder:f1/folder:f3/folder:subf3"
  set test [label "item_ref" "existing subsubfolder" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "subf3"
           && $(parent_id) eq $f3_id && $(item_id) == $subf3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/subf3"
  set test [label "item_ref" "existing subsubfolder short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "subf3"
           && $(parent_id) eq $f3_id && $(item_id) == $subf3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/subf3/."
  set test [label "item_ref" "existing subsubfolder short" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" && $(stripped_name) eq "subf3"
           && $(parent_id) eq $f3_id && $(item_id) == $subf3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "folder:f1/folder:f99"
  set test [label "item_ref" "not existing folder in folder" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "f99"
           && $(parent_id) eq $f1_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "folder:f1/de:testpage"
  set test [label "item_ref" "existing page in folder" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "testpage"
           && $(parent_id) eq $f1_id && $(item_id) == $testpage_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "folder:f1/de:entry"
  set test [label "item_ref" "not existing page in folder" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "entry"
           && $(parent_id) eq $f1_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/image:image.png"
  set test [label "item_ref" "not existing image" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "image" && $(prefix) eq "file" && $(stripped_name) eq "image.png"
           && $(parent_id) eq $f1_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/image.png"
  set test [label "item_ref" "not existing image short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "image" && $(prefix) eq "file" && $(stripped_name) eq "image.png"
           && $(parent_id) eq $f1_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  ################################
  test subsection "Under page:"

  set l "de:parentpage/folder:childfolder"
  set test [label "item_ref" "existing folder under page" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "childfolder"
           && $(parent_id) eq $parentpage_id && $(item_id) == $childfolder_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "de:parentpage/folder:childfolder/"
  set test [label "item_ref" "existing folder under page with prefix and trailing slash" $l]
  array set "" [p item_ref -default_lang en -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "childfolder"
           && $(parent_id) eq $parentpage_id && $(item_id) == $childfolder_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "de:parentpage/folder:childfolder1"
  set test [label "item_ref" "not existing folder under page" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "childfolder1"
           && $(parent_id) eq $parentpage_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "de:parentpage/folder:childfolder1/"
  set test [label "item_ref" "not existing folder under page with prefix and trailing slash" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "" && $(stripped_name) eq "childfolder1"
           && $(parent_id) eq $parentpage_id && $(item_id) == 0}} 1 "\n$test:\n  [array get {}]\n "

  set l "de:parentpage/de:childpage"
  set test [label "item_ref" "existing page under page" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "childpage"
           && $(parent_id) eq $parentpage_id && $(item_id) == $childpage_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "parentpage/childpage"
  set test [label "item_ref" "existing page under page short" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "childpage"
           && $(parent_id) eq $parentpage_id && $(item_id) == $childpage_id}} 1 "\n$test:\n  [array get {}]\n "

  ################################
  test subsection "Ending with /.."

  set l ".."
  set test [label "item_ref" "dot dot (don't traverse beyond root folder)" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq ""
           && $(parent_id) == -100 && $(item_id) == $folder_id}} 1 "\n$test:\n  [array get {}]\n "

  set l ".."
  set test [label "item_ref" "dot dot slash dot dot (don't traverse beyond root folder)" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq ""
           && $(parent_id) == -100 && $(item_id) == $folder_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/subf3/.."
  set test [label "item_ref" "existing subsubfolder dot dot" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/subf3/../"
  set test [label "item_ref" "existing subsubfolder dot dot slash" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/subf3/../."
  set test [label "item_ref" "existing subsubfolder dot dot slash dot" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" && $(stripped_name) eq "f3"
           && $(parent_id) eq $f1_id && $(item_id) == $f3_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "f1/f3/subf3/../.."
  set test [label "item_ref" "existing subsubfolder dot dot slash dot dot" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "folder" && $(prefix) eq "" && $(stripped_name) eq "f1"
           && $(parent_id) eq $folder_id && $(item_id) == $f1_id}} 1 "\n$test:\n  [array get {}]\n "

  set l "parentpage/childpage/.."
  set test [label "item_ref" "existing page und page dot dot" $l]
  array set "" [p item_ref -default_lang de -parent_id $folder_id $l]
  ? {expr {$(link_type) eq "link" && $(prefix) eq "de" && $(stripped_name) eq "parentpage"
           && $(parent_id) eq $folder_id && $(item_id) == $parentpage_id}} 1 "\n$test:\n  [array get {}]\n "


  test subsection "Links:"

  set l "parentpage"
  set test [label "link" "existing simple page" $l]
  set link [p create_link $l]
  ? {$link render} "<a   href='/$instance_name/de/parentpage'>parentpage</a>" "\n$test\n "

  set l "parentpage1"
  set test [label "link" "not existing simple page" $l]
  set link [p create_link $l]
? {$link render} [subst -nocommands {<a  href='/$instance_name/?nls_language=de_DE&edit-new=1&name=de%3aparentpage1&parent_id=$folder_id&title=parentpage1'> [ </a>parentpage1 <a  href='/$instance_name/?nls_language=de_DE&edit-new=1&name=de%3aparentpage1&parent_id=$folder_id&title=parentpage1'> ] </a>}] "\n$test\n "

  set l "parentpage#a"
  set test [label "link" "existing simple with anchor" $l]
  set link [p create_link $l]
? {$link render} [subst -nocommands {<a   href='/$instance_name/de/parentpage#a'>parentpage</a>}] "\n$test\n "

  set l "image:image.png"
  set test [label "link" "existing image" $l]
  set link [p create_link $l]
? {$link render} [subst -nocommands {<img class='image' src='/$instance_name/download/file/image.png' alt='image:image.png' title='image:image.png' >}] "\n$test\n "

  set l "image.png"
  set test [label "link" "existing image short" $l]
  set link [p create_link $l]
? {$link render} [subst -nocommands {<img class='image' src='/$instance_name/download/file/image.png' alt='image.png' title='image.png' >}] "\n$test\n "

  set l ":de:parentpage"
  set test [label "link" "existing language link" $l]
  p array unset lang_links
  set link [p create_link $l]
  ? {$link render} {} "\n$test\n "
? {p array get lang_links} [subst -nocommands {found {{<a href='/$instance_name/de/parentpage' ><img class='found'  src='/resources/xowiki/flags/de.png' alt='de'></a>}}}] "\n$test links\n "

  p destroy
############################################

  test section "page properties"

  set f1 [::xo::db::CrClass get_instance_from_db -item_id $f1_id]
  set f2 [::xo::db::CrClass get_instance_from_db -item_id $f3_id]
  set f3 [::xo::db::CrClass get_instance_from_db -item_id $subf3_id]

  set p1 [::xo::db::CrClass get_instance_from_db -item_id $parentpage_id]
  set p2 [::xo::db::CrClass get_instance_from_db -item_id $testpage_id]
  set p3 [::xo::db::CrClass get_instance_from_db -item_id $childpage_id]
  set p4 [::xo::db::CrClass get_instance_from_db -item_id $enpage_id]
  set p5 [::xo::db::CrClass get_instance_from_db -item_id $f3page_id]

  set i1 [::xo::db::CrClass get_instance_from_db -item_id $image_id]
  set i2 [::xo::db::CrClass get_instance_from_db -item_id $subimage_id]
  set i3 [::xo::db::CrClass get_instance_from_db -item_id $childimage_id]

  set l1 [::xo::db::CrClass get_instance_from_db -item_id $pagelink_id]
  set l2 [::xo::db::CrClass get_instance_from_db -item_id $folderlink_id]
  set l3 [::xo::db::CrClass get_instance_from_db -item_id $subpagelink_id]
  set l4 [::xo::db::CrClass get_instance_from_db -item_id $subfolderlink_id]
  set l5 [::xo::db::CrClass get_instance_from_db -item_id $subimagelink_id]

  ? {$f1 is_folder_page} 1
  ? {$f2 is_folder_page} 1
  ? {$f3 is_folder_page} 1

  ? {$p1 is_folder_page} 0

  ? {$l1 is_folder_page} 0
  ? {$l2 is_folder_page} 1
  ? {$l3 is_folder_page} 0
  ? {$l4 is_folder_page} 1
  ? {$l5 is_folder_page} 0



  test section "pretty links"

  ? {$f1 pretty_link} "/XOWIKI-TEST/f1"
  ? {$f2 pretty_link} "/XOWIKI-TEST/f1/f3"
  ? {$f3 pretty_link} "/XOWIKI-TEST/f1/f3/subf3"

  ? {$p1 pretty_link} "/XOWIKI-TEST/de/parentpage"
  ? {$p2 pretty_link} "/XOWIKI-TEST/de/f1/testpage"
  ? {$p3 pretty_link} "/XOWIKI-TEST/de/de:parentpage/childpage"
  ? {$p4 pretty_link} "/XOWIKI-TEST/page"
  ? {$p5 pretty_link} "/XOWIKI-TEST/f1/f3/page"

  ? {$i1 pretty_link} "/XOWIKI-TEST/file/image.png"
  ? {$i2 pretty_link} "/XOWIKI-TEST/file/f1/image2.png"
  ? {$i3 pretty_link} "/XOWIKI-TEST/file/de:parentpage/image3.png"

  ? {$l1 pretty_link} "/XOWIKI-TEST/link1"
  ? {$l2 pretty_link} "/XOWIKI-TEST/link2"
  ? {$l3 pretty_link} "/XOWIKI-TEST/link3"
  ? {$l4 pretty_link} "/XOWIKI-TEST/link4"
  ? {$l5 pretty_link} "/XOWIKI-TEST/link5"
  ? {$l5 pretty_link -download true} "/XOWIKI-TEST/download/file/link5"

  test section "item info from pretty links"  

  set l [$f1 pretty_link]
  set test [label "url" "topfolder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $f1_id && $(stripped_name) eq "f1"}} 1 "\n$test:\n  [array get {}]\n "  

  set l [$f2 pretty_link]
  set test [label "url" "folder under topfolder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $f3_id && $(stripped_name) eq "f3"}} 1 "\n$test:\n  [array get {}]\n "  

  set l [$f3 pretty_link]
  set test [label "url" "subsubfolder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subf3_id && $(stripped_name) eq "subf3"}} 1 "\n$test:\n  [array get {}]\n "  

  set l [$p1 pretty_link]
  set test [label "url" "toppage" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $parentpage_id && $(stripped_name) eq "parentpage"}} 1 "\n$test:\n  [array get {}]\n "

  set l [$p2 pretty_link]
  set test [label "url" "page in folder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $testpage_id && $(stripped_name) eq "testpage"}} 1 "\n$test:\n  [array get {}]\n "

  set l [$p3 pretty_link]
  set test [label "url" "page under page" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $childpage_id && $(stripped_name) eq "childpage"}} 1 "\n$test:\n  [array get {}]\n "

  set l [$p4 pretty_link]
  set test [label "url" "toplevel en page" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $enpage_id && $(stripped_name) eq "page"
	   && $(name) eq "en:page"}} 1 "\n$test:\n  [array get {}]\n "

  set l [$p5 pretty_link]
  set test [label "url" "en page under subfolder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $f3page_id && $(stripped_name) eq "page"
	   && $(name) eq "en:page"}} 1 "\n$test:\n  [array get {}]\n "

  # image links

  set l [$i1 pretty_link]
  set test [label "url" "toplevel image" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $image_id && $(stripped_name) eq "image.png"
	   && $(name) eq "file:image.png"}} 1 "\n$test:\n  [array get {}]\n "

  set l [$i2 pretty_link]
  set test [label "url" "toplevel image" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subimage_id && $(stripped_name) eq "image2.png"
	   && $(name) eq "file:image2.png"}} 1 "\n$test:\n  [array get {}]\n "

  set l [$i3 pretty_link]
  set test [label "url" "toplevel image" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $childimage_id && $(stripped_name) eq "image3.png"
	   && $(name) eq "file:image3.png" && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n "

  
  # links
 
  set l [$l1 pretty_link]
  set test [label "url" "toplevel link to page" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $pagelink_id && $(stripped_name) eq "link1"
	   && $(name) eq "link1" && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n "

  set l [$l2 pretty_link]
  set test [label "url" "toplevel link to folder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $folderlink_id && $(stripped_name) eq "link2"
	   && $(name) eq "link2" && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n "

  set l [$l3 pretty_link]
  set test [label "url" "toplevel link to page under folder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subpagelink_id && $(stripped_name) eq "link3"
	   && $(name) eq "link3" && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n "

  set l [$l4 pretty_link]
  set test [label "url" "toplevel link to folder under folder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subfolderlink_id && $(stripped_name) eq "link4"
	   && $(name) eq "link4" && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n "

  set l [$l5 pretty_link]
  set test [label "url" "toplevel link to image under folder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subimagelink_id && $(stripped_name) eq "link5"
	   && $(name) eq "link5" && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n "


  test section "item info from variations of pretty links"  

  # download
  set l /XOWIKI-TEST/download/file/image.png
  set test [label "url" "toplevel image download" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $image_id && $(stripped_name) eq "image.png"
	   && $(name) eq "file:image.png"  && $(method) eq "download"}} 1 "\n$test:\n  [array get {}]\n "

  # download via link
  set l /XOWIKI-TEST/download/file/link5
  set test [label "url" "toplevel image download" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subimagelink_id && $(stripped_name) eq "link5"
  	   && $(name) eq "link5"  && $(method) eq "download"}} 1 "\n$test:\n  [array get {}]\n "

  # tag link
  set l /XOWIKI-TEST/tag/a
  set test [label "url" "tag query" $l]
  array set "" [$package_id item_info_from_url -default_lang de $l]
  ? {expr {$(item_id) != 0 && $(stripped_name) eq "weblog"
	   && $(name) eq "en:weblog"  && $(method) eq ""}} 1 "\n$test:\n  [array get {}]\n"  
  # missing: tag links to subdirectories

  # url without default lang
  set l /XOWIKI-TEST/parentpage
  set test [label "url" "toppage w/o de" $l]
  array set "" [$package_id item_info_from_url -default_lang de $l]
  ? {expr {$(item_id) == $parentpage_id && $(stripped_name) eq "parentpage"}} 1 "\n$test:\n  [array get {}]\n "

  # prefixed name
  set l /XOWIKI-TEST/de:parentpage
  set test [label "url" "toppage prefixed eq default_lang" $l]
  array set "" [$package_id item_info_from_url -default_lang de $l]
  ? {expr {$(item_id) == $parentpage_id && $(stripped_name) eq "parentpage"}} 1 "\n$test:\n  [array get {}]\n "

  set l /XOWIKI-TEST/de:parentpage
  set test [label "url" "toppage prefixed ne default_lang" $l]
  array set "" [$package_id item_info_from_url -default_lang en $l]
  ? {expr {$(item_id) == $parentpage_id && $(stripped_name) eq "parentpage"}} 1 "\n$test:\n  [array get {}]\n "


  test section "item info via links to folders"  
  # reference pages over links to folders

  set l /XOWIKI-TEST/link2/testpage
  set test [label "url" "reference page over links to folder default-lang" $l]
  array set "" [$package_id item_info_from_url -default_lang de $l]
  ? {expr {$(item_id) == $testpage_id && $(stripped_name) eq "testpage"
	 && $(name) eq "de:testpage"}} 1 "\n$test:\n  [array get {}]\n "

  set l /XOWIKI-TEST/link2/de:testpage
  set test [label "url" "reference page over links to folder direct name" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $testpage_id && $(stripped_name) eq "testpage"
	 && $(name) eq "de:testpage"}} 1 "\n$test:\n  [array get {}]\n "

  set l /XOWIKI-TEST/download/file/link2/image2.png
  set test [label "url" "reference download image over links to folder" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $subimage_id && $(stripped_name) eq "image2.png"
	   && $(name) eq "file:image2.png"}} 1 "\n$test:\n  [array get {}]\n "

  set l /XOWIKI-TEST/link2/f3/page
  set test [label "url" "path contains link and references finally page" $l]
  array set "" [$package_id item_info_from_url $l]
  ? {expr {$(item_id) == $f3page_id && $(stripped_name) eq "page"
	   && $(name) eq "en:page"}} 1 "\n$test:\n  [array get {}]\n "


  #test section "inherited pages"  

  # link to site-wide page

  #set l /XOWIKI-TEST/en/folder.form
  #set test [label "url" "site-wide-page top" $l]
  #array set "" [$package_id item_info_from_url -default_lang de $l]
  #? {expr {$(item_id) == $parentpage_id && $(stripped_name) eq "parentpage"}} 1 "\n$test:\n  [array get {}]\n "

  # link to page in other package
  # link to dir in other package

ns_write "<p>
<hr>
 Tests passed: [test set passed]<br>
 Tests failed: [test set failed]<br>
 Tests Time: [t1 diff -start]ms<br>
" 
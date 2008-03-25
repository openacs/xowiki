# regression test for xowiki
# $Id$
Object test
test set passed 0
test set failed 0
test proc case msg {ad_return_top_of_page "<title>$msg</title><h2>$msg</h2>"} 
test proc section msg    {my reset; ns_write "<hr><h3>$msg</h3>"} 
test proc subsection msg {ns_write "<h4>$msg</h4>"} 
test proc errmsg msg     {ns_write "ERROR: $msg<BR/>"; test incr failed}
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
  proc ::ns_queryget key {::xo::cc form_parameter $key ""}
  proc ::ns_querygetall key {::xo::cc form_parameter $key {{}} }
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
     test errmsg "$msg returned '$r' ne '$expected'"
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
site_node::instantiate_and_mount \
    -parent_node_id $node(node_id) \
    -node_name $instance_name \
    -package_name $instance_name \
    -package_key xowiki
#test code [array get node]

? {site_node::exists_p -url /$instance_name} 1 \
    "created test instance /$instance_name"
array set info [site_node::get_from_url -url /$instance_name -exact]
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
? {::xotcl::Object isobject ::${folder_id}::payload} 1 "we have a payload"
? {::$folder_id name} ::$folder_id "name of folder object is ::folder_id"
? {::$folder_id parent_id} $folder_id "parent_id of folder object is folder_id"
? {expr {[::$folder_id item_id]>0}} 1 "item_id given"
? {expr {[::$folder_id revision_id]>0}} 1 "revision_id given"
? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 1 \
    "folder contains the folder object"

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
? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 2 \
    "folder contains the folder object and the index page"
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
? {::xotcl::Object isobject ::${folder_id}::payload} 1 "we have a payload"
? {::$folder_id name} ::$folder_id "name of folder object is ::folder_id"
? {::$folder_id parent_id} $folder_id "parent_id of folder object is folder_id"
? {expr {[::$folder_id item_id]>0}} 1 "item_id given"
? {expr {[::$folder_id revision_id]>0}} 1 "revision_id given"
? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 2 \
    "folder contains the folder object and index"

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

? {db_string count "select count(*) from cr_items where parent_id = $folder_id"} 5 \
    "folder contains: folder object, index and weblog page (+2 includelets)"



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

set full_weblog_content_length $content_length


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
? {expr {$full_weblog_content_length > $content_length}} 1 "summary is shorter"


########################################################################
test section "Testing as SWA: query /$instance_name/ "

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
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 5 \
    "folder contains: folder object, index and weblog page (+2 includelets)"


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
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 4 \
    "folder contains: folder object, index and weblog page (+1 includelet)"

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
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 5 \
    "folder contains: folder object, index and weblog, hello page (+1 includelet)"
? {expr {[$page revision_id]>0}} 1 "revision_id given"
? {expr {[$page item_id]>0}} 1 "item_id given"
set revision_id1 [$page revision_id]
set item_id1 [$page item_id]

$page append title "- V.2"
$page save
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 5 \
    "still 5 pages"
? {expr {[$page revision_id]>$revision_id1}} 1 "revision_id > old revision_id"
? {expr {[$page item_id] == $item_id1}} 1 "item id the same"



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
? {db_string count "select count(*) from cr_items where parent_id=[$package_id folder_id]"} 6 \
    "again, 6 pages"


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
      creator {Gustaf Neumann} 
      description {{this is the description}}
      text {$text ... just testing ..<br />} 
      nls_language en_US 
      folder_id $returned_folder_id 
      title {$title}
      item_id $returned_item_id }]

set content [test without_ns_form {::$package_id invoke -method $m}]
? {string first Error $content} -1 "page contains no error"

? {::xo::cc exists __continuation} 1 "continuation exists"
? {::xo::cc set  __continuation} "ad_returnredirect /$instance_name/hello" \
    "redirect to hello page"

########################################################################
test section "Query revisions for hello page via weblink"

::xowiki::Package initialize -parameter $index_vuh_parms \
    -package_id $info(package_id) \
    -url /$instance_name/en/hello \
    -actual_query "m=revisions" \
    -user_id [lindex $swas 0]

set content [::$package_id invoke -method $m]
? {string first Error $content} -1 "page contains no error"
? {expr {[string first 3: $content]>-1}} 1 "page contains three revisions"


ns_write "<p>
<hr>
 Tests passed: [test set passed]<br>
 Tests failed: [test set failed]<br>
 Tests Time: [t1 diff -start]ms<br>
" 
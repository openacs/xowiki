namespace eval ::xowiki {

  Class create Package -parameter {{folder_id 0} url package_url {use_ns_conn 1}}

  #Package instproc create {name args} {if {![my isobject $name]} {next}}

  Package proc process_query {{-defaults ""}} {
    my instvar queryparm formvars
    if {![info exists query]} {set query [ns_conn query]}
    array unset queryparm
    array unset form_parameter
    array set queryparm $defaults
    foreach querypart [split $query &] {
      set att_val [split $querypart =]
      if {[llength $att_val] == 1} {
	set queryparm([ns_urldecode [lindex $att_val 0]]) 1
      } else {
	set queryparm([ns_urldecode [lindex $att_val 0]]) \
	    [ns_urldecode [lindex $att_val 1]]
      }
    }
    foreach key [array names queryparm] {uplevel [list set $key $queryparm($key)]}
  }

  Package proc instantiate_from_page {{-revision_id 0} {-item_id 0}} {
    set page [::Generic::CrItem instantiate -item_id $item_id -revision_id $revision_id]
    set folder_id [$page set parent_id]
    set package_id [db_string get_pid "select package_id from cr_folders where folder_id = $folder_id"]
    $page set package_id $package_id
    [self] create ::$package_id -folder_id $folder_id -use_ns_conn false
    ::$package_id set_url -url [Page pretty_link -package_id $package_id [$page name]]
    return $page
  }

  Package instproc init args {
    my instvar id
    set id [namespace tail [self]]
    my package_url [site_node::get_url_from_object_id -object_id $id]
    my set policy ::xowiki::policy1   ;# hard-coded for now, could be made configurable
    my require_folder_object
    if {[my use_ns_conn]} {my set_url -url [ns_conn url]}
  }

  Package instproc set_url {-url} {
    my instvar id
    my url $url
    my set object [string range [my url] [string length [my package_url]] end]
    my log "--url=[my url] package_url=[my package_url] package_id=$id fo=[my folder_id]"    
  }

  Package instproc get_parameter {attribute {default ""}} {
    my instvar id folder_id
    set value [$folder_id get_payload $attribute]
    if {$value eq ""} {
      set value [parameter::get -parameter $attribute -package_id $id -default $default]
    }
    return $value
  }

  Package instproc invoke {-method} {
    my instvar object folder_id id policy
    my set mime_type text/html
    my set delivery ns_return
    my log "--object = '$object'"
    if {$object eq ""} {
      set exported [$policy defined_methods Package]
      foreach m $exported {
	if {[my exists_query_parameter $m]} {
	  return [my call $policy [self] $m]
	}
      }
      set object [$id get_parameter index_page]
    }
    if {$object eq ""} {
      # we should change this to the new interface with query_parameter
      #if {[ns_queryget summary] eq ""} {rp_form_put summary 1}
      #set object [$id get_parameter weblog_page "en:weblog"]
      ad_returnredirect "admin/list"
    }
    set page [my resolve_request -path $object]
    if {$page ne ""} {
      return [my call $policy $page $method]
    } else {
      #...
    }
  }

  Package instproc call {policy object method} {
    my log "--p $policy check_permissions $object $method = [$policy check_permissions $object $method]  delivery=[my set delivery]"
    if {[$policy check_permissions $object $method]} {
      my log "--p calling $object ([$object info class]) '$method'"
      $object $method
    } else {
      my log "not allowed to call $object $method"
    }
  }
  Package instforward permission_p {%my set policy} %proc

  Package instproc resolve_request {-path} {
    my instvar folder_id
    #my log "--u [self args]"
    [self class] instvar queryparm
    set item_id 0

    if {$path ne ""} {
      set item_id [::Generic::CrItem lookup -name $path -parent_id $folder_id]
      my log "--try $path -> $item_id"
      
      if {$item_id == 0} {
	if {[regexp {^pages/(..)/(.*)$} $path _ lang local_name]} {
	} elseif {[regexp {^(..)/(.*)$} $path _ lang local_name]} {
	} elseif {[regexp {^(..):(.*)$} $path _ lang local_name]} {
	} elseif {[regexp {^(file|image)/(.*)$} $path _ lang local_name]} {
	} else {
	  set key queryparm(lang)
	  set lang [expr {[info exists $key] ? [set $key] : \
			      [string range [lang::conn::locale] 0 1]}]
	  set local_name $path
	}
	set name ${lang}:$local_name
	if {[info exists name]} {
	  set item_id [::Generic::CrItem lookup -name $name -parent_id $folder_id]
	  my log "--try $name -> $item_id"
	}
	if {$item_id == 0} {
	  set nname [Page normalize_name -package_id [my set id] $name]
	  set item_id [::Generic::CrItem lookup -name $nname -parent_id $folder_id]
	  my log "--try $nname -> $item_id"
	}
      } 
    }
    if {$item_id != 0} {
      set key queryparm(revision_id)
      if {[info exists $key]} {set revision_id [set $key]}
      if {[info exists revision_id]} {
	set item_id 0
      } else {
	set revision_id 0
      }
      my log "--instantiate item_id $item_id revision_id $revision_id"
      set r [::Generic::CrItem instantiate -item_id $item_id -revision_id $revision_id]
      my log "--instantiate done "
      $r set package_id [namespace tail [self]]
      return $r
    } else {
      return ""
    }
  }

  Package instproc require_folder_object { 
    {-store_folder_id:boolean true}
  } {
    my instvar id folder_id
    # the flag store_folder_id should not be necessary, when the id is 
    # always stored in the package TODO

    if {$folder_id == 0} {
      set folder_id [::xowiki::Page require_folder -name xowiki -package_id $id]
    }

    if {![::xotcl::Object isobject ::$folder_id]} {
      # if we can't get the folder from the cache, create it
      if {[catch {eval [nsv_get xotcl_object_cache ::$folder_id]}]} {
	while {1} {
	  set item_id [ns_cache eval xotcl_object_type_cache item_id-of-$folder_id {
	    set myid [CrItem lookup -name ::$folder_id -parent_id $folder_id]
	    if {$myid == 0} break; # don't cache ID
	    return $myid
	  }]
	  break
	}
	if {[info exists item_id]} {
	  # we have a valid item_id and get the folder object
	  #my log "--f fetch folder object -object ::$folder_id -item_id $item_id"
	  ::xowiki::Object fetch_object -object ::$folder_id -item_id $item_id
	} else {
	  # we have no folder object yet. so we create one...
	  ::xowiki::Object create ::$folder_id
	  ::$folder_id set text "# this is the payload of the folder object\n\nset index_page \"\"\n"
	  ::$folder_id set parent_id $folder_id
	  ::$folder_id set name ::$folder_id
	  ::$folder_id set title ::$folder_id
	  ::$folder_id save_new
	  ::$folder_id initialize_loaded_object
	}
      }
      
      #$o proc destroy {} {my log "--f "; next}
      ::$folder_id set package_id $id
      uplevel #0 [list ::$folder_id volatile]
    } else {
      #my log "--f reuse folder object $folder_id [::Serializer deepSerialize ::$folder_id]"
    }
    if {$store_folder_id} {
      Page set folder_id $folder_id
    }

    my set folder_id $folder_id
  }

  Package instproc return_page {-adp -variables -form} {
    my log "--vars=[self args]"
    set __vars [list]
    foreach _var $variables {
      if {[llength $_var] == 2} {
	lappend __vars [lindex $_var 0] [uplevel subst [lindex $_var 1]]
      } else {
	set localvar local.$_var
	upvar $_var $localvar
	if {[info exists $localvar]} {
	  # ignore undefined variables
	  lappend __vars $_var [set $localvar]
	}
      }
    }

    if {[info exists form]} {
      set level [template::adp_level]
      foreach f [uplevel #$level info vars ${form}:*] {
	lappend __vars &$f $f
	upvar #$level $f $f
      }
    }
    my log "--before adp"  ;#$__vars
    set text [template::adp_include $adp $__vars]
    my log "--after adp"
    return $text
  }

  Package instproc query_parameter {name {default ""}} {
    [self class] instvar queryparm
    return [expr {[info exists queryparm($name)] ? $queryparm($name) : $default}]
  }
  Package instproc exists_query_parameter {name} {
    [self class] exists queryparm($name)
  }

  Package instproc form_parameter {name {default ""}} {
    [self class] instvar form_parameter
    if {![info exists form_parameter]} {array set form_parameter [ns_set array [ns_getform]]}
    return [expr {[info exists form_parameter($name)] ? $form_parameter($name) : $default}]
  }
  Package instproc exists_form_parameter {name} {
    [self class] instvar form_parameter
    if {![info exists form_parameter]} {array set form_parameter [ns_set array [ns_getform]]}
    [self class] exists form_parameter($name)
  }


  Package ad_instproc reindex {} {
    reindex all items of this package
  } {
    my instvar folder_id
    db_foreach get_pages "select page_id from xowiki_page, cr_revisions r, cr_items i \
	where page_id = r.revision_id and i.item_id = r.item_id and i.parent_id = $folder_id \
	and i.live_revision = page_id" {
	  #search::queue -object_id $page_id -event DELETE
	  search::queue -object_id $page_id -event INSERT
	}
  }

  Package instproc rss {} {
    my instvar id
    set cmd [list ::xowiki::Page rss -package_id $id]
    set rss [my query_parameter rss]
    if {[regexp {[^0-9]*([0-9]+)d} $rss _ days]} {lappend cmd -days $days}
    eval $cmd
  }

  Package instproc edit-new {} {
    my instvar folder_id id
    set object_type [my query_parameter object_type "::xowiki::Page"]
    set page [$object_type new -volatile -parent_id $folder_id -package_id $id]
    set html [$page edit -new true]
    my log "--e html length [string length $html]"
    return $html
  }
  Package instproc condition {method attr value} {
    switch $attr {
      has_class {set result [expr {[my query_parameter object_type ""] eq $value}]}
      default {set result 0}
    }
    my log "--c [self args] returns $result"
    return $result
  }
 

  Class Policy
  Policy instproc defined_methods {class} {
    set c [self]::$class
    expr {[my isclass $c] ? [$c array names require_permission] : [list]}
  }
  Policy instproc permission_p {object method} {
    foreach class [concat [$object info class] [[$object info class] info heritage]] {
      set c [self]::[namespace tail $class]
      if {![my isclass $c]} continue
      set key require_permission($method)
      if {[$c exists $key]} {
	set permission  [$c set $key]
	if {$permission eq "login" || $permission eq "none"} {
	  return 1
	}
	foreach cond_permission $permission {
	  my log "--cond_permission = $cond_permission"
	  switch [llength $cond_permission] {
	    3 {foreach {condition attribute privilege} $cond_permission break
	      if {[eval $object condition $method $condition]} break
	    }
	    2 {foreach {attribute privilege} $cond_permission break
	      break
	    }
	  }
	}
	my log "--p checking permission::permission_p -object_id [$object set $attribute] -privilege $privilege"
	return [permission::permission_p -object_id [$object set $attribute] -privilege $privilege]
      }
    }
    return 0
  }

  Policy instproc check_permissions {object method} {
    set allowed 0
    foreach class [concat [$object info class] [[$object info class] info heritage]] {
      set c [self]::[namespace tail $class]
      if {![my isclass $c]} continue
      set key require_permission($method)
      if {[$c exists $key]} {
	set permission [$c set $key]
	puts "checking $permission for $c $key"
	switch $permission {
	  none  {set allowed 1; break}
	  login {auth::require_login; set allowed 1; break}
	  default {
	    foreach cond_permission $permission {
	      my log "--c check $cond_permission"
	      switch [llength $cond_permission] {
		3 {foreach {condition attribute privilege} $cond_permission break
		  if {[eval $object condition $method $condition]} break
		}
		2 {foreach {attribute privilege} $cond_permission break
		  break
		}
	      }
	    }
	    my log "--c require_permission -object_id [$object set $attribute] -privilege $privilege"
	    permission::require_permission -object_id [$object set $attribute] -privilege $privilege
	    set allowed 1
	    break
	  }
	}
      }
    }
    return $allowed
  }



  Policy policy1 -contains {
  
    Class Package -array set require_permission {
      reindex            {{id admin}}
      rss                none
      edit-new           {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               {{package_id read}}
      revisions          {{package_id write}}
      edit               {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    {{package_id admin}}
      delete             {{package_id admin}}
      save-tags          login
      popular-tags       login
    }

    Class Object -array set require_permission {
      edit               {{package_id admin}}
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
  }
  
}

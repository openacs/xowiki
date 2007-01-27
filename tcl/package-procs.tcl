ad_library {
    XoWiki - package specific methods

    @creation-date 2006-10-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  ::xo::PackageMgr create Package \
      -superclass ::xo::Package \
      -parameter {{folder_id "[::xo::cc query_parameter folder_id 0]"}}

  Package ad_proc instantiate_page_from_id {
    {-revision_id 0} 
    {-item_id 0}
    {-user_id -1}
    {-parameter ""}
  } {
    Instantiate a page in situations, where the context is not set up
    (e.g. we have no package object or folder obect). This call is convenient
    when testing e.g. from the developer shell
  } {
    #TODO can most probably further simplified
    set page [::Generic::CrItem instantiate -item_id $item_id -revision_id $revision_id]

    #my log "--I instantiate i=$item_id revision_id=$revision_id page=$page"

    $page folder_id [$page set parent_id] 
    if {[apm_version_names_compare [ad_acs_version] 5.2] <= -1} {
      set package_id [db_string get_pid "select package_id from cr_folders where folder_id = [$page $folder_id]"]
      $page package_id $package_id
    } else {
      set package_id [$page set package_id]
    }
    ::xowiki::Package initialize \
	-package_id $package_id -user_id $user_id \
	-parameter $parameter -init_url false -actual_query ""
    ::$package_id set_url -url [::$package_id pretty_link [$page name]]
    return $page
  }

  Package ad_proc get_url_from_id {{-item_id 0} {-revision_id 0}} {
    Get the full URL from a page in situations, where the context is not set up.
    @see instantiate_page_from_id
  } {
    set page [::xowiki::Package instantiate_page_from_id \
                  -item_id $item_id -revision_id $revision_id]
    $page volatile
    return [::[$page package_id] url] 
  }

  #
  # URL and naming management
  #
  
  Package instproc normalize_name {string} {
    set string [string trim $string]
    # if subst_blank_in_name is turned on, turn spaces into _
    if {[my get_parameter subst_blank_in_name 1] != 0} {
      regsub -all { +} $string "_" string
    }
      return [ns_urldecode $string]
  }
  
  Package instproc default_locale {} {
    # TODO: this might be called quite often. we can optimize this my caching into xo::cc
    if {[ns_conn isconnected] && [my get_parameter use_connection_locale 0]} {
      # we are connected, return the connection locale
      set locale [lang::conn::locale]
    } else {
      # return either the package locale or the site-wide locale
      set locale [lang::system::locale -package_id [my id]]
    }
    return $locale
  }
  
  Package instproc default_language {} {
    return [string range [my default_locale] 0 1]
  }
  Package array set www-file {
    admin 1
    diff 1
    doc 1
    edit 1
    error-template 1
    portlet 1     portlet-ajax 1  portlets 1
    prototypes 1 
    ressources 1
    revisions 1 
    view-default view-links view-plain oacs-view
  }
  Package instproc pretty_link {
      {-anchor ""} {-absolute:boolean false} {-lang ""} name 
  } {
    #my log "--u name=<$name>"
    set default_lang [my default_language]
    if {$lang eq ""} {
      if {![regexp {^(..):(.*)$} $name _ lang name]} {
        if {![regexp {^(file|image):(.*)$} $name _ lang name]} {
          set lang $default_lang
        }
      }
    }
    set host [expr {$absolute ? [ad_url] : ""}]
    if {$anchor ne ""} {set anchor \#$anchor}
    #my log "--LINK $lang == $default_lang [expr {$lang ne $default_lang}] $name"

    set package_prefix [my get_parameter package_prefix [my package_url]]
    if {$package_prefix eq "/" && [string length $lang]>2} {
      # don't compact the the path for images etc. to avoid conflicts with e.g. //../image/*
      set package_prefix [my package_url]
    }
    if {$lang ne $default_lang || [[self class] exists www-file($name)]} {
      return ${host}${package_prefix}${lang}/[ad_urlencode $name]$anchor
    } else {
      return ${host}${package_prefix}[ad_urlencode $name]$anchor
    }
  }

  Package instproc init {} {
    #my log "--R creating + folder_object"
    next
    my require_folder_object
    my set policy [my get_parameter security_policy ::xowiki::policy1]
    #my proc destroy {} {my log "--P "; next}
  }

  Package instproc get_parameter {attribute {default ""}} {
    set value [::xo::cc get_parameter $attribute]
    if {$value eq ""} {set value [::[my folder_id] get_payload $attribute]}
    if {$value eq ""} {set value [next]}
    return $value
  }

  #
  # conditional links
  #
  Package instproc make_link {-privilege -url object method args} {
    my instvar id
 
    if {[info exists privilege]} {
      set granted [expr {$privilege eq "public" ? 1 :
                 [permission::permission_p \
                      -object_id $id -privilege $privilege \
                      -party_id [::xo::cc user_id]] }]
    } else {
      # determine privilege from policy
      set granted [my permission_p $object $method]
      #my log "--p $id permission_p $object $method ==> $granted"
    }
    if {$granted} {
      if {[$object istype ::xowiki::Package]} {
        set base  [my package_url]
        if {[info exists url]} {
          return [uplevel export_vars -base [list $base$url] [list $args]]
        } else {
          lappend args [list $method 1]
          return [uplevel export_vars -base [list $base] [list $args]]
        }
      } elseif {[$object istype ::xowiki::Page]} {
        if {[info exists url]} {
          set base $url
        } else {
          set base [my url]
        }
        lappend args [list m $method]
        return [uplevel export_vars -base [list $base] [list $args]]
      }
    }
    return ""
  }


  Package instproc invoke {-method} {
    my set mime_type text/html
    my set delivery ns_return
    set page [my resolve_page [my set object] method]
    if {$page ne ""} {
      return [my call $page $method]
    } else {
      my instvar id
      my get_name_and_lang_from_path [my set object] lang local_name
      set name ${lang}:$local_name
      set object_type ::xowiki::Page ;# for the time being; maybe a parameter?
      set new_link    [my make_link $id edit-new object_type return_url name] 
      if {$new_link ne ""} {
        set edit_snippet "<p>Do you want to create page <a href='$new_link'>$name</a> new?"
      } else {
        set edit_snippet ""
      }
      return [my error_msg "Page <b>'[my set object]'</b> is not available. $edit_snippet"]
    }
  }
  Package instproc reply_to_user {text} {
    if {[::xo::cc exists __continuation]} {
      eval [::xo::cc set __continuation]
    } else {
      if {[string length $text] > 1} {
        [my set delivery] 200 [my set mime_type] $text
      }
    }
  }

  Package instproc error_msg {error_msg} {
    my instvar id
    set template_file error-template
    if {![regexp {^[./]} $template_file]} {
      set template_file /packages/xowiki/www/$template_file
    }
    set context [list [$id instance_name]]
    set title Error
    $id return_page -adp $template_file -variables {
      context title error_msg
    }
  }

  Package instproc resolve_page {object method_var} {
    upvar $method_var method
    my instvar folder_id id policy
    if {$object eq ""} {
      set exported [$policy defined_methods Package]
      foreach m $exported {
	#my log "--QP my exists_query_parameter $m = [my exists_query_parameter $m]"
        if {[::xo::cc exists_query_parameter $m]} {
          set method $m  ;# the only reason for the upvar
          return [self]
        }
      }
    }
    #my log "--o object is '$object'"
    if {$object eq ""} {
      # we have no object, but as well no method callable on the package
      set object [$id get_parameter index_page "index"]
    }
    #my log "--o try index '$object'"
    set page [my resolve_request -path $object]
    #my log "--o page is '$page'"
    if {$page ne ""} {
      return $page
    }

    # stripped object is the object without a language prefix
    set stripped_object $object
    regexp {^..:(.*)$} $object _ stripped_object

    # try standard page
    set standard_page [$id get_parameter ${object}_page]
    #my log "--o standard_page '$standard_page'"
    if {$standard_page ne ""} {
      set page [my resolve_request -path $standard_page]
      if {$page ne ""} {
        return $page
      }
    } else {
      regexp {../([^/]+)$} $object _ object
      set standard_page "en:$stripped_object"
      # maybe we are calling from a different language, but the
      # standard page with en: was already instantiated
      set page [my resolve_request -path $standard_page]
      if {$page ne ""} {
        return $page
      }
    }


    my log "--W object='$stripped_object'"
    set fn [get_server_root]/packages/xowiki/www/prototypes/$stripped_object.page
    if {[file readable $fn]} {
      # create from default page
      my log "--sourcing page definition $fn, using name '$standard_page'"
      set page [source $fn]
      $page configure -name $standard_page \
          -parent_id $folder_id -package_id $id 
      if {![$page exists title]} {
        $page set title $object
      }
      $page destroy_on_cleanup
      $page set_content [string trim [$page text] " \n"]
      $page initialize_loaded_object
      $page save_new
      return $page
    } else {
      my log "no prototype for '$object' found"
      return ""
    }
  }

  Package instproc call {object method} {
    my instvar policy
    if {[$policy check_permissions $object $method]} {
      #my log "--p calling $object ([$object info class]) '$method'"
      $object $method
    } else {
      my log "not allowed to call $object $method"
    }
  }
  Package instforward permission_p {%my set policy} %proc

  Package instproc get_name_and_lang_from_path {path vlang vlocal_name} {
    my upvar $vlang lang $vlocal_name local_name 
    if {[regexp {^pages/(..)/(.*)$} $path _ lang local_name]} {
    } elseif {[regexp {^(..)/(.*)$} $path _ lang local_name]} {
    } elseif {[regexp {^(..):(.*)$} $path _ lang local_name]} {
    } elseif {[regexp {^(file|image)/(.*)$} $path _ lang local_name]} {
    } else {
      set key queryparm(lang)
      if {[info exists $key]} {
        set lang [set $key]
      } else {
        # we can't determine lang from name, or query parameter, so take default
        set lang [my default_language]
      }
      set local_name $path
    }
  }

  Package instproc resolve_request {-path} {
    my instvar folder_id
    #my log "--u [self args]"
    [self class] instvar queryparm
    set item_id 0

    if {$path ne ""} {

      set item_id [::Generic::CrItem lookup -name $path -parent_id $folder_id]
      my log "--try $path -> $item_id"
      
      if {$item_id == 0} {
        my get_name_and_lang_from_path $path lang local_name
        set name ${lang}:$local_name
        set item_id [::Generic::CrItem lookup -name $name -parent_id $folder_id]
        my log "--try $name -> $item_id"
        if {$item_id == 0 && $lang eq "file"} {
          set item_id [::Generic::CrItem lookup -name image:$local_name -parent_id $folder_id]
          my log "--try image:$local_name -> $item_id"
        }
        if {$item_id == 0} {
          set nname   [my normalize_name $name]
          set item_id [::Generic::CrItem lookup -name $nname -parent_id $folder_id]
          my log "--try $nname -> $item_id"
        }
      } 
    }
    if {$item_id != 0} {
      set revision_id [my query_parameter revision_id 0]
      set [expr {$revision_id ? "item_id" : "revision_id"}] 0
      #my log "--instantiate item_id $item_id revision_id $revision_id"
      set r [::Generic::CrItem instantiate -item_id $item_id -revision_id $revision_id]
      $r destroy_on_cleanup
      #my log "--instantiate done  CONTENT\n[$r serialize]"
      $r set package_id [namespace tail [self]]
      return $r
    } else {
      return ""
    }
  }

  Package instproc require_folder_object { } {
    my instvar id folder_id
    #my log "--f [my isobject ::$folder_id] folder_id=$folder_id"

    if {$folder_id == 0} {
      set folder_id [::xowiki::Page require_folder -name xowiki -package_id $id]
    }

    if {![::xotcl::Object isobject ::$folder_id]} {
      # if we can't get the folder from the cache, create it
      if {[catch {eval [nsv_get xotcl_object_cache ::$folder_id]}]} {
        while {1} {
          set item_id [ns_cache eval xotcl_object_type_cache item_id-of-$folder_id {
            set myid [CrItem lookup -name ::$folder_id -parent_id $folder_id]
            if {$myid == 0} break; # don't cache ID if invalid
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
          ::$folder_id set text "# this is the payload of the folder object\n\n\
                #set index_page \"index\"\n"
          ::$folder_id set parent_id $folder_id
          ::$folder_id set name ::$folder_id
          ::$folder_id set title ::$folder_id
          ::$folder_id set package_id $id
          ::$folder_id set publish_status "production"
          ::$folder_id save_new
          ::$folder_id initialize_loaded_object
        }
      }
      #my log "--f new folder object = ::$folder_id"
      #::$folder_id proc destroy {} {my log "--f "; next}
      ::$folder_id set package_id $id
      ::$folder_id destroy_on_cleanup
    } else {
      #my log "--f reuse folder object $folder_id [::Serializer deepSerialize ::$folder_id]"
    }
    
    my set folder_id $folder_id
  }

  Package instproc return_page {-adp:required -variables -form} {
    #my log "--vars=[self args]"
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


  Package ad_instproc reindex {} {
    reindex all items of this package
  } {
    my instvar folder_id
    set pages [db_list get_pages "select page_id from xowiki_page, cr_revisions r, cr_items i \
      where page_id = r.revision_id and i.item_id = r.item_id and i.parent_id = $folder_id \
      and i.live_revision = page_id"]
    #my log "--reindex returns <$pages>"
    foreach page_id $pages {
      #search::queue -object_id $page_id -event DELETE
      search::queue -object_id $page_id -event INSERT
    }
  }

  # the following three functions should be moved form page-proc to here 
  Package instproc rss {} {
    my instvar id
    set cmd [list ::xowiki::Page rss -package_id $id]
    if {[regexp {[^0-9]*([0-9]+)d} [my query_parameter rss] _ days]} {
      lappend cmd -days $days
    }
    eval $cmd
  }
  Package instproc google-sitemap {} {
    my instvar id
    ::xowiki::Page [self proc] -package_id $id
  }
  Package instproc google-sitemapindex {} {
    ::xowiki::Page [self proc]
  }

  Package instproc edit-new {} {
    my instvar folder_id id
    set object_type [my query_parameter object_type "::xowiki::Page"]
    set page [$object_type new -volatile -parent_id $folder_id -package_id $id]
    return [$page edit -new true]
  }

  Package instproc delete {-item_id -name} {
    my instvar folder_id id
    if {![info exists item_id]} {
      set item_id [my query_parameter item_id]
      my log "--D item_id from query parameter $item_id"
      set name    [my query_parameter name]
    }
    if {$item_id ne ""} {
      my log "--D trying to delete $item_id $name"
      ::Generic::CrItem delete -item_id $item_id
      #ns_cache flush xotcl_object_cache ::$item_id;;; done by generic
      # we should probably flush as well cached revisions
      if {$name eq "::$folder_id"} {
        my log "--D deleting folder object ::$folder_id"
        ns_cache flush xotcl_object_cache ::$folder_id
        ns_cache flush xotcl_object_type_cache item_id-of-$folder_id
        ::$folder_id destroy
      }
      set key link-*-$name-$folder_id
      foreach n [ns_cache names xowiki_cache $key] {ns_cache flush xowiki_cache $n}
    } else {
      my log "--D nothing to delete!"
    }
    my returnredirect [my query_parameter "return_url" [$id package_url]]
  }

  Package instproc condition {method attr value} {
    switch $attr {
      has_class {set result [expr {[my query_parameter object_type ""] eq $value}]}
      default {set result 0}
    }
    #my log "--c [self args] returns $result"
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
        if {$permission eq "swa"} {
          return [acs_user::site_wide_admin_p]
        }
        foreach cond_permission $permission {
          #my log "--cond_permission = $cond_permission"
          switch [llength $cond_permission] {
            3 {foreach {condition attribute privilege} $cond_permission break
              if {[eval $object condition $method $condition]} break
            }
            2 {foreach {attribute privilege} $cond_permission break
              break
            }
          }
        }
        set id [$object set $attribute]
        #my log "--p checking permission::permission_p -object_id $id -privilege $privilege"
        return [::xo::cc permission -object_id $id -privilege $privilege \
                    -party_id [xo::cc user_id]]
      }
    }
    return 0
  }

  Policy instproc check_permissions {object method} {
    #my log "--p check_permissions {$object $method}"
    set allowed 0
    foreach class [concat [$object info class] [[$object info class] info heritage]] {
      set c [self]::[namespace tail $class]
      if {![my isclass $c]} continue
      set key require_permission($method)
      if {[$c exists $key]} {
        set permission [$c set $key]
        #my log "--p checking $permission for $c $key"
        switch $permission {
          none  {set allowed 1; break}
          login {auth::require_login; set allowed 1; break}
          swa   {
            set allowed [acs_user::site_wide_admin_p]
            if {!$allowed} {
              ad_return_warning "Insufficient Permissions" \
                  "Only side wide admins are allowed for this operation!"
              ad_script_abort
            }
          }
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
            set id [$object set $attribute]
            #my log "--p require_permission -object_id $id -privilege $privilege"
            set p [::xo::cc permission -object_id $id -privilege $privilege]
            if {!$p} {
              ns_log notice "permission::require_permission: [::xo::cc user_id] doesn't \
		have $privilege on object $id"
              ad_return_forbidden  "Permission Denied"  "<blockquote>
  You don't have permission to $privilege [$object name].
</blockquote>"
              ad_script_abort
            }
            #permission::require_permission -object_id $id -privilege $privilege
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
      reindex             swa
      rss                 none
      google-sitemap      none
      google-sitemapindex none
      delete              {{id admin}}
      edit-new            {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               none
      revisions          {{package_id write}}
      diff               {{package_id write}}
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
      download           none
    }
  }


  Policy policy2 -contains {
    #
    # we require side wide admin rights for deletions
    #

    Class Package -array set require_permission {
      reindex            {{id admin}}
      rss                none
      google-sitemap      none
      google-sitemapindex none
      delete             swa
      edit-new           {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               {{package_id read}}
      revisions          {{package_id write}}
      diff               {{package_id write}}
      edit               {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    swa
      delete             swa
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
  
  Policy policy3 -contains {
    #
    # we require side wide admin rights for deletions
    # we perform checking on item_ids for pages. 
    #

    Class Package -array set require_permission {
      reindex            {{id admin}}
      rss                none
      google-sitemap      none
      google-sitemapindex none
      delete             swa
      edit-new           {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               {{item_id read}}
      revisions          {{item_id write}}
      diff               {{item_id write}}
      edit               {{item_id write}}
      make-live-revision {{item_id write}}
      delete-revision    swa
      delete             swa
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




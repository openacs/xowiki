::xo::library doc {
  XoWiki - package specific methods

  @creation-date 2006-10-10
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {

  ::xo::PackageMgr create ::xowiki::Package \
      -superclass ::xo::Package \
      -pretty_name "XoWiki" \
      -package_key xowiki \
      -parameter {
        {folder_id 0}
        {force_refresh_login false}
      }
  # {folder_id "[::xo::cc query_parameter folder_id 0]"}

  if {[apm_version_names_compare [ad_acs_version] 5.2] <= -1} {
    error "We require at least OpenACS Version 5.2; current version is [ad_acs_version]"
  }

  Package ad_proc get_package_id_from_page_id {
    {-revision_id 0} 
    {-item_id 0}
  } {
    Obtain the package_id from either the item_id or the revision_id of a page
  } {
    if {$revision_id} {
      set object_id $revision_id
    } elseif {$item_id} {
      set object_id $item_id
    } else {
      error "Either item_id or revision_id must be provided"
    }
    return [::xo::dc get_value get_pid {select package_id from acs_objects where object_id = :object_id}]
  }

  Package ad_proc instantiate_page_from_id {
    {-revision_id 0} 
    {-item_id 0}
    {-user_id -1}
    {-parameter ""}
  } {
    Instantiate a page in situations, where the context is not set up
    (e.g. we have no package object). This call is convenient
    when testing e.g. from the developer shell
  } {
    set package_id [my get_package_id_from_page_id \
                        -item_id $item_id \
                        -revision_id $revision_id]
    ::xo::Package initialize \
        -export_vars false \
        -package_id $package_id \
        -init_url false -actual_query "" \
        -parameter $parameter \
        -user_id $user_id
    set page [::xo::db::CrClass get_instance_from_db -item_id $item_id -revision_id $revision_id]
    ::$package_id set_url -url [$page pretty_link]
    return $page
  }

  Package ad_proc get_url_from_id {{-item_id 0} {-revision_id 0}} {
    Get the full URL from a page in situations, where the context is not set up.
    @see instantiate_page_from_id
  } {
    set page [::xowiki::Package instantiate_page_from_id \
                  -item_id $item_id -revision_id $revision_id]
    return [::[$page package_id] url] 
  }

  #
  # URL and naming management
  #
  Package instproc split_name {string} {
    set prefix ""
    regexp {^([a-z][a-z]|file|image|video|audio|js|css|swf|folder):(.*)$} $string _ prefix suffix
    return [list prefix $prefix suffix $suffix]
  }
  Package instproc join_name {{-prefix ""} -name} {
    if {$prefix ne ""} {
      return ${prefix}:$name
    }
    return $name
  }

  Package instproc normalize_name {{-with_prefix:boolean false} string} {
    #
    # Normalize the name (in a narrow sense) which refers to a
    # page. This name is not necessarily the content of the "name"
    # field of the content repository, but the name without prefix
    # (sometimes called stripped_name).
    #
    if {$with_prefix} {
      set name_info [my split_name $string]
      set prefix [dict get $name_info prefix]
      set suffix [dict get $name_info suffix]
    } else {
      set prefix ""
      set suffix $string
    }
    set suffix [string trim $suffix]
    # temporary measure; TODO: remove the following if-clause
    if {[string match *:* $suffix]} {
      ad_log warning "normalize_name receives name '$suffix' containing a colon. A missing -with_prefix?"
      xo::show_stack
    }
    regsub -all {[\#/\\:]} $suffix _ suffix
    # if subst_blank_in_name is turned on, turn spaces into _
    if {[my get_parameter subst_blank_in_name 1]} {
      regsub -all { +} $suffix "_" suffix
    }
    return [my join_name -prefix $prefix -name $suffix]
  }

  Package instproc default_locale {} {
    if {[my exists __default_locale]} {
      return [my set __default_locale]
    }
    if {[my get_parameter use_connection_locale 0]} {
      # we return the connection locale (if not connected the system locale)
      set locale [::xo::cc locale]
    } else {
      # return either the package locale or the site-wide locale
      set locale [lang::system::locale -package_id [my id]]
    }
    my set __default_locale $locale
    return $locale
  }

  Package proc get_nls_language_from_lang {lang} {
    # Return the first nls_language matching the provided lang
    # prefix. This method is not precise (when e.g. two nls_languages
    # are defined with the same lang), but the only thing relvant is
    # the lang anyhow.  If nothing matches return empty.
    foreach nls_language [lang::system::get_locales] {
      if {[string range $nls_language 0 1] eq $lang} {
        return $nls_language
      }
    }
    return ""
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
    view-default 1 view-links 1 view-plain 1 oacs-view 1 oacs-view2 1 oacs-view3 1
    view-book 1 view-book-no-ajax 1 view-oacs-docs 1
    download 1
  }
  
  Package instproc get_lang_and_name {-path -name {-default_lang ""} vlang vlocal_name} {
    my upvar $vlang lang $vlocal_name local_name 
    if {[info exists path]} {
      # 
      # Determine lang and name from a path with slashes
      #
      if {[regexp {^pages/(..)/(.*)$} $path _ lang local_name]} {
      } elseif {[regexp {^([a-z][a-z])/(.*)$} $path _ lang local_name]} {

        # TODO we should be able to get rid of this by using a canonical /folder/ in 
        # case of potential conflicts, like for file....

        # check if we have a LANG - FOLDER "conflict"
        set item_id [::xo::db::CrClass lookup -name $lang -parent_id [my folder_id]]
        if {$item_id} {
          my msg "We have a lang-folder 'conflict' (or a two-char folder) with folder: $lang"
          set local_name $path
          if {$default_lang eq ""} {set default_lang [my default_language]}
          set lang $default_lang
        }

      } elseif {[regexp {^(file|image|swf|download/file|download/..|tag)/(.*)$} $path _ lang local_name]} {
      } else {
        set local_name $path
        if {$default_lang eq ""} {set default_lang [my default_language]}
        set lang $default_lang
      }
    } elseif {[info exists name]} {
      # 
      # Determine lang and name from a names as it stored in the database
      #
      if {![regexp {^(..):(.*)$} $name _ lang local_name]} {
        if {![regexp {^(file|image|swf):(.*)$} $name _ lang local_name]} {
          set local_name $name
          if {$default_lang eq ""} {set default_lang [my default_language]}
          set lang $default_lang
        }
      }
    }
  }
  
  Package instproc get_page_from_super {-folder_id:required name} {
    set package [self]
    set inherit_folders [FormPage get_super_folders $package $folder_id]
    
    foreach item_ref $inherit_folders {
      set folder [::xo::cc cache [list $package get_page_from_item_ref $item_ref]]
      if {$folder eq ""} {
        ad_log error "Could not resolve parameter folder page '$item_ref' of FormPage [self]."
      } else {
        set item_id [::xo::db::CrClass lookup -name $name -parent_id [$folder item_id]]
        if { $item_id != 0 } {
          return $item_id
        }
      }
    }
    return 0
  }


  Package instproc get_parent_and_name {-path:required -lang:required -parent_id:required vparent vlocal_name} {
    my upvar $vparent parent $vlocal_name local_name 
    if {[regexp {^([^/]+)/(.+)$} $path _ parent local_name]} {

      # try without a prefix
      set p [my lookup -name $parent -parent_id $parent_id]
      if {$p == 0} {
        # check if page is inherited
        set p2 [my get_page_from_super -folder_id $parent_id $parent]
        if { $p2 != 0 } {
          set p $p2
        }
      }

      if {$p == 0} {
        # content pages are stored with a lang prefix
        set p [my lookup -name ${lang}:$parent -parent_id $parent_id]
        #my log "check with prefix '${lang}:$parent' returned $p"

        if {$p == 0 && $lang ne "en"} {
          # try again with prefix "en"
          set p [my lookup -name en:$parent -parent_id $parent_id]
          #my log "check with en 'en:$parent' returned $p"
        }
      }

      if {$p != 0} {
        if {[regexp {^([^/]+)/(.+)$} $local_name _ parent2 local_name2]} {
          set p2 [my get_parent_and_name -path $local_name -lang $lang -parent_id $p parent local_name]
          #my log "recursive call for '$local_name' parent_id=$p returned $p2"
          if {$p2 != 0} {
            set p $p2
          }
        }
      }

      if {$p != 0} {
        return $p 
      }
    }
    set parent ""
    # a trailing slash indicates a directory, remove it from the path
    set local_name [string trimright $path /]
    return $parent_id
  }

  Package instproc get_page_from_name {{-parent_id ""} {-assume_folder false} -name:required} {
    # Check if an instance with this name exists in the current package.
    if {$assume_folder} {
      set lookup_name $name
    } else {
      my get_lang_and_name -name $name lang stripped_name
      set lookup_name $lang:$stripped_name
    }
    set item_id [my lookup -parent_id $parent_id -name $lookup_name]
    if {$item_id != 0} {
      return [::xo::db::CrClass get_instance_from_db -item_id $item_id]
    }
    return ""
  }

  Package instproc folder_path {{-parent_id ""} {-context_url ""} {-folder_ids ""}} {
    #
    # handle different parent_ids
    #
    if {$parent_id eq "" || $parent_id == [my folder_id]} {
      return ""
    }
    #
    # The item might be in a folder along the folder path.  so it
    # will be found by the object resolver. For the time being, we
    # do nothing more about this.
    #
    #
    if { $context_url ne {} } {
      set parts [split $context_url /]
      set index [expr {[llength $parts]-1}]
    }

    if { $context_url ne {} } {
      set context_id [my get_parent_and_name -path $context_url -lang "" -parent_id $parent_id parent local_name]
      #my msg "context_url $context_url folder_ids $folder_ids context_id $context_id"
    }

    set path ""
    set ids {}
    while {1} {
      lappend ids $parent_id
      set fo [::xo::db::CrClass get_instance_from_db -item_id $parent_id]
      if { $context_url ne {} } {
        set context_name [lindex $parts $index]
        if {1 && $parent_id in $folder_ids} {
          #my msg "---- parent $parent_id in $folder_ids"
          set context_id [$context_id item_id]
          set fo [::xo::db::CrClass get_instance_from_db -item_id $context_id]
        } else {
          #my msg "context_url $context_url, parts $parts, context_name $context_name // parts $parts // index $index / folder $fo"
          
          if { [$fo name] ne $context_name } {
            set context_folder [my get_page_from_name -parent_id $parent_id -assume_folder true -name $context_name]
            if {$context_folder eq ""} {
              my msg "my get_page_from_name -parent_id $parent_id -assume_folder true -name $context_name ==> EMPTY"
              my msg "Cannot lookup '$context_name' in package folder $parent_id [$parent_id name]"
              
              set new_path [join [lrange $parts 0 $index] /]
              set p2 [my get_parent_and_name -path [join [lrange $parts 0 $index] /] -lang "" -parent_id $parent_id parent local_name]
              my msg "p2=$p2 new_path=$new_path '$local_name' ex=[nsf::object::exists $p2] [$p2 name]"
              
            }
            my msg "context_name [$context_folder serialize]"
            set context_id [$context_folder item_id]
            set fo [::xo::db::CrClass get_instance_from_db -item_id $context_id]
          }
          incr index -1
        }
      }

      #my get_lang_and_name -name [$fo name] lang stripped_name
      #set path $stripped_name/$path

      if {[$fo parent_id] < 0} break
      
      if {[$fo is_link_page]} {
        set pid [$fo package_id]
        foreach id $ids {
          if {[$id package_id] ne $pid} {
            #my msg "SYMLINK ++++ have to fix package_id of $id from [$id package_id] to $pid"
            $id set_resolve_context -package_id $pid -parent_id [$id parent_id]
          }
        }
        if {0} {
          #
          # In some older versions, this code was necesary. Keep it
          # inhere as a reference, in case not all relvant cases were
          # covered by the tests
          #
          set target [$fo get_target_from_link_page]
          set target_name [$target name]
          #my msg "----- $path //  target $target [$target name] package_id [$target package_id] path '$path'"
          set orig_path $path
          regsub "^$target_name/" $path "" path
          if {$orig_path ne $path} {
            my msg "----> orig <$orig_path> new <$path> => full [$fo name]/$path"
          }
        }
      }
      
      # prepend always the actual folder name
      set path [ad_urlencode_path [$fo name]]/$path
      
      if {[my folder_id] == [$fo parent_id]} {
        #my msg ".... my folder_id [my folder_id] == $fo parentid"
        break
      }

      set parent_id [$fo parent_id]
    }

    #my msg ====$path
    return $path
  }
  

  Package ad_instproc external_name {
    {-parent_id ""}
    name 
  } {
    Generate a name with a potentially inserted parent name

    @param parent_id parent_id (for now just for download)
    @param name name of the wiki page
  } {
    set folder [my folder_path -parent_id $parent_id]
    if {$folder ne ""} {
      # Return the stripped name for sub-items, the parent has already
      # the language prefix
      #my get_lang_and_name -name $name lang stripped_name
      return $folder$name
    }
    return $name

  }

  Package ad_instproc pretty_link {
    {-anchor ""} 
    {-query ""} 
    {-absolute:boolean false} 
    {-siteurl ""}
    {-lang ""} 
    {-parent_id ""}
    {-download false} 
    {-context_url ""}
    {-folder_ids ""}
    name 
  } {
    Generate a (minimal) link to a wiki page with the specified name.
    Pratically all links in the xowiki systems are generated through this
    function. 

    @param anchor anchor to be added to the link
    @param absolute make an absolute link (including protocol and host)
    @param lang use the specified 2 character language code (rather than computing the value)
    @param download create download link (without m=download)
    @param parent_id parent_id
    @param name name of the wiki page
  } {
    #my msg "input name=$name, lang=$lang parent_id=$parent_id"
    set default_lang [my default_language]
    
    my get_lang_and_name -default_lang $lang -name $name lang name

    set host [expr {$absolute ? ($siteurl ne "" ? $siteurl : [ad_url]) : ""}]
    if {$anchor ne ""} {set anchor \#$anchor}
    if {$query ne ""} {set query ?$query}
    #my log "--LINK $lang == $default_lang [expr {$lang ne $default_lang}] $name"

    set package_prefix [my get_parameter package_prefix [my package_url]]
    if {$package_prefix eq "/" && [string length $lang]>2} {
      # don't compact the the path for images etc. to avoid conflicts
      # with e.g. //../image/*
      set package_prefix [my package_url]
    }
    #my msg "lang=$lang, default_lang=$default_lang, name=$name, parent_id=$parent_id, package_prefix=$package_prefix"
    set encoded_name [ad_urlencode_path $name]

    if {$parent_id eq -100} {
      # In case, we have a cr-toplevel entry, we assume, we can
      # resolve it at lease against the root folder of the current
      # package.
      set folder ""
      set encoded_name ""
    } else {
      if {$parent_id eq ""} {
        ns_log notice "pretty_link of $name: you should consider to pass a parent_id to support folders"
        set parent_id [my folder_id]
      }
      set folder [my folder_path -parent_id $parent_id -folder_ids $folder_ids]
      set pkg [$parent_id package_id]
      if {![my isobject ::$pkg]} {
        ::xowiki::Package initialize -package_id $pkg -init_url false -keep_cc true
      }
      set package_prefix [$pkg get_parameter package_prefix [$pkg package_url]]
    }
    #my msg "folder_path = $folder, -parent_id $parent_id -folder_ids $folder_ids // default_lang [my default_language]"

    # if {$folder ne ""} {
    #   # if folder has a different language than the content, we have to provide a prefix....
    #   regexp {^(..):} $folder _ default_lang
    # }

    #my log "h=${host}, prefix=${package_prefix}, folder=$folder, name=$encoded_name anchor=$anchor download=$download"
    #my msg folder=$folder,lang=$lang,default_lang=$default_lang
    if {$download} {
      #
      # use the special download (file) syntax
      #
      set url ${host}${package_prefix}download/file/$folder$encoded_name$query$anchor
    } elseif {$lang ne $default_lang || [[self class] exists www-file($name)]} {
      #
      # If files are physical files in the www directory, add the
      # language prefix
      #
      set url ${host}${package_prefix}${lang}/$folder$encoded_name$query$anchor
    } else {
      #
      # Use the short notation without language prefix
      #
      set url ${host}${package_prefix}$folder$encoded_name$query$anchor
    }
    #my msg "final url=$url"
    return $url
  }

  Package instproc init {} {
    #my log "--R creating + folder_object"
    next
    my require_folder_object
    my set policy [my get_parameter -check_query_parameter false security_policy ::xowiki::policy1]
    #my proc destroy {} {my log "--P "; next}
  }

  #
  # We could refine here the caching behavior in xowiki
  #
  #Package instproc handle_http_caching {} {
  #  next
  #}

  Package ad_instproc get_parameter {{-check_query_parameter true} {-type ""} attribute {default ""}} {
    resolves configurable parameters according to the following precedence:
    (1) values specifically set per page {{set-parameter ...}}
    (2) query parameter
    (3) form fields from the parameter_page FormPage
    (4) standard OpenACS package parameter
  } {
    set value [::xo::cc get_parameter $attribute]
    if {$check_query_parameter && $value eq ""} {set value [string trim [my query_parameter $attribute]]}
    if {$value eq "" && $attribute ne "parameter_page"} {
      #
      # Try to get the parameter from the parameter_page.  We have to
      # be very cautious here to avoid recursive calls (e.g. when
      # resolve_page_name needs as well parameters such as
      # use_connection_locale or subst_blank_in_name, etc.).
      #
      set pp [my get_parameter parameter_page ""]
      if {$pp ne ""} {
        if {![regexp {/?..:} $pp]} {
          ad_log error "Name of parameter page '$pp' of package [my id] must contain a language prefix"
        } else {
          set page [::xo::cc cache [list [self] get_page_from_item_ref $pp]]
          if {$page eq ""} {
            ad_log errpr "Could not resolve parameter page '$pp' of package [my id]."
          }
          #my msg pp=$pp,page=$page-att=$attribute

          if {$page ne "" && [$page exists instance_attributes]} {
            set __ia [$page set instance_attributes]
            if {[dict exists $__ia $attribute]} {
              set value [dict get $__ia $attribute]
            }
          }
        }
      }
    }
    #if {$value eq ""} {set value [::[my folder_id] get_payload $attribute]}
    if {$value eq ""} {set value [next $attribute $default]}
    if {$type ne ""} {
      # to be extended and generalized
      switch $type {
        word {if {[regexp {\W} $value]} {error "value '$value' contains invalid character"}}
        default {error "requested type unknown: $type"}
      }
    }
    #my log "           $attribute returns '$value'"
    return $value
  }

  Package instproc resolve_package_path {path name_var} {
    #
    # In case, we can resolve the path against an xowiki instance,
    # require the package, set the provided name of the object and
    # return the package_id. If we cannot resolve the name, turn 0.
    #
    my upvar $name_var name

    # Set output variable always to some value
    set name $path

    if {[regexp {^/(/.*)$} $path _ path]} {
      array set "" [site_node::get_from_url -url $path]
      if {$(package_key) eq "acs-subsite"} {
        # the main site
        return 0
      }
      set package_id $(package_id)
      set package_class [::xo::PackageMgr get_package_class_from_package_key $(package_key)]
      if {$package_class ne ""} {
        # we found an xo::Package, but is it an xowiki package?
        set classes [concat $package_class [$package_class info heritage]]
        if {"::xowiki::Package" in $classes} {
          # yes, it is an xowiki::package, compute the name and return the package_id
          ::xowiki::Package require $package_id
          set name [string range $path [string length $(url)] end]
          return $package_id
        }
      }
    } elseif {!([string match "http*://*" $path] || [string match "ftp://*" $path])} {
      return [my id]
    }

    return 0
  }

  Package instproc get_package_id_from_page_name {{-default_lang ""} page_name} {
    #
    # Return package id + remaining page name
    #
    set package_id [my id]
    if {[regexp {^/(/[^/]+/)(.*)$} $page_name _ url page_name]} {
      set provided_name $page_name
      array set "" [site_node::get_from_url -url $url]
      if {$(package_id) eq ""} {return ""}
      if {$(name) ne ""} {set package_id $(package_id)}
      ::xowiki::Package require $package_id
      my get_lang_and_name -default_lang $default_lang -path $page_name lang stripped_name
      set page_name $lang:$stripped_name
      set url $(url)
      set search 0
    } else {
      set url [my url]/
      set provided_name $page_name
      set search 1
    }
    #my msg [self args]->[list package_id $package_id page_name $page_name url $url provided_name $provided_name search $search]
    return [list package_id $package_id page_name $page_name url $url provided_name $provided_name search $search]
  }

  Package instproc resolve_page_name {{-default_lang ""} page_name} {
    #
    # This is a very simple version for resolving page names in an
    # package instance.  It can be called either with a full page
    # name with a language prefix (as stored in the CR) for the
    # current package, or with a path (starting with a //) pointing to
    # an xowiki instance followed by the page name.
    #
    # Examples
    #    ... resolve_page_name en:index
    #    ... resolve_page_name //xowiki/en:somepage
    #
    # The method returns either the page object or empty ("").
    #
    return [my get_page_from_item_ref -allow_cross_package_item_refs true -default_lang $default_lang $page_name]
    #array set "" [my get_package_id_from_page_name $page_name]
  }

  Package instproc resolve_page_name_and_init_context {{-lang} page_name} {
    # todo: currently only used from
    # Page->resolve_included_page_name. maybe, it could be replaced by
    # get_page_from_name or get_page_from_item_ref
    set page ""
    #
    # take a local copy of the package_id, since it is possible
    # that the variable package_id might changed to another instance.
    #
    set package_id [my id]
    array set "" [my get_package_id_from_page_name $page_name]
    if {$(package_id) != $package_id} {
      #
      # Handle cross package resolve requests
      #
      # Note, that package::initialize might change the package id.
      # Preserving the package-url is just necessary, if for some
      # reason the same package is initialized here with a different 
      # url. This could be done probably with a flag to initialize,
      # but we get below the object name from the package_id...
      #
      #my log "cross package request $page_name"
      #
      set last_package_id $package_id
      set last_url [my url]
      #
      # TODO: We assume here that the package is an xowiki package.
      #       The package might be as well a subclass of xowiki...
      #       For now, we fixed the problem to perform reclassing in
      #       ::xo::Package init and calling a per-package instance 
      #       method "initialize"
      #
      ::xowiki::Package initialize -parameter {{-m view}} -url $(url)$(provided_name) \
          -actual_query ""
      #my log "url=$url=>[$package_id serialize]"
      
      if {$package_id != 0} {
        #
        # For the resolver, we create a fresh context to avoid recursive loops, when
        # e.g. revision_id is set through a query parameter...
        #
        set last_context [expr {[$package_id exists context] ? [$package_id context] : "::xo::cc"}]
        $package_id context [::xo::Context new -volatile]
        set object_name [$package_id set object]
        #my log "cross package request got object=$object_name"
        #
        # A user might force the language by preceding the
        # name with a language prefix.
        #
        #my log "check '$object_name' for lang prefix"
        if {![regexp {^..:} $object_name]} {
          if {![info exists lang]} {
            set lang [my default_language]
          }
          set object_name ${lang}:$object_name
        }
        set page [$package_id resolve_page -simple true $object_name __m]
        $package_id context $last_context
      }
      $last_package_id set_url -url $last_url
      
    } else {
      # It is not a cross package request
      set last_context [expr {[$package_id exists context] ? [$package_id context] : "::xo::cc"}]
      $package_id context [::xo::Context new -volatile]
      set page [$package_id resolve_page -use_package_path $(search) $(page_name) __m]
      $package_id context $last_context
    }
    #my log "returning $page"
    return $page
  }


  Package instproc show_page_order {} {
    return [my get_parameter display_page_order 1]
  }

  #
  # conditional links
  #
  Package ad_instproc make_link {{-with_entities 0} -privilege -link object method args} {
    Creates conditionally a link for use in xowiki. When the generated link 
    will be activated, the specified method of the object will be invoked.
    make_link checks in advance, wether the actual user has enough 
    rights to invoke the method. If not, this method returns empty.
    
    @param Object The object to which the link refers to. If it is a package_id it will base \
        to the root_url of the package_id. If it is a page, it will base to the page_url
    @param method Which method to use. This will be appended as "m=method" to the url. 

    Examples for methods:
    <ul>
    <li>view: To view and existing page</li>
    <li>edit: To edit an existing page</li>
    <li>revisions: To view the revisions of an existing page</li>
    </ul>

    @param args List of attributes to be append to the link. Every element 
    can be an attribute name, or a "name value" pair. Behaves like export_vars.

    @return The link or empty
    @see export_vars
  } {
    my instvar id

    set computed_link ""
    #set msg "make_link obj=$object, [$object info class]"
    #if {[info exists link]} {append msg " link '$link'"}
    #if {"::xowiki::Page" in [$object info precedence]} {
    #  append msg " [$object name] [$object package_id] [$object physical_package_id]"
    #}
    #my msg $msg
    if {[$object istype ::xowiki::Package]} {
      set base  [my package_url]
      if {[info exists link]} {
        set computed_link [uplevel export_vars -base [list $base$link] [list $args]]
      } else {
        lappend args [list $method 1]
        set computed_link [uplevel export_vars -base [list $base] [list $args]]
      }
    } elseif {[$object istype ::xowiki::Page]} {
      if {[info exists link]} {
        set base $link
      } else {
        set base [my url]
        #my msg "base = '[my url]'"
      }
      lappend args [list m $method]
      set computed_link [uplevel export_vars -base [list $base] [list $args]]
      #my msg "computed_link = '$computed_link'"
    }
    if {$with_entities} {
      regsub -all & $computed_link "&amp;" computed_link
    }

    # provide links based in untrusted_user_id
    set party_id [::xo::cc set untrusted_user_id]
    if {[info exists privilege]} {
      #my log "-- checking priv $privilege for [self args] from id $id"
      set granted [expr {$privilege eq "public" ? 1 :
                         [::xo::cc permission -object_id $id -privilege $privilege -party_id $party_id] }]
    } else {
      # determine privilege from policy
      #my msg "-- check permissions from $id of object $object $method"
      if {[catch {
        set granted [my check_permissions \
                         -user_id $party_id \
                         -package_id $id \
                         -link $computed_link $object $method]
      } errorMsg ]} {
        ns_log error "error in check_permissions: $errorMsg"
        set granted 0
      }
      #my msg "--p $id check_permissions $object $method ==> $granted"
    }
    #my log "granted=$granted $computed_link"
    if {$granted} {
      return $computed_link
    }
    return ""
  }

  Package instproc make_form_link {-form {-parent_id ""} -title -name -nls_language -return_url} {
    my instvar id
    # use the same instantiate_forms as everywhere; TODO: will go to a different namespace
    set form_id [lindex [::xowiki::Weblog instantiate_forms \
                             -parent_id $parent_id \
                             -forms $form \
                             -package_id $id] 0]
    #my log "instantiate_forms -parent_id $parent_id -forms $form => $form_id "
    if {$form_id ne ""} {
      if {$parent_id eq ""} {unset parent_id}
      set form_link [$form_id pretty_link]
      #my msg "$form -> $form_id -> $form_link -> [my make_link -with_entities 0 -link $form_link $form_id \
          #            create-new return_url title parent_id name nls_language]"
      return [my make_link -with_entities 0 -link $form_link $form_id \
                  create-new return_url title parent_id name nls_language]
    }
  }

  Package instproc create_new_snippet {
    {-object_type ::xowiki::Page}
    provided_name
  } {
    my get_lang_and_name -path $provided_name lang local_name
    set name ${lang}:$local_name
    set new_link [my make_link [my id] edit-new object_type return_url name] 
    if {$new_link ne ""} {
      return "<p>Do you want to create page <a href='[ns_quotehtml $new_link]'>$name</a> new?"
    } else {
      return ""
    }
  }
  
  Package array set delegate_link_to_target {
    csv-dump 1 download 1 list 1
  }
  
  Package instproc invoke {-method {-error_template error-template} {-batch_mode 0}} {
    if {![regexp {^[.a-zA-Z0-9_-]+$} $method]} {return [my error_msg "No valid method provided!"] }
    if {[catch {set page_or_package [my resolve_page [my set object] method]} errorMsg]} {
      return [my error_msg -template_file $error_template $errorMsg]
    }
    ::xo::cc invoke_object $page_or_package
    #my log "--r resolve_page '[my set object]' => $page_or_package"
    if {$page_or_package ne ""} {
      if {[$page_or_package istype ::xowiki::FormPage]
          && [$page_or_package is_link_page]} {
        # If the target is a symbolic link, we may want to call the
        # method on the target. The default behavior is defined in the
        # array delegate_link_to_target, but if can be overruled with
        # the boolean query parameter "deref".
        set deref [[self class] exists delegate_link_to_target($method)]
        if {[my exists_query_parameter deref]} {
          set deref [my query_parameter deref]
        }
        #my log "invoke on LINK <$method> default deref $deref"
        if {$deref} {
          set target [$page_or_package get_target_from_link_page]
          #my log "delegate $method from $page_or_package [$page_or_package name] to $target [$target name]"
          if {$target ne ""} {
            $target set __link_source $page_or_package
            set page_or_package $target
          }
        }
      }
      if {[$page_or_package procsearch www-$method] eq ""} {
        return [my error_msg "Method <b>'[ns_quotehtml $method]'</b> is not defined for this object"]
      } else {
        #my msg "--invoke [my set object] id=$page_or_package method=$method ([my id] batch_mode $batch_mode)"

        if {$batch_mode} {[my id] set __batch_mode 1}
        set err [catch { set r [my call $page_or_package $method ""]} errorMsg]
        if {$err} {set errorCode $::errorCode}
        if {$batch_mode} {[my id] unset -nocomplain __batch_mode}
        if {$err} {
          #
          # Check, if we were called from "ad_script_abort" (intentional abortion)
          #
          if {[ad_exception $errorCode] eq "ad_script_abort"} {
            #
            # Yes, this was an intentional abortion
            #
            return ""
          } elseif {[string match "*for parameter*" $errorMsg]} {
            #
            # The exception might have been due to invalid input parameters
            #
            ad_return_complaint 1 $errorMsg
            ad_script_abort
          } else {
            #
            # The exception was a real error
            #
            ad_log error "error during invocation of method $method errorMsg: $errorMsg, $::errorInfo"
            return [my error_msg -status_code 500 \
                        -template_file $error_template \
                        "error during [ns_quotehtml $method]: <pre>[ns_quotehtml $errorMsg]</pre>"]
          }
        }
        return $r
      }
    } else {
      # the requested page was not found, provide an error message and 
      # an optional link for creating the page
      set path [::xowiki::Includelet html_encode [my set object]]
      set edit_snippet [my create_new_snippet $path]
      return [my error_msg -status_code 404 -template_file $error_template \
                  "Page <b>'[ns_quotehtml $path]'</b> is not available. $edit_snippet"]
    }
  }

  Package instproc error_msg {{-template_file error-template} {-status_code 200} error_msg} {
    my instvar id
    if {![regexp {^[./]} $template_file]} {
      set template_file /packages/xowiki/www/$template_file
    }
    set context [list [$id instance_name]]
    set title Error
    set header_stuff [::xo::Page header_stuff]
    set index_link [my make_link -privilege public -link "" $id {} {}]
    set link [my query_parameter "return_url" ""]
    if {$link ne ""} {set back_link $link}
    set top_includelets ""; set content $error_msg; set folderhtml ""
    ::xo::cc set status_code $status_code
    $id return_page -adp $template_file -variables {
      context title index_link back_link header_stuff error_msg 
      top_includelets content folderhtml
    }
  }

  Package instproc get_page_from_item_or_revision_id {item_id} {
    set revision_id [my query_parameter revision_id 0]
    if {![string is integer -strict $revision_id]} {
      ad_return_complaint 1 "invalid revision_id"
      ad_script_abort
    }
    set [expr {$revision_id ? "item_id" : "revision_id"}] 0
    #my log "--instantiate item_id $item_id revision_id $revision_id"
    return [::xo::db::CrClass get_instance_from_db -item_id $item_id -revision_id $revision_id]
  }

  Package instproc resolve_page {
    {-use_package_path true}
    {-simple false}
    -lang 
    object
    method_var
  } {
    #
    # Try to resolve from object (path) and query parameter the called
    # object (might be a packge or page) and the method to be called.
    #
    # @return instantiated object (Page or Package) or empty
    #
    upvar $method_var method
    my instvar id

    # get the default language if not specified
    if {![info exists lang]} {
      set lang [my default_language]
    }
    #my log "resolve_page '$object', default-lang $lang"

    #
    # First, resolve package level methods, 
    # having the syntax PACKAGE_URL?METHOD&....
    #

    if {$object eq ""} {
      #
      # We allow only to call methods defined by the policy
      #
      set exported [[my set policy] defined_methods Package]
      foreach m $exported {
        #my log "--QP my exists_query_parameter $m = [my exists_query_parameter $m] || [my exists_form_parameter $m]"
        if {[my exists_query_parameter $m] || [my exists_form_parameter $m]} {
          set method $m  ;# determining the method, similar file extensions
          return [self]
        }
      }
    }

    if {[string match "//*" $object]} {
      # we have a reference to another instance, we cant resolve this from this package.
      # Report back not found
      return ""
    }

    #my log "--o object is '$object'"
    if {$object eq ""} {
      #
      # We have no object, but as well no method callable on the
      # package If the method is "view", allow it to be called on the
      # root folder object.
      set m [my query_parameter m]
      if {$m in {list show-object file-upload}} {
        my instvar folder_id
        array set "" [list \
                          name [$folder_id name] \
                          stripped_name [$folder_id name] \
                          parent_id [$folder_id parent_id] \
                          item_id $folder_id \
                          method [my query_parameter m]]
      } else {
        set object [$id get_parameter index_page "index"]
        #my log "--o object is now '$object'"
      }
    }

    #
    # second, resolve object level, unless we got a value already
    #
    if {![info exists (item_id)]} {
      array set "" [my item_info_from_url -with_package_prefix false -default_lang $lang $object]
      #my log "item_info_from_url returns [array get {}]"
    }

    if {$(item_id) ne 0} {
      if {$(method) ne ""} { set method $(method) }
      set page [my get_page_from_item_or_revision_id $(item_id)]

      if {[info exists (logical_package_id)] && [info exists (logical_parent_id)]} {
        #
        # If there was a logical_package_id provided from
        # item_info_from_url, we require that also a logical_parent_id
        # is required. In this case, change the context of the
        # resolved package to this page.
        #
        $page set_resolve_context -package_id $(logical_package_id) -parent_id $(logical_parent_id)
      }
      
      return $page
    }
    if {$simple} { return ""}
    #my log "NOT found object=$object"

    # try standard page
    set standard_page [$id get_parameter $(stripped_name)_page]
    if {$standard_page ne ""} {
      #
      # Allow for now mapped standard pages just on the toplevel
      #
      set page [my get_page_from_item_ref \
                    -allow_cross_package_item_refs false \
                    -use_package_path true \
                    -use_site_wide_pages true \
                    -use_prototype_pages true \
                    -default_lang $lang \
                    -parent_id [my folder_id] \
                    $standard_page]
      #my log "--o resolving standard_page '$standard_page' returns $page"
      if {$page ne ""} {
        return $page
      }
      # Maybe we are calling from a different language, but the
      # standard page with en: was already instantiated.
      #set standard_page "en:$stripped_object"
      #set page [my resolve_request -default_lang en -path $standard_page method]
      #my msg "resolve -default_lang en -path $standard_page returns --> $page"
      #if {$page ne ""} {
      #  return $page
      #}
    }

    # Maybe, a prototype page was imported with language en:, but the current language is different
    #if {$lang ne "en"} {
    #  set page [my resolve_request -default_lang en -path $stripped_object method]
    #  #my msg "resolve -default_lang en -path $stripped_object returns --> $page"
    #  if {$page ne ""} {
    #     return $page
    #  }
    #}

    if {$use_package_path} {
      # Check for this page along the package path
      #my msg "check along package path"
      foreach package [my package_path] {
        set page [$package resolve_page -simple true -lang $lang $object method]
        if {$page ne ""} {
          #my msg "set_resolve_context inherited -package_id [my id] -parent_id [my folder_id]"
          $page set_resolve_context -package_id [my id] -parent_id [my folder_id]
          return $page
        }
      }
      #my msg "package path done [array get {}]"
    }

    set page [::xowiki::Package get_site_wide_page -name en:$(stripped_name)]
    #my msg "get_site_wide_page for en:'$(stripped_name)' returned '$page' (stripped name)"
    if {$page ne ""} {
      #my msg "set_resolve_context site-wide -package_id [my id] -parent_id [my folder_id]"
      $page set_resolve_context -package_id [my id] -parent_id [my folder_id]
      return $page
    }

    #my log "try to import a prototype page for '$stripped_object'"
    set page [my www-import-prototype-page -lang $lang -add_revision false $(stripped_name)]
    if {$page eq ""} {
      my log "no prototype for '$object' found"
    }

    return $page
  }

  Package instproc package_path {} {
    # 
    # Compute a list fo package objects which should be used for
    # resolving ("inheritance of objects from other instances").
    #
    set packages [list]
    set package_url [string trimright [my package_url] /]
    set package_path [my get_parameter PackagePath]
    #
    # To avoid recursions, remove the current package from the list of
    # packages if was accidentally included. Get the package objects
    # from the remaining URLs.
    #
    foreach package_instance_url $package_path {
      #my msg "compare $package_instance_url eq $package_url"
      if {$package_instance_url eq $package_url} continue
      lappend packages ::[::xowiki::Package initialize \
                              -url $package_instance_url/[my set object] \
                              -keep_cc true -init_url false]
    }
    # final sanity check, in case package->initialize is broken
    set p [lsearch $packages ::[my id]]
    if {$p > -1} {set packages [lreplace $packages $p $p]}

    #my msg "[my id] packages=$packages, p=$p"
    return $packages
  }

  Package instproc prefixed_lookup {{-default_lang ""} -lang:required -stripped_name:required -parent_id:required} {
    # todo unify with package->lookup
    #
    # This method tries a direct lookup of stripped_name under
    # parent_id followed by a prefixed lookup.  The direct lookup is
    # only performed, when $default-lang == $lang. The prefixed lookup
    # might change lang in the result set.
    #
    # @return item-ref info
    #

    set item_id 0
    if {$lang eq $default_lang || [string match "*:*" $stripped_name]} {
      # try a direct lookup; ($lang eq "file" needed for links to files)
      set item_id [::xo::db::CrClass lookup -name $stripped_name -parent_id $parent_id]
      if {$item_id != 0} {
        set name $stripped_name
        regexp {^(..):(.+)$} $name _ lang stripped_name
        #my log "direct $stripped_name"
      }
    }

    if { $item_id == 0 } {
      set item_id [my get_page_from_super -folder_id $parent_id $stripped_name]
      if { $item_id == 0 } {
        set item_id [my get_page_from_super -folder_id $parent_id ${lang}:$stripped_name]
        if { $item_id == 0 } {
          set item_id [my get_page_from_super -folder_id $parent_id file:$stripped_name]
        }
      }
      
      if { $item_id != 0 } {
        set name $stripped_name
      }
    }

    if {$item_id == 0} {
      set name ${lang}:$stripped_name
      set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
      #my log "comp $name"
    }
    return [list item_id $item_id parent_id $parent_id \
                lang $lang stripped_name $stripped_name name $name ]
  }

  Package instproc lookup {
    {-use_package_path true} 
    {-use_site_wide_pages false} 
    {-default_lang ""} 
    -name:required 
    {-parent_id ""}
  } {
    # Lookup name (with maybe cross-package references) from a
    # given parent_id or from the list of configured instances
    # (obtained via package_path).
    #
    array set "" [my get_package_id_from_page_name -default_lang $default_lang $name]
    #my msg "result = [array get {}]"
    if {![info exists (package_id)]} {
      return 0
    }
    
    if {$parent_id eq ""} {set parent_id [$(package_id) folder_id]}
    set item_id [::xo::db::CrClass lookup -name $(page_name) -parent_id $parent_id]
    #my log "lookup $(page_name) $parent_id in package $(package_id) returns $item_id, parent_id $parent_id"

    # Test for "0" is only needed when we want to create the first root folder 
    if {$item_id == 0 && $parent_id ne "0"} {
      #
      # Page not found so far. Is the parent-page a regular page and a folder-link?
      # If so, de-reference the link.
      #
      set p [::xo::db::CrClass get_instance_from_db -item_id $parent_id]
      if {[$p istype ::xowiki::FormPage] && [$p is_link_page] && [$p is_folder_page]} {
        set target [$p get_target_from_link_page]
        set target_package_id [$target package_id]
        #my msg "SYMLINK LOOKUP from target-package $target_package_id source package $(package_id)"
        set target_item_id [$target_package_id lookup \
                                -use_package_path $use_package_path \
                                -use_site_wide_pages $use_site_wide_pages \
                                -default_lang $default_lang \
                                -name $name \
                                -parent_id [$target item_id]]
        if {$target_item_id != 0} {
          #my msg "SYMLINK FIX $target_item_id set_resolve_context -package_id [my id] -parent_id $parent_id"
          ::xo::db::CrClass get_instance_from_db -item_id $target_item_id
          $target_item_id set_resolve_context -package_id [my id] -parent_id $parent_id
        }
        return $target_item_id
      }
    }

    if {$item_id == 0 && $use_package_path} {
      #
      # Page not found so far. Is the page inherited along the package
      # path?
      #
      foreach package [my package_path] {
        set item_id [$package lookup -name $name]
        #my msg "lookup from package $package $name returns $item_id"
        if {$item_id != 0} break
      }
    }

    if {$item_id == 0 && $use_site_wide_pages} {
      #
      # Page not found so far. Is the page a site_wide page?
      #
      set item_id [::xowiki::Package lookup_side_wide_page -name $name]
    }

    return $item_id
  }

  #
  # Resolving item refs 
  # (symbolic references to content items and content folders)
  #

  Package ad_instproc item_ref {
    {-use_package_path false}
    {-use_site_wide_pages false}
    {-normalize_name true}
    -default_lang:required 
    -parent_id:required 
    link
  } {

    An item_ref refers to an item (existing or nonexisting) in the
    content repository relative to some parent_id. The item might be
    either a folder or some kind of "page" (e.g. a file). An item_ref
    might be complex, i.e. consist of a path of simple_item_refs,
    separated by "/".  An item_ref stops at the first unknown part in
    the path and returns item_id == 0 and the appropriate parent_id
    (and name etc.)  for insertion.

    @return item info containing link_type form prefix stripped_name item_id parent_id

  } {
    # A trailing slash says that the last element is a folder. We
    # substitute it to allow easy iteration over the slash separated
    # segments.
    if {[string match "*/" $link]} {
      set llink [string trimright $link /]\0
    } else {
      set llink $link
    }

    set elements [split $llink /]
    # Get start-page, if path is empty
    if {[llength $elements] == 0} {
      set link [my get_parameter index_page "index"]
      set elements [list $link]
    }

    # Iterate until the first unknown element appears in the path
    # (we can handle only one unknown at a time).
    set nr_elements [llength $elements]
    set n 0
    set ref_ids {}
    foreach element $elements {
      set (last_parent_id) $parent_id
      lappend ref_ids $parent_id
      array set "" [my simple_item_ref \
                        -normalize_name $normalize_name \
                        -use_package_path $use_package_path \
                        -use_site_wide_pages $use_site_wide_pages \
                        -default_lang $default_lang \
                        -parent_id $parent_id \
                        -assume_folder [expr {[incr n] < $nr_elements}] \
                        $element]
      #my msg "simple_item_ref $element => [array get {}]"
      if {$(item_id) == 0} {
        set parent_id $(parent_id)
        break
      } else {
        set parent_id $(item_id)
      }
    }

    return [list link $link link_type $(link_type) form $(form) \
                prefix $(prefix) stripped_name $(stripped_name) \
                item_id $(item_id) parent_id $(parent_id) ref_ids $ref_ids]
  }

  Package instproc simple_item_ref {
    -default_lang:required 
    -parent_id:required 
    {-use_package_path true}
    {-use_site_wide_pages false}
    {-normalize_name true}
    {-assume_folder:required false}
    element
  } {
    #my log el=[string map [list \0 MARKER] $element]-assume_folder=$assume_folder,parent_id=$parent_id
    set (form) ""
    set use_default_lang 0

    if {[regexp {^(file|image|js|css|swf):(.+)$} $element _ (link_type) (stripped_name)]} {
      # (typed) file links
      set (prefix) file
      set name file:$(stripped_name)
    } elseif {[regexp {^folder:(.+)$} $element _ (stripped_name)]} {
      # (typed) file links
      array set "" [list prefix "" link_type link form "en:folder.form"]
      set name $(stripped_name)
    } elseif {[regexp {^(..):([^:]{3,}?):(..):(.+)$} $element _ form_lang form (prefix) (stripped_name)]} {
      array set "" [list link_type "link" form "$form_lang:$form.form"]
      set name $(prefix):$(stripped_name)
      #my msg "FIRST case name=$name, form=$form_lang:$form"
    } elseif {[regexp {^(..):([^:]{3,}?):(.+)$} $element _ form_lang form (stripped_name)]} {
      array set "" [list link_type "link" form "$form_lang:$form.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
      #my msg "SECOND case name=$name, form=$form_lang:$form"
    } elseif {[regexp {^([^:]{3,}?):(..):(.+)$} $element _ form (prefix) (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:$form.form"]
      set name $(prefix):$(stripped_name)
      #my msg "THIRD case name=$name, form=$default_lang:$form"
    } elseif {[regexp {^([^:]{3,}?):(.+)$} $element _ form (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:$form.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
      #my msg "FOURTH case name=$name, form=$default_lang:$form"
    } elseif {[regexp {^(..):(.+)$} $element _ (prefix) (stripped_name)]} {
      array set "" [list link_type "link"]
      set name $(prefix):$(stripped_name)
    } elseif {[regexp {^(.+)\0$} $element _ (stripped_name)]} {
      array set "" [list link_type "link" form "en:folder.form" prefix ""]
      set name $(stripped_name)
    } elseif {$assume_folder} {
      array set "" [list link_type "link" form "en:folder.form" prefix "" stripped_name $element]
      set name $element
    } else {
      array set "" [list link_type "link" prefix $default_lang stripped_name $element]
      set name $default_lang:$element
      set use_default_lang 1
    }

    if {$use_default_lang && $default_lang eq ""} {
      my log "WARNING: Trying to use empty default lang on link '$element' => $name"
    }

    set name [string trimright $name \0]
    set (stripped_name) [string trimright $(stripped_name) \0]
    if {$normalize_name} {
      set (stripped_name) [my normalize_name $(stripped_name)]
    }

    if {$element eq "" || $element eq "\0"} {
      set folder_id [my folder_id]
      array set "" [my item_info_from_id $folder_id]
      set item_id $folder_id
      set parent_id $(parent_id)
      #my msg "SETTING item_id $item_id parent_id $parent_id // [array get {}]"
    } elseif {$element eq "." || $element eq ".\0"} {
      array set "" [my item_info_from_id $parent_id]
      set item_id $parent_id
      set parent_id $(parent_id)
    } elseif {$element eq ".." || $element eq "..\0"} {
      set id [::xo::db::CrClass get_parent_id -item_id $parent_id]
      if {$id > 0} {
        # refuse to traverse past root folder
        set parent_id $id
      }
      array set "" [my item_info_from_id $parent_id]
      set item_id $parent_id
      set parent_id $(parent_id)
    } else {
      # with the following construct we need in most cases just 1 lookup

      set item_id [my lookup \
                       -use_package_path $use_package_path \
                       -use_site_wide_pages $use_site_wide_pages \
                       -name $name -parent_id $parent_id]
      #my log "[my id] lookup -use_package_path $use_package_path -name $name -parent_id $parent_id => $item_id"

      if {$item_id == 0} {
        #
        # The first lookup was not successful, so we try again. 
        #
        if {$(link_type) eq "link" && $element eq $(stripped_name)} {
          #
          # try a direct lookup, in case it is a folder
          #
          set item_id [my lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name $(stripped_name) -parent_id $parent_id]
          #my msg "try again direct lookup, parent_id $parent_id $(stripped_name) => $item_id"
          if {$item_id > 0} {array set "" [list prefix ""]}
        }

        if {$item_id == 0 && $(link_type) eq "link" && $assume_folder && $(prefix) eq ""} {
          set item_id [my lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name $default_lang:$element -parent_id $parent_id]
          if {$item_id > 0} {array set "" [list link_type "link" prefix $default_lang stripped_name $element]
          }
        }

        if {$item_id == 0 && $(link_type) eq "link" && $use_default_lang && $(prefix) ne "en"} {
          #
          # If the name was not specified explicitely (we are using
          # $default_lang), try again with language "en" try again,
          # maybe element is folder in a different language
          #
          set item_id [my lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name en:$(stripped_name) -parent_id $parent_id]
          #my msg "try again in en en:$(stripped_name) => $item_id"
          if {$item_id > 0} {array set "" [list link_type "link" prefix en]}
        }

        # If the item is still unknown, try filename-based lookup,
        # when the entry looks like a filename with an extension.
        if {$item_id == 0 && [string match "*.*" $element] && ![regexp {[.](form|wf)$} $element]} {
          #
          # Get the mime type to distinguish between images, flash
          # files and ordinary files. 
          #
          set mime_type [::xowiki::guesstype $name]
          set (prefix) file
          switch -glob $mime_type {
            "image/*" {
              set name file:$(stripped_name)
              set (link_type) image
            }
            application/x-shockwave-flash -
            application/vnd.adobe.flash-movie {
              set name file:$(stripped_name)
              set (link_type) swf
            }
            default {
              set name file:$(stripped_name)
              if {![info exists (link_type)]} {set (link_type) file}
            }
          }
          set item_id [my lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name file:$(stripped_name) -parent_id $parent_id]
        }
      }
    }

    #my msg "return link_type $(link_type) prefix $(prefix) stripped_name $(stripped_name) form $(form) parent_id $parent_id item_id $item_id"
    return [list link_type $(link_type) prefix $(prefix) stripped_name $(stripped_name) \
                form $(form) parent_id $parent_id item_id $item_id ]
  }

  Package instproc item_info_from_id {
    item_id
  } {
    #
    # Obtain (partial) item info from id. It does not handle
    # e.g. special link_types as for e.g file|image|js|css|swf, etc.
    #
    ::xo::db::CrClass get_instance_from_db -item_id $item_id
    set name [$item_id name]
    set parent_id [$item_id parent_id]
    if {[$item_id is_folder_page]} {
      return [list link_type "folder" prefix "" stripped_name $name parent_id $parent_id]
    } 
    set stripped_name $name
    set prefix ""
    regexp {^(.+):(.+)$} $name _ prefix stripped_name
    return [list link_type "link" prefix $prefix stripped_name $stripped_name parent_id $parent_id]
  }
  
  Package instproc item_info_from_url {{-with_package_prefix true} {-default_lang ""} url} {
    #
    # Obtain item info (item_id parent_id lang stripped_name) from the
    # specified url. Search starts always at the root.
    #
    # @parm with_package_prefix flag, if provided url contains package-url
    # @return item ref data (parent_id lang stripped_name method)
    #
    if {$with_package_prefix && [string match "/*" $url]} {
      set url [string range $url [string length [my package_url]] end]
    }
    if {$default_lang eq ""} {set default_lang [my default_language]}
    my get_lang_and_name -default_lang $default_lang -path $url (lang) stripped_url
    set (parent_id) [my get_parent_and_name \
                         -lang $(lang) -path $stripped_url \
                         -parent_id [my folder_id] \
                         parent (stripped_name)]
    
    #my msg "get_parent_and_name '$stripped_url' returns [array get {}]"

    if {![regexp {^(download)/(.+)$} $(lang) _ (method) (lang)]} {
      set (method) ""
      # The lang value "tag" is used for allowing tag-urls without
      # parameters, since several tag harvester assume such a syntax
      # and don't process arguments. We rewrite in such cases simply
      # the url and query parameters and update the connection
      # context.
      if {$(lang) eq "tag"} {
        # todo: missing: tag links to subdirectories, also on url generation
        set tag $stripped_url
        set summary [::xo::cc query_parameter summary 0]
        set popular [::xo::cc query_parameter popular 0]
        if {$summary eq ""} {set summary 0}
        if {$popular eq ""} {set popular 0}
        if {![string is boolean -strict $summary]} {error "value of summary must be boolean"}
        if {![string is boolean -strict $popular]} {error "value of popular must be boolean"}
        set tag_kind [expr {$popular ? "ptag" :"tag"}]
        set weblog_page [my get_parameter weblog_page]
        my get_lang_and_name -default_lang $default_lang -name $weblog_page (lang) (stripped_name)
        #set name $(lang):$(stripped_name)
        my set object $weblog_page
        ::xo::cc set actual_query $tag_kind=$tag&summary=$summary
      }
    }
    array set "" [my prefixed_lookup -parent_id $(parent_id) \
                      -default_lang $default_lang -lang $(lang) -stripped_name $(stripped_name)]
    #my log "prefixed_lookup '$(stripped_name)' returns [array get {}]"

    if {$(item_id) == 0} {
      #
      # check symlink (todo: should this happen in package->lookup?)
      #
      ::xo::db::CrClass get_instance_from_db -item_id $(parent_id)
      if {[$(parent_id) is_link_page]} {
        #
        # We encompassed a link to a page or folder, treat both the same way.
        #
        set link_id $(parent_id)
        set target [$link_id get_target_from_link_page]

        $target set_resolve_context -package_id [my id] -parent_id $link_id
        array set "" [list logical_package_id [my id] logical_parent_id $link_id]
        
        #my log "SYMLINK PREFIXED $target ([$target name]) set_resolve_context -package_id [my id] -parent_id $link_id"

        array set "" [[$target package_id] prefixed_lookup -parent_id [$target item_id] \
                          -default_lang $default_lang -lang $(lang) -stripped_name $(stripped_name)]
        #
        # We can't reset the resolve context here, since it is also
        # required for rendering the target
        #
      }
    }

    return [array get ""]
  }
  


  Package instproc get_page_from_item_ref {
    {-allow_cross_package_item_refs true} 
    {-use_package_path false} 
    {-use_site_wide_pages true} 
    {-use_prototype_pages false} 
    {-default_lang ""}
    {-parent_id ""}
    link
  } {
    #
    # Get page from an item ref name (either with language prefix or
    # not).  First it try to resolve the item_ref from the actual
    # package. If not successful, it checks optionally along the
    # package_path and on the side-wide pages.
    #
    # @return page object or empty ("").
    #
    #my log "--get_page_from_item_ref [self args]"

    if {$allow_cross_package_item_refs && [string match "//*" $link]} {

      # todo check: get_package_id_from_page_name uses a different lookup based on site nodes 

      set referenced_package_id [my resolve_package_path $link rest_link]
      #my log "get_page_from_item_ref $link recursive rl?[info exists rest_link] in $referenced_package_id"
      if {$referenced_package_id != 0 && $referenced_package_id != [my id]} {
        # TODO: we have still to check, whether or not we want
        # site-wide-pages etc.  in cross package links, and if, under
        # which parent we would like to create newly importage pages.
        #
        # For now, we do not want to create pages this way, we pass
        # the root folder of the referenced package as start
        # parent_page for the search and turn off all page creation
        # facilities.
        
        #my log cross-package
        return [$referenced_package_id get_page_from_item_ref \
                    -allow_cross_package_item_refs false \
                    -use_package_path false \
                    -use_site_wide_pages false \
                    -use_prototype_pages false \
                    -default_lang $default_lang \
                    -parent_id [$referenced_package_id folder_id] \
                    $rest_link]
      } else {
        # it is a link to the same package, we start search for page at top.
        set link $rest_link
        set search_parent_id ""
      }
    } else {
      set search_parent_id $parent_id
    }

    #my log "my folder [my folder_id]"

    if {$search_parent_id eq ""} {
      set search_parent_id [my folder_id]
    }
    if {$parent_id eq ""} {
      set parent_id [my folder_id]
    }
    #my log call-item_ref-on:$link-parent_id=$parent_id,search_parent_id=$search_parent_id
    array set "" [my item_ref -normalize_name false \
                      -use_package_path $use_package_path \
                      -use_site_wide_pages $use_site_wide_pages \
                      -default_lang $default_lang \
                      -parent_id $search_parent_id \
                      $link]

    #my msg  "[my instance_name] (root [my folder_id]) item-ref for '$link' search parent $search_parent_id, parent $parent_id, returns\n[array get {}]"
    if {$(item_id)} {
      set page [::xo::db::CrClass get_instance_from_db -item_id $(item_id)]
      if {[$page package_id] ne [my id] || [$page parent_id] != $(parent_id)} {
        #my msg "set_resolve_context site_wide_pages [my id] and -parent_id $parent_id"
        $page set_resolve_context -package_id [my id] -parent_id $parent_id
      }
      return $page
    }

    if {!$(item_id) && $use_prototype_pages} {
      array set "" [my item_ref \
                        -normalize_name false \
                        -default_lang $default_lang \
                        -parent_id $parent_id \
                        $link]
      set page [::xowiki::Package import_prototype_page \
                    -package_key [my package_key] \
                    -name $(stripped_name) \
                    -parent_id $(parent_id) \
                    -package_id [my id] ]
      #my msg "import_prototype_page for '$(stripped_name)' => '$page'"
      if {$page ne ""} {
        # we want to be able to address the page via ::$item_id
        set page [::xo::db::CrClass get_instance_from_db -item_id [$page item_id]]
      }
      return $page
    }
    
    return ""
  }

  #
  # import for prototype pages
  # 

  Package instproc www-import-prototype-page {
    {-add_revision:boolean true}
    {-lang en}
    {prototype_name ""}
  } {
    set page ""
    if {$prototype_name eq ""} {
      set prototype_name [my query_parameter import-prototype-page ""]
      set via_url 1
    }
    if {$prototype_name eq ""} {
      error "No name for prototype given"
    }

    set page [::xowiki::Package import_prototype_page \
                  -package_key [my package_key] \
                  -name $prototype_name \
                  -lang $lang \
                  -parent_id [my folder_id] \
                  -package_id [my id] \
                  -add_revision $add_revision]

    if {[info exists via_url] && [my exists_query_parameter "return_url"]} {
      my returnredirect [my query_parameter "return_url" [my package_url]]
    }
    return $page
  }

  Package proc import_prototype_page { 
                                      -package_key:required 
                                      -name:required 
                                      -parent_id:required 
                                      -package_id:required
                                      {-lang en}
                                      {-add_revision:boolean true}
                                    } {
    set page ""
    set fn [get_server_root]/packages/$package_key/www/prototypes/$name.page
    #my log "--W check $fn"
    if {[file readable $fn]} {
      my instvar id
      # We have the file of the prototype page. We try to create
      # either a new item or a revision from definition in the file
      # system.
      if {[regexp {^(..):(.*)$} $name _ lang local_name]} {
        set fullName $name
      } else {
        set fullName en:$name
      }
      my log "--sourcing page definition $fn, using name '$fullName'"
      set page [source $fn]
      $page configure -name $fullName \
          -parent_id $parent_id -package_id $package_id
      # xowiki::File has a different interface for build-name to
      # derive the "name" from a file-name. This is not important for
      # prototype pages, so we skip it
      if {![$page istype ::xowiki::File]} {
        set nls_language [my get_nls_language_from_lang $lang]
        $page name [$page build_name -nls_language $nls_language]
        #my log "--altering name of page $page to '[$page name]'"
        set fullName [$page name]
      }
      if {![$page exists title]} {
        $page set title $object
      }
      $page destroy_on_cleanup
      $page set_content [string trim [$page text] " \n"]
      $page initialize_loaded_object

      set p [$package_id get_page_from_name -name $fullName -parent_id $parent_id]
      #my log "--get_page_from_name --> '$p'"
      if {$p eq ""} {
        # We have to create the page new. The page is completed with
        # missing vars on save_new.
        #my log "--save_new of $page class [$page info class]"
        $page save_new
      } else {
        #my log "--save revision $add_revision"
        if {$add_revision} {
          # An old page exists already, make a revision.  Update the
          # existing page with all scalar variables from the prototype
          # page (which is just partial)
          foreach v [$page info vars] {
            if {[$page array exists $v]} continue ;# don't copy arrays
            $p set $v [$page set $v]
          }
          #my log "--save of $p class [$p info class]"
          $p save
          set page $p
        }
      }
      if {$page ne ""} {
        # we want to be able to address the page via the canonical name ::$item_id
        set page [::xo::db::CrClass get_instance_from_db -item_id [$page item_id]]
      }
    }
    return $page
  }

  Package proc require_site_wide_pages {
                                        {-refetch:boolean false}
                                      } {
    set parent_id -100
    set package_id [::xowiki::Package first_instance]
    ::xowiki::Package require $package_id
    #::xowiki::Package initialize -package_id $package_id -init_url false -keep_cc true
    set package_key "xowiki"

    foreach n {folder.form link.form page.form import-archive.form photo.form} {
      set item_id [::xo::db::CrClass lookup -name en:$n -parent_id $parent_id]
      #my log "lookup en:$n => $item_id"
      if {!$item_id || $refetch} {
        set page [::xowiki::Package import_prototype_page \
                      -name $n \
                      -package_key $package_key \
                      -parent_id $parent_id \
                      -package_id $package_id ]
        my log "Page en:$n loaded as '$page'"
      }
    }
  }

  Package proc lookup_side_wide_page {-name:required} {
    return [::xo::db::CrClass lookup -name $name -parent_id -100]
  }

  Package proc get_site_wide_page {-name:required} {
    set item_id [my lookup_side_wide_page -name $name]
    #my ds "lookup from base objects $name => $item_id"
    if {$item_id} {
      set page [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      set package_id [$page package_id]
      if {$package_id ne ""} {
        #$form set_resolve_context -package_id $package_id -parent_id $parent_id
        ::xo::Package require [$package_id]
      }

      return $page
    }
    return ""
  }

  Package instproc call {object method options} {
    my instvar policy id
    set allowed [$policy enforce_permissions \
                     -package_id $id -user_id [::xo::cc user_id] \
                     $object $method]
    if {$allowed} {
      #my log "--p calling $object ([$object name] [$object info class]) '$method'"
      $object www-$method {*}$options
    } else {
      my log "not allowed to call $object $method"
    }
  }
  Package instforward check_permissions {%my set policy} %proc

  Package ad_instproc require_root_folder {
    {-parent_id -100} 
    {-content_types {}}
    -name:required
  } {
    Make sure, the root folder for the given package exists. If not, 
    create it and register all allowed content types.

    @return folder_id
  } {
    my instvar id
    
    set folder_id [ns_cache eval xotcl_object_type_cache root_folder-$id {
      
      set folder_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
      if {$folder_id == 0} {
        #
        # When the folder_id is 0, then something is wrong. Maybe an
        # earlier update script was not running correctly.
        #
        set old_folder_id [xo::dc get_value double_check_old_package {
          select item_id from cr_items where name = :name and parent_id = :parent_id
        }]
        if {$old_folder_id ne ""} {
          ns_log notice "-- try to transform old root folder $old_folder_id of package $id"
          ::xowiki::transform_root_folder $id
          set folder_id $old_folder_id
        } else {
          ::xowiki::Package require_site_wide_pages
          set form_id [::xowiki::Weblog instantiate_forms -forms en:folder.form -package_id $id]
          set f [FormPage new -destroy_on_cleanup \
                     -name $name \
                     -text "" \
                     -package_id $id \
                     -parent_id $parent_id \
                     -nls_language en_US \
                     -publish_status ready \
                     -instance_attributes {} \
                     -page_template $form_id]
          $f save_new
          set folder_id [$f item_id]

          ::xo::db::sql::acs_object set_attribute -object_id_in $folder_id \
              -attribute_name_in context_id -value_in $id

          my log "CREATED folder '$name' and parent $parent_id ==> $folder_id"
        }
      }

      # register all specified content types
      #::xo::db::CrFolder register_content_types \
          #    -folder_id $folder_id \
          #    -content_types $content_types
      #my log "returning from cache folder_id $folder_id"
      return $folder_id
    }]
    #my log "returning from require folder_id $folder_id"
    return $folder_id
  }

  Package instproc require_folder_object { } {
    set folder_id [my require_root_folder -name "xowiki: [my id]" \
                       -content_types ::xowiki::Page* ]
    ::xo::db::CrClass get_instance_from_db -item_id $folder_id
    my set folder_id $folder_id
  }


  ###############################################################
  #
  # user callable methods on package level
  #

  Package ad_instproc www-refresh-login {} {
    Force a refresh of a login and do a redict. Intended for use from ajax.
  } {
    set return_url [my query_parameter return_url]
    if {[::xo::cc user_id] == 0} {
      set url [subsite::get_url]register
      ad_returnredirect [export_vars -base $url return_url]
    } else {
      ad_returnredirect $return_url
    }
  }

  #
  # reindex (for site wide search)
  #

  Package ad_instproc www-reindex {} {
    reindex all items of this package
  } {
    my instvar folder_id id
    set pages [::xo::dc list get_pages {
      select page_id,package_id from xowiki_page, cr_revisions r, cr_items ci, acs_objects o 
      where page_id = r.revision_id and ci.item_id = r.item_id and ci.live_revision = page_id
      and publish_status = 'ready'
      and page_id = o.object_id and o.package_id = :id
    }]
    #my log "--reindex returns <$pages>"
    foreach page_id $pages {
      #search::queue -object_id $page_id -event DELETE
      search::queue -object_id $page_id -event INSERT
    }
    ad_returnredirect .
  }

  #
  # change-page-order (normally called via ajax POSTs)
  #
  Package ad_instproc www-change-page-order {} {
    
    Change Page Order for pages by renumbering and filling gaps. The
    parameter "clean" is just used for page inserts.
    
  } {

    set folder_id [string trim [my form_parameter folder_id [my set folder_id]]]

    ::xowiki::utility change_page_order \
        -from [string trim [my form_parameter from ""]] \
        -to [string trim [my form_parameter to ""]] \
        -clean [string trim [my form_parameter clean ""]] \
        -folder_id $folder_id \
        -package_id [my id] \
        -publish_status [string trim [my form_parameter publish_status "ready|live|expired"]]

    ns_return 200 text/plain ok
  }


  #
  # RSS 2.0 support
  #
  Package ad_instproc www-rss {
    -maxentries
    -name_filter
    -entries_of
    -title
    -days 
  } {
    Report content of xowiki folder in rss 2.0 format. The
    reporting order is descending by date. The title of the feed
    is taken from the title, the description
    is taken from the description field of the folder object.
    
    @param maxentries maximum number of entries retrieved
    @param days report entries changed in speficied last days
    
  } {
    set package_id [my id]
    set folder_id [$package_id folder_id]
    if {![info exists name_filter]} {
      set name_filter [my get_parameter -type word name_filter ""]
    }
    if {![info exists entries_of]} {
      set entries_of [my get_parameter entries_of ""]
    }
    if {![info exists title]} {
      set title [my get_parameter PackageTitle [my instance_name]]
    }
    set description [my get_parameter PackageDescription ""]

    if {![info exists days] && 
        [regexp {[^0-9]*([0-9]+)d} [my query_parameter rss] _ days]} {
      # setting the variable days
    } else {
      set days 10
    }
    
    set r [RSS new -destroy_on_cleanup \
               -package_id [my id] \
               -parent_ids [my query_parameter parent_ids ""] \
               -name_filter $name_filter \
               -entries_of $entries_of \
               -title $title \
               -description $description \
               -days $days]
    
    #set t text/plain
    set t text/xml
    ns_return 200 $t [$r render]
  }

  #
  # Google sitemap support
  #

  Package ad_instproc www-google-sitemap {
    {-max_entries ""}
    {-changefreq "daily"}
    {-priority "0.5"}
  } {
    Report content of xowiki folder in google site map format
    https://www.google.com/webmasters/sitemaps/docs/en/protocol.html
    
    @param maxentries maximum number of entries retrieved
    @param package_id to determine the xowiki instance
    @param changefreq changefreq as defined by google
    @param priority priority as defined by google
    
  } {
    set package_id [my id]
    set folder_id [::$package_id folder_id]
    
    set timerange_clause ""
    
    set content {<?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.google.com/schemas/sitemap/0.84"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.google.com/schemas/sitemap/0.84
    http://www.google.com/schemas/sitemap/0.84/sitemap.xsd">
    }

    set sql [::xo::dc select \
                 -vars "ci.parent_id, s.body, p.name, p.creator, p.title, p.page_id,\
                p.object_type as content_type, p.last_modified, p.description" \
                 -from "xowiki_pagex p, syndication s, cr_items ci" \
                 -where "ci.parent_id = :folder_id and ci.live_revision = s.object_id \
              and s.object_id = p.page_id $timerange_clause" \
                 -orderby "p.last_modified desc" \
                 -limit $max_entries]
    # my log $sql
    
    ::xo::dc foreach get_pages $sql {
      #my log "--found $name"
      if {[string match "::*" $name]} continue
      if {$content_type eq "::xowiki::PageTemplate::"} continue
      
      set time [::xo::db::tcl_date $last_modified tz]
      set time "[clock format [clock scan $time] -format {%Y-%m-%dT%T}]${tz}:00"

      append content <url> \n\
          <loc>[::$package_id pretty_link -absolute true -parent_id $parent_id $name]</loc> \n\
          <lastmod>$time</lastmod> \n\
          <changefreq>$changefreq</changefreq> \n\
          <priority>$priority</priority> \n\
          </url> \n
    }
    
    append content </urlset> \n

    #set t text/plain
    set t text/xml
    ns_return 200 $t $content
  }

  Package ad_proc www-google-sitemapindex {
    {-changefreq "daily"}
    {-priority "priority"}
  } {
    Provide a sitemap index of all xowiki instances in google site map format
    https://www.google.com/webmasters/sitemaps/docs/en/protocol.html
    
    @param maxentries maximum number of entries retrieved
    @param package_id to determine the xowiki instance
    @param changefreq changefreq as defined by google
    @param priority priority as defined by google
    
  } {
    
    set content {<?xml version="1.0" encoding="UTF-8"?>
      <sitemapindex xmlns="http://www.google.com/schemas/sitemap/0.84">
    }
    foreach package_id  [::xowiki::Package instances] {
      if {![::xo::parameter get -package_id $package_id \
                -parameter include_in_google_sitemap_index -default 1]} {
        continue
      } 
      set last_modified [::xo::dc get_value get_newest_modification_date \
                             {select last_modified from acs_objects 
                               where package_id = :package_id 
                               order by last_modified desc limit 1}]

      set time [::xo::db::tcl_date $last_modified tz]
      set time "[clock format [clock scan $time] -format {%Y-%m-%dT%T}]${tz}:00"

      #my log "--site_node::get_from_object_id -object_id $package_id"
      array set info [site_node::get_from_object_id -object_id $package_id]

      append content <sitemap> \n\
          <loc>[ad_url]$info(url)sitemap.xml</loc> \n\
          <lastmod>$time</lastmod> \n\
          </sitemap> 
    }
    append content </sitemapindex> \n
    #set t text/plain
    set t text/xml
    ns_return 200 $t $content
  }

  Package instproc www-google-sitemapindex {} {
    [self class] www-google-sitemapindex
  }

  Package instproc clipboard-copy {} {
    [my folder_id] clipboard-copy
  }
  
  #
  # Create new pages
  #

  Package instproc www-edit-new {} {
    my instvar folder_id id
    set object_type [my query_parameter object_type "::xowiki::Page"]
    set autoname [my get_parameter autoname 0]
    set parent_id [$id query_parameter parent_id ""]
    if {$parent_id eq ""} {set parent_id [$id form_parameter folder_id $folder_id]}
    if {![string is integer -strict $parent_id]} {
      ad_return_complaint 1 "invalid parent_id"
      ad_script_abort
    }
    set page [$object_type new -volatile -parent_id $parent_id -package_id $id]
    #my ds "parent_id of $page = [$page parent_id], cl=[$page info class] parent_id=$parent_id\n[$page serialize]"
    if {$object_type eq "::xowiki::PageInstance"} {
      #
      # If we create a PageInstance via the ad_form based
      # PageInstanceForm, we have to provide the page_template here to
      # be able to validate the name, where "build_name" needs
      # access to the ::xowiki::PageTemplate of the
      # ::xowiki::PageInstance.
      #
      $page set page_template [my form_parameter page_template]
    }

    set source_item_id [$id query_parameter source_item_id ""]
    if {$source_item_id ne ""} {
      if {![string is integer -strict $source_item_id]} {
        ad_return_complaint 1 "invalid source_item_id"
        ad_script_abort
      }
      set source [$object_type get_instance_from_db -item_id $source_item_id]
      $page copy_content_vars -from_object $source
      set name "[::xowiki::autoname new -parent_id $source_item_id -name [$source name]]"
      #my get_lang_and_name -name $name lang name
      $page set name $name
      #my msg nls=[$page nls_language],source-nls=[$source nls_language],page=$page,name=$name
    } else {
      $page set name ""
    }

    return [$page www-edit -new true -autoname $autoname]
  }

  #
  # manage categories
  #

  Package instproc www-manage-categories {} {
    set object_id [my query_parameter object_id]
    if {![string is integer -strict $object_id]} {
      ad_return_complaint 1 "invalid object_id"
      ad_script_abort
    }

    # flush could be made more precise in the future
    my flush_page_fragment_cache -scope agg

    set href [export_vars -base [site_node::get_package_url -package_key categories]cadmin/object-map {
      {ctx_id $object_id} {object_id}
    }]
    my returnredirect $href
  }

  #
  # edit a single category tree
  #

  Package instproc www-edit-category-tree {} {
    set object_id [my query_parameter object_id]
    if {![string is integer -strict $object_id]} {
      ad_return_complaint 1 "invalid object_id"
      ad_script_abort
    }
    set tree_id   [my query_parameter tree_id]
    if {![string is integer -strict $tree_id]}   {
      ad_return_complaint 1 "invalid tree_id"
      ad_script_abort
    }

    # flush could be made more precise in the future
    my flush_page_fragment_cache -scope agg
    my returnredirect [site_node::get_package_url -package_key categories]cadmin/tree-view?tree_id=$tree_id&ctx_id=$object_id&object_id=$object_id
  }


  #
  # Package import
  #

  Package ad_instproc import {-user_id {-parent_id 0} {-replace 0} -objects {-create_user_ids 0}} {
    import the specified pages into the xowiki instance
  } {
    if {$parent_id == 0} {set parent_id  [my folder_id]}
    if {![info exists user_id]} {set user_id [::xo::cc user_id]}
    if {![info exists objects]} {set objects [::xowiki::Page allinstances]}
    set msg "#xowiki.processing_objects#: $objects<p>"
    set importer [Importer new -package_id [my id] -parent_id $parent_id -user_id $user_id]
    $importer import_all -replace $replace -objects $objects -create_user_ids $create_user_ids
    append msg [$importer report]
  }

  Package instproc flush_references {-item_id:integer,required -name -parent_id} {
    my instvar id folder_id
    if {![info exists parent_id]} {
      set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
    }
    if {![info exists name]} {
      set name [::xo::db::CrClass get_name -item_id $item_id]
    }
    my flush_name_cache -name $name -parent_id $parent_id
  }

  Package instproc flush_name_cache {-name:required -parent_id:required} {
    # Different machines in the cluster might have different entries in their caches.
    # Since we use wild-cards to find these, it has to be done on every machine
    ::xo::clusterwide xo::cache_flush_all xowiki_cache link-*-$name-$parent_id
    ::xo::clusterwide ns_cache flush xotcl_object_type_cache $parent_id-$name
  }

  Package instproc delete_revision {-revision_id:required -item_id:required} {
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$revision_id
    ::xo::db::sql::content_revision del -revision_id $revision_id
  }

  Package instproc www-delete {-item_id -name -parent_id} {
    #
    # This delete method does not require an instantiated object,
    # while the class-specific delete methods in xowiki-procs need these.
    # If a (broken) object can't be instantiated, it cannot be deleted.
    # Therefore we need this package level delete method. 
    # While the class specific methods are used from the
    # application pages, the package_level method is used from the admin pages.
    #
    #my log "--D delete [self args]"
    #
    my instvar id
    #
    # if no item_id given, take it from the query parameter
    #
    if {![info exists item_id]} {
      set item_id [my query_parameter item_id]
      if {![string is integer $item_id]} {
        ad_return_complaint 1 "invalid item_id"
        ad_script_abort
      }
      #my log "--D item_id from query parameter $item_id"
    }
    #
    # if no name is given, take it from the query parameter
    #
    if {![info exists name]} {
      set name [my query_parameter name]
    }

    if {$item_id eq ""} {
      array set "" [my item_info_from_url -with_package_prefix false $name]
      if {$(item_id) == 0} {
        ns_log notice "url lookup of '$name' failed"
      } else {
        set parent_id $(parent_id)
        set item_id $(item_id)
        set name $(name)
      }
    } else {
      set name [::xo::db::CrClass get_name -item_id $item_id]
      if {![info exists parent_id]} {
        set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
      }
    }
    #my msg item_id=$item_id/name=$name

    if {$item_id ne ""} {
      my log "--D trying to delete $item_id $name"
      set object_type [::xo::db::CrClass get_object_type -item_id $item_id]
      # In case of PageTemplate and subtypes, we need to check
      # for pages using this template
      set classes [concat $object_type [$object_type info heritage]]
      if {"::xowiki::PageTemplate" in $classes} {
        set count [::xowiki::PageTemplate count_usages -item_id $item_id -publish_status all]
        if {$count > 0} {
          return [$id error_msg \
                      [_ xowiki.error-delete_entries_first [list count $count]]]
        }
      }
      if {[my get_parameter "with_general_comments" 0]} {
        #
        # We have general comments. In a first step, we have to delete
        # these, before we are able to delete the item.
        #
        set comment_ids [::xo::dc list get_comments {
          select comment_id from general_comments where object_id = :item_id
        }]
        foreach comment_id $comment_ids { 
          my log "-- deleting comment $comment_id"
          ::xo::db::sql::content_item del -item_id $comment_id 
        }
      }
      foreach child_item_id [::xo::db::CrClass get_child_item_ids -item_id $item_id] {
        my flush_references -item_id $child_item_id
      }
      $object_type delete -item_id $item_id
      my flush_references -item_id $item_id -name $name -parent_id $parent_id
      my flush_page_fragment_cache -scope agg
    } else {
      my log "--D nothing to delete!"
    }
    my returnredirect [my query_parameter "return_url" [$id package_url]]
  }

  #
  # Reparent a page
  #
  Package ad_instproc reparent {
    -item_id:integer,required 
    -new_parent_id:integer,required 
    {-allowed_parent_types {::xowiki::FormPage ::xowiki::Page}}
  } {

    Reparent a wiki page from one parent page to another one. The
    function changes the parent_id in cr_items, updates the
    cr-child-rels, and clears the caches. The function does not
    require the item to be instantiated. 

    Limitations: The method does not perform permission checks
    (whether the actual user has rights to move the page to another
    parent folder), which should be implemented by the calling
    methods. Currently, the method does not perform cycle checks.  It
    might be recommended to make sure the target parent is in
    the same package instance.

    @param item_id item_id of the item to be moved
    @param new_parent_id item_id of the target parent

  } {
    set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
    set name      [::xo::db::CrClass get_name      -item_id $item_id]
    if {$new_parent_id == $parent_id} {
      # nothing to do
      return
    }

    set object_type [::xo::db::CrClass get_object_type -item_id $item_id]
    set parent_object_type [::xo::db::CrClass get_object_type -item_id $new_parent_id]
    if {$parent_object_type ni $allowed_parent_types} {
      error "parent_object_type $parent_object_type not in allowed types"
    }
    set relation_tag $parent_object_type-$object_type
    ::xo::dc transaction {
      ::xo::dc dml update_cr_items {
        update cr_items set parent_id = :new_parent_id where item_id = :item_id
      }
      ::xowiki::update_item_index -item_id $item_id -parent_id $new_parent_id
      
      ::xo::dc dml update_cr_child_rels {
        update cr_child_rels set parent_id = :new_parent_id, relation_tag = :relation_tag 
        where child_id = :item_id
      }
      ::xo::dc dml update_rels_object {
        update acs_objects
        set context_id = :new_parent_id,
        title = :relation_tag || ': ' || :new_parent_id || ' - '  || :item_id
        where object_id = (select rel_id from cr_child_rels
                           where child_id = :item_id)
      }
    }
    #
    # clear caches
    #
    my flush_references -item_id $item_id -name $name -parent_id $parent_id
    my flush_page_fragment_cache -scope agg

    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id

    #
    # Clear potentially cached revisions. The function could be
    # optimized in the future by an index of the cached revision_ids
    # for an item_id
    #
    foreach revision_id [::xo::dc list get_revisions {
      select revision_id from cr_revisions where item_id = :item_id
    }] {
      ::xo::clusterwide ns_cache flush xotcl_object_cache ::$revision_id
    }
  }

  Package instproc flush_page_fragment_cache {{-scope agg}} {
    switch -- $scope {
      agg {set key PF-[my id]-agg-*}
      all {set key PF-[my id]-*}
      default {error "unknown scope for flushing page fragment cache"}
    }
    foreach entry [ns_cache names xowiki_cache $key] {
      ns_log notice "::xo::clusterwide ns_cache flush xowiki_cache $entry"
      ::xo::clusterwide ns_cache flush xowiki_cache $entry
    }
  }

  #
  # Perform per connection parameter caching.  Using the
  # per-connection cache speeds later lookups up by a factor of 15.
  # Repeated parameter lookups are quite likely
  #

  Class create ParameterCache
  ParameterCache instproc get_parameter {{-check_query_parameter true}  {-type ""} attribute {default ""}} {
    set key [list [my id] [self proc] $attribute]
    if {[info commands "::xo::cc"] ne ""} {
      if {[::xo::cc cache_exists $key]} {
        return [::xo::cc cache_get $key]
      }
      return [::xo::cc cache_set $key [next]]
    } else {
      # in case, we have no ::xo::cc (e.g. during bootstrap).
      ns_log notice "warning: no ::xo::cc available, returning default for parameter $attribute"
      return $default
    }
  }
  Package instmixin add ParameterCache


  #
  # policy management
  #

  Package instproc condition=has_class {query_context value} {
    return [expr {[$query_context query_parameter object_type ""] eq $value}]
  }
  Package instproc condition=has_name {query_context value} {
    return [regexp $value [$query_context query_parameter name ""]]
  }

  Class create Policy -superclass ::xo::Policy

  Policy policy1 -contains {
    
    Class create Package -array set require_permission {
      reindex             swa
      change-page-order   {{id admin}}
      import-prototype-page swa
      refresh-login       none
      rss                 none
      google-sitemap      none
      google-sitemapindex none
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              {{id admin}}
      edit-new            {
        {{has_class ::xowiki::Object} swa} 
        {{has_class ::xowiki::FormPage} nobody} 
        {{has_name {[.](js|css)$}} id admin}
        {id create}
      }
    }

    Class create Page -array set require_permission {
      view               none
      revisions          {{package_id write}}
      diff               {{package_id write}}
      edit               {
        {{regexp {name {(weblog|index)$}}} package_id admin} 
        {package_id write}
      }
      save-attributes    {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    {{package_id admin}}
      delete             {{package_id admin}}
      bulk-delete        {{package_id admin}}
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    } -set default_permission {{package_id write}}

    Class create Object -array set require_permission {
      edit               swa
    }
    Class create File -array set require_permission {
      download           none
    }
    Class create Form -array set require_permission {
      list              {{package_id read}}
      edit              admin
      view              admin
    }
    Class create CrFolder -array set require_permission {
      view           none
      delete         {{package_id admin}}
      edit-new       {{item_id write}}
    }
  }

  Policy policy2 -contains {
    #
    # we require side wide admin rights for deletions and code
    #

    Class create Package -array set require_permission {
      reindex             {{id admin}}
      rss                 none
      refresh-login       none
      google-sitemap      none
      google-sitemapindex none
      change-page-order   {{id admin}}
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              swa
      edit-new            {
        {{has_class ::xowiki::Object} swa} 
        {{has_class ::xowiki::FormPage} nobody} 
        {{has_name {[.](js|css)$}} swa}
        {id create}
      }
    }
    
    Class create Page -array set require_permission {
      view               {{package_id read}}
      revisions          {{package_id write}}
      diff               {{package_id write}}
      edit               {
        {{regexp {name {(weblog|index)$}}} package_id admin} 
        {package_id write}
      }
      save-attributes    {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    swa
      delete             swa
      bulk-delete        swa
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    }

    Class create Object -array set require_permission {
      edit               swa
    }
    Class create File -array set require_permission {
      download           {{package_id read}}
    }
    Class create Form -array set require_permission {
      view              admin
      edit              admin
      list              {{package_id read}}
    }
  }

  Policy policy3 -contains {
    #
    # we require side wide admin rights for deletions
    # we perform checking on item_ids for pages. 
    #

    Class create Package -array set require_permission {
      reindex             {{id admin}}
      rss                 none
      refresh-login       none
      google-sitemap      none
      google-sitemapindex none
      change-page-order   {{id admin}}
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              swa
      edit-new            {
        {{has_class ::xowiki::Object} swa} 
        {{has_class ::xowiki::FormPage} nobody} 
        {{has_name {[.](js|css)$}} swa}
        {id create}
      }
    }
    
    Class create Page -array set require_permission {
      view               {{item_id read}}
      revisions          {{item_id write}}
      diff               {{item_id write}}
      edit               {{item_id write}}
      make-live-revision {{item_id write}}
      save-attributes    {{package_id write}}
      delete-revision    swa
      delete             swa
      bulk-delete        swa      
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    }

    Class create Object -array set require_permission {
      edit               swa
    }
    Class create File -array set require_permission {
      download           {{package_id read}}
    }
    Class create Form -array set require_permission {
      view              admin
      edit              admin
      list              {{item_id read}}
    }
    #     Class create FormPage -array set require_permission {
    #       view              {
    #         {{is_true {_creation_user = @current_user@}} item_id read}
    #         swa
    #       }
    #     }
  }

  #Policy policy4 -contains {
  #  ::xotcl::Object function -array set require_permission {
  #    f none
  #  } -set default_permission login
  #}
  
  #my log "--set granted [policy4 check_permissions -user_id 0 -package_id 0 function f]"

  #
  # an example with in_state condition...
  #
  Policy policy5 -contains {

    Class create Package -array set require_permission {
      reindex             {{id admin}}
      rss                 none
      refresh-login       none
      google-sitemap      none
      google-sitemapindex none
      change-page-order   {{id admin}}
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              swa
      edit-new            {
        {{has_class ::xowiki::Object} swa}
        {{has_class ::xowiki::FormPage} nobody}
        {{has_name {[.](js|css)$}} swa}
        {id create}
      }
    }
    
    Class create Page -array set require_permission {
      view               {{item_id read}}
      revisions          {{item_id write}}
      diff               {{item_id write}}
      edit               {{item_id write}}
      save-attributes    {{item_id write}}
      make-live-revision {{item_id write}}
      delete-revision    swa
      delete             swa
      bulk-delete        swa
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
      show-object        swa
    }
    
    Class create Object -array set require_permission {
      edit               swa
    }
    Class create File -array set require_permission {
      download           {{package_id read}}
    }
    Class create FormPage -array set require_permission {
      view               creator 
      edit               {
        {{in_state initial|suspended|working} creator} admin
      }
      list               admin
    }
    Class create Form -array set require_permission {
      view              admin
      edit              admin
      list              admin
    }
  }

}

::xo::library source_dependent 

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

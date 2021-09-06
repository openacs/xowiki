::xo::library doc {
  XoWiki - package specific methods

  @creation-date 2006-10-10
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require -package xotcl-core 06-package-procs

namespace eval ::xowiki {
  nx::Object create ::xowiki::CSS {
    :public object method clear {} {
      #
      # Clear the cached toolkit name, such that it is reloads the
      # settings on the next initialize call.
      #
      unset -nocomplain :preferredCSSToolkit
    }
    :public object method toolkit {} {
      #
      # Return the preferred CSS toolkit
      #
      return ${:preferredCSSToolkit}
    }
    :public object method initialize {} {
      #
      # Initialize tailorization for CSS tooklits. The function reads
      # the global apm package parameter and sets/resets accordingly
      # (a) the default values (actially parameters) for the form
      # field and (b) defines the toolkit specific CSS class name
      # mapping.
      #
      #
      set paramValue [parameter::get_global_value -package_key xowiki \
                          -parameter PreferredCSSToolkit \
                          -default bootstrap]
      if {[info exists :preferredCSSToolkit]
          && ${:preferredCSSToolkit} eq $paramValue
        } {
        return
      }
      set :preferredCSSToolkit $paramValue

      if {${:preferredCSSToolkit} eq "bootstrap"} {
        ::xowiki::formfield::FormField parameter {
          {CSSclass form-control}
          {form_item_wrapper_CSSclass form-group}
          {form_widget_CSSclass ""}
          {form_button_CSSclass "btn btn-default"}
          {form_button_wrapper_CSSclass ""}
          {form_help_text_CSSclass help-block}
        }
        set :cssClasses {
          btn-default btn-default
          margin-form ""
        }
      } elseif {${:preferredCSSToolkit} eq "bootstrap5"} {
        ::xowiki::formfield::FormField parameter {
          {CSSclass form-control}
          {form_item_wrapper_CSSclass form-group}
          {form_widget_CSSclass ""}
          {form_button_CSSclass "btn btn-secondary"}
          {form_button_wrapper_CSSclass ""}
          {form_help_text_CSSclass help-block}
        }
        set :cssClasses {
          btn-default btn-secondary
          margin-form ""
        }
      } else {
        ::xowiki::formfield::FormField parameter {
          {CSSclass}
          {form_widget_CSSclass form-widget}
          {form_item_wrapper_CSSclass form-item-wrapper}
          {form_button_CSSclass ""}
          {form_button_wrapper_CSSclass form-button}
          {form_help_text_CSSclass form-help-text}
        }
        set :cssClasses {
          btn-default ""
          margin-form margin-form
        }
        ::xowiki::Form requireFormCSS
      }
    }

    :public object method class {name} {
      #
      # In case, a mapping for CSS classes is defined, return the
      # mapping for the provided class name. Otherwise return the
      # provided class name.
      #
      if {[dict exists ${:cssClasses} $name]} {
        return [dict get ${:cssClasses} $name]
      } else {
        return $name
      }
    }
  }
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

  Package site_wide_package_parameters {
    MenuBar 1
    index_page table-of-contents
    top_includelet ""
    with_general_comments 0
    with_notifications 0
    with_tags 0
    with_user_tracking 0
  }

  Package site_wide_pages {
    folder.form
    link.form
    page.form
    form.form
    import-archive.form
    photo.form
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
    set package_id [:get_package_id_from_page_id \
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

  Package ad_instproc get_ids_for_bulk_actions {-parent_id page_references} {

    The page_reference is either an item_id, a fully qualified URL
    path or the name exactly as stored in the content repository
    ("name" attribute in the database, requires parent_id to be
    provided as well)

    @param parent_id optional, only needed in lagacy cases,
           when page_reference is provided as page name
    @param page_references item_ids, paths or names to be resolved as item_ids
    @return list of valid item_ids

  } {
    set item_ids {}
    foreach page_ref $page_references {
      #
      # First check whether we got a valid item_id, then check for a
      # URL path. If both are failing, resort to the legacy methods
      # (which will be dropped eventually).
      #
      if {[string is integer -strict $page_ref]} {
        if {[content::item::get -item_id $page_ref]} {
          set item_id $page_ref
        }
      } elseif {[string index $page_ref 0] eq "/"} {
        #
        # $page_ref looks like a URL path
        #
        set ref [:item_info_from_url $page_ref]
        set item_id [dict get $ref item_id]
        ns_log notice "get_ids_for_bulk_actions: URL '$page_ref' item_ref <$ref> -> $item_id"
      } else {
        #
        # Try $page_ref as item_ref
        #
        set parent_id_arg [expr {[info exists parent_id] ? [list -parent_id $parent_id] : {}}]
        set p [:get_page_from_item_ref {*}$parent_id_arg $page_ref]
        if {$p ne ""} {
          set item_id [$p item_id]
        }
        ns_log notice "get_ids_for_bulk_actions: tried to resolve item_ref <$page_ref> -> $item_id"
      }

      if {![info exists item_id] || $item_id == 0} {
        #
        # Try to resolve either via a passed in parent_id or via root folder
        #
        set parent_ids [expr {[info exists parent_id] ? $parent_id : ${:folder_id}}]
        foreach parent_id $parent_ids {
          set item_id [::xo::db::CrClass lookup -name $page_ref -parent_id $parent_id]
          if {$item_id != 0} {
            break
          }
        }
      }

      if {$item_id != 0} {
        #:log "clipboard-add adds $page_ref // $item_id"
        lappend item_ids $item_id
      } else {
        ns_log warning "get_ids_for_bulk_actions: clipboard entry <$page_ref> could not be resolved"
      }
    }
    return $item_ids
  }


  Package instproc normalize_name {{-with_prefix:boolean false} string} {
    #
    # Normalize the name (in a narrow sense) which refers to a
    # page. This name is not necessarily the content of the "name"
    # field of the content repository, but the name without prefix
    # (sometimes called stripped_name).
    #
    if {$with_prefix} {
      set name_info [:split_name $string]
      set prefix [dict get $name_info prefix]
      set suffix [dict get $name_info suffix]
    } else {
      set prefix ""
      set suffix $string
    }
    set suffix [string trim $suffix]
    # temporary measure; TODO: remove the following if-clause
    if {[string match "*:*" $suffix]} {
      ad_log warning "normalize_name receives name '$suffix' containing a colon. A missing -with_prefix?"
      xo::show_stack
    }
    regsub -all -- {[\#/\\:]} $suffix _ suffix
    # if subst_blank_in_name is turned on, turn spaces into _
    if {[:get_parameter subst_blank_in_name 1]} {
      regsub -all -- { +} $suffix "_" suffix
    }
    return [:join_name -prefix $prefix -name $suffix]
  }

  Package instproc default_locale {} {
    if {[:get_parameter use_connection_locale 0]} {
      # we return the connection locale (if not connected the system locale)
      set locale [::xo::cc locale]
    } else {
      if {[info exists :__default_locale]} {
        return ${:__default_locale}
      }
      # return either the package locale or the site-wide locale
      set locale [lang::system::locale -package_id ${:id}]
      set :__default_locale $locale
    }
    return $locale
  }

  Package instproc default_language {} {
    #:log "Package ${:instance_name} has default_locale [:default_locale]"
    return [string range [:default_locale] 0 1]
  }

  Package instproc validate_tag {tag} {
    if {![regexp {^[\w.-]+$} $tag]} {
      ad_return_complaint 1 "invalid tag"
      ad_script_abort
    }
  }

  Package array set www-file {
    admin 1
    diff 1
    doc 1
    edit 1
    error-template 1
    portlet 1     portlet-ajax 1  portlets 1
    prototypes 1
    resources 1
    revisions 1
    view-default 1 view-links 1 view-plain 1 oacs-view 1 oacs-view2 1 oacs-view3 1
    view-book 1 view-book-no-ajax 1 view-oacs-docs 1
    download 1
  }

  Package instproc get_lang_and_name {-path -name {-default_lang ""} vlang vlocal_name} {
    :upvar $vlang lang $vlocal_name local_name
    if {[info exists path]} {
      #
      # Determine lang and name from a path with slashes
      #
      if {[regexp {^pages/(..)/(.*)$} $path _ lang local_name]} {
      } elseif {[regexp {^([a-z][a-z])/(.*)$} $path _ lang local_name]} {

        # TODO we should be able to get rid of this by using a canonical /folder/ in
        # case of potential conflicts, like for file....

        # check if we have a LANG - FOLDER "conflict"
        set item_id [::xo::db::CrClass lookup -name $lang -parent_id ${:folder_id}]
        if {$item_id} {
          :msg "We have a lang-folder 'conflict' (or a two-char folder) with folder: $lang"
          set local_name $path
          if {$default_lang eq ""} {set default_lang [:default_language]}
          set lang $default_lang
        }

      } elseif {[regexp {^(file|image|swf|download/file|download/..|tag)/(.*)$} $path _ lang local_name]} {
        #
        # special "lang" contents
        #
      } else {
        set local_name $path
        if {$default_lang eq ""} {set default_lang [:default_language]}
        set lang $default_lang
      }
    } elseif {[info exists name]} {
      #
      # Determine lang and name from a name as it stored in the database.
      #
      if {![regexp {^(..):(.*)$} $name _ lang local_name]} {
        if {![regexp {^(file|image|swf):(.*)$} $name _ lang local_name]} {
          set local_name $name
          if {$default_lang eq ""} {set default_lang [:default_language]}
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


  Package instproc get_parent_and_name {
    -path:required
    -lang:required
    -parent_id:required
    vparent
    vlocal_name
  } {
    :upvar $vparent parent $vlocal_name local_name
    if {[regexp {^([^/]+)/(.+)$} $path _ parent local_name]} {

      # try without a prefix
      set p [:lookup -name $parent -parent_id $parent_id]
      if {$p == 0} {
        # check if page is inherited
        set p2 [:get_page_from_super -folder_id $parent_id $parent]
        if { $p2 != 0 } {
          set p $p2
        }
      }

      if {$p == 0} {
        # content pages are stored with a lang prefix
        set p [:lookup -name ${lang}:$parent -parent_id $parent_id]
        #:log "check with prefix '${lang}:$parent' returned $p"

        if {$p == 0 && $lang ne "en"} {
          # try again with prefix "en"
          set p [:lookup -name en:$parent -parent_id $parent_id]
          #:log "check with en 'en:$parent' returned $p"
        }
      }

      if {$p != 0} {
        if {[regexp {^([^/]+)/(.+)$} $local_name _ parent2 local_name2]} {
          set p2 [:get_parent_and_name -path $local_name -lang $lang -parent_id $p parent local_name]
          #:log "recursive call for '$local_name' parent_id=$p returned $p2"
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
      :get_lang_and_name -name $name lang stripped_name
      set lookup_name $lang:$stripped_name
    }
    set item_id [:lookup -parent_id $parent_id -name $lookup_name]
    if {$item_id != 0} {
      return [::xo::db::CrClass get_instance_from_db -item_id $item_id]
    }
    return ""
  }

  Package ad_instproc folder_path {
    {-parent_id ""}
    {-context_url ""}
    {-folder_ids ""}
    {-path_encode:boolean true}
  } {

    Construct a folder path from a hierarchy of xowiki objects. It is
    designed to work with linked objects, respecting logical and
    physical parent IDs. The result is URL encoded, unless path_encode
    is set to false.

  } {
    #
    # Handle different parent_ids
    #
    if {$parent_id eq "" || $parent_id == ${:folder_id}} {
      return ""
    }
    #
    # The item might be in a folder along the folder path.  So it
    # will be found by the object resolver. For the time being, we
    # do nothing more about this.
    #
    #
    if { $context_url ne {} } {
      set parts [split $context_url /]
      set index [expr {[llength $parts]-1}]
    }

    if { $context_url ne {} } {
      set context_id [:get_parent_and_name -path $context_url -lang "" -parent_id $parent_id parent local_name]
      #:msg "context_url $context_url folder_ids $folder_ids context_id $context_id"
    }

    set path ""
    set ids {}
    while {1} {
      lappend ids $parent_id
      set fo [::xo::db::CrClass get_instance_from_db -item_id $parent_id]
      if { $context_url ne {} } {
        set context_name [lindex $parts $index]
        if {1 && $parent_id in $folder_ids} {
          #:msg "---- parent $parent_id in $folder_ids"
          set context_id [::$context_id item_id]
          set fo [::xo::db::CrClass get_instance_from_db -item_id $context_id]
        } else {
          #:msg "context_url $context_url, parts $parts, context_name $context_name // parts $parts // index $index / folder $fo"

          if { [$fo name] ne $context_name } {
            set context_folder [:get_page_from_name -parent_id $parent_id -assume_folder true -name $context_name]
            if {$context_folder eq ""} {
              :msg "my get_page_from_name -parent_id $parent_id -assume_folder true -name $context_name ==> EMPTY"
              :msg "Cannot lookup '$context_name' in package folder $parent_id [::$parent_id name]"

              set new_path [join [lrange $parts 0 $index] /]
              set p2 [:get_parent_and_name -path [join [lrange $parts 0 $index] /] -lang "" -parent_id $parent_id parent local_name]
              :msg "p2=$p2 new_path=$new_path '$local_name' ex=[nsf::object::exists $p2] [$p2 name]"

            }
            :msg "context_name [$context_folder serialize]"
            set context_id [$context_folder item_id]
            set fo [::xo::db::CrClass get_instance_from_db -item_id $context_id]
          }
          incr index -1
        }
      }

      #:get_lang_and_name -name [$fo name] lang stripped_name
      #set path $stripped_name/$path

      if {[$fo parent_id] < 0} break

      if {[$fo is_link_page]} {
        set pid [$fo package_id]
        foreach id $ids {
          if {[::$id package_id] ne $pid} {
            #:msg "SYMLINK ++++ have to fix package_id of $id from [::$id package_id] to $pid"
            $id set_resolve_context -package_id $pid -parent_id [::$id parent_id]
          }
        }
        if {0} {
          #
          # In some older versions, this code was necessary. Keep it
          # here as a reference, in case not all relevant cases were
          # covered by the tests
          #
          set target [$fo get_target_from_link_page]
          set target_name [$target name]
          #:msg "----- $path //  target $target [$target name] package_id [$target package_id] path '$path'"
          set orig_path $path
          regsub "^$target_name/" $path "" path
          if {$orig_path ne $path} {
            :msg "----> orig <$orig_path> new <$path> => full [$fo name]/$path"
          }
        }
      }

      set name [$fo name]
      if {$path_encode} {
        set name [ad_urlencode_path $name]
      }
      # prepend always the actual folder name
      set path $name/$path

      if {${:folder_id} == [$fo parent_id]} {
        #:msg ".... :folder_id ${:folder_id} == $fo parentid"
        break
      }

      set parent_id [$fo parent_id]
    }

    #:msg ====$path
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
    set folder [:folder_path -parent_id $parent_id]
    if {$folder ne ""} {
      # Return the stripped name for sub-items, the parent has already
      # the language prefix
      # :get_lang_and_name -name $name lang stripped_name
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
    {-path_encode:boolean true}
    {-page ""}
    name
  } {

    Generate a (minimal) link to a wiki page with the specified name.
    Practically all links in the xowiki systems are generated through
    this method. The method returns the URL path urlencoded,
    unless "-path_encode" is set to false.

    @param anchor anchor to be added to the link
    @param query query parameters to be added literally to the resulting URL
    @param absolute make an absolute link (including protocol and host)
    @param lang use the specified 2 character language code (rather than computing the value)
    @param download create download link (without m=download)
    @param parent_id parent_id
    @param name name of the wiki page
    @param path_encode control URL encoding of the path segmemts
  } {
    #:msg "input name=$name, lang=$lang parent_id=$parent_id"

    set host [expr {$absolute ? ($siteurl ne "" ? $siteurl : [ad_url]) : ""}]
    if {$anchor ne ""} {set anchor \#$anchor}
    if {$query ne ""} {set query ?$query}

    :get_lang_and_name -default_lang $lang -name $name lang name

    set package_prefix [:get_parameter package_prefix ${:package_url}]
    if {$package_prefix eq "/" && [string length $lang]>2} {
      #
      # Don't compact the path for images etc. to avoid conflicts
      # with e.g. //../image/*
      #
      set package_prefix ${:package_url}
    }
    #:msg "name=$name, parent_id=$parent_id, package_prefix=$package_prefix"
    if {$path_encode} {
      set encoded_name [ad_urlencode_path $name]
    } else {
      set encoded_name $name
    }

    if {$parent_id eq -100} {
      # In case, we have a CR top-level entry, we assume, we can
      # resolve it at least against the root folder of the current
      # package.
      set folder_path ""
      set encoded_name ""
      set default_lang [:default_language]
    } else {
      if {$parent_id eq ""} {
        ns_log warning "pretty_link of $name: you should consider to pass a parent_id to support folders"
        set parent_id ${:folder_id}
      }
      set folder_path [:folder_path -parent_id $parent_id -folder_ids $folder_ids -path_encode $path_encode]
      set pkg [::$parent_id package_id]
      if {![nsf::is object ::$pkg]} {
        ::xowiki::Package initialize -package_id $pkg -init_url false -keep_cc true
      }
      set package_prefix [$pkg get_parameter package_prefix [$pkg package_url]]
      set default_lang [$pkg default_language]
    }
    #:msg "folder_path = $folder_path, -parent_id $parent_id -folder_ids $folder_ids // default_lang [:default_language]"

    #:log "h=${host}, prefix=${package_prefix}, folder=$folder_path, name=$encoded_name anchor=$anchor download=$download"

    #
    # Lookup plain page name. If we succeed, there is a danger of a
    # name clash between a folder and a language prefixed page. In
    # case, the lookup succeeds, add a language prefix to the page,
    # although it could be omitted otherwise. This way, we can
    # disambiguate between a folder named "foo" and a page named
    # "en:foo" in the same folder.
    #
    # Note: such a naming disambiguation is probably needed in the
    # general case as well on path segments, when arbitrary objects
    # can have children and same-named folders exist.
    #
    set found_id [:lookup -parent_id $parent_id -name $name]
    #:log "-pretty_link: lookup [list :lookup -parent_id $parent_id -name $name] -> $found_id"

    #
    # In case, we did not receive a "page" but we could look up the
    # entry, instantiate the target page to be able to distinguish
    # between folder and page in ambiguous cases.
    #
    if {$found_id != 0 && $page eq ""} {
      #ad_log warning "have to fetch target page. You should provide '-page' to pretty_link"
      set page [::xo::db::CrClass get_instance_from_db -item_id $found_id]
    }

    if {$found_id != 0 && $page ne ""} {
      #
      # Do never add a language prefix for certain pages
      #
      if {[$page is_unprefixed]} {
        #:log "... $page is unprefixed"
        set found_id 0
      }
    }

    #:log "-pretty_link: found_id=$found_id name=$name,folder_path=$folder_path,lang=$lang,default_lang=$default_lang"
    #:log "-pretty_link: host <${host}> package_prefix <${package_prefix}>"
    if {$download} {
      #
      # Use the special download (file) syntax.
      #
      set url ${host}${package_prefix}download/file/$folder_path$encoded_name$query$anchor
    } elseif {$lang ne $default_lang || [[self class] exists www-file($name)]} {
      #
      # If files are physical files in the www directory, add the
      # language prefix
      #
      set url ${host}${package_prefix}${lang}/$folder_path$encoded_name$query$anchor
    } elseif {$found_id != 0} {
      set url ${host}${package_prefix}$folder_path${lang}:$encoded_name$query$anchor
    } else {
      #
      # Use the short notation without language prefix.
      #
      set url ${host}${package_prefix}$folder_path$encoded_name$query$anchor
    }
    #:msg "final url=$url"
    return $url
  }

  Package instproc init {} {
    #:log "--R creating + folder_object"
    next
    :require_folder_object
    set :policy [:get_parameter -check_query_parameter false security_policy ::xowiki::policy1]
    ::xowiki::CSS initialize
    # :proc destroy {} {:log "--P "; next}
  }

  #
  # We could refine here the caching behavior in xowiki
  #
  #Package instproc handle_http_caching {} {
  #  next
  #}

  Package ad_instproc get_parameter {
    {-check_query_parameter true}
    {-nocache:switch}
    {-type ""}
    attribute
    {default ""}
  } {
    resolves configurable parameters according to the following precedence:
    (1) values specifically set per page {{set-parameter ...}}
    (2) query parameter
    (3) form fields from the parameter_page FormPage
    (4) standard OpenACS package parameter
  } {
    if {$nocache} {
      set value ""
    } else {
      set value [::xo::cc get_parameter $attribute]
    }
    if {$check_query_parameter && $value eq ""} {
      set value [string trim [:query_parameter $attribute]]
    }
    if {$value eq "" && $attribute ne "parameter_page"} {
      #
      # Try to get the parameter from the parameter_page.  We have to
      # be very cautious here to avoid recursive calls (e.g. when
      # resolve_page_name needs as well parameters such as
      # use_connection_locale or subst_blank_in_name, etc.).
      #
      set pp [:get_parameter parameter_page ""]
      if {$pp ne ""} {
        if {![regexp {/?..:} $pp]} {
          ad_log error "Name of parameter page '$pp' of package ${:id} must contain a language prefix"
        } else {
          set page [::xo::cc cache [list [self] get_page_from_item_ref $pp]]
          if {$page eq ""} {
            ad_log error "Could not resolve parameter page '$pp' of package ${:id}."
          }
          #:msg pp=$pp,page=$page-att=$attribute

          if {$page ne "" && [$page exists instance_attributes]} {
            set __ia [$page set instance_attributes]
            if {[dict exists $__ia $attribute]} {
              set value [dict get $__ia $attribute]
            }
          }
        }
      }
    }
    #if {$value eq ""} {set value [::${:folder_id} get_payload $attribute]}
    if {$value eq ""} {set value [next $attribute $default]}
    if {$type ne ""} {
      # to be extended and generalized
      switch -- $type {
        word {if {[regexp {\W} $value]} {error "value '$value' contains invalid character"}}
        default {error "requested type unknown: $type"}
      }
    }
    #:log "           $attribute returns '$value'"
    return $value
  }

  Package ad_proc is_xowiki_p {package_id} {
    A small stunt to detect if a package is a descendant of xowiki.

    @return boolean
  } {
    set xowiki_p false
    set package_key [apm_package_key_from_id $package_id]
    set package_class [::xo::PackageMgr get_package_class_from_package_key $package_key]
    if {$package_class ne ""} {
      # we found an xo::Package, but is it an xowiki package?
      set classes [list $package_class {*}[$package_class info heritage]]
      if {"::xowiki::Package" in $classes} {
        set xowiki_p true
      }
    }
    return $xowiki_p
  }

  Package instproc resolve_package_path {path name_var} {
    #
    # In case, we can resolve the path against an xowiki instance,
    # require the package, set the provided name of the object and
    # return the package_id. If we cannot resolve the name, turn 0.
    #
    :upvar $name_var name

    # Set output variable always to some value
    set name $path

    if {[regexp {^/(/.*)$} $path _ path]} {
      set siten_node_info [site_node::get_from_url -url $path]
      set package_key [dict get $siten_node_info package_key]

      if {$package_key eq "acs-subsite"} {
        # the main site
        return 0
      }
      set package_id [dict get $siten_node_info package_id]
      if {[::xowiki::Package is_xowiki_p $package_id]} {
        # yes, it is an xowiki::package, compute the name and return the package_id
        ::xowiki::Package require $package_id
        set name [string range $path [string length [dict get $siten_node_info url]] end]
        return $package_id
      }
    } elseif {!([string match "http*://*" $path] || [string match "ftp://*" $path])} {
      return ${:id}
    }

    return 0
  }

  Package instproc get_package_id_from_page_name {{-default_lang ""} page_name} {
    #
    # Return package id + remaining page name
    #
    set package_id ${:id}
    if {[regexp {^/(/.*)$} $page_name _ fullurl]} {
      #
      # When we have an absolute url, we are working on a different
      # package.
      #
      set siten_node_info [site_node::get_from_url -url $fullurl]

      if {[dict get $siten_node_info package_id] eq ""} {
        return ""
      }
      if {[dict get $siten_node_info name] ne ""} {
        set package_id [dict get $siten_node_info package_id]
      }
      #
      # Use site-node url as package_url and get the full path within
      # under the xo* sitenode (provided path)
      #
      set url [dict get $siten_node_info url]
      set provided_name [string range $fullurl [string length $url] end]
      ::xowiki::Package require $package_id
      :get_lang_and_name -default_lang $default_lang -path $page_name lang stripped_name
      set page_name $lang:$stripped_name
      set search 0
    } else {
      set url [:url]/
      set provided_name $page_name
      set search 1
    }
    #:msg [self args]->[list package_id $package_id page_name $page_name url $url provided_name $provided_name search $search]
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
    return [:get_page_from_item_ref \
                -allow_cross_package_item_refs true \
                -default_lang $default_lang \
                $page_name]
    #array set "" [:get_package_id_from_page_name $page_name]
  }

  Package instproc resolve_page_name_and_init_context {{-lang} page_name} {
    # todo: currently only used from
    # Page->resolve_included_page_name. Maybe, it could be replaced by
    # get_page_from_name or get_page_from_item_ref
    set page ""
    #
    # take a local copy of the package_id, since it is possible
    # that the variable package_id might changed to another instance.
    #
    set package_id ${:id}
    array set "" [:get_package_id_from_page_name $page_name]
    if {$(package_id) != $package_id} {
      #
      # Handle cross package resolve requests
      #
      # Note that package::initialize might change the package id.
      # Preserving the package-url is just necessary, if for some
      # reason the same package is initialized here with a different
      # url. This could be done probably with a flag to initialize,
      # but we get below the object name from the package_id...
      #
      #:log "cross package request $page_name"
      #
      set last_package_id $package_id
      set last_url [:url]
      #
      # TODO: We assume here that the package is an xowiki package.
      #       The package might be as well a subclass of xowiki...
      #       For now, we fixed the problem to perform reclassing in
      #       ::xo::Package init and calling a per-package instance
      #       method "initialize"
      #
      ::xowiki::Package initialize -parameter {{-m:token view}} -url $(url)$(provided_name) \
          -actual_query ""
      #:log "url=$url=>[::$package_id serialize]"

      if {$package_id != 0} {
        #
        # For the resolver, we create a fresh context to avoid recursive loops, when
        # e.g. revision_id is set through a query parameter...
        #
        set package ::$package_id
        set last_context [expr {[$package exists context] ? [$package context] : "::xo::cc"}]
        $package context [::xo::Context new -volatile]
        set object_name [$package set object]
        #:log "cross package request got object=$object_name"
        #
        # A user might force the language by preceding the
        # name with a language prefix.
        #
        #:log "check '$object_name' for lang prefix"
        if {![regexp {^..:} $object_name]} {
          if {![info exists lang]} {
            set lang [:default_language]
          }
          set object_name ${lang}:$object_name
        }
        set page [$package resolve_page -simple true $object_name __m]
        $package context $last_context
      }
      ::$last_package_id set_url -url $last_url

    } else {
      #
      # It is not a cross package request
      #
      set package ::$package_id
      set last_context [expr {[$package exists context] ? [$package context] : "::xo::cc"}]
      $package context [::xo::Context new -volatile]
      set page [$package resolve_page -use_package_path $(search) $(page_name) __m]
      $package context $last_context
    }
    #:log "returning $page"
    return $page
  }


  Package instproc show_page_order {} {
    return [:get_parameter display_page_order 1]
  }

  #
  # conditional links
  #
  Package ad_instproc make_link {
    {-with_entities 0}
    -privilege
    -link
    object
    {method ""}
    args
  } {
    Creates conditionally a link for use in xowiki. When the generated link
    will be activated, the specified method of the object will be invoked.
    make_link checks in advance, whether the actual user has enough
    rights to invoke the method. If not, this method returns empty.

    @param privilege
        When this parameter is not specified, the policy is used to determine
        the rights to be checked.
        When provided, can be "public" (do not check rights) or a privilege to be
        checked on the package_id and the current user.

    @param link
        When this parameter is specified, is used used as base link for export_vars
        when applied on pages (or for packages as next segment under the package url).
        When not specified, the base url for pages is the current url, and for packages
        it is the package url.

    @param object The object to which the link refers to. If it is a package_id it will base \
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

    set computed_link ""

    if {[$object istype ::xowiki::Package]} {
      set base ${:package_url}
      if {$method ne ""} {
        #
        # Convention for calling methods on the package.
        #
        lappend args [list $method 1]
      }
      if {[info exists link]} {
        set computed_link [uplevel export_vars -base [list $base$link] [list $args]]
      } else {
        set computed_link [uplevel export_vars -base [list $base] [list $args]]
      }
    } elseif {[$object istype ::xowiki::Page]} {
      if {[info exists link]} {
        set base $link
      } else {
        #
        # Use the provided object for computing the base URL.
        #
        set base [$object pretty_link]
        #
        # Before, we had
        #
        #    set base ${:url}
        #
        # which depends on the invocation context.
        #
      }
      if {$method ne ""} {
        #
        # Convention for calling methods on an xowiki::Page
        #
        lappend args [list m $method]
      }
      #set computed_link [uplevel export_vars -base [list $base] -no_base_encode [list $args]]
      set computed_link [uplevel [list export_vars -base $base -no_base_encode $args]]
      #:msg "computed_link = '$computed_link'"
    }
    if {$with_entities} {
      regsub -all & $computed_link "&amp;" computed_link
    }

    # provide links based in untrusted_user_id
    set party_id [::xo::cc set untrusted_user_id]
    if {[info exists privilege]} {
      #:log "-- checking priv $privilege for [self args] from id ${:id}"
      set granted [expr {$privilege eq "public" ? 1 :
                         [::xo::cc permission -object_id ${:id} -privilege $privilege -party_id $party_id] }]
    } else {
      # determine privilege from policy
      #:msg "-- check permissions from ${:id} of object $object $method"
      ad_try {
        set granted [:check_permissions \
                         -user_id $party_id \
                         -package_id ${:id} \
                         -link $computed_link $object $method]
      } on error {errorMsg} {
        ns_log error "error in check_permissions: $errorMsg"
        set granted 0
      }
      #:msg "--p ${:id} check_permissions $object $method ==> $granted"
    }
    #:log "granted=$granted $computed_link"
    if {$granted} {
      return $computed_link
    }
    return ""
  }

  Package instproc make_form_link {-form {-parent_id ""} {-query ""} -title -name -nls_language -return_url} {
    # use the same instantiate_forms as everywhere; TODO: will go to a different namespace
    set form_id [lindex [::${:id} instantiate_forms \
                             -parent_id $parent_id \
                             -forms $form] 0]
    #:log "instantiate_forms -parent_id $parent_id -forms $form => $form_id "
    if {$form_id ne ""} {
      if {$parent_id eq ""} {unset parent_id}
      set form_link [::$form_id pretty_link -query $query]
      #:msg "$form -> $form_id -> $form_link -> [:make_link -link $form_link $form_id \
          #            create-new return_url title parent_id name nls_language]"
      return [:make_link -link $form_link $form_id \
                  create-new return_url title parent_id name nls_language]
    }
  }

  Package instproc create_new_snippet {
    {-object_type ::xowiki::Page}
    provided_name
  } {
    :get_lang_and_name -path $provided_name lang local_name
    set name ${lang}:$local_name
    set new_link [:make_link ${:id} edit-new object_type return_url name]
    if {$new_link ne ""} {
      return "<p>Do you want to create page <a href='[ns_quotehtml $new_link]'>$name</a> new?"
    } else {
      return ""
    }
  }

  Package array set delegate_link_to_target {
    csv-dump 1 download 1 list 1
  }

  Package instproc invoke {
    -method:token
    {-error_template error-template}
    {-batch_mode:boolean 0}
  } {
    #
    # Do we have a valid method?
    #
    if {![regexp {^[.a-zA-Z0-9_-]+$} $method]} {
      return [:error_msg "No valid method provided!"]
    }

    #
    # Call the method on the resolved page. This call might trigger an
    # ad_script_abort, so use ad_try to catch these properly.
    #
    ad_try {
      set page_or_package [:resolve_page -lang [:default_language] ${:object} method]
    } on error {errorMsg} {
      #
      # Report true errors in the error log and return the template.
      #
      ad_log error $errorMsg
      return [:error_msg -template_file $error_template $errorMsg]
    }

    #
    # Set the invoke object, such it might be used later
    #
    ::xo::cc invoke_object $page_or_package

    #:log "--r resolve_page '${:object}' => $page_or_package"
    if {$page_or_package ne ""} {

      # TODO: remove me when settled
      if {[$page_or_package istype ::xowiki::FormPage] && [$page_or_package info vars storage_type] eq ""} {ad_log notice "$page_or_package has no storage_type"}

      #
      # Check, of the target is a symbolic link
      #
      if {[$page_or_package istype ::xowiki::FormPage]
          && [$page_or_package is_link_page]
        } {
        #
        # If the target is a symbolic link, we may want to call the
        # method on the target. The default behavior is defined in the
        # array delegate_link_to_target, but if can be overruled with
        # the boolean query parameter "deref".
        #
        set deref [[self class] exists delegate_link_to_target($method)]
        if {[:exists_query_parameter deref]} {
          set deref [:query_parameter deref:boolean]
        }

        #:log "invoke on LINK <$method> default deref $deref"
        if {$deref} {
          set target [$page_or_package get_target_from_link_page]
          #:log "delegate $method from $page_or_package [$page_or_package name] to $target [$target name]"
          if {$target ne ""} {
            $target set __link_source $page_or_package
            set page_or_package $target
          }
        }
      }

      #:log "call procsearch www-$method on: [$page_or_package info precedence]"
      if {[$page_or_package procsearch www-$method] eq ""} {
        return [:error_msg "Method <b>'[ns_quotehtml $method]'</b> is not defined for this object"]
      } else {

        #:log "--invoke ${:object} id=$page_or_package method=$method (${:id} batch_mode $batch_mode)"

        if {$batch_mode} {
          ${:id} set __batch_mode 1
        }

        ad_try {
          set r [:call $page_or_package $method ""]
        } on error {errorMsg} {
          if {[string match "*for parameter*" $errorMsg]} {
            #
            # The exception might have been due to invalid input parameters
            #
            ad_return_complaint 1 [ns_quotehtml $errorMsg]
            ad_script_abort
          } else {
            #
            # The exception was a real error
            #
            ad_log error "error during invocation of method $method errorMsg: $errorMsg, $::errorInfo"
            return [:error_msg -status_code 500 \
                        -template_file $error_template \
                        "error during [ns_quotehtml $method]: <pre>[ns_quotehtml $errorMsg]</pre>"]
          }

        } finally {
          if {$batch_mode} {
            ${:id} unset -nocomplain __batch_mode
          }
        }

        return $r
      }
    } else {
      # the requested page was not found, provide an error message and
      # an optional link for creating the page
      set path [::xowiki::Includelet html_encode ${:object}]
      set edit_snippet [:create_new_snippet $path]
      return [:error_msg -status_code 404 -template_file $error_template \
                  "Page <b>'[ns_quotehtml $path]'</b> is not available. $edit_snippet"]
    }
  }

  Package instproc error_msg {{-template_file error-template} {-status_code 200} error_msg} {
    if {![regexp {^[./]} $template_file]} {
      set template_file [:get_adp_template $template_file]
    }
    set context [list [${:id} instance_name]]
    set title Error
    set header_stuff [::xo::Page header_stuff]
    set index_link [:make_link -privilege public -link "" ${:id} {} {}]
    set link [:query_parameter "return_url:localurl" ""]
    if {$link ne ""} {set back_link $link}
    if {[util::external_url_p $link]} {
      ns_log warning "return_url is apparently an external URL: $link"
      set link ""
      unset back_link
    }
    set top_includelets ""; set content $error_msg; set folderhtml ""
    ::xo::cc set status_code $status_code
    ::xo::Page requireCSS urn:ad:css:xowiki-[::xowiki::CSS toolkit]
    ${:id} return_page -adp $template_file -variables {
      context title index_link back_link header_stuff error_msg
      top_includelets content folderhtml
    }
  }

  Package instproc get_page_from_item_or_revision_id {item_id} {
    set revision_id [:query_parameter revision_id:int32 0]
    if {![string is integer -strict $revision_id]} {
      ad_return_complaint 1 "invalid revision_id"
      ad_script_abort
    }
    set [expr {$revision_id ? "item_id" : "revision_id"}] 0
    #:log "--instantiate item_id $item_id revision_id $revision_id"
    return [::xo::db::CrClass get_instance_from_db \
                -item_id $item_id \
                -revision_id $revision_id]
  }

  Package ad_instproc resolve_page {
    {-use_package_path true}
    {-simple false}
    -lang
    object
    method_var
  } {

    Try to resolve from object (path) and query parameter the called
    object (might be a package or page) and the method to be called.

    @param use_package_path
    @param simple when set, do not try to resolve using item refs, prototype pages or package_path
    @param lang language used for resolving
    @param object element to be resolved
    @param method_var output variable for method to be called on the object
    @return instantiated object (Page or Package) or empty

  } {
    upvar $method_var method

    # get the default language if not specified
    if {![info exists lang]} {
      set lang [:default_language]
      :log "no lang specified for '$object', use default_language <$lang>"
    }
    #:log "--o resolve_page '$object', default-lang $lang"

    #
    # First, resolve package level methods,
    # having the syntax PACKAGE_URL?METHOD&....
    #

    if {$object eq ""} {
      #
      # We allow only to call methods defined by the policy
      #
      set exported [${:policy} defined_methods Package]
      foreach m $exported {
        #:log "--QP :exists_query_parameter $m = [:exists_query_parameter $m] || [:exists_form_parameter $m]"
        if {[:exists_query_parameter $m] || [:exists_form_parameter $m]} {
          set method $m  ;# determining the method, similar file extensions
          return [self]
        }
      }
    }

    if {[string match "//*" $object]} {
      #
      # We have a reference to another instance, we can't resolve this
      # from this package.  Report back not found by empty result.
      #
      #ns_log notice "reference to onother instance: <$object>"
      return ""
    }

    #:log "--o object is '$object'"
    if {$object eq ""} {
      #
      # We have no object, but as well no method callable on the
      # package If the method is "view", allow it to be called on the
      # root folder object.
      set m [:query_parameter m]
      if {$m in {list show-object file-upload}} {
        array set "" [list \
                          name [::${:folder_id} name] \
                          stripped_name [::${:folder_id} name] \
                          parent_id [::${:folder_id} parent_id] \
                          item_id ${:folder_id} \
                          method [:query_parameter m]]
      } else {
        set object [${:id} get_parameter index_page "index"]
        #:log "--o object after getting index_page is '$object'"
      }
    }

    #
    # Second, resolve on object level, unless we have already an
    # item_id from above.
    #
    if {![info exists (item_id)]} {
      array set "" [:item_info_from_url -with_package_prefix false -default_lang $lang $object]
      #:log "item_info_from_url returns [array get {}]"
    }

    #:log "object <$object>"
    if {$(item_id) == 0 && [:get_parameter fallback_languages ""] ne ""} {
      foreach fallback_lang [:get_parameter fallback_languages ""] {
        if {$fallback_lang ne $lang} {
          array set "" [:item_info_from_url -with_package_prefix false -default_lang $fallback_lang $object]
          if { $(item_id) != 0 } {
            :log "item_info_from_url based on fallback_lang <$fallback_lang> returns [array get {}]"
            break
          }
        }
      }
    }

    if {$(item_id) ne 0} {
      if {$(method) ne ""} { set method $(method) }
      set page [:get_page_from_item_or_revision_id $(item_id)]

      # TODO: remove me when settled
      if {[$page info vars storage_type] eq ""} {ad_log notice "$page has no storage_type"}

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

    if {$simple} {
      return ""
    }
    #:log "NOT found object=$object"

    # try standard page
    set standard_page [${:id} get_parameter $(stripped_name)_page]
    if {$standard_page ne ""} {
      #
      # Allow for now mapped standard pages just on the top-level
      #
      set page [:get_page_from_item_ref \
                    -allow_cross_package_item_refs false \
                    -use_package_path true \
                    -use_site_wide_pages true \
                    -use_prototype_pages true \
                    -default_lang $lang \
                    -parent_id ${:folder_id} \
                    $standard_page]
      #:log "--o resolving standard_page '$standard_page' returns $page"
      if {$page ne ""} {
        return $page
      }
      # Maybe we are calling from a different language, but the
      # standard page with en: was already instantiated.
      #set standard_page "en:$stripped_object"
      #set page [:resolve_request -default_lang en -path $standard_page method]
      #:msg "resolve -default_lang en -path $standard_page returns --> $page"
      #if {$page ne ""} {
      #  return $page
      #}
    }

    # Maybe, a prototype page was imported with language en:, but the current language is different
    #if {$lang ne "en"} {
    #  set page [:resolve_request -default_lang en -path $stripped_object method]
    #  #:msg "resolve -default_lang en -path $stripped_object returns --> $page"
    #  if {$page ne ""} {
    #     return $page
    #  }
    #}

    if {$use_package_path} {
      # Check for this page along the package path
      #:msg "check along package path"
      foreach package [:package_path] {
        set page [$package resolve_page -simple true -lang $lang $object method]
        if {$page ne ""} {
          #:msg "set_resolve_context inherited -package_id ${:id} -parent_id ${:folder_id}"
          $page set_resolve_context -package_id ${:id} -parent_id ${:folder_id}
          return $page
        }
      }
      #:msg "package path done [array get {}]"
    }

    #
    # The call ":lookup -use_site_wide_pages true" works for looking
    # up the site-wide-pages all kind of packages, not only ::xowiki::Package
    #
    set (item_id) [:lookup -use_site_wide_pages true -name en:$(stripped_name)]
    set page [expr {$(item_id) != 0 ? [:get_page_from_item_or_revision_id $(item_id)] : ""}]
    #:msg "get_site_wide_page for en:'$(stripped_name)' returned '$page' (stripped name)"
    if {$page ne ""} {
      #:msg "set_resolve_context site-wide -package_id ${:id} -parent_id ${:folder_id}"
      $page set_resolve_context -package_id ${:id} -parent_id ${:folder_id}
      return $page
    }

    :log "try to import a prototype page for '$(stripped_name)' [array get {}]"
    if {$(stripped_name) ne ""} {
      #
      # Allow import of prototype pages into the actual folder.
      #
      if {[info exists (logical_parent_id)]} {
        set parent_id $(logical_parent_id)
      } elseif {[info exists (parent_id)]} {
        set parent_id $(parent_id)
      } else {
        set parent_id ${:folder_id}
      }
      set page [:www-import-prototype-page \
                    -lang $lang \
                    -parent_id $parent_id \
                    -add_revision false \
                    $(stripped_name)]
    }
    if {$page eq ""} {
      :log "no prototype for '$object' found"
    }

    return $page
  }

  Package instproc package_path {} {
    #
    # Compute a list fo package objects which should be used for
    # resolving ("inheritance of objects from other instances").
    #
    set packages [list]
    set package_url [string trimright [:package_url] /]
    set package_path [:get_parameter PackagePath]
    #
    # To avoid recursions, remove the current package from the list of
    # packages if was accidentally included. Get the package objects
    # from the remaining URLs.
    #
    foreach package_instance_url $package_path {
      #:msg "compare $package_instance_url eq $package_url"
      if {$package_instance_url eq $package_url} continue
      lappend packages ::[::xowiki::Package initialize \
                              -url $package_instance_url/${:object} \
                              -keep_cc true -init_url false]
    }
    # final sanity check, in case package->initialize is broken
    set p [lsearch $packages ::${:id}]
    if {$p > -1} {set packages [lreplace $packages $p $p]}

    #:msg "${:id} packages=$packages, p=$p"
    return $packages
  }

  Package instproc normalize_path {name} {
    #
    # Don't allow any addressing outside of the jail.
    #
    # ns_normalizepath always adds a leading "/", so remove this.
    #
    set nn [ns_normalizepath $name]
    return [string range $nn 1 end]
  }

  #view-default/../../../etc/hosts

  Package instproc get_adp_template {name} {
    #
    # Obtain the template from a name. In earlier versions, the
    # templates that xowiki used were in the www directory. This had
    # the disadvantage, that for e.g. the template "edit.adp" a call
    # of "/xowiki/edit" returned an error, since the index.vuh file
    # was bypassed and xowiki/www/edit.adp was called. Therefore, the
    # recommended place was changed to xowiki/resources/templates/.
    #
    # However, this method hides the location change and maintains
    # backward compatibility. The www location is deprecated but still
    # "working".
    #
    set name [:normalize_path $name]

    #
    # Try to locate the file first in the actual package, and - if not
    # found - as well in "xowiki".
    #
    set package_keys ${:package_key}
    if {${:package_key} ne "xowiki"} {
      lappend package_keys xowiki
    }

    set paths {}
    foreach package_key $package_keys {
      #
      # Backward compatibility check for old style definitions.
      # Notify user about such deprecated usages.
      #
      foreach location {resources/templates www} {

        set tmpl /packages/$package_key/$location/$name
        set fn [acs_root_dir]/$tmpl
        lappend paths $fn
        #ns_log notice "=== check get_adp_template $fn"

        if {[ad_file readable $fn.adp]} {
          set result [::template::themed_template $tmpl]
          #ns_log notice "template is <$result>"
          if {$result ne ""} {
            if {$location eq "www"} {
              ns_log warning "deprecated location: you should move template" \
                  "'$tmpl' to /packages/$package_key/resources/templates/"
            }
            return $result
          }
        }
      }
    }
    ns_log warning "get_adp_template: could not locate template '$name'" \
        "on the following paths:\n[join $paths \n]"
    return ""
  }


  Package instproc prefixed_lookup {
    {-default_lang ""}
    -lang:required
    -stripped_name:required
    -parent_id:required
  } {
    # todo unify with package->lookup
    #
    # This method tries a direct lookup of stripped_name under
    # parent_id followed by a prefixed lookup.  The direct lookup is
    # only performed, when $default-lang == $lang. The prefixed lookup
    # might change lang in the result set.
    #
    # Note that the "stripped_name" should be called "local_name" (or
    # path segment), since it might contain language prefixes as well.
    #
    # @return item-ref info
    #
    #:log "incoming stripped name <$stripped_name>"

    set item_id 0
    if {$lang eq $default_lang || [string match "*:*" $stripped_name]} {
      # try a direct lookup; ($lang eq "file" needed for links to files)
      set item_id [::xo::db::CrClass lookup -name $stripped_name -parent_id $parent_id]
      #:log "direct lookup of <$stripped_name> -> $item_id"
      if {$item_id != 0} {
        set name $stripped_name
        regexp {^(..):(.+)$} $name _ lang stripped_name
        #:log "direct $stripped_name"
      }
    }

    if { $item_id == 0 } {
      set item_id [:get_page_from_super -folder_id $parent_id $stripped_name]
      if { $item_id == 0 } {
        set item_id [:get_page_from_super -folder_id $parent_id ${lang}:$stripped_name]
        if { $item_id == 0 } {
          set item_id [:get_page_from_super -folder_id $parent_id file:$stripped_name]
        }
      }

      if { $item_id != 0 } {
        set name $stripped_name
      }
    }

    if {$item_id == 0} {
      #:log "last chance stripped name <$stripped_name>"
      :get_lang_and_name -default_lang $lang -name $stripped_name lang stripped_name
      set name ${lang}:$stripped_name
      set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
      #:log "comp $name"
    }
    return [list item_id $item_id parent_id $parent_id \
                lang $lang stripped_name $stripped_name name $name ]
  }

  Package ad_instproc lookup {
    {-use_package_path true}
    {-use_site_wide_pages false}
    {-default_lang ""}
    -name:required
    {-parent_id ""}
  } -returns integer {

    Lookup name (with maybe cross-package references) from a
    given parent_id or from the list of configured instances
    (obtained via package_path).

  } {
    #:log "LOOKUP of <$name> on-package: ${:id} parent_id '$parent_id'"
    set pkg_info [:get_package_id_from_page_name -default_lang $default_lang $name]

    if {[dict exists $pkg_info package_id]} {
      set package_id [dict get $pkg_info package_id]
    } else {
      return 0
    }

    if {$parent_id eq ""} {
      set parent_id [::$package_id folder_id]
    }
    set item_id [::xo::db::CrClass lookup \
                     -name [dict get $pkg_info page_name] \
                     -parent_id $parent_id]
    #:log "lookup [dict get $pkg_info page_name] $parent_id in package $package_id returns $item_id, parent_id $parent_id"

    #
    # Test for "0" is only needed when we want to create the first
    # root folder.
    #
    if {$item_id == 0 && $parent_id != 0} {
      #
      # Page not found so far, get the parent page.
      #
      set p [::xo::db::CrClass get_instance_from_db -item_id $parent_id]
      #
      # Is the parent-page a regular page and a folder-link?
      # If so, de-reference the link.
      #
      if {[$p istype ::xowiki::FormPage] && [$p is_link_page] && [$p is_folder_page]} {
        set target [$p get_target_from_link_page]
        set target_package_id [$target package_id]
        set target_item_id    [$target item_id]
        #:log "SYMLINK LOOKUP from target-package $target_package_id source package $package_id name $name"
        #
        # Avoid potential recursive loop
        #
        if {${:id} != $target_package_id || $parent_id != $target_item_id} {
          set target_item_id [::$target_package_id lookup \
                                  -use_package_path $use_package_path \
                                  -use_site_wide_pages $use_site_wide_pages \
                                  -default_lang $default_lang \
                                  -name $name \
                                  -parent_id $target_item_id]
        } else {
          :log "SYMLINK LOOKUP avoid recursive loop name $name package_id ${:id} parent_id [$target item_id]"
          set target_item_id 0
        }
        if {$target_item_id != 0} {
          #:msg "SYMLINK FIX $target_item_id set_resolve_context -package_id ${:id} -parent_id $parent_id"
          ::xo::db::CrClass get_instance_from_db -item_id $target_item_id
          ::$target_item_id set_resolve_context -package_id ${:id} -parent_id $parent_id
        }
        return $target_item_id
      }
    }

    if {$item_id == 0 && $use_package_path} {
      #
      # Page not found so far. Is the page inherited along the package
      # path?
      #
      foreach package [:package_path] {
        set item_id [$package lookup -name $name]
        #:msg "lookup from package $package $name returns $item_id"
        if {$item_id != 0} break
      }
    }

    if {$item_id == 0 && $use_site_wide_pages} {
      #
      # Page not found so far. Is the page a site_wide page?
      #
      foreach pkgClass [${:id} info precedence] {
        if {[$pkgClass istype ::xo::PackageMgr] && [$pkgClass package_key] ne "apm_package"} {
          set item_id [$pkgClass lookup_side_wide_page -name $name]
          #ns_log notice "SITE_WIDE: [list $pkgClass lookup_side_wide_page -name $name] -> $item_id"
          if {$item_id ne 0} {
            break
          }
        }
      }
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

    An item_ref refers to an item (existing or non-existing) in the
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
      set link [:get_parameter index_page "index"]
      set elements [list $link]
    }

    #
    # Iterate bottom-up until the first unknown element appears in the
    # path (we can handle only one unknown at a time).
    #
    set nr_elements [llength $elements]
    set n 0
    set ref_ids {}
    foreach element $elements {
      set (last_parent_id) $parent_id
      lappend ref_ids $parent_id
      array set "" [:simple_item_ref \
                        -normalize_name $normalize_name \
                        -use_package_path $use_package_path \
                        -use_site_wide_pages $use_site_wide_pages \
                        -default_lang $default_lang \
                        -parent_id $parent_id \
                        -assume_folder [expr {[incr n] < $nr_elements}] \
                        $element]
      #:msg "simple_item_ref <$element> => [array get {}]"
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
    #:log el=[string map [list \0 MARKER] $element]-assume_folder=$assume_folder,parent_id=$parent_id
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
      #:msg "FIRST case name=$name, form=$form_lang:$form"
    } elseif {[regexp {^(..):([^:]{3,}?):(.+)$} $element _ form_lang form (stripped_name)]} {
      array set "" [list link_type "link" form "$form_lang:$form.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
      #:msg "SECOND case name=$name, form=$form_lang:$form"
    } elseif {[regexp {^([^:]{3,}?):(..):(.+)$} $element _ form (prefix) (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:$form.form"]
      set name $(prefix):$(stripped_name)
      #:msg "THIRD case name=$name, form=$default_lang:$form"
    } elseif {[regexp {^([^:]{3,}?):(.+)$} $element _ form (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:$form.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
      #:msg "FOURTH case name=$name, form=$default_lang:$form"
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
      if {$normalize_name} {
        set element [:normalize_name $element]
      }
      set name $default_lang:$element
      set use_default_lang 1
    }

    set name [string trimright $name \0]
    set (stripped_name) [string trimright $(stripped_name) \0]
    if {$normalize_name} {
      set (stripped_name) [:normalize_name $(stripped_name)]
    }

    #
    # Resolve first the special elements in possible variants, such as
    # ".", "..", ...
    #
    if {$element eq "" || $element eq "\0"} {
      array set "" [:item_info_from_id ${:folder_id}]
      set item_id ${:folder_id}
      set parent_id $(parent_id)
      #:msg "SETTING item_id $item_id parent_id $parent_id // [array get {}]"
    } elseif {$element eq "." || $element eq ".\0"} {
      array set "" [:item_info_from_id $parent_id]
      set item_id $parent_id
      set parent_id $(parent_id)
    } elseif {$element eq ".." || $element eq "..\0"} {
      set id [::xo::db::CrClass get_parent_id -item_id $parent_id]
      if {$id > 0} {
        # refuse to traverse past root folder
        set parent_id $id
      }
      array set "" [:item_info_from_id $parent_id]
      set item_id $parent_id
      set parent_id $(parent_id)
    } else {
      #
      # Resolve the cases, that need lookups.
      #
      # When $use_default_lang is set, we will need a valid
      # $default_lang
      #
      if {$use_default_lang && $default_lang eq ""} {
        ad_log warning "Trying to use empty default lang on link '$element' => $name"
      }

      #
      # with the following construct we need in most cases just 1 lookup
      set item_id [:lookup \
                       -use_package_path $use_package_path \
                       -use_site_wide_pages $use_site_wide_pages \
                       -name $name -parent_id $parent_id]
      #:log "${:id} lookup -use_package_path $use_package_path -name $name -parent_id $parent_id => $item_id"

      if {$item_id == 0} {
        #
        # The first lookup was not successful, so we try again.
        #
        if {$(link_type) eq "link" && $element eq $(stripped_name)} {
          #
          # try a direct lookup, in case it is a folder
          #
          set item_id [:lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name $(stripped_name) -parent_id $parent_id]
          #:msg "try again direct lookup, parent_id $parent_id $(stripped_name) => $item_id"
          if {$item_id > 0} {array set "" [list prefix ""]}
        }

        if {$item_id == 0 && $(link_type) eq "link" && $assume_folder && $(prefix) eq ""} {
          set item_id [:lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name $default_lang:$element -parent_id $parent_id]
          if {$item_id > 0} {array set "" [list link_type "link" prefix $default_lang stripped_name $element]
          }
        }

        if {$item_id == 0 && $(link_type) eq "link" && $use_default_lang && $(prefix) ne "en"} {
          #
          # If the name was not specified explicitly (we are using
          # $default_lang), try again with language "en" try again,
          # maybe element is folder in a different language
          #
          set item_id [:lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name en:$(stripped_name) -parent_id $parent_id]
          #:msg "try again in en en:$(stripped_name) => $item_id"
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
          set item_id [:lookup \
                           -use_package_path $use_package_path \
                           -use_site_wide_pages $use_site_wide_pages \
                           -name file:$(stripped_name) -parent_id $parent_id]
        }
      }
    }

    #:msg "return link_type $(link_type) prefix $(prefix) stripped_name $(stripped_name) form $(form) parent_id $parent_id item_id $item_id"
    return [list link_type $(link_type) prefix $(prefix) stripped_name $(stripped_name) \
                form $(form) parent_id $parent_id item_id $item_id ]
  }

  Package instproc item_info_from_id {
    item_id
  } {
    #
    # Obtain (partial) item info from id. It does not handle
    # e.g. special link_types as for e.g. file|image|js|css|swf, etc.
    #
    ::xo::db::CrClass get_instance_from_db -item_id $item_id
    set name [::$item_id name]
    set parent_id [::$item_id parent_id]
    if {[::$item_id is_folder_page]} {
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
    # @param with_package_prefix flag, if provided url contains package-url
    # @return item ref data (parent_id lang stripped_name method)
    #
    if {$with_package_prefix && [string match "/*" $url]} {
      set url [string range $url [string length [:package_url]] end]
    }
    if {$default_lang eq ""} {set default_lang [:default_language]}
    :get_lang_and_name -default_lang $default_lang -path $url (lang) stripped_url
    #:log "get_lang_and_name -default_lang $default_lang -path $url -> $(lang) '$stripped_url'"

    set (parent_id) [:get_parent_and_name \
                         -lang $(lang) -path $stripped_url \
                         -parent_id ${:folder_id} \
                         parent local_name]
    #:log "get_parent_and_name '$stripped_url' returns [array get {}]"

    if {![regexp {^(download)/(.+)$} $(lang) _ (method) (lang)]} {
      set (method) ""
      # The lang value "tag" is used for allowing tag-URLs without
      # parameters, since several tag harvester assume such a syntax
      # and don't process arguments. We rewrite in such cases simply
      # the url and query parameters and update the connection
      # context.
      if {$(lang) eq "tag"} {
        # todo: missing: tag links to subdirectories, also on url generation
        set tag $stripped_url
        :validate_tag $tag
        set summary [::xo::cc query_parameter summary:boolean 0]
        set popular [::xo::cc query_parameter popular:boolean 0]
        set tag_kind [expr {$popular ? "ptag" :"tag"}]
        set weblog_page [:get_parameter weblog_page]
        :get_lang_and_name -default_lang $default_lang -name $weblog_page (lang) local_name
        set :object $weblog_page
        ::xo::cc set actual_query $tag_kind=$tag&summary=$summary
      }
    }
    array set "" [:prefixed_lookup -parent_id $(parent_id) \
                      -default_lang $default_lang -lang $(lang) \
                      -stripped_name $local_name]
    #:log "prefixed_lookup '$local_name' returns [array get {}]"

    if {$(item_id) == 0} {
      #
      # Check symlink (todo: should this happen in package->lookup?)
      #
      ::xo::db::CrClass get_instance_from_db -item_id $(parent_id)
      if {[$(parent_id) is_link_page]} {
        #
        #  We encompassed a link to a page or folder, treat both the same way.
        #
        #:log "item_info_from_url LINK page $(parent_id)"

        set link_id $(parent_id)
        set target [::$link_id get_target_from_link_page]

        $target set_resolve_context -package_id ${:id} -parent_id $link_id
        array set "" [list logical_package_id ${:id} logical_parent_id $link_id]

        #:log "SYMLINK PREFIXED $target ([$target name]) set_resolve_context -package_id ${:id} -parent_id $link_id"

        array set "" [[$target package_id] prefixed_lookup -parent_id [$target item_id] \
                          -default_lang $default_lang -lang $(lang) -stripped_name $(stripped_name)]
        #
        # We can't reset the resolve context here, since it is also
        # required for rendering the target
        #
      }
    }
    #:log "final returns [array get {}]"

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
    #:log "--get_page_from_item_ref [self args]"

    if {$allow_cross_package_item_refs && [string match "//*" $link]} {

      # todo check: get_package_id_from_page_name uses a different lookup based on site nodes

      set referenced_package_id [:resolve_package_path $link rest_link]
      #:log "get_page_from_item_ref $link recursive rl?[info exists rest_link] in $referenced_package_id"
      if {$referenced_package_id != 0 && $referenced_package_id != ${:id}} {
        # TODO: we have still to check, whether or not we want
        # site-wide-pages etc.  in cross package links, and if, under
        # which parent we would like to create newly imported pages.
        #
        # For now, we do not want to create pages this way, we pass
        # the root folder of the referenced package as start
        # parent_page for the search and turn off all page creation
        # facilities.

        #:log cross-package
        return [::$referenced_package_id get_page_from_item_ref \
                    -allow_cross_package_item_refs false \
                    -use_package_path false \
                    -use_site_wide_pages false \
                    -use_prototype_pages false \
                    -default_lang $default_lang \
                    -parent_id [::$referenced_package_id folder_id] \
                    $rest_link]
      } else {
        #
        # It is a link to the same package, we start search for page
        # at the top.
        #
        #:log "--absolute link to the same package <$link> restlink <$rest_link>"
        set link $rest_link
        set search_parent_id ""
      }
    } else {
      set search_parent_id $parent_id
    }

    #:log "my folder ${:folder_id}"

    if {$search_parent_id eq ""} {
      set search_parent_id ${:folder_id}
    }
    if {$parent_id eq ""} {
      set parent_id ${:folder_id}
    }
    #:log call-item_ref-on:$link-parent_id=$parent_id,search_parent_id=$search_parent_id
    array set "" [:item_ref -normalize_name false \
                      -use_package_path $use_package_path \
                      -use_site_wide_pages $use_site_wide_pages \
                      -default_lang $default_lang \
                      -parent_id $search_parent_id \
                      $link]

    #:msg  "[:instance_name] (root ${:folder_id}) item-ref for '$link' search parent $search_parent_id, parent $parent_id, returns\n[array get {}]"
    if {$(item_id)} {
      set page [::xo::db::CrClass get_instance_from_db -item_id $(item_id)]
      if {[$page package_id] ne ${:id} || [$page parent_id] != $(parent_id)} {
        #:msg "set_resolve_context site_wide_pages ${:id} and -parent_id $parent_id"
        $page set_resolve_context -package_id ${:id} -parent_id $parent_id
      }
      return $page
    }

    if {!$(item_id) && $use_prototype_pages} {
      set item_info [:item_ref \
                         -normalize_name false \
                         -default_lang $default_lang \
                         -parent_id $parent_id \
                         $link]

      foreach pkgClass [${:id} info precedence] {
        if {[$pkgClass istype ::xo::PackageMgr] && [$pkgClass package_key] ne "apm_package"} {
          set page [$pkgClass import_prototype_page \
                        -package_key [$pkgClass package_key] \
                        -name [dict get $item_info stripped_name] \
                        -parent_id [dict get $item_info parent_id] \
                        -package_id ${:id} ]
          if {$page ne ""} {
            :log "loading prototype page for [dict get $item_info stripped_name] from [$pkgClass package_key]"
            break
          }
        }
      }

      #:msg "import_prototype_page for '[dict get $item_info stripped_name]' => '$page'"

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

  Package ad_instproc www-import-prototype-page {
    {-add_revision:boolean true}
    {-lang en}
    {-parent_id}
    {prototype_name ""}
  } {

    This web-callable method is designed for admin to ease the import
    of prototpye pages. When called via web, the query parameter
    "import-prototype-page" determines the page for the import.

  } {
    set page ""
    if {$prototype_name eq ""} {
      set prototype_name [:query_parameter import-prototype-page ""]
      set via_url 1
    }
    if {![info exists parent_id]} {
      set parent_id ${:folder_id}
    }
    if {$prototype_name eq ""} {
      error "No name for prototype given"
    }

    set page [::xowiki::Package import_prototype_page \
                  -package_key [:package_key] \
                  -name $prototype_name \
                  -lang $lang \
                  -parent_id $parent_id \
                  -package_id ${:id} \
                  -add_revision $add_revision]

    if {[info exists via_url] && [:exists_query_parameter "return_url"]} {
      :returnredirect [:query_parameter "return_url" [ad_urlencode_folder_path ${:package_url}]]
    } else {
      return $page
    }
  }

  Package proc reparent_site_wide_pages {} {
    #
    # Reparent the site_wide pages from parent_id -100 to the
    # site_wide xowiki instance. Reparenting is necessary to keep the
    # relations to form instances.
    #
    # This is transitional code (just for the move). It is safe to
    # execute this method multiple times.
    #
    set site_info [:require_site_wide_info]
    set parent_id [dict get $site_info folder_id]
    set page_info [::xo::dc list_of_lists get_site_wide_pages {
      select item_id,name from cr_items
      where parent_id = -100
      and content_type like '::%'
      and name not like 'xowiki: %'
    }]
    xo::dc transaction {
      foreach {item_id name} [concat {*}$page_info] {
        #
        # Avoid potential name clashes in case require_site_wide_pages
        # was already run and has populated the site.
        #
        xo::dc dml maybe_delete_page {
          delete from cr_items where parent_id = :parent_id and name = :name
        }
        #
        # Reparent page (identified by item_id) to site_wide instance
        #
        xo::dc dml reparent_page {
          update cr_items set parent_id = :parent_id where item_id = :item_id
        }
      }
    }
    :fix_site_wide_package_ids
  }

  Package proc -deprecated preferredCSSToolkit {} {
    return [::xowiki::CSS toolkit]
  }

  Package instproc call {object method options} {
    set allowed [${:policy} enforce_permissions \
                     -package_id ${:id} -user_id [::xo::cc user_id] \
                     $object $method]
    if {$allowed} {
      #:log "--p calling $object ([$object info class]) '$method'"
      $object www-$method {*}$options
    } else {
      :log "not allowed to call $object $method"
    }
  }
  Package instforward check_permissions {%set :policy} %proc

  Package ad_instproc require_root_folder {
    {-parent_id -100}
    {-content_types {}}
    -name:required
  } {
    Make sure, the root folder for the given package exists. If not,
    create it and register all allowed content types.

    @return folder_id
  } {
    set folder_id [xo::xotcl_package_cache eval root_folder-${:id} {

      set folder_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
      if {$folder_id == 0} {
        #
        # When the folder_id is empty, then something is wrong. Maybe an
        # earlier update script was not running correctly.
        #
        set old_folder_id [xo::dc get_value double_check_old_package {
          select item_id from cr_items where name = :name and parent_id = :parent_id
        }]
        if {$old_folder_id ne ""} {
          :log "-- try to transform old root folder $old_folder_id of package ${:id}"
          ::xowiki::transform_root_folder ${:id}
          set folder_id $old_folder_id
        } else {
          #
          # Check, if the package_key belongs to xowiki (it might be a
          # subclass). If this is not the case, the call is probably an
          # error and we do not want to create a root folder.
          #
          set package_class [::xo::PackageMgr get_package_class_from_package_key ${:package_key}]
          if {$package_class eq ""} {
            ad_log error "trying to create an xowiki root folder for non-xowiki package ${:id}"
            error "trying to create an xowiki root folder for non-xowiki package ${:id}"
          } else {
            ::xowiki::Package require_site_wide_pages
            set form_id [::${:id} instantiate_forms -forms en:folder.form]
            set f [FormPage new -destroy_on_cleanup \
                       -name $name \
                       -text "" \
                       -package_id ${:id} \
                       -parent_id $parent_id \
                       -nls_language en_US \
                       -publish_status ready \
                       -instance_attributes {} \
                       -page_template $form_id]
            $f save_new
            set folder_id [$f item_id]

            ::xo::db::sql::acs_object set_attribute -object_id_in $folder_id \
                -attribute_name_in context_id -value_in ${:id}

            :log "CREATED folder '$name' and parent $parent_id ==> $folder_id"
          }
        }
      }

      # register all specified content types
      #::xo::db::CrFolder register_content_types \
          #    -folder_id $folder_id \
          #    -content_types $content_types
      #:log "returning from cache folder_id $folder_id"
      return $folder_id
    }]
    #:log "returning from require folder_id $folder_id"
    return $folder_id
  }

  Package instproc require_folder_object { } {
    set :folder_id [:require_root_folder -name "xowiki: ${:id}" \
                       -content_types ::xowiki::Page* ]
    ::xo::db::CrClass get_instance_from_db -item_id ${:folder_id}
  }


  ###############################################################
  #
  # user callable methods on package level
  #

  Package ad_instproc www-refresh-login {} {

    This web-callable method forces a refresh of a login and do a
    redirect. Intended for use from ajax.

  } {
    set return_url [:query_parameter return_url:localurl]
    if {[::xo::cc user_id] == 0} {
      set url [subsite::get_url]register
      :returnredirect [export_vars -base $url return_url]
    } else {
      :returnredirect $return_url
    }
  }

  #
  # reindex (for site wide search)
  #
  Package ad_instproc www-reindex {} {

    This web-callable method can be used to reindex all items of this
    package by adding all pages of this package to the search queue.

  } {
    set id ${:id}
    set pages [::xo::dc list get_pages {
      select page_id,package_id from xowiki_page, cr_revisions r, cr_items ci, acs_objects o
      where page_id = r.revision_id and ci.item_id = r.item_id and ci.live_revision = page_id
      and publish_status = 'ready'
      and page_id = o.object_id and o.package_id = :id
    }]
    #:log "--reindex returns <$pages>"
    foreach page_id $pages {
      #search::queue -object_id $page_id -event DELETE
      search::queue -object_id $page_id -event INSERT
    }
    :returnredirect .
  }

  #
  # www-update-references (for admin purposes, should not be necessary)
  #
  Package ad_instproc www-update-references {} {

    This web-callable method can be used to update the page references
    between all items of this package instance.

    Call with e.g. xowiki/?update-references

  } {
    set id ${:id}
    set item_ids [::xo::dc list get_pages {
      select ci.item_id from xowiki_page, cr_revisions r, cr_items ci, acs_objects o
      where page_id = r.revision_id and ci.item_id = r.item_id and ci.live_revision = page_id
      and publish_status = 'ready'
      and page_id = o.object_id and o.package_id = :id
    }]
    #:log "--update-references returns <$item_ids>"
    foreach item_id $item_ids {
      set o [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      if {$o ne ""} {
        ns_log notice "render $o [$o name]"
        try {
          $o render -update_references all
        } on error {errorMsg} {
          ns_log warning "render $o [$o name] -> error: $errorMsg"
        }
      }
    }
    :returnredirect .
  }

  #
  # change-page-order (normally called via AJAX POSTs)
  #
  Package ad_instproc www-change-page-order {} {

    This web-callable method changes the page order for pages by
    renumbering and filling gaps. The parameter "clean" is just used
    for page inserts. This method is typically called via AJAX.

  } {
    ::xowiki::utility change_page_order \
        -from [string trim [:form_parameter from ""]] \
        -to [string trim [:form_parameter to ""]] \
        -clean [string trim [:form_parameter clean ""]] \
        -folder_id [string trim [:form_parameter folder_id ${:folder_id}]] \
        -package_id ${:id} \
        -publish_status [string trim [:form_parameter publish_status "ready|live|expired"]]

    set :mime_type text/plain
    return ""
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

    This web-callable method reports the content of xowiki folder in
    rss 2.0 format. The reporting order is descending by date. The
    title of the feed is taken from the title, the description is
    taken from the description field of the folder object.

    @param maxentries maximum number of entries retrieved
    @param days report entries changed in specified last days

  } {
    set folder_id [::${:id} folder_id]
    if {![info exists name_filter]} {
      set name_filter [:get_parameter -type word name_filter ""]
    }
    if {![info exists entries_of]} {
      set entries_of [:get_parameter entries_of ""]
    }
    if {![info exists title]} {
      set title [:get_parameter PackageTitle [:instance_name]]
    }
    set description [:get_parameter PackageDescription ""]

    if {![info exists days]} {
      set rss_query_parameter [:query_parameter rss]
      if {[regexp {^([0-9]+)d} $rss_query_parameter _ days]
          && $days < 50000
        } {
        # Variable "days" is set by regexp
      } else {
        ns_log warning "rss_query_parameter has invalid value '$rss_query_parameter'; fall back to 10d"
        set days 10
      }
    } else {
      set days 10
    }
    set r [RSS new -destroy_on_cleanup \
               -package_id ${:id} \
               -parent_ids [:query_parameter parent_ids:int32,0..n ""] \
               -name_filter $name_filter \
               -entries_of $entries_of \
               -title $title \
               -description $description \
               -days $days]

    set :mime_type text/xml
    return [$r render]
  }

  #
  # Google sitemap support
  #

  Package ad_instproc www-google-sitemap {
    {-max_entries ""}
    {-changefreq "daily"}
    {-priority "0.5"}
  } {

    This web-callable method reports the content of xowiki folder in
    google site map format
    https://www.google.com/webmasters/sitemaps/docs/en/protocol.html

    @param max_entries maximum number of entries retrieved
    @param changefreq changefreq as defined by google
    @param priority priority as defined by google

  } {
    set package ::${:id}
    set folder_id [$package folder_id]

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
    # :log $sql

    ::xo::dc foreach get_pages $sql {
      #:log "--found $name"
      if {[string match "::*" $name]} continue
      if {$content_type eq "::xowiki::PageTemplate::"} continue

      set time [::xo::db::tcl_date $last_modified tz]
      set time "[clock format [clock scan $time] -format {%Y-%m-%dT%T}]${tz}:00"

      append content <url> \n\
          <loc>[$package pretty_link -absolute true -parent_id $parent_id $name]</loc> \n\
          <lastmod>$time</lastmod> \n\
          <changefreq>$changefreq</changefreq> \n\
          <priority>$priority</priority> \n\
          </url> \n
    }

    append content </urlset> \n

    set :mime_type text/xml
    return $content

  }

  Package ad_proc google_sitemapindex {
    {-changefreq "daily"}
    {-priority "priority"}
    {-package}
  } {

    This method provides a sitemap index of all xowiki
    instances in google site map format
    https://www.google.com/webmasters/sitemaps/docs/en/protocol.html

    @param package to determine the delivery instance
    @param changefreq changefreq as defined by google
    @param priority priority as defined by google

  } {
    set content {<?xml version="1.0" encoding="UTF-8"?>
      <sitemapindex xmlns="http://www.google.com/schemas/sitemap/0.84">
    }
    foreach package_id [::xowiki::Package instances] {
      if {![::xo::parameter get -package_id $package_id \
                -parameter include_in_google_sitemap_index -default 1]} {
        continue
      }
      set last_modified [::xo::dc get_value get_newest_modification_date \
                             {select max(last_modified)
                               from acs_objects
                               where package_id = :package_id
                             }]

      set time [::xo::db::tcl_date $last_modified tz]
      set time "[clock format [clock scan $time] -format {%Y-%m-%dT%T}]${tz}:00"

      #:log "--site_node::get_from_object_id -object_id $package_id"
      array set info [site_node::get_from_object_id -object_id $package_id]

      append content <sitemap> \n\
          <loc>[ad_url]$info(url)sitemap.xml</loc> \n\
          <lastmod>$time</lastmod> \n\
          </sitemap>
    }
    append content </sitemapindex> \n
    if {[info exists package]} {
      #
      # Since we are running here in a proc, and we were called via
      # "reply_to_user", we have to provide the proper mime_type to the
      # calling package instance for delivery
      #
      $package set mime_type text/xml
      return $content
    } else {
      #
      # In case, someone called us differently
      #
      ns_return 200 text/xml $content
      ad_script_abort
    }
  }

  Package ad_instproc www-google-sitemapindex {} {

    This web-callable method calls "google_sitemapindex" for producing
    a sitemap index.

  } {
    [self class] google_sitemapindex -package [self]
  }

  Package instproc clipboard-copy {} {
    ${:folder_id} clipboard-copy
  }

  #
  # Create new pages
  #

  Package ad_instproc www-edit-new {} {

    This web-callable method can be used to create new pages in the
    current package. The behavior can be influenced by the query
    parameters "object_type", "autoname", "parent_id" and
    "source_item_id".

    Finally, it calls "www-edit" for the freshly created page.

  } {
    set object_type [:query_parameter object_type:class "::xowiki::Page"]
    set autoname [:get_parameter autoname 0]
    set parent_id [${:id} query_parameter parent_id:int32 ""]
    if {$parent_id eq ""} {set parent_id [${:id} form_parameter folder_id ${:folder_id}]}
    if {![string is integer -strict $parent_id]} {
      ad_return_complaint 1 "invalid parent_id"
      ad_script_abort
    }
    set page [$object_type new -volatile -parent_id $parent_id -package_id ${:id}]
    # :ds "parent_id of $page = [$page parent_id], cl=[$page info class] parent_id=$parent_id\n[$page serialize]"
    if {$object_type eq "::xowiki::PageInstance"} {
      #
      # If we create a PageInstance via the ad_form based
      # PageInstanceForm, we have to provide the page_template here to
      # be able to validate the name, where "build_name" needs
      # access to the ::xowiki::PageTemplate of the
      # ::xowiki::PageInstance.
      #
      $page set page_template [:form_parameter page_template]
    }

    set source_item_id [${:id} query_parameter source_item_id:int32 ""]
    if {$source_item_id ne ""} {
      if {![string is integer -strict $source_item_id]} {
        ad_return_complaint 1 "invalid source_item_id"
        ad_script_abort
      }
      set source [$object_type get_instance_from_db -item_id $source_item_id]
      $page copy_content_vars -from_object $source
      set name "[::xowiki::autoname new -parent_id $source_item_id -name [$source name]]"
      # :get_lang_and_name -name $name lang name
      $page set name $name
      #:msg nls=[$page nls_language],source-nls=[$source nls_language],page=$page,name=$name
    } else {
      $page set name ""
    }

    return [$page www-edit -new true -autoname $autoname]
  }

  #
  # Manage categories
  #

  Package ad_instproc www-manage-categories {} {

    This web-callable method redirects the caller to the category
    admin page configured for the current package. The "object_id" has
    to be provided as a query parameter.

  } {
    set object_id [:query_parameter object_id:int32]

    # flush could be made more precise in the future
    :flush_page_fragment_cache -scope agg

    set href [export_vars \
                  -base [site_node::get_package_url -package_key categories]cadmin/object-map {
                    {ctx_id $object_id} object_id
                  }]
    :returnredirect $href
  }

  #
  # Edit a single category tree
  #

  Package ad_instproc www-edit-category-tree {} {

    This web-callable method redirects the caller to the category
    admin page for a certain category tree. The "object_id" and
    "tree_id" have to be provided as a query parameter.

  } {
    set object_id [:query_parameter object_id:int32]
    set tree_id [:query_parameter tree_id:int32]

    # flush could be made more precise in the future
    :flush_page_fragment_cache -scope agg
    :returnredirect [export_vars \
                         -base [site_node::get_package_url -package_key categories]/cadmin/tree-view {
                           tree_id {ctx_id $object_id} object_id
                         }]
  }


  #
  # Package import
  #

  Package ad_instproc import {-user_id {-parent_id 0} {-replace 0} -objects {-create_user_ids 0}} {
    import the specified pages into the xowiki instance
  } {
    if {$parent_id == 0} {set parent_id ${:folder_id}}
    if {![info exists user_id]} {set user_id [::xo::cc user_id]}
    if {![info exists objects]} {set objects [::xowiki::Page allinstances]}
    set msg "#xowiki.processing_objects#: $objects<p>"
    set importer [Importer new -package_id ${:id} -parent_id $parent_id -user_id $user_id]
    $importer import_all -replace $replace -objects $objects -create_user_ids $create_user_ids
    append msg [$importer report]
  }

  Package instproc flush_references {-item_id:integer,required -name -parent_id} {
    if {![info exists parent_id]} {
      set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
    }
    if {![info exists name]} {
      set name [::xo::db::CrClass get_name -item_id $item_id]
    }
    :flush_name_cache -name $name -parent_id $parent_id
  }

  Package instproc flush_name_cache {-name:required -parent_id:required} {
    # xowiki::LinkCache flush $parent_id
    ::xo::xotcl_object_type_cache flush -partition_key $parent_id $parent_id-$name
    acs::per_request_cache flush -pattern xotcl-core.lookup-$parent_id-$name
  }

  Package instproc delete_revision {-revision_id:required -item_id:required} {
    ::xo::xotcl_object_cache flush $item_id
    ::xo::xotcl_object_cache flush $revision_id
    ::xo::db::sql::content_revision del -revision_id $revision_id
  }

  Package ad_instproc www-delete {-item_id -name -parent_id} {

    This web-callable "delete" method does not require an instantiated object,
    while the class-specific delete methods in xowiki-procs need these.
    If a (broken) object can't be instantiated, it cannot be deleted.
    Therefore, we need this package level delete method.
    While the class specific methods are used from the
    application pages, the package_level method is used from the admin pages.

    If no item_id given, take it from the query parameter

  } {
    #:log "--D delete [self args]"

    if {![info exists item_id]} {
      set item_id [:query_parameter item_id:int32]
      #:log "--D item_id from query parameter $item_id"
    }
    #
    # if no name is given, take it from the query parameter
    #
    if {![info exists name]} {
      set name [:query_parameter name]
    }

    if {$item_id eq ""} {
      set item_info [:item_info_from_url -with_package_prefix false $name]
      if {[dict get $item_info item_id] == 0} {
        :log "www-delete: url lookup of '$name' failed"
      } else {
        set parent_id [dict get $item_info parent_id]
        set item_id   [dict get $item_info item_id]
        set name      [dict get $item_info name]
      }
    } else {
      set name [::xo::db::CrClass get_name -item_id $item_id]
      if {![info exists parent_id]} {
        set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
      }
    }
    #:msg item_id=$item_id/name=$name

    if {$item_id ne ""} {
      :log "--D trying to delete $item_id $name"
      set object_type [::xo::db::CrClass get_object_type -item_id $item_id]
      # In case of PageTemplate and subtypes, we need to check
      # for pages using this template
      set classes [list $object_type {*}[$object_type info heritage]]
      if {"::xowiki::PageTemplate" in $classes} {
        set count [::xowiki::PageTemplate count_usages -item_id $item_id -publish_status all]
        if {$count > 0} {
          return [${:id} error_msg \
                      [_ xowiki.error-delete_entries_first [list count $count]]]
        }
      }
      if {[:get_parameter "with_general_comments" 0]} {
        #
        # We have general comments. In a first step, we have to delete
        # these, before we are able to delete the item.
        #
        set comment_ids [::xo::dc list get_comments {
          select comment_id from general_comments where object_id = :item_id
        }]
        foreach comment_id $comment_ids {
          :log "-- deleting comment $comment_id"
          ::xo::db::sql::content_item del -item_id $comment_id
        }
      }
      foreach child_item_id [::xo::db::CrClass get_child_item_ids -item_id $item_id] {
        :flush_references -item_id $child_item_id
      }
      $object_type delete -item_id $item_id
      :flush_references -item_id $item_id -name $name -parent_id $parent_id
      :flush_page_fragment_cache -scope agg
    } else {
      :log "--D nothing to delete!"
    }
    :returnredirect [:query_parameter "return_url" [ad_urlencode_folder_path ${:package_url}]]
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
    :flush_references -item_id $item_id -name $name -parent_id $parent_id
    :flush_page_fragment_cache -scope agg

    ::xo::xotcl_object_cache flush $item_id

    #
    # Clear potentially cached revisions. The function could be
    # optimized in the future by an index of the cached revision_ids
    # for an item_id
    #
    foreach revision_id [::xo::dc list get_revisions {
      select revision_id from cr_revisions where item_id = :item_id
    }] {
      ::xo::xotcl_object_cache flush $revision_id
    }
  }

  Package instproc flush_page_fragment_cache {{-scope agg}} {
    switch -- $scope {
      agg {set key PF-${:id}-agg-*}
      all {set key PF-${:id}-*}
      default {error "unknown scope for flushing page fragment cache"}
    }
    xowiki::cache flush_pattern -partition_key ${:id} $key
  }

  #
  # Perform per connection parameter caching.  Using the
  # per-connection cache speeds later lookups up by a factor of 15.
  # Repeated parameter lookups are quite likely
  #

  Class create ParameterCache
  ParameterCache instproc get_parameter {
    {-check_query_parameter true}
    {-nocache:switch}
    {-type ""}
    attribute
    {default ""}
  } {
    #ns_log notice "check for parameter $attribute, xo::cc exists <[info commands ::xo::cc]>"
    if {$nocache} {
      next
    } else {
      set key [list ${:id} [self proc] $attribute]
      if {[nsf::is object "::xo::cc"]} {
        if {[::xo::cc cache_exists $key]} {
          return [::xo::cc cache_get $key]
        }
        return [::xo::cc cache_set $key [next]]
      } else {
        # in case, we have no ::xo::cc (e.g. during bootstrap).
        ad_log warning "no ::xo::cc available (package_id ${:id}), returning default for parameter $attribute"
        return $default
      }
    }
  }
  Package instmixin add ParameterCache


  #
  # policy management
  #

  Package instproc condition=has_class {query_context value} {
    return [expr {[$query_context query_parameter object_type:class ""] eq $value}]
  }
  Package instproc condition=has_name {query_context value} {
    return [regexp $value [$query_context query_parameter name ""]]
  }

  Class create Policy -superclass ::xo::Policy

  Policy policy1 -contains {

    Class create Package -array set require_permission {
      reindex             swa
      update-references   {{id admin}}
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
        {{regexp {name {(:weblog|:index)$}}} package_id admin}
        {package_id write}
      }
      save-attributes    {{package_id write}}
      autosave-attribute {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    {{package_id admin}}
      delete             {{package_id admin}}
      bulk-delete        {{package_id admin}}
      duplicate          {{package_id write}}
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

    Class create FormPage -array set require_permission {
      list           { {{is_folder_page .} read} }
    }
  }

  Policy policy2 -contains {
    #
    # we require side wide admin rights for deletions and code
    #

    Class create Package -array set require_permission {
      reindex             {{id admin}}
      update-references   {{id admin}}
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
      autosave-attribute {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    swa
      delete             swa
      bulk-delete        swa
      duplicate          {{package_id write}}
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
    Class create FormPage -array set require_permission {
      list           { {{is_folder_page .} read} }
    }
  }

  Policy policy3 -contains {
    #
    # we require side wide admin rights for deletions
    # we perform checking on item_ids for pages.
    #

    Class create Package -array set require_permission {
      reindex             {{id admin}}
      update-references   {{id admin}}
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
      autosave-attribute {{package_id write}}
      delete-revision    swa
      delete             swa
      bulk-delete        swa
      duplicate          {{parent_id create}}
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      login
      list               admin
      show-object        swa
    }

    Class create Object -array set require_permission {
      edit               swa
    }
    Class create File -array set require_permission {
      download           {{item_id read}}
    }
    Class create Form -array set require_permission {
      view              admin
      edit              admin
      list              {{item_id read}}
    }
    Class create FormPage -array set require_permission {
      view               {
        {{in_state initial|answered} creator}
        {{in_state initial|answered} admin}
        {item_id read}
      }
      edit               {
        {{in_state initial|answered|suspended|working|done} creator}
        admin
      }
      list               {
        {{is_folder_page .} read}
        admin
      }
      clipboard-add      admin
      clipboard-clear    admin
      clipboard-content  admin
      clipboard-copy     admin
      clipboard-export   admin
      file-upload        admin
    }
  }

  #Policy policy4 -contains {
  #  ::xotcl::Object function -array set require_permission {
  #    f none
  #  } -set default_permission login
  #}

  #:log "--set granted [policy4 check_permissions -user_id 0 -package_id 0 function f]"

  #
  # an example with in_state condition...
  #
  Policy policy5 -contains {

    Class create Package -array set require_permission {
      reindex             {{id admin}}
      update-references   {{id admin}}
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
      autosave-attribute {{item_id write}}
      make-live-revision {{item_id write}}
      delete-revision    swa
      delete             swa
      bulk-delete        swa
      duplicate          {{parent_id create}}
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
      list               {
        {{is_folder_page .} read}
        admin
      }
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

::xo::library doc {
  XoWiki - define various kind of includelets

  @creation-date 2006-10-10
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki::includelet {
  #
  # Define a meta-class for creating Includelet classes.
  # We use a meta-class for making it easier to define properties
  # on classes of includelets, which can be used without instantiating
  # it. One can for example use the query from the page fragment
  # cache the caching properties of the class.
  #
  Class create ::xowiki::IncludeletClass \
      -superclass ::xotcl::Class \
      -parameter {
        {localized true}
        {personalized true}
        {cacheable false}
        {aggregating false}
      }

  # The general superclass for includelets

  Class create ::xowiki::Includelet \
      -superclass ::xo::Context \
      -parameter {
        {name ""}
        {title ""}
        {__decoration "portlet"}
        {parameter_declaration {}}
        {id}
      }

  ::xowiki::Includelet instproc get_current_folder {parent} {
    set package_id [${:__including_page} package_id]
    #:log "get_current_folder: including_page current_folder $current_folder '[$current_folder name]'"

    if {$parent eq ".."} {
      set current_folder [${:__including_page} parent_id]
      ::xo::db::CrClass get_instance_from_db -item_id $current_folder
    } elseif {$parent eq "."} {
      set current_folder ${:__including_page}
    } elseif {$parent eq "/"} {
      # set current_folder to the package folder
      set current_folder [::$package_id folder_id]
    } else {
      set page [::$package_id get_page_from_item_ref \
                    -use_package_path true \
                    -use_site_wide_pages true \
                    -use_prototype_pages true \
                    -default_lang [string range ${:locale} 0 1] \
                    -parent_id [${:__including_page} parent_id] \
                    $parent]
      if {$page ne ""} {
        set current_folder $page
      } else {
        ns_log warning "could not fetch folder via item_ref '$parent'"
        set current_folder ${:__including_page}
      }
    }
    #:log "get_current_folder: parent $parent, current_folder $current_folder '[$current_folder name]', folder is formPage [$current_folder istype ::xowiki::FormPage]"

    if {![$current_folder istype ::xowiki::FormPage]} {
      # current folder has to be a FormPage
      set current_folder [$current_folder parent_id]
      #:log "###### use parent of current folder $current_folder '[$current_folder name]'"

      if {![$current_folder istype ::xowiki::FormPage]} {
        error "get_current_folder not included from a FormPage"
      }
    }
    return $current_folder
  }

  #2.8.0r4
  ::xowiki::Includelet proc require_YUI_CSS {{-version 2.7.0} {-ajaxhelper true} path} {
    if {$ajaxhelper} {
      ::xo::Page requireCSS "/resources/ajaxhelper/yui/$path"
    } else {
      ::xo::Page requireCSS "//yui.yahooapis.com/$version/build/$path"
      security::csp::require style-src yui.yahooapis.com
    }
  }

  ::xowiki::Includelet proc require_YUI_JS {{-version 2.7.0} {-ajaxhelper true} path} {
    if {$ajaxhelper} {
      ::xo::Page requireJS "/resources/ajaxhelper/yui/$path"
    } else {
      ::xo::Page requireJS "//yui.yahooapis.com/$version/build/$path"
      security::csp::require script-src yui.yahooapis.com
    }
  }

  ::xowiki::Includelet proc describe_includelets {includelet_classes} {
    #:log "--plc=$includelet_classes "
    foreach cl $includelet_classes {
      set result ""
      append result "{{<b>[namespace tail $cl]</b>"
      foreach p [$cl info parameter] {
        if {[llength $p] != 2} continue
        lassign $p name value
        if {$name eq "parameter_declaration"} {
          foreach pp $value {
            #append result ""
            switch [llength $pp] {
              1 {append result " $pp"}
              2 {
                set v [lindex $pp 1]
                if {$v eq ""} {set v {""}}
                append result " [lindex $pp 0] <em>[ns_quotehtml $v]</em>"
              }
            }
            #append result "\n"
          }
        }
      }
      append result "}}\n<p>"
      set index [::xo::api object_index "" $cl]
      if {[nsv_exists api_library_doc $index]} {
        set doc_elements [nsv_get api_library_doc $index]
        append result [lindex [dict get $doc_elements main] 0]
      }
      set :html([namespace tail $cl]) $result
      :describe_includelets [$cl info subclass]
    }
  }
  ::xowiki::Includelet proc available_includelets {} {
    if {[array exists :html]} {array unset :html}
    :describe_includelets [::xowiki::Includelet info subclass]
    set result "<ul>"
    foreach d [lsort [array names :html]] {
      append result "<li>" [set :html($d)] "</li>" \n
    }
    append result "</ul>"
    return $result
  }

  ::xowiki::Includelet proc html_to_text {string} {
    return [string map [list "&amp;" &] $string]
  }

  ::xowiki::Includelet proc js_name {name} {
    return ID[string map [list : _ # _] $name]
  }

  ::xowiki::Includelet proc js_encode {string} {
    string map [list \n \\n \" {\"} ' {\'}] $string
  }

  ::xowiki::Includelet proc html_encode {string} {
    # &apos; is not a known entity to some validators, so we use the
    # numerical entity here for encoding "'"
    return [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&#39;"] $string]
  }


  ::xowiki::Includelet proc html_id {name} {
    # Construct a valid HTML id or name.
    # For details, see http://www.w3.org/TR/html4/types.html
    #
    # For XOTcl object names, strip first the colons
    set name [string trimleft $name :]

    # make sure, the ID starts with characters
    if {![regexp {^[A-Za-z]} $name]} {
      set name id_$name
    }

    # replace unwanted characters
    regsub -all -- {[^A-Za-z0-9_.-]} $name _ name
    return $name
  }

  ::xowiki::Includelet proc publish_status_clause {{-base_table ci} value} {
    set table_prefix ""
    if {$base_table ne ""} {
      set table_prefix "$base_table."
    }
    set publish_status_clause ""
    if {$value ne "all"} {
      set valid_states {production ready live expired}
      set clauses [list]
      foreach state [split $value |] {
        if {$state ni $valid_states} {
          error "no such state: '$state'; valid states are: production, ready, live, expired"
        }
        lappend clauses "${table_prefix}publish_status='$state'"
      }
      if {[llength $clauses] > 0} {
        set publish_status_clause " and ([join $clauses { or }])"
      }
    }
    return $publish_status_clause
  }

  ::xowiki::Includelet proc locale_clause {
                                           -revisions
                                           -items
                                           package_id
                                           locale
                                         } {
    set default_locale [::$package_id default_locale]
    set system_locale ""

    set with_system_locale [regexp {(.*)[+]system} $locale _ locale]
    if {$locale eq "default"} {
      set locale $default_locale
      set include_system_locale 0
    }
    #:msg "--L with_system_locale=$with_system_locale, locale=$locale, default_locale=$default_locale"

    set locale_clause ""
    if {$locale ne ""} {
      set locale_clause " and $revisions.nls_language = '$locale'"
      if {$with_system_locale} {
        set system_locale [lang::system::locale -package_id $package_id]
        #:msg "system_locale=$system_locale, default_locale=$default_locale"
        if {$system_locale ne $default_locale} {
          set locale_clause " and ($revisions.nls_language = '$locale'
        or $revisions.nls_language = '$system_locale' and not exists
          (select 1 from cr_items i where i.name = '[string range $locale 0 1]:' ||
          substring($items.name,4) and i.parent_id = $items.parent_id))"
        }
      }
    }

    #:msg "--locale $locale, def=$default_locale sys=$system_locale, cl=$locale_clause locale_clause=$locale_clause"
    return [list $locale $locale_clause]
  }

  ::xowiki::Includelet instproc category_clause {category_spec {item_ref p.item_id}} {
    # the category_spec has the syntax "a,b,c|d,e", where the values are category_ids
    # pipe symbols are or-operations, commas are and-operations;
    # no parenthesis are permitted
    set extra_where_clause ""
    set or_names [list]
    set ors [list]
    foreach cid_or [split $category_spec |] {
      set ands [list]
      set and_names [list]
      foreach cid_and [split $cid_or ,] {
        if {![string is integer -strict $cid_and]} {
          ad_return_complaint 1 "invalid category id '$cid_and'"
          ad_script_abort
        }
        lappend and_names [::category::get_name $cid_and]
        lappend ands "exists (select 1 from category_object_map \
           where object_id = $item_ref and category_id = [ns_dbquotevalue $cid_and])"
      }
      lappend or_names [join $and_names { and }]
      lappend ors "([join $ands { and }])"
    }
    if {$ors eq "()"} {
      set cnames ""
    } else {
      set cnames [join $or_names { or }]
      set extra_where_clause "and ([join $ors { or }])"
    }
    #:log "--cnames $category_spec -> $cnames // <$extra_where_clause>"
    return [list $cnames $extra_where_clause]
  }

  ::xowiki::Includelet proc parent_id_clause {
                                              {-base_table bt}
                                              {-use_package_path true}
                                              {-parent_id ""}
                                              -base_package_id:required
                                            } {
    #
    # Get the package path and from it, the folder_ids. The parent_id
    # of the returned pages should be a direct child of the folder.
    #
    if {$parent_id eq ""} {
      set parent_id [::$base_package_id folder_id]
    }
    set packages [::$base_package_id package_path]
    if {$use_package_path && [llength $packages] > 0} {
      set parent_ids [list $parent_id]
      foreach p $packages {lappend parent_ids [$p folder_id]}
      return "$base_table.parent_id in ([ns_dbquotelist $parent_ids])"
    } else {
      return "$base_table.parent_id = [ns_dbquotevalue $parent_id]"
    }
  }

  ::xowiki::Includelet proc glob_clause {{-base_table ci} {-attribute name} value} {
    # Return a clause for name matching.
    # value uses * for matching
    set glob [string map [list * %] $value]
    return " and $base_table.$attribute like '$glob'"
  }

  #
  # Other helpers
  #

  ::xowiki::Includelet proc listing {
                                     -package_id
                                     {-count:boolean false}
                                     {-folder_id}
                                     {-parent_id ""}
                                     {-page_size 20}
                                     {-page_number ""}
                                     {-orderby ""}
                                     {-use_package_path true}
                                     {-extra_where_clause ""}
                                     {-glob ""}
                                   } {
    if {$count} {
      set attribute_selection "count(*)"
      set orderby ""      ;# no need to order when we count
      set page_number  ""      ;# no pagination when count is used
    } else {
      set attribute_selection "i.name, r.title, p.page_id, r.publish_date, \
        r.mime_type, i.parent_id, o.package_id, \
                to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as formatted_date"
    }
    if {$page_number ne ""} {
      set limit $page_size
      set offset [expr {$page_size*($page_number-1)}]
    } else {
      set limit ""
      set offset ""
    }
    set parent_id_clause [::xowiki::Includelet parent_id_clause \
                              -base_table i \
                              -use_package_path $use_package_path \
                              -parent_id $parent_id \
                              -base_package_id $package_id]

    if {$glob ne ""} {
      append extra_where_clause [::xowiki::Includelet glob_clause -base_table i $glob]
    }

    set sql [::xo::dc select \
                 -vars $attribute_selection \
                 -from "cr_items i, cr_revisions r, xowiki_page p, acs_objects o" \
                 -where "$parent_id_clause \
                     and r.revision_id = i.live_revision \
                     and i.item_id = o.object_id \
                     and p.page_id = r.revision_id \
             and i.publish_status <> 'production' $extra_where_clause" \
                 -orderby $orderby \
                 -limit $limit -offset $offset]

    if {$count} {
      return [::xo::dc get_value count_listing $sql]
    } else {
      set s [::xowiki::Page instantiate_objects -sql $sql]
      return $s
    }
  }


  #
  # inherited methods for all includelets
  #

  ::xowiki::Includelet instproc resolve_page_name {page_name} {
    return [${:__including_page} resolve_included_page_name $page_name]
  }

  ::xowiki::Includelet instproc get_page_order {-source -ordered_pages -pages} {
    #
    # first check, if we can load the page_order from the page
    # denoted by source
    #
    if {[info exists source]} {
      set p [:resolve_page_name $source]
      if {$p ne ""} {
        set ia [$p set instance_attributes]
        if {[dict exists $ia pages]} {
          set pages [dict get $ia pages]
        } elseif {[dict exists $ia ordered_pages]} {
          set ordered_pages [dict get $ia ordered_pages]
        }
      }
    }

    # compute a list of ordered_pages from pages, if necessary
    if {[info exists ordered_pages]} {
      foreach {order page} $ordered_pages {set :page_order($page) $order}
    } else {
      set i 0
      foreach page $pages {set :page_order($page) [incr i]}
    }
  }

  ::xowiki::Includelet instproc include_head_entries {} {
    # The purpose of this method is to contain all calls to include
    # CSS files, JavaScript, etc. in the HTML head. This kind of
    # requirement could as well be included e.g. in render, but this
    # won't work, when the result of "render" is cached.  This method
    # is called before render to be executed even when render is not
    # due to caching.  It is intended to be overloaded by subclasses.
  }

  ::xowiki::Includelet instproc initialize {} {
    # This method is called at a time after init and before render.
    # It can be used to alter specified parameter from the user,
    # or to influence the rendering of a decoration (e.g. title etc.)
  }

  ::xowiki::Includelet instproc js_name {} {
    return [[self class] js_name [self]]
  }

  ::xowiki::Includelet instproc screen_name {user_id} {
    set screen_name [acs_user::get_user_info -user_id $user_id -element screen_name]
    if {$screen_name eq ""} {
      set screen_name [person::get_person_info -person_id $user_id -element name]
    }
    return $screen_name
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  ::xowiki::IncludeletClass create available-includelets \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "The following includelets can be used in a page"}
      } -ad_doc {
        List the available includelets of this installation.
      }

  available-includelets instproc render {} {
    :get_parameters
    return [::xowiki::Includelet available_includelets]
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  ::xowiki::IncludeletClass create available-formfields \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "The following formfield types can be used in xowiki::Forms"}
        {parameter_declaration {
          {-flat:boolean false}
        }}
      } -ad_doc {
        List the available form field types of this installation.

        @param flat when "true" display a flat list structure instead
        of a tree (default)
      }

  available-formfields instproc class_name {cl} {
    return [expr {
                  [string match ::xowiki::formfield:* $cl]
                  ? [namespace tail $cl]
                  : [string trimleft $cl :]
                }]
  }

  available-formfields instproc render {} {
    :get_parameters

    foreach cl [lsort [::xowiki::formfield::FormField info subclass -closure]] {
      set result ""
      set superClassName [:class_name [$cl info superclass]]
      set className [:class_name $cl]
      set abstract [expr {[$cl exists abstract] && [$cl set abstract] ? "abstract, " : ""}]
      append result \
          "<b><a name='$className' title='$cl'>$className</a></b> " \
          "(${abstract}superclass <a href='#$superClassName'>$superClassName</a>)\n" \
          "<ul>\n"
      foreach p [lsort [$cl info parameter]] {
        if {[llength $p] == 2} {
          lassign $p name value
          append result "<li>-$name <em>[ns_quotehtml $value]</em></li>\n"
        } else {
          append result "<li>-$p</li>"
        }
      }
      append result "</ul>\n"
      set index [::xo::api object_index "" $cl]
      if {[nsv_exists api_library_doc $index]} {
        set doc_elements [nsv_get api_library_doc $index]
        append result <p>[lindex [dict get $doc_elements main] 0]</p>
      } else {
        append result <p>
      }
      set :html($className) $result
    }
    if {$flat} {
      #
      # Output as flat list
      #
      set result <ul>
      foreach className [lsort [array names :html]] {
        append result "<li>[set :html($className)]</li>\n"
      }
      append result "</ul>"
    } else {
      #
      # Output as tree
      #
      set result [:render_as_tree ::xowiki::formfield::FormField [::xowiki::formfield::FormField info subclass]]

    }
    return $result
  }

  available-formfields instproc render_as_tree {cl subclasses} {
    set subclassHTML ""
    set sort_names {}
    foreach subcl $subclasses {
      lappend sort_names $subcl [:class_name $subcl]
    }
    foreach {subcl sort_name} [lsort -index 1 -stride 2 $sort_names] {
      append subclassHTML <li>[:render_as_tree $subcl [$subcl info subclass]]</li>
    }
    if {[llength $subclasses] > 0} {
      set subclassHTML <ul>$subclassHTML</ul>
    }
    append result \
        [set :html([:class_name $cl])] \
        $subclassHTML \

  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # Page Fragment Cache
  #
  # The following mixin-class implements page fragment caching in the
  # xowiki-cache. Caching can be turned on for every
  # ::xowiki::IncludeletClass instance.
  #
  # Fragment caching depends in the class variables
  #   - cacheable    (the mixin is only registered, when cacheable is set to true)
  #   - aggregating  (requires flushing when items are added/edited/deleted)
  #   - localized    (dependency on locale)
  #   - personalized (dependency on userid)
  #
  Class create ::xowiki::includelet::page_fragment_cache  -instproc render {} {
    set c [:info class]
    #
    # Construct a key based on the class parameters and the
    # actual parameters
    #
    set key "PF-${:package_id}-"
    append key [expr {[$c aggregating] ? "agg" : "ind"}]
    append key "-$c ${:__caller_parameters}"
    if {[$c localized]}    {append key -[:locale]}
    if {[$c personalized]} {append key -[::xo::cc user_id]}
    #
    # Get the HTML from the rendered includelet by calling "next"
    #
    set HTML [::xowiki::cache eval -partition_key ${:package_id} $key next]
    #
    # Some side-effects might be necessary, even when the HTML output
    # of the includelet is cached (e.g. some associative arrays,
    # etc.).  For this purpose, we provide here a means to cache
    # additional some "includelet data", if the includelet provides
    # it.
    #
    if {[catch {set data [::xowiki::cache get -partition_key ${:package_id} $key-data]}]} {
      :cache_includelet_data $key-data
    } else {
      #:msg "eval $data"
      {*}$data
    }
    return $HTML
  } -instproc cache_includelet_data {key} {
    #:msg "data=[next]"
    set data [next]
    if {$data ne ""} {
      ::xowiki::cache set -partition_key ${:package_id} $key $data
    }
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # dotlrn style includelet decoration for includelets
  #
  Class create ::xowiki::includelet::decoration=portlet -instproc render {} {
    set name       ${:name}
    set title      ${:title}
    set package_id ${:package_id}
    set class      [namespace tail [:info class]]
    set id         [expr {[info exists :id] ? "id='[:id]'" : ""}]
    set html       [next]
    set localized_title [::xo::localize $title]
    set link [expr {[string match "*:*" $name] ?
                    "<a href='[ns_quotehtml [::$package_id pretty_link -parent_id [::$package_id folder_id] $name]]'>[ns_quotehtml $localized_title]</a>" :
                    $localized_title}]
    ::xo::render_localizer
    return [subst [[self class] set template]]
  } -set template [expr {[apm_version_names_compare [ad_acs_version] 5.3.0] == 1 ?
                         {<div class='$class'><div class='portlet-wrapper'><div class='portlet-header'>
                           <div class='portlet-title-no-controls'>$link</div></div>
                           <div $id class='portlet'>$html</div></div></div>
                         } : {<div class='$class'><div class='portlet-title'><span>$link</span></div>
                           <div $id class='portlet'>[next]</div></div>}
                       }]

  Class create ::xowiki::includelet::decoration=edit -instproc render {} {
    set name       ${:name}
    set title      ${:title}
    set package_id ${:package_id}
    set class      [namespace tail [:info class]]
    set id         [expr {[info exists :id] ? "id='[:id]'" : ""}]
    set html       [next]
    set localized_title [::xo::localize $title]
    set edit_button [:include [list edit-item-button -book_mode true]]
    set link [expr {[string match "*:*" $name] ?
                    "<a href='[ns_quotehtml [::$package_id pretty_link -parent_id [::$package_id folder_id] $name]]'>[ns_quotehtml $localized_title]</a>" :
                    $localized_title}]
    return [subst [[self class] set template]]
  } -set template {<div class='$class'><div class='portlet-wrapper'><div class='portlet-header'>
    <div><div style='float:right;'>$edit_button</div></div></div>
    <div $id class='portlet'>$html</div></div></div>
  }

  Class create ::xowiki::includelet::decoration=plain -instproc render {} {
    set class [namespace tail [:info class]]
    set id [expr {[info exists :id] ? "id='[:id]'" : ""}]
    return "<div $id class='$class'>[next]</div>"
  }

  Class create ::xowiki::includelet::decoration=rightbox -instproc render {} {
    set class [namespace tail [:info class]]
    set id [expr {[info exists :id] ? "id='[:id]'" : ""}]
    return "<div class='rightbox'><div $id class='$class'>[next]</div></div>"
  }
}

namespace eval ::xowiki::includelet {

  ::xowiki::IncludeletClass create get \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-variable}
          {-form_variable}
          {-source ""}
        }}
      } -ad_doc {

        Get an instance variable from the current or from a different
        page.

      } -instproc render {} {
        :get_parameters
        if {![info exists variable] && ![info exists form_variable]} {
          return "either -variable or -form_variable must be specified"
        }
        set page [:resolve_page_name $source]

        if {[info exists variable] && [$page exists $variable]} {
          return [$page set $variable]
        }
        if {[info exists form_variable] && [$page exists instance_attributes]} {
          set __ia [$page set instance_attributes]
          if {[dict exists $__ia $form_variable]} {
            return [dict get $__ia $form_variable]
          }
        }
        if {[info exists variable]} {
          return "no such variable $variable defined in page [$page set name]"
        }
        return "no such form_variable $form_variable defined in page [$page set name]"
      }

  ::xowiki::IncludeletClass create creation-date \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-source ""}
          {-format "%m-%d-%Y"}
        }}
      } -ad_doc {

        Include the creation date of the current
        or specified page in the provided format.

      } -instproc render {} {
        :get_parameters
        set page [:resolve_page_name $source]
        set time [$page set creation_date]
        regexp {^([^.]+)[.]} $time _ time
        return [lc_time_fmt [clock format [clock scan $time] -format "%Y-%m-%d %H:%M:%S"] $format [:locale]]
        #return [clock format [clock scan $time] -format $format]
      }

  #############################################################################
  # rss button
  #
  ::xowiki::IncludeletClass create rss-button \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-span "10d"}
          {-name_filter}
          {-entries_of}
          {-title}
        }}
      } -ad_doc {

        Include an RSS button referring to pages of the specified time span.

      }

  rss-button instproc render {} {
    :get_parameters
    set parent_ids [${:__including_page} parent_id]
    set href [export_vars -base [::$package_id package_url] {{rss $span} parent_ids name_filter title entries_of}]
    ::xo::Page requireLink -rel alternate -type application/rss+xml -title RSS -href $href
    return "<a href=\"[ns_quotehtml $href]\" class='rss'>RSS</a>"
  }

  #############################################################################
  # bookmarklet button
  #
  ::xowiki::IncludeletClass create bookmarklet-button \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-siteurl ""}
          {-label ""}
        }}
      } -ad_doc {

        Include bookmarklet button that makes it easy to add the
        current page as a bookmark in the browser of the client.

      }

  bookmarklet-button instproc render {} {
    :get_parameters
    set parent_id [${:__including_page} parent_id]
    set url [::$package_id pretty_link -absolute 1 -siteurl $siteurl -parent_id $parent_id news-item]
    if {$label eq ""} {set label "Add to [::$package_id instance_name]"}
    if {![info exists :id]} {set :id [::xowiki::Includelet html_id [self]]}

    template::add_event_listener \
        -id [:id] \
        -script [subst {
          d=document;w=window;t='';
          if(d.selection){t=d.selection.createRange().text;}
          else if(d.getSelection){t=d.getSelection();}
          else if(w.getSelection){t=w.getSelection();}
          void(open('$url?m=create-new&title='+escape(d.title)+
                    '&detail_link='+escape(d.location.href)+'&text='+escape(t),'_blank',
                    'scrollbars=yes,width=700,height=575,status=yes,resizable=yes,scrollbars=yes'));
        }]

    return "<a id='[:id]' href='#' title='[ns_quotehtml $label]' class='rss'>[ns_quotehtml $label]</a>"
  }

  #############################################################################
  # set-parameter "includelet"
  #
  ::xowiki::IncludeletClass create set-parameter \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}} \
      -ad_doc {

        Set a parameter accessible to the current page (for certain
        tailorings), accessible in the page via e.g. the query
        parameter interface.

      }

  set-parameter instproc render {} {
    :get_parameters
    set pl ${:__caller_parameters}
    if {[llength $pl] % 2 == 1} {
      error "no even number of parameters '$pl'"
    }
    foreach {att value} $pl {
      ::xo::cc set_parameter $att $value
    }
    return ""
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # valid parameters for the categories includelet are
  #     tree_name: match pattern, if specified displays only the trees
  #                with matching names
  #     no_tree_name: if specified, tree names are not displayed
  #     open_page: name (e.g. en:iMacs) of the page to be opened initially
  #     tree_style: boolean, default: true, display based on mktree

  ::xowiki::IncludeletClass create categories \
      -superclass ::xowiki::Includelet \
      -cacheable true -personalized false -aggregating true \
      -parameter {
        {title "#xowiki.categories#"}
        {parameter_declaration {
          {-tree_name ""}
          {-tree_style:boolean 1}
          {-no_tree_name:boolean 0}
          {-count:boolean 0}
          {-summary:boolean 0}
          {-locale ""}
          {-open_page ""}
          {-order_items_by "title,asc"}
          {-style "mktree"}
          {-category_ids ""}
          {-parent /}
          {-except_category_ids ""}
          {-allow_edit false}
          {-ordered_composite}
        }}
      } \
      -ad_doc {

        List the specified category tree.

        @param tree_name match pattern, if specified displays only the
        trees with matching names

        @param no_tree_name if specified, tree names are not displayed

        @param open_page name (e.g. en:iMacs) of the page to be opened
        initially

        @param tree_style boolean, default: true, render category tree
        in tree style and not in sections style

        @param parent page-ref, default: /, select entries from this directory

      }

  categories instproc initialize {} {
    :get_parameters
    if {!$tree_style} {
      set style sections
    }
    set :style $style
  }

  categories instproc include_head_entries {} {
    ::xowiki::Tree include_head_entries -renderer ${:style}
  }

  categories instproc category_tree_edit_button {
    -object_id:integer
    -locale
    {-allow_edit false}
    -tree_id:integer
  } {
    set allow_p [::xo::cc permission \
                     -object_id $object_id \
                     -privilege admin \
                     -party_id [::xo::cc set untrusted_user_id]]
    if {$allow_edit && $allow_p} {
      set package ::${:package_id}
      if {[info exists tree_id]} {
        #
        # If a tree_id is given, edit directly the category tree ...
        #
        set href "[$package package_url]?edit-category-tree&object_id=$object_id&tree_id=$tree_id"
        return [${:__including_page} include \
                    [list edit-item-button -link $href -title [_ xowiki.Edit_category] -target _blank]]
      } else {
        #
        # ... otherwise, manage categories (allow defining new category trees, map/unmap, etc.)
        #
        set href "[$package package_url]?manage-categories&object_id=$object_id"
        return [${:__including_page} include \
                    [list edit-item-button -link $href -title [_ xowiki.Manage_categories] -target _blank]]
      }
    }
    return ""
  }

  categories instproc category_tree_missing {{-name ""} -edit_html} {
    # todo i18n
    if {$name eq ""} {
      #set msg "No category tree found."
      # maybe it is better to stay quiet in case, no category name was provided
      set msg ""
    } else {
      set msg "No category tree with name '$name' found."
    }
    ::${:package_id} flush_page_fragment_cache -scope agg
    set html "<div class='errorMsg'>[ns_quotehtml $msg]</div>"
    if {$edit_html ne ""} {
      return "$html Manage Categories? $edit_html"
    }
    return $html
  }

  categories instproc render {} {
    :get_parameters

    set content ""
    set current_folder [:get_current_folder $parent]
    set folder_id [$current_folder item_id]

    set open_item_id [expr {$open_page ne "" ?
                            [::xo::db::CrClass lookup -name $open_page -parent_id $folder_id] : 0}]

    lassign [::xowiki::Includelet locale_clause -revisions r -items ci $package_id $locale] \
        locale locale_clause

    set trees [::xowiki::Category get_mapped_trees -object_id $package_id -locale $locale \
                   -names $tree_name \
                   -output {tree_id tree_name}]

    #:msg "[llength $trees] == 0 && tree_name '$tree_name'"
    if {[llength $trees] == 0 && $tree_name ne ""} {
      #
      # We have nothing left from mapped trees, maybe the tree_names
      # are not mapped; try to get these
      #
      foreach name $tree_name {
        #set tree_id [lindex [category_tree::get_id $tree_name $locale] 0]
        set tree_id [lindex [category_tree::get_id $tree_name] 0]
        if {$tree_id ne ""} {
          lappend trees [list $tree_id $name]
        }
      }
    }

    set edit_html [:category_tree_edit_button -object_id $package_id -allow_edit $allow_edit]
    if {[llength $trees] == 0} {
      return [:category_tree_missing -name $tree_name -edit_html $edit_html]
    }

    if {![info exists :id]} {
      set :id [::xowiki::Includelet html_id [self]]
    }

    foreach tree $trees {
      lassign $tree tree_id my_tree_name ...

      set edit_html [:category_tree_edit_button -object_id $package_id \
                         -allow_edit $allow_edit -tree_id $tree_id]
      #append content "<div style='float:right;'>$edit_html</div>\n"

      if {!$no_tree_name} {
        append content "<h3>[ns_quotehtml $my_tree_name] $edit_html</h3>"
      } elseif {$edit_html ne ""} {
        append content "$edit_html<br>"
      }
      set categories [list]
      set pos 0
      set cattree(0) [::xowiki::Tree new -volatile -orderby pos \
                          -id [:id]-$my_tree_name -name $my_tree_name]

      set category_infos [::xowiki::Category get_category_infos \
                              -locale $locale -tree_id $tree_id]
      foreach category_info $category_infos {
        lassign $category_info cid category_label deprecated_p level
        set c [::xowiki::TreeNode new -orderby pos  \
                   -level $level -label $category_label -pos [incr pos]]
        set cattree($level) $c
        set plevel [expr {$level -1}]
        $cattree($plevel) add $c
        set category($cid) $c
        lappend categories $cid
      }

      if {[llength $categories] == 0} {
        return $content
      }

      if {[info exists ordered_composite]} {
        set items [list]
        foreach c [$ordered_composite children] {
          lappend items [$c item_id]
        }

        # If we have no item, provide a dummy one to avoid sql error
        # later
        if {[llength $items]<1} {
          set items -4711
        }

        if {$count} {
          set sql "category_object_map c
              where c.object_id in ([ns_dbquotelist $items]) "
        } else {
          # TODO: the non-count-part for the ordered_composite is not
          # tested yet. Although "ordered composite" can be used
          # only programmatically for now, the code below should be
          # tested. It would be as well possible to obtain titles and
          # names etc. from the ordered composite, resulting in a
          # faster SQL like above.
          set sql "category_object_map c, cr_items ci, cr_revisions r
              where c.object_id in ([ns_dbquotelist $items])
              and c.object_id = ci.item_id
              and r.revision_id = ci.live_revision
              and ci.publish_status <> 'production'
           "
        }
      } else {
        set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
            where c.object_id = ci.item_id and ci.parent_id = :folder_id \
            and ci.content_type not in ('::xowiki::PageTemplate') \
            and c.category_id in ([ns_dbquotelist $categories]) \
            and r.revision_id = ci.live_revision \
            and p.page_id = r.revision_id \
            and ci.publish_status <> 'production'"
      }

      if {[llength $except_category_ids] > 0} {
        append sql \
            " and not exists (select * from category_object_map c2 \
            where ci.item_id = c2.object_id \
            and c2.category_id in ([ns_dbquotelist $except_category_ids]))"
      }
      #ns_log notice "--c category_ids=$category_ids"
      if {$category_ids ne ""} {
        foreach cid [split $category_ids ,] {
          set or_ids [split $cid |]
          foreach or_id $or_ids {
            if {![string is integer $or_id]} {
              ad_return_complaint 1 "invalid category_id"
              ad_script_abort
            }
          }
          append sql " and exists (select * from category_object_map \
         where object_id = ci.item_id and c.category_id in ([ns_dbquotelist $or_ids]))"
        }
      }
      append sql $locale_clause

      if {$count} {
        ::xo::dc foreach get_counts \
            "select count(*) as nr,category_id from $sql group by category_id" {
              $category($category_id) set count $nr
              set s [expr {$summary ? "&summary=$summary" : ""}]
              $category($category_id) href [ad_conn url]?category_id=$category_id$s
              $category($category_id) open_tree
            }
        append content [$cattree(0) render -style ${:style}]
      } else {
        lassign [split $order_items_by ,] orderby direction     ;# e.g. "title,asc"
        set increasing [expr {$direction ne "desc"}]
        set order_column ", p.page_order"

        ::xo::dc foreach get_pages \
            "select ci.item_id, ci.name, ci.parent_id, r.title, category_id $order_column from $sql" {
              if {$title eq ""} {set title $name}
              set itemobj [Object new]
              $itemobj mset [list \
                                 name $name title $title prefix "" suffix "" \
                                 page_order $page_order \
                                 href [::$package_id pretty_link -parent_id $parent_id $name] \
                                ]
              $cattree(0) add_item \
                  -category $category($category_id) \
                  -itemobj $itemobj \
                  -orderby $orderby \
                  -increasing $increasing \
                  -open_item [expr {$item_id == $open_item_id}]
            }
        append content [$cattree(0) render -style ${:style}]
      }
    }
    return $content
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # display recent entries by categories
  #
  # valid parameters from the include are
  #     tree_name: match pattern, if specified displays only the trees with matching names
  #     max_entries: show given number of new entries

  ::xowiki::IncludeletClass create categories-recent \
      -superclass ::xowiki::Includelet \
      -cacheable true -personalized false -aggregating true \
      -parameter {
        {title "#xowiki.recently_changed_pages_by_categories#"}
        {parameter_declaration {
          {-max_entries:integer 10}
          {-tree_name ""}
          {-locale ""}
          {-pretty_age "off"}
        }}
      } -ad_doc {

        Display recent entries by categories.

        @param tree_name match pattern, if specified displays only the
        trees with matching names

        @param max_entries show given number of new entries
        @param locale use the specified locale
        @param pretty_age boolean, use pretty age or not

      }

  categories-recent instproc initialize {} {
    set :style sections
    # When pretty age is activated, this includedlet is not suited for
    # caching (it could make sense e.g. when the age granularity is 1
    # minute or more). This measure here (turning off caching
    # completely) is a little bit too much, but it is safe.
    :get_parameters
    if {[[:info class] cacheable] && $pretty_age ne "off"} {
      [:info class] cacheable false
    }
  }

  categories-recent instproc include_head_entries {} {
    ::xowiki::Tree include_head_entries -renderer ${:style}
  }

  categories-recent instproc render {} {
    :get_parameters

    if {![info exists :id]} {set :id [::xowiki::Includelet html_id [self]]}
    set cattree [::xowiki::Tree new -volatile -id [:id]]

    lassign [::xowiki::Includelet locale_clause -revisions r -items ci $package_id $locale] \
        locale locale_clause

    set tree_ids [::xowiki::Category get_mapped_trees -object_id $package_id -locale $locale \
                      -names $tree_name -output tree_id]

    if {$tree_ids ne ""} {
      set tree_select_clause "and c.tree_id in ([ns_dbquotelist $tree_ids])"
    } else {
      set tree_select_clause ""
    }
    set sql [::xo::dc select \
                 -vars "c.category_id, ci.name, ci.parent_id, r.title, r.publish_date, \
                        to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as formatted_date" \
                 -from "category_object_map_tree c, cr_items ci, cr_revisions r, xowiki_page p" \
                 -where "c.object_id = ci.item_id and ci.parent_id = [ns_dbquotevalue [::$package_id folder_id]] \
     and r.revision_id = ci.live_revision \
     and p.page_id = r.revision_id $tree_select_clause $locale_clause \
         and ci.publish_status <> 'production'" \
                 -orderby "publish_date desc" \
                 -limit $max_entries]
    ::xo::dc foreach get_pages $sql {
      if {$title eq ""} {set title $name}
      set itemobj [Object new]
      set prefix ""
      set suffix ""
      switch -- $pretty_age {
        1 {set suffix " ([::xowiki::utility pretty_age -timestamp [clock scan $formatted_date] -locale [:locale]])"}
        2 {set suffix "([::xowiki::utility pretty_age -timestamp [clock scan $formatted_date] -locale [:locale] -levels 2])"}
        default {set prefix "$formatted_date "}
      }
      if {$prefix ne ""} {set prefix "<span class='date'>$prefix</span>";$itemobj set encoded(prefix) 1}
      if {$suffix ne ""} {set suffix "<span class='date'>$suffix</span>";$itemobj set encoded(suffix) 1}

      $itemobj mset [list \
                         name $name title $title prefix $prefix suffix $suffix \
                         href [::$package_id pretty_link -parent_id $parent_id $name] \
                        ]
            if {![info exists categories($category_id)]} {
        set categories($category_id) [::xowiki::TreeNode new \
                                          -label [category::get_name $category_id $locale] \
                                          -level 1]
        $cattree add  $categories($category_id)
      }
      $cattree add_item -category $categories($category_id) -itemobj $itemobj
    }
    return [$cattree render -style ${:style}]
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # display recent entries
  #

  ::xowiki::IncludeletClass create recent \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.recently_changed_pages#"}
        {parameter_declaration {
          {-max_entries:integer 10}
          {-allow_edit:boolean false}
          {-allow_delete:boolean false}
          {-pretty_age off}
        }}
      } -ad_doc {

        Display recent modified entries.

        @param max_entries show given number of new entries
        @param allow_edit boolean to optionally offer an edit button
        @param allow_delete boolean to optionally offer a delete button
        @param pretty_age boolean, use pretty age or not

      }

  recent instproc render {} {
    :get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"
    set admin_p [::xo::cc permission -object_id $package_id -privilege admin \
                     -party_id [::xo::cc set untrusted_user_id]]
    set show_heritage $admin_p

    TableWidget create t1 -volatile \
        -set allow_edit $allow_edit \
        -set allow_delete $allow_delete \
        -set show_heritage $admin_p \
        -columns {
          Field create date -label [_ xowiki.Page-last_modified]
          if {[[:info parent] set allow_edit]} {
            AnchorField create edit -CSSclass edit-item-button -label "" -richtext 1
          }
          if {[[:info parent] set show_heritage]} {
            AnchorField create inherited -label "" -CSSclass inherited
          }
          AnchorField create title -label [::xowiki::Page::slot::title set pretty_name]
          if {[[:info parent] set allow_delete]} {
            AnchorField create delete -CSSclass delete-item-button -label "" -richtext 1
          }
        }

    set listing [::xowiki::Includelet listing \
                     -package_id $package_id -page_number 1 -page_size $max_entries \
                     -orderby "publish_date desc"]

    foreach entry [$listing children] {
      $entry instvar parent_id formatted_date page_id {title entry_title} {name entry_name}
      set entry_package_id [$entry set package_id]

      set page_link [::$entry_package_id pretty_link -parent_id $parent_id $entry_name]
      switch -- $pretty_age {
        1 {set age [::xowiki::utility pretty_age -timestamp [clock scan $formatted_date] -locale [:locale]]}
        2 {set age [::xowiki::utility pretty_age -timestamp [clock scan $formatted_date] -locale [:locale] -levels 2]}
        default {set age $formatted_date}
      }

      t1 add \
          -title $entry_title \
          -title.href $page_link \
          -date $age

      if {$allow_edit} {
        set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
        set edit_link [::$entry_package_id make_link -link $page_link $p edit return_url]
        #:log "page_link=$page_link, edit=$edit_link"
        [t1 last_child] set edit.href $edit_link
        [t1 last_child] set edit "&nbsp;"
      }
      if {$allow_delete} {
        if {![info exists p]} {
          set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
        }
        set delete_link [::$entry_package_id make_link -link $page_link $p delete return_url]
        [t1 last_child] set delete.href $delete_link
        [t1 last_child] set delete "&nbsp;"
      }
      if {$show_heritage} {
        if {$entry_package_id == ${:package_id}} {
          set href ""
          set title ""
          set alt ""
          set class ""
          set label ""
        } else {
          # provide a link to the original
          set href $page_link
          set label [::$entry_package_id instance_name]
          set title [_ xowiki.view_in_context [list context $label]]
          set alt $title
          set class "inherited"
        }
        [t1 last_child] set inherited $label
        [t1 last_child] set inherited.href $href
        [t1 last_child] set inherited.title $title
        [t1 last_child] set inherited.CSSclass $class
      }
    }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # display last visited entries
  #

  ::xowiki::IncludeletClass create last-visited \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.last_visited_pages#"}
        {parameter_declaration {
          {-max_entries:integer 20}
        }}
      } -ad_doc {

        Display last visited pages.

        @param max_entries show given number of entries
      }


  last-visited instproc render {} {
    :get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget create t1 -volatile \
        -columns {
          AnchorField create title -label [::xowiki::Page::slot::title set pretty_name]
        }

    xo::dc foreach get_pages \
        [::xo::dc select \
             -vars "i.parent_id, r.title,i.name, x.time" \
             -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
             -where "x.page_id = i.item_id and i.live_revision = p.page_id  \
        and r.revision_id = p.page_id and x.user_id = [::xo::cc set untrusted_user_id] \
        and x.package_id = :package_id and i.publish_status <> 'production'" \
             -orderby "x.time desc" \
             -limit $max_entries] \
        {
          t1 add \
              -title $title \
              -title.href [::$package_id pretty_link -parent_id $parent_id $name]
        }
    return [t1 asHTML]
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # list the most popular pages
  #

  ::xowiki::IncludeletClass create most-popular \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.most_popular_pages#"}
        {parameter_declaration {
          {-max_entries:integer "10"}
          {-interval}
        }}
      } -ad_doc {

        Display most popular pages of this wiki instance.

        @param max_entries show given number of entries
        @param interval specified optionally the time interval since when pages are listed

      }


  most-popular instproc render {} {
    :get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    if {[info exists interval]} {
      #
      # If we have and interval, we cannot get report the number of visits
      # for that interval, since we have only the aggregated values in
      # the database.
      #
      append :title " in last $interval"

      TableWidget create t1 -volatile \
          -columns {
            AnchorField create title -label [::xowiki::Page::slot::title set pretty_name]
            Field create users -label [_ xowiki.includelet-visitors] -html { align right }
          }
      set since_condition [::xo::dc since_interval_condition time $interval]
      xo::dc foreach get_pages \
          [::xo::dc select \
               -vars "count(x.user_id) as nr_different_users, r.title, i.name, i.parent_id" \
               -from "xowiki_last_visited x, cr_items i, cr_revisions r"  \
               -where "x.package_id = :package_id and x.page_id = i.item_id and \
          i.publish_status <> 'production' and i.live_revision = r.revision_id \
                  and $since_condition" \
               -groupby "x.page_id, r.title, i.name, i.parent_id" \
               -orderby "nr_different_users desc" \
               -limit $max_entries ] {
                 t1 add \
                     -title $title \
                     -title.href [::$package_id pretty_link -parent_id $parent_id $name] \
                     -users $nr_different_users
               }
    } else {

      TableWidget create t1 -volatile \
          -columns {
            AnchorField create title -label [::xowiki::Page::slot::title set pretty_name]
            Field create count -label [_ xowiki.includelets-visits] -html { align right }
            Field create users -label [_ xowiki.includelet-visitors] -html { align right }
          }
      xo::dc foreach get_pages \
          [::xo::dc select \
               -vars "sum(x.count) as sum, count(x.user_id) as nr_different_users, r.title,i.name, i.parent_id" \
               -from "xowiki_last_visited x, cr_items i, cr_revisions r"  \
               -where "x.package_id = :package_id and x.page_id = i.item_id and \
               i.publish_status <> 'production' and i.live_revision = r.revision_id" \
               -groupby "x.page_id, r.title, i.name, i.parent_id" \
               -orderby "sum desc" \
               -limit $max_entries] {
                 t1 add \
                     -title $title \
                     -title.href [::$package_id pretty_link -parent_id $parent_id $name] \
                     -users $nr_different_users \
                     -count $sum
               }
    }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # include RSS content
  #

  ::xowiki::IncludeletClass create rss-client \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.rss_client#"}
        {parameter_declaration {
          {-url:required}
          {-max_entries:integer "15"}
        }}
      } -ad_doc {

        Include RSS content

        @param max_entries show given number of entries
        @param url source for the RSS feed

      }


  rss-client instproc initialize {} {
    :get_parameters
    set :feed [::xowiki::RSS-client new -url $url -destroy_on_cleanup]
    if {[info commands [${:feed} channel]] ne ""} {
      :title [ [${:feed} channel] title]
    }
  }

  rss-client instproc render {} {
    :get_parameters
    if {[info commands [${:feed} channel]] eq ""} {
      set detail ""
      if {[${:feed} exists errorMessage]} {set detail \n[${:feed} set errorMessage]}
      return "No data available from $url<br>[ns_quotehtml $detail]"
    } else {
      set channel [${:feed} channel]
      #set html "<H1>[ns_quotehtml [$channel title]]</H1>"
      set html "<ul>\n"
      set i 0
      foreach item [ ${:feed} items ] {
        append html "<li><b>[ns_quotehtml [$item title]]</b><br>\
           [ns_quotehtml [$item description]] <a href='[ns_quotehtml [$item link]]'>#xowiki.weblog-more#</a>\n"
        if {[incr i] >= $max_entries} break
      }
      append html "</ul>\n"
      return $html
    }
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # List the most frequent visitors.
  #

  ::xowiki::IncludeletClass create most-frequent-visitors \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.most_frequent_visitors#"}
        {parameter_declaration {
          {-max_entries:integer "15"}
        }}
      } -ad_doc {

         List the most frequent visitors.

        @param max_entries show given number of entries

      }

  most-frequent-visitors instproc render {} {
    :get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget create t1 -volatile \
        -columns {
          Field create user  -label [_ xowiki.includelet-visitors] -html { align right }
          Field create count -label [_ xowiki.includelets-visits] -html { align right }
        }
    ::xo::dc foreach most-frequent-visistors \
        [::xo::dc select \
             -vars "sum(count) as sum, user_id"  \
             -from "xowiki_last_visited"  \
             -where "package_id = :package_id"  \
             -groupby "user_id" \
             -orderby "sum desc" \
             -limit $max_entries] {
               t1 add \
                   -user [::xo::get_user_name $user_id] \
                   -count $sum
             }
    return [t1 asHTML]
  }

}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Display unread items
  #
  # Currently moderately useful
  #
  # TODO: display of unread *revisions* should be included optionally, one has to
  # consider what to do with auto-created stuff (put it into 'production' state?)
  #

  ::xowiki::IncludeletClass create unread-items \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.unread_items#"}
        {parameter_declaration {
          {-max_entries:integer 20}
        }}
      } -ad_doc {

        List unread items.

        @param max_entries show given number of entries

      }

  unread-items instproc render {} {
    :get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget create t1 -volatile \
        -columns {
          AnchorField create title -label [::xowiki::Page::slot::title set pretty_name]
        }
    set user_id [::xo::cc user_id]
    set or_clause "or i.item_id in (
    select x.page_id
    from xowiki_last_visited x, acs_objects o
    where x.time < o.last_modified
    and x.page_id = o.object_id
    and x.package_id = :package_id
        and x.user_id = :user_id
     )"

    set or_clause ""
    set folder_id [::$package_id folder_id]

    ::xo::dc foreach unread-items \
        [::xo::dc select \
             -vars "a.title, i.name, i.parent_id" \
             -from "xowiki_page p, cr_items i, acs_objects a "  \
             -where "(i.item_id not in (
            select x.page_id from xowiki_last_visited x
                        where x.user_id = [::xo::cc user_id] and x.package_id = :package_id
            ) $or_clause
                    )
                    and i.live_revision = p.page_id
                    and i.parent_id = :folder_id
                    and i.publish_status <> 'production'
                    and a.object_id = i.item_id" \
             -orderby "a.creation_date desc" \
             -limit $max_entries] \
        {
          t1 add \
              -title $title \
              -title.href [::$package_id pretty_link -parent_id $parent_id $name]
        }
    return [t1 asHTML]
  }
}




namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Show the tags
  #

  ::xowiki::IncludeletClass create tags \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "Tags"}
        {parameter_declaration {
          {-limit:integer 20}
          {-summary:boolean 0}
          {-popular:boolean 0}
          {-page}
        }}
      } -ad_doc {

        Display specified tags.

        @param limit maximum number of new entries
        @param summary boolean to optionally provide summary
        @param popular boolean to optionally list popular tags
        @param page provide alternate weblog listing page

      }

  tags instproc render {} {
    :get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    if {$popular} {
      set label [_ xowiki.popular_tags_label]
      set tag_type ptag
      set sql [::xo::dc select \
                   -vars "count(*) as nr,tag" \
                   -from xowiki_tags \
                   -where "package_id = :package_id" \
                   -groupby tag \
                   -orderby tag \
                   -limit $limit]
    } else {
      set label [_ xowiki.your_tags_label]
      set tag_type tag
      set user_id [::xo::cc user_id]
      set sql "select count(*) as nr,tag from xowiki_tags where \
        user_id = :user_id and package_id = :package_id group by tag order by tag"
    }
    set entries [list]

    if {![info exists page]} {
      set page [::$package_id get_parameter weblog_page]
    }

    set href [::$package_id package_url]tag/
    ::xo::dc foreach get_tag_counts $sql {
      set q [list]
      if {$summary} {lappend q "summary=[ad_urlencode_query $summary]"}
      if {$popular} {lappend q "popular=[ad_urlencode_query $popular]"}
      set link $href$tag?[join $q &]
      lappend entries "[ns_quotehtml $tag] <a rel='tag' href='[ns_quotehtml $link]'>([ns_quotehtml $nr])</a>"
      #lappend entries "[ns_quotehtml $tag] <a rel='tag' href='[ns_quotehtml $link]'><span class='badge' style='font-size:75%'>[ns_quotehtml $nr]</span></a>"
    }
    return [expr {[llength $entries]  > 0 ?
                  "<h3>[ns_quotehtml $label]</h3> <blockquote>[join $entries {, }]</blockquote>\n" :
                  ""}]
  }

  ::xowiki::IncludeletClass create my-tags \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-summary 1}
        }}
        id
      } \
      -ad_doc {
        List the tags associated with the
        current page.

        @param summary when specified, tag points to a summarized listing
      }

  my-tags instproc render {} {
    :get_parameters

    set p_link [${:__including_page} pretty_link]
    set return_url [::xo::cc url]?[::xo::cc actual_query]
    set weblog_page [::$package_id get_parameter weblog_page weblog]
    set save_tag_link [::$package_id make_link -link $p_link ${:__including_page} \
                           save-tags return_url]
    set popular_tags_link [::$package_id make_link -link $p_link ${:__including_page} \
                               popular-tags]

    set :tags [lsort [::xowiki::Page get_tags -user_id [::xo::cc user_id] \
                          -item_id [${:__including_page} item_id] -package_id $package_id]]
    set entries [list]

    foreach tag ${:tags} {
      set href [export_vars -base [::$package_id package_url]/tag/$tag {summary}]
      lappend entries "<a rel='tag' href='[ns_quotehtml $href]'>[ns_quotehtml $tag]</a>"
    }
    set tags_with_links [join [lsort $entries] {, }]

    if {![info exists :id]} {
      set :id [::xowiki::Includelet html_id [self]]
    }
    set content [subst {
      <span class='your-tags'>#xowiki.your_tags_label#: $tags_with_links</span>
      (<a id='${:id}-edit-tags-control' href='.'>#xowiki.edit_link#</a>,
       <a id='${:id}-popular-tags-control' href='.'>#xowiki.popular_tags_link#</a>)
      <form id='${:id}-edit_tags' style='display: none' action="[ns_quotehtml $save_tag_link]" method='POST'>
      <div><input name='new_tags' type='text' value="[ns_quotehtml ${:tags}]"></div>
      </form>
      <span id='${:id}-popular_tags' style='display: none'></span><br >
    }]

    template::add_event_listener \
        -id ${:id}-edit-tags-control \
        -script [subst {document.getElementById("${:id}-edit_tags").style.display="block";}]

    template::add_event_listener \
        -id ${:id}-popular-tags-control \
        -script [subst {get_popular_tags("[ns_quotehtml $popular_tags_link]","${:id}");}]

    return $content
  }


  ::xowiki::IncludeletClass create my-categories \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-summary 1}
        }}
      } \
      -ad_doc {
        List the categories associated with the
        current page.

        @param summary when specified, the category points to a summarized listing
      }

  my-categories instproc render {} {
    :get_parameters
    set content ""

    set weblog_page [::$package_id get_parameter weblog_page weblog]
    set entries [list]
    set href [export_vars -base [::$package_id package_url]$weblog_page {summary}]
    set notification_type ""
    if {[::$package_id get_parameter "with_notifications" 1] &&
        [::xo::cc user_id] != 0} { ;# notifications require login
      set notification_type [notification::type::get_type_id -short_name xowiki_notif]
    }
    if {[::$package_id exists_query_parameter return_url]} {
      set return_url [::$package_id query_parameter return_url:localurl]
    }
    foreach cat_id [category::get_mapped_categories [${:__including_page} set item_id]] {
      lassign [category::get_data $cat_id] category_id category_name tree_id tree_name
      #:log "--cat $cat_id $category_id $category_name $tree_id $tree_name"
      set label [ns_quotehtml "$category_name ($tree_name)"]
      set entry "<a href='[ns_quotehtml $href&category_id=$category_id]'>[ns_quotehtml $label]</a>"
      if {$notification_type ne ""} {
        set notification_text "Subscribe category $category_name in tree $tree_name"
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_image \
            "<img style='border: 0px;' src='/resources/xowiki/email.png' \
            alt='[ns_quotehtml $notification_text]' title='[ns_quotehtml $notification_text]'>"

        set cat_notif_link [export_vars -base /notifications/request-new \
                                {{return_url $notifications_return_url} \
                                     {pretty_name $notification_text} \
                                     {type_id $notification_type} \
                                     {object_id $category_id}}]
        append entry "<a href='[ns_quotehtml $cat_notif_link]'> " \
            "<img style='border: 0px;' src='/resources/xowiki/email.png' " \
            "alt='[ns_quotehtml $notification_text]' title='[ns_quotehtml $notification_text]'>" </a>

      }
      lappend entries $entry
    }
    if {[llength $entries]>0} {
      set content "#xowiki.categories#: [join $entries {, }]"
    }
    return $content
  }

  ::xowiki::IncludeletClass create my-general-comments \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}} \
      -ad_doc {
        List the general comments available for the
        current page.
      }

  my-general-comments instproc render {} {
    :get_parameters
    set item_id [${:__including_page} item_id]
    set gc_return_url [::$package_id url]
    #
    # Even, if general_comments is turned on, don't offer the
    # link to add comments, unless the user is logged in.
    # Otherwise, this attracts spammers and search bots
    #
    if {[::xo::cc user_id] != 0} {
      set gc_link [general_comments_create_link \
                       -object_name [${:__including_page} title] \
                       $item_id $gc_return_url]
      set gc_link <p>$gc_link</p>
    } else {
      set gc_link ""
    }
    set gc_comments [general_comments_get_comments $item_id $gc_return_url]
    if {$gc_comments ne ""} {
      return "<p>#general-comments.Comments#</p><ul>$gc_comments</ul>$gc_link"
    } else {
      return "$gc_link"
    }
  }

  ::xowiki::IncludeletClass create digg \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-description ""}
          {-url}
        }}
      } -ad_doc {
        Add a button to submit article to digg.
        @param description
        @param url
      }


  digg instproc render {} {
    :get_parameters
    set digg_link [export_vars -base "http://digg.com/submit" {
      {phase 2}
      {url       $url}
      {title     "[string range [${:__including_page} title] 0 74]"}
      {body_text "[string range $description 0 349]"}
    }]
    return "<a class='image-button' href='[ns_quotehtml $digg_link]'><img src='http://digg.com/img/badges/100x20-digg-button.png' width='100' height='20' alt='Digg!'></a>"
  }

  ::xowiki::IncludeletClass create delicious \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-description ""}
          {-tags ""}
          {-url}
        }}
      } -ad_doc {
        Add a button to submit article to delicious.
        @param description
        @param url
        @param tags
      }

  delicious instproc render {} {
    :get_parameters

    # The following snippet opens a window, where a user can edit the
    # posted info.  However, it seems not possible to add tags this
    # way automatically.  Alternatively, one could use the API as
    # described below; this supports tags, but no editing...
    # http://farm.tucows.com/blog/_archives/2005/3/24/462869.html#adding

    set delicious_link [export_vars -base "http://del.icio.us/post" {
      {v 4}
      {url   $url}
      {title "[string range [${:__including_page} title] 0 79]"}
      {notes "[string range $description 0 199]"}
      tags
    }]
    return "<a class='image-button' href='[ns_quotehtml $delicious_link]'><img src='http://i.i.com.com/cnwk.1d/i/ne05/fmwk/delicious_14x14.gif' width='14' height='14' alt='Add to your del.icio.us' />del.icio.us</a>"
  }


  ::xowiki::IncludeletClass create my-yahoo-publisher \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-publisher ""}
          {-rssurl}
        }}
      } \
      -ad_doc {
        Name of the publisher, when posting URLs to my yahoo (use in
        connection with with_yahoo_publisher).

        @param publisher
        @param rssurl
      }

  my-yahoo-publisher instproc render {} {
    :get_parameters

    set publisher [ad_urlencode $publisher]
    set feedname  [ad_urlencode [::$package_id get_parameter PackageTitle [::$package_id instance_name]]]
    set rssurl    [ad_urlencode $rssurl]
    set my_yahoo_link "http://us.rd.yahoo.com/my/atm/$publisher/$feedname/*http://add.my.yahoo.com/rss?url=$rssurl"

    return "<a class='image-button' href='[ns_quotehtml $my_yahoo_link]'><img src='http://us.i1.yimg.com/us.yimg.com/i/us/my/addtomyyahoo4.gif' width='91' height='17' align='middle' alt='Add to My Yahoo!'></a>"
  }


  #
  # my-references lists the pages which are referring to the
  # including page
  #
  ::xowiki::IncludeletClass create my-references \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}} \
      -ad_doc {
        List the pages which are referring to the
        current page.
      }

  my-references instproc render {} {
    :get_parameters

    set item_id [${:__including_page} item_id]
    set refs [list]
    # The same image might be linked both, as img or file on one page,
    # so we need DISTINCT.

    xo::dc foreach -prepare integer get_references {
      SELECT DISTINCT page,ci.name,ci.parent_id,o.package_id as pid
      from xowiki_references,cr_items ci,acs_objects o
      where reference = :item_id and ci.item_id = page and ci.item_id = o.object_id
    } {
      if {$pid eq ""} {
        #
        # In versions before oacs 5.2, the following query returns
        # empty.
        #
        set pid [::xo::dc get_value 5.2 {
          select package_id from cr_folders where folder_id = :parent_id
        }]
      }
      if {$pid ne ""} {
        ::xowiki::Package require $pid
        lappend refs "<a href='[ns_quotehtml [$pid pretty_link -parent_id $parent_id $name]]'>[ns_quotehtml $name]</a>"
      }
    }
    set references [join $refs ", "]

    array set lang {found "" undefined ""}
    foreach i [${:__including_page} array names lang_links] {
      set lang($i) [join [${:__including_page} set lang_links($i)] ", "]
    }

    append references " " $lang(found)
    set result ""
    if {$references ne " "} {
      append result "#xowiki.references_label# $references"
    }
    if {$lang(undefined) ne ""} {
      append result "#xowiki.create_this_page_in_language# $lang(undefined)"
    }
    return $result
  }

  #
  # my-refers lists the pages which are referred to by the
  # including page
  #
  ::xowiki::IncludeletClass create my-refers \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}} \
      -ad_doc {
        List the pages which are referred to the
        current page.
      }

  my-refers instproc render {} {
    :get_parameters

    set item_id [${:__including_page} item_id]
    set refs [list]

    ::xo::dc foreach get_refers "SELECT DISTINCT reference,ci.name,ci.parent_id,o.package_id as pid \
        from xowiki_references,cr_items ci,acs_objects o \
        where page = :item_id and ci.item_id = reference and ci.item_id = o.object_id" {
      if {$pid eq ""} {
        #
        # In versions begore oacs 5.2, the following query returns
        # empty.
        #
        set pid [::xo::dc get_value 5.2 {
          select package_id from cr_folders where folder_id = :parent_id
        }]
      }
      if {$pid ne ""} {
        ::xowiki::Package require $pid
        lappend refs "<a href='[ns_quotehtml [::$pid pretty_link -parent_id $parent_id $name]]'>[ns_quotehtml $name]</a>"
      }
    }

    set references [join $refs ", "]

    array set lang {found "" undefined ""}
    foreach i [${:__including_page} array names lang_links] {
      set lang($i) [join [${:__including_page} set lang_links($i)] ", "]
    }
    append references " " $lang(found)
    set result ""
    if {$references ne " "} {
      append result "#xowiki.references_of_label# $references"
    }
    if {$lang(undefined) ne ""} {
      append result "#xowiki.create_this_page_in_language# $lang(undefined)"
    }
    return $result
  }


  ::xowiki::IncludeletClass create unresolved-references \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}} \
      -ad_doc {

        List the pages with unresolved references in the current
        xowiki/xowf package. This is intended for use by admins.
      }

  unresolved-references instproc render {} {
    :get_parameters

    #
    # Get all unresolved references from this package
    #
    set unresolved_references [xo::dc list_of_lists _ {
      select page, name, o.package_id
      from xowiki_unresolved_references, acs_objects o
      where page = o.object_id
      and o.package_id = :package_id
      and link_type = 'link'
    }]

    set entries_with_unresolved_items {}
    foreach tuple $unresolved_references {
      lassign $tuple page name

      set pageObject [::xo::db::CrClass get_instance_from_db -item_id $page]

      #
      # Skip ::xowiki::Object instances.
      #
      if {[$page info class] eq "::xowiki::Object"} {
        continue
      }

      lappend entries_with_unresolved_items "<a href='[ns_quotehtml [$page pretty_link]]'>[ns_quotehtml [$page name]]</a> contains unresolved reference: $name"
    }
    if {[llength $entries_with_unresolved_items] > 0} {
      #
      # Return the pages with unresolved references in form of an
      # unordered list.
      #
      return <ul><li>[join [lsort -dictionary $entries_with_unresolved_items] </li><li>]</li></ul>
    } else {
      return "<ul><li>[_ acs-subsite.none]/li></ul>"
    }
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # presence
  #
  ::xowiki::IncludeletClass create presence \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration rightbox}
        {parameter_declaration {
          {-interval "10 minutes"}
          {-max_users:integer 40}
          {-show_anonymous "summary"}
          {-page}
        }}
      } -ad_doc {

        Show users actively in the wiki.

        @param interval list users when active in the wiki in the
        specified interval (default: 10 minutes)

        @param max_users maximum number of users to list

        @param show_anonymous specify, whether users not logged in
        should get a result from this includelet. Possible values
        "nothing", "all", "summary"

        @param page restrict listing to changes on a certain page.
      }

  # TODO make display style -decoration

  presence instproc render {} {
    :get_parameters

    set summary 0
    if {[::xo::cc user_id] == 0} {
      switch -- $show_anonymous {
        nothing {return ""}
        all     {set summary 0}
        default {set summary 1}
      }
    }

    if {[info exists page] && $page eq "this"} {
      set extra_where_clause "and page_id = [${:__including_page} item_id] "
      set what " on page [${:__including_page} title]"
    } else {
      set extra_where_clause ""
      set what " in community [::$package_id instance_name]"
    }

    if {!$summary} {
      set select_users "user_id, to_char(max(time),'YYYY-MM-DD HH24:MI:SS') as max_time from xowiki_last_visited "
    }

    # allow for caching prepared value.
    set since [::xo::dc interval $interval]
    set since_condition "time > TO_TIMESTAMP(:since,'YYYY-MM-DD HH24:MI:SS')"

    set where_clause "package_id=:package_id and $since_condition $extra_where_clause"
    set when "<br>in last [ns_quotehtml $interval]"

    set output ""

    if {$summary} {
      set count [::xo::dc get_value presence_count_users \
                     "select count(distinct user_id) from xowiki_last_visited WHERE $where_clause"]
    } else {
      set values [::xo::dc list_of_lists get_users \
                      [::xo::dc select \
                           -vars "user_id, to_char(max(time),'YYYY-MM-DD HH24:MI:SS') as max_time" \
                           -from xowiki_last_visited \
                           -where $where_clause \
                           -groupby user_id \
                           -orderby "max_time desc" \
                           -limit $max_users ]]
      set count [llength $values]
      if {$count == $max_users} {
        # we have to check, whether there were more users...
        set count [::xo::dc get_value presence_count_users \
                       "select count(distinct user_id) from xowiki_last_visited WHERE $where_clause"]
      }
      foreach value  $values {
        lassign $value user_id time
        set seen($user_id) $time

        regexp {^([^.]+)[.]} $time _ time
        set pretty_time [util::age_pretty -timestamp_ansi $time \
                             -sysdate_ansi [lc_clock_to_ansi [clock seconds]] \
                             -mode_3_fmt "%d %b %Y, at %X"]
        set name [::xo::get_user_name $user_id]

        append output [subst {<tr><td class='user'>[ns_quotehtml $name]</td>
          <td class='timestamp'>[ns_quotehtml $pretty_time]</td></tr>
        }]
      }
      if {$output ne ""} {set output "<table>$output</table>\n"}
    }
    set users [expr {$count == 0 ? "No registered users" :
                     $count == 1 ? "1 registered user" :
                     "$count registered users"}]
    return "<div class='title'>[ns_quotehtml $users$what]$when</div>$output"
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  # includelets based on order
  #
  Class create PageReorderSupport
  PageReorderSupport instproc page_reorder_check_allow {
    {-with_head_entries true}
    allow_reorder
  } {
    if {$allow_reorder ne ""} {
      set granted [::${:package_id} check_permissions \
                       -user_id [[::${:package_id} context] user_id] \
                       -package_id ${:package_id} \
                       ${:package_id} change-page-order]
      #:msg "granted=$granted"
      if {$granted} {
        if {$with_head_entries} {
          #set ajaxhelper 1
          #::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "utilities/utilities.js"
          #::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "selector/selector-min.js"
          #::xo::Page requireJS  "/resources/xowiki/yui-page-order-region.js"
          ::xo::Page requireJS "/resources/xowiki/listdnd.js"
        }
      } else {
        # the user has not enough permissions, so disallow
        set allow_reorder ""
      }
    }
    return $allow_reorder
  }

  PageReorderSupport instproc page_reorder_init_vars {-allow_reorder js_ last_level_ ID_ min_level_} {
    :upvar $js_ js $last_level_ last_level $ID_ ID $min_level_ min_level
    #set js "YAHOO.xo_page_order_region.DDApp.package_url = '[::${:package_id} package_url]';\n"
    set last_level 0
    set ID [:js_name]
    if {[string is integer -strict $allow_reorder]} {
      set min_level $allow_reorder
    } else {
      set min_level 1
    }
  }
  PageReorderSupport instproc page_reorder_open_ul {-min_level -ID -prefix_js l} {
    set l1 [expr {$l + 2}]
    set id ${ID}__l${l1}_${prefix_js}
    set css_class [expr {$l1 >= $min_level ? "page_order_region" : "page_order_region_no_target"}]
    return "<ul id='$id' class='$css_class'>\n"
  }
  PageReorderSupport instproc page_reorder_item_id {-ID -prefix_js -page_order js_} {
    :upvar $js_ js
    set key :__count($prefix_js)
    set p [incr $key]
    set id ${ID}_${prefix_js}_$p
    #append js "YAHOO.xo_page_order_region.DDApp.cd\['$id'\] = '$page_order';\n"
    return $id
  }

  #
  # toc -- Table of contents
  #
  # The "toc" includelet renders the page titles of the current files
  # based on the value of the "page_order" attributes. Only those
  # pages are rendered that have a nonempty "page_order" field.
  #
  ::xowiki::IncludeletClass create toc \
      -superclass ::xowiki::Includelet \
      -instmixin PageReorderSupport \
      -cacheable false -personalized false -aggregating true \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-style ""}
          {-renderer ""}
          {-open_page ""}
          {-book_mode false}
          {-folder_mode false}
          {-ajax false}
          {-expand_all false}
          {-remove_levels 0}
          {-category_id}
          {-locale ""}
          {-orderby ""}
          {-source ""}
          {-range ""}
          {-allow_reorder ""}
          {-include_in_foldertree "true"}
        }}
        id
      } -ad_doc {

        Show table of contents of the current wiki.
        The "toc" includelet renders the page titles of the current files
        based on the value of the "page_order" attributes. Only those
        pages are rendered that have a nonempty "page_order" field.

        @param style
        @param renderer
        @param open_page
        @param folder_mode
        @param ajax
        @param expand_all
        @param remove_levels
        @param category_id
        @param locale
        @param orderby by default, sorting is done via page_order
               (and requires pages with page_order). Alternatively, one can use e.g. "title,asc".
        @param source
        @param range
        @param allow_reorder
        @param include_in_foldertree

      }

  #"select page_id,  page_order, name, title, \
      #    (select count(*)-1 from xowiki_page_live_revision where page_order <@ p.page_order) as count \
      #    from xowiki_page_live_revision p where not page_order is NULL order by page_order asc"

  toc instproc count {} {return [set :navigation(count)]}
  toc instproc current {} {return [set :navigation(current)]}
  toc instproc position {} {return [set :navigation(position)]}
  toc instproc page_name {p} {return [set :page_name($p)]}
  toc instproc cache_includelet_data {key} {
    append data \
        [list :array set navigation [array get :navigation]] \n \
        [list :array set page_name [array get :page_name]] \n
    return $data
  }

  toc proc anchor {name} {
    # try to strip the language prefix from the name
    regexp {^.*:([^:]+)$} $name _ name
    # anchor is used between single quotes
    regsub -all ' $name {\'} anchor
    return $anchor
  }

  toc instproc build_toc {package_id locale source range} {
    :get_parameters
    array set :navigation {parent "" position 0 current ""}

    set extra_where_clause ""
    if {[info exists :category_id]} {
      lassign [:category_clause ${:category_id}] cnames extra_where_clause
    }
    lassign [::xowiki::Includelet locale_clause -revisions p -items p $package_id $locale] \
        locale locale_clause
    #:msg locale_clause=$locale_clause
    set order_direction asc
    set order_attribute page_order

    if {$source ne ""} {
      :get_page_order -source $source
      set page_order_clause "and name in ([ns_dbquotelist [array names :page_order]])"
      set page_order_att ""
    } elseif {$orderby ne ""} {
      lassign [split $orderby ,] order_attribute order_direction
      if {$order_attribute ni {page_order title}} {
        ns_log warning "toc includelet: ignore invalid page order '$orderby'"
        set order_attribute page_order
        set order_direction asc
        set page_order_att "page_order,"
        set page_order_clause "and not page_order is NULL"
      } else {
        set page_order_att "page_order,"
        set page_order_clause ""
        append extra_where_clause " and page_id != [${:__including_page} revision_id]"
      }
    } else {
      set page_order_clause "and not page_order is NULL"
      set page_order_att "page_order,"
    }

    if {$folder_mode} {
      # TODO just needed for Michael Aram?
      set parent_id [${:__including_page} item_id]
    } else {
      #set parent_id [::$package_id folder_id]
      set parent_id [${:__including_page} parent_id]
    }

    set sql [::xo::dc select \
                 -vars "page_id, $page_order_att name, title" \
                 -from "xowiki_page_live_revision p" \
                 -where "parent_id = :parent_id \
            $page_order_clause \
            $extra_where_clause $locale_clause"]
    set pages [::xowiki::Page instantiate_objects -sql $sql]

    $pages mixin add ::xo::OrderedComposite::IndexCompare
    if {$range ne "" && $page_order_att ne ""} {
      lassign [split $range -] from to
      foreach p [$pages children] {
        if {[$pages __value_compare [$p set page_order] $from 0] == -1
            || [$pages __value_compare [$p set page_order] $to 0] > 0} {
          $pages delete $p
        }
      }
    }

    $pages orderby \
        -order [expr {$order_direction in {asc ""} ? "increasing" : "decreasing"}] \
        $order_attribute

    if {$source ne ""} {
      # add the page_order to the objects
      foreach p [$pages children] {
        $p set page_order [set :page_order([$p set name])]
      }
    }

    return $pages
  }

  toc instproc href {book_mode name} {
    if {$book_mode} {
      set href [::${:package_id} url]#[toc anchor $name]
    } else {
      set href [::${:package_id} pretty_link -parent_id [${:__including_page} parent_id] $name]
    }
    return $href
  }

  toc instproc page_number {page_order remove_levels} {
    #:log "o: $page_order"
    set displayed_page_order $page_order
    for {set i 0} {$i < $remove_levels} {incr i} {
      regsub {^[^.]+[.]} $displayed_page_order "" displayed_page_order
    }
    return $displayed_page_order
  }

  toc instproc build_navigation {pages} {
    #
    # compute associative arrays open_node and navigation (position
    # and current)
    #
    :get_parameters
    array set :navigation {position 0 current ""}

    # the top node is always open
    set :open_node() true
    set node_cnt 0
    foreach o [$pages children] {
      $o instvar page_order name
      incr node_cnt
      set :page_name($node_cnt) $name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}
      #
      # If we are on the provided $open_page, we remember our position
      # for the progress bar.
      set on_current_node [expr {$open_page eq $name} ? "true" : "false"]
      if {$on_current_node} {
        set :navigation(position) $node_cnt
        set :navigation(current) $page_order
      }
      if {$expand_all} {
        set :open_node($page_order) true
      } elseif {$on_current_node} {
        set :open_node($page_order) true
        # make sure to open all nodes to the root
        for {set p $parent} {$p ne ""} {} {
          set :open_node($p) true
          if {![regexp {^(.*)[.]([^.]+)} $p _ p]} {set p ""}
        }
      }
    }
    set :navigation(count) $node_cnt
    #:log OPEN=[lsort [array names :open_node]]
  }

  #
  # ajax based code for fade-in / fade-out
  #
  toc instproc yui_ajax {} {
    return "var [:js_name] = {

         count: [set :navigation(count)],

         getPage: function(href, c) {
             //console.log('getPage: ' + href + ' type: ' + typeof href) ;

             if ( typeof c == 'undefined' ) {

                 // no c given, search it from the objects
                 // console.log('search for href <' + href + '>');

                 for (i in this.objs) {
                     if (this.objs\[i\].ref == href) {
                        c = this.objs\[i\].c;
                        // console.log('found href ' + href + ' c=' + c);
                        var node = this.tree.getNodeByIndex(c);
                        if (!node.expanded) {node.expand();}
                        node = node.parent;
                        while (node.index > 1) {
                            if (!node.expanded) {node.expand();}
                            node = node.parent;
                        }
                        break;
                     }
                 }
                 if (typeof c == 'undefined') {
                     // console.warn('c undefined');
                     return false;
                 }
             }
             //console.log('have href ' + href + ' c=' + c);

             var transaction = YAHOO.util.Connect.asyncRequest('GET', \
                 href + '?template_file=view-page&return_url=' + encodeURI(href),
                {
                  success:function(o) {
                     var bookpage = document.getElementById('book-page');
                  var fadeOutAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 0} }, 0.5 );

                     var doFadeIn = function(type, args) {
                        // console.log('fadein starts');
                        var bookpage = document.getElementById('book-page');
                        bookpage.innerHTML = o.responseText;
                        var fadeInAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 1} }, 0.1 );
                        fadeInAnim.animate();
                     }

                     // console.log(' tree: ' + this.tree + ' count: ' + this.count);
                     // console.info(this);

                     if (this.count > 0) {
                        var percent = (100 * o.argument.count / this.count).toFixed(2) + '%';
                     } else {
                        var percent = '0.00%';
                     }

                     if (o.argument.count > 1) {
                        var link = o.argument.href;
                        var src = '/resources/xowiki/previous.png';
                        var onclick = 'return [:js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/previous-end.png';
                     }

                     // console.log('changing prev href to ' + link);
                     // console.log('changing prev onclick to ' + onclick);

                     document.getElementById('bookNavPrev.img').src = src;
                     document.getElementById('bookNavPrev.a').href = link;
                     document.getElementById('bookNavPrev.a').setAttribute('onclick',onclick);

                     if (o.argument.count < this.count) {
                        var link = o.argument.href;
                        var src = '/resources/xowiki/next.png';
                        var onclick = 'return [:js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/next-end.png';
                     }

                     // console.log('changing next href to ' + link);
                     // console.log('changing next onclick to ' + onclick);
                     document.getElementById('bookNavNext.img').src = src;
                     document.getElementById('bookNavNext.a').href = link;

                     document.getElementById('bookNavNext.a').setAttribute('onclick',onclick);
                     document.getElementById('bookNavRelPosText').innerHTML = percent;
                     //document.getElementById('bookNavBar').setAttribute('style', 'width: ' + percent + ';');
                     document.getElementById('bookNavBar').style.width = percent;

                     fadeOutAnim.onComplete.subscribe(doFadeIn);
               fadeOutAnim.animate();
                  },
                  failure:function(o) {
                     // console.error(o);
                     // alert('failure ');
                     return false;
                  },
                  argument: {count: c, href: href},
                  scope: [:js_name]
                }, null);

                return false;
            },

         treeInit: function() {
            [:js_name].tree = new YAHOO.widget.TreeView('[:id]');
            [:js_name].tree.subscribe('clickEvent', function(oArgs) {
              var m = /href=\"(\[^\"\]+)\"/.exec(oArgs.node.html);
              [:js_name].getPage( m\[1\], oArgs.node.index);
            });
            [:js_name].tree.draw();
         }

      };

     YAHOO.util.Event.addListener(window, 'load', [:js_name].treeInit);
"
  }

  toc instproc yui_non_ajax {} {
    return "
      var [:js_name];
      YAHOO.util.Event.onDOMReady(function() {
         [:js_name] = new YAHOO.widget.TreeView('[:id]');
         [:js_name].subscribe('clickEvent',function(oArgs) {
            //console.info(oArgs);
            var m = /href=\"(\[^\"\]+)\"/.exec(oArgs.node.html);
            //console.info(m\[1\]);
            //window.location.href = m\[1\];
            return false;
    });
        [:js_name].render();
      });
     "
  }

  toc instproc render_yui_list {{-full false} pages} {
    :get_parameters

    #
    # Render the tree with the yui widget (with or without ajax)
    #
    if {$book_mode} {
      #:log "--warn: cannot use bookmode with ajax, resetting ajax"
      set ajax 0
    }
    set :ajax $ajax

    if {$ajax} {
      set :js [:yui_ajax]
    } else {
      set :js [:yui_non_ajax]
    }

    set tree [::xowiki::Tree new -destroy_on_cleanup -orderby pos -id [:id]]
    $tree array set open_node [array get :open_node]
    $tree add_pages -full $full -remove_levels $remove_levels \
        -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
        -owner [self] \
        $pages

    set HTML [$tree render -style yuitree -js ${:js}]
    return $HTML
  }


  toc instproc render_tree {{-full false} pages} {
    :get_parameters
    set tree [::xowiki::Tree new -destroy_on_cleanup \
                  -orderby pos \
                  -id [:id] \
                  -verbose 0 \
                  -owner [self]]
    $tree array set open_node [array get :open_node]
    $tree add_pages -full $full -remove_levels $remove_levels \
        -book_mode $book_mode -open_page $open_page \
        -owner [self] \
        $pages

    if {$allow_reorder ne ""} {
      set allow_reorder [:page_reorder_check_allow -with_head_entries false $allow_reorder]
    }

    if {$allow_reorder ne ""} {
      :page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
      #:log "=== call tree render [list $tree render -style listdnd] min_level=$min_level"
      set HTML [$tree render -style listdnd -context [list min_level $min_level]]
    } else {
      set HTML [$tree render -style list]
    }
    #:log "render_tree HTML  => $HTML"
    return $HTML
  }

  toc instproc render_list {{-full false} pages} {
    :get_parameters

    #
    # Build a reduced toc tree based on pure HTML (no JavaScript or
    # ajax involved).  If an open_page is specified, produce an as
    # small as possible tree and omit all non-visible nodes.
    #
    if {$open_page ne ""} {
      # TODO: can we allow open_page and reorder?
      set allow_reorder ""
    } else {
      set allow_reorder [:page_reorder_check_allow -with_head_entries false $allow_reorder]
    }
    set tree [::xowiki::Tree new -destroy_on_cleanup -orderby pos -id [:id]]
    $tree array set open_node [array get :open_node]
    $tree add_pages -full $full \
        -remove_levels $remove_levels \
        -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
        -owner [self] \
        $pages

    if {$allow_reorder ne ""} {
      :page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
      #set js "\nYAHOO.xo_page_order_region.DDApp.package_url = '[::$package_id package_url]';"
      set HTML [$tree render -style listdnd -context [list min_level $min_level]]
    } else {
      set HTML [$tree render -style list]
    }

    return $HTML
  }

  # TODO: maybe we could generalize this and similar convenience
  # methods on the includelet root class.
  toc instproc parent_id {} {
    ${:__including_page} parent_id
  }

  toc instproc include_head_entries {} {
    switch -- ${:renderer} {
      yuitree {
        ::xowiki::Tree include_head_entries -renderer yuitree -style ${:style}
      }
      list    {
        :get_parameters
        set tree_renderer [expr {$allow_reorder eq "" ? "list" : "listdnd"}]
        ::xowiki::Tree include_head_entries -renderer $tree_renderer -style ${:style}
      }
      none {}
    }
  }

  toc instproc initialize {} {
    :get_parameters
    array set :navigation {count 0 position 0 current ""}
    set list_mode 0

    #
    # If there is no renderer specified, determine the renderer from
    # the (provided) style. When the render is explicitly specified,
    # use it for rendering.
    #
    if {$renderer eq ""} {
      switch -- $style {
        "menu"    {set style "menu"; set renderer yuitree}
        "folders" {set style "folders"; set renderer yuitree}
        "list"    {set style ""; set list_mode 1; set renderer list}
        "none"    {set style ""; set renderer none}
        "default" {set style "yuitree"; set renderer yuitree}
      }
      set :use_tree_renderer 0
    } else {
      set :use_tree_renderer 1
    }

    set :include_in_foldertree $include_in_foldertree
    set :renderer $renderer
    set :style $style
    set :list_mode $list_mode
    set :book_mode $book_mode
  }

  toc instproc render {} {
    :get_parameters

    if {![info exists :id]} {
      set :id [::xowiki::Includelet html_id [self]]
    }
    if {[info exists category_id]} {
      set :category_id $category_id
    }

    #
    # Collect the pages which are either children of the page, or
    # children of the parent of the page depending on "folder_mode".
    #
    set pages [:build_toc $package_id $locale $source $range]

    #
    # Build the general navigation structure using associative arrays
    #
    :build_navigation $pages
    #
    # Call a render on the created structure
    #
    if {[nsf::is object ::__xowiki__MenuBar] && ${:include_in_foldertree}} {
      ::__xowiki__MenuBar additional_sub_menu -kind folder -pages $pages -owner [self]
    }
    #
    # TODO: We should call here the appropriate tree-renderer instead
    # of the toc-specific renderers, but first we have to check, if
    # these are fully feature-compatible.
    #
    #:log "=== toc render with <${:renderer}> treerenderer ${:use_tree_renderer} list_mode <${:list_mode}>"
    if {${:renderer} eq "none"} {
    } elseif {${:use_tree_renderer}} {
      return [:render_tree -full 1 $pages]
    } elseif {${:list_mode}} {
      return [:render_list $pages]
    } else {
      return [:render_yui_list -full true $pages]
    }
  }

  #############################################################################
  # Selection
  #
  # TODO: base book (and toc) on selection
  ::xowiki::IncludeletClass create selection \
      -superclass ::xowiki::Includelet \
      -instmixin PageReorderSupport \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-edit_links:boolean true}
          {-pages ""}
          {-ordered_pages ""}
          {-source}
          {-publish_status ready}
          {-menu_buttons edit}
          {-range ""}
        }}
      } -ad_doc {

        Provide a selection of pages

        @param edit_link provide an edit link, boolean.
        @param menu_buttons list of buttons for the entries
        @param ordered_pages set of already ordered pages
        @param pages pages of the selection
        @param publish_status list pages only with the provided publish status
        @param range (sub)range of the pages (based on page_order attribute)
        @param source take "pages" or "ordered_pages" from the provided page

      }

  selection instproc render {} {
    :get_parameters
    set :package_id $package_id
    set :edit_links $edit_links

    if {[info exists source]} {
      :get_page_order -source $source
    } else {
      :get_page_order -pages $pages -ordered_pages $ordered_pages
    }
    set publish_status_clause [expr {[info exists publish_status]
                                     ? [::xowiki::Includelet publish_status_clause \
                                            -base_table p \
                                            $publish_status]
                                     : ""}]

    set pages [::xowiki::Page instantiate_objects -sql \
                   "select page_id, name, title, item_id \
        from xowiki_page_live_revision p \
        where parent_id = [ns_dbquotevalue [::$package_id folder_id]] \
        and name in ([ns_dbquotelist [array names :page_order]]) \
        $publish_status_clause \
        [::xowiki::Page container_already_rendered item_id]" ]
    foreach p [$pages children] {
      $p set page_order $:page_order([$p set name])
    }

    $pages mixin add ::xo::OrderedComposite::IndexCompare
    if {$range ne ""} {
      lassign [split $range -] from to
      foreach p [$pages children] {
        if {[$pages __value_compare [$p set page_order] $from 0] == -1
            || [$pages __value_compare [$p set page_order] $to 0] > 0} {
          $pages delete $p
        }
      }
    }

    $pages orderby page_order
    return [:render_children $pages $menu_buttons]
  }

  selection instproc render_children {pages menu_buttons} {
    set output ""
    foreach o [$pages children] {
      $o instvar page_order title page_id name
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}]
      set edit_markup ""
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p references clear

      switch [$p info class] {
        ::xowiki::Form {
          set content [$p render]
        }
        default {
          set content [$p render -with_footer false]
          set content [string map [list "\{\{" "\\\{\{"] $content]
        }
      }

      set menu [list]
      foreach b $menu_buttons {
        if {[info commands ::xowiki::includelet::$b] eq ""} {
          set b $b-item-button
        }
        set html [$p include [list $b -book_mode true]]
        if {$html ne ""} {lappend menu $html}
      }
      set label "$page_order $title"
      append output "<h$level class='book'>" \
          "<div style='float: right'>" [join $menu "&nbsp;"] "</div>" \
          "<a name='[ns_quotehtml [toc anchor $name]]'></a>[ns_quotehtml $label]</h$level>" \
          $content
    }
    return $output
  }

  ::xowiki::IncludeletClass create composite-form \
      -superclass ::xowiki::includelet::selection \
      -parameter {
        {parameter_declaration {
          {-edit_links:boolean false}
          {-pages ""}
          {-ordered_pages}
        }}
      }  -ad_doc {

        Create a form from the selection

        @param edit_links provide an edit link, boolean.
        @param pages pages of the selection
        @param ordered_pages set of already ordered pages

      }

  composite-form instproc render {} {
    :get_parameters
    set inner_html [next]
    #:log "innerhtml=$inner_html"
    regsub -nocase -all "<form " $inner_html "<div class='form' " inner_html
    regsub -nocase -all "<form>" $inner_html "<div class='form'>" inner_html
    regsub -nocase -all "</form *>" $inner_html "</div>" inner_html
    dom parse -simple -html <form>$inner_html</form> doc
    $doc documentElement root

    set fields [$root selectNodes "//div\[@class = 'wiki-menu'\]"]
    foreach field $fields {$field delete}

    set inner_html [$root asHTML]
    set id ID[${:__including_page} item_id]
    set base [${:__including_page} pretty_link]
    #set id ID$item_id
    #$root setAttribute id $id
    set as_att_value [::xowiki::Includelet html_encode $inner_html]
    set save_form [subst {
      <p>
      <a id='$id-control' href='#'>Create Form from Content</a>
      </p>
      <span id='$id' style='display: none'>
      Form Name:
      <form action="$base?m=create-new" method='POST' style='display: inline'>
      <input name='class' type='hidden' value="::xowiki::Form">
      <input name='content' type='hidden' value="$as_att_value">
      <input name='name' type='text'>
      </form>
      </span>
    }]

    template::add_event_listener \
        -id $id-control \
        -script [subst {document.getElementById("$id").style.display="inline";}]

    return $inner_html$save_form
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # book style
  #
  ::xowiki::IncludeletClass create book \
      -superclass ::xowiki::Includelet \
      -instmixin PageReorderSupport \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-category_id}
          {-menu_buttons edit}
          {-folder_mode false}
          {-locale ""}
          {-range ""}
          {-allow_reorder ""}
          {-orderby "page_order,asc"}
          {-with_footer "false"}
          {-publish_status "ready"}
        }}
      } -ad_doc {

        Show contents in book mode.

        @param category_id
        @param menu_buttons default: edit
        @param folder_mode boolean, default false
        @param locale for the content
        @param range page range
        @param allow_reorder allow optional page_reorder based on drag and drop
        @param with_footer boolean, default: false
        @param orderby by default, sorting is done via page_order
               (and requires pages with page_order). Alternatively, one can use e.g. "title,asc"
      }


  book instproc render_item {
    -menu_buttons
    -content:required
    -object:required
    -level:required
  } {
    $object instvar page_order title name
    set menu [list]
    foreach b $menu_buttons {
      if {[info commands ::xowiki::includelet::$b] eq ""} {
        set b $b-item-button
      }
      set html [$object include [list $b -book_mode true]]
      if {$html ne ""} {lappend menu $html}
    }
    set menu [join $menu "&nbsp;"]
    if {$menu ne ""} {
      # <div> not allowed in h*: style='float: right; position: relative; top: -32px
      set menu "<span class='book-item-menu'>$menu</span>"
    }
    set label "$page_order $title"
    append output \
        "<h$level class='book'>" $menu \
        "<a name='[ns_quotehtml [toc anchor $name]]'></a>[ns_quotehtml $label]</h$level>" \
        $content
  }

  book instproc render_items {
    -pages:required
    {-cnames ""}
    {-allow_reorder ""}
    -menu_buttons
    {-with_footer "false"}
  } {
    set output ""
    if {$cnames ne ""} {
      append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }

    :page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
    set renderer default

    foreach o [$pages children] {
      $o instvar page_order page_id
      set level [expr {[regsub -all -- {[.]} $page_order _ page_order_js] + 1}]

      if {$allow_reorder ne ""} {
        #
        # Build a (nested) list structure mirroring the hierarchy
        # implied by the page_order. In essence, we provide CSS
        # classes for the ULs and provide IDs for ULs and LI elements,
        # and pass the associated page_order to javascript.
        #
        if {![regexp {^(.*)[.][^.]+$} $page_order _ prefix]} {set prefix ""}

        # First, insert the appropriate opening and closing of ULs. We
        # could handle here prefix changes as well as different lists
        # (e.g. 1.1 1.2 2.1)
        #
        if {$last_level != $level} {
          for {set l $last_level} {$l > $level} {incr l -1} {append output "</ul>\n" }
          for {set l $last_level} {$l < $level} {incr l} {
            regsub -all -- {[.]} $prefix _ prefix_js
            append output [:page_reorder_open_ul -min_level $min_level -ID $ID -prefix_js $prefix_js $l]
          }
          set last_level $level
          set last_prefix $prefix
        }
        # Pass the page_order for the element to JavaScript and add
        # the li element for the section.
        set item_id [:page_reorder_item_id -ID $ID -prefix_js $prefix_js -page_order $page_order js]
        append output "<li id='[ns_quotehtml $item_id]'>"
      }

      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]

      $p references clear
      #$p set render_adp 0
      switch [$p info class] {
        ::xowiki::Form {
          set content [$p render]
        }
        default {
          set content [$p render -with_footer false]
          #set content [string map [list "\{\{" "\\\{\{"] $content]
        }
      }

      append output [:render_item \
                         -menu_buttons $menu_buttons \
                         -content $content \
                         -object $p \
                         -level $level]
      if {$with_footer} {
        append output [$p htmlFooter -content $content]
      }
    }

    if {$allow_reorder ne ""} {
      for {set l $last_level} {$l > 0} {incr l -1} {append output "</ul>\n" }
      append output "<script type='text/javascript' nonce='[security::csp::nonce]'>$js</script>\n"
    }
    return $output
  }

  book instproc render_images {-addClass pages} {
    #
    # Return a list of the rendered images in HTML markup. The page
    # content is reduced to a bare image.  Note that this function
    # does not return "pages" not containing images.
    #
    set imageList {}
    foreach o [$pages children] {
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id [$o set page_id]]
      set html [$p render -with_footer false]
      if {[regsub -nocase {^(.*)(<img\s*[^>]+>)(.*)$} $html {\2} html] < 1} continue
      if {[info exists addClass]} {
        regsub -nocase {class\s*=\s*'([^']+)'} $html "class='\\1 $addClass'" html
      }
      lappend imageList $html
    }
    return $imageList
  }

  book instproc render {} {
    :get_parameters

    lappend ::xowiki_page_item_id_rendered [${:__including_page} item_id]
    ${:__including_page} set __is_book_page 1

    set allow_reorder [:page_reorder_check_allow $allow_reorder]

    lassign [split $orderby ,] order_attribute order_direction
    if {$order_attribute ni {page_order title}} {
      ns_log warning "book includelet: ignore invalid page order '$orderby'"
      set order_attribute page_order
      set order_direction asc
    }
    set page_order_clause [expr {$order_attribute eq "page_order"
                                 ? "and not page_order is NULL"
                                 : ""}]

    set extra_where_clause ""
    set cnames ""
    if {[info exists category_id]} {
      lassign [:category_clause $category_id] cnames extra_where_clause
    }

    lassign [::xowiki::Includelet locale_clause -revisions p -items p $package_id $locale] \
        locale locale_clause

    set publish_status_clause [expr {[info exists publish_status]
                                     ? [::xowiki::Includelet publish_status_clause \
                                            -base_table p \
                                            $publish_status]
                                     : ""}]
    if {$folder_mode} {
      # TODO just needed for Michael Aram?
      set parent_id [${:__including_page} item_id]
    } else {
      #set parent_id [::$package_id folder_id]
      set parent_id [${:__including_page} parent_id]
    }

    set sql "select page_id, page_order, name, title, item_id \
        from xowiki_page_live_revision p \
        where parent_id = [ns_dbquotevalue $parent_id]  \
        $page_order_clause $extra_where_clause \
        $locale_clause $publish_status_clause \
        [::xowiki::Page container_already_rendered item_id]"

    set pages [::xowiki::Page instantiate_objects -sql $sql]
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby \
        -order [expr {$order_direction in {asc ""} ? "increasing" : "decreasing"}] \
        $order_attribute

    #
    # filter range
    #
    if {$range ne ""} {
      lassign [split $range -] from to
      foreach p [$pages children] {
        if {[$pages __value_compare [$p set page_order] $from 0] == -1
            || [$pages __value_compare [$p set page_order] $to 0] > 0} {
          $pages delete $p
        }
      }
    }

    if {[llength [$pages children]] < 1} {
      #
      # Provide a hint why not pages were found
      #
      set p [::xo::db::CrClass get_instance_from_db -item_id $parent_id]
      set output "<p>No pages with parent object [$p name], page_order not NULL and an appropriate publish status found</p>\n"
    } else {
      set output [:render_items \
                      -menu_buttons $menu_buttons \
                      -with_footer $with_footer \
                      -pages $pages \
                      -cnames $cnames \
                      -allow_reorder $allow_reorder]
    }
    return $output
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # display a sequence of pages via W3C slidy
  #
  ::xowiki::IncludeletClass create slidy \
      -superclass ::xowiki::includelet::book \
      -ad_doc {
        Display a sequence of pages via W3C slidy, based on book includelet
      }

  slidy instproc render_items {
    -pages:required
    {-cnames ""}
    {-allow_reorder ""}
    -menu_buttons
    {-with_footer "false"}
  } {
    if {$cnames ne "" || $allow_reorder ne "" || $with_footer != "false"} {
      error "ignoring cnames, allow_reorder, and with_footer for the time being"
    }

    set output ""
    foreach o [$pages children] {
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id [$o set page_id]]
      append output "<div class='slide'>\n" [$p render -with_footer false] "\n</div>\n"
    }

    ns_return 200 text/html [subst {<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
      <head>
      <title>[${:__including_page} title]</title>
      <link rel="stylesheet" href="http://www.w3.org/Talks/Tools/Slidy2/styles/slidy.css" type="text/css" media="screen, projection" />
      <link rel="stylesheet" href="print.css" type="text/css"
      media="print" />
      <script src="http://www.w3.org/Talks/Tools/Slidy2/scripts/slidy.js" type="text/javascript"></script>
      </head>
      <body>
      $output
      </body>
    }]
    ad_script_abort
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # display a sequence of pages via jQuery Carousel
  #
  ::xowiki::IncludeletClass create jquery-carousel \
      -superclass ::xowiki::includelet::book \
      -ad_doc {
        Display a sequence of pages via jquery-carousel, based on book
        includelet.
      }


  jquery-carousel instproc render_items {
    -pages:required
    {-cnames ""}
    {-allow_reorder ""}
    -menu_buttons
    {-with_footer "false"}
  } {
    if {$cnames ne "" || $allow_reorder ne "" || $with_footer != "false"} {
      error "ignoring cnames, allow_reorder, and with_footer for the time being"
    }

    set id [:js_name]
    append output \
        "<div id='[ns_quotehtml $id]'><ul>\n" \
        <li>[join [:render_images $pages] "</li>\n<li>"]</li> \
        "</ul></div>\n"

    ::xo::Page requireJS urn:ad:js:jquery
    ::xo::Page requireJS "/resources/xowiki/jquery.carousel.min.js"
    ::xo::Page requireJS [subst -novariables {
      $(function(){
        $("#[set id]").carousel(  );
      });
    }]
    return $output
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # Display a sequence of images via the jQuery plugin
  #
  #    Infinite Carousel
  #
  # http://www.catchmyfame.com/2009/08/27/jquery-infinite-carousel-plugin-1-2-released/
  #
  # This includelet works only with images
  #
  # Install: obtain jQuery plugin
  #
  #    http://www.catchmyfame.com/jquery/jquery.infinitecarousel2.zip
  #
  # and install its files under packages/xowiki/resources/infiniteCarousel:
  #
  #    infiniteCarousel/images/caption.gif
  #    infiniteCarousel/images/leftright.gif
  #    infiniteCarousel/images/playpause.gif
  #    infiniteCarousel/jquery.infinitecarousel2.js
  #    infiniteCarousel/jquery.infinitecarousel2.min.js
  #
  ::xowiki::IncludeletClass create jquery-infinite-carousel \
      -superclass ::xowiki::includelet::book \
      -ad_doc {
        Display a sequence of pages via jquery-infinite-carousel, based on book
        includelet.
      }

  jquery-infinite-carousel instproc render_items {
    -pages:required
    {-cnames ""}
    {-allow_reorder ""}
    -menu_buttons
    {-with_footer "false"}
  } {
    if {$cnames ne "" || $allow_reorder ne "" || $with_footer != "false"} {
      error "ignoring cnames, allow_reorder, and with_footer for the time being"
    }

    set id [:js_name]
    append output \
        "<div id='[ns_quotehtml $id]'><ul>\n" \
        <li>[join [:render_images $pages] "</li>\n<li>"]</li> \
        "</ul></div>\n"

    ::xo::Page requireJS urn:ad:js:jquery
    ::xo::Page requireJS "/resources/xowiki/infiniteCarousel/jquery.infinitecarousel2.min.js"
    ::xo::Page requireJS [subst -novariables {
      $(function(){
        $("#[set id]").infiniteCarousel({
          displayTime: 6000,
          textholderHeight : .25,
          imagePath: '/resources/xowiki/infiniteCarousel/images/',
        });
      });}]

    return $output
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # Display a sequence of images via 3D Cloud Carousel
  #
  # This includelet works only with images.
  #
  # Install: get the jQuery plugins cloud-carousel and mousewheel from
  #
  #    http://www.professorcloud.com/mainsite/carousel.htm
  #    https://github.com/brandonaaron/jquery-mousewheel/downloads
  #
  # and install these files under
  #
  #    packages/xowiki/resources/cloud-carousel.1.0.5.min.js
  #    packages/xowiki/resources/jquery.mousewheel.min.js
  #
  # The following elements might be used in the page containing the includelet:
  #
  #     <!-- Define left and right buttons. -->
  #     <input id="left-but"  type="button" value="Left" />
  #     <input id="right-but" type="button" value="Right" />
  #     <p id="title-text"></p>
  #

  ::xowiki::IncludeletClass create jquery-cloud-carousel \
      -superclass ::xowiki::includelet::book \
      -ad_doc {
        Display a sequence of pages via jquery-cloud-carousel, based on book
        includelet.
      }

  jquery-cloud-carousel instproc render_items {
    -pages:required
    {-cnames ""}
    {-allow_reorder ""}
    -menu_buttons
    {-with_footer "false"}
  } {
    if {$cnames ne "" || $allow_reorder ne "" || $with_footer != "false"} {
      error "ignoring cnames, allow_reorder, and with_footer for the time being"
    }

    set id [:js_name]
    append output \
        "<div id='[ns_quotehtml $id]'>" \
        [join [:render_images -addClass cloudcarousel $pages] "\n"] \
        "</div>\n"

    ::xo::Page requireStyle "div.jquery-cloud-carousel div {width:650px; height:400px;background:#000;}"
    ::xo::Page requireJS urn:ad:js:jquery
    ::xo::Page requireJS "/resources/xowiki/jquery.mousewheel.min.js"
    ::xo::Page requireJS "/resources/xowiki/cloud-carousel.1.0.5.min.js"

    ::xo::Page requireJS [subst -novariables {
      $(function(){
        $("#[set id]").CloudCarousel(
                                     {
                                       xPos: 300,
                                       yPos: 32,
                                       buttonLeft: $("#left-but"),
                                       buttonRight: $("#right-but"),
                                       altBox: $("#alt-text"),
                                       titleBox: $("#title-text"),
                                       bringToFront: true,
                                       mouseWheel:true
                                     }
                                     );
      });
    }]
    return $output
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # Display a sequence of images via jQuery spacegallery
  #
  # This includelet works only with images
  #
  # Install: get the jQuery plugin spacegallery from
  #    http://www.eyecon.ro/spacegallery/
  # and install its files under packages/xowiki/resources/spacegallery:
  #
  #    spacegallery/css/custom.css
  #    spacegallery/css/layout.css
  #    spacegallery/css/spacegallery.css
  #    spacegallery/images/ajax_small.gif
  #    spacegallery/images/blank.gif
  #    spacegallery/images/bw1.jpg
  #    spacegallery/images/bw2.jpg
  #    spacegallery/images/bw3.jpg
  #    spacegallery/images/lights1.jpg
  #    spacegallery/images/lights2.jpg
  #    spacegallery/images/lights3.jpg
  #    spacegallery/index.html
  #    spacegallery/js/eye.js
  #    spacegallery/js/jquery.js
  #    spacegallery/js/layout.js
  #    spacegallery/js/spacegallery.js
  #    spacegallery/js/utils.js
  #    spacegallery/spacegallery.css
  #
  # You might want to adapt spacegallery/spacegallery.css according to
  # your needs.

  ::xowiki::IncludeletClass create jquery-spacegallery \
      -superclass ::xowiki::includelet::book \
      -ad_doc {
        Display a sequence of pages via jquery-spacegalleryl, based on book
        includelet.
      }

  jquery-spacegallery instproc render_items {
    -pages:required
    {-cnames ""}
    {-allow_reorder ""}
    -menu_buttons
    {-with_footer "false"}
  } {
    if {$cnames ne "" || $allow_reorder ne "" || $with_footer != "false"} {
      error "ignoring cnames, allow_reorder, and with_footer for the time being"
    }

    set id [:js_name]
    append output \
        "<div id='[ns_quotehtml $id]' class='spacegallery'>\n" \
        [join [:render_images $pages] "\n"] \
        "</div>\n"

    ::xo::Page requireStyle "div.spacegallery {width:600px; height:450px;}"
    ::xo::Page requireCSS "/resources/xowiki/spacegallery/spacegallery.css"
    ::xo::Page requireJS urn:ad:js:jquery
    ::xo::Page requireJS "/resources/xowiki/spacegallery/js/eye.js"
    ::xo::Page requireJS "/resources/xowiki/spacegallery/js/utils.js"
    ::xo::Page requireJS "/resources/xowiki/spacegallery/js/spacegallery.js"
    ::xo::Page requireJS [subst -novariables {
      $(function(){
        $("#[set id]").spacegallery({loadingClass: 'loading'});
      });
    }]
    return $output
  }
}


#############################################################################
# item-button
#
namespace eval ::xowiki::includelet {
  ::xowiki::IncludeletClass create item-button \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {return_url ""}
      }

  item-button instproc initialize {} {
    if {[:return_url] eq "" } {
      :return_url [::${:package_id} url]
    }
  }
  item-button instproc get_page {varname} {
    :upvar $varname page_id
    if {[info exists page_id]} {
      set page [::xo::db::CrClass get_instance_from_db -item_id $page_id]
    } else {
      set page ${:__including_page}
    }
  }

  item-button instproc render_button {
    -page
    -package_id
    -method
    -link
    -alt
    -title
    -return_url
    -page_order
    -object_type
    -source_item_id
    {-target ""}
  } {
    set html ""
    if {![info exists return_url] || $return_url eq ""} {set return_url [::$package_id url]}
    if {![info exists alt]} {set alt $method}
    if {![info exists link] || $link eq ""} {
      if {[$page istype ::xowiki::Package]} {
        set link  [::$package_id make_link $package_id edit-new object_type \
                       return_url page_order source_item_id]
      } else {
        set p_link [$page pretty_link]
        set link [::$package_id make_link -link $p_link $page $method \
                      return_url page_order source_item_id]
      }
    }
    if {$link ne ""} {
      set button_class [namespace tail [:info class]]
      set props ""
      if {$alt ne ""} {append props "alt=\"[ns_quotehtml $alt]\" "}
      if {$title ne ""} {append props "title=\"[ns_quotehtml $title]\" "}
      if {$target ne ""} {append props "target=\"[ns_quotehtml $target]\" "}
      set html "<a class='$button_class' href=\"[ns_quotehtml $link]\" $props>&nbsp;</a>"
    }
    return $html
  }

  ::xowiki::IncludeletClass create edit-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.edit#"}
          {-alt "edit"}
          {-book_mode false}
          {-link ""}
          {-target ""}
        }}
      } -ad_doc {
        Button to edit the current or a different page

        @param page_id optional item_id of the referred page
      }

  edit-item-button instproc render {} {
    :get_parameters
    set page [:get_page page_id]
    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      #set title "$title [$template title] [$page name]"
    }

    if {$book_mode} {
      append :return_url #[toc anchor [$page name]]
    }
    return [:render_button \
                -page $page -method edit -package_id $package_id -link $link \
                -title $title -alt $alt -return_url ${:return_url} -target $target]
  }

  ::xowiki::IncludeletClass create delete-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.delete#"}
          {-alt "delete"}
          {-book_mode false}
        }}
      } -ad_doc {
        Button to delete the current or a different page

        @param page_id optional item_id of the referred page
      }

  delete-item-button instproc render {} {
    :get_parameters
    set page [:get_page page_id]
    return [:render_button \
                -page $page -method delete -package_id $package_id \
                -title $title -alt $alt \
                -return_url ${:return_url}]
  }

  ::xowiki::IncludeletClass create view-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.view#"}
          {-alt "view"}
          {-link ""}
          {-book_mode false}
        }}
      } -ad_doc {
        Button to view the current or a different page

        @param page_id optional item_id of the referred page
      }

  view-item-button instproc render {} {
    :get_parameters
    set page [:get_page page_id]
    return [:render_button \
                -page $page -method view -package_id $package_id \
                -link $link -title $title -alt $alt \
                -return_url ${:return_url}]
  }


  ::xowiki::IncludeletClass create create-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-page_id}
          {-alt "new"}
          {-book_mode false}
        }}
      } -ad_doc {
        Button to create a new page based on the current one

        @param page_id optional item_id of the referred page
      }

  create-item-button instproc render {} {
    :get_parameters
    set page [:get_page page_id]
    set page_order [::xowiki::utility incr_page_order [$page page_order]]
    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      return [:render_button \
                  -page $template -method create-new -package_id $package_id \
                  -title [_ xowiki.create_new_entry_of_type [list type [$template title]]] \
                  -alt $alt -page_order $page_order \
                  -return_url ${:return_url}]
    } else {
      set object_type [${:__including_page} info class]
      return [:render_button \
                  -page $package_id -method edit_new -package_id $package_id \
                  -title [_ xowiki.create_new_entry_of_type [list type $object_type]] \
                  -alt $alt -page_order $page_order \
                  -return_url ${:return_url} \
                  -object_type $object_type]
    }
  }

  ::xowiki::IncludeletClass create copy-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-page_id}
          {-alt "copy"}
          {-book_mode false}
        }}
      } -ad_doc {
        Button to copy a page

        @param page_id optional item_id of the referred page
      }

  copy-item-button instproc render {} {
    :get_parameters
    set page [:get_page page_id]

    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      return [:render_button \
                  -page $template -method create-new -package_id $package_id \
                  -title [_ xowiki.copy_entry [list type [$template title]]] \
                  -alt $alt -source_item_id [$page item_id] \
                  -return_url ${:return_url}]
    } else {
      set object_type [${:__including_page} info class]
      return [:render_button \
                  -page $package_id -method edit_new -package_id $package_id \
                  -title [_ xowiki.copy_entry [list type $object_type]] \
                  -alt $alt -source_item_id [$page item_id] \
                  -return_url ${:return_url} \
                  -object_type $object_type]
    }
  }
}


namespace eval ::xowiki::includelet {

  ::xowiki::IncludeletClass create graph \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration plain}}

  graph instproc graphHTML {-edges -nodes -max_edges -cutoff -base {-attrib node_id}} {

    ::xo::Page requireJS "/resources/ajaxhelper/prototype/prototype.js"
    set user_agent [string tolower [ns_set iget [ns_conn headers] User-Agent]]
    if {[string match "*msie *" $user_agent]} {
      # canvas support for MSIE
      ::xo::Page requireJS "/resources/xowiki/excanvas.js"
    }
    ::xo::Page requireJS "/resources/xowiki/collab-graph.js"
    ::xo::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xo::Page requireJS "/resources/ajaxhelper/yui/event/event.js"

    set nodesHTML ""
    array set n $nodes

    foreach {node label} $nodes {
      set link "<a href='[ns_quotehtml $base?$attrib=$node]'>[ns_quotehtml $label]</a>"
      append nodesHTML "<div id='[ns_quotehtml $node]' style='position:relative;'>&nbsp;&nbsp;&nbsp;&nbsp;$link</div>\n"
    }

    set edgesHTML ""; set c 0
    foreach p [lsort -index 1 -decreasing -integer $edges] {
      lassign $p edge weight width
      lassign [split $edge ,] a b
      #:log "--G $a -> $b check $c > $max_edges, $weight < $cutoff"
      if {[incr c] > $max_edges} break
      if {$weight < $cutoff} continue
      append edgesHTML "g.addEdge(\$('$a'), \$('$b'), $weight, 0, $width);\n"
    }
    # [lsort -index 1 -decreasing -integer $edges]<br>[set cutoff] - [set c]<br>

    return [subst -novariables {
      <div>
      <canvas id="collab" width="500" height="500" style="border: 0px solid black">
      </canvas>
      [set nodesHTML]
      <script type="text/javascript" nonce='[security::csp::nonce]'>
      function draw() {
        if (typeof(G_vmlCanvasManager) == "object") {
          G_vmlCanvasManager.init_(window.document);
        }

        var g = new Graph();
        [set edgesHTML]
        var layouter = new Graph.Layout.Spring(g);
        layouter.layout();

        // IE does not pick up the canvas width or height
        $('collab').width=500;
        $('collab').height=500;

        var renderer = new Graph.Renderer.Basic($('collab'), g);
        renderer.radius = 5;
        renderer.draw();
      }
      YAHOO.util.Event.addListener(window, 'load', draw);
      //   YAHOO.util.Event.onContentReady('collab', draw);
      </script>
      </div>
    }]
  }
}

namespace eval ::xowiki::includelet {
  ::xowiki::IncludeletClass create collab-graph \
      -superclass ::xowiki::includelet::graph \
      -parameter {
        {parameter_declaration {
          {-max_edges 70}
          {-cutoff 0.1}
          {-show_anonymous "message"}
          -user_id
        }}
      } -ad_doc {
        Include a collaboration graph
      }

  collab-graph instproc render {} {
    :get_parameters

    if {$show_anonymous ne "all" && [::xo::cc user_id] eq "0"} {
      return "You must login to see the [namespace tail [self class]]"
    }
    if {![info exists user_id]} {set user_id [::xo::cc user_id]}

    set folder_id [::$package_id folder_id]
    ::xo::dc foreach get_collaborators {
      select count(revision_id), item_id, creation_user
      from cr_revisions r, acs_objects o
      where item_id in
      (select distinct i.item_id from
       acs_objects o, acs_objects o2, cr_revisions cr, cr_items i
       where o.object_id = i.item_id and o2.object_id = cr.revision_id
       and o2.creation_user = :user_id and i.item_id = cr.item_id
       and i.parent_id = :folder_id order by item_id
       )
      and o.object_id = revision_id
      and creation_user is not null
      group by item_id, creation_user} {

      lappend i($item_id) $creation_user $count
      set count_var user_count($creation_user)
      if {![info exists $count_var]} {set $count_var 0}
      incr $count_var $count
      set user($creation_user) "[::xo::get_user_name $creation_user] ([set $count_var])"
      if {![info exists activities($creation_user)]} {set activities($creation_user) 0}
      incr activities($creation_user) $count
    }

    set result "<p>Collaboration Graph for <b>[::xo::get_user_name $user_id]</b> in this wiki"
    if {[array size i] < 1} {
      append result "</p><p>No collaborations found</p>"
    } else {

      foreach x [array names i] {
        foreach {u1 c1} $i($x) {
          foreach {u2 c2} $i($x) {
            if {$u1 < $u2} {
              set var collab($u1,$u2)
              if {![info exists $var]} {set $var 0}
              incr $var $c1
              incr $var $c2
            }
          }
        }
      }

      set max 50
      foreach x [array names collab] {
        if {$collab($x) > $max} {set max $collab($x)}
      }

      set edges [list]
      foreach x [array names collab] {
        lappend edges [list $x $collab($x) [expr {$collab($x)*5.0/$max}]]
      }

      append result "($activities($user_id) contributions)</p>\n"
      append result [:graphHTML \
                         -nodes [array get user] -edges $edges \
                         -max_edges $max_edges -cutoff $cutoff \
                         -base collab -attrib user_id]
    }

    return $result
  }


  ::xowiki::IncludeletClass create activity-graph \
      -superclass ::xowiki::includelet::graph \
      -parameter {
        {parameter_declaration {
          {-max_edges 70}
          {-cutoff 0.1}
          {-max_activities:integer 100}
          {-show_anonymous "message"}
        }}
      } -ad_doc {
        Include an activity graph
      }


  activity-graph instproc render {} {
    :get_parameters

    if {$show_anonymous ne "all" && [::xo::cc user_id] eq "0"} {
      return "You must login to see the [namespace tail [self class]]"
    }

    set tmp_table_name XOWIKI_TMP_ACTIVITY
    #:msg "tmp exists [::xo::db::require exists_table $tmp_table_name]"
    set tt [::xo::db::temp_table new \
                -name $tmp_table_name \
                -query [::xo::dc select \
                            -vars "i.item_id, revision_id, creation_user" \
                            -from "cr_revisions cr, cr_items i, acs_objects o" \
                            -where "cr.item_id = i.item_id \
                            and i.parent_id = [ns_dbquotevalue [::$package_id folder_id]] \
                            and o.object_id = revision_id" \
                            -orderby "revision_id desc" \
                            -limit $max_activities] \
                -vars "item_id, revision_id, creation_user"]

    set total 0
    ::xo::dc foreach get_activities "
      select count(revision_id) as count, item_id, creation_user
      from $tmp_table_name
      where creation_user is not null
      group by item_id, creation_user
   " {
      lappend i($item_id) $creation_user $count
      incr total $count
      set count_var user_count($creation_user)
      if {![info exists $count_var]} {set $count_var 0}
      incr $count_var $count
      set user($creation_user) "[::xo::get_user_name $creation_user] ([set $count_var])"
    }
    $tt destroy

    if {[array size i] == 0} {
      append result "<p>No activities found</p>"
    } elseif {[array size user] == 1} {
      set user_id [lindex [array names user] 0]
      append result "<p>Last $total activities were done by user " \
          "<a href='[ns_quotehtml collab?$user_id]'>[ns_quotehtml [::xo::get_user_name $user_id]]</a>."
    } else {
      append result "<p>Collaborations in last $total activities by [array size user] Users in this wiki</p>"

      foreach x [array names i] {
        foreach {u1 c1} $i($x) {
          foreach {u2 c2} $i($x) {
            if {$u1 < $u2} {
              set var collab($u1,$u2)
              if {![info exists $var]} {set $var 0}
              incr $var $c1
              incr $var $c2
            }
          }
        }
      }

      set max 0
      foreach x [array names collab] {
        if {$collab($x) > $max} {set max $collab($x)}
      }

      set edges [list]
      foreach x [array names collab] {
        lappend edges [list $x $collab($x) [expr {$collab($x)*5.0/$max}]]
      }

      append result [:graphHTML \
                         -nodes [array get user] -edges $edges \
                         -max_edges $max_edges -cutoff $cutoff \
                         -base collab -attrib user_id]
    }

    return $result
  }

  ::xowiki::IncludeletClass create timeline \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
          -user_id
          {-data timeline-data}
          {-interval1 DAY}
          {-interval2 MONTH}
        }}
      } -ad_doc {
        Include a timeline of changes (based on yahoo timeline API)
      }


  timeline instproc render {} {
    :get_parameters

    ::xo::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xo::Page requireJS "/resources/ajaxhelper/yui/event/event.js"
    ::xo::Page requireJS "/resources/xowiki/timeline/api/timeline-api.js"

    set stamp [clock format [clock seconds] -format "%b %d %Y %X %Z" -gmt true]
    if {[info exists user_id]} {append data "?user_id=$user_id"}

    set nonce [security::csp::nonce]

    return [subst -nocommands -nobackslashes {
      <div id="my-timeline" style="font-size:70%; height: 350px; border: 1px solid #aaa"></div>
      <script type="text/javascript" nonce='$nonce'>
      var tl;
      function onLoad() {
        var eventSource = new Timeline.DefaultEventSource();
        var bandInfos = [
                         Timeline.createBandInfo({
                           eventSource:    eventSource,
                           date:           "$stamp",
                           width:          "70%",
                           intervalUnit:   Timeline.DateTime.$interval1,
                           intervalPixels: 100
                         }),
                         Timeline.createBandInfo({
                           eventSource:    eventSource,
                           date:           "$stamp",
                           width:          "30%",
                           intervalUnit:   Timeline.DateTime.$interval2,
                           intervalPixels: 200
                         })
                        ];
        //console.info(bandInfos);
        bandInfos[1].syncWith = 0;
        bandInfos[1].highlight = true;

        tl = Timeline.create(document.getElementById("my-timeline"), bandInfos);
        //console.log('create done');
        Timeline.loadXML("$data", function(xml, url) {eventSource.loadXML(xml,url); });
      }

      var resizeTimerID = null;
      function onResize() {
        //   console.log('resize');

        if (resizeTimerID == null) {
          resizeTimerID = window.setTimeout(function() {
            resizeTimerID = null;
            //   console.log('call layout');
            tl.layout();
          }, 500);
        }
      }

      YAHOO.util.Event.addListener(window, 'load',   onLoad());
      // YAHOO.util.Event.addListener(window, 'resize', onResize());

      </script>

    }]
  }

  ::xowiki::IncludeletClass create user-timeline \
      -superclass timeline \
      -parameter {
        {parameter_declaration {
          -user_id
          {-data timeline-data}
          {-interval1 DAY}
          {-interval2 MONTH}
        }}
      } -ad_doc {
        Include a timeline of changes of the current or specified user
        (based on yahoo timeline API)
      }

  user-timeline instproc render {} {
    :get_parameters
    if {![info exists user_id]} {set user_id [::xo::cc user_id]]}
  ::xo::cc set_parameter user_id $user_id
  next
}

}


namespace eval ::xowiki::includelet {
  #############################################################################
  Class create form-menu-button \
      -parameter {
        form
        method
        link
        package_id
        parent_id
        base
        return_url
        {label_suffix ""}
      }

  form-menu-button instproc render {} {
    if {![info exists :link]} {
      if {${:parent_id} != [::${:package_id} folder_id]} {
        set parent_id ${:parent_id}
      }
      if {[info exists :return_url]} {set return_url ${:return_url}}
      set :link [::${:package_id} make_link -link ${:base} ${:form} ${:method} return_url parent_id]
    }
    if {${:link} eq ""} {
      return ""
    }
    set msg_key [namespace tail [:info class]]
    set label [_ xowiki.$msg_key [list form_name [${:form} name]]]${:label_suffix}
    return "<a href='[ns_quotehtml ${:link}]'>[ns_quotehtml $label]</a>"
  }

  Class create form-menu-button-new -superclass form-menu-button -parameter {
    {method create-new}
  }

  Class create form-menu-button-answers -superclass form-menu-button -parameter {
    {method list}
  }
  form-menu-button-answers instproc render {} {
    array set "" [list publish_status all]
    array set "" [::xowiki::PageInstance get_list_from_form_constraints \
                      -name @table_properties \
                      -form_constraints [[:form] get_form_constraints -trylocal true]]
    set count [[:form] count_usages \
                   -package_id ${:package_id} -parent_id ${:parent_id} \
                   -publish_status $(publish_status)]
    :label_suffix " ($count)"
    next
  }

  Class create form-menu-button-form -superclass form-menu-button -parameter {
    {method view}
  }


  ::xowiki::IncludeletClass create form-menu \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-form_item_id:integer}
          {-parent_id}
          {-form}
          {-buttons {new answers}}
          {-button_objs}
          {-return_url}
        }}
      } -ad_doc {
        Include a form menu for the specified Form
      }

  form-menu instproc render {} {
    :get_parameters
    set package_id [${:__including_page} package_id]
    #:msg form-menu-[info exists form_item_id] buttons=$buttons

    if {![info exists form_item_id]} {
      set form_item_id [::$package_id instantiate_forms \
                            -forms $form \
                            -parent_id [${:__including_page} parent_id]]
      if {$form_item_id eq ""} {
        # we could throw an error as well...
        :msg "could not locate form '$form' for parent_id [${:__including_page} parent_id]"
        return ""
      }
    }
    if {[info exists parent_id]} {
      if {$parent_id eq "self"} {
        set parent_id [${:__including_page} item_id]
      }
    } else {
      set parent_id [${:__including_page} parent_id]
    }
    if {![info exists button_objs]} {
      set button_objs {}
      foreach b $buttons {
        if {[llength $b]>1} {
          lassign $b button id
        } else {
          lassign [list $b $form_item_id] button id
        }
        set form [::xo::db::CrClass get_instance_from_db -item_id $id]
        set form_package_id [$form package_id]
        if {$form_package_id eq ""} {
          #
          # When the package_id is empty, the page might be from a
          # site-wide page. Resolve the form page to the local context
          #
          $form set_resolve_context -package_id $package_id -parent_id $parent_id
          set form_package_id $package_id
        }
        #
        # "Package require" is just a part of "Package initialize"
        # creating the package object if needed....
        #
        ::xowiki::Package require $form_package_id
        set obj [form-menu-button-$button new -volatile -package_id $package_id \
                     -base [::$package_id pretty_link -parent_id $parent_id $form] \
                     -form $form -parent_id $parent_id]
        if {[info exists return_url]} {$obj return_url $return_url}
        lappend button_objs $obj
      }
    }
    set links [list]
    foreach b $button_objs { lappend links [$b render] }
    return "<div style='clear: both;'><div class='wiki-menu'>[join $links { &middot; }]</div></div>\n"
  }

  #############################################################################
  ::xowiki::IncludeletClass create form-stats \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-form}
          {-parent_id}
          {-property _state}
          {-orderby "count,desc"}
          {-renderer "table"}

        }}
      } -ad_doc {
        Include form statistics for the specofied Form page.
      }

  form-stats instproc render {} {
    :get_parameters
    set o ${:__including_page}
    if {![info exists parent_id]} {set parent_id [$o parent_id]}
    set form_item_ids [::$package_id instantiate_forms \
                           -forms $form \
                           -parent_id $parent_id]
    if {[llength $form_item_ids] != 1} {
      return "no such form $form<br>\n"
    }
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_ids -form_fields "" \
                   -always_queried_attributes "*" -initialize false \
                   -publish_status all -package_id $package_id]

    set sum 0
    foreach i [$items children] {
      set value ""
      if {[string match _* $property]} {
        set varname [string range $property 1 end]
        if {[$i exists $varname]} {set value [$i set $varname]}
      } else {
        set instance_attributes [$i set instance_attributes]
        if {[dict exists $instance_attributes $property]} {
          set value [dict get $instance_attributes $property]
        }
      }
      if {[info exists __count($value)]} {incr __count($value)} else {set __count($value) 1}
      incr sum 1
    }

    if {$sum == 0} {
      return "[_ xowiki.no_data]<br>\n"
    }

    if {$renderer eq "highcharts"} {
      #
      # experimental highcharts pie renderer
      #
      set percentages [list]
      foreach {value count} [array get __count] {
        lappend percentages $value [format %.2f [expr {$count*100.0/$sum}]]
      }
      set h [highcharts new -volatile -id [:js_name] \
                 -title [::xowiki::Includelet js_encode \
                             "$sum $total_text [_ xowiki.Answers_for_Survey] '[$form_item_ids title]'"]]
      return [$h pie [list value count] $percentages]

    } else {
      #
      # standard table encoder
      #
      TableWidget create t1 -volatile \
          -columns {
            Field create value -orderby value -label value
            Field create count -orderby count -label count
          }

      lassign [split $orderby ,] att order
      t1 orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att
      foreach {value count} [array get __count] {
        t1 add -value $value -count $count
      }
      return [t1 asHTML]
    }
  }

  #
  # To use highcharts, download it from http://www.highcharts.com/
  # and install it under the directory xowiki/www/resources/highcharts
  # (you have to create the directory and unpack the zip file there).
  #
  ::xotcl::Class highcharts -parameter {title id}
  highcharts instproc pie {names data} {
    ::xo::Page requireJS urn:ad:js:jquery
    ::xo::Page requireJS urn:ad:js:highcharts
    ::xo::Page requireJS urn:ad:js:highcharts-theme
    set result "<div id='[:id]' style='width: 100%; height: 400px'></div>\n"
    set title ${:title}
    if {![info exists :id]} {set :id [::xowiki::Includelet html_id [self]]}
    set id [:id]
    set values [list]
    foreach {name value} $data {
      lappend values "\['[::xowiki::Includelet js_encode $name]', $value\]"
    }
    set values [join $values ",\n"]

    set nonce [security::csp::nonce]

    append result [subst -nocommands {
      <script type='text/javascript' nonce='$nonce'>
      var chart;
      chart = new Highcharts.Chart({
        chart: {
          renderTo: '$id',
          plotBackgroundColor: null,
          plotBorderWidth: null,
          plotShadow: true
        },
        title: {text: '$title'},
        tooltip: {
          formatter: function() {
            if (this.point.name.length < 70) {
              return '<b>'+ this.point.name +'</b>: '+ this.y +' %';
            } else {
              return this.point.name.substr(0,70) + '... : ' + this.y +' %';
            }
          }
        },
        plotOptions: {
          pie: {
            allowPointSelect: true,
            cursor: 'pointer',
            dataLabels: {
              enabled: true,
              color: Highcharts.theme.textColor || '#000000',
              connectorColor: Highcharts.theme.textColor || '#000000',
              formatter: function() {
                return '<b>'+ this.point.name +'</b>: '+ this.y +' %';
              }
            }
          }
        },
        series: [{
          type: 'pie',
          name: '$names',
          data: [$values]
        }]
      });
      </script>
    }]
    return $result
  }


  #############################################################################
  ::xowiki::IncludeletClass create form-usages \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-form_item_id:integer}
          {-form}
          {-parent_id}
          {-package_ids ""}
          {-orderby "_raw_last_modified,desc"}
          {-view_field _name}
          {-publish_status "all"}
          {-field_names}
          {-hidden_field_names "_last_modified"}
          {-extra_form_constraints ""}
          {-inherit_from_forms ""}
          {-category_id}
          {-unless}
          {-where}
          {-csv true}
          {-voting_form}
          {-voting_form_form ""}
          {-voting_form_anon_instances "t"}
          {-generate}
          {-with_form_link true}
          {-with_categories}
          {-wf}
          {-bulk_actions ""}
          {-buttons "edit delete"}
          {-renderer ""}
          {-return_url}
          {-date_format}
          {-with_checkboxes:boolean false}
        }}
      }  -ad_doc {
        Show usages of the specified form.

        @param return_url
           When provided and NOT empty, use the value as return_url.
           When provided and empty, do NOT set a return URL.
           When NOT provided, set the calling page as return_url.
        @param date_format
           Date format used for modification date.
           Might be "pretty-age" or a format string like "%Y-%m-%d %T".
      }

  form-usages instproc render {} {
    :get_parameters

    set o ${:__including_page}
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    if {[info exists return_url]} {
      if {$return_url eq ""} {
        #
        # If provided return_url is empty, NO return_url is set.
        #
        unset return_url
      } else {
        #
        # Use the provided return_url.
        #
      }
    } else {
      #
      # Per default, set the return_url to the current page.
      #
      set return_url [::xo::cc url]?[::xo::cc actual_query]
    }

    if {[info exists parent_id]} {
      if {$parent_id eq "self"} {
        set parent_id [${:__including_page} item_id]
      } elseif {$parent_id eq "*"} {
        set query_parent_id $parent_id
        set parent_id [$o parent_id]
      }
    } else {
      set parent_id [$o parent_id]
    }
    if {![info exists query_parent_id]} {
      set query_parent_id $parent_id
    }

    if {![info exists form_item_id]} {
      #
      # Resolve forms by name, since we have no id.  The variable
      # "$form" can be actually refer to multiple forms in the usual
      # syntax, therefore, the result has the plural form.
      #
      set form_item_ids [::$package_id instantiate_forms \
                             -parent_id $parent_id \
                             -default_lang [$o lang] \
                             -forms $form \
                            ]
      if {$form_item_ids eq ""} {
        return -code error "could not load form '$form' (default-language [$o lang])"
      }
    } else {
      set form_item_ids [list $form_item_id]
    }

    set form_constraints $extra_form_constraints\n

    set inherit_form_ids {}
    if {$inherit_from_forms ne ""} {
      foreach inherit_form $inherit_from_forms {
        set inherit_form_id [::$package_id instantiate_forms \
                                 -parent_id [$o parent_id] \
                                 -default_lang [$o lang] \
                                 -forms $inherit_form]
        if {$inherit_form_id ne ""} {
          if {[::$inherit_form_id istype ::xowiki::FormPage]} {
            set p [::$inherit_form_id property form_constraints]
          } else {
            set p [::$inherit_form_id form_constraints]
          }
          append form_constraints $p\n
          lappend inherit_form_ids $inherit_form_id
        }
      }
    }

    foreach form_item $form_item_ids {
      append form_constraints [$form_item get_form_constraints -trylocal true] \n
    }
    #:log fc=$form_constraints

    # load table properties; order_by won't work due to comma, but solve that later (TODO)
    set table_properties [::xowiki::PageInstance get_list_from_form_constraints \
                              -name @table_properties \
                              -form_constraints $form_constraints]

    foreach {attr value} $table_properties {
      # All labels of the following switch statement are used as
      # variable names. Take care when adding new labels to avoid
      # overwriting existing variables.
      switch -- $attr {
        orderby {set $attr _[::xowiki::formfield::FormField fc_decode $value]}
        buttons - publish_status - category_id - unless -
        where -   with_categories - with_form_link - csv - view_field -
        voting_form - voting_form_form - voting_form_anon_instances {
          set $attr $value
          #:msg " set $attr $value"
        }
        default {error "unknown table property '$attr' provided"}
      }
    }

    if {![info exists field_names]} {
      set fn [::xowiki::PageInstance get_short_spec_from_form_constraints \
                  -name @table \
                  -form_constraints $form_constraints]
      set raw_field_names [split $fn ,]
    } elseif {[string match "*,*" $field_names] } {
      set raw_field_names [split $field_names ,]
    } else {
      set raw_field_names $field_names
    }

    if {$raw_field_names eq ""} {
      set raw_field_names {_name _last_modified _creation_user}
    }
    foreach fn $hidden_field_names {
      lappend raw_field_names $fn
    }

    #:log raw_field_names=$raw_field_names

    #
    # Finally, evaluate conditions in case these are included.
    #
    set field_names [list]
    foreach f $raw_field_names {
      set _ [string trim [::xowiki::formfield::FormField get_single_spec \
                              -object $o -package_id $package_id $f]]
      if {$_ ne ""} {lappend field_names $_}
    }

    if {[llength $inherit_form_ids] > 0} {
      set item_ids $inherit_form_ids
    } else {
      set item_ids $form_item_ids
    }

    set form_fields ""
    foreach form_item $item_ids {
      set form_field_objs [::xowiki::FormPage get_table_form_fields \
                               -base_item $form_item \
                               -field_names $field_names \
                               -form_constraints $form_constraints \
                               -nls_language [${:__including_page} nls_language] \
                              ]
      #$form_item show_fields $form_field_objs
      foreach f $form_field_objs {
        dict set form_fields [$f name] $f
      }
      #foreach f $form_field_objs {ns_log notice "form <[$form_item name]: field [$f name] label [$f label]"}
    }
    # if {[dict exists $form_fields _creation_user]} {[dict get $form_fields _creation_user] label "By User"}

    #
    # TODO: wiki-substitution is just forced in here. Maybe it makes
    # more sense to use it as a default for _text, but we have to
    # check all the nested cases to avoid double-substitutions.
    #
    if {[dict exists $form_fields _text]} {
      [dict get $form_fields _text] set wiki 1
    }

    if {[dict exists $form_fields _last_modified] && [info exists date_format]} {
      [dict get $form_fields _last_modified] display_format $date_format
    }

    #
    # Create Table widget
    #
    set table_widget [::xowiki::TableWidget create_from_form_fields \
                          -form_field_objs $form_field_objs \
                          -package_id $package_id \
                          -buttons $buttons \
                          -hidden_field_names $hidden_field_names \
                          -bulk_actions $bulk_actions \
                          -renderer $renderer \
                          -orderby $orderby \
                          -with_checkboxes $with_checkboxes]
    #
    # Handling voting_forms
    #
    if {[info exists voting_form]} {
      #
      # If the user provided a voting form name without a language
      # prefix, add one.
      #
      if {![regexp {^..:} $voting_form]} {
        set voting_form [${:__including_page} lang]:$voting_form
      }
      dict set voting_dict voting_form $voting_form
      dict set voting_dict renderer \
          [list [self] generate_voting_form $voting_form $voting_form_form \
               $table_widget $field_names $voting_form_anon_instances]
    } else {
      set voting_dict ""
    }

    #
    # Compute filter clauses
    #
    set filters [::xowiki::FormPage compute_filter_clauses \
                     {*}[expr {[info exists unless] ? [list -unless $unless] : ""}] \
                     {*}[expr {[info exists where] ? [list -where $where] : ""}]]

    #:msg filters=$filters

    #
    # Get an ordered composite of the base set (currently including
    # extra_where clause)
    #
    #:log "exists category_id [info exists category_id]"
    set extra_where_clause ""
    if {[info exists category_id]} {
      lassign [:category_clause $category_id item_id] cnames extra_where_clause
    }

    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_ids \
                   -parent_id $query_parent_id \
                   -form_fields $form_field_objs \
                   -publish_status $publish_status \
                   -extra_where_clause $extra_where_clause \
                   -h_where [dict get $filters wc] \
                   -h_unless [dict get $filters uc] \
                   -from_package_ids $package_ids \
                   -package_id $package_id]

    if {[info exists with_categories]} {
      if {$extra_where_clause eq ""} {
        set base_items $items
      } else {
        # difference to variable items: just the extra_where_clause
        set base_items [::xowiki::FormPage get_form_entries \
                            -base_item_ids $form_item_ids \
                            -parent_id $query_parent_id \
                            -form_fields $form_field_objs \
                            -publish_status $publish_status \
                            -h_where [dict get $filters wc] \
                            -h_unless [dict get $filters uc] \
                            -from_package_ids $package_ids \
                            -package_id $package_id]
      }
    }
    #:log "queries done"
    if {[info exists wf]} {
      set wf_link [::$package_id pretty_link -parent_id $parent_id -path_encode false $wf]
    }

    set HTML [$table_widget render_page_items_as_table \
                  -form_field_objs $form_field_objs \
                  -return_url [ad_return_url] \
                  -package_id $package_id \
                  -items $items \
                  -init_vars [dict get $filters init_vars] \
                  -view_field $view_field \
                  -buttons $buttons \
                  -include_object_id_attribute [expr {$with_checkboxes || [llength $bulk_actions] > 0}] \
                  -form_item_ids $form_item_ids \
                  -with_form_link $with_form_link \
                  -csv $csv \
                  {*}[expr {[info exists generate] ? [list -generate $generate] : ""}] \
                  -voting_dict $voting_dict \
                 ]
    $table_widget destroy
    return $HTML
  }

  form-usages instproc generate_voting_form {
    form_name
    form_form
    t1
    field_names
    voting_form_anon_instances
  } {
    #:msg "generate_voting anon=$voting_form_anon_instances"
    set form "<form> How do you rate<br />
    <table rules='all' frame='box' cellspacing='1' cellpadding='1' border='0' style='border-style: none;'>
      <tbody>
        <tr>
          <td style='border-style: none;'> </td>
          <td style='border-style: none; text-align: left; width: 150px;'>&nbsp;very good<br /></td>
          <td align='right' style='border-style: none; text-align: right; width: 150px;'>&nbsp;very bad<br /></td>
        </tr> \n"

    # We use here the table t1 to preserve sorting etc.
    # The basic assumption is that every line of the table has an instance variable
    # corresponding to the wanted field name. This is guaranteed by the construction
    # in form-usages.
    set count 0
    set table_field_names [list]
    foreach t [$t1 children] {
      incr count
      lappend table_field_names $count
      # In most situations, it seems useful to have just one field in
      # the voting table. If there are multiple, we use a comma to
      # separate the values (looks bettern than separate columns).
      set field_contents [list]
      foreach __fn $field_names {
        lappend field_contents [$t set $__fn]
      }
      append form "<tr><td>[join $field_contents {, }]</td><td align='center' colspan='2'>@$count@</td></tr>\n"
    }

    append form "</tbody></table></form>\n"
    lappend table_field_names _last_modified _creation_user

    # Check, of we have a form for editing the generated form. If yes, we will
    # instantiate a form page from it.
    set form_form_id 0
    if {$form_form ne ""} {
      set form_form_id  [::xo::db::CrClass lookup -name $form_form -parent_id [::${:package_id} folder_id]]
    }
    # The normal form requires for rich-text the 2 element list as content
    if {$form_form_id == 0} { set form [list $form text/html] }

    set item_id [::xo::db::CrClass lookup -name $form_name -parent_id [::${:package_id} folder_id]]
    if {$item_id == 0} {

      if {$form_form_id == 0} {
        set f [::xowiki::Form new \
                   -package_id ${:package_id} \
                   -parent_id [::${:package_id} folder_id] \
                   -name $form_name \
                   -anon_instances $voting_form_anon_instances \
                   -form $form \
                   -form_constraints "@fields:scale,n=7,inline=true @cr_fields:hidden @categories:off\n\
                   @table:[join $table_field_names ,]" \
                  ]
      } else {
        set f [::xowiki::FormPage new \
                   -page_template $form_form_id \
                   -package_id ${:package_id} \
                   -parent_id [::${:package_id} folder_id] \
                   -name $form_name]
        $f set_property anon_instances $voting_form_anon_instances
        $f set_property form $form
        $f set_property form_constraints "@fields:scale,n=7,inline=true @cr_fields:hidden @categories:off\n\
                   @table:[join $table_field_names ,]"
      }
      $f save_new
      set form_href [$f pretty_link]
      $f destroy
      set action created
    } else {
      ::xo::db::CrClass get_instance_from_db -item_id $item_id
      if {$form_form_id == 0} {
        ::$item_id form $form
      } else {
        ::$item_id set_property form $form
      }
      ::$item_id save
      set form_href [::$item_id pretty_link]
      set action updated
    }
    return "#xowiki.form-$action# <a href='[ns_quotehtml $form_href]'>[ns_quotehtml $form_name]</a>"
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Show an iframe as includelet
  #
  ::xowiki::IncludeletClass create iframe \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
          {-title ""}
          {-url:required}
          {-width "100%"}
          {-height "500px"}
        }}
      } -ad_doc {
        Include an iframe contining the specified URL

        @param title
        @param url
        @param width
        @param height
      }


  iframe instproc render {} {
    :get_parameters

    if {$title eq ""} {
      set title $url
    }

    set url    [ns_quotehtml $url]
    set title  [ns_quotehtml $title]
    set width  [ns_quotehtml $width]
    set height [ns_quotehtml $height]

    return [subst -nocommands {
      <iframe src='${url}' width='${width}' height='${height}'></iframe>
      <p><a href='${url}' title='${title}'>${title}</a></p>
    }
  }

}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # present images in an YUI carousel
  #
  ::xowiki::IncludeletClass create yui-carousel \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
          {-title ""}
          {-item_size 600x400}
          {-image_size}
          {-num_visible 1}
          {-play_interval 0}
          {-auto_size 0}
          {-folder}
          {-glob ""}
          {-form ""}
        }}
      } -ad_doc {
        Include YUI carousel showing the pages of the specified or
        current folder.

        @param folder
        @param glob optional matching patter for page names
      }

  yui-carousel instproc images {-package_id -parent_id {-glob ""} {-width ""} {-height ""}} {
    set size_info ""
    if {$width ne ""} {append size_info " width='[ns_quotehtml $width]'"}
    if {$height ne ""} {append size_info " height='[ns_quotehtml $height]'"}
    if {$width ne "" && $height ne ""} {
      set geometry "?geometry=${width}x${height}"
    } else {
      set geometry ""
    }
    set listing [::xowiki::Includelet listing \
                     -package_id $package_id \
                     -parent_id $parent_id \
                     -use_package_path false \
                     -extra_where_clause " and mime_type like 'image/%'" \
                     -orderby "name asc" \
                     -glob $glob]
    #:msg "parent-id=$parent_id, glob=$glob entries=[llength [$listing children]]"

    foreach entry [$listing children] {
      $entry class ::xowiki::Page
      $entry set html "<img src='[$entry pretty_link -download true]$geometry' $size_info> <h2>[$entry title]</h2>"
    }
    return $listing
  }

  yui-carousel instproc form_images {
    -package_id
    -parent_id
    {-form "en:photo.form"}
    {-glob ""} {-width ""} {-height ""}
  } {
    set form_item_ids [::$package_id instantiate_forms -parent_id $parent_id -forms $form]
    if {$form_item_ids eq ""} {error "could not find en:photo.form"}
    set form_item_id [lindex $form_item_ids 0]

    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_ids -form_fields "" \
                   -publish_status all \
                   -always_queried_attributes * \
                   -parent_id $parent_id \
                   -package_id $package_id]
    #:msg "parent-id=$parent_id, glob=$glob entries=[llength [$items children]]"

    foreach entry [$items children] {
      # order?
      set image_name [$entry property image]
      if {$glob ne "" && ![string match $glob $image_name]} {
        $items delete $entry
        continue
      }
      if {![info exists entry_field_names]} {
        set entry_field_names [$entry field_names]
        set entry_form_fields [::xowiki::FormPage get_table_form_fields \
                                   -base_item $form_item_id \
                                   -field_names $entry_field_names \
                                   -form_constraints [::$form_item_id set form_constraints]]
        foreach fn $entry_field_names f $entry_form_fields {set ff($fn) $f}
      }
      $entry load_values_into_form_fields $entry_form_fields
      foreach f $entry_form_fields {$f object $entry}
      if {[info exists ff(image)]} {
        if {$width ne ""} {$ff(image) width $width}
        if {$height ne ""} {$ff(image) height $height}
        if {$width ne "" && $height ne ""} {
          $ff(image) set geometry "${width}x${height}"
        }
        $ff(image) label [$entry property _title]
      }
      $entry set html [$entry render_content]
      #:log html=[$entry set html]
    }
    return $items
  }

  yui-carousel instproc render {} {
    :get_parameters

    set ajaxhelper 1
    ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper carousel/assets/skins/sam/carousel.css
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "yahoo-dom-event/yahoo-dom-event.js"
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "connection/connection-min.js"
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "animation/animation-min.js"
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "element/element-min.js"
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "carousel/carousel-min.js"
    ::xo::Page set_property body class "yui-skin-sam "

    if {![regexp {^(.*)x(.*)$} $item_size _ item_width item_height]} {
      error "invalid item size '$item_size'; use e.g. 300x240"
    }

    if {[info exists image_size]} {
      if {![regexp {^(.*)x(.*)$} $image_size _ width height]} {
        error "invalid image size '$image_size'; use e.g. 300x240"
      }
    } elseif {$auto_size} {
      set width $item_width
      set height $item_height
    } else {
      set width ""
      set height ""
    }

    set ID container_[::xowiki::Includelet html_id [self]]
    set play_interval [expr {int($play_interval * 1000)}]

    ::xo::Page requireJS [subst {
      YAHOO.util.Event.onDOMReady(function (ev) {
        var carousel    = new YAHOO.widget.Carousel("$ID",{
          isCircular: true, numVisible: $num_visible,
          autoPlayInterval: $play_interval, animation: {speed: 1.0}
        });
        carousel.render(); // get ready for rendering the widget
        carousel.show();   // display the widget

      });
    }]

    ::xo::Page requireStyle [subst {

      \#$ID {
        margin: 0 auto;
      }

      .yui-carousel-element .yui-carousel-item-selected {
        opacity: 1;
      }

      .yui-carousel-element li {
        height: ${item_height}px;
        width: ${item_width}px;
      }

      .yui-skin-sam .yui-carousel-nav ul li {
        margin: 0;
      }}]

    set parent_id [${:__including_page} parent_id]
    if {[info exists folder]} {
      set folder_page [::$package_id get_page_from_item_ref -parent_id $parent_id $folder]
      if {$folder_page eq ""} {
        error "no such folder '$folder'"
      } else {
        set parent_id [$folder_page item_id]
      }
    }

    set content "<div id='[ns_quotehtml $ID]'><ol>\n"
    if {$form ne ""} {
      set images [:form_images -package_id $package_id -parent_id $parent_id \
                      -form $form -glob $glob -width $width -height $height]
    } else {
      set images [:images -package_id $package_id -parent_id $parent_id \
                      -glob $glob -width $width -height $height]
    }
    foreach entry [$images children] {
      append content "<li class='item'> [$entry set html] </li>\n"
    }
    append content "</ol></div>\n<div id='spotlight'></div>\n"
    #if {$title eq ""} {set title $url}
    return $content
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  # gravatar
  #
  # user image based on email address
  # for details: see http://en.gravatar.com/
  #
  ::xowiki::IncludeletClass create gravatar \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-email:required}
          {-size 80}
        }}
      } -ad_doc {
        Include gravatar picture for the specified email

        @param email
        @param size in pixel, default 80
      }

  gravatar proc url {-email {-size 80} {-default mp}} {
    # reusable helper proc to compute a gravatar URL
    if {[info commands ns_md5] ne ""} {
      set md5 [string tolower [ns_md5 $email]]
    } else {
      package require md5
      set md5 [string tolower [md5::Hex [md5::md5 -- $email]]]
    }
    security::csp::require img-src www.gravatar.com
    return //www.gravatar.com/avatar/$md5?size=$size&d=$default
  }

  gravatar instproc render {} {
    :get_parameters
    return "<img src='[gravatar url -email $email -size $size]' alt='[ns_quotehtml $email]'>"
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # random-form-page
  #
  ::xowiki::IncludeletClass create random-form-page  \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-form:required}
          {-publish_status "ready"}
          {-expires 600}
        }}
      } -ad_doc {
        Include random form page (instance of the specified form)

        @param form
        @param publish_status (default ready)
        @param expires (default 600 secs)
      }

  random-form-page proc page_names {package_id form publish_status} {
    #
    # This is a cacheable method returning a list of the names from
    # which the random page is selected. We use a class method and the
    # argument list with util_memoize inability to provide a key for
    # caching.
    #
    set form_item_ids [::$package_id instantiate_forms -forms $form]
    set form_fields [::xowiki::FormPage get_table_form_fields \
                         -base_item [lindex $form_item_ids 0] \
                         -field_names _name \
                         -form_constraints ""]
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_ids \
                   -form_fields $form_fields \
                   -initialize false \
                   -publish_status $publish_status \
                   -package_id $package_id]
    set result [list]
    foreach item [$items children] {
      lappend result [$item name]
    }
    return $result
  }

  random-form-page instproc render {} {
    :get_parameters

    set cmd [list ::xowiki::includelet::random-form-page page_names $package_id $form $publish_status]
    if {[ns_info name] eq "NaviServer"} {
      set names [::xowiki::cache \
                     -expires $expires \
                     -partition_key $package_id \
                     random-$package_id-$form \
                     $cmd]
    } else {
      set names [util_memoize $cmd]
    }
    set random_item [lindex $names [expr { int([llength $names] * rand()) }]]
    if {$random_item eq ""} {
      return ""
    } {
      return [${:__including_page} include [list $random_item -decoration none]]
    }
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # flowplayer
  #
  # Get flowplayer from
  #    http://flowplayer.org/download/index.html
  # Get pseudostreaming plugin from
  #     http://flowplayer.org/plugins/streaming/pseudostreaming.html#download
  #
  # install both under packages/xowiki/www/resources/flowplayer
  #
  ::xowiki::IncludeletClass create flowplayer \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          -mp4:required,nohtml
        }}
      } -ad_doc {
        Include an mp4 image using flowplayer

        @param mp4
      }

  flowplayer instproc include_head_entries {} {
    ::xo::Page requireJS  "/resources/xowiki/flowplayer/example/flowplayer-3.2.6.js"
  }

  flowplayer instproc render {} {
    :get_parameters
    return "<a href='[ns_quotehtml $mp4]' style='display:block;width:425px;height:300px;' id='player'> </a>
    <script type='text/javascript' nonce='[security::csp::nonce]'>
 flowplayer('player', '/resources/xowiki/flowplayer/flowplayer-3.2.7.swf', {

    // this will enable pseudostreaming support
    plugins: {
        pseudo: { url: '/resources/xowiki/flowplayer/flowplayer.pseudostreaming-3.1.3.swf' }
    },

    // clip properties
    clip: {
        // our clip uses pseudostreaming
        provider: 'pseudo',

                autoPlay: false,
                autoBuffering: false,

        // Provide MP4 file for Flash version 9.0.115 and above. Otherwise use FLV
        url: '$mp4'
    }

 });
   </script>"
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Show the content of an HTML file in includelet
  #
  ::xowiki::IncludeletClass create html-file \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
          {-title ""}
          {-extra_css ""}
          {-levels 0}
          {-file:required}
        }}
      } -ad_doc {
        Include the specified HTML file

        @param file file to be included
        @param title
        @param extra_css
      }


  #
  # The two methods "href" and "page_number" are copied from "toc"
  #
  html-file instproc href {book_mode name} {
    if {$book_mode} {
      set href [::xo::cc url]#[toc anchor $name]
    } else {
      set href [::${:package_id} pretty_link -parent_id [${:__including_page} parent_id] $name]
    }
    return $href
  }

  html-file instproc page_number {page_order remove_levels} {
    #:log "o: $page_order"
    set displayed_page_order $page_order
    for {set i 0} {$i < $remove_levels} {incr i} {
      regsub {^[^.]+[.]} $displayed_page_order "" displayed_page_order
    }
    #return $displayed_page_order
    return ""
  }

  html-file instproc render {} {
    :get_parameters

    if {$title eq ""} {set title $file}
    set parent_id [${:__including_page} parent_id]
    set page [::$package_id get_page_from_item_ref -parent_id $parent_id $file]
    if {$page eq ""} {
      error "could not resolve page from item ref $file"
    }
    if {$extra_css ne ""} {foreach css $extra_css {::xo::Page requireCSS $css}}
    return [$page html_content -add_sections_to_folder_tree $levels -owner [self]]
  }

}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Define chat as an includelet
  #
  ::xowiki::IncludeletClass create chat \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
          {-title ""}
          {-chat_id ""}
          {-mode ""}
          {-path ""}
          -skin
          -login_messages_p
          -logout_messages_p
          -avatar_p
          -timewindow
        }}
      } -ad_doc {
        Include a chat in the current page

        @param mode
        @param path
        @param skin
        @param title
        @param chat_id
        @param avatar_p
        @param login_messages_p
        @param logout_messages_p
        @param timewindow
      }

  chat instproc render {} {
    :get_parameters
    if {$chat_id eq ""} {
      # make the chat just for including page
      set chat_id [${:__including_page} item_id]
    }
    set chat_cmd [list \
                      ::xowiki::Chat login \
                      -chat_id $chat_id \
                      -mode $mode \
                      -path $path]
    # We don't want to override Chat class default with our own and
    # therefore we build the command dynamically depending if these
    # variables are there or not.
    set optional_vars [list login_messages_p logout_messages_p timewindow skin avatar_p]
    foreach var $optional_vars {
      if {[info exists $var]} {
        lappend chat_cmd -${var} [set $var]
      }
    }
    set r [{*}$chat_cmd]

    #ns_log notice chat=>$r

    return $r
  }
}

namespace eval ::xowiki::includelet {

  ::xowiki::IncludeletClass create community-link \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-text ""}
          {-url ""}
        }}
      } -ad_doc {
        Include a link to the community including the current page.
        This includelet is designed to work with dotlrn.

        @param text text to be displayed in community link
        @param url optional path relative to community

      } -instproc render {} {
        :get_parameters
        if {[info commands ::dotlrn_community::get_community_id] ne ""} {
          set community_id [::dotlrn_community::get_community_id]
          set base_url [dotlrn_community::get_community_url $community_id]

          return [subst {<a href="$base_url/$url">[ns_quotehtml $text]</a>}]
        }
      }

  #
  # link-with-local-return-url: insert a link with extra return URL
  # pointing the current object. This is particularly useful in cases,
  # where a return URL must be created for a page that does not yet
  # exist at time of definition (e.g. for link pointing to concrete
  # workflow instances)
  #
  ::xowiki::IncludeletClass create link-with-local-return-url \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-text ""}
          {-url ""}
        }}
      } -ad_doc {

        Insert a link with extra return URL pointing the current
        object. This is particularly useful in cases, where a
        return URL must be created for a page that does not yet
        exist at time of definition (e.g. for link pointing to
        concrete workflow instances)

      } -instproc render {} {
        :get_parameters
        #set return_url [ad_return_url]
        set return_url [${:__including_page} pretty_link]
        append url &return_url=$return_url
        return [subst {<a href="[ns_quotehtml $url]">[ns_quotehtml $text]</a>}]
      }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

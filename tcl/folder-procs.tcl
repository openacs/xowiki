::xo::library doc {

  This is an experimental implementation for folders
  based on xowiki form pages. In particular, this file provides

  * An xowiki includelet to display the "folders"
  * An xowiki includelet to display the "child-resources"
    of a page (e.g. the contents of a folder)

  @author Michael Aram
  @author Gustaf Neumann
}

::xo::library require xowiki-procs
::xo::library require includelet-procs
::xo::library require form-field-procs
::xo::library require -package xotcl-core 30-widget-procs

namespace eval ::xowiki::includelet {
  ###########################################################
  #
  # ::xowiki::includelet::folders
  #
  ###########################################################
  ::xowiki::IncludeletClass create folders \
      -superclass ::xowiki::Includelet \
      -cacheable false \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-show_full_tree false}
          {-context_tree_view false}
        }}
        {id "[xowiki::Includelet js_name [self]]"}
      } -ad_doc {

        List the folder tree of the current instance

        @param show_full_tree (default false)
        @param context_tree_view (default false)

      }

  folders instproc include_head_entries {} {
    switch [::${:package_id} get_parameter PreferredCSSToolkit bootstrap] {
      yui     {::xowiki::Tree include_head_entries -renderer yuitree -style folders}
      bootstrap -
      default { ::xowiki::Tree include_head_entries -renderer bootstrap3 }
    }
  }

  folders instproc render {} {
    :get_parameters

    set tree [:build_tree]
    switch [::${:package_id} get_parameter PreferredCSSToolkit bootstrap] {
      yui {
           set js "
           var [:js_name];
           YAHOO.util.Event.onDOMReady(function() {
             [:js_name] = new YAHOO.widget.TreeView('foldertree_[:id]');
             [:js_name].subscribe('clickEvent',function(oArgs) {
               var m = /href=\"(\[^\"\]+)\"/.exec(oArgs.node.html);
               return false;
             });
             [:js_name].render();
           });
           "
        set HTML [$tree render -style yuitree -js $js]
      }
      bootstrap -
      default   {
        #:msg "render tree $tree // [$tree procsearch render ]"
        set HTML [$tree render -style bootstrap3-folders]
      }
    }
    #:log HTML=$HTML
    return $HTML
  }

  folders instproc folder_query {
    -form_id:required
    -package_id:required
    {-parent_id ""}
  } {
    if {$parent_id eq ""} {
      return [subst {
        select * from xowiki_form_instance_item_view
        where page_template = '$form_id' and package_id = '$package_id'
        and publish_status = 'ready'
      }]
    }
    #return [subst {
    #  select * from xowiki_form_instance_children ch
    #  left join xowiki_form_instance_attributes xa on (ch.item_id = xa.item_id)
    #  where page_template = '$form_id' and ch.package_id = '$package_id'
    #  and root_item_id = '$parent_id'
    #  and publish_status = 'ready'
    #}]

    #
    # Oracle query missing
    #
    return [subst {
    select
         xi.package_id, xi.parent_id, xi.name,
         xi.publish_status, xi.assignee, xi.state, xi.page_template, xi.item_id,
         o.object_id, o.object_type, o.title AS object_title, o.context_id,
         o.security_inherit_p, o.creation_user, o.creation_date, o.creation_ip,
         o.last_modified, o.modifying_user, o.modifying_ip,
         --o.tree_sortkey, o.max_child_sortkey,
         cr.revision_id, cr.title, content_revision__get_content(cr.revision_id) AS text,
         cr.description, cr.publish_date, cr.mime_type, cr.nls_language,
         xowiki_form_page.xowiki_form_page_id,
         xowiki_page_instance.page_instance_id,
         xowiki_page_instance.instance_attributes,
         xowiki_page.page_id,
         xowiki_page.page_order,
         xowiki_page.creator
      from (
         WITH RECURSIVE child_items AS (
           select * from xowiki_form_instance_item_index
           where item_id = '$parent_id'
      UNION ALL
        select xi.* from xowiki_form_instance_item_index xi, child_items
        where xi.parent_id = child_items.item_id
      )
      select * from child_items
         where page_template = '$form_id' and package_id = '$package_id' and publish_status = 'ready') xi
         left join cr_items ci on (ci.item_id = xi.item_id)
         left join cr_revisions cr on (cr.revision_id = ci.live_revision)
         left join acs_objects o on (o.object_id = ci.live_revision)
         left join xowiki_page on (o.object_id = xowiki_page.page_id)
         left join xowiki_page_instance on (o.object_id = xowiki_page_instance.page_instance_id)
         left join xowiki_form_page on (o.object_id = xowiki_form_page.xowiki_form_page_id)
    }]
  }

  folders instproc collect_folders {
    -package_id:required
    -folder_form_id:required
    -link_form_id:required
    {-parent_id ""}
    {-subtree_query ""}
    {-depth 3}
  } {
    set folders [list]

    # safety belt, for recursive structures
    if {$depth < 1} {
      return $folders
    }

    #
    # Get Folders
    #
    set sql [:folder_query -form_id $folder_form_id \
                 -parent_id $parent_id \
                 -package_id $package_id]

    #ns_log notice "folder_pages:\n$sql"
    set folder_pages [::xowiki::FormPage instantiate_objects -sql $sql \
                          -named_objects true -object_named_after "item_id" \
                          -keep_existing_objects true \
                          -object_class ::xowiki::FormPage -initialize true]

    #
    # Get links.
    #
    set sql [:folder_query -form_id $link_form_id \
                 -parent_id $parent_id \
                 -package_id $package_id]
    #ns_log notice "links (parent-id ='$parent_id'):\n$sql"
    set links [::xowiki::FormPage instantiate_objects -sql $sql \
                   -named_objects true -object_named_after "item_id" \
                   -object_class ::xowiki::FormPage -initialize true]

    #:msg "[llength [$links children]] links under $parent_id "

    set folders [$folder_pages children]

    #
    # filter links to folders.
    # links might be cross-package links
    #
    foreach l [$links children] {
      set link_type [$l get_property_from_link_page link_type]
      set cross_package [$l get_property_from_link_page cross_package]
      #:log "==================== [$l name]: link_type  $link_type cross package $cross_package"

      if {$link_type ne "folder_link"} continue

      if {$cross_package} {
        #
        # We found a cross-package link. These kind of links require
        # further queries.
        #
        set target [$l get_target_from_link_page]
        set sub_folders [:collect_folders -package_id [$target physical_package_id] \
                             -folder_form_id $folder_form_id -link_form_id $link_form_id \
                             -parent_id [$target item_id] \
                             -depth [expr {$depth -1}]]

        foreach f $sub_folders {

          #:msg "$f [$f name] is a folder-link pointing to $target [$target name] current ${:current_folder_id}"
          if {[$f parent_id] eq [$target item_id]} {
            #:msg "1 found child [$f name] and reset parent_id from [$f parent_id] to [$l item_id], package_id [$l package_id]"
            #
            # reset the current_folder if necessary
            #
            if {${:current_folder_id} eq [$f parent_id]} {
              set :current_folder_id [$l item_id]
            }
            #
            # set the resolve_context
            #
            $f set_resolve_context -package_id [$l package_id] -parent_id [$l item_id]
            #
            # TODO we could save the double-fetch by collecting in
            # get_form_entries via item_ids, not via new objects.
            #
            #::xo::db::CrClass get_instance_from_db -item_id [$f item_id]
            [$f item_id] set_resolve_context -package_id [$l package_id] -parent_id [$l item_id]
          } else {
            #:msg "2 found child [$f name] and reset parent_id from [$f parent_id] to [$f parent_id], package id [$l package_id]"
            $f set_resolve_context -package_id [$l package_id] -parent_id [$f parent_id]
            #::xo::db::CrClass get_instance_from_db -item_id [$f item_id]
            [$f item_id] set_resolve_context -package_id [$l package_id] -parent_id [$f parent_id]
          }

          #:msg "including $f [$f name] [$f item_id]"
          lappend folders $f
        }
      }
      #:msg link=$link
      lappend folders $l
    }
    return $folders
  }

  folders instproc build_tree {} {
    :get_parameters

    set page ${:__including_page}
    if {[$page exists __link_source]} {
      set page [$page set __link_source]
    }
    set package_id [::xo::cc package_id]

    set lang [::xo::cc lang]
    set return_url [::xo::cc url]
    set nls_language [$page get_nls_language_from_lang $lang]

    set :folder_form_id [::$package_id instantiate_forms -forms en:folder.form]
    set :link_form_id   [::$package_id instantiate_forms -forms en:link.form]

    #:msg folder_form=${:folder_form_id}

    set :current_folder [$page get_folder -folder_form_ids ${:folder_form_id}]
    set :current_folder_id [${:current_folder} item_id]

    #:msg "FOLDERS [$page name] package_id $package_id current_folder ${:current_folder} [${:current_folder} name]"

    if {[::$package_id get_parameter "MenuBar" 0]} {

      #
      # We want a menubar. Create a menubar object, which might be
      # configured via the menu_entries property in the current
      # folder.
      #
      set menu_entries [list \
                            {*}[::$package_id get_parameter ExtraMenuEntries {}] \
                            {*}[${:current_folder} property extra_menu_entries]]
      set have_config [lsearch -index 0 $menu_entries config]

      if {$have_config > -1} {
        #
        # We have a special configuration for the menubar, probably
        # consisting of a default setup and/or a menubar class. The
        # entry should be of the form:
        #
        #    {config -use xxxx -class MenuBar}
        #
        set properties [lrange [lindex $menu_entries $have_config] 1 end]
        if {[dict exists $properties -class]} {
          set p_class [dict get $properties -class]
        }
        foreach p {-class -use} {
          if {[dict exists $properties $p]} {
            set p$p [dict get $properties $p]
          }
        }
      }
      set class ::xowiki::MenuBar
      if {[info exists p-class]
          && [info commands ::xowiki::${p-class}]
          && [::xowiki::${p-class} istype ::xowiki::MenuBar]
        } {
        set class ::xowiki::${p-class}
      } else {
        set class ::xowiki::MenuBar
      }
      set mb [$class create ::__xowiki__MenuBar -id menubar]

      if {[info exists p-use]
          && [$mb procsearch config=${p-use}] ne ""
        } {
        set config ${p-use}
      } else {
        set config default
      }

      #
      # Now we have a menubar $mb. Add folder-specific content to it.
      #
      # "bind_vars" will contain the variables used by "make_link" to
      # set the query parameters.  We do not want to see parent_ids in
      # the links of the root folder. When we insert to the root
      # folder, set opt_parent_id to empty to make argument passing
      # easy. "make_link" just checks for the existence of the
      # variable, so no add "parent_id" to the "bind_vars".
      #

      if {[${:current_folder_id} is_package_root_folder]} {
        set opt_parent_id ""
        set folder_link [::$package_id package_url]
        set bind_vars {}
        #:msg "use instance name as title to [::$package_id instance_name]"
        ${:current_folder} title [::$package_id instance_name]
      } else {
        set parent_id ${:current_folder_id}
        set opt_parent_id $parent_id
        ::xo::db::CrClass get_instance_from_db -item_id $parent_id
        set folder_link [${:current_folder} pretty_link]
        set bind_vars [list parent_id $parent_id opt_parent_id $parent_id]
      }
      lappend bind_vars nls_language $nls_language

      set return_url [::xo::cc url]
      $mb current_folder ${:current_folder}
      $mb parent_id $opt_parent_id
      #:log "folders: call update_items with config '$config' bind_vars=$bind_vars"
      $mb update_items \
          -bind_vars $bind_vars \
          -config $config \
          -current_page $page \
          -folder_link $folder_link \
          -package_id $package_id \
          -return_url $return_url
    }

    # Start with the "package's folder" as root folder
    set root_folder [::xo::db::CrClass get_instance_from_db \
                         -item_id [::$package_id folder_id]]

    #
    # Check, if the optional context tree view is activated
    #
    set top_folder_of_tree $root_folder
    if {$context_tree_view || [::$package_id get_parameter FolderContextTreeView false]} {
      set parent_id [${:current_folder} parent_id]
      if {$parent_id ne -100} {
        set top_folder_of_tree $parent_id
        #:msg top_folder_of_tree=$top_folder_of_tree
      }
    }

    if {$top_folder_of_tree eq $root_folder
        || [$top_folder_of_tree parent_id] eq "-100"
      } {
      set href  [::$package_id package_url]
      set label [::$package_id instance_name]
      #:msg "use instance name in tree display"
    } else {
      set href  [$top_folder_of_tree pretty_link]
      set label "[$top_folder_of_tree title] ..."
    }

    set t [::xowiki::Tree new -id foldertree_[:id] -destroy_on_cleanup]
    set node [::xowiki::TreeNode new \
                  -href $href \
                  -label $label \
                  -highlight [expr {${:current_folder_id} == [$top_folder_of_tree item_id]}] \
                  -object $top_folder_of_tree \
                  -expanded 1 \
                  -orderby label \
                  -open_requests 1 \
                  -destroy_on_cleanup]
    $t add $node
    set folders [:collect_folders \
                     -package_id $package_id \
                     -folder_form_id ${:folder_form_id} \
                     -link_form_id ${:link_form_id}]

    #:msg "folder ${:folder_form_id} has [llength $folders] entries"
    #:msg [lmap f $folders {$f item_id}]

    :build_sub_tree -node $node -folders $folders
    return $t
  }

  folders instproc build_sub_tree {
    {-node}
    {-folders}

  } {
    :get_parameters

    set current_object [$node object]
    set current_item_id [$current_object item_id]
    set sub_folders [list]
    set remaining_folders [list]

    foreach f $folders {
      if {[$f parent_id] ne $current_item_id} {
        lappend remaining_folders $f
      } else {
        lappend sub_folders $f
      }
    }

    #:msg "[$node label] has [llength $sub_folders] subfolders"
    foreach c $sub_folders {

      set label [$c title]
      if {[regexp [lang::util::message_key_regexp] $label . innerValue]} {
        set label [_ $innerValue]
      }
      set folder_href [$c pretty_link]

      set is_current [expr {${:current_folder_id} eq [$c item_id]}]
      set is_open [expr {$is_current || $show_full_tree}]

      #regexp {^..:(.+)$} $label _ label

      set subnode [::xowiki::TreeNode new \
                       -href $folder_href \
                       -label $label \
                       -object $c \
                       -highlight $is_current \
                       -expanded $is_open \
                       -open_requests 1 \
                       -destroy_on_cleanup]
      $node add $subnode

      if {$is_current} {
        $node open_tree

        if {[nsf::is object ::__xowiki__MenuBar]
            && [::__xowiki__MenuBar exists submenu_pages(folder)]} {
          set owner [::__xowiki__MenuBar set submenu_owner(folder)]
          $subnode add_pages -full true \
              -book_mode [$owner set book_mode] \
              -owner $owner \
              [::__xowiki__MenuBar set submenu_pages(folder)]
        }
      }

      :build_sub_tree -node $subnode -folders $remaining_folders
    }
  }
}


namespace eval ::xowiki::includelet {

  ###########################################################
  #
  # ::xowiki::includelet::child-resources
  #
  ###########################################################
  ::xowiki::IncludeletClass create child-resources \
      -superclass ::xowiki::Includelet \
      -parameter {
        {
          parameter_declaration {
            {-skin:optional "yui-skin-sam"}
            {-show_types "::xowiki::Page,::xowiki::File,::xowiki::Form,::xowiki::FormPage"}
            {-regexp:optional}
            {-language_specific:boolean false}
            {-with_subtypes:boolean,optional false}
            {-orderby:token,optional "last_modified,desc"}
            {-publish_status:wordchar "ready"}
            {-view_target ""}
            {-html-content}
            {-parent .}
            {-columns {
              objects
              edit
              object_type
              name
              last_modified
              mod_user
              duplicate
              delete
            }}
            {-hide {}}
            {-menubar ""}
          }
        }
      } -ad_doc {

        Include the content of the current folder somewhat similar to explorer.

        @param show_types types of the pages to be included
        @param with_subtypes (default false)
        @param orderby order entries by the specified attribite (default last_modified,desc)
        @param publish_status show content with the provided publishstatuses (can be ored)
        @param parent folder (defaults to . (=current page as parent))
        @param columns columns to be displayed
        @param hide hide certain columns
        @param menubar include menubar optionally
        @param regepx SQL reqexp for filtering on content item names

      }

  child-resources instproc types_to_show {} {
    :get_parameters
    return [lsort -unique [split $show_types ,]]
  }

  child-resources instproc render {} {
    :get_parameters

    set current_folder ${:__including_page}
    #:log "child-resources: including_page current_folder $current_folder '[$current_folder name]'"

    if {$parent eq ".."} {
      set current_folder [$current_folder parent_id]
      ::xo::db::CrClass get_instance_from_db -item_id $current_folder
    } elseif {$parent eq "."} {
      # current_folder is already set
    } else {
      set lang [string range ${:locale} 0 1]
      set page [::$package_id get_page_from_item_ref \
                    -use_package_path true \
                    -use_site_wide_pages true \
                    -use_prototype_pages true \
                    -default_lang $lang \
                    -parent_id [$current_folder item_id] \
                    $parent]
      set current_folder $page
    }
    #:log "child-resources parent $parent, current_folder $current_folder '[$current_folder name]', folder is formPage [$current_folder istype ::xowiki::FormPage]"

    if {![$current_folder istype ::xowiki::FormPage]} {
      # current folder has to be a FormPage
      set current_folder [$current_folder parent_id]
      #:log "###### use parent of current folder $current_folder '[$current_folder name]'"

      if {![$current_folder istype ::xowiki::FormPage]} {
        error "child-resources not included from a FormPage"
      }
    }
    set :current_folder_id [$current_folder item_id]

    set logical_folder_id ${:current_folder_id}
    if {[$current_folder exists physical_item_id]} {
      set :current_folder_id [$current_folder set physical_item_id]
    }

    if {[::xo::cc query_parameter m] ne "list"} {
      set index [$current_folder property index]
      #:log "child-resources: current folder $current_folder has index <$index>"
      if {$index ne ""} {
        set download [string match "file:*" $index]
        #:log "child-resources: lookup index under [$current_folder item_id] ${:current_folder_id}"
        set index_link [::$package_id pretty_link \
                            -parent_id ${:current_folder_id} \
                            -download $download \
                            $index]
        return [::$package_id returnredirect $index_link]
      }
    }


    #::$package_id instvar package_key
    set current_folder_pretty_link [$current_folder pretty_link]
    set return_url [ad_return_url -default_url $current_folder_pretty_link]
    set category_url [export_vars -base [::$package_id package_url] {
      {manage-categories 1} {object_id $package_id}
    }]

    set all_columns {objects edit object_type name title last_modified mod_user duplicate delete}
    foreach column $all_columns {
      set ::hidden($column) [expr {$column ni $columns || $column in $hide}]
    }

    #
    # We have to use the global variable for the time being due to
    # scoping in "-columns"
    set ::__xowiki_with_publish_status [expr {
                                              $publish_status ne "ready"
                                              || "publish_status" in $columns}]

    # unexisting csrf token usually means we are outside a connection thread
    set csrf [expr {[info exists ::__csrf_token] ? [list __csrf_token $::__csrf_token] : ""}]
    set ::__xowiki_folder_link [::$package_id make_link \
                                    -link $current_folder_pretty_link \
                                    $current_folder bulk-delete $csrf return_url]
    switch [::$package_id get_parameter PreferredCSSToolkit bootstrap] {
      bootstrap {set tableWidgetClass ::xowiki::BootstrapTable}
      default   {set tableWidgetClass ::xowiki::YUIDataTable}
    }

    set t [$tableWidgetClass new -volatile -skin $skin \
               -columns {
                 BulkAction create objects -id ID -hide $::hidden(objects) -actions {
                   if {$::__xowiki_folder_link ne ""} {
                     Action bulk-delete \
                         -label [_ xowiki.delete] \
                         -tooltip [_ xowiki.Delete_selected] \
                         -url $::__xowiki_folder_link \
                         -confirm_message [_ xowiki.delete_confirm]
                   }
                 }

                 # The "-html" options are currently ignored in the YUI
                 # DataTable. Not sure, it can be integrated in the traditional way.
                 #
                 HiddenField create ID
                 AnchorField create edit -CSSclass edit-item-button -label "" \
                     -hide $::hidden(edit)
                 AnchorField create duplicate -CSSclass copy-item-button \
                     -hide $::hidden(duplicate) \
                     -label ""
                 if {$::__xowiki_with_publish_status} {
                   ImageAnchorField create publish_status -orderby publish_status.src -src "" \
                       -width 8 -height 8 -border 0 -title "Toggle Publish Status" \
                       -alt "publish status" -label "" ;#[_ xowiki.publish_status]
                 }
                 Field create object_type -label [_ xowiki.page_kind] -orderby object_type -richtext false \
                     -hide $::hidden(object_type)
                 AnchorField create name -label [_ xowiki.name] -orderby name \
                     -hide $::hidden(name)
                 AnchorField create title -label [_ xowiki.title] -orderby title \
                     -hide $::hidden(title)
                 Field create last_modified -label [_ xowiki.Page-last_modified] -orderby last_modified \
                     -hide $::hidden(last_modified)
                 Field create mod_user -label [_ xowiki.By_user] -orderby mod_user  -hide $::hidden(mod_user)
                 AnchorField create delete -CSSclass delete-item-button \
                     -hide $::hidden(delete) \
                     -label ""
               }]

    set extra_where_clause "true"
    # TODO: why filter on title and name?
    if {[info exists regexp]} {
      set extra_where_clause "(bt.title ~ '$regexp' OR ci.name ~ '$regexp' )"
    }

    if {$language_specific} {
      #
      # Setting the property language_specific does two things:
      # a) filter the entries by this language
      # b) change the title of the folder when a property ml_title is supplied.
      #
      set lang [string range [:locale] 0 1]
      set extra_where_clause "ci.name like '${lang}:%'"

      #
      # Update the title to a language-specific value
      #
      $current_folder update_langstring_property _title $lang
      :msg "$current_folder update_langstring_property _title $lang -> [$current_folder title]"
    }
    #:log "child-resources of folder_id ${:current_folder_id}"
    set items [::xowiki::FormPage get_all_children \
                   -folder_id ${:current_folder_id} \
                   -publish_status $publish_status \
                   -object_types [:types_to_show] \
                   -extra_where_clause $extra_where_clause]

    set package_id [::xo::cc package_id]
    set pkg ::$package_id
    set url [::xo::cc url]
    $pkg get_lang_and_name -default_lang "" -name [$current_folder name] lang name
    set folder [$pkg folder_path -parent_id [$current_folder parent_id]]
    set folder_ids [$items set folder_ids]

    foreach c [$items children] {
      set name [$c name]
      #:log "===###=== child-resources: get link for $name under ::$package_id logical_folder_id $logical_folder_id"
      #set ::DDD 1
      set page_link [::$package_id pretty_link \
                         -parent_id $logical_folder_id \
                         -context_url $url \
                         -folder_ids $folder_ids \
                         -path_encode false \
                         -page $c \
                         $name]
      #:log "===###=== child-resources: get link for $name under ::$package_id -> $page_link"
      #unset ::DDD
      set icon [$c render_icon]

      ad_try {
        set prettyName [$c pretty_name]
      } on error {errorMsg} {
        :msg "can't obtain pretty name of [$c item_id] [$c name]: $errorMsg"
        set prettyName $name
      }

      # -ID $page_link
      $t add \
          -ID [$c item_id] \
          -name $prettyName \
          -name.href [export_vars -base $page_link {template_file html-content}] \
          -name.title [$c set title] \
          -title [$c set title] \
          -title.href [export_vars -base $page_link {template_file html-content}] \
          -object_type [dict get $icon text] \
          -object_type.richtext [dict get $icon is_richtext] \
          -last_modified [$c set last_modified] \
          -edit "" \
          -edit.href [export_vars -base $page_link {{m edit} return_url}] \
          -edit.title #xowiki.edit# \
          -mod_user [::xo::get_user_name [$c set creation_user]] \
          -duplicate "" \
          -duplicate.href [export_vars -base $page_link {{m duplicate} return_url}] \
          -duplicate.title #xowiki.duplicate# \
          -delete "" \
          -delete.href [export_vars -base $page_link {{m delete} return_url}] \
          -delete.title #xowiki.delete#
      if {$::__xowiki_with_publish_status} {
        # TODO: this should get some architectural support
        if {[$c set publish_status] eq "ready"} {
          set image active.png
          set state "production"
        } else {
          set image inactive.png
          set state "ready"
        }
        set revision_id [$c set revision_id]
        [$t last_child] set publish_status.src /resources/xowiki/$image
        [$t last_child] set publish_status.href \
            [export_vars -base $page_link {{m toggle-publish-status} return_url}]
      }
    }

    lassign [split $orderby ,] att order
    if {$att in [$t column_names]} {
      $t orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att
    } else {
      ad_log warning "Ignore invalid sorting criterion '$att'"
      util_user_message -message "Ignore invalid sorting criterion '$att'"
    }

    # if {$menubar ne ""} {
    #   set mb [::xowiki::MenuBar new -id submenubar]
    #   # for now, just the first group
    #   lassign $menubar Menu entries
    #   $mb add_menu -name $Menu
    #   set menuEntries {}
    #   foreach e $entries {
    #     switch -- $e {
    #       ::xowiki::File {
    #         lappend menuEntries {entry -name New.File -label File -object_type ::xowiki::File}
    #       }
    #       default {ns_log notice "can't handle $e in submenubar so far"}
    #     }
    #   }
    #   ns_log notice "================= 2nd call update_items"
    #   $mb update_items \
    #       -package_id $package_id \
    #       -parent_id ${:current_folder_id} \
    #       -return_url $return_url \
    #       -nls_language [$current_folder get_nls_language_from_lang [::xo::cc lang]]
    #   set menubar [$mb render-preferred]
    # }
    ns_log notice "sub-menubar: 2nd update_items needed? menubar <$menubar>"
    set viewers [util_coalesce \
                     [$current_folder property viewers] \
                     [$current_folder get_parameter viewers]]
    set viewer_links ""
    foreach v $viewers {
      set wf_link "${v}?p.folder=[$current_folder name]"
      append wf_link "&m=create-or-use"
      append viewer_links [subst -nocommands -nobackslashes {
        <li><a href="[ns_quotehtml $wf_link]">view with $v</a></li>
      }]
    }
    return "$menubar<ul>$viewer_links</ul> [$t asHTML]"

  }
}

namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::menuentries
  #
  ###########################################################

  Class create menuentries -superclass textarea -parameter {
    {rows 10}
    {cols 80}
  }
  menuentries instproc pretty_value {v} {
    ${:object} do_substitutions 0
    return "<pre class='code'>[string map [list & {&amp;} < {&lt;} > {&gt;}]  [:value]]</pre>"
  }
}


::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

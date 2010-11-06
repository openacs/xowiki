::xo::library doc { 

  This is an experimental implemetation for folders
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
        }}
        {id "[xowiki::Includelet js_name [self]]"}
      }

  folders instproc include_head_entries {} {
    ::xowiki::Tree include_head_entries -renderer yuitree -style folders
  }

  folders instproc render {} {
    my get_parameters
    set js "
      var [my js_name];
      YAHOO.util.Event.onDOMReady(function() {
         [my js_name] = new YAHOO.widget.TreeView('foldertree_[my id]'); 
         [my js_name].subscribe('clickEvent',function(oArgs) { 
            var m = /href=\"(\[^\"\]+)\"/.exec(oArgs.node.html);
            return false;
          });
         [my js_name].render();
      });
     "
    return [[my build_tree] render -style yuitree -js $js]
  }

  folders instproc collect_folders {
    -package_id:required
    -folder_form_id:required
    -link_form_id:required
    {-subtree_query ""}
    {-depth 3}
  } {
    set folders [list]

    # safety belt, for recursive structures
    if {$depth < 1} {return $folders}

    #
    # get folders
    #
    set folder_pages [::xowiki::FormPage get_form_entries \
                          -base_item_ids $folder_form_id -form_fields "" \
			  -extra_where_clause $subtree_query \
                          -publish_status ready -package_id $package_id]
    #
    # get links
    #
    set links [::xowiki::FormPage get_form_entries \
		   -base_item_ids $link_form_id -form_fields "" \
		   -extra_where_clause $subtree_query \
		   -publish_status ready -package_id $package_id]
    #my msg "[llength [$links children]] links"

    set folders [$folder_pages children]
    my instvar current_folder_id

    #
    # filter links to folders.
    # links might be cross-package links
    #
    foreach l [$links children] {
      set link_type [$l get_property_from_link_page link_type]
      set cross_package [$l get_property_from_link_page cross_package]

      if {$link_type ne "folder_link"} continue

      if {$cross_package} {
	#
	# we found a cross-package link. These kind of links require further queries
	#
	set target [$l get_target_from_link_page]

	# the following clause needs an oracle counter-part
	set tree_sortkey [db_string get_tree_sort_key "select tree_sortkey from acs_objects where object_id = [$target item_id]"]
	set extra_where "and bt.item_id in (select object_id from acs_objects \
		where tree_sortkey between '$tree_sortkey' and tree_right('$tree_sortkey') \
		and object_type = 'content_item')"

	set sub_folders [my collect_folders -package_id [$target package_id] \
			     -folder_form_id $folder_form_id -link_form_id $link_form_id \
			     -subtree_query $extra_where -depth [expr {$depth -1}]]


	foreach f $sub_folders {

	  #my msg "$f [$f name] is a folder-link pointing to $target [$target name] current $current_folder_id"
	  if {[$f parent_id] eq [$target item_id]} {
	    #my msg "1 found child [$f name] and reset parent_id from [$f parent_id] to [$l item_id], package_id [$l package_id]"
	    #
	    # reset the current_folder if necessary
	    # 
	    if {$current_folder_id eq [$f parent_id]} {set current_folder_id [$l item_id]}
	    #
	    # set the resolve_context
	    #
	    $f set_resolve_context -package_id [$l package_id] -parent_id [$l item_id]
	    #
	    # TODO we could save the double-fetch by collecing in get_form_entries via item-ids, not via new-objects
	    #
	    ::xo::db::CrClass get_instance_from_db -item_id [$f item_id]
	    [$f item_id] set_resolve_context -package_id [$l package_id] -parent_id [$l item_id]
	  } else {
	    #my msg "2 found child [$f name] and reset parent_id from [$f parent_id] to [$f parent_id], package id [$l package_id]"
	    $f set_resolve_context -package_id [$l package_id] -parent_id [$f parent_id]
	    ::xo::db::CrClass get_instance_from_db -item_id [$f item_id]
	    [$f item_id] set_resolve_context -package_id [$l package_id] -parent_id [$f parent_id]
	  }

	  #my msg "including $f [$f name] [$f item_id]"
	  lappend folders $f
	}
      }
      #my msg link=$link
      lappend folders $l
    }
    return $folders
  }

  folders instproc build_tree {} {
    my instvar current_folder current_folder_id folder_form_id link_form_id
    my get_parameters

    set with_links 0

    set page [my set __including_page]
    set package_id [::xo::cc package_id]
    #my ds [::xo::cc serialize]
    set lang [::xo::cc lang]
    #set lang en
    set return_url [::xo::cc url]
    set nls_language [$page get_nls_language_from_lang $lang]

    set folder_form_id [::xowiki::Weblog instantiate_forms -forms en:folder.form \
                            -package_id $package_id]
    set link_form_id   [::xowiki::Weblog instantiate_forms -forms en:link.form \
                            -package_id $package_id]
    #my log folder_form=[my set folder_form_id]

    set current_folder [$page get_folder -folder_form_ids $folder_form_id]
    set current_folder_id [$current_folder item_id]

    #my msg "FOLDERS [$page name] package_id $package_id current_folder $current_folder [$current_folder name]"

    # Start with the "package's folder" as root folder
    set root_folder_id [::$package_id folder_id]
    set root_folder [::xo::db::CrClass get_instance_from_db -item_id $root_folder_id]
    set root_folder_is_current [expr {$current_folder_id == [$root_folder item_id]}]

    set mb [info command ::__xowiki__MenuBar]
    if {$mb ne ""} {
      #
      # We have a menubar. Add folder-specific content to the
      # menubar. 
      #
      if {$root_folder_is_current} {
	#
	# We do not want to see unneeded parent_ids in the links. When
	# we insert to the root folder, set opt_parent_id to empty to
	# make argument passing easy. "make_link" just checks for the
	# existance of the variable, so we unset parent_id in this case.
	#
        set opt_parent_id ""
	set folder_link [$package_id package_url]
        if {[info exists parent_id]} {unset parent_id}
      } else {
	set parent_id $current_folder_id
        set opt_parent_id $parent_id
        ::xo::db::CrClass get_instance_from_db -item_id $parent_id
	set folder_link [$current_folder pretty_link]
      }
      set return_url [::xo::cc url]
      set new_folder_link [$package_id make_form_link -form en:folder.form \
                               -parent_id $opt_parent_id \
                               -return_url $return_url]
      if {$with_links} {
	set new_sym_link [$package_id make_form_link -form en:link.form \
			      -parent_id $opt_parent_id \
			      -nls_language $nls_language -return_url $return_url]
      }
#       set new_page_link [$package_id make_link -with_entities 0 \
#                              $package_id edit-new \
#                              {object_type ::xowiki::Page} \
#                              parent_id return_url autoname template_file]

      set new_page_link [$package_id make_form_link -form en:page.form \
			     -parent_id $opt_parent_id \
			     -return_url $return_url]
      set new_file_link [$package_id make_link -with_entities 0 \
                             $package_id edit-new \
                             {object_type ::xowiki::File} \
                             parent_id return_url autoname template_file]
      set new_form_link [$package_id make_link -with_entities 0 \
			     $package_id edit-new \
			     {object_type ::xowiki::Form} \
			     parent_id return_url autoname template_file]
      set import_link  [$package_id make_link -privilege admin \
                            -link "admin/import" $package_id {} parent_id return_url]
      set import_archive_link [$package_id make_form_link -form en:import-archive.form \
				    -parent_id $opt_parent_id]

      set index_link [$package_id make_link -link $folder_link $current_folder list]

      $mb add_menu_item -name Package.Startpage \
          -item [list text #xowiki.index# url $index_link]

      $mb add_menu_item -name New.Page \
          -item [list text #xowiki.new# url $new_page_link]
      $mb add_menu_item -name New.File \
          -item [list text File url $new_file_link]
      $mb add_menu_item -name New.Folder \
          -item [list text Folder url $new_folder_link]
      if {$with_links} {
	$mb add_menu_item -name New.SymLink    \
	    -item [list text SymLink url $new_sym_link]
      }
      $mb add_menu_item -name New.Form \
	  -item [list text Form url $new_form_link]
      $mb add_menu_item -name Package.ImportDump -item [list url $import_link]
      $mb add_menu_item -name Package.ImportArchive -item [list url $import_archive_link]

      if {[::xowiki::clipboard is_empty]} {
	set clipboard_copy_link ""
	set clipboard_export_link ""
	set clipboard_content_link ""
	set clipboard_clear_link ""
      } else {
	# todo: check, whether the use is allowed to insert into the current folder
	set clipboard_copy_link [$current_folder pretty_link]?m=clipboard-copy
	set clipboard_export_link [$current_folder pretty_link]?m=clipboard-export
	set clipboard_content_link [$current_folder pretty_link]?m=clipboard-content
	set clipboard_clear_link [$current_folder pretty_link]?m=clipboard-clear
      }
      # todo: we should check either, whether to user is allowed to
      # copy-to-clipboard from the current folder, and/or the user is
      # allowed to do this with certain items.... (the latter in
      # clipboad-add)
      $mb add_menu_item -name Clipboard.Add \
          -item [list url javascript:acs_ListBulkActionClick("objects","$folder_link?m=clipboard-add")]
      $mb add_menu_item -name Clipboard.Content -item [list url $clipboard_content_link]
      $mb add_menu_item -name Clipboard.Clear -item [list url $clipboard_clear_link]
      $mb add_menu_item -name Clipboard.Use.Copy -item [list url $clipboard_copy_link]
      $mb add_menu_item -name Clipboard.Use.Export -item [list url $clipboard_export_link]

      # A folder page can contain extra menu entries (sample
      # below). Iterate of the extra_menu property and add according
      # menu entries.
      foreach me [$current_folder property extra_menu_entries] {
        array unset ""
        set kind [lindex $me 0]
        if {[string range $kind 0 0] eq "#"} continue
        switch $kind {
          clear_menu {
            # sample entry: clear_menu -menu New
            array set "" [lrange $me 1 end]
            $mb clear_menu -menu $(-menu)
          }

          form_link -
          entry {
            # sample entry: form_entry -name New.YouTubeLink -label YouTube -form en:YouTube.form
	    if {$kind eq "form_link"} {
	      my log "$me, name 'form_link' is deprecated, use 'entry' instead"
	    }
            array set "" [lrange $me 1 end]
	    if {[info exists (-form)]} {
	      set link [$package_id make_form_link -form $(-form) \
			    -parent_id $opt_parent_id \
			    -nls_language $nls_language -return_url $return_url]
	    } elseif {[info exists (-object_type)]} {
	      set link [$package_id make_link -with_entities 0 \
			    $package_id edit-new \
			    [list object_type $(-object_type)] \
			    parent_id return_url autoname template_file]
	    } else {
	      my log "Warning: no link specified"
	      set link ""
	    }
	    set item [list url $link]
	    if {[info exists (-label)]} {lappend item text $(-label)}
            $mb add_menu_item -name $(-name) -item $item
          }

          default { error "unknown kind of menu entry: $kind" }
        }
      }
    }

    set t [::xowiki::Tree new -id foldertree_[my id] ]
    set node [::xowiki::TreeNode new \
                -href [::$package_id package_url] \
                -label [::$package_id instance_name] \
                -highlight $root_folder_is_current \
                -object $root_folder \
                -expanded 1 \
                -open_requests 1]
    $t add $node
    set folders [my collect_folders \
		     -package_id $package_id \
		     -folder_form_id $folder_form_id \
		     -link_form_id $link_form_id]

    #my msg "folder [my set folder_form_id] has [llength $folders] entries"
    #foreach f $folders {lappend _ [$f item_id]}; my msg $_

    my build_sub_tree -node $node -folders $folders
    return $t
  }

  folders instproc build_sub_tree { 
    {-node}
    {-folders}

  } {
    my get_parameters
    my instvar current_folder_id

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

    foreach c $sub_folders {

      set label [$c title]
      set object $c
      set folder_href [$c pretty_link]

      set is_current [expr {$current_folder_id eq [$c item_id]}]
      set is_open [expr {$is_current || $show_full_tree}]

      #regexp {^..:(.+)$} $label _ label

      set subnode [::xowiki::TreeNode new \
                       -href $folder_href \
                       -label $label \
                       -object $c \
                       -highlight $is_current \
                       -expanded $is_open \
                       -open_requests 1]
      $node add $subnode

      if {$is_current} {
	$node open_tree

	if {[info command ::__xowiki__MenuBar] ne "" 
	    && [::__xowiki__MenuBar exists submenu_pages(folder)]} {
	  set owner [::__xowiki__MenuBar set submenu_owner(folder)]
	  $subnode add_pages -full true \
	      -book_mode [$owner set book_mode] \
	      -owner $owner \
	      [::__xowiki__MenuBar set submenu_pages(folder)]
	}
      }

      my build_sub_tree -node $subnode -folders $remaining_folders
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
            {-with_subtypes:optional false}
            {-orderby:optional "last_modified,desc"}
            {-publish_status "ready"}
            {-view_target ""}
          }
        }
      }
  
  child-resources instproc types_to_show {} {
    my get_parameters
    foreach type [split $show_types ,] {set ($type) 1}
    return [lsort [array names ""]]
  }

  child-resources instproc render {} {
    my get_parameters

    set current_folder [my set __including_page]
    set current_folder_id [$current_folder item_id]

    if {[::xo::cc query_parameter m] ne "list"} {
      set index [$current_folder property index]
      if {$index ne ""} {
	set index_link [$package_id pretty_link -parent_id [$current_folder item_id] $index]
	return [$package_id returnredirect $index_link]
      }
    }

    set logical_folder_id $current_folder_id
    if {[$current_folder exists physical_item_id]} {
      #my msg "!!! $current_folder_id to [$current_folder set physical_item_id]"
      set current_folder_id [$current_folder set physical_item_id]
    }
    #my msg "current_folder_id $current_folder_id logical_folder_id $logical_folder_id"

    $package_id instvar package_key

    set return_url [::xo::cc url] ;#"[$package_id package_url]edit-done"
    set category_url [export_vars -base [$package_id package_url] { {manage-categories 1} {object_id $package_id}}]

    set t [::YUI::DataTable new -skin $skin -volatile \
               -columns {
                 BulkAction objects -id ID -actions {
                   Action new -label select -tooltip select -url admin/select
                 }
		 # The "-html" options are currenty ignored in the YUI
		 # DataTable. Not sure, it can be integrated in the traditional way. 
		 #
		 # A full example for skinning the datatable is here:
		 # http://developer.yahoo.com/yui/examples/datatable/dt_skinning.html
		 #
                 HiddenField ID
                 AnchorField edit -CSSclass edit-item-button -label "" \
                     -html {style "padding: 0px;"}
                 Field object_type -label [_ xowiki.page_kind] -orderby object_type -richtext false \
                     -html {style "padding: 0px;"}
		 AnchorField name -label [_ xowiki.Page-name] -orderby name \
		     -html {style "padding: 2px;"}
                 Field last_modified -label [_ xowiki.Page-last_modified] -orderby last_modified
                 AnchorField delete -CSSclass delete-item-button \
                     -label "" ;#-html {onClick "return(confirm('Confirm delete?'));"}
               }]


    set where_clause "true"
    # TODO: why filter on title and name?
    if {[my exists regexp]} {set where_clause "(bt.title ~ '$regexp' OR ci.name ~ '$regexp' )"}

    set publish_status_clause [::xowiki::Includelet publish_status_clause $publish_status]

    foreach object_type [my types_to_show] {
      set attributes [list revision_id creation_user title parent_id \
                          "to_char(last_modified,'YYYY-MM-DD HH24:MI') as last_modified" ]
      if {$object_type eq "::xowiki::FormPage"} {
        set attributes "* $attributes"
        set base_table [$object_type set table_name]i
      } else {
        set base_table cr_revisions
      }
      set items [$object_type get_instances_from_db \
                   -folder_id $current_folder_id \
                   -with_subtypes false \
                   -select_attributes $attributes \
                   -where_clause "$where_clause $publish_status_clause" \
                   -base_table $base_table]

      foreach c [$items children] {
	set name [$c name]
        set page_link [::$package_id pretty_link -parent_id $logical_folder_id $name]
	array set icon [$c render_icon]
        
        $t add \
            -ID [$c name] \
            -name [$c pretty_name] \
	    -name.href [export_vars -base $page_link {template_file}] \
            -name.title [$c set title] \
            -object_type $icon(text) \
            -object_type.richtext $icon(is_richtext) \
            -last_modified [$c set last_modified] \
            -edit "" \
            -edit.href [export_vars -base $page_link {{m edit} return_url}] \
            -edit.title #xowiki.edit# \
            -delete "" \
            -delete.href [export_vars -base  [$package_id package_url] \
			      [list {delete 1} \
				   [list item_id [$c item_id]] \
				   [list name [$c pretty_link]] return_url]] \
            -delete.title #xowiki.delete#
      }
    }

    foreach {att order} [split $orderby ,] break
    $t orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att
    set resources_list [$t asHTML]
    return [$t asHTML]
  }
}

namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::menuentries
  #
  ###########################################################

  Class menuentries -superclass textarea -parameter {
    {rows 10}
    {cols 80}
  }
  menuentries instproc pretty_value {v} {
    [my object] do_substitutions 0
    return "<pre class='code'>[string map [list & {&amp;} < {&lt;} > {&gt;}]  [my value]]</pre>"
  }
}

#####################
#                   #
#   YUI stuff       #
#                   #
#####################

namespace eval ::YUI {

    Object loader -ad_doc {
        The YUI Library comes with a "Loader" module, that resolves YUI-module
        dependencies. Also, it combines numerous files into one single file to
        increase page loading performance.
        This works only for the "hosted" YUI library. This Loader module should
        basically do the same (in future). For two simple calls like e.g. 
        "::YUI::loader require menu" and "::YUI::loader require datatable"
        it should take care of selecting all the files needed and assemble them
        into one single resource, that may be delivered.
        Note, that this is not implemented yet.
    }

    loader set ajaxhelper 1

    # TODO: Make "::YUI::loader require -module XYZ" work everywhere "out-of-the-box"
    #       Now, as we use "::xo:Page require_JS" we have to include the generated
    #       header_stuff "manually" (e.g. in tcl-adp pairs),  whereas ::template::head...
    #       includes it directly, which is nice.

    loader ad_proc require {
        -module
        {-version "2.7.0b"}
      } {
        This is the key function of the loader, that will be used by other packages.
        @param module 
            The YUI Module to be loaded
      } {
        my instvar ajaxhelper
        switch -- [string tolower $module] {

            utilities {
                # utilities.js: The utilities.js aggregate combines the Yahoo Global Object,
                # Dom Collection, Event Utility, Element Utility, Connection Manager,
                # Drag & Drop Utility, Animation Utility, YUI Loader and the Get Utility.
                # Use this file to reduce HTTP requests whenever you are including more
                # than three of its constituent components.
                ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "yahoo-dom-event/yahoo-dom-event.js"
                ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "utilities/utilities.js"
            }
            menubar {
              #
              # We should not have two different versions of the YUI
              # library on one page, because YUI2 (afaik) doesnt support
              # "sandboxing". If we use e.g. the yui-hosted utilities.js file here
              # we may end up with two YAHOO object definitions, because e.g.
              # the tree-procs uses the local yahoo-dom-event.

              # In future, the YUI loader object should be capable of
              # resolving such conflicts. for now, the simple fix is to stick to
              # the local versions, because then the requireJS function takes care
              # of duplicates.
              #
              my require -module "utilities"
              # todo : this is more than necessary
              foreach jsFile {
                "container/container-min.js"
                "treeview/treeview-min.js"
                "button/button-min.js"
                "menu/menu-min.js"
                "datasource/datasource-min.js"
                "autocomplete/autocomplete-min.js"
                "datatable/datatable-min.js"
                "selector/selector-min.js"
              } {
                ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper $jsFile
              }

              my require -module "reset-fonts-grids"
              my require -module "base"

              foreach cssFile {
                "container/assets/container.css"
                "datatable/assets/skins/sam/datatable.css"
                "button/assets/skins/sam/button.css"
                "assets/skins/sam/skin.css"
                "menu/assets/skins/sam/menu.css"
              } {
                ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper $cssFile
              }
              ::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "treeview/assets/folders/tree.css"
            }
            datatable {
              # see comment above
              my require -module "utilities"
              # todo : this is more than necessary
              foreach jsFile {
                "container/container-min.js"
                "treeview/treeview-min.js"
                "button/button-min.js"
                "menu/menu-min.js"
                "datasource/datasource-min.js"
                "autocomplete/autocomplete-min.js"
                "datatable/datatable-min.js"
                "selector/selector-min.js"
              } {
                ::xowiki::Includelet require_YUI_JS -version "2.7.0b" -ajaxhelper $ajaxhelper $jsFile
              }

              my require -module "reset-fonts-grids"
              my require -module "base"

              foreach cssFile {
                "container/assets/container.css"
                "datatable/assets/skins/sam/datatable.css"
                "button/assets/skins/sam/button.css"
                "assets/skins/sam/skin.css"
                "menu/assets/skins/sam/menu.css"
              } {
                ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper $cssFile
              }
              #::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "treeview/assets/skins/sam/treeview.css"
              #::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "treeview/assets/folders/tree.css"
            }
            reset {
              ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "reset/reset.css"
            }
            fonts {
              ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "fonts/fonts.css"
            }
            grids {
              ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "grids/grids.css"
            }
            base {
              ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "base/base.css"
            }
            "reset-fonts-grids" {
              ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "reset-fonts-grids/reset-fonts-grids.css"
            }
        }
    }

    Class DataTable \
        -superclass ::xo::Table \
        -parameter {
            {skin "yui-skin-sam"}
        }

    DataTable instproc init {} {
        set trn_mixin [expr {[lang::util::translator_mode_p] ?"::xo::TRN-Mode" : ""}]
        my render_with YUIDataTableRenderer $trn_mixin
        next
    }

    Class AnchorField \
       -superclass ::xo::Table::AnchorField \
        -ad_doc "
            In addition to the standard TableWidget's AnchorField, we also allow the attributes
            <ul>
                <li>onclick
                <li>target
            </ul>
        " \
       -instproc get-slots {} {
         set slots [list -[my name]]
         foreach subfield {href title CSSclass target onclick} {
           lappend slots [list -[my name].$subfield ""]
         }
         return $slots
       }
}

# TODO Allow renderers from other namespaces in 30-widget-procs

namespace eval ::xo::Table {

    Class create YUIDataTableRenderer \
        -superclass TABLE3 \
        -instproc init_renderer {} {
            next
            my set css.table-class list-table
            my set css.tr.even-class even
            my set css.tr.odd-class odd
          my set id [::xowiki::Includelet js_name [::xowiki::Includelet html_id [self]]]
        }

    YUIDataTableRenderer ad_instproc -private render_yui_js {} {
        Generates the JavaScript fragment, that is put below and
        (progressively enhances) the HTML table.
      } {
        my instvar id
        set container   ${id}_container
        set datasource  ${id}_datasource
        set datatable   ${id}_datatable
        set coldef      ${id}_coldef

        set js      "var $datasource = new YAHOO.util.DataSource(YAHOO.util.Dom.get('$id')); \n"
        append js   "$datasource.responseType = YAHOO.util.DataSource.TYPE_HTMLTABLE; \n"
        append js   "$datasource.responseSchema = \{ \n"
        append js   "   fields: \[ \n"
	set js_fields [list]
        foreach field [[self]::__columns children] {
          lappend js_fields "       \{ key: \"[$field set name]\" \}"
        }
	append js [join $js_fields ", "] "   \] \n\};\n"
        append js "var $coldef = \[\n"
	set js_fields [list]
        foreach field [[self]::__columns children] {
	  if {[$field istype HiddenField]} continue
	  if {[$field istype BulkAction]} {
            set label "<input type='checkbox' onclick='acs_ListCheckAll(\\\"objects\\\",this.checked)'></input>"
	    set sortable false
	  } else {
	    set label [$field label]
	    set sortable [expr {[$field exists sortable] ? [$field set sortable] : true}]
	  }
          lappend js_fields "    \{ key: \"[$field set name]\" , sortable: $sortable, label: \"$label\" \}"
        }
        append js  [join $js_fields ", "] "\];\n"
        append js  "var $datatable = new YAHOO.widget.DataTable('$container', $coldef, $datasource);\n"
        return $js
    }

    YUIDataTableRenderer instproc render-body {} {
        html::thead {
            html::tr -class list-header {
                foreach o [[self]::__columns children] {
                    $o render
                }
            }
        }
        set children [my children]
        html::tbody {
            foreach line [my children] {
                html::tr -class [expr {[my incr __rowcount]%2 ? [my set css.tr.odd-class] : [my set css.tr.even-class] }] {
                    foreach field [[self]::__columns children] {
                        html::td  [concat [list class list] [$field html]] { 
                            $field render-data $line
                        }
                    }
                }
            }
        }
    }

    YUIDataTableRenderer instproc render {} {
        ::YUI::loader require -module "datatable"
        if {![my isobject [self]::__actions]} {my actions {}}
        if {![my isobject [self]::__bulkactions]} {my __bulkactions {}}
        set bulkactions [[self]::__bulkactions children]
        if {[llength $bulkactions]>0} {
          set name [[self]::__bulkactions set __identifier]
        } else {
          set name [::xowiki::Includelet js_name [self]]
        }
        # TODO: maybe use skin everywhere? hen to use style/CSSclass or skin?
        set skin [expr {[my exists skin] ? [my set skin] : ""}]
        html::div -id [my set id]_wrapper -class $skin {
	    html::form -name $name -id $name -method POST { 
	        html::div -id [my set id]_container {
                    html::table -id [my set id] -class [my set css.table-class] {
                        # TODO do i need that?
                        my render-actions
                        my render-body
                    }
                    if {[llength $bulkactions]>0} { my render-bulkactions }
                }
            }
	    ::xo::Page requireJS "YAHOO.util.Event.onDOMReady(function () {\n[my render_yui_js]});"
        }
    }


    #Class create YUIDataTableRenderer::AnchorField -superclass TABLE::AnchorField

    Class create YUIDataTableRenderer::AnchorField \
        -superclass TABLE::Field \
        -ad_doc "
            In addition to the standard TableWidget's AnchorField, we also allow the attributes
            <ul>
                <li>onclick
                <li>target
            </ul>
        " \
        -instproc render-data {line} {
        if {[$line exists [my name].href] &&
            [set href [$line set [my name].href]] ne ""} {
                # use the CSS class rather from the Field than not the line
                my instvar CSSclass
                $line instvar   [list [my name].title title] \
                                [list [my name].target target] \
                                [list [my name].onclick onclick] 
                html::a [my get_local_attributes href title {CSSclass class} target onclick] {
                    return "[next]"
                }
            }
        next
    }

    Class create YUIDataTableRenderer::Action -superclass TABLE::Action
    Class create YUIDataTableRenderer::Field -superclass TABLE::Field
    Class create YUIDataTableRenderer::HiddenField -superclass TABLE::HiddenField
    Class create YUIDataTableRenderer::ImageField -superclass TABLE::ImageField
    Class create YUIDataTableRenderer::ImageAnchorField -superclass TABLE::ImageAnchorField
    Class create YUIDataTableRenderer::BulkAction -superclass TABLE::BulkAction
}

::xo::library source_dependent 

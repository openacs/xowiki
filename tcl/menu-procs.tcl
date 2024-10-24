::xo::library doc {

  Basic classes for Menus (context menu, menu bar, menu item).  The
  design is influenced by the YUI2 classes, but we tried to keep the
  implementation generic. The original version was developed by Michael
  Aram in his Master Thesis. Over the time it was simplified,
  downstripped and refactored by Gustaf Neumann. The currently
  preferred interface is the class.

  @author Michael Aram
  @author Gustaf Neumann
}

namespace eval ::xowiki {

  #
  # MenuComponent
  #
  ::xo::tdom::Class create MenuComponent \
      -superclass ::xo::tdom::Object

  MenuComponent instproc js_name {} {
    return [::xowiki::Includelet js_name [self]]
  }
  MenuComponent instproc html_id {} {
    return [::xowiki::Includelet html_id [self]]
  }

  #
  # Menu
  #
  ::xo::tdom::Class create Menu \
      -superclass MenuComponent \
      -parameter {
        {id "[:html_id]"}
        CSSclass
      }

  Menu ad_instproc render {} {doku} {
    html::ul [:get_attributes id {CSSclass class}] {
      foreach menuitem [:children] {$menuitem render}
    }
  }

  #
  # MenuItem
  #
  ::xo::tdom::Class create MenuItem \
      -superclass MenuComponent \
      -parameter {
        text
        href
        title
        {id "[:html_id]"}
        CSSclass
        style
        linkclass
        target
        {group ""}
        {listener}
      }


  MenuItem ad_instproc -private init args {doku} {
    next
    # Use computed default values when not specified
    if {![info exists :title]} {
      # set the mouseover-title to the "MenuItem-Label"
      # TODO: Do we really want "text" to be required ?
      set :title ${:text}
    }
    if {![info exists :CSSclass]} {
      # set the CSS class to e.g. "yuimenuitem"
      set :CSSclass [string tolower [namespace tail [:info class]]]
    }

    if {![info exists :href] || ${:href} eq ""} {
      append :CSSclass " " [string tolower [namespace tail [:info class]]]-disabled
    }
    if {![info exists :linkclass]} {
      # set the CSS class to e.g. "yuimenuitemlabel"
      set :linkclass [string tolower [namespace tail [:info class]]]label
    }
  }

  MenuItem ad_instproc render {} {doku} {
    html::li [:get_attributes id {CSSclass class}] {
      html::a [:get_attributes title href target] {
        html::t ${:text}
      }
    }
  }


  #
  # Simple Generic MenuBar
  #
  # Class for creating and updating Menubars in an incremental
  # fashion. Menu handling works as following:
  #
  #   1) Create an ::xowiki::MenuBar instance
  #
  #   2) Create menus via the "add_menu" method.  The order of the
  #      creation commands determine the order of the menu buttons.
  #
  #   3) Add/update menuentries via the "add_menu_item" method.  The
  #      provided name determines the menu to which the entry is
  #      added. The following example adds a menu entry "StartPage" to
  #      the menu "Package":
  #
  #        $mb add_menu_item -name Package.Startpage \
  #             -item [list label t #xowiki.index# url $index_link]
  #
  #   4) After all updates are performed, use "render-preferred" to obtain
  #      the HTML rendering of the menu.
  #
  # Follow the following naming conventions:
  #  1) All menu names must start with a capital letter
  #  2) All menu entry names must start with a capital letter
  #  3) All menu entry names should be named after the menu name
  #
  # Notice: the current implementation uses internally dicts. Since the
  # code should as well work with Tcl 8.4 instances, we provide a
  # compatibility layer. Maybe it would be better to base the code on
  # an ordered composite. Ideally, the interface should stay mostly
  # compatible.
  #
  # Gustaf Neumann, May 31, 2010

  Class create ::xowiki::MenuBar -parameter {
    id
    {dropzone:boolean true}
    {current_folder:object}
    {parent_id:integer,0..1 ""}
  }

  ::xowiki::MenuBar instproc get_prop {dict key {default ""}} {
    if {![dict exists $dict $key]} {
      return $default
    }
    return [dict get $dict $key]
  }

  ::xowiki::MenuBar instproc init {} {
    set :Menus [list]
    :destroy_on_cleanup
  }

  ::xowiki::MenuBar instproc add_menu {-name {-label ""}} {
    if {$name in ${:Menus}} {
      error "menu $name exists already"
    }
    if {[string match {[a-z]*} $name]} {
      error "names must start with uppercase, provided name '$name'"
    }
    lappend :Menus $name
    if {$label eq ""} {set label $name}
    set :Menu($name) [list label $label]
    #:log "menus: ${:Menus}"
  }

  ::xowiki::MenuBar instproc additional_sub_menu {-kind:required -pages:required -owner:required} {
    set :submenu_pages($kind) $pages
    set :submenu_owner($kind) $owner
  }

  ::xowiki::MenuBar instproc clear_menu {-menu:required} {
    set :Menu($menu) [list label [dict get [set :Menu($menu)] label]]
  }

  ::xowiki::MenuBar instproc add_menu_item {
    -name:required
    -item:required
  } {
    #
    # The provided items are of the form of attribute-value pairs
    # containing at least attributes "label" and "url"
    #   (e.g. "label .... url ....").
    #
    set full_name $name
    if {![regexp {^([^.]+)[.](.+)$} $name _ menu name]} {
      error "menu item name '$name' not of the form Menu.Name"
    }
    if {$menu ni ${:Menus}} {
      error "menu $menu does not exist"
    }
    if {[string match {[a-z]*} $name]} {
      error "names must start with uppercase, provided name '$name'"
    }

    #
    # get group name (syntax: Menu.Group.Item)
    #
    set group_name ""
    regexp {^[^.]+[.]([^.]+)[.].*} $full_name _ group_name
    #
    # provide a default label
    #
    regsub -all -- {[.]} $full_name - full_name
    set item [dict merge [list label "#xowiki.menu-$full_name#" group $group_name] $item]

    #
    # If an entry with the given name exists, update it. Otherwise add
    # such an entry.
    #
    set updated 0
    set newitems [list]
    foreach {n i} [set :Menu($menu)] {
      if {$n eq $name} {
        lappend newitems $name $item
        set updated 1
      } else {
        lappend newitems $n $i
      }
    }
    if {$updated} {
      set :Menu($menu) $newitems
    } else {
      lappend :Menu($menu) $name $item
    }
  }

  ::xowiki::MenuBar instproc add_extra_item {
    -name:required
    -type:required
    -item:required
  } {
    if {$type ni {"DropZone" "ModeButton"}} {
      error "unknown extra item type: $type"
    }
    set :${type}($name) $item
  }


  ::xowiki::MenuBar instproc config_menu=Package {
    -folder_link:required
    -return_url_required
    -package_id:required
    {-bind_vars {}}
  } {

    set index_link [::$package_id make_link \
                        -link $folder_link \
                        ${:current_folder} list]

    set admin_link [::$package_id make_link -privilege admin \
                        -link admin/ ::$package_id]
    dict with bind_vars {
      set import_link \
          [::$package_id make_link -privilege admin \
               -link "admin/import" \
               ::$package_id {} parent_id return_url]

      set import_archive_link \
          [::$package_id make_form_link -form en:import-archive.form \
               -parent_id ${:parent_id}]
    }

    :add_menu_item -name Package.Startpage -item [list url $folder_link]
    :add_menu_item -name Package.Toc -item [list url $index_link]

    if {[::$package_id get_parameter with_notifications:boolean 1]} {
      if {[::xo::cc user_id] != 0} {
        #
        # notifications require login
        #
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_type [notification::type::get_type_id -short_name xowiki_notif]
        set notification_text "Subscribe to [::$package_id instance_name]"
        set notification_subscribe_link \
                                         [export_vars -base /notifications/request-new \
                                              {{return_url $notifications_return_url}
                                                {pretty_name $notification_text}
                                                {type_id $notification_type}
                                                {object_id $package_id}}]
        :add_menu_item -name Package.Notifications \
            -item [list url /notifications/manage]
      }
    }

    :add_menu_item -name Package.Admin \
        -item [list text #xowiki.admin# url $admin_link]
    :add_menu_item -name Package.ImportDump -item [list url $import_link]
    :add_menu_item -name Package.ImportArchive -item [list url $import_archive_link]
  }

  ::xowiki::MenuBar instproc config_menu=New {
    -folder_link:required
    -return_url:required
    -package_id:required
    {-bind_vars {}}
  } {

    dict with bind_vars {

      set new_folder_link \
          [::$package_id make_form_link -form en:folder.form \
               -parent_id ${:parent_id} \
               -return_url $return_url]

      set new_page_link \
          [::$package_id make_form_link -form en:page.form \
               -parent_id ${:parent_id} \
               -return_url $return_url]
      #
      # Two old style links for xowiki::File and xowiki::Form
      #
      set new_file_link \
          [::$package_id make_link  \
               ::$package_id edit-new \
               {object_type ::xowiki::File} \
               parent_id return_url autoname template_file]

      set new_form_link [::$package_id make_form_link -form en:form.form \
                             -parent_id ${:parent_id} \
                             -nls_language $nls_language -return_url $return_url]
    }

    :add_menu_item -name New.Page   -item [list url $new_page_link]
    :add_menu_item -name New.File   -item [list url $new_file_link]
    :add_menu_item -name New.Folder -item [list url $new_folder_link]

    if {[::$package_id get_parameter MenuBarSymLinks:boolean 0]} {
      #
      # Symlinks are configured
      #
      dict with bind_vars {
        set new_sym_link [::$package_id make_form_link -form en:link.form \
                              -parent_id ${:parent_id} \
                              -nls_language $nls_language -return_url $return_url]
      }
      :add_menu_item -name New.SymLink -item [list url $new_sym_link]
    }
    :add_menu_item -name New.Form -item [list url $new_form_link]
  }

  ::xowiki::MenuBar instproc config_menu=Clipboard {
    -folder_link:required
    -return_url:required
  } {
    if {[::xowiki::clipboard is_empty]} {
      set clipboard_copy_link ""
      set clipboard_export_link ""
      set clipboard_content_link ""
      set clipboard_clear_link ""
    } else {
      set clipboard_copy_link    $folder_link?m=clipboard-copy
      set clipboard_export_link  $folder_link?m=clipboard-export
      set clipboard_content_link $folder_link?m=clipboard-content
      set clipboard_clear_link   $folder_link?m=clipboard-clear
    }
    set clipboard_add_link [export_vars -base $folder_link?m=clipboard-add {return_url}]

    # TODO: we should check either, whether to user is allowed to
    # copy-to-clipboard from the current folder, and/or the user is
    # allowed to do this with certain items.... (the latter in
    # clipboard-add)
    :add_menu_item -name Clipboard.Add \
        -item [list url \# listener [list click acs_ListBulkActionMultiFormClick("objects","$clipboard_add_link")]]
    :add_menu_item -name Clipboard.Content     -item [list url $clipboard_content_link]
    :add_menu_item -name Clipboard.Clear       -item [list url $clipboard_clear_link]
    :add_menu_item -name Clipboard.Use.Copy    -item [list url $clipboard_copy_link]
    :add_menu_item -name Clipboard.Use.Export  -item [list url $clipboard_export_link]
  }

  ::xowiki::MenuBar instproc config_menu=Page {
    -folder_link:required
    -return_url:required
    -current_page:required
  } {
    set package_id [$current_page package_id]

    set edit_link   [::$package_id make_link $current_page edit return_url]
    set view_link   [::$package_id make_link $current_page view return_url]
    set delete_link [::$package_id make_link $current_page delete return_url]
    set rev_link    [::$package_id make_link $current_page revisions]

    :add_menu_item -name Page.Edit \
        -item [list text #xowiki.edit# url $edit_link]
    :add_menu_item -name Page.View \
        -item [list text #xowiki.menu-Page-View# url $view_link]
    :add_menu_item -name Page.Delete \
        -item [list text #xowiki.delete# url $delete_link]
    :add_menu_item -name Page.Revisions \
        -item [list text #xowiki.revisions# url $rev_link]
    if {[acs_user::site_wide_admin_p]} {
      set page_show_link [::$package_id make_link -privilege admin \
                              $current_page show-object return_url]
      :add_menu_item -name Page.Show \
          -item [list text "Show Object" url $page_show_link]
    }
  }


  ::xowiki::MenuBar instproc config=default {
    {-bind_vars {}}
    -current_page:required
    -package_id:required
    -folder_link:required
    -return_url
  } {

    #:log folder_link=$folder_link
    #:log parent_id=${:parent_id}

    #
    # Define standard xowiki menubar
    #
    set clipboard_size [::xowiki::clipboard size]
    set clipboard_label [expr {$clipboard_size ? "Clipboard ($clipboard_size)" : "Clipboard"}]

    :add_menu -name Package   -label [::$package_id instance_name]
    :add_menu -name New       -label [_ xowiki.menu-New]
    :add_menu -name Clipboard -label $clipboard_label
    :add_menu -name Page      -label [_ xowiki.menu-Page]

    :config_menu=Package \
        -folder_link $folder_link \
        -return_url $return_url \
        -package_id $package_id \
        -bind_vars $bind_vars

    :config_menu=New \
        -folder_link $folder_link \
        -return_url $return_url \
        -package_id $package_id \
        -bind_vars $bind_vars

    :config_menu=Clipboard \
        -folder_link $folder_link \
        -return_url $return_url

    :config_menu=Page \
        -folder_link $folder_link \
        -return_url $return_url \
        -current_page $current_page


    set upload_link [::$package_id make_link ${:current_folder} file-upload]
    :add_extra_item -name dropzone1 -type DropZone \
        -item [list url $upload_link label DropZone disposition File]

    #set modestate [::xowiki::mode::admin get]
    #set modebutton_link [::$package_id make_link ${:current_folder} toggle-modebutton]
    #:add_extra_item -name admin -type ModeButton \
        #    -item [list url $modebutton_link on $modestate label admin]
    return {}
  }

  ::xowiki::MenuBar instproc update_items {
    -autoname
    {-bind_vars ""}
    -current_page:required
    {-config default}
    -folder_link:required
    -package_id:required
    -return_url:required
    -template_file
  } {
    # A folder page can contain extra menu entries (sample
    # below). Iterate of the extra_menu property and add according
    # menu entries. Sample:
    #
    #   {clear_menu -menu New}
    #   {entry -name New.Page -label #xowiki.new# -form en:page.form}
    #   {entry -name New.File -label File -object_type ::xowiki::File}
    #   {dropzone -name DropZone -label DropZone -disposition File}
    #   {modebutton -name Admin -label admin -button admin}

    set config_items [:config=$config \
                          -package_id $package_id \
                          -current_page $current_page \
                          -folder_link $folder_link \
                          -bind_vars $bind_vars \
                          -return_url $return_url]

    set menu_entries [list \
                          {*}[::$package_id get_parameter ExtraMenuEntries {}] \
                          {*}$config_items \
                          {*}[${:current_folder} property extra_menu_entries]]

    #:log "config=$config DONE menu_entries=$menu_entries"

    foreach me $menu_entries {
      set kind [lindex $me 0]
      if {[string index $kind 0] eq "#"} continue
      #:log notice "menu_entry <$kind> full <$me>"
      set properties [lrange $me 1 end]

      switch -- $kind {

        clear_menu {
          :clear_menu -menu [dict get $properties -menu]
        }

        form_link -
        entry {
          # sample entry: entry -name New.YouTubeLink -label YouTube -form en:YouTube.form
          if {$kind eq "form_link"} {
            ad_log_deprecated menu-entry $link entry
          }
          if {[dict exists $properties -link]} {
            set link [dict get $properties -link]
          } elseif {[dict exists $properties -form]} {
            set q [expr {[dict exists $properties -query] ? "-query [dict get $properties -query]" : ""}]
            dict with bind_vars {
              set link [::$package_id make_form_link \
                            -form [dict get $properties -form] \
                            -parent_id ${:parent_id} \
                            -nls_language $nls_language \
                            -return_url $return_url \
                            {*}$q]
            }
          } elseif {[dict exists $properties -object_type]} {
            set link [::$package_id make_link \
                          $package_id edit-new \
                          [list object_type [dict get $properties -object_type]] \
                          parent_id return_url autoname template_file]
          } else {
            :log "Warning: no link specified"
            set link ""
          }
          if {[dict exists $properties -disabled] && [dict get $properties -disabled]} {
            set link ""
          }
          set item [list url $link]
          if {[dict exists $properties -label]} {
            lappend item label [dict get $properties -label]
          } else {
            #
            # We have no explicit label. Replace dots of menu entry
            # names by dashes for message key.
            #
            set locale [::xo::cc locale]
            set dname [string map {. -} [dict get $properties -name]]

            foreach message_key [list xowiki.menu-$dname xowf.menu-$dname] {
              if {[lang::message::message_exists_p en_US $message_key]} {
                lappend item label [lang::message::lookup $locale $message_key]
                break
              }
            }
          }
          :add_menu_item -name [dict get $properties -name] -item $item
        }

        dropzone {
          foreach {var default} {
            name dropzone
            uploader File
            disposition File
            label DropZone
          } {
            set $var $default
            if {[dict exists $properties -$var]} {
              set $var [dict get $properties -$var]
            }
          }
          if {![info exists disposition] && [info exists uploader]} {
            # use the legacy name
            set disposition $uploader
          }

          set link [::$package_id make_link ${:parent_id} file-upload]
          :add_extra_item -name $name -type DropZone \
              -item [list url $link disposition $disposition label $label]
        }

        modebutton {
          foreach {var default} {
            name modebutton
            button admin
            label ""
          } {
            set $var $default
            if {[dict exists $properties -$var]} {
              set $var [dict get $properties -$var]
            }
          }
          if {$label eq ""} {set label $button}
          set state [::xowiki::mode::$button get]
          set link [::$package_id make_link ${:parent_id} toggle-modebutton]
          :add_extra_item -name $name -type ModeButton \
              -item [list url $link on $state label $label]
        }
        config {}
        default {
          error "unknown kind of menu entry: $kind"
        }
      }
    }
  }

  ::xowiki::MenuBar instproc content {} {
    set result [list id [:id]]
    foreach e ${:Menus} {
      lappend result $e [list kind MenuButton {*}[set :Menu($e)]]
    }

    foreach e [:array name ModeButton] {
      lappend result $e [list kind ModeButton {*}[set :ModeButton($e)]]
    }

    foreach e [:array name DropZone] {
      lappend result $e [list kind DropZone {*}[set :DropZone($e)]]
    }

    return $result
  }

  ::xowiki::MenuBar instproc render-preferred {} {
    switch [::template::CSS toolkit] {
      bootstrap -
      bootstrap5 {set menuBarRenderer render-bootstrap}
      default    {set menuBarRenderer render-yui}
    }
    :$menuBarRenderer
  }

  namespace export Menu
  # end of namespace ::xowiki
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

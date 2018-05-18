::xo::library doc {
  XoWiki - importer

  @creation-date 2008-04-25
  @author Gustaf Neumann
  @cvs-id $Id$
}


namespace eval ::xowiki {

  Class create Importer -parameter {
    {added 0} {replaced 0} {updated 0} {inherited 0}
    {package_id} {parent_id} {user_id}
  }
  Importer instproc init {} {
    set :log ""
    :destroy_on_cleanup
  }
  Importer instproc report_lines {} {
    util_user_message -message "[_ xowiki.Import_successful]"
    return "<table><caption>Details</caption>${:log}</table>"
  }
  Importer instproc report_line {obj operation} {
    set href [$obj pretty_link]
    set name [[$obj package_id] external_name -parent_id [$obj parent_id] [$obj name]]
    switch -- $operation {
      "added"     { set operation [_ xowiki.added]     }
      "replaced"  { set operation [_ xowiki.replaced]  }
      "updated"   { set operation [_ xowiki.updated]   }
      "inherited" { set operation [_ xowiki.inherited] }
    }
    append :log "<tr><td>$operation</td><td><a href='[ns_quotehtml $href]'>$name</a></td></tr>\n"
  }
  Importer instproc report {} {
    return "<b>${:added}</b> #xowiki.objects_newly_inserted#,\
    <b>${:updated}</b> #xowiki.objects_updated#, <b>${:replaced}</b> #xowiki.objects_replaced#, <b>${:inherited}</b> #xowiki.inherited_update_ignored#<p>\
    [:report_lines]"
  }

  Importer instproc import {-object:required -replace -create_user_ids} {
    #
    # Import a single object. In essence, this method demarshalls a
    # single object and inserts it (or updates it) in the database. It
    # takes as well care about categories.
    #

    $object demarshall -parent_id [$object parent_id] -package_id ${:package_id} \
        -creation_user ${:user_id} -create_user_ids $create_user_ids
    set item_id [::xo::db::CrClass lookup -name [$object name] -parent_id [$object parent_id]]
    #:msg "lookup of [$object name] parent [$object parent_id] => $item_id"
    if {$item_id != 0} {
      if {$replace} { ;# we delete the original
        ::xo::db::CrClass delete -item_id $item_id
        set item_id 0
        :report_line $object replaced
        incr :replaced
      } else {
        #:msg "$item_id update: [$object name]"
        ::xo::db::CrClass get_instance_from_db -item_id $item_id
        $item_id copy_content_vars -from_object $object
        $item_id save -use_given_publish_date [$item_id exists publish_date] \
            -modifying_user [$object set modifying_user]
        #:log "$item_id saved"
        $object set item_id [$item_id item_id]
        #:msg "$item_id updated: [$object name]"
        :report_line $item_id updated
        incr :updated
      }
    }
    if {$item_id == 0} {
      set n [$object save_new -use_given_publish_date [$object exists publish_date] \
                 -creation_user [$object set modifying_user] ]
      $object set item_id $n
      set item_id $object
      #:msg "$object added: [$object name]"
      :report_line $object added
      incr :added
    }
    #
    # The method demarshall might set the mapped __category_ids in $object.
    # Insert these into the category object map
    #
    if {[$object exists __category_ids]} {
      #:msg "$item_id map_categories [object set __category_ids] // [$item_id item_id]"
      $item_id map_categories [$object set __category_ids]
    }

    ${:package_id} flush_references -item_id [$object item_id] -name [$object name]
  }

  Importer instproc import_all {-replace -objects:required {-create_user_ids 0} {-keep_inherited 1}} {
    #
    # Import a series of objects. This method takes care especially
    # about dependencies of objects, which is reflected by the order
    # of object-imports.
    #
    #
    # Extract information from objects to be imported, that might be
    # changed later in the objects.
    #
    foreach o $objects {
      #
      # Remember old item_ids and old_names for pages with
      # item_ids. Only these can have parents (page_templates) or
      # child_objects
      #
      if {[$o exists item_id]}   {
        set item_ids([$o item_id]) $o
        set old_names([$o item_id]) [$o name]
      } {
        $o item_id ""
      }
      # Remember old parent_ids for name-mapping, names are
      # significant per parent_id.
      if {[$o exists parent_id]} {
        set parent_ids([$o item_id]) [$o parent_id]
      } {
        $o parent_id ""
      }
      set todo($o) 1

      #
      # Handle import of categories in the first pass
      #
      if {[$o exists __map_command]} {
        $o package_id ${:package_id}
        $o eval [$o set __map_command]
      }
      # FIXME remove?
      #if {[$o exists __category_map]} {
      #  array set ::__category_map [$o set __category_map]
      #}
    }
    #:msg "item_ids=[array names item_ids], parent_ids=[array names parent_ids]"

    #
    # Make a fix-point iteration during import. Do only import, when
    # all pre-requirement pages are already loaded.
    #
    while {[array size todo] > 0} {
      set new 0
      foreach o [array names todo] {
        #:msg "work on $o [$o info class] [$o name]"

        set old_name      [$o name]
        set old_item_id   [$o item_id]
        set old_parent_id [$o parent_id]

        # page instances have references to page templates, add the templates first
        if {[$o istype ::xowiki::PageInstance]} {
          set old_template_id [$o page_template]
          if {![info exists old_names($old_template_id)]} {
            set new 0
            :msg "need name for $old_template_id. Maybe item_ids for PageTemplate missing?"
            break
          }

          set template_name_key $parent_ids($old_template_id)-$old_names($old_template_id)
          if {![info exists name_map($template_name_key)]} {
            #:msg "... delay import of $o (no object with name $template_name_key) imported"
            continue
          }
          #:msg "we found entry for name_map($template_name_key) = $name_map($template_name_key)"
        }

        if {[info exists item_ids($old_parent_id)]} {
          # we have a child object
          if {![info exists id_map($old_parent_id)]} {
            #:msg "... delay import of $o (map of parent_id $old_parent_id missing)"
            continue
          }
        }

        set need_to_import 1
        #
        # If the page was implicitly added (due to being a
        # page_template of an exported page), and a page (e.g. a form
        # or a workflow) with the same name can be found in the
        # target, don't materialize the inherited page.
        #
        if {$keep_inherited
            && [$o exists __export_reason]
            && [$o set __export_reason] eq "implicit_page_template"} {
          $o unset __export_reason
          set page [${:package_id} get_page_from_item_ref \
                        -allow_cross_package_item_refs false \
                        -use_package_path true \
                        -use_site_wide_pages true \
                        -use_prototype_pages false \
                        [$o name] \
                       ]

          # If we would like to restrict to just inherited pages in
          # the target, we could extend the test below with a test like
          # the following:
          #   set inherited [expr {[$page physical_parent_id] ne [$page parent_id]}]

          if {$page ne ""} {
            #:msg "page [$o name] can ne found in folder ${:parent_id}"
            incr :inherited
            unset todo($o)
            set o $page
            set need_to_import 0
          }
        }

        if {$need_to_import} {
          # Now, all requirements are met, parent-object and
          # child-object conditions are fulfilled. We have to map
          # page_template for PageInstances and parent_ids for child
          # objects to new IDs.
          #
          if {[$o istype ::xowiki::PageInstance]} {
            #:msg "importing [$o name] page_instance, map $template_name_key to $name_map($template_name_key)"
            $o page_template $name_map($template_name_key)
            #:msg "exists template? [:isobject [$o page_template]]"
            if {![:isobject [$o page_template]]} {
              ::xo::db::CrClass get_instance_from_db -item_id [$o page_template]
              #:msg "[:isobject [$o page_template]] loaded"
            }
          }

          if {[info exists item_ids($old_parent_id)]} {
            $o set parent_id $id_map($old_parent_id)
          } else {
            $o set parent_id ${:parent_id}
          }

          # Everything is mapped, we can now do the import.

          #:msg "start import for $o, name=[$o name]"
          :import \
              -object $o \
              -replace $replace \
              -create_user_ids $create_user_ids
          #:msg "import for $o done, name=[$o name]"

          unset todo($o)
        }

        #
        # Maintain the maps and iterate
        #
        if {$old_item_id ne ""} {
          set id_map($old_item_id) [$o item_id]
        }
        set name_map($old_parent_id-$old_name) [$o item_id]
        #:msg "setting name_map($old_parent_id-$old_name)=$name_map($old_parent_id-$old_name), o=$o, old_item_id=$old_item_id"

        set new 1
      }
      if {$new == 0} {
        :msg "could not import [array names todo]"
        break
      }
    }
    #:msg "final name_map=[array get name_map], id_map=[array get id_map]"

    #
    # final cleanup
    #
    foreach o $objects {$o destroy}

    ${:package_id} flush_page_fragment_cache
  }

  #
  # A small helper for exporting objects
  #

  Object create exporter
  exporter proc include_needed_objects {item_ids} {
    #
    # Load the objects
    #
    foreach item_id $item_ids {
      if {[::xo::db::CrClass get_instance_from_db -item_id $item_id] eq ""} {
        :log "Warning: cannot fetch item $item_id for exporting"
      } else {
        set items($item_id) 1
      }
    }

    #
    # In a second step, include the objects which should be exported implicitly
    #
    while {1} {
      set new 0
      ns_log notice "--export works on [array names items]"
      foreach item_id [array names items] {
        #
        # We flag the reason, why the implicitly included elements were
        # included. If the target can resolve already such items
        # (e.g. forms), we might not have to materialize these finally.
        #
        # For PageInstances (or its subtypes), include the parent-objects as well
        #
        if {[$item_id istype ::xowiki::PageInstance]} {
          set template_id [$item_id page_template]
          if {![info exists items($template_id)]} {
            ns_log notice "--export including template-object $template_id [$template_id name]"
            set items($template_id) 1
            ::xo::db::CrClass get_instance_from_db -item_id $template_id
            set new 1
            $template_id set __export_reason implicit_page_template
            continue
          }
        }
        #
        # check for child objects of the item
        #
        set sql [::xowiki::Page instance_select_query -folder_id $item_id -with_subtypes true]
        ::xo::dc foreach export_child_obj $sql {
          if {![info exists items($item_id)]} {
            ::xo::db::CrClass get_instance_from_db -item_id $item_id
            ns_log notice "--export including child $item_id [$item_id name]"
            set items($item_id) 1
            set new 1
            $item_id set __export_reason implicit_child_page
          }
        }
      }
      if {!$new} break
    }
    return [array names items]
  }

  exporter proc marshall_all {{-mode export} item_ids} {
    set content ""
    foreach item_id $item_ids {
      ad_try {
        set obj [$item_id marshall -mode $mode]
      } on error {errorMsg} {
        ns_log error "Error while exporting $item_id [$item_id name]\n$errorMsg\n$::errorInfo"
        error $errorMsg
      }
      append content $obj\n
    }
    return $content
  }

  exporter proc export {item_ids} {
    #
    # include implicitly needed objects, instantiate the objects.
    #
    set item_ids [:include_needed_objects $item_ids]
    #
    # stream the objects via ns_write
    #
    ns_set put [ns_conn outputheaders] "Content-Type" "text/plain"
    ns_set put [ns_conn outputheaders] "Content-Disposition" "attachment;filename=export.xotcl"
    ad_return_top_of_page ""

    foreach item_id $item_ids {
      ns_log notice "--exporting $item_id [$item_id name]"
      set pretty_link [expr {[$item_id package_id] ne "" ? [$item_id pretty_link] : "(not visible)"}]
      ns_write "# exporting $item_id [$item_id name] $pretty_link\n"
      ad_try {
        set obj [$item_id marshall]
      } on error {errorMsg} {
        ns_log error "Error while exporting $item_id [$item_id name]\n$errorMsg\n$::errorInfo"
      } finally {
        ns_write "$obj\n"
      }
    }
  }


  #
  # Simple archive file manager
  #
  # The Archive manages supports importing .zip files and .tar.gz
  # files as ::xowiki::File into xowiki folders.
  #
  ::xotcl::Class create ArchiveFile -parameter {
    file
    name
    parent_id
    {use_photo_form false}
  }
  ArchiveFile instproc init {} {
    :destroy_on_cleanup
    ::xo::db::CrClass get_instance_from_db -item_id ${:parent_id}
    set :tmpdir [ad_tmpnam]
    file mkdir ${:tmpdir}
  }
  ArchiveFile instproc delete {} {
    file delete -force -- ${:tmpdir}
    next
  }
  ArchiveFile instproc unpack {} {
    set success 0
    #:log "::xowiki::guesstype '${:name}' => [::xowiki::guesstype ${:name}]"
    switch [::xowiki::guesstype ${:name}] {
      application/zip -
      application/x-zip -
      application/x-zip-compressed {
        set zipcmd [::util::which unzip]
        #:msg "zip = $zipcmd, tempdir = ${:tmpdir}"
        exec $zipcmd ${:file} -d ${:tmpdir}
        :import -dir ${:tmpdir} -parent_id ${:parent_id}
        set success 1
      }
      application/x-compressed {
        if {[string match "*tar.gz" ${:name}]} {
          set cmd [::util::which tar]
          exec $cmd -xzf ${:file} -C ${:tmpdir}
          :import -dir ${:tmpdir} -parent_id ${:parent_id}
          set success 1
        } else {
          :msg "unknown compressed file type ${:name}"
        }
      }
      default {:msg "type [::xowiki::guesstype ${:name}] of ${:name} unknown"}
    }
    #:msg success=$success
    return $success
  }
  ArchiveFile instproc import {-dir -parent_id} {
    set package_id [$parent_id package_id]

    foreach tmpfile [glob -nocomplain -directory $dir *] {
      #:msg "work on $tmpfile [::file isdirectory $tmpfile]"
      set file_name [::file tail $tmpfile]
      if {[::file isdirectory $tmpfile]} {
        # ignore mac os x resource fork directories
        if {[string match "*__MACOSX" $tmpfile]} continue
        set folder_object [$package_id get_page_from_name -assume_folder true \
                               -name $file_name -parent_id $parent_id]
        if {$folder_object ne ""} {
          # if the folder exists already, we have nothing to do
        } else {
          # we create a new folder ...
          set folder_form_id [::xowiki::Weblog instantiate_forms -forms en:folder.form \
                                  -package_id $package_id]
          set folder_object [FormPage new -destroy_on_cleanup \
                                 -title $file_name \
                                 -name $file_name \
                                 -package_id $package_id \
                                 -parent_id $parent_id \
                                 -nls_language en_US \
                                 -instance_attributes {} \
                                 -page_template $folder_form_id]
          $folder_object save_new
          # ..... and refetch it under its canonical name
          ::xo::db::CrClass get_instance_from_db -item_id [$folder_object item_id]
        }
        :import -dir $tmpfile -parent_id [$folder_object item_id]
      } else {
        set mime_type [::xowiki::guesstype $file_name]
        if {[string match "image/*" $mime_type] && [:use_photo_form]} {
          set photo_object [$package_id get_page_from_name -name en:$file_name -parent_id $parent_id]
          if {$photo_object ne ""} {
            # photo entry exists already, create a new revision
            :log "Photo $file_name exists already"
            $photo_object set title $file_name
            set f [::xowiki::formfield::file new -object $photo_object -name "image" -destroy_on_cleanup]
            $f set value $file_name
            $f content-type $mime_type
            $f set tmpfile $tmpfile
            $f convert_to_internal
            $photo_object save
          } else {
            # create a new photo entry
            :log "new Photo $file_name"
            set photoFormObj [::xowiki::Weblog instantiate_forms \
                                  -parent_id $parent_id -forms en:photo.form -package_id $package_id]
            set photo_object [$photoFormObj create_form_page_instance \
                                  -name en:$file_name \
                                  -nls_language en_US \
                                  -creation_user [::xo::cc user_id] \
                                  -parent_id $parent_id \
                                  -package_id $package_id \
                                  -instance_attributes [list image [list name $file_name]]]
            $photo_object title $file_name
            $photo_object publish_status "ready"
            $photo_object save_new ;# to obtain item_id needed by the form-field
            set f [::xowiki::formfield::file new -object $photo_object -name "image" -destroy_on_cleanup]
            $f set value $file_name
            $f content-type $mime_type
            $f set tmpfile $tmpfile
            $f convert_to_internal
            #:log "after convert to internal $file_name"
          }
        } else {
          set file_object [$package_id get_page_from_name -name file:$file_name -parent_id $parent_id]
          if {$file_object ne ""} {
            :msg "file $file_name exists already"
            # file entry exists already, create a new revision
            $file_object set import_file $tmpfile
            $file_object set mime_type $mime_type
            $file_object set title $file_name
            $file_object save
          } else {
            :msg "file $file_name created new"
            set file_object [::xowiki::File new -destroy_on_cleanup \
                                 -title $file_name \
                                 -name file:$file_name \
                                 -parent_id $parent_id \
                                 -mime_type $mime_type \
                                 -package_id $package_id \
                                 -creation_user [::xo::cc user_id] ]
            $file_object set import_file $tmpfile
            $file_object save_new
          }
        }
      }
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

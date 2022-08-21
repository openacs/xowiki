::xo::library doc {

  XoWiki - Uploader procs

  @creation-date 2016-03-21
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {
  nx::Class create ::xowiki::Upload {
    #
    # Abstract class for upload handlers. Subclasses define concreate
    # behavior. The method "store_file" should either return 201 for
    # successful uploads or 200 for ignored cases.
    #
    :property file_name
    :property content_type
    :property tmpfile
    :property parent_object

    :public method store_file {} {
      #
      # Abstract method.
      #

      error "not implemented"
    }
  }

  nx::Class create ::xowiki::UploadFile -superclass ::xowiki::Upload {
    #
    # Class for storing files as xowiki::File instances.
    #
    :public method store_file {} {
      #
      # Store the file provided via instance variables by using the
      # formfield::file implementation (uses xowiki::File).
      #
      set f [::xowiki::formfield::file new -name upload -object ${:parent_object}]
      set file_object [$f store_file \
                           -file_name ${:file_name} \
                           -content_type ${:content_type} \
                           -package_id [${:parent_object} package_id] \
                           -parent_id [${:parent_object} item_id] \
                           -object_name file:${:file_name} \
                           -tmpfile ${:tmpfile} \
                           -publish_date_cmd {;} \
                           -save_flag ""]
      $f destroy
      return [list status_code 201 message created file_object $file_object file_name ${:file_name}]
    }
  }

  nx::Class create ::xowiki::UploadFileIconified -superclass ::xowiki::UploadFile {
    #
    # Refinement of ::xowiki::UploadFile but returning content rended
    # by a special renderer. There is e.g. such a renderer defined in
    # xowf for the online exam.
    #
    :public method store_file {} {
      set d [next]
      if {[dict get $d status_code] in {200 201}} {
        return [list status_code 201 message [${:parent_object} render_thumbnails $d]]
      }
      return {status_code 500 message "something wrong"}
    }
  }

  nx::Class create ::xowiki::UploadPhotoForm -superclass ::xowiki::Upload {
    #
    # Class for storing files as instances of photo.form.
    #
    :public method store_file {} {
      #
      # Ignore everything, which does not have an image/* mime type.
      #
      if {![string match image/* ${:content_type}]} {
        ns_log notice "ignore store_file operation for ${:file_name} mimetype ${:content_type}"
        return {status_code 200 message ok}
      }
      #
      # Mime type is ok, save the file under the filename either as a
      # new item or as a new revision.
      #
      set package_id [${:parent_object} package_id]
      set parent_id [${:parent_object} item_id]

      set photo_object [::$package_id get_page_from_name -name en:${:file_name} -parent_id $parent_id]
      if {$photo_object ne ""} {
        #
        # The photo page instance exists already, create a new revision.
        #
        ns_log notice "Photo ${:file_name} exists already"
        $photo_object set title ${:file_name}
        set f [::xowiki::formfield::file new -object $photo_object -name "image" -destroy_on_cleanup]
        $f set value ${:file_name}
        $f content-type ${:content_type}
        $f set tmpfile ${:tmpfile}
        $f convert_to_internal
        $photo_object save
      } else {
        #
        # Create a new page instance of photo.form.
        #
        ns_log notice "new Photo ${:file_name}"
        set photoFormObj [::$package_id instantiate_forms \
                              -parent_id $parent_id -forms en:photo.form]
        set photo_object [$photoFormObj create_form_page_instance \
                              -name en:${:file_name} \
                              -nls_language en_US \
                              -creation_user [::xo::cc user_id] \
                              -parent_id $parent_id \
                              -package_id $package_id \
                              -instance_attributes [list image [list name ${:file_name}]]]
        $photo_object title ${:file_name}
        $photo_object publish_status "ready"
        $photo_object save_new ;# to obtain item_id needed by the form-field
        set f [::xowiki::formfield::file new -object $photo_object -name "image" -destroy_on_cleanup]
        $f set value ${:file_name}
        $f content-type ${:content_type}
        $f set tmpfile ${:tmpfile}
        $f convert_to_internal
      }

      return {status_code 201 message created}
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

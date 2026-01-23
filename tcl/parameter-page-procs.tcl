::xo::library doc {
  xowiki - procs for working with parameter pages.

  @creation-date 2020-02-13
  @author Gustaf Neumann
}

namespace eval ::xowiki {
  ad_proc require_parameter_page {
    -name:required
    -package_id:required
    -parent_id
    {-title "Parameter Page"}
    {-instance_attributes ""}
    {-form en:Parameter.form}
    {-publish_status production}
  } {

    Create or up update a parameter page. This is a convenience
    method to ease the interaction with parameter pages.

  } {
    ::xo::Package require $package_id

    if {![info exists parent_id]} {
      set parent_id [::$package_id folder_id]
    }

    set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]
    if {$item_id == 0} {
      #
      # We have to create the parameter page new....
      # Get first the parameter form
      #
      set page [::$package_id get_page_from_item_ref \
                    -use_prototype_pages true \
                    -use_package_path true \
                    -parent_id $parent_id \
                    $form]
      if {$page eq ""} {
        error "cannot instantiate $form"
      }

      #ns_log notice FORM=[$page serialize]

      if {[$page publish_status] ne $publish_status} {
        ns_log notice "form $form: change publish_status -> $publish_status"
        ::xo::db::sql::content_item set_live_revision \
            -revision_id [::$page revision_id] \
            -publish_status $publish_status
      }

      set instance_vars [list title $title parent_id $parent_id \
                             package_id $package_id \
                             instance_attributes $instance_attributes]
      ad_try {
        #ns_log notice "form $form: try to create form page $name"
        ::$page create_form_page_instance \
            -name $name \
            -package_id $package_id \
            -parent_id $parent_id \
            -nls_language en_US \
            -default_variables $instance_vars
      } on error {errorMsg} {
        error "cannot create instance named '$name' of form $form: $errorMsg\n$::errorInfo"
      } on ok {p} {
        $p save_new
      }
    } else {
      #
      # The parameter page exists already. Get the old instance
      # attributes, add the new ones and save the page
      #
      set p [::xowiki::FormPage get_instance_from_db -item_id $item_id]
      $p title $title
      $p instance_attributes [dict merge [$p instance_attributes] $instance_attributes]
      $p save
      ns_log notice "form $form: updated parameter page saved."
    }
  }
}


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

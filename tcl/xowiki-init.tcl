#
# Check, if we have to update the hkeys in the
# form_instance_item_index.
#
# We do this in a *-init file, since at that time, all library files
# are usable. If we would do this during loading, we would have
# problems with not-yet loaded library files from other packages.
#
if {[nsv_exists xowiki must_update_hkeys]
    && [nsv_get xowiki must_update_hkeys]
  } {
    ::xowiki::hstore::update_update_all_form_instances
    nsv_unset xowiki must_update_hkeys
}

# Make sure, the site-wide pages are loaded and/or refetched when the
# source code in the prototype pages changed.
#
::xo::dc transaction {
  ::xowiki::Package require_site_wide_pages -refetch_if_modified true
} on_error {
  ns_log error "xowiki-init:  require_site_wide_pages lead to: $errmsg"
}

# Offer XoWiki search controls only when Search is mounted and has a usable driver.
set ::xowiki::search_mounted_p 0
if {[site_node::get_package_url -package_key search] eq ""} {
  ns_log notice "xowiki: Search package is not mounted."
} elseif {[info commands ::search::driver_name] eq "" || [::search::driver_name] eq ""} {
  ns_log warning "xowiki: Search is mounted but has no usable driver."
} else {
  set ::xowiki::search_mounted_p 1
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

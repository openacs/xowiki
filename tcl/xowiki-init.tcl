#
# Check, if we have to update the hkeys in the
# form_instance_item_index.
#
# We do this in an -init file, since at that time, all library files
# are usable. If we would do thisduring loading, we would have
# problems with not-yet loaded library files from other packages.
#
if {[nsv_exists xowiki must_update_hkeys] && [nsv_get xowiki must_update_hkeys]} {
    ::xowiki::hstore::update_update_all_form_instances
    nsv_unset xowiki must_update_hkeys
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

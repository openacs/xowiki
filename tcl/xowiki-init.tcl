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

set ::xowiki::search_mounted_p 1
set search_driver [parameter::get -package_id [apm_package_id_from_key search] \
                       -parameter FtsEngineDriver]

#
# Check, if search is configured. If not, we do not want to offer
# e.g. a search link.
#
# For the time being, the check is just for xowiki, but in general, we
# might want to have more global option, which allows to check for
# example, if search is available for a certain subsite (when search
# is subsite aware).
#
if { [site_node::get_package_url -package_key search] eq "" } { 
  ns_log Warning "xowiki: Search package is not mounted."
  set ::xowiki::search_mounted_p 0
} elseif { $search_driver eq ""} {
  ns_log Warning "xowiki: FtsEngineDriver parameter in package search is empty."
  set ::xowiki::search_mounted_p 0
} elseif { [apm_package_id_from_key $search_driver] == 0} { 
  ns_log Warning "xowiki Search driver $search_driver is not installed."
  set ::xowiki::search_mounted_p 0
} else {
  set ::xowiki::search_mounted_p 1
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

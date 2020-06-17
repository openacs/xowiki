
aa_register_case -cats {smoke production_safe} web_callable_methods_naming {
    checks naming conventions of web callable methods

    @author Gustaf Neumann
} {
    set count 0
    foreach cl [concat \
                    [::xowiki::Page info subclass -closure] \
                    [::xowiki::Package info subclass -closure] \
                    ] {
        foreach m [lsort [$cl info instprocs www-*]] {
            incr count
            regexp {www[-](.*)$} $m . suffix
            set wrong [regexp {[^a-z0-9-]} $suffix]
            aa_false "web callable method '$cl instproc $m' does not follow naming guidelines (just lower case, digit and dash)" $wrong
        }
    }
    aa_log "Checked $count web callable methods"
}

aa_register_case \
    -cats {smoke production_safe} \
    -error_level warning \
    web_callable_methods_doc {
        Checks if documentation exists for web callable methods

        @author Gustaf Neumann
} {
    set count 0
    foreach cl [concat \
                    [::xowiki::Page info subclass -closure] \
                    [::xowiki::Package info subclass -closure] \
                    ] {
        foreach m [lsort [$cl info instprocs www-*]] {
            incr count
            set exists [nsv_exists api_proc_doc "[string trimleft $cl :] instproc $m"]
            aa_true "documentation for web callable method '$cl instproc $m'" $exists
        }
    }
    aa_log "Checked $count web callable methods"
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:

ad_page_contract {
	
} {
	revision:notnull,integer 
} 

template::add_event_listener \
    -id controls-link \
    -script {window.open(this.href, 'Bildvorschau', 'width=500,height=500,scrollbars,resizable');}


# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

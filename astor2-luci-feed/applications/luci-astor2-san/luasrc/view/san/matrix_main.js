<script type="text/javascript">

jQuery.noConflict();
(function($) {

// effects

// Hide all elements with class "to_hide*".
$( '[ class ^= "to_hide" ]' ).hide();

// Hide all on click button "Hide all".
$( 'input[ name = "hide_all" ]' ).click( function() {
	$( '[ class ^= "to_hide" ]' ).fadeOut();
} );

// Show all on click button "Show all".
$( 'input[ name = "show_all" ]' ).click( function() {
	$( '[ class ^= "to_hide" ]' ).fadeIn();
} );

// Hide/show form for "Create RAID".
$( 'form input:checkbox[ name = "checkbox_drive" ]' ).click( function() {
	if ( $( this ).is( ':checked' ) ) {
		$( '#div_raid_create' ).fadeIn( 'fast' );
	} else {
		if ( $( 'form input:checkbox[ name = "checkbox_drive" ]' ).is( ':checked' ) ) {
		} else {
			$( '#div_raid_create' ).fadeOut( 'fast' );
		}
	}

	// Physicals drives to RAID.
	var drives_list_to_raid = $.makeArray(
		$( 'form input:checkbox[ name = "checkbox_drive" ]:checked:' )
			.map( function() { return $( this ).attr( 'value' ); } 	)
		).join( ', ' );
	$( 'form input:text[ name = "drives_to_raid_list" ]' ).val( drives_list_to_raid );
} );

// Hide/show information of physicals and logicals.
$( 'form a[ id *= "ical_info-" ]' ).click( function() {
	var parent_selector = $( this ).parent( 'td' ).parent( 'tr' ).next( 'tr' ).css( 'background-color', 'yellow' );
	if ( $( parent_selector ).is( ':hidden' ) ) {
		$( parent_selector ).fadeIn( 'fast' );
	} else {
		$( parent_selector ).fadeOut( 'fast' );
	}
} );

//styles

/*
$( 'td.border' ).css( 'background-color', '#f0f' )
$( 'td.border-top-left' ).css( {
	'border-width': '10px 0 0 10px',
	'border-style': 'solid',
	'border-color': '#f0f' } )
$( 'td.border-top' ).css( {
	'border-width': '10px 0 0 0',
	'border-style': 'solid',
	'border-color': '#f0f' } )
$( 'td.border-top-right' ).css( {
	'border-width': '10px 10px 0 0',
	'border-style': 'solid',
	'border-color': '#f0f' } )
$( 'td.border-top-right-bottom' ).css( {
	'border-width': '10px 10px 10px 0',
	'border-style': 'solid',
	'border-color': '#f0f' } )
$( 'td.border-left' ).css( {
	'border-width': '0 0 0 10px',
	'border-style': 'solid',
	'border-color': '#f0f' } )
*/

})(jQuery);

</script>

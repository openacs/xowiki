/*
Copyright (c) 2003-2011, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

// Register a templates definition set named "default".
CKEDITOR.addTemplates( 'default',
{
	// The name of sub folder which hold the shortcut preview images of the
	// templates.
        imagesPath : CKEDITOR.getUrl( CKEDITOR.plugins.getPath( 'templates' ) + 'templates/images/' ),

	// The templates definitions.
	templates :
		[
			{
				title: 'Image and Title',
				image: 'template1.gif',
				description: 'One main image with a title and text that surround the image.',
				html:
					'<h3>' +
						'<img style="margin-right: 10px" height="100" width="100" align="left"/>' +
						'Type the title here'+
					'</h3>' +
					'<p>' +
						'Type the text here' +
					'</p>'
			},
			{
				title: 'Strange Template',
				image: 'template2.gif',
				description: 'A template that defines two colums, each one with a title, and some text.',
				html:
					'<table cellspacing="0" cellpadding="0" style="width:100%" border="0">' +
						'<tr>' +
							'<td style="width:50%">' +
								'<h3>Title 1</h3>' +
							'</td>' +
							'<td></td>' +
							'<td style="width:50%">' +
								'<h3>Title 2</h3>' +
							'</td>' +
						'</tr>' +
						'<tr>' +
							'<td>' +
								'Text 1' +
							'</td>' +
							'<td></td>' +
							'<td>' +
								'Text 2' +
							'</td>' +
						'</tr>' +
					'</table>' +
					'<p>' +
						'More text goes here.' +
					'</p>'
			},
			{
				title: 'Text and Table',
				image: 'template3.gif',
				description: 'A title with some text and a table.',
				html:
					'<div style="width: 80%">' +
						'<h3>' +
							'Title goes here' +
						'</h3>' +
						'<table style="width:150px;float: right" cellspacing="0" cellpadding="0" border="1">' +
							'<caption style="border:solid 1px black">' +
								'<strong>Table title</strong>' +
							'</caption>' +
							'</tr>' +
							'<tr>' +
								'<td>&nbsp;</td>' +
								'<td>&nbsp;</td>' +
								'<td>&nbsp;</td>' +
							'</tr>' +
							'<tr>' +
								'<td>&nbsp;</td>' +
								'<td>&nbsp;</td>' +
								'<td>&nbsp;</td>' +
							'</tr>' +
							'<tr>' +
								'<td>&nbsp;</td>' +
								'<td>&nbsp;</td>' +
								'<td>&nbsp;</td>' +
							'</tr>' +
						'</table>' +
						'<p>' +
							'Type the text here' +
						'</p>' +
					'</div>'
			}
		]
});


// Register a templates definition set named "interactions".
CKEDITOR.addTemplates( 'interactions',
{
	// The name of sub folder which hold the shortcut preview images of the
	// templates.
        imagesPath : CKEDITOR.getUrl( '/resources/xowiki/images/' ),

	// The templates definitions.
	templates :
		[
			{
				title: 'Simple Open Text Question',
				image: '1answer.png',
			        description: 'Question with a text and a single answer field.',
				html:   
			    		'<form>Schreiben Sie den Angabetext hier...' + 
					'<div style="float:right;">(10 Minuten)</div>' + 
					'<br><textarea class="answer-text" name="a1" cols="100" rows="4"></textarea></form>'
			},
			{
				title: 'Open Text question consisting of three parts',
				image: '2answers.png',
			    description: 'Question with a introductory text and three subquestions.',
				html:
					'<form><p>Schreiben Sie den allgemeinen Angabetext hier' +
					'</p><ol>' +
				        '<li>Angabetext für die erste Teilaufgabe' +
					'<div class="answer-text" style="float:right;">(10 Minuten)</div>' + 
					'<br><textarea class="answer-text name="a1" cols="100" rows="4">' +
					'</textarea>' +

				        '<li>Angabetext für die zweite Teilaufgabe' +
					'<div style="float:right;">(10 Minuten)</div>' + 
					'<br><textarea class="answer-text" name="a2" cols="100" rows="4">' +
					'</textarea>' +

				        '<li>Angabetext für die dritte Teilaufgabe' +
					'<div style="float:right;">(10 Minuten)</div>' + 
					'<br><textarea class="answer-text" name="a3" cols="100" rows="4">' +
					'</textarea>' +
				        '</ol></form>'

			}
		]
});
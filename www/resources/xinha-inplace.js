/*
 * A simple inplace editor vor xinha to be used within OpenACS
 * (providing the basic configuration). The inplace editor is to be
 * used within forms to edit elements with the style 'xinha' and pass
 * the content via a hidden variable back to the application. The
 * editor was desinged to be used with xowiki and xowiki content flow.
 *
 * Gustaf Neumann
 */

// provide a namespace 'xinha'
if (!window.xinha) {
  window.xinha = {};
}

xinha.inplace = {
   hoverColor : '#BBffBB',
   saveButtonLabel : 'Save',
   cancelButtonLabel : 'Cancel',
   backgroundColor : null,
   xinha_editors : []
};

/*
 * Initialize the inplace editor. This means essentially to setup all
 * handlers for elemets of CSS class 'xinha' and 'xinhaupdate'.
 */
xinha.inplace.init = function() {
  var editElements = [];

  // In case the iteration over all nodes turns out to be a problem,
  // we should switch to YUI to do so....

  var elements = document.getElementsByTagName('*');
  var nrElements = elements.length;

  for (i = 0, j = 0; i < nrElements; i++) {
    if (elements[i].className == 'xinha') {
      // For all nodes of CSS class 'xinha', we register the event
      // handlers.
      editElements.push(this.setEventHandler(elements[i])); 
    } else if (elements[i].className == 'xinhaupdate') {
      // For all nodes of CSS class 'xinhaupdate' (usually only a
      // single button) we register the finish handler to copy the
      // content to the hidden fields.
      elements[i].onclick = function() {
	xinha.inplace.finish();
      }
    }
  }		
};

/*
 * Iterate over all nodes and copy the content of the elements of
 * class 'xinha' to the corresponding hidden fields in the form; the
 * correspondance happens via a naming convention of IDs.  
 *
 */	
xinha.inplace.finish = function() {
  var elements = document.getElementsByTagName('*');
  var nrElements = elements.length;
  for (i = 0, j = 0; i < nrElements; i++) {
    if (elements[i].className == 'xinha') {
      var htmlText = elements[i].innerHTML;
      var hiddenId = elements[i].id + '__HIDDEN__';
      var hidden = document.getElementById(hiddenId);
      if (hidden == undefined) {
	//console.log('ignoring ' + hiddenId);
      } else {
	hidden.value = htmlText;
      }
    }
  }
};

/*
 * Define standard handlers (for 'xinha' elements)
 * - onmouseover
 * - onmouseout
 * - ondblclick
 */
xinha.inplace.setEventHandler = function(element) {
  element.onmouseover = function() {
    xinha.inplace.backgroundColor = this.style.backgroundColor;
    this.style.backgroundColor = xinha.inplace.hoverColor;
  }
  element.onmouseout = function() {this.style.backgroundColor = xinha.inplace.backgroundColor;}
  element.ondblclick = function() {xinha.inplace.openEditor(this);}
  return element;
};


/*
 * openEditor function: we define an inplace form with a textarea and a save
 * and cancel button. The content of the textarea will be set to the
 * content of the given element. On a save operation, this content of
 * the element will be replaced by the content of the textarea.
 */
xinha.inplace.openEditor = function(element) {
  // use two IDs to locate later the editForm and the textArea
  var editFormId = element.id + '__FORM__';
  var textAreaId = element.id + '__TEXTAREA__';

  // create editForm and form elements
  var editForm = document.createElement('form');
  var textArea = document.createElement('textarea');
  var saveButton = document.createElement('input');
  var cancelButton = document.createElement('input');

  // configure textArea, editForm and buttons
  textArea.id = textAreaId;
  textArea.value = element.innerHTML;
  textArea.style.width  = element.style.width ?  element.style.width  : element.offsetWidth  + 'px';
  textArea.style.height = element.style.height ? element.style.height : (element.offsetHeight + 25) + 'px';
  textArea.focus();

  editForm.id = editFormId;
  editForm.onsubmit =  function() {
    xinha.inplace.closeEditor(this.id, element, 1, this.getElementsByTagName('textarea')[0].value);
    return false;
  };
  
  saveButton.type = 'submit';
  saveButton.value = this.saveButtonLabel;

  cancelButton.type = 'button';
  cancelButton.value =  this.cancelButtonLabel;
  cancelButton.onclick =  function() {
    xinha.inplace.closeEditor(editFormId, element, 0, '');
    return false;
  };

  // insert the created nodes
  editForm.appendChild(textArea);
  editForm.appendChild(saveButton);
  editForm.appendChild(cancelButton);
  element.parentNode.insertBefore(editForm,element);
  
  // make the original element invisible
  element.style.display = 'none';
  
  // configure xinha
  
  // use globally provided xinha_config, provided by OpenACS, and configure a few parameter
  xinha_config.statusBar = false;
  xinha_config.height = 'auto'; //textArea.style.height;
  xinha_config.sizeIncludesBars = false;
  xinha_config.sizeIncludesPanels = false;

  // start xinha
  this.xinha_editors.push(textAreaId);
  this.xinha_editors = Xinha.makeEditors(this.xinha_editors, xinha_config, xinha_plugins);
  Xinha.startEditors(this.xinha_editors);
  this.xinha_editors = [];
};

/* 
 * closeEditor is the inverse function of openEditor: it updates
 * optionally the base element and removes the inplace editor
 */
xinha.inplace.closeEditor = function(id, element, replace, htmlText) {
  var editForm = document.getElementById(id);
  // update text of the div, 
  if (replace) {
    element.innerHTML = htmlText;
  }
  // make div visible and remove editor
  element.style.display = 'block';
  this.setEventHandler(element);
  editForm.parentNode.removeChild(editForm);
};
